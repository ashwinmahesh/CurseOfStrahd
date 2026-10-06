extends TestCase
## Music and sound (owner feedback after Phase 3): every file art/audio.json names loads, every place's mood has music,
## and the effects the game asks for exist.


func test_every_listed_recording_loads() -> void:
	for section: String in ["music", "sfx"]:
		for id: String in (Audio._data[section] as Dictionary):
			for path in Audio.files(section, id):
				assert_true(ResourceLoader.exists(path) and load(path) is AudioStream, "%s %s: %s" % [section, id, path])


func test_every_place_has_music() -> void:
	var c := Compendium.shared()
	for id: String in c.table("locations"):
		var loc := c.get_entry("locations", id)
		var m := Audio.mood_for(id, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary))
		assert_false(Audio.files("music", m).is_empty(), "%s (%s) has music" % [id, m])
	for m: String in ["title", "combat"]:
		assert_false(Audio.files("music", m).is_empty(), m)


func test_the_effects_the_game_plays_exist() -> void:
	for id: String in ["click", "page", "door", "unlock", "coins", "card", "rest", "level_up", "hit", "crit", "swing",
			"spell", "heal", "victory", "defeat"]:
		assert_false(Audio.files("sfx", id).is_empty(), id)
	for mood: String in (Audio._data["ambient"] as Dictionary):
		for id: Variant in (Audio._data["ambient"] as Dictionary)[mood]:
			assert_false(Audio.files("sfx", str(id)).is_empty(), "ambient %s" % id)
