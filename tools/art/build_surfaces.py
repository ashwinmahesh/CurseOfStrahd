#!/usr/bin/env python3
"""Builds the HD surface sets for the Modern look (Improvement Ideas W4, docs/art/textures.md) from
tools/art/surface_recipes.json.

Usage: tools/art/build_surfaces.py [--generate] [--only theme/surface ...] [--jobs 3] [--force] [--macro]

--generate asks Gemini for one swatch per surface at 2K through tools/art/generate.sh, with
art/prompts/surface_preamble.txt and a look target frame as the style reference, saved as
art/generated/surfaces/<theme>_<surface>.webp (Gemini's PNG turned into WebP); swatches already there are kept unless --force. Further variants are
quilted from the first tile's own content (blender/make_surface.py --quilt), so they keep its scale and colours. The art spend
ledger checks the batch first (gemini_budget.preflight). Then blender/make_surface.py makes the tiles (seamless,
edge-matched variants, normal and ORM maps) and this writes them as WebP into art/textures/<theme>/:
<surface>_2k.webp (albedo), _2k_n.webp (normal), _2k_orm.webp (occlusion, roughness, metal; half size), and _2k_b...
for each further variant, and points the surface's manifest entry at them: hd_file, normal_file, orm_file, variants
and material. The Classic tile (`file`) is left as it is. --macro (re)makes art/textures/macro_noise.png, the soft
tileable noise the Modern shader varies large floors with. Then: make import && tools/art/set_import.py ...
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
RECIPES = ROOT / "tools" / "art" / "surface_recipes.json"
MANIFEST = ROOT / "art" / "textures" / "manifest.json"
LOOK = ROOT / "world" / "look" / "look.gd"
SWATCHES = ROOT / "art" / "generated" / "surfaces"
LETTERS = "abcdefgh"
SIZE = 1024


def materials():
    """Look.MATERIALS from world/look/look.gd (the one place the numbers live): [(word, {roughness, spread ...})]."""
    rows = []
    text = LOOK.read_text()
    block = text[text.index("const MATERIALS"):]
    block = block[:block.index("\n]\n")]
    for word, body in re.findall(r'\["([a-z_]+)", \{([^}]*)\}\]', block):
        rows.append((word, {k: float(v) for k, v in re.findall(r'"([a-z]+)": ([0-9.]+)', body)}))
    return rows


def material_for(key, own):
    out = {"roughness": 0.8, "spread": 0.35, "relief": 1.0, "metallic": 0.0}
    for word, spec in materials():
        if word in key:
            out.update(spec)
            break
    out.update(own)
    return out


def swatch(key, i):
    """A surface's swatch: kept as WebP (a fifth the size of Gemini's PNG); the PNG is only there just after it's painted."""
    theme, surface = key.split("/")
    stem = SWATCHES / (f"{theme}_{surface}" + ("" if i == 0 else f"_{LETTERS[i]}"))
    png = stem.with_suffix(".png")
    if png.exists():
        Image.open(png).convert("RGB").save(stem.with_suffix(".webp"), "WEBP", quality=94, method=6)
        png.unlink()
    return stem.with_suffix(".webp")


_REFS = Path(tempfile.mkdtemp(prefix="surface_refs_"))


def small_ref(name):
    """The look target frame, at 1376 px: enough to show the style, a fifth of the upload."""
    out = _REFS / f"{name}.png"
    if not out.exists():
        im = Image.open(ROOT / "art" / "generated" / "look_targets" / f"{name}.png").convert("RGB")
        im.resize((1376, round(im.height * 1376 / im.width)), Image.LANCZOS).save(out, "PNG")
    return str(out)


def small_swatch(key):
    out = _REFS / f"{swatch(key, 0).stem}.png"
    Image.open(swatch(key, 0)).convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out, "PNG")
    return str(out)


def generate(rec, key, i):
    r = rec["surfaces"][key]
    prompt = rec["prompt_template"].format(subject=r["subject"], view=rec["views"][r["view"]])
    name = swatch(key, i).stem
    cmd = [str(ROOT / "tools" / "art" / "generate.sh"), name, "surfaces", prompt, "--aspect", "1:1", "--size", "2K",
           "--preamble", "art/prompts/surface_preamble.txt", "--ref", small_ref(r["ref"])]

    g = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    ok = g.returncode == 0 and swatch(key, i).exists()   # (swatch() turns the fresh PNG into WebP)
    print(f"{'ok' if ok else 'FAILED'} {name}" + ("" if ok else ": " + (g.stdout + g.stderr)[-400:]), flush=True)
    return ok


def process(rec, key, wrap):
    r = rec["surfaces"][key]
    theme, surface = key.split("/")
    srcs = [swatch(key, 0)]
    if not all(s.exists() for s in srcs):
        print(f"missing swatches for {key}: run with --generate", file=sys.stderr)
        return None
    spec = material_for(key, r.get("material", {}))
    with tempfile.TemporaryDirectory() as tmp:
        cmd = [BLENDER, "-b", "--python", str(ROOT / "blender" / "make_surface.py"), "--"]
        for s in srcs:
            cmd += ["--in", str(s)]
        cmd += ["--out", tmp, "--name", f"{theme}_{surface}", "--axis", "x" if wrap == "x" else "both",
                "--size", str(SIZE), "--roughness", str(spec["roughness"]), "--spread", str(spec["spread"]),
                "--metallic", str(spec.get("metallic", 0.0)), "--relief", str(spec.get("relief", 1.0)),
                "--quilt", str(max(0, int(r["variants"]) - 1)), "--pieces", str(r.get("pieces", 0)),
                "--crop", str(r.get("crop", 0))]
        out = subprocess.run(cmd, capture_output=True, text=True)
        for l in out.stdout.splitlines():
            if l.startswith("pieces: ") or l.startswith("variant") or l.startswith("crop: "):
                print(f"  {key}: {l}")
        line = next((l for l in out.stdout.splitlines() if l.startswith("surface: ")), None)
        if out.returncode != 0 or line is None:
            print(out.stdout[-1200:] + out.stderr[-600:], file=sys.stderr)
            return None
        made = json.loads(line[len("surface: "):])
        files = []
        gain = brightness_gain(key, made["variants"][0]["albedo"], r)
        if abs(gain - 1.0) > 0.03:
            print(f"  {key}: brightness x{gain:.2f} (to the old tile's)")
        for i, v in enumerate(made["variants"]):
            stem = f"{surface}_2k" + ("" if i == 0 else f"_{LETTERS[i]}")
            rel = {k: Path("art") / "textures" / theme / f"{stem}{suffix}.webp"
                   for k, suffix in (("file", ""), ("normal_file", "_n"), ("orm_file", "_orm"))}
            (ROOT / rel["file"]).parent.mkdir(parents=True, exist_ok=True)
            albedo = Image.open(v["albedo"]).convert("RGB")
            if abs(gain - 1.0) > 0.03:
                albedo = albedo.point(lambda x: min(255, int(x * gain)))
            if r.get("grade"):
                # A colour grade on the painted tile (the kit's oak darkened to the beams' near-black brown).
                g = r["grade"]
                albedo = Image.merge("RGB", [ch.point(lambda x, k=k: min(255, int(x * k))) for ch, k in zip(albedo.split(), g)])
            albedo.save(ROOT / rel["file"], "WEBP", quality=92, method=6)
            Image.open(v["normal"]).convert("RGB").save(ROOT / rel["normal_file"], "WEBP", quality=95, method=6)
            orm = Image.open(v["orm"]).convert("RGB")
            orm.resize((orm.width // 2, orm.height // 2), Image.LANCZOS).save(ROOT / rel["orm_file"], "WEBP", quality=90,
                                                                               method=6)
            files.append({k: str(p) for k, p in rel.items()})
    print(f"surface: {key} ({made['tile_px']} px seamless, {len(files)} variant{'s' if len(files) > 1 else ''})")
    return files, spec


def _mean_lum(path):
    im = Image.open(path).convert("L").resize((64, 64), Image.BOX)
    return sum(im.getdata()) / (64.0 * 64.0 * 255.0)


def brightness_gain(key, new_albedo, recipe):
    """The new painted tile brought to the old tile's average brightness (the scenes' light was set by the old ones),
    within 0.85 to 1.8 so a dark surface stays darker; 1 for a surface with no old tile."""
    if "brightness" in recipe:
        return float(recipe["brightness"])
    theme, surface = key.split("/")
    old = ROOT / "art" / "textures" / theme / f"{surface}_hd.png"
    if not old.exists():
        old = ROOT / "art" / "textures" / theme / f"{surface}.png"
    if not old.exists():
        return 1.0
    return max(0.85, min(1.8, _mean_lum(old) / max(_mean_lum(new_albedo), 0.02)))


def derive(data, key, spec):
    """A surface made from another's set, turned a quarter (the kit's oak with its grain running up, for posts): every
    tile, normal map (its vectors turned with it) and ORM map, and an entry like the source's."""
    src_theme, src_surface = spec["from"].split("/")
    theme, surface = key.split("/")
    src = data["themes"][src_theme][src_surface]
    sets = [{"file": src["hd_file"], "normal_file": src["normal_file"], "orm_file": src["orm_file"]}] + src.get("variants", [])
    out = []
    for i, s in enumerate(sets):
        stem = f"{surface}_2k" + ("" if i == 0 else f"_{LETTERS[i]}")
        made = {}
        for k, suffix in (("file", ""), ("normal_file", "_n"), ("orm_file", "_orm")):
            im = Image.open(ROOT / s[k]).convert("RGB").transpose(Image.Transpose.ROTATE_90)
            if k == "normal_file":
                # A quarter turn anticlockwise turns the normal's (x, y) to (-y, x).
                r_, g_, b_ = im.split()
                im = Image.merge("RGB", [g_.point(lambda x: 255 - x), r_, b_])
            path = Path("art") / "textures" / theme / f"{stem}{suffix}.webp"
            (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
            im.save(ROOT / path, "WEBP", quality=92 if k != "normal_file" else 95, method=6)
            made[k] = str(path)
        out.append(made)
    entry = {k: v for k, v in src.items() if k in ("size", "wrap", "tile_world_units", "palette", "material")}
    entry.update({"file": out[0]["file"], "hd_file": out[0]["file"], "normal_file": out[0]["normal_file"],
                  "orm_file": out[0]["orm_file"], "derived_from": spec["from"], "turned": 90})
    if len(out) > 1:
        entry["variants"] = out[1:]
    data["themes"].setdefault(theme, {})[surface] = entry
    print(f"surface: {key} (from {spec['from']}, turned)")


def macro_noise(path, size=512, seed=7):
    """A soft, tileable value noise of a few octaves, grey, for large-scale variation."""
    import random
    rnd = random.Random(seed)
    acc = [[0.0] * size for _ in range(size)]
    total = 0.0
    for octave, amp in ((4, 1.0), (8, 0.55), (16, 0.3), (32, 0.15)):
        g = [[rnd.random() for _ in range(octave)] for _ in range(octave)]
        for y in range(size):
            fy = y * octave / size
            y0 = int(fy) % octave
            y1 = (y0 + 1) % octave
            ty = fy - int(fy)
            ty = ty * ty * (3 - 2 * ty)
            row = acc[y]
            for x in range(size):
                fx = x * octave / size
                x0 = int(fx) % octave
                x1 = (x0 + 1) % octave
                tx = fx - int(fx)
                tx = tx * tx * (3 - 2 * tx)
                top = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
                bot = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
                row[x] += (top + (bot - top) * ty) * amp
        total += amp
    lo = min(min(r) for r in acc)
    hi = max(max(r) for r in acc)
    img = Image.new("L", (size, size))
    img.putdata([int(255 * (v - lo) / (hi - lo)) for r in acc for v in r])
    img.save(path, "PNG")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--jobs", type=int, default=3)
    p.add_argument("--force", action="store_true", help="generate swatches again even where they exist")
    p.add_argument("--no-process", action="store_true")
    p.add_argument("--macro", action="store_true")
    a = p.parse_args()
    rec = json.loads(RECIPES.read_text())
    keys = [k for k in rec["surfaces"] if not a.only or k in a.only]
    data = json.loads(MANIFEST.read_text())
    if a.macro:
        macro_noise(ROOT / "art" / "textures" / "macro_noise.png")
        data["macro_file"] = "art/textures/macro_noise.png"
    failed = []
    if a.generate:
        todo = [(k, 0) for k in keys if a.force or not swatch(k, 0).exists()]
        if todo:
            gemini_budget.preflight(len(todo), "2K", "HD surface swatches")
            SWATCHES.mkdir(parents=True, exist_ok=True)
            # First patches first: the further variants are painted from them.
            for phase in (lambda t: t[1] == 0, lambda t: t[1] > 0):
                batch = [t for t in todo if phase(t) and (t[1] == 0 or swatch(t[0], 0).exists())]
                with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
                    for (k, i), ok in zip(batch, pool.map(lambda t: generate(rec, *t), batch)):
                        if not ok:
                            failed.append(f"{k} #{i + 1}")
    if not a.no_process:
        def wrap_of(key):
            theme, surface = key.split("/")
            return (data["themes"].get(theme, {}).get(surface) or {}).get("wrap", "xy")
        with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
            results = list(pool.map(lambda k: process(rec, k, wrap_of(k)), keys))
        for key, res in zip(keys, results):
            theme, surface = key.split("/")
            entry = data["themes"].setdefault(theme, {}).get(surface)
            r = rec["surfaces"][key]
            if res is None:
                failed.append(key)
                continue
            files, spec = res
            if entry is None:
                # A surface the kit adds: its HD tile is its only tile.
                entry = {"file": files[0]["file"], "size": SIZE, "wrap": "xy",
                         "tile_world_units": r.get("tile_world_units", 2.0), "palette": []}
                data["themes"][theme][surface] = entry
            entry["hd_file"] = files[0]["file"]
            entry["normal_file"] = files[0]["normal_file"]
            entry["orm_file"] = files[0]["orm_file"]
            entry["hd_source"] = str(swatch(key, 0).relative_to(ROOT))
            if len(files) > 1:
                entry["variants"] = files[1:]
            else:
                entry.pop("variants", None)
            if r.get("material"):
                entry["material"] = {**entry.get("material", {}), **r["material"]}
    for key, spec in rec.get("derived", {}).items():
        if a.only and spec["from"] not in a.only and key not in a.only:
            continue
        derive(data, key, spec)
    MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
    if failed:
        sys.exit(f"failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
