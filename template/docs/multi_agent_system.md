# The multi-agent system

> **What:** Why Claude Code, Codex and a cheap executor share this repository the way they do, and how delegated work is routed.
> **Standing:** Reference. The rules themselves are in `AGENTS.md`; this file explains them.
> **How to read:** Read before changing a rule, or before delegating work.

`AGENTS.md` is the constitution, `docs/agent_board.md` is the operational board, this file
explains why they are shaped the way they are.

## The constraint everything follows from

Several agents are in use because **several quotas are in use**, not because several models
are better than one. Each has its own meter:

| Pool | Entry | Billing | What it is for |
|---|---|---|---|
| Claude subscription | `claude` | Subscription quota | Judgment, review, orchestration |
| ChatGPT subscription | Codex app, or `codex exec` | Subscription quota | Multi-file drafting and execution with repository awareness |
| A cheap API model (e.g. DeepSeek) | a headless harness | Per token, cheap | Bulk mechanical work |
| Local models | `codex exec --oss --local-provider ollama` | Free | Trivial text operations only |

A design that funnels every token through one agent defeats the purpose. The rule that
follows: **orchestration may live in one place, but execution tokens must land in the right
pool.**

When one pool becomes large enough to do everything (a bigger plan, say), the honest move is
to let it, and to keep delegation for when the owner asks. The rules below still say how to
split a task when delegation *is* asked for.

## Where the owner enters

**Judgment work: enter directly, no middle layer.** Anything that touches an evidence label,
a claim of novelty, or `docs/decisions.md` is work done with one agent, in conversation, and
it ends with the owner's approval. Adding a layer here only adds a place for the claim to
drift.

**Mechanical work: one entry, then delegation.** The owner talks to one agent. It writes a
handoff packet, runs `scripts/delegate.sh`, and reads back one line — PASS or FAIL — plus the
acceptance command's output and a diffstat. It never reads the executing agent's transcript;
that is where the saving would otherwise leak away.

    scripts/delegate.sh docs/handoffs/2026-01-15-link-fix.md

**Bulk repository work the owner wants to watch: enter that agent directly.** A long
multi-file session under the owner's eye does not need a middle layer either.

## Why the router is a rule, not a judgment call

"Let the AI decide which model to use" fails in exactly the wrong place. The choice is
itself a judgment, and its failure mode is silent: a routing mistake sends a judgment call
to the cheap tier, where nothing catches it. So routing is a deterministic gate:

> A packet carries a line `**Acceptance:** \`<command>\``. `scripts/delegate.sh` refuses any
> packet without one. If you cannot name the command that proves the work correct, the task
> is not mechanical, and it does not leave the judgment tier.

That is the whole router. It is auditable, it fails closed, and it cannot be talked out of.

## When delegation is worth it

Writing the packet costs the expensive agent tokens. Delegation pays only when execution is
much larger than specification. A usable threshold: **delegate when the packet is under about
1 KB and the work touches more than about 20 KB of files.** Index repair, batch renames, link
fixes and format conversion clear this easily. A two-line edit does not; do it yourself.

## The three files that make it work

| File | Role | Who writes it |
|---|---|---|
| `AGENTS.md` (= `CLAUDE.md`) | Constitution. Same rules for every agent | The owner |
| `docs/agent_board.md` | Claims, blocking questions, where to look | Whoever is working |
| `docs/handoffs/*.md` | One task's specification and acceptance command | The delegating agent |

The agents cannot talk to each other. Files are the only channel, so a claim that is not on
the board and a decision that is not in a packet do not exist.

## Isolation and attribution

- Each parallel agent works in its own worktree on `agent/<name>` (`scripts/agent_worktree.sh`).
  Two agents never work on `main` in the same directory.
- Every commit carries an `Agent:` trailer, enforced by `.githooks/commit-msg`, so a
  rollback can be attributed even though all agents share one git identity.
- The executor never commits: `delegate.sh` commits for it after the acceptance command
  passes, so the trailer is guaranteed rather than trusted.
- Merging any `agent/*` branch into `main` is the owner's call.

## Failure modes this design accepts

| Failure | What catches it |
|---|---|
| Two agents edit the same file | Worktrees; the claims table |
| One agent reverts another's conclusion | Append-only ledgers; the `Agent:` trailer makes it visible afterwards |
| A stale decision is read as the rule | `check_current_docs.py` on every commit that touches an entry file |
| A cheap agent produces plausible garbage | The acceptance command, run by `delegate.sh` |
| A cheap agent is handed a judgment task | The acceptance gate refuses the packet |
| One seat spends the other's quota | `delegate.sh` refuses a peer target without `--peer` |
| An overclaim in prose | **Nothing mechanical. The owner is the only check.** |
| Orchestration costs more than it saves | The 1 KB / 20 KB threshold above |

The last two are the real limits of this design.

## How work is routed

Routing by "which model is smartest" wastes money, because almost no task is uniformly hard.
Route by these three rules instead.

### Rule 1 — split the task before you route it

A typical task is roughly one part judgment and four parts mechanics. Adding a paper to a
literature library is *deciding what the paper shows versus what the project infers from it*
(judgment) plus *filling the card template, updating the index files and recomputing
checksums* (mechanics). Routing the whole task to one agent means paying the judgment price
for the mechanics, or the mechanics price for the judgment. Split it, then route each half.

The expensive half produces a **handoff packet** (`docs/handoffs/`) — a short spec with an
acceptance command. The cheap half executes it.

### Rule 2 — verifiability decides the tier

If a mechanical check can prove the output right, the check is what guarantees correctness,
not the model. Send it to the cheapest agent that can follow instructions. Every checker you
add under `scripts/` widens what can be delegated.

No checker exists for "does this sentence overstate the evidence". That class is Rule 3.

### Rule 3 — the silent-failure class never goes to the cheap tier

The dominant failure mode of agent work is not a crash, it is an overclaim that nobody
notices for weeks. Anything that touches an evidence label, a novelty statement, or
`docs/decisions.md` is judgment work at any size, and ends with the owner, not with an agent.

### The split, by task type (an example; adapt it)

| Task type | Judgment half | Mechanical half | Accepted when |
|---|---|---|---|
| New source in a library | What it shows vs. what we infer | Fill the template, sync indexes, checksums | The library checker passes |
| Experiment | The control and the decision criterion; what a null result means | Implement, run, store outputs and provenance | A reproduction script matches |
| Daily log | Whether the state or a blocker actually changed | Summarise the day's diff into bullets with paths | The owner reads it |
| Report / slides | Register, hedging, what may not be claimed | Generation script, layout, figures, translation | It renders; wording matches the approved draft |
| Repository hygiene | — | Moves, renames, link fixes, index repair | Checks pass |
| `STATUS.md`, `decisions.md`, `open_questions.md` | All of it | — | The owner approves |

### Calibrate this table instead of trusting it

The tiers above are a starting assumption, not measured fact, and model rankings move with
every release. When the routing is worth tuning, replay two or three past tasks with known
good commits on each agent and record which passed its checker and at what cost. Update
this table from the result.
