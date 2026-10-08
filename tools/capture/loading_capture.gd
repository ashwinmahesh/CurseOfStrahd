extends Node
## The loading cover as played (the loading lane): a new game's first place, then its first walk into the Village of
## Barovia, whose arrival picture pauses the game. Shots every few frames, each with what is on top of the screen, for
## the grey screen that waited for a click (Ashwin, 2026-10-08). Motion on, and this capture's own settings and saves.
## make capture SCENE=res://tools/capture/loading_capture.tscn NAME=loading/village FRAMES=2 ARGS=--motion

## Frames between shots, and shots per change of place.
const EVERY := 12
const SHOTS := 24

var root: Node


func _ready() -> void:
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")   # never the owner's settings file
	GameState.reset()
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	await _shots(tool, out + "_newgame")
	_close_popups()
	await tool.call("wait_frames", 30)
	root.call("_covered", "village_of_barovia", Callable(root, "enter_location").bind("village_of_barovia", "default"))
	await _shots(tool, out + "_village")


func _shots(tool: Node, prefix: String) -> void:
	var t0 := Time.get_ticks_msec()
	for i in SHOTS:
		tool.call("_shot", "%s_%02d.png" % [prefix, i])
		print("capture state %s_%02d t=%.2fs %s" % [prefix.get_file(), i, (Time.get_ticks_msec() - t0) / 1000.0, _state()])
		await tool.call("wait_frames", EVERY)


## What covers the screen now: the pause, the open screen, a conversation, the black, the loading card.
func _state() -> String:
	var fade := root.get("_place_fade") as ColorRect
	var cards := root.find_children("*", "LoadingCard", false, false)
	var card := ""
	if not cards.is_empty():
		var c := cards[0] as LoadingCard
		card = "card %.2f%s" % [(c.get_child(0) as Control).modulate.a, " lifted" if c._lifted else ""]
	var screen := root.get("screen") as Node
	return "paused=%s moving=%s screen=%s dialogue=%s black=%.2f %s" % [get_tree().paused, root.get("moving"),
		screen.get_class() if screen != null and screen.get_script() == null else (str(screen.name) if screen != null else "-"),
		root.get("dialogue") != null, fade.color.a if fade != null else -1.0, card]


func _close_popups() -> void:
	root.call("close_screen")
	var d := root.get("dialogue") as Node
	if d != null:
		d.queue_free()
		root.set("dialogue", null)
		ModeController.force(ModeController.Mode.EXPLORATION)
