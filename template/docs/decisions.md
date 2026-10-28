# Decisions

> **What:** Every accepted decision, one dated entry each, with an index table at the top.
> **Standing:** Ledger (append-only); the authoritative record of what was decided.
> **How to read:** Never read whole once it grows. Read the index, look up a code in `glossary.md`, then grep the entry heading.

Revise a decision by adding a superseding entry, never by rewriting an old one. Only the
owner deletes an entry.

## Index

One row per entry. **Standing** is *live* when nothing later supersedes it, or starts with
*superseded by Dn* / *historical* / *closed* / *withdrawn* when it no longer holds.
`scripts/check_current_docs.py` reads this table.

| Date | D | Entry | Standing |
|---|---|---|---|
| 2026-01-01 | D1 | Adopt the multi-agent protocol | live |

## Entries

### D1 — Adopt the multi-agent protocol (2026-01-01)

**Status:** accepted by the owner.

Every agent working here follows `AGENTS.md`. Commits carry an `Agent:` trailer, parallel
sessions use separate worktrees, and delegated work needs an acceptance command.

<!-- Entry template:

### Dn — <title> (YYYY-MM-DD)

**Status:** accepted by the owner. [Supersedes Dm.]

What was decided, in one paragraph. Then why, and what evidence it rests on.
-->
