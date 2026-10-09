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
## How far past the edge (squares) natural ground at the map's edge takes to settle into the land.
const TERRAIN_SETTLE := 8.0

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
## What lies past the edge, seen when the camera tilts toward the horizon (Vista, W13); null in Classic.
var vista: Vista = null
## What building this land took, phase by phase (milliseconds), for the frame budget's checks.
var build_ms: Dictionary = {}
## A place's land is built on every arrival, and comes out the same each time (its randomness is seeded by the
## place): what a build works out is kept for the newest KEEP places and drawn again from that on the next visit.
## Each entry: its key (the place, the look, the board's shape) -> {"fields", "terrain", "map", "trees", "plants"}.
const KEEP := 8
static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []
var _key := ""
## What this build reuses (from an earlier visit) or works out and keeps.
var _snap: Dictionary = {}
var _woods_material: Material = null
var _ground: Array[MeshInstance3D] = []
var _map_plants: Array[Node] = []
var _edge: Dictionary = {}      ## border cell -> Edge
var _w := 0
var _d := 0
## Empty squares on the map (' ') are hillside like the land around it, unless the mood says they're a drop (a
## chasm, a cliff) or the map has a fall off its edge (`drop_ft`).
var _void_land := true
## Over the whole area the land covers, one cell per square from (-REACH, -REACH): how far each is from the map's own
## squares (`_dist`) and from the squares people walk on (`_walk`), in squares.
var _dist := PackedFloat32Array()
var _walk := PackedFloat32Array()
## Each cell's kind (Edge, or -1 on the map's own squares) and its distance from the roads out, in squares.
var _kinds := PackedInt32Array()
var _road_d := PackedFloat32Array()
var _nx := 0
var _nz := 0
## The land mesh's corner heights ((_nx + 1) x (_nz + 1), from (-REACH, -REACH)), so plants stand on it exactly.
var _corner_h := PackedFloat32Array()


## Whether a place's map falls away past its empty squares (its `drop_ft`, the fall the rules use): those squares
## are then a drop, never hillside. At the Amber Temple's doors (a land mood) the hillside rose 12 squares high over
## the empty squares between the camera and the arrival, and the party was drawn under it (UI QA W-07).
static func has_drop(place: String) -> bool:
	var loc := Compendium.shared().get_entry("locations", place) if place != "" else {}
	return float((loc.get("map", {}) as Dictionary).get("drop_ft", 0.0)) > 0.0


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
	l._void_land = str(l.spec.get("void", "land")) == "land" and not has_drop(board_.place)
	var t := Time.get_ticks_usec()
	l._key = "%s|%s|%dx%d|%d|%d" % [board_.place, Look.style(), l._w, l._d, board_.occupied.size(),
		board_.house_cells.size()]
	var known := _kept.has(l._key)
	l._snap = _kept.get(l._key, {}) as Dictionary
	if l._snap.has("fields"):
		var f := l._snap["fields"] as Array
		l._edge = f[0] as Dictionary
		l._dist = f[1] as PackedFloat32Array
		l._walk = f[2] as PackedFloat32Array
		l._kinds = f[3] as PackedInt32Array
		l._road_d = f[4] as PackedFloat32Array
		l._nx = int(f[5])
		l._nz = int(f[6])
	else:
		l._classify()
		l._distances()
		l._snap["fields"] = [l._edge, l._dist, l._walk, l._kinds, l._road_d, l._nx, l._nz]
	var loc := Compendium.shared().get_entry("locations", board_.place) if board_.place != "" \
		and Compendium.shared().has("locations", board_.place) else {}
	t = l._lap("fields", t)
	if GroundRelief.enabled():
		l.relief = GroundRelief.build(board_, loc)
		Clutter.ruts(board_, l.relief.roads())   # wheel-rut decals along its roads (lane 7's W10)
	t = l._lap("relief", t)
	l._terrain()
	t = l._lap("terrain", t)
	if l.relief != null:
		l.relief.quiet_floors()
		l._woods_material = Look.cel_textured(str(l.spec.get("ground", "village/grass")))
		l._ground = l.relief.meshes(l._woods_material)
		for mi in l._ground:
			l.root.add_child(mi)
	t = l._lap("shaped_ground", t)
	var mood_id := Atmosphere.mood_for(board_.place, loc) if not loc.is_empty() else ""
	if Flora.enabled():
		l.flora = Flora.for_place(board_, mood_id, mood)
		l._flora_board_trees()
		t = l._lap("map_trees", t)
		if l._snap.has("map"):
			l.flora.map_items = (l._snap["map"] as Array)[0] as Dictionary
			l.flora.map_made = (l._snap["map"] as Array)[1] as Array
		else:
			l.flora.dress_map(board_, l.map_y, _trap_cells(loc))
		l._map_plants = l.flora.plant_map(l.root)
		l._snap["map"] = [l.flora.map_items, l.flora.map_made]
		t = l._lap("map_plants", t)
	if float(l.spec.get("trees", 0.0)) > 0.0:
		if l.flora != null:
			l._flora_trees()
		else:
			l._trees()
	t = l._lap("land_trees", t)
	if l.flora != null:
		l._flora_ground()
	t = l._lap("land_plants", t)
	if l.relief != null or l.flora != null:
		l.root.add_child(HiddenWatch.new(l))
	if Look.modern():
		# The mountains, Castle Ravenloft and the lake past the edge, seen when the camera tilts up (W13).
		l.vista = Vista.build(board_, Flora.set_for(mood_id))
		if l.vista != null:
			l.root.add_child(l.vista)
	l._lap("vista", t)
	if not known:
		_kept[l._key] = l._snap
		_kept_order.append(l._key)
		while _kept_order.size() > KEEP:
			_kept.erase(_kept_order.pop_front())
	return l


func _lap(phase: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	build_ms[phase] = float(now - since) / 1000.0
	return now


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
	# What each cell of the land is, once (the trees and plants ask for it thousands of times), and how far each is
	# from a road out (the land's trees keep off them).
	var r := int(REACH)
	_kinds.resize(_nx * _nz)
	_road_d.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var c := Vector2i(i - r, j - r)
			var k := -1
			if g.in_bounds(c):
				if _is_void(c):
					k = Edge.FOREST if _void_land else Edge.DROP
			else:
				k = edge_at(Vector2(i - r + 0.5, j - r + 0.5))
			_kinds[j * _nx + i] = k
			_road_d[j * _nx + i] = 0.0 if k == Edge.OPEN else 1e6
	_road_d = _chamfered(_road_d)


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
	if _snap.has("terrain"):
		var kept := _snap["terrain"] as Array
		_corner_h = kept[0] as PackedFloat32Array
		_land_node(kept[1] as ArrayMesh, kept[2] as Array)
		return
	var r := int(REACH)
	var nx := _nx
	var nz := _nz
	var kinds := _kinds
	var terrain := board.has_terrain()
	# Corner heights: water or a drop next to a corner pins it down; a road beside it flattens it; a corner touching
	# the map's own squares sits level with its floor (or the shaped ground's, W11).
	var heights := PackedFloat32Array()
	heights.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var p := Vector2(i - r, j - r)
			var water := false
			var road := 0
			var on_map := false
			var near := 1e6
			for q in 4:
				var qi: int = i - 1 + (q & 1)
				var qj: int = j - 1 + (q >> 1)
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
			var edge := p.clamp(Vector2.ZERO, Vector2(_w, _d))
			if relief != null and not water and near < 3.5:
				# The banks under the map's woods carry on past its edge and settle into the land.
				var bank := relief.shape(edge)
				h += bank * (1.0 - smoothstep(0.5, 3.5, near)) * (1.0 - float(road) / 4.0)
			if on_map:
				h = _map_corner(Vector2i(i - r, j - r))
			elif water:
				h = WATER_Y
			else:
				if road > 0:
					h *= 1.0 - 0.8 * float(road) / 4.0
				var cell := Vector2i(clampi(floori(edge.x), 0, _w - 1), clampi(floori(edge.y), 0, _d - 1))
				if terrain and board.grid.has_flag(cell, CombatGrid.NATURAL):
					# Natural ground (an empty hillside square on the map, or the map's edge: a slope, a climbing road)
					# carries on past the edge and settles into the land.
					var out := maxf(absf(p.x - edge.x), absf(p.y - edge.y))
					h = lerpf(board.ground_y(edge), h, smoothstep(0.0, TERRAIN_SETTLE, out))
			heights[j * (nx + 1) + i] = h
	_corner_h = heights
	# One grid of corners, smooth normals across it, and a list of squares per surface (ground, road, water): built
	# as arrays rather than vertex by vertex, since a place is built on every arrival.
	var w1 := nx + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(w1 * (nz + 1))
	normals.resize(w1 * (nz + 1))
	for j in nz + 1:
		for i in w1:
			var k := j * w1 + i
			verts[k] = Vector3(i - r, heights[k], j - r)
			var dx := heights[j * w1 + mini(i + 1, nx)] - heights[j * w1 + maxi(i - 1, 0)]
			var dz := heights[mini(j + 1, nz) * w1 + i] - heights[maxi(j - 1, 0) * w1 + i]
			normals[k] = Vector3(-dx, 2.0, -dz).normalized()
	var flat := verts.duplicate()
	var up := PackedVector3Array()
	up.resize(flat.size())
	for k in flat.size():
		var v := flat[k]
		v.y = WATER_Y
		flat[k] = v
		up[k] = Vector3.UP
	var mesh := ArrayMesh.new()
	var mats: Array[Material] = []
	var ground := Look.cel_textured(str(spec.get("ground", "village/grass")))
	var road := Look.cel_textured(str(spec.get("road", spec.get("ground", "village/mud_road"))))
	for kind: int in [Edge.FOREST, Edge.OPEN, Edge.WATER]:
		var idx := _quads(kinds, kind, nx, nz)
		if idx.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = flat if kind == Edge.WATER else verts
		arrays[Mesh.ARRAY_NORMAL] = up if kind == Edge.WATER else normals
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m: Material = ground if kind == Edge.FOREST else (road if kind == Edge.OPEN else water_material)
		mats.append(m if m != null else Look.cel("bog_deep"))
	_snap["terrain"] = [heights, mesh, mats]
	_land_node(mesh, mats)


func _land_node(mesh: ArrayMesh, mats: Array) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Land"
	mi.mesh = mesh
	for i in mats.size():
		mi.set_surface_override_material(i, mats[i] as Material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## The corner indices of every square of `kind`, two triangles each (one pass to count, one to fill, so the array is
## never copied as it grows).
static func _quads(kinds: PackedInt32Array, kind: int, nx: int, nz: int) -> PackedInt32Array:
	var n := 0
	for k in nx * nz:
		if kinds[k] == kind:
			n += 1
	var idx := PackedInt32Array()
	idx.resize(n * 6)
	var f := 0
	var w1 := nx + 1
	for j in nz:
		for i in nx:
			if kinds[j * nx + i] != kind:
				continue
			var a := j * w1 + i
			idx[f] = a
			idx[f + 1] = a + 1
			idx[f + 2] = a + w1
			idx[f + 3] = a + 1
			idx[f + 4] = a + w1 + 1
			idx[f + 5] = a + w1
			f += 6
	return idx


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

## The ground's height at a point on the map's own squares: its banks (0 where people walk, and in Classic), on
## natural ground's slopes where the map has them (the board's own columns where the shaped ground doesn't draw).
func map_y(p: Vector2) -> float:
	if not board.has_terrain():
		return relief.height(p) if relief != null else 0.0
	var c := Vector2i(clampi(floori(p.x), 0, _w - 1), clampi(floori(p.y), 0, _d - 1))
	return relief.height(p) if relief != null and relief.draws(c) else board.ground_y(p)


## Where the land meets the map at grid point `p`: on the map's own floor or shaped ground; on a map with natural
## ground, level with the lowest of the map's own squares there (the others' sides fill the step), so the land never
## hangs above an edge.
func _map_corner(p: Vector2i) -> float:
	if not board.has_terrain():
		return relief.height(Vector2(p)) if relief != null else 0.0
	var low := INF
	for o: Vector2i in [p + Vector2i(-1, -1), p + Vector2i(0, -1), p + Vector2i(-1, 0), p]:
		if not board.grid.in_bounds(o) or _is_void(o):
			continue
		var y := relief.height(Vector2(p)) if relief != null and relief.draws(o) else board.corner_height(o, p - o)
		low = minf(low, y)
	return low if low < INF else map_y(Vector2(p))


## Squares a location's traps lie on (a pit opens there): no plant grows on them.
static func _trap_cells(loc: Dictionary) -> Dictionary:
	var out := {}
	for t: Variant in loc.get("traps", []) as Array:
		var trap := t as Dictionary
		var cells := trap.get("cells", []) as Array
		if trap.has("cell"):
			cells = cells + [trap["cell"]]
		for c: Variant in cells:
			var a := c as Array
			if a.size() >= 2:
				out[Vector2i(int(a[0]), int(a[1]))] = true
	return out


## Redraws what the land puts on the map's own squares (the shaped ground, the ground plants), leaving out the squares
## HiddenAreas hides.
func respect_hidden(hidden: Dictionary) -> void:
	if relief != null:
		for mi in _ground:
			if is_instance_valid(mi):
				root.remove_child(mi)
				mi.queue_free()
		_ground = relief.meshes(_woods_material, hidden)
		for mi in _ground:
			root.add_child(mi)
	if flora != null:
		for n in _map_plants:
			if is_instance_valid(n):
				root.remove_child(n)
				n.queue_free()
		_map_plants = flora.plant_map(root, hidden)


## Watches the place's hidden areas (rooms behind secret doors nobody has found, "hidden until found") and keeps the
## land's own pieces on those squares out of sight, as HiddenAreas does the board's.
class HiddenWatch extends Node:
	var land: AtmosphereLand
	var _seen := 0
	var _wait := 0.0

	func _init(l: AtmosphereLand) -> void:
		land = l
		name = "HiddenWatch"
		_seen = hash([])

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0:
			return
		_wait = HiddenAreas.CHECK_EVERY
		var atmo := land.root.get_parent()
		var view := atmo.get_parent() as LocationView if atmo != null else null
		var areas := HiddenAreas.of(view)
		var hidden := areas.hidden if areas != null else {}
		var seen := hash(hidden.keys())
		if seen != _seen:
			_seen = seen
			land.respect_hidden(hidden)


# --- The Modern look's trees and plants (Flora, Improvement Ideas W9) -----------------------------------------------

## Beyond this many squares from the map the land's trees are their lighter far copies.
const FAR_DETAIL := 9.0
## Only trees within this many squares of where people walk cast the sun's shadow: the rest are too far out to shade
## anything anyone looks at, and every shadow split draws every tree that casts (lane 6's frame budget, W17).
const SHADOW_REACH := 3.0


## How far a point is from the squares people walk on (squares).
func walk_distance(p: Vector2) -> float:
	var k := _cell(p)
	return REACH if k < 0 else _walk[k]


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
	var k := _cell(p)
	if k >= 0:
		return _kinds[k]
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
		var tree := Flora.instance(id, flora.tree_scale(id, "map", pick))
		if walk_distance(Vector2(holder.position.x, holder.position.z)) > SHADOW_REACH:
			tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(tree)
		holder.set_meta("model", id)
		# Up on the bank under the woods (W11), a little sunk so its foot never shows a gap.
		holder.position.y = map_y(Vector2(holder.position.x, holder.position.z)) - 0.05


## The land's trees as _trees() places them, from Flora: the first rows each a node of its own that fades like the
## map's trees, the rest drawn many at once (the furthest as their lighter copies), darker further out as before.
## Flora's trees are fuller than the old ones, so they stand further apart (the set's tree_density).
func _flora_trees() -> void:
	if _snap.has("trees"):
		var kept := _snap["trees"] as Array
		for rec: Array in kept[0] as Array:
			_ring_tree(str(rec[0]), rec[1] as Vector3, float(rec[2]), float(rec[3]), bool(rec[4]))
		Flora.replant(root, kept[1] as Array)
		return
	var ring := []
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
			if _road_d[k] < 1.6:
				continue
			var pick := ModelPiece.hash_cell(Vector2i(floori(p.x * 3.0), floori(p.y * 3.0)))
			var id := flora.tree_for(kind, pick)
			if id == "":
				continue
			var s := flora.tree_scale(id, "land", pick)
			var yaw := float(pick % 360) * PI / 180.0
			var at := Vector3(p.x, surface_y(p) - 0.05, p.y)
			if out < NEAR_RING:
				ring.append([id, at, s, yaw, _walk[k] <= SHADOW_REACH])
				_ring_tree(id, at, s, yaw, _walk[k] <= SHADOW_REACH)
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
	# Every tree drawn many at once stands at least NEAR_RING squares out, past SHADOW_REACH: none casts.
	var made := Flora.plant_all(root, near, false, "Trees")
	made.append_array(Flora.plant_all(root, far, false, "FarTrees"))
	_snap["trees"] = [ring, made]


## One of the land's first rows of trees, a node of its own that fades like the map's.
func _ring_tree(id: String, at: Vector3, s: float, yaw: float, shadow: bool) -> void:
	var tree := flora.node(id, at, s, yaw)
	if not shadow:
		(tree.get_child(0) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tree)
	mesh_occluders.append(tree)


## Ground plants over the land near the map: ferns, grass and undergrowth on the forest ground, thinning out to the
## set's land_reach, reeds and sedge along the shores, nothing on the roads.
func _flora_ground() -> void:
	if _snap.has("plants"):
		Flora.replant(root, _snap["plants"] as Array)
		return
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
	_snap["plants"] = Flora.plant_all(root, items, false, "Plants")


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
