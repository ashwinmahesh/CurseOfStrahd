extends TestCase
## When and where the party may take a Long Rest (story/rest_rules.gd; owner rules, 2026-10-09): 16 hours after the
## last one, and not in a dungeon or building while enemies remain on any of its floors.

## A keep: a hall and a cellar indoors, joined by stairs, and the yard outside. Rats wait in the cellar; the steward in
## the hall only fights if a conversation goes wrong.
const KEEP := {
	"test_keep_yard": {"id": "test_keep_yard", "name": "Keep Yard", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#####"], "outdoors": true}, "spawns": {"default": [1, 1]},
		"exits": [{"id": "in", "cell": [3, 1], "to": "test_keep_hall", "spawn": "default"}],
		"encounters": [{"id": "crows", "trigger": "enter_area:yard", "monsters": [{"monster": "zombie", "cell": [2, 1]}]}]},
	"test_keep_hall": {"id": "test_keep_hall", "name": "Keep Hall", "region": "test", "summary": "", "rest": "safe",
		"map": {"rows": ["#####", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
		"exits": [{"id": "out", "cell": [1, 1], "to": "test_keep_yard", "spawn": "default"},
			{"id": "down", "cell": [3, 1], "to": "test_keep_cellar", "spawn": "default"}],
		"encounters": [{"id": "steward", "trigger": "dialogue", "monsters": [{"monster": "zombie", "cell": [2, 1]}]}]},
	"test_keep_cellar": {"id": "test_keep_cellar", "name": "Keep Cellar", "region": "test", "summary": "", "rest": "risky",
		"map": {"rows": ["#####", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
		"exits": [{"id": "up", "cell": [3, 1], "to": "test_keep_hall", "spawn": "default"}],
		"encounters": [{"id": "rats", "trigger": "enter_area:cellar", "when": "not flag.test_rats_fled",
			"monsters": [{"monster": "zombie", "cell": [2, 1]}]}]},
}


func before_each() -> void:
	for id: String in KEEP:
		Compendium.shared().tables["locations"][id] = (KEEP[id] as Dictionary).duplicate(true)


func after_each() -> void:
	for id: String in KEEP:
		(Compendium.shared().tables["locations"] as Dictionary).erase(id)


func _at(location: String) -> StoryState:
	var st := StoryState.new()
	st.location = location
	return st


func _won(st: StoryState, location: String, encounter: String, state: Variant = true) -> void:
	(st.loc_state(location)["encounters"] as Dictionary)[encounter] = state


func test_a_building_is_its_walled_maps_joined_by_exits() -> void:
	var hall := RestRules.building_of("test_keep_hall")
	hall.sort()
	assert_eq(hall, ["test_keep_cellar", "test_keep_hall"] as Array[String], "the hall and the cellar under it, not the yard")
	assert_eq(RestRules.building_of("test_keep_yard"), [] as Array[String], "the open air is no building")
	var house := RestRules.building_of("death_house_ground")
	house.sort()
	assert_eq(house, ["death_house_attic", "death_house_dungeon_1", "death_house_dungeon_2", "death_house_ground",
		"death_house_third", "death_house_upper"] as Array[String], "Death House is every floor of it")
	assert_true("castle_ravenloft_spires_roofs" in RestRules.building_of("castle_ravenloft_spires_rooms"), "a castle's roofs are the castle's")
	assert_eq(RestRules.building_of("village_of_barovia"), [] as Array[String], "a town")


func test_enemies_on_another_floor_refuse_a_long_rest_until_they_are_gone() -> void:
	var st := _at("test_keep_hall")
	var why := RestRules.long_rest_refusals(st)
	assert_eq(why.size(), 1, str(why))
	assert_true(why[0].begins_with("Enemies still prowl this place"), why[0])
	assert_eq(RestRules.waiting_fights(st, "test_keep_hall"), [{"location": "test_keep_cellar", "id": "rats"}] as Array[Dictionary],
		"the cellar's rats; the steward only fights if a talk goes wrong")
	_won(st, "test_keep_cellar", "rats")
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String], "the rats are dealt with")
	# A fight that's over some other way (its condition no longer holds) doesn't count either.
	var st2 := _at("test_keep_cellar")
	st2.set_flag("test_rats_fled")
	assert_eq(RestRules.long_rest_refusals(st2), [] as Array[String], "the rats fled")


func test_a_fight_begun_and_not_won_counts_whatever_started_it() -> void:
	var st := _at("test_keep_hall")
	_won(st, "test_keep_cellar", "rats")
	_won(st, "test_keep_hall", "steward", "started")
	assert_false(RestRules.long_rest_refusals(st).is_empty(), "the steward's fight was begun and the party ran")
	_won(st, "test_keep_hall", "steward")
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String])


func test_the_open_air_never_refuses_for_enemies() -> void:
	var st := _at("test_keep_yard")
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String], "crows in the yard, but it's the open road")


func test_a_fresh_death_house_refuses_a_long_rest_on_every_floor() -> void:
	for floor_id: String in ["death_house_ground", "death_house_upper", "death_house_attic"]:
		var st := _at(floor_id)
		assert_false(RestRules.long_rest_refusals(st).is_empty(), "%s: the ghouls below and the armor above" % floor_id)


func test_sixteen_hours_between_long_rests() -> void:
	var st := _at("test_keep_yard")
	assert_eq(RestRules.minutes_until_long_rest(st), 0, "never rested")
	RestRules.note_long_rest(st)
	st.advance_minutes(8 * 60 + 30)
	var why := RestRules.long_rest_refusals(st)
	assert_eq(why, ["The last Long Rest ended less than 16 hours ago: the next can start in 7 hours 30 minutes."] as Array[String])
	assert_eq(RestRules.item_rest_refusal(st), why[0], "an item's safe rest waits too")
	st.advance_minutes(7 * 60 + 30)
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String], "16 hours on")
	assert_eq(RestRules.duration(60), "1 hour")
	assert_eq(RestRules.duration(45), "45 minutes")
	assert_eq(RestRules.duration(121), "2 hours 1 minute")
