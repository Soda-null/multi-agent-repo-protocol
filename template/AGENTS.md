# Instructions for every AI agent working in this repository

> **What:** The constitution: the same rules for Claude Code, Codex, DeepSeek and any other agent.
> **Standing:** Current. Written by the owner; agents follow it and do not edit it unless asked.
> **How to read:** Read all of it at the start of every session.

`CLAUDE.md` is a symlink to this file. Point every new agent at it so all of them run on the
same instructions. `docs/multi_agent_system.md` explains why the rules are shaped this way.

## Project

<!-- Fill this in: one paragraph on what the project is, and the invariants no session may
erase. Do not restate the current state here; it lives in STATUS.md only, because two copies
of the state drift apart. -->

## Multi-agent collaboration protocol

Several agents work in this repository. They share one git history and one commit identity,
and they cannot talk to each other: files are the only channel. The rules below are what keeps
them from overwriting each other.

- **Start of session.** Run `git pull` and `git status` first, and read `docs/agent_board.md`.
  Uncommitted changes in the tree are another agent's unfinished session: never revert, stash,
  checkout over, or tidy them away. If they block your task, say so and stop. When a decision
  code (`D<n>`) is unfamiliar, look it up in `docs/glossary.md` before grepping `docs/decisions.md`.
- **Claim your task** in `docs/agent_board.md`, in the same commit as your first change, and
  release the claim when the work is committed. Do not edit a path another agent has claimed.
- **Sign every commit.** End the message with `Agent: codex`, `Agent: claude-code`,
  `Agent: deepseek`, `Agent: local` or `Agent: human`. The `commit-msg` hook enforces this;
  without it nobody can tell who reverted whom. Enable the hooks once per clone with
  `git config core.hooksPath .githooks`.
- **Keep the first line of a commit message under 100 characters** — what changed, in one
  clause. Numbers and narrative go in the body. `git log --oneline` is read at the start of
  every session, so a long first line is paid for by every agent, every time. The hook warns.
- **Stage your own paths by name.** Never `git add -A` or `git add .` in a shared tree: that
  is how another agent's half-finished file gets committed under your name.
- **End of session.** Commit everything you finished. Anything left uncommitted is what the
  next agent destroys. Before the last commit, run `python3 scripts/worklog.py --today` and
  paste its line into the day's log (it derives hours from commit times; no tokens, no judgment).
- **Never silently reverse another agent's recorded conclusion.** In `STATUS.md`,
  `docs/decisions.md` and `docs/open_questions.md`, entries written by others are
  append-only. With new evidence, add a dated entry that names what it supersedes and why.
  Without new evidence, record the disagreement in `docs/open_questions.md` and let the
  owner decide. Only the owner deletes an entry.
- **Parallel sessions need separate working trees.** When another agent is already running,
  run `scripts/agent_worktree.sh <codex|claude-code|deepseek|local>` and work in that
  directory on branch `agent/<name>`. Merging into `main` is the owner's call. Two agents must
  never work on `main` in the same directory at the same time.
- **Who may call whom.** Codex and Claude Code are the owner's two seats, each a session they
  opened deliberately with its own context and its own quota; neither may invoke the other on
  its own initiative, only when the owner asks for that agent in that conversation.
  `scripts/delegate.sh` refuses a peer target unless `--peer` says the owner asked.
- **Delegating mechanical work.** Write a packet under `docs/handoffs/` and run
  `scripts/delegate.sh <packet>`. It refuses any packet without an `**Acceptance:**` command,
  which is the whole routing rule: work no command can check does not leave the judgment
  tier. Read back the verdict, not the executor's transcript.
- **Judgment work stays with the owner.** Anything that changes `docs/decisions.md`, a
  claim's evidence level, or what the project says it has shown is judgment work whatever its
  size, and ends with the owner's approval.

## Decision discipline

- Record accepted decisions in `docs/decisions.md`: one dated entry each, code `D<n>`, and a
  row in its index table. A new decision adds its one-line meaning to `docs/glossary.md` in
  the same commit.
- Update `STATUS.md` whenever the current goal, the canonical artifact, the implementation
  state or a blocking question changes, and move its `**Updated:**` date forward.
- **The most-read files state only what holds now.** `STATUS.md`, `docs/agent_board.md`,
  this file and `docs/glossary.md` are read first by every session, so a superseded decision
  written there as if it held is read as the rule. When a decision supersedes another, the
  same commit removes the old wording from these files (frozen text goes to
  `docs/history/`) or marks it in the same clause ("replaced by D<n>").
  `python3 scripts/check_current_docs.py` checks this; the pre-commit hook runs it.
- Put unresolved items in `docs/open_questions.md`; do not fill gaps by guessing.

## Document discipline

- Every document opens with a three-line card under its title:

      > **What:** one sentence on what the file holds.
      > **Standing:** Current / Reference / Ledger / Index / History / Procedure, and what it defers to.
      > **How to read:** the cheapest way to read it ("read the index, then grep").

- `docs/README.md` lists every file and folder under `docs/`. Finished rounds of work move to
  `docs/history/<round>/` with a README naming each file.
- Entry files have size budgets (`scripts/check_doc_structure.py`). Every agent pays for
  every byte it opens; ledgers are never read whole — read the index, grep the heading.

## Daily log

- After substantive work, create or update today's entry under `docs/log/YYYY-MM-DD.md`
  (`python3 scripts/new_log.py`). Never overwrite an existing entry; add to it.
- Record only work actually completed, point to repository evidence, state any status change
  explicitly, and name one concrete next action.
- The log is not a substitute for `STATUS.md`, `docs/decisions.md` or `docs/open_questions.md`.
