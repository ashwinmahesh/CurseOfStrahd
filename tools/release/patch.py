#!/usr/bin/env python3
"""A release's update patch (owner, 2026-10-09: in-place updates), and its release.json.

  python3 tools/release/patch.py --version 1.0.4 --out <release folder> [--godot <binary>] [--latest <url>]

The update commands (curseofstrahd.app/update.sh and update.ps1) fetch a patch instead of the whole game when the
player has the full download it builds on. A patch is cumulative: every file changed since that full download
("base"), made by Godot's --export-patch against the base's pack. core/patch_loader.gd loads it at startup.

The base is the one the published latest.json names. A release can only be a patch on it when nothing a pack can't
carry has changed since: the Godot version, project.godot (project settings are read before any pack loads), and no
file removed or renamed in a folder the game lists at run time (data/, narrative/, art/sprites/: a patch can add and
replace files, never take one away, and a listed folder would still show the old file). A removed script or scene is fine:
nothing asks for it any more. Otherwise this release is a full one and becomes the next base. Either way it writes <out>/release.json, which tools/publish_latest.sh on the site
turns into latest.json once the release's files are checked; with a patch, also <out>/patch.pck.
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


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--version", required=True)
	ap.add_argument("--out", type=Path, required=True)
	ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
	ap.add_argument("--godot-version", default=os.environ.get("GODOT_VERSION", ""))
	ap.add_argument("--latest", default=DOWNLOADS + "/latest.json")
	args = ap.parse_args()
	latest = fetch_json(args.latest)
	base = str(latest.get("base", ""))
	reason = why_full(base, str(latest.get("godot", "")), args.godot_version)
	release = {"version": args.version, "base": args.version, "godot": args.godot_version, "patch": None}
	if reason:
		print("patch: %s is a full release: %s" % (args.version, reason))
	else:
		name = "CurseOfStrahd-%s-windows.zip" % base
		with tempfile.TemporaryDirectory() as tmp:
			zpath = Path(tmp) / name
			print("patch: fetching %s's pack to diff against" % base)
			url = "%s/%s/%s" % (DOWNLOADS, base, name)
			with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=600) as r, \
					open(zpath, "wb") as f:
				shutil.copyfileobj(r, f, 1 << 24)
			with zipfile.ZipFile(zpath) as z:
				z.extract("CurseOfStrahd.pck", tmp)
			zpath.unlink()
			patch = args.out / "patch.pck"
			subprocess.run([args.godot, "--headless", "--path", ".", "--export-patch", "Windows", str(patch),
				"--patches", str(Path(tmp) / "CurseOfStrahd.pck")], check=True)
		release["base"] = base
		release["patch"] = {"file": "CurseOfStrahd-%s-patch-from-%s.pck" % (args.version, base),
			"sha256": sha256(patch), "size": patch.stat().st_size}
		print("patch: %s patches %s with %.1f MB" % (args.version, base, patch.stat().st_size / 1e6))
	(args.out / "release.json").write_text(json.dumps(release, indent=2) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
