#!/usr/bin/env python3
"""What each effect costs (P3, for W17's presets): reads perf_probe's effects phase (pairs of samples, everything on
and then one effect off) and prints, per place, the frame time saved by switching each effect off: the median over
the pairs of (on - off), so drift in the Mac's load between pairs cancels out.

  python3 tools/perf/perf_effects.py captures/perf/<name>.json
"""
import json
import statistics
import sys
from collections import defaultdict


def main():
    r = json.load(open(sys.argv[1]))
    on = defaultdict(list)
    off = defaultdict(list)
    loads = []
    for s in r["samples"]:
        if s["kind"] != "effects" or "|" not in s["what"]:
            continue
        head, fx = s["what"].split("|")
        place = head.rsplit(" ", 2)[0] if head.endswith("all on") else head.rsplit(" ", 1)[0]
        (on if head.endswith("all on") else off)[(place, fx)].append(s)
        loads.append(s.get("load", 0))
    med = statistics.median
    places = sorted({k[0] for k in on}, key=lambda p: list(dict.fromkeys(k[0] for k in on)).index(p))
    print("Size %s; Mac load average %.0f to %.0f (median %.0f)\n" % (r["meta"]["size"], min(loads), max(loads), med(loads)))
    for place in places:
        base = [x["frame_ms"]["p50"] for k, v in on.items() if k[0] == place for x in v]
        print("%s: everything on, frame p50 %.1f ms (median of %d samples)" % (place, med(base), len(base)))
        print("  %-14s %8s %8s %9s %7s   %s" % ("effect off", "on ms", "off ms", "saves ms", "saves", "draw calls on -> off"))
        for (p, fx), ons in on.items():
            if p != place or (p, fx) not in off:
                continue
            offs = off[(p, fx)]
            pairs = list(zip(ons, offs))
            d = med([a["frame_ms"]["p50"] - b["frame_ms"]["p50"] for a, b in pairs])
            a = med([x["frame_ms"]["p50"] for x in ons])
            b = med([x["frame_ms"]["p50"] for x in offs])
            print("  %-14s %8.1f %8.1f %9.1f %6.0f%%   %d -> %d" % (fx, a, b, d, 100.0 * d / a if a else 0,
                  med([x["draw_calls"] for x in ons]), med([x["draw_calls"] for x in offs])))
        print()


if __name__ == "__main__":
    main()
