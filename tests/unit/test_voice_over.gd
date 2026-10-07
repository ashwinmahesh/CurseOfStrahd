extends TestCase
## Spoken lines (ADR 0013): the game finds a line's clip by the same key tools/audio/voice_lines.py gives it, a line
## with no clip is silent, and every recorded clip belongs to a speaker the game knows and loads.


func test_key_matches_the_generator() -> void:
	# Keys computed by tools/audio/voice_lines.py key().
	assert_eq(VoiceOver.key("The door shuts behind you with a satisfied click."), "9d4d992faaf8a620")
	assert_eq(VoiceOver.key("  Strangers, in Barovia. Either a miracle or a mistake. "), "3f8aae857f86d1b6", "edges trimmed")
	assert_eq(VoiceOver.key("Café — naïve “quotes”"), "abcedcd1e782a191", "UTF-8")


func test_clip_path() -> void:
	assert_eq(VoiceOver.clip_path("narrator", "The door shuts behind you with a satisfied click."),
		"res://audio/voice/narrator/9d4d992faaf8a620.mp3")


func test_a_line_without_a_clip_is_silent() -> void:
	assert_false(VoiceOver.has_clip("narrator", "No writer has ever written this line, and nobody has voiced it."))
	assert_eq(VoiceOver.say("narrator", "No writer has ever written this line, and nobody has voiced it."), 0.0)
	assert_eq(VoiceOver.say("", "Anything."), 0.0, "no speaker")
	assert_false(VoiceOver.is_speaking())


func test_every_clip_belongs_to_a_known_speaker_and_loads() -> void:
	var dir := DirAccess.open(VoiceOver.DIR)
	if dir == null:
		return
	for speaker in dir.get_directories():
		assert_true(speaker == VoiceOver.NARRATOR or speaker in VoiceOver.HEROES or speaker in VoiceOver.HERO_VOICES
			or not Compendium.shared().get_entry("npcs", speaker).is_empty() or CombatBarks.is_speaker(speaker),
			"%s is the Narrator, a hero, an npc or a fight voice" % speaker)
		var clips := Array(DirAccess.open(VoiceOver.DIR + speaker).get_files()).filter(func(f: String) -> bool:
			return f.ends_with(".mp3"))
		# A few per speaker: loading thousands of clips would slow the suite for no extra safety.
		for f: String in clips.slice(0, 3):
			var path := VoiceOver.DIR + speaker + "/" + f
			assert_true(load(path) is AudioStream, path)


func test_every_recorded_line_finds_its_clip() -> void:
	# The generator's manifest (speaker/key -> the text it voiced): the game must reach each clip from the text alone.
	var path := VoiceOver.DIR + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var said := false
	for id: String in manifest:
		var speaker := id.get_slice("/", 0)
		var text := str((manifest[id] as Dictionary)["text"])
		assert_eq(speaker + "/" + VoiceOver.key(text), id, "key of: " + text)
		assert_true(VoiceOver.has_clip(speaker, text), id)
		if not said:
			said = true
			assert_true(VoiceOver.say(speaker, text) > 0.5, "say() returns the clip's length")
			VoiceOver.stop()


func test_party_members_speak_in_their_own_voices() -> void:
	for id: String in VoiceOver.HEROES:
		assert_eq(VoiceOver.voice_for(TestChars.pregen(id)), id)
	# A custom character speaks in the hero voice the player picked; with none picked, not at all.
	var custom := TestChars.pregen("ilse_varga")
	custom.id = "custom_1"
	custom.name = "Mara Vey"
	custom.build["appearance"] = {"custom": true, "voice": "hero_male"}
	assert_eq(VoiceOver.voice_for(custom), "hero_male")
	custom.build["appearance"] = {"custom": true}
	assert_eq(VoiceOver.voice_for(custom), "")
	assert_eq(VoiceOver.voice_for(null), "")


func test_a_party_line_beat_finds_its_speakers_voice() -> void:
	var saved: Array[Character] = GameState.story.party.duplicate()
	var hedda := TestChars.pregen("hedda_ironvow")
	var party: Array[Character] = [hedda]
	GameState.story.party = party
	assert_eq(VoiceOver.beat_voice({"speaker_id": hedda.id, "party": true, "text": "Dawn comes."}), "hedda_ironvow")
	assert_eq(VoiceOver.beat_voice({"speaker_id": "ismark", "party": false, "text": "Welcome to Barovia."}), "ismark")
	assert_eq(VoiceOver.beat_voice({"speaker_id": "nobody", "party": true, "text": "Hm."}), "")
	GameState.story.party = saved
