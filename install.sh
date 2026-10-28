#!/usr/bin/env bash
# Copy the protocol into a git repository. Never overwrites a file that already exists.
#
#   ./install.sh /path/to/your/repo
#   ./install.sh /path/to/your/repo --dry-run
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/template"
target="${1:-}"; dry=0
[ "${2:-}" = "--dry-run" ] && dry=1
if [ -z "$target" ] || [ "$target" = "-h" ] || [ "$target" = "--help" ]; then
    sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi
target="$(cd "$target" && pwd)"
git -C "$target" rev-parse --show-toplevel >/dev/null 2>&1 || {
    echo "not a git repository: $target (run git init first)" >&2
    exit 1
}

copied=0; skipped=0
while IFS= read -r rel; do
    rel="${rel#./}"
    if [ -e "$target/$rel" ] || [ -L "$target/$rel" ]; then
        echo "skip (exists)  $rel"
        skipped=$((skipped + 1))
        continue
    fi
    echo "add            $rel"
    copied=$((copied + 1))
    [ "$dry" = 1 ] && continue
    mkdir -p "$(dirname "$target/$rel")"
    cp -p "$src/$rel" "$target/$rel"
done < <(cd "$src" && find . -type f ! -name .DS_Store | sort)

# CLAUDE.md must say the same as AGENTS.md. A symlink is best; where symlinks are not
# allowed (Windows without Developer Mode) a one-line file that imports AGENTS.md does the
# same for Claude Code. Never a copy: two copies drift apart.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) export MSYS=winsymlinks:nativestrict ;; esac
if [ -e "$target/CLAUDE.md" ] || [ -L "$target/CLAUDE.md" ]; then
    echo "skip (exists)  CLAUDE.md -- make it point at AGENTS.md yourself if you want one rule file"
elif [ "$dry" = 1 ]; then
    echo "add            CLAUDE.md -> AGENTS.md"
elif ln -s AGENTS.md "$target/CLAUDE.md" 2>/dev/null && [ -L "$target/CLAUDE.md" ]; then
    echo "add            CLAUDE.md -> AGENTS.md"
else
    rm -f "$target/CLAUDE.md"
    printf '@AGENTS.md\n' > "$target/CLAUDE.md"
    echo "add            CLAUDE.md (one line, @AGENTS.md: symlinks are not allowed here)"
fi

if [ "$dry" = 1 ]; then
    echo; echo "dry run: $copied file(s) would be added, $skipped skipped"
    exit 0
fi

chmod +x "$target"/.githooks/* "$target"/scripts/*.sh "$target"/scripts/*.py 2>/dev/null || true
git -C "$target" config core.hooksPath .githooks

cat <<EOF

$copied file(s) added, $skipped skipped. Hooks enabled (core.hooksPath = .githooks).

Next:
  1. Fill in the "Project" section of AGENTS.md and §1 of STATUS.md.
  2. If you skipped files that already existed, merge the protocol into them by hand.
  3. Edit AGENTS_ALLOWED in .githooks/commit-msg if your agents have other names.
  4. Run: python3 scripts/check_current_docs.py && python3 scripts/check_doc_structure.py
     (on Windows: python instead of python3)
  5. First commit: git add -A && git commit -m "Adopt the multi-agent protocol" -m "Agent: human"
EOF
