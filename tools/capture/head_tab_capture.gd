extends Node
## The Appearance step's Head tab (ui/character/appearance_panel.gd) for the looks whose hair art carried stray bits by
## the boots and hands: a man with Tousled hair, a man with Long hair and a woman with each, so every head, hairstyle
## and beard picture can be checked as a close-up of the head. Its settings go to a file of its own and the game's
## saves to the capture's own folder (tools/capture/capture.gd), never the owner's.
## make capture SCENE=res://tools/capture/head_tab_capture.tscn NAME=head_tab FRAMES=10

const LOOKS: Array[Array] = [["male", "tousled"], ["male", "long"], ["female", "tousled"], ["female", "long"]]

var root: Node


func _ready() -> void:
	GameSettings.path = "user://capture_saves/%d/settings.cfg" % OS.get_process_id()
	Compendium.shared().tables["locations"]["sheet_hall"] = {"id": "sheet_hall", "name": "Sheet Hall", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	GameState.story.party.append(Pregens.build("godrick_pendlebrook", 1))
	GameState.story.location = "sheet_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	root.call("open_screen", "create", 0)
	var cs := root.get("screen") as CreationScreen
	var b := cs.b()
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
		func(key: String, chosen: Array) -> void: b.choose(key, chosen))
	b.set_name("Head Tab")
	for look in LOOKS:
		var app := HeroLook.default_appearance(str(look[0]), "fighter")
		app["hair"] = str(look[1])
		b.set_appearance(HeroLook.settle(app))
		cs.step = CharacterBuilder.Step.APPEARANCE
		cs.set("_appearance_tab", "Head")
		cs.call("_draw")
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%s_%s.png" % [out, look[0], look[1]])
