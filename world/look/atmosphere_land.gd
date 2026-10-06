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
	l._terrain()
	if float(l.spec.get("trees", 0.0)) > 0.0:
		l._trees()
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
			var walk := g.in_bounds(c) and not g.has_flag(c, CombatGrid.WALL) and not g.has_flag(c, CombatGrid.VOID)
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
			if on_map:
				h = 0.0
			elif water:
				h = WATER_Y
			elif road > 0:
				h *= 1.0 - 0.8 * float(road) / 4.0
			heights[j * (nx + 1) + i] = h
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
