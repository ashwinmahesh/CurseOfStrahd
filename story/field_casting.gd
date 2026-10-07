class_name FieldCasting
extends RefCounted
## Casting outside a fight (plan §5.2, "rest and recover between fights"): healing and helpful spells on the party,
## from the character sheet. It goes through the combat SpellCaster on a small peaceful board, so slots, free
## castings, Concentration and lasting effects behave exactly as they do in a fight. Spells that harm, push or
## summon wait for a fight.

const MAX_TARGETS := 8
## Spells that also work in a fight but are worth casting while exploring (their light lasts).
const EXPLORING_TOO: Array[String] = ["light", "dancing_lights", "continual_flame", "daylight"]


## What `caster` can cast right now outside combat: [{id, name, level, slots: Array[int], free, count, self_only,
## legal, reason}], helpful spells only.
static func options(party: Array[Character], caster: Character, dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := _board(party, caster, dice)
	var c := e.get_c(caster.id)
	if c == null:
		return out
	for s in e.spells.castable(c):
		var data := Compendium.shared().spell_data(str(s["id"]))
		if not helpful(data):
			continue
		var entry := {"id": str(s["id"]), "name": str(s["name"]), "level": int(s["level"]), "free": bool(s["free"]),
			"count": int((data.get("targets", {}) as Dictionary).get("count", 1)),
			"self_only": str((data.get("targets", {}) as Dictionary).get("kind", "")) == "self",
			"legal": bool(s["legal"]), "reason": str(s["reason"]).replace("in this fight", "outside a fight"),
			"slots": _slots(caster, int(s["level"]))}
		if bool(entry["legal"]) and int(s["level"]) > 0 and not bool(s["free"]) and (entry["slots"] as Array).is_empty():
			entry["legal"] = false
			entry["reason"] = "No spell slots left"
		if not c.can_act():
			entry["legal"] = false
			entry["reason"] = "%s can't act" % caster.name
		out.append(entry)
	return out


## Healing and help: spells that target creatures or the caster and neither deal damage, force a save, make an attack
## nor fill an area.
static func helpful(data: Dictionary) -> bool:
	for k: String in ["damage", "save", "attack", "area", "summon"]:
		if data.has(k):
			return false
	var kind := str((data.get("targets", {}) as Dictionary).get("kind", ""))
	return kind in ["creature", "self"] and (data.has("heal") or data.has("effects") or bool(data.get("field_utility", false)))


## Casts `spell_id` from `caster` at `slot` (0 = the lowest that works) on `targets`. Returns {ok, text, lines}.
static func cast(party: Array[Character], caster: Character, spell_id: String, slot: int, targets: Array[Character],
		dice: DiceRoller) -> Dictionary:
	var e := _board(party, caster, dice)
	var c := e.get_c(caster.id)
	if c == null:
		return {"ok": false, "text": "%s isn't in the party" % caster.name, "lines": []}
	var data := Compendium.shared().spell_data(spell_id)
	if not helpful(data):
		return {"ok": false, "text": "Only in a fight", "lines": []}
	var level := int(data.get("level", 0))
	if slot <= 0 and level > 0:
		var slots := _slots(caster, level)
		slot = slots[0] if not slots.is_empty() else level
	var tgt: Array = []
	if str((data.get("targets", {}) as Dictionary).get("kind", "")) == "self":
		tgt.append(c)
	else:
		for t in targets:
			var tc := e.get_c(t.id)
			if tc != null:
				tgt.append(tc)
	var before := e.log.entries.size()
	var res := e.spells.cast(c, spell_id, slot, tgt)
	var lines: Array[String] = []
	for i in range(before, e.log.entries.size()):
		var entry := e.log.entries[i]
		if str(entry["kind"]) != "turn":
			lines.append(str(entry["text"]))
	if not res.ok:
		return {"ok": false, "text": res.reason, "lines": lines}
	return {"ok": true, "text": "\n".join(lines), "lines": lines}


static func _slots(caster: Character, level: int) -> Array[int]:
	var out: Array[int] = []
	if level == 0:
		return out
	for l in range(level, 10):
		if caster.slots_left(l) > 0:
			out.append(l)
	return out


## A 5x5 open board with the caster in the middle and everyone else in the squares around them (all within touch),
## the caster's turn already begun.
static func _board(party: Array[Character], caster: Character, dice: DiceRoller) -> Encounter:
	var rows: Array = []
	for i in 5:
		rows.append(".....")
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	e.add(caster, &"party", Vector2i(2, 2)).controller = &"player"
	var spots: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
	var n := 0
	for ch in party:
		if ch == caster or n >= MAX_TARGETS:
			continue
		e.add(ch, &"party", spots[n]).controller = &"player"
		n += 1
	e.order = e.combatants.duplicate()
	e.turn_index = 0
	e.round_no = 1
	e.state = Encounter.State.ACTIVE
	return e


# --- Spells for exploring (no effect in a fight) ----------------------------------------------------

## Spells whose effect is on exploring rather than fighting (Light, Detect Magic, Find Traps, Comprehend Languages,
## Speak with Animals ...): [{id, name, level, ritual, slots, legal, reason}]. A Ritual spell can be cast as a Ritual
## (10 minutes longer, no slot) by a caster who has it prepared (2024).
static func utility_options(party: Array[Character], caster: Character, dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := _board(party, caster, dice)
	var seen := {}
	for k in caster.known_spells():
		var id := str(k["id"])
		if seen.has(id):
			continue
		seen[id] = true
		var data := Compendium.shared().spell_data(id)
		if data.is_empty() or (e.spells.has_combat_rules(data) and not id in EXPLORING_TOO):
			continue
		var unit := str((data.get("casting_time", {}) as Dictionary).get("unit", "action"))
		if unit == "reaction":
			continue
		var level := int(data.get("level", 0))
		var slots := _slots(caster, level)
		var ritual := bool(data.get("ritual", false))
		var entry := {"id": id, "name": str(data["name"]), "level": level, "ritual": ritual, "slots": slots, "legal": true, "reason": "", "resource_casts": caster.resource_casts(id)}
		if level > 0 and slots.is_empty() and not ritual:
			entry["legal"] = false
			entry["reason"] = "No spell slots left"
		if caster.hp <= 0 or caster.dead:
			entry["legal"] = false
			entry["reason"] = "%s can't act" % caster.name
		out.append(entry)
	return out


## Casts an exploring spell: spends the slot (or, `as_ritual`, ten more minutes), records it in
## StoryState.active_spells for its duration (conditions: `spell:<id>`), and returns {ok, text, effect}; the world
## applies `effect` (light, detect_magic, find_traps) where the party stands.
static func cast_utility(st: StoryState, caster: Character, spell_id: String, as_ritual: bool, slot: int = 0, resource_feature: String = "") -> Dictionary:
	var data := Compendium.shared().spell_data(spell_id)
	if data.is_empty():
		return {"ok": false, "text": "Unknown spell"}
	var utilities := utility_options(st.party, caster, DiceRoller.new(0))
	if not utilities.any(func(option: Dictionary) -> bool: return str(option["id"]) == spell_id):
		return {"ok": false, "text": "Use this spell through its combat or helpful-spell action"}
	if not caster.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == spell_id):
		return {"ok": false, "text": "Spell is not prepared or known"}
	if caster.hp <= 0 or caster.dead or caster.has_condition(&"incapacitated") or caster.has_flag("cant_cast"):
		return {"ok": false, "text": "%s can't cast" % caster.name}
	if bool((data.get("components", {}) as Dictionary).get("v", false)) and caster.has_flag("speechless"):
		return {"ok": false, "text": "Can't speak"}
	var payment: Dictionary = {}
	if resource_feature != "":
		if as_ritual or slot > int(data.get("level", 0)):
			return {"ok": false, "text": "This feature casts at base level using its Magic action"}
		for feature in caster.resource_casts(spell_id):
			if str(feature["id"]) == resource_feature:
				payment = feature["resource_cast"] as Dictionary
		if payment.is_empty():
			return {"ok": false, "text": "This feature cannot cast that spell"}
		if caster.resource_left(str(payment["resource"])) < int(payment["cost"]):
			return {"ok": false, "text": "No uses left"}
	var level := int(data.get("level", 0))
	if as_ritual and not bool(data.get("ritual", false)):
		return {"ok": false, "text": "%s isn't a Ritual" % data["name"]}
	if level > 0 and not as_ritual and payment.is_empty():
		var slots := _slots(caster, level)
		if slots.is_empty():
			return {"ok": false, "text": "No spell slots left"}
		if not caster.expend_slot(slot if slot in slots else slots[0]):
			return {"ok": false, "text": "No spell slots left"}
	if not payment.is_empty():
		caster.spend_resource(str(payment["resource"]), int(payment["cost"]))
	var minutes := 10 if as_ritual else 1
	var dur := data.get("duration", {}) as Dictionary
	var lasting := 0
	match str(dur.get("kind", "")):
		"minutes":
			lasting = int(dur.get("amount", 1))
		"hours":
			lasting = int(dur.get("amount", 1)) * 60
		"days":
			lasting = int(dur.get("amount", 1)) * 24 * 60
	st.advance_minutes(minutes)
	if lasting > 0:
		st.active_spells[spell_id] = {"until": st.total_minutes() + lasting, "caster": caster.id}
	return {"ok": true, "effect": spell_id, "text": "%s casts %s%s." % [caster.name.get_slice(" ", 0), data["name"],
		" as a Ritual" if as_ritual else ""]}
