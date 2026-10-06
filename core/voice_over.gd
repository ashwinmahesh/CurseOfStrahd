class_name VoiceOver
extends RefCounted
## Spoken lines (ADR 0013). A line plays its recorded clip if it has one: res://audio/voice/<speaker>/<key>.mp3, made
## by tools/audio/generate_voice.py, where the key is a hash of the line's text. A line nobody has voiced yet (or one
## edited since it was) is simply silent, so nothing depends on audio. One voice speaks at a time: a new line, or
## moving on, cuts the last. The volume is the player's, kept beside music and effects in user://settings.cfg.

const DIR := "res://audio/voice/"
const NARRATOR := "narrator"
const BUS := &"Voice"
const SETTINGS := "user://settings.cfg"

static var _player: AudioStreamPlayer
static var _volume := -1.0


## The clip key for a line's text: the first 16 hex digits of its SHA-1 (tools/audio/voice_lines.py computes the same).
static func key(text: String) -> String:
	return text.strip_edges().sha1_text().substr(0, 16)


static func clip_path(speaker: String, text: String) -> String:
	return "%s%s/%s.mp3" % [DIR, speaker, key(text)]


static func has_clip(speaker: String, text: String) -> bool:
	return speaker != "" and text.strip_edges() != "" and ResourceLoader.exists(clip_path(speaker, text))


## Speaks a line: `speaker` is "narrator" or an npc id (a dialogue beat's speaker_id). Cuts off whatever was playing.
## Returns the clip's length in seconds, or 0.0 if the line has no clip (then nothing plays).
static func say(speaker: String, text: String) -> float:
	stop()
	if not has_clip(speaker, text):
		return 0.0
	var stream := load(clip_path(speaker, text)) as AudioStream
	if stream == null:
		return 0.0
	var p := _ensure_player()
	if p != null:
		p.stream = stream
		if p.is_inside_tree():
			p.play()
		else:
			p.play.call_deferred()
	return stream.get_length()


static func stop() -> void:
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		_player.stop()


static func is_speaking() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing


static func volume() -> float:
	if _volume < 0.0:
		var cfg := ConfigFile.new()
		_volume = float(cfg.get_value("audio", "voice", 1.0)) if cfg.load(SETTINGS) == OK else 1.0
	return _volume


static func set_volume(v: float) -> void:
	_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "voice", _volume)
	cfg.save(SETTINGS)


## The player lives under the scene tree's root, so it outlives scenes and keeps speaking while the game is paused.
## No sound device (headless tests and tools): no player, so nothing is left playing.
static func _ensure_player() -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or AudioServer.get_driver_name() == "Dummy":
		return null
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	_apply_volume()
	_player = AudioStreamPlayer.new()
	_player.name = "VoiceOver"
	_player.bus = BUS
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_player)
	return _player


static func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume(), 0.0001)))
