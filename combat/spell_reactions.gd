class_name SpellReactions
extends RefCounted
## Spells cast as a Reaction in a fight (SpellCaster): Shield, Counterspell, Hellish Rebuke and the like, spells that
## answer a d20 roll (Silvery Barbs), whether a creature can react at all, and releasing a readied spell.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Begin a reaction spell without assuming its result (casting disruption can consume only the Reaction).
func begin_reaction_spell(c: Combatant, spell_id: String) -> bool:
	var spells := sp()
	if not can_cast_reaction(c, spell_id):
		return false
	c.reaction_available = false
	if not spells.casting_gate(c):
		return false
	var s := _comp().spell_data(spell_id)
	var paid := pay(c, spell_id)
	spells.trigger_ends(c, "cast_spell")
	enc().log.add("spell", "%s casts %s%s" % [c.name(), s["name"], " (free casting)" if bool(paid["free"]) else ""], c.id)
	return true


## Whether `c` has a free casting of `spell_id` left (a species' or a feat's spell, once a Long Rest without a slot). A
## Reaction spell cast that way is still a Reaction (2024; coordinator relay 2026-10-13: Kip's tiefling Hellish Rebuke
## was never cast once his pact slots were gone).
func free_casting(c: Combatant, spell_id: String) -> bool:
	var ch := sp().caster_char(c)
	return ch != null and ch.resource_left("spell:%s" % spell_id) > 0


## Pays for the Reaction spell `spell_id`: `slot_choice`, what its prompt picked (a slot level, or -1 for the free
## casting), else the free casting when one is left, else the lowest slot. As anywhere else (FieldCasting._offer), a
## warlock's free casting below its pact level waits until the pact slots are spent. A slot spent on a Reaction isn't
## the turn's slot spell (owner, 2026-10-13: Reactions don't count towards the one spell slot a turn), so it leaves
## cast_slot_spell_this_turn alone. {level: the level it's cast at, 0 when nothing paid; free: a free casting}.
func pay(c: Combatant, spell_id: String, slot_choice: int = 0) -> Dictionary:
	var ch := sp().caster_char(c)
	if ch == null:
		return {"level": enc().monster_actions.spend_reaction_spell(c, spell_id), "free": false}
	var level := maxi(1, int(_comp().spell_data(spell_id).get("level", 1)))
	var levels := slot_levels(ch, level)
	if free_casting(c, spell_id) and (slot_choice == -1 or not slot_choice in levels) and (slot_choice == -1 or free_first(c, spell_id)):
		ch.spend_resource("spell:%s" % spell_id)
		return {"level": free_level(c, spell_id), "free": true}
	var slot := slot_choice if slot_choice in levels else _lowest_slot(ch, level)
	if slot == 0:
		return {"level": 0, "free": false}
	ch.expend_slot(slot)
	return {"level": slot, "free": false}


## The level a free casting of `spell_id` is cast at: its own, or higher for a feature that says so (Genie Magic).
func free_level(c: Combatant, spell_id: String) -> int:
	return maxi(maxi(1, int(_comp().spell_data(spell_id).get("level", 1))), int(sp()._entry_any(c, spell_id).get("free_slot", 0)))


## Whether `c`'s free casting of `spell_id` goes before its slots: yes, unless only a Pact Magic slot of a higher level
## could pay and one is left (a tiefling warlock's level 1 Hellish Rebuke waits for the pact slots, as FieldCasting
## offers it).
func free_first(c: Combatant, spell_id: String) -> bool:
	var ch := sp().caster_char(c)
	if ch == null:
		return true
	var pact_at := ch.pact_only_level(maxi(1, int(_comp().spell_data(spell_id).get("level", 1))))
	return pact_at == 0 or free_level(c, spell_id) >= pact_at


## Reaction spells that answer a failed d20 roll (Reweave Fate: the roll again with Advantage; Moment of Prescience: a
## 20), settled now: only when the creature's rule for the spell is Automatic.
func after_failed_d20(roller: Combatant, test: D20Test) -> void:
	var out: Array = []
	d20_offers(roller, test, out)
	enc().d20.run_now(out)


## The same as offers (D20Responses): asked about where the roll can pause.
func d20_offers(roller: Combatant, test: D20Test, out: Array) -> void:
	var spells := sp()
	var e := enc()
	if test.target <= 0 or test.auto_failed:
		return
	for c in e.living():
		var ch := spells.caster_char(c)
		if ch == null or (c != roller and not c.allied_with(roller)):
			continue
		for known in ch.known_spells():
			var s := _comp().spell_data(str(known["id"]))
			var response := s.get("roll_response", {}) as Dictionary
			if response.is_empty() or (str(response.get("scope", "self")) == "self" and c != roller):
				continue
			var visible := str(response.get("scope", "self")) == "visible"
			var caster := c
			var sid := str(s["id"])
			var sname := str(s["name"])
			out.append({"kind": sid, "reactor": c, "trigger": roller.id, "sync": "decision", "title": "Reaction: %s?" % sname,
				"text": func() -> String: return "%s. %s %s?" % [D20Responses.line(roller, test), caster.name() + " can cast " + sname if caster != roller else "Cast " + sname,
					"so the roll is a 20" if response.has("natural") else "so it's rolled again with Advantage"],
				"cost": "Reaction and a spell slot",
				"still": func() -> bool: return not test.success and can_cast_reaction(caster, sid) \
					and (not visible or (e.distance(caster, roller) <= spells.range_ft(s, caster) and e.can_see(caster, roller))),
				"helps": func() -> bool: return D20Responses.could_reach(test, int(response.get("natural", 20))),
				"use": func() -> void:
					if not begin_reaction_spell(caster, sid):
						return
					if response.has("natural"):
						test.set_natural(int(response["natural"]), sname)
					else:
						test.reroll(e.dice, sname, true)
					if test.success and response.has("success_temp_hp"):
						roller.creature.add_temp_hp(int(e.dice.roll_expr(str(response["success_temp_hp"]), sname)["total"]), sname)
					e.log.add("save", test.describe(), roller.id)})


## Spell attack resolution is synchronous; weapon/monster attacks offer the same response interactively.
func answer_incoming_roll(c: Combatant, test: D20Test, spell_id: String) -> bool:
	if not test.success or not begin_reaction_spell(c, spell_id):
		return false
	var s := _comp().spell_data(spell_id)
	test.set_natural(int((s["roll_response"] as Dictionary)["incoming_natural"]), str(s["name"]))
	return not test.success


func incoming_roll_responses(c: Combatant) -> Array[String]:
	var spells := sp()
	var out: Array[String] = []
	if spells.caster_char(c) == null:
		return out
	for known in spells.caster_char(c).known_spells():
		var id := str(known["id"])
		if not id in out and (_comp().spell_data(id).get("roll_response", {}) as Dictionary).has("incoming_natural") and can_cast_reaction(c, id):
			out.append(id)
	return out


## Whether `c` can cast `spell_id` as a Reaction now: its slots or a free casting, whatever it cast earlier in the turn.
## Reactions don't count towards the one spell slot a turn (owner, 2026-10-13: Ratatouille cast a level 3 spell on his
## turn, then wasn't asked about Shield when an Opportunity Attack hit him on the way out).
## A monster casts one from its stat block: a use of its Spellcasting or a Reaction that casts it (the mage's Protective
## Magic; MonsterActions.reaction_spell_source).
func can_cast_reaction(c: Combatant, spell_id: String) -> bool:
	var spells := sp()
	if not can_react(c):
		return false
	var ch := spells.caster_char(c)
	var s := _comp().spell_data(spell_id)
	if ch == null:
		return c.creature is Monster and str(s.get("automation", "")) != "reference" and _voice_ok(c, s) \
			and enc().monster_actions.reaction_spell_source(c, spell_id) != ""
	if not ch.knows_spell(spell_id):
		return false
	var free := free_casting(c, spell_id)
	if str(s.get("automation", "")) == "reference" or c.creature.has_flag("cant_cast") or spells.specials.high.in_antimagic(c):
		return false
	if not _voice_ok(c, s):
		return false
	if ch.armor_cast_blocker() != "":
		return false
	if free:
		return true
	var level := int(s.get("level", 1))
	for l in range(level, 10):
		if ch.slots_left(l) > 0:
			return true
	return false


## Whether `c` can give spell `s` its Verbal component: not speechless, not in Silence.
func _voice_ok(c: Combatant, s: Dictionary) -> bool:
	if not bool((s.get("components", {}) as Dictionary).get("v", false)):
		return true
	if c.creature.has_flag("speechless"):
		return false
	for cell in c.footprint():
		if sp().zones.silenced(cell):
			return false
	return true


## Counterspell (2024) from a creature the AI plays: `c` is casting `s` (`seen`: with Verbal, Somatic or Material
## components left) and a creature hostile to it within 60 ft that sees it can cast Counterspell (a mage's Protective
## Magic, Kasimir's or Mordenkainen's Spellcasting, an enemy wizard's slot). It does when the spell is a levelled one
## (coordinator relay 2026-10-13: foes never cast Shield or Counterspell; the owner's rule is that foes use their spells
## when best). `c` makes a Constitution save against its spell save DC; on a failure the spell dissipates with no
## effect: its action is spent, a slot isn't. Heroes and the guests the player runs don't counter here (asking them
## would have to pause the cast). True when the spell is countered.
func counterspelled(c: Combatant, s: Dictionary, seen: bool = true) -> bool:
	var e := enc()
	if not seen or int(s.get("level", 0)) < 1:
		return false
	for o in e.living():
		if o == c or o.is_player_controlled() or not o.hostile_to(c) or e.distance(o, c) > 60 or not e.can_see(o, c):
			continue
		if not can_cast_reaction(o, "counterspell") or e._reaction_decision(o, "counterspell") == "never":
			continue
		o.reaction_available = false
		if not sp().casting_gate(o):
			continue
		pay(o, "counterspell")
		var dc := reaction_dc(o, "counterspell")
		e.log.add("spell", "%s casts Counterspell at %s" % [o.name(), c.name()], o.id)
		e.events.append({"type": "spell", "caster": o.id, "spell": "counterspell", "cells": [], "targets": [c.id]})
		var test := c.creature.roll_save(e.dice, &"con", dc, [], [], "Constitution save vs Counterspell (%s)" % c.name(), SpellCaster.spell_save_keys(o.id))
		if test.success:
			e.log.add("save", "%s's %s gets through the Counterspell" % [c.name(), s["name"]], c.id, [test.describe()])
			return false
		e.log.add("spell", "%s's %s dissipates (Counterspell): the action is spent, the spell slot kept" % [c.name(), s["name"]], c.id, [test.describe()])
		return true
	return false


## The spell save DC `c` casts the Reaction spell `spell_id` with: its stat block's (a monster) or its class's.
func reaction_dc(c: Combatant, spell_id: String) -> int:
	if sp().caster_char(c) == null:
		return enc().monster_actions.spell_dc(c)
	return (sp().numbers(c, sp()._entry_any(c, spell_id))["dc"] as Breakdown).total()


## Whether `c` can take a Reaction now (it has one, can act, and nothing stops it: Shocking Grasp, Slow).
func can_react(c: Combatant) -> bool:
	return c.reaction_available and c.can_act() and not c.creature.has_flag("no_reactions") and not c.creature.has_flag("slowed") \
		and not enc().has_mark("no_reactions", c.id)


func _lowest_slot(ch: Character, from_level: int) -> int:
	for l in range(from_level, 10):
		if ch.slots_left(l) > 0:
			return l
	return 0


## The slot levels `ch` could spend on a spell of `from_level`, lowest first. A warlock's Pact Magic slots are all of
## its pact level, so a pure warlock has just that one: its spells are always cast at it.
static func slot_levels(ch: Character, from_level: int) -> Array[int]:
	return ch.slot_levels(from_level)


## Shield (2024): +5 AC until the start of your next turn, as a Reaction, with its free casting or a level 1 slot (the
## lowest available). Also stops Magic Missile.
func cast_shield(c: Combatant) -> bool:
	var spells := sp()
	if not can_cast_reaction(c, "shield"):
		return false
	c.reaction_available = false
	if not spells.casting_gate(c):
		return false
	var paid := pay(c, "shield")
	var e := Effect.new("Shield", &"spell", "shield").with_modifier("ac", {"value": 5})
	e.ends = Effect.Ends.START_OF_TURN
	e.turn_owner_id = c.id
	e.spell_level = maxi(1, int(paid["level"]))
	c.creature.add_effect(e)
	enc().log.add("spell", "%s casts Shield (+5 AC until its next turn%s)" % [c.name(), ", free casting" if bool(paid["free"]) else ""], c.id)
	return true


## A reaction spell answering `trigger` (Hellish Rebuke against whoever hurt the caster; Counterspell against a
## caster): the Reaction and a slot or a free casting are spent (`slot_choice`, the level picked on the prompt, else a
## free casting, else the lowest slot; a warlock's is its pact level: pay), then the spell resolves against the trigger
## at that level.
func cast_reaction_spell(c: Combatant, spell_id: String, trigger: Combatant, slot_choice: int = 0) -> CombatResult:
	var spells := sp()
	var e := enc()
	var ch := spells.caster_char(c)
	var s := _comp().spell_data(spell_id)
	if ch == null or not can_react(c) or (_lowest_slot(ch, int(s.get("level", 1))) == 0 and not free_casting(c, spell_id)):
		return CombatResult.new()
	c.reaction_available = false
	if not spells.casting_gate(c):
		return CombatResult.new()
	var paid := pay(c, spell_id, slot_choice)
	var slot := int(paid["level"])
	var entry := spells._entry_any(c, spell_id)
	var nums := spells.numbers(c, entry)
	e.log.add("spell", "%s answers with %s (%s)" % [c.name(), s["name"], "free casting, level %d" % slot if bool(paid["free"]) else "level %d slot" % slot], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": [], "targets": [trigger.id]})
	spells.trigger_ends(c, "cast_spell")
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [trigger]
	return e.then(spells._generic(ctx, tgt, [], r, true), func() -> CombatResult:
		e._check_over()
		return r)


## War Caster's Reactive Spell (2024): with the Reaction, instead of an Opportunity Attack, a spell with a casting time
## of an action aimed at `target` alone (every dart or ray of a spell that has several), spending its lowest slot.
func cast_reactive_spell(c: Combatant, spell_id: String, target: Combatant) -> CombatResult:
	var spells := sp()
	var e := enc()
	var s := _comp().spell_data(spell_id)
	var level := int(s.get("level", 0))
	var ch := spells.caster_char(c)
	var slot := 0
	if level > 0:
		slot = _lowest_slot(ch, level) if ch != null else 0
		if slot == 0:
			return CombatResult.new()
	if not can_react(c):
		return CombatResult.new()
	c.reaction_available = false
	if not spells.casting_gate(c):
		return CombatResult.new()
	if slot > 0:
		ch.expend_slot(slot)   # a Reaction: not the turn's slot spell (pay)
	var used := ch.use_component(s) if ch != null else ""
	if used != "":
		e.log.add("info", "%s uses up %s (%s)" % [c.name(), used, s["name"]], c.id)
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var entry := spells._entry_any(c, spell_id)
	e.log.add("spell", "%s answers with %s (War Caster%s)" % [c.name(), s["name"], ", level %d slot" % slot if slot > 0 else ""], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": [], "targets": [target.id]})
	spells.trigger_ends(c, "cast_spell")
	var ctx := {"c": c, "s": s, "slot": maxi(slot, level), "nums": spells.numbers(c, entry), "conc": conc, "opts": {}, "point": e.center_of(target),
		"cells": [], "choice": SpellCaster.choice_of(s, {}), "direction": (e.center_of(target) - e.center_of(c)).normalized(), "cell": target.cell}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [target]
	var count := int((s.get("targets", {}) as Dictionary).get("count", 1))
	if count > 1 and (spell_id in ["magic_missile", "scorching_ray"] or bool(s.get("repeat_targets", false))):
		for i in count - 1:
			tgt.append(target)
	return e.then(spells._resolve(ctx, tgt, [], r, true), func() -> CombatResult:
		spells.check_tethers()
		spells._finish_concentration(ctx)
		spells.zones.prune()
		e._check_over()
		return r)


## Releases a readied spell at `target` (the creature that triggered it) with the Reaction: its slot was spent when
## it was readied. Areas are centred on (or aimed at) the target.
func release_readied(c: Combatant, held: Dictionary, target: Combatant) -> CombatResult:
	var spells := sp()
	var e := enc()
	var conc := held.get("conc") as Concentration
	if conc != null and conc.ended:
		return CombatResult.new()
	var spell_id := str(held["spell"])
	var s := _comp().spell_data(spell_id)
	c.reaction_available = false
	if conc != null:
		conc.ended = true
		if c.creature.concentration == conc:
			c.creature.concentration = null
	var new_conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		new_conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var entry := spells._entry_any(c, spell_id)
	var point := e.center_of(target)
	var dir := (point - e.center_of(c)).normalized()
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = spells.area_for(c, s, point, dir, int(held["slot"]))
	e.log.add("reaction", "%s releases the readied %s at %s" % [c.name(), s["name"], target.name()], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": [target.id]})
	var ctx := {"c": c, "s": s, "slot": int(held["slot"]), "nums": spells.numbers(c, entry), "conc": new_conc, "opts": {},
		"point": point, "cells": cells, "choice": SpellCaster.choice_of(s, {}), "direction": dir, "cell": target.cell}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [target]
	return e.then(spells._resolve(ctx, tgt, cells, r, true), func() -> CombatResult:
		spells.check_tethers()
		spells._finish_concentration(ctx)
		spells.zones.prune()
		e._check_over()
		return r)
