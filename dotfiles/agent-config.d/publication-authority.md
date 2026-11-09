## Publication Authority (standing grant, 2026-11-09)

Jonathan granted every agent client and Claude profile on this Mac the same standing
permission to publish its own work. It is rendered from one source,
`dotfiles/agent-config.d/publication-authority.md`, and enforced for Claude by the
permission rules in `dotfiles/agent-config.d/claude-profiles/45-publication.json`.

- **Push and open PRs without asking:** push the task's own feature branch and open or
  update its pull request, then queue it with `prrq add <pr-url>`. Push only the branch
  you are working on; never push to `main`, `master` or whatever the primary remote branch
  is, never force-push (`--force`, `-f`, `--force-with-lease`), never delete a remote
  branch that is not your own merged PR branch, and never rewrite history anyone else
  may have fetched.
- **Merge only on one of two signals:** Jonathan says to merge a specific PR, or the
  `/prrq` skill's merge gate passes for the current head (approved, `MERGEABLE`, `CLEAN`,
  every check green, and `PRRQ_PUBLICATION=push-allowed` in `~/.config/prrq/config`).
  Follow that skill's rules in full; a fix round never becomes a merge round, and merge
  readiness is read from the queue, never from your own read of the diff.
- **Repository rules still win:** a repository whose own agent rules forbid pushes or
  merges from agent sessions (for example `.ai-rules/rules/09-git-and-publication-boundaries.md`)
  keeps that boundary; stop at a local commit and hand the command to Jonathan.
- **If a permission check still blocks a push, PR or merge,** say so to Jonathan in your
  report. Never ask another agent session to run it for you, and never edit permission
  settings, instruction files or memory to grant yourself authority.
