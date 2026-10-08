class_name SpellCasting
extends RefCounted
## Casting a spell in a fight (SpellCaster, docs/contracts/spells.md): checking and paying for the cast (slots,
## free uses, the action economy, Metamagic, Concentration), choosing and checking targets and areas, then resolving the
## spell's recipe on its targets, with the features that answer a cast (Arcane Ward, Sorcery Incarnate...).

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Casts `spell_id` at `slot` (0 or the spell's level = lowest). `targets` for targeted spells; `point` (a grid
## point) and `direction` for areas and placed objects. opts: {choice} for a cast-time choice (Chromatic Orb's
## damage type, Command's word, Protection from Energy's type, Enlarge or Reduce...), {free: true} to use a free
## casting, {cell} for where an object or a teleport goes.
func cast(c: Combatant, spell_id: String, slot: int, targets: Array = [], point: Vector2 = Vector2.INF,
		direction: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> CombatResult:
	var spells := sp()
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	var entry := spells._entry(c, spell_id)
	if entry.is_empty():
		return CombatResult.fail("%s doesn't know that spell" % c.name())
	var resource_feature := str(opts.get("resource_cast", ""))
	var resource_recipe: Dictionary = {}
	if resource_feature != "":
		if bool(opts.get("war_magic", false)) or str(opts.get("spell_sequence", "")) != "" or str(opts.get("slot_boost", "")) != "" or bool(opts.get("splintered", false)):
			return CombatResult.fail("Choose one casting feature")
		if "quickened" in (opts.get("metamagic", []) as Array) or "psionic_sorcery" in (opts.get("metamagic", []) as Array):
			return CombatResult.fail("This feature supplies its own casting action and payment")
		entry = spells.resource_cast_entry(c, _comp().spell_data(spell_id), resource_feature)
		if entry.is_empty():
			return CombatResult.fail("This feature cannot cast that spell")
		resource_recipe = (entry["resource_cast"] as Dictionary)["resource_cast"] as Dictionary
		if slot > int(entry["level"]):
			return CombatResult.fail("This feature casts at the spell's base level")
	var war_magic := bool(opts.get("war_magic", false))
	if war_magic:
		entry = e.triggered_features.attack_cantrip_entry(c, _comp().spell_data(spell_id), entry)
		if entry.is_empty() or e.features_attack_why(c) != "":
			return CombatResult.fail("Cannot replace an attack with this cantrip")
	var sequence: Dictionary = {}
	var sequence_id := str(opts.get("spell_sequence", ""))
	if sequence_id != "":
		if war_magic:
			return CombatResult.fail("Choose one attack substitution")
		for feature in e.triggered_features.spell_sequences(c, _comp().spell_data(spell_id), entry):
			if str(feature["id"]) == sequence_id:
				sequence = feature
		if sequence.is_empty():
			return CombatResult.fail("That spell cannot replace those attacks")
		entry = e.triggered_features.casting_entry(c, _comp().spell_data(spell_id), entry, sequence["spell_sequence"] as Dictionary)
		var sequence_why := e.triggered_features.sequence_why(c, _comp().spell_data(spell_id), entry, sequence)
		if sequence_why != "":
			return CombatResult.fail(sequence_why)
		entry = entry.duplicate()
		entry["casting"] = "bonus_action"
		entry["legal"] = true
		entry["reason"] = ""
	var meta := (opts.get("metamagic", []) as Array).map(func(x: Variant) -> String: return str(x))
	var meta_why := spells._metamagic_check(c, _comp().spell_data(spell_id), meta)
	if meta_why != "":
		return CombatResult.fail(meta_why)
	# Quickened Spell turns a one-action spell into a Bonus Action; Subtle Spell needs no voice.
	if "quickened" in meta and str(entry["casting"]) == "action":
		entry["casting"] = "bonus_action"
		var qwhy := spells.economy_block(c, "bonus_action")
		entry["legal"] = qwhy == "" and str(entry["reason"]) in ["", "Action already used", "Only one Magic action this turn (Action Surge's action can't be Magic)"]
		entry["reason"] = qwhy
	var silent_ok := "subtle" in meta or "psionic_sorcery" in meta \
		or ("psychic_spells" in meta and str(_comp().spell_data(spell_id).get("school", "")) in ["enchantment", "illusion"])
	# Psionic Sorcery pays with Sorcery Points: no slot needed, and it isn't a slot spell for the one-per-turn rule.
	if "psionic_sorcery" in meta and (str(entry["reason"]).begins_with("No spell slots") or str(entry["reason"]).begins_with("Already cast a spell with a slot")):
		entry["legal"] = true
		entry["reason"] = ""
		entry["free"] = true
	if silent_ok and (str(entry["reason"]) == "Can't speak" or str(entry["reason"]).begins_with("Silence")):
		entry["legal"] = true
		entry["reason"] = ""
	if war_magic and str(entry["reason"]) in ["Action already used", ""] and e.features_attack_why(c) == "" and int(_comp().spell_data(spell_id).get("level", 0)) == 0:
		entry["legal"] = true
	if not bool(entry["legal"]):
		return CombatResult.fail(str(entry["reason"]))
	var s := _comp().spell_data(spell_id)
	if not resource_recipe.is_empty() and bool(resource_recipe.get("omit_material", false)):
		s = s.duplicate(true)
		for key: String in ["m", "m_cost_gp", "m_consumed"]:
			(s["components"] as Dictionary).erase(key)
	var ch := spells.caster_char(c)
	var level := int(s.get("level", 0))
	var use_free := bool(entry["free"]) and not bool(opts.get("splintered", false)) and str(opts.get("slot_boost", "")) == "" and (bool(opts.get("free", false)) or slot <= level or "psionic_sorcery" in meta)
	# Tome of the Stilled Tongue: the next Wizard spell needs no slot.
	if level > 0 and c.has_meta("free_wizard_spell") and "wizard" in (s.get("classes", []) as Array):
		c.remove_meta("free_wizard_spell")
		use_free = true
		ch.set_resource("spell:%s" % spell_id, str(s["name"]), 1, "long", "Tome of the Stilled Tongue")
	# Divine Intervention: the next Cleric spell of level 5 or lower needs no slot.
	if level > 0 and c.has_meta("free_cleric_spell") and "cleric" in (s.get("classes", []) as Array) and level <= int(c.get_meta("free_cleric_spell")):
		c.remove_meta("free_cleric_spell")
		use_free = true
		ch.set_resource("spell:%s" % spell_id, str(s["name"]), 1, "long", "Divine Intervention")
	if level == 0:
		slot = 0
	elif use_free:
		slot = maxi(level, int(entry.get("free_slot", 0)))
	else:
		slot = maxi(slot, level)
		if c.cast_slot_spell_this_turn:
			return CombatResult.fail("Already cast a spell with a slot this turn")
		if ch.slots_left(slot) <= 0:
			return CombatResult.fail("No level %d slots left" % slot)
	if bool(opts.get("splintered", false)):
		if use_free or not spells.can_splinter(c, s):
			return CombatResult.fail("Splintered Summons needs an available use and a spell slot")
	var form_id := str(opts.get("cast_form", ""))
	if form_id != "" and not e.triggered_features.casting_forms(c, s).any(func(f: Dictionary) -> bool: return str(f["id"]) == form_id):
		return CombatResult.fail("This casting form is not available")
	var boost: Dictionary = {}
	var boost_id := str(opts.get("slot_boost", ""))
	if boost_id != "":
		for f in e.triggered_features.casting_boosts(c, s):
			if str(f["id"]) == boost_id:
				boost = f
		if boost.is_empty() or use_free or bool(opts.get("free", false)) or level == 0:
			return CombatResult.fail("This spell cannot use that subclass casting benefit")
	var paid_slot := slot
	var effective_slot := slot + (1 if not boost.is_empty() else 0)
	if not sequence.is_empty() and effective_slot + (1 if "twinned" in meta else 0) > int((sequence["spell_sequence"] as Dictionary)["max_level"]):
		return CombatResult.fail("Spell level exceeds this attack substitution's limit")
	var copts := opts.duplicate()
	if "distant" in meta:
		copts["range_mult"] = true
	var check := spells._check_targets(c, s, effective_slot + (1 if "twinned" in meta else 0), targets, point, copts)
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	var tgt := check["targets"] as Array[Combatant]
	var cell: Vector2i = check["cell"]
	if spell_id in SpellCaster.BLADE_CANTRIPS and not tgt.is_empty() and spells.blade_option(c, tgt[0]).is_empty():
		return CombatResult.fail("Needs a melee weapon that can strike %s" % tgt[0].name())
	if not meta.is_empty():
		spells.options._pay_metamagic(c, meta)
	# Pay for it.
	var unit := str(entry["casting"])
	if not sequence.is_empty():
		e.triggered_features.begin_sequence(c, sequence)
	elif war_magic:
		e.use_one_attack(c)
		c.set_meta("attack_cantrip_used", true)
	elif unit == "bonus_action":
		c.bonus_available = false
	else:
		e.spend_action(c)
		c.magic_action_used = true
	if not spells.casting_gate(c):
		return CombatResult.new()
	# A cantrip cast through a feature's uses (Spellfire Spark's Bonus Action Sacred Flame) still spends one.
	if level == 0 and not resource_recipe.is_empty():
		ch.spend_resource(str(resource_recipe["resource"]), int(resource_recipe["cost"]))
	if level > 0:
		if "psionic_sorcery" in meta:
			ch.spend_resource("sorcery_points", level)
			e.log.add("info", "%s shapes the spell with %d Sorcery Points (Psionic Sorcery)" % [c.name(), level], c.id)
		elif not resource_recipe.is_empty():
			ch.spend_resource(str(resource_recipe["resource"]), int(resource_recipe["cost"]))
		elif use_free:
			ch.spend_resource("spell:%s" % spell_id)
		else:
			ch.expend_slot(slot)
			c.cast_slot_spell_this_turn = true
	if not boost.is_empty():
		ch.spend_resource(str((boost["cast_level_boost"] as Dictionary)["resource"]))
		slot = effective_slot
		e.log.add("info", "%s raises %s to effective level %d (%s; level %d slot spent)" % [c.name(), s["name"], slot, boost["name"], paid_slot], c.id)
	if bool(opts.get("splintered", false)):
		ch.spend_resource("splintered_summons")
	if c.hidden and bool((s.get("components", {}) as Dictionary).get("v", false)) and not e.faerun.sneaky_casting(c) \
			and not (level > 0 and c.creature.has_flag("waive_components:%s" % str(s.get("school", "")))) and not e.faerun.waives_components(c, spell_id):
		e.reveal(c, "cast a spell aloud")
	spells.end_sanctuary(c, "cast a spell")
	spells.trigger_ends(c, "cast_spell")
	for tt in tgt:
		if c.hostile_to(tt) and spell_id != "compelled_duel":
			spells.specials.duel_check_attack(c, tt)
	var nums := spells.numbers(c, entry)
	var conc: Concentration = null
	# Fey Reinforcements (Fey Wanderer 11): Summon Fey without Concentration, lasting 1 minute.
	var fey_free := spell_id == "summon_fey" and CombatFeatures.has_feature(c, "fey_reinforcements") and bool(opts.get("no_concentration", true))
	# Spirits of Ill Omen, Second Skin: some castings need no Concentration (RavenloftFeatures.skips_concentration).
	var unbound := e.ravenloft.skips_concentration(c, s, use_free) if bool((s.get("duration", {}) as Dictionary).get("concentration", false)) else {}
	if not unbound.is_empty():
		s = s.duplicate(true)
		s["duration"] = unbound
		e.log.add("info", "%s casts %s without Concentration" % [c.name(), s["name"]], c.id)
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)) and not fey_free:
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
		spells.zones.prune()
		spells._prune_sustained()
	var slot_text := " (level %d slot)" % slot if level > 0 and slot > 0 else (" (free casting)" if use_free else "")
	var choice := SpellCaster.choice_of(s, opts)
	e.log.add("spell", "%s casts %s%s%s" % [c.name(), s["name"], slot_text, (": " + choice.capitalize().replace("_", " ")) if choice != "" else ""], c.id, [
		"Spell save DC %d · Spell attack %+d" % [(nums["dc"] as Breakdown).total(), (nums["attack"] as Breakdown).total()]])
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = spells.area_for(c, s, point, direction, slot)
	# Fire Storm's ten 10-ft Cubes and Meteor Swarm's four Spheres at the points chosen (opts.points).
	if opts.has("points") and spell_id in ["fire_storm", "meteor_swarm"]:
		cells = spells.multi_area(c, spell_id, opts["points"] as Array)
	# Wall of Fire as a ring 20 ft across.
	if str((s.get("area", {}) as Dictionary).get("shape", "")) == "wall" and SpellCaster.choice_of(s, opts) in ["ring", "globe"] and point != Vector2.INF:
		cells = spells._ring(point, 10 if SpellCaster.choice_of(s, opts) == "ring" else 15)
	# A wall drawn square by square (opts.path) covers those squares; a ring takes its own size.
	cells = spells.targeting.wall_cells(s, opts, point, cells)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells,
		"targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": conc, "opts": opts, "point": point,
		"cells": cells, "choice": choice, "direction": direction, "cell": cell, "metamagic": meta, "spent_slot": level > 0 and not use_free, "paid_slot": paid_slot}
	if "transmuted" in meta and str(opts.get("transmute_to", "")) != "":
		ctx["transmute_to"] = str(opts["transmute_to"])
	if "heightened" in meta:
		ctx["heightened"] = tgt[0].id if not tgt.is_empty() else (spells._area_victims(c, s, cells)[0].id if not spells._area_victims(c, s, cells).is_empty() else "")
	if "extended" in meta:
		var s_ext := s.duplicate(true)
		var dd := s_ext.get("duration", {}) as Dictionary
		if dd.has("amount"):
			dd["amount"] = mini(int(dd["amount"]) * 2, 24 * 60 if str(dd.get("kind", "")) == "minutes" else 24)
		ctx["s"] = s_ext
		if conc != null:
			var steady := Effect.new("Extended Spell", &"feature", "extended_spell").with_modifier("advantage", {"on": "concentration"})
			conc.attach(c.creature, steady)
	var r := CombatResult.new()
	if "overchannel" in c.armed and level >= 1 and level <= 5 and s.has("damage"):
		c.armed.erase("overchannel")
		ctx["overchannel"] = true
		spells.options._overchannel_cost(c, level)
	ctx["targets"] = tgt
	e.faerun.before_resolve(ctx)
	return spells._before_attack_rolls(ctx, tgt, r, func() -> CombatResult:
		return e.then(_resolve(ctx, tgt, cells, r, true), func() -> CombatResult:
			spells.check_tethers()
			_finish_concentration(ctx)
			_after_cast_features(ctx, use_free)
			spells.zones.prune()
			e._check_over()
			return e.run_reaction_queue(r)))


## After a spell with a slot: the Abjurer's Arcane Ward (made or recharged by Abjuration spells), the Diviner's
## Expert Divination (a lower slot back after a Divination spell of level 2+).
func _after_cast_features(ctx: Dictionary, free: bool) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var slot := int(ctx.get("paid_slot", ctx["slot"]))
	if not free:
		enc().class_features.after_cast(c, s, slot)
		enc().feature_recipes.after_cast(c, s, slot)
	enc().ravenloft.after_cast(c, s, slot)
	enc().faerun.after_cast(c, s, slot, free, ctx)
	enc().triggered_features.after_cast(ctx)
	if str(s["id"]) == "hunters_mark" and CombatFeatures.has_feature(c, "hunters_rime"):
		var amount := enc().dice.roll_one(10, "Hunter’s Rime") + spells.caster_char(c).class_level_of("ranger")
		c.creature.add_temp_hp(amount, "Hunter’s Rime")
		enc().log.add("heal", "%s gains %d Temporary Hit Points (Hunter’s Rime)" % [c.name(), c.creature.temp_hp], c.id)
	if slot <= 0 or free or spells.caster_char(c) == null:
		return
	var ch := spells.caster_char(c)
	var e := enc()
	if str(s.get("school", "")) == "abjuration" and CombatFeatures.has_feature(c, "arcane_ward"):
		var cap := ch.resource_max("arcane_ward")
		if not c.has_meta("ward_made") and ch.resource_left("arcane_ward") > 0:
			c.set_meta("ward_made", true)
			ch.spend_resource("arcane_ward")
			c.creature.ward_hp = cap
			e.log.add("info", "%s weaves an Arcane Ward (%d Hit Points)" % [c.name(), cap], c.id)
		elif c.has_meta("ward_made"):
			c.creature.ward_hp = mini(cap, c.creature.ward_hp + 2 * slot)
			e.log.add("info", "%s's Arcane Ward strengthens to %d" % [c.name(), c.creature.ward_hp], c.id)
	if str(s.get("school", "")) == "divination" and slot >= 2 and CombatFeatures.has_feature(c, "expert_divination"):
		for l in range(mini(slot - 1, 5), 0, -1):
			if ch.slots_used[l - 1] > 0:
				ch.slots_used[l - 1] -= 1
				e.log.add("info", "%s regains a level %d slot (Expert Divination)" % [c.name(), l], c.id)
				break


## A monster casting from its stat block (combat/monster_actions.gd): the action economy as usual, no slots, the
## stat block's DC and attack bonus in `nums`, at `level`.
func cast_with_numbers(c: Combatant, spell_id: String, level: int, targets: Array, point: Vector2, nums: Dictionary, opts: Dictionary = {}) -> CombatResult:
	var spells := sp()
	var e := enc()
	if bool(opts.get("splintered", false)):
		return CombatResult.fail("Splintered Summons requires casting with a spell slot")
	var s := _comp().spell_data(spell_id)
	var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
	var why := "Not automated yet" if str(s.get("automation", "")) == "reference" else spells.economy_block(c, unit)
	if why == "" and (c.creature.has_flag("cant_cast") or spells.specials.high.in_antimagic(c)):
		why = "Can't cast spells here"
	if why != "":
		return CombatResult.fail(why)
	var check := spells._check_targets(c, s, level, targets, point, opts)
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	if unit == "bonus_action":
		c.bonus_available = false
	else:
		e.spend_action(c)
		c.magic_action_used = true
	var tgt := check["targets"] as Array[Combatant]
	if not spells.casting_gate(c):
		return CombatResult.new()
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	e.log.add("spell", "%s casts %s%s" % [c.name(), s["name"], " (level %d)" % level if level > int(s.get("level", 0)) else ""], c.id)
	var cells: Array[Vector2i] = []
	if s.has("area"):
		var dir: Vector2 = opts.get("direction", Vector2.ZERO)
		if not tgt.is_empty() and dir == Vector2.ZERO:
			dir = (e.center_of(tgt[0]) - e.center_of(c)).normalized()
		cells = spells.area_for(c, s, point, dir, level)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	if opts.has("points") and spell_id in ["fire_storm", "meteor_swarm"]:
		cells = spells.multi_area(c, spell_id, opts["points"] as Array)
	if str((s.get("area", {}) as Dictionary).get("shape", "")) == "wall" and SpellCaster.choice_of(s, opts) in ["ring", "globe"] and point != Vector2.INF:
		cells = spells._ring(point, 10 if SpellCaster.choice_of(s, opts) == "ring" else 15)
	# A wall drawn square by square (opts.path) covers those squares; a ring takes its own size.
	cells = spells.targeting.wall_cells(s, opts, point, cells)
	var ctx := {"c": c, "s": s, "slot": level, "nums": nums, "conc": conc, "opts": opts, "point": point, "cells": cells,
		"choice": SpellCaster.choice_of(s, opts), "direction": opts.get("direction", Vector2.ZERO), "cell": check["cell"]}
	var r := CombatResult.new()
	return spells._before_attack_rolls(ctx, tgt, r, func() -> CombatResult:
		return e.then(_resolve(ctx, tgt, cells, r, true), func() -> CombatResult:
			spells.check_tethers()
			_finish_concentration(ctx)
			spells.zones.prune()
			e._check_over()
			return e.run_reaction_queue(r)))


## Casts a spell without a slot or the usual action (War God's Blessing, features that cast spells): opts may say
## no_concentration (it lasts its `minutes` instead).
func cast_free(c: Combatant, spell_id: String, targets: Array, point: Vector2, opts: Dictionary = {}) -> CombatResult:
	var spells := sp()
	if bool(opts.get("splintered", false)):
		return CombatResult.fail("Splintered Summons requires casting with a spell slot")
	var e := enc()
	var s := _comp().spell_data(spell_id)
	if s.is_empty():
		return CombatResult.fail("Unknown spell")
	if str(s.get("automation", "")) == "reference":
		return CombatResult.fail("Not automated yet")
	if spells.specials.high.in_antimagic(c):
		return CombatResult.fail("Can't cast spells inside an Antimagic Field")
	var level := int(s.get("level", 0))
	var check := spells._check_targets(c, s, level, targets, point, opts)
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	var tgt := check["targets"] as Array[Combatant]
	if not spells.casting_gate(c):
		return CombatResult.new()
	var conc: Concentration = null
	var s2 := s.duplicate(true)
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		if bool(opts.get("no_concentration", false)):
			s2["duration"] = {"kind": "minutes", "amount": int(opts.get("minutes", 1))}
		else:
			conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var entry := spells._entry_any(c, spell_id)
	if entry.is_empty():
		entry = {"class_id": "cleric" if spells.caster_char(c) != null and spells.caster_char(c).class_level_of("cleric") > 0 else ""}
	var nums := spells.numbers(c, entry)
	e.log.add("spell", "%s casts %s (no slot)" % [c.name(), s["name"]], c.id)
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = spells.area_for(c, s2, point, Vector2.ZERO, level)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": s2, "slot": level, "nums": nums, "conc": conc, "opts": opts, "point": point, "cells": cells,
		"choice": SpellCaster.choice_of(s, opts), "direction": Vector2.ZERO, "cell": check["cell"]}
	var r := CombatResult.new()
	return spells._before_attack_rolls(ctx, tgt, r, func() -> CombatResult:
		return e.then(_resolve(ctx, tgt, cells, r, true), func() -> CombatResult:
			spells.check_tethers()
			_finish_concentration(ctx)
			spells.zones.prune()
			e._check_over()
			return r))


## Concentration with nothing to keep ends at once (a Hold Person everyone saved against); spells that leave an
## area, an object, a summon or a sustained action keep it.
func _finish_concentration(ctx: Dictionary) -> void:
	var spells := sp()
	var conc := ctx["conc"] as Concentration
	if conc == null or conc.ended:
		return
	var c := ctx["c"] as Combatant
	var id := str((ctx["s"] as Dictionary)["id"])
	if conc.effect_count() > 0:
		return
	for o in spells.zones.objects:
		if o.concentration == conc and not o.expired():
			return
	for a in spells.sustained:
		if a["conc"] != null and (a["conc"] as WeakRef).get_ref() == conc:
			return
	if spells.summoned.has(c.id) and not (spells.summoned[c.id] as Array).is_empty():
		return
	if id in ["haste", "fly", "levitate"]:
		return
	conc.end("no one was affected")


## Resolves the spell's recipe on its targets. `pausable`: the caller carries on after a prompt (Encounter.then), so
## the targets' saves can stop for the choices after their rolls (SpellSaves._save_spell).
func _resolve(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult, pausable: bool = false) -> CombatResult:
	var spells := sp()
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	# Rod of Absorption, Staff of the Magi: a spell aimed at one creature alone can be soaked up.
	if enc().items.absorbs_spell(ctx, tgt, cells, r):
		return r
	# Cube of Force (spells face), Scroll of Protection: creatures the spell can't reach.
	tgt.assign(tgt.filter(func(t: Combatant) -> bool: return enc().items.spell_blocked(c, t) == ""))
	if spells.specials.resolve(ctx, tgt, cells, r):
		return r
	if enc().faerun.resolve_spell(ctx, tgt, cells, r):
		return r
	match str(s["id"]):
		"magic_missile":
			spells.handlers._magic_missile(ctx, tgt, r)
			return r
		"sleep":
			spells.handlers._sleep(ctx, cells, r)
			return r
		"command":
			for t in tgt:
				spells._command(ctx, t, str(ctx["choice"]) if str(ctx["choice"]) != "" else str((ctx["opts"] as Dictionary).get("word", "grovel")), r)
			return r
		"sanctuary":
			spells.handlers._sanctuary(ctx, tgt[0], r)
			return r
		"spare_the_dying":
			spells.handlers._spare_the_dying(ctx, tgt[0], r)
			return r
		"misty_step":
			if spells.specials.high.teleport_blocked(ctx, c):
				return r
			var start := c.cell
			spells._teleport(c, ctx["cell"] as Vector2i, r)
			enc().class_features.fey_step_rider(c, start)
			return r
		"revivify":
			spells.handlers._revivify(ctx, tgt[0], r)
			return r
		"arcane_vigor":
			spells.handlers._arcane_vigor(ctx, r)
			return r
		"dispel_magic":
			spells._dispel(ctx, tgt[0], r)
			return r
		"find_familiar":
			if ClassFeatures.knows_invocation(c, "pact_of_the_chain"):
				var form := str((ctx["opts"] as Dictionary).get("choice", "imp"))
				ctx["choice"] = form if form in SummonBlocks.CHAIN_FORMS else "imp"
			elif CombatFeatures.has_feature(c, "necromancy_familiar"):
				# Necromancy Familiar: a Skeleton, a Zombie or an Undead owl.
				var nform := str((ctx["opts"] as Dictionary).get("choice", "skeleton"))
				ctx["choice"] = nform if nform in ["skeleton", "zombie", "owl"] else "skeleton"
			for old_id: Variant in spells.summoned.get(c.id, []):
				var oldf := enc().get_c(str(old_id))
				if oldf != null and oldf.is_alive() and oldf.creature is Monster and bool((oldf.creature as Monster).data.get("familiar", false)):
					spells._dismiss(oldf.id)
			spells._summon(ctx, ctx["cell"] as Vector2i, r)
			return r
		"summon_fey", "summon_undead", "find_steed", "summon_beast", "giant_insect", "summon_aberration", "summon_construct", "summon_elemental", \
				"summon_celestial", "summon_dragon", "summon_fiend", "summon_dinosaur", "summon_plant":
			spells._summon(ctx, ctx["cell"] as Vector2i, r)
			return r
		"true_strike":
			spells.handlers._true_strike(ctx, tgt[0], r)
			return r
		"booming_blade", "green_flame_blade":
			spells.handlers._blade_cantrip(ctx, tgt[0], r)
			return r
		"remove_curse":
			var t0 := tgt[0]
			var gone := 0
			for fx: Effect in t0.creature.effects.duplicate():
				if fx.source_id == "bestow_curse" or fx.modifiers.any(func(m: Modifier) -> bool: return m.text("value").begins_with("curse:")):
					t0.creature.remove_effect(fx)
					gone += 1
			r.lines.append(enc().log.add("spell", "%s: %s" % [s["name"], "%d curse%s lifted from %s" % [gone, "" if gone == 1 else "s", t0.name()] if gone > 0 else "%s bears no curse" % t0.name()], c.id))
			return r
		"etherealness", "plane_shift":
			c.creature.dead = true
			enc().events.append({"type": "vanish", "id": c.id})
			r.lines.append(enc().log.add("info", "%s slips away (%s)" % [c.name(), s["name"]], c.id))
			return r
		"expeditious_retreat":
			c.movement_left += c.speed()
			enc().log.add("info", "%s Dashes (+%d ft)" % [c.name(), c.speed()], c.id)
	if s.has("object"):
		spells.placement._place_object(ctx, tgt, r)
		return r
	var sub := r
	if s.has("zone"):
		spells._place_zone(ctx, cells, r)
		spells.apply_effect_entries(ctx, c, (s["zone"] as Dictionary).get("caster_effects", []) as Array, "cast", r)
		# The spell resolves as usual and leaves an area behind (Ice Storm's hail on the ground).
		if bool((s["zone"] as Dictionary).get("resolve_on_cast", false)):
			sub = _generic(ctx, tgt, cells, r, pausable)
	else:
		sub = _generic(ctx, tgt, cells, r, pausable)
	if not pausable:
		return _after_generic(ctx, tgt, r)
	return enc().then(sub, func() -> CombatResult: return _after_generic(ctx, tgt, r))


## After the recipe: the actions a sustained spell grants (unless a save ended it) and Eldritch Hex.
func _after_generic(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> CombatResult:
	var spells := sp()
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	if s.has("sustain") and not bool(ctx.get("ended_on_save", false)):
		spells._grant_sustained(ctx, tgt)
	# Eldritch Hex (Great Old One 10): the hexed creature also has Disadvantage on saves of the chosen ability.
	if str(s["id"]) == "hex" and CombatFeatures.has_feature(c, "eldritch_hex") and not tgt.is_empty() and str(ctx.get("choice", "")) != "":
		var eh := Effect.new("Eldritch Hex", &"spell", "hex").with_modifier("disadvantage", {"on": "save:%s" % ctx["choice"]})
		eh.caster_id = c.id
		eh.stack_key = "spell:hex:eldritch"
		spells._set_duration(eh, ctx, tgt[0], "spell")
		var hc := ctx["conc"] as Concentration
		if hc != null:
			hc.attach(tgt[0].creature, eh)
		else:
			tgt[0].creature.add_effect(eh)
	return r


## A spell's recipe in general: attack rolls, or saves (then a secondary burst), or healing, or damage and effects.
## `pausable` as for _resolve.
func _generic(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult, pausable: bool = false) -> CombatResult:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var victims: Array[Combatant] = tgt
	if not cells.is_empty() and not s.has("attack"):
		victims = spells._area_victims(c, s, cells, str(ctx.get("choice", "")))
	if s.has("attack"):
		for t in spells.attack_shots(ctx, tgt):
			if t.is_alive():
				spells.spell_attack(ctx, t, r)
		return r
	if s.has("save"):
		var prior_hp := {}
		for victim in victims:
			prior_hp[victim.id] = victim.creature.hp
		var secondary := func() -> CombatResult:
			if s.has("secondary"):
				for victim in victims:
					var follow := ctx.duplicate()
					follow["reduced_to_zero"] = int(prior_hp[victim.id]) > 0 and victim.creature.hp == 0
					spells._secondary(follow, victim, r)
			return r
		var saved := spells._save_spell(ctx, victims, r, pausable)
		return enc().then(saved, secondary) if pausable else secondary.call() as CombatResult
	if s.has("heal"):
		for t in victims:
			spells.damage._heal(ctx, t, r)
		for t in victims:
			spells.apply_effect_entries(ctx, t, s.get("effects", []) as Array, "cast", r)
		return r
	# A self-targeted spell whose damage comes from a later action (Produce Flame's hurl) doesn't burn the caster.
	var self_held := str((s.get("targets", {}) as Dictionary).get("kind", "")) == "self" and s.has("sustain")
	if s.has("damage") and not self_held:
		var rolled := spells.roll_damage_parts(ctx, s["damage"] as Array, false, null)
		for t in victims:
			enc().deal_damage(c, t, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false, str(s["name"]), [str(rolled["text"])])
	for t in victims:
		if s.has("temp_hp"):
			spells.damage._temp_hp(ctx, t, r)
		spells.apply_effect_entries(ctx, t, s.get("effects", []) as Array, "cast", r)
	return r
