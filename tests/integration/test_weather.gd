extends TestCase
## Weather as world state (F12): the same weather for the same playthrough and spell, each region's climate, storms
## that grow with Strahd's attention, journeys slowed and roads busier, sight in the open obscured, a condition for
## data, townsfolk who go in out of a storm, a line when it turns, and a place's look dressed for it.

var st: StoryState


func before_each() -> void:
	Weather.use({})
	StrahdPresence.use_attention({})
	st = StoryState.new()
	st.playthrough_seed = 1234
	st.party.append(Pregens.build("ilse_varga", 5))


func after_each() -> void:
	Weather.use({})
	StrahdPresence.use_attention({})


## A weather file with one kind per climate, so a test knows what it gets.
func _only(kinds: Dictionary) -> void:
	var d := Weather.data().duplicate(true)
	var climates := {}
	for c: String in d["climates"]:
		climates[c] = {str(kinds.get(c, kinds.get("*", "overcast"))): 1}
	d["climates"] = climates
	Weather.use(d)


func test_the_same_playthrough_gets_the_same_weather() -> void:
	var seen := {}
	for spell in 40:
		var minute := spell * 6 * 60
		var a := Weather.at(st, "vallaki", minute)
		assert_eq(Weather.at(st, "vallaki", minute + 59), a, "it holds for the spell")
		assert_eq(Weather.at(st, "vallaki", minute), a, "and never changes on a second look")
		seen[a] = true
	assert_true(seen.size() >= 3, "the valley has more than one kind of day (%s)" % [seen.keys()])
	assert_false(seen.has("snow") or seen.has("blizzard"), "and no snow")
	var mountain := {}
	for spell in 40:
		mountain[Weather.at(st, "tsolenka_pass_guard_tower", spell * 6 * 60)] = true
	assert_true(mountain.has("snow") or mountain.has("blizzard"), "the pass gets snow (%s)" % [mountain.keys()])
	assert_eq(Weather.climate_of("krezk"), "highland")
	assert_eq(Weather.climate_of("castle_ravenloft_court"), "castle")


func test_his_attention_brings_storms() -> void:
	var calm := 0
	var angry := 0
	for spell in 200:
		calm += 1 if Weather.at(st, "vallaki", spell * 6 * 60) == "storm" else 0
	StrahdPresence.use_attention({"tiers": [{"id": "unnoticed", "min": 0}, {"id": "hunted", "min": 1}],
		"marks": [{"id": "m", "when": "true", "points": 1, "summary": ""}]})
	for spell in 200:
		angry += 1 if Weather.at(st, "vallaki", spell * 6 * 60) == "storm" else 0
	assert_true(angry > calm, "hunted, more storms (%d against %d)" % [angry, calm])


func test_storms_and_snow_slow_journeys_and_fog_busies_the_roads() -> void:
	_only({"*": "overcast"})
	st.location = "vallaki"
	assert_eq(Weather.travel_mult(st), 1.0)
	_only({"*": "storm"})
	assert_eq(Weather.travel_mult(st), 1.25)
	_only({"*": "blizzard"})
	assert_eq(Weather.travel_mult(st), 2.0)
	_only({"*": "fog"})
	st.minute_of_day = 23 * 60
	assert_eq(Weather.road_bonus(st), 0.05)
	assert_true(StoryConditions.check("weather == fog and weather", st))
	assert_false(StoryConditions.check("weather == storm", st))


func test_fog_obscures_sight_only_in_the_open() -> void:
	_only({"*": "fog"})
	assert_eq(Weather.sight_penalty(st, "vallaki"), ["Fog"] as Array[String], "the town square is out in it")
	assert_true(Weather.sight_penalty(st, "vallaki_blue_water_inn").is_empty(), "not inside the inn")
	_only({"*": "rain"})
	assert_true(Weather.sight_penalty(st, "vallaki").is_empty(), "rain alone doesn't hide anything")


func test_a_place_looks_like_its_weather() -> void:
	var mood := {"weather": ["chimney_smoke", "rain", {"kind": "snow", "amount": 100}], "mist": {"cover": 0.4}}
	_only({"*": "overcast"})
	var dry := Weather.dress_mood(st, "vallaki", mood, true)
	assert_eq(dry["weather"], ["chimney_smoke"], "overcast: the mood's own rain and snow stop")
	_only({"*": "storm"})
	var wet := Weather.dress_mood(st, "vallaki", mood, true)
	assert_true((wet["weather"] as Array).has({"kind": "rain", "amount": 460}), str(wet["weather"]))
	_only({"*": "fog"})
	# Fog lays its own cover over the place's mist (data/weather: thinned on 2026-10-08, UI QA W-06), thicker than it.
	var fog_cover := float((((Weather.kind("fog")["look"] as Dictionary)["mist"]) as Dictionary)["cover"])
	assert_eq(float((Weather.dress_mood(st, "vallaki", mood, true)["mist"] as Dictionary)["cover"]), fog_cover)
	assert_true(fog_cover > 0.4, "fog is thicker than the place's own mist")
	assert_eq(Weather.dress_mood(st, "vallaki", mood, false), mood, "indoors, nothing changes")


func test_townsfolk_go_in_out_of_a_storm_and_the_party_sees_it_turn() -> void:
	Schedule.use([] as Array[Dictionary])
	_only({"*": "overcast"})
	GameState.reset()
	GameState.story.party.append(Pregens.build("ilse_varga", 5))
	GameState.story.location = "vallaki"
	GameState.story.minute_of_day = 11 * 60 + 30
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var view := root.get("view") as LocationView
	assert_true(view.npc_tokens.has("vallaki_goodwife"), "Marta is out on her round")
	var said: Array[String] = []
	view.narration.connect(func(text: String) -> void: said.append(text))
	_only({"*": "storm"})
	GameState.story.advance_minutes(45)   # 12:15: a new spell, and the storm comes
	for i in 3:
		await get_tree().process_frame
	assert_false(view.npc_tokens.has("vallaki_goodwife"), "she has gone in out of the storm")
	assert_true(said.any(func(t: String) -> bool: return t.contains("Thunder")), "the party sees it come: %s" % [said])
	root.queue_free()
	Schedule.use([] as Array[Dictionary])
