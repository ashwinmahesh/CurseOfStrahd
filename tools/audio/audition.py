#!/usr/bin/env python3
"""Casting voices for the voice pipeline (ADR 0012). Auditions go to captures/voice_auditions/<speaker>/ (not in git).

  audition.py voices [--search old]                      the voices on the account (premade and saved)
  audition.py design <speaker> "<description>" [--text T] three new voices from a description (Voice Design)
  audition.py sample <speaker> <voice_id> [--text T]     a voice reading the sample with the pinned model
  audition.py keep <speaker> <generated_voice_id> "<name>" "<description>"
                                                         saves a designed voice to the account and casts it
  audition.py cast <speaker> <voice_id> [--name N]       casts an existing voice in audio/voice/casting.json
  audition.py auto <speaker> ...                         designs a voice from the casting description with a short
                                                         sample, saves the first take and casts it (minor parts)
  audition.py release <speaker> ...                      deletes the speaker's voice from the account once its lines
                                                         are made (frees a slot; the clips stay; new lines need a recast)

The default sample is three of the speaker's own lines (the Narrator's from docs/voice/narrator.md).
"""
import argparse
import base64
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import elevenlabs as el  # noqa: E402
import voice_lines  # noqa: E402

OUT = el.ROOT / "captures" / "voice_auditions"
NARRATOR_SAMPLE = ("The road narrows, the trees lean closer, and the fog behind you thickens like a door swinging shut. "
                   "A portrait of a handsome family. The painter gave everyone kind eyes; you suspect that was a "
                   "commission. The house is quiet now. It has the stillness of something that has been fed.")


def sample_text(speaker, given):
    if given:
        return given
    if speaker == voice_lines.NARRATOR:
        return NARRATOR_SAMPLE
    own = sorted((e["text"] for e in voice_lines.lines().values() if e["speaker"] == speaker), key=len, reverse=True)
    text = ""
    for t in own:
        if len(text) + len(t) > 600:
            continue
        text = f"{text} {t}".strip()
        if len(text) > 300:
            break
    return text


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("voices")
    s.add_argument("--search", default="")
    s = sub.add_parser("design")
    s.add_argument("speaker")
    s.add_argument("description")
    s.add_argument("--text", default="")
    s.add_argument("--model", default="eleven_ttv_v3")
    s.add_argument("--tag", default="")
    s = sub.add_parser("sample")
    s.add_argument("speaker")
    s.add_argument("voice_id")
    s.add_argument("--text", default="")
    s.add_argument("--tag", default="")
    s = sub.add_parser("keep")
    s.add_argument("speaker")
    s.add_argument("generated_voice_id")
    s.add_argument("name")
    s.add_argument("description")
    s = sub.add_parser("auto")
    s.add_argument("speakers", nargs="+")
    s = sub.add_parser("release")
    s.add_argument("speakers", nargs="+")
    s = sub.add_parser("cast")
    s.add_argument("speaker")
    s.add_argument("voice_id")
    s.add_argument("--name", default="")
    a = p.parse_args()

    if a.cmd == "voices":
        data = el.get_json("/v2/voices", f"page_size=100&search={a.search}" if a.search else "page_size=100")
        for v in data.get("voices", []):
            labels = ", ".join(f"{k}: {x}" for k, x in (v.get("labels") or {}).items())
            print(f"{v['voice_id']}  {v['name']:28s} {v.get('category', ''):12s} {labels}")
        return

    if a.cmd == "auto":
        for speaker in a.speakers:
            auto(speaker)
        return
    if a.cmd == "release":
        for speaker in a.speakers:
            release(speaker)
        return

    out = OUT / getattr(a, "speaker", "")
    out.mkdir(parents=True, exist_ok=True)
    if a.cmd == "design":
        text = sample_text(a.speaker, a.text)
        raw, _ = el.request("POST", "/v1/text-to-voice/design", {"voice_description": a.description, "model_id": a.model,
                                                                "text": text}, "output_format=mp3_44100_64")
        data = json.loads(raw)
        record = out / "designs.json"
        designs = json.loads(record.read_text()) if record.exists() else []
        for i, prev in enumerate(data.get("previews", [])):
            name = f"design{('_' + a.tag) if a.tag else ''}_{len(designs) + 1}.mp3"
            (out / name).write_bytes(base64.b64decode(prev["audio_base_64"]))
            designs.append({"file": name, "generated_voice_id": prev["generated_voice_id"], "description": a.description,
                            "model": a.model})
            print(f"{out / name}  generated_voice_id={prev['generated_voice_id']}")
        record.write_text(json.dumps(designs, indent=1) + "\n")
        el.log({"audition": "design", "speaker": a.speaker, "chars": len(text), "model": a.model,
                "previews": len(data.get("previews", []))})
    elif a.cmd == "sample":
        c = el.casting()
        text = sample_text(a.speaker, a.text)
        audio, headers = el.tts(a.voice_id, text, c["model"], c["output_format"], c["default_settings"])
        name = f"sample_{a.tag or a.voice_id}.mp3"
        (out / name).write_bytes(audio)
        el.log({"audition": "sample", "speaker": a.speaker, "voice_id": a.voice_id, "chars": len(text),
                "model": c["model"], "request_id": headers.get("request-id", "")})
        print(out / name)
    elif a.cmd == "keep":
        raw, _ = el.request("POST", "/v1/text-to-voice", {"voice_name": a.name, "voice_description": a.description,
                                                         "generated_voice_id": a.generated_voice_id})
        voice_id = json.loads(raw)["voice_id"]
        cast(a.speaker, voice_id, a.name, a.description)
        print(f"Saved {a.name} as {voice_id} and cast it for {a.speaker}")
    elif a.cmd == "cast":
        cast(a.speaker, a.voice_id, a.name, "")
        print(f"Cast {a.voice_id} for {a.speaker}")


def auto(speaker):
    """A minor part: one Voice Design call with a short sample of the speaker's own lines (Voice Design bills the
    sample's characters), the first take saved and cast. The preview is kept with the auditions for review."""
    c = el.casting()
    v = c["voices"][speaker]
    own = sorted((e["text"] for e in voice_lines.lines().values() if e["speaker"] == speaker), key=len, reverse=True)
    text = next((t for t in own if 100 <= len(t) <= 260), "")
    if not text:
        joined = ""
        for t in own:
            joined = f"{joined} {t}".strip()
            if len(joined) >= 100:
                break
        text = joined if 100 <= len(joined) <= 400 else ""
    body = {"voice_description": v["description"], "model_id": "eleven_ttv_v3", "guidance_scale": 7}
    body.update({"text": text} if text else {"auto_generate_text": True})
    raw, _ = el.request("POST", "/v1/text-to-voice/design", body, "output_format=mp3_44100_64")
    prev = json.loads(raw)["previews"][0]
    out = OUT / speaker
    out.mkdir(parents=True, exist_ok=True)
    (out / "auto.mp3").write_bytes(base64.b64decode(prev["audio_base_64"]))
    el.log({"audition": "design", "speaker": speaker, "chars": len(text), "model": "eleven_ttv_v3", "previews": 1})
    name = f"Barovia {speaker}"
    raw, _ = el.request("POST", "/v1/text-to-voice", {"voice_name": name, "voice_description": v["description"][:500],
                                                     "generated_voice_id": prev["generated_voice_id"]})
    cast(speaker, json.loads(raw)["voice_id"], name, "")
    print(f"{speaker}: designed and cast ({len(text)} sample characters)")


def release(speaker):
    c = el.casting()
    v = c["voices"][speaker]
    if v.get("voice_id") and not v.get("released"):
        el.request("DELETE", f"/v1/voices/{v['voice_id']}")
        v["released"] = True
        el.save_casting(c)
        print(f"{speaker}: voice {v['voice_id']} deleted from the account; its clips stay")


def cast(speaker, voice_id, name, description):
    c = el.casting()
    v = c["voices"].setdefault(speaker, {})
    v["voice_id"] = voice_id
    if name:
        v["name"] = name
    if description:
        v["description"] = description
    el.save_casting(c)


if __name__ == "__main__":
    main()
