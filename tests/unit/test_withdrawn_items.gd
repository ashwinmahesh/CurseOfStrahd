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
