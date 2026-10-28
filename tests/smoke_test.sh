#!/usr/bin/env bash
# End-to-end check: install the protocol into a throwaway repository and exercise every gate.
#
#   tests/smoke_test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
repo="$work/demo"
trap "rm -rf \"$work\"" EXIT; [ -n "${KEEP:-}" ] && trap - EXIT
fails=0

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }
expect_ok()   { if "${@:2}" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }
expect_fail() { if "${@:2}" >/dev/null 2>&1; then fail "$1"; else pass "$1"; fi; }

mkdir -p "$repo" && cd "$repo"
git init -q -b main
git config user.email demo@example.com
git config user.name demo

expect_ok   "install.sh copies the template"            "$here/install.sh" "$repo"
expect_ok   "CLAUDE.md is a symlink to AGENTS.md"        test "$(readlink CLAUDE.md)" = AGENTS.md
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
git add -A && git commit -q -m "Supersede D1" -m "Agent: claude-code"

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
git add -A && git commit -q -m "Add packets" -m "Agent: claude-code"
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

echo
if [ "$fails" = 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
[ "$fails" = 0 ]
