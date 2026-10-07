class_name GameSettings
extends RefCounted
## The player's own settings, kept in user://settings.cfg beside the volumes and never in a save (docs/plans/ui_polish.md):
## the window, how fast fights play, how long the Narrator's box stays up, and the world's look (read through Look.style).

## Tests point this at a file of their own run (tests/test_runner.gd), so they never change the player's.
static var path := "user://settings.cfg":
	set(v):
		path = v
		_loaded = false
		_cache = {}
const SECTION := "game"
## How much faster the fast combat speed plays moves and the pauses between them.
const FAST_PACE := 0.5


## Read once and kept (a fight asks for its pace on every step).
static var _cache: Dictionary = {}
static var _loaded := false


static func value(key: String, default: Variant) -> Variant:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK and cfg.has_section(SECTION):
			for k in cfg.get_section_keys(SECTION):
				_cache[k] = cfg.get_value(SECTION, k)
	return _cache.get(key, default)


## `save` false changes it for this run only (captures).
static func set_value(key: String, v: Variant, save: bool = true) -> void:
	value(key, null)
	_cache[key] = v
	if not save:
		return
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(SECTION, key, v)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	cfg.save(path)


static func fullscreen() -> bool:
	return bool(value("fullscreen", false))


static func set_fullscreen(on: bool) -> void:
	set_value("fullscreen", on)
	apply_display()


## Puts the window in the mode the player picked (the title screen calls it once at start).
static func apply_display() -> void:
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


static func fast_combat() -> bool:
	return bool(value("fast_combat", false))


static func set_fast_combat(on: bool) -> void:
	set_value("fast_combat", on)


## Seconds in a fight's moves and pauses are multiplied by this.
static func combat_pace() -> float:
	return FAST_PACE if fast_combat() else 1.0


## Whether the Narrator's box stays up until it's closed instead of fading on its own.
static func narration_stays() -> bool:
	return bool(value("narration_stays", false))


static func set_narration_stays(on: bool) -> void:
	set_value("narration_stays", on)


## The Modern look's depth of field (on by default; it only ever softens the far distance).
static func depth_blur() -> bool:
	return bool(value("depth_blur", true))


static func set_depth_blur(on: bool) -> void:
	set_value("depth_blur", on)
