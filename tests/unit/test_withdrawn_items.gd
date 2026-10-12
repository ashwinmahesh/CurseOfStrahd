extends TestCase
## Items taken out of the game (SaveSystem.WITHDRAWN): a save's copies, carried, stashed or waiting in a chest, become
## useful uncommons in turn when it's loaded, the attunement to them ends, and the owner's old saves load clean.

const AMULET := "amulet_of_proof_against_detection_and_location"


func test_a_saves_amulets_become_useful_items() -> void:
	var save := {"version": GameState.SAVE_VERSION, "story": {
		"party": [{"id": "ilse", "attuned": [AMULET, "ring_of_protection"],
			"inventory": [{"id": AMULET, "qty": 1, "slot": "neck"}, {"id": "dagger", "qty": 1, "slot": ""}]}],
		"stash": [{"id": AMULET, "qty": 1}],
		"location_states": {"bildraths_mercantile": {"treasure": {"strongbox": [{"id": AMULET, "qty": 1, "made": true}]}}}}}
	var up := SaveSystem.upgrade(save)
	var story := up["story"] as Dictionary
	var hero := (story["party"] as Array)[0] as Dictionary
	assert_eq(str(((hero["inventory"] as Array)[0] as Dictionary)["id"]), "periapt_of_wound_closure")
	assert_eq(str(((hero["inventory"] as Array)[0] as Dictionary)["slot"]), "", "off the neck")
	assert_eq(hero["attuned"], ["ring_of_protection"], "its attunement ends")
	assert_eq(str(((story["stash"] as Array)[0] as Dictionary)["id"]), "cloak_of_protection")
	var chest := ((story["location_states"] as Dictionary)["bildraths_mercantile"] as Dictionary)["treasure"] as Dictionary
	assert_eq(str(((chest["strongbox"] as Array)[0] as Dictionary)["id"]), "stone_of_good_luck")
	assert_false(JSON.stringify(up).contains(AMULET))


func test_the_owners_old_save_keeps_no_amulet() -> void:
	var raw := JSON.parse_string(FileAccess.get_file_as_string("res://tests/saves/owner_2026-10-06_death_house.json")) as Dictionary
	assert_true(JSON.stringify(raw).contains(AMULET), "it had them")
	var up := SaveSystem.upgrade(raw)
	assert_false(JSON.stringify(up).contains("\"%s\"" % AMULET), "none left after the upgrade")
	for id: String in SaveSystem.WITHDRAWN:
		assert_false(Compendium.playable(Compendium.shared().item_data(id)), "%s is hidden, its data kept" % id)
		for sub: Variant in SaveSystem.WITHDRAWN[id]:
			var data := Compendium.shared().item_data(str(sub))
			assert_true(Compendium.playable(data) and MagicItems.rarity(data) == "uncommon", "%s is a playable uncommon" % sub)


## Every replacement does something in the game: the gem's elemental fights under the user's orders, the headband
## sets Intelligence, the eyes help Investigation (the search for hidden compartments rolls it), the periapt stabilizes
## its dying wearer, the cloak and the stone add to AC, checks and saves.
func test_each_replacement_works_in_play() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 3)
	var ch := c.creature as Character
	TestCombat.foe(e, "wolf", Vector2i(9, 2))
	ch.add_item("elemental_gem_blue_sapphire")
	TestCombat.start_with(e, c)
	assert_true(e.items.use(c, "elemental_gem_blue_sapphire", "break", [], Vector2(4.5, 2.5)).ok)
	var air := e.order[e.order.find(c) + 1]
	assert_eq(str((air.creature as Monster).data.get("id", "")), "air_elemental")
	assert_eq(air.side, &"guest")
	assert_eq(air.controller, c.controller, "it takes the user's orders")
	assert_false(ch.carries("elemental_gem_blue_sapphire"), "the gem is broken")
	var int0 := ch.ability_score(&"int")
	ch.add_item("headband_of_intellect")
	ch.equip("headband_of_intellect", "head")
	assert_true(ch.attune("headband_of_intellect"))
	assert_eq(ch.ability_score(&"int"), maxi(int0, 19))
	ch.add_item("eyes_of_minute_seeing")
	ch.equip("eyes_of_minute_seeing", "eyes")
	assert_true("Eyes of Minute Seeing" in ch.d20_sources(ch.check_keys(&"investigation"))["advantage"])
	var ac := ch.ac_value()
	var save := ch.roll_save(DiceRoller.new(1), &"dex", 10).total
	var check := ch.roll_check(DiceRoller.new(1), &"athletics", 10).total
	ch.add_item("cloak_of_protection")
	ch.equip("cloak_of_protection", "cloak")
	assert_true(ch.attune("cloak_of_protection"))
	assert_eq(ch.ac_value(), ac + 1, "Cloak of Protection: +1 AC")
	assert_eq(ch.roll_save(DiceRoller.new(1), &"dex", 10).total, save + 1, "and +1 to saves")
	ch.add_item("stone_of_good_luck")
	assert_true(ch.attune("stone_of_good_luck"))
	assert_eq(ch.roll_save(DiceRoller.new(1), &"dex", 10).total, save + 2, "Stone of Good Luck: +1 to saves")
	assert_eq(ch.roll_check(DiceRoller.new(1), &"athletics", 10).total, check + 1, "and to checks")
	var e2 := TestCombat.open_field()
	var d := TestCombat.hero(e2, "ilse_varga", Vector2i(2, 2), 3)
	var dch := d.creature as Character
	dch.add_item("periapt_of_wound_closure")
	dch.equip("periapt_of_wound_closure", "neck")
	assert_true(dch.attune("periapt_of_wound_closure"))
	TestCombat.foe(e2, "wolf", Vector2i(9, 2))
	TestCombat.start_with(e2, d)
	dch.hp = 0
	e2.items.turn_start(d)
	assert_true(dch.stable, "Periapt of Wound Closure: stable at the start of a dying turn")
	assert_true(dch.has_flag("double_hit_dice"), "and Hit Point Dice heal double")
