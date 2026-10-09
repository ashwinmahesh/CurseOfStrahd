extends Node
## The blur dissolve's shots (Visual Polish Plan 10, PlaceDissolve): the game walks from Bildrath's Mercantile into
## the Blood of the Vine and shoots the tavern coming in, a few frames apart, as the black lifts and the blur clears.
## Not part of the game. Needs motion on in a still capture:
##   make capture SCENE=res://tools/capture/dissolve_capture.tscn NAME=dissolve FRAMES=10 ARGS="--motion"

## Frames after the change of place each shot is taken.
const AT: Array[int] = [12, 24, 36, 48, 72]

var game: Node = null


func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 120)
	game.call("enter_location", "bildraths_mercantile", "default")
	await tool.call("wait_frames", 300)   # the region's loading card comes and goes
	game.call("enter_location", "blood_of_the_vine", "default")
	var done := 0
	for f in AT:
		await tool.call("wait_frames", f - done)
		done = f
		tool.call("_shot", "%s_%03d.png" % [out, f])
