#!/usr/bin/env python3
"""Generates the voice clips that are missing (ADR 0013): make voice [SPEAKER="narrator ..."] [LIMIT=n] [DRY=1]

For every voiced line (tools/audio/voice_lines.py) whose speaker has a voice in audio/voice/casting.json and whose
clip audio/voice/<speaker>/<key>.mp3 doesn't exist yet, asks ElevenLabs for it with the pinned model, output format
and the speaker's settings, saves it, records it in audio/voice/manifest.json and logs the call (characters, voice,
model, estimated cost) to audio/voice/generation_log.jsonl. Lines already voiced are never paid for twice.

--max-usd stops a run whose estimate is higher (default 5); --recast regenerates a speaker's clips made with another
voice, model or settings; --prune deletes clips no line uses any more (an edited or deleted line).

Each clip's model is recorded in the manifest. A speaker who moved to a new model keeps their older clips (owner,
2026-10-07: v3 for new lines of every non-minor character, the old v4 lines kept for now): casting.json names the
model they came from as `earlier_model`, --models counts every speaker's clips by model, and
`make voice SPEAKER=<id> RECAST=1` re-voices a speaker's older clips on their current model.
"""
import argparse
import hashlib
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import elevenlabs as el  # noqa: E402
import voice_lines  # noqa: E402

MANIFEST = el.VOICE_DIR / "manifest.json"


def settings_for(c, speaker):
    return {**c["default_settings"], **(c["voices"][speaker].get("settings", {}))}


def voice_id(c, speaker):
    """The ElevenLabs voice that speaks for `speaker` ("shares" borrows another speaker's, as the Mad Mage does
    Mordenkainen's); "" when none is cast, or when it was released (deleted from the account after its lines were
    made, so its clips stay but new lines need a new voice)."""
    v = c["voices"].get(speaker, {})
    if v.get("shares"):
        return voice_id(c, v["shares"])
    return "" if v.get("released") else v.get("voice_id", "")


def accent_tag(c, speaker):
    """An audio tag sent before every line the speaker says, such as "[strong Romanian accent]" (owner, 2026-10-06:
    the accent asked for in a voice's design doesn't survive generation on its own). It isn't spoken, and it isn't
    part of the clip's key."""
    v = c["voices"].get(speaker, {})
    return accent_tag(c, v["shares"]) if v.get("shares") else v.get("accent_tag", "")


def spoken(c, speaker, text):
    tag = accent_tag(c, speaker)
    return f"{tag} {text}" if tag else text


def model_for(c, speaker):
    """The speaker's own model if casting.json names one (owner, 2026-10-07: eleven_v3 keeps the Eastern European
    accents that eleven_v4 flattens), else the pinned default."""
    v = c["voices"].get(speaker, {})
    return model_for(c, v["shares"]) if v.get("shares") else v.get("model", c["model"])


PRICE_PER_1K = {"eleven_v3": 0.08, "eleven_multilingual_v2": 0.08}


def price(c, speaker):
    return PRICE_PER_1K.get(model_for(c, speaker), float(c["price_per_1k_usd"]))


def recipe(c, speaker, model=None):
    """What makes a clip: a change here means the speaker's clips are out of date (--recast). `model` asks what the
    recipe was on another model (a speaker's earlier one)."""
    blob = [voice_id(c, speaker), model or model_for(c, speaker), c["output_format"], settings_for(c, speaker)]
    if accent_tag(c, speaker):
        blob.append(accent_tag(c, speaker))
    return hashlib.sha1(json.dumps(blob, sort_keys=True).encode()).hexdigest()[:10]


def clip_model(c, speaker, entry):
    """The model a manifest entry's clip was made on: as recorded, else read from its recipe (the current model's or
    the speaker's earlier one), else "unknown"."""
    if entry.get("model"):
        return entry["model"]
    for m in (model_for(c, speaker), c["voices"].get(speaker, {}).get("earlier_model")):
        if m and entry.get("recipe") == recipe(c, speaker, m):
            return m
    return "unknown"


def report_models(c, manifest, speakers):
    """Each speaker's clips by model, flagging those not on the speaker's current model (what --recast would redo)."""
    counts = {}
    for k, entry in manifest.items():
        speaker = k.split("/")[0]
        if speakers and speaker not in speakers or speaker not in c["voices"]:
            continue
        m = clip_model(c, speaker, entry)
        counts.setdefault(speaker, {}).setdefault(m, [0, 0])
        counts[speaker][m][0] += 1
        counts[speaker][m][1] += int(entry.get("chars", 0))
    for speaker in sorted(counts):
        now = model_for(c, speaker)
        parts = [f"{m} {n:,} clips ({ch:,} chars)" + ("" if m == now else " <- older") for m, (n, ch) in sorted(counts[speaker].items())]
        print(f"{speaker:28} now {now}: " + "; ".join(parts))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--speaker", nargs="*", default=[])
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--max-usd", type=float, default=5.0)
    p.add_argument("--workers", type=int, default=4)
    p.add_argument("--recast", action="store_true")
    p.add_argument("--prune", action="store_true")
    p.add_argument("--models", action="store_true", help="count each speaker's clips by the model that made them")
    a = p.parse_args()

    c = el.casting()
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    every = voice_lines.lines()

    if a.models:
        report_models(c, manifest, a.speaker)
        return

    if a.prune:
        live = {f"{s}/{k}" for s, k in every}
        gone = [f for f in sorted(el.VOICE_DIR.glob("*/*.mp3")) if f"{f.parent.name}/{f.stem}" not in live]
        for f in gone:
            f.unlink()
            manifest.pop(f"{f.parent.name}/{f.stem}", None)
            print(f"pruned {f.relative_to(el.ROOT)}")
        MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
        print(f"{len(gone)} clip(s) pruned")
        return

    cast = {s for s in c["voices"] if voice_id(c, s)}
    todo, uncast = [], set()
    for (speaker, key), line in sorted(every.items(), key=lambda kv: (kv[0][0], kv[1]["sources"][0])):
        if a.speaker and speaker not in a.speaker:
            continue
        if speaker not in cast:
            uncast.add(speaker)
            continue
        out = el.VOICE_DIR / speaker / f"{key}.mp3"
        stale = a.recast and manifest.get(f"{speaker}/{key}", {}).get("recipe") != recipe(c, speaker)
        if not out.exists() or stale:
            todo.append(line)
    if a.limit:
        todo = todo[:a.limit]
    chars = sum(len(t["text"]) for t in todo)
    usd = sum(len(t["text"]) / 1000 * price(c, t["speaker"]) for t in todo)
    print(f"{len(todo)} clip(s) to generate, {chars:,} characters, about ${usd:.2f} at ${c['price_per_1k_usd']}/1K "
          f"({c['model']})" + (f"; no voice cast yet for {len(uncast)} speaker(s)" if uncast else ""))
    if a.dry_run or not todo:
        return
    if usd > a.max_usd:
        sys.exit(f"Estimate ${usd:.2f} is over --max-usd {a.max_usd:.2f}; raise it to go ahead.")

    lock = threading.Lock()
    done = [0, 0]

    def one(line):
        speaker, key, text = line["speaker"], line["key"], line["text"]
        vid = voice_id(c, speaker)
        audio, headers = el.tts(vid, spoken(c, speaker, text), model_for(c, speaker), c["output_format"], settings_for(c, speaker))
        out = el.VOICE_DIR / speaker / f"{key}.mp3"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(audio)
        cost = headers.get("character-cost") or headers.get("x-character-count")
        with lock:
            manifest[f"{speaker}/{key}"] = {"text": text, "recipe": recipe(c, speaker), "chars": len(text),
                                             "model": model_for(c, speaker)}
            el.log({"speaker": speaker, "key": key, "chars": len(text), "voice_id": vid, "model": model_for(c, speaker),
                    "format": c["output_format"], **({"accent_tag": accent_tag(c, speaker)} if accent_tag(c, speaker) else {}),
                    "usd_est": round(len(text) / 1000 * price(c, speaker), 5),
                    **({"billed_chars": cost} if cost else {}), "request_id": headers.get("request-id", "")})
            done[0] += 1
            done[1] += len(text)
            if done[0] % 50 == 0:
                MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
                print(f"  {done[0]}/{len(todo)} clips, {done[1]:,} characters")

    failed = []
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        futures = {pool.submit(one, t): t for t in todo}
        for f in as_completed(futures):
            if f.exception() is not None:
                failed.append((futures[f], f.exception()))
    MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
    print(f"Generated {done[0]} clip(s), {done[1]:,} characters, about "
          f"${done[1] / 1000 * float(c['price_per_1k_usd']):.2f}")
    for t, e in failed[:10]:
        print(f"  FAILED {t['speaker']}/{t['key']}: {e}")
    if failed:
        sys.exit(f"{len(failed)} clip(s) failed; run again to retry them")


if __name__ == "__main__":
    main()
