#!/usr/bin/env python3
"""Respells a name across the game's own text and carries its voice clips along (owner, 2026-10-12: the Wizard is
"Ratatouille", not "Ratatoille"; the recordings stay as they are).

Re-runnable: after merging a branch written before the change, run it again and it respells what that branch brought
(a run over text that's already right changes nothing). Lines a merge left in conflict are its to resolve first.

What changes: the shown name wherever the repo's tracked text files write it (dialogue, data, UI strings, docs, tests,
tools), as a whole word in its capitalised or capital-letter form. What stays:
  - ids, which are lowercase: `ratatoille` is the pregen, speaker, voice folder and art folder, and flags, nodes and
    file names are built from it;
  - records of what the art and voice services were sent: the two generation logs, and "Barovia Ratatoille", the
    ElevenLabs voice's name on the account, which audio/voice/casting.json and docs/voice/casting.md copy;
  - the golden saves in tests/saves: saves older builds wrote, which SaveSystem.upgrade respells on load
    (SaveSystem.RESPELLED holds the same pairs);
  - any line marked `respell: keep`, and this file.

Voice clips: a clip is keyed by its line's text (tools/audio/voice_lines.py), so a respelled line would lose its clip.
Each voiced line whose text changes moves its clip to the new key (git mv), with its manifest entry, its direction,
its generation-log entries (marked "rekeyed_from") and any keep_keys, so it plays as recorded and `make voice` never
makes it again, --recast included. Nothing is generated or re-recorded.

Usage: python3 tools/data/respell.py [--dry-run] [--check]
  --dry-run  say what would change, change nothing
  --check    exit 1 if any old spelling is left (changes nothing)
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "audio"))
import voice_lines  # noqa: E402

# Old spelling -> the name as it is spelled now. Each is matched as a whole word, capitalised and in capitals; the
# lowercase form is the id and is never touched. The extra mistypings weren't in the repo on 2026-10-12; they are
# here so a merged branch that has one is caught too.
RESPELL = {
    "Ratatoille": "Ratatouille",
    "Rataoille": "Ratatouille",
    "Ratatoile": "Ratatouille",
    "Ratatouile": "Ratatouille",
    "Ratatuille": "Ratatouille",
}
KEEP_PHRASES = ["Barovia Ratatoille"]   # the ElevenLabs voice's own name (audio/voice/casting.json)
KEEP_MARK = "respell: keep"
SKIP_FILES = {"art/generation_log.jsonl", "audio/voice/generation_log.jsonl", "tools/data/respell.py",
              "audio/voice/manifest.json"}   # the manifest is rekeyed below, text and key together
SKIP_DIRS = ("tests/saves/",)

VOICE = ROOT / "audio" / "voice"
MANIFEST = VOICE / "manifest.json"
DIRECTIONS = VOICE / "directions.json"
CASTING = VOICE / "casting.json"
LOG = VOICE / "generation_log.jsonl"

PAIRS = {}
for old, new in RESPELL.items():
    PAIRS[old] = new
    PAIRS[old.upper()] = new.upper()
WORD = re.compile(r"\b(" + "|".join(sorted(map(re.escape, PAIRS), key=len, reverse=True)) + r")\b")


def respell_line(line):
    """`line` with every old spelling replaced, except in a kept phrase or a line marked to keep."""
    if KEEP_MARK in line:
        return line
    kept = {}
    for i, phrase in enumerate(KEEP_PHRASES):
        if phrase in line:
            token = f"\0{i}\0"
            kept[token] = phrase
            line = line.replace(phrase, token)
    line = WORD.sub(lambda m: PAIRS[m.group(1)], line)
    for token, phrase in kept.items():
        line = line.replace(token, phrase)
    return line


def respell(text):
    return "".join(respell_line(line) for line in text.splitlines(keepends=True))


def git(*args, check=True):
    return subprocess.run(["git", *args], cwd=ROOT, check=check, capture_output=True, text=True).stdout


def files_with_old_spellings():
    """Tracked text files that hold an old spelling, as repo paths (git grep, so binary and LFS files are skipped)."""
    words = []
    for w in PAIRS:
        words += ["-e", w]
    out = subprocess.run(["git", "grep", "-l", "-I", "-w", "-F", *words], cwd=ROOT, capture_output=True, text=True)
    if out.returncode not in (0, 1):
        sys.exit(out.stderr)
    return [p for p in out.stdout.splitlines()
            if p not in SKIP_FILES and not p.startswith(SKIP_DIRS)]


def voice_moves():
    """[(speaker, old key, new key, new text)] for every voiced line the respelling changes."""
    moves = []
    for (speaker, key), e in sorted(voice_lines.lines().items()):
        new_text = respell(e["text"])
        if new_text != e["text"]:
            moves.append((speaker, key, voice_lines.key(new_text), new_text.strip()))
    return moves


def tracked(path):
    return git("ls-files", "--error-unmatch", str(path.relative_to(ROOT)), check=False) != ""


def dump(path, data, **kw):
    path.write_text(json.dumps(data, ensure_ascii=False, **kw) + "\n")


def same_format(path, **kw):
    """Whether rewriting `path` with json.dumps(**kw) would only change what we change (it was written that way)."""
    text = path.read_text()
    return json.dumps(json.loads(text), ensure_ascii=False, **kw) + "\n" == text


def move_clips(moves, dry):
    """Moves each clip, its manifest entry, direction, log entries and keep_keys from the old key to the new."""
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    directions = json.loads(DIRECTIONS.read_text()) if DIRECTIONS.exists() else {}
    for path, kw in ((MANIFEST, {"indent": 1, "sort_keys": True}), (DIRECTIONS, {"indent": 1, "sort_keys": True})):
        if path.exists() and not same_format(path, **kw):
            sys.exit(f"{path.relative_to(ROOT)} isn't written the way this expects; nothing changed")
    casting = CASTING.read_text()
    renamed = {}
    moved, missing, both = [], [], []
    for speaker, old, new, text in moves:
        src, dst = VOICE / speaker / f"{old}.mp3", VOICE / speaker / f"{new}.mp3"
        if not src.exists():
            missing.append(f"{speaker}/{old}")   # never voiced: the text alone changes
            continue
        if dst.exists():
            both.append(f"{speaker}/{old}")      # the new text has a clip already: the old one waits for --prune
            continue
        moved.append((speaker, old, new))
        renamed[(speaker, old)] = new
        if dry:
            continue
        if tracked(src):
            git("mv", str(src.relative_to(ROOT)), str(dst.relative_to(ROOT)))
        else:
            src.rename(dst)
        sidecar = src.with_name(src.name + ".import")   # Godot's import settings: untracked, made again by make import
        if sidecar.exists() and not tracked(sidecar):
            sidecar.unlink()
        entry = manifest.pop(f"{speaker}/{old}", None)
        if entry is not None:
            manifest[f"{speaker}/{new}"] = {**entry, "text": text, "chars": len(text)}
        if old in directions.get(speaker, {}):
            directions[speaker][new] = directions[speaker].pop(old)
        casting = casting.replace(f'"{old}"', f'"{new}"')
    if renamed and not dry:
        dump(MANIFEST, manifest, indent=1, sort_keys=True)
        if directions:
            dump(DIRECTIONS, directions, indent=1, sort_keys=True)
        CASTING.write_text(casting)
        if LOG.exists():
            out = []
            for raw in LOG.read_text().splitlines(keepends=True):
                e = json.loads(raw) if raw.strip() else None
                new = renamed.get((e.get("speaker"), e.get("key"))) if e else None
                if new:
                    e = {**e, "key": new, "rekeyed_from": e["key"]}
                    raw = json.dumps(e, ensure_ascii=False) + "\n"
                out.append(raw)
            LOG.write_text("".join(out))
    return moved, missing, both


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--check", action="store_true")
    a = p.parse_args()

    files = files_with_old_spellings()
    changes = {}
    for rel in files:
        path = ROOT / rel
        text = path.read_text(encoding="utf-8")
        new = respell(text)
        if new != text:
            changes[rel] = (new, sum(1 for x, y in zip(text.splitlines(), new.splitlines()) if x != y))
    if a.check:
        for rel, (_, n) in sorted(changes.items()):
            print(f"{rel}: {n} line(s) with an old spelling")
        sys.exit(1 if changes else 0)

    moves = voice_moves()   # before the text changes: the old keys come from the old text
    for rel, (new, n) in sorted(changes.items()):
        print(f"{'would respell' if a.dry_run else 'respelled'} {n:4d} line(s)  {rel}")
        if not a.dry_run:
            (ROOT / rel).write_text(new, encoding="utf-8")
    moved, missing, both = move_clips(moves, a.dry_run)
    for speaker, old, new in moved:
        print(f"{'would move' if a.dry_run else 'moved'} clip {speaker}/{old}.mp3 -> {new}.mp3")
    print(f"{len(changes)} file(s), {sum(n for _, n in changes.values())} line(s); {len(moves)} voiced line(s) change: "
          f"{len(moved)} clip(s) {'to move' if a.dry_run else 'moved'}, {len(missing)} never voiced"
          + (f", {len(both)} voiced under the new text already (make voice PRUNE=1 drops the old): {both}"
             if both else ""))
    if a.dry_run or not moved:
        return
    # Every moved clip must be reachable from its line's new text, as the game looks it up.
    now = voice_lines.lines()
    lost = [f"{s}/{n}" for s, _, n in moved if (s, n) not in now]
    if lost:
        sys.exit(f"moved clips that no line reaches now: {lost}")


if __name__ == "__main__":
    main()
