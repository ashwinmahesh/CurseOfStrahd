class_name WhatsNew
extends RefCounted
## The title screen's What's new (Q2): what changed on main since the player last opened the game. make play writes
## the list (builds/play_build.json, tools/play/whats_new.py) each time it moves the play copy forward; the panel opens
## by itself on the title when something is new, and the title's What's new button opens the latest changes any time.
## Only the play copy has the list, so a working checkout's title shows neither.

const BUILD_PATH := "res://builds/play_build.json"
## The first time (nothing seen yet), the newest few days of changes.
const FIRST_DAYS := 3
const MAX_SHOWN := 40
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
	"November", "December"]
const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

## Where the newest change the player has seen is kept, and the list itself when set (tests and captures).
static var seen_path := "user://whats_new.cfg"
static var build_override: Dictionary = {}


## builds/play_build.json: {commit, committed, committed_at, changes: [{commit, date, at, lines}]}, newest first.
static func build() -> Dictionary:
	if not build_override.is_empty():
		return build_override
	if not FileAccess.file_exists(BUILD_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))
	return data as Dictionary if data is Dictionary else {}


static func available() -> bool:
	return not changes().is_empty()


static func changes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Variant in build().get("changes", []):
		if c is Dictionary:
			out.append(c as Dictionary)
	return out


## The commit time of the newest change the player has seen (0: never opened the play copy).
static func seen_at() -> int:
	var cfg := ConfigFile.new()
	cfg.load(seen_path)
	return int(cfg.get_value("whats_new", "seen_at", 0))


static func mark_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(seen_path)
	cfg.set_value("whats_new", "seen_at", maxi(seen_at(), int(build().get("committed_at", 0))))
	cfg.save(seen_path)


## The changes the player hasn't seen, newest first: those after the newest one they saw, or the newest FIRST_DAYS
## days' worth the first time.
static func unseen() -> Array[Dictionary]:
	var all := changes()
	var out: Array[Dictionary] = []
	if all.is_empty():
		return out
	var since := seen_at()
	if since == 0:
		since = int(all[0].get("at", 0)) - FIRST_DAYS * 86400 - 1
	for c in all:
		if int(c.get("at", 0)) > since and out.size() < MAX_SHOWN:
			out.append(c)
	return out


## The title's hook: opens the panel when there's something new, only on the game's own title (never in a capture).
static func show_if_new(menu: Node) -> void:
	if menu.is_inside_tree() and menu.get_tree().current_scene == menu and not unseen().is_empty():
		open(menu)


## The panel over `parent`: the unseen changes, or the latest ones when nothing is new. Closing it marks them seen.
static func open(parent: Node) -> CanvasLayer:
	var fresh := unseen()
	var list: Array[Dictionary] = fresh if not fresh.is_empty() else changes().slice(0, MAX_SHOWN)
	var first := seen_at() == 0
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.name = "WhatsNew"
	parent.add_child(layer)
	var close := func() -> void:
		mark_seen()
		layer.queue_free()
	var esc := _EscCloses.new()
	esc.close = close
	layer.add_child(esc)
	var frame := UiKit.screen_frame(layer, "What's new", Vector2(980, 720))
	var lead := "Since you last played" if not fresh.is_empty() and not first else \
		"The latest changes" if fresh.is_empty() else "The last few days' changes"
	var top := HBoxContainer.new()
	top.add_child(UiKit.label(lead, 18, "parchment"))
	top.add_child(UiParts.gap())
	var info := build()
	top.add_child(UiKit.label("This copy: main at %s, %s" % [str(info.get("commit", "?")),
		_day_name(str(info.get("committed", "")).substr(0, 10))], 13, "parchment"))
	frame.add_child(top)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var day := ""
	for c in list:
		if str(c.get("date", "")) != day:
			day = str(c.get("date", ""))
			if body.get_child_count() > 0:
				body.add_child(_gap(6))
			body.add_child(UiParts.section(_day_name(day)))
		for line: Variant in c.get("lines", []):
			body.add_child(_bullet(str(line)))
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(body))
	frame.add_child(pane)
	frame.add_child(UiParts.primary_button("Close", close))
	return layer


## "2026-10-07" -> "Wednesday 7 October".
static func _day_name(date: String) -> String:
	if date.length() < 10:
		return date
	var d := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_string(date + "T12:00:00"))
	return "%s %d %s" % [WEEKDAYS[int(d["weekday"])], int(d["day"]), MONTHS[int(d["month"]) - 1]]


static func _bullet(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := UiKit.label("•", 15, "gilt")
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dot)
	row.add_child(UiKit.label(text, 15, "vellum", 840))
	return row


static func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## Escape closes the panel, as on the other framed screens.
class _EscCloses extends Node:
	var close: Callable

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close.call()
