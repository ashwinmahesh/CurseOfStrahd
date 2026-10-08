#!/usr/bin/env python3
"""Builds the Mac app around an exported game pack, as Godot's macOS exporter would.

  python3 tools/release/mac_app.py --pck <exported .pck> --out <folder> [--version 1.0.0]

Why not Godot's own macOS export: for Apple silicon it refuses unless every texture is also imported as ETC2/ASTC,
which would double the import cache in every checkout. Apple silicon Macs read the BPTC/S3TC textures we already
import (the editor runs on them), so the Windows export's pack is the Mac's pack too. This puts it in Godot's universal
macOS template (from the installed 4.7.2 export templates), fills in Info.plist, signs the app ad hoc (Apple silicon
won't run unsigned code; Gatekeeper still asks on first open, since it isn't notarized) and zips it with ditto.
Writes <out>/Curse of Strahd.app and <out>/CurseOfStrahd-macos.zip.
"""
import argparse
import shutil
import subprocess
import zipfile
from pathlib import Path

NAME = "Curse of Strahd"
BUNDLE_ID = "app.curseofstrahd.game"
COPYRIGHT = "Unofficial fan game. Not affiliated with Wizards of the Coast."
TEMPLATES = Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip"


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--pck", type=Path, required=True)
	ap.add_argument("--out", type=Path, required=True)
	ap.add_argument("--version", default="1.0.0")
	args = ap.parse_args()
	out = args.out.resolve()
	out.mkdir(parents=True, exist_ok=True)
	app = out / (NAME + ".app")
	shutil.rmtree(app, ignore_errors=True)
	with zipfile.ZipFile(TEMPLATES) as z:
		for info in z.infolist():
			if not info.filename.startswith("macos_template.app/") or info.is_dir():
				continue
			rel = info.filename[len("macos_template.app/"):]
			if rel.endswith("godot_macos_debug.universal"):
				continue
			if rel.endswith("godot_macos_release.universal"):
				rel = "Contents/MacOS/" + NAME
			dest = app / rel
			dest.parent.mkdir(parents=True, exist_ok=True)
			dest.write_bytes(z.read(info))
	(app / "Contents/MacOS" / NAME).chmod(0o755)
	plist = (app / "Contents/Info.plist").read_text()
	fill = {
		"$binary": NAME, "$name": NAME, "$bundle_identifier": BUNDLE_ID, "$short_version": args.version,
		"$version": args.version, "$signature": "????", "$copyright": COPYRIGHT,
		"$app_category": "role-playing-games", "$min_version_arm64": "11.00", "$min_version_x86_64": "10.15",
		"$highres": "\t<true/>", "$liquid_glass_icon": "", "$usage_descriptions": "", "$additional_plist_content": "",
		"$platfbuild": "", "$sdkver": "", "$sdkbuild": "", "$sdkname": "", "$xcodever": "", "$xcodebuild": "",
	}
	# Longest first, so $min_version_arm64 isn't caught by a shorter key.
	for key in sorted(fill, key=len, reverse=True):
		plist = plist.replace(key, fill[key])
	assert "$" not in plist, "Info.plist still has a placeholder"
	(app / "Contents/Info.plist").write_text(plist)
	shutil.copyfile(args.pck, app / "Contents/Resources" / (NAME + ".pck"))
	subprocess.run(["codesign", "--force", "--deep", "--timestamp=none", "--sign", "-", str(app)], check=True)
	subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
	archive = out / "CurseOfStrahd-macos.zip"
	archive.unlink(missing_ok=True)
	subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)], check=True)
	print("mac_app: %s (%.2f GB zipped)" % (archive, archive.stat().st_size / 1e9))


if __name__ == "__main__":
	main()
