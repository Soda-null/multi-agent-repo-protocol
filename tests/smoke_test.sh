#!/usr/bin/env bash
# End-to-end check: install the protocol into a throwaway repository and exercise every gate.
#
#   tests/smoke_test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
repo="$work/demo"
trap "rm -rf \"$work\"" EXIT; [ -n "${KEEP:-}" ] && { trap - EXIT; echo "keeping $work"; }
fails=0
. "$here/template/scripts/find_python.sh"   # python3 may be called python on Windows

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }
expect_ok()   {
    local out
    if out="$("${@:2}" 2>&1)"; then pass "$1"; else fail "$1"; printf '%s\n' "$out" | tail -5 | sed 's/^/      /'; fi
}
expect_fail() { if "${@:2}" >/dev/null 2>&1; then fail "$1"; else pass "$1"; fi; }

mkdir -p "$repo" && cd "$repo"
git init -q -b main
git config user.email demo@example.com
git config user.name demo

expect_ok   "install.sh copies the template"            "$here/install.sh" "$repo"
claude_md_points_at_agents() {
    if [ -L CLAUDE.md ]; then [ "$(readlink CLAUDE.md)" = AGENTS.md ]; else [ "$(cat CLAUDE.md)" = "@AGENTS.md" ]; fi
}
expect_ok   "CLAUDE.md points at AGENTS.md"              claude_md_points_at_agents
expect_ok   "hooks are enabled"                         test "$(git config core.hooksPath)" = .githooks
expect_ok   "second install overwrites nothing"         "$here/install.sh" "$repo"
expect_ok   "check_current_docs passes on the template" python3 scripts/check_current_docs.py
expect_ok   "check_doc_structure passes on the template" python3 scripts/check_doc_structure.py

git add -A
expect_fail "commit without an Agent trailer is rejected" git commit -q -m "first"
expect_ok   "commit with an Agent trailer is accepted"    git commit -q -m "Adopt the protocol" -m "Agent: human"
expect_fail "unknown agent name is rejected" \
    git commit -q --allow-empty -m "x" -m "Agent: someone-else"

# A superseded decision cited in an entry file without saying so must block the commit.
cat >> docs/decisions.md <<'EOF'

### D2 — Replace D1 (2026-01-02)

**Status:** accepted by the owner. Supersedes D1.
EOF
sed -i.bak 's/^| 2026-01-01 | D1 | Adopt the multi-agent protocol | live |$/| 2026-01-01 | D1 | Adopt the multi-agent protocol | superseded by D2 |\
| 2026-01-02 | D2 | Replace D1 | live |/' docs/decisions.md && rm docs/decisions.md.bak
expect_fail "stale decision in STATUS.md is caught" python3 scripts/check_current_docs.py
sed -i.bak 's/^- D1 — every agent/- D1 (replaced by D2) — every agent/; s/(D1)\./(D1, replaced by D2)./; s/^\*\*Updated:\*\* .*/**Updated:** 2026-01-02/' STATUS.md && rm STATUS.md.bak
sed -i.bak 's/Live\.$/Superseded by D2./' docs/glossary.md && rm docs/glossary.md.bak
echo "- **D2** — replaces D1. Live." >> docs/glossary.md
expect_ok   "marked as replaced, it passes"              python3 scripts/check_current_docs.py
sed -i.bak 's/^\*\*Updated:\*\* .*/**Updated:** 2026-01-01/' STATUS.md && rm STATUS.md.bak
expect_fail "STATUS.md older than the newest decision is caught" python3 scripts/check_current_docs.py
sed -i.bak 's/^\*\*Updated:\*\* .*/**Updated:** 2026-01-02/' STATUS.md && rm STATUS.md.bak

# Document structure.
printf '# Notes\n\nno card here\n' > docs/notes.md
expect_fail "a doc without a header card is caught"       python3 scripts/check_doc_structure.py
printf '# Notes\n\n> **What:** notes.\n> **Standing:** Reference.\n> **How to read:** any way.\n' > docs/notes.md
expect_fail "a doc missing from docs/README.md is caught" python3 scripts/check_doc_structure.py
echo '| `notes.md` | Reference | Notes |' >> docs/README.md
expect_ok   "listed and carded, it passes"                python3 scripts/check_doc_structure.py
git add -A && git commit -q -m "Supersede D1" -m "Agent: human"

# Delegation gates (dry runs: no executor is called).
printf '# Fix links\n\nno acceptance line\n' > docs/handoffs/2026-01-03-bad.md
printf '# Fix links\n\n**Acceptance:** `python3 scripts/check_doc_structure.py`\n' > docs/handoffs/2026-01-03-good.md
expect_fail "packet without an acceptance command is refused" \
    scripts/delegate.sh docs/handoffs/2026-01-03-bad.md --dry-run
expect_fail "peer target without --peer is refused" \
    scripts/delegate.sh docs/handoffs/2026-01-03-good.md --to codex --dry-run
expect_ok   "peer target with --peer passes the gate" \
    scripts/delegate.sh docs/handoffs/2026-01-03-good.md --to codex --peer --dry-run
expect_ok   "a good packet passes the gate" \
    scripts/delegate.sh docs/handoffs/2026-01-03-good.md --dry-run

# A full delegation round with a fake executor that edits one file.
git add -A && git commit -q -m "Add packets" -m "Agent: human"
printf '#!/bin/sh\necho done >> docs/log/README.md\n' > "$work/fake_executor.sh"
chmod +x "$work/fake_executor.sh"
export DEEPSEEK_CMD="$work/fake_executor.sh"
expect_ok   "fake executor: acceptance runs and delegate.sh commits" \
    scripts/delegate.sh docs/handoffs/2026-01-03-good.md
unset DEEPSEEK_CMD
expect_ok   "the delegated commit carries Agent: deepseek" \
    sh -c "git -C '$work/demo-deepseek' log -1 --format=%B | grep -qx 'Agent: deepseek'"

# Worktrees, logs, check-up, preflight.
expect_ok   "agent_worktree.sh makes a separate tree"   scripts/agent_worktree.sh codex
expect_ok   "the tree is on agent/codex" \
    test "$(git -C "$work/demo-codex" branch --show-current)" = agent/codex
expect_ok   "new_log.py creates today's entry"          python3 scripts/new_log.py
expect_fail "new_log.py refuses to overwrite"           python3 scripts/new_log.py
expect_ok   "worklog.py --today runs"                   python3 scripts/worklog.py --today
expect_ok   "repo_hygiene.py runs"                      python3 scripts/repo_hygiene.py
expect_ok   "preflight runs" python3 .claude/skills/close-session/scripts/preflight.py

# Each agent commits only on its own branch, so a clash becomes a merge conflict.
expect_fail "an agent cannot commit on main" \
    git commit -q --allow-empty -m "x" -m "Agent: codex"
expect_ok   "the human can commit on main" \
    git commit -q --allow-empty -m "x" -m "Agent: human"
codex="$work/demo-codex"
expect_ok   "an agent can commit on its own branch" \
    git -C "$codex" commit -q --allow-empty -m "x" -m "Agent: codex"
expect_fail "an agent cannot commit on another agent's branch" \
    git -C "$codex" commit -q --allow-empty -m "x" -m "Agent: claude-code"
expect_ok   "agent_worktree.sh takes a second session of an agent" scripts/agent_worktree.sh codex-2
expect_ok   "an agent can commit on its second-session branch" \
    git -C "$work/demo-codex-2" commit -q --allow-empty -m "x" -m "Agent: codex"
expect_fail "agent_worktree.sh refuses an unknown name" scripts/agent_worktree.sh stranger
expect_fail "agent_worktree.sh refuses the human" scripts/agent_worktree.sh human
expect_ok   "from inside a worktree, a new tree still sits beside the main checkout" \
    sh -c "cd '$codex' && scripts/agent_worktree.sh claude-code && test -d '$work/demo-claude-code'"
detached() { git -C "$codex" switch -q --detach && git -C "$codex" commit -q --allow-empty -m "x" -m "Agent: codex"; }
expect_fail "an agent cannot commit on a detached HEAD" detached
git -C "$codex" switch -q agent/codex
rebase_edit() {
    ( cd "$codex" &&
      GIT_SEQUENCE_EDITOR='sed -i.bak s/^pick/edit/' git rebase -i --keep-empty HEAD~1 &&
      git commit -q --amend --allow-empty -m "x amended" -m "Agent: codex" &&
      git rebase --continue )
}
expect_ok   "an amend during a rebase is allowed" rebase_edit
sed -i.bak 's/^REQUIRE_AGENT_BRANCH=1$/REQUIRE_AGENT_BRANCH=0/' .githooks/commit-msg && rm .githooks/commit-msg.bak
expect_ok   "with the switch off, an agent can commit on main" \
    git commit -q --allow-empty -m "x" -m "Agent: codex"
git checkout -q -- .githooks/commit-msg
sed -i.bak 's/^AGENTS_ALLOWED="/AGENTS_ALLOWED="gemini|/' .githooks/commit-msg && rm .githooks/commit-msg.bak
expect_ok   "agent_worktree.sh follows the names in the hook" scripts/agent_worktree.sh gemini
git checkout -q -- .githooks/commit-msg
echo 'moved' > moved.txt && git add moved.txt
expect_ok   "the copy command in the rejection message works" \
    sh -c "git diff --cached --binary | git -C '$codex' apply --index && test -f '$codex/moved.txt'"
git restore --staged moved.txt && rm moved.txt
git -C "$codex" commit -q -m "Add moved" -m "Agent: codex"
list_shows_changes() { local out; out="$(scripts/agent_worktree.sh --list)" && printf '%s\n' "$out" | grep -q 'moved.txt'; }
expect_ok   "--list shows what an agent has changed"     list_shows_changes
# Both agents add a row to the board; the merge keeps both.
add_row() {
    awk -v row="| $1 | $1 | src/ | 2026-01-05 |" '{ print } /^\|---\|---\|---\|---\|$/ && !done { print row; done = 1 }' \
        "$2/docs/agent_board.md" > "$2/board.tmp" && mv "$2/board.tmp" "$2/docs/agent_board.md"
}
add_row one "$codex"; git -C "$codex" add docs/agent_board.md; git -C "$codex" commit -q -m "Claim" -m "Agent: codex"
add_row two "$work/demo-claude-code"; git -C "$work/demo-claude-code" add docs/agent_board.md
git -C "$work/demo-claude-code" commit -q -m "Claim" -m "Agent: claude-code"
merge_both() { git merge -q --no-ff --no-edit agent/codex && git merge -q --no-ff --no-edit agent/claude-code; }
expect_ok   "two claims on the board merge without a conflict" merge_both
expect_ok   "the merged board keeps both claims" \
    sh -c "grep -q '^| one |' docs/agent_board.md && grep -q '^| two |' docs/agent_board.md"

# A fresh clone has no hooks: an unsigned commit gets through locally, and the CI check sees it.
expect_ok   "the install adds the CI workflow"          test -f .github/workflows/agent-trailers.yml
git clone -q "$repo" "$work/fresh"
cd "$work/fresh"
git config user.email demo@example.com
git config user.name demo
expect_ok   "a fresh clone has the hooks off"           test -z "$(git config core.hooksPath)"
git commit -q --allow-empty -m "Signed work" -m "Agent: codex"
expect_ok   "the CI check accepts a signed commit"      scripts/check_agent_trailers.sh -1 HEAD
git commit -q --allow-empty -m "Unsigned work from a fresh clone"
expect_fail "the CI check catches an unsigned commit"   scripts/check_agent_trailers.sh HEAD~2..HEAD
git commit -q --amend --allow-empty -m "Now it names someone" -m "Agent: someone-else"
expect_fail "the CI check catches an unknown agent"     scripts/check_agent_trailers.sh -1 HEAD
git commit -q --amend --allow-empty -m "Now it is signed" -m "Agent: codex"
expect_ok   "after signing, the range passes"           scripts/check_agent_trailers.sh HEAD~2..HEAD
expect_fail "a bad range is an error, not a pass"       scripts/check_agent_trailers.sh no-such-ref..HEAD
cd "$repo"

echo
if [ "$fails" = 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
[ "$fails" = 0 ]
