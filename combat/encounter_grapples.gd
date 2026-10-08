class_name EncounterGrapples
extends RefCounted
## Grapple and Shove in a fight (Encounter, 2024): the Unarmed Strike's special modes, escaping a grapple, and
## letting go when the grappler can't hold on.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Grapple or Shove with an Unarmed Strike as one attack of the Attack action (2024): the target makes a Strength
## or Dexterity save (its choice: the better one) against 8 + Str modifier + PB; it can be at most one size larger.
func unarmed_special(c: Combatant, target: Combatant, mode: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	if target == null or e.distance(c, target) > 5:
		return CombatResult.fail("Target must be within 5 ft")
	if Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(c.creature.size) + 1:
		return CombatResult.fail("Target is more than one size larger")
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		e.spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1
	else:
		return CombatResult.fail("No attacks left this turn")
	var dc := 8 + c.creature.ability_mod(&"str") + c.creature.proficiency_bonus()
	var ab := &"str" if target.creature.save_bonus(&"str").total() >= target.creature.save_bonus(&"dex").total() else &"dex"
	var s := target.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], mode.capitalize(), target.name()])
	var r := CombatResult.new()
	if s.success:
		e.log.add("info", "%s resists %s's %s" % [target.name(), c.name(), mode], c.id, [s.describe()])
		return r
	match mode:
		"grapple":
			target.creature.add_condition(&"grappled", c.name())
			e.grapples[target.id] = c.id
			e.log.add("condition", "%s grapples %s (escape DC %d)" % [c.name(), target.name(), dc], c.id, [s.describe()])
		"shove_prone":
			target.creature.add_condition(&"prone", "Shove")
			e.log.add("condition", "%s shoves %s Prone" % [c.name(), target.name()], c.id, [s.describe()])
		_:
			var moved := e.forced_move(target, e.center_of(c), 5)
			e.log.add("info", "%s shoves %s %d ft" % [c.name(), target.name(), moved * 5], c.id, [s.describe()])
	return r


## Escaping a grapple (2024): an action and a Strength (Athletics) or Dexterity (Acrobatics) check against the
## escape DC.
func escape_grapple(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not e.grapples.has(c.id):
		return CombatResult.fail("Not grappled")
	e.spend_action(c)
	var grappler := e.get_c(str(e.grapples[c.id]))
	var dc := 8 + grappler.creature.ability_mod(&"str") + grappler.creature.proficiency_bonus() if grappler != null else 10
	if c.has_meta("escape_dc"):
		dc = int(c.get_meta("escape_dc"))
	var skill := &"athletics" if c.creature.skill_bonus(&"athletics").total() >= c.creature.skill_bonus(&"acrobatics").total() else &"acrobatics"
	var t := c.creature.roll_check(e.dice, skill, dc)
	if t.success:
		e.grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
		c.remove_meta("escape_dc")
		e.monster_actions.release_engulf(c)
		e.log.add("info", "%s breaks free" % c.name(), c.id, [t.describe()])
	else:
		e.log.add("info", "%s struggles but stays Grappled" % c.name(), c.id, [t.describe()])
	return CombatResult.new()


## The creatures `c` holds in a grapple.
func held_by(c: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for k: String in e.grapples:
		var t := e.get_c(k)
		if str(e.grapples[k]) == c.id and t != null and t.is_alive():
			out.append(t)
	return out


## 1 when `c` drags someone as it moves: every foot costs it 1 extra foot unless the grappled creature is Tiny or two or
## more sizes smaller (2024 Grappled), else 0.
func drag_extra(c: Combatant) -> int:
	var mine := Creature.SIZES.find(c.creature.size)
	for t in held_by(c):
		if t.creature.size != &"tiny" and mine - Creature.SIZES.find(t.creature.size) < 2 and not t.has_meta("engulfed_by"):
			return 1
	return 0


## The grapple's range: the grappler's reach (5 ft for an Unarmed Strike, more for a long-limbed monster's hold).
func grapple_range(grappler: Combatant) -> int:
	return grappler.reach_ft()


## After `c` stepped from `from`: each creature it grapples that's now out of the grapple's range comes along, into the
## open square nearest where it was that's still in range (the square `c` left, as a rule). Being dragged isn't moving
## on its own (no Opportunity Attacks), but areas it's pulled into affect it. With nowhere to put it, the grapple ends.
func drag_along(c: Combatant, from: Vector2i) -> void:
	var e := enc()
	for t in held_by(c):
		# An engulfed creature rides inside its engulfer's space.
		if str(t.get_meta("engulfed_by", "")) == c.id:
			var inside := t.cell
			t.cell = c.cell
			e.events.append({"type": "move", "id": t.id, "from": inside, "to": c.cell, "forced": true, "dragged": true})
			continue
		if e.distance(c, t) <= grapple_range(c):
			continue
		var spot := _drag_spot(c, t, from)
		if spot.x < -999:
			_end(t, "%s loses its hold on %s" % [c.name(), t.name()])
			continue
		var was := t.cell
		t.cell = spot
		t.clear_run()
		e.events.append({"type": "move", "id": t.id, "from": was, "to": spot, "forced": true, "dragged": true})
		e._after_step(t, was)


func _drag_spot(c: Combatant, t: Combatant, from: Vector2i) -> Vector2i:
	var e := enc()
	var best := Vector2i(-1000, -1000)
	var best_d := INF
	var r := grapple_range(c) / CombatGrid.FEET + t.size_cells
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := c.cell + Vector2i(dx, dz)
			if e.grid.distance_ft(c.cell, c.size_cells, cell, t.size_cells, c.altitude, t.altitude) > grapple_range(c) or not e.space_available(cell, t.size_cells, [t]):
				continue
			# The square the grappler left first, then the one nearest where it was held.
			var d := 0.0 if cell == from else 1.0 + Vector2(cell - t.cell).length()
			if d < best_d:
				best_d = d
				best = cell
	return best


## A grapple that no longer reaches ends: after `c` was moved against its will, any grapple it holds or is held in
## whose two creatures are now farther apart than its range (2024 Grappled).
func check_range(c: Combatant) -> void:
	var e := enc()
	for t in held_by(c):
		if str(t.get_meta("engulfed_by", "")) == c.id:
			t.cell = c.cell   # carried inside, wherever its engulfer is thrown
		elif e.distance(c, t) > grapple_range(c):
			_end(t, "%s is torn from %s's grip" % [t.name(), c.name()])
	if e.grapples.has(c.id):
		var g := e.get_c(str(e.grapples[c.id]))
		if g != null and e.distance(g, c) > grapple_range(g):
			_end(c, "%s is torn from %s's grip" % [c.name(), g.name()])


## Letting go of a creature you grapple takes no action (2024).
func release(c: Combatant, target: Combatant) -> CombatResult:
	var e := enc()
	if target == null or str(e.grapples.get(target.id, "")) != c.id:
		return CombatResult.fail("Not holding that creature")
	_end(target, "%s lets go of %s" % [c.name(), target.name()])
	return CombatResult.new()


func _end(t: Combatant, line: String) -> void:
	var e := enc()
	e.grapples.erase(t.id)
	t.creature.remove_condition(&"grappled")
	if t.has_meta("escape_dc"):
		t.remove_meta("escape_dc")
	e.monster_actions.release_engulf(t)
	e.log.add("info", line, t.id)
	e.events.append({"type": "condition", "id": t.id})


func _release_grapples_by(grappler: Combatant) -> void:
	var e := enc()
	for k: String in e.grapples.keys():
		if str(e.grapples[k]) == grappler.id:
			e.grapples.erase(k)
			var t := e.get_c(k)
			if t != null:
				t.creature.remove_condition(&"grappled")
				if t.has_meta("escape_dc"):
					t.remove_meta("escape_dc")
				e.monster_actions.release_engulf(t)
