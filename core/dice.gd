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


func reseed_random() -> void:
	roller.reseed(fresh_seed())
