class_name SpellCounters
extends RefCounted
## The Counterspell chain (2024 PHB, Counterspell). A creature casting a spell with Verbal, Somatic or Material
## components can be Counterspelled by anyone who sees it within 60 ft, and Counterspell is such a spell itself, so it
## can be Counterspelled in turn by another creature that still has its Reaction and a slot (or a free casting) for it,
## and so on. Each Counterspell spends its Reaction when it is cast, and its slot only if it isn't countered itself
## ("if the spell was cast with a spell slot, that slot isn't expended"). When no one answers any more the chain resolves
## from the last Counterspell back: the creature each one targets makes a Constitution save against its caster's spell
## save DC, and on a failure what it was casting dissipates (a Counterspell fizzles, so the one before it stands; the
## spell itself is lost with its action spent and its slot kept).
##
## The foes the AI plays answer whenever they can (SpellReactions: a levelled spell is worth a Counterspell, and a
## Counterspell is a level 3 spell). The heroes and guests the player runs are asked on the usual Reaction prompt, whose
## text says what each side's save is and its odds; the slot to pay with is a pick when there are several ways, and an
## Automatic rule still asks then. They are asked about a Counterspell aimed at their side's casting and about any levelled
## spell a foe casts, a stat block's Spellcasting included (Ashwin, 2026-10-24: Baba Lysaga's and Strahd's Fireball).

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func _rs() -> SpellReactions:
	return enc().spells.reaction_spells


## `c` is casting `s` (`seen`: with components left to see) and `proceed` would pay for it and resolve it. A foe the
## AI plays may Counterspell it, and the chain goes from there: the result of `proceed` when the spell goes ahead,
## CombatResult.new() when it dissipates (the action is spent, the slot kept), or a paused result while a player is
## asked about a Counterspell.
func run(c: Combatant, s: Dictionary, seen: bool, proceed: Callable) -> CombatResult:
	if not seen or int(s.get("level", 0)) < 1:
		return proceed.call() as CombatResult
	var chain: Array[Dictionary] = []
	var first := _ai_answer(c)
	while first != null and not _declare(chain, first, c, c, s, 0):
		first = _ai_answer(c)   # its casting was stopped (the Reaction is spent): the next foe
	if chain.is_empty():
		return _ask_heroes(c, s, proceed)
	return _answered(chain, c, s, proceed, CombatResult.new())


## `c`, a foe the AI plays, casts `s`: each hero or guest who sees it within 60 ft and could Counterspell it is asked, one
## after another. The first yes opens the chain (the foes may answer that Counterspell: _answered); all no's let the
## spell go ahead.
func _ask_heroes(c: Combatant, s: Dictionary, proceed: Callable) -> CombatResult:
	if c.is_player_controlled():
		return proceed.call() as CombatResult
	var chain: Array[Dictionary] = []
	var r := CombatResult.new()
	var offers: Array = []
	for h in _player_answers(c):
		offers.append(_first_offer(chain, h, c, s, proceed, r))
	if offers.is_empty():
		return proceed.call() as CombatResult
	return enc().reactions.offer(offers, func() -> CombatResult: return _resolve(chain, c, s, proceed), r)


## `h`'s offer to Counterspell `c`'s spell `s` itself (the first step of a chain, which `chain` is still empty of).
func _first_offer(chain: Array[Dictionary], h: Combatant, c: Combatant, s: Dictionary, proceed: Callable, r: CombatResult) -> Dictionary:
	var picks := _pay_choices(h)
	var pick := {"slot": 0}
	var offer := {"kind": "counterspell", "reactor": h, "trigger": c.id, "title": "Reaction: Counterspell?",
		"text": func() -> String: return _first_text(h, c, s),
		"cost": func() -> String: return _cost_text(h, picks),
		"target_choices": picks, "ways": func() -> int: return maxi(1, picks.size()),
		"still": func() -> bool: return chain.is_empty() and _rs().can_cast_reaction(h, "counterspell") and enc().distance(h, c) <= 60 and enc().can_see(h, c),
		"select": func(picked: Array) -> void: pick["slot"] = (-1 if str(picked[0]) == "free" else int(str(picked[0]))) if not picked.is_empty() else 0,
		"use": func() -> void: _declare(chain, h, c, c, s, int(pick["slot"])),
		"stop": func() -> CombatResult: return _answered(chain, c, s, proceed, r),
		"stop_if": func() -> bool: return not chain.is_empty() and chain.back()["caster"] == h}
	if not picks.is_empty():
		offer["selected_ids"] = [str(picks[0]["id"])]
		offer["min_targets"] = 1
		offer["max_targets"] = 1
	return offer


## The creature the AI plays that would Counterspell `caster` now: hostile to it, seeing it within 60 ft, with its
## Reaction and a casting left and its rule not Off. Null for none.
func _ai_answer(caster: Combatant) -> Combatant:
	var e := enc()
	for o in e.living():
		if o == caster or o.is_player_controlled() or not o.hostile_to(caster) or e.distance(o, caster) > 60 or not e.can_see(o, caster):
			continue
		if _rs().can_cast_reaction(o, "counterspell") and e._reaction_decision(o, "counterspell") != "never":
			return o
	return null


## The heroes and guests who could Counterspell `caster`'s Counterspell now.
func _player_answers(caster: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for o in e.living():
		if o == caster or not o.is_player_controlled() or not o.hostile_to(caster) or e.distance(o, caster) > 60 or not e.can_see(o, caster):
			continue
		if _rs().can_cast_reaction(o, "counterspell") and e._reaction_decision(o, "counterspell") != "never":
			out.append(o)
	return out


## `caster` casts Counterspell at `target` (the creature whose casting it stops: the spell's caster, or the caster of the
## Counterspell before it in `chain`): its Reaction goes now, a use of a free casting or a monster's use too, a slot only
## when the step stands (`slot` is the level that will be spent). False when its casting was stopped (Reaction spent).
func _declare(chain: Array[Dictionary], caster: Combatant, target: Combatant, c: Combatant, s: Dictionary, slot_choice: int) -> bool:
	var e := enc()
	caster.reaction_available = false
	if not e.spells.casting_gate(caster):
		return false
	var paid := _rs().pay(caster, "counterspell", slot_choice, true)
	chain.append({"caster": caster, "target": target, "dc": _rs().reaction_dc(caster, "counterspell"), "level": int(paid["level"]),
		"slot": int(paid["level"]) if bool(paid.get("deferred", false)) else 0, "countered": false})
	var what := "" if chain.size() == 1 else " (to stop its Counterspell of %s's %s)" % [c.name(), s["name"]] if chain.size() == 2 \
		else " (to stop %s's Counterspell)" % target.name()
	e.log.add("spell", "%s casts Counterspell at %s%s" % [caster.name(), target.name(), what], caster.id)
	e.events.append({"type": "spell", "caster": caster.id, "spell": "counterspell", "cells": [], "targets": [target.id]})
	if caster.is_player_controlled():
		e.spells.trigger_ends(caster, "cast_spell")
	return true


## The chain so far has `chain.back()` as its last Counterspell: whoever is hostile to its caster may Counterspell it. The
## AI answers at once; the player is asked (an answer extends the chain, a refusal or no one able ends it).
func _answered(chain: Array[Dictionary], c: Combatant, s: Dictionary, proceed: Callable, r: CombatResult) -> CombatResult:
	var last := chain.back() as Dictionary
	var d := last["caster"] as Combatant
	if d.is_player_controlled():
		var o := _ai_answer(d)
		while o != null:
			if _declare(chain, o, d, c, s, 0):
				return _answered(chain, c, s, proceed, r)
			o = _ai_answer(d)
		return _resolve(chain, c, s, proceed)
	var offers: Array = []
	for h in _player_answers(d):
		offers.append(_offer(chain, h, d, c, s, proceed, r))
	return enc().reactions.offer(offers, func() -> CombatResult: return _resolve(chain, c, s, proceed), r)


## `h`'s offer to Counterspell `d`'s Counterspell (the last in `chain`).
func _offer(chain: Array[Dictionary], h: Combatant, d: Combatant, c: Combatant, s: Dictionary, proceed: Callable, r: CombatResult) -> Dictionary:
	var picks := _pay_choices(h)
	var pick := {"slot": 0}
	var offer := {"kind": "counterspell", "reactor": h, "trigger": d.id, "title": "Reaction: Counterspell?",
		"text": func() -> String: return _prompt_text(chain, h, d, c, s),
		"cost": func() -> String: return _cost_text(h, picks),
		"target_choices": picks, "ways": func() -> int: return maxi(1, picks.size()),
		"still": func() -> bool: return _rs().can_cast_reaction(h, "counterspell") and enc().distance(h, d) <= 60 and enc().can_see(h, d),
		"select": func(picked: Array) -> void: pick["slot"] = (-1 if str(picked[0]) == "free" else int(str(picked[0]))) if not picked.is_empty() else 0,
		"use": func() -> void: _declare(chain, h, d, c, s, int(pick["slot"])),
		"stop": func() -> CombatResult: return _answered(chain, c, s, proceed, r),
		"stop_if": func() -> bool: return chain.back()["caster"] == h}
	if not picks.is_empty():
		offer["selected_ids"] = [str(picks[0]["id"])]
		offer["min_targets"] = 1
		offer["max_targets"] = 1
	return offer


## The ways `h` could pay for Counterspell when there is more than one: each slot level from the third up and a free
## casting left (first, unless it waits for the pact slots, as Hellish Rebuke's prompt lists them). Empty for one way.
func _pay_choices(h: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := h.creature as Character
	if ch == null:
		return out
	var rs := _rs()
	var levels := SpellReactions.slot_levels(ch, 3)
	var free := rs.free_casting(h, "counterspell")
	if levels.size() + (1 if free else 0) <= 1:
		return out
	var pact := int(ch.pact_magic()["level"])
	for l in levels:
		out.append({"id": str(l), "label": "Level %d slot%s" % [l, " (Pact Magic)" if l == pact else ""]})
	if free:
		var entry := {"id": "free", "label": "Free casting, no slot"}
		if rs.free_first(h, "counterspell"):
			out.push_front(entry)
		else:
			out.append(entry)
	return out


func _cost_text(h: Combatant, picks: Array[Dictionary]) -> String:
	if not picks.is_empty():
		return "Reaction and the casting you choose" if str(picks[0]["id"]) == "free" or picks.any(func(p: Dictionary) -> bool: return str(p["id"]) == "free") \
			else "Reaction and the spell slot you choose"
	var ch := h.creature as Character
	if ch != null and SpellReactions.slot_levels(ch, 3).is_empty() and _rs().free_casting(h, "counterspell"):
		return "Reaction and its free casting (no spell slot)"
	return "Reaction and a spell slot (kept if this Counterspell is countered)"


## What the prompt says: the Counterspell that is about to resolve, the spell it would stop, the odds of the save it asks
## for, and what `h`'s own Counterspell would do.
func _prompt_text(chain: Array[Dictionary], h: Combatant, d: Combatant, c: Combatant, s: Dictionary) -> String:
	var last := chain.back() as Dictionary
	var t := last["target"] as Combatant
	var what := "%s's %s" % [c.name(), s["name"]] if chain.size() == 1 else "%s's Counterspell" % t.name()
	var back := "goes ahead" if chain.size() == 1 else "stands"
	return "%s casts Counterspell at %s: unless %s's Constitution save holds (%s), %s dissipates. Counterspell it? %s's save would be against DC %d (%s); on a failure the Counterspell fizzles, its slot is kept, and %s %s." \
		% [d.name(), t.name(), t.name(), _odds(t, int(last["dc"])), what, d.name(), _rs().reaction_dc(h, "counterspell"), _odds(d, _rs().reaction_dc(h, "counterspell")), what, back]


## What the prompt says for a foe's own spell: who casts it, the odds of the save it asks for, and what happens to it.
func _first_text(h: Combatant, c: Combatant, s: Dictionary) -> String:
	var dc := _rs().reaction_dc(h, "counterspell")
	return "%s casts %s. Counterspell it? Unless %s's Constitution save holds (%s), the spell dissipates: its action is spent and its slot kept. If a foe Counterspells yours, it fizzles and your slot is kept." \
		% [c.name(), s["name"], c.name(), _odds(c, dc)]


## "+2 against DC 15, 40% to fail": a Constitution save of `who` against `dc`.
func _odds(who: Combatant, dc: int) -> String:
	var bonus := who.creature.save_bonus(&"con").total()
	var fail := roundi(clampf((dc - bonus - 1) / 20.0, 0.0, 1.0) * 100.0)
	return "%+d against DC %d, %d%% to fail" % [bonus, dc, fail]


## The chain resolved from its last Counterspell back (see the class note). `proceed` when the spell goes ahead.
func _resolve(chain: Array[Dictionary], c: Combatant, s: Dictionary, proceed: Callable) -> CombatResult:
	var e := enc()
	for i in range(chain.size() - 1, -1, -1):
		var step := chain[i]
		if bool(step["countered"]):
			continue
		var d := step["caster"] as Combatant
		var t := step["target"] as Combatant
		# It stands, so its slot goes now.
		if int(step["slot"]) > 0 and d.creature is Character:
			(d.creature as Character).expend_slot(int(step["slot"]))
		var test := t.creature.roll_save(e.dice, &"con", int(step["dc"]), [], [], "Constitution save vs Counterspell (%s)" % t.name(),
			SpellCaster.spell_save_keys(d.id))
		var what := "%s's %s" % [t.name(), s["name"]] if i == 0 else "%s's Counterspell" % t.name()
		if test.success:
			e.log.add("save", "%s gets through the Counterspell" % what if i == 0 else "%s holds against %s's Counterspell" % [what, d.name()], t.id, [test.describe()])
			continue
		if i == 0:
			e.log.add("spell", "%s dissipates (Counterspell): the action is spent, the spell slot kept" % what, t.id, [test.describe()])
			return CombatResult.new()
		(chain[i - 1])["countered"] = true
		e.log.add("spell", "%s fizzles (countered by %s): its Reaction is spent, its slot kept" % [what, d.name()], t.id, [test.describe()])
	return proceed.call() as CombatResult
