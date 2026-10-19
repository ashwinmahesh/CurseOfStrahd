class_name SpellAttacks
extends RefCounted
## Spell attacks in a fight (SpellCaster): the shots a spell makes, the pause for reactions before the rolls, the
## attack roll itself, what a hit does, secondary targets (Ice Knife's burst) and Chromatic Orb's leap.

## The prompt (and its Ask / Auto / Never rule) for where a Chromatic Orb leaps.
const ORB_LEAP := "chromatic_orb_leap"

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## The creature each of a spell's attack rolls is made against, in order: one per target, or one per ray or beam
## (Scorching Ray, Eldritch Blast) shared round the targets. A cast that carries a `beam_cap` (a Reaction casting:
## SpellReactions.cast_reactive_spell) sends no more beams than that.
func attack_shots(ctx: Dictionary, tgt: Array[Combatant]) -> Array[Combatant]:
	var spells := sp()
	var s := ctx["s"] as Dictionary
	var count := 1
	var dmg := s.get("damage", []) as Array
	if not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "ray":
		count = spells.target_count(s, int(ctx["slot"]))
	elif not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "beam":
		count = spells.specials.beams(ctx["c"] as Combatant)
		if ctx.has("beam_cap"):
			count = mini(count, int(ctx["beam_cap"]))
	var shots: Array[Combatant] = []
	if count > 1 and not tgt.is_empty():
		for i in count:
			shots.append(tgt[i % tgt.size()])
	else:
		shots.assign(tgt)
	return shots


## Before a spell's attack rolls, the reactions that come before an attack roll (Shadow Martyr, Warding Flare,
## Protection, Lucky against you) are offered for each roll, pausing for a player's answer as a weapon attack does;
## then `go` resolves the spell. Each roll's answers wait in ctx.pre_rolls for spell_attack: the creature the roll is
## now made against and any Advantage or Disadvantage they added.
func _before_attack_rolls(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult, go: Callable) -> CombatResult:
	var s := ctx["s"] as Dictionary
	if not s.has("attack") or s.has("object") or tgt.is_empty():
		return go.call() as CombatResult
	var e := enc()
	var c := ctx["c"] as Combatant
	var option := {"melee": str(s["attack"]) == "melee", "profile": WeaponProfile.new(), "kind": "spell"}
	var pre: Array = []
	var offers: Array = []
	for t in attack_shots(ctx, tgt):
		var adv: Array[String] = []
		var dis: Array[String] = []
		var st := {"c": c, "target": t, "orig": t, "option": option, "sit": {"advantage": adv, "disadvantage": dis}, "pre_roll": true, "ac": 0}
		pre.append(st)
		offers.append_array(e.echo_knight.before_roll(st))
		offers.append_array(e.reactions.before_roll(st))
	ctx["pre_rolls"] = pre
	if offers.is_empty():
		return go.call() as CombatResult
	return e.reactions.offer(offers, go, r)


## The answers given before this attack roll at `t` (_before_attack_rolls), taken once; {} if there were none.
func _take_pre_roll(ctx: Dictionary, t: Combatant) -> Dictionary:
	for st: Variant in ctx.get("pre_rolls", []):
		var d := st as Dictionary
		if not bool(d.get("used", false)) and d["orig"] == t:
			d["used"] = true
			return d
	return {}


## Advantage, Disadvantage and cover for a spell attack roll by `c` at `t` (from the square `origin` when it isn't the
## caster's own): Encounter.attack_situation for a spell, where Spell Sniper's Casting in Melee and Bypass Cover go by
## the attack's kind, then the cover a spell ignores (`ignore_partial_cover`; the Wand of the War Mage's Half Cover).
## The roll and the target tooltip (ActionCatalog.spell_attack_preview) both read it, so the odds shown are the odds
## rolled.
func situation(c: Combatant, s: Dictionary, t: Combatant, origin: Variant = null) -> Dictionary:
	var option := {"melee": str(s["attack"]) == "melee", "profile": WeaponProfile.new(), "kind": "spell"}
	(option["profile"] as WeaponProfile).normal_range = sp().range_ft(s, c)
	if origin != null:
		option["origin_cell"] = origin
	var sit := enc().attack_situation(c, t, option)
	if bool(s.get("ignore_partial_cover", false)):
		sit["cover_bonus"] = 0
	# Wand of the War Mage: spell attacks ignore Half Cover.
	if c.creature.has_flag("spell_attacks_ignore_half_cover") and int(sit.get("cover", 0)) == CombatGrid.Cover.HALF:
		sit["cover_bonus"] = 0
	return sit


## A spell attack roll at `t`: damage on a hit (with Critical Hits), the spell's hit effects, Chromatic Orb's
## leap, Vampiric Touch's drain; half damage on a miss for spells that say so (Melf's Acid Arrow) and for Potent
## Cantrip; Ice Knife's burst either way.
func spell_attack(ctx: Dictionary, t: Combatant, r: CombatResult) -> D20Test:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var melee := str(s["attack"]) == "melee"
	# Shadow Martyr (Echo Knight) may have sent an echo in before the roll; a roll the spell makes later (a Chromatic
	# Orb's leap) can't pause, so there the echo takes it only on Automatic.
	var pre := _take_pre_roll(ctx, t)
	t = pre["target"] as Combatant if not pre.is_empty() else e.echo_knight.spell_redirect(c, t)
	var sit := situation(c, s, t, ctx.get("attack_origin"))
	if not pre.is_empty():
		(sit["advantage"] as Array[String]).append_array((pre["sit"] as Dictionary)["advantage"] as Array[String])
		(sit["disadvantage"] as Array[String]).append_array((pre["sit"] as Dictionary)["disadvantage"] as Array[String])
	e._consume_marks(c, t)
	spells.specials.duel_check_attack(c, t)
	spells.trigger_ends(c, "attack_roll")
	var ac := t.creature.ac_value() + int(sit["cover_bonus"])
	var atk := ctx["nums"]["attack"] as Breakdown
	var keys: Array[String] = ["attack", "attack:melee" if melee else "attack:ranged", "attack:spell"]
	var test := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, ac, keys, sit["advantage"] as Array[String],
		sit["disadvantage"] as Array[String], "%s → %s (%s)" % [c.name(), t.name(), s["name"]], int(s.get("crit_range", 20)))
	if int(sit.get("height_bonus", 0)) != 0:
		test.add_bonus(int(sit.get("height_bonus", 0)), "High ground" if int(sit.get("height_bonus", 0)) > 0 else "Low ground")
	t.creature.consume_attacked()
	if not test.success and "seeking" in (ctx.get("metamagic", []) as Array) and not bool(ctx.get("seeking_used", false)):
		ctx["seeking_used"] = true
		test = c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, ac, keys, sit["advantage"] as Array[String],
			sit["disadvantage"] as Array[String], "%s → %s (%s, Seeking Spell reroll)" % [c.name(), t.name(), s["name"]], int(s.get("crit_range", 20)))
	if test.success:
		for sid in spells.incoming_roll_responses(t):
			if enc()._reaction_decision(t, sid) == "auto":
				spells.answer_incoming_roll(t, test, sid)
	var details: Array[String] = [test.describe(), atk.describe()]
	var hit := test.success
	if hit and e.mirror_image_takes(t, c, test.total):
		hit = false
	e.events.append({"type": "attack", "attacker": c.id, "target": t.id, "hit": hit, "critical": test.critical and hit, "edge": Encounter.attack_edge(test), "action": "spell:" + str(s["id"])})
	if not hit:
		r.lines.append(e.log.add("miss", "%s's %s misses %s (%d vs AC %d)" % [c.name(), s["name"], t.name(), test.total, ac], c.id, details))
		var half_on_miss := str(s.get("miss", "")) == "half" or (int(s.get("level", 0)) == 0 and c.creature.has_flag("potent_cantrip"))
		if half_on_miss and s.has("damage"):
			var half := spells.damage._roll_spell_damage(ctx, t, false)
			var amount := int(half["total"]) / 2
			spells.deal_spell_damage(ctx, t, [{"amount": amount, "type": spells._damage_type(ctx), "spell": true}], false, str(s["name"]),
				["Half damage on a miss", str(half["text"])])
		spells.apply_effect_entries(ctx, t, s.get("effects", []) as Array, "miss", r)
		_secondary(ctx, t, r)
		return test
	r.hit = true
	e.feature_recipes.synchronous_hit_responses(c, t)
	var critical := test.critical
	if s.has("damage"):
		var rolled := spells.damage._roll_spell_damage(ctx, t, critical)
		details.append(str(rolled["text"]))
		var parts: Array = [{"amount": int(rolled["total"]), "type": spells._damage_type(ctx), "spell": true, "spell_id": str(s["id"])}]
		# Extra damage on any attack roll that hits (Hunter's Mark, Hex).
		for m in c.creature.modifiers_for(&"extra_damage"):
			# Absorb Elements' stored charge rides a melee spell attack too, once.
			var first_melee := m.text("on", "weapon") == "first_melee" and melee
			if (m.text("on", "weapon") != "attack" and not first_melee) or (m.data.has("vs") and str(m.data["vs"]) != t.id):
				continue
			var xt := spells.extra_damage_type(c, t, m, spells._damage_type(ctx))
			if xt == "":
				continue
			var xr := e._roll_damage_dice(m.text("dice", "1d6"), critical, 0, m.source_name)
			parts.append({"amount": int(xr["total"]), "type": xt, "spell": true})
			details.append("%s %s: %s" % [m.source_name, m.text("dice"), xr["text"]])
			if first_melee:
				spells.reaction_spells.spend_stored_charge(c, m)
		e.hit_context = {"attacker": c.id, "target": t.id, "melee": melee, "spell": true}
		var dr := spells.deal_spell_damage(ctx, t, parts, critical, str(s["name"]), details)
		e.hit_context = {}
		r.damage += dr.final
		if melee:
			e.retaliate(c, t)
		if str(s["id"]) == "chromatic_orb":
			_orb_leap(ctx, t, rolled, r)
	if t.is_alive():
		_on_spell_hit(ctx, t, r)
		e.class_features.cantrip_hit(ctx, t)
		e.items.specials.fr.after_spell_hit(ctx, t, melee, r)
	_secondary(ctx, t, r)
	return test


## Riders on a hit that need code: everything else is in the spell's effects data (`on: hit`).
func _on_spell_hit(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var e := enc()
	match str((ctx["s"] as Dictionary)["id"]):
		"guiding_bolt":
			e.add_mark({"kind": "advantage_against", "target": t.id, "source": "Guiding Bolt",
				"expires_owner": c.id, "expires_phase": "end", "skip": e.own_turn_skip(c), "consume": true})
			return
	spells.apply_effect_entries(ctx, t, (ctx["s"] as Dictionary).get("effects", []) as Array, "hit", r)


## Ice Knife: hit or miss, the target and each creature within 5 ft of it make the burst's save.
func _secondary(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var spells := sp()
	var s := ctx["s"] as Dictionary
	if not s.has("secondary"):
		return
	var sec := s["secondary"] as Dictionary
	var e := enc()
	var cells := e.grid.area_cells("emanation", int(sec.get("radius", 5)), e.center_of(t), Vector2.RIGHT, 5, t.cell, t.size_cells)
	if not bool(sec.get("exclude_target", false)):
		for cell in t.footprint():
			if not cell in cells:
				cells.append(cell)
	e.events.append({"type": "spell", "caster": (ctx["c"] as Combatant).id, "spell": str(s["id"]), "cells": cells, "targets": []})
	var sub := ctx.duplicate()
	var sub_s := s.duplicate()
	sub_s["save"] = sec["save"]
	sub_s["save_success"] = sec.get("save_success", "none")
	sub_s["damage"] = sec["damage"]
	sub_s["effects"] = sec.get("effects", [])
	sub_s.erase("secondary")
	sub_s.erase("attack")
	sub["s"] = sub_s
	sub["point"] = e.center_of(t)
	if bool(sec.get("disadvantage_if_zero", false)) and bool(ctx.get("reduced_to_zero", false)):
		sub["save_disadvantage"] = ["%s reduced its first target to 0 Hit Points" % s["name"]]
	var victims := spells.creatures_in(cells)
	if bool(sec.get("exclude_target", false)):
		victims.erase(t)
	var objects: Array[Combatant] = []
	for victim: Combatant in victims.duplicate():
		if victim.creature.creature_type == &"object" or victim.creature.has_flag("spell_object"):
			victims.erase(victim)
			if bool(sec.get("damages_objects", false)) and not victim.creature.has_flag("spell_object") and not victim.creature.has_flag("magical") and not victim.creature.has_flag("attended"):
				objects.append(victim)
	var rolled := spells.damage._roll_spell_damage(sub, null, false)
	sub["shared_damage"] = rolled
	spells._save_spell(sub, victims, r)
	# The battlefield's objects in the burst (EncounterObjects): its damage, and fire.
	e.objects.area_spell(sub, cells, rolled, [], bool(sec.get("ignites_objects", false)))
	if not objects.is_empty():
		for obj in objects:
			r.damage += spells.deal_spell_damage(sub, obj, [{"amount": int(rolled["total"]), "type": spells._damage_type(sub)}], false, str(s["name"]), [str(rolled["text"])]).final
			if bool(sec.get("ignites_objects", false)) and obj.creature.has_flag("flammable"):
				e.monster_actions.set_burning(ctx["c"] as Combatant, obj)


## Chromatic Orb (2024): if two or more of the d8s match on a hit, the orb leaps to a different creature of the
## caster's choice within 30 ft of the one it hit (a new attack roll and new damage), up to the slot level in leaps; no
## creature is targeted twice by one casting. On the player's own turn a prompt asks where (the foe nearest the caster
## already picked; declining lets the leap go, docs/rules/deviations.md). The AI, the prompt's Auto rule and a casting
## on someone else's turn (War Caster) send it to the foe nearest the caster.
func _orb_leap(ctx: Dictionary, last: Combatant, rolled: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var leaps := int(ctx.get("leaps_left", int(ctx["slot"])))
	var hitlist := ctx.get("orb_hit", [last.id]) as Array
	if leaps <= 0 or not _has_duplicate(rolled):
		return
	var next := orb_leap_default(c, last, hitlist)
	if c.is_player_controlled() and e.current() == c and e.pending == null:
		var decision := e._reaction_decision(c, ORB_LEAP)
		if decision == "never":
			return
		if decision != "auto":
			_ask_orb_leap(ctx, last, next, leaps, hitlist)
			return
	if next != null:
		_leap_to(ctx, next, leaps, hitlist, r)


## Where the orb can leap from `last`: any other creature within 30 ft of it, but not the caster or a creature this
## casting already targeted.
func orb_leap_targets(c: Combatant, last: Combatant, hitlist: Array) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in enc().living():
		if o != c and not o.id in hitlist and not o.is_down() and enc().distance(last, o) <= 30:
			out.append(o)
	return out


## The leap the AI makes and the prompt starts from: the foe nearest the caster among those it can reach.
func orb_leap_default(c: Combatant, last: Combatant, hitlist: Array) -> Combatant:
	var e := enc()
	var next: Combatant = null
	var best := 1 << 30
	for o in e.hostiles_of(c):
		if o.id in hitlist or o.is_down() or e.distance(last, o) > 30:
			continue
		var d := e.distance(c, o)
		if d < best:
			best = d
			next = o
	return next


func _leap_to(ctx: Dictionary, next: Combatant, leaps: int, hitlist: Array, r: CombatResult) -> void:
	enc().log.add("spell", "The orb leaps to %s (matching dice)" % next.name(), (ctx["c"] as Combatant).id)
	var sub := ctx.duplicate()
	sub["leaps_left"] = leaps - 1
	hitlist.append(next.id)
	sub["orb_hit"] = hitlist
	spell_attack(sub, next, r)


## The player's choice of where the orb leaps (a prompt that costs nothing; one creature, or decline to let it go).
func _ask_orb_leap(ctx: Dictionary, last: Combatant, next: Combatant, leaps: int, hitlist: Array) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var options := orb_leap_targets(c, last, hitlist)
	if options.is_empty():
		return
	var req := ReactionRequest.new(ORB_LEAP, c.id, last.id)
	req.title = "Chromatic Orb's leap"
	req.text = "Two of the dice matched: the orb leaps to another creature within 30 ft of %s, with a new attack roll and new damage.%s" % [
		last.name(), " It can leap %d more time%s after this." % [leaps - 1, "" if leaps == 2 else "s"] if leaps > 1 else ""]
	req.cost = "No action or Reaction"
	req.spends_reaction = false
	req.min_targets = 1
	req.max_targets = 1
	if next != null:
		req.selected_ids.assign([next.id])
	for o in options:
		req.target_choices.append({"id": o.id, "label": "%s · %d ft from %s%s" % [o.name(), e.distance(last, o), last.name(),
			"" if c.hostile_to(o) else " (not a foe)"]})
	# Weakly hold the prompt: the continuation lives on it until the player answers.
	var request_ref: WeakRef = weakref(req)
	req.continuation = func(use: bool) -> CombatResult:
		var out := CombatResult.new()
		var request := request_ref.get_ref() as ReactionRequest
		if use and request != null and not request.selected_ids.is_empty():
			var to := e.get_c(request.selected_ids[0])
			if to != null and to in orb_leap_targets(c, last, hitlist):
				_leap_to(ctx, to, leaps, hitlist, out)
		return out
	e.pending = req


func _has_duplicate(rolled: Dictionary) -> bool:
	var text := str(rolled.get("text", ""))
	var open := text.find("[")
	var close := text.find("]")
	if open < 0 or close < 0:
		return false
	var seen := {}
	for part in text.substr(open + 1, close - open - 1).split(","):
		var v := part.strip_edges()
		if seen.has(v):
			return true
		seen[v] = true
	return false
