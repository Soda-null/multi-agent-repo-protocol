#!/usr/bin/env bash
# Hand a mechanical task to a cheaper agent and bring back only the verdict.
#
#   scripts/delegate.sh docs/handoffs/2026-01-15-link-fix.md       # -> deepseek
#   scripts/delegate.sh <packet> --to local                        # -> a local model, free
#   scripts/delegate.sh <packet> --to codex --peer                 # only if the owner asked
#   scripts/delegate.sh <packet> --dry-run
#
# The expensive agent writes the packet, runs this, and reads back one line --
# PASS or FAIL -- plus the acceptance command's own output and a diffstat. It must
# not read the cheap agent's transcript; that is where the savings go.
# See docs/multi_agent_system.md.
set -euo pipefail

packet=""; to="deepseek"; dry=0; peer=0
base_branch="${BASE_BRANCH:-main}"
while [ $# -gt 0 ]; do
    case "$1" in
        --to) to="${2:?--to needs a value}"; shift 2 ;;
        --dry-run) dry=1; shift ;;
        --peer) peer=1; shift ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 2 ;;
        *) packet="$1"; shift ;;
    esac
done

case "$to" in codex|claude-code|deepseek|local) ;; *) echo "unknown target: $to" >&2; exit 2 ;; esac

# Codex and Claude Code are the owner's own two seats: each is a session they opened
# deliberately, with its own context and its own quota. One seat must not spend the other's
# quota on its own initiative. A pay-per-token executor has neither property.
if [ "$peer" = 0 ] && { [ "$to" = codex ] || [ "$to" = claude-code ]; }; then
    cat >&2 <<MSG
refusing to delegate to $to.

$to is a peer agent, not an executor. Delegate mechanical work to the executor:

    scripts/delegate.sh $packet --to deepseek

Only when the owner has asked for $to specifically in this conversation, pass
--peer to say so. See "Who may call whom" in AGENTS.md.
MSG
    exit 2
fi
[ -n "$packet" ] && [ -f "$packet" ] || {
    echo "usage: scripts/delegate.sh <packet.md> [--to codex|claude-code|deepseek|local] [--peer] [--dry-run]" >&2
    exit 2
}

root=$(git rev-parse --show-toplevel)
. "$root/scripts/find_python.sh"   # acceptance lines say `python3`; this makes that work on Windows

# The gate. A task whose correctness no command can check is not mechanical.
accept=$(grep -m1 '^\*\*Acceptance:\*\*' "$packet" | sed -n 's/.*`\(.*\)`.*/\1/p' || true)
if [ -z "$accept" ]; then
    cat >&2 <<'MSG'
packet rejected: no acceptance command.

Add one line to the packet, exactly in this form:

    **Acceptance:** `python3 scripts/check_doc_structure.py`

If you cannot name a command that proves the work correct, the task is not
mechanical and must not leave the judgment tier. See docs/multi_agent_system.md, Rule 3.
MSG
    exit 2
fi

dir="$(dirname "$root")/$(basename "$root")-$to"
prompt="$(cat "$packet")

---
Repository rules are in AGENTS.md; read it first. Work only inside this worktree.
Do not modify anything listed under \"Do not touch\". Do not re-decide anything
listed under \"Already decided\". Leave your changes in the working tree and do
NOT run git add, git commit, git checkout, git stash or git push: the delegation
script checks your work and commits it for you with the right trailer."

if [ "$dry" = 1 ]; then
    printf 'target      %s\nworktree    %s\nacceptance  %s\nprompt      %s bytes\n' \
        "$to" "$dir" "$accept" "${#prompt}"
    exit 0
fi

"$root/scripts/agent_worktree.sh" "$to" >/dev/null
# The executor must start from the current base branch: the packet names files and checkers
# that live there. Accepted work is cherry-picked into the base branch by the orchestrating
# agent, so the agent branch is disposable -- reset it when the tree is clean; refuse to run
# over dirty work.
if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "refusing: $dir has uncommitted changes (another packet's leftovers?); inspect or clean it first" >&2
    exit 2
fi
git -C "$dir" reset -q --hard "$base_branch"

logdir="${TMPDIR:-/tmp}/delegate-$(basename "$root")"; mkdir -p "$logdir"
log="$logdir/$(basename "${packet%.md}")-$to.txt"

# An executor that cannot run at all -- an exhausted quota, a stale binary, a missing
# key -- must report why, not die silently under set -e.
# Every launcher can be overridden by an environment variable; the prompt is passed on
# stdin (codex, local) or as the final argument (claude-code, deepseek).
set +e
case "$to" in
    codex)
        printf '%s' "$prompt" | ${CODEX_BIN:-codex} exec -C "$dir" -s workspace-write - \
            >"$log" 2>&1
        ;;
    local)
        printf '%s' "$prompt" | ${CODEX_BIN:-codex} exec --oss --local-provider ollama \
            -m "${LOCAL_MODEL:-qwen3:4b}" -C "$dir" -s workspace-write - >"$log" 2>&1
        ;;
    claude-code)
        # shellcheck disable=SC2086
        ( cd "$dir" && ${CLAUDE_CMD:-claude -p --permission-mode acceptEdits} "$prompt" ) \
            >"$log" 2>&1
        ;;
    deepseek)
        # Any headless executor that takes a prompt and edits files works here. The default
        # is the DeepSeek Harness headless profile; its API key lives in its own config,
        # never in this repository.
        # shellcheck disable=SC2086
        ( cd "$dir" && ${DEEPSEEK_CMD:-npx -y @deepseek-ai/dsh --profile headless} "$prompt" ) \
            >"$log" 2>&1
        ;;
esac
exec_rc=$?
set -e
if [ "$exec_rc" != 0 ]; then
    echo "--- $to exited $exec_rc without finishing ---"
    grep -iE 'error|usage limit|quota|unauthor' "$log" | sort -u | tail -3 | sed 's/^/  /'
fi

echo "--- $to on agent/$to ---"
git -C "$dir" --no-pager diff --stat | tail -20
git -C "$dir" status --porcelain | grep '^??' | sed 's/^?? /new: /' || true
echo "--- acceptance: $accept ---"
if ( cd "$dir" && eval "$accept" ) 2>&1 | tail -15; then verdict=PASS; else verdict=FAIL; fi

# The commit is made here, not by the executor: the trailer is then guaranteed rather
# than trusted, and the executor never needs write access to the git directory.
if [ "$verdict" = PASS ] && [ -n "$(git -C "$dir" status --porcelain)" ]; then
    git -C "$dir" add -A
    git -C "$dir" commit -q -F - <<COMMIT
$(head -1 "$packet" | sed 's/^# *//')

Delegated as $(basename "$packet"). Acceptance passed:

    $accept

Agent: $to
COMMIT
    echo "committed: $(git -C "$dir" log --oneline -1)"
fi

echo "$verdict"
echo "(transcript for the owner, not for the orchestrating agent: $log)"
[ "$verdict" = PASS ]
