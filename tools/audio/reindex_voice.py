#!/usr/bin/env python3
"""Rebuilds audio/voice/manifest.json from the clips on disk and audio/voice/generation_log.jsonl (ADR 0013).

Two `make voice` runs at once each write the manifest they started with, so the last one to finish drops the
other's entries; the clips and the log are always complete. This puts the manifest back: every clip on disk, with
the text of the line it voices, the recipe (voice, model, format, settings) the log says made it, and its model and
direction (audio/voice/directions.json) as logged."""
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import elevenlabs as el  # noqa: E402
import voice_lines  # noqa: E402
from generate_voice import MANIFEST, settings_for  # noqa: E402


def main():
    c = el.casting()
    made = {}
    if el.LOG.exists():
        for raw in el.LOG.read_text().splitlines():
            e = json.loads(raw)
            if "key" in e:
                made[f"{e['speaker']}/{e['key']}"] = e
    lines = {f"{s}/{k}": e for (s, k), e in voice_lines.lines().items()}
    old = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    manifest, unknown = {}, []
    for f in sorted(el.VOICE_DIR.glob("*/*.mp3")):
        clip = f"{f.parent.name}/{f.stem}"
        text = lines[clip]["text"] if clip in lines else old.get(clip, {}).get("text")
        if text is None:
            unknown.append(clip)
            continue
        e = made.get(clip, {})
        blob = [e.get("voice_id", ""), e.get("model", c["model"]), e.get("format", c["output_format"]),
                settings_for(c, f.parent.name) if f.parent.name in c["voices"] else c["default_settings"]]
        if e.get("accent_tag"):
            blob.append(e["accent_tag"])
        recipe = hashlib.sha1(json.dumps(blob, sort_keys=True).encode()).hexdigest()[:10]
        manifest[clip] = {"text": text, "recipe": recipe, "chars": len(text),
                          **({"model": e["model"]} if e.get("model") else {}),
                          **({"direction": e["direction"]} if e.get("direction") else {})}
    MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
    print(f"{len(manifest)} clips indexed" + (f"; {len(unknown)} clip(s) voice no current line: {unknown[:5]}" if unknown else ""))


if __name__ == "__main__":
    main()
