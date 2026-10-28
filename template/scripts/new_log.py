#!/usr/bin/env python3
"""Create today's log entry from docs/log/TEMPLATE.md, never overwriting an existing one.

  python3 scripts/new_log.py                    # today, in LOG_TZ (default: the machine's zone)
  python3 scripts/new_log.py --date 2026-01-15

Set LOG_TZ (e.g. Europe/Berlin) when the agents run on machines in different zones,
so that every agent agrees on which day "today" is.
"""
from __future__ import annotations

import argparse
import os
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = ROOT / "docs" / "log"


def today() -> date:
    tz = os.environ.get("LOG_TZ")
    return datetime.now(ZoneInfo(tz)).date() if tz else date.today()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--date", type=date.fromisoformat, help="YYYY-MM-DD (default: today)")
    d = ap.parse_args().date or today()
    target = LOG_DIR / f"{d.isoformat()}.md"
    template = LOG_DIR / "TEMPLATE.md"
    if target.exists():
        print(f"error: {target.relative_to(ROOT)} already exists; update it in place")
        return 2
    if not template.is_file():
        print(f"error: template not found: {template.relative_to(ROOT)}")
        return 2
    target.write_text(template.read_text(encoding="utf-8").replace("{{date}}", d.isoformat()), encoding="utf-8")
    print(f"created {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
