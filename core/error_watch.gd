extends Node
## Errors you can see (P11). A script error during play shows a small notice at the bottom right, instead of passing
## unseen or leaving a grey screen, and goes into an error report beside the saves: user://saves/errors/<session>/
## report.txt, with a copy of the newest save and where the game was (scene, place, day, mode, build). Godot's log
## hook (OS.add_logger) catches the errors. It can be called from any thread, so the hook only queues them and this
## node writes and shows them on the main thread. The notice offers the way back to the title, where Continue loads
## the newest save: the way out of a grey screen. It stays up while an error has left no scene, else it fades.
## The first autoload, so it also catches errors in the others. It is off in headless runs (tests, make smoke) and when
## the first scene is a tool's or a test's (make capture), so only real play is reported. It names no other script
## or autoload directly: the notice must still work when a broken script is the problem.

const REPORTS := "user://saves/errors/"
const KEEP_REPORTS := 20
## A notice fades after this long, unless the error left no scene.
const NOTICE_SECONDS := 14.0
## The same error (file and line) is written out in full this many times a session, then only counted.
const REPEATS_WRITTEN := 3
const ENTRIES_WRITTEN := 300

## Off, undecided or on (decided on the first frame, from the first scene).
var active := -1
## Where this session's report goes (tests point it elsewhere).
var reports_dir := REPORTS
var save_dir := "user://saves/"
var catcher: Catcher = null
var _session := ""
var _written := 0
var _counts: Dictionary = {}
var _notice: CanvasLayer = null
var _notice_text: Label = null
var _notice_more: Label = null
var _shown := 0
var _age := 0.0
var _palette: Dictionary = {}


## The hook Godot calls for every error and message. Errors and script errors are queued; warnings, shader errors
## and messages aren't.
class Catcher extends Logger:
	var queue: Array[Dictionary] = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_ERROR and error_type != ERROR_TYPE_SCRIPT:
			return
		var trace := ""
		var where := "%s:%d" % [file, line]
		for b in script_backtraces:
			if b != null and not b.is_empty():
				trace += b.format()
				if error_type == ERROR_TYPE_ERROR and b.get_frame_count() > 0:
					# An engine error raised from a script (push_error, a failed load) is the script's line.
					where = "%s:%d" % [b.get_frame_file(0), b.get_frame_line(0)]
		var entry := {"script": error_type == ERROR_TYPE_SCRIPT, "function": function, "where": where,
			"text": code if rationale == "" else "%s (%s)" % [rationale, code], "trace": trace,
			"time": Time.get_datetime_string_from_system(false, true)}
		mutex.lock()
		if queue.size() < 500:
			queue.append(entry)
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[Dictionary]:
		mutex.lock()
		var out := queue.duplicate()
		queue.clear()
		mutex.unlock()
		return out


func _init() -> void:
	if DisplayServer.get_name() != "headless":
		catcher = Catcher.new()
		OS.add_logger(catcher)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(catcher != null)


func _exit_tree() -> void:
	if catcher != null:
		OS.remove_logger(catcher)


func _process(delta: float) -> void:
	if active == -1:
		var first := get_tree().current_scene
		var path := first.scene_file_path if first != null else ""
		active = 0 if path.begins_with("res://tools/") or path.begins_with("res://tests/") else 1
	var queued := catcher.take()
	if active == 0:
		return
	for e in queued:
		report(e)
	if _notice != null and get_tree().current_scene != null:
		_age += delta
		if _age > NOTICE_SECONDS:
			dismiss()
		elif _age > NOTICE_SECONDS - 1.0:
			(_notice.get_child(0) as Control).modulate.a = NOTICE_SECONDS - _age


## One error: written to this session's report, then shown.
func report(e: Dictionary) -> void:
	var key := "%s %s" % [e.get("where", ""), e.get("text", "")]
	_counts[key] = int(_counts.get(key, 0)) + 1
	if _counts[key] <= REPEATS_WRITTEN and _written < ENTRIES_WRITTEN:
		_write(e, _counts[key])
	show_notice(e)


## The report file for this session (made, with a copy of the newest save, at its first error).
func report_path() -> String:
	if _session == "":
		_session = Time.get_datetime_string_from_system().replace(":", "-")
		var dir := reports_dir.path_join(_session)
		DirAccess.make_dir_recursive_absolute(dir)
		var save := _newest_save()
		if save != "":
			DirAccess.copy_absolute(save, dir.path_join(save.get_file()))
		var f := FileAccess.open(dir.path_join("report.txt"), FileAccess.WRITE)
		if f == null:
			_written = ENTRIES_WRITTEN   # nowhere to write: stop trying (each failure would be an error of its own)
		else:
			f.store_string("Curse of Strahd error report\nStarted: %s\nBuild: %s\nNewest save: %s\n\n" % [
				Time.get_datetime_string_from_system(false, true), _build(),
				save.get_file() + " (copied here)" if save != "" else "none"])
			f.close()
		_prune()
	return reports_dir.path_join(_session).path_join("report.txt")


func _write(e: Dictionary, nth: int) -> void:
	var f := FileAccess.open(report_path(), FileAccess.READ_WRITE)
	if f == null:
		_written = ENTRIES_WRITTEN
		return
	f.seek_end()
	var kind := "SCRIPT ERROR" if bool(e.get("script", false)) else "ERROR"
	f.store_string("[%s] %s at %s%s\n  %s\n  %s\n" % [e.get("time", ""), kind, e.get("where", ""),
		" (again: %d)" % nth if nth > 1 else "", e.get("text", ""), _context()])
	var trace := str(e.get("trace", "")).strip_edges()
	if trace != "" and nth == 1:
		f.store_string("  " + trace.replace("\n", "\n  ") + "\n")
	if nth == REPEATS_WRITTEN:
		f.store_string("  (later repeats of this one are only counted on screen)\n")
	f.store_string("\n")
	f.close()
	_written += 1


## Where the game was: scene, place, day and mode, read by name so a broken autoload can't stop the report.
func _context() -> String:
	var scene := get_tree().current_scene
	var parts: Array[String] = ["scene: %s" % (scene.scene_file_path if scene != null else "none (grey screen)")]
	var state := get_node_or_null("/root/GameState")
	var story: Variant = state.get("story") if state != null else null
	if story is Object:
		parts.append("location: %s" % str((story as Object).get("location")))
		parts.append("day: %s" % str((story as Object).get("day")))
	var modes := get_node_or_null("/root/ModeController")
	if modes != null and modes.get_script() is Script:
		var names: Variant = (modes.get_script() as Script).get_script_constant_map().get("Mode", {})
		var mode: Variant = modes.get("mode")
		if names is Dictionary:
			parts.append("mode: %s" % str((names as Dictionary).find_key(mode)))
	return ", ".join(parts)


## The play copy's commit (make play writes it), or "a working checkout".
func _build() -> String:
	var path := "res://builds/play_build.json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			return "the play copy at main %s (%s)" % [(data as Dictionary).get("commit", "?"),
				(data as Dictionary).get("committed", "")]
	return "a working checkout (%s)" % ProjectSettings.globalize_path("res://")


func _newest_save() -> String:
	var dir_path := save_dir
	var saves := get_node_or_null("/root/SaveSystem")
	if saves != null and saves.get("save_dir") is String:
		dir_path = str(saves.get("save_dir"))
	var newest := ""
	var newest_at := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	for f in dir.get_files():
		var p := dir_path.path_join(f)
		if f.ends_with(".json") and FileAccess.get_modified_time(p) >= newest_at:
			newest_at = FileAccess.get_modified_time(p)
			newest = p
	return newest


## Keeps the newest KEEP_REPORTS sessions' reports.
func _prune() -> void:
	var dir := DirAccess.open(reports_dir)
	if dir == null:
		return
	var sessions := Array(dir.get_directories())
	sessions.sort()
	while sessions.size() > KEEP_REPORTS:
		var old := reports_dir.path_join(str(sessions.pop_front()))
		var inner := DirAccess.open(old)
		if inner != null:
			for f in inner.get_files():
				DirAccess.remove_absolute(old.path_join(f))
		DirAccess.remove_absolute(old)


# ---- the notice ---------------------------------------------------------------------------------------------------

func show_notice(e: Dictionary) -> void:
	_age = 0.0
	if _notice == null:
		_build_notice()
	else:
		(_notice.get_child(0) as Control).modulate.a = 1.0
	_shown += 1
	if _shown == 1:
		var text := str(e.get("text", "")).strip_edges()
		_notice_text.text = "%s\n%s" % [text.substr(0, 160) + ("…" if text.length() > 160 else ""),
			str(e.get("where", "")).get_file()]
	else:
		_notice_more.text = "and %d more since" % (_shown - 1)
		_notice_more.visible = true


func dismiss() -> void:
	if _notice != null:
		_notice.queue_free()
	_notice = null
	_shown = 0


func _build_notice() -> void:
	_notice = CanvasLayer.new()
	_notice.layer = 120
	_notice.name = "ErrorNotice"
	add_child(_notice)
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(_colour("ui_black", Color(0.06, 0.04, 0.05)), 0.96)
	s.border_color = _colour("vampire_red", Color(0.6, 0.1, 0.1))
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", s)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -520
	p.offset_right = -24
	p.offset_bottom = -24
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notice.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	var title := _label("Something went wrong", 19, "gilt_light")
	title.add_theme_font_override("font", UiKit.display_font())   # the game's own book hand, on every platform
	col.add_child(title)
	_notice_text = _label("", 14, "vellum")
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_text.custom_minimum_size = Vector2(468, 0)
	col.add_child(_notice_text)
	_notice_more = _label("", 13, "parchment")
	_notice_more.visible = false
	col.add_child(_notice_more)
	col.add_child(_label("It's in the error log, with a copy of your newest save.", 13, "parchment"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	row.add_child(_button("Back to the title", func() -> void:
		get_tree().paused = false
		dismiss()
		get_tree().change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))))
	row.add_child(_button("Open the log", func() -> void:
		OS.shell_open(ProjectSettings.globalize_path(report_path().get_base_dir()))))
	row.add_child(_button("Dismiss", dismiss))


func _label(text: String, size: int, colour: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", _colour(colour, Color(0.9, 0.85, 0.75)))
	l.add_theme_color_override("font_outline_color", _colour("void", Color.BLACK))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for state: String in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = _colour("ui_oxblood" if state == "normal" else "ui_wine", Color(0.3, 0.06, 0.08))
		bs.border_color = _colour("gilt_dark" if state == "normal" else "gilt", Color(0.6, 0.5, 0.3))
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(3)
		bs.content_margin_left = 12
		bs.content_margin_right = 12
		bs.content_margin_top = 4
		bs.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, bs)
	b.add_theme_color_override("font_color", _colour("vellum", Color(0.9, 0.85, 0.75)))
	b.add_theme_color_override("font_hover_color", _colour("gilt_light", Color(1, 0.9, 0.6)))
	b.pressed.connect(on_press)
	return b


## A palette colour (art/palette/palette.json, then the menus' ui_palette.json), read here rather than through Look.
func _colour(name: String, fallback: Color) -> Color:
	if _palette.is_empty():
		for path: String in ["res://art/palette/palette.json", "res://art/palette/ui_palette.json"]:
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
			if data is Dictionary:
				_palette.merge(data as Dictionary)
	return Color(str(_palette[name])) if _palette.has(name) else fallback
