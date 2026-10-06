class_name TownBuilder
extends RefCounted
## The buildings of a town board (the Village of Barovia, Vallaki), from the same '#' squares the rules see
## (docs/art/set_dressing.md). Solid blocks of wall (every square in some 2 x 2 of wall) become houses: plaster and
## timber walls under a gabled roof of thatch or slate, with a chimney and shuttered windows. Lines of wall one square
## thick are low stone yard walls. A building standing between the camera and the party is cut away: its roof and
## everything on its walls hide and the walls drop to a low band, like the cut-away interiors.

const HOUSE_H := 2.2
const YARD_WALL_H := 1.0
const EAVE := 0.18          ## how far a roof overhangs the walls
const CUT_H := 0.5          ## a cut-away building's wall height
const STONE := "church/stone_wall"


## Splits the board's inner walls into houses and yard walls, and builds the houses. Returns the yard-wall squares
## (built square by square in ArenaBoard._wall so props can take their place).
static func plan(board: ArenaBoard) -> Dictionary:
	var walls := {}
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if board.grid.has_flag(c, CombatGrid.WALL) and not _border(board, c):
				walls[c] = true
	var block := {}
	for c: Vector2i in walls:
		for o: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			var a := c + o
			if walls.has(a) and walls.has(a + Vector2i(1, 0)) and walls.has(a + Vector2i(0, 1)) and walls.has(a + Vector2i(1, 1)):
				block[c] = true
				break
	var lines := {}
	for c: Vector2i in walls:
		if not block.has(c):
			lines[c] = true
	var taken := {}
	var cells: Array = block.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in cells:
		if taken.has(c):
			continue
		# The largest rectangle growing right, then down, from the first free square.
		var w := 1
		while block.has(c + Vector2i(w, 0)) and not taken.has(c + Vector2i(w, 0)):
			w += 1
		var d := 1
		while true:
			var row_ok := true
			for i in w:
				var n := c + Vector2i(i, d)
				if not block.has(n) or taken.has(n):
					row_ok = false
					break
			if not row_ok:
				break
			d += 1
		for i in w:
			for j in d:
				taken[c + Vector2i(i, j)] = true
		_house(board, Rect2i(c, Vector2i(w, d)))
	return lines


static func _border(board: ArenaBoard, c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == board.grid.width - 1 or c.y == board.grid.depth - 1


## A low stone yard wall on one square: a post in the middle and an arm toward each neighbouring wall.
static func yard_wall(board: ArenaBoard, c: Vector2i, stone: Material) -> void:
	var base := Vector3(c.x + 0.5, 0, c.y + 0.5)
	var h := YARD_WALL_H
	board.add_box("YardWall", Vector3(0.5, h, 0.5), base + Vector3(0, h / 2.0, 0), stone)
	board.add_box("YardCap", Vector3(0.6, 0.1, 0.6), base + Vector3(0, h + 0.05, 0), Look.cel("stone_deep"))
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if not board.grid.in_bounds(n) or not (board.grid.has_flag(n, CombatGrid.WALL) or board.door_cells.has(n)):
			continue
		# Same material and height as the post, so where they overlap nothing shows.
		var off := Vector3(d.x * 0.25, 0, d.y * 0.25)
		board.add_box("YardWall", Vector3(0.5, h, 0.5), base + off + Vector3(0, h / 2.0, 0), stone)
		board.add_box("YardCap", Vector3(0.6, 0.1, 0.6), base + off + Vector3(0, h + 0.05, 0), Look.cel("stone_deep"))


static func _house(board: ArenaBoard, r: Rect2i) -> void:
	var seed := absi(r.position.x * 73856093 ^ r.position.y * 19349663 ^ r.size.x * 83492791)
	var area := r.size.x * r.size.y
	var h := HOUSE_H + (0.4 if area >= 16 else 0.0) + float(seed % 3) * 0.15
	var root := Node3D.new()
	root.name = "Building"
	board.add_child(root)
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, h, r.size.y)
	walls.mesh = bm
	walls.position = Vector3(r.position.x + r.size.x / 2.0, h / 2.0, r.position.y + r.size.y / 2.0)
	walls.material_override = board.house_wall_material()
	root.add_child(walls)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	# A gable along the longer side; big houses get slate, small ones thatch (where the town has both).
	var along_x := r.size.x >= r.size.y
	var half := (r.size.y if along_x else r.size.x) / 2.0
	var rise := clampf(half * 0.62, 0.45, 2.0)
	var roof_mat := board.roof_material(area >= 30)
	upper.add_child(_gable(Vector2(r.position), Vector2(r.position + r.size), h - 0.02, rise, along_x, roof_mat,
		board.house_wall_material()))
	if seed % 3 != 2:
		var stone := Look.cel_textured(STONE)
		var t := 0.22 + float(seed % 5) * 0.12
		var at := Vector2(lerpf(r.position.x + 0.5, r.end.x - 0.5, t), r.position.y + r.size.y / 2.0) if along_x \
			else Vector2(r.position.x + r.size.x / 2.0, lerpf(r.position.y + 0.5, r.end.y - 0.5, t))
		var ch := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.38, rise + 0.7, 0.38)
		ch.mesh = cm
		ch.position = Vector3(at.x, h + (rise + 0.7) / 2.0, at.y)
		ch.material_override = stone if stone != null else Look.cel("stone")
		upper.add_child(ch)
	var idx := board.buildings.size()
	board.buildings.append({"root": root, "walls": walls, "upper": upper, "height": h, "extras": [],
		"aabb": AABB(Vector3(r.position.x - EAVE, 0, r.position.y - EAVE), Vector3(r.size.x + 2 * EAVE, h + rise + 0.2, r.size.y + 2 * EAVE)),
		"cut": false, "rect": r})
	for i in r.size.x:
		for j in r.size.y:
			board.house_cells[r.position + Vector2i(i, j)] = idx
	_windows(board, r, upper, h, seed)


## Shuttered windows on the walls that face open ground, every few squares (one may show a light).
static func _windows(board: ArenaBoard, r: Rect2i, upper: Node3D, h: float, seed: int) -> void:
	var n := 0
	for i in r.size.x:
		for j in r.size.y:
			var c := r.position + Vector2i(i, j)
			for d in SetDressing.FACES:
				var out := c + d
				if r.has_point(out) or not board.grid.in_bounds(out) or board.grid.has_flag(out, CombatGrid.WALL):
					continue
				n += 1
				if (n + seed) % 3 != 0:
					continue
				var art := "window_lit" if (n * 7 + seed) % 5 == 0 else "window_shuttered"
				var sp := SetDressing.wall_sprite(art)
				if sp == null:
					return
				var nv := Vector3(d.x, 0, d.y)
				sp.position = Vector3(c.x + 0.5, minf(0.85, h - 1.0), c.y + 0.5) + nv * (0.5 + SetDressing.WALL_GAP)
				sp.rotation.y = atan2(nv.x, nv.z)
				upper.add_child(sp)
				board.windows["%d,%d,%d,%d" % [c.x, c.y, d.x, d.y]] = sp


## A gabled roof over the rectangle [a, b] (world x, z), its eaves at `eave`, the ridge `rise` above them, with
## gable ends in the wall material. Flat-shaded; texture comes from world position (cel_world.gdshader).
static func _gable(a: Vector2, b: Vector2, eave: float, rise: float, along_x: bool, roof: Material, gable: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := EAVE
	var top := eave + rise
	if along_x:
		var zc := (a.y + b.y) / 2.0
		var half := (b.y - a.y) / 2.0 + o
		var drop := o * rise / ((b.y - a.y) / 2.0)
		var lo := eave - drop
		var n_n := Vector3(0, half, -rise).normalized()
		var n_s := Vector3(0, half, rise).normalized()
		_quad(st, Vector3(a.x - o, lo, a.y - o), Vector3(b.x + o, lo, a.y - o), Vector3(b.x + o, top, zc), Vector3(a.x - o, top, zc), n_n)
		_quad(st, Vector3(a.x - o, lo, b.y + o), Vector3(b.x + o, lo, b.y + o), Vector3(b.x + o, top, zc), Vector3(a.x - o, top, zc), n_s)
	else:
		var xc := (a.x + b.x) / 2.0
		var half := (b.x - a.x) / 2.0 + o
		var drop := o * rise / ((b.x - a.x) / 2.0)
		var lo := eave - drop
		var n_w := Vector3(-rise, half, 0).normalized()
		var n_e := Vector3(rise, half, 0).normalized()
		_quad(st, Vector3(a.x - o, lo, a.y - o), Vector3(a.x - o, lo, b.y + o), Vector3(xc, top, b.y + o), Vector3(xc, top, a.y - o), n_w)
		_quad(st, Vector3(b.x + o, lo, a.y - o), Vector3(b.x + o, lo, b.y + o), Vector3(xc, top, b.y + o), Vector3(xc, top, a.y - o), n_e)
	var roof_mesh := st.commit()
	# The gable ends: triangles in the wall plane under the roof.
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	if along_x:
		var zc := (a.y + b.y) / 2.0
		_tri(gs, Vector3(a.x, eave, a.y), Vector3(a.x, eave, b.y), Vector3(a.x, top - 0.02, zc), Vector3(-1, 0, 0))
		_tri(gs, Vector3(b.x, eave, a.y), Vector3(b.x, eave, b.y), Vector3(b.x, top - 0.02, zc), Vector3(1, 0, 0))
	else:
		var xc := (a.x + b.x) / 2.0
		_tri(gs, Vector3(a.x, eave, a.y), Vector3(b.x, eave, a.y), Vector3(xc, top - 0.02, a.y), Vector3(0, 0, -1))
		_tri(gs, Vector3(a.x, eave, b.y), Vector3(b.x, eave, b.y), Vector3(xc, top - 0.02, b.y), Vector3(0, 0, 1))
	gs.commit(roof_mesh)
	roof_mesh.surface_set_material(0, roof)
	roof_mesh.surface_set_material(1, gable)
	var mi := MeshInstance3D.new()
	mi.name = "Roof"
	mi.mesh = roof_mesh
	return mi


static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	_tri(st, p0, p1, p2, n)
	_tri(st, p0, p2, p3, n)


## One triangle facing `n`: Godot draws clockwise triangles (seen from the front), so the winding is set from n.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


## Cuts away the buildings that hide `focus` (the party's leader) from the camera, and restores the others.
static func cut_away(board: ArenaBoard, camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	var target := focus + Vector3(0, 0.8, 0)
	for b: Dictionary in board.buildings:
		var aabb := b["aabb"] as AABB
		var hides: bool = aabb.intersects_segment(camera_pos, target) != null and not aabb.has_point(target)
		var walls := b["walls"] as MeshInstance3D
		var h := float(b["height"])
		var goal := CUT_H / h if hides else 1.0
		var s := move_toward(walls.scale.y, goal, delta * 4.0)
		if not is_equal_approx(s, walls.scale.y):
			walls.scale.y = s
			walls.position.y = h * s / 2.0
		if hides != bool(b["cut"]):
			b["cut"] = hides
			(b["upper"] as Node3D).visible = not hides
			for e: Variant in b["extras"]:
				if is_instance_valid(e):
					(e as Node3D).visible = not hides
