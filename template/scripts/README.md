# Scripts

> **What:** The tools that make the multi-agent protocol mechanical.
> **Standing:** Index. The rules they enforce are in `AGENTS.md`.
> **How to read:** Find the script you need below; each one's docstring says how to run it.

| Script | What it does | Who runs it |
|---|---|---|
| `agent_worktree.sh` | Gives one agent its own working tree on branch `agent/<name>` | An agent starting a parallel session |
| `delegate.sh` | Sends a handoff packet to an executor, runs the acceptance command, commits on PASS | The orchestrating agent, only when the owner asked for delegation |
| `check_current_docs.py` | The entry files cite no superseded decision; every cited decision has a glossary line; `STATUS.md` is not older than the newest decision | The pre-commit hook |
| `check_doc_structure.py` | Every document has a header card; indexes list every file; entry files stay within their size budget | The pre-commit hook |
| `worklog.py` | Hours per day, derived from commit times (a proxy, not a timesheet) | The closing agent, for the day's log |
| `new_log.py` | Creates today's log entry from the template; never overwrites | The closing agent |
| `repo_hygiene.py` | Weekly check-up: deletes only junk and merged branches, reports everything else | A scheduler, weekly |

Your project's own checkers go here too. A checker that a handoff packet can name as its
`**Acceptance:**` command is what makes a task delegable.
