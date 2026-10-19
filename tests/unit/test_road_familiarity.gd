extends TestCase
## Familiar ground on the roads (Ashwin, 2026-10-18: "if we are travelling a path to visit somewhere we have already been,
## reduce the rate of combat random encounters"; story/road_familiarity.gd). A road walked before, or a journey bound for a
## place already visited, or a leg that ends at one, rolls 10% of its table's chance (Ashwin, 2026-10-19: "still too many
## random combat encounters for paths we've already travelled"); a first visit rolls all of it, and Strahd's attention is
## added after the cut, so his patrols stay on a road the party knows.

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
	assert_eq(RoadFamiliarity.SCALE, 0.1, "a familiar leg rolls a tenth of the chance")


func test_a_leg_ending_at_a_place_been_to_is_familiar_on_the_way_somewhere_new() -> void:
	var road := _road("crossroads_to_tser_pool")
	st.visited["tser_pool"] = true
	assert_false(RoadFamiliarity.familiar(st, road, "berez"), "bound for somewhere new, the leg alone is not known")
	assert_true(RoadFamiliarity.familiar(st, road, "berez", "tser_pool"), "but it ends at a place the party has been to")
	assert_false(RoadFamiliarity.familiar(st, road, "berez", "berez"), "a leg into the new place is not")
	assert_eq(RoadFamiliarity.scale(st, road, "berez", "tser_pool"), RoadFamiliarity.SCALE)
	assert_false(RoadFamiliarity.been(st, ""), "no place is no place been to")
	assert_false(RoadFamiliarity.been(st, "nowhere"), "a place not on the map was not been to")


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
	assert_between(again, 8, 35, "familiar ground on one in twenty (%d of 400)" % again)
	assert_between(float(again) / float(first), 0.05, 0.15, "about a tenth of the encounters")


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


## Ashwin, 2026-10-19: getting around Barovia on roads already travelled met too much. The real map and tables, a trip
## from the gates to Vallaki (four legs, most of it after dark when it starts in the evening) over ground the party
## has been to, 600 journeys each way: about one journey in six meets something at worst (it was one in two), and the
## stretch over known ground on the way somewhere new adds about as little.
func _trip(legs: Array, ends: Array, final: String, hour: int, seed_value: int) -> int:
	var dice := DiceRoller.new(seed_value)
	st.minute_of_day = hour * 60
	var met := 0
	for i in legs.size():
		var road := _road(str(legs[i]))
		st.advance_minutes(roundi(float(road["hours"]) * 60.0))
		met += 0 if Travel.roll(road, st, dice, final, str(ends[i])).is_empty() else 1
	return met


func test_a_long_known_route_is_quiet() -> void:
	var legs := ["gates_to_village", "village_to_crossroads", "crossroads_to_tser_pool", "tser_pool_to_vallaki"]
	var ends := ["village_of_barovia", "svalich_crossroads", "tser_pool", "vallaki"]
	for p: String in ["gates_of_barovia", "village_of_barovia", "svalich_crossroads", "tser_pool", "vallaki"]:
		st.visited[Travel.place(p)["location"].get_slice(":", 0)] = true
	Weather.use({"kinds": {}, "climates": {}})
	for hour: int in [7, 17, 22]:
		var journeys := 0
		for s in 600:
			st.flags.erase(RoadFamiliarity.FLAG)
			journeys += 1 if _trip(legs, ends, "vallaki", hour, s + 1) > 0 else 0
		assert_true(journeys <= 120, "bound for a place been to, starting at %02d:00: %d of 600 journeys meet something" % [hour, journeys])
		journeys = 0
		for s in 600:
			st.flags.erase(RoadFamiliarity.FLAG)
			journeys += 1 if _trip(legs + ["vallaki_to_berez"], ends + ["berez"], "berez", hour, s + 1) > 0 else 0
		# The last leg is new ground (3 hours, 20% by day and 45% at night); the four before it are known.
		var new_leg_only := 0
		for s in 600:
			st.flags.erase(RoadFamiliarity.FLAG)
			new_leg_only += 1 if _trip(["vallaki_to_berez"], ["berez"], "berez", (hour + 8) % 24, s + 1) > 0 else 0
		assert_true(journeys <= new_leg_only + 130, "bound for somewhere new, starting at %02d:00: the known stretch adds little (%d against %d for the new leg alone)" % [hour, journeys, new_leg_only])
