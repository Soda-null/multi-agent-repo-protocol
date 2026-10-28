#!/usr/bin/env python3
"""Weekly repository check-up. Schedule it (cron, launchd, your agent app's scheduler).

Prints one plain report of what has gone stale or messy, and with flags removes only the
things that cannot carry work:

  python3 scripts/repo_hygiene.py                       # report only, changes nothing
  python3 scripts/repo_hygiene.py --delete-junk --delete-merged
  python3 scripts/repo_hygiene.py --memory-dir ~/.claude/projects/<project>/memory

--delete-junk    removes untracked .DS_Store, Office lock files (~$*), __pycache__ and
                 .pytest_cache outside .git / .venv / node_modules. Never a tracked file.
--delete-merged  runs `git branch -d` (which refuses unmerged work) on local branches already
                 merged into main and not checked out in any worktree.
--memory-dir     also flags agent memory files that cite a superseded decision.

Everything else is reported, never changed: the document checks, the age of STATUS.md,
old board claims, entry-file sizes, uncommitted changes (another session's work), side
worktrees. Fixing those is judgment work and waits for the owner.
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

# Windows consoles and pipes default to a legacy code page; print UTF-8 everywhere.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".venv", "node_modules"}
JUNK_FILES = re.compile(r"^(\.DS_Store|~\$.*)$")
JUNK_DIRS = {"__pycache__", ".pytest_cache"}
CLAIM_STALE_DAYS = 3
STATUS_STALE_DAYS = 7
MEMORY_STALE_DAYS = 14
CHECKS = [("entry files state only live decisions", "scripts/check_current_docs.py"),
          ("document structure", "scripts/check_doc_structure.py")]


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / f"scripts/{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def git(*args: str, cwd: Path = ROOT) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def run_check(script: str) -> tuple[bool, str]:
    r = subprocess.run([sys.executable, script], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = (r.stdout + r.stderr).strip().splitlines()
    return r.returncode == 0, (tail[-1] if tail else "")


def find_junk() -> list[Path]:
    tracked = set(git("ls-files").splitlines())
    found = []
    stack = [ROOT]
    while stack:
        d = stack.pop()
        for p in d.iterdir():
            if p.is_dir():
                if p.name in SKIP_DIRS or p.is_symlink():
                    continue
                if p.name in JUNK_DIRS:
                    found.append(p)
                else:
                    stack.append(p)
            elif JUNK_FILES.match(p.name) and p.relative_to(ROOT).as_posix() not in tracked:
                found.append(p)
    return sorted(found)


def merged_branches() -> list[str]:
    in_worktree = set(re.findall(r"^branch refs/heads/(.+)$", git("worktree", "list", "--porcelain"), re.M))
    out = []
    for line in git("branch", "--merged", "main").splitlines():
        name = line.strip().lstrip("*+ ").strip()
        if name and name != "main" and name not in in_worktree:
            out.append(name)
    return out


def status_age() -> tuple[str, int | None]:
    p = ROOT / "STATUS.md"
    m = re.search(r"\*\*Updated:\*\*\s*(\d{4}-\d{2}-\d{2})", p.read_text(encoding="utf-8")) if p.exists() else None
    if not m:
        return "no Updated line", None
    return m.group(1), (date.today() - date.fromisoformat(m.group(1))).days


def old_claims() -> list[str]:
    p = ROOT / "docs/agent_board.md"
    if not p.exists():
        return []
    sec = p.read_text(encoding="utf-8").split("## Claims", 1)[-1].split("\n## ", 1)[0]
    out = []
    for line in sec.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 4 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", cells[-1]):
            age = (date.today() - date.fromisoformat(cells[-1])).days
            if age > CLAIM_STALE_DAYS:
                out.append(f"{cells[0]} ({cells[1]}, since {cells[-1]}, {age} days)")
    return out


def stale_memories(memory_dir: Path) -> list[str]:
    if not memory_dir.is_dir():
        return [f"memory dir {memory_dir} not found"]
    ccd = load("check_current_docs")
    dead = ccd.superseded_codes(ccd.index_rows())
    out = []
    for p in sorted(memory_dir.glob("*.md")):
        text = p.read_text(encoding="utf-8")
        bad = sorted({c for part in ccd.clauses(text) if not ccd.MARKER.search(part)
                      for c in ccd.expand(part) if ccd.is_superseded(c, dead)})
        age = (date.today() - date.fromtimestamp(p.stat().st_mtime)).days
        if bad:
            out.append(f"{p.name}: cites {', '.join(bad)} without saying they were replaced")
        elif age > MEMORY_STALE_DAYS and ccd.CODE.search(text):
            out.append(f"{p.name}: {age} days old and cites decision codes; check it still matches STATUS.md")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--delete-junk", action="store_true")
    ap.add_argument("--delete-merged", action="store_true")
    ap.add_argument("--memory-dir", type=Path)
    a = ap.parse_args()

    print(f"# Repository check-up {date.today().isoformat()}\n")

    print("## Handled automatically (no risk)")
    junk = find_junk()
    if a.delete_junk:
        for p in junk:
            shutil.rmtree(p) if p.is_dir() else p.unlink()
    note = ", deleted" if a.delete_junk and junk else "" if not junk else " (pass --delete-junk to delete)"
    print(f"- junk files: {len(junk)}{note}" + "".join(f"\n  - {p.relative_to(ROOT)}" for p in junk[:15]))
    merged = merged_branches()
    deleted = []
    if a.delete_merged:
        for b in merged:
            if subprocess.run(["git", "branch", "-d", b], cwd=ROOT, capture_output=True).returncode == 0:
                deleted.append(b)
    print(f"- branches already merged into main: {len(merged)}"
          + (f", deleted {len(deleted)}" if a.delete_merged and merged else "")
          + "".join(f"\n  - {b}" for b in merged))

    print("\n## Document checks")
    for name, script in CHECKS:
        if (ROOT / script).exists():
            ok, last = run_check(script)
            print(f"- {'pass' if ok else '**FAIL**'}: {name} — {last}")

    print("\n## For the owner to look at (never changed automatically)")
    items = []
    when, age = status_age()
    if age is None or age > STATUS_STALE_DAYS:
        items.append(f"STATUS.md last updated {when} ({age} days ago): finished items may still be listed")
    items += [f"old claim on the board: {c}" for c in old_claims()]
    for rel, budget in load("check_doc_structure").BUDGET_KB.items():
        p = ROOT / rel
        if p.exists() and p.stat().st_size > budget * 1024:
            items.append(f"{rel} is {p.stat().st_size // 1024} KB, over its {budget} KB budget")
    dirty = [l for l in git("status", "--short").splitlines() if l.strip()]
    if dirty:
        items.append(f"{len(dirty)} uncommitted change(s) (maybe another session's -- do not touch):"
                     + "".join(f"\n  - {l}" for l in dirty[:10]))
    for line in git("worktree", "list").splitlines()[1:]:
        path = Path(line.split()[0])
        n = len([l for l in git("status", "--short", cwd=path).splitlines() if l.strip()])
        items.append(f"side worktree {path}: {n} uncommitted change(s)")
    if a.memory_dir:
        items += [f"memory {m}" for m in stale_memories(a.memory_dir.expanduser())]
    print("\n".join(f"- {i}" for i in items) if items else "- nothing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
