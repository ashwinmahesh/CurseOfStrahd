class_name LocationWalk
extends RefCounted
## Walking in a location (LocationView): paths that open doors on the way and go round found traps, a square at a
## time with WASD, the marching order (each follower steps into the square ahead of it), and what each step sets off:
## traps, areas (narration, fights, banter), people who speak first, and the ways out.


## Walks the leader to `cell` (followers trail behind unless solo), then calls `then` on arrival.
static func walk_to(view: LocationView, cell: Vector2i, then: Callable = Callable()) -> bool:
	if view.busy or view.in_combat or view.members.is_empty():
		return false
	if PitFall.holds(view, view.leader()) and not PitFall.climb_out(view, view.leader().cell):
		return false   # the leader is at the bottom of a pit: the climb comes first
	var path := _path(view, view.leader().cell, cell)
	if path.is_empty():
		view.toast.emit("Can't get there")
		return false
	var too_far := LocationPlan.why_not(view, path)   # turn-based: this round's movement
	if too_far != "":
		view.toast.emit(too_far)
		return false
	view._queue = path.slice(1)
	view._on_arrive = then
	if view._queue.is_empty():
		if then.is_valid():
			then.call()
		elif _exit_at(view, cell):
			_check_cell_events(view)   # standing on a way out and clicking it again: go
	return true


static func _path(view: LocationView, from: Vector2i, to: Vector2i, around_traps: bool = true) -> Array[Vector2i]:
	var avoid := {}
	if around_traps:
		for t: Variant in view.loc.get("traps", []):
			var trap := t as Dictionary
			var tstate := str((view.st.loc_state(view.loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
			if tstate == "found" or PitFall.open_hole(trap, tstate):
				for c: Variant in trap["cells"]:
					avoid[LocationView._cell(c)] = true
	avoid.erase(to)
	# Closed doors that would open at a touch are part of the way: the party opens them as it reaches them.
	var doors := LocationLocks._openable_doors(view)
	# An exit set into a wall or a tent (a house's front door, Madam Eva's tent flap) is walked into like a door.
	var low_exit := view.grid.has_flag(to, CombatGrid.LOW) and _exit_at(view, to)
	if view.grid.has_flag(to, CombatGrid.WALL) and _exit_at(view, to):
		doors[to] = {}
	for c: Vector2i in doors:
		view.grid.set_flag(c, CombatGrid.WALL, false)
	if low_exit:
		view.grid.set_flag(to, CombatGrid.LOW, false)
	var reach := view.grid.reachable(from, 1, 2000, func(c: Vector2i) -> bool: return avoid.has(c),
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	for c: Vector2i in doors:
		view.grid.set_flag(c, CombatGrid.WALL, true)
	if low_exit:
		view.grid.set_flag(to, CombatGrid.LOW, true)
	var way := CombatGrid.path_to(reach, to)
	# A found trap that fills the only way (a corridor) is crossed rather than leaving the party stuck; stepping
	# on it springs it as usual unless it's disarmed first.
	if way.is_empty() and around_traps and not avoid.is_empty():
		return _path(view, from, to, false)
	return way


static func _exit_at(view: LocationView, cell: Vector2i) -> bool:
	for ex: Variant in view.loc.get("exits", []):
		if LocationView._cell((ex as Dictionary)["cell"]) == cell:
			return true
	return false


## One square in a direction (WASD).
static func step(view: LocationView, dir: Vector2i) -> void:
	if view.busy or view.in_combat or view.members.is_empty() or not view._queue.is_empty():
		return
	var to := view.leader().cell + dir
	if view.grid.step_cost(view.leader().cell, to, 1, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false) < 0:
		return
	var one: Array[Vector2i] = [view.leader().cell, to]
	var too_far := LocationPlan.why_not(view, one)
	if too_far != "":
		view.toast.emit(too_far)
		return
	view._queue = [to]


## Each frame outside a fight: the party moves on along the leader's path, a square every STEP_TIME (longer when
## sneaking or on a diagonal), opening doors in the way. A step that sets something off ends the walk; arriving calls
## the walk's `then`.
static func tick(view: LocationView, delta: float) -> void:
	if view.in_combat or view._queue.is_empty():
		return
	view._step_t -= delta
	if view._step_t > 0.0:
		return
	var next: Vector2i = view._queue.pop_front()
	# A diagonal step is longer, so it takes longer: the party keeps one steady pace.
	var diagonal := absi(next.x - view.leader().cell.x) + absi(next.y - view.leader().cell.y) == 2
	view._step_t = (LocationView.SNEAK_STEP_TIME if view.sneaking else LocationView.STEP_TIME) * (sqrt(2.0) if diagonal else 1.0)
	if view.grid.has_flag(next, CombatGrid.WALL) and not _exit_at(view, next):
		var door := LocationLocks._openable_doors(view).get(next, {}) as Dictionary
		if not door.is_empty():
			LocationLocks._use_door(view, door)
		if view.grid.has_flag(next, CombatGrid.WALL) or view.in_combat:
			view._queue.clear()
			view._on_arrive = Callable()
			return
	var was := view.leader().cell
	_advance_party(view, next)
	LocationPlan.spend(view, was, next)
	# Foes in plain view may notice the party (LocationStealth).
	if _check_cell_events(view) or LocationStealth.after_step(view):
		view._queue.clear()
		view._on_arrive = Callable()
		return
	if view._queue.is_empty():
		view._save_positions()
		if view._on_arrive.is_valid():
			var cb := view._on_arrive
			view._on_arrive = Callable()
			cb.call()




## The leader steps to `next`; each follower steps into the square the one ahead of it just left.
static func _advance_party(view: LocationView, next: Vector2i) -> void:
	var old: Array[Vector2i] = []
	for m in view.members:
		old.append(m.cell)
	_move_member(view, 0, next)
	if view.solo:
		return
	for i in range(1, view.members.size()):
		if view.members[i].creature.hp <= 0 or PitFall.holds(view, view.members[i]):
			continue
		if old[i - 1] != view.members[i].cell:
			_move_member(view, i, old[i - 1])
	# Guests walk at the back of the line.
	var ahead := old[old.size() - 1] if not old.is_empty() else next
	for g in view.guest_members:
		if g.creature.hp <= 0 or g.cell == ahead:
			continue
		var was := g.cell
		g.cell = ahead
		_glide(view, g.id, view.board.cell_center(ahead), view.members.size() + view.guest_members.find(g))
		ahead = was


static func _move_member(view: LocationView, i: int, to: Vector2i) -> void:
	var m := view.members[i]
	m.cell = to
	_glide(view, m.id, view.board.cell_center(to), i)


## Sends a party token on toward `to` (the square it just moved into). `place` in the line sets how long a follower
## waits before setting off from a standstill, so the line moves off one after another.
static func _glide(view: LocationView, id: String, to: Vector3, place: int) -> void:
	var tok := view.tokens.get(id) as CombatToken
	if tok == null:
		return
	var g := view._glides.get(id) as PartyGlide
	if g == null:
		g = PartyGlide.new(tok)
		g.wait = PartyGlide.FOLLOW_DELAY * place
		g.catch_up = 1.0 if place == 0 else 1.4
		view._glides[id] = g
	g.step_time = LocationView.SNEAK_STEP_TIME if view.sneaking else LocationView.STEP_TIME
	g.points.append(to)


static func _update_glides(view: LocationView, delta: float) -> void:
	if view.in_combat:
		view._glides.clear()   # the fight places everyone itself
		return
	for id: String in view._glides.keys():
		var g := view._glides[id] as PartyGlide
		if not is_instance_valid(g.token) or g.update(delta):
			view._glides.erase(id)


## Areas, traps and exits after a step. True if something stopped the walk.
static func _check_cell_events(view: LocationView) -> bool:
	if LocationTraps._check_traps(view):
		return true
	if _check_areas(view):
		return true
	if LocationNpcs._check_approach(view):
		return true
	for ex: Variant in view.loc.get("exits", []):
		var exit := ex as Dictionary
		if LocationView._cell(exit["cell"]) == view.leader().cell:
			if not StoryConditions.check(str(exit.get("when", "")), view.st):
				# A barred way only stops a walk that ends on it (passing over it, or standing there to use
				# something next to it, carries on).
				if view._queue.is_empty() and not view._on_arrive.is_valid():
					view.narration.emit(str(exit.get("locked_text", "The way is barred.")))
				return false
			view._save_positions()
			if str(exit["to"]) == "travel":
				view.travel_requested.emit()
				return true
			view.st.advance_minutes(5)   # walking between places takes a few minutes; rests take the hours
			view.exit_requested.emit(str(exit["to"]), str(exit.get("spawn", "default")))
			return true
	return false


static func _check_areas(view: LocationView) -> bool:
	if view.members.is_empty():
		return false
	var c := view.leader().cell
	for a: Variant in view.loc.get("areas", []):
		var area := a as Dictionary
		var id := str(area["id"])
		var inside := _in_area(area, c)
		if inside and not view._areas_in.has(id):
			view._areas_in[id] = true
			view.st.visited[id] = true
			view._say("enter:" + id)
			if view._trigger_encounter("enter_area:" + id):
				return true
			_maybe_banter(view)
		elif not inside:
			view._areas_in.erase(id)
	return false


static func _in_area(area: Dictionary, c: Vector2i) -> bool:
	var a := LocationView._cell((area["cells"] as Array)[0])
	var b := LocationView._cell((area["cells"] as Array)[1])
	return c.x >= mini(a.x, b.x) and c.x <= maxi(a.x, b.x) and c.y >= mini(a.y, b.y) and c.y <= maxi(a.y, b.y)


## Now and then (entering an area, at most every 10 game minutes) the party talks among themselves.
static func _maybe_banter(view: LocationView) -> void:
	if view.banter_player == null or view.st.total_minutes() - view._last_banter < 10:
		return
	var lines := view.banter_player.next(view.st, str(view.loc.get("region", "")))
	if not lines.is_empty():
		view._last_banter = view.st.total_minutes()
		view.banter.emit(lines)
