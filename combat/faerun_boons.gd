class_name FaerunBoons
extends FaerunCommon
## Epic boons from Heroes of Faerûn and Arcana Unleashed in a fight (FaerunFeatures).


## The epic boons' actions: Exquisite Radiance armed, Fluid Forms' shapes, the Bright Sun.
func _boon_list(c: Combatant, ch: Character, out: Array[Dictionary], tw: String) -> void:
	var e := enc()
	if feat(c, "boon_of_exquisite_radiance") and ch.resource_left("exquisite_radiance") > 0:
		var armed := bool(c.get_meta("radiance_armed", false))
		out.append(_entry("radiance_arm", "Exquisite Radiance" + (" (armed)" if armed else ""), "maximize a Radiant roll", "free", tw, "none",
			"Arm it: the next Radiant damage roll you make uses the maximum on every die. Once per Long Rest. Click again to hold it back."))
	if feat(c, "boon_of_fluid_forms"):
		var fw := _first(_first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else ""), _res_why(c, "fluid_forms"))
		var ff := _entry("fluid_forms", "Fluid Shape", "CR 10 or lower · 1 hour", "action", fw, "none",
			"Magic action: become a Beast, Humanoid or Monstrosity of Challenge Rating 10 or lower for 1 hour, with its Hit Points as Temporary Hit Points (and 20 more). You keep your mind, Hit Points and spellcasting. Once per Long Rest.")
		var forms: Array = [{"value": "", "label": "Strongest"}]
		for f in fluid_forms():
			forms.append({"value": str(f["id"]), "label": "%s (CR %s)" % [f.get("name", ""), str(f.get("cr", 0))]})
		ff["choices"] = forms
		ff["choice_label"] = "Shape"
		out.append(ff)
	if feat(c, "boon_of_the_bright_sun"):
		var lit := _sun_of(c) != null
		out.append(_entry("bright_sun", "End the Bright Sun" if lit else "Bright Sun", "no action" if lit else "30 ft of sunlight",
			"free" if lit else "bonus", tw if lit else e._bonus_check(c), "none",
			"End the sunlight." if lit else "Bonus Action: shine with sunlight in a 30-ft Emanation that dispels magical Darkness; you and allies you can see in it gain 10 Temporary Hit Points at the start of each of your turns."))


## A creature drops: Exquisite Radiance's final rest, Bloodshed's taste of blood, the Soul Drinker's siphon.
func _boons_on_death(source: Combatant, dead: Combatant) -> void:
	var e := enc()
	if source != null and feat(source, "boon_of_exquisite_radiance"):
		dead.set_meta("no_undead", true)
	for h in e.combatants:
		if h == dead or not h.is_alive() or h.is_down() or not h.hostile_to(dead):
			continue
		if feat(h, "boon_of_bloodshed") and e.can_see_space(h, dead.cell):
			var fx := Effect.new("Taste of Blood", &"feature", "boon_of_bloodshed").with_modifier("flag", {"value": "bloodshed_advantage"})
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = h.id
			fx.skip_turn_ends = e.own_turn_skip(h)
			fx.ends_on.append("attack_roll")
			fx.stack_key = "boon_of_bloodshed"
			h.creature.add_effect(fx)
		var hc := _ch(h)
		if hc != null and feat(h, "boon_of_the_soul_drinker") and hc.resource_left("siphon_life") > 0 and allowed(h, "siphon_life") \
				and e.spells.can_react(h) and e.distance(h, dead) <= 120 and h.creature.hp < h.creature.max_hp():
			hc.spend_resource("siphon_life")
			h.reaction_available = false
			var got := h.creature.heal(50, "Siphon Life")
			_log("heal", "%s drinks the fading life of %s: +%d Hit Points (Boon of the Soul Drinker)" % [h.name(), dead.name(), got], h)
			e.events.append({"type": "heal", "id": h.id, "amount": got})


## Boon of Bloodshed: once per turn while Bloodied, a hit adds the Proficiency Bonus of its damage type.
func _bloodshed_dice(c: Combatant, ty: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if feat(c, "boon_of_bloodshed") and c.creature.is_bloodied() and allowed(c, "bloodshed_strike") and _once_per_turn(c, "bloodshed_turn"):
		out.append({"dice": str(c.creature.proficiency_bonus()), "type": ty, "label": "Boon of Bloodshed"})
	return out


## Whether every die of `c`'s damage roll of type `ty` counts as its maximum now (spent when it does): Boon of
## Exquisite Radiance once armed, Boon of Poison Mastery once per turn.
func maximized(c: Combatant, ty: String) -> bool:
	if c == null:
		return false
	var ch := _ch(c)
	if ty == "radiant" and ch != null and bool(c.get_meta("radiance_armed", false)) and ch.resource_left("exquisite_radiance") > 0:
		ch.spend_resource("exquisite_radiance")
		c.remove_meta("radiance_armed")
		_log("info", "%s's radiance burns at its brightest (Boon of Exquisite Radiance)" % c.name(), c)
		return true
	if ty == "poison" and feat(c, "boon_of_poison_mastery") and _once_per_turn(c, "poison_mastery_turn"):
		return true
	return false


## Boon of Fluid Forms: the shapes it allows.
static func fluid_forms() -> Array[Dictionary]:
	return HighMagic.forms(10.0, ["beast", "humanoid", "monstrosity"])


## Boon of Fluid Forms: 20 more Temporary Hit Points from any change of shape.
static func shape_temp_bonus(cr: Creature) -> int:
	var ch := cr as Character if cr is Character else null
	if ch != null and ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "boon_of_fluid_forms"):
		return 20
	return 0


func _fluid_form(c: Combatant, pick: String) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var why := _first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else "")
	if why != "":
		return CombatResult.fail(why)
	if ch.resource_left("fluid_forms") <= 0:
		return CombatResult.fail("None left")
	var form := {}
	for f in fluid_forms():
		if str(f["id"]) == pick:
			form = f
	if form.is_empty():
		var all := fluid_forms()
		if all.is_empty():
			return CombatResult.fail("No shape to take")
		form = all[all.size() - 1]
	ch.spend_resource("fluid_forms")
	e.spend_action(c)
	c.magic_action_used = true
	e.shapes.transform(c, form, {"temp_hp": int((form.get("hp", {}) as Dictionary).get("average", 1)), "keep_mind": true,
		"ends_without_temp_hp": true, "label": "Fluid Forms"})
	return CombatResult.new()


## Boon of the Bright Sun: the sunlight shining from `c`, or null.
func _sun_of(c: Combatant) -> FieldObject:
	return enc().spells.zones.object_of(c.id, "boon_of_the_bright_sun") if c != null else null


func _bright_sun(c: Combatant) -> CombatResult:
	var e := enc()
	if _sun_of(c) != null:
		var o := _sun_of(c)
		o.ended = true
		e.spells.zones.prune()
		_log("info", "%s lets the sunlight fade (Boon of the Bright Sun)" % c.name(), c)
		return CombatResult.new()
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	c.bonus_available = false
	var o2 := FieldObject.new(FieldObject.Kind.ZONE, "boon_of_the_bright_sun", "Bright Sun")
	o2.caster_id = c.id
	o2.cell = c.cell
	o2.cells = [c.cell]
	o2.origin = e.center_of(c)
	o2.follows_caster = true
	o2.rules = {"light": {"bright": 30, "dim": 0, "sunlight": true}, "light_on": "caster", "triggers": []}
	var r := CombatResult.new()
	e.spells.zones.add(o2, r)
	_log("spell", "%s blazes with the light of the sun (Boon of the Bright Sun)" % c.name(), c)
	_sun_dispels(c)
	return r


## Magical Darkness overlapping the Bright Sun's 30 ft is dispelled.
func _sun_dispels(c: Combatant) -> void:
	var e := enc()
	for other in e.spells.zones.live():
		if not bool(other.rule("darkness", false)):
			continue
		if other.cells.any(func(cell: Vector2i) -> bool: return e.grid.distance_ft(c.cell, c.size_cells, cell, 1) <= 30):
			other.ended = true
			_log("info", "The sunlight burns away %s (Boon of the Bright Sun)" % other.name, c)
	e.spells.zones.prune()


## The Bright Sun goes out when its bearer dies or is Incapacitated; at the start of the bearer's turn it and its
## allies it can see in the light gain 10 Temporary Hit Points.
func _sun_turn(c: Combatant) -> void:
	var e := enc()
	for h in e.combatants:
		var o := _sun_of(h)
		if o != null and (not h.is_alive() or not h.can_act()):
			o.ended = true
			_log("info", "%s's sunlight fades" % h.name(), h)
	e.spells.zones.prune()
	if _sun_of(c) == null:
		return
	_sun_dispels(c)
	for a: Combatant in e.allies_of(c) + [c]:
		if not a.is_alive() or a.is_down() or e.distance(c, a) > 30 or (a != c and not e.can_see(c, a)):
			continue
		if a.creature.add_temp_hp(10, "Bright Sun"):
			_log("heal", "%s basks in the sunlight: 10 Temporary Hit Points (Boon of the Bright Sun)" % a.name(), a)


## Boon of Terror: a Frightened creature starting its turn near the boon's bearer may be made to flee.
func _terror_turn(t: Combatant) -> void:
	var e := enc()
	if not t.creature.has_condition(&"frightened") or not t.is_alive() or t.is_down():
		return
	for h in e.combatants:
		var hc := _ch(h)
		if hc == null or h == t or not h.hostile_to(t) or not feat(h, "boon_of_terror") or not allowed(h, "boon_of_terror_benefit"):
			continue
		if hc.resource_left("boon_of_terror") <= 0 or not e.spells.can_react(h) or e.distance(h, t) > 60 or not e.can_see(h, t):
			continue
		if int(e.cover(h, t)["cover"]) == CombatGrid.Cover.TOTAL:
			continue
		hc.spend_resource("boon_of_terror")
		h.reaction_available = false
		var dc := 8 + h.creature.ability_mod(&"cha") + h.creature.proficiency_bonus()
		var sv := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Boon of Terror (%s)" % t.name(), ["save_vs:frightened"])
		if sv.success:
			_log("info", "%s holds its ground against %s's dread (Boon of Terror)" % [t.name(), h.name()], t, [sv.describe()])
			return
		var fx := Effect.new("Paralyzing Dread", &"feature", "boon_of_terror").with_modifier("flag", {"value": "fear_flee"})
		fx.caster_id = h.id
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = t.id
		t.creature.add_effect(fx)
		_log("condition", "%s flees from %s in terror (Boon of Terror)" % [t.name(), h.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
		return


## Spells about to resolve: Erupting Spellpower (a damaging spell cast with a slot) and Boon of the Furious Storm
## (Disadvantage on saves against Lightning or Thunder spells).
func _boons_before_resolve(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	var s := ctx["s"] as Dictionary
	if ch == null:
		return
	var types: Array = (s.get("damage", []) as Array).map(func(d: Variant) -> String: return str((d as Dictionary).get("type", "")))
	if feat(c, "boon_of_the_furious_storm") and ("lightning" in types or "thunder" in types or enc().spells._damage_type_safe(ctx) in ["lightning", "thunder"]):
		var dis := (ctx.get("save_disadvantage", []) as Array).duplicate()
		dis.append("Boon of the Furious Storm")
		ctx["save_disadvantage"] = dis
	if feat(c, "boon_of_erupting_spellpower") and bool(ctx.get("spent_slot", false)) and s.has("damage") \
			and ch.resource_left("erupting_spellpower") > 0 and allowed(c, "erupting_spellpower"):
		ch.spend_resource("erupting_spellpower")
		ctx["erupting"] = true
		c.set_meta("erupting_live", true)
		_log("info", "%s's spell erupts with power (Boon of Erupting Spellpower)" % c.name(), c)


## Boon of Revelry: a creature Charmed by its bearer's Otto's Irresistible Dance can't cast Verbal spells.
func _revelry(c: Combatant, s: Dictionary) -> void:
	if str(s.get("id", "")) != "ottos_irresistible_dance" or not feat(c, "boon_of_revelry"):
		return
	for t in enc().combatants:
		for fx: Effect in t.creature.effects:
			if fx.source_id == "ottos_irresistible_dance" and fx.caster_id == c.id and &"charmed" in fx.conditions \
					and not fx.modifiers.any(func(m: Modifier) -> bool: return m.text("value") == "speechless"):
				fx.with_modifier("flag", {"value": "speechless"})
				_log("info", "%s sings nonsense as it dances (Boon of Revelry)" % t.name(), t)


## Spells whose components `c` can skip: Magic School Mastery's level 1 spell, Boon of Revelry's dance.
func waives_components(c: Combatant, spell_id: String) -> bool:
	var fr := faerun()
	if spell_id == "ottos_irresistible_dance" and feat(c, "boon_of_revelry"):
		return true
	return feat(c, "boon_of_magic_school_mastery") and fr.familiars._feat_pick(c, "boon_of_magic_school_mastery", "school_mastery_minor") == spell_id
