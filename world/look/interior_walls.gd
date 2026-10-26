class_name InteriorWalls
extends RefCounted
## Interiors that sit in the world (Improvement Ideas W8, docs/art/building_kit.md): a room's walls stand a full storey
## high from every heading, and a wall between the camera and the party opens a window round the party (SeeThrough;
## owner 2026-10-17: "walls collapse down when looking from certain angles ... I don't like this behavior"). Past the
## building's outer walls there is ground (a village street, a castle yard) instead of black, a storey or more below on
## an upper floor, with the outer walls running down to it.
##
## Walls as thick as walls (Natural Maps Plan I1, owner 2026-10-19: "we don't need to draw our real world maps as a
## battle grid ... a real natural map that we just overlay a grid on top afterwards"): each side of a wall square that
## faces a room is drawn set back into the wall square (catalog interiors "thin_walls", 0.35 of a square), so a wall
## between two rooms stands a foot and a half thick, not a whole square, and the room's floor runs on to the new face.
## Doors, pieces hung on a wall and furniture backed onto it follow through ArenaBoard.wall_inset_at. Walls with no room
## beside them stay whole blocks (thick masonry, the outer mass). The rules grid is never changed.
##
## With the catalog's interiors "cut_away" on (off since 2026-10-17), the walls between the camera and the rooms behind
## them drop to the old cut-away height instead, turning with the camera: each wall is built in a full and a cut
## version, and the board's cut-away each frame reaches them through a building entry {"interior": true}
## (TownBuilder.cut_away). Nothing here changes the rules grid.

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
## How far a room-facing side of a wall is set back into its square (a fraction of a square) unless the catalog's
## interiors "thin_walls" says otherwise: a wall between two rooms stands 1 - 2 * THIN = 0.3 of a square thick.
const THIN := 0.35


## Builds wall square `c` (wall material `wall_mat`, as ArenaBoard picked it): a pillar, a room wall (with a cut version
## where cutting is on), a solid block, or outside ground; a tent's canvas (TentWalls). False where W8 isn't on for
## this board (its walls stay as before).
static func build(board: ArenaBoard, c: Vector2i, wall_mat: Material) -> bool:
	var cave := Caves.of(board)
	if cave != null and cave.claims(c):
		cave.build(c)   # a cave's rock is one surface, not a block a square (Caves, the Natural Maps Plan's I2)
		return true
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


## This board's W8 settings, worked out once: {style, height, ground, below, outside (cells), walls, headers, cutting,
## inset (how far thin walls are set back, 0 for whole squares), cuts (wall square -> bits of the sides set back, by
## SetDressing.FACES), feet (the floor still to lay under the bands thin walls leave of their squares)}; empty when off.
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
			"headers": {}, "done_ground": false, "cutting": cutting(), "inset": _inset(board, cfg), "cuts": {}, "feet": []}
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
	if not st.is_empty() and float(st["inset"]) > 0.0:
		board.wall_inset = -float(st["inset"])   # pieces hung on a wall or backed onto it stand on its set-back face
	return st


## How far in this board's walls are set back (catalog interiors "thin_walls": {"inset", "not": [place id starts]}); 0
## for the places the catalog leaves out (the caves), tents (their canvas), natural ground (a hill's floors aren't flat)
## and Castle Ravenloft's roofs (the castle's own walls).
static func _inset(board: ArenaBoard, cfg: Dictionary) -> float:
	var thin := cfg.get("thin_walls", {}) as Dictionary
	if thin.is_empty() or TentWalls.is_tent(board) or board.has_terrain() or board.has_meta("castle"):
		return 0.0
	for prefix: Variant in thin.get("not", []):
		if board.place.begins_with(str(prefix)):
			return 0.0
	return clampf(float(thin.get("inset", THIN)), 0.0, 0.45)


## Whether rooms' walls cut away toward the camera (catalog building_kit interiors "cut_away"; off, owner 2026-10-17).
static func cutting() -> bool:
	return bool((BuildingKit.settings().get("interiors", {}) as Dictionary).get("cut_away", false))


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


## A room wall: its full storey on its square (and, where cutting is on, its cut-away version under the same node, the
## full one standing unless the camera looks into a room over it). An outer wall of an upper floor runs down to the
## ground outside. It opens round the party when it stands in the way (SeeThrough).
static func _room_wall(board: ArenaBoard, c: Vector2i, wall_mat: Material, st: Dictionary) -> void:
	var h := float(st["height"])
	var node := Node3D.new()
	node.name = "InteriorWall"
	node.position = board.cell_center(c)
	node.set_meta("on_floor", true)   # (standing on its square already: ArenaBoard._lift leaves it be on a hill)
	board.add_child(node)
	var full := Node3D.new()
	full.name = "Full"
	node.add_child(full)
	var rects := _solid(board, c, st)
	_slabs(full, rects, h, _tall(wall_mat, h))
	ModelPiece.dress_wall(board, c, wall_mat, h, full)
	var low: Node3D = null
	if bool(st["cutting"]):
		low = Node3D.new()
		low.name = "Cut"
		low.visible = false
		node.add_child(low)
		_slabs(low, rects, CUT, wall_mat)
		ModelPiece.dress_wall(board, c, wall_mat, CUT, low)
	var below := float(st["below"])
	if below > 0.0 and _beside_outside(c, st):
		_footing(node, below, wall_mat, st)   # down to the street
	SeeThrough.mark(node)
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


## The wall over a doorway, from the cut-away height (an interior door's top) to the storey's; where cutting is on, it
## stands while either wall beside it stands. A doorway into a room is framed in the place's style (W7): the jambs stay, and the head over
## them (a lintel, an arch, a cornice) goes with the wall over the doorway. Thin walls: as thick as they, running on to
## the opening's edge at a doorway, and across to the set-back faces over a corridor.
static func _header(board: ArenaBoard, n: Vector2i, along: Vector2i, wall_mat: Material, st: Dictionary) -> void:
	var h := float(st["height"])
	var node := Node3D.new()
	node.name = "InteriorWall"
	node.position = board.cell_center(n)
	node.set_meta("on_floor", true)
	board.add_child(node)
	var full := Node3D.new()
	full.name = "Full"
	node.add_child(full)
	var inset := float(st["inset"])
	var thick := 0.5 if inset <= 0.0 else 1.0 - 2.0 * inset
	var span := 1.0 if inset <= 0.0 or doorway(board, n) != Vector2i.ZERO else 1.0 + 2.0 * inset
	var size := Vector3(span, h - CUT, thick) if along.x != 0 else Vector3(thick, h - CUT, span)
	_box(full, size, Vector3(0, CUT + (h - CUT) / 2.0, 0), _tall(wall_mat, h))
	_box(full, size + Vector3(0.02, 0.1 - size.y, 0.02), Vector3(0, h + 0.05, 0), Look.cel(ArenaBoard.CUT_FACE))
	var low: Node3D = null
	if bool(st["cutting"]):
		low = Node3D.new()
		low.name = "Cut"
		low.visible = false
		node.add_child(low)
	# The frame stands on the faces of the walls beside the doorway, the wall over it set back behind its head.
	var sides := _framed_sides(board, n, along, str(st["style"]))
	if not sides.is_empty():
		_frame(node, full, sides, str(st["style"]), st, n)
	SeeThrough.mark(node)
	(st["headers"] as Dictionary)[n] = true
	(st["walls"] as Array).append({"node": node, "full": full, "low": low, "cell": n, "cut": false, "h": h,
		"flanks": [n - along, n + along]})


## The sides of doorway `n` (one open square between two walls along `along`) that open into a room, each framed in
## `style` when the kit has its doorway: a side whose square runs on between walls the same way is a passage (a
## corridor, a tunnel under the wall over it), not framed.
static func _framed_sides(board: ArenaBoard, n: Vector2i, along: Vector2i, style: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not BuildingKit.has("kit_%s_doorway" % style) or CampaignLook.current().claims(board, n - along) \
			or CampaignLook.current().claims(board, n + along):
		return out   # the castle's roofs: a passage through its own walls (W19)
	if Caves.owns(board, n - along) or Caves.owns(board, n + along):
		return out   # a gap in a cave's rock: the door brings its own frame
	# A gap between free-standing walls (the Amber Temple's book stacks) is an aisle, unless a door hangs in it.
	if not (_anchored(board, n - along) and _anchored(board, n + along)) and not _door_at(board, n):
		return out
	var perp := Vector2i(along.y, along.x)
	for p: Vector2i in [perp, -perp]:
		var m := n + p
		if _open(board, m) and (_open(board, m - along) or _open(board, m + along)):
			out.append(p)
	return out


## Whether wall square `c` is part of the building's walls: joined, wall to wall, to a wall at the map's edge. A
## free-standing wall inside a room (a screen, a stack of shelves) isn't.
static func _anchored(board: ArenaBoard, c: Vector2i) -> bool:
	if not board.has_meta("anchored_walls"):
		var g := board.grid
		var out := {}
		var open: Array[Vector2i] = []
		for z in g.depth:
			for x in g.width:
				var e := Vector2i(x, z)
				if (x == 0 or z == 0 or x == g.width - 1 or z == g.depth - 1) and g.has_flag(e, CombatGrid.WALL):
					out[e] = true
					open.append(e)
		while not open.is_empty():
			var w: Vector2i = open.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _wall(board, w + d) and not out.has(w + d):
					out[w + d] = true
					open.append(w + d)
		board.set_meta("anchored_walls", out)
	return (board.get_meta("anchored_walls") as Dictionary).has(c)


## Whether the place hangs a door on square `c` (its location's doors).
static func _door_at(board: ArenaBoard, c: Vector2i) -> bool:
	if board.place == "" or not (Compendium.shared().tables.get("locations", {}) as Dictionary).has(board.place):
		return false
	for door: Variant in Compendium.shared().get_entry("locations", board.place).get("doors", []):
		var cell := (door as Dictionary).get("cell", []) as Array
		if cell.size() == 2 and Vector2i(int(cell[0]), int(cell[1])) == c:
			return true
	return false


## The doorway's frame on each of its room sides: the jambs on the doorway's own node (they stay as the walls cut
## away), the head in the wall over it (`full`). Each stands on the face of the walls beside the doorway (set back, with
## thin walls).
static func _frame(node: Node3D, full: Node3D, sides: Array[Vector2i], style: String, st: Dictionary, n: Vector2i) -> void:
	var jambs: Array = []
	var heads: Array = []
	for p in sides:
		var dir := Vector3(p.x, 0, p.y)
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), dir * (0.5 - float(st["inset"]) + ModelPiece.GAP))
		jambs.append(["kit_%s_doorway" % style, xf])
		heads.append(["kit_%s_doorway_head" % style, xf])
	var parts: Array[Node3D] = []
	var jm := BuildingKit.merge(jambs)
	if jm != null:
		jm.name = "DoorwayJambs"
		node.add_child(jm)
		parts.append(jm)
	var hm := BuildingKit.merge(heads)
	if hm != null:
		hm.name = "DoorwayHead"
		full.add_child(hm)
		parts.append(hm)
	if not st.has("frames"):
		st["frames"] = {}
	(st["frames"] as Dictionary)[n] = parts
	if (st.get("hidden_frames", {}) as Dictionary).has(n):
		for part in parts:
			part.visible = false


## Whether doorway `c` is framed in the place's style (W7), so a door hung there needs no frame of its own: a board
## with full walls, one open square between two walls, opening into a room on at least one side.
static func frames(board: ArenaBoard, c: Vector2i) -> bool:
	var st := _state(board)
	if st.is_empty():
		return false
	# Once the walls are built, what they framed (a closed door has made its square wall in the grid since).
	if not (st["walls"] as Array).is_empty():
		return (st.get("frames", {}) as Dictionary).has(c)
	if not _open(board, c):
		return false
	for along: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var a := c - along
		var b := c + along
		# Two lone pillars (BuildingKit.pillar) put no wall over the gap between them.
		if not (_wall(board, a) and _wall(board, b)) or (_lone(board, a) and _lone(board, b)):
			continue
		if not _framed_sides(board, c, along, str(st["style"])).is_empty():
			return true
	return false


## A wall square with no wall beside it (a pillar, where the style has one).
static func _lone(board: ArenaBoard, c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _wall(board, c + d) or (board.grid.in_bounds(c + d) and board.grid.has_flag(c + d, CombatGrid.VOID)):
			return false
	return true


## Shows or hides doorway `c`'s frame: a secret door nobody has found shows no doorway (SetDressing.door), until it is
## found (SetDressing.reveal_door).
static func show_frame(board: ArenaBoard, c: Vector2i, on: bool) -> void:
	var st := _state(board)
	if st.is_empty():
		return
	for part: Variant in (st.get("frames", {}) as Dictionary).get(c, []):
		if is_instance_valid(part):
			(part as Node3D).visible = on
	# Remembered for a doorway whose walls aren't built yet.
	if not st.has("hidden_frames"):
		st["hidden_frames"] = {}
	if on:
		(st["hidden_frames"] as Dictionary).erase(c)
	else:
		(st["hidden_frames"] as Dictionary)[c] = true


static func _wall(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL)


## Solid wall inside the building (a thick wall's middle): a block as tall as the walls round it, its top the dark of
## a wall's top (at the cut-away height where walls cut away, so it never stands over a wall that's down). Whole, unless
## a room's corner touches it diagonally (thin walls cut that corner back).
static func _block(board: ArenaBoard, c: Vector2i, wall_mat: Material, st: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "WallBlock"
	node.position = board.cell_center(c)
	node.set_meta("on_floor", true)
	board.add_child(node)
	var h := CUT if bool(st["cutting"]) else float(st["height"])
	_slabs(node, _solid(board, c, st), h, wall_mat if bool(st["cutting"]) else _tall(wall_mat, h))
	var below := float(st["below"])
	if below > 0.0 and _beside_outside(c, st):
		_footing(node, below, wall_mat, st)
	SeeThrough.mark(node)


## The part of wall square `c` that is solid, as rectangles in the square's own frame (x and z from -0.5 to 0.5). With
## thin walls it is the square less a band of `inset` along each side that faces a room, and less a corner where only
## the diagonal square is open: the 3 x 3 pieces of the square, merged. Also records which sides were set back
## (`cuts`, for the pieces that stand on them) and queues the floor to lay under the bands (`finish`).
static func _solid(board: ArenaBoard, c: Vector2i, st: Dictionary) -> Array[Rect2]:
	var inset := float(st["inset"])
	var rects: Array[Rect2] = []
	if inset <= 0.0:
		rects.append(Rect2(-0.5, -0.5, 1.0, 1.0))
		return rects
	var xs: Array[float] = [-0.5, -0.5 + inset, 0.5 - inset, 0.5]
	var gone := [[false, false, false], [false, false, false], [false, false, false]]   # [column][row]
	var mask := 0
	var bands: Array[Array] = []   # [rect, the open square it lies beside]
	for k in SetDressing.FACES.size():
		var d: Vector2i = SetDressing.FACES[k]
		if _cuts_now(board, c, d):
			mask |= 1 << k
			for j in 3:
				if d.x != 0:
					gone[0 if d.x < 0 else 2][j] = true
				else:
					gone[j][0 if d.y < 0 else 2] = true
	var cut_n := (mask & (1 << SetDressing.FACES.find(Vector2i(0, -1)))) != 0
	var cut_s := (mask & (1 << SetDressing.FACES.find(Vector2i(0, 1)))) != 0
	for k in SetDressing.FACES.size():
		if (mask & (1 << k)) == 0:
			continue
		var d: Vector2i = SetDressing.FACES[k]
		var r: Rect2
		if d.y > 0:
			r = Rect2(-0.5, 0.5 - inset, 1.0, inset)
		elif d.y < 0:
			r = Rect2(-0.5, -0.5, 1.0, inset)
		else:
			# (the north and south bands take the corners)
			var z0 := -0.5 + (inset if cut_n else 0.0)
			var z1 := 0.5 - (inset if cut_s else 0.0)
			r = Rect2(0.5 - inset if d.x > 0 else -0.5, z0, inset, z1 - z0)
		bands.append([r, c + d])
	for dz: int in [-1, 1]:
		for dx: int in [-1, 1]:
			var i := 0 if dx < 0 else 2
			var j := 0 if dz < 0 else 2
			if not gone[i][j] and _open(board, c + Vector2i(dx, dz)):
				gone[i][j] = true
				bands.append([Rect2(-0.5 if dx < 0 else 0.5 - inset, -0.5 if dz < 0 else 0.5 - inset, inset, inset), c + Vector2i(dx, dz)])
	(st["cuts"] as Dictionary)[c] = mask
	for b: Array in bands:
		(st["feet"] as Array).append([c, b[0], b[1]])
	# Merge the pieces that are left: runs along each row, then runs of the same width down the rows.
	var prev := {}
	for j in 3:
		var now := {}
		var i := 0
		while i < 3:
			if gone[i][j]:
				i += 1
				continue
			var k := i
			while k + 1 < 3 and not gone[k + 1][j]:
				k += 1
			var key := Vector2i(i, k)
			var z0 := xs[j]
			var z1 := xs[j + 1]
			if prev.has(key):
				var at: int = prev[key]
				rects[at] = Rect2(rects[at].position, Vector2(rects[at].size.x, z1 - rects[at].position.y))
				now[key] = at
			else:
				rects.append(Rect2(xs[i], z0, xs[k + 1] - xs[i], z1 - z0))
				now[key] = rects.size() - 1
			i = k + 1
		prev = now
	return rects


## Whether the open square beside wall square `c` in direction `d` takes the wall's side back from the grid line: every
## open square does but a doorway lying in the line of the wall, where the wall runs on to the opening's edge.
static func cuts(board: ArenaBoard, c: Vector2i, d: Vector2i) -> bool:
	# As it was when the wall was built: a closed door has made its square wall in the grid since.
	var st := board.get_meta("interior_walls", {}) as Dictionary
	if st.has("cuts") and (st["cuts"] as Dictionary).has(c):
		var k := SetDressing.FACES.find(d)
		return k >= 0 and (int((st["cuts"] as Dictionary)[c]) & (1 << k)) != 0
	return _cuts_now(board, c, d)


static func _cuts_now(board: ArenaBoard, c: Vector2i, d: Vector2i) -> bool:
	var n := c + d
	if not _open(board, n):
		return false
	var along := doorway(board, n)
	return along == Vector2i.ZERO or (along != d and along != -d)


## Which way the wall runs through open square `n` when it is a doorway: one open square between two walls, opening into
## a room on at least one side (so not a corridor or its dead end); ZERO when it isn't.
static func doorway(board: ArenaBoard, n: Vector2i) -> Vector2i:
	if not _open(board, n):
		return Vector2i.ZERO
	for along: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (_wall(board, n - along) and _wall(board, n + along)):
			continue
		var perp := Vector2i(along.y, along.x)
		for p: Vector2i in [perp, -perp]:
			var m := n + p
			if _open(board, m) and (_open(board, m - along) or _open(board, m + along)):
				return along
	return Vector2i.ZERO


## How far in from wall square `wall`'s side toward `normal` the wall's surface stands, for the pieces hung on it or
## backed onto it (ArenaBoard.wall_inset_at): negative for a side thin walls set back into the square, 0 where the
## wall runs to the grid line (the side of a doorway, a pillar), a tent canvas's inset otherwise.
static func inset_at(board: ArenaBoard, wall: Vector2i, normal: Vector2i, hung := true) -> float:
	var st := board.get_meta("interior_walls", {}) as Dictionary
	var inset := 0.0 if st.is_empty() else float(st.get("inset", 0.0))
	if inset <= 0.0:
		return board.wall_inset
	if (st["cuts"] as Dictionary).has(wall):
		if not cuts(board, wall, normal):
			return 0.0
		# Furniture stays on the grid line against a face too short for it: pressed back into the wall square, two pieces
		# against the two faces of a wall's end would meet in it. A hung piece has to touch the wall.
		return 0.0 if not hung and short_face(board, wall, normal) else -inset
	return -inset if board.door_cells.has(wall) else 0.0


## Whether side `d` of wall square `c` is much shorter than a square (a thin wall's end, or its last square before an
## end): what stands against it or hangs on it would reach past the wall.
static func short_face(board: ArenaBoard, c: Vector2i, d: Vector2i) -> bool:
	if board.wall_inset >= 0.0:
		return false
	var length := 1.0
	for e: Vector2i in [Vector2i(d.y, -d.x), Vector2i(-d.y, d.x)]:
		if cuts(board, c, e):
			length += board.wall_inset
	return length < 0.9


## How far side `d` of thin wall square `c` runs along a face module's own x (a module is made standing on its face, one
## square wide, from -0.5 to 0.5; its +x is (d.y, -d.x) on the grid): shorter at an end where the next square along is a
## room too (the wall's end cuts that end of the face back by the inset), longer where it goes on round a room's inside
## corner into the corner square's notch.
static func face_span(board: ArenaBoard, c: Vector2i, d: Vector2i) -> Vector2:
	var span := Vector2(-0.5, 0.5)
	var inset := -board.wall_inset
	var along := Vector2i(d.y, -d.x)
	for k: int in [1, -1]:
		var e := along * k
		var edge := 0.5 * k
		if cuts(board, c, e):
			edge -= inset * k
		elif _wall(board, c + e) and _wall(board, c + e + d):
			edge += inset * k   # a room's inside corner: the face goes on into the corner square's notch
		if k > 0:
			span.y = edge
		else:
			span.x = edge
	return span


## The floor still to lay under the bands thin walls leave of their squares, once every square is built (ArenaBoard.
## _build): each band takes the floor of the open square it lies beside, so that room's floor runs on to the wall's
## face. Recorded with the wall square's scenery (a prop that takes the square hides them, as the wall).
static func finish(board: ArenaBoard) -> void:
	var st := board.get_meta("interior_walls", {}) as Dictionary
	if st.is_empty() or float(st["inset"]) <= 0.0:
		return
	for f: Array in st["feet"]:
		var c: Vector2i = f[0]
		var r: Rect2 = f[1]
		var n: Vector2i = f[2]
		var fb := board.floor_box(n)
		var mat: Material = fb.material_override if fb != null and fb.material_override != null else board.floor_material()
		var top := board.floor_y(n)
		var bottom := minf(top, 0.0) - 0.2
		var at := board.cell_center(c)
		var mi := MeshInstance3D.new()
		mi.name = "WallFoot"
		mi.mesh = _box_mesh(Vector3(r.size.x, top - bottom, r.size.y))
		mi.position = Vector3(at.x + r.get_center().x, (top + bottom) / 2.0, at.z + r.get_center().y)
		mi.material_override = mat
		board.add_child(mi)
		mi.set_meta("on_floor", true)
		mi.set_meta("wall_foot", true)
		var nodes: Array = board.dressing.get(c, [])
		nodes.append(mi)
		board.dressing[c] = nodes
	(st["feet"] as Array).clear()


## Solid wall boxes for `rects` (`_solid`), `h` tall on the square's floor, each with its dark top.
static func _slabs(parent: Node3D, rects: Array[Rect2], h: float, mat: Material) -> void:
	for r in rects:
		var mid := r.get_center()
		_box(parent, Vector3(r.size.x, h, r.size.y), Vector3(mid.x, h / 2.0, mid.y), mat)
		_box(parent, Vector3(r.size.x + 0.02, 0.1, r.size.y + 0.02), Vector3(mid.x, h + 0.05, mid.y), Look.cel(ArenaBoard.CUT_FACE))


## An outer wall of an upper floor running down to the ground outside. With thin walls it starts under the floor laid at
## the foot of the room-facing sides, so the two never share a top.
static func _footing(node: Node3D, below: float, wall_mat: Material, st: Dictionary) -> void:
	var skip := 0.2 if float(st["inset"]) > 0.0 else 0.0
	_box(node, Vector3(1, below - skip, 1), Vector3(0, -(below + skip) / 2.0, 0), wall_mat)


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
	mi.mesh = _box_mesh(size)
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static var _box_meshes: Dictionary = {}   ## size (thousandths) -> the BoxMesh every wall of that size shares


## The box mesh of `size`, made once: a place's walls come in a few sizes and a mesh of its own for each of hundreds of
## boxes was most of what drawing them cost to build.
static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := Vector3i(roundi(size.x * 1000.0), roundi(size.y * 1000.0), roundi(size.z * 1000.0))
	if not _box_meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_box_meshes[key] = bm
	return _box_meshes[key] as BoxMesh


## Each frame where cutting is on (TownBuilder.cut_away): a wall with floor just beyond it, looking from the camera, near the party,
## stands in front of the party's room or one beside it and goes down to the cut-away height; the rest stand (the far
## walls frame the rooms, and rooms further off stay walled). A thick wall's back half goes down with its front. A wall changing squashes down or grows back, then its other version takes over.
static func cut(board: ArenaBoard, entry: Dictionary, camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	var dir := Vector2(focus.x - camera_pos.x, focus.z - camera_pos.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var st := entry["state"] as Dictionary
	if not bool(st.get("cutting", false)):
		return   # built without cut versions (cutting off when the board was built)
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
