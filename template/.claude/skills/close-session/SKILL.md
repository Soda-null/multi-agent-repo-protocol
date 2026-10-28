---
name: close-session
description: "End-of-session close-out for a repository shared by several AI agents: commit this session's work with the Agent trailer, write or update today's log, paste the worklog line, release the board claim, and leave nothing of ours uncommitted. Use this whenever the user says wrap up, commit everything, close the session, we're done for today, write the log — and on your own initiative before you stop after a long stretch of repository work."
---

# Session close-out

## Why this list exists

Several agents share this checkout and one git identity. The protocol (`AGENTS.md`) therefore
treats an uncommitted change as *the next agent's problem*: it is what gets reverted, stashed
or built on by mistake. Three other things depend on closing properly:

- the daily log is the only record of what was actually done (`STATUS.md`, `decisions.md`
  and `open_questions.md` are for state, not narrative);
- the worklog line is derived from commit times, so it is only right if it is generated after
  the substantive commit;
- the `commit-msg` hook rejects any commit without an `Agent:` trailer.

Work through the steps in order; each is short.

## Step 0 — run the preflight

```bash
python3 .claude/skills/close-session/scripts/preflight.py --agent claude-code
```

It is read-only. It prints `[ok]` / `[todo]` / `[info]` lines: hook configuration, branch,
every dirty path, whether today's log exists and has its worklog line, which board claims
belong to this agent, and the worklog line as of now. Treat `[todo]` lines as the remaining
work; re-run it at the end.

## Step 1 — sort the dirty tree into ours and theirs

`git status --short` lists everything. Decide, path by path, what this session touched. The
rest belongs to another agent's unfinished session (compare with the status you saw when the
session started).

- Stage our paths explicitly (`git add path1 path2`). Never `git add -A` / `git add .`.
- Never revert, stash, checkout over or tidy a file we did not touch. If one of them blocks
  our commit, say so in the report and leave it.
- A tree that is dirty only with other agents' files is an acceptable end state; say which.

## Step 2 — canonical files, only if their contents truly changed

Did the current goal, canonical artifact, implementation state or a blocking question change
(→ `STATUS.md`, and move its `**Updated:**` date)? Did the owner accept a decision
(→ `docs/decisions.md`, a new dated entry, its index row and its glossary line)? Did
something stay unresolved (→ `docs/open_questions.md`)? Entries written by others are
append-only. If nothing changed, touch none of them.

## Step 3 — run the checks the change makes relevant

Run the project's checkers for what changed, so a hook failure is not a surprise at commit
time. Never bypass a hook with `--no-verify`; fix what it reports.

## Step 4 — commit the substantive work

First line under 100 characters: what changed. Numbers and narrative in the body. Then the
trailer on its own line:

```
<what changed>

<why, key numbers, the owner's words if it was their request>

Agent: claude-code
```

If `git config core.hooksPath` is not `.githooks`, set it before committing.

## Step 5 — today's log

If today's entry does not exist, `python3 scripts/new_log.py`. If it exists, edit it in place
and keep every earlier bullet. Fill it from the template: only finished work, each item
pointing at a file or commit; the evidence; status changes (say "none" when true); then run
`python3 scripts/worklog.py --today` **after the substantive commit** and paste its line; one
concrete next action. Do not create a log for a session with no substantive work.

## Step 6 — the board

In `docs/agent_board.md`, delete the claim row for the task this session finished. Keep a row
only for work that genuinely continues into a later session, and say so in the report.

## Step 7 — the closing commit

Stage the log, the board and any canonical-file edits and commit them with the same trailer.
Re-run the preflight: it should show no `[todo]` for our paths. On an `agent/*` branch, commit
there and do not merge; merging into `main` is the owner's call.

## Step 8 — report to the owner

Short and plain: what was committed (short hash and one line each), the worklog line, which
uncommitted files were left alone because they belong to another agent, and the one next
action.
