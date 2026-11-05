#!/bin/sh
# Check that commits name their agent, by the same rule as the commit-msg hook.
# The hook only runs where it is enabled, and a fresh clone has it off, so the CI
# workflow .github/workflows/agent-trailers.yml runs this on every push and pull request.
#
#   scripts/check_agent_trailers.sh origin/main..HEAD
#   scripts/check_agent_trailers.sh -1 HEAD
#
# The arguments go straight to `git rev-list`. Exits 1 if any commit fails the rule.
set -eu

if [ $# -eq 0 ]; then
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
fi
cd "$(git rev-parse --show-toplevel)"
if [ ! -f .githooks/commit-msg ]; then
    echo "not found: .githooks/commit-msg (is the protocol installed here?)" >&2
    exit 2
fi

commits="$(git rev-list "$@")"
msg="$(mktemp)"
trap 'rm -f "$msg"' EXIT
checked=0; bad=0
for sha in $commits; do
    checked=$((checked + 1))
    git log -1 --format=%B "$sha" > "$msg"
    if ! sh .githooks/commit-msg "$msg" 2>/dev/null; then
        bad=$((bad + 1))
        echo "no valid Agent trailer: $(git log -1 --format='%h %s' "$sha")" >&2
    fi
done
echo "checked $checked commit(s); $bad without a valid Agent trailer"

if [ "$bad" -gt 0 ]; then
    cat >&2 <<MSG

Add the trailer with \`git commit --amend\` (or \`git rebase -i\` for older commits), then
turn the local check on so it cannot happen again: git config core.hooksPath .githooks
MSG
    exit 1
fi
