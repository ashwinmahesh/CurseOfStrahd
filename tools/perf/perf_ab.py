#!/usr/bin/env python3
"""Before and after in the same sitting (P3): runs tools/perf/perf_run.py in two checkouts in turn, several rounds, and
prints each load and frame figure side by side (median of the rounds), so the Mac's other work weighs on both alike.

  python3 tools/perf/perf_ab.py --before ../CurseOfStrahdGame-perf-base --after . [--rounds 3] [perf_run.py options]
"""
import argparse
import json
import os
import statistics
import subprocess
import sys
from collections import defaultdict


def run(checkout, out, name, extra):
    cmd = [sys.executable, os.path.join(checkout, "tools", "perf", "perf_run.py"), "--out", out, "--name", name] + extra
    subprocess.run(cmd, cwd=checkout, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    path = os.path.join(out, name + ".json")
    return json.load(open(path)) if os.path.exists(path) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True)
    ap.add_argument("--after", required=True)
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--out", default=os.path.abspath("captures/perf_ab"))
    args, extra = ap.parse_known_args()
    os.makedirs(args.out, exist_ok=True)
    loads = {"before": defaultdict(list), "after": defaultdict(list)}
    frames = {"before": defaultdict(list), "after": defaultdict(list)}
    for r in range(args.rounds):
        for side in (["before", "after"] if r % 2 == 0 else ["after", "before"]):
            rep = run(os.path.abspath(getattr(args, side)), args.out, "%s_%d" % (side, r), extra)
            if rep is None:
                print("round %d %s: no report" % (r, side))
                continue
            for row in rep["loads"]:
                loads[side][(row["kind"], row["what"])].append(row["ms"])
            for s in rep["samples"]:
                key = (s["kind"], s["what"].split(" (")[0])
                frames[side][key].append(s)
                for f in s.get("slow_frames", []):
                    frames[side][("slow", key[1])].append(f["ms"])
            print("round %d %s done" % (r, side), flush=True)
    med = statistics.median
    print("\nLoads, ms (median of rounds): before -> after")
    for key in loads["before"]:
        b = loads["before"][key]
        a = loads["after"].get(key, [])
        if a:
            print("  %-14s %-34s %8.0f -> %8.0f" % (key[0], key[1][:34], med(b), med(a)))
    print("\nFrames, ms (median of rounds): p50 and max, before -> after")
    for key in frames["before"]:
        if key[0] == "slow":
            continue
        b = frames["before"][key]
        a = frames["after"].get(key, [])
        if not a:
            continue
        p = lambda xs, k, q: med([x[k][q] for x in xs])
        print("  %-8s %-40s p50 %6.2f -> %6.2f   max %7.1f -> %7.1f   draws %5d -> %5d" % (
            key[0], key[1][:40], p(b, "frame_ms", "p50"), p(a, "frame_ms", "p50"), p(b, "frame_ms", "max"),
            p(a, "frame_ms", "max"), med([x["draw_calls"] for x in b]), med([x["draw_calls"] for x in a])))
    for key in frames["before"]:
        if key[0] != "slow":
            continue
        b = sorted(frames["before"][key], reverse=True)
        a = sorted(frames["after"].get(key, []), reverse=True)
        print("\nFrames over 100 ms in %s (all rounds): before %d (worst %s), after %d (worst %s)" % (
            key[1], len(b), ", ".join("%.0f" % x for x in b[:5]), len(a), ", ".join("%.0f" % x for x in a[:5])))


if __name__ == "__main__":
    main()
