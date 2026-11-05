#!/usr/bin/env bash
# Give one agent its own working tree on its own branch, so agents cannot overwrite
# each other. The commit-msg hook only lets an agent commit there.
# See AGENTS.md, "Multi-agent collaboration protocol".
#
#   scripts/agent_worktree.sh codex
#   scripts/agent_worktree.sh claude-code-2     # a second session of the same agent
#   scripts/agent_worktree.sh --list            # what each agent is changing right now
#   scripts/agent_worktree.sh --remove codex
#
# Agent names come from AGENTS_ALLOWED in .githooks/commit-msg.
set -euo pipefail

# The main checkout, even when this runs inside an agent's own worktree.
root=$(cd "$(git rev-parse --git-common-dir)/.." && pwd)
base_branch="${BASE_BRANCH:-main}"
parent=$(dirname "$root")
base=$(basename "$root")

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

case "${1:-}" in
    ""|-h|--help) usage 0 ;;
    --list)
        git -C "$root" worktree list
        for branch in $(git -C "$root" for-each-ref --format='%(refname:short)' refs/heads/agent/); do
            echo
            echo "$branch, not yet in $base_branch:"
            git -C "$root" diff --name-only "$base_branch...$branch" | sed 's/^/  /'
            tree="$parent/$base-${branch#agent/}"
            [ -d "$tree" ] || continue
            echo "$branch, uncommitted:"
            git -C "$tree" status --porcelain | sed 's/^/  /'
        done
        exit 0
        ;;
    --remove)
        agent="${2:?usage: --remove <agent>}"
        git -C "$root" worktree remove "$parent/$base-$agent"
        echo "removed $parent/$base-$agent (branch agent/$agent kept)"
        exit 0
        ;;
    -*) echo "unknown option: $1" >&2; usage ;;
esac

# One list of names, in the hook; `human` works in the main checkout.
allowed=$(sed -n 's/^AGENTS_ALLOWED="\(.*\)"$/\1/p' "$root/.githooks/commit-msg")
agent="$1"
if [ "$agent" = human ] || ! printf '%s\n' "$agent" | grep -Eq "^($allowed)(-[A-Za-z0-9._]+)?\$"; then
    echo "unknown agent: $agent (names come from AGENTS_ALLOWED in .githooks/commit-msg)" >&2
    usage
fi

dir="$parent/$base-$agent"
branch="agent/$agent"

# On Windows (Git Bash) `ln -s` silently copies unless told to make real links. Copying a
# dataset would be slow and huge, so ask for native links and skip a path that cannot be
# linked (native links need Windows Developer Mode, or an administrator shell).
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export MSYS=winsymlinks:nativestrict ;; esac
link() {
    ln -s "$1" "$2" 2>/dev/null ||
        echo "warning: could not link ${2#"$dir"/}; on Windows, turn on Developer Mode to allow symlinks" >&2
}

# A worktree carries only tracked files. Data a project keeps untracked on purpose
# (datasets, PDFs, a virtualenv) would be missing, and checkers then report nothing
# rather than failing loudly -- so link it in. The paths are already ignored by
# .gitignore, so the links never show up as changes.
link_untracked_data() {
    git -C "$root" ls-files -o -i --exclude-standard --directory |
        { grep -vE '(^|/)(\.DS_Store|__pycache__/?|\.git/)' || true; } |
        while IFS= read -r rel; do
            rel="${rel%/}"
            [ -e "$root/$rel" ] || continue
            if [ -e "$dir/$rel" ] || [ -L "$dir/$rel" ]; then continue; fi
            mkdir -p "$(dirname "$dir/$rel")"
            if [ -d "$root/$rel" ] && [ ! -L "$root/$rel" ]; then
                link_dir_contents "$rel"
            else
                link "$root/$rel" "$dir/$rel"
            fi
        done
}

# A .gitignore pattern ending in "/" matches a directory but not a symlink to one, so make
# the directory real and link what is inside it. Otherwise every linked dataset shows up as
# an untracked change forever.
link_dir_contents() {
    local rel="$1" child name
    mkdir -p "$dir/$rel"
    for child in "$root/$rel"/* "$root/$rel"/.[!.]*; do
        [ -e "$child" ] || continue
        name=$(basename "$child")
        [ -e "$dir/$rel/$name" ] || [ -L "$dir/$rel/$name" ] || link "$child" "$dir/$rel/$name"
        if [ -L "$dir/$rel/$name" ] && [ -d "$child" ] && [ ! -L "$child" ] &&
            [ -n "$(git -C "$dir" status --porcelain -- "$rel/$name")" ]; then
            rm "$dir/$rel/$name"
            link_dir_contents "$rel/$name"
        fi
    done
}

if [ -d "$dir" ]; then
    echo "already exists: $dir (branch $(git -C "$dir" branch --show-current))"
    echo "to pick up the latest $base_branch, run there: git merge $base_branch"
    link_untracked_data
else
    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$root" worktree add "$dir" "$branch"
    else
        git -C "$root" worktree add -b "$branch" "$dir" HEAD
    fi
    link_untracked_data
fi

cat <<EOF

Start the agent with $dir as its working directory.
It commits to $branch; merging into main is the owner's call:

    git -C "$root" merge --no-ff $branch
EOF
