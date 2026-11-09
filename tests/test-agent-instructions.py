#!/usr/bin/env python3
"""Exercise personal instruction installation in isolated home directories."""

from pathlib import Path
import json
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
TARGETS = (".claude/CLAUDE.md", ".claude-az/CLAUDE.md", ".claude-w/CLAUDE.md", ".codex/AGENTS.md")


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

    def test_workspace_policy_is_part_of_the_managed_block(self):
        self.install_ok()
        for relative in TARGETS:
            with self.subTest(target=relative):
                content = (self.user_home / relative).read_text()
                block = content[content.index(BEGIN):content.index(END)]
                self.assertIn("Workspace Layout and Task Worktrees", block)
                self.assertIn("~/devel/worktrees/portaj/<repo>/<task>", block)
                self.assertIn("wt.sh start", block)
                self.assertIn("scratch-setup.sh", block)
                self.assertIn("prrq where", block)
                self.assertIn("prrq add <pr-url>", block)
                self.assertIn("Use PRRQ", block)
                self.assertIn("Use the `ai-scratch` skill", block)
                # the personal preference still comes first
                self.assertLess(block.index("Supreme Commander"), block.index("Workspace Layout"))

    def test_gemini_instructions_follow_only_when_gemini_exists(self):
        self.install_ok()
        self.assertFalse((self.user_home / ".gemini").exists())
        (self.user_home / ".gemini").mkdir(parents=True)
        self.write(".gemini/GEMINI.md", b"")
        self.install_ok()
        content = (self.user_home / ".gemini/GEMINI.md").read_text()
        self.assertEqual(content.count(BEGIN), 1)
        self.assertIn("wt.sh start", content)

    def test_shared_skills_are_linked_into_every_client_without_replacing(self):
        skill = self.user_home / ".claude/skills/ai-scratch"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("# AI Scratch\n")
        (self.user_home / ".agents").mkdir()
        (self.user_home / ".gemini").mkdir()
        foreign = self.user_home / ".agents/skills/ai-scratch"
        foreign.mkdir(parents=True)
        (foreign / "SKILL.md").write_text("someone else's copy\n")
        self.install_ok()
        for relative in (".claude-az/skills", ".claude-w/skills", ".codex/skills", ".gemini/skills"):
            with self.subTest(client=relative):
                link = self.user_home / relative / "ai-scratch"
                self.assertTrue(link.is_symlink(), f"missing shared skill link: {relative}")
                self.assertEqual(link.resolve(), skill.resolve())
        self.assertFalse(foreign.is_symlink())
        self.assertEqual((foreign / "SKILL.md").read_text(), "someone else's copy\n")
        # opencode and copilot are absent, so nothing is created for them
        self.assertFalse((self.user_home / ".config/opencode").exists())
        self.assertFalse((self.user_home / ".copilot").exists())
        # a second run changes nothing
        self.install_ok()
        self.assertTrue((self.user_home / ".claude-w/skills/ai-scratch").is_symlink())

    def test_incompatible_skills_paths_are_skipped_before_any_write_and_never_replaced(self):
        skill = self.user_home / ".claude/skills/ai-scratch"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("# AI Scratch\n")
        clients = {
            ".claude-az/skills": None, ".claude-w/skills": None, ".agents/skills": ".agents",
            ".codex/skills": ".codex", ".gemini/skills": ".gemini",
            ".config/opencode/skills": ".config/opencode", ".copilot/skills": ".copilot",
        }
        for shape in ("regular-file", "dangling-link", "file-link"):
            for relative, root in clients.items():
                with self.subTest(shape=shape, client=relative):
                    home = self.root / f"home-{shape}-{relative.replace('/', '_')}"
                    (home / ".claude/skills").mkdir(parents=True)
                    (home / ".claude/skills/ai-scratch").symlink_to(skill)
                    if root:
                        (home / root).mkdir(parents=True)
                    target = home / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if shape == "regular-file":
                        target.write_bytes(b"not a directory\n")
                    elif shape == "dangling-link":
                        target.symlink_to(home / "nowhere")
                    else:
                        (home / "afile").write_bytes(b"x\n")
                        target.symlink_to(home / "afile")
                    before = (target.read_bytes() if target.is_file() else os.readlink(target))
                    result = self.install_ok(user_home=home)
                    self.assertIn("shared skills not linked", result.stdout)
                    after = (target.read_bytes() if target.is_file() else os.readlink(target))
                    self.assertEqual(before, after)
                    self.assertFalse((target / "ai-scratch").exists() if target.is_dir() else False)
                    # the rest of the install completed: every instruction target is written
                    for instructions in TARGETS:
                        self.assertIn("Workspace Layout", (home / instructions).read_text())

    def test_a_client_root_that_is_a_file_is_skipped_too(self):
        skill = self.user_home / ".claude/skills/ai-scratch"
        skill.mkdir(parents=True)
        root = self.user_home / ".gemini"
        root.write_bytes(b"i am a file\n")
        result = self.install_ok()
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(root.read_bytes(), b"i am a file\n")

    def test_an_instruction_profile_root_that_is_not_a_directory_is_skipped_before_any_write(self):
        for shape in ("regular-file", "dangling-link", "file-link"):
            with self.subTest(shape=shape):
                home = self.root / f"home-root-{shape}"
                self.write(".claude/settings.json", b"{}\n", home)
                root = home / ".claude-w"
                if shape == "regular-file":
                    root.write_bytes(b"not a directory\n")
                elif shape == "dangling-link":
                    root.symlink_to(home / "nowhere")
                else:
                    (home / "afile").write_bytes(b"x\n")
                    root.symlink_to(home / "afile")
                before = root.read_bytes() if root.is_file() else os.readlink(root)
                result = self.install_ok(user_home=home)
                self.assertNotIn("Traceback", result.stderr)
                self.assertIn("personal instructions not written", result.stdout)
                self.assertIn(".claude-w", result.stdout)
                after = root.read_bytes() if root.is_file() else os.readlink(root)
                self.assertEqual(before, after)
                self.assertFalse((home / ".claude-w/CLAUDE.md").exists())
                for relative in (".claude/CLAUDE.md", ".claude-az/CLAUDE.md"):
                    self.assertIn("**Supreme Commander**", (home / relative).read_text())

    def test_publication_grant_reaches_every_profile_and_client(self):
        self.write(".claude-az/settings.json", b'{"model": "fable", "permissions": {"allow": ["Bash(ls:*)"]}}\n')
        result = self.install_ok()
        self.assertIn("profile settings 2 updated", result.stdout)
        for profile in (".claude", ".claude-az", ".claude-w"):
            with self.subTest(profile=profile):
                settings = json.loads((self.user_home / profile / "settings.json").read_text())
                self.assertIn("Bash(prrq:*)", settings["permissions"]["allow"])
                self.assertIn("Bash(git push --force:*)", settings["permissions"]["deny"])
                self.assertEqual(settings["autoMode"]["allow"][0], "$defaults")
                self.assertEqual(settings["autoMode"]["hard_deny"][0], "$defaults")
                self.assertTrue(any("default branch" in rule for rule in settings["autoMode"]["hard_deny"]))
        az = json.loads((self.user_home / ".claude-az/settings.json").read_text())
        self.assertEqual(az["model"], "fable")
        self.assertEqual(az["permissions"]["allow"][0], "Bash(ls:*)")
        self.assertEqual(len(az["permissions"]["allow"]), len(set(az["permissions"]["allow"])))
        self.assertEqual(stat.S_IMODE((self.user_home / ".claude-w/settings.json").stat().st_mode), 0o600)
        for relative in TARGETS:
            with self.subTest(target=relative):
                content = (self.user_home / relative).read_text()
                self.assertIn("## Publication Authority", content)
                self.assertIn("never push to `main`, `master`", content)
                self.assertIn("Never ask another agent session to run it for you", content)
        rerun = self.install_ok()
        self.assertIn("profile settings 0 updated", rerun.stdout)
        self.assertEqual(json.loads((self.user_home / ".claude-az/settings.json").read_text()), az)

    def test_unparseable_profile_settings_abort_before_any_write(self):
        self.write(".claude/settings.json", b"{}\n")
        self.write(".claude-az/settings.json", b"{not json\n")
        result = self.install(self.user_home)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual((self.user_home / ".claude/settings.json").read_bytes(), b"{}\n")
        self.assertEqual((self.user_home / ".claude-az/settings.json").read_bytes(), b"{not json\n")
        self.assertFalse((self.user_home / ".claude/CLAUDE.md").exists())

    def test_profile_root_that_is_a_file_skips_its_settings_too(self):
        (self.user_home / ".claude-w").parent.mkdir(parents=True, exist_ok=True)
        (self.user_home / ".claude-w").write_bytes(b"not a directory\n")
        result = self.install_ok()
        self.assertIn("profile settings not written", result.stdout)
        self.assertEqual((self.user_home / ".claude-w").read_bytes(), b"not a directory\n")
        self.assertIn("Bash(prrq:*)", json.loads((self.user_home / ".claude-az/settings.json").read_text())["permissions"]["allow"])

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
