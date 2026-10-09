#!/usr/bin/env python3
"""The performance pass (P3): runs tools/perf/perf_probe.tscn in a window that never shows and prints its report.

  python3 tools/perf/perf_run.py [--out DIR] [--frames N] [--warm N] [--passes N]
                                 [--only title,newgame,places,saveload,combat,transitions,fights,foemem] [--places id,id]
                                 [--encounters id,id] [--settle S] [--profile]
                                 [--headless] [--cover] [--timeout S]

--headless runs without a window or GPU: script and loading costs only (no shader compiles or texture uploads), for
when the owner may be playing. --cover sends the transitions phase's changes of place through the game's loading cover.

--profile also records GDScript time per function: the game connects to a small debugger server here
(Godot's --remote-debug protocol) and streams the script profiler's frames, split by the probe's phases.
Profiling slows scripts down, so take frame times from a run without it.
"""
import argparse
import json
import os
import socket
import struct
import subprocess
import sys
import threading
import time
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")


# --- Godot Variant decoding (core/io/marshalls.cpp), enough for debugger messages --------------------------------

class Reader:
    def __init__(self, data):
        self.d = data
        self.i = 0

    def u32(self):
        v = struct.unpack_from("<I", self.d, self.i)[0]
        self.i += 4
        return v

    def take(self, fmt):
        v = struct.unpack_from(fmt, self.d, self.i)
        self.i += struct.calcsize(fmt)
        return v

    def string(self):
        n = self.u32()
        s = self.d[self.i:self.i + n].decode("utf-8", "replace")
        self.i += n + ((4 - n % 4) % 4)
        return s

    def variant(self):
        header = self.u32()
        t = header & 0xFF
        f64 = header & (1 << 16)
        if t == 0:
            return None
        if t == 1:
            return self.u32() != 0
        if t == 2:
            return self.take("<q")[0] if f64 else self.take("<i")[0]
        if t == 3:
            return self.take("<d")[0] if f64 else self.take("<f")[0]
        if t in (4, 21, 22):   # String, StringName, NodePath (as written by the debugger: plain strings)
            if t == 22:
                return self._nodepath()
            return self.string()
        real = "<d" if f64 else "<f"
        sizes = {5: 2, 6: 2, 7: 4, 8: 4, 9: 3, 10: 3, 11: 6, 12: 4, 13: 4, 14: 4, 15: 4, 16: 6, 17: 9, 18: 12, 19: 16, 20: 4}
        if t in sizes:
            ints = t in (6, 8, 10, 13)
            n = sizes[t]
            if t == 20:
                return self.take("<4f")
            return self.take("<%d%s" % (n, "i" if ints else real[1]))
        if t == 23:   # RID
            return self.take("<Q")[0]
        if t == 24:   # Object (as id when encoded for the debugger)
            if header & (1 << 16):
                return ("object", self.take("<Q")[0])
            name = self.string()
            if name == "":
                return None
            props = {}
            for _ in range(self.u32()):
                k = self.string()
                props[k] = self.variant()
            return ("object", name, props)
        if t == 27:   # Dictionary
            typed = (header >> 16) & 0xF
            if typed:
                self._container_type(typed & 3)
                self._container_type((typed >> 2) & 3)
            n = self.u32() & 0x7FFFFFFF
            out = {}
            for _ in range(n):
                k = self.variant()
                out[k if isinstance(k, (str, int, float, bool, type(None))) else str(k)] = self.variant()
            return out
        if t == 28:   # Array
            typed = (header >> 16) & 3
            if typed:
                self._container_type(typed)
            n = self.u32() & 0x7FFFFFFF
            return [self.variant() for _ in range(n)]
        if t == 29:
            n = self.u32()
            b = self.d[self.i:self.i + n]
            self.i += n + ((4 - n % 4) % 4)
            return b
        packed = {30: "i", 31: "q", 32: "f", 33: "d"}
        if t in packed:
            n = self.u32()
            return list(self.take("<%d%s" % (n, packed[t])))
        if t == 34:
            return [self.string() for _ in range(self.u32())]
        if t in (35, 36, 37, 38):
            n = self.u32()
            k = {35: 2, 36: 3, 37: 4, 38: 4}[t]
            return list(self.take("<%d%s" % (n * k, real[1] if t != 37 else "f")))
        raise ValueError("variant type %d" % t)

    def _container_type(self, kind):
        if kind == 1:
            self.u32()
        elif kind in (2, 3):
            self.string()

    def _nodepath(self):
        n = self.u32()
        if n & 0x80000000:
            sub = self.u32()
            self.u32()
            names = [self.string() for _ in range((n & 0x7FFFFFFF) + sub)]
            return "/".join(names)
        return ""


def enc_string(s):
    b = s.encode()
    return struct.pack("<I", len(b)) + b + b"\0" * ((4 - len(b) % 4) % 4)


def encode(v):
    if v is None:
        return struct.pack("<I", 0)
    if isinstance(v, bool):
        return struct.pack("<II", 1, 1 if v else 0)
    if isinstance(v, int):
        return struct.pack("<Iq", 2 | (1 << 16), v)
    if isinstance(v, float):
        return struct.pack("<Id", 3 | (1 << 16), v)
    if isinstance(v, str):
        return struct.pack("<I", 4) + enc_string(v)
    if isinstance(v, list):
        return struct.pack("<II", 28, len(v)) + b"".join(encode(x) for x in v)
    raise ValueError(v)


# --- The debugger server ------------------------------------------------------------------------------------------

class Profiler:
    """Takes the game's debugger connection, turns the script profiler on and sums each function's time by phase."""

    def __init__(self, port):
        self.port = port
        self.sigs = {}
        self.phase = "boot"
        # phase -> sig id -> [calls, self_s, total_s]
        self.funcs = defaultdict(lambda: defaultdict(lambda: [0, 0.0, 0.0]))
        self.frames = defaultdict(int)
        self.script_s = defaultdict(float)
        self.layout = None
        self.errors = []
        self.worst = []   # (script_s, phase, frame_number, [(sig, self_s, total_s)])
        self.srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind(("127.0.0.1", port))
        self.srv.listen(1)
        self.thread = threading.Thread(target=self._serve, daemon=True)
        self.thread.start()

    def _send(self, conn, msg, data):
        body = encode([msg, 1, data])
        conn.sendall(struct.pack("<I", len(body)) + body)

    def _serve(self):
        self.srv.settimeout(120)
        try:
            conn, _ = self.srv.accept()
        except socket.timeout:
            return
        conn.settimeout(None)
        self._send(conn, "profiler:servers", [True, [512, False]])
        buf = b""
        while True:
            try:
                chunk = conn.recv(1 << 20)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            while len(buf) >= 4:
                n = struct.unpack_from("<I", buf)[0]
                if len(buf) < 4 + n:
                    break
                payload = buf[4:4 + n]
                buf = buf[4 + n:]
                try:
                    msg = Reader(payload).variant()
                except Exception as e:   # a type this reader doesn't know: skip the message
                    self.errors.append(str(e))
                    continue
                self._handle(msg)

    def _handle(self, msg):
        if not isinstance(msg, list) or len(msg) < 2:
            return
        name = msg[0]
        data = msg[-1] if isinstance(msg[-1], list) else []
        if name == "output":
            # [strings, types]
            for line in (data[0] if data and isinstance(data[0], list) else []):
                for part in str(line).splitlines():
                    if part.startswith("PERF phase "):
                        self.phase = part[len("PERF phase "):].replace("\x00", "").strip()
        elif name == "servers:function_signature":
            # [name, id]
            if len(data) >= 2:
                self.sigs[data[1]] = data[0]
        elif name == "servers:profile_frame":
            self._frame(data)

    def _frame(self, a):
        # frame_number, frame_time, process_time, physics_time, physics_frame_time, script_time, servers..., funcs
        i = 6
        self.frames[self.phase] += 1
        self.script_s[self.phase] += float(a[5]) if len(a) > 5 else 0.0
        n_servers = a[i]
        i += 1
        for _ in range(n_servers):
            i += 1
            k = a[i]
            i += 1 + k
        n = a[i]
        i += 1
        rest = a[i:i + n]
        if self.layout is None and rest:
            # sig_id, call_count, self_time, total_time[, internal_time]
            self.layout = 5 if len(rest) % 5 == 0 and (len(rest) % 4 != 0 or isinstance(rest[4], float)) else 4
        k = self.layout or 4
        acc = self.funcs[self.phase]
        here = []
        for j in range(0, len(rest) - k + 1, k):
            sig, calls, self_t, total_t = rest[j], rest[j + 1], rest[j + 2], rest[j + 3]
            row = acc[sig]
            row[0] += int(calls)
            row[1] += float(self_t)
            row[2] += float(total_t)
            here.append((sig, int(calls), float(self_t), float(total_t)))
        st = float(a[5]) if len(a) > 5 else 0.0
        if st > 0.05:
            here.sort(key=lambda r: -r[3])
            self.worst.append((st, self.phase, a[0], here[:30]))
            self.worst.sort(key=lambda w: -w[0])
            del self.worst[12:]

    def summary(self, top=25):
        out = {}
        for phase, acc in self.funcs.items():
            rows = []
            for sig, (calls, self_t, total_t) in acc.items():
                rows.append({"fn": self.sigs.get(sig, "#%s" % sig), "calls": calls, "self_ms": self_t * 1000,
                             "total_ms": total_t * 1000})
            rows.sort(key=lambda r: -r["self_ms"])
            out[phase] = {"frames": self.frames[phase], "script_ms": self.script_s[phase] * 1000, "top_self": rows[:top],
                          "top_total": sorted(rows, key=lambda r: -r["total_ms"])[:top]}
        out["_worst_frames"] = [{"script_ms": w[0] * 1000, "phase": w[1], "frame": w[2],
                                 "by_total": [{"fn": self.sigs.get(sig, "#%s" % sig), "calls": c, "self_ms": st * 1000,
                                               "total_ms": tt * 1000} for sig, c, st, tt in w[3]]} for w in self.worst]
        return out


# --- Running ------------------------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "captures", "perf"))
    ap.add_argument("--name", default="perf")
    ap.add_argument("--frames", type=int, default=240)
    ap.add_argument("--warm", type=int, default=90)
    ap.add_argument("--passes", type=int, default=2)
    ap.add_argument("--only", default="")
    ap.add_argument("--places", default="")
    ap.add_argument("--encounters", default="")
    ap.add_argument("--settle", default="")
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--profile", action="store_true")
    ap.add_argument("--preload", default="")
    ap.add_argument("--pairs", type=int, default=0)
    ap.add_argument("--cycles", type=int, default=0)
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--headless", action="store_true")
    ap.add_argument("--cover", action="store_true")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    report = os.path.join(os.path.abspath(args.out), args.name + ".json")
    log = os.path.join(os.path.abspath(args.out), args.name + ".log")
    user = ["--out=" + report, "--frames=%d" % args.frames, "--warm=%d" % args.warm, "--passes=%d" % args.passes,
            "--size=" + args.size]
    if args.only:
        user.append("--only=" + args.only)
    if args.places:
        user.append("--places=" + args.places)
    if args.encounters:
        user.append("--encounters=" + args.encounters)
    if args.settle:
        user.append("--settle=" + args.settle)
    if args.preload:
        user.append("--preload=" + args.preload)
    if args.pairs:
        user.append("--pairs=%d" % args.pairs)
    if args.cycles:
        user.append("--cycles=%d" % args.cycles)
    if args.cover:
        user.append("--cover=1")
    cmd = [os.path.join(ROOT, "tools", "godot"), "--path", ROOT, "--resolution", "1x1", "--position", "100000,100000",
           "--audio-driver", "Dummy"]
    if args.headless:
        cmd = [GODOT, "--headless", "--path", ROOT, "--audio-driver", "Dummy"]
    prof = None
    if args.profile:
        port = args.port or (6100 + os.getpid() % 800)
        prof = Profiler(port)
        cmd += ["--remote-debug", "tcp://127.0.0.1:%d" % port, "--ignore-error-breaks"]
    cmd += ["res://tools/perf/perf_probe.tscn", "--"] + user
    env = dict(os.environ, GODOT=GODOT)
    t0 = time.time()
    with open(log, "w") as lf:
        proc = subprocess.Popen(cmd, stdout=lf, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, env=env, cwd=ROOT)
        print("perf: probe running as pid %d (log %s)" % (proc.pid, log), flush=True)
        try:
            proc.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            proc.kill()   # only our own run
            print("perf: timed out after %ds; stopped pid %d" % (args.timeout, proc.pid))
    print("perf: finished in %.0f s (exit %s)" % (time.time() - t0, proc.returncode))
    if prof is not None:
        time.sleep(0.5)
        path = os.path.join(os.path.abspath(args.out), args.name + "_profile.json")
        with open(path, "w") as f:
            json.dump({"phases": prof.summary(), "decode_errors": prof.errors[:20]}, f, indent=1)
        print("perf: script profile in", path)
    if os.path.exists(report):
        print_report(json.load(open(report)))
        if any(s["kind"] in ("effect", "effects") for s in json.load(open(report))["samples"]):
            print("\nEffect costs: python3 tools/perf/perf_effects.py " + report)
    else:
        print("perf: no report; see", log)
        sys.exit(1)


def print_report(r):
    m = r["meta"]
    print("\n%s, %s, %sx%s, engine ready at %d ms, %s data entries" % (m.get("adapter"), m.get("renderer"),
          *str(m.get("size", "")).strip("()").split(", "), m.get("engine_ready_ms", 0), m.get("data_entries")))
    print("\nLoads (ms; sync = inside the call, total = to the first frame drawn)")
    by = defaultdict(list)
    for row in r["loads"]:
        by[(row["kind"], row["what"])].append(row)
    for (kind, what), rows in by.items():
        totals = ", ".join("%.0f" % x["ms"] for x in rows)
        syncs = ", ".join("%.0f" % x["sync_ms"] for x in rows if "sync_ms" in x)
        hitch = ", ".join("%.0f" % x["hitch_ms"] for x in rows if "hitch_ms" in x)
        print("  %-14s %-34s total %-16s%s%s" % (kind, what, totals, ("  sync " + syncs) if syncs else "",
                                              ("  worst next-second frame " + hitch) if hitch else ""))
    if r.get("foe_memory"):
        print("\nHolding a place's foes (video and texture memory with their sheets read ahead: off, when = fights whose "
              "condition holds, possible = whose condition could come true this visit, all = every fight still to come)")
        for f in r["foe_memory"]:
            print("  %-34s %-4s %3d files read in %5d ms  video %6.0f MB  textures %6.0f MB" % (f["place"][:34], f["mode"],
                  f["files"], f["read_ms"], f["video_mb"], f["texture_mb"]))
    if r.get("fights"):
        print("\nFights starting (ms: call = starting it, first = the next frame drawn, worst = the worst frame in the "
              "second after, with how many were over 100 ms)")
        for f in r["fights"]:
            print("  pass %d  %-30s %-34s %s call %5.0f  first %5.0f  worst %5.0f (%d slow)  load %4.1f" % (
                f["pass"], f["location"][:30], f["encounter"][:34], "     " if f["started"] else "(not)",
                f["call_ms"], f["first_frame_ms"], f["worst_after_ms"], f["slow_after"], f.get("load", 0)))
    if r.get("transitions"):
        print("\nChanges of place (ms from asking: block = the longest frame until the place is ready, first = the next "
              "frame drawn, ready = the place ready (under a cover: the cover starts to lift), stuck = the end of the last "
              "frame over 100 ms in the 2 s after; worst = the worst frame in those 2 s)")
        for t in r["transitions"]:
            print("  pass %d  %-28s -> %-30s %-5s %-4s block %6.0f  first %6.0f  ready %6.0f  stuck %6.0f  worst %5.0f (%d slow)  load %4.1f" % (
                t["pass"], t["from"][:28], t["to"][:30], "new" if t["first_visit"] else "again",
                "out" if t["outdoors"] else "in", t["block_ms"], t["first_frame_ms"], t["ready_ms"], t["stuck_ms"],
                t["worst_after_ms"], t["slow_after"], t.get("load", 0)))
    print("\nFrames (ms; p10 / p50 / p95 / max; draw p50 = the renderer's CPU side plus waiting on the GPU; draw calls; "
          "video MB; resident MB; load average)")
    for s in r["samples"]:
        if s["kind"] == "effect":
            continue   # tools/perf/perf_effects.py prints these
        f = s["frame_ms"]
        print("  %-8s %-44s %6.2f %6.2f %6.2f %7.1f | draw %5.2f | %5d draws | %5.0f vram | %5.0f rss | load %4.1f%s" % (
            s["kind"], s["what"][:44], f.get("p10", 0), f["p50"], f["p95"], f["max"], s["draw_ms"]["p50"],
            s["draw_calls"], s["video_mb"], s["rss_mb"], s.get("load", 0),
            ("  (%d frames, %.0f s)" % (s["n"], s["wall_s"])) if "wall_s" in s else ""))

if __name__ == "__main__":
    main()
