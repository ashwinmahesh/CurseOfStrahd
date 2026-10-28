extends TestCase
## A Long Rest inside Castle Ravenloft (held ask, 2026-10-24: allowed once the current floor is cleared of enemies, with a chance
## of vampires interrupting it): the castle's walled maps are grouped into floors (a location's `floor`), only the enemies on
## the party's own floor refuse a rest (RestRules.rest_maps), a night in the castle is broken one time in three (data/camp/
## night_visitors.json `interrupt_on`) by the castle's bats, dead and vampire spawn (`region_settings`), and every place there
## that allows sleep has a night line of its own.

## A d6 for the night's interruption that shows `value`.
class NightDie extends DiceRoller:
	var value := 1

	func roll_one(sides: int, reason: String = "") -> int:
		if sides == 6 and reason == "Long Rest interruption":
			return value
		return super.roll_one(sides, reason)


func _castle(location: String) -> StoryState:
	var st := StoryState.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := TestChars.pregen(id, 8)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = location
	st.minute_of_day = 22 * 60
	return st


## Marks every fight waiting on `location`'s floor as won.
func _clear_floor(st: StoryState, location: String) -> void:
	for f in RestRules.waiting_fights(st, location):
		(st.loc_state(str(f["location"]))["encounters"] as Dictionary)[str(f["id"])] = true


func test_every_walled_map_of_the_castle_is_on_a_floor() -> void:
	var floors := {}
	for loc in Compendium.shared().all("locations"):
		var id := str(loc["id"])
		if str(loc.get("region", "")) != "castle_ravenloft":
			continue
		var floor_id := RestRules.floor_of(id)
		if RestRules.building_of(id).is_empty():
			assert_eq(floor_id, "", "%s is in the open: no floor" % id)
			continue
		assert_true(floor_id != "", "%s is on a floor" % id)
		floors[floor_id] = true
	var names := floors.keys()
	names.sort()
	assert_eq(names, ["catacombs", "court", "ground", "larders", "tower"], "the castle's five floors")


func test_a_rest_waits_only_for_the_enemies_of_its_own_floor() -> void:
	var st := _castle("castle_ravenloft_main_floor")
	assert_false(RestRules.waiting_fights(st, "castle_ravenloft_main_floor").is_empty(), "the ground floor is full of enemies")
	assert_false(RestRules.waiting_fights(st, "castle_ravenloft_court").is_empty(), "so is the count's floor")
	assert_false(RestRules.long_rest_refusals(st).is_empty(), "no rest while they wait")
	_clear_floor(st, "castle_ravenloft_main_floor")
	assert_eq(RestRules.waiting_fights(st, "castle_ravenloft_chapel"), [] as Array[Dictionary], "the chapel and the balcony are the ground floor's")
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String], "the ground floor is clear: the party may rest, whatever waits above and below")
	assert_false(RestRules.waiting_fights(st, "castle_ravenloft_court").is_empty(), "the count's floor still has its enemies")
	st.location = "castle_ravenloft_court"
	var why := RestRules.long_rest_refusals(st)
	assert_eq(why.size(), 1, str(why))
	assert_true(why[0].begins_with("Enemies still prowl this floor."), why[0])


func test_a_place_that_allows_no_sleep_still_allows_none_on_a_clear_floor() -> void:
	var st := _castle("castle_ravenloft_court_belfry")
	_clear_floor(st, "castle_ravenloft_court_belfry")
	var why := RestRules.long_rest_refusals(st)
	assert_eq(why.size(), 1, str(why))
	assert_true(why[0].contains("bell overhead"), why[0])


func test_a_building_without_floors_still_waits_for_all_of_it() -> void:
	var whole := RestRules.rest_maps("death_house_ground")
	var house := RestRules.building_of("death_house_ground")
	whole.sort()
	house.sort()
	assert_eq(whole, house, "every floor of Death House")


func test_a_night_in_the_castle_is_broken_one_time_in_three() -> void:
	var die := NightDie.new(5)
	for value: int in [1, 2]:
		die.value = value
		var st := _castle("castle_ravenloft_main_floor")
		assert_eq(str(LongRest.take(st, "risky", die)["how"]), LongRest.DARK, "a %d in the castle breaks the night" % value)
	die.value = 3
	var calm := _castle("castle_ravenloft_main_floor")
	assert_true(str(LongRest.take(calm, "risky", die)["how"]) != LongRest.DARK, "a 3 does not")
	die.value = 2
	var elsewhere := _castle("village_of_barovia")
	assert_true(str(LongRest.take(elsewhere, "risky", die)["how"]) != LongRest.DARK, "and only a 1 does anywhere else")
	assert_eq(RestRules.interrupt_on(_castle("castle_ravenloft_larders")), 2)
	assert_eq(RestRules.interrupt_on(_castle("vallaki")), 1)


func test_the_castles_halls_are_visited_by_the_castles_own_dead() -> void:
	assert_eq(CampSite.land_of("castle_ravenloft", CampSite.INDOORS), "castle", "not the rats and shadows of any house")
	assert_eq(CampSite.land_of("svalich_road", CampSite.INDOORS), "indoors", "other regions' houses keep theirs")
	assert_eq(CampSite.land_of("castle_ravenloft", CampSite.TOWN), "town")
	var spawn := CampSite.groups_for("castle_ravenloft", 8, CampSite.INDOORS)
	assert_eq(spawn.size(), 1)
	assert_true("vampire_spawn" in (spawn[0]["monsters"] as Array), "vampires at level 8: %s" % [spawn[0]["monsters"]])
	for level: int in [1, 4, 7, 10]:
		assert_false(CampSite.groups_for("castle_ravenloft", level, CampSite.INDOORS).is_empty(), "something comes for a level %d night" % level)
	for g: Variant in CampSite.visitors()["groups"]:
		var group := g as Dictionary
		if str(group["land"]) == "castle":
			var words := str(group["text"]).to_lower()
			assert_false(words.contains("sky") or words.contains("fire"), "%s reads right under a vault: %s" % [group["id"], group["text"]])


func test_every_castle_place_to_sleep_has_a_night_line_of_its_own() -> void:
	var n := Narrator.new()
	var count := 0
	for loc in Compendium.shared().all("locations"):
		if str(loc.get("region", "")) != "castle_ravenloft" or str(loc.get("rest", "risky")) == "no":
			continue
		count += 1
		assert_true(n.has_trigger("rest:long:" + str(loc["id"])), "%s has a night of its own, not only the castle's" % loc["id"])
	assert_true(count >= 13, "the castle's places to sleep were counted: %d" % count)
