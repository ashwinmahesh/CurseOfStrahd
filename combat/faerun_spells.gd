class_name FaerunSpells
extends FaerunCommon
## Heroes of Faerûn and Arcana Unleashed spells with code of their own (FaerunFeatures): Wither and Bloom, Negative
## Energy Flood, Mooncloak, Elminster's Effulgent Spheres and Backlash, Holy Star of Mystra, Spirit Lantern, Transfix,
## Illusory Dragon and Conjure Constructs.


## The spellcasting modifier of whoever cast `spell_id` (its effect's caster).
func _caster_mod(caster_id: String, spell_id: String) -> int:
	var e := enc()
	var caster := e.get_c(caster_id)
	if caster == null or _ch(caster) == null:
		return 0
	var entry := e.spells._entry_any(caster, spell_id)
	return int(e.spells.numbers(caster, entry).get("mod", 0))


## Spells whose rules are in code here. True when handled.
func resolve_spell(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	match str((ctx["s"] as Dictionary)["id"]):
		"wither_and_bloom":
			_wither_and_bloom(ctx, tgt, cells, r)
			return true
		"negative_energy_flood":
			_negative_energy_flood(ctx, tgt, r)
			return true
		"elminsters_effulgent_spheres":
			e_spheres_cast(ctx, r)
			return false
		"illusory_dragon":
			_illusory_dragon(ctx, r)
			return true
		"conjure_constructs":
			_conjure_constructs(ctx, tgt, r)
			return true
		"transfix":
			for t in tgt:
				_transfix_one(ctx, t, r)
			enc().spells._grant_sustained(ctx, tgt)
			return true
	return false


func _wither_and_bloom(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> void:
	var fr := faerun()
	var e := enc()
	var c := ctx["c"] as Combatant
	var victims := e.spells._area_victims(c, ctx["s"] as Dictionary, cells) if tgt.is_empty() else tgt
	e.spells._save_spell(ctx, victims, r)
	# The bloom: the most hurt ally in the Sphere spends Hit Dice (one, plus one per slot level above 2).
	var best: Combatant = null
	for a in e.living():
		if not (a == c or a.allied_with(c)) or _ch(a) == null or a.creature.hp >= a.creature.max_hp():
			continue
		if not a.footprint().any(func(cl: Vector2i) -> bool: return cl in cells):
			continue
		if best == null or float(a.creature.hp) / maxf(1.0, a.creature.max_hp()) < float(best.creature.hp) / maxf(1.0, best.creature.max_hp()):
			best = a
	if best == null:
		return
	var dice := 1 + maxi(0, int(ctx["slot"]) - 2)
	var rolled := fr.origin._spend_hit_dice(_ch(best), dice, "Wither and Bloom", fr.healing_floor(best))
	if rolled <= 0:
		return
	var got := best.creature.heal(rolled + int((ctx["nums"] as Dictionary).get("mod", 0)), "Wither and Bloom")
	r.lines.append(e.log.add("heal", "%s blooms: +%d Hit Points (Wither and Bloom)" % [best.name(), got], best.id))
	e.events.append({"type": "heal", "id": best.id, "amount": got})


func _negative_energy_flood(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var fr := faerun()
	var e := enc()
	var c := ctx["c"] as Combatant
	for t in tgt:
		if t.creature.creature_type == &"undead":
			var thp := int(e.dice.roll_expr("3d10", "Negative Energy Flood")["total"])
			if t.creature.add_temp_hp(thp, "Negative Energy Flood"):
				r.lines.append(e.log.add("heal", "%s drinks the negative energy: %d Temporary Hit Points" % [t.name(), thp], t.id))
			continue
		var only: Array[Combatant] = [t]
		e.spells._save_spell(ctx, only, r)
		if t.creature.dead and t.creature.creature_type == &"humanoid" and not t.has_meta("no_undead"):
			fr._rising.append({"caster": c.id, "cell": t.cell, "slot": int(ctx["slot"])})
			r.lines.append(e.log.add("info", "%s will rise as a Zombie at the start of %s's next turn" % [t.name(), c.name()], t.id))


func _raise_zombie(c: Combatant, z: Dictionary) -> void:
	var e := enc()
	var s := Compendium.shared().spell_data("negative_energy_flood")
	var nums := e.spells.numbers(c, e.spells._entry_any(c, "negative_energy_flood"))
	var ctx := {"c": c, "s": s, "slot": int(z["slot"]), "nums": nums, "conc": null, "opts": {}, "choice": "zombie",
		"summon_block": SummonBlocks.for_spell("animate_dead", int(z["slot"]), "zombie", nums)}
	var r := CombatResult.new()
	e.spells._summon(ctx, z["cell"] as Vector2i, r)
	e.log.add("spell", "A Zombie rises to serve %s (Negative Energy Flood)" % c.name(), c.id)


## After a D20 Test (D20Responses): Modify Magic's Unravel, Shared Resilience, Noble Scion and Alustriel's Mooncloak.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var fr := faerun()
	fr.subclasses.unravel_offers(c, t, keys, out)
	fr.subclasses.shared_resilience_offers(c, t, out)
	fr.subclasses.noble_scion_offers(c, t, out)
	_mooncloak_offers(c, t, keys, out)


## Alustriel's Mooncloak: a Reaction turns a failed save against being Frightened, Grappled or Restrained into a success
## and ends the spell. It asks where the save can pause (its class-tab rule otherwise).
func _mooncloak_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if t.kind != D20Test.Kind.SAVING_THROW or c.creature.concentration == null or c.creature.concentration.source_id != "alustriels_mooncloak":
		return
	if not keys.any(func(k: String) -> bool: return k in ["save_vs:frightened", "save_vs:grappled", "save_vs:restrained"]):
		return
	out.append({"kind": "alustriels_mooncloak", "reactor": c, "sync": "explicit", "title": "Reaction: Alustriel's Mooncloak?",
		"text": func() -> String: return "%s. Spend the Mooncloak's moonlight to succeed instead (the spell ends)?" % D20Responses.line(c, t),
		"cost": "Reaction, and the spell ends",
		"still": func() -> bool: return not t.success and e.spells.can_react(c) and c.creature.concentration != null \
			and c.creature.concentration.source_id == "alustriels_mooncloak",
		"use": func() -> void:
			c.reaction_available = false
			t.add_bonus(maxi(0, t.target - t.total), "Alustriel's Mooncloak")
			c.creature.concentration.end("its moonlight steadies %s" % c.name())
			_log("reaction", "%s spends the Mooncloak's moonlight to shrug it off" % c.name(), c)})


## Why a `do: faerun` sustained action can't be used now ("" if it can); checked before its cost is paid.
func sustained_why(c: Combatant, a: Dictionary, d: Dictionary, t: Combatant, point: Vector2) -> String:
	var e := enc()
	match str(d.get("mode", str(a["spell_id"]))):
		"elminsters_effulgent_spheres":
			if t == null or e.distance(c, t) > 120 or not e.can_see(c, t):
				return "Choose a creature you can see within 120 ft"
			if _spheres(c) <= 0:
				return "No spheres left"
		"harm", "mend", "veil":
			if t == null or e.distance(c, t) > 60 or not e.can_see(c, t):
				return "Choose a creature you can see within 60 ft"
			if int(c.get_meta("lantern_fragments", 0)) <= 0:
				return "No spirit fragments"
			if str(d.get("mode", "")) == "mend" and t.creature.creature_type != &"undead":
				return "Only an Undead can be mended"
		"transfix":
			if t == null or t == c or e.distance(c, t) > 60 or not e.can_see(c, t):
				return "Choose a creature you can see within 60 ft"
			if t.id in (c.get_meta("transfix_resisted", []) as Array) or transfixed_by(t) == c:
				return "%s can't be transfixed again" % t.name()
		"dragon_breath":
			if point == Vector2.INF:
				return "Choose where the dragon breathes"
		"constructs":
			var obj := e.spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj == null:
				return "The spirits are gone"
			if t == null or e.grid.distance_ft(obj.cell, 1, t.cell, t.size_cells) > 5:
				return "Choose a creature within 5 ft of the spirits"
	return ""


## A sustained spell action whose rules are in code here (`do: faerun`); its cost is already paid.
func sustained(c: Combatant, a: Dictionary, d: Dictionary, ctx: Dictionary, targets: Array, point: Vector2, _dir: Vector2, r: CombatResult) -> CombatResult:
	var e := enc()
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() else null
	match str(d.get("mode", str(a["spell_id"]))):
		"elminsters_effulgent_spheres":
			_spend_sphere(c)
			var sub := ctx.duplicate()
			var s := (ctx["s"] as Dictionary).duplicate()
			s["attack"] = "ranged"
			s["damage"] = [{"dice": "3d6", "type": str(ctx.get("choice", "fire")) if str(ctx.get("choice", "")) != "" else "fire"}]
			s.erase("effects")
			sub["s"] = s
			e.log.add("spell", "%s hurls an effulgent sphere" % c.name(), c.id)
			e.spells.spell_attack(sub, t, r)
		"harm", "mend", "veil":
			c.set_meta("lantern_fragments", int(c.get_meta("lantern_fragments", 0)) - 1)
			_lantern(c, str(d.get("mode", "")), t, ctx, r)
		"transfix":
			_transfix_one(ctx, t, r)
		"dragon_breath":
			_dragon_breath(c, ctx, point, int(d.get("move", 60)), r)
		"constructs":
			_constructs_act(c, ctx, t, r)
	return CombatResult.new()


func e_spheres_cast(ctx: Dictionary, _r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	c.set_meta("effulgent_spheres", 6 + maxi(0, int(ctx["slot"]) - 6))


func _spheres(c: Combatant) -> int:
	if not c.creature.has_flag("effulgent_spheres"):
		return 0
	return int(c.get_meta("effulgent_spheres", 0))


func _spend_sphere(c: Combatant) -> void:
	var left := _spheres(c) - 1
	c.set_meta("effulgent_spheres", left)
	if left <= 0:
		for fx: Effect in c.creature.effects.duplicate():
			if fx.source_id == "elminsters_effulgent_spheres":
				c.creature.remove_effect(fx)
		_log("info", "%s's last effulgent sphere is spent" % c.name(), c)


func _sphere_ward(c: Combatant, ty: String) -> void:
	_spend_sphere(c)
	c.reaction_available = false
	var fx := Effect.new("Effulgent Sphere (%s)" % ty.capitalize(), &"spell", "effulgent_sphere_ward").with_modifier("resistance", {"value": ty})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)
	_log("reaction", "%s catches the %s on a sphere: Resistance until its next turn" % [c.name(), ty], c)


## Attack damage: offers for the reaction prompt (Backlash, a sphere's ward, Elemental Rebuke, Crown of Spellfire).
func against_damage(st: Dictionary, parts: Dictionary, total: Callable, cut: Callable, out: Array, responded: Array) -> void:
	var fr := faerun()
	var e := enc()
	var target := st["target"] as Combatant
	var source := st["c"] as Combatant
	fr.subclasses._subclass_against_damage(target, source, total, cut, out)
	if e.spells.can_cast_reaction(target, "backlash") and int(total.call()) > 0:
		responded.append("backlash")
		out.append({"kind": "backlash", "reactor": target, "trigger": source.id, "title": "Reaction: Backlash?",
			"text": "%s hits %s for %d. Cut it by 4d6 + your spellcasting modifier and lash back for 4d6 Force?" % [source.name(), target.name(), int(total.call())],
			"cost": "Reaction and a level 4+ spell slot",
			"still": func() -> bool: return e.spells.can_cast_reaction(target, "backlash") and int(total.call()) > 0,
			"use": func() -> void: _backlash(target, source, cut)})
	var ty := ""
	for k: String in parts:
		if k in FaerunFeatures.ELEMENTS and int(parts[k]) > 0:
			ty = k
	if ty != "" and _spheres(target) > 0 and e.spells.can_react(target) and target.creature.resistance_source(StringName(ty)) == "":
		responded.append("elminsters_effulgent_spheres")
		out.append({"kind": "elminsters_effulgent_spheres", "reactor": target, "trigger": source.id, "title": "Reaction: an effulgent sphere?",
			"text": "%s deals %s damage. Spend a sphere for Resistance to it until your next turn?" % [source.name(), ty.capitalize()],
			"cost": "Reaction and a sphere",
			"still": func() -> bool: return _spheres(target) > 0 and e.spells.can_react(target),
			"use": func() -> void: _sphere_ward(target, ty)})


## Damage that can't pause (spells, hazards): Backlash and the spheres act only on Automatic.
func synchronous_damage(source: Combatant, target: Combatant, parts: Array, details: Array, resolved: Array) -> Array:
	var e := enc()
	if target == null or not target.creature is Character:
		return parts
	var out := parts
	var total := func() -> int:
		var n := 0
		for p: Variant in out:
			n += maxi(0, int((p as Dictionary)["amount"]))
		return n
	if not "elminsters_effulgent_spheres" in resolved and _spheres(target) > 0 and e.spells.can_react(target) \
			and str(target.reaction_rules.get("elminsters_effulgent_spheres", "ask")) == "auto":
		for p: Variant in out:
			var ty := str((p as Dictionary)["type"])
			if ty in FaerunFeatures.ELEMENTS and int((p as Dictionary)["amount"]) > 0 and target.creature.resistance_source(StringName(ty)) == "":
				_sphere_ward(target, ty)
				break
	if not "backlash" in resolved and int(total.call()) > 0 and e.spells.can_cast_reaction(target, "backlash") \
			and str(target.reaction_rules.get("backlash", "ask")) == "auto":
		out = out.duplicate(true)
		_backlash(target, source, func(amount: int, label: String) -> void:
			var left := amount
			for p2: Variant in out:
				var d := p2 as Dictionary
				var cutn := mini(left, maxi(0, int(d["amount"])))
				d["amount"] = int(d["amount"]) - cutn
				left -= cutn
			details.append("%s: −%d" % [label, amount - left]))
	return out


func _backlash(c: Combatant, source: Combatant, cut: Callable) -> void:
	var e := enc()
	var ch := _ch(c)
	var slot := e.spells._lowest_slot(ch, 4)
	if slot == 0:
		return
	c.reaction_available = false
	ch.expend_slot(slot)
	var s := Compendium.shared().spell_data("backlash")
	var nums := e.spells.numbers(c, e.spells._entry_any(c, "backlash"))
	var extra := maxi(0, slot - 4)
	var guard := int(e.dice.roll_expr("%dd6" % (4 + extra), "Backlash")["total"]) + int(nums.get("mod", 0))
	e.log.add("spell", "%s answers with Backlash (level %d slot)" % [c.name(), slot], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": "backlash", "cells": [], "targets": [source.id] if source != null else []})
	cut.call(guard, "Backlash")
	if source == null or not source.is_alive() or e.distance(c, source) > 60:
		return
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var only: Array[Combatant] = [source]
	e.spells._save_spell(ctx, only, CombatResult.new())


## After a successful save against a level 7 or lower spell aimed at the holder alone: turned back on its caster
## (Automatic only).
func reflects_spell(c: Combatant, t: Combatant, ctx: Dictionary, victims: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var s := ctx["s"] as Dictionary
	if not t.creature.has_flag("holy_star_reflect") or bool(ctx.get("turned", false)) or int(ctx.get("slot", 0)) > 7:
		return
	if victims.size() != 1 or s.has("area") or c == t or not c.is_alive() or not e.spells.can_react(t):
		return
	if str(t.reaction_rules.get("holy_star_of_mystra", "never")) != "auto":
		return
	t.reaction_available = false
	var back := ctx.duplicate()
	back["turned"] = true
	r.lines.append(e.log.add("reaction", "%s's Holy Star turns %s back on %s" % [t.name(), s.get("name", ""), c.name()], t.id))
	var only: Array[Combatant] = [c]
	e.spells._save_spell(back, only, r)


func _lantern_catch(dead: Combatant) -> void:
	var e := enc()
	for h in e.combatants:
		if not h.creature.has_flag("spirit_lantern") or not h.hostile_to(dead) or e.distance(h, dead) > 60:
			continue
		# Grave Reaper's lantern holds five.
		var cap := int(h.get_meta("lantern_capacity", maxi(1, _caster_mod(h.id, "spirit_lantern"))))
		var n := int(h.get_meta("lantern_fragments", 0))
		if n < cap:
			h.set_meta("lantern_fragments", n + 1)
			_log("info", "%s's lantern catches a fragment of %s's spirit (%d)" % [h.name(), dead.name(), n + 1], h)


func _lantern(c: Combatant, mode: String, t: Combatant, ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var mod := int((ctx["nums"] as Dictionary).get("mod", 0))
	match mode:
		"harm":
			var s := (ctx["s"] as Dictionary).duplicate()
			s["save"] = "con"
			s["save_success"] = "half"
			s["damage"] = [{"dice": "4d8+%d" % mod, "type": "necrotic"}]
			s.erase("effects")
			var sub := ctx.duplicate()
			sub["s"] = s
			var only: Array[Combatant] = [t]
			e.spells._save_spell(sub, only, r)
		"mend":
			var got := t.creature.heal(int(e.heal_roll("4d8", t, "Spirit Lantern")["total"]) + mod, "Spirit Lantern")
			r.lines.append(e.log.add("heal", "%s mends %s with a captured spirit: +%d Hit Points" % [c.name(), t.name(), got], c.id))
			e.events.append({"type": "heal", "id": t.id, "amount": got})
		"veil":
			var fx := Effect.new("Spirit Veil", &"spell", "spirit_lantern").with_modifier("attacked_with", {"value": "disadvantage"})
			fx.caster_id = c.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			t.creature.add_effect(fx)
			r.lines.append(e.log.add("info", "Spirits veil %s: attacks against it have Disadvantage" % t.name(), c.id))


func transfixed_by(t: Combatant) -> Combatant:
	if not t.creature.has_flag("transfixed"):
		return null
	for fx: Effect in t.creature.effects:
		if fx.source_id == "transfix":
			return enc().get_c(fx.caster_id)
	return null


func _transfix_one(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	if t == null:
		return
	var only: Array[Combatant] = [t]
	e.spells._save_spell(ctx, only, r)
	if transfixed_by(t) != c:
		var resisted := (c.get_meta("transfix_resisted", []) as Array).duplicate()
		resisted.append(t.id)
		c.set_meta("transfix_resisted", resisted)


## Transfix: a creature ending its turn within 5 ft of its caster takes the Psychic damage.
func _transfix_turn_end(c: Combatant) -> void:
	var e := enc()
	var caster := transfixed_by(c)
	if caster == null or e.distance(c, caster) > 5:
		return
	var s := Compendium.shared().spell_data("transfix")
	var conc := caster.creature.concentration
	var slot := 7
	for fx: Effect in c.creature.effects:
		if fx.source_id == "transfix":
			slot = maxi(7, fx.spell_level)
	var rolled := e._roll_damage_dice("%dd8" % (4 + slot - 7), false, 0, "Transfix")
	var nums := e.spells.numbers(caster, e.spells._entry_any(caster, "transfix"))
	var ctx := {"c": caster, "s": s, "slot": slot, "nums": nums, "conc": conc, "opts": {}, "choice": "", "point": Vector2.INF}
	e.spells.deal_spell_damage(ctx, c, [{"amount": int(rolled["total"]), "type": "psychic", "spell": true}], false, "Transfix", [str(rolled["text"])])


func _illusory_dragon(ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var point := ctx["point"] as Vector2
	var o := FieldObject.new(FieldObject.Kind.ILLUSION, "illusory_dragon", "Illusory Dragon")
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cell = Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else c.cell
	o.cells = CombatGrid.footprint(o.cell, 3)
	o.rules = {"choice": str(ctx.get("choice", "fire")), "size": 3}
	o.keep_with(ctx["conc"] as Concentration)
	e.spells.zones.add(o, r)
	e.events.append({"type": "summon", "caster": c.id, "cell": o.cell})
	r.lines.append(e.log.add("spell", "A Huge shadow dragon looms over the field", c.id))
	# Its appearance: every enemy that sees it saves or drops what it holds and is Frightened.
	var conc := ctx["conc"] as Concentration
	for t in e.hostiles_of(c):
		if t.is_down() or not e.can_see_space(t, o.cell, 3):
			continue
		var keys := SpellCaster.spell_save_keys(c.id)
		keys.append("save_vs:frightened")
		var sv := t.creature.roll_save(e.dice, &"wis", o.save_dc, [], [], "Wisdom save vs the Illusory Dragon (%s)" % t.name(), keys)
		if sv.success:
			e.log.add("info", "%s isn't cowed by the dragon" % t.name(), t.id, [sv.describe()])
			continue
		var fx := Effect.new("Illusory Dragon", &"spell", "illusory_dragon").with_condition(&"frightened")
		fx.caster_id = c.id
		fx.spell_level = o.slot
		fx.repeat_save = {"ability": "wis", "dc": o.save_dc, "when": "end", "if": "no_sight_of_object"}
		if conc != null:
			conc.attach(t.creature, fx)
		else:
			t.creature.add_effect(fx)
		if t.creature.has_condition(&"frightened"):
			e.ground.drop_held(t, "Illusory Dragon")
			e.log.add("condition", "%s drops what it holds and cowers before the dragon" % t.name(), t.id, [sv.describe()])
			e.events.append({"type": "condition", "id": t.id})
	if s.has("sustain"):
		e.spells._grant_sustained(ctx, [])


func _dragon_breath(c: Combatant, ctx: Dictionary, point: Vector2, move_ft: int, r: CombatResult) -> void:
	var e := enc()
	var o := e.spells.zones.object_of(c.id, "illusory_dragon")
	if o == null:
		return
	# The dragon closes up to `move_ft` toward the point, then breathes at it.
	var aim := point - (Vector2(o.cell) + Vector2(1.5, 1.5))
	var steps := mini(int(move_ft / CombatGrid.FEET), maxi(0, int(aim.length()) - 6))
	if steps > 0:
		var dv := Vector2i((aim.normalized() * float(steps)).round())
		var to := o.cell + dv
		if e.grid.in_bounds(to) and e.grid.in_bounds(to + Vector2i(2, 2)):
			o.cell = to
			o.cells = CombatGrid.footprint(to, 3)
			e.spells.zones.moved_object(o, r)
	var cells := e.grid.cone_from(o.cell, 3, point, 60)
	var s := (ctx["s"] as Dictionary).duplicate()
	s["damage"] = [{"dice": "6d6", "type": str(o.rules.get("choice", "fire"))}]
	s.erase("effects")
	var sub := ctx.duplicate()
	sub["s"] = s
	e.events.append({"type": "spell", "caster": c.id, "spell": "illusory_dragon", "cells": cells, "targets": []})
	e.log.add("spell", "The shadow dragon breathes", c.id)
	var victims: Array[Combatant] = []
	for t in e.living():
		if t != c and t.footprint().any(func(x: Vector2i) -> bool: return x in cells):
			victims.append(t)
	e.spells._save_spell(sub, victims, r)


func _conjure_constructs(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	if tgt.is_empty():
		return
	var t := tgt[0]
	var o := FieldObject.new(FieldObject.Kind.LIGHTS, "conjure_constructs", "Construct Spirits")
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cell = e.spells._free_cell_near(t.cell, 1)
	o.cells = [o.cell]
	o.rules = {}
	o.keep_with(ctx["conc"] as Concentration)
	e.spells.zones.add(o, r)
	e.events.append({"type": "summon", "caster": c.id, "cell": o.cell})
	r.lines.append(e.log.add("spell", "Construct spirits gather beside %s" % t.name(), c.id))
	_constructs_act(c, ctx, t, r)
	e.spells._grant_sustained(ctx, tgt)


func _constructs_act(c: Combatant, ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var extra := maxi(0, int(ctx["slot"]) - 3)
	if t == c or c.allied_with(t):
		var amount := int(e.dice.roll_expr("%dd6" % (1 + extra), "Construct spirits")["total"]) + int((ctx["nums"] as Dictionary).get("mod", 0))
		if t.creature.add_temp_hp(maxi(1, amount), "Conjure Constructs"):
			r.lines.append(e.log.add("heal", "The spirits shield %s: %d Temporary Hit Points" % [t.name(), maxi(1, amount)], c.id))
		return
	var only: Array[Combatant] = [t]
	e.spells._save_spell(ctx, only, r)
