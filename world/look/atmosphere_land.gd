class_name AtmosphereLand
extends RefCounted
## The land around a map (Atmosphere, docs/art/atmosphere.md), so no place floats in a void: the ground runs on past
## the edge and rises into hills, forest thins into the distance, a road runs on out of every way out, a lake or river
## that meets the edge goes on past it, and a drop at the edge stays a drop. Each point outside the map takes after
## the edge square nearest it. Cosmetic only: the rules grid never sees any of it.

const TREE_SHADER := preload("res://shaders/atmosphere/surround_tree.gdshader")
const WATER_SHADER := preload("res://shaders/atmosphere/water.gdshader")
## How far the land reaches past the map (world units), and the depth of the ring of trees that fade like the board's
## own when they stand in front of the party.
const REACH := 30.0
const NEAR_RING := 4.0
## The top of the board's water (ArenaBoard._water).
const WATER_Y := -0.13

enum Edge { FOREST, OPEN, WATER, DROP }

var board: ArenaBoard
var spec: Dictionary
var mists := ""
var rng: RandomNumberGenerator
var root: Node3D
var water_material: ShaderMaterial = null
var occluders: Array[Sprite3D] = []
var mesh_occluders: Array[Node3D] = []   ## 3D trees (ModelPiece, or Flora's) in the first rows
## The Modern look's trees and plants (Flora, Improvement Ideas W9); null in Classic, which keeps the old trees.
var flora: Flora = null
## The Modern look's shaped ground under the map's woods (GroundRelief, W11); null in Classic, which stays flat.
var relief: GroundRelief = null
## The roads out of the map (W11): each edge square of a way out -> Vector2(the middle of its run of open squares
## along that edge, half the run's width).
var _roads: Dictionary = {}
var _edge: Dictionary = {}      ## border cell -> Edge
var _w := 0
var _d := 0
## Empty squares on the map (' ') are hillside like the land around it, unless the mood says they're a drop (a
## chasm, a cliff).
var _void_land := true
## Over the whole area the land covers, one cell per square from (-REACH, -REACH): how far each is from the map's own
## squares (`_dist`) and from the squares people walk on (`_walk`), in squares.
var _dist := PackedFloat32Array()
var _walk := PackedFloat32Array()
var _nx := 0
var _nz := 0
## The land mesh's corner heights ((_nx + 1) x (_nz + 1), from (-REACH, -REACH)), so plants stand on it exactly.
var _corner_h := PackedFloat32Array()


## Builds the land for `board` from a mood's `surround` (ground, road, trees, dead, rise, hills, void) and its
## `mists_edge` side.
static func build(board_: ArenaBoard, mood: Dictionary, rng_: RandomNumberGenerator, water: ShaderMaterial) -> AtmosphereLand:
	var l := AtmosphereLand.new()
	l.board = board_
	l.spec = mood.get("surround", {}) as Dictionary
	l.mists = str(mood.get("mists_edge", ""))
	l.rng = rng_
	l.water_material = water
	l.root = Node3D.new()
	l.root.name = "Surround"
	l._w = board_.grid.width
	l._d = board_.grid.depth
	l._void_land = str(l.spec.get("void", "land")) == "land"
	l._classify()
	l._distances()
	var loc := Compendium.shared().get_entry("locations", board_.place) if board_.place != "" \
		and Compendium.shared().has("locations", board_.place) else {}
	if GroundRelief.enabled():
		l.relief = GroundRelief.build(board_, loc)
		l._find_roads()
	l._terrain()
	if l.relief != null:
		var shaped := l.relief.meshes(Look.cel_textured(str(l.spec.get("ground", "village/grass"))))
		if shaped != null:
			l.root.add_child(shaped)
	if Flora.enabled():
		l.flora = Flora.for_place(board_, Atmosphere.mood_for(board_.place, loc) if not loc.is_empty() else "", mood)
		l._flora_board_trees()
		l.flora.dress_map(board_, l.root, l.map_y)
	if float(l.spec.get("trees", 0.0)) > 0.0:
		if l.flora != null:
			l._flora_trees()
		else:
			l._trees()
	if l.flora != null:
		l._flora_ground()
	return l


## Is a map square empty ground the land covers (a plain ' ' square)?
func _is_void(c: Vector2i) -> bool:
	var g := board.grid
	return g.has_flag(c, CombatGrid.VOID) and not g.has_flag(c, CombatGrid.WATER)


## What each square on the map's edge leads on into.
func _classify() -> void:
	var g := board.grid
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if x != 0 and z != 0 and x != _w - 1 and z != _d - 1:
				continue
			var inward := Vector2i(clampi(x, 1, _w - 2), clampi(z, 1, _d - 2))
			if g.has_flag(c, CombatGrid.WATER):
				_edge[c] = Edge.WATER
			elif _is_void(c):
				_edge[c] = Edge.FOREST if _void_land else Edge.DROP
			elif g.has_flag(c, CombatGrid.WALL):
				# The map's frame of trees: a lake behind it goes on past it.
				_edge[c] = Edge.WATER if g.in_bounds(inward) and g.has_flag(inward, CombatGrid.WATER) else Edge.FOREST
			else:
				_edge[c] = Edge.OPEN


## The kind of land at a point outside the map: what the nearest edge square leads into.
func edge_at(p: Vector2) -> int:
	if mists != "" and _beyond(p, mists):
		return Edge.FOREST   # under the wall of the Mists
	var c := Vector2i(clampi(floori(p.x), 0, _w - 1), clampi(floori(p.y), 0, _d - 1))
	return int(_edge.get(c, Edge.FOREST))


func _beyond(p: Vector2, side: String) -> bool:
	match side:
		"east":
			return p.x > _w
		"west":
			return p.x < 0.0
		"south":
			return p.y > _d
		"north":
			return p.y < 0.0
	return false


static func outside(p: Vector2, w: float, d: float) -> float:
	var o := Vector2(maxf(maxf(-p.x, p.x - w), 0.0), maxf(maxf(-p.y, p.y - d), 0.0))
	return o.length()


## The cell of the land's grid a point is in, or -1 off it.
func _cell(p: Vector2) -> int:
	var i := floori(p.x) + int(REACH)
	var j := floori(p.y) + int(REACH)
	if i < 0 or j < 0 or i >= _nx or j >= _nz:
		return -1
	return j * _nx + i


## A square of the map's own that the land doesn't cover (anything but empty ground in land mode).
func _is_map(i: int, j: int) -> bool:
	var c := Vector2i(i - int(REACH), j - int(REACH))
	if not board.grid.in_bounds(c):
		return false
	return not (_void_land and _is_void(c))


## Two chamfer passes (straight steps 1, diagonal 1.41) for the distances from the map and from where people walk.
func _distances() -> void:
	_nx = _w + 2 * int(REACH)
	_nz = _d + 2 * int(REACH)
	_dist.resize(_nx * _nz)
	_walk.resize(_nx * _nz)
	var g := board.grid
	for j in _nz:
		for i in _nx:
			var c := Vector2i(i - int(REACH), j - int(REACH))
			_dist[j * _nx + i] = 0.0 if _is_map(i, j) else 1e6
			var walk := g.in_bounds(c) and not g.has_flag(c, CombatGrid.WALL) and not g.has_flag(c, CombatGrid.VOID) \
				and not g.has_flag(c, CombatGrid.WATER)
			_walk[j * _nx + i] = 0.0 if walk else 1e6
	_dist = _chamfered(_dist)
	_walk = _chamfered(_walk)


func _chamfered(f: PackedFloat32Array) -> PackedFloat32Array:
	var d := 1.41421
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var v := f[k]
			if i > 0:
				v = minf(v, f[k - 1] + 1.0)
			if j > 0:
				v = minf(v, f[k - _nx] + 1.0)
				if i > 0:
					v = minf(v, f[k - _nx - 1] + d)
				if i < _nx - 1:
					v = minf(v, f[k - _nx + 1] + d)
			f[k] = v
	for j in range(_nz - 1, -1, -1):
		for i in range(_nx - 1, -1, -1):
			var k := j * _nx + i
			var v := f[k]
			if i < _nx - 1:
				v = minf(v, f[k + 1] + 1.0)
			if j < _nz - 1:
				v = minf(v, f[k + _nx] + 1.0)
				if i < _nx - 1:
					v = minf(v, f[k + _nx + 1] + d)
				if i > 0:
					v = minf(v, f[k + _nx - 1] + d)
			f[k] = v
	return f


## How far a point is from the map's own squares (0 on them).
func distance(p: Vector2) -> float:
	var k := _cell(p)
	return REACH if k < 0 else _dist[k]


## Ground height at a point: rising away from the map into hills (`rise` at the far edge, `hills` of roll on top).
func height(p: Vector2) -> float:
	return _height_at(p, distance(p))


func _height_at(p: Vector2, out: float) -> float:
	var rise := float(spec.get("rise", 3.0))
	var hills := float(spec.get("hills", 1.2))
	var k := clampf((out - 1.5) / (REACH - 1.5), 0.0, 1.0)
	var n := _noise(p * 0.09) * 0.7 + _noise(p * 0.21 + Vector2(7.1, 3.3)) * 0.3
	return rise * pow(k, 1.3) + (n - 0.35) * hills * smoothstep(2.0, 9.0, out)


func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


## One mesh of 1-unit quads around the map (and over its empty squares), in three surfaces: ground, road and water.
## Shared corners, so the ground dips to the waterline at a shore, flattens along a road and meets the map's floor
## level at its squares.
func _terrain() -> void:
	var r := int(REACH)
	var nx := _nx
	var nz := _nz
	var kinds := PackedInt32Array()
	kinds.resize(nx * nz)
	for j in nz:
		for i in nx:
			var p := Vector2(i - r + 0.5, j - r + 0.5)
			var c := Vector2i(i - r, j - r)
			if board.grid.in_bounds(c):
				if _is_void(c):
					kinds[j * nx + i] = Edge.FOREST if _void_land else Edge.DROP
				else:
					kinds[j * nx + i] = -1
			else:
				kinds[j * nx + i] = edge_at(p)
	# Corner heights: water or a drop next to a corner pins it down; a road beside it flattens it; a corner touching
	# the map's own squares sits level with its floor.
	var heights := PackedFloat32Array()
	heights.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var p := Vector2(i - r, j - r)
			var water := false
			var road := 0
			var on_map := false
			var near := 1e6
			for dj: int in [-1, 0]:
				for di: int in [-1, 0]:
					var qi: int = i + di
					var qj: int = j + dj
					if qi < 0 or qj < 0 or qi >= nx or qj >= nz:
						continue
					var k := kinds[qj * nx + qi]
					near = minf(near, _dist[qj * nx + qi])
					if k == -1:
						on_map = true
						continue
					water = water or k == Edge.WATER or k == Edge.DROP
					if k == Edge.OPEN:
						road += 1
			var h := _height_at(p, near)
			if relief != null and not water:
				# The banks under the map's woods carry on past its edge and settle into the land.
				var bank := relief.height(p.clamp(Vector2.ZERO, Vector2(_w, _d)))
				h += bank * (1.0 - smoothstep(0.5, 3.5, near)) * (1.0 - float(road) / 4.0)
			if on_map:
				h = relief.height(p) if relief != null else 0.0
			elif water:
				h = WATER_Y
			elif road > 0:
				h *= 1.0 - 0.8 * float(road) / 4.0
			heights[j * (nx + 1) + i] = h
	_corner_h = heights
	var tools := {Edge.FOREST: SurfaceTool.new(), Edge.OPEN: SurfaceTool.new(), Edge.WATER: SurfaceTool.new()}
	var used := {}
	for st: SurfaceTool in tools.values():
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var k := kinds[j * nx + i]
			if k == -1 or k == Edge.DROP:
				continue
			var st := tools[k] as SurfaceTool
			used[k] = true
			var y00 := heights[j * (nx + 1) + i]
			var y10 := heights[j * (nx + 1) + i + 1]
			var y01 := heights[(j + 1) * (nx + 1) + i]
			var y11 := heights[(j + 1) * (nx + 1) + i + 1]
			if k == Edge.WATER:
				y00 = WATER_Y
				y10 = WATER_Y
				y01 = WATER_Y
				y11 = WATER_Y
			if k == Edge.OPEN and relief != null:
				_rutted(st, i - r, j - r, y00, y10, y01, y11)
				continue
			var a := Vector3(i - r, y00, j - r)
			var b := Vector3(i - r + 1, y10, j - r)
			var c := Vector3(i - r, y01, j - r + 1)
			var e := Vector3(i - r + 1, y11, j - r + 1)
			for v: Vector3 in [a, b, c, b, e, c]:
				st.add_vertex(v)
	var mesh := ArrayMesh.new()
	var mats: Array[Material] = []
	var ground := Look.cel_textured(str(spec.get("ground", "village/grass")))
	var road := Look.cel_textured(str(spec.get("road", spec.get("ground", "village/mud_road"))))
	for k: int in [Edge.FOREST, Edge.OPEN, Edge.WATER]:
		if not used.has(k):
			continue
		var st := tools[k] as SurfaceTool
		st.generate_normals()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		var m: Material = ground if k == Edge.FOREST else (road if k == Edge.OPEN else water_material)
		mats.append(m if m != null else Look.cel("bog_deep"))
	var mi := MeshInstance3D.new()
	mi.name = "Land"
	mi.mesh = mesh
	for s in mats.size():
		mi.set_surface_override_material(s, mats[s])
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Trees on a jittered grid over the forest land, never within two squares of where people walk: the first rows as
## the board's own fading billboards, the rest in one MultiMesh per kind, darker further out.
func _trees() -> void:
	var density := float(spec.get("trees", 0.8))
	var dead := float(spec.get("dead", 0.2))
	var kinds := spec.get("tree_kinds", ["pine", "dead_tree"]) as Array
	var step := 1.0 / sqrt(density)
	var far: Dictionary = {}
	for k: Variant in kinds:
		far[str(k)] = []
	var y := -REACH
	while y < _d + REACH:
		var x := -REACH
		while x < _w + REACH:
			var p := Vector2(x + rng.randf_range(0.0, step), y + rng.randf_range(0.0, step))
			x += step
			var k := _cell(p)
			if k < 0:
				continue
			var out := _dist[k]
			var c := Vector2i(floori(p.x), floori(p.y))
			var kind_here := (Edge.FOREST if _void_land else Edge.DROP) if board.grid.in_bounds(c) and _is_void(c) else (-1 if board.grid.in_bounds(c) else edge_at(p))
			if out < 0.5 or _walk[k] < 2.0 or out > REACH - 1.0 or kind_here != Edge.FOREST:
				continue
			if mists != "" and _beyond(p, mists):
				continue
			var kind := str(kinds[1 if kinds.size() > 1 and rng.randf() < dead else 0])
			var size := rng.randf_range(0.5, 0.75)
			var at := Vector3(p.x, height(p) - 0.05, p.y)
			if out < NEAR_RING:
				var pick := ModelPiece.hash_cell(Vector2i(floori(p.x * 3.0), floori(p.y * 3.0)))
				var tree := ModelPiece.tree(board, kind, at, size, pick, float(pick % 360) * PI / 180.0)
				if tree != null:
					root.add_child(tree)   # 3D trees (docs/art/models.md), as tall as the billboards were
					mesh_occluders.append(tree)
					continue
				var sp := board.prop_sprite(kind, at, size)
				if sp != null:
					sp.get_parent().remove_child(sp)
					root.add_child(sp)
					occluders.append(sp)
				continue
			(far[kind] as Array).append([at, size, clampf(1.0 - (out - NEAR_RING) / (REACH - NEAR_RING) * 0.45, 0.5, 1.0)])
		y += step
	for kind: String in far:
		_tree_multimesh(kind, far[kind] as Array)


func _tree_multimesh(kind: String, items: Array) -> void:
	var info := SetDressing.manifest().get(kind, {}) as Dictionary
	if items.is_empty() or info.is_empty():
		return
	if _tree_models(kind, items):
		return
	var px := float(info.get("pixel_size", 0.01))
	var quad := QuadMesh.new()
	quad.size = Vector2(float(info.get("width_px", 256)) * px, float(info.get("height_px", 256)) * px)
	quad.center_offset = Vector3(0, quad.size.y / 2.0, 0)
	var mat := ShaderMaterial.new()
	mat.shader = TREE_SHADER
	mat.set_shader_parameter("tex", load("res://" + str(info["file"])) as Texture2D)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = items.size()
	for i in items.size():
		var it := items[i] as Array
		var s := float(it[1])
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), it[0] as Vector3))
		var shade := float(it[2])
		mm.set_instance_color(i, Color(shade, shade, shade))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees_" + kind
	mmi.multimesh = mm
	root.add_child(mmi)


## The far trees as 3D models (docs/art/models.md) where the place has them: one MultiMesh per variant, each tree as
## tall as its billboard was, turned its own way, darker further out as before. False if there's no model.
func _tree_models(kind: String, items: Array) -> bool:
	var variants: Array[String] = []
	for k in 8:
		var id := ModelPiece.for_art(board, kind, k)
		if id != "" and not id in variants:
			variants.append(id)
	if variants.is_empty():
		return false
	for v in variants.size():
		var id := variants[v]
		var mesh := ModelPiece.tree_mesh(id)
		if mesh == null:
			return false
		var mine: Array = []
		for i in items.size():
			if i % variants.size() == v:
				mine.append(items[i])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = mine.size()
		for i in mine.size():
			var it := mine[i] as Array
			var at := it[0] as Vector3
			var s := ModelPiece.tree_scale(kind, id, float(it[1]))
			var yaw := float(ModelPiece.hash_cell(Vector2i(floori(at.x * 3.0), floori(at.z * 3.0))) % 360) * PI / 180.0
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), at))
			var shade := float(it[2])
			mm.set_instance_color(i, Color(shade, shade, shade))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Trees_" + id
		mmi.multimesh = mm
		root.add_child(mmi)
	return true


# --- Ground with shape (Improvement Ideas W11) --------------------------------------------------------------------

## Pieces a road square is cut into across, for its ruts.
const RUT_STEPS := 6


## The ways out: runs of open squares along each edge of the map, each run's middle and half its width.
func _find_roads() -> void:
	for side: int in 4:
		var n := _w if side < 2 else _d
		var run: Array[Vector2i] = []
		for t in n + 1:
			var c := Vector2i(-1, -1)
			if t < n:
				c = Vector2i(t, 0 if side == 0 else _d - 1) if side < 2 else Vector2i(0 if side == 2 else _w - 1, t)
			if t < n and int(_edge.get(c, -1)) == Edge.OPEN:
				run.append(c)
				continue
			if not run.is_empty():
				var a := float(run[0].x if side < 2 else run[0].y)
				var b := float(run[-1].x if side < 2 else run[-1].y) + 1.0
				for rc in run:
					var info := Vector2((a + b) / 2.0, (b - a) / 2.0)
					# A corner square is on two edges: keep the wider way out.
					if not _roads.has(rc) or (_roads[rc] as Vector2).y < info.y:
						_roads[rc] = info
				run.clear()


## The ruts' height at a point on a road out: a raised crown down the middle, two wheel ruts, the verges rising at
## the sides; nothing where the road leaves the map, so it meets the map's own flat squares.
func _rut(p: Vector2) -> float:
	var c := Vector2i(clampi(floori(p.x), 0, _w - 1), clampi(floori(p.y), 0, _d - 1))
	if not _roads.has(c):
		return 0.0
	var info := _roads[c] as Vector2
	var ox := maxf(-p.x, p.x - _w)
	var oz := maxf(-p.y, p.y - _d)
	# Beyond the left or right edge the road runs along x, so its width lies along z, and the other way round.
	var across := p.y if ox > oz else p.x
	var u := (across - info.x) / maxf(info.y, 0.5)
	var au := absf(u)
	var h := 0.03 * exp(-pow(u / 0.18, 2.0)) - 0.055 * exp(-pow((au - 0.48) / 0.14, 2.0)) + 0.07 * smoothstep(0.78, 1.1, au)
	return h * smoothstep(0.2, 1.6, maxf(ox, oz))


## A road square of the land cut into strips with ruts in them, on top of its corner heights.
func _rutted(st: SurfaceTool, x: float, z: float, y00: float, y10: float, y01: float, y11: float) -> void:
	var q := 1.0 / RUT_STEPS
	for sj in RUT_STEPS:
		for si in RUT_STEPS:
			var v: Array[Vector3] = []
			for corner: Vector2 in [Vector2(si, sj), Vector2(si + 1, sj), Vector2(si, sj + 1), Vector2(si + 1, sj + 1)]:
				var fx := corner.x * q
				var fz := corner.y * q
				var y := lerpf(lerpf(y00, y10, fx), lerpf(y01, y11, fx), fz)
				var p := Vector2(x + fx, z + fz)
				v.append(Vector3(p.x, y + _rut(p), p.y))
			for t: Vector3 in [v[0], v[1], v[2], v[1], v[3], v[2]]:
				st.add_vertex(t)


## The ground's height at a point on the map's own squares: its banks (0 where people walk, and in Classic).
func map_y(p: Vector2) -> float:
	return relief.height(p) if relief != null else 0.0


# --- The Modern look's trees and plants (Flora, Improvement Ideas W9) -----------------------------------------------

## Beyond this many squares from the map the land's trees are their lighter far copies and cast no shadow.
const FAR_DETAIL := 9.0


## The ground's height at a point exactly as the land mesh has it (its corners, each square split as the mesh splits
## it), so plants stand on it rather than float or sink.
func surface_y(p: Vector2) -> float:
	if _corner_h.is_empty():
		return height(p)
	var fi := p.x + REACH
	var fj := p.y + REACH
	var i := clampi(floori(fi), 0, _nx - 1)
	var j := clampi(floori(fj), 0, _nz - 1)
	var fx := clampf(fi - i, 0.0, 1.0)
	var fz := clampf(fj - j, 0.0, 1.0)
	var w := _nx + 1
	var y00 := _corner_h[j * w + i]
	var y10 := _corner_h[j * w + i + 1]
	var y01 := _corner_h[(j + 1) * w + i]
	var y11 := _corner_h[(j + 1) * w + i + 1]
	if fx + fz <= 1.0:
		return y00 + (y10 - y00) * fx + (y01 - y00) * fz
	return y11 + (y01 - y11) * (1.0 - fx) + (y10 - y11) * (1.0 - fz)


## What the land is at a point: one of Edge, or -1 on the map's own squares.
func _land_kind(p: Vector2) -> int:
	var c := Vector2i(floori(p.x), floori(p.y))
	if board.grid.in_bounds(c):
		if _is_void(c):
			return Edge.FOREST if _void_land else Edge.DROP
		return -1
	return edge_at(p)


## The map's own woods (ArenaBoard's trees on its wall squares) become the Modern look's trees: each keeps its square,
## heading and fading; only the tree in it changes.
func _flora_board_trees() -> void:
	for holder in board.mesh_occluders:
		if not is_instance_valid(holder) or not holder.has_meta("nature"):
			continue
		var info := ModelPiece.manifest().get(str(holder.get_meta("model", "")), {}) as Dictionary
		var stands := info.get("stands_for", []) as Array
		if stands.is_empty():
			continue
		var pick := ModelPiece.hash_cell(Vector2i(floori(holder.position.x * 3.0), floori(holder.position.z * 3.0)))
		var id := flora.tree_for(str(stands[0]), pick)
		if id == "":
			continue
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		holder.add_child(Flora.instance(id, flora.tree_scale(id, "map", pick)))
		holder.set_meta("model", id)
		# Up on the bank under the woods (W11), a little sunk so its foot never shows a gap.
		holder.position.y = map_y(Vector2(holder.position.x, holder.position.z)) - 0.05


## Is land of kind `kind` within `r` squares of a point (sampled round it)?
func _near(p: Vector2, kind: int, r: float) -> bool:
	for i in 12:
		var a := TAU * i / 12.0
		for f: float in [0.5, 1.0]:
			if _land_kind(p + Vector2(cos(a), sin(a)) * r * f) == kind:
				return true
	return false


## The land's trees as _trees() places them, from Flora: the first rows each a node of its own that fades like the
## map's trees, the rest drawn many at once (the furthest as their lighter copies), darker further out as before.
## Flora's trees are fuller than the old ones, so they stand further apart (the set's tree_density).
func _flora_trees() -> void:
	var density := float(spec.get("trees", 0.8)) * float(flora.spec.get("tree_density", 0.45))
	var dead := float(spec.get("dead", 0.2))
	var kinds := spec.get("tree_kinds", ["pine", "dead_tree"]) as Array
	var step := 1.0 / sqrt(density)
	var near := {}
	var far := {}
	var y := -REACH
	while y < _d + REACH:
		var x := -REACH
		while x < _w + REACH:
			var p := Vector2(x + rng.randf_range(0.0, step), y + rng.randf_range(0.0, step))
			x += step
			var k := _cell(p)
			if k < 0:
				continue
			var out := _dist[k]
			if out < 0.5 or _walk[k] < 2.0 or out > REACH - 1.0 or _land_kind(p) != Edge.FOREST:
				continue
			if mists != "" and _beyond(p, mists):
				continue
			var kind := str(kinds[1 if kinds.size() > 1 and rng.randf() < dead else 0])
			# A spruce's crown is wide: keep it off the roads out so they stay open lanes through the woods.
			if _near(p, Edge.OPEN, 1.3):
				continue
			var pick := ModelPiece.hash_cell(Vector2i(floori(p.x * 3.0), floori(p.y * 3.0)))
			var id := flora.tree_for(kind, pick)
			if id == "":
				continue
			var s := flora.tree_scale(id, "land", pick)
			var yaw := float(pick % 360) * PI / 180.0
			var at := Vector3(p.x, surface_y(p) - 0.05, p.y)
			if out < NEAR_RING:
				var tree := flora.node(id, at, s, yaw)
				root.add_child(tree)
				mesh_occluders.append(tree)
				continue
			var shade := clampf(1.0 - (out - NEAR_RING) / (REACH - NEAR_RING) * 0.45, 0.5, 1.0)
			var v := shade * (0.9 + float(pick % 17) / 80.0)
			var bucket := near
			if out >= FAR_DETAIL:
				bucket = far
				id = str((Flora.manifest().get(id, {}) as Dictionary).get("far", id))
			if not bucket.has(id):
				bucket[id] = []
			(bucket[id] as Array).append([Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at), Color(v, v, v)])
		y += step
	Flora.plant_all(root, near, true, "Trees")
	Flora.plant_all(root, far, false, "FarTrees")


## Ground plants over the land near the map: ferns, grass and undergrowth on the forest ground, thinning out to the
## set's land_reach, reeds and sedge along the shores, nothing on the roads.
func _flora_ground() -> void:
	var land := flora.spec.get("land", []) as Array
	var shore := flora.spec.get("shore", []) as Array
	var reach := float(flora.spec.get("land_reach", 14.0))
	var items := {}
	for j in _nz:
		for i in _nx:
			var out := _dist[j * _nx + i]
			if out <= 0.0 or out > reach:
				continue
			var p := Vector2(i - REACH + 0.5, j - REACH + 0.5)
			if _land_kind(p) != Edge.FOREST or (mists != "" and _beyond(p, mists)):
				continue
			var by_water := false
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				if _land_kind(p + d) == Edge.WATER:
					by_water = true
			var list := shore if by_water and not shore.is_empty() else land
			var n := Flora.density(list) * lerpf(1.0, 0.35, out / reach)
			var count := floori(n) + (1 if flora.rng.randf() < n - floorf(n) else 0)
			for q in count:
				var id := flora.pick_from(list)
				if id == "":
					continue
				var at := p + Vector2(flora.rng.randf_range(-0.5, 0.5), flora.rng.randf_range(-0.5, 0.5))
				if not items.has(id):
					items[id] = []
				(items[id] as Array).append(flora.ground_item(Vector3(at.x, surface_y(at) - 0.02, at.y), 1.0))
	Flora.plant_all(root, items, false, "Plants")


## Where the map's water is, for the water's shore and depth: one texel per square, 0 on land rising to 1 four
## squares out into the water.
static func water_mask(grid: CombatGrid) -> ImageTexture:
	var img := Image.create(grid.width, grid.depth, false, Image.FORMAT_R8)
	var dist := {}
	var todo: Array[Vector2i] = []
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			if not grid.has_flag(c, CombatGrid.WATER):
				dist[c] = 0
				todo.append(c)
	var i := 0
	while i < todo.size():
		var c := todo[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if grid.in_bounds(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				todo.append(n)
	for z in grid.depth:
		for x in grid.width:
			var v := clampf(float(dist.get(Vector2i(x, z), 4)) / 4.0, 0.0, 1.0)
			img.set_pixel(x, z, Color(v, v, v))
	return ImageTexture.create_from_image(img)
