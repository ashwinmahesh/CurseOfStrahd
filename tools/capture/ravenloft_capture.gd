extends Node
## Ravenloft: The Horrors Within options on the character sheet: a Lupin Hollow Warden, a Dhampir Phantom, a Hexblood
## Undead Patron warlock with a Ravenloft Dark Gift, and a Reborn College of Spirits bard, all level 6.
## make capture SCENE=res://tools/capture/ravenloft_capture.tscn NAME=ravenloft FRAMES=10

const PARTY := [["ranger", "lupin", "hollow_warden", "Vasska", ""], ["rogue", "dhampir", "phantom", "Mirela", ""],
	["warlock", "hexblood", "undead_patron", "Old Nan", "living_shadow"], ["bard", "reborn", "college_of_spirits", "Teodor", "watchers"]]
## [character index, tab]
const SHOTS := [[0, "Features"], [1, "Actions"], [2, "Features"], [3, "Features"]]

var root: Node


func _ready() -> void:
	Compendium.shared().tables["locations"]["sheet_hall"] = {"id": "sheet_hall", "name": "Sheet Hall", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for row: Variant in PARTY:
		var r := row as Array
		var ch := _build(str(r[0]), str(r[1]), str(r[2]), str(r[3]), str(r[4]))
		GameState.story.party.append(ch)
	GameState.story.location = "sheet_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _build(cls: String, species: String, sub: String, who: String, gift: String) -> Character:
	var b := CharacterBuilder.new()
	b.set_class(cls)
	b.set_background("soldier")
	b.set_species(species)
	b.set_name(who)
	b.apply_recommended_scores()
	TestChars.auto_pick(b.pending_choices, b.choose)
	var ch := b.build_character()
	while ch.character_level() < 6:
		var up := LevelUpController.new(ch)
		up.choose_class(cls)
		up.take_fixed_hit_points()
		for c in up.pending_choices():
			if c.kind == "subclass":
				up.choose(c.key, [sub])
		TestChars.auto_pick(up.pending_choices, up.choose)
		up.confirm()
	if gift != "":
		(ch.build["choices"] as Dictionary)["background.feat_choice"] = [gift]
		ch.refresh()
	ch.finish_long_rest()
	return ch


func capture_shots(tool: Node, out: String) -> void:
	var party := GameState.story.party
	var n := 1
	for s: Variant in SHOTS:
		var shot := s as Array
		root.call("open_screen", "sheet", int(shot[0]))
		var sheet := root.get("screen") as CharacterSheetScreen
		sheet.show_tab(str(shot[1]))
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%d_%s_%s.png" % [out, n, party[int(shot[0])].name.get_slice(" ", 0).to_lower(), str(shot[1]).to_lower()])
		n += 1
