class_name LocationLead
extends Node
## The party follows someone across the map (the dialogue statement `lead <npc> to <where>`, docs/contracts/dialogue.md):
## the person's figure walks to the spot, and the party's figures follow it in marching order a couple of squares
## behind, with the same smooth walk the rest of exploring uses (PartyGlide). A lead is a scene, not a stroll: nothing
## is set off on the way (no traps, areas or watchers), and the walk can be skipped at any moment (a click, Enter,
## Space or Esc), which puts everyone where the walk was going. The game root asks first when the spot is in another
## place (LeadPrompt), walks to the way out, and changes place; this node only does the walking on one map.

## `followed` is true when the party was taken to the spot (also when the walk was skipped), false when something
## stopped it (a fight began).
signal finished(followed: bool)

## Squares the party keeps behind the one it follows.
const GAP := 2
## Seconds a square takes the one leading: a purposeful walk, just slower than the party's own (LocationView.STEP_TIME),
## so the party keeps up and never has to wait for long.
const NPC_STEP := 0.34 / WalkPace.FASTER
## A walk longer than this many seconds is finished at once.
const LIMIT := 75.0

var view: LocationView
var npc_id := ""
var stand := Vector2i(-1, -1)
var _tok: CombatToken
var _shown: Dictionary = {}               ## the person's _npc_shown entry, when they are one of the place's people
var _path: Array[Vector2i] = []           ## from where they stand to the spot
var _at := 0                              ## where along _path they are
var _trail: Array[Vector2i] = []          ## squares the party's leader still has to step through
var _npc_wait := 0.0
var _leader_wait := 0.0
var _clock := 0.0
var _glide: PartyGlide = null
var _done := false
var _solo_was := false


# --- Planning: where `to` is -------------------------------------------------------------------------------------

## What a lead's `to` names, seen from `view`: {kind: "here", cell, exact} for a spot on this map (a door, prop,
## container, exit or area id, or "x,y"), {kind: "there", where, spawn, exit, name} for another place (a location id,
## "id" or "id:spawn"; `exit` is this map's way out to it, {} when it has none), or {kind: "none"}.
static func plan(view: LocationView, to: String) -> Dictionary:
	var place := to.get_slice(":", 0)
	if place != view.loc_id and Compendium.shared().has("locations", place):
		var ex := exit_to(view, place)
		var spawn := to.get_slice(":", 1) if to.contains(":") else ""
		return {"kind": "there", "where": place, "spawn": spawn if spawn != "" else str(ex.get("spawn", "default")), "exit": ex,
			"name": str(Compendium.shared().get_entry("locations", place).get("name", place))}
	if to.contains(","):
		var xy := to.split(",")
		if xy.size() == 2 and xy[0].is_valid_int() and xy[1].is_valid_int():
			return {"kind": "here", "cell": Vector2i(int(xy[0]), int(xy[1])), "exact": true}
		return {"kind": "none"}
	for list: String in ["doors", "props", "containers", "exits"]:
		for t: Variant in view.loc.get(list, []):
			var spec := t as Dictionary
			if str(spec.get("id", "")) == to and spec.has("cell"):
				return {"kind": "here", "cell": LocationView._cell(spec["cell"]), "exact": false}
	for a: Variant in view.loc.get("areas", []):
		var area := a as Dictionary
		if str(area.get("id", "")) == to:
			var c0 := LocationView._cell((area["cells"] as Array)[0])
			var c1 := LocationView._cell((area["cells"] as Array)[1])
			return {"kind": "here", "cell": Vector2i((c0.x + c1.x) / 2, (c0.y + c1.y) / 2), "exact": true}
	return {"kind": "none"}


## This map's exit that leads to location `place` and can be used now, or {}.
static func exit_to(view: LocationView, place: String) -> Dictionary:
	for ex: Variant in view.loc.get("exits", []):
		var spec := ex as Dictionary
		if str(spec.get("to", "")) == place and StoryConditions.check(str(spec.get("when", "")), view.st):
			return spec
	return {}


## Where the one leading stops for a spot: the spot itself when it is `exact` (a cell, an area) and free, else the nearest
## free square beside it by the walk from `from`. (-1, -1) when there is none.
static func stand_for(view: LocationView, from: Vector2i, spot: Vector2i, exact: bool) -> Vector2i:
	var taken := {}
	for m: Combatant in view.members + view.guest_members:
		taken[m.cell] = true
	for shown in view._npc_shown:
		taken[shown["cell"] as Vector2i] = true
	var cands: Array[Vector2i] = []
	if exact:
		cands.append(spot)
	for d in CombatGrid.DIRS:
		cands.append(spot + d)
	var best := Vector2i(-1, -1)
	var best_len := 1 << 30
	for c in cands:
		if not view.grid.in_bounds(c) or view.grid.is_solid(c):
			continue
		if c == from:
			return c
		if taken.has(c):
			continue
		var p := LocationWalk._path(view, from, c)
		if p.is_empty():
			continue
		if exact and c == spot:
			return c   # the square asked for, when it can be walked to
		if p.size() < best_len:
			best_len = p.size()
			best = c
	return best


## The figure that leads, as {token, shown, cell}: a person of the place, or a staged one, or (when they aren't on the map)
## one brought on beside the party. {} if there is no such npc to draw.
static func figure(view: LocationView, npc_id_: String) -> Dictionary:
	for shown in view._npc_shown:
		if str((shown["spec"] as Dictionary)["npc"]) == npc_id_ and is_instance_valid(shown["token"]):
			return {"token": shown["token"], "shown": shown, "cell": shown["cell"] as Vector2i}
	if not view._staged.has(npc_id_):
		view.stage_npc(npc_id_, "")
	var tok: Variant = view._staged.get(npc_id_)
	if tok is CombatToken and is_instance_valid(tok):
		return {"token": tok, "shown": {}, "cell": view.grid.cell_at((tok as Node3D).position)}
	return {}


# --- The walk ----------------------------------------------------------------------------------------------------

## Starts the walk: `npc_id_` leads the party to `stand_` on this map. Returns the node (it frees itself once it has
## emitted `finished`), or null when there is nobody to follow.
static func begin(view: LocationView, npc_id_: String, stand_: Vector2i) -> LocationLead:
	var fig := figure(view, npc_id_)
	if fig.is_empty() or view.members.is_empty() or stand_.x < 0:
		return null
	var lead := LocationLead.new()
	lead.name = "LocationLead"
	lead.view = view
	lead.npc_id = npc_id_
	lead.stand = stand_
	lead._tok = fig["token"] as CombatToken
	lead._shown = fig["shown"] as Dictionary
	view.add_child(lead)
	lead._start(fig["cell"] as Vector2i)
	return lead


func _start(from: Vector2i) -> void:
	view.busy = true
	_solo_was = view.solo
	view.solo = false   # the whole party follows, even split
	if not _shown.is_empty():
		_shown["route"] = []   # a lead takes them off their round
	if _tok.resting:
		_tok.get_up()   # someone lying there (Lupu on the step by day) gets up first
		_npc_wait = 0.7
	_make_hint()
	_path = LocationWalk._path(view, from, stand) if from != stand else ([from] as Array[Vector2i])
	var lead_cell := view.leader().cell
	if lead_cell != from:
		_trail = LocationWalk._path(view, lead_cell, from).slice(1)
	if _path.is_empty() or (lead_cell != from and _trail.is_empty()):
		_path = [from, stand]   # no way through: everyone simply arrives
		_skip.call_deferred()
		return
	_at = 0


## "Following Ismark. Click or Esc: skip" at the foot of the screen while the walk lasts.
func _make_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var who := str(Compendium.shared().get_entry("npcs", npc_id).get("name", npc_id))
	var l := UiKit.label("", 15, "parchment")
	PadGlyphs.hint(l, "Following %s. Click or Esc: skip" % who, "Following %s. {a}: skip" % who)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_bottom = -26
	layer.add_child(l)


func _process(delta: float) -> void:
	if _done:
		return
	if view.in_combat or view.members.is_empty() or not is_instance_valid(_tok):
		_end(false)
		return
	_clock += delta
	if _clock > LIMIT:
		_skip()
		return
	if _glide != null and _glide.update(delta):
		_glide = null
	_npc_wait -= delta
	_leader_wait -= delta
	var arrived := _at >= _path.size() - 1
	# The one leading goes on when the party is close behind.
	if not arrived and _npc_wait <= 0.0 and _trail.size() <= GAP + 1:
		_step_npc()
		arrived = _at >= _path.size() - 1
	# The party's leader follows the trail, keeping GAP squares back.
	if _leader_wait <= 0.0 and _trail.size() > GAP:
		_step_leader()
	if arrived and _trail.size() <= GAP and _glide == null and view._glides.is_empty():
		_end(true)


func _step_npc() -> void:
	var from := _path[_at]
	_at += 1
	var next := _path[_at]
	_open_door(next)
	_tok.combatant.cell = next
	if not _shown.is_empty():
		_shown["low_before"] = view.grid.has_flag(next, CombatGrid.LOW)
		_shown["cell"] = next
	if _glide == null:
		_glide = PartyGlide.new(_tok)
	_glide.step_time = NPC_STEP
	_glide.points.append(view.board.cell_center(next))
	_npc_wait = NPC_STEP * (sqrt(2.0) if absi(next.x - from.x) + absi(next.y - from.y) == 2 else 1.0)
	_trail.append(next)


func _step_leader() -> void:
	var next: Vector2i = _trail.pop_front()
	_open_door(next)
	var here := view.leader().cell
	_leader_wait = LocationView.STEP_TIME * (sqrt(2.0) if absi(next.x - here.x) + absi(next.y - here.y) == 2 else 1.0)
	LocationWalk._advance_party(view, next)


## A closed door that opens at a touch opens as someone reaches it.
func _open_door(c: Vector2i) -> void:
	if not view.grid.has_flag(c, CombatGrid.WALL):
		return
	var door := LocationLocks._openable_doors(view).get(c, {}) as Dictionary
	if not door.is_empty():
		LocationLocks._use_door(view, door)


## Everyone to where the walk was going, at once: the one leading at the spot, the party gathered behind them.
func _skip() -> void:
	if _done:
		return
	for c in _path:
		_open_door(c)
	var spot := _path[_path.size() - 1]
	_at = _path.size() - 1
	_glide = null
	_tok.combatant.cell = spot
	_tok.position = view.board.cell_center(spot)
	if not _shown.is_empty():
		_shown["low_before"] = view.grid.has_flag(spot, CombatGrid.LOW)
		_shown["cell"] = spot
	var anchor := _path[maxi(0, _path.size() - 1 - GAP)]
	var cells := LocationParty._cells_around(view, anchor, view.members.size())
	view._glides.clear()
	for i in view.members.size():
		var m := view.members[i]
		m.cell = cells[i]
		var tok := view.tokens.get(m.id) as CombatToken
		if tok != null:
			tok.position = view.board.cell_center(cells[i])
			tok.face(Vector2.ZERO, false)
	LocationParty.place_guests(view)
	_trail.clear()
	_end(true)


func _end(followed: bool) -> void:
	if _done:
		return
	_done = true
	view.busy = false
	view.solo = _solo_was
	if followed and is_instance_valid(_tok) and not view.members.is_empty():
		var spot := _tok.combatant.cell
		_tok.face(Vector2(view.leader().cell - spot), false)
		var lead_tok := view.tokens.get(view.leader().id) as CombatToken
		if lead_tok != null:
			lead_tok.face(Vector2(spot - view.leader().cell), false)
	view._save_positions()
	finished.emit(followed)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var k := event as InputEventKey
	var m := event as InputEventMouseButton
	if event.is_action_pressed(&"combat_cancel") or event.is_action_pressed(&"combat_confirm") \
			or (k != null and k.pressed and not k.echo and k.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
			or (m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_skip()
