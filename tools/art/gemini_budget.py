"""A shared cap on Gemini calls for a batch run (the project's key allows 1,000 image requests a day, refusals and
errors included, split between threads).

Set GEMINI_BUDGET=<counter file>:<max calls> and every call made through tools/art/anim_keyframes.py or
tools/art/new_creatures.py takes one from the counter first; once it's spent they stop instead of calling. The
counter is a plain number in the file, shared by every process that names the same file (file-locked).
"""
import fcntl
import os
from pathlib import Path


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
