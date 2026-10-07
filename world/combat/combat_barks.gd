class_name CombatBarks
extends Node
## What enemies say and the noises creatures make in a fight (narrative/combat/barks.json; the clips are made by
## make voice, ADR 0013): a battle cry the first time a kind of enemy acts, a taunt or a snarl when its blow lands, a
## cry under a heavy blow, its last words or its death noise. The combat view owns one and tells it what happened; it
## only plays sounds. One plays at a time, never over the Narrator, with a pause between them, and only some blows get
## one, so a fight doesn't turn into a choir. A line or noise with no clip is silent.

const DATA := "res://narrative/combat/barks.json"
const MOMENTS: Array[String] = ["battle", "strike", "hurt", "death"]
## How likely each moment is to be heard, when nothing else is playing.
const CHANCE := {"battle": 1.0, "strike": 0.35, "hurt": 0.5, "death": 1.0}
## The quiet after one before the next, in seconds.
const GAP := 2.5

static var _data: Dictionary = {}
static var _by_monster: Dictionary = {}   # monster id -> {"speaker", "takes": {moment: [text]}}

var rng := RandomNumberGenerator.new()   # cosmetic: which take, and whether this blow gets one
var _player: AudioStreamPlayer
var _quiet_until := 0
var _cried: Dictionary = {}   # speakers that gave their battle cry this fight


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary
		for section: String in ["voices", "noises"]:
			for kind: String in _data.get(section, {}) as Dictionary:
				var v := (_data[section] as Dictionary)[kind] as Dictionary
				var takes := {}
				if section == "voices":
					takes = v.get("lines", {}) as Dictionary
				else:
					for moment: String in v.get("sounds", {}) as Dictionary:
						takes[moment] = ((v["sounds"] as Dictionary)[moment] as Array).map(func(s: Variant) -> String: return str((s as Dictionary)["prompt"]))
				var who := {"speaker": ("bark_" if section == "voices" else "noise_") + kind, "takes": takes}
				for m: Variant in v.get("monsters", []) as Array:
					_by_monster[str(m)] = who
	return _data


## The speaker a monster barks as ("bark_bandit", "noise_wolf"), or "" for one that stays quiet.
static func speaker_for(monster_id: String) -> String:
	data()
	return str((_by_monster.get(monster_id, {}) as Dictionary).get("speaker", ""))


## Whether `speaker` is one of the fight voices or noises (bark_<kind>, noise_<kind>).
static func is_speaker(speaker: String) -> bool:
	data()
	return _by_monster.values().any(func(w: Variant) -> bool: return str((w as Dictionary)["speaker"]) == speaker)


## A monster's lines (or noise prompts) for one moment.
static func takes_for(monster_id: String, moment: String) -> Array[String]:
	data()
	var out: Array[String] = []
	for t: Variant in ((_by_monster.get(monster_id, {}) as Dictionary).get("takes", {}) as Dictionary).get(moment, []) as Array:
		out.append(str(t))
	return out


static func monster_id(c: Combatant) -> String:
	if c == null or not c.creature is Monster:
		return ""
	return str((c.creature as Monster).data.get("id", ""))


func _init() -> void:
	name = "CombatBarks"
	rng.randomize()


func _ready() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		return
	if AudioServer.get_bus_index(VoiceOver.BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, VoiceOver.BUS)
	_player = AudioStreamPlayer.new()
	_player.bus = VoiceOver.BUS
	add_child(_player)


## `c` reached `moment` (battle, strike, hurt, death): plays one of its kind's takes when the rules above allow.
## Returns the line or prompt it played ("" for none).
func bark(c: Combatant, moment: String) -> String:
	var take := pick(c, moment, Time.get_ticks_msec())
	if take == "" or _player == null:
		return take
	var stream := load(VoiceOver.clip_path(speaker_for(monster_id(c)), take)) as AudioStream
	if stream != null:
		_player.stream = stream
		_player.volume_db = 0.0
		_player.play()
	return take


## Which take `c` would play for `moment` at `now_ms`, also noting it as played; "" when it stays quiet.
func pick(c: Combatant, moment: String, now_ms: int) -> String:
	if c == null or c.side in [&"party", &"guest"]:
		return ""
	var speaker := speaker_for(monster_id(c))
	if speaker == "" or now_ms < _quiet_until or VoiceOver.is_speaking() or (_player != null and _player.playing):
		return ""
	if moment == "battle" and _cried.has(speaker):
		return ""
	if rng.randf() >= float(CHANCE.get(moment, 0.0)):
		return ""
	var voiced: Array[String] = []
	for t in takes_for(monster_id(c), moment):
		if VoiceOver.has_clip(speaker, t):
			voiced.append(t)
	if voiced.is_empty():
		return ""
	if moment == "battle":
		_cried[speaker] = true
	var take := voiced[rng.randi_range(0, voiced.size() - 1)]
	var length := 1.5
	var stream := load(VoiceOver.clip_path(speaker, take)) as AudioStream
	if stream != null:
		length = stream.get_length()
	_quiet_until = now_ms + int((length + GAP) * 1000.0)
	return take


## The Narrator is about to speak: whatever is barking fades out under it.
func hush() -> void:
	if _player == null or not _player.playing:
		return
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", -40.0, 0.25)
	tw.tween_callback(func() -> void:
		_player.stop()
		_player.volume_db = 0.0)


## A new fight: every kind may give its battle cry again.
func reset() -> void:
	_cried.clear()
	_quiet_until = 0
