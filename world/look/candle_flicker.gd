class_name CandleFlicker
extends OmniLight3D
## Uneven candle flicker. Uses its own RNG, not Dice: it is cosmetic and must not shift game rolls.
## In the Modern finish the flames nearest the party that cast shadows also sway a little with the flicker (meta
## "sway", set by Atmosphere within the graphics preset's budget), so the shadows they cast stir (Improvement Ideas W5).

@export var base_energy := 1.6
@export var flicker := 0.35
## How far (world units) a swaying flame's light drifts from where it stands.
@export var sway := 0.035

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _target := 1.0
var _drift := Vector3.ZERO
var _offset := Vector3.ZERO


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(0.05, 0.18)
		_target = 1.0 + _rng.randf_range(-flicker, flicker)
		_drift = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1.0, 1.0)) * sway
	light_energy = lerpf(light_energy, base_energy * _target, clampf(delta * 12.0, 0.0, 1.0))
	# Sway only while asked to; otherwise the light rests where it was put (nothing moves its shadow map).
	var want := _drift if flicker > 0.0 and bool(get_meta("sway", false)) else Vector3.ZERO
	if want.is_equal_approx(Vector3.ZERO) and _offset.is_equal_approx(Vector3.ZERO):
		return
	var next := _offset.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
	if want == Vector3.ZERO and next.length() < 0.001:
		next = Vector3.ZERO
	position += next - _offset
	_offset = next
