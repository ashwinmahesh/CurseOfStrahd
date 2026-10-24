extends TestCase
## The vault beneath Marina's Monument plays the castle's music (held ask of 2026-10-23: "more somber music, similar to Strahd's
## castle", reusing the castle's recordings): its own entry in art/audio.json "places", where the rest of Berez keeps its own.


func test_the_vault_under_the_monument_plays_the_castles_music() -> void:
	var theme := str(((Compendium.shared().get_entry("locations", "berez_marinas_monument") as Dictionary)["map"] as Dictionary)["theme"])
	assert_eq(Audio.mood_for("berez_marinas_monument", theme, null), "castle", "the same mood as Strahd's castle")
	assert_false(Audio.entries("music", "castle").is_empty(), "and the castle's recordings are there to play")


func test_the_rest_of_berez_keeps_its_own_music() -> void:
	for id: String in ["berez", "berez_marsh_track", "berez_baba_lysagas_hut"]:
		var loc := Compendium.shared().get_entry("locations", id) as Dictionary
		assert_eq(Audio.mood_for(id, str((loc["map"] as Dictionary)["theme"]), null), "berez", "%s plays Berez's music" % id)
