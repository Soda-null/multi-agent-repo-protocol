#!/usr/bin/env python3
"""Check that the most-read files state only current decisions.

Every session reads the entry files first. A superseded decision written there as if it
still held is read as the rule by the next agent. This checker makes that mechanical:

1. Superseded codes. From the index of `docs/decisions.md` it collects every decision code
   that is no longer live: rows whose Standing starts with superseded / historical / closed /
   retired / withdrawn, codes a Standing names as "superseded", "replaced", "closed" ...,
   sub-letters such as "(b superseded by D9)", and codes a later entry says it "replaces".
   A superseded code may still appear in an entry file, but only in a clause that says so
   (replaced / superseded / historical / earlier ...), or under a heading about history.
   Ranges count: "D4–D7" includes D5.
2. Glossary coverage. Every decision code cited in STATUS.md, the board or AGENTS.md, and the
   newest code in the index, has a line in `docs/glossary.md`.
3. STATUS date. The "**Updated:**" date of STATUS.md is not older than the newest dated row
   of the decisions index.

The index is a markdown table whose rows look like
    | 2026-01-15 | D3 | Short title of the entry | live |
Decision codes are D followed by a number, optionally a sub-letter (D3, D3a).

Run: python3 scripts/check_current_docs.py      (exit 0 = clean, 1 = findings)
     python3 scripts/check_current_docs.py --list-dead
The pre-commit hook runs it when a commit touches one of the files below.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Windows consoles and pipes default to a legacy code page; print UTF-8 everywhere.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent
DECISIONS = ROOT / "docs/decisions.md"
GLOSSARY = ROOT / "docs/glossary.md"
STATUS = ROOT / "STATUS.md"

# File -> how a superseded code must be qualified: within its clause, or within its line.
ENTRY_FILES = {
    "STATUS.md": "clause",
    "AGENTS.md": "clause",
    "docs/agent_board.md": "clause",
    "docs/glossary.md": "line",
}
# Files whose cited codes must all be explained in the glossary.
GLOSSARY_SOURCES = ["STATUS.md", "AGENTS.md", "docs/agent_board.md"]

DASH = "[–-]"
CODE = re.compile(r"\bD(\d{1,4})([a-z]\d?)?\b")
RANGE = re.compile(rf"\bD(\d{{1,4}})([a-z]?){DASH}D?(\d{{1,4}})?([a-z]?)\b")
# Words that mark a clause as talking about the past. Extend for your language.
MARKER = re.compile(
    r"replac|supersed|historical|history|closed|retired|withdrawn|before|moved to|earlier|formerly|"
    r"取代|替换|已被|之前|以前|旧|历史|撤回|关闭|作废",
    re.IGNORECASE,
)
HISTORY_HEADING = re.compile(r"history|历史", re.IGNORECASE)
NON_LIVE_START = re.compile(r"^(?:historical|superseded|closed|retired|withdrawn)", re.IGNORECASE)
VERB = r"(?:superseded|replaced|closed|retired|withdrawn)"
ROW = re.compile(r"^\|\s*\d{4}-\d{2}-\d{2}\s*\|")


def expand(text: str) -> list[str]:
    """Codes named in text, ranges expanded: 'D4–D7' -> D4..D7, 'D4b–d' -> D4b..D4d."""
    codes: list[str] = []
    spans: list[tuple[int, int]] = []
    for m in RANGE.finditer(text):
        a, la, b, lb = m.group(1), m.group(2), m.group(3), m.group(4)
        if b is None and la and lb:  # D4b–d
            codes += [f"D{a}{chr(c)}" for c in range(ord(la), ord(lb) + 1)]
        elif b is not None and int(b) > int(a) and int(b) - int(a) < 80:
            codes += [f"D{n}" for n in range(int(a), int(b) + 1)]
            if la:
                codes[-(int(b) - int(a) + 1)] = f"D{a}{la}"
            if lb:
                codes[-1] = f"D{b}{lb}"
        else:
            continue
        spans.append(m.span())
    for m in CODE.finditer(text):
        if any(s <= m.start() < e for s, e in spans):
            continue
        codes.append(m.group(0))
    return codes


def base(code: str) -> str:
    return re.match(r"D\d+", code).group(0)


def index_rows() -> list[tuple[str, str, str, str]]:
    rows = []
    if not DECISIONS.exists():
        return rows
    for line in DECISIONS.read_text(encoding="utf-8").splitlines():
        if ROW.match(line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 4:
                rows.append((cells[0], cells[1], cells[2], cells[3]))
    return rows


def superseded_codes(rows) -> dict[str, str]:
    """code -> reason it is no longer live."""
    out: dict[str, str] = {}
    for date, dcol, entry, standing in rows:
        own = expand(dcol)
        bare = standing.replace("*", "").strip()
        if own and NON_LIVE_START.match(bare):
            for c in own:
                out.setdefault(c, f"index {date}: {bare[:60]}")
        # "D3 superseded", "D4–D6 closed by D7", "D2's wording replaced"
        for m in re.finditer(rf"((?:D\d{{1,4}}[a-z]?(?:{DASH}D\d{{1,4}})?(?:,\s*)?)+)(?:'s wording|\s*\([^)]*\))?\s+{VERB}",
                             bare):
            for c in expand(m.group(1)):
                out.setdefault(c, f"index {date}: {m.group(0)[:60]}")
        # "(b superseded by D9)", "a superseded by D9, c by D10"
        if own:
            b = base(own[0])
            for m in re.finditer(r"(?:\(|;\s*|,\s*)([a-z])\s+(?:superseded\s+)?by\s+D\d+", standing):
                out.setdefault(b + m.group(1), f"index {date}: sub-decision {m.group(0)[:40]}")
        # a later entry that "replaces D5" / "supersedes D4a"
        for m in re.finditer(r"(?:[Rr]eplaces|[Ss]upersedes)\s+(D\d{1,4}[a-z]?)", entry):
            out.setdefault(m.group(1), f"index {date}: {dcol} replaces it")
    return out


def is_superseded(code: str, dead: dict[str, str]) -> str | None:
    if code in dead:
        return dead[code]
    b = base(code)
    if b != code and b in dead:  # D5a when D5 is dead
        return dead[b]
    return None


def clauses(line: str) -> list[str]:
    return [c for c in re.split(r"[。；;|]|\.\s", line) if c.strip()]


def check_superseded(dead) -> list[str]:
    findings = []
    for rel, mode in ENTRY_FILES.items():
        path = ROOT / rel
        if not path.exists():
            findings.append(f"{rel}: file missing")
            continue
        in_history = False
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith("#"):
                in_history = bool(HISTORY_HEADING.search(line))
                continue
            if in_history:
                continue
            for part in ([line] if mode == "line" else clauses(line)):
                if MARKER.search(part):
                    continue
                for code in dict.fromkeys(expand(part)):
                    why = is_superseded(code, dead)
                    if why:
                        findings.append(f"{rel}:{n}: {code} is not live ({why}) but is cited without saying so")
    return findings


def glossary_codes() -> set[str]:
    have = set()
    if not GLOSSARY.exists():
        return have
    for line in GLOSSARY.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^- \*\*([^*]+)\*\*", line)
        if m:
            have.update(base(c) for c in expand(m.group(1)))
    return have


def check_glossary(rows) -> list[str]:
    findings = []
    have = glossary_codes()
    cited: dict[str, str] = {}
    for rel in GLOSSARY_SOURCES:
        path = ROOT / rel
        if not path.exists():
            continue
        in_history = False
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith("#"):
                in_history = bool(HISTORY_HEADING.search(line))
            if in_history:
                continue
            for code in expand(line):
                cited.setdefault(base(code), f"{rel}:{n}")
    for code, where in sorted(cited.items(), key=lambda kv: int(kv[0][1:])):
        if code not in have:
            findings.append(f"{where}: {code} is cited but has no line in docs/glossary.md")
    newest = max((int(base(c)[1:]) for r in rows for c in expand(r[1])), default=0)
    if newest and f"D{newest}" not in have:
        findings.append(f"docs/decisions.md: newest decision D{newest} has no line in docs/glossary.md")
    return findings


def check_status_date(rows) -> list[str]:
    if not STATUS.exists():
        return ["STATUS.md: file missing"]
    m = re.search(r"\*\*Updated:\*\*\s*(\d{4}-\d{2}-\d{2})", STATUS.read_text(encoding="utf-8"))
    if not m:
        return ["STATUS.md: no '**Updated:** YYYY-MM-DD' line"]
    newest = max((r[0] for r in rows), default=None)
    if newest and m.group(1) < newest:
        return [f"STATUS.md: Updated {m.group(1)} is older than the newest decision ({newest}); "
                f"bring STATUS.md up to date in the same commit"]
    return []


def main() -> int:
    rows = index_rows()
    dead = superseded_codes(rows)
    findings = check_superseded(dead) + check_glossary(rows) + check_status_date(rows)
    for f in findings:
        print(f)
    print(f"{len(rows)} decisions in the index, {len(dead)} not live; {len(findings)} finding(s) "
          f"in {len(ENTRY_FILES)} entry files")
    return 1 if findings else 0


if __name__ == "__main__":
    if "--list-dead" in sys.argv:
        for code, why in sorted(superseded_codes(index_rows()).items(),
                                key=lambda kv: (int(base(kv[0])[1:]), kv[0])):
            print(f"{code}: {why}")
        sys.exit(0)
    sys.exit(main())
