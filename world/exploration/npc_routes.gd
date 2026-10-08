class_name NpcRoutes
extends Node
## People who walk a route (owner, 2026-10-07: "NPCs should move around the map, maybe on a predetermined path so the
## world looks more alive"). A location NPC entry with `path` walks from its `cell` through each waypoint and back,
## a square at a time with the party's smooth walk (PartyGlide), standing a few seconds at each waypoint (`pause`, or
## a waypoint's third number). It holds its ground while anyone talks or fights, while the leader stands beside it,
## and while its next square is taken; a sleeper never walks. Under turn-based exploring (F7) it walks only when a
## round ends, at most its Speed. LocationNpcs builds each route; this node, one per LocationView, moves them.
## People at work (lane 28, owner request 2026-10-08: "more people walking around and doing things"): a waypoint may be
## {"at": [x, y], "wait": seconds, "face": "east", "work": "swing" or "gesture"}, and an entry its own `work`: standing
## there (a stop of the route, or the place a person keeps), they face their work and swing at it (an axe, a spade, a
## hammer: the figure's attack) or gesture over it (a stall, a sermon: its spell gesture, else nothing) every few seconds.

## Seconds a square takes: a stroll, slower than the party's walk.
const STEP_TIME := 0.7
## Seconds at a waypoint when the entry gives no `pause`.
const PAUSE := 3.0
## Squares a walker covers in one turn-based round (30 ft).
const ROUND_SQUARES := 6
## Seconds between one swing or gesture at a person's work and the next.
const WORK_BEAT := 2.4

var view: LocationView
var _glides: Dictionary = {}   ## token -> PartyGlide
var _round_seen := 0


static func of(v: LocationView) -> NpcRoutes:
	for c in v.get_children():
		if c is NpcRoutes:
			return c as NpcRoutes
	var r := NpcRoutes.new()
	r.name = "NpcRoutes"
	r.view = v
	v.add_child(r)
	return r


## The squares an entry walks, in order, from its cell round to its cell again: [{cell, pause}], the pause on the
## square that ends each leg. [] when it has no path, or a leg can't be walked (a wall, a closed door).
static func route_for(v: LocationView, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stops: Array = (spec.get("path", []) as Array).duplicate()
	if stops.is_empty() or bool(spec.get("asleep", false)):
		return out
	var start := LocationView._cell(spec["cell"])
	# Home again at the end: the entry's own facing and work.
	stops.append({"at": [start.x, start.y], "face": str(spec.get("facing", "")), "work": str(spec.get("work", ""))})
	var from := start
	for s: Variant in stops:
		var stop := _stop(s, spec)
		var to := stop["cell"] as Vector2i
		var leg := leg_path(v.grid, from, to)
		if leg.is_empty() and to != from:
			return [] as Array[Dictionary]
		for i in range(1, leg.size()):
			var e := {"cell": leg[i], "pause": float(stop["wait"]) if i == leg.size() - 1 else 0.0}
			if i == leg.size() - 1:
				e["face"] = stop["face"]
				e["work"] = stop["work"]
			out.append(e)
		from = to
	return out


## The farthest a leg's search goes, in feet of walking.
const LEG_FEET := 4000

## Legs searched this session, by the grid they were searched on and their ends: a place's people walk the same legs
## on every visit, and searching a town's took most of a second (the loading lane).
static var _legs: Dictionary = {}


## The squares of the shortest walk from `from` to `to`, both ends included; [] when there's none within LEG_FEET.
## Searching the whole map for every leg took 0.85 s of building Vallaki (the loading lane), so a leg is searched once
## per session for the grid as it stands (its squares and heights; an opened door makes another grid), and the search
## starts with a budget a little over the straight distance, doubling it until `to` is in reach. The path is the one a
## whole-map search finds, since a smaller budget only leaves out squares that cost more than it.
static func leg_path(grid: CombatGrid, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var key := "%d|%s|%s" % [hash([grid.width, grid.depth, grid._flags, grid._height]), from, to]
	if _legs.has(key):
		return (_legs[key] as Array[Vector2i]).duplicate()
	var no := func(_c: Vector2i) -> bool: return false
	var budget := (maxi(absi(to.x - from.x), absi(to.y - from.y)) + 4) * CombatGrid.FEET * 2
	var path: Array[Vector2i] = []
	while true:
		budget = mini(budget, LEG_FEET)
		var reach := grid.reachable(from, 1, budget, no, no, no)
		if reach.has(to) or budget >= LEG_FEET:
			path = CombatGrid.path_to(reach, to)
			break
		budget *= 2
	_legs[key] = path
	return path.duplicate()


## A waypoint as {cell, wait, face, work}, from [x, y], [x, y, seconds] or {"at", "wait", "face", "work"}.
static func _stop(s: Variant, spec: Dictionary) -> Dictionary:
	if s is Dictionary:
		var d := s as Dictionary
		return {"cell": LocationView._cell(d["at"]), "wait": float(d.get("wait", spec.get("pause", PAUSE))),
			"face": str(d.get("face", "")), "work": str(d.get("work", ""))}
	var a := s as Array
	return {"cell": Vector2i(int(a[0]), int(a[1])), "wait": float(a[2]) if a.size() > 2 else float(spec.get("pause", PAUSE)),
		"face": "", "work": ""}


func _process(delta: float) -> void:
	for tok: Variant in _glides.keys():   # untyped: a person's figure may be gone (the people were rebuilt)
		if not is_instance_valid(tok) or (_glides[tok] as PartyGlide).update(delta):
			_glides.erase(tok)
	if view == null or view.in_combat or view.members.is_empty() or ModeController.mode != ModeController.Mode.EXPLORATION:
		return
	if view.planning and view.plan_round != _round_seen:
		_round_seen = view.plan_round
		for shown in view._npc_shown:
			shown["round_left"] = ROUND_SQUARES
	for shown in view._npc_shown:
		if not (shown.get("route", []) as Array).is_empty():
			_walk(shown, delta)
		elif str((shown["spec"] as Dictionary).get("work", "")) != "":
			# Someone who keeps one place and works there: the woodcutter at his block.
			shown["face"] = str((shown["spec"] as Dictionary).get("facing", ""))
			shown["work"] = str((shown["spec"] as Dictionary)["work"])
			_work(shown, delta)


func _walk(shown: Dictionary, delta: float) -> void:
	var tok := shown["token"] as CombatToken
	if not is_instance_valid(tok) or not tok.visible:
		return
	var cr := tok.combatant.creature
	if cr.has_condition(&"incapacitated") or cr.has_condition(&"prone") or cr.has_condition(&"restrained"):
		return   # asleep, held, laughing on the ground: they go nowhere
	shown["wait"] = float(shown.get("wait", 0.0)) - delta
	if float(shown["wait"]) > 0.0:
		_work(shown, delta)
		return
	if view.planning and int(shown.get("round_left", 0)) <= 0:
		return
	var here := shown["cell"] as Vector2i
	var lead := view.leader().cell
	if maxi(absi(lead.x - here.x), absi(lead.y - here.y)) <= 1:
		if not _glides.has(tok):
			tok.face(Vector2(lead - here), false)   # someone comes up to them: they stop and look
		return
	var route := shown["route"] as Array
	var at := int(shown.get("at", 0))
	var next := (route[at] as Dictionary)["cell"] as Vector2i
	if _taken(next, shown):
		return
	_step(shown, next)
	shown["at"] = (at + 1) % route.size()
	shown["face"] = str((route[at] as Dictionary).get("face", ""))
	shown["work"] = str((route[at] as Dictionary).get("work", ""))
	shown["work_t"] = STEP_TIME + 0.4
	shown["wait"] = STEP_TIME * (sqrt(2.0) if absi(next.x - here.x) + absi(next.y - here.y) == 2 else 1.0) + float((route[at] as Dictionary)["pause"])
	if view.planning:
		shown["round_left"] = int(shown.get("round_left", 0)) - 1
	LocationNpcs._check_approach(view)   # walking up to the party counts as coming near


## A person standing at their work: once they've arrived, they turn to it and swing or gesture every WORK_BEAT
## seconds, unless the party's leader is beside them (they look up and talk instead).
func _work(shown: Dictionary, delta: float) -> void:
	var face := str(shown.get("face", ""))
	var work := str(shown.get("work", ""))
	if face == "" and work == "":
		return
	var tok := shown["token"] as CombatToken
	if not is_instance_valid(tok) or not tok.visible or _glides.has(tok):
		return
	var here := shown["cell"] as Vector2i
	var lead := view.leader().cell
	if maxi(absi(lead.x - here.x), absi(lead.y - here.y)) <= 1:
		return
	shown["work_t"] = float(shown.get("work_t", 0.0)) - delta
	if float(shown["work_t"]) > 0.0:
		return
	shown["work_t"] = WORK_BEAT
	var dir := SetDressing.FACINGS.get(face, Vector2.ZERO) as Vector2
	if dir == Vector2.ZERO:
		dir = Vector2(tok.sprite.facing.x, tok.sprite.facing.z)
	match work:
		"swing":
			tok.start_attack(dir)
		"gesture":
			if not tok.start_cast(dir):
				tok.face(dir, false)
		_:
			tok.face(dir, false)


## Whether a square is someone's: the party's, a guest's, another person's, a foe's in plain view, on the party's way
## (the next few squares of its walk), behind a door now shut, or in a room nobody has found.
func _taken(c: Vector2i, me: Dictionary) -> bool:
	if view.grid.is_solid(c) or HiddenAreas.hides(view, c):
		return true
	for m: Combatant in view.members + view.guest_members:
		if m.cell == c:
			return true
	for i in mini(3, view._queue.size()):
		if view._queue[i] == c:
			return true
	for shown in view._npc_shown:
		if shown != me and shown["cell"] == c:
			return true
	for w in view.waiting:
		if (w["foe"] as Combatant).cell == c:
			return true
	for tok: Variant in view._staged.values():
		if view.grid.cell_at((tok as Node3D).position) == c:
			return true
	return false


## One square on: the person's square (and the low block that keeps the party off it) moves with them.
func _step(shown: Dictionary, next: Vector2i) -> void:
	var was := shown["cell"] as Vector2i
	if not bool(shown["low_before"]):
		view.grid.set_flag(was, CombatGrid.LOW, false)
	shown["low_before"] = view.grid.has_flag(next, CombatGrid.LOW)
	view.grid.set_flag(next, CombatGrid.LOW, true)
	shown["cell"] = next
	var tok := shown["token"] as CombatToken
	tok.combatant.cell = next
	var g := _glides.get(tok, null) as PartyGlide
	if g == null:
		g = PartyGlide.new(tok)
		_glides[tok] = g
	g.step_time = STEP_TIME
	g.points.append(view.board.cell_center(next))
