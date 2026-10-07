class_name LocationPlan
extends RefCounted
## Turn-based exploring (F7, "Plan before the fight", as in Baldur's Gate 3; docs/rules/stealth.md): outside fights the
## player can switch the party into rounds of six seconds at any time (T, the hotbar's Turn-based button, or the
## Settings page; GameSettings keeps the choice). The player moves one party member at a time, each up to their Speed a
## round, and ends the round (Space) to give everyone their movement again. Passing through a companion's square costs
## double and nobody stops on one (2024). Foes waiting in plain view stay where they are; the party can open the fight
## on them from wherever it was placed, with Surprise if it sneaked up (LocationStealth).

const ROUND_SECONDS := 6


## Whether exploring is turn-based now (the player's choice, kept in GameSettings).
static func wanted() -> bool:
	return GameSettings.turn_based()


## Switches turn-based exploring on or off (and keeps the choice). Never in a fight.
static func toggle(view: LocationView) -> void:
	if view.in_combat:
		return
	GameSettings.set_turn_based(not view.planning)
	if view.planning:
		stop(view)
		view.toast.emit("Real time")
	else:
		start(view)
		view.toast.emit("Turn-based: move each of the party in turn; Space ends the round")


## Starts the rounds: whoever is walking stops where they are, and each member gets their Speed for round 1.
static func start(view: LocationView) -> void:
	if view.planning or view.in_combat:
		return
	view.planning = true
	view._solo_before = view.solo
	view.solo = true
	view._queue.clear()
	view._on_arrive = Callable()
	view.plan_round = 1
	view._plan_seconds = 0
	_fresh_movement(view)


## After a fight: turn-based again if that's how the player explores.
static func resume(view: LocationView) -> void:
	if wanted():
		start(view)


## Back to real time (the party follows the leader again unless it was split before).
static func stop(view: LocationView) -> void:
	if not view.planning:
		return
	view.planning = false
	view.solo = view._solo_before
	view.plan_left.clear()
	preview(view, Vector2i(-1, -1))


## Ends the round once nobody is still walking: six seconds pass (a minute on the clock for every ten rounds) and
## everyone has their Speed again.
static func next_round(view: LocationView) -> void:
	if not view.planning or view.in_combat or not view._queue.is_empty():
		return
	view.plan_round += 1
	view._plan_seconds += ROUND_SECONDS
	if view._plan_seconds >= 60:
		view._plan_seconds -= 60
		view.st.advance_minutes(1)
	_fresh_movement(view)


static func _fresh_movement(view: LocationView) -> void:
	view.plan_left.clear()
	for m: Combatant in view.members + view.guest_members:
		view.plan_left[m.id] = m.speed() if m.creature.hp > 0 else 0


## Feet of movement `m` has left this round.
static func left_ft(view: LocationView, m: Combatant) -> int:
	return int(view.plan_left.get(m.id, 0))


## Squares where someone else stands (a companion, a guest, a foe in plain view): passable but not to stop on.
static func _others(view: LocationView, walker: Combatant) -> Dictionary:
	var out := {}
	for m: Combatant in view.members + view.guest_members:
		if m != walker and not m.creature.dead:
			out[m.cell] = true
	for w in view.waiting:
		if LocationStealth.is_shown(w):
			for c in (w["foe"] as Combatant).footprint():
				out[c] = true
	return out


## One step's cost in feet: the grid's (Difficult Terrain, climbing), doubled through someone else's square. Closed
## doors on the way open as the walker reaches them, so they cost a plain step.
static func step_ft(view: LocationView, walker: Combatant, from: Vector2i, to: Vector2i) -> int:
	var others := _others(view, walker)
	var cost := view.grid.step_cost(from, to, 1, func(_c: Vector2i) -> bool: return false,
		func(c: Vector2i) -> bool: return others.has(c))
	return cost if cost > 0 else CombatGrid.FEET * (2 if others.has(to) else 1)


## The cost in feet of walking `path` (its first square is where the walker stands).
static func path_ft(view: LocationView, walker: Combatant, path: Array[Vector2i]) -> int:
	var total := 0
	for i in range(1, path.size()):
		total += step_ft(view, walker, path[i - 1], path[i])
	return total


## Why the leader can't walk `path` this round ("" if they can).
static func why_not(view: LocationView, path: Array[Vector2i]) -> String:
	if not view.planning or path.size() < 2:
		return ""
	var walker := view.leader()
	if walker.creature.hp <= 0:
		return "%s is down" % walker.name()
	if _others(view, walker).has(path[path.size() - 1]):
		return "Someone is standing there"
	var need := path_ft(view, walker, path)
	var left := left_ft(view, walker)
	if need > left:
		return "Too far: %d ft, and %s has %d ft left this round (Space: next round)" % [need, walker.name().get_slice(" ", 0), left]
	return ""


## The leader just stepped from `from` to `to`: it comes off their movement.
static func spend(view: LocationView, from: Vector2i, to: Vector2i) -> void:
	if not view.planning:
		return
	var walker := view.leader()
	view.plan_left[walker.id] = maxi(0, left_ft(view, walker) - step_ft(view, walker, from, to))


## The hover hint for a square in turn-based mode: its cost against the leader's movement left, or "".
static func hover_text(view: LocationView, cell: Vector2i) -> String:
	if not view.planning or view.members.is_empty() or cell == view.leader().cell:
		return ""
	var path := view._path(view.leader().cell, cell)
	if path.is_empty():
		return ""
	var why := why_not(view, path)
	if why != "":
		return why
	return "Walk here: %d of %d ft" % [path_ft(view, view.leader(), path), left_ft(view, view.leader())]


## Shows the walk to the hovered square on the ground, as in fights: a dotted trail to a ring, red when it's beyond
## this round's movement. Off the floor (or out of turn-based mode) it clears.
static func preview(view: LocationView, cell: Vector2i) -> void:
	var overlay := view.get_node_or_null("PlanOverlay") as GridOverlay
	if not view.planning or cell.x < 0 or view.members.is_empty() or cell == view.leader().cell:
		if overlay != null:
			overlay.clear_all()
		return
	if overlay == null:
		overlay = GridOverlay.create(view.board)
		overlay.name = "PlanOverlay"
		view.add_child(overlay)
	overlay.clear_all()
	var path := view._path(view.leader().cell, cell)
	if path.is_empty():
		return
	overlay.show_trail("path", path)
	overlay.show_cells("danger" if why_not(view, path) != "" else "goal", [cell])
