extends Node
## Music and sound effects (owner feedback after Phase 3). The recordings are free-licensed files kept untouched in
## art/sourced/<pack>/ (docs/assets/LICENSES.md); art/audio.json says which file plays for each mood and each effect,
## and which mood each place or map theme has. A mood or effect with no file is silent, so nothing depends on audio.
## Volumes are the player's, kept in user://settings.cfg (not in a save).

const MANIFEST := "res://art/audio.json"
const SETTINGS := "user://settings.cfg"
const FADE := 1.6

var music_volume := 0.6
var sfx_volume := 0.8
var mood := ""
var _data: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _deck := 0
var _sfx: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()  # cosmetic: which of several takes plays


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volumes()


func set_volumes(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	_apply_volumes()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


## The files listed for a mood or an effect.
func files(section: String, id: String) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in (_data.get(section, {}) as Dictionary).get(id, []):
		out.append(str(f))
	return out


## The mood for a place: its own entry, else its map theme's, else "wilds".
func mood_for(location_id: String, theme: String) -> String:
	var places := _data.get("places", {}) as Dictionary
	if places.has(location_id):
		return str(places[location_id])
	return str((_data.get("themes", {}) as Dictionary).get(theme, "wilds"))


## Crossfades to a mood's music; the same mood keeps playing where it is.
func play_music(next_mood: String) -> void:
	if next_mood == mood:
		return
	mood = next_mood
	var choices := files("music", next_mood)
	var old := _decks[_deck]
	_deck = 1 - _deck
	var new := _decks[_deck]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.chain().tween_callback(old.stop)
	if choices.is_empty():
		return
	var stream := _stream(choices[_rng.randi_range(0, choices.size() - 1)], true)
	if stream == null:
		return
	new.stream = stream
	new.volume_db = -30.0
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", float((_data.get("levels", {}) as Dictionary).get(next_mood, 0.0)), FADE)


func stop_music() -> void:
	play_music("")


## A one-shot effect (a click, a door, a sword hit); several takes of one effect are picked at random.
func sfx(id: String, pitch_jitter: float = 0.06) -> void:
	var choices := files("sfx", id)
	if choices.is_empty():
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
	p.volume_db = float((_data.get("levels", {}) as Dictionary).get(id, 0.0))
	p.play()


## A short piece over the music (victory, defeat): the music ducks under it.
func sting(id: String) -> void:
	var deck := _decks[_deck]
	if deck.playing:
		var tw := create_tween()
		tw.tween_property(deck, "volume_db", -18.0, 0.3)
		tw.tween_interval(3.0)
		tw.tween_property(deck, "volume_db", float((_data.get("levels", {}) as Dictionary).get(mood, 0.0)), 2.0)
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
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_streams[path] = s
	return s
