## Workspace Layout and Task Worktrees (standing policy, 2026-11-04; recorded here 2026-11-08)

One rule set for every agent client and profile on this Mac. Full detail: the `ai-scratch`
skill (`~/.claude/skills/ai-scratch/SKILL.md`) and `~/devel/worktrees/README.md`.

- **`~/devel/portaj/<repo>` is Jonathan's canonical checkout.** Read it freely. Never switch its
  branch, reset, stash, clean, or `git worktree add` from a path beside it. Write there only when
  Jonathan explicitly asks you to review or work *in his checkout* for the current task; then
  preserve his existing changes, coordinate every write, and do nothing unrelated (no branch
  switches, resets or cleanup). That permission ends with the task.
- **Repository work happens in an owned task worktree** at `~/devel/worktrees/portaj/<repo>/<task>`,
  created only by `wt.sh` (never by hand):
  ```sh
  export WT_OWNER="<project>-<nn> (<session id>)"      # once per session, before any wt.sh call
  ~/.claude/skills/ai-scratch/scripts/wt.sh list <repo>  # existing worktrees, owners, state
  ~/.claude/skills/ai-scratch/scripts/wt.sh start <repo> <task> --purpose "..."
  ```
  `list` first: a worktree for the task that you own is resumed by the same `start`; one owned by
  another session is left alone (ask, do not take). `start` writes the ownership record at
  `~/devel/worktrees/.owners/<repo>/<task>.json`; a worktree without a record is unmanaged.
  Sibling paths (`~/devel/portaj/<repo>-wt-*`), `/private/tmp`, `/tmp` and session scratchpads
  are never acceptable for source worktrees. If `wt.sh` cannot resolve the primary checkout or the
  worktree root, report that configuration problem; do not pick another location.
- **Use the `ai-scratch` skill whenever it is installed** (`~/.claude/skills/ai-scratch`, linked into
  every client): scratch work, generated artifacts, experiments and PR-review clones go in a
  task-specific directory under the AI scratch root, never under `/tmp`, `$HOME`, a session
  scratchpad or a canonical checkout. Discover the root, do not guess:
  `~/.claude/skills/ai-scratch/scripts/scratch-setup.sh` prints the root and its source.
  Precedence: `$AI_SCRATCH_ROOT`, then `~/.ai-scratch/config`, then the built-in default. An unset
  environment variable is normal (noninteractive children have none); the config file is the
  durable source, and the same lookup works from a bare `sh` child. `WT_ROOT`, `WT_PRIMARIES` and
  `WT_BUNDLES` live in that config too. The scratch sweep **hold** is standing policy; nothing is
  deleted on age.
- **Use PRRQ (the PR review queue) whenever it is available** (`prrq` on `PATH`, else
  `~/.local/bin/prrq`): every pull request you open or update is queued for review with
  `prrq add <pr-url>`, and merge readiness is read from the queue (`prrq status`, `prrq check`,
  or the `/prrq` skill), never improvised from your own judgement of the diff. `prrq where` prints
  the queue location from `~/.config/prrq/config` (environment variables override it). PRRQ's own
  review worktrees live inside the repository's `.git/prrq-worktrees/`.
- **Finish through the lifecycle, delete nothing by hand:**
  `wt.sh finish <repo> <task> --pr <url> --release`, then `wt.sh check <repo> <task> --for-removal`.
  Removal is only the non-forced `git worktree remove` that a passing check prints. Preservation
  means reachable from the fresh remote default branch, or a `refs/keep/*` ref plus an
  offline-restored bundle under `~/devel/recovery/bundles/`; a pushed branch tip or merged-PR head
  ref is not enough.
