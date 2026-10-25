class_name FieldCasting
extends RefCounted
## Casting outside a fight (plan §5.2, "rest and recover between fights"): healing and helpful spells on the party,
## from the character sheet. It goes through the combat SpellCaster on a small peaceful board, so slots, free
## castings, Concentration and lasting effects behave exactly as they do in a fight. Spells that harm, push or
## summon wait for a fight, except the companions that stay with their caster (Find Familiar, Find Steed).

const MAX_TARGETS := 8
## Spells that also work in a fight but are worth casting while exploring (their light lasts; Find Familiar's familiar
## and Find Steed's steed stay with their caster and join the next fights).
## Costly components with no item to carry, bought from the party's purse as the spell is cast (docs/rules/deviations.md):
## Heroes' Feast's gem-encrusted bowl.
const PURSE_COMPONENTS := {"heroes_feast": 1000}
## st.flags: the last brew of Tasha's Bubbling Cauldron {who, item, qty} (an underscore key: bookkeeping).
const CAULDRON_KEY := "_cauldron"
const EXPLORING_TOO: Array[String] = ["light", "dancing_lights", "continual_flame", "daylight", "find_familiar",
	"find_steed", "animate_dead", "create_undead"]
## The dead raised while exploring (Animate Dead, Create Undead): how many, of what, at each slot level, for the day they
## stay under the caster's control (2024: 24 hours), joining each fight beside the caster (bring_risen).
const RISEN := {"animate_dead": {"base": 3, "count": 1, "per_level": 2}, "create_undead": {"base": 6, "count": 3, "per_level": 1}}


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
			"legal": bool(s["legal"]), "reason": str(s["reason"]).replace("in this fight", "outside a fight")}
		entry.merge(_offer(caster, int(s["level"]), bool(s["free"]), bool(s.get("at_will", false))), true)
		if bool(entry["legal"]) and int(s["level"]) > 0 and not bool(entry["free"]) and (entry["slots"] as Array).is_empty():
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


## Casts `spell_id` from `caster` at `slot` (0 = the lowest that works) on `targets`: party members, or with `st` the
## story allies travelling with the party too (st.guests; owner, 2026-10-12: a companion should take spells outside
## fights). Returns {ok, text, lines}. With `st`, a spell that takes minutes or hours to cast (Prayer of Healing's ten
## minutes) takes them off the clock.
static func cast(party: Array[Character], caster: Character, spell_id: String, slot: int, targets: Array,
		dice: DiceRoller, st: StoryState = null) -> Dictionary:
	if st != null and Wards.antimagic_notice(st) != "":
		return {"ok": false, "text": Wards.antimagic_notice(st), "lines": []}   # in an antimagic area: nothing is cast
	var guests: Array = []
	if st != null:
		guests.append_array(st.guests)
	var e := _board(party, caster, dice, 5, guests)
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
		for t: Variant in targets:
			if t == caster and bool((data.get("targets", {}) as Dictionary).get("other", false)):
				return {"ok": false, "text": "%s goes on another creature" % data.get("name", spell_id), "lines": []}
			var tc := e.get_c((t as Creature).id)
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
	var ct := data.get("casting_time", {}) as Dictionary
	if st != null and str(ct.get("unit", "")) in ["minute", "hour"]:
		st.advance_minutes(int(ct.get("amount", 1)) * (60 if str(ct["unit"]) == "hour" else 1))
	return {"ok": true, "text": "\n".join(lines), "lines": lines}


# --- Bringing back the dead, outside a fight -------------------------------------------------------

## The spells that bring a dead party member back outside a fight (owner, 2026-10-12: Revivify worked only inside the
## fight, and a party caster's Raise Dead used up its diamond and did nothing): how long the hero may have been dead
## (minutes, Services.dead_for), whether they come back with all their Hit Points or 1, and whether the ordeal follows
## (-4 on D20 Tests for 10 days, as the temple's Raise Dead). Reincarnate's rare oils are bought with 1,000 gp from the
## purse (there's no oils item; docs/rules/deviations.md). Gentle Repose keeps a body instead: its days don't count.
const REVIVAL := {
	"revivify": {"within": 1, "full_hp": false, "ordeal": false},
	"raise_dead": {"within": 10 * 24 * 60, "full_hp": false, "ordeal": true},
	"reincarnate": {"within": 10 * 24 * 60, "full_hp": true, "ordeal": false, "purse": 1000},
	"resurrection": {"within": 100 * 365 * 24 * 60, "full_hp": true, "ordeal": true},
	"true_resurrection": {"within": 200 * 365 * 24 * 60, "full_hp": true, "ordeal": false},
	"gentle_repose": {"within": -1},
}
const REPOSE_MINUTES := 10 * 24 * 60


## The revival spells `caster` knows, as options() gives them, with `targets`: the dead party members each can reach.
static func revival_options(st: StoryState, caster: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for k in caster.known_spells():
		var id := str(k["id"])
		if not REVIVAL.has(id) or seen.has(id):
			continue
		seen[id] = true
		var data := Compendium.shared().spell_data(id)
		var level := int(data.get("level", 0))
		var targets: Array[Character] = []
		var first_why := ""
		for ch in st.party:
			if ch == caster or not ch.dead:
				continue
			var why := revive_why(st, id, ch)
			if why == "":
				targets.append(ch)
			elif first_why == "":
				first_why = why
		var entry := {"id": id, "name": str(data["name"]), "level": level, "free": false, "count": 1, "self_only": false,
			"others_only": true, "slots": _slots(caster, level), "targets": targets, "legal": true, "reason": "",
			"ritual": bool(data.get("ritual", false))}
		var why := _revive_cost_why(st, caster, id, data)
		if targets.is_empty():
			why = first_why if first_why != "" else "Nobody in the party is dead"
		if why != "":
			entry["legal"] = false
			entry["reason"] = why
		out.append(entry)
	return out


## Why `spell_id` can't bring `ch` back now, or "".
static func revive_why(st: StoryState, spell_id: String, ch: Character) -> String:
	if not ch.dead:
		return "%s isn't dead" % ch.name.get_slice(" ", 0)
	var within := int((REVIVAL.get(spell_id, {}) as Dictionary).get("within", -1))
	if within >= 0 and Services.dead_for(st, ch) > within:
		return "%s has been dead too long for %s" % [ch.name.get_slice(" ", 0), Compendium.shared().display_name("spells", spell_id)]
	return ""


## What stops `caster` paying for a revival spell: a slot (Gentle Repose can be a Ritual), its costly component, the
## purse for Reincarnate's oils, or being unable to cast. "" when nothing does.
static func _revive_cost_why(st: StoryState, caster: Character, spell_id: String, data: Dictionary) -> String:
	if caster.dead or caster.hp <= 0 or caster.has_condition(&"incapacitated"):
		return "%s can't cast" % caster.name.get_slice(" ", 0)
	var level := int(data.get("level", 0))
	if level > 0 and _slots(caster, level).is_empty() and not bool(data.get("ritual", false)):
		return "No spell slots left"
	if caster.component_why(data) != "":
		return caster.component_why(data)
	var purse := float((REVIVAL.get(spell_id, {}) as Dictionary).get("purse", 0))
	if purse > 0.0 and st.gold < purse:
		return "Needs rare oils worth %d gp (the purse holds %d)" % [roundi(purse), floori(st.gold)]
	return ""


## The dead party members `spell_id` can bring back now (revive_why), for an item that casts it (a scroll, the Rod of
## Resurrection) and the inventory's "<power> on <hero>" buttons.
static func revivable(st: StoryState, spell_id: String) -> Array[Character]:
	var out: Array[Character] = []
	for ch in st.party:
		if ch.dead and revive_why(st, spell_id, ch) == "":
			out.append(ch)
	return out


## An item's casting of a revival spell on dead party member `target`, outside a fight (Ashwin, 2026-10-15: a Spell
## Scroll of Revivify or Raise Dead and the Rod of Resurrection did nothing there): as revive() does, with no slot and no
## costly component (2024 DMG: a Spell Scroll's spell needs no Material components; the Rod's charges are its cost) and
## no rare oils. The item's use (the scroll, the charges) is the caller's. {ok, text}.
static func revive_with_item(st: StoryState, reader: Character, spell_id: String, target: Character) -> Dictionary:
	var data := Compendium.shared().spell_data(spell_id)
	if data.is_empty() or not REVIVAL.has(spell_id):
		return {"ok": false, "text": "Not a spell that brings back the dead"}
	var why := revive_why(st, spell_id, target)
	if why != "":
		return {"ok": false, "text": why}
	var rule := REVIVAL[spell_id] as Dictionary
	var ct := data.get("casting_time", {}) as Dictionary
	var minutes := int(ct.get("amount", 1)) * 60 if str(ct.get("unit", "")) == "hour" else 1
	var who := reader.name.get_slice(" ", 0)
	var them := target.name.get_slice(" ", 0)
	var text := ""
	if spell_id == "gentle_repose":
		Services.repose(st, target, REPOSE_MINUTES)
		text = "%s casts Gentle Repose on %s's body: for 10 days it won't decay, and those days don't count against raising them." % [who, them]
	else:
		Services.bring_back(st, target, bool(rule["full_hp"]), bool(rule["ordeal"]), str(data["name"]))
		text = "%s casts %s, and %s breathes again%s." % [who, data["name"], them,
			" with every Hit Point" if bool(rule["full_hp"]) else ", with 1 Hit Point"]
		if bool(rule["ordeal"]):
			text += " The journey back leaves them -4 on D20 Tests for 10 days."
	st.advance_minutes(minutes)
	return {"ok": true, "text": text}


## Casts a revival spell on dead party member `target`: the slot (`slot` 0: the lowest; Gentle Repose without a slot is
## a Ritual), the component and the casting time are spent, and the hero comes back (Services.bring_back) or, for
## Gentle Repose, their body keeps for 10 days. {ok, text}.
static func revive(st: StoryState, caster: Character, spell_id: String, slot: int, target: Character) -> Dictionary:
	if Wards.antimagic_notice(st) != "":
		return {"ok": false, "text": Wards.antimagic_notice(st)}
	var data := Compendium.shared().spell_data(spell_id)
	if data.is_empty() or not REVIVAL.has(spell_id):
		return {"ok": false, "text": "Not a spell that brings back the dead"}
	if not caster.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == spell_id):
		return {"ok": false, "text": "Spell is not prepared or known"}
	var why := revive_why(st, spell_id, target)
	if why == "":
		why = _revive_cost_why(st, caster, spell_id, data)
	if why != "":
		return {"ok": false, "text": why}
	var level := int(data.get("level", 0))
	var slots := _slots(caster, level)
	var ritual := bool(data.get("ritual", false)) and (slot <= 0 or slots.is_empty())
	if not ritual:
		if not caster.expend_slot(slot if slot in slots else slots[0]):
			return {"ok": false, "text": "No spell slots left"}
	var used := caster.use_component(data)
	var rule := REVIVAL[spell_id] as Dictionary
	var purse := float(rule.get("purse", 0))
	if purse > 0.0:
		st.gold = maxf(0.0, st.gold - purse)
	var ct := data.get("casting_time", {}) as Dictionary
	var minutes := (int(ct.get("amount", 1)) * 60 if str(ct.get("unit", "")) == "hour" else 1) + (10 if ritual else 0)
	var who := caster.name.get_slice(" ", 0)
	var them := target.name.get_slice(" ", 0)
	var text := ""
	if spell_id == "gentle_repose":
		Services.repose(st, target, REPOSE_MINUTES)
		text = "%s casts Gentle Repose on %s's body: for 10 days it won't decay, and those days don't count against raising them." % [who, them]
	else:
		Services.bring_back(st, target, bool(rule["full_hp"]), bool(rule["ordeal"]), str(data["name"]))
		text = "%s casts %s, and %s breathes again%s." % [who, data["name"], them,
			" with every Hit Point" if bool(rule["full_hp"]) else ", with 1 Hit Point"]
		if bool(rule["ordeal"]):
			text += " The journey back leaves them -4 on D20 Tests for 10 days."
	st.advance_minutes(minutes)
	if used != "":
		text = text.trim_suffix(".") + ", using up %s." % used
	if purse > 0.0:
		text += " The rare oils cost %d gp." % roundi(purse)
	return {"ok": true, "text": text}


static func _slots(caster: Character, level: int) -> Array[int]:
	var out: Array[int] = []
	if level == 0:
		return out
	return caster.slot_levels(level)


## What an option is paid with, {slots, free, at_will}, as a fight's hotbar offers it (owner, 2026-10-13: a warlock's
## spells only at the pact level). An at-will casting (an Eldritch Invocation's) is free and takes no slot. A spell only
## a Pact Magic slot pays for is cast at the pact level: a free casting of it (a tiefling's Darkness) comes first only
## when it's of that level too, and otherwise waits until the pact slots are spent.
static func _offer(caster: Character, level: int, free: bool, at_will: bool) -> Dictionary:
	var slots := _slots(caster, level)
	var pact_at := caster.pact_only_level(level)
	if at_will or (free and pact_at == level):
		slots.clear()
		return {"slots": slots, "free": true, "at_will": at_will}
	return {"slots": slots, "free": free and pact_at == 0, "at_will": false}


## A 5x5 open board (or `size` x `size`) with the caster in the middle and everyone else in the squares around them
## (all within touch), the caster's turn already begun: the party, then any `guests` (story allies, StoryState.guests).
static func _board(party: Array[Character], caster: Character, dice: DiceRoller, size: int = 5, guests: Array = []) -> Encounter:
	var rows: Array = []
	for i in size:
		rows.append(".".repeat(size))
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	e.peaceful = true   # outside a fight: a spell's minutes or hours of casting pass on the clock (cast())
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
	for g: Variant in guests:
		if n >= MAX_TARGETS or (g as Creature).dead:
			continue
		e.add(g as Creature, &"party", spots[n])
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
			"range": e.spells.range_ft(data, c), "legal": bool(s["legal"]), "reason": str(s["reason"]).replace("in this fight", "outside a fight")}
		entry.merge(_offer(caster, int(s["level"]), bool(s["free"]), bool(s.get("at_will", false))), true)
		if bool(entry["legal"]) and int(s["level"]) > 0 and not bool(entry["free"]) and (entry["slots"] as Array).is_empty():
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
## Speak with Animals ...): [{id, name, level, ritual, slots, free, choices, legal, reason}]. A Ritual spell can be cast
## as a Ritual (10 minutes longer, no slot) by a caster who has it prepared (2024). `free`: a casting a feature gives
## without a slot is left (Faithful Steed's Find Steed). `choices`: what the spell asks for as it's cast (Find Steed's
## creature type), [] for none.
static func utility_options(party: Array[Character], caster: Character, dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := _board(party, caster, dice)
	var c := e.get_c(caster.id)
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
		var at_will := level > 0 and c != null and (ClassFeatures.at_will(c, id) or bool(k.get("at_will", false)))
		var offer := _offer(caster, level, level > 0 and caster.resource_left("spell:%s" % id) > 0, at_will)
		var slots := offer["slots"] as Array[int]
		var ritual := bool(data.get("ritual", false))
		var free := bool(offer["free"])
		var choice_def := data.get("choice", {}) as Dictionary
		var choices: Array = (choice_def.get("from", []) as Array) if str(choice_def.get("kind", "")) == "option" else []
		var entry := {"id": id, "name": str(data["name"]), "level": level, "ritual": ritual, "slots": slots, "free": free,
			"at_will": at_will, "choices": choices, "choice_labels": choice_def.get("labels", {}), "legal": true, "reason": "",
			"resource_casts": caster.resource_casts(id)}
		if level > 0 and slots.is_empty() and not ritual and not free:
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


## Casts an exploring spell: spends the slot (or, `as_ritual`, ten more minutes; or a feature's free casting, Faithful
## Steed's, when no slot is asked for), records it in StoryState.active_spells for its duration
## (conditions: `spell:<id>`), and returns {ok, text, effect}; the world applies `effect` (light, detect_magic,
## find_traps) where the party stands. `choice`: what the spell asks for as it's cast (Find Steed's creature type).
static func cast_utility(st: StoryState, caster: Character, spell_id: String, as_ritual: bool, slot: int = 0, resource_feature: String = "",
		choice: String = "") -> Dictionary:
	if Wards.antimagic_notice(st) != "":
		return {"ok": false, "text": Wards.antimagic_notice(st)}
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
	if spell_id == "create_undead" and not st.is_night():
		return {"ok": false, "text": "Create Undead can only be cast at night"}
	if spell_id == "commune_with_nature" and not bool((Compendium.shared().get_entry("locations", st.location).get("map", {}) as Dictionary).get("outdoors", false)):
		return {"ok": false, "text": "Commune with Nature needs the open air"}
	var purse := float(PURSE_COMPONENTS.get(spell_id, 0))
	if purse > 0.0 and st.gold < purse:
		return {"ok": false, "text": "Needs %s (%d gp; the purse holds %d)" % [str((data.get("components", {}) as Dictionary).get("m", "its component")).get_slice(",", 0), roundi(purse), floori(st.gold)]}
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
	var cast_level := level
	var offered: Dictionary = utilities.filter(func(option: Dictionary) -> bool: return str(option["id"]) == spell_id)[0]
	if level > 0 and not as_ritual and payment.is_empty() and not bool(offered["at_will"]):
		var slots := _slots(caster, level)
		if bool(offered["free"]) and (slot <= 0 or slots.is_empty()):
			caster.spend_resource("spell:%s" % spell_id)   # a free casting a feature gives (Faithful Steed)
		elif slots.is_empty():
			return {"ok": false, "text": "No spell slots left"}
		else:
			cast_level = slot if slot in slots else slots[0]
			if not caster.expend_slot(cast_level):
				return {"ok": false, "text": "No spell slots left"}
	if not payment.is_empty():
		caster.spend_resource(str(payment["resource"]), int(payment["cost"]))
	var used := "" if omit_material else caster.use_component(data)
	if purse > 0.0:
		st.gold = maxf(0.0, st.gold - purse)
	var res := _take_effect(st, caster, spell_id, data, as_ritual, payment.is_empty(), cast_level, choice)
	if used != "":
		res["text"] = str(res["text"]).trim_suffix(".") + ", using up %s." % used
	if purse > 0.0:
		res["text"] = str(res["text"]) + " The %s cost %d gp." % [str((data.get("components", {}) as Dictionary).get("m", "component")).get_slice(" worth", 0).trim_prefix("a "), roundi(purse)]
	return res


## What casting an exploring spell does once it's paid for (a slot, a Ritual's time, a feature's use, or a Spell
## Scroll): the casting time passes, the spell is recorded for its duration, and Find Familiar's familiar or Find
## Steed's steed (of the `choice` type, at `level`) is with the caster. `own_time` false: a feature casting it with its
## Magic action, which takes a minute whatever the spell says.
static func _take_effect(st: StoryState, caster: Character, spell_id: String, data: Dictionary, as_ritual: bool, own_time: bool,
		level: int = 0, choice: String = "") -> Dictionary:
	var minutes := 10 if as_ritual else 1
	# A casting time of minutes or hours takes that long (a Ritual adds its 10 minutes): Find Familiar's hour. A
	# feature that casts the spell with its Magic action keeps the minute.
	var ct := data.get("casting_time", {}) as Dictionary
	if own_time and str(ct.get("unit", "")) in ["minute", "hour"]:
		minutes = int(ct.get("amount", 1)) * (60 if str(ct["unit"]) == "hour" else 1) + (10 if as_ritual else 0)
	var dur := Spellcasting.duration_at(data, level)   # a higher slot can last longer (Magic Circle: an hour a level)
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
	# Leomund's Secret Chest lasts until dispelled; after 60 days it may fail any day (2024), so the game keeps it 60.
	if spell_id == "leomunds_secret_chest":
		lasting = 60 * 24 * 60
	if lasting > 0:
		st.active_spells[spell_id] = {"until": st.total_minutes() + lasting, "caster": caster.id}
		if Effect.until_long_rest(dur):
			RestRules.keep_until_long_rest(st, spell_id)
	# Spells that help a check while they run (Zone of Truth on Insight...): CHECK_AIDS.
	if CHECK_AIDS.has(spell_id) and lasting > 0:
		_check_aid(st, caster, spell_id, data, lasting)
	# Wards on a place or a rest (and Hallow's places, for good): story/wards.gd.
	Wards.cast_here(st, spell_id)
	if spell_id == "heroes_feast":
		return {"ok": true, "effect": spell_id, "text": _feast(st, caster)}
	# Find Familiar: the familiar is with the caster from now on (it joins fights until it's lost or dismissed).
	if spell_id == "find_familiar":
		caster.familiar = "here"
	# Find Steed (2024): the steed answers, a new one in place of any before it, and stays until it drops to 0 Hit Points.
	if spell_id == "find_steed":
		var kinds := (data.get("choice", {}) as Dictionary).get("from", ["celestial"]) as Array
		var kind := choice if choice in kinds else str(kinds[0])
		caster.steed = {"type": kind, "level": maxi(level, int(data.get("level", 2)))}
		return {"ok": true, "effect": spell_id, "text": "%s casts Find Steed: a %s steed answers, and stays until it falls." % [
			caster.name.get_slice(" ", 0), kind.capitalize()]}
	# Animate Dead, Create Undead: the dead rise and follow their caster for a day, joining each fight (bring_risen).
	if RISEN.has(spell_id):
		var rule := RISEN[spell_id] as Dictionary
		var kinds := (data.get("choice", {}) as Dictionary).get("from", ["zombie" if spell_id == "animate_dead" else "ghoul"]) as Array
		var kind := choice if choice in kinds else str(kinds[0])
		var count := int(rule["count"]) + int(rule["per_level"]) * maxi(0, level - int(rule["base"]))
		st.active_spells[spell_id] = {"until": st.total_minutes() + 24 * 60, "caster": caster.id, "kind": kind, "count": count}
		return {"ok": true, "effect": spell_id, "text": "%s casts %s: %d %s%s rise%s to follow them for a day, and will fight beside them." % [
			caster.name.get_slice(" ", 0), data["name"], count, Compendium.shared().display_name("monsters", kind),
			"" if count == 1 else "s", "s" if count == 1 else ""]}
	# Scouting and divining (story/oracles.gd): what the spell finds out where the party stands.
	if Campaign.module().handles_spell(spell_id):
		return {"ok": true, "effect": spell_id, "text": Campaign.module().cast_spell(st, caster, spell_id, choice)}
	# Tenser's Floating Disk: it carries 500 lb more for its caster while it lasts.
	if spell_id == "tensers_floating_disk" and lasting > 0:
		for old: Effect in caster.effects.duplicate():
			if old.source_id == spell_id:
				caster.remove_effect(old)
		var disk := Effect.new("Tenser's Floating Disk", &"spell", spell_id).with_modifier("carry_bonus", {"value": 500})
		disk.ends = Effect.Ends.MINUTES
		disk.minutes_left = lasting
		caster.add_effect(disk)
	if spell_id == "tashas_bubbling_cauldron":
		return {"ok": true, "effect": spell_id, "text": _cauldron(st, caster, data, choice)}
	# Druidcraft's Weather Sensor (2024): what the sky will do over the next day.
	if spell_id == "druidcraft":
		var tomorrow := Weather.at(st, st.location, st.total_minutes() + 24 * 60)
		return {"ok": true, "effect": spell_id, "text": "%s casts Druidcraft and reads the sky: tomorrow brings %s." % [
			caster.name.get_slice(" ", 0), str(Weather.kind(tomorrow).get("label", tomorrow)).to_lower()]}
	return {"ok": true, "effect": spell_id, "text": "%s casts %s%s." % [caster.name.get_slice(" ", 0), data["name"],
		" as a Ritual" if as_ritual else ""]}


## Spells that only did something with people, a disguise or an illusion help the checks they'd help while they run
## (Ashwin's answer to the spell audit, 2026-10-12; docs/rules/deviations.md): Advantage on these skills for the
## spell's duration, for its caster (Seeming: the whole party). Zone of Amicability floors a check to influence at 10.
const CHECK_AIDS := {"zone_of_truth": ["insight"], "disguise_self": ["deception"],
	"seeming": ["deception"], "silent_image": ["stealth"], "major_image": ["stealth", "deception"],
	"comprehend_languages": ["history", "investigation"], "tongues": ["persuasion"], "beast_sense": ["perception"],
	"locate_object": ["perception", "investigation"], "locate_creature": ["survival"],
	"zone_of_amicability": ["animal_handling", "deception", "intimidation", "performance", "persuasion"]}


static func _check_aid(st: StoryState, caster: Character, spell_id: String, data: Dictionary, minutes: int) -> void:
	var who: Array[Character] = [caster]
	if spell_id == "seeming":
		who = st.party.filter(func(ch: Character) -> bool: return not ch.dead)
	for ch in who:
		for old: Effect in ch.effects.duplicate():
			if old.source_id == spell_id:
				ch.remove_effect(old)
		var fx := Effect.new(str(data["name"]), &"spell", spell_id)
		for skill: String in CHECK_AIDS[spell_id]:
			if spell_id == "zone_of_amicability":
				fx = fx.with_modifier("d20_floor", {"on": "check:" + skill, "value": 10})
			else:
				fx = fx.with_modifier("advantage", {"on": "check:" + skill})
		fx.ends = Effect.Ends.MINUTES
		fx.minutes_left = minutes
		ch.add_effect(fx)


## The dead raised while exploring join a fight beside their caster, if the day isn't over (LocationFights).
static func bring_risen(e: Encounter, st: StoryState) -> void:
	for id: String in RISEN:
		if not st.spell_active(id):
			continue
		var a := st.active_spells[id] as Dictionary
		var c := e.get_c(str(a.get("caster", "")))
		if c != null and c.is_alive():
			e.spells.summons.bring_risen(c, id, str(a.get("kind", "")), int(a.get("count", 1)))


## Tasha's Bubbling Cauldron (2024): copies of a common or uncommon potion (`choice`), one per point of the caster's
## spellcasting modifier (at least one), in their pack; what's left of the last brew is gone when they brew again.
static func _cauldron(st: StoryState, caster: Character, data: Dictionary, choice: String) -> String:
	var kinds := (data.get("choice", {}) as Dictionary).get("from", ["potion_of_healing"]) as Array
	var potion := choice if choice in kinds else str(kinds[0])
	var last := st.flags.get(CAULDRON_KEY, {}) as Dictionary
	if not last.is_empty():
		for ch in st.party:
			if ch.id == str(last.get("who", "")):
				for i in int(last.get("qty", 0)):
					if not ch.carries(str(last["item"])):
						break
					ch.remove_one(str(last["item"]))
	var cls := str((caster.spellcasting[0] as Dictionary).get("class_id", "")) if not caster.spellcasting.is_empty() else ""
	var casting := Compendium.shared().class_data(cls).get("spellcasting", {}) as Dictionary
	var n := maxi(1, caster.ability_mod(StringName(str(casting.get("ability", "int")).to_lower().substr(0, 3))))
	caster.add_item(potion, n)
	st.flags[CAULDRON_KEY] = {"who": caster.id, "item": potion, "qty": n}
	return "%s's cauldron bubbles: %d %s%s, ready in the pack." % [caster.name.get_slice(" ", 0), n,
		Compendium.shared().display_name("items", potion), "" if n == 1 else " (x%d)" % n]


## Heroes' Feast (2024): everyone alive in the party eats, and for 24 hours is free of poison, has Resistance to Poison
## damage and immunity to the Poisoned and Frightened conditions, has Advantage on Wisdom saving throws (the 2014 spell's;
## the owner kept it, 2026-10-18) and gains 2d10 to their Hit Point maximum and as many Hit Points.
static func _feast(st: StoryState, caster: Character) -> String:
	var dice := DiceRoller.new(st.playthrough_seed + st.total_minutes())
	var fed: Array[String] = []
	for ch in st.party:
		if ch.dead:
			continue
		for old: Effect in ch.effects.duplicate():
			if old.source_id == "heroes_feast":
				ch.remove_effect(old)
		var gain := int(dice.roll_expr("2d10", "Heroes' Feast (%s)" % ch.name)["total"])
		var fx := Effect.new("Heroes' Feast", &"spell", "heroes_feast").with_modifier("hp_max", {"value": gain}) \
			.with_modifier("resistance", {"value": "poison"}).with_modifier("condition_immunity", {"value": "poisoned"}) \
			.with_modifier("condition_immunity", {"value": "frightened"}).with_modifier("advantage", {"on": "save:wis"})
		fx.ends = Effect.Ends.MINUTES
		fx.minutes_left = 24 * 60
		ch.add_effect(fx)
		Services.cure(ch, &"poisoned")
		Services.cure(ch, &"frightened")
		ch.heal(gain, "Heroes' Feast")
		fed.append("%s +%d" % [ch.name.get_slice(" ", 0), gain])
	return "%s lays out Heroes' Feast. For a day the party resists poison damage, can't be poisoned or frightened and keeps its wits (Hit Point maximum: %s)." % [
		caster.name.get_slice(" ", 0), ", ".join(fed)]


## Who has eaten at Heroes' Feast and what each gained, read from the effect they carry: ["Ilse +12", ...] (the Hit
## Points and the maximum rose by that much). The world's toast and Narrator note tell it (LocationMagic).
static func feast_shares(party: Array[Character]) -> Array[String]:
	var out: Array[String] = []
	for ch in party:
		for fx: Effect in ch.effects:
			if fx.source_id == "heroes_feast" and not fx.modifiers.is_empty():
				out.append("%s +%d" % [ch.name.get_slice(" ", 0), fx.modifiers[0].number("value")])
				break
	return out


## Casts an exploring spell from a Spell Scroll (story/field_items.gd): no slot and no preparation, in the spell's own
## casting time. The scroll's own rules (the class list, the check for a level above the reader's) come first, there.
static func cast_from_scroll(st: StoryState, caster: Character, spell_id: String) -> Dictionary:
	if Wards.antimagic_notice(st) != "":
		return {"ok": false, "text": Wards.antimagic_notice(st)}
	var data := Compendium.shared().spell_data(spell_id)
	if data.is_empty():
		return {"ok": false, "text": "Unknown spell"}
	var r := _take_effect(st, caster, spell_id, data, false, true)
	r["text"] = "%s reads the scroll aloud and casts %s." % [caster.name.get_slice(" ", 0), data["name"]]
	return r
