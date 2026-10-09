extends TestCase
## Lightning in the rain (lane 28, owner 2026-10-09: "in rain, we can also have lightning effects happen sometimes (with
## a lighting change) and associated thunder"): rain strikes now and then and a storm often, each strike lights the
## scene, outdoors a bolt comes down beyond the map's edge and thunder follows, soon after a close strike and late after
## a far one, and nothing strikes while a cutscene plays.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Weather.use({})
	ModeController.force(ModeController.Mode.EXPLORATION)


## The whole valley under one kind of weather.
func _weather(kind: String) -> void:
	var d := Weather.data().duplicate(true)
	for c: String in d["climates"]:
		d["climates"][c] = {kind: 1}
	Weather.use(d)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func test_rain_strikes_now_and_then_and_a_storm_often() -> void:
	var rain := (Weather.kind("rain")["look"] as Dictionary)["strikes"] as Dictionary
	var storm := (Weather.kind("storm")["look"] as Dictionary)["strikes"] as Dictionary
	assert_true(float((rain["every"] as Array)[0]) > float((storm["every"] as Array)[1]), "rain strikes more rarely than a storm")
	assert_false((Weather.kind("overcast")["look"] as Dictionary).has("strikes"), "no lightning without rain")
	_weather("rain")
	var mood := Weather.dress_mood(GameState.story, "tser_pool", {"weather": []}, true)
	assert_eq(mood.get("strikes", {}), rain, "the rain's lightning reaches the place's look outdoors")
	assert_false(Weather.dress_mood(GameState.story, "tser_pool", {}, false).has("strikes"), "indoors it stays as it was")


func test_a_strike_lights_the_scene_and_brings_thunder() -> void:
	_weather("storm")
	var v := _view("tser_pool")
	await get_tree().process_frame
	var atmo := v.atmosphere
	var calm := atmo.sun.light_energy
	var ambient := atmo.env.ambient_light_energy
	atmo.strike(true)
	atmo._process(0.01)
	assert_true(atmo.sun.light_energy > calm * 2.0, "the strike lights the scene (%.2f from %.2f)" % [atmo.sun.light_energy, calm])
	assert_true(atmo.env.ambient_light_energy > ambient * 2.0, "and everything in it")
	assert_eq(atmo.strikes, 1)
	assert_true(v.find_child("LightningBolt", true, false) != null, "a bolt comes down beyond the map's edge")
	for i in 30:
		atmo._process(0.02)
	assert_true(atmo.sun.light_energy < calm * 1.05, "and fades back within a second (a flash, not a strobe)")
	v.queue_free()


func test_thunder_follows_soon_when_close_and_late_when_far() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var near := LightningStrike.thunder(self, true, rng)
		var far := LightningStrike.thunder(self, false, rng)
		assert_between(near, LightningStrike.NEAR_DELAY.x, LightningStrike.NEAR_DELAY.y, "a close strike's thunder comes soon")
		assert_between(far, LightningStrike.FAR_DELAY.x, LightningStrike.FAR_DELAY.y, "a far one's comes late")
	for id: String in ["thunder_near", "thunder_far", "thunder_crack"]:
		assert_false(Audio.files("sfx", id).is_empty(), "%s has takes" % id)
		for f: String in Audio.files("sfx", id):
			assert_true(ResourceLoader.exists(f), "%s exists" % f)


func test_no_strikes_during_a_cutscene() -> void:
	_weather("storm")
	var v := _view("tser_pool")
	await get_tree().process_frame
	var atmo := v.atmosphere
	ModeController.force(ModeController.Mode.CUTSCENE)
	atmo._next_flash = 0.0
	atmo._lightning(0.01)
	assert_eq(atmo.strikes, 0, "nothing strikes while a cutscene plays")
	ModeController.force(ModeController.Mode.EXPLORATION)
	atmo._next_flash = 0.0
	atmo._lightning(0.01)
	assert_eq(atmo.strikes, 1, "and the storm goes on after")
	v.queue_free()
