extends Node
## In-place updates (owner, 2026-10-09). A release whose project settings and engine match an earlier full download
## also ships a patch: a pack of every file changed since that download (Godot's --export-patch). The update commands
## (curseofstrahd.app/update.sh and update.ps1) put it at user://patches/patch.pck, beside the saves and outside the app
## (so the Mac app's signature stays whole), with user://patches/patch.json naming the full download it builds on
## ("base") and the version it brings ("version"). This is the first autoload and loads the patch in _init, before any
## other autoload, scene or script loads, so every one of them comes from the patch. A patch for a different full
## download (an older one, after a fresh install) is left unused. It names no other script, and can't itself be patched.

const DIR := "user://patches/"

## The version being played: the full download's (application/config/version, set by the release workflow), or the
## loaded patch's. Empty when running from the project (the editor, make run, tests), so no patch loads there.
static var version := ""
## Why a patch in the folder wasn't used ("" when it was, or when there was none).
static var skipped := ""


func _init() -> void:
	version = str(ProjectSettings.get_setting("application/config/version", ""))
	if version == "" or not FileAccess.file_exists(DIR + "patch.json"):
		return
	var info := read_info(DIR + "patch.json")
	skipped = check(info, version, FileAccess.file_exists(DIR + "patch.pck"))
	if skipped == "" and not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(DIR + "patch.pck")):
		skipped = "patch.pck couldn't be read"
	if skipped != "":
		push_warning("PatchLoader: not using the patch: %s" % skipped)
		return
	version = str(info["version"])


## patch.json as a Dictionary; empty when it's missing or isn't a JSON object.
static func read_info(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()   # JSON.parse_string would log an error for a damaged file
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


## Why the patch described by `info` can't go on the full download `base` ("" when it can).
static func check(info: Dictionary, base: String, have_pack: bool) -> String:
	if not info.has("base") or not info.has("version"):
		return "patch.json doesn't name its base and version"
	if str(info["base"]) != base:
		return "it builds on %s, and this is %s" % [info["base"], base]
	if not have_pack:
		return "patch.pck is missing"
	return ""
