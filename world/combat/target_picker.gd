class_name TargetPicker
extends RefCounted
## The combat view's picks beyond the first click (docs/ui/combat_view.md, docs/contracts/combat.md): a wall drawn
## square by square and the side a drawn Wall of Fire burns on, the creature Commander's Strike's ally attacks, the
## creature Crown of Madness's victim must attack (or no one), and the ally Maneuvering Attack lets move, with its
## square. It keeps what has been picked, says what the floor and the tooltip show, and builds the command; the engine
## checks every pick (SpellTargeting, SpellPlacement, EncounterWeapons, EncounterMovement).

## What is being picked: "" (nothing), "wall" (the wall's squares), "side" (the side a drawn Wall of Fire burns on),
## "strike" (the creature Commander's Strike's ally attacks), "victim" (the creature the crowned one must attack),
## "mover" (the ally Maneuvering Attack moves) or "square" (where that ally goes).
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


## The player backed out: a move Maneuvering Attack offered is passed on.
func cancel() -> void:
	if step in ["mover", "square"]:
		e.movement.decline_reaction_move()
	reset()


# --- Starting -------------------------------------------------------------------------------------

## Whether `a` (aimed with nothing on the hotbar) still takes a pick here: Crown of Madness's keep-control action picks
## the creature the crowned one must attack.
func takes(who: Combatant, a: Dictionary) -> bool:
	return not _crowned_by(who, a).is_empty()


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
	return a


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
	return false


# --- What the floor and the tooltip show ----------------------------------------------------------

## The marks and the tooltip for pointing at `cell` (`who` there): {area, trail, target, friendly, goal, danger: cells,
## title, lines, warnings}.
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
