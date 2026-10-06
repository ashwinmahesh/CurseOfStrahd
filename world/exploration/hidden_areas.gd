class_name HiddenAreas
extends Node
## Rooms behind secret doors nobody has found yet stay out of sight (owner ask 2026-10-06, docs/ui/travel_map.md
## "Hidden areas"): their floor, walls, furniture, props, lights and people aren't drawn in the level view, the
## minimap leaves them dark and their ways out get no markers. When the door is found they fade in.
##
## A hidden area is every square that can't be reached from the location's spawns (or where the party stands)
## without going through an undiscovered secret door; ordinary doors count as open. Its walls are hidden too, except
## those that also face a square in sight (the wall the secret door is set in stays). The rules grid is never changed.

const FADE := 0.6
const CHECK_EVERY := 0.25

var view: LocationView
## The squares hidden now: cell -> true.
var hidden: Dictionary = {}
var _sig := ""
var _wait := 0.0
## What this hid, to fade back in when its square is in sight: node -> its cell.
var _put_away: Dictionary = {}


static func create(v: LocationView) -> HiddenAreas:
	var h := HiddenAreas.new()
	h.name = "HiddenAreas"
	h.view = v
	return h


func _ready() -> void:
	_sig = signature(view)
	hidden = hidden_cells(view)
	_hide_nodes()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_EVERY
	var sig := signature(view)
	if sig == _sig:
		# The view rebuilds its props and containers after a conversation or a fight (refresh_npcs), freeing the
		# ones this put away: hide their replacements too.
		if _forget_freed():
			_hide_nodes()
		return
	_sig = sig
	hidden = hidden_cells(view)
	_forget_freed()
	_reveal_shown()
	_hide_nodes()


## Drops pieces that were freed while put away. True if there were any.
func _forget_freed() -> bool:
	var gone := false
	for n: Variant in _put_away.keys():
		if not is_instance_valid(n):
			_put_away.erase(n)
			gone = true
	return gone


func is_hidden(cell: Vector2i) -> bool:
	return hidden.has(cell)


## The location's HiddenAreas, or null.
static func of(v: LocationView) -> HiddenAreas:
	return v.get_node_or_null("HiddenAreas") as HiddenAreas if v != null and is_instance_valid(v) else null


## Is a square hidden in this location now (false when nothing is)?
static func hides(v: LocationView, cell: Vector2i) -> bool:
	var h := of(v)
	return h != null and h.is_hidden(cell)


## Which secret doors have been found here (it changes when the party finds one).
static func signature(v: LocationView) -> String:
	var found := v.st.loc_state(v.loc_id)["found"] as Dictionary
	var ids: Array[String] = []
	for d: Variant in v.loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) > 0 and bool(found.get(str(door["id"]), false)):
			ids.append(str(door["id"]))
	return ",".join(ids)


## The squares of a location hidden behind undiscovered secret doors: cell -> true (empty when there are none).
static func hidden_cells(v: LocationView) -> Dictionary:
	var out := {}
	var found := v.st.loc_state(v.loc_id)["found"] as Dictionary
	var shut := {}
	for d: Variant in v.loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) > 0 and not bool(found.get(str(door["id"]), false)):
			var a := door["cell"] as Array
			shut[Vector2i(int(a[0]), int(a[1]))] = true
	if shut.is_empty():
		return out
	# The map as authored: closed ordinary doors are open ground here, only the secret ones block.
	var grid := CombatGrid.from_rows(v.loc["map"]["rows"] as Array)
	var open := func(c: Vector2i) -> bool:
		return grid.in_bounds(c) and not shut.has(c) and not grid.has_flag(c, CombatGrid.WALL) \
			and (not grid.has_flag(c, CombatGrid.VOID) or grid.has_flag(c, CombatGrid.WATER))
	var seen := {}
	var todo: Array[Vector2i] = []
	for s: Variant in (v.loc.get("spawns", {}) as Dictionary).values():
		var a := s as Array
		todo.append(Vector2i(int(a[0]), int(a[1])))
	for m in v.members:
		todo.append(m.cell)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if seen.has(c) or not open.call(c):
			continue
		seen[c] = true
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(c + dir)
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			if seen.has(c) or shut.has(c):
				continue
			if grid.has_flag(c, CombatGrid.VOID) and not grid.has_flag(c, CombatGrid.WATER):
				continue
			if grid.has_flag(c, CombatGrid.WALL) and CombatGrid.DIRS.any(func(d: Vector2i) -> bool: return seen.has(c + d)):
				continue   # a wall that also faces a square in sight
			out[c] = true
	return out


## Everything that can stand on a square, with its square: the location's own doors, props, containers and people
## (by their cell in the data, since a piece may be hung on a neighbouring wall), then the board's per-square pieces
## and the rest of the view's (lights, flames) by where they stand. [[node, cell], ...]
func _candidates() -> Array[Array]:
	var out: Array[Array] = []
	var taken := {}
	var by_id := {}
	for key: String in ["doors", "props", "containers"]:
		for e: Variant in view.loc.get(key, []):
			var a := (e as Dictionary)["cell"] as Array
			by_id[key + ":" + str((e as Dictionary)["id"])] = Vector2i(int(a[0]), int(a[1]))
	for pair: Array in [["doors", view.door_nodes], ["props", view.prop_nodes], ["containers", view.container_nodes]]:
		var nodes := pair[1] as Dictionary
		for id: Variant in nodes:
			var key := "%s:%s" % [pair[0], str(id).get_slice("#", 0)]
			var n := nodes[id] as Node3D
			if n != null and is_instance_valid(n) and by_id.has(key):
				out.append([n, by_id[key]])
				taken[n] = true
	for shown: Variant in view.get("_npc_shown") as Array:
		var tok := (shown as Dictionary)["token"] as Node3D
		if tok != null and is_instance_valid(tok):
			out.append([tok, (shown as Dictionary)["cell"]])
			taken[tok] = true
	var skip := {view.board: true, view.rig: true}
	for t: Variant in view.tokens.values():
		skip[t] = true
	var loose: Array[Node] = []
	if view.board != null:
		loose.append_array(view.board.get_children())
	loose.append_array(view.get_children())
	for n in loose:
		if not (n is Node3D) or skip.has(n) or taken.has(n) or n is DirectionalLight3D or n is Camera3D:
			continue
		for piece in _pieces(n as Node3D):
			out.append([piece, _cell_of(piece)])
	return out


## A holder left at the origin stands for its children (a dressing root, a group of pieces).
func _pieces(n: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if n.position == Vector3.ZERO and not (n is VisualInstance3D) and n.get_child_count() > 0:
		for c in n.get_children():
			if c is Node3D:
				out.append_array(_pieces(c as Node3D))
		return out
	out.append(n)
	return out


func _cell_of(n: Node3D) -> Vector2i:
	var p := n.global_position
	return Vector2i(floori(p.x), floori(p.z))


## A big piece (a ground slab under the whole map) isn't anybody's square.
static func _local(n: Node3D) -> bool:
	if n is VisualInstance3D:
		var ab := (n as VisualInstance3D).get_aabb()
		var s := n.global_basis.get_scale()
		return maxf(ab.size.x * s.x, ab.size.z * s.z) <= 3.0
	return true


func _hide_nodes() -> void:
	if hidden.is_empty():
		return
	for pair in _candidates():
		var n := pair[0] as Node3D
		if n.visible and not _put_away.has(n) and hidden.has(pair[1]) and _local(n):
			_put_away[n] = pair[1]
			n.visible = false


## Fades in what stood on squares that aren't hidden any more.
func _reveal_shown() -> void:
	for n: Variant in _put_away.keys():
		var node := n as Node3D
		if not is_instance_valid(node):
			_put_away.erase(n)
			continue
		if hidden.has(_put_away[n]):
			continue
		_put_away.erase(n)
		node.visible = true
		_fade_in(node)


func _fade_in(n: Node3D) -> void:
	var tw := create_tween().set_parallel(true)
	if n is CandleFlicker:
		var e := (n as CandleFlicker).base_energy
		(n as CandleFlicker).base_energy = 0.0
		tw.tween_property(n, "base_energy", e, FADE)
		return
	if n is Light3D:
		var le := (n as Light3D).light_energy
		(n as Light3D).light_energy = 0.0
		tw.tween_property(n, "light_energy", le, FADE)
		return
	var parts: Array[Node] = [n]
	parts.append_array(n.find_children("*", "GeometryInstance3D", true, false))
	var any := false
	for p in parts:
		if p is GeometryInstance3D:
			var g := p as GeometryInstance3D
			var was := g.transparency
			g.transparency = 1.0
			tw.tween_property(g, "transparency", was, FADE)
			any = true
	if not any:
		tw.kill()
