#!/usr/bin/env python3
"""Check the document structure that AGENTS.md ("Document discipline") asks for.

What it checks, each mechanically:

1. Header card. Every markdown file directly under docs/, and every README.md in the tree
   outside SKIP_PREFIXES, has `**Standing:**` within its first 15 lines, so a reader knows
   from the top whether the file still counts.
2. docs/README.md names every markdown file directly under docs/ and every folder under docs/.
3. Every folder directly under docs/ has a README.md.
4. Every folder under docs/history/ has a README.md that names every file and folder in it.
5. Size budgets of the entry files (BUDGET_KB, in kilobytes). Every agent pays for every byte
   of an entry file at the start of every session.

It only reports; it never edits a file.

Run: python3 scripts/check_doc_structure.py [--root PATH]   (exit 0 = clean, 1 = findings)
The pre-commit hook runs it when a commit touches docs/, STATUS.md, AGENTS.md or a README.md.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

# Windows consoles and pipes default to a legacy code page; print UTF-8 everywhere.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

CARD_KEYS = ("**Standing:**", "**地位：**")
CARD_LINES = 15
BUDGET_KB = {"STATUS.md": 20, "AGENTS.md": 16, "docs/agent_board.md": 8, "docs/glossary.md": 40}
# README files that are frozen records (one experiment, an archived route): not retrofitted.
SKIP_PREFIXES = ("archive/", ".claude/")


def tracked(root: Path) -> list[str]:
    files: set[str] = set()
    for args in (["ls-files"], ["ls-files", "--others", "--exclude-standard"]):
        try:
            out = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", check=True).stdout
            files.update(out.splitlines())
        except (subprocess.CalledProcessError, FileNotFoundError):
            files.update(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file())
    return sorted(files)


def has_card(path: Path) -> bool:
    try:
        head = path.read_text(encoding="utf-8").splitlines()[:CARD_LINES]
    except (OSError, UnicodeDecodeError):
        return False
    return any(k in line for line in head for k in CARD_KEYS)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    root = Path(ap.parse_args().root).resolve()
    files = tracked(root)
    docs = root / "docs"
    findings: list[str] = []

    # 1. header cards
    targets = [f for f in files if f.startswith("docs/") and f.count("/") == 1 and f.endswith(".md")]
    targets += [f for f in files if f.endswith("README.md") and not f.startswith(SKIP_PREFIXES)]
    targets = sorted(set(t for t in targets if (root / t).exists()))
    for rel in targets:
        if not has_card(root / rel):
            findings.append(f"{rel}: no header card (`**Standing:**` in the first {CARD_LINES} lines)")

    if docs.is_dir():
        # 2. docs/README.md names every top-level docs file and folder
        readme = docs / "README.md"
        index = readme.read_text(encoding="utf-8") if readme.exists() else ""
        for p in sorted(docs.iterdir()):
            if p.name.startswith(".") or p.name == "README.md":
                continue
            if p.is_dir():
                if f"`{p.name}/`" not in index and f"`{p.name}`" not in index and f"({p.name}/" not in index:
                    findings.append(f"docs/README.md: folder docs/{p.name}/ is not listed")
            elif p.suffix == ".md" and f"`{p.name}`" not in index:
                findings.append(f"docs/README.md: docs/{p.name} is not listed")

        # 3. every folder directly under docs/ has a README.md
        for d in sorted(p for p in docs.iterdir() if p.is_dir() and not p.name.startswith(".")):
            if not (d / "README.md").exists():
                findings.append(f"docs/{d.name}/: no README.md")

        # 4. history folders: README present and complete
        hist = docs / "history"
        if hist.is_dir():
            for folder in sorted(d for d in hist.iterdir() if d.is_dir()):
                r = folder / "README.md"
                if not r.exists():
                    findings.append(f"docs/history/{folder.name}/: no README.md")
                    continue
                text = r.read_text(encoding="utf-8")
                for item in sorted(folder.iterdir()):
                    if item.name != "README.md" and not item.name.startswith(".") and item.name not in text:
                        findings.append(f"docs/history/{folder.name}/README.md does not name {item.name}")

    # 5. size budgets
    for rel, kb in BUDGET_KB.items():
        p = root / rel
        if p.exists() and p.stat().st_size > kb * 1024:
            findings.append(f"{rel}: {p.stat().st_size / 1024:.1f} KB, over its {kb} KB budget")

    for f in findings:
        print(f)
    print(f"checked {len(targets)} files for a header card; {len(findings)} finding(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
