class_name Choice
extends RefCounted
## One decision a character build involves: "pick 2 skills", "pick a Fighting Style", "+2/+1 to your
## background's abilities". Character.refresh() lists every choice with its current picks; ChoiceOptions
## fills `options` with what's allowed and why not; the UI picks a widget by `kind` (plan §5.6), so a new
## feat or subclass needs data, never new UI code.

## Unique, stable id inside the build: "fighter.1.fighting_style", "background.abilities",
## "fighter.4.ability_score_improvement/alert.abilities", "wizard.spellbook".
var key: String
var kind: String
var count: int = 1
var label: String = ""
## Where it comes from, as the player reads it: "Fighter 1", "Background: Sage", "Species: Elf".
var source: String = ""
var source_kind: String = ""
## Explicit pool of ids; empty means every id of the kind that passes `filter`.
var from: Array[String] = []
var filter: Dictionary = {}
## kind option / maneuver: the options as feature dictionaries.
var inline_options: Array[Dictionary] = []
## ability_increase: most points one ability can take, and the score cap.
var per_ability: int = 1
var max_score: int = 20
## When earlier picks can be swapped: long_rest, level_up, never.
var replaceable: String = ""
## Spell choices: the class whose list and spellcasting ability apply.
var class_id: String = ""
## Character level at which this choice first appeared.
var level: int = 0
var picks: Array[String] = []
## Filled by ChoiceOptions.populate().
var options: Array[ChoiceOption] = []


func remaining() -> int:
	return count - picks.size()


func is_complete() -> bool:
	return picks.size() == count


func option(option_id: String) -> ChoiceOption:
	for o in options:
		if o.id == option_id:
			return o
	return null


func to_dict() -> Dictionary:
	var opts: Array = []
	for o in options:
		opts.append(o.to_dict())
	return {"key": key, "kind": kind, "count": count, "label": label, "source": source, "picks": picks.duplicate(),
		"options": opts}


func describe() -> String:
	return "%s (%s): %d of %d chosen" % [label, source, picks.size(), count]
