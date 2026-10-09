#!/usr/bin/env python3
"""Builds the Mac app around an exported game pack, as Godot's macOS exporter would.

  python3 tools/release/mac_app.py --pck <exported .pck> --out <folder> [--version 1.0.0]

Why not Godot's own macOS export: for Apple silicon it refuses unless every texture is also imported as ETC2/ASTC,
which would double the import cache in every checkout. Apple silicon Macs read the BPTC/S3TC textures we already
import (the editor runs on them), so the Windows export's pack is the Mac's pack too. This puts it in Godot's universal
macOS template (from the installed 4.7.2 export templates), fills in Info.plist, signs the app ad hoc (Apple silicon
won't run unsigned code; Gatekeeper still asks on first open, since it isn't notarized) and zips it. On a Mac that's
codesign and ditto; elsewhere (the release workflow's Linux runner) rcodesign and zip.
Writes <out>/Curse of Strahd.app and <out>/CurseOfStrahd-macos.zip.

With a Developer ID it signs the app properly instead (owner, 2026-10-08): set MAC_SIGN_P12 and
MAC_SIGN_P12_PASSWORD_FILE (paths to the Developer ID Application certificate and a file holding its password) to sign
with the hardened runtime, with rcodesign, on a Mac too. The game loads no native plugins, so the hardened runtime needs
no entitlements. Apple notarizes the disk image .github/workflows/mac-dmg.yml makes from this app, not this zip: the
notary service can't read zips holding a file over 4 GiB (Zip64), and the game's pack is about 8.5 GB. Notarizing the
disk image covers the app inside it, so Gatekeeper also lets the zip's copy open once it can check with Apple.
"""
import argparse
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

NAME = "Curse of Strahd"
BUNDLE_ID = "app.curseofstrahd.game"
COPYRIGHT = "Unofficial fan game. Not affiliated with Wizards of the Coast."
# Where Godot keeps export templates on a Mac, and on Linux.
TEMPLATE_DIRS = [Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable",
	Path.home() / ".local/share/godot/export_templates/4.7.2.stable"]


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
	templates = next((d / "macos.zip" for d in TEMPLATE_DIRS if (d / "macos.zip").exists()), None)
	if templates is None:
		raise SystemExit("mac_app: Godot's 4.7.2 macOS export template isn't installed")
	with zipfile.ZipFile(templates) as z:
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
	# Our icon (tools/release/make_icon.py) in place of Godot's.
	shutil.copyfile(Path(__file__).resolve().parent / "app_icon.icns", app / "Contents/Resources/icon.icns")
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
	archive = out / "CurseOfStrahd-macos.zip"
	archive.unlink(missing_ok=True)
	p12 = os.environ.get("MAC_SIGN_P12", "")
	if p12:
		subprocess.run(["rcodesign", "sign", "--p12-file", p12, "--p12-password-file",
			os.environ["MAC_SIGN_P12_PASSWORD_FILE"], "--code-signature-flags", "runtime", str(app)], check=True)
		if shutil.which("ditto"):
			subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)], check=True)
		else:
			subprocess.run(["zip", "-q", "-r", "-y", str(archive), app.name], cwd=out, check=True)
	elif shutil.which("codesign"):
		subprocess.run(["codesign", "--force", "--deep", "--timestamp=none", "--sign", "-", str(app)], check=True)
		subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
		subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)], check=True)
	else:
		# rcodesign with no certificate signs ad hoc, as codesign --sign - does.
		subprocess.run(["rcodesign", "sign", str(app)], check=True)
		subprocess.run(["zip", "-q", "-r", "-y", str(archive), app.name], cwd=out, check=True)
	how = "Developer ID signed" if p12 else "signed ad hoc"
	print("mac_app: %s (%s, %.2f GB zipped)" % (archive, how, archive.stat().st_size / 1e9))


if __name__ == "__main__":
	main()
