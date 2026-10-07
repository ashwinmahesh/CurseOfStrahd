extends Node
## The play build's screens for captures (Q2, P11): the title with What's new open (the list make play writes, from
## builds/play_build.json when this checkout has one, run tools/play/whats_new.py . first), then the error notice.
## make capture SCENE=res://tools/capture/play_capture.tscn NAME=play

const SEEN := "user://capture_whats_new.cfg"
const REPORTS := "user://capture_errors/"

var menu: Control


func _ready() -> void:
	WhatsNew.seen_path = SEEN   # never the player's own
	var cfg := ConfigFile.new()
	# As if the player last played six hours before the newest change.
	cfg.set_value("whats_new", "seen_at", int(WhatsNew.build().get("committed_at", 0)) - 6 * 3600)
	cfg.save(SEEN)
	menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_1_title.png")
	var panel := WhatsNew.open(menu)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_2_whats_new.png")
	panel.free()
	# A real script error, caught by the log hook like one in play (the watch is switched on by hand: the autoload
	# stays off in captures).
	var watch: Node = (load("res://core/error_watch.gd") as GDScript).new()
	watch.set("reports_dir", REPORTS)
	add_child(watch)
	await tool.call("wait_frames", 2)
	watch.set("active", 1)
	_broken_door(null)
	_broken_door(null)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_3_error_notice.png")
	var path := str(watch.call("report_path"))
	print(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(SEEN)
	for f in DirAccess.get_files_at(path.get_base_dir()):
		DirAccess.remove_absolute(path.get_base_dir().path_join(f))
	DirAccess.remove_absolute(path.get_base_dir())
	DirAccess.remove_absolute(REPORTS)


## Fails the way a script does in play: a method called on nothing.
func _broken_door(door: Node3D) -> void:
	door.look_at(Vector3.ZERO)
