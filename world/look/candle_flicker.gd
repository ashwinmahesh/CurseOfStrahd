class_name CandleFlicker
extends OmniLight3D
## Uneven candle flicker. Uses its own RNG, not Dice: it is cosmetic and must not shift game rolls.

@export var base_energy := 1.6
@export var flicker := 0.35

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _target := 1.0


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(0.05, 0.18)
		_target = 1.0 + _rng.randf_range(-flicker, flicker)
	light_energy = lerpf(light_energy, base_energy * _target, clampf(delta * 12.0, 0.0, 1.0))
