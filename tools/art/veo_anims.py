#!/usr/bin/python3
"""The six heroes' walk, idle, attack and cast from video clips: Veo 3.1 until it shut down on 2026-10-22, Gemini Omni
since (owner 2026-10-19, docs/art/animation.md "Veo").

    /usr/bin/python3 tools/art/veo_anims.py [--only id ...] [--kinds walk idle attack cast] [--dirs s se e ne n]
        [--generate] [--redo kind_dir ...] [--sheets] [--review]

--generate  asks Gemini Omni (image to video, a flat green or cyan background) for every clip that isn't in
            art/generated/veo/<id>/ yet: one clip per kind and drawn direction (4 seconds for a walk or idle, 3 for an
            attack, cast or flinch), starting from that direction's first frame in the hero's current sheet. Calls are counted in the shared Gemini ledger (tools/art/gemini_budget.py) and stop
            at the key's stop point. --redo names clips to draw again (e.g. attack_ne).
--sheets    turns the clips into the sheets the game plays (walk.png/.tres with walk_ and idle_, attack, cast): every
            frame keyed off the green, cut to the hero's cell, snapped to the palette like the drawn sheets, and the
            animation chosen from the clip (a walk or idle loop, an attack or cast from guard to guard with the blow on
            the sheet's hit frame), then trimmed and packed as render_keys.py packs.
--review    writes a contact sheet per hero and kind to art/generated/veo/<id>/review_<kind>.png.

Clips are 720x1280 (9:16) at 24 fps. The first frame puts the sheet's cell centre at (360, 776), so a clip's pixels are
the sheet's pixels: no scaling, and the figure keeps its size and ground line. Frames are decoded with macOS's own
AVFoundation (tools/art/veo_frames.swift), so nothing needs installing. PIL only (/usr/bin/python3).
"""
import argparse
import base64
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageMath, ImageStat

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import gemini_budget as gb  # noqa: E402

HEROES = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot", "kip_smudgewick"]
KINDS = ["walk", "idle", "attack", "cast", "hurt"]
DIRS = ["s", "se", "e", "ne", "n"]          # the drawn directions; the sheets show nw, w and sw as mirror images
SHE = {"liriel_dawnsong", "thistle"}
# Veo 3.1 (Lite, Fast and standard) shut down on 2026-10-22; its replacement is Gemini Omni Flash, called through the
# Interactions API: an image (or two) and a prompt in, a video out. It takes no length: the prompt says how long, and a
# clip costs about $0.10 a second at 720p (gemini_budget.PRICES). Clips made on Veo keep their model's name in clips.json
# (Godrick's and Liriel's swings and Ratatouille's cast were Veo Fast, everything else Veo Lite).
MODEL = "gemini-omni-1.1-flash"
MODEL_OF = {}           # a kind to make on another model
MODEL_FOR = {}          # a (hero, kind) to make on another model
# Sheets the owner keeps as they are, whatever clips there are (owner 2026-10-20: Godrick's and Liriel's casts with their
# effects, his the first Veo one, hers the drawn one).
KEEP = {("godrick_pendlebrook", "cast"), ("liriel_dawnsong", "cast")}
SECONDS = 4
# Attacks, casts and flinches are 3-second clips that end on their first frame (the first image sent twice, as first and
# last frame): without it Veo often turned a hero seen from behind round to face the camera, or left him in another pose
# than he started from. They are asked for in real time: Veo's 8-second ones ran the motion in slow motion.
ONE_SHOT_SECONDS = 3
FPS = 24
W, H = 720, 1280
CENTRE = (360, 776)                         # where a sheet's cell centre sits in a clip
# Attacks and casts reach wider than a 720-wide clip at the sheet's scale (a sword swung out to the side), so their
# first frame is drawn at ONE_SHOT_SCALE and the clip's frames are scaled back up.
ONE_SHOT_SCALE = 0.8
# Frames are worked on in a canvas big enough for that, with the cell centre at WORK_CENTRE.
WORK = (1200, 1700)
WORK_CENTRE = (600, 1000)
# The flat background each hero is filmed on, keyed out again: green, except for heroes who wear green (Kip's coat,
# Thistle's moss), who stand on cyan, a hue none of the six has (Godrick's clips were made on green first).
SCREENS = {"green": (0, 177, 64), "cyan": (0, 190, 190)}
SCREEN_OF = {"kip_smudgewick": "cyan", "thistle": "cyan"}
OUT = ROOT / "art" / "generated" / "veo"
API = "https://generativelanguage.googleapis.com/v1beta"
SHEET_OF = {"walk": "walk", "idle": "walk", "attack": "attack", "cast": "cast", "hurt": "hurt"}
# What each kind becomes: frames, playback fps, and for the one-shots the frame the blow (or the spell) lands on.
WALK_FRAMES, WALK_FPS = 24, 24.0            # one cycle (two steps) a second at the sheet's own pace
IDLE_FPS = 6.0
IDLE_LOOP = (36, 72)                        # 1.5 to 3 s of the clip: 9 to 18 frames
SEAM = 8                                    # clip frames an idle loop's end is faded into its start over
# Every swing feels heavy (owner 2026-10-19/20: "make weapon swings feel heavier"): a longer wind-up eased so it
# gathers slowly and the blow comes fast (WINDUP_EASE), the impact frame held (IMPACT_HOLD frames), then the recovery.
ATTACK_FRAMES, ATTACK_HIT, ATTACK_FPS = 18, 11, 16.0
WINDUP_EASE = 1.6
IMPACT_HOLD = 2.0
# A cast plays for 1.5 s (owner 2026-10-25: "It should be like 1.5 seconds"): 24 frames at 16 fps. It had been 12 frames at 16
# fps, 0.75 s, which squeezed five or six seconds of slow Veo video into less than a second.
CAST_FRAMES, CAST_HIT, CAST_FPS = 24, 8, 16.0
HURT_FRAMES, HURT_PEAK, HURT_FPS = 8, 2, 16.0     # a flinch and back (the hurt sheet's die_ and down_ stay drawn)
# A hero whose attack needs other timing: (frames, hit frame, fps).
ATTACK_TIMING = {
    # Godrick's swing plays 1.3x faster than the others' (owner 2026-10-24: "about 1.3x faster"): 16 fps x 1.3.
    "godrick_pendlebrook": (ATTACK_FRAMES, ATTACK_HIT, 20.8),
}
PAD = 12                                    # border kept round each trimmed frame (the shader's outline)
CLIPS_LOCK = threading.Lock()


# ---- the hero's current sheets -------------------------------------------------------------------------------------

def read_tres(path):
    """A sheet's SpriteFrames: {anim: [(sub id, duration)]}, speeds, {sub id: (region, margin)} and its metadata."""
    t = path.read_text()
    subs = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="(\w+)"\]\s*atlas = ExtResource\("1"\)\s*'
                         r'region = Rect2\(([^)]*)\)(?:\s*margin = Rect2\(([^)]*)\))?', t):
        reg = [int(float(v)) for v in m.group(2).split(",")]
        mar = [int(float(v)) for v in m.group(3).split(",")] if m.group(3) else [0, 0, 0, 0]
        subs[m.group(1)] = (reg, mar)
    anims, speeds, loops = {}, {}, {}
    block = t.split("animations = [", 1)[1]
    for a in re.finditer(r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"(\w+)",\s*"speed": ([\d.]+)',
                         block, re.S):
        loops[a.group(3)] = a.group(2) == "true"
        anims[a.group(3)] = [(sid, float(d)) for d, sid in
                             re.findall(r'"duration": ([\d.]+),\s*"texture": SubResource\("(\w+)"\)', a.group(1))]
        speeds[a.group(3)] = float(a.group(4))
    meta = {k: json.loads(v) for k, v in re.findall(r"^metadata/(\w+) = (.*)$", t, re.M)}
    READ_LOOPS[str(path)] = loops
    return anims, speeds, subs, meta


READ_LOOPS = {}


def sheet_frame(hero, kind, d, index=0):
    """One frame of the hero's current sheet as a full cell (RGBA) and the cell's size."""
    sheet = SHEET_OF[kind]
    anims, _speeds, subs, _meta = read_tres(ROOT / "art" / "sprites" / hero / f"{sheet}.tres")
    sid = anims[f"{kind}_{d}"][index][0]
    (x, y, w, h), (ml, mt, mw, mh) = subs[sid]
    src = Image.open(ROOT / "art" / "sprites" / hero / f"{sheet}.png").convert("RGBA")
    cell = Image.new("RGBA", (w + mw, h + mh), (0, 0, 0, 0))
    cell.paste(src.crop((x, y, x + w, y + h)), (ml, mt))
    return cell


ONE_SHOTS = ("attack", "cast", "hurt")


def model_of(kind, hero=""):
    return MODEL_FOR.get((hero, kind), MODEL_OF.get(kind, MODEL))


def seconds_of(kind):
    # The flinch too: 4-second flinches without a last frame had Godrick draw his sword, turn round and throw sparks.
    return ONE_SHOT_SECONDS if kind in ONE_SHOTS else SECONDS


def size_of(kind):
    return f"720p-{seconds_of(kind)}s"


def source_of(kind):
    """The sheet animation a clip starts (and, for 8-second clips, ends) on. A cast starts from standing: the drawn
    cast's first frame holds a glowing orb, and the clips are motions only. A flinch starts from standing too: the drawn
    flinch's first frame is already a crouch."""
    return "idle" if kind in ("cast", "hurt") else kind


def scale_of(kind):
    return ONE_SHOT_SCALE if kind in ONE_SHOTS else 1.0


def screen_of(hero):
    return SCREEN_OF.get(hero, "green")


def first_frame(hero, kind, d):
    """The clip's first frame: the sheet's frame on the hero's flat screen colour, its cell centred on CENTRE."""
    path = OUT / hero / f"{kind}_{d}_first.png"
    if not path.exists():
        cell = sheet_frame(hero, source_of(kind), d)
        s = scale_of(kind)
        if s != 1.0:
            cell = cell.resize((round(cell.width * s), round(cell.height * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), SCREENS[screen_of(hero)] + (255,))
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        layer.paste(cell, (CENTRE[0] - cell.width // 2, CENTRE[1] - cell.height // 2))
        canvas.alpha_composite(layer)
        path.parent.mkdir(parents=True, exist_ok=True)
        canvas.convert("RGB").save(path)
        with CLIPS_LOCK:
            log = OUT / hero / "firsts.json"
            firsts = json.loads(log.read_text()) if log.exists() else {}
            bb = sheet_frame(hero, source_of(kind), d).getchannel("A").getbbox()
            firsts[f"{kind}_{d}"] = {"scale": s, "height": bb[3] - bb[1]}
            log.write_text(json.dumps(firsts, indent=1) + "\n")
    return path


def first_scale(hero, kind, d):
    """The scale the clip's first frame was drawn at (firsts.json; a frame made before it was recorded: the kind's)."""
    entry = first_entry(hero, kind, d)
    return float(entry.get("scale", scale_of(kind)))


def first_entry(hero, kind, d):
    log = OUT / hero / "firsts.json"
    entry = (json.loads(log.read_text()) if log.exists() else {}).get(f"{kind}_{d}", {})
    return entry if isinstance(entry, dict) else {"scale": entry}


# ---- prompts -------------------------------------------------------------------------------------------------------

# The motions only (owner 2026-10-19: "no effects when spellcasting or making an attack, just the motions; the effects
# come from our game engine"): animations.json's wind-ups and strikes describe the drawn strips' glows and bursts, so
# the clips use these words instead.
MOVES = {
    "godrick_pendlebrook": {
        # A heavier blow (owner 2026-10-19: "make it look like a heavier attack").
        "attack": "heavy overhead chop with his longsword",
        "windup": "the longsword heaved up high above his head, the round shield pulled tight to his chest, knees bent "
                  "and weight sinking back, holding for a moment at the top",
        "strike": "the longsword brought down hard in one heavy chop to waist height in front of him, his whole body "
                  "dropping into the blow and the front knee bending with the impact, then a short, heavy "
                  "follow-through"},
    "liriel_dawnsong": {
        # Her drawn attack holds a weapon and shield, and the attack plays for her weapon attacks (spells use the cast).
        "attack": "heavy overhead swing with the weapon in her right hand",
        "windup": "the weapon heaved up high over her right shoulder, the shield pulled tight to her side, knees bent "
                  "and weight sinking back, holding for a moment at the top",
        "strike": "the weapon brought down hard in one heavy blow to waist height in front of her, her whole body "
                  "dropping into it and the front knee bending with the impact, then a short, heavy follow-through"},
    "wren_featherfoot": {
        "attack": "flying punch",
        "windup": "sinking into a deep crouch, coiled low on the balls of his feet, the right fist pulled back beside his "
                  "ribs, the left open hand forward for balance, his clothes pulled back by the motion",
        "strike": "springing forward off both legs into a long, low lunge, the right fist driven out at full arm's "
                  "length, the back leg straight and the heel lifted, his clothes snapping after him"},
    "thistle": {
        "attack": "longbow shot",
        "windup": "dropping into a wide, braced crouch, the longbow raised and drawn to her cheek with an arrow nocked, "
                  "her torso twisting with the draw, her cloak and hair swinging back",
        "strike": "the arrow loosed, the bowstring snapping forward, her drawing hand flung back past her ear, her body "
                  "rocking back onto the rear leg with the release, the cloak whipping out"},
    "ratatoille": {
        "attack": "forceful spell attack, shown only as the motion of casting",
        "windup": "planting his feet wide, knees bending into a low braced stance, the wooden staff raised high in the "
                  "right hand and the left hand pulled back beside the hip with the fingers curled, torso leaning back "
                  "as if drawing in power, his robes and apron billowing",
        "strike": "the left arm thrust straight out toward the enemy at shoulder height with the palm open, the staff "
                  "swept forward too, the whole body lunging into it, robes and apron whipping after him"},
    "kip_smudgewick": {
        "attack": "forceful eldritch blast, shown only as the motion of casting",
        "windup": "planting his feet wide, knees bending into a low braced stance, both hands pulled back beside his right "
                  "hip with the palms facing each other as if holding in a great power, his body coiling, his tail and "
                  "coat swinging back",
        "strike": "both hands thrust straight out toward the enemy at chest height, the whole body lunging forward onto "
                  "the front foot, the straw hat tilted back, his coat and tail whipping after him"},
}
# Heroes whose attack is a weapon swing: the prompt asks for weight. Every hero's attack now gets the fighting-game
# prompt (owner 2026-10-20: "there's no movement ... capes, bodies, expressions"), made on Lite.
SWINGS = {"godrick_pendlebrook", "liriel_dawnsong"}
# The casters' own casts (owner 2026-10-20: "putting power into it, as if they are channeling magic"; effects are the
# engine's): legs bending into a braced stance, the body gathering, then thrown forward.
MOVES["ratatoille"].update(
    cast_gather="planting his feet wide, knees bending into a low braced stance, the wooden staff raised high in his "
                "right hand and his left hand drawn in toward his chest as if gathering a great power, his robes and "
                "apron billowing, his face intense",
    cast_release="the left arm thrust out toward the enemy with the palm open, the staff swept forward, the whole body "
                 "lunging into it, the robes whipping after him")
MOVES["kip_smudgewick"].update(
    cast_gather="planting his feet wide, knees bending into a low braced stance, both hands drawn in to his chest "
                "with the palms facing each other as if holding in a great power, his body coiling, his coat and tail "
                "swinging back, his face intense",
    cast_release="both hands thrust out toward the enemy, the whole body lunging forward onto the front foot, his coat "
                 "and tail whipping after him")
CAST_MOVES = ("one hand raised before the chest with the palm open, the other arm drawn back, eyes intent",
              "the hand thrust forward with the palm out, leaning forward")


# How each drawn direction is faced, in words. The first Omni walk turned Kip from facing the camera to three-quarter view
# (2026-10-24) until the prompt said his chest and face stay squared and his body never rotates. e, se and ne face the
# viewer's right in the sheets.
FACING = {
    "s": "facing straight toward the camera, a front view with {his} chest, shoulders, hips and face squared to the viewer "
         "exactly as in the first frame, never turned to either side or into three-quarter view",
    "se": "turned three-quarters toward the camera and to the viewer's right, exactly as in the first frame, never turning "
          "further round",
    "e": "in side profile facing the viewer's right, exactly as in the first frame, never turning toward or away from the "
         "camera",
    "ne": "seen from behind the whole time, exactly as in the first frame (we only ever see {his} back; {he} never turns "
          "toward the viewer)",
    "n": "seen from behind the whole time, exactly as in the first frame (we only ever see {his} back; {he} never turns "
         "toward the viewer)",
}


# What flows on each hero in a walk. The first Omni walks, told "cape, clothes and hair", drew Godrick and Ratatouille a cape.
FLOWS = {
    "godrick_pendlebrook": "tabard and long hair",
    "liriel_dawnsong": "cloak, robes and long hair",
    "thistle": "cloak, clothes and hair",
    "ratatoille": "robes, apron and hair",
    "wren_featherfoot": "loose clothes and hair",
    "kip_smudgewick": "tail, apron, clothes and hair",
}


def prompt(hero, kind, d="s"):
    spec = json.loads((ROOT / "art" / "anim" / "animations.json").read_text()).get(hero, {})
    spec.update(MOVES.get(hero, {}))
    he, his, him = ("she", "her", "her") if hero in SHE else ("he", "his", "him")
    He = he.capitalize()
    who = spec.get("who", "the character")
    who = who.split(", ", 1)[1] if ", " in who else who      # the description, not the name
    gear = (spec["gear"][0].upper() + spec["gear"][1:] + ". ") if spec.get("gear") else ""
    facing = FACING[d].format(he=he, his=his)
    backdrop = ("Flat, even chroma-key green background" if screen_of(hero) == "green"
                else "Flat, even solid cyan (turquoise) background")
    common = (f" {He} stays the same size and in the same spot in the frame and never turns. Locked-off static camera: "
              f"no zoom, no pan, no camera shake. {backdrop} everywhere, no floor, no "
              f"shadow, no other objects or people. Keep {his} face, clothes, colours and gear exactly as in the image. "
              f"Silent.")
    head = f"Hand-painted 2D game character animation of {who}, from the image. "
    no_fx = (f" Only {his} body, clothes and gear move: no visual effects of any kind, no glow, light, sparks, flames, "
             f"magic, energy, beams, impact flashes, motion trails or swooshes.")
    if kind == "walk":
        body = (f"{He} walks in place as if on a treadmill, {facing}: a lively, full-bodied walk cycle in the style of a "
                f"high-end 2D game, the knees bending with each step, the weight rolling from foot to foot, the arms "
                f"swinging, the shoulders and head moving, {his} {FLOWS.get(hero, 'clothes and hair')} flowing and swaying with "
                f"every step, a living expression. {gear}{He} never moves forward or sideways and {his} body never rotates.")
    elif kind == "idle":
        body = (f"{He} stands still in a relaxed, ready stance, {facing}, breathing gently, {his} weight shifting "
                f"slightly; {his} hair and clothes stir in a light breeze. {gear}{He} does not walk, speak or move "
                f"{his} feet.")
    elif kind == "attack" and hero in SWINGS:
        body = (f"A big, powerful {spec.get('attack', 'attack')}, animated like a high-end 2D fighting game with full, "
                f"exaggerated key poses, {facing}. Anticipation: {he} sinks into a deep crouch, knees bent wide, the torso "
                f"twisting away, the weapon drawn far back and up; {his} cape and hair swing back with the motion; "
                f"{his} face is fierce, teeth gritted. Then {he} explodes into the blow: {he} drives off the back leg "
                f"into a low lunge, the whole body whipping round behind the weapon as it comes down hard, the cape "
                f"flaring out and whipping after {him}, hair flying. A short, heavy follow-through, a beat held at the "
                f"end of the blow, then {he} straightens back into the pose in the image while the cape swings and "
                f"settles. {his.capitalize()} cape, hair and clothes never stop moving; nothing is stiff. The front "
                f"foot may step forward and back, but {he} ends exactly where {he} began." + no_fx)
    elif kind == "attack" and hero in MOVES:
        body = (f"A big, powerful {spec.get('attack', 'attack')}, animated like a high-end 2D fighting game with full, "
                f"exaggerated key poses, {facing}. Anticipation: {spec.get('windup', '')}; {his} face is fierce and "
                f"focused. Then {he} explodes into the move: {spec.get('strike', '')}. A short, heavy follow-through, a "
                f"beat held at the end of it, then {he} straightens back into the pose in the image while {his} clothes "
                f"and hair swing and settle. {his.capitalize()} clothes and hair never stop moving; nothing is stiff. "
                f"{He} ends exactly where {he} began." + no_fx)
    elif kind == "attack":
        body = (f"One powerful {spec.get('attack', 'attack')}, {facing}: first the wind-up, "
                f"{spec.get('windup', '')}; then the strike, {spec.get('strike', '')}; then {he} returns to the pose in "
                f"the image and holds still. The whole attack takes about {'a second and a half' if hero in SWINGS else 'one second'} "
                f"and {his} feet stay planted."
                + (f" It must feel heavy and weighty: a slow, deliberate wind-up that pauses at the top, then a sudden, "
                   f"fast, powerful strike carrying {his} whole weight, then a brief settle." if hero in SWINGS else "")
                + no_fx)
    elif kind == "hurt":
        # Not "struck by a blow": Veo drew an impact flash for it whatever else the prompt said.
        body = (f"{He} flinches, {facing}: as if shoved hard in the chest, {his} body jolts back and the head snaps "
                f"aside, {he} staggers on the spot, then recovers to the pose in the image and holds still. The "
                f"whole flinch takes about half a second and {his} feet stay in place. {He} does not draw, swing or "
                f"pick up anything; {his} hands keep exactly what they hold in the image." + no_fx)
    else:
        gather = CAST_MOVES[0] if "cast_gather" not in MOVES.get(hero, {}) else spec["cast_gather"]
        release = CAST_MOVES[1] if "cast_release" not in MOVES.get(hero, {}) else spec["cast_release"]
        # Not "casts a spell": with that word Veo drew bursts of light whatever else the prompt said.
        body = (f"{He} makes a commanding gesture, {facing}: first {gather}; then {release}; then {he} returns to the "
                f"pose in the image and holds still. It takes about one second and {his} feet stay planted. Nothing "
                f"magical appears: nothing new comes into {his} hands and nothing glows, sparks or bursts." + no_fx)
    return head + body + common


# ---- generation ----------------------------------------------------------------------------------------------------

def omni_video(answer, key, out):
    """Saves the video in an Interactions answer to `out`: inline base64, or a files/ uri to wait on and download.
    Returns None, or what went wrong."""
    def find(o):
        if isinstance(o, dict):
            if o.get("type") == "video" or str(o.get("mime_type", "")).startswith("video"):
                return o
            for x in o.values():
                if (r := find(x)):
                    return r
        elif isinstance(o, list):
            for x in o:
                if (r := find(x)):
                    return r
        return None

    def call(url):
        req = urllib.request.Request(url, headers={"x-goog-api-key": key})
        return urllib.request.urlopen(req, timeout=600)

    video = find(answer)
    if not video:
        return f"no video in the answer ({json.dumps(answer)[:300]})"
    if video.get("data"):
        out.write_bytes(base64.b64decode(video["data"]))
        return None
    if not video.get("uri"):
        return f"a video with neither data nor uri ({json.dumps(video)[:300]})"
    file_id = video["uri"].rstrip("/").split("/")[-1].split(":")[0]
    for _ in range(90):
        with call(f"{API}/files/{file_id}") as r:
            state = json.loads(r.read()).get("state")
        if state in ("ACTIVE", "FAILED"):
            break
        time.sleep(4)
    with call(f"{API}/files/{file_id}:download?alt=media") as r:
        out.write_bytes(r.read())
    return None


def generate_one(hero, kind, d, key):
    name = f"{kind}_{d}"
    out = OUT / hero / f"{name}.mp4"
    seconds, one_shot = seconds_of(kind), kind in ONE_SHOTS
    text = prompt(hero, kind, d) + f" The clip is exactly {seconds} seconds long."
    image = {"type": "image", "data": base64.b64encode(first_frame(hero, kind, d).read_bytes()).decode(),
             "mime_type": "image/png"}
    if one_shot:
        text += " The first image is the clip's first frame and the second image is its last frame."
    body = {"model": model_of(kind, hero),
            "input": [image] + ([image] if one_shot else []) + [{"type": "text", "text": text}],
            "response_format": {"type": "video", "aspect_ratio": "9:16", "resolution": "720p", "delivery": "uri"},
            "generation_config": {"video_config": {"task": "image_to_video"}}}
    SIZE = size_of(kind)
    model = body["model"]
    gb.guard(model, SIZE, key)
    for attempt in range(5):
        try:
            req = urllib.request.Request(f"{API}/interactions", data=json.dumps(body).encode(),
                                         headers={"x-goog-api-key": key, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=900) as r:
                answer = json.loads(r.read())
            break
        except urllib.error.HTTPError as e:
            gb.record(model, SIZE, f"{hero}/{name}", "omni", "error", code=e.code, key=key)
            if e.code in (429, 500, 503) and attempt < 4:
                time.sleep(45 * (attempt + 1))    # the requests a minute; a refused request costs nothing
                continue
            return f"{hero} {name}: HTTP {e.code} {e.read().decode()[:300]}"
        except (urllib.error.URLError, TimeoutError) as e:
            gb.record(model, SIZE, f"{hero}/{name}", "omni", "error", code="network", key=key)
            return f"{hero} {name}: network {e}"
    problem = omni_video(answer, key, out)
    if problem:
        # The clip was made and billed whether or not it could be fetched.
        gb.record(model, SIZE, f"{hero}/{name}", "omni", "refused", key=key)
        return f"{hero} {name}: {problem}"
    gb.record(model, SIZE, f"{hero}/{name}", "omni", "ok", key=key)
    with CLIPS_LOCK:
        log = OUT / hero / "clips.json"
        clips = json.loads(log.read_text()) if log.exists() else {}
        clips[name] = {"model": model, "seconds": seconds, "prompt": text, "made": gb._stamp(),
                       "centre": CENTRE, "scale": first_scale(hero, kind, d), "last_frame": one_shot,
                       "screen": screen_of(hero)}
        log.write_text(json.dumps(clips, indent=1) + "\n")
    return f"{hero} {name}: ok"


def generate(heroes, kinds, dirs, redo):
    todo = [(h, k, d) for h in heroes for k in kinds for d in dirs
            if f"{k}_{d}" in redo or not (OUT / h / f"{k}_{d}.mp4").exists()]
    if not todo:
        print("every clip is there")
        return
    # A clip's price depends on its length; the preflight counts them in 4-second units.
    unit = gb.price(MODEL, f"720p-{SECONDS}s")
    units = round(sum(gb.price(model_of(k, h), size_of(k)) for h, k, _d in todo) / unit)
    gb.preflight(units, f"720p-{SECONDS}s", f"video clips for {', '.join(sorted({h for h, _, _ in todo}))}", MODEL)
    key = gb.api_key()
    for h, k, d in todo:
        first_frame(h, k, d)      # kept from the first take: the sheet may already be the Veo one
    # Two at once: each clip takes about half a minute, and more at once runs into the requests a minute.
    by_hero = {}
    for h, k, d in todo:
        by_hero.setdefault(h, []).append((k, d))
    with cf.ThreadPoolExecutor(max_workers=2) as pool:
        futures = []
        for h, jobs in by_hero.items():
            for k, d in jobs:
                futures.append(pool.submit(generate_one, h, k, d, key))
                time.sleep(1.5)
        for f in cf.as_completed(futures):
            print(f.result(), flush=True)


# ---- frames out of a clip ------------------------------------------------------------------------------------------

def decode(clip):
    """Every frame of a clip as RGB images (tools/art/veo_frames.swift, AVFoundation)."""
    with tempfile.TemporaryDirectory(prefix="veo_") as tmp:
        subprocess.run(["swift", str(ROOT / "tools" / "art" / "veo_frames.swift"), str(clip), tmp], check=True,
                       capture_output=True)
        return [Image.open(p).convert("RGB") for p in sorted(Path(tmp).glob("*.png"))]


def key_screen(im, screen="green"):
    """RGBA with the screen keyed out. A pixel's excess is how much more of the screen's own channels it has than of
    the others (green: g - max(r, b); cyan: min(g, b) - r), against the background's excess read from the frame's
    corners: under half of it is figure. One pixel is eaten off the edge (where the screen bleeds in), and what is
    left of the screen colour in a kept pixel is unmixed: c' = (c - k * screen) / (1 - k), k its share of the screen."""
    r, g, b = im.split()
    if screen == "green":
        excess = ImageChops.subtract(g, ImageChops.lighter(r, b))
    else:
        excess = ImageChops.subtract(ImageChops.darker(g, b), r)
    spots = [(x, y) for x in (4, W - 5) for y in (4, 60)]
    bg = sorted(excess.getpixel(p) for p in spots)[len(spots) // 2] or 100
    sc = [sorted(im.getpixel(p)[c] for p in spots)[len(spots) // 2] for c in range(3)]
    alpha = excess.point(lambda v: 255 if v < bg * 0.5 else 0).filter(ImageFilter.MinFilter(3))
    share = excess.point(lambda v: min(int(255 * v / bg), 230))      # k, as 0..255
    chans = []
    for ch, s in zip((r, g, b), sc):
        chans.append(ImageMath.lambda_eval(
            lambda e: e["convert"](e["min"](e["max"]((e["c"] * 255 - e["k"] * s) / (255 - e["k"]), 0), 255), "L"),
            c=ch, k=share))
    rgba = Image.merge("RGBA", (*chans, alpha))
    return Image.composite(rgba, Image.new("RGBA", im.size, (0, 0, 0, 0)), alpha)


def keep_figure(rgba):
    """The figure without the specks Veo still scatters round a blow or a gesture (sparks, a flying bit of light): only
    the opaque parts joined to the figure's body, found by flood-filling a quarter-size mask (widened by 5 px so a
    sword tip or a strand of hair keeps its join) from the opaque pixel nearest the cell centre's column at mid-body."""
    a = rgba.getchannel("A")
    q = a.resize((a.width // 4, a.height // 4), Image.BILINEAR).point(lambda v: 255 if v > 40 else 0)
    q = q.filter(ImageFilter.MaxFilter(3))
    cx, cy = WORK_CENTRE[0] // 4, (WORK_CENTRE[1] - 120) // 4
    seed = None
    for r in range(0, 60):
        for dx, dy in ((0, r), (0, -r), (r, 0), (-r, 0)):
            x, y = cx + dx, cy + dy
            if 0 <= x < q.width and 0 <= y < q.height and q.getpixel((x, y)) == 255:
                seed = (x, y)
                break
        if seed:
            break
    if seed is None:
        return rgba
    from PIL import ImageDraw
    ImageDraw.floodfill(q, seed, 128)
    body = q.point(lambda v: 255 if v == 128 else 0).resize(a.size, Image.NEAREST).filter(ImageFilter.MaxFilter(5))
    return Image.composite(rgba, Image.new("RGBA", rgba.size, (0, 0, 0, 0)), ImageChops.multiply(a, body))


def small(rgba):
    """A grey-backed thumbnail round the cell centre, for comparing poses."""
    box = (WORK_CENTRE[0] - 330, WORK_CENTRE[1] - 470, WORK_CENTRE[0] + 330, WORK_CENTRE[1] + 400)
    bg = Image.new("RGBA", rgba.size, (92, 92, 97, 255))
    bg.alpha_composite(rgba)
    return bg.convert("L").crop(box).resize((88, 116), Image.BILINEAR)


def diff(a, b):
    return ImageStat.Stat(ImageChops.difference(a, b)).mean[0]


def head_y(rgba):
    bb = rgba.getchannel("A").getbbox()
    return bb[1] if bb else 0


def best_loop(thumbs, lo, hi, starts):
    """(start, length) of the cleanest loop: the frame after the loop matches its first, and so does the next one."""
    best = None
    for s in starts:
        for n in range(lo, hi + 1):
            if s + n + 1 >= len(thumbs):
                break
            score = diff(thumbs[s], thumbs[s + n]) + diff(thumbs[s + 1], thumbs[s + n + 1])
            if best is None or score < best[0]:
                best = (score, s, n)
    return best[1], best[2], best[0]


def walk_frames(frames, thumbs):
    s, n, score = best_loop(thumbs, 16, 56, range(2, 30))
    loop = list(range(s, s + n))
    # Start on the lowest head (a foot coming down): the game sends footfalls on the first and middle frames.
    heads = [head_y(frames[i]) for i in loop]
    low = max(range(n), key=lambda i: heads[i])
    loop = loop[low:] + loop[:low]
    picks = [loop[int(i * n / WALK_FRAMES)] for i in range(WALK_FRAMES)]
    return picks, WALK_FPS, {"loop": [s, n], "score": round(score, 2)}


def idle_frames(frames, thumbs):
    """A loop of the standing clip. An idle drifts (the weight shifts, the cloak settles) and seldom comes back
    exactly, so the loop's last SEAM frames are faded into the frames just before its start: it ends where it began.
    Returns the frames themselves (some are blends)."""
    s, n, score = best_loop(thumbs, IDLE_LOOP[0], IDLE_LOOP[1], range(SEAM, 24))
    loop = [frames[i] for i in range(s, s + n)]
    for j in range(SEAM):
        w = (j + 1) / (SEAM + 1)
        loop[n - SEAM + j] = Image.blend(loop[n - SEAM + j], frames[s - SEAM + j], w)
    count = max(8, int(round(n * IDLE_FPS / FPS)))
    step = sum(diff(thumbs[i], thumbs[i + 1]) for i in range(s, s + n - 1)) / (n - 1)
    return [loop[int(i * n / count)] for i in range(count)], IDLE_FPS, {
        "loop": [s, n], "score": round(score, 2), "seam_in_steps": round(score / max(step, 0.01), 1)}


def info_hit(hero):
    return ATTACK_TIMING.get(hero, (ATTACK_FRAMES, ATTACK_HIT, ATTACK_FPS))[1]


def one_shot_frames(frames, thumbs, count, hit, fps, ease=1.0, quick=False):
    """From guard back to guard, retimed so the fastest motion (the blow) lands on frame `hit` of `count`."""
    motion = [diff(thumbs[i], thumbs[i + 1]) for i in range(len(thumbs) - 1)]
    quiet = sorted(motion)[len(motion) // 4]
    moving = [i for i, m in enumerate(motion) if m > 2.0 * quiet + 0.5]
    peak = max(range(2, len(motion)), key=lambda i: motion[i]) + 1
    # The start: just before it starts moving (still the first pose, which the game starts it from standing).
    start = max(0, min((i for i in moving if i < peak), default=0) - 2)
    # The end: the first frame after the blow that is back at the first pose (the clip ends on it).
    after = list(range(min(peak + 4, len(thumbs) - 1), len(thumbs)))
    back = [diff(thumbs[i], thumbs[0]) for i in after]
    lo, mid = min(back), sorted(back)[len(back) // 2]
    end = next(i for i, b in zip(after, back) if b <= lo + 0.3 * (mid - lo))
    if quick:
        # A flinch is over in a moment; an 8-second clip fills the rest with other business (raising a sword).
        end = min(end, next((i for i, b in zip(after, back) if b <= lo + 0.12 * (mid - lo)), end), peak + 24)
    picks = []
    for i in range(count):
        if i <= hit:
            picks.append(int(round(start + (peak - start) * (i / hit) ** ease)))
        else:
            picks.append(int(round(peak + (end - peak) * (i - hit) / (count - 1 - hit))))
    return picks, fps, {"start": start, "peak": peak, "end": end,
                        "end_vs_first": round(diff(thumbs[end], thumbs[0]), 2)}


# ---- the palette snap (blender/lib/cutout.py finish_sheet, in PIL) --------------------------------------------------

def palette_images():
    data = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
    cols = [tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for v in data.values()]
    neutral = [c for c in cols if (max(c) - min(c)) / 255.0 < 0.075]

    def pimg(cs):
        p = Image.new("P", (1, 1))
        flat = [v for c in cs for v in c]
        p.putpalette(flat + flat[-3:] * (256 - len(cs)))
        return p
    return pimg(cols), pimg(neutral)


PALETTES = None


def finish(rgba):
    """Binary alpha and every visible pixel on the palette; greys only on the grey ramp where the pixel and most of
    its 7x7 neighbourhood are grey (mail, plate), so a warm line on skin keeps its warmth."""
    global PALETTES
    if PALETTES is None:
        PALETTES = palette_images()
    full, neutral = PALETTES
    rgb = rgba.convert("RGB")
    q_all = rgb.quantize(palette=full, dither=Image.Dither.NONE).convert("RGB")
    q_neu = rgb.quantize(palette=neutral, dither=Image.Dither.NONE).convert("RGB")
    r, g, b = rgb.split()
    mx = ImageChops.lighter(ImageChops.lighter(r, g), b)
    mn = ImageChops.darker(ImageChops.darker(r, g), b)
    grey = ImageChops.multiply(ImageChops.subtract(mx, mn).point(lambda v: 255 if v < 16 else 0),
                               mx.point(lambda v: 255 if v < 220 else 0))
    area = grey.filter(ImageFilter.BoxBlur(3)).point(lambda v: 255 if v >= 128 else 0)
    use_grey = ImageChops.multiply(grey, area)
    out = Image.composite(q_neu, q_all, use_grey).convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    out.putalpha(alpha)
    return Image.composite(out, Image.new("RGBA", out.size, (0, 0, 0, 0)), alpha)


# ---- sheets --------------------------------------------------------------------------------------------------------

def choose(hero, kind, d):
    """The frames (RGBA, clip-sized) and fps one animation keeps, plus notes for the review."""
    log = OUT / hero / "clips.json"
    clip = (json.loads(log.read_text()) if log.exists() else {}).get(f"{kind}_{d}", {})
    at, s = clip.get("centre", CENTRE), float(clip.get("scale", 1.0))
    screen = clip.get("screen", "green")
    frames, inside = [], None
    for raw in decode(OUT / hero / f"{kind}_{d}.mp4"):
        k = key_screen(raw, screen)
        if s != 1.0:
            k = k.resize((round(W / s), round(H / s)), Image.LANCZOS)
        ox, oy = round(WORK_CENTRE[0] - at[0] / s), round(WORK_CENTRE[1] - at[1] / s)
        work = Image.new("RGBA", WORK, (0, 0, 0, 0))
        work.paste(k, (ox, oy))
        frames.append(keep_figure(work) if kind in ONE_SHOTS else work)
        inside = (ox, oy, ox + k.width, oy + k.height)
    thumbs = [small(f) for f in frames]
    if kind == "walk":
        picks, fps, info = walk_frames(frames, thumbs)
    elif kind == "idle":
        chosen, fps, info = idle_frames(frames, thumbs)
        picks = [0]
    elif kind == "attack":
        picks, fps, info = one_shot_frames(frames, thumbs, *ATTACK_TIMING.get(hero, (ATTACK_FRAMES, ATTACK_HIT,
                                                                                      ATTACK_FPS)), ease=WINDUP_EASE)
        info["durations"] = [IMPACT_HOLD if i == info_hit(hero) else 1.0 for i in range(len(picks))]
    elif kind == "hurt":
        picks, fps, info = one_shot_frames(frames, thumbs, HURT_FRAMES, HURT_PEAK, HURT_FPS, quick=True)
    else:
        picks, fps, info = one_shot_frames(frames, thumbs, CAST_FRAMES, CAST_HIT, CAST_FPS)
    # The framing (owner 2026-10-19: no zooming): the clip's first frame must sit where the frame Veo was given sat, at
    # the same size, and the feet must stay on that ground line (a zoom or a drifting camera moves them).
    given = key_screen(Image.open(OUT / hero / f"{kind}_{d}_first.png").convert("RGB"), screen)
    if s != 1.0:
        given = given.resize((round(W / s), round(H / s)), Image.LANCZOS)
    ref = Image.new("RGBA", WORK, (0, 0, 0, 0))
    ref.paste(given, (round(WORK_CENTRE[0] - at[0] / s), round(WORK_CENTRE[1] - at[1] / s)))
    gb_, fb_ = ref.getchannel("A").getbbox(), frames[0].getchannel("A").getbbox()
    framing = {"height": round((fb_[3] - fb_[1]) / max(1, gb_[3] - gb_[1]), 3), "feet": fb_[3] - gb_[3],
               "x": round((fb_[0] + fb_[2] - gb_[0] - gb_[2]) / 2)}
    # And against the drawn sheet's own frame, at full size (a first frame drawn at another scale than recorded shows
    # here: Godrick's first attacks came out a quarter too big).
    drawn = first_entry(hero, kind, d).get("height")
    if drawn:
        framing["vs_sheet"] = round((fb_[3] - fb_[1]) / drawn, 3)
    edge, shadow, drift = [], [], []
    feet = frames[0].getchannel("A").getbbox()[3]
    for i in sorted(set(picks)):
        a = frames[i].getchannel("A")
        bb = a.getbbox()
        if bb and (bb[0] <= inside[0] + 1 or bb[2] >= inside[2] - 1 or bb[1] <= inside[1] + 1):
            edge.append(i)
        # Veo sometimes paints a floor shadow despite the prompt: opaque pixels well below the first frame's feet.
        if bb and bb[3] > feet + 10 and a.crop((0, feet + 10, a.width, bb[3])).histogram()[255] > 400:
            shadow.append(i)
        if bb and abs(bb[3] - feet) > 14 and kind != "walk":
            drift.append(i)
    ok = (abs(framing["height"] - 1) <= 0.03 and abs(framing.get("vs_sheet", 1) - 1) <= 0.03
          and abs(framing["feet"]) <= 6 and abs(framing["x"]) <= 8 and not drift)
    info.update(picks=picks, clipped=edge, shadow=shadow, framing=framing, feet_moved=drift, framing_ok=ok)
    if kind == "idle":
        return chosen, fps, info
    return [frames[i] for i in picks], fps, info


def trim(rgba, cell):
    """The frame cut to its figure plus PAD, symmetric about the cell centre column, inside the cell; returns
    (crop, (left, top) in the cell)."""
    cw, ch = cell
    X0, Y0 = WORK_CENTRE[0] - cw // 2, WORK_CENTRE[1] - ch // 2
    a = rgba.getchannel("A")
    bb = a.getbbox()
    if not bb:
        return Image.new("RGBA", (2 * PAD, 2 * PAD), (0, 0, 0, 0)), (cw // 2 - PAD, ch - 2 * PAD)
    half = max(WORK_CENTRE[0] - bb[0], bb[2] - WORK_CENTRE[0]) + PAD
    x0, x1 = max(X0, WORK_CENTRE[0] - half), min(X0 + cw, WORK_CENTRE[0] + half)
    y0, y1 = max(Y0, bb[1] - PAD), min(Y0 + ch, bb[3] + PAD)
    return rgba.crop((x0, y0, x1, y1)), (x0 - X0, y0 - Y0)


def even_cell(frames, base):
    """The logical cell holding every frame's figure plus PAD, centred on CENTRE, at least `base` (w, h)."""
    hw, hh = base[0] / 2, base[1] / 2
    for f in frames:
        bb = f.getchannel("A").getbbox()
        if bb:
            hw = max(hw, WORK_CENTRE[0] - bb[0] + PAD, bb[2] - WORK_CENTRE[0] + PAD)
            hh = max(hh, WORK_CENTRE[1] - bb[1] + PAD, bb[3] - WORK_CENTRE[1] + PAD)
    return 2 * int(-(-hw // 1)), 2 * int(-(-hh // 1))


def pack(crops):
    """render_keys.py's shelf packer (anim.pack_atlas): identical crops once, sides in multiples of 4."""
    keys, unique, index = {}, [], []
    for c in crops:
        k = (c.size, hash(c.tobytes()))
        if k not in keys:
            keys[k] = len(unique)
            unique.append(c)
        index.append(keys[k])
    area = sum(c.width * c.height for c in unique)
    width = max(max(c.width for c in unique), int(area ** 0.5 * 1.08))
    width = (width + 3) // 4 * 4
    order = sorted(range(len(unique)), key=lambda i: -unique[i].height)
    spots, x, y, shelf = {}, 0, 0, 0
    for i in order:
        if x + unique[i].width > width:
            x, y, shelf = 0, y + shelf, 0
        spots[i] = (x, y)
        x += unique[i].width
        shelf = max(shelf, unique[i].height)
    atlas = Image.new("RGBA", (width, (y + shelf + 3) // 4 * 4), (0, 0, 0, 0))
    for i, (x, y) in spots.items():
        atlas.paste(unique[i], (x, y))
    return atlas, [(*spots[i], unique[i].width, unique[i].height) for i in index]


def write_tres(path, texture, cell, entries, meta):
    """SpriteFrames: `entries` [(anim name, fps, loop, [(rect, (left, top))])], each frame an AtlasTexture whose
    margin restores the full cell (blender/lib/anim.py write_sheet_tres)."""
    cw, ch = cell
    subs, anims, n = [], [], 0
    for name, fps, loop, frames in entries:
        ids = []
        durations = []
        for (x, y, w, h), (left, top), du in frames:
            sid = f"f_{n}"
            n += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                        f"region = Rect2({x}, {y}, {w}, {h})\nmargin = Rect2({left}, {top}, {cw - w}, {ch - h})\n")
            ids.append(sid)
            durations.append(du)
        listed = ", ".join(f'{{"duration": {float(du)}, "texture": SubResource("{i}")}}' for i, du in zip(ids, durations))
        anims.append(f'{{\n"frames": [{listed}],\n"loop": {"true" if loop else "false"},\n"name": &"{name}",\n'
                     f'"speed": {float(fps)}\n}}')
    meta_lines = "".join(f"metadata/{k} = {json.dumps(v)}\n" for k, v in meta.items())
    path.write_text('[gd_resource type="SpriteFrames" format=3]\n\n'
                    f'[ext_resource type="Texture2D" path="{texture}" id="1"]\n\n' + "\n".join(subs)
                    + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n" + meta_lines)


def build_sheet(hero, sheet, kinds, dirs, notes):
    """Rewrites art/sprites/<hero>/<sheet>.png/.tres: the Veo kinds replaced, any other animation in it kept as is."""
    tres = ROOT / "art" / "sprites" / hero / f"{sheet}.tres"
    old_anims, old_speeds, old_subs, meta = read_tres(tres)
    old_png = Image.open(ROOT / "art" / "sprites" / hero / f"{sheet}.png").convert("RGBA")
    base = None
    for sid, (reg, mar) in old_subs.items():
        base = (reg[2] + mar[2], reg[3] + mar[3])
        break
    chosen = {}
    for kind in kinds:
        if (hero, kind) in KEEP:
            print(f"{hero} {kind}: kept as the owner chose (KEEP)")
            continue
        missing = [d for d in DIRS if not (OUT / hero / f"{kind}_{d}.mp4").exists()]
        if kind in ("attack", "cast") and missing and len(missing) < len(DIRS):
            # One hit frame serves every direction: a sheet half Veo, half drawn would land some blows early.
            print(f"{hero} {kind}: waiting for {', '.join(missing)} before its sheet is rebuilt")
            continue
        for d in dirs:
            if (OUT / hero / f"{kind}_{d}.mp4").exists():
                fr, fps, info = choose(hero, kind, d)
                chosen[(kind, d)] = ([finish(f) for f in fr], fps, info.get("durations"))
                notes[f"{kind}_{d}"] = info
    if not chosen:
        return
    every = [f for fr, _fps, _durs in chosen.values() for f in fr]
    # The walk sheet keeps its cell (the game sizes a sprite by its standing frame); others grow to fit a raised sword.
    cell = base if sheet == "walk" else even_cell(every, base)
    entries, crops, order = [], [], []
    names = []
    for name in old_anims:                       # keep the sheet's own order of animations
        kind, d = name.rsplit("_", 1)
        names.append((name, kind, d))
    for name, kind, d in names:
        if (kind, d) in chosen:
            fr, fps, durs = chosen[(kind, d)]
            placed = [trim(f, cell) for f in fr]
            order.append((name, fps, kind in ("walk", "idle"), placed, durs))
        else:
            # An animation the clips don't replace: its old frames, moved onto the new cell.
            placed = []
            for sid, _dur in old_anims[name]:
                (x, y, w, h), (ml, mt, mw, mh) = old_subs[sid]
                dx, dy = (cell[0] - (w + mw)) // 2, (cell[1] - (h + mh)) // 2
                placed.append((old_png.crop((x, y, x + w, y + h)), (ml + dx, mt + dy)))
            order.append((name, old_speeds[name], READ_LOOPS[str(tres)].get(name, False), placed,
                          [du for _sid, du in old_anims[name]]))
    for _name, _fps, _loop, placed, _durs in order:
        crops.extend(c for c, _ in placed)
    atlas, rects = pack(crops)
    i = 0
    for name, fps, loop, placed, durs in order:
        frames = []
        for j, (_crop, at) in enumerate(placed):
            frames.append((rects[i], at, durs[j] if durs else 1.0))
            i += 1
        entries.append((name, fps, loop, frames))
    if "attack" in kinds and sheet == "attack":
        hit = ATTACK_TIMING.get(hero, (ATTACK_FRAMES, ATTACK_HIT, ATTACK_FPS))[1]
        meta["hit_frames"] = {"attack": hit}
        meta["hit_frame"] = hit
        if hero in SWINGS:
            meta["casts"] = False        # a weapon swing now, never played as a spell gesture
    if "cast" in kinds and sheet == "cast":
        meta["hit_frames"] = {"cast": CAST_HIT}
    meta["veo"] = True
    atlas.save(ROOT / "art" / "sprites" / hero / f"{sheet}.png")
    write_tres(tres, f"res://art/sprites/{hero}/{sheet}.png", cell, entries, meta)
    print(f"{hero} {sheet}: {len(crops)} frames, cell {cell[0]}x{cell[1]}, atlas {atlas.width}x{atlas.height}")


def sheets(heroes, kinds, dirs):
    for hero in heroes:
        notes_path = OUT / hero / "sheets.json"
        notes = json.loads(notes_path.read_text()) if notes_path.exists() else {}
        for sheet in ("walk", "attack", "cast"):
            ks = [k for k in kinds if SHEET_OF[k] == sheet]
            if ks:
                build_sheet(hero, sheet, ks, dirs, notes)
        notes_path.write_text(json.dumps(notes, indent=1) + "\n")


def review(heroes, kinds, dirs):
    for hero in heroes:
        for kind in kinds:
            rows = []
            for d in dirs:
                if not (OUT / hero / f"{kind}_{d}.mp4").exists():
                    continue
                fr, _fps, info = choose(hero, kind, d)
                th = []
                for f in fr:
                    g = Image.new("RGBA", f.size, (92, 92, 97, 255))
                    g.alpha_composite(finish(f))
                    th.append(g.convert("RGB").crop((WORK_CENTRE[0] - 420, WORK_CENTRE[1] - 560, WORK_CENTRE[0] + 420,
                                                     WORK_CENTRE[1] + 400)).resize((132, 151), Image.LANCZOS))
                row = Image.new("RGB", (132 * len(th), 151), (92, 92, 97))
                for i, t in enumerate(th):
                    row.paste(t, (132 * i, 0))
                rows.append(row)
                print(hero, kind, d, json.dumps(info))
            if rows:
                out = Image.new("RGB", (max(r.width for r in rows), 151 * len(rows)), (60, 60, 64))
                for i, r in enumerate(rows):
                    out.paste(r, (0, 151 * i))
                out.save(OUT / hero / f"review_{kind}.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", nargs="*", default=HEROES)
    ap.add_argument("--kinds", nargs="*", default=KINDS)
    ap.add_argument("--dirs", nargs="*", default=DIRS)
    ap.add_argument("--generate", action="store_true")
    ap.add_argument("--redo", nargs="*", default=[])
    ap.add_argument("--sheets", action="store_true")
    ap.add_argument("--review", action="store_true")
    a = ap.parse_args()
    if a.generate:
        generate(a.only, a.kinds, a.dirs, set(a.redo))
    if a.review:
        review(a.only, a.kinds, a.dirs)
    if a.sheets:
        sheets(a.only, a.kinds, a.dirs)


if __name__ == "__main__":
    main()
