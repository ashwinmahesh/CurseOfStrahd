#!/usr/bin/env python3
"""The What's new list for the play copy (Q2): main's history up to the copy's commit, one entry per merge or direct
commit on main (with its commit time, so the game can tell which ones the player hasn't seen), written to
<copy>/builds/play_build.json, which the title screen reads (ui/menu/whats_new.gd).

Usage: tools/play/whats_new.py <checkout> [--days 60]   (make play runs it after moving the play copy forward)

A merge's summary is the part of its message in brackets ("Merge branch 'echo-knight' (Echo Knight fitted to the 2024
Fighter; spell attack rolls pause for reactions; cfe54021)"), split at the semicolons, without the commit hash. Notes
that only matter to the people building the game are left out: commits to CLAUDE.md, the README, docs, the Makefile,
Git LFS and the tests, merges of main into a branch, and asides such as "(test and capture)" or "(owner, 2026-10-07)".
Stdlib only.
"""
import argparse
import datetime as dt
import json
import re
import subprocess
from pathlib import Path

MERGE = re.compile(r"^Merge (?:remote-tracking )?branch '([^']+)'(?: of \S+)?(?: into \S+)?(?:\s*\((.*)\)|:\s*(.*))?\s*$")
BUILDERS_ONLY = re.compile(r"^(CLAUDE\.md|AGENTS\.md|README|Makefile|make [a-z-]+:|Git LFS|Docs?\b|docs?:|Tests?\b|tests?:|"
                           r"\.git|P\d+-\d+.* to review|Merge (?:GitHub|origin)|Revert )", re.I)
ASIDE = re.compile(r"\s*\((?:[^()]*\b(?:owner|test|tests|capture|captures|commit|ADR|docs?|P\d+-\d+)\b[^()]*)\)")
TRAILING = re.compile(r"\s*\([^()]*\)$|,\s*[0-9a-f]{7,12}$")
OWNER_NOTE = re.compile(r",?\s*\(?\bowner(?: report)?,? \d{4}-\d{2}-\d{2}\)?")
HASH = re.compile(r"^[0-9a-f]{7,12}$")
NOT_NEWS = {"docs", "doc", "tests", "test", "capture", "captures", "and docs", "docs and tests", "tests and docs"}


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, check=True).stdout


def tidy(text):
    text = OWNER_NOTE.sub("", ASIDE.sub("", text)).strip()
    text = TRAILING.sub("", text).strip().rstrip(".;, ")
    if len(text) > 160 and ": " in text:
        text = text.split(": ", 1)[0]   # a long subject's headline
    return text[:1].upper() + text[1:]


def lines(subject, body=""):
    """What a commit on main changed, in a few short lines ([] when it's only for the builders)."""
    if subject.startswith("Merge pull request"):
        subject = (body.strip().splitlines() or [""])[0]   # a GitHub merge: its title is the body's first line
        return [tidy(subject)] if subject and not BUILDERS_ONLY.match(subject) else []
    m = MERGE.match(subject)
    if m:
        branch, inside, after = m.groups()
        inside = inside or after
        if branch in ("main", "master") or branch.startswith("origin/") or re.search(r"\btests?\b", branch.replace("-", " ")):
            return []
        if not inside:
            return [tidy(branch.replace("-", " ").replace("_", " "))]
        parts = [p.strip() for p in re.split(r";\s+", inside)]
        return [tidy(p) for p in parts if p and not HASH.match(p) and p.lower() not in NOT_NEWS]
    if BUILDERS_ONLY.match(subject):
        return []
    return [tidy(subject)]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("checkout")
    p.add_argument("--days", type=int, default=60)
    a = p.parse_args()
    repo = Path(a.checkout).resolve()
    head = git(repo, "rev-parse", "HEAD").strip()
    log = git(repo, "log", "--first-parent", f"--since={a.days} days ago", "--format=%H%x1f%cI%x1f%ct%x1f%s%x1f%b%x1e", head)
    changes = []
    for rec in log.split("\x1e"):
        if not rec.strip("\n"):
            continue
        # (Not str.strip(): Python counts the \x1f separator as whitespace.)
        commit, when, at, subject, body = (rec.strip("\n").split("\x1f", 4) + [""])[:5]
        said = [s for s in lines(subject, body) if s]
        if said:
            changes.append({"commit": commit[:8], "date": when[:10], "at": int(at), "lines": said})
    out = repo / "builds" / "play_build.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        "commit": head[:8],
        "committed": git(repo, "show", "-s", "--format=%cI", head).strip(),
        "committed_at": int(git(repo, "show", "-s", "--format=%ct", head).strip()),
        "updated": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "changes": changes,
    }, indent=1, ensure_ascii=False) + "\n")
    print(f"What's new: {len(changes)} changes on main up to {head[:8]} ({out.relative_to(repo)})")


if __name__ == "__main__":
    main()
