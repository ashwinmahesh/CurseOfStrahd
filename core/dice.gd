extends Node
## Autoload wrapper around the game's single DiceRoller. Game code calls Dice.roller; the rules
## engine takes a DiceRoller argument so tests can pass their own seeded one.

var roller := DiceRoller.new(int(Time.get_unix_time_from_system()))


func _ready() -> void:
	roller.rolled.connect(func(entry: Dictionary) -> void: EventBus.roll_made.emit(entry))


func reseed(seed_value: int) -> void:
	roller.reseed(seed_value)
