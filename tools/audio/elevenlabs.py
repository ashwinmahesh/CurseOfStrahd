"""ElevenLabs API calls for the voice pipeline (ADR 0013). Stdlib only.

The key comes from ELEVENLABS_API_KEY (read from ~/.zshrc if the shell doesn't have it, like GEMINI_API_KEY in
tools/art/generate_gemini.py) and is sent as the xi-api-key header, never in a URL, a file or a log.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API = "https://api.elevenlabs.io"
VOICE_DIR = ROOT / "audio" / "voice"
CASTING = VOICE_DIR / "casting.json"
LOG = VOICE_DIR / "generation_log.jsonl"


def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        rc = Path.home() / ".zshrc"
        if rc.exists():
            m = re.search(r"^export ELEVENLABS_API_KEY=['\"]?([^'\"\n]+)", rc.read_text(), re.M)
            key = m.group(1) if m else None
    if not key:
        sys.exit("ELEVENLABS_API_KEY is not set (add `export ELEVENLABS_API_KEY=...` to ~/.zshrc)")
    return key


def request(method, path, body=None, query="", accept="application/json", tries=4):
    """Returns (bytes, headers). Retries rate limits and server errors with backoff."""
    url = f"{API}{path}{('?' + query) if query else ''}"
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(tries):
        req = urllib.request.Request(url, data=data, method=method, headers={
            "xi-api-key": api_key(), "Content-Type": "application/json", "Accept": accept})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read(), dict(r.headers)
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            if e.code in (429, 500, 502, 503, 504) and attempt < tries - 1:
                time.sleep(2 ** (attempt + 1))
                continue
            try:
                detail = json.dumps(json.loads(detail).get("detail", detail))
            except ValueError:
                pass
            raise RuntimeError(f"ElevenLabs {method} {path} failed ({e.code}): {detail[:400]}") from None
        except urllib.error.URLError as e:
            if attempt < tries - 1:
                time.sleep(2 ** (attempt + 1))
                continue
            raise RuntimeError(f"ElevenLabs {method} {path} failed: {e.reason}") from None


def get_json(path, query=""):
    raw, _ = request("GET", path, query=query)
    return json.loads(raw)


def tts(voice_id, text, model, output_format, settings, seed=None):
    """Speech for one line: (mp3 bytes, headers)."""
    body = {"text": text, "model_id": model, "voice_settings": settings}
    if seed is not None:
        body["seed"] = seed
    return request("POST", f"/v1/text-to-speech/{voice_id}", body, f"output_format={output_format}", "audio/mpeg")


def casting():
    return json.loads(CASTING.read_text())


def save_casting(c):
    CASTING.write_text(json.dumps(c, indent=2, ensure_ascii=False) + "\n")


def log(entry):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a") as f:
        f.write(json.dumps({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), **entry}, ensure_ascii=False) + "\n")
