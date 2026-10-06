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
const HANDLED := ["polymorph", "banishment", "otilukes_resilient_sphere", "dimension_door", "heat_metal"]


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
		"heat_metal":
			for t in tgt:
				heat_metal(ctx, t, r)
			sp()._grant_sustained(ctx, tgt)
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


# --- Turn hooks ---------------------------------------------------------------------------------------

## Start of `c`'s turn: Confusion's d10, Compulsion's forced march.
func turn_start(c: Combatant) -> void:
	if not c.is_alive() or c.creature.hp <= 0:
		return
	if c.creature.has_flag("confused"):
		_confusion_turn(c)
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == "compulsion" and StringName("charmed") in fx.conditions and fx in c.creature.effects:
			_compelled_march(c, fx)


## End of `c`'s turn: Compelled Duel ends if its caster finishes a turn more than 30 ft from the target.
func turn_end(c: Combatant) -> void:
	var e := enc()
	for t in e.living():
		for fx: Effect in t.creature.effects.duplicate():
			if fx.source_id == "compelled_duel" and fx.caster_id == c.id and e.distance(c, t) > 30:
				_end_duel(c, "the duellist strayed more than 30 ft")
				return


## Confusion (2024): no Bonus Actions or Reactions, and a d10 at the start of each turn: 1, it moves its full Speed
## in a random direction and does nothing else; 2-6, it neither moves nor acts; 7-8, it stays put and makes one melee
## attack against a random creature within reach (or nothing); 9-10, it acts normally.
func _confusion_turn(c: Combatant) -> void:
	var e := enc()
	c.bonus_available = false
	var roll := e.dice.roll_one(10, "Confusion (%s)" % c.name())
	match roll:
		1:
			var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
			var way: Vector2i = dirs[e.dice.roll_one(4, "Confusion direction") - 1]
			e.log.add("info", "Confusion (d10: 1): %s wanders off %s" % [c.name(), ["north", "east", "south", "west"][dirs.find(way)]], c.id)
			var r := CombatResult.new()
			e.march(c, Vector2(way), c.movement_left, r)
			c.movement_left = 0
			c.action_available = false
		2, 3, 4, 5, 6:
			e.log.add("info", "Confusion (d10: %d): %s stands dazed" % [roll, c.name()], c.id)
			c.movement_left = 0
			c.action_available = false
		7, 8:
			c.movement_left = 0
			c.action_available = false
			var near: Array[Combatant] = []
			for o in e.living():
				if o != c and not o.is_down() and e.distance(c, o) <= c.reach_ft():
					near.append(o)
			var opt := e.best_melee_option(c, null)
			if near.is_empty() or opt.is_empty():
				e.log.add("info", "Confusion (d10: %d): %s lashes at nothing" % [roll, c.name()], c.id)
			else:
				var victim := near[e.dice.roll_one(near.size(), "Confusion target") - 1]
				e.log.add("info", "Confusion (d10: %d): %s attacks %s at random" % [roll, c.name(), victim.name()], c.id)
				e._resolve_attack(c, victim, opt, {})
		_:
			e.log.add("info", "Confusion (d10: %d): %s acts normally" % [roll, c.name()], c.id)


## Compulsion: a charmed creature spends its movement going the way the caster named, then repeats its save.
func _compelled_march(c: Combatant, fx: Effect) -> void:
	var e := enc()
	var caster := e.get_c(fx.caster_id)
	if caster == null or not caster.has_meta("compel_dir"):
		return
	var dv := caster.get_meta("compel_dir") as Array
	var r := CombatResult.new()
	e.log.add("info", "%s is compelled to march (Compulsion)" % c.name(), c.id)
	e.march(c, Vector2(float(dv[0]), float(dv[1])), c.movement_left, r)
	c.movement_left = 0
	sp()._repeat_save(c, fx, [])


# --- Compelled Duel -------------------------------------------------------------------------------------

## Disadvantage on attack rolls against anyone but the duellist who compelled it.
func duel_disadvantage(attacker: Combatant, target: Combatant) -> String:
	for fx: Effect in attacker.creature.effects:
		if fx.source_id == "compelled_duel" and fx.caster_id != target.id:
			return "Compelled Duel"
	return ""


## The duellist it may not wander more than 30 ft from, or null.
func duel_anchor(c: Combatant) -> Combatant:
	for fx: Effect in c.creature.effects:
		if fx.source_id == "compelled_duel":
			return enc().get_c(fx.caster_id)
	return null


## The duel ends when its caster attacks someone else, casts a spell at another enemy, or an ally hurts the target.
func duel_check_attack(caster: Combatant, target: Combatant) -> void:
	var foe := _dueled_by(caster)
	if foe != null and foe != target:
		_end_duel(caster, "%s turned on someone else" % caster.name())


func duel_check_damage(source: Combatant, target: Combatant) -> void:
	if source == null:
		return
	for fx: Effect in target.creature.effects:
		if fx.source_id == "compelled_duel" and fx.caster_id != source.id:
			var caster := enc().get_c(fx.caster_id)
			if caster != null and caster.allied_with(source):
				_end_duel(caster, "an ally of the duellist joined in")
			return


func _dueled_by(caster: Combatant) -> Combatant:
	for t in enc().living():
		for fx: Effect in t.creature.effects:
			if fx.source_id == "compelled_duel" and fx.caster_id == caster.id:
				return t
	return null


func _end_duel(caster: Combatant, why: String) -> void:
	if caster.creature.concentration != null and caster.creature.concentration.source_id == "compelled_duel":
		caster.creature.concentration.end(why)
		enc().log.add("info", "Compelled Duel ends: %s" % why, caster.id)


# --- Dominate Beast ----------------------------------------------------------------------------------

## A dominated Beast fights for the caster's side under the player's command until the spell ends.
func dominate(ctx: Dictionary, t: Combatant) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	if t.has_meta("dominated_from"):
		return
	var fx := _marker(ctx, t, "Dominated", ["dominated"], "undominate")
	fx.conditions.append(&"charmed")
	# Each time it takes damage it repeats the save, ending the spell on itself on a success.
	fx.repeat_save = {"ability": "wis", "dc": (ctx["nums"]["dc"] as Breakdown).total(), "when": "manual", "on_damage": true}
	if not _attach(ctx, t, fx):
		return
	t.set_meta("dominated_from", [str(t.side), str(t.controller)])
	t.side = &"guest" if c.side == &"party" else c.side
	t.controller = c.controller
	var tid := t.id
	fx.on_end = func() -> void: undominate(tid)
	e.log.add("condition", "%s bends to %s's will" % [t.name(), c.name()], t.id)
	e.events.append({"type": "condition", "id": t.id})


func undominate(tid: String) -> void:
	var e := enc()
	if e == null:
		return
	var t := e.get_c(tid)
	if t == null or not t.has_meta("dominated_from"):
		return
	var was := t.get_meta("dominated_from") as Array
	t.remove_meta("dominated_from")
	t.side = StringName(str(was[0]))
	t.controller = StringName(str(was[1]))
	e.log.add("info", "%s shakes off the domination" % t.name(), t.id)


# --- Dissonant Whispers ---------------------------------------------------------------------------------

## On a failed save the target spends its Reaction to move as far from the caster as its Speed allows (and that
## movement can provoke Opportunity Attacks).
func flee_with_reaction(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	if not t.reaction_available or not t.can_act() or t.creature.has_flag("no_reactions") or t.speed() <= 0:
		return
	t.reaction_available = false
	e.log.add("info", "%s flees from the whispers" % t.name(), t.id)
	e.flee(t, c, t.speed(), r)


# --- Heat Metal ---------------------------------------------------------------------------------------

## The metal a creature carries that Heat Metal can heat: "weapon" (droppable), "armor", or "".
func metal_of(t: Combatant) -> String:
	const NOT_METAL := ["club", "quarterstaff", "greatclub", "sling", "shortbow", "longbow", "blowgun", "dart", "whip", "unarmed_strike"]
	if t.creature is Character:
		var ch := t.creature as Character
		var main := ch.equipped("main_hand")
		if not main.is_empty() and not str(main.get("id", "")) in NOT_METAL and main.has("weapon"):
			return "weapon"
		var armor := ch.equipped("armor")
		if not armor.is_empty() and str((armor.get("armor", {}) as Dictionary).get("kind", "")) in ["medium", "heavy"] and str(armor.get("id", "")) != "hide_armor":
			return "armor"
		return ""
	var m := t.creature as Monster
	var note := str(m.data.get("ac_note", "")).to_lower()
	for word: String in ["mail", "plate", "breastplate", "scale", "splint", "ring"]:
		if note.contains(word):
			return "armor"
	for a: Variant in m.data.get("actions", []):
		if bool((a as Dictionary).get("weapon", false)):
			return "weapon"
	return ""


## Heat Metal's searing: Fire damage to the creature touching the object, then a Constitution save: on a failure it
## drops a held object; if it doesn't drop it, it has Disadvantage on attack rolls and ability checks until the start
## of the caster's next turn.
func heat_metal(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var metal := metal_of(t)
	if metal == "":
		r.lines.append(e.log.add("info", "%s carries nothing metal to heat" % t.name(), t.id))
		return
	var rolled := sp().roll_damage_parts(ctx, s.get("damage", []) as Array, false, t)
	var dr := e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "fire", "spell": true}], false, str(s["name"]), [str(rolled["text"])])
	r.damage += dr.final
	if not t.is_alive() or t.creature.hp <= 0:
		return
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var sv := t.creature.roll_save(e.dice, &"con", dc, [], [], "Constitution save vs Heat Metal (%s)" % t.name())
	if not sv.success and metal == "weapon":
		if t.creature is Character:
			(t.creature as Character).unequip("main_hand")
		else:
			t.set_meta("disarmed", true)
		e.log.add("info", "%s drops the searing weapon" % t.name(), t.id, [sv.describe()])
		return
	var fx := Effect.new("Searing metal", &"spell", "heat_metal").with_modifier("disadvantage", {"on": "attack"}).with_modifier("disadvantage", {"on": "check:all"})
	fx.caster_id = c.id
	fx.stack_key = "spell:heat_metal:grip"
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	t.creature.add_effect(fx)
	e.log.add("condition", "%s grits its teeth around the searing metal (Disadvantage on attacks and checks)" % t.name(), t.id, [sv.describe()])


# --- Cantrips -------------------------------------------------------------------------------------------

## Eldritch Blast's beams: one more at character levels 5, 11 and 17.
func beams(c: Combatant) -> int:
	return 1 + Spellcasting.cantrip_tier(c.creature.character_level())


## Sorcerous Burst: each 8 rolled adds another d8, up to the spellcasting modifier in extra dice. Returns the extra
## total and a note.
func sorcerous_burst_extra(ctx: Dictionary, text: String) -> Dictionary:
	var e := enc()
	var cap := maxi(0, int((ctx["nums"] as Dictionary).get("mod", 0)))
	var eights := 0
	var open := text.find("[")
	var close := text.find("]")
	if open >= 0 and close > open:
		for part in text.substr(open + 1, close - open - 1).split(","):
			if part.strip_edges() == "8":
				eights += 1
	var extra := 0
	var rolls: Array[String] = []
	var added := 0
	while eights > 0 and added < cap:
		eights -= 1
		var v := e.dice.roll_one(8, "Sorcerous Burst extra die")
		added += 1
		extra += v
		rolls.append(str(v))
		if v == 8:
			eights += 1
	return {"total": extra, "text": "Sorcerous Burst: %d extra d8 [%s]" % [added, ", ".join(rolls)] if added > 0 else ""}
