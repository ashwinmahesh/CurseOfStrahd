extends Node
## The place title's shots (Visual Polish Plan 6, PlaceTitle): the game goes to Bildrath's Mercantile (a new region:
## its loading card names it, no title), then to the Blood of the Vine and the village church in the same region,
## shooting each arrival as its name is up.
## Not part of the game. Needs motion on in a still capture:
##   make capture SCENE=res://tools/capture/place_title_capture.tscn NAME=title/after FRAMES=10 ARGS="--motion"

const VISITS: Array[String] = ["bildraths_mercantile", "blood_of_the_vine", "village_church"]
## Frames after arriving the shot is taken (the black has lifted and the name has risen into place).
const UP := 95

var game: Node = null


func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 240)   # the opening's loading card comes and goes
	for id in VISITS:
		game.call("enter_location", id, "default")
		await tool.call("wait_frames", UP)
		tool.call("_shot", "%s_%s.png" % [out, id])
		await tool.call("wait_frames", 240)   # a card or the title goes before the next
