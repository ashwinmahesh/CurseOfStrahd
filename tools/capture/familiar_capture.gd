extends Node
## Find Familiar cast while exploring (owner's playtest, 2026-10-08): the owl appears at the back of the party's line in
## Bildrath's Mercantile, then follows as the party walks.
## make capture SCENE=res://tools/capture/familiar_capture.tscn NAME=familiar FRAMES=40

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["silvain_aster", "ilse_varga", "hedda_ironvow"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "bildraths_mercantile"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	var wizard := GameState.story.party[0]
	# Into the room first, away from the wall by the door that would hide the owl.
	await _walk(tool, view, Vector2i(6, 6))
	FieldCasting.cast_utility(GameState.story, wizard, "find_familiar", true)
	view.apply_spell_effect("find_familiar")
	await tool.call("wait_frames", 90)   # past the "An hour later" card
	tool.call("_shot", out + "_1_cast.png")
	await _walk(tool, view, Vector2i(4, 3))
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_2_follows.png")


func _walk(tool: Node, view: LocationView, to: Vector2i) -> void:
	view.walk_to(to)
	for i in 600:
		if view._queue.is_empty():
			break
		await tool.call("wait_frames", 1)
