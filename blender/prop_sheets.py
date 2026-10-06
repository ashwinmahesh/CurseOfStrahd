"""Cuts a batch of prop sources (single images or 2 x 2 sheets) into billboard props (docs/art/set_dressing.md).

blender -b --python blender/prop_sheets.py -- --jobs <jobs.json>

jobs.json: [{"src": "art/generated/props/sheet_x.png", "layout": "2x2",
             "items": [{"id": "harpsichord", "slot": 2, "height": 1.0, "mount": "stand", "saturate": 1.0}, ...]}]
Each item has a `height` or a `width` in world units (one unit = 5 ft). Written by tools/art/build_props.py, which
also merges every result into art/sprites/props/manifest.json.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402
import propsheet  # noqa: E402

MANIFEST = propsheet.PROPS_DIR / "manifest.json"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--jobs", required=True)
    a = p.parse_args(sys.argv[sys.argv.index("--") + 1:])
    jobs = json.loads(Path(a.jobs).read_text())
    data = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    props = data.setdefault("props", {})
    failed = []
    for job in jobs:
        src = cutout.ROOT / job["src"]
        parts = propsheet.split(cutout.load_rgba(src), job.get("layout", "1x1"))
        for item in job["items"]:
            part = parts[item.get("slot", 0)]
            if part is None:
                print(f"prop failed: {item['id']} (slot {item.get('slot', 0)} of {job['src']} is empty)")
                failed.append(item["id"])
                continue
            props[item["id"]] = propsheet.finish(part, item["id"], job["src"], height=item.get("height"),
                                                 width=item.get("width"), max_px=item.get("max", 512),
                                                 saturate=item.get("saturate", 1.0), mount=item.get("mount", "stand"))
            if job.get("layout", "1x1") != "1x1":
                props[item["id"]]["slot"] = item.get("slot", 0)
    MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
    if failed:
        print("props failed: " + ", ".join(failed))


main()
