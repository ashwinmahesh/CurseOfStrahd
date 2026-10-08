class_name SpellAttacks
extends RefCounted
## Spell attacks in a fight (SpellCaster): the shots a spell makes, the pause for reactions before the rolls, the
## attack roll itself, what a hit does, secondary targets (Ice Knife's burst) and Chromatic Orb's leap.

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
## (Scorching Ray, Eldritch Blast) shared round the targets.
func attack_shots(ctx: Dictionary, tgt: Array[Combatant]) -> Array[Combatant]:
	var spells := sp()
	var s := ctx["s"] as Dictionary
	var count := 1
	var dmg := s.get("damage", []) as Array
	if not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "ray":
		count = spells.target_count(s, int(ctx["slot"]))
	elif not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "beam":
		count = spells.specials.beams(ctx["c"] as Combatant)
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


## A spell attack roll at `t`: damage on a hit (with Critical Hits), the spell's hit effects, Chromatic Orb's
## leap, Vampiric Touch's drain; half damage on a miss for spells that say so (Melf's Acid Arrow) and for Potent
## Cantrip; Ice Knife's burst either way.
func spell_attack(ctx: Dictionary, t: Combatant, r: CombatResult) -> D20Test:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var melee := str(s["attack"]) == "melee"
	var option := {"melee": melee, "profile": WeaponProfile.new(), "kind": "spell"}
	(option["profile"] as WeaponProfile).normal_range = spells.range_ft(s, c)
	if ctx.has("attack_origin"):
		option["origin_cell"] = ctx["attack_origin"]
	# Shadow Martyr (Echo Knight) may have sent an echo in before the roll; a roll the spell makes later (a Chromatic
	# Orb's leap) can't pause, so there the echo takes it only on Automatic.
	var pre := _take_pre_roll(ctx, t)
	t = pre["target"] as Combatant if not pre.is_empty() else e.echo_knight.spell_redirect(c, t)
	var sit := e.attack_situation(c, t, option)
	if not pre.is_empty():
		(sit["advantage"] as Array[String]).append_array((pre["sit"] as Dictionary)["advantage"] as Array[String])
		(sit["disadvantage"] as Array[String]).append_array((pre["sit"] as Dictionary)["disadvantage"] as Array[String])
	if bool(s.get("ignore_partial_cover", false)):
		sit["cover_bonus"] = 0
	# Wand of the War Mage: spell attacks ignore Half Cover.
	if c.creature.has_flag("spell_attacks_ignore_half_cover") and int(sit.get("cover", 0)) == CombatGrid.Cover.HALF:
		sit["cover_bonus"] = 0
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
			if m.text("on", "weapon") != "attack" or (m.data.has("vs") and str(m.data["vs"]) != t.id):
				continue
			var xt := spells.extra_damage_type(c, t, m, spells._damage_type(ctx))
			if xt == "":
				continue
			var xr := e._roll_damage_dice(m.text("dice", "1d6"), critical, 0, m.source_name)
			parts.append({"amount": int(xr["total"]), "type": xt, "spell": true})
			details.append("%s %s: %s" % [m.source_name, m.text("dice"), xr["text"]])
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


## Chromatic Orb (2024): if two or more of the d8s match, the orb leaps to a creature within 30 ft of the last
## one it hit (a new attack roll and damage), up to the slot level in leaps, never the same creature twice.
func _orb_leap(ctx: Dictionary, last: Combatant, rolled: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var leaps := int(ctx.get("leaps_left", int(ctx["slot"])))
	var hitlist := ctx.get("orb_hit", [last.id]) as Array
	if leaps <= 0 or not _has_duplicate(rolled):
		return
	var next: Combatant = null
	var best := 1 << 30
	for o in e.hostiles_of(c):
		if o.id in hitlist or o.is_down() or e.grid.distance_ft(last.cell, last.size_cells, o.cell, o.size_cells) > 30:
			continue
		var d := e.distance(c, o)
		if d < best:
			best = d
			next = o
	if next == null:
		return
	e.log.add("spell", "The orb leaps to %s (matching dice)" % next.name(), c.id)
	var sub := ctx.duplicate()
	sub["leaps_left"] = leaps - 1
	hitlist.append(next.id)
	sub["orb_hit"] = hitlist
	spell_attack(sub, next, r)


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
