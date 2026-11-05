# Changelog

## 0.1.0 (2026-11-05)

First tagged release.

- Rules, git hooks and scripts for several AI coding agents sharing one repository.
- Installers for Linux, macOS and Windows, with a smoke test on all three in CI.
- New: `scripts/check_agent_trailers.sh` and a GitHub Actions workflow that check commit
  trailers on every push and pull request. A fresh clone has the local hook off, so unsigned
  commits used to go unnoticed there.
- `AGENTS.md` now tells every agent to enable the hooks at the start of each session.
