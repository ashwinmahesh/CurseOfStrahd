extends Node
## The character sheet for captures: the four pregens at level 5 with some wear on them (a Bloodied cleric, a spent
## Second Wind and spell slot, Shield of Faith, Poisoned), one shot per tab across the party, and a shot of sample
## tooltips laid over the sheet, then a level 7 warlock, monk and druid.
## make capture SCENE=res://tools/capture/sheet_capture.tscn NAME=sheet FRAMES=10

const PARTY: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]
## [character index, tab]
const SHOTS := [[2, "Actions"], [0, "Actions"], [2, "Spells"], [3, "Spells"], [1, "Features"], [0, "Equipment"],
	[0, "Effects"], [3, "Notes"]]

var root: Node


func _ready() -> void:
	Compendium.shared().tables["locations"]["sheet_hall"] = {"id": "sheet_hall", "name": "Sheet Hall", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "sheet_hall"
	GameState.story.gold = 42.0
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var party := GameState.story.party
	var ilse := party[0]
	var hedda := party[2]
	var silvain := party[3]
	hedda.hp = int(hedda.max_hp() / 2.0) - 3
	ilse.spend_resource("second_wind")
	ilse.add_temp_hp(5, "Capture")
	var me: Array[Character] = [ilse]
	FieldCasting.cast(party, hedda, "shield_of_faith", 1, me, DiceRoller.new(3))
	silvain.expend_slot(1)
	silvain.add_condition(&"poisoned", "Ghoul claws")
	silvain.build["notes"] = "Ireena trusts Ismark, not us. The burgomaster's letter was signed in a hand Silvain didn't know."
	var n := 1
	for s: Variant in SHOTS:
		var shot := s as Array
		root.call("open_screen", "sheet", int(shot[0]))
		var sheet := root.get("screen") as CharacterSheetScreen
		sheet.show_tab(str(shot[1]))
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%d_%s_%s.png" % [out, n, party[int(shot[0])].name.get_slice(" ", 0).to_lower(), str(shot[1]).to_lower()])
		n += 1
	# Tooltips as the engine shows them (the theme's tooltip panel around each custom tooltip).
	root.call("open_screen", "sheet", 2)
	var tips := CanvasLayer.new()
	tips.layer = 100
	add_child(tips)
	var spell := Compendium.shared().spell_data("spirit_guardians")
	var samples: Array[Control] = [SheetParts.breakdown_tip(hedda.armor_class(), "Armor Class"),
		SheetParts.breakdown_tip(hedda.skill_bonus(&"religion"), "Religion", hedda.skill_bonus(&"religion").signed(), "Proficient."),
		SheetParts.rules_tip(str(spell["name"]), "Level 3 Conjuration", str(spell.get("text", spell["summary"])),
			[["Casting time", "Action"], ["Range", "Self"], ["Duration", "Concentration, up to 10 minutes"]])]
	var x := 60.0
	for t in samples:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", ThemeDB.get_default_theme().get_stylebox("panel", "TooltipPanel"))
		p.add_child(t)
		p.position = Vector2(x, 330)
		tips.add_child(p)
		x += 470.0 if t != samples[0] else 330.0
	await tool.call("wait_frames", 8)
	tool.call("_shot", "%s_%d_tooltips.png" % [out, n])
	tips.queue_free()
	# Level 7 in other classes: Pact Magic, Ki-style resources, a druid's long feature list.
	for extra: Array in [["warlock", "Actions"], ["warlock", "Spells"], ["monk", "Actions"], ["druid", "Features"]]:
		n += 1
		party[1] = TestChars.custom(str(extra[0]), "human", 7)
		root.call("open_screen", "sheet", 1)
		(root.get("screen") as CharacterSheetScreen).show_tab(str(extra[1]))
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%d_%s_%s.png" % [out, n, extra[0], str(extra[1]).to_lower()])
	root.call("close_screen")
