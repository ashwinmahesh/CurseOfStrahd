class_name GameSettings
extends RefCounted
## The player's own settings, kept in user://settings.cfg beside the volumes and never in a save (docs/plans/ui_polish.md):
## the window, how fast fights play, how long the Narrator's box stays up, the world's look (read through Look.style),
## the interface and text sizes, and the keys (InputActions).

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


## The Modern look's depth blur (on by default): the world softens toward the screen's edges, most in the corners.
static func depth_blur() -> bool:
	return bool(value("depth_blur", true))


static func set_depth_blur(on: bool) -> void:
	set_value("depth_blur", on)


## How far in from the edges the depth blur reaches: an Atmosphere.EDGE_BLURS id, or "" for the look's default.
static func blur_reach() -> String:
	return str(value("blur_reach", ""))


static func set_blur_reach(id: String) -> void:
	set_value("blur_reach", id)


## Whether exploring runs in rounds, one party member at a time (turn-based mode, F7: LocationPlan). Off by default;
## T, the hotbar's Turn-based button and the Settings page all switch it.
static func turn_based() -> bool:
	return bool(value("turn_based", false))


static func set_turn_based(on: bool) -> void:
	set_value("turn_based", on)


## How big the interface draws while playing (Settings, Interface: U4): the HUD, conversations, the Narrator's box and
## rules cards. Menus and other full screens stay at 1.0 (UiScale).
const UI_SCALES: Array[float] = [0.85, 1.0, 1.1, 1.2]
## How big the reading text is (Settings, Text: U4): conversations, the Narrator's box and the journal (UiScale.text).
const TEXT_SCALES: Array[float] = [1.0, 1.15, 1.3]


static func ui_scale() -> float:
	return _nearest(float(value("ui_scale", 1.0)), UI_SCALES)


## The window takes it at once through UiScale.apply().
static func set_ui_scale(v: float) -> void:
	set_value("ui_scale", v)


static func text_scale() -> float:
	return _nearest(float(value("text_scale", 1.0)), TEXT_SCALES)


static func set_text_scale(v: float) -> void:
	set_value("text_scale", v)


## A hand-edited or older settings file can hold any number: the closest choice the page offers.
static func _nearest(v: float, choices: Array[float]) -> float:
	var best := choices[0]
	for c in choices:
		if absf(c - v) < absf(best - v):
			best = c
	return best
