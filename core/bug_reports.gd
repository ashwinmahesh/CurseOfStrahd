class_name BugReports
extends Node
## Report a bug (owner, 2026-10-11), in dev builds only. F12 anywhere, or Report a bug in the pause menu, keeps the
## screen as it was, pauses the game and opens BugReportScreen for what went wrong. Sent, it writes a report where
## every Claude on the project reads: ~/Documents/Obsidian Vault/CurseOfStrahd/Bug Reports/<date>T<time>-<title>/
## holds report.md (what he wrote; where the game was, the party, the settings and the build; this session's errors
## and the log's last lines, from ErrorWatch), screenshot.png, save.json (the game as it is now, as a save holds it)
## and errors.txt (this session's error report, when it has one). Copies only: nothing is written into his saves or
## settings.cfg. A Mac without that vault gets user://bug_reports/; STRAHD_BUG_REPORTS names another folder.
## Dev builds are the ones run from a checkout with the editor's Godot (make run, make run-main); an exported game (an
## export template) makes no node, so it has no key and no menu entry. UiFeel makes the one node; `current` is it.
## F12, not F8: a Mac keyboard's F8 without fn is play/pause, which opens Music.

const NODE_NAME := "BugReports"
const KEY := KEY_F12
## Where the project's notes live under the home folder and the environment variable that names another folder for reports,
## both from data/campaign.json "bug_reports" ({"vault": "...", "env": "..."}); without a vault reports go to FALLBACK.
const CONFIG := "res://data/campaign.json"
const FOLDER := "Bug Reports"
const FALLBACK := "user://bug_reports/"
## The picture's longest side at most: a Retina window is bigger than a bug needs.
const SHOT_MAX := 2560
## How many of the log's last lines go into the report.
const LOG_LINES := 80
## The kinds of problem the screen offers (one may be picked, or none).
const KINDS: Array[String] = ["Looks wrong", "Plays wrong", "Rules", "Words", "Sound", "Error"]
const README := """# Bug Reports

Reports from the game's Report a bug (F12, or the pause menu) in dev builds: make run and make run-main. One folder per
report, named by when it was made and the first words of what was written.

- report.md: what was written, where the game was (place, day, mode, the screen open), the party, the settings, the
  build, this session's errors and the log's last lines. `status:` starts as `open`; set it to `fixed <commit>` or
  `not a bug` once it's dealt with.
- screenshot.png: the screen as the report began (the game under the pause menu, from there).
- save.json: the game as it was, as a save holds it. To play it, copy it into the saves folder under a new name
  (never over a save) and load that slot; a test loads it with SaveSystem.load_from(<folder>, "save").
- errors.txt: that session's error report (user://saves/errors/), when it had errors.
"""

static var current: BugReports = null

## Where reports go: "" for folder()'s choice (tests point it elsewhere).
var dir := ""
var screen: BugReportScreen = null
var _opening := false
var _was_paused := false


static func enabled() -> bool:
	return OS.has_feature("editor") and not OS.has_feature("template")


func _init() -> void:
	name = NODE_NAME
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY or k.physical_keycode == KEY):
		get_viewport().set_input_as_handled()
		open()


func is_open() -> bool:
	return _opening or (screen != null and is_instance_valid(screen) and screen.is_inside_tree())


## Opens the report screen over everything, with the screen as it is. `cover`: a menu to hide first (the pause menu),
## so the picture is the game under it; it shows again when the report screen closes.
func open(cover: CanvasLayer = null) -> void:
	if is_open():
		return
	_opening = true
	if cover != null:
		cover.visible = false
		await _drawn()
	var shot := grab()
	var context := gather("the pause menu" if cover != null else "F12")
	var save := snapshot()
	_was_paused = get_tree().paused
	get_tree().paused = true   # nothing moves while he writes, and the keys he types reach no one else
	Cursors.show("pointer")
	screen = BugReportScreen.new()
	get_tree().root.add_child(screen)
	var back: WeakRef = weakref(cover) if cover != null else null
	screen.closed.connect(func() -> void: _closed(back.get_ref() as CanvasLayer if back != null else null))
	screen.open(self, shot, context, save)
	_opening = false


func _closed(cover: CanvasLayer) -> void:
	screen = null
	get_tree().paused = _was_paused
	if cover != null:
		cover.visible = true


## Waits until the screen has been drawn again (a frame, in a headless run, which draws nothing).
func _drawn() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


## The screen's last frame, at most SHOT_MAX on its longest side, or null (no screen: headless runs and tests).
func grab() -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGB8)
	var longest := maxi(img.get_width(), img.get_height())
	if longest > SHOT_MAX:
		var k := float(SHOT_MAX) / longest
		img.resize(roundi(img.get_width() * k), roundi(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	return img


## The game as it is now, as a save holds it (what the autosave writes, with the game's own slot as home_slot), or
## {} with no game going (the title screen). In a fight it holds the fight as its round began.
func snapshot() -> Dictionary:
	var st := GameState.story
	if st == null or st.party.is_empty():
		return {}
	var data := GameState.to_dict()
	data["home_slot"] = SaveSystem.current_slot
	return data


# --- Where the game is ----------------------------------------------------------------------------

## Where the game is now, for the screen and report.md: each value a line of text, but "party" (a line per member),
## "errors" (a line per error this session) and "log" (the log's last lines).
func gather(from: String) -> Dictionary:
	var st := GameState.story
	var going := st != null and not st.party.is_empty()
	var scene := get_tree().current_scene
	var out := {
		"from": from,
		"stamp": Time.get_datetime_string_from_system(false, false).replace(":", "-"),
		"when": Time.get_datetime_string_from_system(false, true),
		"scene": scene.scene_file_path if scene != null and scene.scene_file_path != "" else "none",
		"place": "none (no game going)",
		"place_id": "",
		"day": 0,
		"clock": "",
		"mode": _mode(),
		"screen": _screen_open(scene, from),
		"difficulty": "",
		"party": [] as Array[String],
		"settings": _settings(),
		"commit": "",
		"build": "",
		"system": "%s %s, Godot %s, %s" % [OS.get_name(), OS.get_version(), str(Engine.get_version_info().get("string", "")),
			RenderingServer.get_video_adapter_name()],
		"errors": _errors(),
		"error_report": ErrorWatch.session_report(),
		"log": _log(),
	}
	_build(out)
	if going:
		var loc := Compendium.shared().get_entry("locations", st.location)
		out["place"] = "%s (%s)" % [str(loc.get("name", st.location)), st.location] if st.location != "" else "nowhere yet"
		out["place_id"] = st.location
		out["day"] = st.day
		out["clock"] = "Day %d, %02d:%02d" % [st.day, floori(st.minute_of_day / 60.0), st.minute_of_day % 60]
		out["difficulty"] = Difficulty.of_options(st.options).name
		out["party"] = _party(st)
	return out


func _mode() -> String:
	var mode := str(ModeController.Mode.find_key(ModeController.mode)).capitalize()
	if ModeController.mode == ModeController.Mode.COMBAT:
		var round_no := int((GameState.combat_snapshot.get("data", {}) as Dictionary).get("round", 0))
		if round_no > 0:
			mode += ", round %d (the save holds the fight as this round began)" % round_no
	return mode


## What was open over the game: the game's screen (its class), a conversation, and where the report came from.
func _screen_open(scene: Node, from: String) -> String:
	var parts: Array[String] = []
	if scene != null and "screen" in scene:
		var s := scene.get("screen") as Node
		if s != null:
			var script := s.get_script() as Script
			parts.append(script.get_global_name() if script != null and script.get_global_name() != &"" else String(s.name))
	if scene != null and "dialogue" in scene and scene.get("dialogue") != null:
		parts.append("a conversation")
	var open := "none" if parts.is_empty() else ", ".join(parts)
	return "%s (reported with %s)" % [open, from]


func _party(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	var leader := st.leader_character()
	for ch in st.party:
		var line := "%s%s: %s, %d/%d HP" % [ch.name, " (leading)" if ch == leader else "", ch.class_summary(), ch.hp, ch.max_hp()]
		if ch.temp_hp > 0:
			line += " +%d temporary" % ch.temp_hp
		if not ch.conditions.is_empty():
			line += ", " + ", ".join(PackedStringArray(ch.conditions.keys()))
		out.append(line)
	for g in st.guests:
		out.append("%s (guest), %d/%d HP" % [g.name, g.hp, g.max_hp()])
	return out


func _settings() -> String:
	var window := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	return "look %s, graphics %s, %s %dx%d, exploring %s, fights %s, interface %d%%, text %d%%" % [Look.style(),
		str(Graphics.LABELS.get(Graphics.preset(), Graphics.preset())), "fullscreen" if GameSettings.fullscreen() else "window",
		window.x, window.y, "turn-based" if GameSettings.turn_based() else "in real time",
		"fast" if GameSettings.fast_combat() else "normal", roundi(GameSettings.ui_scale() * 100.0),
		roundi(GameSettings.text_scale() * 100.0)]


## The build: the checkout's own branch and commit, read from git.
func _build(out: Dictionary) -> void:
	var path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var head := _git(path, PackedStringArray(["log", "-1", "--format=%h %s"]))
	out["commit"] = head.get_slice(" ", 0)
	var branch := _git(path, PackedStringArray(["rev-parse", "--abbrev-ref", "HEAD"]))
	out["build"] = "a checkout%s at %s (%s)" % [" on " + branch if branch != "" else "", head if head != "" else "?", path]


static func _git(path: String, args: PackedStringArray) -> String:
	var said: Array = []
	var full := PackedStringArray(["-C", path])
	full.append_array(args)
	if OS.execute("git", full, said) != 0 or said.is_empty():
		return ""
	return str(said[0]).strip_edges().get_slice("\n", 0)


func _errors() -> Array[String]:
	var out: Array[String] = []
	for e in ErrorWatch.recent:
		out.append("[%s] %s at %s: %s" % [e.get("time", ""), "SCRIPT ERROR" if bool(e.get("script", false)) else "ERROR",
			e.get("where", ""), e.get("text", "")])
	return out


func _log() -> Array[String]:
	var out: Array[String] = []
	var lines := ErrorWatch.log_tail()
	for line in lines.slice(maxi(0, lines.size() - LOG_LINES)):
		out.append(line)
	return out


# --- Writing --------------------------------------------------------------------------------------

## Where reports go: the environment variable named by the config, else the vault's Bug Reports folder when that vault is on
## this Mac, else FALLBACK. An absolute path.
func folder() -> String:
	if dir != "":
		return ProjectSettings.globalize_path(dir)
	var env := str(setup().get("env", "BUG_REPORTS"))
	var named := OS.get_environment(env)
	if named != "":
		return named
	if vault() != "":
		var vault_dir := OS.get_environment("HOME").path_join(vault())
		if DirAccess.dir_exists_absolute(vault_dir):
			return vault_dir.path_join(FOLDER)
	return ProjectSettings.globalize_path(FALLBACK)


## data/campaign.json "bug_reports": {"vault": folder under the home folder, "env": environment variable}.
static func setup() -> Dictionary:
	if not FileAccess.file_exists(CONFIG):
		return {}
	return (JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) as Dictionary).get("bug_reports", {}) as Dictionary


static func vault() -> String:
	return str(setup().get("vault", ""))


## Writes a report: `text` is what he wrote (it may be empty), `kind` one of KINDS or "". Returns its folder, or ""
## when nothing could be written there.
func write(text: String, kind: String, shot: Image, context: Dictionary, save: Dictionary) -> String:
	var base := folder()
	var title := title_of(text, kind, context)
	var out := base.path_join("%s-%s" % [context.get("stamp", "report"), slug(title)])
	var n := 2
	while DirAccess.dir_exists_absolute(out):
		out = base.path_join("%s-%s-%d" % [context.get("stamp", "report"), slug(title), n])
		n += 1
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		return ""
	var files: Array[String] = []
	if shot != null and shot.save_png(out.path_join("screenshot.png")) == OK:
		files.append("screenshot.png")
	if not save.is_empty() and _store(out.path_join("save.json"), JSON.stringify(save, "\t")):
		files.append("save.json")
	var errors := str(context.get("error_report", ""))
	if errors != "" and FileAccess.file_exists(errors) and DirAccess.copy_absolute(errors, out.path_join("errors.txt")) == OK:
		files.append("errors.txt")
	if not _store(out.path_join("report.md"), markdown(text, kind, title, context, files)):
		return ""
	if not FileAccess.file_exists(base.path_join("README.md")):
		_store(base.path_join("README.md"), README)
	return out


static func _store(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


## The report's title: the first line he wrote (cut at a word, at most 72 letters), else the kind and the place.
static func title_of(text: String, kind: String, context: Dictionary) -> String:
	for line in text.split("\n", false):
		var t := line.strip_edges()
		if t == "":
			continue
		if t.length() > 72:
			t = t.left(72)
			t = t.left(t.rfind(" ")) if t.rfind(" ") > 40 else t
			t += "…"
		return t
	var place := str(context.get("place", "")).get_slice(" (", 0)
	return "%s%s" % [kind if kind != "" else "A bug", " in %s" % place if context.get("place_id", "") != "" else ""]


## A folder-safe name from a title: its first words, lower case, joined by hyphens.
static func slug(title: String) -> String:
	var words := RegEx.create_from_string("[^a-z0-9]+").sub(title.to_lower(), " ", true).strip_edges().split(" ", false)
	var out := "-".join(words.slice(0, 6)).left(48).trim_suffix("-")
	return out if out != "" else "bug"


## report.md: the front matter Claude sorts by (status, when, kind, place, mode, commit), what he wrote, the picture,
## where the game was, the files beside it, then this session's errors and the log's last lines.
static func markdown(text: String, kind: String, title: String, c: Dictionary, files: Array[String]) -> String:
	var md: Array[String] = ["---", "status: open", "reported: %s" % c.get("when", ""), "title: %s" % JSON.stringify(title),
		"kind: %s" % JSON.stringify(kind if kind != "" else "none"), "place: %s" % JSON.stringify(c.get("place_id", "")),
		"day: %d" % int(c.get("day", 0)), "mode: %s" % JSON.stringify(c.get("mode", "")),
		"commit: %s" % JSON.stringify(c.get("commit", "")), "---", "", "# " + title, ""]
	md.append(text.strip_edges() if text.strip_edges() != "" else "(Nothing written: the picture and the game's state are the report.)")
	md.append("")
	if "screenshot.png" in files:
		md.append_array(["![screenshot](screenshot.png)", ""])
	md.append_array(["## Where the game was", "",
		"- Reported: %s, with %s" % [c.get("when", ""), c.get("from", "")],
		"- Place: %s" % c.get("place", ""),
		"- Time: %s" % _or_none(c, "clock"),
		"- Mode: %s" % c.get("mode", ""),
		"- Open: %s" % c.get("screen", ""),
		"- Scene: %s" % c.get("scene", ""),
		"- Difficulty: %s" % _or_none(c, "difficulty"),
		"- Kind: %s" % (kind if kind != "" else "none picked")])
	var party := c.get("party", []) as Array
	md.append("- Party:%s" % ("" if not party.is_empty() else " none"))
	for line: Variant in party:
		md.append("  - %s" % line)
	md.append_array(["- Settings: %s" % c.get("settings", ""), "- Build: %s" % c.get("build", ""),
		"- System: %s" % c.get("system", ""), "", "## Files", ""])
	var about := {"screenshot.png": "the screen as the report began", "save.json":
		"the game as it was, as a save holds it: copy it into the saves folder under a new name to play it, or load it in a test with SaveSystem.load_from(<this folder>, \"save\")",
		"errors.txt": "this session's error report"}
	for f in files:
		md.append("- %s: %s" % [f, about.get(f, "")])
	if files.is_empty():
		md.append("- none")
	md.append_array(["", "## Errors this session", ""])
	md.append_array(_fenced(c.get("errors", []) as Array, "none"))
	md.append_array(["", "## The log's last lines", ""])
	md.append_array(_fenced(c.get("log", []) as Array, "none (headless runs keep no log)"))
	md.append("")
	return "\n".join(md)


static func _or_none(c: Dictionary, key: String) -> String:
	var v := str(c.get(key, ""))
	return v if v != "" else "none"


static func _fenced(lines: Array, none: String) -> Array[String]:
	if lines.is_empty():
		return [none]
	var out: Array[String] = ["```text"]
	for line: Variant in lines:
		out.append(str(line).replace("```", "'''"))
	out.append("```")
	return out
