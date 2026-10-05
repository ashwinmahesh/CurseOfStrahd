class_name DiceRoller
extends RefCounted
## The one source of randomness (plan §4, ADR 0002). Every die roll goes through here and is logged,
## so a seed plus a state reproduces a fight exactly. Pure: no scene or autoload dependencies.

signal rolled(entry: Dictionary)

const MAX_LOG := 500

var log: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _seed: int = 0


func _init(seed_value: int = 0) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value
	log.clear()


func get_seed() -> int:
	return _seed


## Rolls `count` dice with `sides` faces. Returns each die.
func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
	assert(sides >= 1 and count >= 0)
	var results: Array[int] = []
	for i in count:
		results.append(_rng.randi_range(1, sides))
	_record({"reason": reason, "sides": sides, "rolls": results.duplicate()})
	return results


func roll_one(sides: int, reason: String = "") -> int:
	return roll(sides, 1, reason)[0]


func d20(reason: String = "") -> int:
	return roll_one(20, reason)


## Parses and rolls a dice expression like "2d6+3", "1d8", "d20-1" or "4". Returns
## {expr, rolls, modifier, total}.
func roll_expr(expr: String, reason: String = "") -> Dictionary:
	var parsed := parse_expr(expr)
	var rolls: Array[int] = []
	if int(parsed["count"]) > 0:
		rolls = roll(int(parsed["sides"]), int(parsed["count"]), reason if reason != "" else expr)
	var total: int = int(parsed["modifier"])
	for r in rolls:
		total += r
	return {"expr": expr, "rolls": rolls, "modifier": parsed["modifier"], "total": total}


## "2d6+3" -> {count: 2, sides: 6, modifier: 3}. A bare number is a flat value.
static func parse_expr(expr: String) -> Dictionary:
	var s := expr.replace(" ", "").to_lower()
	var re := RegEx.create_from_string("^(?:(\\d*)d(\\d+))?([+-]\\d+)?$|^(\\d+)$")
	var m := re.search(s)
	assert(m != null, "Bad dice expression: %s" % expr)
	if m.get_string(4) != "":
		return {"count": 0, "sides": 0, "modifier": int(m.get_string(4))}
	var count := 1 if m.get_string(1) == "" else int(m.get_string(1))
	return {"count": count, "sides": int(m.get_string(2)), "modifier": int(m.get_string(3))}


## Opaque RNG state for saving. Restoring it continues the exact same roll sequence.
func get_state() -> Dictionary:
	return {"seed": _seed, "state": _rng.state}


func set_state(data: Dictionary) -> void:
	_seed = int(data.get("seed", 0))
	_rng.seed = _seed
	_rng.state = int(data.get("state", _rng.state))


func _record(entry: Dictionary) -> void:
	log.append(entry)
	if log.size() > MAX_LOG:
		log.pop_front()
	rolled.emit(entry)
