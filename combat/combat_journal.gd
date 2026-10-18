class_name CombatJournal
extends RefCounted
## Write-ahead command ledger for mobile recovery. Replaying the original encounter recreates pending Callables
## through the real rules engine; closures and partially applied combat state are never deserialized.
## Dice states are decimal strings, because JSON numbers cannot represent every 64-bit RNG state exactly.

const VERSION := 1
var data: Dictionary = {}


static func begin(e: Encounter, round_base: Dictionary = {}) -> CombatJournal:
	var journal := CombatJournal.new()
	journal.data = {"version": VERSION, "base": encode(EncounterSnapshot.capture(e) if round_base.is_empty() else round_base),
		"phase": "setup" if round_base.is_empty() else "round", "dice": dice_state(e.dice), "commands": [],
		"counters": counters(), "effects": {}, "combatants": {},
		"options": {"shared_turns": e.shared_turns, "flanking": e.flanking, "allies_block": e.allies_block,
			"default_player_reaction": e.default_player_reaction, "peaceful": e.peaceful, "intro": e.intro}}
	for c in e.combatants:
		(journal.data["combatants"] as Dictionary)[c.id] = {"ai_profile": str(c.ai_profile), "facing": encode(c.facing)}
		var effects: Array = []
		for effect in c.creature.effects:
			effects.append([effect.id, effect.order])
		(journal.data["effects"] as Dictionary)[c.id] = effects
	return journal


static func dice_state(dice: DiceRoller) -> Dictionary:
	var state := dice.get_state()
	return {"seed": str(state["seed"]), "state": str(state["state"])}


func append(e: Encounter, kind: String, args: Dictionary = {}) -> void:
	(data["commands"] as Array).append({"kind": kind, "args": encode(args), "dice": dice_state(e.dice),
		"shared_turns": e.shared_turns, "flanking": e.flanking, "counters": counters()})


## The host writes data atomically BEFORE executing the appended command. If that write fails it must wait and
## retry, without executing or appending twice. Recovery executes each durable entry exactly once.
func restore(dice: DiceRoller, party: Array[Character] = []) -> Encounter:
	if not valid(data):
		return null
	var signals_blocked := dice.is_blocking_signals()
	dice.set_block_signals(true)
	dice.set_state(data["dice"] as Dictionary)
	var base := decode(data["base"], null) as Dictionary
	var e := EncounterSnapshot.restore(base, dice, party, false, true)
	for c in e.combatants:
		var properties := (data["combatants"] as Dictionary).get(c.id, {}) as Dictionary
		c.ai_profile = StringName(str(properties.get("ai_profile", str(c.ai_profile))))
		c.facing = decode(properties.get("facing", encode(c.facing)), e) as Vector2
		var effects := (data["effects"] as Dictionary).get(c.id, []) as Array
		for i in mini(effects.size(), c.creature.effects.size()):
			c.creature.effects[i].id = int(effects[i][0])
			c.creature.effects[i].order = int(effects[i][1])
	_set_counters(data["counters"] as Dictionary)
	for key: String in ["shared_turns", "flanking", "allies_block", "default_player_reaction", "peaceful", "intro"]:
		e.set(key, (data["options"] as Dictionary)[key])
	if str(data["phase"]) == "round":
		e._lair_then_begin()
	else:
		e.state = Encounter.State.SETUP
		e.turn_index = -1
		e.order.clear()
	for entry: Dictionary in data["commands"]:
		_set_counters(entry["counters"] as Dictionary)
		e.dice.set_state(entry["dice"] as Dictionary)
		e.shared_turns = bool(entry["shared_turns"])
		e.flanking = bool(entry["flanking"])
		apply(e, str(entry["kind"]), decode(entry["args"], e) as Dictionary)
		e.drain_events()   # recovery restores state, not a second showing of past animations
	dice.set_block_signals(signals_blocked)
	return e


static func apply(e: Encounter, kind: String, args: Dictionary) -> CombatResult:
	var c := e.get_c(str(args.get("actor", "")))
	match kind:
		"start":
			e.start(args.get("surprised", []) as Array)
			return CombatResult.new()
		"ai": return e.run_ai_turn()
		"end": return e.end_turn()
		"undo": return e.undo_move(c)
		"death": return e.death_save(c)
		"switch": return e.switch_to(c)
		"move": return e.move(c, args["cell"] as Vector2i)
		"reaction_move": return e.reaction_move(c, args["cell"] as Vector2i)
		"perform":
			return ActionCatalog.new(e).perform(c, args["action"] as Dictionary, args["targets"] as Array,
				args["point"] as Vector2, args["direction"] as Vector2, int(args["slot"]))
		"policy": return ActionCatalog.new(e).set_rule(c, args["action"] as Dictionary)
		"answer":
			if e.pending == null:
				return CombatResult.fail("No pending reaction to recover")
			var request := e.pending
			request.selected_ids.assign(args.get("selected", []) as Array)
			request.amounts = (args.get("amounts", {}) as Dictionary).duplicate()
			var reactor := e.get_c(request.reactor_id)
			if reactor != null and str(args["rule"]) != "ask":
				reactor.reaction_rules[request.kind] = str(args["rule"])
			return e.answer_reaction(bool(args["use"]))
	return CombatResult.fail("Unknown recovery command")


## Restricted value codec: references name combatants, never arbitrary objects or executable code.
static func encode(value: Variant) -> Variant:
	if value is Combatant:
		return {"$combatant": (value as Combatant).id}
	if value is Vector2i:
		return {"$cell": [value.x, value.y]}
	if value is Vector2:
		return {"$point": [str(value.x), str(value.y)]}
	if value is StringName:
		return str(value)
	if value is Array:
		var array: Array = []
		for item: Variant in value:
			array.append(encode(item))
		return array
	if value is Dictionary:
		var dict := {}
		for key: Variant in value:
			dict[str(key)] = encode(value[key])
		return dict
	assert(value == null or value is bool or value is int or value is float or value is String, "Unsupported recovery value")
	return value


static func decode(value: Variant, e: Encounter) -> Variant:
	if value is Array:
		var array: Array = []
		for item: Variant in value:
			array.append(decode(item, e))
		return array
	if value is Dictionary:
		var dict := value as Dictionary
		if dict.has("$combatant"):
			return e.get_c(str(dict["$combatant"])) if e != null else null
		if dict.has("$cell"):
			return Vector2i(int(dict["$cell"][0]), int(dict["$cell"][1]))
		if dict.has("$point"):
			return Vector2(_number(str(dict["$point"][0])), _number(str(dict["$point"][1])))
		var out := {}
		for key: String in dict:
			out[key] = decode(dict[key], e)
		return out
	return value


static func _number(value: String) -> float:
	return INF if value == "inf" else -INF if value == "-inf" else float(value)


func walk_plan(e: Encounter) -> Dictionary:
	var plan := {}
	for entry: Dictionary in data["commands"]:
		var kind := str(entry["kind"])
		var args := decode(entry["args"], e) as Dictionary
		if kind == "move":
			plan = (args.get("strike", {}) as Dictionary).duplicate()
		elif kind not in ["answer", "policy"]:
			plan = {}
	return plan


static func counters() -> Dictionary:
	return {"effect": Effect._next_id, "field": FieldObject._next_id}


static func _set_counters(saved: Dictionary) -> void:
	Effect._next_id = int(saved["effect"])
	FieldObject._next_id = int(saved["field"])


## Reject incompatible or malformed ledgers before constructing an encounter or changing the active campaign.
static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var d := value as Dictionary
	if not d.get("version") is int and not d.get("version") is float:
		return false
	if int(d.get("version", 0)) != VERSION or str(d.get("phase", "")) not in ["setup", "round"]:
		return false
	for key: String in ["base", "dice", "options", "effects", "combatants", "counters"]:
		if not d.get(key) is Dictionary:
			return false
	if not _valid_dice(d["dice"]) or not _valid_counters(d["counters"]):
		return false
	var options := d["options"] as Dictionary
	for key: String in ["shared_turns", "flanking", "allies_block", "peaceful"]:
		if not options.get(key) is bool:
			return false
	if not options.get("intro") is String or str(options.get("default_player_reaction", "")) not in ["ask", "auto", "never"]:
		return false
	var base := d["base"] as Dictionary
	if not base.get("rows") is Array or not base.get("combatants") is Array or not base.get("order") is Array or not base.has("round"):
		return false
	var rows := base["rows"] as Array
	if rows.is_empty() or rows.size() > 256 or (base["combatants"] as Array).size() > 256:
		return false
	for row: Variant in rows:
		if not row is String or (row as String).length() > 256:
			return false
	for c: Variant in base["combatants"]:
		if not c is Dictionary or not (c as Dictionary).get("id") is String or not (c as Dictionary).get("cell") is Array:
			return false
		for key: String in ["side", "group"]:
			if not c.get(key) is String:
				return false
		if not c.get("initiative") is int and not c.get("initiative") is float:
			return false
		if not c.get("surprised") is bool:
			return false
		if c.has("character") and not c["character"] is Dictionary or c.has("state") and not c["state"] is Dictionary:
			return false
		if (c["cell"] as Array).size() != 2 or not c.has("state") and not c.has("character"):
			return false
	if not d.get("commands") is Array or not _valid_values(d):
		return false
	for entry: Variant in d["commands"]:
		if not entry is Dictionary or not (entry as Dictionary).get("args") is Dictionary:
			return false
		if not _valid_dice(entry.get("dice")) or not _valid_counters(entry.get("counters")):
			return false
		if not entry.get("shared_turns") is bool or not entry.get("flanking") is bool:
			return false
		var kind := str(entry.get("kind", ""))
		var args := entry["args"] as Dictionary
		if kind not in ["start", "ai", "end", "undo", "death", "switch", "move", "reaction_move", "perform", "policy", "answer"]:
			return false
		if kind in ["undo", "death", "switch", "move", "reaction_move", "perform", "policy"] and not args.get("actor") is String:
			return false
		if kind in ["move", "reaction_move"] and (not args.get("cell") is Dictionary or not args["cell"].has("$cell")):
			return false
		if kind in ["perform", "policy"] and not args.get("action") is Dictionary:
			return false
		if kind == "perform" and (not args.get("targets") is Array or not args.get("point") is Dictionary or not args.get("direction") is Dictionary or not args.has("slot")):
			return false
		if kind == "answer" and (not args.get("use") is bool or not args.get("selected") is Array or not args.get("amounts") is Dictionary or str(args.get("rule", "")) not in ["ask", "auto", "never"]):
			return false
		if kind == "start" and not args.get("surprised") is Array:
			return false
	return true


static func _valid_dice(value: Variant) -> bool:
	return value is Dictionary and str(value.get("seed", "")).is_valid_int() and str(value.get("state", "")).is_valid_int()


static func _valid_counters(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: String in ["effect", "field"]:
		if not value.get(key) is float and not value.get(key) is int:
			return false
		if int(value[key]) < 1:
			return false
	return true


static func _valid_values(value: Variant, depth: int = 0) -> bool:
	if depth > 40:
		return false
	if value is Dictionary:
		var d := value as Dictionary
		for tag: String in ["$cell", "$point"]:
			if d.has(tag) and (not d[tag] is Array or (d[tag] as Array).size() != 2):
				return false
		if d.has("$combatant") and not d["$combatant"] is String:
			return false
		for v: Variant in d.values():
			if not _valid_values(v, depth + 1):
				return false
	elif value is Array:
		for v: Variant in value:
			if not _valid_values(v, depth + 1):
				return false
	return true
