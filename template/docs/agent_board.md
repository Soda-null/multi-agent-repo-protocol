# Agent board

> **What:** The entry point of every session: task claims, blocking questions, where to look, known issues.
> **Standing:** Current (operational). The project state is in `STATUS.md`, not here.
> **How to read:** Read all of it; it is short. Keep it under 8 KB.

Read this first; open the large documents only when your task needs them. Rules live in
`AGENTS.md`.

## Current main line

One place for the current state: [`STATUS.md`](../STATUS.md). This board does not repeat it,
because two copies drift apart.

## Blocking questions — only the owner can close these

- Nothing blocks an agent session today.

## Claims — edit this table in the same commit as your first change

| Task | Agent | Paths it owns | Since |
|---|---|---|---|

Release a claim by deleting the row when the work is committed. If a task you want is
claimed, pick another one or ask the owner. Never edit a path another agent owns.

## Where to look

| You need | Open | How |
|---|---|---|
| what holds now, what waits, what is next | `STATUS.md` | read §1, then the section you need |
| what a decision code means | `docs/glossary.md` | one line per code |
| a decision's full text | `docs/decisions.md` | read the index, grep the heading; never read whole |
| an open question | `docs/open_questions.md` | read the index, grep the section |
| why the agents share the repository this way | `docs/multi_agent_system.md` | only before delegating |
| what a file under `docs/` is | `docs/README.md` | the index labels each file |

## Known issues — still true

- None.
