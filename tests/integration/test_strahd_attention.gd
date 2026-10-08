extends TestCase
## Strahd's attention (F9): a hidden measure worked out from the story (his servants killed, his treasures carried,
## the times he was defied), never saved. Its tier is a condition (`attention >= marked`), brings his visits closer
## together, unlocks the visits and road events that wait for it, and puts more of his patrols on the roads at night.

var st: StoryState


func before_each() -> void:
	StrahdPresence.use({})
	StrahdPresence.use_attention({})
	st = StoryState.new()
	var ch := Pregens.build("ilse_varga", 5)
	st.party.append(ch)


func after_each() -> void:
	StrahdPresence.use({})
	StrahdPresence.use_attention({})
	Compendium.shared().tables["random_encounters"].erase("test_quiet_road")


func test_attention_adds_up_from_what_he_has_noticed() -> void:
	assert_eq(StrahdPresence.attention(st), 0)
	assert_eq(str(StrahdPresence.tier(st)["id"]), "unnoticed")
	st.set_flag("gulthias_tree_burned")
	st.give_item("sunsword", 1, st.party[0])
	assert_eq(StrahdPresence.attention(st), 5, "the tree (2) and his brother's sword (3)")
	assert_eq(str(StrahdPresence.tier(st)["id"]), "watched")
	assert_true(StoryConditions.check("attention >= watched", st))
	assert_false(StoryConditions.check("attention >= marked", st))
	assert_true(StoryConditions.check("attention >= 5 and not attention > 5", st), "numbers work too")
	st.set_flag("strahd_window", "faith")
	st.set_flag("strahd_invitation", "declined")
	assert_eq(str(StrahdPresence.tier(st)["id"]), "marked", "keeping Ireena from him and refusing his carriage")
	st.set_flag("strahd_window", "taken")
	assert_eq(StrahdPresence.attention(st), 6, "he took her, so that one no longer counts")


func test_the_more_he_notices_the_sooner_he_comes_again() -> void:
	StrahdPresence.use({"gap_hours": 12, "visits": [
		{"id": "a", "trigger": {"on": ["rest"]}, "once": true},
		{"id": "b", "trigger": {"on": ["rest"]}, "once": true}]})
	assert_eq(str(StrahdPresence.due(st, "rest", {"location": ""})["id"]), "a")
	st.advance_minutes(7 * 60)
	assert_true(StrahdPresence.due(st, "rest", {"location": ""}).is_empty(), "unnoticed: twelve hours apart")
	StrahdPresence.use_attention({"tiers": [{"id": "unnoticed", "min": 0, "gap": 1.0}, {"id": "hunted", "min": 1, "gap": 0.5}],
		"marks": [{"id": "m", "when": "flag.test_mark", "points": 1, "summary": ""}]})
	st.set_flag("test_mark")
	assert_eq(str(StrahdPresence.due(st, "rest", {"location": ""})["id"]), "b", "hunted: six hours is enough")


func test_visits_wait_for_his_attention() -> void:
	st.set_flag("strahd_watcher_seen")
	var ctx := {"location": "vallaki_blue_water_inn", "night": true, "outdoors": false}
	var first := StrahdPresence.due(st, "rest", ctx)
	assert_ne(str(first.get("id", "")), "eyes_at_the_window", "not while he isn't watching")
	StrahdPresence.use({})
	st.flags.erase(StrahdPresence.MEMORY)
	st.set_flag("gulthias_tree_burned")
	st.set_flag("doru_destroyed")
	assert_eq(str(StrahdPresence.due(st, "rest", ctx).get("id", "")), "eyes_at_the_window", "watched: a bat at the shutters")
	for v: Variant in StrahdPresence.data()["visits"]:
		if str((v as Dictionary)["id"]) in ["letter_of_grievance", "the_hunt"]:
			assert_true(str((v as Dictionary)["when"]).contains("attention >="), "%s waits for his attention" % (v as Dictionary)["id"])


func test_his_patrols_crowd_the_roads_at_night() -> void:
	Compendium.shared().tables["random_encounters"]["test_quiet_road"] = {"id": "test_quiet_road", "chance_day": 0.0,
		"chance_night": 0.0, "entries": [{"id": "anything", "weight": 1}]}
	var road := {"id": "test_road", "name": "A test road", "table": "test_quiet_road"}
	st.minute_of_day = 23 * 60
	var dice := DiceRoller.new(7)
	var met := 0
	for i in 200:
		met += 0 if Travel.roll(road, st, dice).is_empty() else 1
	assert_eq(met, 0, "unnoticed, a quiet road stays quiet")
	st.give_item("sunsword", 1, st.party[0])
	st.give_item("holy_symbol_of_ravenkind", 1, st.party[0])
	st.set_flag("gulthias_tree_burned")
	st.set_flag("strahd_invitation", "declined")
	st.set_flag("strahd_withdrew")
	st.set_flag("rahadin_defeated")
	assert_eq(str(StrahdPresence.tier(st)["id"]), "hunted")
	for i in 200:
		met += 0 if Travel.roll(road, st, dice).is_empty() else 1
	assert_between(met, 10, 60, "hunted: his patrols find them about one night road in seven (%d of 200)" % met)
	var gated := 0
	for t: String in ["svalich_road", "svalich_woods", "vineyard_road"]:
		for e: Variant in Compendium.shared().get_entry("random_encounters", t)["entries"]:
			if str((e as Dictionary)["id"]) == "strahds_wolves":
				gated += 1
				assert_true(str((e as Dictionary)["when"]).contains("attention >= marked"))
	assert_eq(gated, 3, "his wolves patrol three roads once the party is marked")
