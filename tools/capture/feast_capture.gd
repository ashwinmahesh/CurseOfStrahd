extends Node
## Heroes' Feast cast while exploring (owner's playtest, 2026-10-18: it worked and nothing said so): the table's light
## wells up round each hero in Bildrath's Mercantile, then the party frames carry the feast with its time left.
## make capture SCENE=res://tools/capture/feast_capture.tscn NAME=feast FRAMES=40

var root: Node


func _ready() -> void:
	GameState.reset()
	var cleric := Pregens.build("hedda_ironvow", 11)
	var prepared := (cleric.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "heroes_feast" in prepared:
		prepared.append("heroes_feast")
	cleric.finish_long_rest()
	GameState.story.party.append(cleric)
	for id: String in ["silvain_aster", "ilse_varga"]:
		var ch := Pregens.build(id, 11)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.gold = 1500.0
	GameState.story.location = "bildraths_mercantile"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	await _walk(tool, view, Vector2i(6, 6))
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_0_before.png")
	var res := FieldCasting.cast_utility(GameState.story, GameState.story.party[0], "heroes_feast", false)
	print("feast: ", res["text"])
	view.apply_spell_effect(str(res["effect"]))
	hud.refresh()
	for i in 4:
		await tool.call("wait_frames", 18)
		tool.call("_shot", out + "_%d_cast.png" % (i + 1))
	await tool.call("wait_frames", 150)
	tool.call("_shot", out + "_5_after.png")


func _walk(tool: Node, view: LocationView, to: Vector2i) -> void:
	view.walk_to(to)
	for i in 600:
		if view._queue.is_empty():
			break
		await tool.call("wait_frames", 1)
