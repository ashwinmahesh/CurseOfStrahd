extends TestCase
## Familiar ground on the roads (Ashwin, 2026-10-18: "if we are travelling a path to visit somewhere we have already been,
## reduce the rate of combat random encounters"; story/road_familiarity.gd). A road walked before, or a journey bound for a
## place already visited, rolls 40% of its table's chance; a first visit rolls all of it, and Strahd's attention is added
## after the cut, so his patrols stay on a road the party knows.

const TABLE := "test_familiar_road"

var st: StoryState


func before_each() -> void:
	StrahdPresence.use_attention({})
	Weather.use({"kinds": {}, "climates": {}})   # no fog to raise the odds
	st = StoryState.new()
	st.party.append(Pregens.build("ilse_varga", 5))
	st.minute_of_day = 12 * 60
	Compendium.shared().tables["random_encounters"][TABLE] = {"id": TABLE, "map": "road_ambush", "chance_day": 0.5,
		"chance_night": 0.5, "entries": [{"id": "anything", "weight": 1}]}


func after_each() -> void:
	StrahdPresence.use_attention({})
	Weather.use({})
	Compendium.shared().tables["random_encounters"].erase(TABLE)


func _road(id: String) -> Dictionary:
	for r: Variant in Travel.map_data()["roads"]:
		if str((r as Dictionary)["id"]) == id:
			return r as Dictionary
	return {}


## Rolls the test road `n` times by day, with the dice seeded the same each time; how many met something.
func _met(journey_to: String, n: int = 400) -> int:
	var road := {"id": "test_leg", "name": "A test road", "table": TABLE}
	var dice := DiceRoller.new(11)
	var met := 0
	for i in n:
		met += 0 if Travel.roll(road, st, dice, journey_to).is_empty() else 1
	return met


func test_a_road_walked_or_a_place_been_to_is_familiar() -> void:
	var road := _road("village_to_crossroads")
	assert_false(road.is_empty(), "the road is on the map")
	assert_false(RoadFamiliarity.familiar(st, road), "a first walk, going nowhere in particular")
	assert_false(RoadFamiliarity.familiar(st, road, "svalich_crossroads"), "bound for a place not yet been to")
	st.visited["svalich_crossroads"] = true
	assert_true(RoadFamiliarity.familiar(st, road, "svalich_crossroads"), "bound for a place already been to")
	assert_false(RoadFamiliarity.familiar(st, road), "the road itself is still new when no destination is given")
	st.visited.erase("svalich_crossroads")
	RoadFamiliarity.note(st, road)
	assert_true(RoadFamiliarity.familiar(st, road), "walked")
	assert_true(RoadFamiliarity.familiar(st, road, "vallaki"), "and walked again on the way to somewhere new")
	assert_false(RoadFamiliarity.familiar(st, _road("crossroads_to_tser_pool"), "vallaki"), "another road is not")
	assert_eq(RoadFamiliarity.scale(st, road), RoadFamiliarity.SCALE)
	assert_eq(RoadFamiliarity.scale(st, _road("crossroads_to_tser_pool")), 1.0)


func test_the_walked_roads_are_saved_and_come_back() -> void:
	RoadFamiliarity.note(st, _road("village_to_crossroads"))
	RoadFamiliarity.note(st, _road("village_to_crossroads"))
	RoadFamiliarity.note(st, {"name": "no id"})
	assert_eq((st.flags[RoadFamiliarity.FLAG] as Dictionary).size(), 1, "noted once, and a road with no id is skipped")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_true(RoadFamiliarity.walked(back, "village_to_crossroads"), "after a save and a load")
	assert_false(RoadFamiliarity.walked(back, "crossroads_to_tser_pool"))
	assert_false(RoadFamiliarity.walked(StoryState.new(), "village_to_crossroads"), "a save from before: nothing walked")


func test_familiar_ground_meets_fewer_encounters() -> void:
	st.visited["vallaki"] = true
	var first := _met("")
	var again := _met("vallaki")
	assert_between(first, 170, 230, "a first visit meets something on half its legs (%d of 400)" % first)
	assert_between(again, 60, 100, "familiar ground on two in ten (%d of 400)" % again)
	assert_between(float(again) / float(first), 0.3, 0.5, "about 40% of the encounters")


func test_the_same_dice_give_the_first_visit_every_encounter_the_familiar_one_does() -> void:
	st.visited["vallaki"] = true
	var road := {"id": "test_leg", "name": "A test road", "table": TABLE}
	var dice_first := DiceRoller.new(5)
	var dice_again := DiceRoller.new(5)
	for i in 200:
		var first := not Travel.roll(road, st, dice_first, "").is_empty()
		var again := not Travel.roll(road, st, dice_again, "vallaki").is_empty()
		if again:
			assert_true(first, "roll %d: a familiar encounter is never one a first visit would have missed" % i)


func test_his_patrols_are_not_quieted_by_a_road_the_party_knows() -> void:
	Compendium.shared().tables["random_encounters"][TABLE]["chance_day"] = 0.0
	StrahdPresence.use_attention({"marks": [{"id": "m", "when": "flag.test_mark", "points": 1, "summary": ""}],
		"tiers": [{"id": "unnoticed", "min": 0, "gap": 1.0}, {"id": "hunted", "min": 1, "gap": 1.0, "road_day": 0.5, "road_night": 0.5}]})
	st.set_flag("test_mark")
	st.visited["vallaki"] = true
	var first := _met("")
	var again := _met("vallaki")
	assert_eq(first, again, "his +50% on the roads is added after the cut: the same on a road the party knows")
	assert_between(first, 170, 230, "(%d of 400)" % first)


func test_a_quiet_road_stays_quiet_and_an_unknown_place_is_not_familiar() -> void:
	Compendium.shared().tables["random_encounters"][TABLE]["chance_day"] = 0.0
	assert_eq(_met("vallaki"), 0, "a table with no chance stays quiet")
	assert_eq(RoadFamiliarity.scale(st, {"id": "x"}, "nowhere"), 1.0, "a place that isn't on the map is not familiar")
