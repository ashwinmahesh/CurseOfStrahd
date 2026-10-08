extends Node
## Music and sound effects (owner feedback after Phase 3). The recordings are free-licensed files kept untouched in
## art/sourced/<pack>/ (docs/assets/LICENSES.md); art/audio.json says which file plays for each mood and each effect,
## and which mood each place or map theme has. A mood or effect with no file is silent, so nothing depends on audio.
## Volumes are the player's, kept in their settings file (GameSettings.path: user://settings.cfg, or a test's or
## capture's own), not in a save.

const MANIFEST := "res://art/audio.json"
const FADE := 1.6
## How loud the music is (A2): calm while exploring, a fight's own level, and full while a boss stands on the field or
## someone in the party is Bloodied.
enum Intensity { CALM, FIGHT, FULL }
const FIGHT_MOODS: Array[String] = ["combat", "boss"]
## Seconds the music takes to swell or fall between intensities.
const SWELL := 2.5
## A fight's danger is checked this often; the music falls back only after the danger has passed for CALM_CHECKS checks
## in a row, so a quick heal between two blows doesn't make it see-saw.
const FIGHT_CHECK := 1.0
const CALM_CHECKS := 5
## A silent intensity version (linear_to_db(0.001)).
const SILENT_DB := -60.0

var music_volume := 0.6
var sfx_volume := 0.8
var mood := ""
var intensity: int = Intensity.CALM
var _data: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _deck := 0
## Each deck's running fade, so a new fade or a sting's dip replaces the old one instead of fighting it.
var _deck_tweens: Array[Tween] = [null, null]
## The music id on the current deck: the mood's own, or at full intensity the harder mood "rises" names for it.
var playing_id := ""
## The current deck's volume: its music id's level plus its recording's own ("track_levels").
var _playing_db := 0.0
## The current recording's intensity versions playing in step, when it was recorded at several intensities.
var _versions: AudioStreamSynchronized = null
var _swell_tween: Tween = null
var _fight: WeakRef = null
var _fight_timer: Timer
var _calm_checks := 0
var _sfx: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()  # cosmetic: which of several takes plays, when ambience sounds
var _ambience: Timer
## No sound device (headless tests and tools): moods and choices still work, nothing plays, so no playback is left
## for an audio thread that never runs to release.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = AudioServer.get_driver_name() == "Dummy"
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
		_decks.append(p)
	for i in 8:
		var s := AudioStreamPlayer.new()
		s.bus = &"SFX"
		add_child(s)
		_sfx.append(s)
	if FileAccess.file_exists(MANIFEST):
		_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	_ambience = Timer.new()
	_ambience.one_shot = true
	_ambience.timeout.connect(_ambient)
	add_child(_ambience)
	_fight_timer = Timer.new()
	_fight_timer.wait_time = FIGHT_CHECK
	_fight_timer.timeout.connect(_check_fight)
	add_child(_fight_timer)
	var cfg := ConfigFile.new()
	if cfg.load(GameSettings.path) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volumes()


func set_volumes(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	_apply_volumes()
	var cfg := ConfigFile.new()
	cfg.load(GameSettings.path)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	DirAccess.make_dir_recursive_absolute(GameSettings.path.get_base_dir())
	cfg.save(GameSettings.path)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


## The files listed for a mood or an effect (each intensity version of a recording counts).
func files(section: String, id: String) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in entries(section, id):
		if f is Array:
			for g: Variant in f as Array:
				out.append(str(g))
		else:
			out.append(str(f))
	return out


## The recordings listed for a mood or an effect as art/audio.json writes them: a path, or for music a list of one
## piece's intensity versions from calmest to fullest, which play in step so the music swells without a seam (A2).
func entries(section: String, id: String) -> Array:
	return (_data.get(section, {}) as Dictionary).get(id, []) as Array


## The mood for a place: its own entry, else its region's theme (art/audio.json "regions", unless its map theme keeps
## its own mood there, like a tavern, or the region's theme has no music yet), else its map theme's, else "wilds".
func mood_for(location_id: String, theme: String) -> String:
	var places := _data.get("places", {}) as Dictionary
	if places.has(location_id):
		return str(places[location_id])
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", ""))
	var own := str((_data.get("regions", {}) as Dictionary).get(region, ""))
	if own != "" and not (_data.get("region_keeps", []) as Array).has(theme) and not entries("music", own).is_empty():
		return own
	return str((_data.get("themes", {}) as Dictionary).get(theme, "wilds"))


## Crossfades to a mood's music; the same mood keeps playing where it is. A fight's mood starts at the fight's own
## intensity, any other mood calm.
func play_music(next_mood: String) -> void:
	if next_mood == mood or not is_inside_tree():
		return
	mood = next_mood
	if not is_fight_mood(next_mood):
		_fight = null
		_fight_timer.stop()
	intensity = Intensity.FIGHT if is_fight_mood(next_mood) else Intensity.CALM
	_ambience.start(_rng.randf_range(12.0, 30.0))
	_crossfade_to(music_for(next_mood, intensity))


## A fight's mood: "combat", "boss", or a foe's own (art/audio.json "boss_music", Strahd's theme).
func is_fight_mood(m: String) -> bool:
	return m in FIGHT_MOODS or (_data.get("boss_music", {}) as Dictionary).values().has(m)


## The mood a foe on the field has for its own fights (art/audio.json "boss_music": Strahd's theme), or "".
func fight_mood(combatants: Array[Combatant]) -> String:
	var own := _data.get("boss_music", {}) as Dictionary
	for c in combatants:
		if c.side == &"enemy" and c.creature is Monster and c.creature.hp > 0:
			var id := str((c.creature as Monster).data.get("id", ""))
			if own.has(id):
				return str(own[id])
	return ""


## Which music id plays for a mood at an intensity: its own, or at full intensity the harder mood art/audio.json
## "rises" names for it, when the mood has no recording made at several intensities (the free way to swell, A2).
func music_for(for_mood: String, level: int) -> String:
	var rises := str((_data.get("rises", {}) as Dictionary).get(for_mood, ""))
	if level >= Intensity.FULL and rises != "" and not has_versions(for_mood) and not entries("music", rises).is_empty():
		return rises
	return for_mood


## Whether any of a mood's recordings was made at several intensities.
func has_versions(for_mood: String) -> bool:
	return entries("music", for_mood).any(func(e: Variant) -> bool: return e is Array)


## Which of a recording's `count` intensity versions plays at `level`: calm the first, a fight the middle one (the
## first of two), full the last.
static func version_for(count: int, level: int) -> int:
	if count <= 1 or level <= Intensity.CALM:
		return 0
	return (count - 1) / 2 if level == Intensity.FIGHT else count - 1


## Lets the music swell or fall (A2): between the recording's own intensity versions where it has them, else by a
## crossfade to the mood "rises" names for full intensity and back.
func set_intensity(level: int) -> void:
	level = clampi(level, Intensity.CALM, Intensity.FULL)
	if level == intensity:
		return
	var was := intensity
	intensity = level
	if _versions != null:
		var a := version_for(_versions.stream_count, was)
		var b := version_for(_versions.stream_count, level)
		if a != b:
			_swell(a, b)
		return
	var id := music_for(mood, level)
	if id != playing_id:
		_crossfade_to(id)


## Follows a fight's danger (A2): full intensity while a boss stands on the field or someone in the party is Bloodied,
## the fight's own level otherwise. Checked every FIGHT_CHECK seconds until the music leaves the fight's mood.
func follow_fight(cv: CombatView) -> void:
	if not is_instance_valid(cv):
		return
	_fight = weakref(cv)
	_calm_checks = 0
	_fight_timer.start()
	_check_fight()


## How dangerous a fight looks for the music: FULL with a boss (a foe with legendary actions) still standing or
## anyone in the party or a guest Bloodied, else FIGHT.
static func danger(combatants: Array[Combatant]) -> int:
	for c in combatants:
		if c.creature == null:
			continue
		if c.side in [&"party", &"guest"] and c.creature.is_bloodied():
			return Intensity.FULL
		if c.side == &"enemy" and c.creature.hp > 0 and c.creature is Monster \
				and not ((c.creature as Monster).data.get("legendary_actions", {}) as Dictionary).is_empty():
			return Intensity.FULL
	return Intensity.FIGHT


func _check_fight() -> void:
	var cv := _fight.get_ref() as CombatView if _fight != null else null
	if cv == null or cv.e == null or not is_fight_mood(mood):
		if cv == null:
			_fight_timer.stop()
		return
	var own := fight_mood(cv.e.combatants)
	if own != "" and own != mood:
		play_music(own)
	var level := danger(cv.e.combatants)
	if level >= intensity:
		_calm_checks = 0
		set_intensity(level)
		return
	_calm_checks += 1
	if _calm_checks >= CALM_CHECKS:
		_calm_checks = 0
		set_intensity(level)


## Crossfades from the current deck to music `id`.
func _crossfade_to(id: String) -> void:
	playing_id = id
	_versions = null
	if _swell_tween != null:
		_swell_tween.kill()
	var choices := entries("music", id)
	var old := _decks[_deck]
	var old_index := _deck
	_deck = 1 - _deck
	var new := _decks[_deck]
	var tw := _deck_tween(old_index)
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.tween_callback(old.stop)
	if choices.is_empty() or _silent:
		return
	var entry: Variant = choices[_rng.randi_range(0, choices.size() - 1)]
	var stream := _music_stream(entry)
	if stream == null:
		return
	_playing_db = level_db(id) + track_level(str((entry as Array)[0]) if entry is Array else str(entry))
	new.stream = stream
	new.volume_db = -30.0
	new.play()
	_deck_tween(_deck).tween_property(new, "volume_db", _playing_db, FADE)


## A deck's fresh tween, replacing whatever fade or dip it had running.
func _deck_tween(index: int) -> Tween:
	if _deck_tweens[index] != null:
		_deck_tweens[index].kill()
	_deck_tweens[index] = create_tween()
	return _deck_tweens[index]


## A recording's own volume offset in dB (art/audio.json "track_levels"), so the pieces a mood picks between sound
## about as loud as each other.
func track_level(path: String) -> float:
	return float((_data.get("track_levels", {}) as Dictionary).get(path, 0.0))


## A music mood's or an effect's volume offset in dB (art/audio.json "levels").
func level_db(id: String) -> float:
	return float((_data.get("levels", {}) as Dictionary).get(id, 0.0))


## One music entry as a stream: a path loops on its own; a list of intensity versions loops in step, with only the
## version for the current intensity heard.
func _music_stream(entry: Variant) -> AudioStream:
	if not entry is Array:
		return _stream(str(entry), true)
	var parts := entry as Array
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = parts.size()
	var on := version_for(parts.size(), intensity)
	for i in parts.size():
		var s := _stream(str(parts[i]), true)
		if s == null:
			return null
		sync.set_sync_stream(i, s)
		sync.set_sync_stream_volume(i, 0.0 if i == on else SILENT_DB)
	_versions = sync
	return sync


## Fades intensity version `from` out and `to` in, in step.
func _swell(from: int, to: int) -> void:
	if _swell_tween != null:
		_swell_tween.kill()
	var sync := _versions
	for i in sync.stream_count:
		if i != from and i != to:
			sync.set_sync_stream_volume(i, SILENT_DB)
	_swell_tween = create_tween()
	_swell_tween.tween_method(func(t: float) -> void:
		sync.set_sync_stream_volume(from, linear_to_db(maxf(1.0 - t, 0.001)))
		sync.set_sync_stream_volume(to, linear_to_db(maxf(t, 0.001))), 0.0, 1.0, SWELL)


## Now and then a crow, a far-off wolf or the wind over the music (art/audio.json "ambient" per mood).
func _ambient() -> void:
	var list := (_data.get("ambient", {}) as Dictionary).get(mood, []) as Array
	if not list.is_empty():
		sfx(str(list[_rng.randi_range(0, list.size() - 1)]), 0.08)
	_ambience.start(_rng.randf_range(25.0, 60.0))


func stop_music() -> void:
	play_music("")


## Whether sound plays here: false with no sound device (headless tests and tools), where nothing should start.
func audible() -> bool:
	return not _silent


## A looping bed for a place (a fire, running water; art/audio.json "loops"), one of its takes at random; null when it
## has none. WorldSounds plays it from where it is.
func loop_stream(id: String) -> AudioStream:
	var choices := files("loops", id)
	if choices.is_empty():
		return null
	return _stream(choices[_rng.randi_range(0, choices.size() - 1)], true)


## A one-shot effect (a click, a door, a sword hit); several takes of one effect are picked at random. `volume_db` is
## added to its level (quieter footsteps while sneaking).
func sfx(id: String, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> void:
	var choices := files("sfx", id)
	if choices.is_empty() or not is_inside_tree() or _silent:
		return
	var stream := _stream(choices[_rng.randi_range(0, choices.size() - 1)], false)
	if stream == null:
		return
	var p := _sfx[0]
	for s in _sfx:
		if not s.playing:
			p = s
			break
	p.stream = stream
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = level_db(id) + volume_db
	p.play()


## A short piece over the music (victory, defeat): the music ducks under it.
func sting(id: String) -> void:
	var deck := _decks[_deck]
	if deck.playing:
		var tw := _deck_tween(_deck)
		tw.tween_property(deck, "volume_db", -18.0, 0.3)
		tw.tween_interval(3.0)
		tw.tween_property(deck, "volume_db", _playing_db, 2.0)
	sfx(id, 0.0)


func _stream(path: String, looped: bool) -> AudioStream:
	if _streams.has(path):
		return _streams[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s != null and looped:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		elif s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if w.loop_end <= w.loop_begin:   # imported without loop points: loop the whole recording
				w.loop_end = int(w.get_length() * w.mix_rate)
	_streams[path] = s
	return s


## Players still sounding at quit would hold their streams past shutdown.
func _exit_tree() -> void:
	_ambience.stop()
	_fight_timer.stop()
	_versions = null
	for p in _decks:
		p.stop()
		p.stream = null
	for p in _sfx:
		p.stop()
		p.stream = null
	_streams.clear()
