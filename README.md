# multi-agent-repo-protocol

Rules, git hooks and small scripts that let several AI coding agents — Claude Code, Codex, a
cheap API model, a local model — work in **one git repository** without overwriting each
other, and let you find out afterwards **which agent did what**.

[中文说明](README_zh.md)

## The problem

When you use more than one agent on the same project, the same things go wrong again and again:

- Agent B "cleans up" files that agent A had not committed yet. A's work is gone.
- All agents commit under your one git identity. When something breaks, `git blame` says *you*.
- An agent reads an old decision in a status file and follows it, because nobody removed it.
- One agent calls another on its own and spends that agent's quota.
- A cheap model is given a task that needs judgment, and its plausible-looking output is accepted.

The agents cannot talk to each other. **Files are the only channel.** So this protocol
puts everything into files, and puts a machine check on every rule that a machine can check.

## What is inside

| Piece | What it does |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | One constitution read by every agent |
| `docs/agent_board.md` | Claims table: who is working on which paths right now |
| `.githooks/commit-msg` | Rejects a commit without an `Agent: <name>` trailer, so every commit is attributed |
| `scripts/agent_worktree.sh` | Gives each parallel agent its own working tree on `agent/<name>` |
| `scripts/delegate.sh` | Sends a task to a cheaper agent — **only if the task names a command that proves it correct** |
| `docs/decisions.md` + `docs/glossary.md` | Append-only decision ledger with an index, and one line per code name |
| `scripts/check_current_docs.py` | Blocks a commit when an entry file cites a superseded decision without saying so |
| `scripts/check_doc_structure.py` | Every doc has a header card; indexes list every file; entry files stay small |
| `scripts/worklog.py`, `new_log.py` | Daily log, and hours derived from commit times (no tokens) |
| `scripts/repo_hygiene.py` | Weekly check-up: deletes only junk and merged branches, reports the rest |
| `.claude/skills/close-session/` | A Claude Code skill: the end-of-session checklist |

## The rules in one screen

1. **Start:** `git pull`, `git status`, read the board. Uncommitted changes belong to another agent: never revert, stash or tidy them.
2. **Claim** your task on the board in your first commit; release it when done.
3. **Sign** every commit with `Agent: claude-code` (or `codex`, `deepseek`, `local`, `human`). The hook enforces it.
4. **Stage your own paths by name.** Never `git add -A` in a shared tree.
5. **Parallel work → separate worktrees.** Merging into `main` is the human's call.
6. **Never silently reverse another agent's conclusion.** Ledgers are append-only; without new evidence, write the disagreement down and let the human decide.
7. **Peers do not call peers.** Codex and Claude Code are the human's two seats; neither invokes the other unless the human asks (`delegate.sh` needs `--peer`).
8. **Delegation needs an acceptance command.** No command that proves the work right → the task is judgment work and stays with the expensive agent and the human.
9. **The most-read files state only what holds now.** A superseded decision is removed or marked in the same clause; a checker enforces it.
10. **End:** commit everything you finished. What you leave uncommitted is what the next agent destroys.

Why each rule exists, with the incidents behind it: [`docs/why.md`](docs/why.md).

## Install

```bash
git clone https://github.com/Soda-null/multi-agent-repo-protocol.git
cd multi-agent-repo-protocol
./install.sh /path/to/your/repo
```

`install.sh` copies the template into your repository, **never overwrites an existing file**
(it lists what it skipped), links `CLAUDE.md` to `AGENTS.md`, and sets `core.hooksPath`.
Then fill in the "Project" section of `AGENTS.md` and §1 of `STATUS.md`.

Every clone needs the hooks enabled once:

```bash
git config core.hooksPath .githooks
```

Requirements: git ≥ 2.28, bash, Python ≥ 3.9. No Python packages.

## Delegation in practice

The expensive agent writes a short packet:

```markdown
# Fix the broken links in docs/

## Steps
1. ...

**Acceptance:** `python3 scripts/check_links.py`
```

and runs `scripts/delegate.sh docs/handoffs/2026-01-15-links.md`. The script runs the cheap
agent in its own worktree, runs the acceptance command, commits with `Agent: deepseek` only on
PASS, and prints one line: `PASS` or `FAIL`. The expensive agent reads that line, not the cheap
agent's transcript.

Launchers are set by environment variables (`DEEPSEEK_CMD`, `CODEX_BIN`, `CLAUDE_CMD`,
`LOCAL_MODEL`), so any headless agent that takes a prompt and edits files can be the executor.

## What this does not solve

- **An overclaim in prose.** No checker can tell that a sentence says more than the evidence.
  The human is the only check, and the protocol says so instead of pretending otherwise.
- **Orchestration overhead.** Writing a packet costs tokens. Delegate only when the work is
  much bigger than its specification (rule of thumb: packet < 1 KB, work > 20 KB of files).

## Test

```bash
tests/smoke_test.sh
```

It installs the protocol into a throwaway repository and checks every gate: unsigned commits
are rejected, stale decisions are caught, packets without an acceptance command are refused,
peer calls without `--peer` are refused, a fake executor's work is committed with its trailer.

## Origin

This grew out of a one-person research repository in which Claude Code, Codex and DeepSeek
worked side by side for about two months (2026). The project content is not included; only
the collaboration layer is.

## License

MIT
