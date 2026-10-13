extends TestCase
## What the Narrator says after a Long Rest (narrative/narrator/nights.dialogue and the region files): every place a
## Long Rest can be taken has a night of its own or its region's, and every region with such a place has its dreams.
## At a camp (CampSite.night_keys) a place's own night still comes first, unless it was written for sleeping behind
## walls and the camp is out of doors.


func _restful_places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for loc in Compendium.shared().all("locations"):
		if str(loc.get("rest", "risky")) != "no":
			out.append(loc)
	return out


func test_every_place_to_rest_has_a_night_line() -> void:
	var n := Narrator.new()
	for loc in _restful_places():
		var region := str(loc.get("region", ""))
		assert_true(n.has_trigger("rest:long:" + str(loc["id"])) or n.has_trigger("rest:long:" + region),
			"%s has a night (rest:long:%s or rest:long:%s)" % [loc["id"], loc["id"], region])


func test_every_region_to_rest_in_has_its_dreams() -> void:
	var n := Narrator.new()
	for loc in _restful_places():
		assert_true(n.has_trigger("dream:" + str(loc.get("region", ""))), "%s's region dreams" % loc["id"])


## The first line the Narrator has for the night at a camp at `loc_id` (CampSite.night_keys), "" if none.
func _camp_night(n: Narrator, st: StoryState, loc_id: String) -> String:
	var loc := Compendium.shared().get_entry("locations", loc_id)
	st.location = loc_id
	for key in CampSite.night_keys(loc_id, str(loc.get("region", "")), CampSite.setting(loc)):
		var text := n.line(key, st)
		if text != "":
			return text
	return ""


func test_death_houses_own_night_comes_first_at_its_camp() -> void:
	var n := Narrator.new()
	var st := StoryState.new()
	st.visited["death_house_ground"] = true
	var text := _camp_night(n, st, "death_house_upper")
	assert_true(text.contains("the same footsteps upstairs"), "Death House's night, not the camp's: %s" % text)
	st.set_flag("death_house_completed")
	text = _camp_night(n, st, "death_house_upper")
	assert_true(text != "" and not text.contains("footsteps upstairs"), "once the house is done, the camp's own: %s" % text)


func test_a_night_behind_shutters_stays_off_a_camp_in_the_street() -> void:
	var n := Narrator.new()
	var st := StoryState.new()
	var text := _camp_night(n, st, "village_of_barovia")
	assert_false(text.contains("shutters"), "the village square is out of doors: %s" % text)
	assert_true(text in _camp_night_lines(n, "camp:night:town"), "the camp's night in town: %s" % text)
	assert_true(_camp_night(n, st, "burgomaster_mansion").contains("behind shutters"), "under the burgomaster's roof, it fits")
	assert_true(_camp_night(n, st, "blood_of_the_vine").contains("behind shutters"), "and at the inn")


## Every line `key` has, whatever its condition.
func _camp_night_lines(n: Narrator, key: String) -> Array[String]:
	var out: Array[String] = []
	for v: Dictionary in n._variants.get(key, []):
		out.append(str(v["text"]))
	return out

