extends Node
## Autoload wrapper around the game's single DiceRoller. Game code calls Dice.roller; the rules
## engine takes a DiceRoller argument so tests can pass their own seeded one.

var roller := DiceRoller.new(fresh_seed())


func _ready() -> void:
	roller.rolled.connect(func(entry: Dictionary) -> void: EventBus.roll_made.emit(entry))


func reseed(seed_value: int) -> void:
	roller.reseed(seed_value)


## A seed nobody can predict (owner decision 2026-10-07: every new game and every load rolls fresh dice, so reloading
## never replays the same rolls). Tests seed with fixed numbers instead.
static func fresh_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return int(r.randi()) ^ int(Time.get_ticks_usec())


## Tests set this (tests/test_runner.gd): a "fresh" seed is then derived from the current one, so a run that loads a
## save still rolls new dice but the same ones every time it runs.
var deterministic := false
var _reseeds := 0


func reseed_random() -> void:
	if deterministic:
		_reseeds += 1
		roller.reseed(hash("%d:%d" % [roller.get_seed(), _reseeds]))
		return
	roller.reseed(fresh_seed())
