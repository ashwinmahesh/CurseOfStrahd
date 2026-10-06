extends TestCase
## The character sheet (ui/screens/character_sheet_screen.gd) for every class at level 7: every tab draws, every
## feature, resource and spell gets a row, every tooltip builds, the old tab names still open the right tab, the
## down and dead states draw, casting from the Spells tab heals and spends the slot, and a spell's effect shows on
## the Effects tab in words.

const CLASSES: Array[String] = ["barbarian", "bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger", "rogue",
	"sorcerer", "warlock", "wizard"]

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _sheet(index: int) -> CharacterSheetScreen:
	root.call("open_screen", "sheet", index)
	return root.get("screen") as CharacterSheetScreen


func _texts(sheet: CharacterSheetScreen) -> Dictionary:
	var out := {}
	for l in sheet.find_children("*", "Label", true, false):
		out[(l as Label).text] = true
	return out


## Builds every tooltip on the open page; returns how many there were.
func _build_tips(sheet: CharacterSheetScreen, where: String) -> int:
	var n := 0
	for node in sheet.find_children("*", "", true, false):
		var tip: Callable
		if node is UiParts.Tipped:
			tip = (node as UiParts.Tipped).tip
		elif node is UiParts.Drawn:
			tip = (node as UiParts.Drawn).tip
		if not tip.is_valid():
			continue
		var c := tip.call() as Control
		assert_true(c != null, "%s: a tooltip built nothing" % where)
		if c != null:
			c.free()
		n += 1
	return n


func test_every_class_every_tab() -> void:
	for cid in CLASSES:
		var ch := TestChars.custom(cid, "human", 7)
		GameState.story.party[0] = ch
		var sheet := _sheet(0)
		await _frames(1)
		for t in CharacterSheetScreen.TABS:
			sheet.show_tab(t)
			assert_eq(sheet.tab, t)
			var tips := _build_tips(sheet, "%s %s" % [cid, t])
			assert_true(tips >= 30, "%s %s: tooltips on the abilities, skills and core numbers (%d)" % [cid, t, tips])
		sheet.show_tab("Features")
		var shown := _texts(sheet)
		for f in ch.features:
			if str(f["name"]).ends_with(" Subclass") and ch.subclasses.has(str(f["class_id"])):
				continue
			assert_true(shown.has(str(f["name"])), "%s: feature %s on the sheet" % [cid, f["name"]])
		sheet.show_tab("Actions")
		shown = _texts(sheet)
		for res_id: String in ch.resources:
			assert_true(shown.has(str((ch.resources[res_id] as Dictionary)["name"])), "%s: resource %s on the sheet" % [cid, res_id])
		for a in ch.attacks():
			assert_true(shown.has(a.name), "%s: attack %s on the sheet" % [cid, a.name])
		sheet.show_tab("Spells")
		shown = _texts(sheet)
		for k in ch.known_spells():
			var spell_name := Compendium.shared().display_name("spells", str(k["id"]))
			assert_true(shown.has(spell_name), "%s: spell %s on the sheet" % [cid, spell_name])
		root.call("close_screen")
		await _frames(1)


func test_old_tab_names() -> void:
	var sheet := _sheet(2)
	for pair: Array in [["Overview", "Actions"], ["Abilities & Skills", "Actions"], ["Features & Traits", "Features"],
			["Inventory", "Equipment"], ["Active Effects", "Effects"], ["Spells", "Spells"], ["Nonsense", "Actions"]]:
		sheet.show_tab(str(pair[0]))
		assert_eq(sheet.tab, str(pair[1]), str(pair[0]))


func test_down_and_dead() -> void:
	var ilse := GameState.story.party[0]
	ilse.hp = 0
	ilse.death_failures = 1
	var sheet := _sheet(0)
	assert_true(_texts(sheet).has("Death saves"))
	assert_true(_texts(sheet).has("Unconscious"))
	ilse.dead = true
	sheet.call("_draw")
	assert_true(_texts(sheet).has("Dead"))
	_build_tips(sheet, "dead")


func test_casting_from_the_spells_tab() -> void:
	var ilse := GameState.story.party[0]
	var hedda := GameState.story.party[2]
	ilse.hp = 2
	var slots := hedda.slots_left(1)
	var sheet := _sheet(2)
	sheet.show_tab("Spells")
	var cast: MenuButton = null
	for mb in sheet.find_children("*", "MenuButton", true, false):
		for l in (mb.get_parent() as Node).find_children("*", "Label", true, false):
			if (l as Label).text == "Healing Word":
				cast = mb as MenuButton
	assert_true(cast != null, "a Cast on menu for Healing Word")
	if cast == null:
		return
	cast.get_popup().id_pressed.emit(0)
	assert_true(ilse.hp > 2, "Ilse healed")
	assert_eq(hedda.slots_left(1), slots - 1, "a level 1 slot spent")
	assert_true(_texts(sheet).has(str(sheet.get("_cast_note"))), "what the cast did is shown")


func test_effects_in_words() -> void:
	var ilse := GameState.story.party[0]
	var hedda := GameState.story.party[2]
	var me: Array[Character] = [ilse]
	assert_true(bool(FieldCasting.cast(GameState.story.party, hedda, "shield_of_faith", 1, me, DiceRoller.new(3))["ok"]))
	ilse.add_condition(&"poisoned", "Ghoul claws")
	var sheet := _sheet(0)
	sheet.show_tab("Effects")
	var shown := _texts(sheet)
	assert_true(shown.has("Shield of Faith"), str(shown.keys()))
	assert_true(shown.has("+2 AC"), str(shown.keys()))
	assert_true(shown.has("Poisoned"), str(shown.keys()))
	_build_tips(sheet, "effects")
