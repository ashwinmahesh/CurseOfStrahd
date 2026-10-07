class_name NpcRoutes
extends Node
## People who walk a route (owner, 2026-10-07: "NPCs should move around the map, maybe on a predetermined path so the
## world looks more alive"). A location NPC entry with `path` walks from its `cell` through each waypoint and back,
## a square at a time with the party's smooth walk (PartyGlide), standing a few seconds at each waypoint (`pause`, or
## a waypoint's third number). It holds its ground while anyone talks or fights, while the leader stands beside it,
## and while its next square is taken; a sleeper never walks. Under turn-based exploring (F7) it walks only when a
## round ends, at most its Speed. LocationNpcs builds each route; this node, one per LocationView, moves them.

## Seconds a square takes: a stroll, slower than the party's walk.
const STEP_TIME := 0.7
## Seconds at a waypoint when the entry gives no `pause`.
const PAUSE := 3.0
## Squares a walker covers in one turn-based round (30 ft).
const ROUND_SQUARES := 6

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
	stops.append([start.x, start.y])
	var from := start
	var no := func(_c: Vector2i) -> bool: return false
	for s: Variant in stops:
		var stop := s as Array
		var to := Vector2i(int(stop[0]), int(stop[1]))
		var leg := CombatGrid.path_to(v.grid.reachable(from, 1, 4000, no, no, no), to)
		if leg.is_empty() and to != from:
			return [] as Array[Dictionary]
		var wait := float(stop[2]) if stop.size() > 2 else float(spec.get("pause", PAUSE))
		for i in range(1, leg.size()):
			out.append({"cell": leg[i], "pause": wait if i == leg.size() - 1 else 0.0})
		from = to
	return out


func _process(delta: float) -> void:
	for tok: CombatToken in _glides.keys():
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


func _walk(shown: Dictionary, delta: float) -> void:
	var tok := shown["token"] as CombatToken
	if not is_instance_valid(tok) or not tok.visible:
		return
	if tok.combatant.creature.has_condition(&"unconscious") or tok.combatant.creature.has_condition(&"prone"):
		return
	shown["wait"] = float(shown.get("wait", 0.0)) - delta
	if float(shown["wait"]) > 0.0:
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
	shown["wait"] = STEP_TIME * (sqrt(2.0) if absi(next.x - here.x) + absi(next.y - here.y) == 2 else 1.0) + float((route[at] as Dictionary)["pause"])
	if view.planning:
		shown["round_left"] = int(shown.get("round_left", 0)) - 1
	LocationNpcs._check_approach(view)   # walking up to the party counts as coming near


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
