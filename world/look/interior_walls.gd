class_name InteriorWalls
extends RefCounted
## Interiors that sit in the world (Improvement Ideas W8, docs/art/building_kit.md): a room's walls stand a full storey
## high, and the walls between the camera and the rooms behind them drop to the old cut-away height, so the party is
## always in view and the far walls frame the room the way the look target frames do. Turning the camera turns which
## walls are down. Past the building's outer walls there is ground (a village street, a castle yard) instead of black,
## a storey or more below on an upper floor, with the outer walls running down to it.
##
## ArenaBoard hands every wall square of an interior or dungeon here (BuildingKit.interior_wall); the board's cut-away
## each frame reaches the walls through a building entry {"interior": true} (TownBuilder.cut_away). Nothing here
## changes the rules grid.

const CUT := ModelPiece.CUT_TOP
## How tall a room's walls stand, by interior style (BuildingKit.interior_style); a place can set its own.
const HEIGHTS := {"castle": 3.0, "church": 2.8, "amber": 3.0, "dungeon": 2.4, "manor": 2.5, "timber": 2.3, "tent": 2.4}
## A storey, for an upper floor's drop to the ground outside.
const STOREY := 2.5
## How far the outside ground reaches past the map.
const REACH := 10.0
## How far apart (squares) the points are that look past a wall, away from the camera, for floor behind it.
const BEYOND := 0.8
## Only floor this near the party (squares) brings a wall down: rooms further off keep their walls, so the view is the
## party's room and its neighbours, framed by standing walls.
const NEAR := 7.0


## Builds wall square `c` (wall material `wall_mat`, as ArenaBoard picked it): a pillar, a room wall (a full and a cut
## version), a solid block, or outside ground; a tent's canvas (TentWalls). False where W8 isn't on for this board
## (its walls stay as before).
static func build(board: ArenaBoard, c: Vector2i, wall_mat: Material) -> bool:
	var st := _state(board)
	if not st.is_empty() and (st["outside"] as Dictionary).has(c):
		_outside(board, c, st)
		return true
	if TentWalls.is_tent(board):
		return TentWalls.build(board, c, wall_mat, st)   # canvas, not walls (in Classic too, at the cut-away height)
	if st.is_empty():
		return false
	if _open_faces(board, c).is_empty():
		_block(board, c, wall_mat, st)
		return true
	_room_wall(board, c, wall_mat, st)
	return true


## This board's W8 settings, worked out once: {style, height, ground, below, outside (cells), walls, headers}; empty
## when off.
static func _state(board: ArenaBoard) -> Dictionary:
	if board.has_meta("interior_walls"):
		return board.get_meta("interior_walls") as Dictionary
	var st := {}
	var cfg := BuildingKit.settings().get("interiors", {}) as Dictionary
	var style := BuildingKit.interior_style(board)
	if bool(cfg.get("full_walls", false)) and style != "" and Look.modern():
		var place := _place_settings(board, cfg.get("outside", {}) as Dictionary)
		st = {"style": style, "height": float(place.get("height", HEIGHTS.get(style, 2.4))),
			"ground": str(place.get("ground", (cfg.get("ground", {}) as Dictionary).get(style, ""))),
			"below": float(place.get("below", 0.0)) * STOREY, "outside": _outside_cells(board), "walls": [],
			"headers": {}, "done_ground": false}
		var root := Node3D.new()
		root.name = "InteriorWalls"
		board.add_child(root)
		var upper := Node3D.new()
		upper.name = "Upper"
		root.add_child(upper)
		# A building entry so the board's cut-away reaches the walls each frame (TownBuilder.cut_away).
		var entry := {"interior": true, "root": root, "upper": upper, "walls": null, "extras": [], "cut": false,
			"aabb": AABB(), "rect": Rect2i(), "group": -1, "height": float(st["height"]), "state": st, "dir": Vector2.ZERO}
		board.buildings.append(entry)   # (the entry holds the state, never the other way: a cycle would leak both)
	board.set_meta("interior_walls", st)
	return st


## A place's own outside (catalog building_kit interiors.outside, by the start of its id): its ground, how many storeys
## below it lies, and its walls' height.
static func _place_settings(board: ArenaBoard, places: Dictionary) -> Dictionary:
	var best := ""
	for prefix: String in places:
		if board.place.begins_with(prefix) and prefix.length() > best.length():
			best = prefix
	return places[best] as Dictionary if best != "" else {}


## The wall squares outside the building: solid wall reached from the map's edge through solid wall without touching
## a room (a wall square with an open square beside it, diagonals too, is the building's).
static func _outside_cells(board: ArenaBoard) -> Dictionary:
	var g := board.grid
	var out := {}
	var open: Array[Vector2i] = []
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if (x == 0 or z == 0 or x == g.width - 1 or z == g.depth - 1) and _mass(board, c):
				out[c] = true
				open.append(c)
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if g.in_bounds(n) and not out.has(n) and _mass(board, n):
				out[n] = true
				open.append(n)
	return out


## A wall square with no open square round it (diagonals too).
static func _mass(board: ArenaBoard, c: Vector2i) -> bool:
	var g := board.grid
	if not g.has_flag(c, CombatGrid.WALL):
		return g.has_flag(c, CombatGrid.VOID)
	for dz: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var n := c + Vector2i(dx, dz)
			if g.in_bounds(n) and not g.has_flag(n, CombatGrid.WALL) and not g.has_flag(n, CombatGrid.VOID):
				return false
	return true


## The sides of `c` with an open square beside it (the faces of a room wall).
static func _open_faces(board: ArenaBoard, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in SetDressing.FACES:
		var n := c + d
		if board.grid.in_bounds(n) and not board.grid.has_flag(n, CombatGrid.WALL) and not board.grid.has_flag(n, CombatGrid.VOID):
			out.append(d)
	return out


## A room wall: its full storey and its cut-away version under one node on its square, the full one standing unless
## the camera looks into a room over it. An outer wall of an upper floor runs down to the ground outside.
static func _room_wall(board: ArenaBoard, c: Vector2i, wall_mat: Material, st: Dictionary) -> void:
	var h := float(st["height"])
	var node := Node3D.new()
	node.name = "InteriorWall"
	node.position = board.cell_center(c)
	board.add_child(node)
	var full := Node3D.new()
	full.name = "Full"
	node.add_child(full)
	var low := Node3D.new()
	low.name = "Cut"
	low.visible = false
	node.add_child(low)
	_box(full, Vector3(1, h, 1), Vector3(0, h / 2.0, 0), _tall(wall_mat, h))
	_box(full, Vector3(1.02, 0.1, 1.02), Vector3(0, h + 0.05, 0), Look.cel(ArenaBoard.CUT_FACE))
	ModelPiece.dress_wall(board, c, wall_mat, h, full)
	_box(low, Vector3(1, CUT, 1), Vector3(0, CUT / 2.0, 0), wall_mat)
	_box(low, Vector3(1.02, 0.1, 1.02), Vector3(0, CUT + 0.05, 0), Look.cel(ArenaBoard.CUT_FACE))
	ModelPiece.dress_wall(board, c, wall_mat, CUT, low)
	var below := float(st["below"])
	if below > 0.0 and _beside_outside(c, st):
		_box(node, Vector3(1, below, 1), Vector3(0, -below / 2.0, 0), wall_mat)   # down to the street
	(st["walls"] as Array).append({"node": node, "full": full, "low": low, "cell": c, "cut": false, "h": h})
	# A doorway beside this wall (one open square between it and another wall): the wall goes on over it.
	for d in SetDressing.FACES:
		var n := c + d
		var other := n + d
		if board.grid.in_bounds(other) and _open(board, n) and board.grid.has_flag(other, CombatGrid.WALL) \
				and not (st["headers"] as Dictionary).has(n):
			_header(board, n, d, wall_mat, st)


static func _open(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID)


## The wall over a doorway, from the cut-away height (an interior door's top) to the storey's; it stands while either
## wall beside it stands.
static func _header(board: ArenaBoard, n: Vector2i, along: Vector2i, wall_mat: Material, st: Dictionary) -> void:
	var h := float(st["height"])
	var node := Node3D.new()
	node.name = "InteriorWall"
	node.position = board.cell_center(n)
	board.add_child(node)
	var full := Node3D.new()
	full.name = "Full"
	node.add_child(full)
	var size := Vector3(1.0, h - CUT, 0.5) if along.x != 0 else Vector3(0.5, h - CUT, 1.0)
	_box(full, size, Vector3(0, CUT + (h - CUT) / 2.0, 0), _tall(wall_mat, h))
	_box(full, size + Vector3(0.02, 0.1 - size.y, 0.02), Vector3(0, h + 0.05, 0), Look.cel(ArenaBoard.CUT_FACE))
	var low := Node3D.new()
	low.name = "Cut"
	low.visible = false
	node.add_child(low)
	(st["headers"] as Dictionary)[n] = true
	(st["walls"] as Array).append({"node": node, "full": full, "low": low, "cell": n, "cut": false, "h": h,
		"flanks": [n - along, n + along]})


## Solid wall inside the building (a thick wall's middle): a block at the cut-away height, its top the dark of a cut wall.
static func _block(board: ArenaBoard, c: Vector2i, wall_mat: Material, st: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "WallBlock"
	node.position = board.cell_center(c)
	board.add_child(node)
	_box(node, Vector3(1, CUT, 1), Vector3(0, CUT / 2.0, 0), wall_mat)
	_box(node, Vector3(1.02, 0.1, 1.02), Vector3(0, CUT + 0.05, 0), Look.cel(ArenaBoard.CUT_FACE))
	var below := float(st["below"])
	if below > 0.0 and _beside_outside(c, st):
		_box(node, Vector3(1, below, 1), Vector3(0, -below / 2.0, 0), wall_mat)


## Outside the building: the ground the house stands on, a storey or more below on an upper floor, made once as one slab
## reaching past the map. A dungeon's outside is rock (its rock blocks stay, topped with rock).
static func _outside(board: ArenaBoard, c: Vector2i, st: Dictionary) -> void:
	var ground := str(st["ground"])
	if ground == "":
		var rock := Look.cel_textured("cave/rock_wall")
		_box(board, Vector3(1, CUT, 1), Vector3(c.x + 0.5, CUT / 2.0, c.y + 0.5), rock if rock != null else Look.cel("stone_deep"))
		return
	if bool(st["done_ground"]):
		return
	st["done_ground"] = true
	var mat := Look.cel_textured(ground, 0.0)
	var w := board.grid.width + 2.0 * REACH
	var d := board.grid.depth + 2.0 * REACH
	var y := -float(st["below"]) - 0.04   # a little under the rooms' floors, which stand at the squares' level
	var slab := _box(board, Vector3(w, 0.2, d), Vector3(board.grid.width / 2.0, y - 0.1, board.grid.depth / 2.0),
		mat if mat != null else Look.cel("stone_deep"))
	slab.name = "OutsideGround"
	# One slab for the whole map: on natural ground the board lifts what a wall square built to that square's height
	# (ArenaBoard._lift), which raised the slab to the first outside square's (5 at the Amber Temple's doors) and drew it
	# over the lower ground where the party arrives (UI QA W-07). It stays at the map's ground level.
	slab.set_meta("whole_map", true)


static func _beside_outside(c: Vector2i, st: Dictionary) -> bool:
	var outside := st["outside"] as Dictionary
	for dz: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if outside.has(c + Vector2i(dx, dz)):
				return true
	return false


## A wall material for a full storey: a wall texture painted as one band over the wall's height (the wainscot) is
## mapped over the taller wall instead of the cut-away one.
static func _tall(wall_mat: Material, h: float) -> Material:
	var sm := wall_mat as ShaderMaterial
	if sm == null or not bool(sm.get_shader_parameter("wall_band")):
		return wall_mat
	var key := "tall|%d|%.2f" % [sm.get_instance_id(), h]
	if _talls.has(key):
		return _talls[key] as Material
	var d := sm.duplicate() as ShaderMaterial
	d.set_shader_parameter("band_top", h)
	d.set_shader_parameter("band_height", h)
	_talls[key] = d
	return d


static var _talls: Dictionary = {}


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Wall"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Each frame (TownBuilder.cut_away): a wall with floor just beyond it, looking from the camera, near the party,
## stands in front of the party's room or one beside it and goes down to the cut-away height; the rest stand (the far
## walls frame the rooms, and rooms further off stay walled). A thick wall's back half goes down with its front. A wall changing squashes down or grows back, then its other version takes over.
static func cut(board: ArenaBoard, entry: Dictionary, camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	var dir := Vector2(focus.x - camera_pos.x, focus.z - camera_pos.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var st := entry["state"] as Dictionary
	var ahead := {}
	var near := Vector2(focus.x, focus.z)
	for w: Dictionary in st["walls"]:
		if not w.has("flanks"):
			ahead[w["cell"]] = _in_front(board, w["cell"] as Vector2i, dir, near)
	for w: Dictionary in st["walls"]:
		if not is_instance_valid(w["node"]):
			continue
		var front := bool(ahead.get(w["cell"], false))
		if w.has("flanks"):
			front = false
			for f: Vector2i in w["flanks"]:
				front = front or bool(ahead.get(f, true))
		var full := w["full"] as Node3D
		var low := w["low"] as Node3D
		var goal := CUT / float(w["h"]) if front else 1.0
		if w.has("flanks"):
			goal = 0.02 if front else 1.0   # a doorway's header: gone with the walls beside it
		var s := move_toward(full.scale.y, goal, delta * 4.0)
		if not is_equal_approx(s, full.scale.y):
			full.scale.y = s
		var down := front and is_equal_approx(s, goal)
		if full.visible == down:
			full.visible = not down
			low.visible = down
		w["cut"] = front


## Floor within four squares beyond wall square `c`, looking away from the camera along `dir` (a full storey hides the
## ground about three squares behind it from the camera), and near the party (`near`): the wall stands in front of
## the room the party is in or one beside it.
static func _in_front(board: ArenaBoard, c: Vector2i, dir: Vector2, near: Vector2) -> bool:
	for k: int in [1, 2, 3, 4, 5]:
		var p := Vector2(c.x + 0.5, c.y + 0.5) + dir * (k * BEYOND)
		var n := Vector2i(floori(p.x), floori(p.y))
		if n != c and _open(board, n) and p.distance_to(near) <= NEAR:
			return true
	return false
