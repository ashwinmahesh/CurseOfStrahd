class_name FieldCasting
extends RefCounted
## Casting outside a fight (plan §5.2, "rest and recover between fights"): healing and helpful spells on the party,
## from the character sheet. It goes through the combat SpellCaster on a small peaceful board, so slots, free
## castings, Concentration and lasting effects behave exactly as they do in a fight. Spells that harm, push or
## summon wait for a fight.

const MAX_TARGETS := 8
## Spells that also work in a fight but are worth casting while exploring (their light lasts; Find Familiar's familiar
## stays with its caster and joins the next fights).
const EXPLORING_TOO: Array[String] = ["light", "dancing_lights", "continual_flame", "daylight", "find_familiar"]


## What `caster` can cast right now outside combat: [{id, name, level, slots: Array[int], free, count, self_only,
## others_only, legal, reason}], helpful spells only. `others_only`: a spell for another creature, never its caster
## (Warding Bond).
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
			"others_only": bool((data.get("targets", {}) as Dictionary).get("other", false)),
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


## Healing and help: spells that target creatures, allies or the caster and neither deal damage, force a save, make an
## attack nor fill an area. An ally spell may go on its caster too (Protection from Evil and Good, Lesser Restoration,
## Invisibility; owner report 2026-10-09: they had no Cast button outside fights). Light and Continual Flame are cast
## from the exploring list instead (utility_options).
static func helpful(data: Dictionary) -> bool:
	for k: String in ["damage", "save", "attack", "area", "summon"]:
		if data.has(k):
			return false
	if str(data.get("id", "")) in EXPLORING_TOO:
		return false
	var kind := str((data.get("targets", {}) as Dictionary).get("kind", ""))
	return kind in ["creature", "ally", "self"] and (data.has("heal") or data.has("effects") or bool(data.get("field_utility", false)))


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
			if t == caster and bool((data.get("targets", {}) as Dictionary).get("other", false)):
				return {"ok": false, "text": "%s goes on another creature" % data.get("name", spell_id), "lines": []}
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


## A 5x5 open board (or `size` x `size`) with the caster in the middle and everyone else in the squares around them
## (all within touch), the caster's turn already begun.
static func _board(party: Array[Character], caster: Character, dice: DiceRoller, size: int = 5) -> Encounter:
	var rows: Array = []
	for i in size:
		rows.append(".".repeat(size))
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	var mid := floori(size / 2.0)
	e.add(caster, &"party", Vector2i(mid, mid)).controller = &"player"
	var spots: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		spots.append(Vector2i(mid, mid) + d)
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


# --- Spells at someone on the map, outside a fight -------------------------------------------------

## Spells that put something on another creature outside a fight (owner, 2026-10-07: "if we cast sleep in the
## overworld, or anything that gives any enemy or NPC an effect, that should show"): those with a save and a lasting
## effect that neither deal damage, heal nor summon (Sleep, Charm Person, Hold Person, Hideous Laughter, Bane, Faerie
## Fire ...). Healing and help for the party are helpful(); anything that hurts waits for a fight.
static func at_creature(data: Dictionary) -> bool:
	for k: String in ["damage", "heal", "summon", "on_hit_spell"]:
		if data.has(k):
			return false   # (an on-hit spell, Ensnaring Strike, rides on a weapon's hit in a fight)
	if (data.get("casting_time", {}) as Dictionary).has("trigger"):
		return false
	var kind := str((data.get("targets", {}) as Dictionary).get("kind", ""))
	return kind in ["creature", "area"] and data.has("save") and data.has("effects")


## What `caster` can cast at someone on the map now: castable() entries for at_creature() spells, with `range` (feet)
## and their slots, the same shape as options().
static func options_at(party: Array[Character], caster: Character, dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := _board(party, caster, dice)
	var c := e.get_c(caster.id)
	if c == null:
		return out
	for s in e.spells.castable(c):
		var data := Compendium.shared().spell_data(str(s["id"]))
		if not at_creature(data):
			continue
		var entry := {"id": str(s["id"]), "name": str(s["name"]), "level": int(s["level"]), "free": bool(s["free"]),
			"range": e.spells.range_ft(data, c), "legal": bool(s["legal"]), "reason": str(s["reason"]).replace("in this fight", "outside a fight"),
			"slots": _slots(caster, int(s["level"]))}
		if bool(entry["legal"]) and int(s["level"]) > 0 and not bool(s["free"]) and (entry["slots"] as Array).is_empty():
			entry["legal"] = false
			entry["reason"] = "No spell slots left"
		if not c.can_act():
			entry["legal"] = false
			entry["reason"] = "%s can't act" % caster.name
		out.append(entry)
	return out


## Casts an at_creature() spell from `caster` at `target` (someone on the map, its own creature, so what the spell
## leaves on it stays there) on a peaceful board, then lets one round go by there, so what changes at the end of the
## target's turn does as in a fight (Sleep's drowsiness deepening into sleep on a failed second save). Returns
## {ok, text, lines}. The caller checks range and sight on the real map.
static func cast_at(party: Array[Character], caster: Character, spell_id: String, slot: int, target: Creature,
		dice: DiceRoller) -> Dictionary:
	var data := Compendium.shared().spell_data(spell_id)
	if not at_creature(data):
		return {"ok": false, "text": "Only in a fight", "lines": []}
	var e := _board(party, caster, dice, 9)
	var c := e.get_c(caster.id)
	if c == null:
		return {"ok": false, "text": "%s isn't in the party" % caster.name, "lines": []}
	var tc := e.add(target, &"enemy", Vector2i(4, 7))   # 15 ft off, beyond any 5-ft burst round the party
	e.order.append(tc)
	var level := int(data.get("level", 0))
	if slot <= 0 and level > 0:
		var slots := _slots(caster, level)
		slot = slots[0] if not slots.is_empty() else level
	# An area spell lands on the target's square, whether its data names the area or the creatures in it (Calm
	# Emotions' "each Humanoid in the Sphere": with no point it refused, "Choose a point", QA 2026-10-08).
	var point := Vector2(4.5, 7.5) if data.has("area") or str((data.get("targets", {}) as Dictionary).get("kind", "")) == "area" else Vector2.INF
	var before := e.log.entries.size()
	var res := e.spells.cast(c, spell_id, slot, [tc], point)
	if res.ok:
		for i in e.order.size() + 1:
			if e.state != Encounter.State.ACTIVE or e.pending != null:
				break
			var whose := e.current()
			e.end_turn()
			if whose == tc:
				break
	var lines: Array[String] = []
	for i in range(before, e.log.entries.size()):
		var entry := e.log.entries[i]
		if str(entry["kind"]) != "turn":
			lines.append(str(entry["text"]))
	if not res.ok:
		return {"ok": false, "text": res.reason, "lines": lines}
	return {"ok": true, "text": "\n".join(lines), "lines": lines}


# --- Spells for exploring (no effect in a fight) ----------------------------------------------------

## Whether one of `caster`'s features casts `spell_id` without its Material component (Knowledge Domain's Channel
## Divinity): then a costly one isn't asked for when it's cast that way.
static func _waives_material(caster: Character, spell_id: String) -> bool:
	return caster.resource_casts(spell_id).any(func(f: Dictionary) -> bool: return bool((f["resource_cast"] as Dictionary).get("omit_material", false)))

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
		# A costly material component (2024): carried, even for a Ritual (Find Familiar's incense).
		if caster.component_why(data) != "" and not _waives_material(caster, id):
			entry["legal"] = false
			entry["reason"] = caster.component_why(data)
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
	var omit_material := resource_feature != "" and caster.resource_casts(spell_id).any(func(f: Dictionary) -> bool:
		return str(f["id"]) == resource_feature and bool((f["resource_cast"] as Dictionary).get("omit_material", false)))
	if not omit_material and caster.component_why(data) != "":
		return {"ok": false, "text": caster.component_why(data)}
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
	var used := "" if omit_material else caster.use_component(data)
	var res := _take_effect(st, caster, spell_id, data, as_ritual, payment.is_empty())
	if used != "":
		res["text"] = str(res["text"]).trim_suffix(".") + ", using up %s." % used
	return res


## What casting an exploring spell does once it's paid for (a slot, a Ritual's time, a feature's use, or a Spell
## Scroll): the casting time passes, the spell is recorded for its duration, and Find Familiar's familiar is with the
## caster. `own_time` false: a feature casting it with its Magic action, which takes a minute whatever the spell says.
static func _take_effect(st: StoryState, caster: Character, spell_id: String, data: Dictionary, as_ritual: bool, own_time: bool) -> Dictionary:
	var minutes := 10 if as_ritual else 1
	# A casting time of minutes or hours takes that long (a Ritual adds its 10 minutes): Find Familiar's hour. A
	# feature that casts the spell with its Magic action keeps the minute.
	var ct := data.get("casting_time", {}) as Dictionary
	if own_time and str(ct.get("unit", "")) in ["minute", "hour"]:
		minutes = int(ct.get("amount", 1)) * (60 if str(ct["unit"]) == "hour" else 1) + (10 if as_ritual else 0)
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
	# A longer Ritual for one spell (Emerald Enclave Fledgling: Speak with Animals for 8 hours).
	if as_ritual:
		for m in caster.modifiers_for(&"ritual_duration"):
			if m.text("spell_id") == spell_id:
				lasting = maxi(lasting, m.number("value"))
	if lasting > 0:
		st.active_spells[spell_id] = {"until": st.total_minutes() + lasting, "caster": caster.id}
	# Find Familiar: the familiar is with the caster from now on (it joins fights until it's lost or dismissed).
	if spell_id == "find_familiar":
		caster.familiar = "here"
	return {"ok": true, "effect": spell_id, "text": "%s casts %s%s." % [caster.name.get_slice(" ", 0), data["name"],
		" as a Ritual" if as_ritual else ""]}


## Casts an exploring spell from a Spell Scroll (story/field_items.gd): no slot and no preparation, in the spell's own
## casting time. The scroll's own rules (the class list, the check for a level above the reader's) come first, there.
static func cast_from_scroll(st: StoryState, caster: Character, spell_id: String) -> Dictionary:
	var data := Compendium.shared().spell_data(spell_id)
	if data.is_empty():
		return {"ok": false, "text": "Unknown spell"}
	var r := _take_effect(st, caster, spell_id, data, false, true)
	r["text"] = "%s reads the scroll aloud and casts %s." % [caster.name.get_slice(" ", 0), data["name"]]
	return r
