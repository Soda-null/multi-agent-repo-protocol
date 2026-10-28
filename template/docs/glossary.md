# Glossary

> **What:** One plain line per code name used in this repository: decisions, labels, abbreviations.
> **Standing:** Index. The full text of each decision is in `decisions.md`; this file only says what a code means and whether it still holds.
> **How to read:** Grep the code.

Agents invent short codes fast, and the owner forgets them just as fast. Every code that
appears in `STATUS.md`, `AGENTS.md` or the board needs a line here; `scripts/check_current_docs.py`
enforces it. A superseded code keeps its line and says so in the same line.

- **D1** — every agent follows `AGENTS.md`: signed commits, claims on the board, separate worktrees for parallel work. Live.
