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


# --- A mood plays all its recordings (owner, 2026-10-15: one castle song seemed to go on repeating) -------------------

## A mood with several recordings plays each once in a round, in an order that changes from round to round, before any
## comes round again, and never the one just heard.
func test_a_mood_plays_every_recording_before_one_repeats() -> void:
	var saved := [Audio._data, Audio._bags, Audio._last_track]
	Audio._data = {"music": {"m": ["a.ogg", "b.ogg", "c.ogg", "d.ogg"], "pair": ["x.ogg", "y.ogg"], "one": ["z.ogg"]}}
	Audio._bags = {}
	Audio._last_track = ""
	var heard: Array[String] = []
	for i in 40:
		heard.append(str(Audio._pick_entry("m", Audio.entries("music", "m"))))
	for r in 10:
		var round_heard := heard.slice(r * 4, r * 4 + 4)
		round_heard.sort()
		assert_eq(round_heard, ["a.ogg", "b.ogg", "c.ogg", "d.ogg"], "round %d heard each one once: %s" % [r, heard.slice(r * 4, r * 4 + 4)])
	for i in range(1, heard.size()):
		assert_ne(heard[i], heard[i - 1], "pick %d is not the one before it" % i)
	var pair: Array[String] = []
	for i in 12:
		pair.append(str(Audio._pick_entry("pair", Audio.entries("music", "pair"))))
	for i in range(1, pair.size()):
		assert_ne(pair[i], pair[i - 1], "two recordings take turns")
	for i in 4:
		assert_eq(str(Audio._pick_entry("one", Audio.entries("music", "one"))), "z.ogg", "a mood with one has only that one")
	Audio._data = saved[0]
	Audio._bags = saved[1]
	Audio._last_track = saved[2]


## When a recording ends the mood goes on with another of its own; a conversation's mood in between doesn't throw the
## round off, and the one just heard never opens the next mood.
func test_a_mood_goes_on_with_another_recording_when_one_ends() -> void:
	var saved := [Audio._data, Audio._bags, Audio._last_track, Audio.mood, Audio.intensity, Audio.playing_id, Audio.playing_track]
	Audio._data = {"music": {"castle": ["a.ogg", "b.ogg", "c.ogg"], "dread": ["d.ogg", "e.ogg"], "title": ["t.ogg"]}}
	Audio._bags = {}
	Audio._last_track = ""
	Audio.mood = ""
	Audio.play_music("castle")
	var seen: Array[String] = [Audio.playing_track]
	assert_true(seen[0] in ["a.ogg", "b.ogg", "c.ogg"], "the castle's own music starts")
	for i in 8:
		Audio._next_track()
		assert_eq(Audio.playing_id, "castle", "it stays the castle's music")
		assert_ne(Audio.playing_track, seen[-1], "the next recording is another one")
		seen.append(Audio.playing_track)
	for i in 6:
		Audio.play_music("dread")
		assert_true(Audio.playing_track in ["d.ogg", "e.ogg"], "a conversation plays the dread: %s" % Audio.playing_track)
		Audio.play_music("castle")
		assert_true(Audio.playing_track in ["a.ogg", "b.ogg", "c.ogg"], "and the castle's own comes back: %s" % Audio.playing_track)
	Audio.play_music("title")
	assert_eq(Audio.playing_track, "t.ogg")
	Audio.play_music("")
	assert_eq(Audio.playing_track, "", "no music, no recording")
	Audio._data = saved[0]
	Audio._bags = saved[1]
	Audio._last_track = saved[2]
	Audio.mood = saved[3]
	Audio.intensity = saved[4]
	Audio.playing_id = saved[5]
	Audio.playing_track = saved[6]


func test_a_recording_repeats_by_itself_only_when_asked() -> void:
	var s := AudioStreamMP3.new()
	Audio._set_loop(s, true)
	assert_true(s.loop, "a mood with one recording repeats it")
	Audio._set_loop(s, false)
	assert_false(s.loop, "a mood with several lets it end and moves on")
	var w := AudioStreamWAV.new()
	Audio._set_loop(w, false)
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_DISABLED)


## Only the title screen deliberately repeats a single recording; every other mood has several to play through. A new
## mood with one recording goes in the list, on purpose.
func test_every_mood_but_the_title_has_several_recordings() -> void:
	var repeats_one := ["title"]
	for id: String in (Audio._data["music"] as Dictionary):
		if id in repeats_one:
			assert_eq(Audio.entries("music", id).size(), 1, "%s repeats its one recording" % id)
		else:
			assert_true(Audio.entries("music", id).size() >= 2, "%s has one recording, so it would repeat it: add more, or list it here" % id)


## The castle's music turns to dread for the few in it who frighten it (art/audio.json talk_moods), and only there.
func test_the_castle_turns_to_dread_for_its_menacing_few() -> void:
	for npc: String in ["strahd", "rahadin", "volenta_popofsky", "ludmilla_vilisevic", "escher", "kestrel_merrow"]:
		assert_eq(Audio.talk_mood("castle", npc), "dread", "%s brings the dread" % npc)
	for npc: String in ["", "castle_steward", "helga_ruvak", "castle_ghost_servant", "castle_courtier_1", "gertruda", "lief_lipsiege",
			"anastrasya_karelova", "pidlwick_ii", "ireena"]:
		assert_eq(Audio.talk_mood("castle", npc), "", "%s leaves the castle's music alone" % npc)
	assert_eq(Audio.talk_mood("town", "strahd"), "", "only the castle's music turns")
	assert_eq(Audio.talk_mood("haunted", "rahadin"), "")
	assert_false(Audio.is_fight_mood("dread"), "a conversation's music is not a fight's")


func test_every_talk_mood_is_complete() -> void:
	var talk := Audio._data.get("talk_moods", {}) as Dictionary
	assert_false(talk.is_empty(), "some place's music turns for a conversation")
	var places := {}
	for k: Variant in (Audio._data["places"] as Dictionary).values() + (Audio._data["themes"] as Dictionary).values() \
			+ (Audio._data["regions"] as Dictionary).values():
		places[str(k)] = true
	for place_mood: String in talk:
		var entry := talk[place_mood] as Dictionary
		var m := str(entry.get("mood", ""))
		assert_true(places.has(place_mood), "%s is the music of some place" % place_mood)
		assert_true(Audio.files("music", m).size() >= 2, "%s has several recordings to play" % m)
		assert_false(places.has(m), "%s is for a conversation, not a place" % m)
		assert_false((entry.get("npcs", []) as Array).is_empty(), "%s names who brings it" % m)
		for npc: Variant in entry.get("npcs", []):
			assert_false(Compendium.shared().get_entry("npcs", str(npc)).is_empty(), "%s is an NPC" % npc)


# --- A scene's own music (owner's music audit, 2026-10-17: docs/assets/music_audit.md) ----------------------------------

## A cutscene can bring its own music to the conversation under it (art/audio.json "scenes"): every entry names a
## cutscene a conversation plays and a mood with several recordings, none of them a fight's.
func test_every_scene_mood_is_complete() -> void:
	var scenes := Audio._data.get("scenes", {}) as Dictionary
	assert_false(scenes.is_empty(), "some scene has its own music")
	for id: String in scenes:
		var m := str(scenes[id])
		assert_false(Cutscenes.get_cutscene(id).is_empty(), "%s is a cutscene" % id)
		assert_eq(str(Cutscenes.get_cutscene(id).get("trigger", "")), "", "%s plays in a conversation, not from a place" % id)
		assert_true(Audio.files("music", m).size() >= 2, "%s: %s has several recordings to play" % [id, m])
		assert_false(Audio.is_fight_mood(m), "%s: %s is not a fight's music" % [id, m])
		assert_eq(Audio.scene_mood(id), m)
	assert_eq(Audio.scene_mood("no_such_scene"), "", "a scene without its own leaves the music alone")
	assert_eq(Audio.scene_mood(""), "", "nor does taking a picture away")


## Strahd brings the dread wherever he turns up, not only in his castle: the window of a lively inn, the camp's fire, the
## road; the moments the place's music would fight get theirs (the audit's picks).
func test_the_scenes_the_audit_turned() -> void:
	for id: String in ["strahd_watcher", "strahd_camp", "ireena_window", "church_gate", "black_carriage", "marina_rose"]:
		assert_eq(Audio.scene_mood(id), "dread", id)
	assert_eq(Audio.scene_mood("festival_standoff"), "tension", "Vallaki draws steel to no folk tune")
	assert_eq(Audio.scene_mood("elvir_burial"), "sorrow", "a burial, not the freed vineyard's dance")
	assert_eq(Audio.scene_mood("chapel_dawn"), "dawn", "real dawn in the castle chapel")
	assert_eq(Audio.scene_mood("vines_feast"), "", "the feast keeps the vineyard's own")
	assert_eq(Audio.scene_mood("burial_strahd"), "", "the village's mournful gloom suits a funeral")


## Every ending plays music, and Dawn over Barovia isn't a funeral march (the audit).
func test_every_ending_has_music() -> void:
	for e in Endings.all():
		var m := str(e.get("music", "ending"))
		assert_true(Audio.files("music", m).size() >= 2, "%s: %s has music" % [e.get("id", ""), m])
	assert_eq(str(Endings.get_ending("strahd_destroyed").get("music", "")), "dawn")


## The castle's lively swing tune went (owner, 2026-10-17: it sounded like a tavern); its file and credit stay.
func test_the_castle_has_no_tavern_swing() -> void:
	var swing := "res://art/sourced/oga_isao/short_A New World Order!!_0.mp3"
	for id: String in (Audio._data["music"] as Dictionary):
		assert_false(Audio.files("music", id).has(swing), "%s plays Swing Jazz Band Gothic Dance" % id)
	assert_true(Audio.files("music", "castle").has(
			"res://art/sourced/wikimedia_commons/Frederic_Chopin_Piano_Sonata_No.2_in_B_flat_minor_Op35_-_III_Marche_Funebre.ogg"),
			"the lonely piano stays")
	assert_true(Audio.files("music", "castle").has("res://art/sourced/oga_tausdei/stronghold.mp3"), "and Stronghold")


## The castle's lonely piano (owner, 2026-10-18): the Marche funebre and the six more he picked from the listening page.
## Piano is quiet, so each carries a track level from its whole-file loudness against the Marche funebre's.
func test_the_castle_plays_the_lonely_piano() -> void:
	var piano: Array[String] = [
		"wikimedia_commons/Chopin_Nocturne_Op48_No1_Luke_Faulkner.ogg",
		"wikimedia_commons/Chopin_Prelude_Op28_No4_Ivan_Ilic.ogg",
		"wikimedia_commons/Chopin_Nocturne_Op_posth_C-sharp_minor_Musopen.ogg",
		"wikimedia_commons/Chopin_Nocturne_Op72_No1_Luke_Faulkner.mp3",
		"wikimedia_commons/Beethoven_Moonlight_Sonata_I_Paul_Pitman.ogg",
		"kevin_macleod/Wounded.mp3"]
	var levels := Audio._data["track_levels"] as Dictionary
	for f: String in piano:
		var path := "res://art/sourced/" + f
		assert_true(Audio.files("music", "castle").has(path), "the castle plays %s" % f)
		assert_true(levels.has(path), "%s has its own level" % f)
		assert_true(absf(float(levels.get(path, 99.0))) <= 12.0, "%s: a level that big would clip or vanish" % f)


## The farewells and burials (art/audio.json "scenes" -> sorrow) share the piano with the castle (owner, 2026-10-18):
## Wounded and the three nocturnes, with the strings the mood had. Every recording of the mood has its own level.
func test_sorrow_shares_the_piano_with_the_castle() -> void:
	var sorrow := Audio.files("music", "sorrow")
	var castle := Audio.files("music", "castle")
	var levels := Audio._data["track_levels"] as Dictionary
	for f: String in ["kevin_macleod/Wounded.mp3", "wikimedia_commons/Chopin_Nocturne_Op48_No1_Luke_Faulkner.ogg",
			"wikimedia_commons/Chopin_Nocturne_Op72_No1_Luke_Faulkner.mp3",
			"wikimedia_commons/Chopin_Nocturne_Op_posth_C-sharp_minor_Musopen.ogg"]:
		var path := "res://art/sourced/" + f
		assert_true(sorrow.has(path), "sorrow plays %s" % f)
		assert_true(castle.has(path), "and the castle still does")
	assert_true(sorrow.has("res://art/sourced/kevin_macleod/Relent.mp3"), "the strings stay")
	for path: String in sorrow:
		assert_true(levels.has(path), "%s has its own level" % path)


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
	# Spinning Tavern is Blood of the Vine's own tune beside the regular tavern ones (owner, 2026-10-15); no other tavern plays it.
	var spinning := "res://art/sourced/oga_inspectorj/Spinning Tavern - MP3.mp3"
	assert_eq(Audio.mood_for("blood_of_the_vine", "tavern"), "blood_of_the_vine", "Blood of the Vine has its own music")
	var vine := Audio.files("music", "blood_of_the_vine")
	assert_true(vine.has(spinning), "it plays Spinning Tavern")
	for path in Audio.files("music", "tavern"):
		assert_true(vine.has(path), "and still the regular tavern tune %s" % path)
	assert_false(Audio.files("music", "tavern").has(spinning), "no other tavern plays it")
	# The title screen opens on Bach's Toccata (owner, 2026-10-15); Skeleton Waltz Theme plays among the haunted tracks.
	var toccata := "res://art/sourced/wikimedia_commons/Bach,_Toccata_und_Fuge_d-moll_BWV_565,_Norbert_Schenk.mp3"
	var waltz := "res://art/sourced/oga_wolfgang/Bone Yard Waltz - Loopable.ogg"
	var title := Audio.files("music", "title")
	assert_true(title.size() == 1 and title.has(toccata), "the title screen plays the Toccata alone")
	assert_true(Audio.files("music", "haunted").has(waltz), "Skeleton Waltz Theme plays in the haunted mood")


## The Wizard of Wines turns cheerful once Yester Hill is broken (owner, 2026-10-13): every one of its places, the
## winery's tavern hall too, plays the region's later theme; before that each keeps its own, and other regions never
## take it.
func test_the_vineyard_turns_cheerful_once_yester_hill_is_broken() -> void:
	var c := Compendium.shared()
	var st := StoryState.new()
	var places := {}
	for id: String in c.table("locations"):
		var loc := c.get_entry("locations", id)
		if str(loc.get("region", "")) == "wizard_of_wines":
			places[id] = ArenaBoard.theme_for(loc.get("map", {}) as Dictionary)
	for id: String in ["wizard_of_wines", "wizard_of_wines_winery", "wizard_of_wines_press_house", "wizard_of_wines_cellar"]:
		assert_true(places.has(id), "%s is in the Wizard of Wines" % id)
	assert_false(Audio.files("music", "vineyard_freed").is_empty(), "the later theme has music")
	for id: String in places:
		var before := Audio.mood_for(id, str(places[id]), st)
		assert_eq(before, Audio.mood_for(id, str(places[id])), "%s keeps its music before the hill falls" % id)
		assert_ne(before, "vineyard_freed", id)
	st.set_flag("yester_hill_resolved")
	for id: String in places:
		assert_eq(Audio.mood_for(id, str(places[id]), st), "vineyard_freed", "%s turns cheerful" % id)
	for id: String in ["yester_hill", "vallaki_blue_water_inn"]:
		var theme := ArenaBoard.theme_for(c.get_entry("locations", id).get("map", {}) as Dictionary)
		assert_eq(Audio.mood_for(id, theme, st), Audio.mood_for(id, theme), "%s keeps its own music" % id)


## Every later theme names a region places belong to, a mood with music and a condition (an empty one would always hold).
func test_every_region_turn_is_complete() -> void:
	var regions := {}
	for id: String in Compendium.shared().table("locations"):
		regions[str(Compendium.shared().get_entry("locations", id).get("region", ""))] = true
	var turns := Audio._data.get("region_turns", {}) as Dictionary
	assert_false(turns.is_empty(), "some region has a later theme")
	for region: String in turns:
		assert_true(regions.has(region), "%s is a region places belong to" % region)
		for t: Variant in turns[region] as Array:
			var turn := t as Dictionary
			assert_ne(str(turn.get("when", "")).strip_edges(), "", "%s: a later theme needs a condition" % region)
			assert_false(Audio.files("music", str(turn.get("mood", ""))).is_empty(), "%s: %s has music" % [region, turn.get("mood", "")])


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
