# multi-agent-repo-protocol

[![smoke test](https://github.com/Soda-null/multi-agent-repo-protocol/actions/workflows/test.yml/badge.svg)](https://github.com/Soda-null/multi-agent-repo-protocol/actions/workflows/test.yml)
[![release](https://img.shields.io/github/v/release/Soda-null/multi-agent-repo-protocol)](https://github.com/Soda-null/multi-agent-repo-protocol/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

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
puts everything into files, gives each agent its own branch and directory, and backs the most
important rules with machine checks. [What is enforced](#what-is-enforced-and-what-is-not) lists
which rules have a check and which do not.

## Try it in one minute

```bash
git clone https://github.com/Soda-null/multi-agent-repo-protocol.git
git init -b main demo
multi-agent-repo-protocol/install.sh demo
cd demo
git add -A
git commit -m "first"                     # rejected: no agent named
git commit -m "first" -m "Agent: human"   # accepted
```

## What is inside

| Piece | What it does |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | One constitution read by every agent |
| `docs/agent_board.md` | Claims table: who is working on which paths right now |
| `.githooks/commit-msg` | Rejects a commit without an `Agent: <name>` trailer, and an agent's commit outside its own branch |
| `.github/workflows/agent-trailers.yml` | Runs the same check on GitHub, so a commit from a clone without hooks is still seen |
| `scripts/agent_worktree.sh` | Gives each agent its own working tree on `agent/<name>`, and lists what each one has changed |
| `scripts/delegate.sh` | Sends a task to a cheaper agent — **only if the task names a command that proves it correct** |
| `docs/decisions.md` + `docs/glossary.md` | Append-only decision ledger with an index, and one line per code name |
| `scripts/check_current_docs.py` | Blocks a commit when an entry file cites a superseded decision without saying so |
| `scripts/check_doc_structure.py` | Every doc has a header card; indexes list every file; entry files stay small |
| `scripts/worklog.py`, `new_log.py` | Daily log, and hours derived from commit times (no tokens) |
| `scripts/repo_hygiene.py` | Weekly check-up: deletes only junk and merged branches, reports the rest |
| `.claude/skills/close-session/` | A Claude Code skill: the end-of-session checklist |

## The rules in one screen

1. **Start:** go to your own working tree, `git merge main`, `git status`, read the board. Uncommitted changes belong to another agent: never revert, stash or tidy them.
2. **Claim** your task on the board in your first commit; release it when done.
3. **Sign** every commit with `Agent: claude-code` (or `codex`, `deepseek`, `local`, `human`). The hook enforces it.
4. **Stage your own paths by name.** Never `git add -A` in a shared tree.
5. **Each agent commits only on its own branch,** in its own directory. The hook enforces it. Merging into `main` is the human's call.
6. **Never silently reverse another agent's conclusion.** Ledgers are append-only; without new evidence, write the disagreement down and let the human decide.
7. **Peers do not call peers.** Codex and Claude Code are the human's two seats; neither invokes the other unless the human asks (`delegate.sh` needs `--peer`).
8. **Delegation needs an acceptance command.** No command that proves the work right → the task is judgment work and stays with the expensive agent and the human.
9. **The most-read files state only what holds now.** A superseded decision is removed or marked in the same clause; a checker enforces it.
10. **End:** commit everything you finished. What you leave uncommitted is what the next agent destroys.

Why each rule exists, with the incidents behind it: [`docs/why.md`](docs/why.md).

## What is enforced, and what is not

| Rule | What checks it |
|---|---|
| Every commit names its agent | `commit-msg` hook, and CI on GitHub |
| An agent commits only on its own branch | `commit-msg` hook, on your machine only |
| Entry files cite no superseded decision | `pre-commit` hook |
| Delegation has an acceptance command; peers need `--peer` | `delegate.sh` |
| Claims are respected; other agents' uncommitted files are left alone; paths are staged by name; ledgers are append-only | **Nothing.** These are written rules. Separate directories make the first three matter less |

Any agent can skip a hook with `git commit --no-verify`. The CI check cannot be skipped that way,
but it only looks at the trailer.

## A normal day

```bash
scripts/agent_worktree.sh codex         # makes ../your-repo-codex on branch agent/codex
scripts/agent_worktree.sh claude-code   # makes ../your-repo-claude-code on agent/claude-code
```

Start each agent in its own directory. If an agent tries to commit anywhere else, the hook rejects
the commit and tells it what to do. When an agent is done, merge its work from your main checkout:

```bash
scripts/agent_worktree.sh --list        # see what each agent has changed
git merge --no-ff agent/codex
```

If two agents changed the same lines, git shows a conflict here and you decide. Your own commits
(`Agent: human`) can go anywhere.

**This costs one extra merge per job,** even when you run one agent at a time. To turn the rule off,
set `REQUIRE_AGENT_BRANCH=0` in `.githooks/commit-msg`. Do the same if a tool insists on its own
branch names, because the rule only accepts `agent/<name>` and `agent/<name>-<suffix>`.

## Install

```bash
git clone https://github.com/Soda-null/multi-agent-repo-protocol.git
cd multi-agent-repo-protocol
./install.sh /path/to/your/repo
```

`install.sh` copies the template into your repository, **never overwrites an existing file**
(it lists what it skipped), links `CLAUDE.md` to `AGENTS.md`, and sets `core.hooksPath`.
Then fill in the "Project" section of `AGENTS.md` and §1 of `STATUS.md`.

### Every new clone

Git does not turn hooks on when it clones a repository, so in a fresh clone an unsigned commit
goes through. Three things cover this:

- **Locally:** run this once per clone. `AGENTS.md` tells every agent to run it at the start of a session.

  ```bash
  git config core.hooksPath .githooks
  ```

- **On GitHub:** the installed workflow checks every push and pull request, and marks the run
  as failed when a commit is unsigned.
- **To block merges:** a failed run does not stop anything by itself. In the repository's
  settings, add a branch protection rule for `main` and make `agent-trailers` a required check.

A bot that cannot sign its commits, such as Dependabot, fails this check. Skip it in the
workflow with `if: github.actor != 'dependabot[bot]'`, or leave the check optional.

Requirements: git ≥ 2.28, bash, Python ≥ 3.9. No Python packages. Tested on Linux, macOS and Windows.

### Windows

Install [Git for Windows](https://git-scm.com/download/win) (it brings Git Bash) and Python
3.9+, then in PowerShell:

```powershell
.\install.ps1 C:\path\to\your\repo
```

What is different on Windows, and handled for you:

- **Line endings.** `.gitattributes` keeps shell scripts and hooks at LF; with CRLF, bash fails
  with `\r: command not found`. If your repository already has a `.gitattributes`, the
  installer skips it — add the lines from `template/.gitattributes` yourself.
- **`python3`.** Windows often has only `python` or `py`. The hooks and `delegate.sh` find a
  working Python 3 and make `python3 ...` acceptance lines work anyway. In PowerShell, run the
  scripts as `python scripts\check_doc_structure.py`.
- **Symlinks** need Developer Mode. Without it, `CLAUDE.md` becomes a one-line file
  `@AGENTS.md` (Claude Code reads it as an import), and `agent_worktree.sh` skips linking
  untracked data rather than copying it.
- **Run the shell scripts** (`agent_worktree.sh`, `delegate.sh`) from Git Bash. Git runs the
  hooks with its own bash, so commits from any terminal or app are checked.
- **Time zone names** (`LOG_TZ`) need `pip install tzdata` on Windows; without it the local
  time is used, with a warning.

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

- **Damage before a commit.** Git has no hook that runs before `git checkout -- file` or
  `git stash`, so an agent that ignores the rules and enters another agent's directory can still
  destroy uncommitted work.
- **An agent that lies.** The trailer is a claim, not a proof: any agent can write
  `Agent: human`. It stops forgetting and confusion, not deliberate forgery.
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

## Feedback

Tried it on a real project? A [field report](https://github.com/Soda-null/multi-agent-repo-protocol/issues/new?template=field_report.md)
helps most, good or bad. To change the code, see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
