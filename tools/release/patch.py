#!/usr/bin/env python3
"""A release's update patches (owner, 2026-10-09: in-place updates), and its release.json.

  python3 tools/release/patch.py --version 1.0.5 --out <release folder> [--godot <binary>] [--latest <url>] [--plan]

The update commands (curseofstrahd.app/update.sh and update.ps1) fetch a patch instead of the whole game when the
player has a full download a patch builds on. A patch is cumulative: every file changed since that full download
("base"), made by Godot's --export-patch against the base's pack. core/patch_loader.gd loads it at startup when its
base is the version the installed game reports.

Every release patches every earlier full download back to the first base (owner, 2026-10-12: any version from 1.0.3 on
updates to the latest with a patch). The installed game's loader only ever loads one patch, matched to its own full
version, so each base gets a cumulative patch of its own rather than a chain: the bases are those the published
latest.json patches, its base, and its own version (every release also ships a full download). A base can only be
patched when nothing a pack can't carry has changed since: the Godot version, project.godot (project settings are read
before any pack loads), and no file removed or renamed in a folder the game lists at run time (data/, narrative/,
art/sprites/: a patch can add and replace files, never take one away, and a listed folder would still show the old
file). A removed script or scene is fine: nothing asks for it any more. A base that can't be patched gets the full
download; when none can, this release is a full one and the only base for the next.

It writes <out>/release.json, which tools/publish_latest.sh on the site turns into latest.json once the release's files
are checked: "patches" lists each base with its file, size and SHA-256, and "base" and "patch" name the oldest one, for
update commands from before the list. The patches themselves go in <out>/patches/, named as release.json names them.
--plan prints the bases and why any can't be patched, and fetches and exports nothing.
Run after make release, from the repo root, with the import done.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

DOWNLOADS = "https://downloads.curseofstrahd.app"
# Folders the game lists at run time, where a file a patch can't remove would still be found: data/ (the compendium,
# cutscenes, endings, schedules), narrative/ (banter, camp talks, the Narrator) and art/sprites/ (the sprite gallery).
# Everything else is loaded by name, so a removed sound or picture there just goes unused.
LISTED = ("data/", "narrative/", "art/sprites/")
# Cloudflare turns away Python's default user agent.
HEADERS = {"User-Agent": "curseofstrahd-release (+https://curseofstrahd.app)"}


def fetch_json(url: str) -> dict:
	try:
		with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as r:
			data = json.load(r)
		return data if isinstance(data, dict) else {}
	except Exception as e:   # no latest.json yet, or the site's down: a full release is always safe
		print("patch: couldn't read %s (%s)" % (url, e))
		return {}


def git(*args: str) -> subprocess.CompletedProcess:
	return subprocess.run(["git", *args], capture_output=True, text=True)


def version_key(v: str) -> tuple:
	return tuple(int(p) for p in v.split(".")) if v.replace(".", "").isdigit() else (0,)


def bases_of(latest: dict, version: str) -> list:
	"""The full downloads this release patches, oldest first: those the published release patches, the one it builds
	on, and the published release itself."""
	found = {str(p.get("base", "")) for p in (latest.get("patches") or []) if isinstance(p, dict)}
	found |= {str(latest.get("base", "")), str(latest.get("version", ""))}
	return sorted((b for b in found if b and b != version), key=version_key)


def why_full(base: str, base_godot: str, godot: str) -> str:
	"""Why this release can't be a patch on `base` ("" when it can)."""
	if not base:
		return "no published release names a base"
	tag = "v" + base
	if git("rev-parse", "-q", "--verify", "refs/tags/" + tag).returncode != 0:
		fetched = git("fetch", "-q", "--no-tags", "--depth=1", "origin", "refs/tags/%s:refs/tags/%s" % (tag, tag))
		if fetched.returncode != 0:
			return "the tag %s isn't on GitHub" % tag
	if base_godot != godot:
		return "Godot changed (%s on %s, %s now)" % (base_godot or "unknown", base, godot)
	if git("diff", "--quiet", tag, "HEAD", "--", "project.godot").returncode != 0:
		return "project settings changed since %s" % base
	gone = []
	for line in git("diff", "--name-status", "-M", "--diff-filter=DR", tag, "HEAD").stdout.splitlines():
		old = line.split("\t")[1]   # "D\tpath" or "R100\told\tnew": the old path is what lingers in the base pack
		if old.startswith(LISTED):
			gone.append(old)
	if gone:
		return "%d file(s) removed or renamed since %s in folders the game lists, e.g. %s" % (len(gone), base, gone[0])
	return ""


def sha256(path: Path) -> str:
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for block in iter(lambda: f.read(1 << 20), b""):
			h.update(block)
	return h.hexdigest()


def export_patch(base: str, version: str, godot: str, folder: Path) -> dict:
	"""Exports the patch on `base` into `folder`, against the base's own pack (from its Windows download, which the Mac
	download's pack matches), and returns its entry for release.json. One base's pack at a time: each is ~8.5 GB."""
	name = "CurseOfStrahd-%s-windows.zip" % base
	file = "CurseOfStrahd-%s-patch-from-%s.pck" % (version, base)
	patch = folder / file
	with tempfile.TemporaryDirectory() as tmp:
		zpath = Path(tmp) / name
		print("patch: fetching %s's pack to diff against" % base, flush=True)
		url = "%s/%s/%s" % (DOWNLOADS, base, name)
		with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=600) as r, \
				open(zpath, "wb") as f:
			shutil.copyfileobj(r, f, 1 << 24)
		with zipfile.ZipFile(zpath) as z:
			z.extract("CurseOfStrahd.pck", tmp)
		zpath.unlink()
		subprocess.run([godot, "--headless", "--path", ".", "--export-patch", "Windows", str(patch),
			"--patches", str(Path(tmp) / "CurseOfStrahd.pck")], check=True)
	print("patch: %s patches %s with %.1f MB" % (version, base, patch.stat().st_size / 1e6), flush=True)
	return {"base": base, "file": file, "sha256": sha256(patch), "size": patch.stat().st_size}


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--version", required=True)
	ap.add_argument("--out", type=Path, required=True)
	ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
	ap.add_argument("--godot-version", default=os.environ.get("GODOT_VERSION", ""))
	ap.add_argument("--latest", default=DOWNLOADS + "/latest.json")
	ap.add_argument("--plan", action="store_true", help="print the bases and reasons only")
	args = ap.parse_args()
	latest = fetch_json(args.latest)
	patchable = []
	for base in bases_of(latest, args.version):
		# Each base's own Godot version, from its release.json (the latest's, for the latest).
		info = latest if base == str(latest.get("version", "")) else fetch_json("%s/%s/release.json" % (DOWNLOADS, base))
		reason = why_full(base, str(info.get("godot", "")), args.godot_version)
		if reason:
			print("patch: %s needs the full download: %s" % (base, reason))
		else:
			print("patch: %s gets a patch" % base)
			patchable.append(base)
	if not patchable:
		print("patch: %s is a full release" % args.version)
	if args.plan:
		return 0
	patches = []
	if patchable:
		folder = args.out / "patches"
		folder.mkdir(parents=True, exist_ok=True)
		for base in patchable:
			patches.append(export_patch(base, args.version, args.godot, folder))
	oldest = patches[0] if patches else None
	release = {"version": args.version, "base": oldest["base"] if oldest else args.version, "godot": args.godot_version,
		"patch": {k: oldest[k] for k in ("file", "sha256", "size")} if oldest else None, "patches": patches}
	(args.out / "release.json").write_text(json.dumps(release, indent=2) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
