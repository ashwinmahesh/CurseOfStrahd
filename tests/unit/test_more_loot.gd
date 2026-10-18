extends TestCase
## More loot (owner, 2026-10-12: "place more magic items, money and potions"): a place with chests holds more magic
## items and some potions besides, scaled to its level; a won fight at a place leaves its foes' coins and a find.


## The place with the most chests that has random loot, and its level.
func _a_place() -> String:
	var best := ""
	var most := 0
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc["id"]).begins_with("test_") or bool(loc.get("no_random_loot", false)):
			continue
		var n := (loc.get("containers", []) as Array).size()
		if n > most:
			most = n
			best = str(loc["id"])
	return best


func test_chests_hold_more_magic_items_and_potions() -> void:
	var loc := _a_place()
	var magic := 0
	var potions := 0
	var healing := 0
	var runs := 200
	for s in runs:
		var st := StoryState.new()
		st.playthrough_seed = s
		for cid: String in Treasure.placed(st, loc):
			for it: Variant in Treasure.placed(st, loc)[cid]:
				var data := Compendium.shared().item_data(str((it as Dictionary)["id"]))
				assert_false(data.is_empty(), str(it))
				if str(data.get("category", "")) == "potion":
					potions += 1
					if str(data["id"]).begins_with("potion_of_healing"):
						healing += 1
				else:
					magic += 1
	# About 1.4 random magic items a place, more with many chests, and a potion besides. Since each lasting item turns
	# up once (Ashwin, 2026-10-17: Treasure.taken_kinds), a roll that would repeat one the story places is something
	# else, so more of those magic items are potions and scrolls than before.
	assert_true(float(magic + potions) / runs >= 2.2, "about 1.4 magic items and a potion a place: %.2f" % (float(magic + potions) / runs))
	assert_true(float(magic) / runs >= 0.9, "most of them lasting items or scrolls: %.2f" % (float(magic) / runs))
	assert_true(float(potions) / runs >= 0.8, "about one potion a place: %.2f" % (float(potions) / runs))
	assert_true(healing > potions / 3, "most of them healing: %d of %d" % [healing, potions])


func test_a_healing_potion_fits_the_places_tier() -> void:
	var rng := DiceRoller.new(3)
	assert_eq(str(Treasure.roll_potion(rng, 2, 100)["id"]), "potion_of_healing")
	assert_eq(str(Treasure.roll_potion(rng, 8, 100)["id"]), "potion_of_healing_greater")
	for i in 30:
		var p := Treasure.roll_potion(rng, 8, 0)
		assert_eq(str(Compendium.shared().item_data(str(p["id"])).get("category", "")), "potion", str(p))


func test_a_won_fight_at_a_place_leaves_coins_and_a_find() -> void:
	var st := StoryState.new()
	st.playthrough_seed = 9
	st.party.append(TestChars.pregen("ilse_varga", 3))
	var foes := [{"monster": "bandit"}, {"monster": "bandit"}, {"monster": "bandit", "side": "neutral"}]
	var spoils := RoadSpoils.for_story_fight(st, foes, "village:test")
	assert_true(int(spoils["gold"]) >= 6, "two foes' coins (3d6 each): %d" % int(spoils["gold"]))
	assert_eq((spoils["items"] as Array).size(), 1, "and a find")
	assert_eq(JSON.stringify(RoadSpoils.for_story_fight(st, foes, "village:test")), JSON.stringify(spoils), "the same on a reload")
	assert_eq(int(RoadSpoils.for_story_fight(st, [{"monster": "bandit", "side": "neutral"}], "x")["gold"]), 0, "no foes, no spoils")
	# Wolves and zombies carry no treasure (the 2025 Monster Manual): nothing.
	var beasts := RoadSpoils.for_story_fight(st, [{"monster": "wolf"}, {"monster": "wolf"}, {"monster": "zombie"}], "y")
	assert_eq(int(beasts["gold"]), 0)
	assert_true((beasts["items"] as Array).is_empty())
	assert_false(RoadSpoils.carries_treasure(Compendium.shared().get_entry("monsters", "wolf")))
	assert_true(RoadSpoils.carries_treasure(Compendium.shared().get_entry("monsters", "bandit")))
