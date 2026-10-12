class_name SpellSummons
extends RefCounted
## Creatures a spell calls up in a fight (SpellCaster.summoned, combat/summon_blocks.gd): placing them, sending them
## away, a shape that ends, and finding free squares for them.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Summon Fey / Summon Undead (a spirit whose numbers grow with the slot level, on your side, acting right after
## you), Find Familiar and Animate Dead (cast before the fight). The player controls them; they vanish when the
## spell ends or at 0 Hit Points.
func can_splinter(c: Combatant, s: Dictionary) -> bool:
	var spells := sp()
	return spells.caster_char(c) != null and CombatFeatures.has_feature(c, "splintered_summons") \
		and spells.caster_char(c).resource_left("splintered_summons") > 0 and str(s.get("school", "")) == "conjuration" \
		and str(s.get("id", "")).begins_with("summon_") and str(s.get("id", "")) in SpellCaster.SUMMON_SPELLS


func _summon(ctx: Dictionary, cell: Vector2i, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var block: Dictionary = ctx["summon_block"] if ctx.has("summon_block") else SummonBlocks.for_spell(str(s["id"]), int(ctx["slot"]), str(ctx.get("choice", "")), ctx["nums"] as Dictionary)
	if block.is_empty():
		return
	if bool((ctx.get("opts", {}) as Dictionary).get("splintered", false)):
		var split := ctx.duplicate()
		split["opts"] = (ctx["opts"] as Dictionary).duplicate()
		(split["opts"] as Dictionary).erase("splintered")
		var smaller := block.duplicate(true)
		(smaller["hp"] as Dictionary)["average"] = int((smaller["hp"] as Dictionary)["average"]) / 2
		(smaller["hp"] as Dictionary)["dice"] = str((smaller["hp"] as Dictionary)["average"])
		split["summon_block"] = smaller
		_summon(split, cell, r)
		var second := ((ctx["opts"] as Dictionary)["points"] as Array)[1] as Vector2
		_summon(split, Vector2i(floori(second.x), floori(second.y)), r)
		return
	var m := Monster.from_data(block, e.dice)
	m.name = str(block["name"])
	e.feature_recipes.after_summon(ctx, m)
	e.faerun.after_summon(ctx, m)
	# A new Otherworldly Steed replaces the old one, and stays with its caster after the fight (Character.steed).
	if bool(block.get("steed", false)):
		for old_id: Variant in spells.summoned.get(c.id, []):
			var old := e.get_c(str(old_id))
			if old != null and old.is_alive() and old.creature is Monster and bool((old.creature as Monster).data.get("steed", false)):
				_dismiss(old.id)
		if spells.caster_char(c) != null:
			var kind := str(ctx.get("choice", ""))
			spells.caster_char(c).steed = {"type": kind if kind != "" else "celestial", "level": int(ctx["slot"])}
	var size := CombatGrid.size_cells_for(m.size)
	if cell.x < 0 or not _room_for(cell, size):
		cell = _free_cell_near(c.cell, size)
	var sc := e.add(m, &"guest" if c.side == &"party" else c.side, cell)
	sc.controller = c.controller
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	if not spells.summoned.has(c.id):
		spells.summoned[c.id] = []
	(spells.summoned[c.id] as Array).append(sc.id)
	var conc := ctx["conc"] as Concentration
	if conc != null:
		var marker := Effect.new(str(s["name"]), &"spell", str(s["id"]))
		marker.modifiers.append(Modifier.of("flag", {"value": "summoned"}, str(s["name"]), &"spell"))
		conc.attach(m, marker)
		var sid := sc.id
		marker.data["on_end"] = {"kind": "dismiss", "target": sid}
		marker.on_end = func() -> void: _dismiss(sid)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, sc)
	# A summon cast without Concentration (Fey Reinforcements, Spirits of Ill Omen) lasts its duration in rounds.
	var sd := s.get("duration", {}) as Dictionary
	if conc == null and not bool(ctx.get("precast", false)) and str(sd.get("kind", "")) in ["rounds", "minutes"]:
		sc.set_meta("vanish_round", e.round_no + SpellPlacement._duration_rounds(sd))
	elif conc == null and str(s["id"]) == "summon_fey":
		sc.set_meta("vanish_round", e.round_no + 10)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": cell, "caster": c.id})
	r.lines.append(e.log.add("spell", "%s appears beside %s" % [m.name, c.name()], c.id))


## The Otherworldly Steed `c` called earlier (Character.steed: its type and level) joins the fight beside them, as
## Find Familiar's familiar does; nothing is spent. False when there's none.
func bring_steed(c: Combatant) -> bool:
	var ch := sp().caster_char(c)
	if ch == null or ch.steed.is_empty():
		return false
	var s := _comp().spell_data("find_steed")
	var entry := sp()._entry_any(c, "find_steed")
	if entry.is_empty():
		entry = {"class_id": "paladin"}   # no longer prepared: the steed still comes, with the Paladin's numbers
	var ctx := {"c": c, "s": s, "slot": int(ch.steed.get("level", 2)), "nums": sp().numbers(c, entry), "conc": null,
		"opts": {}, "precast": true, "choice": str(ch.steed.get("type", "celestial"))}
	_summon(ctx, c.cell, CombatResult.new())
	return true


## The dead `c` raised while exploring (Animate Dead, Create Undead: FieldCasting.bring_risen) join the fight beside
## them, `count` of `kind`; nothing is spent. They come whole to each fight of their day (docs/rules/deviations.md).
func bring_risen(c: Combatant, spell_id: String, kind: String, count: int) -> void:
	var s := _comp().spell_data(spell_id)
	var entry := sp()._entry_any(c, spell_id)
	if entry.is_empty():
		entry = {"class_id": "wizard"}
	for i in count:
		var ctx := {"c": c, "s": s, "slot": int(s.get("level", 3)), "nums": sp().numbers(c, entry), "conc": null,
			"opts": {}, "precast": true, "choice": kind}
		_summon(ctx, Vector2i(-1, -1), CombatResult.new())


## The familiar `c` called earlier (Character.familiar) when `c` can't cast Find Familiar now (it came from a scroll, or
## the spell has left their book): it joins the fight beside them all the same, the form a casting would make.
func bring_familiar(c: Combatant) -> bool:
	if sp().caster_char(c) == null:
		return false
	var s := _comp().spell_data("find_familiar")
	var entry := sp()._entry_any(c, "find_familiar")
	if entry.is_empty():
		entry = {"class_id": "wizard"}
	var choice := str(c.get_meta("chain_form", "imp")) if ClassFeatures.knows_invocation(c, "pact_of_the_chain") else ""
	if CombatFeatures.has_feature(c, "necromancy_familiar"):
		choice = str(c.get_meta("familiar_form", "skeleton"))
	var ctx := {"c": c, "s": s, "slot": 1, "nums": sp().numbers(c, entry), "conc": null, "opts": {}, "precast": true,
		"choice": choice}
	_summon(ctx, c.cell, CombatResult.new())
	return true


## A death in the fight: an Otherworldly Steed that drops to 0 Hit Points is gone until Find Steed calls another, and
## so is a caster's steed when the caster dies (2024).
func on_death(dead: Combatant) -> void:
	var e := enc()
	if dead.creature is Monster and bool((dead.creature as Monster).data.get("steed", false)) and dead.has_meta("summoner"):
		var owner := e.get_c(str(dead.get_meta("summoner")))
		if owner != null and sp().caster_char(owner) != null:
			sp().caster_char(owner).steed = {}
	elif dead.creature is Character and not (dead.creature as Character).steed.is_empty():
		(dead.creature as Character).steed = {}
		for sid: Variant in sp().summoned.get(dead.id, []):
			var steed := e.get_c(str(sid))
			if steed != null and steed.is_alive() and steed.creature is Monster \
					and bool((steed.creature as Monster).data.get("steed", false)):
				_dismiss(steed.id)


func _revert_shape(creature_id: String, why: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(creature_id)
	if c != null:
		e.shapes.revert(c, why)


func _dismiss(creature_id: String) -> void:
	var e := enc()
	if e == null:
		return
	var sc := e.get_c(creature_id)
	if sc == null or sc.creature.dead:
		return
	sc.creature.dead = true
	e.log.add("info", "%s vanishes" % sc.name(), sc.id)
	e.events.append({"type": "vanish", "id": sc.id})


func _free_cell_near(cell: Vector2i, size: int = 1) -> Vector2i:
	for radius in range(1, 8):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c2 := cell + Vector2i(dx, dy)
				if _room_for(c2, size):
					return c2
	return cell


## Whether a creature `size` squares across fits with its corner at `cell`.
func _room_for(cell: Vector2i, size: int) -> bool:
	var e := enc()
	for f in CombatGrid.footprint(cell, size):
		if not e.grid.in_bounds(f) or e.grid.is_solid(f) or e.occupant_at(f) != null:
			return false
	return true
