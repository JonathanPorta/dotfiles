#!/usr/bin/env python3
"""Exercise personal instruction installation in isolated home directories."""

from pathlib import Path
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
BEGIN = "<!-- dotfiles:personal-instructions:start -->"
END = "<!-- dotfiles:personal-instructions:end -->"
TARGETS = (".claude/CLAUDE.md", ".claude-az/CLAUDE.md", ".codex/AGENTS.md")


class PersonalInstructionsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.user_home = self.root / "home"
        self.dotfiles = self.root / "dotfiles"
        shutil.copytree(REPO / "dotfiles/agent-config.d", self.dotfiles / "agent-config.d")
        self.source = self.dotfiles / "agent-config.d/personal-instructions.md"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        executable = self.bin / "codex"
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)

    def install(self, user_home=None, *, codex=True):
        environment = os.environ.copy()
        environment["PATH"] = str(self.bin if codex else self.root / "empty-bin")
        return subprocess.run(
            [sys.executable, str(REPO / "dotfiles/helpers/install_agent_config.py"),
             "--dotfiles-dir", str(self.dotfiles), "--home", str(user_home or self.user_home)],
            env=environment, capture_output=True, text=True, check=False,
        )

    def install_ok(self, **kwargs):
        result = self.install(**kwargs)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def write(self, relative, content, user_home=None):
        path = (user_home or self.user_home) / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def test_fresh_install_covers_personal_profiles(self):
        self.install_ok()
        for relative in TARGETS:
            with self.subTest(target=relative):
                path = self.user_home / relative
                self.assertTrue(path.is_file(), f"missing personal instructions: {relative}")
                content = path.read_text()
                self.assertIn("Jonathan Porta", content)
                self.assertIn("**Supreme Commander**", content)
                self.assertEqual(content.count(BEGIN), 1)
                self.assertEqual(content.count(END), 1)
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_existing_text_backup_mode_and_rerun_are_preserved(self):
        originals = {}
        for index, relative in enumerate(TARGETS):
            original = b"# Existing personal rules\r\nKeep my preferences." + bytes([65 + index])
            path = self.write(relative, original)
            path.chmod(0o640)
            originals[relative] = original
        self.install_ok()
        snapshots = {}
        for relative, original in originals.items():
            path = self.user_home / relative
            self.assertTrue(path.read_bytes().startswith(original))
            self.assertIn(b"Supreme Commander", path.read_bytes())
            self.assertEqual(path.with_name(path.name + ".pre-agent-config").read_bytes(), original)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o640)
            snapshots[relative] = (path.read_bytes(), path.stat().st_mtime_ns)
        self.install_ok()
        for relative, snapshot in snapshots.items():
            path = self.user_home / relative
            self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), snapshot)
            self.assertEqual(path.with_name(path.name + ".pre-agent-config").read_bytes(), originals[relative])

    def test_source_update_replaces_only_the_managed_section(self):
        prefix = b"# Keep this prefix\n"
        suffix = b"\n# Keep this suffix\r\n"
        path = self.write(TARGETS[0], prefix)
        self.install_ok()
        path.write_bytes(path.read_bytes() + suffix)
        self.source.write_text("Updated personal preference for Jonathan Porta.\n")
        self.install_ok()
        content = path.read_bytes()
        self.assertTrue(content.startswith(prefix))
        self.assertTrue(content.endswith(suffix))
        self.assertEqual(content.count(BEGIN.encode()), 1)
        self.assertIn(b"Updated personal preference", content)
        self.assertNotIn(b"Supreme Commander", content)
        self.assertEqual(path.with_name(path.name + ".pre-agent-config").read_bytes(), prefix)

    def test_nonempty_codex_override_receives_the_preference(self):
        base = self.write(".codex/AGENTS.md", b"Keep the base instructions untouched.\n")
        override = self.write(".codex/AGENTS.override.md", b"My active override.\n")
        self.install_ok()
        self.assertEqual(base.read_bytes(), b"Keep the base instructions untouched.\n")
        self.assertTrue(override.read_bytes().startswith(b"My active override.\n"))
        self.assertIn(b"Supreme Commander", override.read_bytes())

    def test_blank_codex_override_does_not_hide_the_base(self):
        override = self.write(".codex/AGENTS.override.md", b" \n")
        self.install_ok()
        self.assertEqual(override.read_bytes(), b" \n")
        self.assertIn("Supreme Commander", (self.user_home / ".codex/AGENTS.md").read_text())

    def test_missing_codex_leaves_its_instructions_alone(self):
        target = self.write(".codex/AGENTS.md", b"Keep me unchanged.\n")
        self.install_ok(codex=False)
        self.assertEqual(target.read_bytes(), b"Keep me unchanged.\n")
        self.assertFalse(target.with_name(target.name + ".pre-agent-config").exists())
        self.assertIn("Supreme Commander", (self.user_home / TARGETS[0]).read_text())
        fresh = self.root / "fresh-without-codex"
        self.install_ok(user_home=fresh, codex=False)
        self.assertFalse((fresh / ".codex").exists())

    def assert_no_partial_write(self, user_home, result):
        self.assertNotEqual(result.returncode, 0, "unsafe input was accepted")
        self.assertIn("Error:", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual((user_home / ".claude/settings.json").read_bytes(), b"{}\n")
        self.assertFalse((user_home / ".claude/settings.json.pre-agent-config").exists())
        self.assertFalse((user_home / ".claude/statusline-command.sh").exists())
        self.assertFalse((user_home / ".codex/config.toml").exists())

    def test_malformed_markers_abort_before_any_writes(self):
        malformed = [BEGIN, END, END + "\n" + BEGIN,
                     BEGIN + "\n" + END + "\n" + BEGIN + "\n" + END,
                     "inline " + BEGIN + "\n" + END,
                     BEGIN + "\n" + END + " trailing text"]
        for index, content in enumerate(malformed):
            with self.subTest(markers=content):
                user_home = self.root / f"malformed-{index}"
                self.write(".claude/settings.json", b"{}\n", user_home)
                target = self.write(TARGETS[2], content.encode(), user_home)
                self.assert_no_partial_write(user_home, self.install(user_home))
                self.assertEqual(target.read_bytes(), content.encode())
                self.assertFalse((user_home / TARGETS[0]).exists())

    def test_symlinks_and_directories_abort_before_any_writes(self):
        external = self.root / "external.md"
        external.write_text("Do not touch.\n")
        for index, relative in enumerate(TARGETS + (".codex/AGENTS.override.md",)):
            for kind in ("symlink", "dangling", "directory"):
                with self.subTest(target=relative, kind=kind):
                    user_home = self.root / f"unsafe-{index}-{kind}"
                    self.write(".claude/settings.json", b"{}\n", user_home)
                    target = user_home / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if kind == "directory":
                        target.mkdir()
                    else:
                        target.symlink_to(external if kind == "symlink" else self.root / "missing")
                    self.assert_no_partial_write(user_home, self.install(user_home))
                    self.assertEqual(external.read_text(), "Do not touch.\n")
                    self.assertTrue(target.is_dir() if kind == "directory" else target.is_symlink())

    def test_unsafe_backup_paths_abort_before_any_writes(self):
        external = self.root / "external-backup.md"
        external.write_bytes(b"Existing backup.\n")
        for index, relative in enumerate(TARGETS):
            for kind in ("symlink", "directory"):
                with self.subTest(target=relative, kind=kind):
                    user_home = self.root / f"backup-{index}-{kind}"
                    self.write(".claude/settings.json", b"{}\n", user_home)
                    target = self.write(relative, b"Original instructions.\n", user_home)
                    backup = target.with_name(target.name + ".pre-agent-config")
                    if kind == "directory":
                        backup.mkdir()
                    else:
                        backup.symlink_to(external)
                    self.assert_no_partial_write(user_home, self.install(user_home))
                    self.assertEqual(target.read_bytes(), b"Original instructions.\n")
                    self.assertEqual(external.read_bytes(), b"Existing backup.\n")

    def test_invalid_source_or_target_encoding_aborts_cleanly(self):
        cases = [(b"", None), (BEGIN.encode(), None), (b"\xff", None),
                 (b"Valid source.\n", b"\xff")]
        for index, (source, original) in enumerate(cases):
            with self.subTest(case=index):
                user_home = self.root / f"invalid-{index}"
                self.write(".claude/settings.json", b"{}\n", user_home)
                self.source.write_bytes(source)
                if original is not None:
                    self.write(TARGETS[0], original, user_home)
                self.assert_no_partial_write(user_home, self.install(user_home))


if __name__ == "__main__":
    unittest.main()
