# Changelog

## Unreleased

- **New rule, on by default:** an agent may commit only on its own branch, `agent/<name>` or
  `agent/<name>-<suffix>`. `Agent: human` is exempt. Set `REQUIRE_AGENT_BRANCH=0` in
  `.githooks/commit-msg` to turn it off. Existing installs keep their old hook, because the
  installer never overwrites a file.
- `agent_worktree.sh --list` shows what each agent has changed. The script takes its agent names
  from the hook, accepts a second session such as `codex-2`, and works from inside a worktree.
- `docs/agent_board.md` and the daily logs merge without conflicts when agents add rows.
- The README now lists which rules have a machine check and which do not.

## 0.1.0 (2026-11-05)

First tagged release.

- Rules, git hooks and scripts for several AI coding agents sharing one repository.
- Installers for Linux, macOS and Windows, with a smoke test on all three in CI.
- New: `scripts/check_agent_trailers.sh` and a GitHub Actions workflow that check commit
  trailers on every push and pull request. A fresh clone has the local hook off, so unsigned
  commits used to go unnoticed there.
- `AGENTS.md` now tells every agent to enable the hooks at the start of each session.
