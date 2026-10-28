#!/usr/bin/env python3
"""Work-time tally derived from git history. Zero agent tokens: run it, read one table.

Usage:
  python3 scripts/worklog.py                 # per-day sessions, last 14 days, plus weekly totals
  python3 scripts/worklog.py --since 2026-01-01 --gap 90 --lead 15
  python3 scripts/worklog.py --today         # one line for today's log entry

How a session is counted (stated so the number can be read honestly):
  * commits are grouped by wall-clock time; a gap longer than --gap minutes (default 90)
    starts a new session;
  * a session lasts from its first commit minus --lead minutes (default 15, the work that
    precedes a first commit) to its last commit;
  * a session with a single commit counts --lead minutes.
The result is a proxy for time spent in the repository by the owner and the agents they
were driving, not a timesheet: agents commit only while a session is open, but a long session
may include idle stretches, and work that ends without a commit is invisible. Read it as an
order of magnitude, and as a trend.
"""
from __future__ import annotations

import argparse
import subprocess
from collections import defaultdict
from datetime import datetime, timedelta


def commits(since: str | None) -> list[datetime]:
    cmd = ["git", "log", "--all", "--format=%ad", "--date=format-local:%Y-%m-%d %H:%M"]
    if since:
        cmd.append(f"--since={since}")
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return sorted(datetime.strptime(l.strip(), "%Y-%m-%d %H:%M") for l in out.splitlines() if l.strip())


def sessions(times: list[datetime], gap_min: int, lead_min: int) -> list[tuple[datetime, datetime, int]]:
    out = []
    if not times:
        return out
    start = prev = times[0]
    n = 1
    for t in times[1:]:
        if (t - prev) > timedelta(minutes=gap_min):
            out.append((start - timedelta(minutes=lead_min), prev, n))
            start, n = t, 0
        prev = t
        n += 1
    out.append((start - timedelta(minutes=lead_min), prev, n))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", default=None, help="YYYY-MM-DD (default: 14 days ago)")
    ap.add_argument("--gap", type=int, default=90, help="minutes of silence that end a session")
    ap.add_argument("--lead", type=int, default=15, help="minutes credited before a session's first commit")
    ap.add_argument("--today", action="store_true", help="print one line for today's log entry")
    a = ap.parse_args()
    since = a.since or (datetime.now() - timedelta(days=14)).strftime("%Y-%m-%d")
    ss = sessions(commits(since), a.gap, a.lead)
    by_day: dict[str, list] = defaultdict(list)
    for s, e, n in ss:
        by_day[s.strftime("%Y-%m-%d")].append((s, e, n))
    if a.today:
        d = datetime.now().strftime("%Y-%m-%d")
        hrs = sum((e - s).total_seconds() for s, e, _ in by_day.get(d, [])) / 3600
        spans = ", ".join(f"{s:%H:%M}–{e:%H:%M}" for s, e, _ in by_day.get(d, []))
        print(f"Work time (from git, gap {a.gap} min): {hrs:.1f} h ({spans or 'no commits'})")
        return 0
    print(f"sessions from {since} (gap {a.gap} min, lead {a.lead} min); hours are a proxy, see docstring\n")
    print("| day | sessions | hours | commits |")
    print("|---|---|---:|---:|")
    weekly: dict[str, float] = defaultdict(float)
    total = 0.0
    for d in sorted(by_day):
        rows = by_day[d]
        hrs = sum((e - s).total_seconds() for s, e, _ in rows) / 3600
        total += hrs
        weekly[datetime.strptime(d, "%Y-%m-%d").strftime("%G-W%V")] += hrs
        spans = ", ".join(f"{s:%H:%M}–{e:%H:%M}" for s, e, _ in rows)
        print(f"| {d} | {spans} | {hrs:.1f} | {sum(n for _, _, n in rows)} |")
    print(f"\ntotal {total:.0f} h over {len(by_day)} days")
    print("\n| ISO week | hours |\n|---|---:|")
    for w in sorted(weekly):
        print(f"| {w} | {weekly[w]:.1f} |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
