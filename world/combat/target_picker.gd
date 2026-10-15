class_name TargetPicker
extends RefCounted
## The combat view's picks beyond the first click (docs/ui/combat_view.md, docs/contracts/combat.md): a wall drawn
## square by square and the side a drawn Wall of Fire burns on, the creature Commander's Strike's ally attacks, the
## creature Crown of Madness's victim must attack (or no one), the ally Maneuvering Attack lets move, with its square,
## who an Evoker's Evocation spell shields (Sculpt Spells), which creatures in a spell's area it takes when it takes
## up to so many of the caster's choice (Slow, Mass Cure Wounds), and the willing creature a teleport takes along
## (Dimension Door, Thunder Step). It keeps what has been picked, says what the floor and
## the tooltip show, and builds the command; the engine checks every pick (SpellTargeting, SpellPlacement,
## EncounterWeapons, EncounterMovement, SpellSaves). It also says where an area placed at a point goes (aim).

## What is being picked: "" (nothing), "wall" (the wall's squares), "side" (the side a drawn Wall of Fire burns on),
## "strike" (the creature Commander's Strike's ally attacks), "victim" (the creature the crowned one must attack),
## "mover" (the ally Maneuvering Attack moves), "square" (where that ally goes), "sculpt" (who Sculpt Spells shields),
## "choose" (the creatures in the area a spell of the caster's choice takes) or "companion" (who a teleport takes along,
## after the square it lands on).
var step := ""
var e: Encounter
## Who acts, the hotbar action being aimed, and its spell slot.
var c: Combatant = null
var action: Dictionary = {}
var slot := 0
## The creature picked first: Commander's Strike's ally, Crown of Madness's crowned creature, the ally that moves.
var first: Combatant = null
## The wall's squares so far, in drawing order.
var path: Array[Vector2i] = []
## The square last pointed at (Enter on the side step takes its side).
var _pointed := Vector2i(-1, -1)
## Squares the moving ally can reach (the square step), and whether it was the only one who could move.
var _reach: Dictionary = {}
var _only_mover := false
## The sculpt and choose steps: the creatures to pick from, those picked, the spell's squares, and where it goes off
## (the companion step keeps the square the teleport lands on in `_point`).
## `_sculpt_self`: a spell from the caster with no aim of its own (Thunderclap), so Backspace has no aim to go back to.
## `_choose_cap`: how many creatures the spell of the caster's choice takes.
var _sculpt_all: Array[Combatant] = []
var _sculpt_picks: Array[Combatant] = []
var _sculpt_cells: Array[Vector2i] = []
var _point := Vector2.INF
var _dir := Vector2.ZERO
var _sculpt_self := false
var _choose_cap := 0


func _init(encounter: Encounter) -> void:
	e = encounter


func active() -> bool:
	return step != ""


## Forgets the picks (the command went out, or the view moved on).
func reset() -> void:
	step = ""
	c = null
	action = {}
	first = null
	path = []
	_pointed = Vector2i(-1, -1)
	_reach = {}
	_only_mover = false
	_sculpt_all = []
	_sculpt_picks = []
	_sculpt_cells = []
	_point = Vector2.INF
	_dir = Vector2.ZERO
	_sculpt_self = false
	_choose_cap = 0


## The player backed out: a move Maneuvering Attack offered is passed on.
func cancel() -> void:
	if step in ["mover", "square"]:
		e.movement.decline_reaction_move()
	reset()


# --- Starting -------------------------------------------------------------------------------------

## Whether `a` (aimed with nothing on the hotbar) still takes a pick here: Crown of Madness's keep-control action picks
## the creature the crowned one must attack; an Evoker's Evocation spell from itself (Thunderclap) with its own side
## caught in it, who to shield.
func takes(who: Combatant, a: Dictionary) -> bool:
	return not _crowned_by(who, a).is_empty() or str(a.get("targeting", "")) == "none" \
		and not _sculptable(who, a, Vector2.INF, Vector2.ZERO, int(a.get("slot", 0))).is_empty()


## Starts aiming `a`: a wall starts its drawing, Crown of Madness's keep-control its victim. Returns the action to aim:
## `a`, or for a wall whose cast-time choice is a ring, a globe or a dome a copy aimed at a point.
func begin(who: Combatant, a: Dictionary, slot_: int) -> Dictionary:
	reset()
	if str(a.get("targeting", "")) == "wall":
		var s := _spell(a)
		if not SpellTargeting.drawn_wall(s, SpellTargeting.choice_of(s, a.get("opts", {}) as Dictionary)):
			var placed := a.duplicate()
			placed["targeting"] = "point"
			return placed
		_start(who, a, slot_, "wall")
		return a
	var crowned := _crowned_by(who, a)
	if not crowned.is_empty():
		_start(who, a, slot_, "victim")
		first = e.get_c(crowned)
	elif str(a.get("targeting", "")) == "none" and sculpt(who, a, Vector2.INF, Vector2.ZERO, slot_):
		_sculpt_self = true
	return a


## The spell is aimed (`point`, or `dir` for a cone or a line): a spell on up to so many creatures of the caster's
## choice in its area (Slow, Mass Cure Wounds) asks which first, with the ones it would take picked to start with
## (SpellTargeting.area_default: for Slow, the foes in it); an Evoker's Evocation spell with the caster or its allies
## caught in it asks who to shield (Sculpt Spells), starting from the caster and the allies nearest it. True when that
## pick starts; otherwise the spell is cast as aimed.
func sculpt(who: Combatant, a: Dictionary, point: Vector2, dir: Vector2, slot_: int) -> bool:
	if _choose(who, a, point, dir, slot_):
		return true
	var all := _sculptable(who, a, point, dir, slot_)
	if all.is_empty():
		return false
	var s := _spell(a)
	_start(who, a, slot_, "sculpt")
	_sculpt_all = all
	_sculpt_cells = e.spells.area_for(who, s, point, dir, slot_)
	_point = point
	_dir = dir
	for id in e.spells.saves.sculpt_default(who, all, SpellSaves.sculpt_cap(s, slot_)):
		_sculpt_picks.append(e.get_c(id))
	return true


## Starts the choose step for a spell on up to `area_max_targets` creatures of the caster's choice with anyone in its
## area; false for any other spell, or when no one is in it.
func _choose(who: Combatant, a: Dictionary, point: Vector2, dir: Vector2, slot_: int) -> bool:
	if who == null or not str(a.get("kind", "")) in ["spell", "item_spell"] or (point == Vector2.INF and dir == Vector2.ZERO):
		return false
	var s := _spell(a)
	var cap := int(s.get("area_max_targets", 0))
	if cap <= 0 or not s.has("area"):
		return false
	var cells := e.spells.area_for(who, s, point, dir, slot_)
	var all := e.spells.targeting.area_candidates(who, s, cells)
	if all.is_empty():
		return false
	_start(who, a, slot_, "choose")
	_sculpt_all = all
	_sculpt_cells = cells
	_point = point
	_dir = dir
	_choose_cap = cap
	_sculpt_picks = e.spells.targeting._area_victims(who, s, cells, SpellTargeting.choice_of(s, a.get("opts", {}) as Dictionary))
	return true


## After the first pick of an action that takes a second: Commander's Strike's ally (then the creature it attacks) and
## Crown of Madness's target (then the creature it must attack). True when the second pick starts.
func second(who: Combatant, a: Dictionary, t: Combatant, slot_: int) -> bool:
	if t == null:
		return false
	if str(a.get("id", "")) == "feat:commanders_strike" and e.weapons.strike_ally_why(who, t) == "":
		_start(who, a, slot_, "strike")
		first = t
		return true
	if str(a.get("kind", "")) in ["spell", "item_spell"] and str(a.get("spell_id", "")) == "crown_of_madness":
		_start(who, a, slot_, "victim")
		first = t
		return true
	return false


## The square a teleport lands on is picked (`point`): a teleport that can take one willing creature along (Thunder
## Step: `bring_along` in the spell's data) with someone able to come asks who first. True when that pick starts; false
## when the cast goes ahead as it is (nobody to bring, or the square is no good: the cast says why).
func bring_along(who: Combatant, a: Dictionary, point: Vector2, slot_: int) -> bool:
	if who == null or not str(a.get("kind", "")) in ["spell", "item_spell"]:
		return false
	var s := _spell(a)
	if e.spells.targeting.companions_for(who, s).is_empty():
		return false
	var opts := (a.get("opts", {}) as Dictionary).duplicate()
	if "distant" in (opts.get("metamagic", []) as Array):
		opts["range_mult"] = true
	if str(e.spells._check_targets(who, s, slot_, [], point, opts)["why"]) != "":
		return false
	_start(who, a, slot_, "companion")
	_point = point
	return true


## Maneuvering Attack just hit for `who`: the ally that moves (or the only one who can), then its square. False when
## nothing was offered or no one can take it (the offer is then passed on).
func begin_move(who: Combatant) -> bool:
	var offer := e.movement.open_reaction_move()
	if offer.is_empty() or str(offer["by"]) != who.id:
		return false
	var movers := _movers()
	if movers.is_empty():
		e.movement.decline_reaction_move()
		return false
	_start(who, {"id": "reaction_move", "kind": "reaction_move", "label": str(offer["source"]), "targeting": "ally",
		"legal": true, "reason": "", "range": 0, "cost": "reaction", "spell_id": "", "option_id": ""}, 0, "mover")
	if movers.size() == 1:
		_only_mover = true
		_mover_picked(movers[0])
	return true


func _start(who: Combatant, a: Dictionary, slot_: int, first_step: String) -> void:
	reset()
	c = who
	action = a
	slot = slot_
	step = first_step


# --- Picking --------------------------------------------------------------------------------------

## A click (or A) on `cell`, with `who` the creature there if any: {} to keep picking, {do: "refuse", why}, or the
## command: {do: "perform", action, targets, point, dir} or {do: "move", ally, cell}.
func pick(cell: Vector2i, who: Combatant) -> Dictionary:
	if cell.x < 0 and who == null:
		return {}
	match step:
		"wall":
			var at := _square(cell, who)
			if not path.is_empty() and at == path[path.size() - 1]:
				return _finish_wall()
			var run := _run_to(at)
			if run.is_empty():
				return _refuse(_step_why(at))
			path.append_array(run)
			return {}
		"side":
			var side := e.spells.placement.side_of(path, _square(cell, who))
			if side == "":
				return _refuse("Click a square beside the wall, on the side that should burn")
			return _cast_wall(side)
		"strike":
			if who == null:
				return _refuse("Choose the creature %s attacks (Enter: its best target)" % first.name())
			if e.weapons.strike_option(first, who).is_empty():
				return _refuse("%s can't reach %s with an attack" % [first.name(), who.name()])
			return _command([first, who])
		"victim":
			if who == null:
				return _refuse("Choose the creature it must attack (Enter: no one)")
			if who == first:
				return _victim(null)
			var why := e.spells.targeting.crown_victim_why(c, first, who)
			return _refuse(why) if why != "" else _victim(who)
		"mover":
			var mover_why := e.movement.reaction_mover_why(who) if who != null else "Choose an ally"
			if who == null or not who.is_player_controlled() or mover_why != "":
				return _refuse(mover_why if mover_why != "" else "Choose an ally")
			_mover_picked(who)
			return {}
		"square":
			var to := _square(cell, who)
			if to == first.cell:
				return {}
			if not _reach.has(to) or bool((_reach[to] as Dictionary)["occupied"]):
				return _refuse("%s can't get there with %d ft" % [first.name(), first.speed() / 2])
			return {"do": "move", "ally": first, "cell": to}
		"sculpt":
			if who == null or not who in _sculpt_all:
				return _refuse("Click a creature in the spell to shield it, or not · Enter: cast")
			if who in _sculpt_picks:
				_sculpt_picks.erase(who)
				return {}
			if _sculpt_picks.size() >= _sculpt_cap():
				return _refuse("Sculpt Spells shields up to %d creatures" % _sculpt_cap())
			_sculpt_picks.append(who)
			return {}
		"companion":
			if who != null and who != c:
				var why_not := e.spells.targeting.companion_why(c, _spell(action), who)
				return _refuse(why_not) if why_not != "" else _cast_with(who)
			if _square(cell, who) == Vector2i(floori(_point.x), floori(_point.y)):
				return _cast_with(null)
			return _refuse("Click an ally beside you to bring along · Enter or click the landing square: go alone")
		"choose":
			if who == null:
				return _cast_chosen()
			if not who in _sculpt_all:
				return _refuse("%s isn't in the area · click the floor or press Enter: cast" % who.name())
			if who in _sculpt_picks:
				_sculpt_picks.erase(who)
				return {}
			if _sculpt_picks.size() >= _choose_cap:
				return _refuse("%s takes up to %d creatures" % [_spell(action).get("name", ""), _choose_cap])
			_sculpt_picks.append(who)
			return {}
	return {}


## Enter: the wall is done, the hovered side burns, the ally picks its own target, or no one is crowned's victim.
func confirm() -> Dictionary:
	match step:
		"wall":
			return _finish_wall() if not path.is_empty() else _refuse("Click the square where the wall begins")
		"side":
			var side := e.spells.placement.side_of(path, _pointed)
			return _cast_wall(side) if side != "" else _refuse("Point at a square on the side that should burn")
		"strike":
			return _command([first])
		"victim":
			return _victim(null)
		"sculpt":
			return _cast_sculpted()
		"choose":
			return _cast_chosen()
		"companion":
			return _cast_with(null)
	return {}


## Backspace or right-click: takes back the last square, goes back from the side to the drawing, or from the second
## pick to the first. False when there is nothing to take back (right-click then cancels).
func undo() -> bool:
	match step:
		"wall":
			if path.is_empty():
				return false
			path.pop_back()
			return true
		"side":
			step = "wall"
			return true
		"strike", "victim":
			# Crown of Madness's keep-control has no first pick to go back to.
			if not _crowned_by(c, action).is_empty():
				return false
			step = ""
			first = null
			return true
		"square":
			if _only_mover:
				return false
			step = "mover"
			first = null
			return true
		"sculpt":
			# Back to aiming the spell; a spell from the caster has no aim, so Backspace cancels it.
			if _sculpt_self:
				return false
			reset()
			return true
		"choose", "companion":
			reset()
			return true
	return false


## Whether `o` is something to pick now (the controller's next-target key cycles through these).
func candidate(o: Combatant) -> bool:
	match step:
		"strike":
			return o != first and not e.weapons.strike_option(first, o).is_empty()
		"victim":
			return e.spells.targeting.crown_victim_why(c, first, o) == ""
		"mover":
			return o.is_player_controlled() and e.movement.reaction_mover_why(o) == ""
		"sculpt", "choose":
			return o in _sculpt_all
		"companion":
			return o != c and e.spells.targeting.companion_why(c, _spell(action), o) == ""
	return false


# --- What the floor and the tooltip show ----------------------------------------------------------

## The marks and the tooltip for pointing at `cell` (`who` there): {area, trail, target, friendly, goal, danger: cells,
## title, lines, warnings}, and for a spell's area already placed (the sculpt and choose steps) its edge to draw instead
## of painting its squares (owner, 2026-10-12: "don't make the floor orange"): outline (SpellTargeting.area_outline)
## and outline_cells.
func show(cell: Vector2i, who: Combatant) -> Dictionary:
	_pointed = _square(cell, who)
	var out := {"area": [], "trail": [], "target": [], "friendly": [], "goal": [], "danger": [], "title": "", "lines": [], "warnings": []}
	match step:
		"wall":
			_show_wall(out)
		"side":
			_show_side(out)
		"strike":
			_show_strike(out, who)
		"victim":
			_show_victim(out, who)
		"mover":
			_show_mover(out, who)
		"square":
			_show_square(out)
		"sculpt":
			_show_sculpt(out, who)
		"choose":
			_show_choose(out, who)
		"companion":
			_show_companion(out, who)
	return out


func _show_wall(out: Dictionary) -> void:
	var s := _spell(action)
	var most := e.spells.targeting.wall_squares(s, slot)
	out["area"] = path.duplicate()
	if path.size() >= 2:
		out["trail"] = path.duplicate()
	_mark_creatures(out, path)
	out["title"] = "%s · %d of %d ft" % [s.get("name", ""), path.size() * CombatGrid.FEET, most * CombatGrid.FEET]
	var lines: Array = []
	var warnings: Array = []
	var fire := _burns(s)
	if path.is_empty():
		lines.append("Click the square where the wall begins (within %d ft)" % e.spells.range_ft(s, c))
	elif _pointed == path[path.size() - 1]:
		out["goal"] = [_pointed]
		lines.append("Click again to finish the wall%s" % (", then choose the side that burns" if fire else ""))
	else:
		lines.append("Click a square touching the last one (further along a straight line adds the squares between)")
		lines.append("Click the last square or press Enter to %s" % ("choose the side that burns" if fire else "cast"))
	if not path.is_empty():
		lines.append("Backspace or right-click takes back the last square")
	if _pointed.x >= 0 and (path.is_empty() or _pointed != path[path.size() - 1]):
		var run := _run_to(_pointed)
		if run.is_empty():
			out["danger"] = [_pointed]
			warnings.append(_step_why(_pointed))
		else:
			out["goal"] = run
	var inside := e.spells.creatures_in(path)
	if not inside.is_empty():
		lines.append("In the wall: %s" % ", ".join(inside.map(func(o: Combatant) -> String: return o.name())))
	out["lines"] = lines
	out["warnings"] = warnings


func _show_side(out: Dictionary) -> void:
	var s := _spell(action)
	var feet := int((s.get("zone", {}) as Dictionary).get("side_ft", 10))
	out["area"] = path.duplicate()
	if path.size() >= 2:
		out["trail"] = path.duplicate()
	out["title"] = "%s: the side that burns" % s.get("name", "")
	out["lines"] = ["Click a square on the side that should burn (%d ft deep)" % feet, "Backspace or right-click goes back to the drawing"]
	var side := e.spells.placement.side_of(path, _pointed)
	if side == "":
		out["warnings"] = ["Point at a square beside the wall"]
		return
	var burning: Array[Vector2i] = []
	for pair: Variant in e.spells.placement.path_side(path, side, feet):
		burning.append(Vector2i(int((pair as Array)[0]), int((pair as Array)[1])))
	out["target"] = burning
	var caught: Array = []
	for o in e.spells.creatures_in(burning):
		caught.append(o.name())
	if not caught.is_empty():
		(out["lines"] as Array).append("Burns there: %s" % ", ".join(caught))


func _show_strike(out: Dictionary, who: Combatant) -> void:
	for o in e.living():
		if o != first and not e.weapons.strike_option(first, o).is_empty():
			_mark(out, o)
	out["title"] = "%s strikes: choose its target" % first.name()
	var lines: Array = ["Click a creature %s can attack · Enter: its best target" % first.name(), "Backspace or right-click: another ally"]
	if who != null and who != first:
		var o := e.weapons.strike_option(first, who)
		if o.is_empty():
			out["warnings"] = ["%s can't reach %s with an attack" % [first.name(), who.name()]]
		else:
			var hc := e.hit_chance(first, who, o)
			lines.push_front("%s with %s: hit %d%%" % [who.name(), (o["profile"] as WeaponProfile).name, roundi(float(hc["chance"]) * 100.0)])
	out["lines"] = lines


func _show_victim(out: Dictionary, who: Combatant) -> void:
	for o in e.living():
		if first != null and e.spells.targeting.crown_victim_why(c, first, o) == "":
			((out["target"] if _in_reach(o) else out["friendly"]) as Array).append_array(o.footprint())
	var name_ := first.name() if first != null else "The crowned creature"
	out["title"] = "Crown of Madness: whom %s must attack" % name_
	var lines: Array = ["Click a creature · Enter%s: no one" % (", or a click on %s" % name_ if first != null else "")]
	if who != null and who != first and first != null:
		var why := e.spells.targeting.crown_victim_why(c, first, who)
		if why != "":
			out["warnings"] = [why]
		else:
			lines.push_front("%s: %s" % [who.name(), "in its reach now" if _in_reach(who) else "out of its reach now (it acts normally unless that changes)"])
	out["lines"] = lines


func _show_mover(out: Dictionary, who: Combatant) -> void:
	var offer := e.movement.open_reaction_move()
	var by := e.get_c(str(offer.get("by", "")))
	for o in _movers():
		(out["friendly"] as Array).append_array(o.footprint())
	out["title"] = "%s: who moves?" % offer.get("source", "")
	out["lines"] = ["Click an ally who can see or hear %s: it moves up to half its Speed with its Reaction" % (by.name() if by != null else "you"), "Esc: no one moves"]
	if who != null and who.is_player_controlled() and e.movement.reaction_mover_why(who) != "":
		out["warnings"] = [e.movement.reaction_mover_why(who)]


func _show_square(out: Dictionary) -> void:
	var spared := e.movement.reaction_move_spared()
	var open: Array = []
	for cell: Vector2i in _reach:
		if cell != first.cell and not bool((_reach[cell] as Dictionary)["occupied"]):
			open.append(cell)
	out["area"] = open
	out["title"] = "%s moves (up to %d ft, Reaction)" % [first.name(), first.speed() / 2]
	var lines: Array = ["No Opportunity Attack from %s" % spared.name() if spared != null else "Click the square it moves to"]
	lines.append("Esc: it stays put" if _only_mover else "Backspace or right-click: another ally · Esc: no one moves")
	var warnings: Array = []
	if _pointed in open:
		var route := CombatGrid.path_to(_reach, _pointed)
		out["trail"] = route
		var seen := {}
		for i in range(1, route.size()):
			for p in e._provokers(first, route[i - 1], route[i]):
				if p != spared and not seen.has(p.id):
					seen[p.id] = true
					warnings.append("Leaves %s's reach: Opportunity Attack" % p.name())
		out["danger" if not warnings.is_empty() else "goal"] = [_pointed]
	elif _pointed.x >= 0 and _pointed != first.cell:
		warnings.append("Out of reach")
	out["lines"] = lines
	out["warnings"] = warnings


func _show_sculpt(out: Dictionary, who: Combatant) -> void:
	_show_edge(out)
	for o in _sculpt_all:
		((out["friendly"] if o in _sculpt_picks else out["target"]) as Array).append_array(o.footprint())
	out["title"] = "Sculpt Spells: %d of %d shielded" % [_sculpt_picks.size(), _sculpt_cap()]
	var lines: Array = ["Click a creature in the spell to shield it, or not · Enter: cast",
		"Esc: don't cast" if _sculpt_self else "Backspace or right-click: aim again"]
	if who != null and who in _sculpt_all:
		lines.push_front("%s: %s" % [who.name(), "shielded (no save, no damage)" if who in _sculpt_picks else "caught in it"])
	out["lines"] = lines


func _show_choose(out: Dictionary, who: Combatant) -> void:
	_show_edge(out)
	for o in _sculpt_picks:
		_mark(out, o)
	var s := _spell(action)
	out["title"] = "%s: %d of up to %d chosen" % [s.get("name", ""), _sculpt_picks.size(), _choose_cap]
	var lines: Array = ["Click a creature in the area to add or drop it · click the floor or press Enter: cast", "Backspace or right-click: aim again"]
	if who != null and who in _sculpt_all:
		lines.push_front("%s: %s" % [who.name(), "chosen" if who in _sculpt_picks else "not chosen"])
	out["lines"] = lines
	if _sculpt_picks.is_empty():
		out["warnings"] = ["Choose at least one creature"]


func _show_companion(out: Dictionary, who: Combatant) -> void:
	var s := _spell(action)
	var landing := Vector2i(floori(_point.x), floori(_point.y))
	# A boom round the space left (Thunder Step) keeps its edge on the floor; a teleport with no area (Dimension Door) has none.
	var boom := s.has("area")
	if boom:
		out["outline"] = e.spells.targeting.area_outline(c, s, _point, Vector2.ZERO, slot)
		out["outline_cells"] = e.spells.area_for(c, s, _point, Vector2.ZERO, slot)
	out["goal"] = [landing]
	for o in e.spells.targeting.companions_for(c, s):
		(out["friendly"] as Array).append_array(o.footprint())
	var smaller := str((s.get("bring_along", {}) as Dictionary).get("max_size", "")) == "caster"
	out["title"] = "%s: bring someone along?" % s.get("name", "")
	var lines: Array = ["Click an ally beside you to bring along%s" % (" (it must be your size or smaller)" if smaller else ""),
		"Enter or click the landing square: go alone · Backspace or right-click: another square"]
	var warnings: Array = []
	var caught: Array = []
	if boom:
		for o in e.spells.creatures_in(out["outline_cells"] as Array[Vector2i]):
			if o != c and o != who:
				caught.append(o.name())
	if who != null and who != c:
		var why := e.spells.targeting.companion_why(c, s, who)
		if why != "":
			warnings.append(why)
		else:
			lines.push_front("%s comes along" % who.name())
			var spot := e.spells._free_cell_near(landing, who.size_cells)
			if e.grid.distance_ft(landing, c.size_cells, spot, who.size_cells) > 5 or not e.spells._room_for(spot, who.size_cells):
				warnings.append("No room beside the landing: %s would be left behind%s" % [who.name(), ", in the boom" if boom else ""])
	if not caught.is_empty():
		lines.append("In the boom: %s" % ", ".join(caught))
	out["lines"] = lines
	out["warnings"] = warnings


## The placed spell's edge, as it showed while aimed.
func _show_edge(out: Dictionary) -> void:
	out["outline"] = e.spells.targeting.area_outline(c, _spell(action), _point if _point != Vector2.INF else e.center_of(c), _dir, slot)
	out["outline_cells"] = _sculpt_cells.duplicate()


# --- Helpers --------------------------------------------------------------------------------------

## The square a click means: the floor square pointed at, or a 1-square creature's own square when the pointer is on
## its figure (the floor behind a tall figure is another square).
static func _square(cell: Vector2i, who: Combatant) -> Vector2i:
	if who != null and not cell in who.footprint():
		return who.cell
	return cell


## The squares a click on `at` adds to the wall: `at` itself when it touches the last square (or starts the wall), or
## every square on the straight line from the last one to it, as long as each can be added. Empty when none can.
func _run_to(at: Vector2i) -> Array[Vector2i]:
	var run: Array[Vector2i] = []
	if at.x < 0:
		return run
	var s := _spell(action)
	var opts := _opts()
	var so_far := path.duplicate()
	for sq in _line_to(at):
		if e.spells.targeting.wall_step_why(c, s, slot, so_far, sq, opts) != "":
			run.clear()
			return run
		so_far.append(sq)
		run.append(sq)
	return run


## The squares from the wall's last square to `at`: every one along a straight line (across, down or diagonal), else
## just `at`.
func _line_to(at: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = [at]
	if path.is_empty():
		return line
	var last := path[path.size() - 1]
	var d := at - last
	var n := maxi(absi(d.x), absi(d.y))
	if n > 1 and (d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)):
		line.clear()
		for i in range(1, n + 1):
			line.append(last + Vector2i(signi(d.x), signi(d.y)) * i)
	return line


## Why `at` can't be the wall's next square (or, past a straight run, the first square of the run that can't).
func _step_why(at: Vector2i) -> String:
	var s := _spell(action)
	var opts := _opts()
	var so_far := path.duplicate()
	for sq in _line_to(at):
		var why := e.spells.targeting.wall_step_why(c, s, slot, so_far, sq, opts)
		if why != "":
			return why
		so_far.append(sq)
	return ""


## The wall's squares are drawn: a Wall of Fire then picks its burning side; any other wall is cast.
func _finish_wall() -> Dictionary:
	var why := e.spells.targeting.wall_path_why(c, _spell(action), slot, path, _opts())
	if why != "":
		return _refuse(why)
	if _burns(_spell(action)):
		step = "side"
		return {}
	return _cast_wall("")


func _cast_wall(side: String) -> Dictionary:
	var cast := action.duplicate(true)
	var opts := (cast.get("opts", {}) as Dictionary).duplicate()
	opts["path"] = path.duplicate()
	if side != "":
		opts["side"] = side
	cast["opts"] = opts
	var mid := path[path.size() / 2]
	return {"do": "perform", "action": cast, "targets": [], "point": Vector2(mid) + Vector2(0.5, 0.5), "dir": Vector2.ZERO}


## Crown of Madness's victim picked (`who`, or null for no one): cast with it, or keep control naming it.
func _victim(who: Combatant) -> Dictionary:
	if not _crowned_by(c, action).is_empty():
		return _command([who] if who != null else [])
	var cast := action.duplicate(true)
	var opts := (cast.get("opts", {}) as Dictionary).duplicate()
	opts["crown_victim"] = who.id if who != null else ""
	cast["opts"] = opts
	return {"do": "perform", "action": cast, "targets": [first], "point": Vector2.INF, "dir": Vector2.ZERO}


## The spell goes off with the creatures picked shielded (opts.sculpt, read by SpellSaves).
func _cast_sculpted() -> Dictionary:
	var cast := action.duplicate(true)
	var opts := (cast.get("opts", {}) as Dictionary).duplicate()
	opts["sculpt"] = _sculpt_picks.map(func(o: Combatant) -> String: return o.id)
	cast["opts"] = opts
	return {"do": "perform", "action": cast, "targets": [], "point": _point, "dir": _dir}


## The spell goes off on the creatures picked (opts.chosen, read by SpellTargeting._area_victims).
func _cast_chosen() -> Dictionary:
	if _sculpt_picks.is_empty():
		return _refuse("Choose at least one creature in the area (Esc: don't cast)")
	var cast := action.duplicate(true)
	var opts := (cast.get("opts", {}) as Dictionary).duplicate()
	opts["chosen"] = _sculpt_picks.map(func(o: Combatant) -> String: return o.id)
	cast["opts"] = opts
	return {"do": "perform", "action": cast, "targets": [], "point": _point, "dir": _dir}


## The teleport goes ahead to the square picked, with `ally` along (opts.with, read by SpellTargeting.companion_why and
## the spell's handler) or alone.
func _cast_with(ally: Combatant) -> Dictionary:
	var cast := action.duplicate(true)
	if ally != null:
		var opts := (cast.get("opts", {}) as Dictionary).duplicate()
		opts["with"] = ally.id
		cast["opts"] = opts
	return {"do": "perform", "action": cast, "targets": [], "point": _point, "dir": Vector2.ZERO}


## Who an Evoker's Evocation spell aimed so could shield, when the caster or one of its allies is among them; else
## nothing (not an Evoker's Evocation spell with a save, or only foes in it).
func _sculptable(who: Combatant, a: Dictionary, point: Vector2, dir: Vector2, slot_: int) -> Array[Combatant]:
	var none: Array[Combatant] = []
	if who == null or not str(a.get("kind", "")) in ["spell", "item_spell"]:
		return none
	var s := _spell(a)
	if s.is_empty() or not s.has("save") or not s.has("area") or not e.spells.saves.sculpts(who, s):
		return none
	var self_origin := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	if point == Vector2.INF and dir == Vector2.ZERO and not self_origin:
		return none
	var cells := e.spells.area_for(who, s, point, dir, slot_)
	var all := e.spells.saves.sculpt_candidates(who, e.spells._area_victims(who, s, cells,
		SpellTargeting.choice_of(s, a.get("opts", {}) as Dictionary)))
	if not all.any(func(v: Combatant) -> bool: return v == who or who.allied_with(v)):
		return none
	return all


func _sculpt_cap() -> int:
	return SpellSaves.sculpt_cap(_spell(action), slot)


func _command(targets: Array) -> Dictionary:
	return {"do": "perform", "action": action, "targets": targets, "point": Vector2.INF, "dir": Vector2.ZERO}


func _refuse(why: String) -> Dictionary:
	return {"do": "refuse", "why": why}


func _mover_picked(who: Combatant) -> void:
	first = who
	step = "square"
	_reach = e.movement.reaction_move_reach(who)


## Allies the player runs who can take the offered move.
func _movers() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in e.living():
		if o.is_player_controlled() and e.movement.reaction_mover_why(o) == "":
			out.append(o)
	return out


## For Crown of Madness's keep-control action (a sustained action of `who`'s), the crowned creature's id; else "".
func _crowned_by(who: Combatant, a: Dictionary) -> String:
	if who == null or str(a.get("kind", "")) != "sustain" or str(a.get("spell_id", "")) != "crown_of_madness":
		return ""
	for s in e.spells.sustained_actions(who):
		if str(s["id"]) == str(a.get("sustain_id", "")):
			return str(s.get("target_id", ""))
	return ""


## Whether the crowned creature could attack `o` with a melee attack from where it stands.
func _in_reach(o: Combatant) -> bool:
	if first == null:
		return false
	for opt in e.attack_options(first):
		if bool(opt["melee"]) and e.weapons.attack_legal(first, o, opt) == "":
			return true
	return false


## Marks the creatures standing in `cells`.
func _mark_creatures(out: Dictionary, cells: Array[Vector2i]) -> void:
	for o in e.spells.creatures_in(cells):
		_mark(out, o)


## Marks `o`'s squares: a foe of the one acting in red, anyone else in the friendly colour.
func _mark(out: Dictionary, o: Combatant) -> void:
	((out["target"] if c.hostile_to(o) else out["friendly"]) as Array).append_array(o.footprint())


func _spell(a: Dictionary) -> Dictionary:
	return Compendium.shared().spell_data(str(a.get("spell_id", "")))


## Whether a drawn wall burns on one side (Wall of Fire): the side is picked after the squares.
static func _burns(s: Dictionary) -> bool:
	return (s.get("zone", {}) as Dictionary).has("side_ft")


## The cast's options the wall's checks read: its range doubled by Distant Spell.
func _opts() -> Dictionary:
	var opts := (action.get("opts", {}) as Dictionary).duplicate()
	if "distant" in (opts.get("metamagic", []) as Array):
		opts["range_mult"] = true
	return opts


## Where an area placed at a point goes when the player points at `at` on the floor (owner, 2026-10-13: "the pointer
## should be at the middle of the area"): {point, dir}, the cast's point and direction, with the area's middle at `at`.
## A Sphere or a Cylinder is centred on the grid intersection nearest it (the DMG's grid rule for a point of origin), an
## Emanation from a point on the square (or squares) under it. A Cube's point of origin lies on a face (2024): it's
## the middle of the face nearest the caster, so the Cube spreads away from the caster round `at` (its middle on the
## nearest intersection when it's an even number of squares across, on the middle of the square under `at` when odd),
## and its range counts to that face. Anything else (a wall at a point, a Tsunami) as before: the nearest
## intersection, with point_dir's direction.
static func aim(enc: Encounter, who: Combatant, a: Dictionary, at: Vector2, slot_: int = 0) -> Dictionary:
	var snapped := Vector2(roundf(at.x), roundf(at.y))
	var s := Compendium.shared().spell_data(str(a.get("spell_id", ""))) if str(a.get("spell_id", "")) != "" else {}
	var area := s.get("area", {}) as Dictionary
	match str(area.get("shape", "")):
		"emanation":
			return {"point": at, "dir": Vector2.ZERO}
		"cube":
			if who != null:
				var size := int(area.get("size", 5)) + int((s.get("upcast", {}) as Dictionary).get("area", 0)) * maxi(0, slot_ - int(s.get("level", 0)))
				var w := maxi(1, size / CombatGrid.FEET)
				var mid := snapped if w % 2 == 0 else Vector2(floorf(at.x) + 0.5, floorf(at.y) + 0.5)
				var to_caster := enc.center_of(who) - mid
				var toward := Vector2(signf(to_caster.x), 0.0) if absf(to_caster.x) >= absf(to_caster.y) else Vector2(0.0, signf(to_caster.y))
				if toward == Vector2.ZERO:
					toward = Vector2.LEFT
				return {"point": mid + toward * (w / 2.0), "dir": -toward}
	return {"point": snapped, "dir": point_dir(enc, who, a, snapped)}


## The way a wall placed at a point runs (a Tsunami's, aimed): across the line from its caster to the point, so it
## faces the caster and rolls away from it. Vector2.ZERO for any other spell.
static func point_dir(enc: Encounter, who: Combatant, a: Dictionary, point: Vector2) -> Vector2:
	if str(a.get("spell_id", "")) == "" or point == Vector2.INF:
		return Vector2.ZERO
	var s := Compendium.shared().spell_data(str(a.get("spell_id", "")))
	if str((s.get("area", {}) as Dictionary).get("shape", "")) != "wall":
		return Vector2.ZERO
	var d := point - enc.center_of(who)
	if d.length() < 0.1:
		return Vector2.ZERO
	var angle := snappedf(d.angle(), PI / 4.0) + PI / 2.0
	return Vector2(cos(angle), sin(angle))
