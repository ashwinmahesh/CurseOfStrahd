"""Gemini spend: the ledger every image call is counted in (P13), and the shared call cap for batch runs.

The ledger. tools/art/generate_gemini.py records every call, from every worktree and thread, in one file outside the
repo (GEMINI_LEDGER, default ~/.curse-of-strahd/gemini_ledger.jsonl): when, which thread (ART_THREAD, else the
branch), which key, the model and size, ok or the error, and the cost at Google's list price. A key appears only as
a short fingerprint, named "primary" or "backup" when it matches GEMINI_API_KEY or GEMINI_BACKUP_API_KEY in ~/.zshrc.
Each key keeps its own balance, stop point and daily request cap (KEYS; GEMINI_DAILY_CAP overrides; refusals and
errors count, the day resets at midnight Pacific). Calls go out with GEMINI_API_KEY, so a run on the backup key is
GEMINI_API_KEY="$GEMINI_BACKUP_API_KEY" <command>.
  make art-spend                                 each key's credit and today's requests, then the spend per day and
                                                 thread (DAYS=n, 7)
  make art-spend [KEY=backup] BALANCE=<usd> KEEP=<usd>
                                                 records the key's credit as it stands now (after a top-up, from the
                                                 billing page) and the credit to leave untouched: art stops when only
                                                 that much is left. Google's own "credits are depleted" reply sets the
                                                 credit to nothing until the next BALANCE
Batch tools call preflight() before their first call: it prints the batch's cost and what's left, and stops the batch
before it starts if it would pass the key's stop point, today's requests or GEMINI_BUDGET, so batches stop being cut
off halfway. A batch that starts reserves its calls until its process ends, so two threads can't both count on the
same credit. generate_gemini.py calls guard() before each call and sends nothing once the key is at its stop point
or today's requests are spent. GEMINI_OVERRUN=1 goes past both. Calls made by worktrees whose scripts predate the
ledger are read from their art/generation_log.jsonl (key unknown) by preflight() and the report.

The call cap. GEMINI_BUDGET=<counter file>:<max calls> and every call made through tools/art/anim_keyframes.py or
tools/art/new_creatures.py takes one from the counter first; once it's spent they stop instead of calling. The
counter is a plain number in the file, shared by every process that names the same file (file-locked).

python3 tools/art/gemini_budget.py [--days 7] [--key primary|backup] [--balance USD --keep USD]
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[2]
PACIFIC = ZoneInfo("America/Los_Angeles")   # Gemini's daily quotas reset at midnight Pacific
# The owner's keys (2026-10-07): the variable in ~/.zshrc that holds each, and its daily request cap.
KEYS = {"primary": ("GEMINI_API_KEY", 10000), "backup": ("GEMINI_BACKUP_API_KEY", 1000)}
# Google's list price per image (ai.google.dev pricing, checked 2026-10-07): image output is billed as a fixed number
# of tokens per size. Thinking and input tokens add about a cent per ten calls and aren't counted.
PRICES = {
    "gemini-3.1-flash-image": {"512": 0.045, "1K": 0.067, "2K": 0.101, "4K": 0.151},
    "gemini-3-pro-image": {"1K": 0.134, "2K": 0.134, "4K": 0.24},
}
UNKNOWN = "unknown"   # the key of calls read from a generation log (scripts older than the ledger)
RESERVE_HOURS = 12    # a batch's reservation lapses after this even if its process is somehow still there
_reservation = ""     # this process's open reservation (preflight)


# ---- the call cap -------------------------------------------------------------------------------------------------

def take():
    """True if a call may be made (and counts it); always True when no budget is set."""
    spec = os.environ.get("GEMINI_BUDGET", "")
    if not spec:
        return True
    path, _, cap = spec.rpartition(":")
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        used = int(f.read().strip() or 0)
        if used >= int(cap):
            return False
        f.seek(0)
        f.truncate()
        f.write(str(used + 1))
    return True


def used():
    spec = os.environ.get("GEMINI_BUDGET", "")
    path = spec.rpartition(":")[0]
    try:
        return int(Path(path).read_text().strip() or 0)
    except (OSError, ValueError):
        return 0


# ---- keys ---------------------------------------------------------------------------------------------------------

def _zshrc(var):
    rc = Path.home() / ".zshrc"
    if not rc.exists():
        return ""
    m = re.search(rf"^export {var}=['\"]?([^'\"\n]+)", rc.read_text(), re.M)
    return m.group(1) if m else ""


def api_key(required=True):
    """The key calls go out with: GEMINI_API_KEY, read from ~/.zshrc if the shell doesn't have it."""
    key = os.environ.get("GEMINI_API_KEY") or _zshrc("GEMINI_API_KEY")
    if not key and required:
        sys.exit("GEMINI_API_KEY is not set")
    return key


def key_id(key=None):
    """A short fingerprint of the key, never the key itself."""
    key = api_key(required=False) if key is None else key
    return hashlib.sha256(key.encode()).hexdigest()[:8] if key else "none"


def labelled():
    """{fingerprint: label} for the keys in KEYS (as ~/.zshrc defines them, else as the shell has them)."""
    out = {}
    for label, (var, _) in KEYS.items():
        value = _zshrc(var) or os.environ.get(var, "")
        if value:
            out[key_id(value)] = label
    return out


def resolve(name):
    """A key's fingerprint from its label ("primary", "backup"), or the fingerprint itself."""
    for fp, label in labelled().items():
        if label == name:
            return fp
    return name


def label(fp):
    return labelled().get(fp, UNKNOWN + " key" if fp == UNKNOWN else f"key {fp}")


def daily_cap(fp):
    if os.environ.get("GEMINI_DAILY_CAP"):
        return int(os.environ["GEMINI_DAILY_CAP"])
    return KEYS.get(labelled().get(fp, ""), ("", 1000))[1]


# ---- the ledger ---------------------------------------------------------------------------------------------------

def ledger_path():
    return Path(os.environ.get("GEMINI_LEDGER") or Path.home() / ".curse-of-strahd" / "gemini_ledger.jsonl").expanduser()


def pinned_model():
    return json.loads((ROOT / "art" / "manifest.json").read_text())["image_model"]


def size_key(size=""):
    s = (size or "1K").upper()
    return "512" if s in ("0.5K", "512") else s


def price(model, size=""):
    """Dollars per image at list price; a model not in PRICES is priced as the pinned Flash model."""
    table = PRICES.get(model, PRICES["gemini-3.1-flash-image"])
    return table.get(size_key(size), table["1K"])


def _git(*args, cwd=ROOT):
    try:
        return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""


def _branch(tree):
    b = _git("rev-parse", "--abbrev-ref", "HEAD", cwd=tree)
    return b if b and b != "HEAD" else Path(tree).name


def thread():
    """Who is spending: ART_THREAD, else this worktree's branch, else its folder."""
    return os.environ.get("ART_THREAD") or _branch(ROOT)


def _now():
    return dt.datetime.now().astimezone()


def _stamp(when=None):
    return (when or _now()).isoformat(timespec="seconds")


def _when(entry):
    return dt.datetime.fromisoformat(str(entry["t"]))


def _append(*items):
    p = ledger_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write("".join(json.dumps(e) + "\n" for e in items))


def entries():
    try:
        with open(ledger_path()) as f:
            lines = f.readlines()
    except OSError:
        return []
    out = []
    for line in lines:
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if isinstance(e, dict) and "t" in e:
            out.append(e)
    return out


def record(model, size, name, folder, status, code=None, key=None, when=None):
    """One call. status: ok, refused (an answer with no image) or error (code: the HTTP status, or "network").
    `when` should be the time written to art/generation_log.jsonl, so the log and the ledger name the same call."""
    entry = {"kind": "call", "t": _stamp(when), "key": key_id(key), "thread": thread(), "worktree": ROOT.name,
             "model": model, "size": size_key(size), "name": name, "folder": folder, "status": status,
             "usd": price(model, size) if status == "ok" else 0.0}
    if code is not None:
        entry["code"] = code
    if os.environ.get("GEMINI_RESERVATION"):
        entry["res"] = os.environ["GEMINI_RESERVATION"]
    _append(entry)


def set_balance(usd, keep=0.0, key_fp=None, kind="balance", when=None):
    """A key's credit as it stands now, and the credit art leaves untouched ("depleted": Google said none is left)."""
    _append({"kind": kind, "t": _stamp(when), "key": key_fp or key_id(), "usd": float(usd), "keep": float(keep),
             "thread": thread()})


def depleted(key=None):
    """Google replied that the key's credits are depleted: nothing is left until the next BALANCE."""
    set_balance(0.0, 0.0, key_id(key), kind="depleted")


def sync_logs():
    """Adds calls that are in a worktree's art/generation_log.jsonl but not in the ledger: those made before the
    ledger existed, or by a worktree whose scripts predate it (key unknown). A call merged into several worktrees is
    counted once, under the first worktree that has it: main's checkout, then the branches, then detached ones."""
    out = _git("worktree", "list", "--porcelain")
    trees = [line[len("worktree "):] for line in out.splitlines() if line.startswith("worktree ")]
    if not trees:
        return 0
    main_tree = trees[0]
    detached = {b.splitlines()[0][len("worktree "):] for b in out.split("\n\n") if "\ndetached" in b}
    trees.sort(key=lambda t: (t != main_tree, t in detached))
    seen = {(str(e["t"])[:19], e.get("folder"), e.get("name")) for e in entries() if e.get("kind") == "call"}
    new = []
    for tree in trees:
        try:
            lines = (Path(tree) / "art" / "generation_log.jsonl").read_text().splitlines()
        except OSError:
            continue
        name = None
        for line in lines:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not str(d.get("model", "")).startswith("gemini") or "time" not in d:
                continue
            sig = (str(d["time"])[:19], d.get("folder"), d.get("name"))
            if sig in seen:
                continue
            seen.add(sig)
            name = name or (_branch(tree) if tree != main_tree else "main (merged)")
            when = dt.datetime.fromisoformat(sig[0]).astimezone()
            new.append({"kind": "call", "t": _stamp(when), "key": UNKNOWN, "thread": name, "worktree": Path(tree).name,
                        "model": d["model"], "size": size_key(d.get("size", "")), "name": d.get("name"),
                        "folder": d.get("folder"), "status": "ok", "usd": price(d["model"], d.get("size", "")),
                        "from_log": True})
    new.sort(key=lambda e: e["t"])
    if new:
        _append(*new)
    return len(new)


def _alive(pid):
    try:
        os.kill(int(pid), 0)
    except ProcessLookupError:
        return False
    except (PermissionError, ValueError, TypeError):
        return True
    return True


def state(fp=None, now=None, skip_reservation=""):
    """A key's numbers now: today's calls and spend (Pacific day), its balance, what was spent since and what's left,
    what art may still spend before the stop point, and what other running batches have reserved but not made yet."""
    fp, now = fp or key_id(), now or _now()
    today = now.astimezone(PACIFIC).date()
    every = entries()
    mine = [e for e in every if e.get("key") == fp]
    balance = max((e for e in mine if e.get("kind") in ("balance", "depleted")), key=_when, default=None)
    calls = [e for e in mine if e.get("kind") == "call"]
    released = {e.get("id") for e in mine if e.get("kind") == "release"}
    st = {"key": fp, "cap": daily_cap(fp), "today_calls": 0, "today_usd": 0.0, "balance": balance,
          "spent_since": 0.0, "left": None, "usable": None, "reserved_calls": 0, "reserved_usd": 0.0,
          "reserved_by": [], "unknown_since": [0, 0.0]}
    for e in calls:
        if _when(e).astimezone(PACIFIC).date() == today:
            st["today_calls"] += 1
            st["today_usd"] += float(e.get("usd", 0))
        if balance is not None and _when(e) > _when(balance):
            st["spent_since"] += float(e.get("usd", 0))
    if balance is not None:
        st["left"] = float(balance["usd"]) - st["spent_since"]
        st["usable"] = st["left"] - float(balance.get("keep", 0.0))
        for e in every:
            if e.get("kind") == "call" and e.get("key") == UNKNOWN and _when(e) > _when(balance):
                st["unknown_since"][0] += 1
                st["unknown_since"][1] += float(e.get("usd", 0))
    for r in mine:
        if r.get("kind") != "reserve" or r["id"] in released or r["id"] == skip_reservation:
            continue
        if not _alive(r.get("pid")) or now - _when(r) > dt.timedelta(hours=RESERVE_HOURS):
            continue
        made = [e for e in calls if e.get("res") == r["id"]]
        open_calls = max(0, int(r["calls"]) - len(made))
        if open_calls:
            st["reserved_calls"] += open_calls
            st["reserved_usd"] += max(0.0, float(r["usd"]) - sum(float(e.get("usd", 0)) for e in made))
            st["reserved_by"].append((r.get("thread", "?"), open_calls))
    return st


def guard(model, size="", key=None):
    """Before one call: exits without sending once today's requests are spent or the key is at its stop point
    (counting what other running batches have reserved). The messages carry the phrases the batch tools already stop
    on for Google's own replies ("(429)", "per_day", "exceeded your current quota"; "(402)", "credits are depleted")."""
    if os.environ.get("GEMINI_OVERRUN") == "1":
        return
    st = state(key_id(key), skip_reservation=os.environ.get("GEMINI_RESERVATION", ""))
    if st["today_calls"] + st["reserved_calls"] >= st["cap"]:
        sys.exit(f"Gemini request not sent (429): today's {st['cap']:,} requests on the {label(st['key'])} are used "
                 f"or reserved (per_day count in the art spend ledger; exceeded your current quota until midnight "
                 f"Pacific). make art-spend shows who used them; GEMINI_OVERRUN=1 sends anyway.")
    if st["usable"] is not None and st["usable"] - st["reserved_usd"] < price(model, size):
        sys.exit(f"Gemini request not sent (402): the {label(st['key'])}'s credits are depleted down to the stop point "
                 f"the art spend ledger keeps ({_credit_line(st, True)}). Stop and report to the coordinator; after a "
                 f"top-up, record it with make art-spend BALANCE=<usd> KEEP=<usd>. GEMINI_OVERRUN=1 sends anyway.")


def preflight(calls, size="", what="", model=None):
    """Before a batch's first call: prints its cost and what's left, and exits before anything is sent if it would
    pass the key's stop point, today's requests or GEMINI_BUDGET. A batch that goes ahead reserves its calls until its
    process ends (or its next preflight)."""
    global _reservation
    if calls <= 0:
        return
    model = model or pinned_model()
    fp = key_id()
    if _reservation:
        _append({"kind": "release", "t": _stamp(), "key": fp, "id": _reservation})
        _reservation = ""
    sync_logs()
    st = state(fp)
    each = price(model, size)
    cost = calls * each
    requests_left = st["cap"] - st["today_calls"] - st["reserved_calls"]
    usable = None if st["usable"] is None else st["usable"] - st["reserved_usd"]
    held = f" ({', '.join(f'{t} holds {n}' for t, n in st['reserved_by'])})" if st["reserved_by"] else ""
    print(f"Gemini, {label(fp)}: {what + ', ' if what else ''}{calls} call{'s' if calls != 1 else ''} at "
          f"{size_key(size)}, about ${cost:.2f}. {_credit_line(st)}; {max(0, requests_left):,} of today's "
          f"{st['cap']:,} requests left{held}.", flush=True)
    if st["unknown_since"][0]:
        n, usd = st["unknown_since"]
        print(f"  Not counted: {n} calls (${usd:.2f}) since the balance was set came from worktrees whose scripts "
              f"predate the ledger; merging main into them counts their key.", flush=True)
    short = []
    if calls > requests_left:
        short.append(f"today's requests ({max(0, requests_left)} left)")
    if usable is not None and cost > usable:
        short.append(f"the stop point (about ${max(0.0, usable):.2f} to spend, {max(0, int(usable // each))} calls at "
                     f"this size)")
    if os.environ.get("GEMINI_BUDGET"):
        cap_left = int(os.environ["GEMINI_BUDGET"].rpartition(":")[2]) - used()
        if calls > cap_left:
            short.append(f"GEMINI_BUDGET ({max(0, cap_left)} calls left)")
    if short and os.environ.get("GEMINI_OVERRUN") != "1":
        sys.exit("Stopped before the first call: this batch would pass " + " and ".join(short) + ". Run fewer "
                 "(--only ...) or report to the coordinator; after a top-up, record it with make art-spend "
                 "BALANCE=<usd> KEEP=<usd>. GEMINI_OVERRUN=1 goes ahead anyway.")
    _reservation = f"{os.getpid()}-{_now().strftime('%H%M%S%f')}"
    _append({"kind": "reserve", "t": _stamp(), "key": fp, "id": _reservation, "pid": os.getpid(), "calls": calls,
             "usd": round(cost, 4), "thread": thread(), "what": what})
    os.environ["GEMINI_RESERVATION"] = _reservation


def _credit_line(st, inside=False):
    b = st["balance"]
    if b is None:
        line = "Credit not recorded (make art-spend BALANCE=<usd> KEEP=<usd>)"
    elif b.get("kind") == "depleted":
        line = f"No credit (Google said it was depleted, {_when(b).astimezone().strftime('%b %-d %H:%M')})"
    else:
        held = f", ${st['reserved_usd']:.2f} of it held by running batches" if st["reserved_usd"] else ""
        line = (f"About ${st['left']:.2f} of credit left (${float(b['usd']):.2f} on "
                f"{_when(b).astimezone().strftime('%b %-d %H:%M')}, ${st['spent_since']:.2f} spent since); art stops at "
                f"${float(b.get('keep', 0.0)):.2f}, so ${max(0.0, st['usable']):.2f} to spend{held}")
    return line[0].lower() + line[1:] if inside else line


# ---- the report ---------------------------------------------------------------------------------------------------

def report(days=7):
    added = sync_logs()
    every = entries()
    calls = [e for e in every if e.get("kind") == "call"]
    print(f"Gemini spend at Google's list prices (ledger: {ledger_path()})")
    if added:
        print(f"{added} calls read from worktrees' generation logs (scripts older than the ledger, key unknown).")
    keys = list(labelled())
    keys += sorted({str(e["key"]) for e in every if e.get("key") not in keys + [UNKNOWN, "none"]})
    for fp in keys:
        st = state(fp)
        print(f"\n{label(fp).capitalize()} ({fp}): {_credit_line(st)}.")
        if st["usable"] is not None:
            print("  That's about " + ", ".join(f"{int(max(0.0, st['usable']) // price(pinned_model(), s))} images at "
                                                f"{s}" for s in ("1K", "2K")) + ".")
        print(f"  Today (Pacific): {st['today_calls']:,} of {st['cap']:,} requests, ${st['today_usd']:.2f}.")
        for t, n in st["reserved_by"]:
            print(f"  Running batch: {t} holds {n} more calls.")
    names = {fp: ("" if label(fp) == "primary" else f" [{label(fp)}]") for fp in {str(e.get('key')) for e in calls}}
    by_day = {}
    for e in calls:
        day = _when(e).astimezone(PACIFIC).date()
        who = str(e.get("thread", "?")) + names[str(e.get("key"))]
        row = by_day.setdefault(day, {}).setdefault(who, [0, 0, 0.0])
        row[0] += 1
        row[1] += e.get("status") != "ok"
        row[2] += float(e.get("usd", 0))
    print()
    for day in sorted(by_day, reverse=True)[:days]:
        rows = by_day[day]
        n, bad, usd = (sum(r[i] for r in rows.values()) for i in range(3))
        print(f"{day}  {n:6,} calls  ${usd:8.2f}" + (f"  ({bad} failed)" if bad else ""))
        for who, (wn, wbad, wusd) in sorted(rows.items(), key=lambda kv: -kv[1][2]):
            print(f"  {who:36.36} {wn:6,}  ${wusd:8.2f}" + (f"  ({wbad} failed)" if wbad else ""))
    if calls:
        first = min(_when(e) for e in calls).astimezone(PACIFIC).date()
        print(f"\nSince {first}: {len(calls):,} calls, ${sum(float(e.get('usd', 0)) for e in calls):.2f}.")
    else:
        print("No calls yet.")


def main():
    p = argparse.ArgumentParser(description="The Gemini spend ledger: what was spent, by day and thread, and what's left.")
    p.add_argument("--days", type=int, default=7)
    p.add_argument("--key", default="", help="primary, backup or a fingerprint (default: the key in GEMINI_API_KEY)")
    p.add_argument("--balance", type=float, help="record the key's credit now, in dollars")
    p.add_argument("--keep", type=float, default=None, help="with --balance: the credit art leaves untouched")
    a = p.parse_args()
    if a.balance is not None:
        fp = resolve(a.key) if a.key else key_id()
        keep = a.keep if a.keep is not None else 0.0
        set_balance(a.balance, keep, fp)
        print(f"Recorded ${a.balance:.2f} of credit on the {label(fp)}, stopping art at ${keep:.2f}.\n")
    report(a.days)


if __name__ == "__main__":
    main()
