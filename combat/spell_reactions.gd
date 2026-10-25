class_name SpellReactions
extends RefCounted
## Spells cast as a Reaction in a fight (SpellCaster): Shield, Counterspell, Hellish Rebuke and the like, spells that
## answer a d20 roll (Silvery Barbs), whether a creature can react at all, and releasing a readied spell.

var _enc: WeakRef
## The Counterspell chain (a Counterspell can be Counterspelled in turn).
var counters: SpellCounters


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	counters = SpellCounters.new(encounter)


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
## `defer_slot`: a slot is only chosen, not spent (`deferred` in the result): a Counterspell's slot goes only if it isn't
## countered itself (SpellCounters).
func pay(c: Combatant, spell_id: String, slot_choice: int = 0, defer_slot: bool = false) -> Dictionary:
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
	if defer_slot:
		return {"level": slot, "free": false, "deferred": true}
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


## `c` casts `s`: the Counterspells it may meet, and the chain they make (SpellCounters.run). `proceed` is the rest of the
## cast, run when nothing stops it.
func counter_chain(c: Combatant, s: Dictionary, seen: bool, proceed: Callable) -> CombatResult:
	return counters.run(c, s, seen, proceed)


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
## of an action aimed at `target` alone (every dart or ray of a spell that has several), spending its lowest slot. A spell
## of beams (Eldritch Blast) sends one beam, whatever the caster's level (SpellSpecials.REACTION_BEAMS).
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
	var beam_note := spells.specials.reaction_beam_note(c, s)
	e.log.add("spell", "%s answers with %s (War Caster%s%s)" % [c.name(), s["name"], ", level %d slot" % slot if slot > 0 else "",
		", " + beam_note if beam_note != "" else ""], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": [], "targets": [target.id]})
	spells.trigger_ends(c, "cast_spell")
	var ctx := {"c": c, "s": s, "slot": maxi(slot, level), "nums": spells.numbers(c, entry), "conc": conc, "opts": {}, "point": e.center_of(target),
		"cells": [], "choice": SpellCaster.choice_of(s, {}), "direction": (e.center_of(target) - e.center_of(c)).normalized(), "cell": target.cell}
	if beam_note != "":
		ctx["beam_cap"] = SpellSpecials.REACTION_BEAMS
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


# --- Absorb Elements (Xanathar's) --------------------------------------------------------------------

## The five damage types Absorb Elements answers.
const ABSORB_TYPES := ["acid", "cold", "fire", "lightning", "thunder"]


## Whether `c` can answer damage with Absorb Elements now: a hero or guest the player runs that knows it and has a
## Reaction and a slot (or a free casting). Foes never cast it (docs/rules/deviations.md): no stat block lists it, and
## the AI has no rule for when it is worth a slot.
func absorb_ready(c: Combatant) -> bool:
	return c.creature is Character and c.is_player_controlled() and can_cast_reaction(c, "absorb_elements")


## The type Absorb Elements would answer in `amounts` (damage type -> amount): the biggest of its five that `c` neither
## resists nor is immune to, or "" when there is none (a resistance already in force makes the spell pointless).
func absorb_type(c: Combatant, amounts: Dictionary) -> String:
	var best := ""
	for ty: String in ABSORB_TYPES:
		var amount := int(amounts.get(ty, 0))
		if amount <= 0 or c.creature.resistance_source(StringName(ty)) != "" or c.creature.immunity_source(StringName(ty)) != "":
			continue
		if best == "" or amount > int(amounts[best]):
			best = ty
	return best


## Damage given as a packet list ({amount, type}) as a type -> amount dictionary.
static func amounts_of(parts: Array) -> Dictionary:
	var out := {}
	for p: Variant in parts:
		var d := p as Dictionary
		out[str(d["type"])] = int(out.get(str(d["type"]), 0)) + maxi(0, int(d["amount"]))
	return out


## How many ways `c` could pay for the Reaction spell `spell_id` now: each slot level and a free casting left.
func payment_ways(c: Combatant, spell_id: String) -> int:
	var ch := c.creature as Character
	if ch == null:
		return 0
	var level := maxi(1, int(_comp().spell_data(spell_id).get("level", 1)))
	return slot_levels(ch, level).size() + (1 if free_casting(c, spell_id) else 0)


## A prompt's payment picks for the Reaction spell `spell_id`, the way Hellish Rebuke's list them (one per slot level, a
## warlock's pact level named, the free casting first unless it waits for the pact slots): {cost, choices, selected}.
## `describe` is given the level a casting is made at and returns what it does. With a single way to pay there is no
## pick, only the cost.
func payment_prompt(c: Combatant, spell_id: String, describe: Callable) -> Dictionary:
	var ch := c.creature as Character
	var out := {"cost": "Reaction and a spell slot", "choices": [] as Array[Dictionary], "selected": [] as Array[String]}
	if ch == null:
		return out
	var from := maxi(1, int(_comp().spell_data(spell_id).get("level", 1)))
	var levels := slot_levels(ch, from)
	var free_at := free_level(c, spell_id) if free_casting(c, spell_id) else 0
	if levels.is_empty() and free_at == 0:
		return out
	var pact := int(ch.pact_magic()["level"])
	if levels.is_empty():
		out["cost"] = "Reaction and its free casting (no spell slot)"
		return out
	if levels.size() == 1 and free_at == 0:
		out["cost"] = "Reaction and a level %d spell slot%s" % [levels[0], " (Pact Magic)" if levels[0] == pact else ""]
		return out
	out["cost"] = "Reaction and the casting you choose" if free_at > 0 else "Reaction and the spell slot you choose"
	var choices: Array[Dictionary] = []
	for l in levels:
		choices.append({"id": str(l), "label": "Level %d slot%s · %s" % [l, " (Pact Magic)" if l == pact else "", describe.call(l)]})
	if free_at > 0:
		var free := {"id": "free", "label": "Free casting, no slot · %s" % describe.call(free_at)}
		if free_first(c, spell_id):
			choices.push_front(free)
		else:
			choices.append(free)
	out["choices"] = choices
	out["selected"] = [str(choices[0]["id"])] as Array[String]
	return out


## Absorb Elements on the reaction prompt for damage aimed at `target` (an attack's, `parts`: type -> amount, cut as the
## offers before it cut it): Resistance to the biggest of its types for the blow itself and to the start of its next
## turn, and the same type stored for its next melee hit. `responded` learns it was offered, so the damage that follows
## doesn't act on it again (absorb_synchronous).
func absorb_offers(target: Combatant, source: Combatant, parts: Dictionary, responded: Array) -> Array:
	var ty := absorb_type(target, parts)
	if ty == "" or not absorb_ready(target):
		return []
	responded.append("absorb_elements")
	var prompt := payment_prompt(target, "absorb_elements", func(level: int) -> String: return "%dd6 %s stored" % [level, ty.capitalize()])
	var pick := {"slot": 0}
	return [{"kind": "absorb_elements", "reactor": target, "trigger": source.id if source != null else "", "title": "Reaction: Absorb Elements?",
		"text": "%s takes %d %s damage. Absorb Elements: Resistance to %s until your next turn, the blow included, and your next melee hit deals extra %s damage." \
			% [target.name(), int(parts[ty]), ty.capitalize(), ty.capitalize(), ty.capitalize()],
		"cost": prompt["cost"], "target_choices": prompt["choices"], "selected_ids": prompt["selected"],
		"min_targets": 1 if not (prompt["choices"] as Array).is_empty() else 0, "max_targets": 1 if not (prompt["choices"] as Array).is_empty() else 0,
		# A hero on Automatic is still asked when there are several ways to cast it (Hellish Rebuke's rule).
		"several_ways": func() -> bool: return payment_ways(target, "absorb_elements") > 1,
		"still": func() -> bool: return absorb_ready(target) and absorb_type(target, parts) == ty,
		"select": func(ids: Array[String]) -> void:
			if not ids.is_empty():
				pick["slot"] = -1 if ids[0] == "free" else int(ids[0]),
		"use": func() -> void: cast_absorb_elements(target, ty, int(pick["slot"]))}]


## The damage a saving throw has left for `target` (`parts`: a breath's or a spell's, whole after a failed save, half after a
## passed one; none left, none to ask about): Absorb Elements is offered on the usual Reaction prompt before it lands, a
## passed save that still deals damage included (Ashwin, 2026-10-24: it must ask, and never fire by itself). `go` deals the
## damage and is given the Reactions already answered, to hand to deal_damage so the blow doesn't act on Absorb Elements'
## rule a second time. `pausable` false (a caller that can't wait) goes straight to `go`.
func absorb_before_save_damage(target: Combatant, source: Combatant, parts: Array, go: Callable, r: CombatResult, pausable: bool) -> CombatResult:
	var responded: Array = []
	if pausable:
		var offers := absorb_offers(target, source, amounts_of(parts), responded)
		if not offers.is_empty():
			return enc().reactions.offer(offers, func() -> CombatResult: return go.call(responded) as CombatResult, r)
	return go.call(responded) as CombatResult


## Damage that can't pause (a spell's attack, hazards, zones): Absorb Elements is cast only on Automatic, at the casting Hellish Rebuke's
## rule would pay with (a free casting first unless it waits for the pact slots, else the lowest slot).
func absorb_synchronous(target: Combatant, parts: Array, resolved: Array) -> void:
	if "absorb_elements" in resolved or not target.creature is Character or str(target.reaction_rules.get("absorb_elements", "ask")) != "auto":
		return
	if not absorb_ready(target):
		return
	var ty := absorb_type(target, amounts_of(parts))
	if ty != "":
		cast_absorb_elements(target, ty)


## Casts Absorb Elements as `c`'s Reaction against `ty` damage: the Reaction and a slot (`slot_choice`, what its prompt
## picked: pay) are spent, Resistance to `ty` lasts until the start of `c`'s next turn, and 1d6 of `ty` a slot level
## waits for its next melee hit, to the end of its next turn.
func cast_absorb_elements(c: Combatant, ty: String, slot_choice: int = 0) -> bool:
	var e := enc()
	if not can_cast_reaction(c, "absorb_elements"):
		return false
	c.reaction_available = false
	if not sp().casting_gate(c):
		return false
	var paid := pay(c, "absorb_elements", slot_choice)
	var level := maxi(1, int(paid["level"]))
	var ward := Effect.new("Absorb Elements (%s)" % ty.capitalize(), &"spell", "absorb_elements").with_modifier("resistance", {"value": ty})
	ward.caster_id = c.id
	ward.spell_level = level
	ward.stack_key = "spell:absorb_elements:ward"
	ward.ends = Effect.Ends.START_OF_TURN
	ward.turn_owner_id = c.id
	c.creature.add_effect(ward)
	var stored := Effect.new("Absorb Elements (stored %s)" % ty.capitalize(), &"spell", "absorb_elements") \
		.with_modifier("extra_damage", {"dice": "%dd6" % level, "type": ty, "on": "first_melee"})
	stored.caster_id = c.id
	stored.spell_level = level
	stored.stack_key = "spell:absorb_elements:stored"
	stored.ends = Effect.Ends.END_OF_TURN
	stored.turn_owner_id = c.id
	stored.skip_turn_ends = e.own_turn_skip(c)
	stored.data["await_owner_start"] = true   # idle until the start of its next turn (Effect.on_turn_start)
	c.creature.add_effect(stored)
	sp().trigger_ends(c, "cast_spell")
	e.log.add("spell", "%s casts Absorb Elements (%s; Resistance to %s until its next turn, %dd6 stored for its next melee hit)" \
		% [c.name(), "free casting" if bool(paid["free"]) else "level %d slot" % level, ty.capitalize(), level], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": "absorb_elements", "cells": [], "targets": [c.id]})
	return true


## A melee hit uses up the charge Absorb Elements stored (`m`, its extra_damage modifier): the spell ends.
func spend_stored_charge(c: Combatant, m: Modifier) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if m in fx.modifiers:
			c.creature.remove_effect(fx)
			enc().log.add("info", "%s's stored %s is spent (Absorb Elements ends)" % [c.name(), str(m.data.get("type", "")).capitalize()], c.id)
