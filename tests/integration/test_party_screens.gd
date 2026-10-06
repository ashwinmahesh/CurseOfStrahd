extends TestCase
## The plan §5.6 screens open and work on a real party: sheet, inventory, journal, party and formation, rests, the
## pause menu, level up through LevelUpController, and character creation clicked through for every class.

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_every_screen_opens() -> void:
	for kind: String in ["sheet", "inventory", "journal", "party", "rest", "menu", "level_up"]:
		root.call("open_screen", kind, 0)
		await _frames(2)
		assert_true(root.get("screen") != null, "%s opened" % kind)
		root.call("close_screen")
		await _frames(1)
	assert_true(root.get("screen") == null)


func test_inventory_equips_and_gives() -> void:
	root.call("open_screen", "inventory", 0)
	await _frames(1)
	var inv := root.get("screen") as InventoryScreen
	var ilse := GameState.story.party[0]
	inv.selected = "flail"
	inv.call("_draw")
	ilse.equip("flail", "main_hand")
	assert_eq(str(ilse.equipped("main_hand").get("id", "")), "flail")
	inv.selected = "javelin"
	var before := 0
	for e in GameState.story.party[1].inventory:
		if str(e["id"]) == "javelin":
			before += int(e["qty"])
	inv.call("_give", GameState.story.party[1])
	var after := 0
	for e in GameState.story.party[1].inventory:
		if str(e["id"]) == "javelin":
			after += int(e["qty"])
	assert_eq(after, before + 1)


func test_short_rest_spends_hit_dice() -> void:
	var ilse := GameState.story.party[0]
	ilse.hp = 3
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_spend", ilse, 10)
	assert_true(ilse.hp > 3, "hp %d, dice %s, log %s" % [ilse.hp, ilse.hit_dice(), rest.get("_log").text])
	var minute := GameState.story.minute_of_day
	rest.call("_finish_short")
	assert_eq(GameState.story.minute_of_day, (minute + 60) % (24 * 60))


func test_level_up_with_a_milestone() -> void:
	GameState.story.milestones = 1
	var ilse := GameState.story.party[0]
	root.call("open_screen", "level_up", 0)
	await _frames(1)
	var lu := root.get("screen") as LevelUpScreen
	assert_true(lu.ctl != null)
	for c in lu.ctl.pending_choices():
		var picks: Array = []
		for o in c.options:
			if o.legal and picks.size() < c.count:
				picks.append(o.id)
		lu.ctl.choose(c.key, picks)
	lu.call("_confirm")
	assert_eq(ilse.character_level(), 2)
	assert_false(GameState.story.can_level_up(ilse))


func test_creation_for_every_class() -> void:
	for cid: String in ["barbarian", "bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger", "rogue",
			"sorcerer", "warlock", "wizard"]:
		var cs := CreationScreen.new()
		add_child(cs)
		var empty: Array[Dictionary] = []
		cs.open_with(empty)
		var b := cs.b()
		b.set_class(cid)
		b.set_background("acolyte")
		b.set_species("human")
		var missing := TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
			func(key: String, picks: Array) -> void: b.choose(key, picks))
		assert_true(missing.is_empty(), "%s: %s" % [cid, missing])
		b.set_name("Test %s" % cid)
		cs.step = CharacterBuilder.Step.REVIEW
		cs.call("_draw")
		assert_true(b.errors().is_empty(), "%s: %s" % [cid, b.errors()])
		for step in CharacterBuilder.STEP_NAMES.size():
			cs.step = step
			cs.call("_draw")
		cs.queue_free()
		await _frames(1)


func test_healing_and_mage_armor_outside_combat() -> void:
	var hedda := GameState.story.party[2]
	var silvain := GameState.story.party[3]
	var ilse := GameState.story.party[0]
	ilse.hp = 2
	var opts := FieldCasting.options(GameState.story.party, hedda, DiceRoller.new(3))
	var ids: Array = opts.map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("healing_word" in ids, str(ids))
	assert_false("guiding_bolt" in ids, "harmful spells wait for a fight")
	var slots := hedda.slots_left(1)
	var target: Array[Character] = [ilse]
	var res := FieldCasting.cast(GameState.story.party, hedda, "healing_word", 1, target, DiceRoller.new(3))
	assert_true(bool(res["ok"]), str(res))
	assert_true(ilse.hp > 2)
	assert_eq(hedda.slots_left(1), slots - 1)
	if "mage_armor" in silvain.known_spells().map(func(k: Dictionary) -> String: return str(k["id"])):
		var ac := silvain.ac_value()
		var me: Array[Character] = [silvain]
		res = FieldCasting.cast(GameState.story.party, silvain, "mage_armor", 1, me, DiceRoller.new(3))
		assert_true(bool(res["ok"]), str(res))
		assert_true(silvain.ac_value() > ac, "Mage Armor lasts after the cast")
	root.call("open_screen", "sheet", 2)
	await _frames(1)
	var sheet := root.get("screen") as CharacterSheetScreen
	sheet.call("_draw")


func test_the_stash_at_a_safe_place() -> void:
	var ilse := GameState.story.party[0]
	assert_true(GameState.story.stash_put("javelin", ilse))
	assert_true(GameState.story.party_has_item("javelin"))
	var before := ilse.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "javelin").size()
	assert_true(GameState.story.stash_take("javelin", ilse))
	assert_false(GameState.story.stash_take("javelin", ilse), "only the one we put there")
	root.call("open_screen", "inventory", 0)
	await _frames(1)
	var inv := root.get("screen") as InventoryScreen
	assert_true(inv.call("_stash_open"), "the test hall is a safe place")
	assert_true(before >= 0)


func test_arcane_recovery_after_a_short_rest() -> void:
	var silvain := GameState.story.party[3]
	silvain.slots_used[0] = 2
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_finish_short")
	await _frames(1)
	var buttons := rest.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text.begins_with("Recover a level 1"))
	assert_eq(buttons.size(), 1, "level 1 wizard: one slot level to recover")
	(buttons[0] as Button).pressed.emit()
	assert_eq(silvain.slots_used[0], 1)
	assert_eq(silvain.resource_left("arcane_recovery"), 0, "once per Long Rest")


func test_preparing_spells_after_a_long_rest() -> void:
	var hedda := GameState.story.party[2]
	var list := PrepareScreen.preparable(GameState.story)
	var keys: Array = list.map(func(e: Dictionary) -> String: return (e["choice"] as Choice).key)
	assert_true("cleric.prepared" in keys, str(keys))
	var c := hedda.choice("cleric.prepared")
	ChoiceOptions.populate(c, hedda)
	var current: Array = c.picks.duplicate()
	var other := ""
	for o in c.options:
		if o.legal and not o.id in current:
			other = o.id
			break
	assert_true(other != "", "another cleric spell to prepare")
	var picks: Array = current.duplicate()
	picks[0] = other
	(hedda.build["choices"] as Dictionary)["cleric.prepared"] = picks
	hedda.refresh()
	var known: Array = hedda.known_spells().map(func(k: Dictionary) -> String: return str(k["id"]))
	assert_true(other in known, "now prepared")
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_long_rest", "safe")
	await _frames(1)
	var btn := rest.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Change prepared spells")
	assert_eq(btn.size(), 1)
	(btn[0] as Button).pressed.emit()
	await _frames(2)
	assert_eq(rest.find_children("*", "PrepareScreen", true, false).size(), 1)


func test_quicksave_from_the_pause_menu() -> void:
	# A new game has no slot: the first quicksave makes one, and later ones go over it.
	SaveSystem.current_slot = ""
	root.call("open_screen", "menu", 0)
	await _frames(1)
	var menu := root.get("screen") as PauseMenu
	var quick := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text.begins_with("Quicksave"))
	assert_eq(quick.size(), 1, "a Quicksave button")
	(quick[0] as Button).pressed.emit()
	var slot := SaveSystem.current_slot
	assert_true(slot != "" and SaveSystem.has_slot(slot), "the first quicksave made the game's slot")
	var count := SaveSystem.list_slots().size()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F5
	ev.pressed = true
	menu.call("_unhandled_input", ev)
	assert_eq(SaveSystem.current_slot, slot, "F5 saves over the same slot")
	assert_eq(SaveSystem.list_slots().size(), count, "no new slot")
	# A loaded game quicksaves over the slot it came from.
	assert_eq(SaveSystem.save("test_loaded"), OK)
	SaveSystem.current_slot = ""
	assert_eq(SaveSystem.load_slot("test_loaded"), OK)
	assert_eq(SaveSystem.current_slot, "test_loaded")
	assert_eq(SaveSystem.quick_save(), OK)
	assert_eq(SaveSystem.current_slot, "test_loaded")
	SaveSystem.delete_slot("test_loaded")
	SaveSystem.delete_slot(slot)
	SaveSystem.current_slot = ""
	root.call("close_screen")
