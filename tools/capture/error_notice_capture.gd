extends Node
## The error notice's screens for captures (P11): the title, then the notice a script error raises.
## make capture SCENE=res://tools/capture/error_notice_capture.tscn NAME=errors

const REPORTS := "user://capture_errors/"

var menu: Control


func _ready() -> void:
	menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_1_title.png")
	# A real script error, caught by the log hook like one in play (the watch is switched on by hand: the autoload
	# stays off in captures).
	var watch: Node = (load("res://addons/dnd_core/core/error_watch.gd") as GDScript).new()
	watch.set("reports_dir", REPORTS)
	add_child(watch)
	await tool.call("wait_frames", 2)
	watch.set("active", 1)
	_broken_door(null)
	_broken_door(null)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_2_error_notice.png")
	var path := str(watch.call("report_path"))
	print(FileAccess.get_file_as_string(path))
	for f in DirAccess.get_files_at(path.get_base_dir()):
		DirAccess.remove_absolute(path.get_base_dir().path_join(f))
	DirAccess.remove_absolute(path.get_base_dir())
	DirAccess.remove_absolute(REPORTS)


## Fails the way a script does in play: a method called on nothing.
func _broken_door(door: Node3D) -> void:
	door.look_at(Vector3.ZERO)
