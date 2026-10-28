# Handoff packets

> **What:** The template for packets that hand mechanical work from one agent to another.
> **Standing:** Procedure; used only when the owner asks for delegation.
> **How to read:** Read before writing a packet.

The agents working in this repository cannot talk to each other. When one specifies work for
another — typically a judgment-tier agent specifying mechanical work for a cheaper one — the
specification goes in a file here, named `YYYY-MM-DD-<slug>.md`, and runs through
`scripts/delegate.sh`.

Delete a packet once the work is committed and accepted; the commit is the record.

**A packet without an acceptance command is not a packet.** If you cannot name the command
that proves the work correct, the task is not mechanical, and it must not leave the judgment
tier. See Rule 3 in `docs/multi_agent_system.md`.

## Template

```markdown
# <what this produces — becomes the first line of the commit>

**From:** claude-code   **To:** deepseek   **Date:** YYYY-MM-DD

## Goal
One sentence. What exists at the end that does not exist now.

## Inputs
Exact paths. Say which lines or sections matter, so the executing agent does not read a
whole 90 KB document.

## Steps
Numbered, mechanical, no judgment left in them. If a step needs a decision about evidence,
provenance or wording strength, it belongs in this packet as an already-made decision, not
as a step.

## Do not touch
Paths this task must not modify. Name the owner's canonical files explicitly whenever they
are near the work.

## Already decided (do not re-litigate)
The judgment calls this packet rests on, stated flatly.

## Acceptance
One line, exactly in this form — `scripts/delegate.sh` greps for it and refuses a packet
without it. Say below the line what its output should say.

**Acceptance:** `python3 scripts/check_doc_structure.py`

It runs against the working tree, before any commit exists, so it must not refer to
`git log` or to the commit. The executing agent does not commit at all — `delegate.sh`
commits for it once this command passes, which is also what guarantees the `Agent:` trailer.
```
