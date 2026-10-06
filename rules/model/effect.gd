class_name Effect
extends RefCounted
## Something that changes a creature for a while (plan §4.3, ADR 0003): a spell, a condition someone
## imposed, an item's activated power or a feature like Second Wind's movement. It carries modifiers and/or
## conditions, its source and a duration. Effects live on the creature they affect; a caster's Concentration
## links the effects it keeps alive.

enum Ends {
	NEVER,          ## until removed (or dispelled)
	ROUNDS,         ## counts down at the start of the turn owner's turn; ends at 0
	START_OF_TURN,  ## ends at the start of the turn owner's next turn ("until the start of your next turn")
	END_OF_TURN,    ## ends at the end of the turn owner's next turn ("until the end of your next turn")
	MINUTES,        ## time-based (exploration); 1 round = 6 seconds, so 10 rounds a minute in combat
	SHORT_REST,     ## ends when the creature finishes a Short or Long Rest
	LONG_REST,      ## ends when the creature finishes a Long Rest
}

const ROUNDS_PER_MINUTE := 10

static var _next_id: int = 1

var id: int
var name: String
var source_kind: StringName = &"spell"
var source_id: String = ""
var caster_id: String = ""
var modifiers: Array[Modifier] = []
var conditions: Array[StringName] = []
var ends: Ends = Ends.NEVER
var rounds_left: int = 0
var minutes_left: int = 0
## Whose turn start/end the duration counts on. Defaults to the caster.
var turn_owner_id: String = ""
var concentration: Concentration = null
## Effects with the same key don't stack (2024 "Combining Game Effects"): only the most potent applies,
## and between equals the most recent. Defaults to source_kind:source_id.
var stack_key: String = ""
var order: int = 0


func _init(name_: String = "", source_kind_: StringName = &"spell", source_id_: String = "") -> void:
	id = _next_id
	_next_id += 1
	order = id
	name = name_
	source_kind = source_kind_
	source_id = source_id_


func key() -> String:
	return stack_key if stack_key != "" else "%s:%s" % [source_kind, source_id if source_id != "" else name]


func with_modifier(stat: String, fields: Dictionary) -> Effect:
	var m := Modifier.of(stat, fields, name, source_kind)
	m.source_id = source_id
	modifiers.append(m)
	return self


func with_condition(condition: StringName) -> Effect:
	conditions.append(condition)
	return self


func lasting_rounds(rounds: int, owner_id: String = "") -> Effect:
	ends = Ends.ROUNDS
	rounds_left = rounds
	if owner_id != "":
		turn_owner_id = owner_id
	return self


## Sets the duration from a spell's duration block ({kind, amount, concentration}).
func lasting(duration: Dictionary) -> Effect:
	var amount := int(duration.get("amount", 1))
	match str(duration.get("kind", "instantaneous")):
		"rounds":
			ends = Ends.ROUNDS
			rounds_left = amount
		"minutes":
			ends = Ends.ROUNDS
			rounds_left = amount * ROUNDS_PER_MINUTE
			minutes_left = amount
		"hours":
			ends = Ends.MINUTES
			minutes_left = amount * 60
		"days":
			ends = Ends.MINUTES
			minutes_left = amount * 24 * 60
		_:
			ends = Ends.NEVER
	return self


## Rough strength for "most potent wins": sum of numeric modifier values, conditions count heavily.
func potency() -> int:
	var p := conditions.size() * 100
	for m in modifiers:
		var v: Variant = m.data.get("value", 0)
		if v is int or v is float:
			p += absi(int(v))
		elif m.data.has("dice"):
			p += 3
		else:
			p += 1
	return p


func _owner() -> String:
	return turn_owner_id if turn_owner_id != "" else caster_id


## Called when `creature_id`'s turn starts. Returns true when this effect has expired.
func on_turn_start(creature_id: String) -> bool:
	if creature_id != _owner():
		return false
	match ends:
		Ends.START_OF_TURN:
			return true
		Ends.ROUNDS:
			rounds_left -= 1
			return rounds_left <= 0
	return false


## Called when `creature_id`'s turn ends. Returns true when this effect has expired.
func on_turn_end(creature_id: String) -> bool:
	return ends == Ends.END_OF_TURN and creature_id == _owner()


## Exploration time passing. Returns true when expired.
func advance_minutes(minutes: int) -> bool:
	match ends:
		Ends.MINUTES:
			minutes_left -= minutes
			return minutes_left <= 0
		Ends.ROUNDS:
			rounds_left -= minutes * ROUNDS_PER_MINUTE
			return rounds_left <= 0
	return false


func describe_duration() -> String:
	match ends:
		Ends.ROUNDS:
			return "%d round%s" % [rounds_left, "" if rounds_left == 1 else "s"]
		Ends.START_OF_TURN:
			return "until the start of the next turn"
		Ends.END_OF_TURN:
			return "until the end of the next turn"
		Ends.MINUTES:
			return "%d min" % minutes_left
		Ends.SHORT_REST:
			return "until a rest"
		Ends.LONG_REST:
			return "until a Long Rest"
	return "until removed"
