class_name SpellSaves
extends RefCounted
## Saving throws against spells in a fight (SpellCaster): damage rolled once for every target, half on a success,
## cover for Dexterity saves, Sculpt Spells and Careful Spell, pushes resolved farthest first, and the repeated saves
## an effect allows at the start or end of a turn.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Saving-throw spells: damage rolled once for all targets; each target saves (Dexterity saves add cover from
## the point of origin, except Sacred Flame; creature-type Disadvantage like Shatter against Constructs); half
## damage on a success when the spell says so (or for Potent Cantrip); effects on a failure or a success; pushes
## and pulls afterwards, farthest creature first so a pack isn't blocked by its own back row. `pausable`: the caller
## carries on after a prompt (Encounter.then), so each save stops for the choices after its roll (Indomitable, an ally's
## Bend Luck...); otherwise they follow their rules at once.
func _save_spell(ctx: Dictionary, victims: Array[Combatant], r: CombatResult, pausable: bool = false) -> CombatResult:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var has_damage := s.has("damage") and not (s["damage"] as Array).is_empty()
	var shared := ctx.get("shared_damage", {}) as Dictionary
	# Several damage types at once (Ice Storm's Bludgeoning and Cold): each part rolled once, halved on its own.
	var multi: Array[Dictionary] = []
	if has_damage and (s["damage"] as Array).size() > 1:
		for i in (s["damage"] as Array).size():
			var part := (s["damage"] as Array)[i] as Dictionary
			if str(part.get("per", "")) == "turn":
				continue
			var pr := spells.roll_damage_parts(ctx, [part], false, null)
			if i == 0:
				var bonus0 := spells.damage._damage_bonus(ctx)
				pr["total"] = int(pr["total"]) + bonus0.total()
			multi.append(pr)
	elif has_damage and str(s["id"]) != "toll_the_dead" and shared.is_empty():
		shared = spells.damage._roll_spell_damage(ctx, null, false)
	var pushes: Array[Dictionary] = []
	ctx["push_queue"] = pushes
	var st := {"has_damage": has_damage, "shared": shared, "multi": multi,
		"half": str(s.get("save_success", "none")) == "half" or (int(s.get("level", 0)) == 0 and c.creature.has_flag("potent_cantrip"))}
	var done := func() -> CombatResult:
		ctx.erase("push_queue")
		_run_pushes(ctx, pushes)
		# The objects in the area take the damage too, and fire lights oil and burns webs there (EncounterObjects).
		enc().objects.area_spell(ctx, ctx.get("cells", []) as Array, shared, multi, bool(s.get("ignites_objects", false)))
		return r
	if not pausable:
		for t in victims:
			_save_victim(ctx, t, victims, st, r, false)
		return done.call() as CombatResult
	return enc().each(victims, func(t: Variant) -> CombatResult: return _save_victim(ctx, t as Combatant, victims, st, r, true), done)


## One creature's save against the spell, then what it does to that creature (_after_save).
func _save_victim(ctx: Dictionary, t: Combatant, victims: Array[Combatant], st: Dictionary, r: CombatResult, pausable: bool) -> CombatResult:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var spells := sp()
	if not t.is_alive():
		return r
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var ab := StringName(str(s["save"]))
	if c.hostile_to(t):
		e.class_features.kept_rage(c)
	var bonus_text := ""
	var save_bd := t.creature.save_bonus(ab)
	if ab == &"dex" and str(s["id"]) != "sacred_flame":
		var cov := e.grid.cover_between(c.cell, c.size_cells, t.cell, t.size_cells, e.creature_cells([c, t]))
		var cb := CombatGrid.COVER_BONUS[int(cov["cover"])]
		if cb > 0:
			save_bd.add(CombatGrid.COVER_NAMES[int(cov["cover"])], cb)
			bonus_text = " (cover +%d)" % cb
	var keys := t.creature.save_keys(ab)
	for cond in _conditions_in(s.get("effects", []) as Array, str(ctx.get("choice", ""))):
		keys.append("save_vs:%s" % cond)
	keys.append_array(spell_save_keys(c.id))
	var dis: Array[String] = []
	dis.assign(ctx.get("save_disadvantage", []))
	var adv: Array[String] = []
	if t.creature.has_flag("eldritch_struck:%s" % c.id):
		dis.append("Eldritch Strike")
	if CombatFeatures.has_feature(c, "magical_ambush") and (c.hidden or c.creature.has_condition(&"invisible")):
		dis.append("Magical Ambush")
	if c.creature.has_flag("corona") and e.in_sunlight(t) and c.hostile_to(t) and spells._damage_type_safe(ctx) in ["fire", "radiant"]:
		dis.append("Corona of Light")
	var sculpted := _sculpted(ctx, t) or _careful(ctx, t) or e.items.specials.fr.banded(ctx, t)
	if str(ctx.get("heightened", "")) == t.id:
		dis.append("Heightened Spell")
	var vs := s.get("save_disadvantage_for", "") as String
	if vs != "" and str(t.creature.creature_type) == vs:
		dis.append("%s against %s" % [vs.capitalize(), s["name"]])
	if bool(s.get("save_advantage_if_fighting", false)) and c.hostile_to(t):
		adv.append("you're fighting it")
	var min_size := str(s.get("save_advantage_min_size", ""))
	if min_size != "" and Creature.SIZES.find(t.creature.size) >= Creature.SIZES.find(StringName(min_size)):
		adv.append("%s or larger" % min_size.capitalize())
	if str(s["id"]) == "sleep" and t.creature.is_condition_immune(&"exhaustion"):
		r.lines.append(e.log.add("info", "%s doesn't sleep: unaffected" % t.name(), t.id))
		return r
	var willing := bool(s.get("willing_skip_save", false)) and c.allied_with(t)
	# Enthrall: a creature you or your companions are fighting succeeds automatically.
	if bool(s.get("fighting_auto_success", false)) and c.hostile_to(t):
		r.lines.append(e.log.add("info", "%s is too caught up in the fight to be enthralled" % t.name(), t.id))
		return r
	var auto_fail := str(t.creature.creature_type) in (s.get("auto_fail_types", []) as Array)
	if sculpted:
		r.lines.append(e.log.add("info", "%s is sculpted out of %s" % [t.name(), s["name"]], t.id))
		return r
	var details: Array[String] = []
	if str(t.creature.creature_type) in (s.get("auto_success_types", []) as Array):
		details.append("%s succeeds automatically (%s)" % [t.name(), str(t.creature.creature_type).capitalize()])
		return _after_save(ctx, t, true, details, victims, st, r)
	if auto_fail:
		details.append("%s fails automatically (%s)" % [t.name(), str(t.creature.creature_type).capitalize()])
		return _after_save(ctx, t, false, details, victims, st, r)
	if willing:
		details.append("%s doesn't resist" % t.name())
		return _after_save(ctx, t, false, details, victims, st, r)
	var roll := func() -> D20Test:
		return t.creature.roll_d20(e.dice, D20Test.Kind.SAVING_THROW, save_bd, dc, keys, adv, dis,
			"%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], s["name"], t.name()])
	var after := func(test: D20Test) -> CombatResult:
		details.append(test.describe() + bonus_text)
		return _after_save(ctx, t, test.success, details, victims, st, r)
	if pausable:
		return e.d20.then_after(t, roll, after, r)
	return after.call(roll.call() as D20Test) as CombatResult


## What the spell does to `t` once its save is settled: Spell Turning and reflection, damage (whole or half), the
## effects on a failure or a success, and a spell that ends on a successful save.
func _after_save(ctx: Dictionary, t: Combatant, success: bool, details: Array[String], victims: Array[Combatant], st: Dictionary, r: CombatResult) -> CombatResult:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var spells := sp()
	var ab := StringName(str(s["save"]))
	var half_on_success := bool(st["half"])
	var multi := st["multi"] as Array[Dictionary]
	var shared := st["shared"] as Dictionary
	# Ring of Spell Turning: a saved-against spell of level 7 or lower has no effect (and may go back at its caster).
	if success and e.items.turns_spell(c, t, ctx, victims, r):
		return r
	if success:
		e.faerun.reflects_spell(c, t, ctx, victims, r)
	if bool(st["has_damage"]) and not multi.is_empty():
		var parts: Array = []
		for pr in multi:
			var amt := int(pr["total"])
			amt = t.creature.damage_after_save(amt, ab, success, half_on_success, true)
			parts.append({"amount": amt, "type": str(pr["type"]), "spell": true})
			details.append(str(pr["text"]))
		if parts.any(func(x: Dictionary) -> bool: return int(x["amount"]) > 0):
			var drm := spells.deal_spell_damage(ctx, t, parts, false, str(s["name"]), details)
			r.damage += drm.final
		else:
			r.lines.append(e.log.add("info", "%s saves against %s" % [t.name(), s["name"]], t.id, details))
	elif bool(st["has_damage"]):
		var rolled := shared if not shared.is_empty() else spells.damage._roll_spell_damage(ctx, t, false)
		var amount := int(rolled["total"])
		amount = t.creature.damage_after_save(amount, ab, success, half_on_success, true)
		# Shield Master's Interpose Shield: a Reaction turns a successful Dexterity save's half damage into none.
		if success and ab == &"dex" and half_on_success and e.features.has_feat(t, "shield_master") and e.features.wields_shield(t) and spells.can_react(t) \
				and e._reaction_decision(t, "interpose_shield") != "never":
			t.reaction_available = false
			amount = 0
			details.append("Interpose Shield: no damage")
		details.append(str(rolled["text"]))
		if amount > 0:
			var dr := spells.deal_spell_damage(ctx, t, [{"amount": amount, "type": spells._damage_type(ctx), "spell": true}], false, str(s["name"]), details)
			r.damage += dr.final
			# Harm: a failed save lowers the Hit Point maximum by the Necrotic damage taken (never below 1).
			if bool(s.get("reduce_max_hp", false)) and not success and dr.final > 0 and t.is_alive():
				var cut := mini(dr.final, t.creature.max_hp() - 1)
				if cut > 0:
					e.monster_actions.drain_max_hp(t, cut, str(s["name"]))
		else:
			r.lines.append(e.log.add("info", "%s saves against %s" % [t.name(), s["name"]], t.id, details))
	else:
		r.lines.append(e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if success else "fails", s["name"]], t.id, details))
	if t.is_alive():
		spells.apply_effect_entries(ctx, t, s.get("effects", []) as Array, "success" if success else "fail", r)
	if success and bool(s.get("ends_on_save", false)):
		ctx["ended_on_save"] = true
		if ctx["conc"] != null:
			(ctx["conc"] as Concentration).end("successful save")
	return r


## The conditions a spell's effects impose (for saves against them: Dwarven Resilience, Fey Ancestry, Brave).
static func _conditions_in(entries: Array, choice: String) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in entries:
		var p := (raw as Dictionary).get("params", {}) as Dictionary
		if str((raw as Dictionary).get("effect", "")) == "condition":
			var cond := str(p.get("condition", ""))
			if cond == "choice":
				cond = choice
			if cond != "" and not cond in out:
				out.append(cond)
	return out


## Sculpt Spells (Evoker 6): allies the caster chooses (up to 1 + the spell's level) in an Evocation spell's area
## automatically succeed and take no damage.
func _sculpted(ctx: Dictionary, t: Combatant) -> bool:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if t == c or not c.allied_with(t) or str(s.get("school", "")) != "evocation" or not CombatFeatures.has_feature(c, "sculpt_spells"):
		return false
	var used := int(ctx.get("sculpted", 0))
	if used >= 1 + int(s.get("level", 0)):
		return false
	ctx["sculpted"] = used + 1
	return true


## Careful Spell: up to the caster's Charisma modifier allies automatically succeed and take no damage.
func _careful(ctx: Dictionary, t: Combatant) -> bool:
	var c := ctx["c"] as Combatant
	if not "careful" in (ctx.get("metamagic", []) as Array) or t == c or not c.allied_with(t):
		return false
	var used := int(ctx.get("careful_used", 0))
	if used >= maxi(1, c.creature.ability_mod(&"cha")):
		return false
	ctx["careful_used"] = used + 1
	return true


func _run_pushes(ctx: Dictionary, pushes: Array[Dictionary]) -> void:
	if pushes.is_empty():
		return
	var e := enc()
	var c := ctx["c"] as Combatant
	var origin: Vector2 = ctx.get("pull_origin", e.center_of(c))
	pushes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := a["target"] as Combatant
		var tb := b["target"] as Combatant
		var da := (e.center_of(ta) - origin).length()
		var db := (e.center_of(tb) - origin).length()
		return da > db if not bool(a["toward"]) else da < db)
	for p in pushes:
		var t := p["target"] as Combatant
		if not t.is_alive():
			continue
		var moved := e.forced_move(t, origin, int(p["feet"]), bool(p["toward"]))
		if moved > 0:
			e.log.add("info", "%s is %s %d ft (%s)" % [t.name(), "pulled" if bool(p["toward"]) else "pushed", moved * 5, (ctx["s"] as Dictionary)["name"]], t.id)
		else:
			e.log.add("info", "%s can't be %s: something's in the way" % [t.name(), "pulled" if bool(p["toward"]) else "pushed"], t.id)


## Kept for callers of the old name: the end-of-turn repeated saves.
func end_of_turn_saves(c: Combatant) -> void:
	_repeat_saves(c, "end")


## Effects with a repeated save at the start or end of the creature's turn (Hold Person, Slow, Fear, Sleep's
## drowsiness, Tasha's Hideous Laughter). `pausable`: the turn carries on after a prompt (EncounterTurns), so each save
## stops for the choices after its roll (Indomitable, Heroic Inspiration...).
func _repeat_saves(c: Combatant, when: String, pausable: bool = false) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var one := func(raw: Variant) -> CombatResult:
		var fx := raw as Effect
		if fx.repeat_save.is_empty() or str(fx.repeat_save.get("when", "end")) != when or not fx in c.creature.effects:
			return r
		if str(fx.repeat_save.get("if", "")) == "no_sight_of_caster":
			var caster := e.get_c(fx.caster_id)
			if caster != null and e.can_see(c, caster):
				return r
		# Illusory Dragon: only while the dragon is out of sight.
		if str(fx.repeat_save.get("if", "")) == "no_sight_of_object":
			var obj := sp().zones.object_of(fx.caster_id, fx.source_id)
			if obj != null and e.can_see_space(c, obj.cell):
				return r
		return _repeat_save(c, fx, [], pausable)
	var due := c.creature.effects.duplicate()
	if not pausable:
		for fx: Effect in due:
			one.call(fx)
		return r
	return e.each(due, one, func() -> CombatResult: return r)


## One repeated save against `fx` (also on taking damage, with `adv`), then what it settles.
func _repeat_save(c: Combatant, fx: Effect, adv: Array[String], pausable: bool = false) -> CombatResult:
	var e := enc()
	var ab := StringName(str(fx.repeat_save.get("ability", "wis")))
	var dc := int(fx.repeat_save.get("dc", 10))
	var keys: Array[String] = []
	if fx.source_kind == &"spell":
		keys = spell_save_keys(fx.caster_id)
	var roll := func() -> D20Test:
		return c.creature.roll_save(e.dice, ab, dc, adv, [], "%s save to end %s (%s)" % [Creature.ABILITY_NAMES[ab], fx.name, c.name()], keys)
	var after := func(test: D20Test) -> CombatResult: return _repeat_settled(c, fx, test)
	if pausable:
		return e.d20.then_after(c, roll, after, CombatResult.new())
	return after.call(roll.call() as D20Test) as CombatResult


func _repeat_settled(c: Combatant, fx: Effect, test: D20Test) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var then_kind := str(fx.repeat_save.get("then", ""))
	# Contagion and Flesh to Stone: three successes end it; three failures settle it (lasting, or Petrified).
	var three := str(fx.repeat_save.get("three", ""))
	if three != "":
		var key := "wins" if test.success else "fails"
		fx.data[key] = int(fx.data.get(key, 0)) + 1
		e.log.add("info", "%s %s the save against %s (%d of 3)" % [c.name(), "wins" if test.success else "fails", fx.name, int(fx.data[key])], c.id, [test.describe()])
		if int(fx.data.get("wins", 0)) >= 3:
			c.creature.remove_effect(fx)
			e.log.add("info", "%s throws off %s" % [c.name(), fx.name], c.id)
		elif int(fx.data.get("fails", 0)) >= 3:
			fx.repeat_save = {}
			if three == "petrify":
				fx.conditions = [&"petrified"]
				e.log.add("condition", "%s turns to stone" % c.name(), c.id)
			else:
				e.log.add("condition", "%s succumbs to %s for its full course" % [c.name(), fx.name], c.id)
		e.events.append({"type": "condition", "id": c.id})
		return r
	if test.success:
		c.creature.remove_effect(fx)
		e.log.add("info", "%s shakes off %s" % [c.name(), fx.name], c.id, [test.describe()])
		e.events.append({"type": "condition", "id": c.id})
		e.faerun.after_save_ended(c, fx)
	elif then_kind == "sleep_unconscious":
		c.creature.remove_effect(fx)
		var deep := Effect.new("Sleep", &"spell", "sleep").with_condition(&"unconscious")
		deep.caster_id = fx.caster_id
		deep.ends_on_damage = true
		deep.stack_key = fx.stack_key
		deep.data = {"wakeable": true}
		if fx.concentration != null:
			fx.concentration.attach(c.creature, deep)
		else:
			c.creature.add_effect(deep)
		e.log.add("condition", "%s falls Unconscious (Sleep)" % c.name(), c.id, [test.describe()])
		e.events.append({"type": "condition", "id": c.id})
	else:
		e.log.add("info", "%s is still affected by %s" % [c.name(), fx.name], c.id, [test.describe()])
		# An arcanaloth's Soul Tome: three failed saves bind the prisoner for good.
		if fx.repeat_save.has("bind_after"):
			fx.data["fails"] = int(fx.data.get("fails", 0)) + 1
			if int(fx.data["fails"]) >= int(fx.repeat_save["bind_after"]):
				fx.repeat_save = {}
				e.log.add("condition", "%s is bound fast (%s)" % [c.name(), fx.name], c.id)
		for ignored in int(fx.repeat_save.get("fail_exhaustion", 0)):
			c.creature.add_exhaustion()
		var fd := fx.repeat_save.get("fail_damage", {}) as Dictionary
		if not fd.is_empty():
			var rolled := e._roll_damage_dice(str(fd["dice"]), false, 0, fx.name)
			e.deal_damage(e.get_c(fx.caster_id), c, [{"amount": int(rolled["total"]), "type": str(fd["type"]), "spell": true}], false, fx.name, [str(rolled["text"])])
	return r


static func spell_save_keys(caster_id: String) -> Array[String]:
	var keys: Array[String] = ["save_vs:spell", "save_vs:magic"]
	if caster_id != "":
		keys.append("save_vs:spell:" + caster_id)
	return keys
