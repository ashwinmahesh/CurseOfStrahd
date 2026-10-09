class_name LightFlicker
extends Node
## A flame's light wavering in the Modern finish, and with it everything the light reaches: the floors, walls and
## figures it lights, the light they bounce on (SSIL works from the lit frame), the haze it lights and its glow in the
## screen pass (the owner's ask, 2026-10-09: fires, candles and lamps flicker, and the light and the way characters
## are lit flicker with them). Atmosphere gives each light of a flickering kind one of these as a child (give()); it
## sets the light's energy and colour every frame, and moves it a little while Atmosphere lets it sway.
##
## The waver is three layers of smooth noise, a slow swell, a flutter and a fast shiver, each starting from its own
## random point so no two lights in a room pulse together, and now and then a gutter: a quick dip, as if a draught
## caught the flame, that reddens the light as it dims. Only the energy and colour change, never the range: Godot
## redraws a light's shadow map when its range changes, not its energy. A CandleFlicker it drives stops its own even
## jitter (which the Classic finish keeps). Its own RNG, not Dice: cosmetic, it must not shift game rolls.

## By kind of light (Atmosphere.LIGHT_KINDS): how far the `swell`, `flutter` and `shiver` move the energy (a share of
## it), how fast they run (`pace`, 1 a candle's), how many gutters a minute and how deep they go (`dip`), how far a
## dimmed flame's colour falls toward red (`redden`) and how far its light drifts while it sways (`sway`, world units).
## Hearths and braziers flicker hardest, torches nearly as hard, candles gently, lamps, lanterns and lit windows barely.
const STYLES := {
	"fire": {"swell": 0.35, "flutter": 0.2, "shiver": 0.08, "pace": 1.1, "gutters": 12.0, "dip": 0.4,
		"redden": 0.6, "sway": 0.15},
	"torch": {"swell": 0.28, "flutter": 0.18, "shiver": 0.07, "pace": 1.3, "gutters": 10.0, "dip": 0.35,
		"redden": 0.5, "sway": 0.1},
	"candle": {"swell": 0.15, "flutter": 0.1, "shiver": 0.04, "pace": 1.0, "gutters": 5.0, "dip": 0.25,
		"redden": 0.3, "sway": 0.04},
	"lamp": {"swell": 0.06, "flutter": 0.03, "shiver": 0.0, "pace": 0.6, "gutters": 1.0, "dip": 0.12, "redden": 0.15,
		"sway": 0.02},
	"lantern": {"swell": 0.08, "flutter": 0.04, "shiver": 0.0, "pace": 0.7, "gutters": 1.5, "dip": 0.15,
		"redden": 0.2, "sway": 0.0},
	"lit_window": {"swell": 0.08, "flutter": 0.03, "shiver": 0.0, "pace": 0.6, "gutters": 1.0, "dip": 0.12,
		"redden": 0.1, "sway": 0.0},
}
## How many times a second each layer (swell, flutter, shiver) turns, at pace 1.
const RATES: Array[float] = [0.5, 2.2, 8.0]
## How fast a light eases to a new `boost` (a share of the boost a second).
const BOOST_EASE := 0.4

## A further gain on the light's energy that Atmosphere sets (an outdoor fire after dark); eased to, not jumped.
var boost := 1.0

var _light: OmniLight3D = null
var _rng := RandomNumberGenerator.new()
var _swell := 0.0
var _flutter := 0.0
var _shiver := 0.0
var _pace := 1.0
var _gutters := 0.0
var _dip_most := 0.0
var _redden := 0.0
var _sway := 0.0
# Each layer's last and next value and how far between them it is.
var _from := PackedFloat32Array([0.0, 0.0, 0.0])
var _to := PackedFloat32Array([0.0, 0.0, 0.0])
var _at := PackedFloat32Array([0.0, 0.0, 0.0])
var _dip := 0.0
var _gutter := 0.0
var _gutter_left := 0.0
var _boost := 1.0
# A plain light's own energy and every light's own colour, and what was last written: a change made by anything else
# (a light dimmed, a window taking the moon's colour) becomes the new base. A CandleFlicker's energy is its base_energy.
var _energy := 0.0
var _colour := Color.WHITE
var _wrote_energy := -1.0
var _wrote_colour := Color(-1, -1, -1)
var _offset := Vector3.ZERO
var _shown := false


## Gives `l` the flicker of its `kind` (nothing for a kind not in STYLES), with `boost` on its energy.
static func give(l: OmniLight3D, kind: String, boost_by: float = 1.0) -> void:
	if not STYLES.has(kind):
		return
	var f := l.get_node_or_null(^"Flicker") as LightFlicker
	if f == null:
		f = LightFlicker.new()
		f.name = "Flicker"
		f.boost = boost_by
		f._boost = boost_by
		l.add_child(f)
	f.set_style(STYLES[kind] as Dictionary)
	f.set_boost(boost_by)


## Eases to a new `boost`, or takes it at once (`jump`: as a place opens).
func set_boost(b: float, jump: bool = false) -> void:
	boost = b
	if jump:
		_boost = b


## The flicker driving `l`, or null.
static func of(l: Node) -> LightFlicker:
	return l.get_node_or_null(^"Flicker") as LightFlicker


func set_style(s: Dictionary) -> void:
	_swell = float(s["swell"])
	_flutter = float(s["flutter"])
	_shiver = float(s["shiver"])
	_pace = float(s["pace"])
	_gutters = float(s["gutters"])
	_dip_most = float(s["dip"])
	_redden = float(s["redden"])
	_sway = float(s["sway"])


func _init() -> void:
	_rng.randomize()
	_start()


## Starts the waver over from seed `n` instead of at random, so it runs the same every time (tests).
func set_seed(n: int) -> void:
	_rng.seed = n
	_dip = 0.0
	_gutter_left = 0.0
	_start()


func _start() -> void:
	for i in 3:
		_from[i] = _rng.randf_range(-1.0, 1.0)
		_to[i] = _rng.randf_range(-1.0, 1.0)
		_at[i] = _rng.randf()


func _enter_tree() -> void:
	_light = get_parent() as OmniLight3D
	if _light is CandleFlicker:
		_light.set_process(false)


func _exit_tree() -> void:
	if is_instance_valid(_light) and _light is CandleFlicker:
		_light.set_process(true)


func _process(delta: float) -> void:
	if _light == null:
		return
	if not _light.is_visible_in_tree():
		# Hidden, a plain light goes back to its own energy, so what shows it again (HiddenAreas fades it in to the
		# energy it finds) brings back that and not one moment of its flicker.
		if _shown and not (_light is CandleFlicker):
			_light.light_energy = _energy
			_wrote_energy = _light.light_energy
		_shown = false
		return
	_shown = true
	var level := step(delta)
	if not is_equal_approx(_boost, boost):
		_boost = move_toward(_boost, boost, delta * BOOST_EASE * maxf(boost, _boost))
	if _light is CandleFlicker:
		_energy = (_light as CandleFlicker).base_energy
	elif not is_equal_approx(_light.light_energy, _wrote_energy):
		_energy = _light.light_energy
	_wrote_energy = _energy * _boost * level
	_light.light_energy = _wrote_energy
	if _light.light_color != _wrote_colour:
		_colour = _light.light_color
	# Dimmer is redder: a dipping flame loses its yellow first.
	var warm := _redden * clampf((1.0 - level) * 2.5, 0.0, 1.0)
	_wrote_colour = Color(_colour.r, _colour.g * (1.0 - 0.3 * warm), _colour.b * (1.0 - 0.6 * warm), _colour.a)
	_light.light_color = _wrote_colour
	_move(delta)


## Moves the waver on by `delta` seconds and returns the light's energy as a share of its own.
func step(delta: float) -> float:
	for i in 3:
		var at := _at[i] + delta * RATES[i] * _pace
		if at >= 1.0:
			at = fmod(at, 1.0)
			_from[i] = _to[i]
			_to[i] = _rng.randf_range(-1.0, 1.0)
		_at[i] = at
	var level := 1.0 + _swell * _value(0) + _flutter * _value(1) + _shiver * _value(2)
	# A gutter drops fast and comes back slower.
	if _gutter_left > 0.0:
		_gutter_left -= delta
	elif _rng.randf() < delta * _gutters / 60.0:
		_gutter = _dip_most * _rng.randf_range(0.5, 1.0)
		_gutter_left = _rng.randf_range(0.08, 0.3)
	var want := _gutter if _gutter_left > 0.0 else 0.0
	_dip = move_toward(_dip, want, delta * (6.0 if want > _dip else 1.5))
	return maxf(0.25, level - _dip)


## Layer `i` now, between -1 and 1.
func _value(i: int) -> float:
	var t := _at[i]
	return lerpf(_from[i], _to[i], t * t * (3.0 - 2.0 * t))


## While Atmosphere lets it (meta "sway": a light casting no shadow, or one of the nearest few that do), the light
## drifts with its flame, so the pool it throws and the shadows it casts stir; otherwise it comes back to rest.
func _move(delta: float) -> void:
	var want := Vector3.ZERO
	if _sway > 0.0 and bool(_light.get_meta("sway", false)):
		want = Vector3(_value(1), _value(2) * 0.5, _value(0)) * _sway
	if want == Vector3.ZERO and _offset == Vector3.ZERO:
		return
	var next := _offset.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
	if want == Vector3.ZERO and next.length() < 0.001:
		next = Vector3.ZERO
	_light.position += next - _offset
	_offset = next
