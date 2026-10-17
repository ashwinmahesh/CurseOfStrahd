extends "res://tests/ios/gallery.gd"
## Offscreen mobile-profile audit, not native simulator or gameplay E2E evidence.

var capture_tool: Node


func _ready() -> void:
	pass


func wait_frames(count: int) -> void:
	await capture_tool.call("wait_frames", count)


func _shot(path: String) -> void:
	capture_tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	capture_tool = tool
	directory = out + "_"
	for fixture: String in ["mobile_menu", "mobile_ui", "mobile_secondary", "mobile_recovery", "mobile_controller"]:
		var scene := (load("res://tools/capture/%s_capture.tscn" % fixture) as PackedScene).instantiate()
		add_child(scene)
		await wait_frames(4)
		await scene.call("capture_shots", tool, directory + fixture)
		scene.queue_free()
		await wait_frames(4)
	await _additional_pages()
