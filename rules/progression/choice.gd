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
## How many earlier picks one such chance may swap; -1 means any number (a Cleric's list after a Long Rest).
var replace_max: int = -1
## Choices that share one swap between them name the same group, also how the player reads them ("Mystic Arcanum":
## one arcanum spell per Warlock level across all four).
var replace_group: String = ""
## False for a pick only a rest changes, which character creation leaves at its `default` (a High Elf's
## Prestidigitation).
var at_creation := true
## Set while a swap chance is open (ChoiceOptions.open_swap): the picks it started from, and how many of them may
## still go (-1 any). Empty `swap_from` means no chance is open and the picks are free (character creation).
var swap_from: Array[String] = []
var swap_max: int = -1
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


# --- Repeatable options (2024 Eldritch Invocations: Agonizing Blast, Lessons of the First Ones) --------------------
# A later copy of a repeatable inline option is picked as "<id>#2", "<id>#3"; its own choice is keyed after it
# ("warlock.1.eldritch_invocations/agonizing_blast#2"), so each copy picks its own cantrip or feat.

## The option a pick, or the choice key of a copy, repeats: "agonizing_blast#2" -> "agonizing_blast"; anything else
## is returned as it is.
static func repeat_base(s: String) -> String:
	var cut := s.rfind("#")
	if cut < 0 or not s.substr(cut + 1).is_valid_int():
		return s
	return s.substr(0, cut)


## Which copy a pick or a copy's choice key is: 1 for the option itself, n for "<id>#n".
static func copy_number(s: String) -> int:
	var base := repeat_base(s)
	return 1 if base == s else int(s.substr(base.length() + 1))


## How a copy reads: "Agonizing Blast (2nd)".
static func copy_label(name_: String, n: int) -> String:
	if n <= 1:
		return name_
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th") as String
	return "%s (%d%s)" % [name_, n, suffix]
