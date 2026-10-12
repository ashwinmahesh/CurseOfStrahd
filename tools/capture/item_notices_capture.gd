extends Node
## Item notices (ui/exploration/item_notices.gd) in the game, at the Wizard of Wines (owner's report, 2026-10-12): the
## well's Athletics check passed and the Rope of Climbing handed over, with its "Magic item found" notice on the side;
## then a mundane find and a second magic one stacked under it.
## make capture SCENE=res://tools/capture/item_notices_capture.tscn NAME=item_notices FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "wizard_of_wines"
	GameState.story.minute_of_day = 11 * 60
	for c in Cutscenes.all():   # no arrival picture in the way
		Cutscenes.mark_played(str(c["id"]), GameState.story)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	await tool.call("wait_frames", 20)
	hud.close_narration()
	var spec := {}
	for p: Variant in view.loc["props"]:
		if str((p as Dictionary)["id"]) == "yard_well":
			spec = p as Dictionary
	UiMotion.reduced = false
	LocationChecks._resolve(view, spec, WorldChecks.find(spec, "winery_well_climb"), view.leader().creature as Character, true)
	await _shoot(tool, out + "_1_well.png", 40)
	var notices := root.get("notices") as ItemNotices
	hud.close_narration()
	notices.show_item("antitoxin", 2, "Liriel Dawnsong")
	notices.show_item("potion_of_resistance_necrotic", 1, "")
	await _shoot(tool, out + "_2_stacked.png", 30)
