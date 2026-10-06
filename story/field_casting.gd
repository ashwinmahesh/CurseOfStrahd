class_name FieldCasting
extends RefCounted
## Casting outside a fight (plan §5.2, "rest and recover between fights"): healing and helpful spells on the party,
## from the character sheet. It goes through the combat SpellCaster on a small peaceful board, so slots, free
## castings, Concentration and lasting effects behave exactly as they do in a fight. Spells that harm, push or
## summon wait for a fight.

const MAX_TARGETS := 8


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
	return kind in ["creature", "self"] and (data.has("heal") or data.has("effects"))


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
