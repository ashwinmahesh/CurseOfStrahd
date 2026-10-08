class_name EncounterMovement
extends RefCounted
## Moving in a fight (Encounter): the squares a creature can reach (Difficult Terrain, other creatures' spaces, fear,
## cages and walls), walking a path and what each step sets off (Opportunity Attacks, Reactive Strike, readied attacks,
## areas entered), moves made on a creature (Confusion, Dissonant Whispers, pushes), standing up, dropping Prone,
## feature movement and Jump.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func space_available(cell: Vector2i, size: int, except: Array = []) -> bool:
	var e := enc()
	for square in CombatGrid.footprint(cell, size):
		if not e.grid.in_bounds(square) or e.grid.is_solid(square):
			return false
		var occupant := e.occupant_at(square)
		if occupant != null and not occupant in except:
			return false
	return true


## Whether a creature stands in running water (a deep-water square it isn't flying over, or the `in_running_water`
## flag): a vampire's Regeneration, shape changes and Misty Escape fail there.
func in_running_water(c: Combatant) -> bool:
	var e := enc()
	if c.creature.has_flag("in_running_water"):
		return true
	if move_mode(c) & CombatGrid.MOVE_FLY:
		return false
	for cell in c.footprint():
		if e.grid.has_flag(cell, CombatGrid.WATER):
			return true
	return false


## Squares `c` can reach with its movement (or `budget` feet). A Prone creature crawls (double cost) unless
## `standing` says it will stand up first; dragging a grappled creature costs 1 extra foot per foot too.
func reachable_for(c: Combatant, budget: int = -1, standing: bool = false) -> Dictionary:
	var e := enc()
	var feet := c.movement_left if budget < 0 else budget
	feet = feet / extra_cost(c, standing)
	var occ := _occupancy_for(c)
	var blocked := occ["blocked"] as Dictionary
	# Frightened: no square closer to a source of fear the creature can see (a stricter, per-square reading of
	# "can't willingly move closer", see deviations.md).
	for src in fear_sources(c):
		var now := e.grid.distance_ft(c.cell, c.size_cells, src.cell, src.size_cells)
		for x in e.grid.width:
			for y in e.grid.depth:
				var cell := Vector2i(x, y)
				if e.grid.distance_ft(cell, c.size_cells, src.cell, src.size_cells) < now:
					blocked[cell] = true
	# Forcecage: no stepping out of a cage, or into one; Antilife Shell keeps most creatures out.
	for cell3: Vector2i in e.spells.specials.high.cage_blocks(c):
		blocked[cell3] = true
	for cell4: Vector2i in e.spells.specials.mid.shell_blocks(c):
		blocked[cell4] = true
	# Compelled Duel: no square more than 30 ft from the duellist.
	var anchor := e.spells.specials.duel_anchor(c)
	if anchor != null:
		for x2 in e.grid.width:
			for y2 in e.grid.depth:
				var cell2 := Vector2i(x2, y2)
				if e.grid.distance_ft(cell2, c.size_cells, anchor.cell, anchor.size_cells) > 30:
					blocked[cell2] = true
	return e.grid.reachable(c.cell, c.size_cells, feet, _has_fn(blocked),
		_value_fn(occ["slowed"] as Dictionary), _has_fn(occ["occupied"] as Dictionary), move_mode(c))


## What each foot of `c`'s movement costs (2024: the extra feet add up): 1, plus 1 crawling while Prone (unless it
## stands up first) and 1 dragging a grappled creature that isn't Tiny or two sizes smaller.
func extra_cost(c: Combatant, standing: bool = false) -> int:
	var per_foot := 1 + enc().grappling.drag_extra(c)
	if c.creature.has_condition(&"prone") and not standing:
		per_foot += 1
	return per_foot


## How `c` moves: flying (a fly speed at least its walking speed, Fly, Gaseous Form) or climbing (Spider Climb).
func move_mode(c: Combatant) -> int:
	var mode := 0
	if c.creature.speed("fly").total() > 0 and c.creature.speed("fly").total() >= c.creature.speed().total():
		mode |= CombatGrid.MOVE_FLY
	if c.creature.has_flag("spider_climb") or c.creature.speed("climb").total() > 0 or CombatFeatures.has_feature(c, "second_story_work"):
		mode |= CombatGrid.MOVE_CLIMB
	if c.creature.has_flag("incorporeal_movement"):
		mode |= CombatGrid.MOVE_INCORPOREAL
	if c.creature.has_flag("freedom_of_movement") or c.creature.has_flag("ignore_difficult_terrain"):
		mode |= CombatGrid.MOVE_UNHINDERED
	if c.creature.has_flag("ignore_natural_difficult"):
		mode |= CombatGrid.MOVE_TERRAIN
	return mode


## The creatures `c` is Frightened of and can see.
func fear_sources(c: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	if not c.creature.has_condition(&"frightened"):
		return out
	for fx in c.creature.effects:
		if not &"frightened" in fx.conditions or fx.caster_id == "":
			continue
		var src := e.get_c(fx.caster_id)
		if src != null and src != c and src.is_alive() and not src in out and e.can_see(c, src):
			out.append(src)
	return out


## How other creatures' squares affect `c`'s movement: {blocked, slowed, occupied}, each a set of cells.
## 2024: you can pass through an ally, an Incapacitated creature, a Tiny creature or one two sizes different
## (Halfling Nimbleness: any larger creature); another creature's space, an ally's too, is Difficult Terrain unless
## it's Tiny; you can't end your move in an occupied space. `allies_block` (a place's flag) makes allies block too.
func _occupancy_for(c: Combatant) -> Dictionary:
	var e := enc()
	var blocked := {}
	var slowed := {}
	var occupied := {}
	var my_size := Creature.SIZES.find(c.creature.size)
	var partner := e.mount_of(c) if e.mount_of(c) != null else e.rider_of(c)
	for o in e.combatants:
		if o == c or not o.is_alive() or o == partner:
			continue
		var o_size := Creature.SIZES.find(o.creature.size)
		# Swarms, and elementals made of air, fire or water, can move into (and stay in) other creatures' spaces.
		var swarmy := o.creature.has_flag("swarm") or c.creature.has_flag("swarm") or c.creature.has_flag("enters_spaces")
		if swarmy:
			continue
		var passable := (c.allied_with(o) and not e.allies_block) or o.creature.has_flag("no_actions") or o.creature.size == &"tiny" \
			or absi(o_size - my_size) >= 2 or (c.creature.has_flag("halfling_nimbleness") and o_size > my_size)
		# 2024: any other creature's space is Difficult Terrain, an ally's included (a Tiny one excepted).
		var slows := o.creature.size != &"tiny"
		for cell in o.footprint():
			occupied[cell] = true
			if not passable:
				blocked[cell] = true
			if slows:
				slowed[cell] = true
	var terrain := e.spells.zones.difficult_cells(c)
	for cell: Vector2i in terrain:
		slowed[cell] = terrain[cell] if terrain[cell] is int else true
	if c.creature.has_flag("pass_through_creatures"):
		blocked = {}
	if c.creature.has_flag("incorporeal_occupied"):
		for cell: Vector2i in occupied:
			slowed[cell] = true
		occupied = {}
	# Wall of Force and Wall of Stone: no one walks through.
	for wcell: Vector2i in e.spells.specials.mid.blocked_cells():
		blocked[wcell] = true
	return {"blocked": blocked, "slowed": slowed, "occupied": occupied}


static func _has_fn(set: Dictionary) -> Callable:
	return func(cell: Vector2i) -> bool: return set.has(cell)


## The value stored for a square (true, or a movement multiplier), or false.
static func _value_fn(set: Dictionary) -> Callable:
	return func(cell: Vector2i) -> Variant: return set.get(cell, false)


## Moves the current creature to `dest` along the cheapest legal path. Leaving a hostile creature's reach
## provokes an Opportunity Attack unless the mover took Disengage; a player-controlled reactor is asked first.
## A Prone mover stands up first if it has the movement for it (half its Speed).
func move(c: Combatant, dest: Vector2i) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if c.creature.hp <= 0:
		return CombatResult.fail("%s is down" % c.name())
	# What the move may change, so it can be taken back if nothing comes of it (EncounterUndo).
	var undo := e.undo.before_move(c)
	# Riding: the controlled mount carries its rider, spending its own movement.
	var steed := e.controlled_mount(c)
	if steed != null:
		var sreach := reachable_for(steed)
		if not sreach.has(dest):
			return CombatResult.fail("Your mount can't reach that square with %d ft of movement" % steed.movement_left)
		if bool((sreach[dest] as Dictionary)["occupied"]):
			return CombatResult.fail("Your mount can't end its move in an occupied space")
		c.moved = true
		return e.undo.after_move(undo, _walk(steed, CombatGrid.path_to(sreach, dest), 1, CombatResult.new(), undo.handled))
	# Freedom of Movement: 5 ft of movement slips any grapple.
	if c.creature.has_flag("freedom_of_movement") and e.grapples.has(c.id) and c.movement_left >= 5:
		e.grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
		c.remove_meta("escape_dc")
		e.monster_actions.release_engulf(c)
		c.movement_left -= 5
		e.log.add("info", "%s slips free (Freedom of Movement)" % c.name(), c.id)
	if c.speed() <= 0:
		return CombatResult.fail("Speed 0")
	if c.creature.has_condition(&"prone") and c.movement_left >= c.speed() / 2:
		stand_up(c)
	var reach := reachable_for(c)
	if not reach.has(dest):
		return CombatResult.fail("Can't reach that square with %d ft of movement" % c.movement_left)
	if bool((reach[dest] as Dictionary)["occupied"]):
		return CombatResult.fail("You can't end your move in an occupied space")
	var path := CombatGrid.path_to(reach, dest)
	var r := CombatResult.new()
	return e.undo.after_move(undo, _walk(c, path, 1, r, undo.handled))


## Moves `c` (not on its own turn) up to `feet` toward the reachable square that best follows `dir` (Confusion,
## Compulsion). The movement can provoke Opportunity Attacks.
func march(c: Combatant, dir: Vector2, feet: int, r: CombatResult) -> CombatResult:
	var origin := center_of(c)
	return _move_best(c, feet, r, func(cell: Vector2i) -> float: return (Vector2(cell) + Vector2(0.5, 0.5) - origin).dot(dir.normalized()))


## Moves `c` up to `feet` as far from `away` as it can get (Dissonant Whispers).
func flee(c: Combatant, away: Combatant, feet: int, r: CombatResult) -> CombatResult:
	var e := enc()
	return _move_best(c, feet, r, func(cell: Vector2i) -> float: return float(e.grid.distance_ft(away.cell, away.size_cells, cell, c.size_cells)))


func _move_best(c: Combatant, feet: int, r: CombatResult, score: Callable) -> CombatResult:
	var keep := c.movement_left
	c.movement_left = feet
	var reach := reachable_for(c)
	var best := c.cell
	var best_s := float(score.call(c.cell))
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var sc := float(score.call(cell))
		if sc > best_s + 0.01:
			best_s = sc
			best = cell
	if best == c.cell:
		c.movement_left = keep
		return r
	var res := _walk(c, CombatGrid.path_to(reach, best), 1, r, {})
	c.movement_left = keep
	return res


func _walk(c: Combatant, path: Array[Vector2i], i: int, r: CombatResult, handled: Dictionary) -> CombatResult:
	var e := enc()
	while i < path.size():
		var to := path[i]
		if not c.creature.has_flag("flyby") and not c.creature.has_flag("agile"):
			for p in _provokers(c, c.cell, to):
				var key := "%s@%d" % [p.id, i]
				if handled.has(key):
					continue
				handled[key] = true
				var decision := e._reaction_decision(p, "opportunity_attack")
				var idx := i
				var resume := func() -> CombatResult:
					if c.is_down() or c.speed() <= 0 or e.state != Encounter.State.ACTIVE:
						return r
					return _walk(c, path, idx, r, handled)
				if decision == "ask":
					var req := ReactionRequest.new("opportunity_attack", p.id, c.id)
					req.title = "Opportunity Attack?"
					req.text = "%s is leaving %s's reach. %s can spend a Reaction to make one melee attack now." % [c.name(), e.echo_knight.reach_name(p, c), p.name()]
					req.continuation = func(use: bool) -> CombatResult:
						if use:
							return e.then(e._opportunity_attack(p, c), resume)
						return resume.call() as CombatResult
					e.pending = req
					r.pending = req
					return r
				elif decision == "auto":
					var sub := e._opportunity_attack(p, c)
					if e.pending != null:
						return e.then(sub, resume)
					if c.is_down() or c.speed() <= 0 or e.state != Encounter.State.ACTIVE:
						return r
		var occ := _occupancy_for(c)
		var step := e.grid.step_cost(c.cell, to, c.size_cells, _has_fn(occ["blocked"] as Dictionary), _value_fn(occ["slowed"] as Dictionary), move_mode(c))
		if step > 0:
			step *= extra_cost(c)   # crawling, dragging someone
		if c.has_meta("jumping"):
			step = 0
		if step < 0 or step > c.movement_left:
			break
		var from := c.cell
		c.movement_left -= step
		c.moved = true
		c.record_step(c.cell, to)
		c.cell = to
		c.facing = Vector2(to - from).normalized()
		e.events.append({"type": "move", "id": c.id, "from": from, "to": to})
		var carried := e.rider_of(c)
		if carried != null:
			var rfrom := carried.cell
			carried.cell = to
			e.events.append({"type": "move", "id": carried.id, "from": rfrom, "to": to, "mounted": true})
		e.grappling.drag_along(c, from)
		_after_step(c, from)
		# Booming Blade: 5 ft moved of the creature's own will (`handled.willing`, set by move, free_move, jump and a
		# legendary move) sets off the energy around it.
		if handled.has("willing"):
			e.spells.booming_moved(c)
		if c.is_down() or e.state != Encounter.State.ACTIVE:
			return r
		i += 1
		# Polearm Master's Reactive Strike: entering the reach of a polearm-wielder.
		for pm in e.hostiles_of(c):
			var pkey := "pole:%s" % pm.id
			if handled.has(pkey) or not e.features.has_feat(pm, "polearm_master") or not e.spells.can_react(pm) or not e.can_see(pm, c):
				continue
			var pole := e.weapons._polearm_option(pm)
			if pole.is_empty():
				continue
			var preach := (pole["profile"] as WeaponProfile).reach
			if e.grid.distance_ft(pm.cell, pm.size_cells, to, c.size_cells) <= preach and e.grid.distance_ft(pm.cell, pm.size_cells, from, c.size_cells) > preach:
				handled[pkey] = true
				var pdec := e._reaction_decision(pm, "reactive_strike")
				if pdec == "auto":
					pm.reaction_available = false
					e.log.add("reaction", "%s strikes as %s closes in (Polearm Master)" % [pm.name(), c.name()], pm.id)
					var psub := e._resolve_attack(pm, c, pole, {"reaction": true})
					if e.pending != null:
						var ii := i
						return e.then(psub, func() -> CombatResult:
							if c.is_down() or c.speed() <= 0 or e.state != Encounter.State.ACTIVE:
								return r
							return _walk(c, path, ii, r, handled))
					if c.is_down() or e.state != Encounter.State.ACTIVE:
						return r
				elif pdec == "ask":
					var preq := ReactionRequest.new("reactive_strike", pm.id, c.id)
					preq.title = "Reaction: Reactive Strike?"
					preq.text = "%s enters %s's reach. Strike with the polearm?" % [c.name(), pm.name()]
					var jj := i
					preq.continuation = func(use: bool) -> CombatResult:
						var cont := func() -> CombatResult:
							if c.is_down() or c.speed() <= 0 or e.state != Encounter.State.ACTIVE:
								return r
							return _walk(c, path, jj, r, handled)
						if use:
							pm.reaction_available = false
							return e.then(e._resolve_attack(pm, c, pole, {"reaction": true}), cont)
						return cont.call() as CombatResult
					e.pending = preq
					r.pending = preq
					return r
		# Readied attacks trigger when the mover comes into reach.
		for p in _readied_triggers(c, from, to):
			var rkey := "ready:%s" % p.id
			if handled.has(rkey):
				continue
			handled[rkey] = true
			var rdecision := e._reaction_decision(p, "readied_attack")
			var next_i := i
			var resume2 := func() -> CombatResult:
				if c.is_down() or c.speed() <= 0 or e.state != Encounter.State.ACTIVE:
					return r
				return _walk(c, path, next_i, r, handled)
			if rdecision == "ask":
				var rreq := ReactionRequest.new("readied_attack", p.id, c.id)
				rreq.title = "Readied attack?"
				rreq.text = "%s comes within reach of %s, who readied an attack. Use the Reaction to attack now?" % [c.name(), p.name()]
				rreq.continuation = func(use: bool) -> CombatResult:
					if use:
						return e.then(e.attacks._readied_attack(p, c), resume2)
					p.readied = {}
					return resume2.call() as CombatResult
				e.pending = rreq
				r.pending = rreq
				return r
			elif rdecision == "auto":
				var sub2 := e.attacks._readied_attack(p, c)
				if e.pending != null:
					return e.then(sub2, resume2)
				if c.is_down() or c.speed() <= 0 or e.state != Encounter.State.ACTIVE:
					return r
	if c.hidden:
		e._check_still_hidden(c)
	return r


## Creatures with a readied attack whose reach (or range) `mover` has just entered.
func _readied_triggers(mover: Combatant, from: Vector2i, to: Vector2i) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for p in e.hostiles_of(mover):
		if p.readied.is_empty() or not p.reaction_available or not p.can_act() or p.creature.has_flag("no_reactions") or not e.can_see(p, mover):
			continue
		var reach := 0
		if p.readied.has("spell"):
			reach = e.spells.range_ft(Compendium.shared().spell_data(str(p.readied["spell"])), p)
		else:
			var option := e.option_by_id(p, str(p.readied.get("option", "")))
			if option.is_empty():
				continue
			var prof := option["profile"] as WeaponProfile
			reach = prof.reach if bool(option["melee"]) else prof.normal_range
		var before := e.grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells)
		var after := e.grid.distance_ft(p.cell, p.size_cells, to, mover.size_cells)
		if after <= reach and before > reach:
			out.append(p)
	return out


## Hostile creatures that can see the mover and have it in reach at `from` but not at `to`.
func _provokers(mover: Combatant, from: Vector2i, to: Vector2i) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for p in e.hostiles_of(mover):
		if not e.spells.can_react(p) or not e.can_see(p, mover) or p.creature.has_flag("no_opportunity_attacks"):
			continue
		# Disengage stops Opportunity Attacks, except a Sentinel's against a creature within 5 ft of it.
		if mover.disengaged and not (e.features.has_feat(p, "sentinel") and e.grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells) <= 5):
			continue
		var reach := p.reach_ft()
		var before := e.grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells)
		var after := e.grid.distance_ft(p.cell, p.size_cells, to, mover.size_cells)
		if before <= reach and after > reach:
			out.append(p)
	# An Echo Knight's echo: leaving its 5-ft reach.
	e.echo_knight.provokers(mover, from, to, out)
	return out


func _after_step(c: Combatant, from: Vector2i) -> void:
	var e := enc()
	e.items.specials.fr.after_step(c, from)
	e.spells.specials.mid.shell_moved(c)
	e.monster_actions.entered_space(c)
	e.spells.on_enter_cell(c, from)


func stand_up(c: Combatant) -> CombatResult:
	var e := enc()
	if not c.creature.has_condition(&"prone"):
		return CombatResult.fail("Not Prone")
	var cost := 5 if c.creature.has_flag("hop_up") else c.speed() / 2
	if c.speed() <= 0 or c.movement_left < cost:
		return CombatResult.fail("Standing up costs %d ft" % cost)
	c.movement_left -= cost
	c.creature.remove_condition(&"prone")
	c.stood_up = true
	e.log.add("move", "%s stands up (%d ft)" % [c.name(), cost], c.id)
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## Moving with feature movement that doesn't provoke Opportunity Attacks (Tactical Shift, Cunning Strike's
## Withdraw, Remarkable Athlete, Maneuvering Attack): up to `c.free_move_ft`, not using the creature's movement.
func free_move(c: Combatant, dest: Vector2i) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if c.free_move_ft <= 0:
		return CombatResult.fail("No free movement")
	var reach := reachable_for(c, c.free_move_ft)
	if not reach.has(dest) or bool((reach[dest] as Dictionary)["occupied"]):
		return CombatResult.fail("Can't get there with %d ft" % c.free_move_ft)
	var path := CombatGrid.path_to(reach, dest)
	var keep_move := c.movement_left
	var keep_dis := c.disengaged
	var undo := e.undo.before_move(c)
	c.movement_left = c.free_move_ft
	c.disengaged = true
	var r := _walk(c, path, 1, CombatResult.new(), undo.handled)
	c.free_move_ft = 0
	c.movement_left = keep_move
	c.disengaged = keep_dis
	return e.undo.after_move(undo, r)


## Jump (the spell): once on each of its turns, a leap of up to 30 ft for 10 ft of movement, over creatures and
## Difficult Terrain (not through walls). Leaving an enemy's reach still provokes Opportunity Attacks.
func jump(c: Combatant, dest: Vector2i) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.creature.has_flag("jump"):
		return CombatResult.fail("No Jump")
	if int(c.get_meta("jumped_round", -1)) == e.round_no:
		return CombatResult.fail("Already jumped this turn")
	if c.movement_left < 10:
		return CombatResult.fail("Needs 10 ft of movement")
	if e.grappling.drag_extra(c) > 0:
		return CombatResult.fail("Can't leap while dragging someone: let go first")
	if e.grid.distance_ft(c.cell, c.size_cells, dest, c.size_cells) > 30:
		return CombatResult.fail("At most 30 ft")
	for cell in CombatGrid.footprint(dest, c.size_cells):
		if e.grid.is_solid(cell) or (e.occupant_at(cell) != null and e.occupant_at(cell) != c):
			return CombatResult.fail("Can't land there")
	var path: Array[Vector2i] = [c.cell]
	var from := center_of(c)
	var to := Vector2(dest.x + c.size_cells / 2.0, dest.y + c.size_cells / 2.0)
	var steps := maxi(absi(dest.x - c.cell.x), absi(dest.y - c.cell.y))
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		var cell := Vector2i(floori(p.x - c.size_cells / 2.0 + 0.5), floori(p.y - c.size_cells / 2.0 + 0.5))
		if e.grid.has_flag(cell, CombatGrid.WALL):
			return CombatResult.fail("A wall is in the way")
		if cell != path[path.size() - 1]:
			path.append(cell)
	if path[path.size() - 1] != dest:
		path.append(dest)
	var undo := e.undo.before_move(c)
	c.movement_left -= 10
	c.set_meta("jumped_round", e.round_no)
	c.set_meta("jumping", true)
	e.log.add("move", "%s leaps %d ft (Jump)" % [c.name(), e.grid.distance_ft(c.cell, c.size_cells, dest, c.size_cells)], c.id)
	var r := _walk(c, path, 1, CombatResult.new(), undo.handled)
	c.remove_meta("jumping")
	return e.undo.after_move(undo, r)


func drop_prone(c: Combatant) -> CombatResult:
	var e := enc()
	if c.speed() <= 0:
		return CombatResult.fail("Speed 0")
	c.creature.add_condition(&"prone", "Dropped prone")
	e.log.add("move", "%s drops Prone" % c.name(), c.id)
	return CombatResult.new()


## Moves a creature without using its movement (Push, Shove, Thunderwave, Thorn Whip): no Opportunity Attacks.
## It goes in a straight line away from (or, with `toward`, toward) the grid point `origin`, square by square, and
## stops at walls, other creatures and ledges 10 ft or more above it. Areas it's moved into still affect it. Pushed
## off a ledge 10 ft or more high it falls; pushed into the map's open drop (a chasm) it falls out of the fight.
## Returns the squares moved.
func forced_move(target: Combatant, origin: Vector2, feet: int, toward: bool = false) -> int:
	var e := enc()
	# Stand as One (Tyro of the Gauntlet): an ally beside it spends a Reaction and it doesn't budge.
	if feet > 0 and e.faerun.blocks_forced_move(target):
		return 0
	# Dwarven Plate: a Reaction cuts a shove across the ground by up to 10 ft.
	feet = e.items.forced_move_feet(target, feet)
	var dir := center_of(target) - origin
	if toward:
		dir = -dir
	if dir.length() < 0.01:
		return 0
	dir = dir.normalized()
	var start := target.cell
	var moved := 0
	for k in range(1, feet / CombatGrid.FEET + 1):
		var nxt := start + Vector2i(roundi(dir.x * k), roundi(dir.y * k))
		if nxt == target.cell:
			continue
		var ok := true
		var over := 0
		var partner := e.mount_of(target) if e.mount_of(target) != null else e.rider_of(target)
		for cell in CombatGrid.footprint(nxt, target.size_cells):
			var o := e.occupant_at(cell)
			if e.grid.drop_at(cell) > 0:
				over = maxi(over, e.grid.drop_at(cell))
			elif not e.grid.in_bounds(cell) or e.grid.is_solid(cell) or (o != null and o != target and o != partner):
				ok = false
		var rise := e.grid.height(nxt) - e.grid.height(target.cell)
		if not ok or (over == 0 and rise > CombatGrid.FEET):
			break
		var falls := over > 0 or rise < -CombatGrid.FEET
		if falls and catches_itself(target):
			break
		e.events.append({"type": "move", "id": target.id, "from": target.cell, "to": nxt, "forced": true})
		var was := target.cell
		target.cell = nxt
		target.clear_run()
		moved += 1
		if over > 0:
			fall_away(target, over)
			return moved
		_after_step(target, was)
		if falls:
			fall(target, -rise)
			break
	if moved > 0:
		e.mounts._forced_mount_check(target)
		e.grappling.check_range(target)
	return moved


# --- Falling ----------------------------------------------------------------------------------------

## Whether `c`, forced over an edge, stops at it instead: it can fly (a Fly Speed it can use) or cling to a sheer face
## (a Climb Speed, Spider Climb). The 2024 rules leave catching yourself to the DM (deviations.md).
func catches_itself(c: Combatant) -> bool:
	if not c.can_act() or c.creature.has_condition(&"prone") or c.speed() <= 0:
		return false
	return c.creature.speed("fly").total() > 0 or (move_mode(c) & CombatGrid.MOVE_CLIMB) != 0


## `c` falls `feet` (2024): 1d6 Bludgeoning for every 10 ft, at most 20d6, landing Prone unless the fall did it no harm.
## A caster's Feather Fall (it lands on its feet, unharmed, if it reaches the ground within the minute: 600 ft) and a
## monk's Slow Fall answer it as Reactions, used when they help unless the reactor's rule for them is Never (a fall
## can't wait for a prompt). Returns the damage taken.
func fall(c: Combatant, feet: int, why: String = "Falling") -> int:
	var e := enc()
	if feet < 10 or not c.is_alive():
		return 0
	e.events.append({"type": "fall", "id": c.id, "feet": feet})
	var hurts := feet
	if _feather_fall(c, feet):
		hurts = maxi(0, feet - 600)
		if hurts < 10:
			e.log.add("move", "%s drifts down %d ft and lands on its feet" % [c.name(), feet], c.id)
			return 0
	var rolled := e._roll_damage_dice("%dd6" % mini(20, hurts / 10), false, 0, why)
	var amount := int(rolled["total"])
	amount -= _slow_fall(c, amount)
	if amount <= 0:
		e.log.add("move", "%s falls %d ft and lands unharmed" % [c.name(), feet], c.id, [str(rolled["text"])])
		return 0
	var dr := e.deal_damage(null, c, [{"amount": amount, "type": "bludgeoning"}], false, "%s %d ft" % [why, feet], [str(rolled["text"])])
	if dr.final > 0 and c.is_alive() and not c.creature.has_condition(&"prone"):
		c.creature.add_condition(&"prone", "Fell %d ft" % feet)
		e.events.append({"type": "condition", "id": c.id})
	return dr.final


## Feather Fall (2024 Reaction spell, 60 ft, a falling creature the caster can see): the falling creature's own, or the
## nearest ally's who has it and its Reaction. Used for a fall that could hurt (20 ft or more, or enough to drop it).
func _feather_fall(c: Combatant, feet: int) -> bool:
	var e := enc()
	if feet < 20 and feet / 10 * 6 < c.creature.hp:
		return false
	var casters: Array[Combatant] = [c]
	var near := e.allies_of(c)
	near.sort_custom(func(a: Combatant, b: Combatant) -> bool: return e.distance(a, c) < e.distance(b, c))
	casters.append_array(near)
	for caster in casters:
		if caster != c and (e.distance(caster, c) > 60 or not e.can_see(caster, c)):
			continue
		if e._reaction_decision(caster, "feather_fall") == "never" or not e.spells.reaction_spells.can_cast_reaction(caster, "feather_fall"):
			continue
		if e.spells.reaction_spells.begin_reaction_spell(caster, "feather_fall"):
			e.log.add("reaction", "%s slows %s's fall (Feather Fall)" % [caster.name(), "its own" if caster == c else c.name() + "'s"], caster.id)
			return true
	return false


## Slow Fall (Monk 4, 2024): a Reaction takes five times the monk's level off the falling damage. Returns the damage
## it takes off.
func _slow_fall(c: Combatant, amount: int) -> int:
	var e := enc()
	if amount <= 0 or not CombatFeatures.has_feature(c, "slow_fall") or not e.spells.can_react(c) \
			or e._reaction_decision(c, "slow_fall") == "never":
		return 0
	c.reaction_available = false
	var cut := mini(amount, 5 * ClassFeatures.level_of(c, "monk"))
	e.log.add("reaction", "%s twists in the air and takes %d less from the fall (Slow Fall)" % [c.name(), cut], c.id)
	return cut


## `c` goes over the edge into the map's open drop (a chasm, a tower's well): it falls `feet` and is out of the fight,
## off the grid, with whoever rides it. A foe that lives through it is gone; a party member comes back to the party
## once the fight is over (it climbs back up, or the others fetch it).
func fall_away(c: Combatant, feet: int) -> void:
	var e := enc()
	e.log.add("move", "%s goes over the edge" % c.name(), c.id)
	var rider := e.rider_of(c)
	var mount := e.mount_of(c)
	if mount != null:
		c.remove_meta("mounted_on")
		mount.remove_meta("ridden_by")
	fall(c, feet)
	leave_grid(c, "fell")
	if rider != null:
		rider.remove_meta("mounted_on")
		c.remove_meta("ridden_by")
		fall_away(rider, feet)


## Takes `c` off the grid for the rest of the fight (`how`: "fell"): no space, no turns, no target, and it doesn't count
## for the end of the fight. Its grapples and Concentration end.
func leave_grid(c: Combatant, how: String) -> void:
	var e := enc()
	e._release_grapples_by(c)
	if e.grapples.has(c.id):
		e.grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
	if c.creature.concentration != null:
		c.creature.concentration.end("out of the fight")
	c.set_meta("left_fight", how)
	c.cell = SpellSpecials.BANISHED_CELL
	var at := e.order.find(c)
	if at >= 0 and at != e.turn_index:
		e.order.remove_at(at)
		if at < e.turn_index:
			e.turn_index -= 1
	e.events.append({"type": "vanish", "id": c.id, "left": how})
	e._check_over()


## The middle of a creature's space, in grid units.
func center_of(c: Combatant) -> Vector2:
	return Vector2(c.cell.x + c.size_cells / 2.0, c.cell.y + c.size_cells / 2.0)
