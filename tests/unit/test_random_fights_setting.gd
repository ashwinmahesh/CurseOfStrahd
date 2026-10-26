extends TestCase
## Random fights (Ashwin, 2026-10-26: "an option to turn off combat random encounters in settings"): with the setting off,
## Travel.roll never returns a fight (a road's roll that would pick one leaves it quiet), meetings are rolled as before, and
## nothing a fight would have marked seen is marked. On, as it always was, both come.

const TABLE := "test_random_fights"

var st: StoryState


func before_each() -> void:
	StrahdPresence.use_attention({})
	Weather.use({"kinds": {}, "climates": {}})
	st = StoryState.new()
	st.party.append(Pregens.build("ilse_varga", 5))
	st.minute_of_day = 12 * 60
	Compendium.shared().tables["random_encounters"][TABLE] = {"id": TABLE, "map": "road_ambush", "chance_day": 0.95,
		"chance_night": 0.95, "entries": [
			{"id": "wolves", "weight": 1, "once": true, "monsters": [{"monster": "wolf", "cell": [1, 1]}]},
			{"id": "pilgrim", "weight": 1, "dialogue": "test/pilgrim"}]}
	GameSettings.set_random_fights(true)


func after_each() -> void:
	StrahdPresence.use_attention({})
	Weather.use({})
	Compendium.shared().tables["random_encounters"].erase(TABLE)
	GameSettings.set_random_fights(true)


## What `n` rolls of the test road gave: {fights, meetings} counts.
func _rolls(fights_on: bool, n: int = 300) -> Dictionary:
	var road := {"id": "test_leg", "name": "A test road", "table": TABLE}
	var dice := DiceRoller.new(5)
	var out := {"fights": 0, "meetings": 0}
	for i in n:
		st.flags.erase("_random_seen")   # the wolves are `once`: let them come again each roll
		var ev := Travel.roll(road, st, dice, "", "", fights_on)
		if ev.is_empty():
			continue
		out["fights" if (ev["entry"] as Dictionary).has("monsters") else "meetings"] += 1
	return out


func test_with_fights_off_no_road_brings_one() -> void:
	var on := _rolls(true)
	assert_true(int(on["fights"]) > 20 and int(on["meetings"]) > 20, "on: both come: %s" % [on])
	var off := _rolls(false)
	assert_eq(int(off["fights"]), 0, "off: no fight")
	assert_true(int(off["meetings"]) > 20, "off: meetings still come at about the same rate: %s vs %s" % [off, on])
	assert_true(absi(int(off["meetings"]) - int(on["meetings"])) < 40, "the meetings' rate does not change: %s vs %s" % [off, on])


func test_a_fight_kept_off_the_road_is_not_marked_seen() -> void:
	var road := {"id": "test_leg", "name": "A test road", "table": TABLE}
	var dice := DiceRoller.new(9)
	for i in 200:
		Travel.roll(road, st, dice, "", "", false)
	var seen := st.flags.get("_random_seen", {}) as Dictionary
	assert_false(seen.has("%s:wolves" % TABLE), "the `once` fight that never came is still to come")


func test_the_setting_is_on_by_default_and_kept() -> void:
	assert_true(GameSettings.random_fights())
	GameSettings.set_random_fights(false)
	assert_false(GameSettings.random_fights())
	GameSettings.set_random_fights(true)
	assert_true(GameSettings.random_fights())
