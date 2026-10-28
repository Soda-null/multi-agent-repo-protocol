#!/usr/bin/env python3
"""Read-only pre-close checklist.

  python3 .claude/skills/close-session/scripts/preflight.py --agent claude-code

Prints [ok] / [todo] / [info] lines: hook configuration, branch, dirty paths, today's log
state, board claims held by this agent, and the worklog line as of now. Changes nothing.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent", default="claude-code", help="whose board claims to list")
    agent = ap.parse_args().agent
    root = Path(git("rev-parse", "--show-toplevel") or ".").resolve()
    todo = 0

    def ok(msg: str) -> None:
        print(f"[ok]   {msg}")

    def td(msg: str) -> None:
        nonlocal todo
        todo += 1
        print(f"[todo] {msg}")

    def info(msg: str) -> None:
        print(f"[info] {msg}")

    # 1. hooks and branch
    if git("config", "core.hooksPath") == ".githooks":
        ok("core.hooksPath = .githooks (Agent trailer enforced)")
    else:
        td("run: git config core.hooksPath .githooks  (the commit-msg hook is not active)")
    branch = git("branch", "--show-current")
    if branch == "main":
        ok("on main")
    else:
        info(f"on branch {branch!r}: commit here; merging into main is the owner's call")

    # 2. dirty tree
    status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout
    dirty = [line[3:] for line in status.splitlines() if line.strip()]
    if not dirty:
        ok("working tree clean")
    else:
        info(f"{len(dirty)} dirty path(s) — decide for each whether it is ours or another agent's:")
        for path in dirty:
            print(f"         {path}")

    # 3. today's log
    tz = os.environ.get("LOG_TZ")
    today = (datetime.now(ZoneInfo(tz)).date() if tz else date.today()).isoformat()
    log = root / "docs" / "log" / f"{today}.md"
    if not log.is_file():
        td(f"no log for {today} → python3 scripts/new_log.py (skip only if no substantive work)")
    else:
        text = log.read_text(encoding="utf-8")
        ok(f"log exists: docs/log/{today}.md")
        if re.search(r"Work time \(from git[^)]*\):\s*\d", text):
            ok("worklog line pasted")
        else:
            td("worklog line missing → after the substantive commit: python3 scripts/worklog.py --today")
        m = re.search(r"## Next\s*\n(.*?)(?:\n## |\Z)", text, re.S)
        if m and re.sub(r"[-\s]", "", m.group(1)):
            ok("Next has content")
        else:
            td("Next is empty → one concrete next action")
        if re.search(r"^- \s*$", text, re.M):
            td("log still has empty template bullets ('- ') → fill or delete them")

    # 4. board claims
    board = root / "docs" / "agent_board.md"
    if board.is_file():
        rows = []
        for line in board.read_text(encoding="utf-8").splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if line.startswith("|") and len(cells) >= 4 and cells[1] == agent:
                rows.append(cells)
        if rows:
            info(f"{len(rows)} board claim(s) held by {agent} — release the finished ones:")
            for cells in rows:
                print(f"         since {cells[-1]}: {cells[0][:90]}")
        else:
            ok(f"no board claim held by {agent}")

    # 5. worklog line as of now
    wl = root / "scripts" / "worklog.py"
    if wl.is_file():
        line = subprocess.run([sys.executable, str(wl), "--today"], capture_output=True, text=True,
                              cwd=root).stdout.strip()
        if line:
            info(f"worklog line now (re-run after the last substantive commit): {line}")

    print()
    print("nothing left to do for our paths" if todo == 0 else f"{todo} item(s) left")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
