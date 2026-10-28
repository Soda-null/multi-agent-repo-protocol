# Why each rule exists

Every rule in `AGENTS.md` was added after something went wrong, in the research repository
this protocol was extracted from (one human, three agents, about two months in 2026). The
numbers below are from that repository's history.

## Files are the only channel

The agents never talk to each other. A claim that is not on the board, a decision that is
not in the ledger, a task that is not in a packet — none of them exist for the next agent.
That is why the board, the ledger and the handoff packets are files with fixed shapes, and
not habits.

## Uncommitted changes belong to someone else

The most common damage was not a bad edit but a *tidy* one: an agent starting a session saw
unfamiliar uncommitted files, assumed they were leftovers, and reverted or stashed them. They
were another agent's half-finished session. Hence: never touch what you did not write, stage
your own paths by name, and end every session with your work committed.

## The `Agent:` trailer

All agents commit under the human's one git identity. Without the trailer, the history cannot
answer "who reverted this?". The hook makes the trailer non-optional. When delegated work is
committed, `delegate.sh` writes the trailer itself, so it is guaranteed rather than trusted.

## Peers do not call peers

Codex and Claude Code each run on a subscription the human opened deliberately, with its own
context. An agent that calls the other on its own initiative spends the other's quota and
splits the human's attention across a session they did not open. `delegate.sh` refuses a peer
target unless `--peer` records that the human asked.

## The acceptance gate is the whole router

"Let the AI decide which model to use" fails silently: the routing choice is itself a
judgment, and a wrong one sends a judgment task to the cheap tier, where nothing catches it.
A packet that names a command proving it correct is mechanical; anything else is not. The
gate is auditable, fails closed, and cannot be argued with.

Further gates can be added the same way. The origin repository later added a second one: a
packet that implements an algorithm spec must carry a passing mechanical pre-flight report,
after a spec sent out without one was found, in its first review round, to contain three
fatal mechanical errors.

## Delegation became on-request

When the human moved to a larger Claude plan, Claude Code did almost all the work itself: in
one week, 114 commits by `claude-code`, 3 by `deepseek`, 0 by `codex`. The rules were then
rewritten to match practice: delegation happens only when the human asks for it. The routing
rules stayed, as the way to split a task *when* delegation is asked for. A protocol that
describes what agents no longer do is read as an instruction to do it.

## Short commit first lines

`git log --oneline` is read at the start of every session. At one point the last 60 first
lines averaged 300 characters, and reading fifteen of them cost about 2,500 tokens — every
session, every agent. The hook now warns above 100 characters; the narrative goes in the body.

## One place for the current state

The current state was once written in three places (status file, board, constitution). They
drifted apart within days, and agents followed whichever copy they read first. Now `STATUS.md`
holds the state and the others link to it.

## The most-read files state only what holds now

A superseded decision left in an entry file as if it still held was read as the rule by the
next session. `check_current_docs.py` reads the decision index, works out which codes are no
longer live, and blocks a commit that cites one of them in an entry file without saying so in
the same clause.

## A glossary line for every code

Agents coin short codes (decision numbers, labels) quickly, and the human forgets them just as
quickly. Reports full of codes became unreadable to the person they were written for. Every
code cited in an entry file now needs a one-line plain meaning in `docs/glossary.md`.

## Header cards and size budgets

Every agent pays for every byte it opens, at the start of every session. Each document now
says in three lines what it is, whether it still counts, and the cheapest way to read it;
ledgers are read by index and grep, never whole; entry files have byte budgets.

## Numbers live in one place

While extracting this protocol, the size budget of one file was found written in two scripts
with two different values (30 KB and 40 KB): one had been raised, the other forgotten. The
check-up script now imports the budget from the checker instead of repeating it.

## A worktree with nothing to link

Also found while extracting: in a fresh repository with no ignored files, an empty `grep` in
`agent_worktree.sh` ended the script early under `set -o pipefail`. The origin repository
always had ignored files, so it never showed. The smoke test now covers a fresh repository.
