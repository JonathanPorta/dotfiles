#!/usr/bin/env python3
"""Install Claude and Codex config.d fragments without replacing user config."""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile
import tomllib
from typing import Any


class SafetyError(RuntimeError):
    """Raised when an install would risk replacing unparseable user data."""


def deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge objects; fragment scalars and arrays replace targets."""
    result = copy.deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def require_regular_target(path: Path) -> None:
    if path.is_symlink():
        raise SafetyError(
            f"refusing to replace symlinked config {path}; merge its target explicitly"
        )
    if path.exists() and not path.is_file():
        raise SafetyError(f"refusing to replace non-file config {path}")


def read_json_object(path: Path, *, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SafetyError(f"cannot parse {label} as JSON: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SafetyError(f"{label} must contain a JSON object: {path}")
    return value


def plan_claude_config(home: Path, fragments_dir: Path) -> tuple[Path, str]:
    target = home / ".claude" / "settings.json"
    require_regular_target(target)
    merged: dict[str, Any]
    if target.exists():
        merged = read_json_object(target, label="Claude settings")
    else:
        merged = {}

    fragments = sorted(fragments_dir.glob("*.json"))
    if not fragments:
        raise SafetyError(f"no Claude JSON fragments found in {fragments_dir}")
    for fragment_path in fragments:
        fragment = read_json_object(fragment_path, label="Claude config fragment")
        merged = deep_merge(merged, fragment)

    return target, json.dumps(merged, indent=2, ensure_ascii=False) + "\n"


CODEX_TUI_KEYS = {"notification_condition", "notifications", "status_line"}


def load_codex_tui_settings(fragments_dir: Path) -> dict[str, Any]:
    fragments = sorted(fragments_dir.glob("*.toml"))
    if not fragments:
        raise SafetyError(f"no Codex TOML fragments found in {fragments_dir}")

    settings: dict[str, Any] = {}
    for fragment_path in fragments:
        try:
            fragment = tomllib.loads(fragment_path.read_text(encoding="utf-8"))
        except (OSError, tomllib.TOMLDecodeError) as exc:
            raise SafetyError(
                f"cannot parse Codex config fragment {fragment_path}: {exc}"
            ) from exc

        if set(fragment) != {"tui"} or not isinstance(fragment["tui"], dict):
            raise SafetyError(
                f"Codex fragment may only contain the [tui] table: {fragment_path}"
            )
        if not fragment["tui"]:
            raise SafetyError(
                f"Codex fragment must set at least one [tui] key: {fragment_path}"
            )
        unsupported = set(fragment["tui"]) - CODEX_TUI_KEYS
        if unsupported:
            raise SafetyError(
                "Codex fragment contains unsupported [tui] keys "
                f"{sorted(unsupported)}: {fragment_path}"
            )

        for key, candidate in fragment["tui"].items():
            if key in {"notifications", "status_line"}:
                if not isinstance(candidate, list) or not all(
                    isinstance(item, str) and item for item in candidate
                ):
                    raise SafetyError(
                        f"tui.{key} must be an array of non-empty strings: "
                        f"{fragment_path}"
                    )
            elif key == "notification_condition" and candidate not in {
                "always",
                "unfocused",
            }:
                raise SafetyError(
                    "tui.notification_condition must be 'always' or 'unfocused': "
                    f"{fragment_path}"
                )
            settings[key] = copy.deepcopy(candidate)

    return settings


TABLE_HEADER_RE = re.compile(r"^\s*\[\[?[^]]+\]\]?\s*(?:#.*)?$")
TUI_HEADER_RE = re.compile(r"^\s*\[tui\]\s*(?:#.*)?$")


def bracket_delta(line: str) -> int:
    """Count TOML array brackets outside quoted strings and comments."""
    delta = 0
    quote: str | None = None
    escaped = False
    for char in line:
        if quote == '"':
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quote = None
            continue
        if quote == "'":
            if char == "'":
                quote = None
            continue
        if char == "#":
            break
        if char in {'"', "'"}:
            quote = char
        elif char == "[":
            delta += 1
        elif char == "]":
            delta -= 1
    return delta


def render_tui_setting(key: str, value: Any, indent: str = "") -> list[str]:
    if isinstance(value, list):
        lines = [f"{indent}{key} = [\n"]
        lines.extend(
            f"{indent}  {json.dumps(item, ensure_ascii=False)},\n" for item in value
        )
        lines.append(f"{indent}]\n")
        return lines
    if isinstance(value, str):
        return [f"{indent}{key} = {json.dumps(value, ensure_ascii=False)}\n"]
    raise SafetyError(f"cannot render unsupported tui.{key} value")


def merge_codex_tui_setting(original: str, key: str, value: Any) -> str:
    lines = original.splitlines(keepends=True)
    tui_index = next(
        (
            index
            for index, line in enumerate(lines)
            if TUI_HEADER_RE.match(line.rstrip("\r\n"))
        ),
        None,
    )

    if tui_index is None:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.append("[tui]\n")
        lines.extend(render_tui_setting(key, value))
        return "".join(lines)

    table_end = len(lines)
    for index in range(tui_index + 1, len(lines)):
        if TABLE_HEADER_RE.match(lines[index].rstrip("\r\n")):
            table_end = index
            break

    setting_re = re.compile(rf"^(?P<indent>\s*){re.escape(key)}\s*=")
    existing_index: int | None = None
    existing_end: int | None = None
    indent = ""
    for index in range(tui_index + 1, table_end):
        match = setting_re.match(lines[index])
        if not match:
            continue
        existing_index = index
        indent = match.group("indent")
        depth = bracket_delta(lines[index].split("=", 1)[1])
        existing_end = index + 1
        while depth > 0 and existing_end < table_end:
            depth += bracket_delta(lines[existing_end])
            existing_end += 1
        if depth != 0:
            raise SafetyError(f"could not find the end of existing tui.{key}")
        break

    replacement = render_tui_setting(key, value, indent)
    if existing_index is not None and existing_end is not None:
        lines[existing_index:existing_end] = replacement
    else:
        insert_at = tui_index + 1
        lines[insert_at:insert_at] = replacement
    return "".join(lines)


def merge_codex_tui_settings(original: str, settings: dict[str, Any]) -> str:
    merged = original
    # Missing keys are inserted directly after [tui]. Apply in reverse so their
    # final order still follows the lexical fragment order.
    for key in reversed(settings):
        merged = merge_codex_tui_setting(merged, key, settings[key])
    return merged


def plan_codex_config(home: Path, fragments_dir: Path) -> tuple[Path, str]:
    target = home / ".codex" / "config.toml"
    require_regular_target(target)
    original = target.read_text(encoding="utf-8") if target.exists() else ""
    if original:
        try:
            tomllib.loads(original)
        except tomllib.TOMLDecodeError as exc:
            raise SafetyError(f"cannot parse Codex config {target}: {exc}") from exc

    settings = load_codex_tui_settings(fragments_dir)
    merged = merge_codex_tui_settings(original, settings)
    try:
        parsed = tomllib.loads(merged)
    except tomllib.TOMLDecodeError as exc:
        raise SafetyError(
            f"refusing to write invalid merged Codex config {target}: {exc}"
        ) from exc
    parsed_tui = parsed.get("tui", {})
    for key, expected in settings.items():
        if parsed_tui.get(key) != expected:
            raise SafetyError(
                f"merged Codex config did not retain the requested tui.{key}"
            )
    return target, merged


def backup_once(path: Path) -> None:
    if not path.exists():
        return
    backup = path.with_name(path.name + ".pre-agent-config")
    if not backup.exists() and not backup.is_symlink():
        shutil.copy2(path, backup)


def atomic_write(path: Path, content: str) -> bool:
    old_content = path.read_text(encoding="utf-8") if path.exists() else None
    if old_content == content:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    backup_once(path)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    handle, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()
    return True


def plan_symlink(
    source: Path, destination: Path
) -> tuple[Path, Path, str, Path | None]:
    """Validate a renderer update without changing the filesystem."""
    try:
        source = source.resolve(strict=True)
    except OSError as exc:
        raise SafetyError(f"cannot resolve renderer source {source}: {exc}") from exc

    if destination.is_symlink() and os.readlink(destination) == str(source):
        return source, destination, "unchanged", None

    if os.path.lexists(destination):
        backup = destination.with_name(destination.name + ".pre-agent-config")
        same_regular_file = (
            destination.is_file()
            and not destination.is_symlink()
            and destination.read_bytes() == source.read_bytes()
        )
        if os.path.lexists(backup):
            if not same_regular_file:
                raise SafetyError(
                    f"refusing to replace {destination}; backup already exists at {backup}"
                )
            return source, destination, "remove", None
        return source, destination, "backup", backup

    return source, destination, "link", None


def apply_symlink(plan: tuple[Path, Path, str, Path | None]) -> bool:
    """Apply a preflighted renderer update."""
    source, destination, action, backup = plan
    if action == "unchanged":
        return False

    destination.parent.mkdir(parents=True, exist_ok=True)
    if action == "backup":
        assert backup is not None
        os.replace(destination, backup)
    elif action == "remove":
        destination.unlink()
    elif action != "link":
        raise RuntimeError(f"unknown renderer plan action: {action}")

    destination.symlink_to(source)
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dotfiles-dir", type=Path, required=True)
    parser.add_argument("--home", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    fragments_root = args.dotfiles_dir / "agent-config.d"

    # Plan and validate every config before modifying any of them.
    claude_target, claude_content = plan_claude_config(
        args.home, fragments_root / "claude"
    )
    codex_plan = None
    if shutil.which("codex") is not None:
        codex_plan = plan_codex_config(args.home, fragments_root / "codex")
    renderer_plan = plan_symlink(
        fragments_root / "claude" / "statusline-command.sh",
        args.home / ".claude" / "statusline-command.sh",
    )

    claude_changed = atomic_write(claude_target, claude_content)
    codex_changed = atomic_write(*codex_plan) if codex_plan is not None else None
    renderer_changed = apply_symlink(renderer_plan)

    if codex_changed is None:
        codex_result = "skipped (not installed)"
    else:
        codex_result = "updated" if codex_changed else "unchanged"

    print(
        "Agent config: "
        f"Claude {'updated' if claude_changed else 'unchanged'}, "
        f"Codex {codex_result}, "
        f"renderer {'linked' if renderer_changed else 'unchanged'}."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SafetyError as exc:
        raise SystemExit(f"Error: {exc}") from exc
