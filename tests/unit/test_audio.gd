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
	for id: String in ["click", "page", "door", "locked", "unlock", "coins", "card", "rest", "level_up", "hit", "crit", "swing",
			"spell", "heal", "victory", "defeat"]:
		assert_false(Audio.files("sfx", id).is_empty(), id)
	for mood: String in (Audio._data["ambient"] as Dictionary):
		for id: Variant in (Audio._data["ambient"] as Dictionary)[mood]:
			assert_false(Audio.files("sfx", str(id)).is_empty(), "ambient %s" % id)


# --- Music that follows the fight (A2) ---------------------------------------------------------------------------

func test_intensity_versions_by_level() -> void:
	var I := Audio.Intensity
	assert_eq(Audio.version_for(3, I.CALM), 0, "three versions: calm plays the first")
	assert_eq(Audio.version_for(3, I.FIGHT), 1, "a fight the middle one")
	assert_eq(Audio.version_for(3, I.FULL), 2, "full the last")
	assert_eq(Audio.version_for(2, I.FIGHT), 0, "two versions: a fight stays on the first")
	assert_eq(Audio.version_for(2, I.FULL), 1)
	assert_eq(Audio.version_for(1, I.FULL), 0, "one recording has nothing to swell to")


## The free way to swell: at full intensity the music crossfades to the mood "rises" names, and back as the danger
## passes; a mood with recordings made at several intensities swells inside its own recording instead.
func test_full_intensity_rises_to_the_harder_mood() -> void:
	var saved := [Audio._data, Audio.mood, Audio.intensity, Audio.playing_id]
	Audio._data = {"music": {"combat": ["res://a.ogg"], "combat_hard": ["res://b.ogg"], "boss": [["res://c1.ogg", "res://c2.ogg"]]},
		"rises": {"combat": "combat_hard", "boss": "combat_hard", "wilds": "combat_hard"}}
	Audio.mood = ""
	Audio.play_music("combat")
	assert_eq(Audio.intensity, Audio.Intensity.FIGHT, "a fight starts at its own intensity")
	assert_eq(Audio.playing_id, "combat")
	Audio.set_intensity(Audio.Intensity.FULL)
	assert_eq(Audio.playing_id, "combat_hard", "full intensity crossfades to the harder mood")
	Audio.set_intensity(Audio.Intensity.FIGHT)
	assert_eq(Audio.playing_id, "combat", "and back once the danger passes")
	assert_true(Audio.has_versions("boss"))
	assert_eq(Audio.music_for("boss", Audio.Intensity.FULL), "boss", "a recording with versions swells in itself")
	assert_eq(Audio.files("music", "boss"), ["res://c1.ogg", "res://c2.ogg"] as Array[String], "every version is listed")
	Audio.play_music("wilds")
	assert_eq(Audio.intensity, Audio.Intensity.CALM, "leaving the fight calms the music")
	Audio._data = saved[0]
	Audio.mood = saved[1]
	Audio.intensity = saved[2]
	Audio.playing_id = saved[3]


func test_danger_rises_with_a_bloodied_hero_or_a_boss() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(5, 1))
	assert_eq(Audio.danger(e.combatants), Audio.Intensity.FIGHT, "a fresh party against zombies")
	hero.creature.hp = floori(hero.creature.max_hp() / 2.0)
	assert_eq(Audio.danger(e.combatants), Audio.Intensity.FULL, "a Bloodied hero")
	hero.creature.hp = hero.creature.max_hp()
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(8, 4))
	assert_eq(Audio.danger(e.combatants), Audio.Intensity.FULL, "Strahd on the field")
	strahd.creature.hp = 0
	assert_eq(Audio.danger(e.combatants), Audio.Intensity.FIGHT, "a fallen boss no longer counts")


## Fights stay on free recordings (owner, 2026-10-08): a Bloodied hero crossfades an ordinary fight to the harder
## track, and Strahd brings his own theme.
func test_fights_rise_and_strahd_has_his_theme() -> void:
	assert_eq(Audio.music_for("combat", Audio.Intensity.FULL), "combat_hard", "a Bloodied hero swells an ordinary fight")
	assert_false(Audio.files("music", "combat_hard").is_empty())
	var e := TestCombat.open_field()
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(5, 1))
	assert_eq(Audio.fight_mood(e.combatants), "", "zombies have no theme of their own")
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(8, 4))
	assert_eq(Audio.fight_mood(e.combatants), "strahd", "Strahd brings his own")
	assert_true(Audio.is_fight_mood("strahd"))
	assert_false(Audio.files("music", "strahd").is_empty())
	strahd.creature.hp = 0
	assert_eq(Audio.fight_mood(e.combatants), "")


func test_every_track_level_names_a_listed_recording() -> void:
	var listed := {}
	for id: String in (Audio._data["music"] as Dictionary):
		for path in Audio.files("music", id):
			listed[path] = true
	for path: String in (Audio._data.get("track_levels", {}) as Dictionary):
		assert_true(listed.has(path), "track_levels names %s, which no mood plays" % path)


## Region themes (A1, lane 11): a region's places play its theme, but taverns and the like keep their own mood.
func test_regions_play_their_theme() -> void:
	var c := Compendium.shared()
	var regions := Audio._data.get("regions", {}) as Dictionary
	var checked := 0
	for id: String in c.table("locations"):
		var loc := c.get_entry("locations", id)
		var own := str(regions.get(str(loc.get("region", "")), ""))
		var theme := ArenaBoard.theme_for(loc.get("map", {}) as Dictionary)
		if own == "" or (Audio._data["places"] as Dictionary).has(id) or (Audio._data.get("region_keeps", []) as Array).has(theme) \
				or Audio.files("music", own).is_empty():
			continue
		assert_eq(Audio.mood_for(id, theme), own, "%s plays its region's theme" % id)
		checked += 1
	assert_true(checked > 0, "some region has a theme")
	assert_eq(Audio.mood_for("vallaki_blue_water_inn", "tavern"), "tavern", "an inn keeps its tavern music")
	assert_eq(Audio.mood_for("vallaki_st_andrals", "church"), "church", "St. Andral's keeps the church's")


## The volumes are kept in the settings file GameSettings.path names, like every other setting: a test run's own file,
## never the player's (QA, 2026-10-08: the pause menu's Voices slider test rewrote the owner's settings.cfg in every
## full make ci). No game script names the player's file itself.
func test_volumes_are_kept_in_the_settings_file_in_use() -> void:
	assert_ne(GameSettings.path, "user://settings.cfg", "tests never touch the player's own settings")
	var music := Audio.music_volume
	var sfx := Audio.sfx_volume
	var voice := VoiceOver.volume()
	Audio.set_volumes(0.25, 0.5)
	VoiceOver.set_volume(0.75)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(GameSettings.path), OK, "the volumes went to the run's own settings file")
	assert_eq(float(cfg.get_value("audio", "music", -1.0)), 0.25, "music")
	assert_eq(float(cfg.get_value("audio", "sfx", -1.0)), 0.5, "effects")
	assert_eq(float(cfg.get_value("audio", "voice", -1.0)), 0.75, "voices")
	Audio.set_volumes(music, sfx)
	VoiceOver.set_volume(voice)
	for dir: String in ["res://core/", "res://ui/", "res://world/", "res://story/", "res://rules/", "res://combat/"]:
		for path in _scripts(dir):
			if path == "res://core/game_settings.gd":
				continue
			for line in FileAccess.get_file_as_string(path).split("\n"):
				if line.contains("\"user://settings.cfg\"") and not line.strip_edges().begins_with("#"):
					fail("%s names the player's settings file itself; use GameSettings.path" % path)


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + d + "/"))
	return out
