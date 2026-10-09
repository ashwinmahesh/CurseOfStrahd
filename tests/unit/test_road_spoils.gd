extends TestCase
## Every random encounter pays (Ashwin, 2026-10-09; story/road_spoils.gd): a fight's reward grows with its foes and
## the party's level, a meeting on the road leaves a smaller one, and the same encounter always gives the same.


func _party(level: int, n: int = 4) -> StoryState:
	var st := StoryState.new()
	var ids: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]
	for i in n:
		st.party.append(Pregens.build(ids[i], level))
	st.playthrough_seed = 7
	return st


func _wolves(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"monster": "wolf", "cell": [i, 0]})
	return out


func test_a_fight_always_leaves_coins_and_a_find() -> void:
	var st := _party(2)
	for seed_key: String in ["a", "b", "c", "d", "e", "f"]:
		var r := RoadSpoils.for_fight(st, _wolves(3), seed_key)
		assert_true(int(r["gold"]) > 0, "coins: %s" % [r])
		assert_true((r["items"] as Array).size() >= 1, "and at least one find: %s" % [r])
		for it: Variant in r["items"]:
			assert_false(Compendium.shared().item_data(str((it as Dictionary)["id"])).is_empty(), "a real item: %s" % [it])


func test_the_same_encounter_gives_the_same_reward() -> void:
	var st := _party(4)
	assert_eq(str(RoadSpoils.for_fight(st, _wolves(4), "svalich_road:wolves:600")), str(RoadSpoils.for_fight(st, _wolves(4), "svalich_road:wolves:600")))
	assert_eq(str(RoadSpoils.for_event(st, "svalich_road:raven:600")), str(RoadSpoils.for_event(st, "svalich_road:raven:600")))


func test_bigger_fights_and_parties_get_more() -> void:
	var small := 0
	var big := 0
	var deep := 0
	var low := _party(3)
	var high := _party(9)
	var spawn := [{"monster": "vampire_spawn", "cell": [0, 0]}, {"monster": "vampire_spawn", "cell": [1, 0]}]
	for i in 40:
		small += int(RoadSpoils.for_fight(low, _wolves(2), "k%d" % i)["gold"])
		big += int(RoadSpoils.for_fight(low, _wolves(8), "k%d" % i)["gold"])
		deep += int(RoadSpoils.for_fight(high, spawn, "k%d" % i)["gold"])
	assert_true(big > small * 2, "eight wolves leave more than two: %d vs %d" % [big, small])
	assert_true(deep > big, "vampire spawn leave more than wolves: %d vs %d" % [deep, big])
	# The find keeps step with the party: a level 12 party's potion is a greater one, never the plain kind.
	var twelve := _party(12)
	for i in 30:
		for it: Variant in RoadSpoils.for_fight(twelve, _wolves(1), "p%d" % i)["items"]:
			assert_ne(str((it as Dictionary)["id"]), "potion_of_healing", "a level 12 party gets stronger healing")


func test_a_meeting_on_the_road_leaves_something_too() -> void:
	var st := _party(5)
	for i in 10:
		var r := RoadSpoils.for_event(st, "e%d" % i)
		assert_true(int(r["gold"]) > 0 and not (r["items"] as Array).is_empty(), str(r))
