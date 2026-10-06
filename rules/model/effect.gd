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
## The Concentration keeping this effect alive, held weakly (Concentration already holds the effect).
var concentration: Concentration:
	get:
		return _concentration.get_ref() as Concentration if _concentration != null else null
	set(value):
		_concentration = weakref(value) if value != null else null
var _concentration: WeakRef = null
## Effects with the same key don't stack (2024 "Combining Game Effects"): only the most potent applies,
## and between equals the most recent. Defaults to source_kind:source_id.
var stack_key: String = ""
var order: int = 0
## Ends the moment the creature takes damage (Turn Undead, Sleep's unconsciousness).
var ends_on_damage: bool = false
## Ends if the creature becomes Incapacitated (Dodge).
var ends_when_incapacitated: bool = false
## A save the creature repeats to end this effect: {ability, dc, when: "end"|"start", on_damage: bool,
## damage_advantage: bool, then: ...}. `when` defaults to the end of each of its turns.
var repeat_save: Dictionary = {}
## Turn ends of the owner to let pass before END_OF_TURN expires: 1 when the effect starts during the owner's own
## turn, so "until the end of your next turn" doesn't end with the current one.
var skip_turn_ends: int = 0
## Ends after the creature's next D20 Test with one of these keys (Mind Sliver: "save:all"; True Strike-like
## "attack" buffs). Empty = not consumed.
var consume_on: Array[String] = []
## Ends after the next attack roll made against the creature (Guiding Bolt's Advantage).
var consume_when_attacked: bool = false
## Things the creature does that end this effect: attack_roll, deal_damage, cast_spell (Invisibility).
var ends_on: Array[String] = []
## An action the creature can take to end it with an ability check: {skill, dc} (Web, Entangle).
var escape: Dictionary = {}
## Level of the spell that made it (Dispel Magic), 0 for cantrips and non-spells.
var spell_level: int = 0
## Counters and links bespoke rules keep on the effect (Mirror Image's duplicates, Warding Bond's caster).
var data: Dictionary = {}
## Called once when the effect is removed for any reason (Haste's lethargy).
var on_end: Callable = Callable()


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
	if ends != Ends.END_OF_TURN or creature_id != _owner():
		return false
	if skip_turn_ends > 0:
		skip_turn_ends -= 1
		return false
	return true


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


## For saves: everything about the effect, with its Concentration named by caster and source (relinked on load).
func to_dict() -> Dictionary:
	var mods: Array = []
	for m in modifiers:
		mods.append({"data": m.data.duplicate(true), "name": m.source_name, "kind": str(m.source_kind), "id": m.source_id, "class_id": m.class_id})
	var conds: Array = []
	for c in conditions:
		conds.append(str(c))
	var conc := concentration
	return {"name": name, "source_kind": str(source_kind), "source_id": source_id, "caster_id": caster_id, "modifiers": mods,
		"conditions": conds, "ends": int(ends), "rounds_left": rounds_left, "minutes_left": minutes_left,
		"turn_owner_id": turn_owner_id, "stack_key": stack_key, "ends_on_damage": ends_on_damage,
		"ends_when_incapacitated": ends_when_incapacitated, "repeat_save": repeat_save.duplicate(true),
		"skip_turn_ends": skip_turn_ends, "consume_on": consume_on.duplicate(), "consume_when_attacked": consume_when_attacked,
		"ends_on": ends_on.duplicate(), "escape": escape.duplicate(), "spell_level": spell_level, "data": data.duplicate(true),
		"concentration": {"caster": conc.caster().id if conc != null and conc.caster() != null else "", "source": conc.source_id if conc != null else ""}}


static func from_dict(d: Dictionary) -> Effect:
	var e := Effect.new(str(d.get("name", "")), StringName(str(d.get("source_kind", "effect"))), str(d.get("source_id", "")))
	e.caster_id = str(d.get("caster_id", ""))
	for md: Variant in d.get("modifiers", []):
		var m := md as Dictionary
		e.modifiers.append(Modifier.make((m["data"] as Dictionary).duplicate(true), str(m.get("name", e.name)),
			StringName(str(m.get("kind", "effect"))), str(m.get("id", "")), str(m.get("class_id", ""))))
	for c: Variant in d.get("conditions", []):
		e.conditions.append(StringName(str(c)))
	e.ends = int(d.get("ends", 0)) as Ends
	e.rounds_left = int(d.get("rounds_left", 0))
	e.minutes_left = int(d.get("minutes_left", 0))
	e.turn_owner_id = str(d.get("turn_owner_id", ""))
	e.stack_key = str(d.get("stack_key", ""))
	e.ends_on_damage = bool(d.get("ends_on_damage", false))
	e.ends_when_incapacitated = bool(d.get("ends_when_incapacitated", false))
	e.repeat_save = (d.get("repeat_save", {}) as Dictionary).duplicate(true)
	e.skip_turn_ends = int(d.get("skip_turn_ends", 0))
	for k: Variant in d.get("consume_on", []):
		e.consume_on.append(str(k))
	e.consume_when_attacked = bool(d.get("consume_when_attacked", false))
	for k2: Variant in d.get("ends_on", []):
		e.ends_on.append(str(k2))
	e.escape = (d.get("escape", {}) as Dictionary).duplicate()
	e.spell_level = int(d.get("spell_level", 0))
	e.data = (d.get("data", {}) as Dictionary).duplicate(true)
	return e


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
