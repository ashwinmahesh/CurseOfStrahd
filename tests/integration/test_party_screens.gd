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
	for cid: String in ["fighter", "rogue", "cleric", "wizard"]:
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
