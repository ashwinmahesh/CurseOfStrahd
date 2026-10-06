class_name SpellSpecials
extends RefCounted
## Spells whose fight rules need code of their own beyond the data recipe (docs/contracts/spells.md), the ones the
## Phase 4 classes brought: Polymorph, Banishment, Otiluke's Resilient Sphere, Dimension Door, Confusion, Compelled
## Duel, Dissonant Whispers' flight, Heat Metal, Call Lightning's storm, Cordon of Arrows, Mordenkainen's Faithful
## Hound, Conjure Animals' pack, Eldritch Blast's beams and Sorcerous Burst's exploding dice. SpellCaster hands a
## cast here first; `resolve` returns true when it handled it.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


## Where a banished creature waits: off the grid, out of everyone's reach.
const BANISHED_CELL := Vector2i(-1000, -1000)

## Spells handled here.
const HANDLED := ["polymorph", "banishment", "otilukes_resilient_sphere", "dimension_door"]


func resolve(ctx: Dictionary, tgt: Array[Combatant], _cells: Array[Vector2i], r: CombatResult) -> bool:
	var s := ctx["s"] as Dictionary
	match str(s["id"]):
		"polymorph":
			for t in tgt:
				polymorph(ctx, t, r)
			return true
		"banishment":
			for t in tgt:
				banish(ctx, t, r)
			return true
		"otilukes_resilient_sphere":
			if not tgt.is_empty():
				resilient_sphere(ctx, tgt[0], r)
			return true
		"dimension_door":
			dimension_door(ctx, ctx["cell"] as Vector2i, r)
			return true
	return false


# --- Saves ------------------------------------------------------------------------------------------

## One creature's save against a spell with the usual Advantage sources (Magic Resistance, "you're fighting it"),
## or no save for a willing ally. True if it resisted.
func _resists(ctx: Dictionary, t: Combatant, ab: StringName, extra_keys: Array[String] = []) -> bool:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	if c.allied_with(t):
		return false
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var keys := t.creature.save_keys(ab)
	keys.append("save_vs:spell")
	keys.append_array(extra_keys)
	var adv: Array[String] = []
	if bool(s.get("save_advantage_if_fighting", false)) and c.hostile_to(t):
		adv.append("you're fighting it")
	var test := t.creature.roll_d20(e.dice, D20Test.Kind.SAVING_THROW, t.creature.save_bonus(ab), dc, keys, adv, [] as Array[String],
		"%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], s["name"], t.name()])
	e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if test.success else "fails", s["name"]], t.id, [test.describe()])
	return test.success


## A marker effect on `t` kept by the spell's Concentration (or its duration) that runs `on_end` when the spell ends.
func _marker(ctx: Dictionary, t: Combatant, label: String, flags: Array[String], end_kind: String, extra: Dictionary = {}) -> Effect:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var fx := Effect.new(label, &"spell", str(s["id"]))
	fx.caster_id = c.id
	fx.spell_level = int(ctx["slot"])
	fx.stack_key = "spell:%s:marker" % s["id"]
	sp()._set_duration(fx, ctx, t, "spell")
	for f in flags:
		fx.modifiers.append(Modifier.of("flag", {"value": f}, label, &"spell"))
	var data := {"kind": end_kind, "target": t.id}
	data.merge(extra)
	fx.data["on_end"] = data
	return fx


func _attach(ctx: Dictionary, t: Combatant, fx: Effect) -> bool:
	var conc := ctx["conc"] as Concentration
	return conc.attach(t.creature, fx) if conc != null else t.creature.add_effect(fx)


# --- Polymorph ----------------------------------------------------------------------------------------

## Polymorph: a Wisdom save (allies don't resist; shape-changers and creatures at 0 Hit Points are unaffected), then
## the target becomes a Beast of Challenge Rating up to its own (or its level): `opts.choice` names the form, else
## the strongest one for an ally and the weakest for a foe. It gains the Beast's Hit Points as Temporary Hit Points;
## the spell ends on it when they run out.
func polymorph(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	if t.creature.hp <= 0 or t.creature.has_flag("shapechanger"):
		r.lines.append(e.log.add("info", "Polymorph has no effect on %s" % t.name(), t.id))
		return
	if _resists(ctx, t, &"wis"):
		return
	var limit := float(t.creature.character_level()) if t.creature is Character else (t.creature as Monster).cr
	var forms := ShapeChange.beast_forms(limit)
	if forms.is_empty():
		r.lines.append(e.log.add("info", "No Beast form fits %s" % t.name(), t.id))
		return
	var pick := str((ctx["opts"] as Dictionary).get("choice", ""))
	var form: Dictionary = forms[forms.size() - 1] if c.allied_with(t) else forms[0]
	for f in forms:
		if str(f.get("id", "")) == pick:
			form = f
	if pick != "" and str(form.get("id", "")) != pick:
		e.log.add("info", "That Beast out-ranks %s; Polymorph picks %s instead" % [t.name(), form.get("name", "")], t.id)
	var beast_hp := int((form.get("hp", {}) as Dictionary).get("average", 1))
	var m := e.shapes.transform(t, form, {"temp_hp": beast_hp, "ends_without_temp_hp": true, "label": "Polymorph"})
	var fx := _marker(ctx, t, "Polymorph", ["polymorphed"], "revert_shape")
	var conc := ctx["conc"] as Concentration
	if conc != null:
		conc.attach(m, fx)
	else:
		m.add_effect(fx)
	var tid := t.id
	fx.on_end = func() -> void: sp()._revert_shape(tid, "Polymorph ended")


# --- Banishment ---------------------------------------------------------------------------------------

## Banishment: a Charisma save or the target leaves the fight for a harmless demiplane (Incapacitated, off the grid)
## until the spell ends; it then returns to its space or the nearest free one. An Aberration, Celestial, Elemental,
## Fey or Fiend banished for the full minute doesn't come back.
func banish(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	if _resists(ctx, t, &"cha"):
		return
	var fx := _marker(ctx, t, "Banished", ["banished", "ethereal"], "unbanish", {"cell": [t.cell.x, t.cell.y], "round": e.round_no})
	fx.conditions.append(&"incapacitated")
	if not _attach(ctx, t, fx):
		return
	t.set_meta("banished", [t.cell.x, t.cell.y])
	t.cell = BANISHED_CELL
	e.events.append({"type": "vanish", "id": t.id})
	r.lines.append(e.log.add("condition", "%s is banished to a demiplane" % t.name(), t.id))
	var tid := t.id
	var cast_round := e.round_no
	fx.on_end = func() -> void: unbanish(tid, cast_round)
	e.features.end_turning_from(t)


func unbanish(tid: String, cast_round: int) -> void:
	var e := enc()
	if e == null:
		return
	var t := e.get_c(tid)
	if t == null or not t.has_meta("banished"):
		return
	var at := t.get_meta("banished") as Array
	t.remove_meta("banished")
	var native := str(t.creature.creature_type) in ["aberration", "celestial", "elemental", "fey", "fiend"]
	if native and e.round_no - cast_round >= 10:
		t.creature.dead = true
		e.log.add("info", "%s is sent home to its own plane for good" % t.name(), t.id)
		return
	var cell := Vector2i(int(at[0]), int(at[1]))
	if not sp()._room_for(cell, t.size_cells):
		cell = sp()._free_cell_near(cell, t.size_cells)
	t.cell = cell
	e.events.append({"type": "teleport", "id": t.id, "from": cell, "to": cell})
	e.log.add("info", "%s returns from the demiplane" % t.name(), t.id)


# --- Otiluke's Resilient Sphere ------------------------------------------------------------------------

## A globe of force around a Large or smaller creature (a Dexterity save if unwilling): nothing passes in or out, so
## it can't be hurt from outside or hurt anything outside, and it can't move except by rolling the sphere.
func resilient_sphere(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	if Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(&"large"):
		r.lines.append(e.log.add("info", "%s is too big for the sphere" % t.name(), t.id))
		return
	if _resists(ctx, t, &"dex"):
		return
	var fx := _marker(ctx, t, "Resilient Sphere", ["sphered"], "none")
	fx.modifiers.append(Modifier.of("speed_percent", {"value": 50}, "Resilient Sphere", &"spell"))
	if _attach(ctx, t, fx):
		r.lines.append(e.log.add("condition", "A shimmering sphere of force encloses %s" % t.name(), t.id))
		e.events.append({"type": "condition", "id": t.id})


## Whether a sphere stands between `a` and `b` (one inside, the other not): no attacks, spells or damage pass.
func sphere_blocks(a: Combatant, b: Combatant) -> bool:
	if a == null or b == null or a == b:
		return false
	return a.creature.has_flag("sphered") or b.creature.has_flag("sphered")


# --- Dimension Door -----------------------------------------------------------------------------------

## Dimension Door: the caster teleports up to 500 ft, with one willing ally within 5 ft arriving beside them
## (`opts.with`: the ally's id). An occupied destination fails the spell and deals 4d6 Force to each.
func dimension_door(ctx: Dictionary, cell: Vector2i, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var with_id := str((ctx["opts"] as Dictionary).get("with", ""))
	var ally := e.get_c(with_id) if with_id != "" else null
	if ally != null and (ally == c or not c.allied_with(ally) or e.distance(c, ally) > 5):
		ally = null
	var travellers: Array[Combatant] = [c]
	if ally != null:
		travellers.append(ally)
	if not sp()._room_for(cell, c.size_cells):
		for t in travellers:
			var rolled := e._roll_damage_dice("4d6", false, 0, "Dimension Door")
			e.deal_damage(null, t, [{"amount": int(rolled["total"]), "type": "force"}], false, "Dimension Door", ["The destination is filled", str(rolled["text"])])
		r.lines.append(e.log.add("info", "Dimension Door fails: the destination is occupied", c.id))
		return
	sp()._teleport(c, cell, r)
	if ally != null:
		var spot := sp()._free_cell_near(cell, ally.size_cells)
		if e.grid.distance_ft(cell, c.size_cells, spot, ally.size_cells) <= 5:
			sp()._teleport(ally, spot, r)
