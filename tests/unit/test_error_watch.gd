extends TestCase
## Errors you can see (P11, core/error_watch.gd): Godot's log hook queues errors and script errors (not warnings), and
## an error during play goes into a report beside the saves, with a copy of the newest save and where the game was,
## and shows a notice with the way back to the title.

const WATCH := preload("res://core/error_watch.gd")
const ERROR := {"script": true, "where": "res://world/exploration/x.gd:12", "function": "_ready",
	"text": "Cannot call method 'foo' on a null value.", "trace": "[0] _ready (res://world/exploration/x.gd:12)",
	"time": "2026-10-07 12:00:00"}

var watch: Node


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var f := FileAccess.open(SaveSystem.save_dir.path_join("error_watch_slot.json"), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	watch = WATCH.new()
	watch.set("reports_dir", SaveSystem.save_dir.path_join("errors"))
	add_child(watch)


func after_each() -> void:
	watch.free()
	var root := SaveSystem.save_dir.path_join("errors")
	var dir := DirAccess.open(root)
	if dir != null:
		for session in dir.get_directories():
			for f in DirAccess.get_files_at(root.path_join(session)):
				DirAccess.remove_absolute(root.path_join(session).path_join(f))
			DirAccess.remove_absolute(root.path_join(session))
		DirAccess.remove_absolute(root)
	if FileAccess.file_exists(SaveSystem.save_dir.path_join("error_watch_slot.json")):
		DirAccess.remove_absolute(SaveSystem.save_dir.path_join("error_watch_slot.json"))


func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	for n in root.find_children("*", "Button", true, false):
		out.append((n as Button).text)
	return out


func test_the_hook_queues_errors_and_script_errors_but_not_warnings() -> void:
	var c: Logger = WATCH.Catcher.new()
	var none: Array[ScriptBacktrace] = []
	c.call("_log_error", "_ready", "res://a.gd", 3, "boom", "", false, Logger.ERROR_TYPE_SCRIPT, none)
	c.call("_log_error", "f", "res://a.gd", 4, "careful", "", false, Logger.ERROR_TYPE_WARNING, none)
	c.call("_log_error", "load", "core/io/resource_loader.cpp", 5, "Failed loading", "", false, Logger.ERROR_TYPE_ERROR, none)
	c.call("_log_error", "f", "res://s.gdshader", 6, "bad", "", false, Logger.ERROR_TYPE_SHADER, none)
	var got: Array = c.call("take")
	assert_eq(got.size(), 2, "the script error and the engine error")
	assert_true(bool(got[0]["script"]), "a script error is marked as one")
	assert_eq(str(got[0]["where"]), "res://a.gd:3", "with its file and line")
	var again: Array = c.call("take")
	assert_true(again.is_empty(), "taking empties the queue")


func test_off_in_headless_runs() -> void:
	assert_true(watch.get("catcher") == null, "tests and make smoke install no log hook")


func test_an_error_writes_a_report_with_the_newest_save_and_shows_a_notice() -> void:
	watch.call("report", ERROR)
	var path := str(watch.call("report_path"))
	var text := FileAccess.get_file_as_string(path)
	assert_true(text.begins_with("Curse of Strahd error report"), "a report beside the saves")
	assert_true(text.contains("SCRIPT ERROR at res://world/exploration/x.gd:12"), "naming the file and line")
	assert_true(text.contains("Cannot call method 'foo' on a null value."), "with Godot's message")
	assert_true(text.contains("scene: ") and text.contains("[0] _ready"), "where the game was, and the script's trace")
	var copied := Array(DirAccess.get_files_at(path.get_base_dir())).filter(func(f: String) -> bool: return f.ends_with(".json"))
	assert_eq(copied.size(), 1, "with a copy of the newest save")
	var notice := watch.get_node_or_null("ErrorNotice")
	assert_true(notice != null, "a notice on screen")
	var texts := _texts(notice)
	assert_true("Something went wrong" in texts, "saying so")
	assert_true(texts.any(func(t: String) -> bool: return t.contains("x.gd")), "and where")
	for b: String in ["Back to the title", "Open the log", "Dismiss"]:
		assert_true(b in texts, "a %s button" % b)


func test_repeats_are_counted_not_written_out_again_and_again() -> void:
	for i in 6:
		watch.call("report", ERROR)
	var text := FileAccess.get_file_as_string(str(watch.call("report_path")))
	assert_eq(text.count("SCRIPT ERROR at res://world/exploration/x.gd:12"), WATCH.REPEATS_WRITTEN, "written a few times")
	assert_true("and 5 more since" in _texts(watch.get_node("ErrorNotice")), "counted on the notice")
	watch.call("dismiss")
	assert_true(watch.get_node_or_null("ErrorNotice") == null or watch.get_node("ErrorNotice").is_queued_for_deletion(),
		"Dismiss takes it away")
