extends TestCase
## The game's HD-2D look (data/campaign.json "hd2d", the moods' focus, moon colour, moths and motes): every setting is
## one the engine knows, in range, and the places meant to flutter with moths and drift with motes do.

## Places lit by lamps and candles: their Modern weather has moths round the flames.
const MOTH_PLACES := ["tavern", "warm_inn", "sour_tavern", "barovia_village", "vallaki", "krezk", "wizard_of_wines"]


func _kinds(mood_id: String) -> Array[String]:
	var base := Atmosphere.resolve(mood_id)
	var own := base.get("modern", {}) as Dictionary
	Atmosphere._merge(base, own)
	var out: Array[String] = []
	for w: Variant in base.get("weather", []):
		out.append(str(w) if not w is Dictionary else str((w as Dictionary)["kind"]))
	return out


func test_the_games_settings_are_the_engines_and_in_range() -> void:
	var own: Variant = Campaign.config().get("hd2d", {})
	assert_true(own is Dictionary and not (own as Dictionary).is_empty(), "the game turns HD-2D on")
	for k: String in own as Dictionary:
		assert_true(Look.HD2D.has(k), "%s is an HD-2D setting" % k)
	var h := Look.hd2d_settings()
	for k: String in ["focus", "tilt_shift", "tilt_band"]:
		assert_true(float(h[k]) >= 0.0 and float(h[k]) <= 1.0, "%s is 0 to 1" % k)
	for k: String in ["focus_fight", "bloom", "bloom_wide", "lamp_energy", "lamp_reach", "lamp_haze"]:
		assert_true(float(h[k]) > 0.0 and float(h[k]) < 3.0, "%s is a sane multiple" % k)
	assert_true(float(h["focus_fight"]) < float(h["focus_talk"]), "a fight blurs less than a conversation")
	assert_true(float(h["focus_fight"]) <= 1.0, "the board stays readable in a fight")
	for k: String in ["mote_colour", "mote_rim"]:
		assert_true(Look.color(str(h[k])) is Color, "%s names a palette colour" % k)


func test_places_name_known_palette_colours_for_their_moon_and_moths() -> void:
	var moods := (Atmosphere.moods().get("moods", {}) as Dictionary)
	for id: String in moods:
		var mood := Atmosphere.resolve(id)
		var night := ((mood.get("modern", {}) as Dictionary).get("times", {}) as Dictionary).get("night", {}) as Dictionary
		if night.has("moon_colour"):
			assert_true(Look.color(str(night["moon_colour"])) is Color, "%s's moon colour is a palette name" % id)
		if mood.has("focus"):
			assert_true(float(mood["focus"]) > 0.0 and float(mood["focus"]) <= 1.5, "%s's focus is a sane scale" % id)


func test_lamp_lit_places_have_moths_and_dark_ones_do_not() -> void:
	for id: String in MOTH_PLACES:
		assert_true("moths" in _kinds(id), "%s has moths round its lamps" % id)
	for id: String in ["crypt", "ravenloft_crypt", "death_house_crypt", "cave"]:
		assert_false("moths" in _kinds(id), "%s has none" % id)
	assert_true("motes" in _kinds("amber_temple"), "the amber temple's air glows with motes")
