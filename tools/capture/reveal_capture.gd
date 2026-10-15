extends Node
## make capture SCENE=res://tools/capture/reveal_capture.tscn NAME=reveal/shot FRAMES=10
## A person turning out to be something else when a conversation ends in a fight (FxShapeshift via
## LocationFights._reveal): Offalia in her apron at the Old Bonegrinder's bakery, then the hag she is. One shot every
## FRAME_STEP frames from the moment the fight starts (<out>_<n>.png).

const FRAME_STEP := 4
const STRIP := 14

var game: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "old_bonegrinder"
	GameState.story.minute_of_day = 14 * 60
	Dice.reseed(7)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 60)
	var v := game.get("view") as LocationView
	v._stepped_aside.append({"name": "Offalia Wormwiggle", "art": "offalia_wormwiggle"})
	v.start_encounter("bakery_offalia")
	var hag: CombatToken = null
	for t: Variant in v.combat_view.tokens.values():
		if (t as CombatToken).combatant.name() == "Offalia Wormwiggle":
			hag = t as CombatToken
	for i in STRIP:
		await tool.call("wait_frames", FRAME_STEP if i > 0 else 1)
		# The fight's opening shot pulls the camera round the field; each shot is taken close on where she stands.
		v.rig.follow = null
		v.rig.global_position = hag.position
		v.rig.distance = 5.0
		await tool.call("wait_frames", 1)
		tool.call("_shot", "%s_%02d.png" % [out, i])
