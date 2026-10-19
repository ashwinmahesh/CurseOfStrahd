class_name Crags
extends RefCounted
## A place's rock walls as one shaped mountain (catalog place_looks `rock_shape: "crags"`, Modern only; owner
## 2026-10-19: "why are all of our mountain tops flat? ... Things should look natural"). `rock_walls` drew every '#' as
## its own flat-topped box, so a mountain's crags were a field of square pillars. Here the board's rock squares share
## one surface instead: it rises out of the ground the party walks on in a steep, ragged face, climbs the deeper the
## rock runs (the land past the map's edge counts as more mountain) and breaks into ridges, peaks and saddles from
## seeded noise, so no two places come out alike. Each square still gets its own piece of that surface (the patch over
## it), so a crag fades in the party's way like the old columns did and a prop can still take its square.
## The face's foot bends both ways (the plan's rule 2): in under the rock, and out over the walkable squares beside it
## by a quarter of a square at most, with a low scree apron round it that is gone by half a square, so the middle of a
## walkable square beside the rock stays clear.
## Cosmetic only: the rules grid never sees any of it.
## A place is built on every arrival, and comes out the same each time (its randomness is seeded by the place): what
## `plan` works out, and each square's mesh, are kept for the newest KEEP places and drawn again on the next visit.

## Grid points per square: the surface's triangles are a quarter square across (RES_SHIFT is its log2: a point's
## square is its index >> RES_SHIFT).
const RES := 4
const RES_SHIFT := 2
## The face's height (world units) a short way in from the open ground, and how quickly it gets there (squares).
const FACE := 1.5
const FACE_IN := 0.32
## How much higher the rock climbs for each square deeper into it, and the depth past which it climbs no more.
const CLIMB := 0.62
const DEEP := 7.0
## How far in from the open ground the face's foot may wander (squares), so it never runs straight along the grid.
const FOOT_WANDER := 0.65
## How far the foot may also reach out over the walkable squares beside the rock (owner 2026-10-19: "natural edges can
## bend into a square the party can stand on"; the plan's rule 2): a rock face is taller than a knee, so a quarter of a
## square at most, which leaves a token in the square's middle and its ring clear.
const FOOT_OUT := 0.25
## The scree at the foot: a low apron of the place's rock that reaches out up to half a square from the grid line (at
## the walkable square's middle it is gone) and stands no higher than this (below a token's knee).
const SCREE := 0.14
const SCREE_REACH := 0.5
## How much of its `crag_floor` a thin band's crest stands at in the saddles and at the peaks.
const CREST_LOW := 0.55
const CREST_HIGH := 1.2
## How far (world units) the ground beside a rock square may stand from the rock's own level for its foot to spread onto it.
const MARGIN_STEP := 0.5
## Where the surface is this low or lower it tucks under the ground beside it.
const TUCK := 0.04
## How far (squares) the face's line is bent off the grid.
const WARP := 0.55
## How far (squares) past the map's edge the rock carries on before it settles into the land (N8).
const BEYOND := 8.0
## Boulders along the foot (owner 2026-10-19, rule 2: "scree and boulders up to half a square"): on average this many
## per side of a rock square that a walkable square touches, none reaching further than BOULDER_REACH (squares from the
## grid line, so never into the middle of the square) with a radius in this range and no taller than BOULDER_TALL
## (world units, below a token's knee), and a big one now and then.
const BOULDERS_A_SIDE := 2.0
const BOULDER_REACH := 0.5
const BOULDER_RADIUS := Vector2(0.1, 0.26)
const BOULDER_BIG := 0.34
const BOULDER_TALL := 0.32
## How many places' plans and meshes are kept.
const KEEP := 8
const FAR := 1e6

static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []
## What the last plan took, phase by phase (milliseconds), for the frame budget's checks.
static var plan_ms: Dictionary = {}

var board: ArenaBoard
var cells: Dictionary = {}
var _w := 0
var _d := 0
var _nx := 0   ## grid points across (_w * RES + 1)
var _nz := 0
## The surface's height (world units, from the ground under it) at every grid point, and the ground's under it. Only
## the points of the rock squares and the squares beside them are worked out: the rest stay tucked at zero.
var _h := PackedFloat32Array()
var _base := PackedFloat32Array()
var _n := PackedVector3Array()   ## the surface's normal at every grid point
var _rng := RandomNumberGenerator.new()
## The place look's `crag_floor` (world units: no point more than half a square in from open ground stands lower, so a
## thin band of rock stays a ridge instead of breaking into lone spikes) and `crag_scale` (a multiplier on every height
## above the ground: the castle gates' rock stays under the castle).
var _floor := 0.0
var _scale := 1.0
## Rock square -> the quads (j * the grid's width in quads + i) of the walkable squares round it that its face and scree
## reach into, drawn with that square's piece (each such quad has one owner).
var _margin: Dictionary = {}
## Rock square -> its mesh and how high it stands, made the first time its piece is asked for.
var _meshes: Dictionary = {}
## Rock square -> its boulders: [centre (x, y, z), radius, height, seed], on the walkable squares it touches.
var _boulders: Dictionary = {}
## A unit icosahedron's 20 faces, three corners each, made once for every boulder.
static var _ico: Array = []
## The rock's height along each side of the map's edge, for the range that carries on past it (N8): four arrays, one
## value a quarter square (0 north, 1 east, 2 south, 3 west), made the first time they are asked for.
var _edge_prof: Array = []
var _beyond_noise: FastNoiseLite = null


## Plans the surface over `cells` (square -> true), the board's rock squares, once for the whole board (or takes the
## plan kept from an earlier visit). `look` is the place's look: `crag_floor` and `crag_scale`.
static func plan(board_: ArenaBoard, cells_: Dictionary, look: Dictionary = {}) -> Crags:
	var floor_ := float(look.get("crag_floor", 0.0))
	var scale_ := float(look.get("crag_scale", 1.0))
	var key := "%s|%d|%d|%s|%s|%d" % [board_.place, board_.grid.width, board_.grid.depth, floor_, scale_, cells_.keys().hash()]
	if _kept.has(key):
		var kept := _kept[key] as Crags
		kept.board = board_
		_kept_order.erase(key)
		_kept_order.append(key)
		plan_ms = {"kept": 0.0}
		return kept
	var k := Crags.new()
	k.board = board_
	k.cells = cells_
	k._floor = floor_
	k._scale = scale_
	k._w = board_.grid.width
	k._d = board_.grid.depth
	k._nx = k._w * RES + 1
	k._nz = k._d * RES + 1
	k._rng.seed = hash(board_.place)
	k._heights()
	_kept[key] = k
	_kept_order.append(key)
	while _kept_order.size() > KEEP:
		_kept.erase(_kept_order.pop_front())
	return k


func _heights() -> void:
	var t0 := Time.get_ticks_usec()
	var n := _nx * _nz
	# The squares that matter: the rock and the squares beside it (the surface only ever rises over those). `live`
	# marks their grid points, `touched` what touches each (1 an open square, 2 a rock square: a point touched by both
	# is on the rock's edge).
	var act := PackedByteArray()
	act.resize(_w * _d)
	for c: Vector2i in cells:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if c.x + dx >= 0 and c.y + dz >= 0 and c.x + dx < _w and c.y + dz < _d:
					act[(c.y + dz) * _w + c.x + dx] = 1
	var live := PackedByteArray()
	var touched := PackedByteArray()
	live.resize(n)
	touched.resize(n)
	for sz in _d:
		for sx in _w:
			if act[sz * _w + sx] == 0:
				continue
			var kind := 2 if cells.has(Vector2i(sx, sz)) else 1
			for b in RES + 1:
				var row := (sz * RES + b) * _nx + sx * RES
				for a in RES + 1:
					touched[row + a] |= kind
					live[row + a] = 1
	var pts := PackedInt32Array()
	var pis := PackedInt32Array()
	var pjs := PackedInt32Array()
	for j in _nz:
		for i in _nx:
			if live[j * _nx + i] != 0:
				pts.append(j * _nx + i)
				pis.append(i)
				pjs.append(j)
	var t1 := Time.get_ticks_usec()
	# Each point's distance (squares) to the rock's edge, a two-pass chamfer sweep (1 along, 1.414 across) in grid steps
	# over those points, then one signed depth: into the rock, negative out over the open ground. The land past the map's
	# edge counts as rock (the mountain carries on), so the map's own edge is no edge of the rock.
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(FAR)
	for q in pts:
		if touched[q] == 3:
			dist[q] = 0.0
	var s := 1.0 / RES
	var diag := s * sqrt(2.0)
	for k in pts:
		var i := k % _nx
		var v := dist[k]
		if i > 0:
			v = minf(v, dist[k - 1] + s)
		if k >= _nx:
			v = minf(v, dist[k - _nx] + s)
			if i > 0:
				v = minf(v, dist[k - _nx - 1] + diag)
			if i < _nx - 1:
				v = minf(v, dist[k - _nx + 1] + diag)
		dist[k] = v
	for idx in range(pts.size() - 1, -1, -1):
		var k := pts[idx]
		var i := k % _nx
		var v := dist[k]
		if i < _nx - 1:
			v = minf(v, dist[k + 1] + s)
		if k < n - _nx:
			v = minf(v, dist[k + _nx] + s)
			if i < _nx - 1:
				v = minf(v, dist[k + _nx + 1] + diag)
			if i > 0:
				v = minf(v, dist[k + _nx - 1] + diag)
		dist[k] = v
	var depth := PackedFloat32Array()
	depth.resize(n)
	depth.fill(-1.0)
	for k in pts:
		depth[k] = dist[k] if touched[k] == 2 else -dist[k]
	var t2 := Time.get_ticks_usec()
	# Noise, seeded by the place, one value a grid point: broad swells (which stretches are peaks, which saddles), ridges
	# along them, a little roughness on top, how sheer the face is along its length (buttresses and gullies), a warp that
	# bends the face's line off the grid and the scree's thickness. Each is 0..255 over -1..1.
	var mass := _field(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.075, 1)
	var ridge := _field(FastNoiseLite.TYPE_SIMPLEX, 0.14, 2, FastNoiseLite.FRACTAL_RIDGED)
	var rough := _field(FastNoiseLite.TYPE_SIMPLEX, 0.9, 1)
	var sheer := _field(FastNoiseLite.TYPE_SIMPLEX, 0.32, 1)
	var foot := _field(FastNoiseLite.TYPE_SIMPLEX, 0.6, 2)
	var warp_x := _field(FastNoiseLite.TYPE_SIMPLEX, 0.45, 2)
	var warp_z := _field(FastNoiseLite.TYPE_SIMPLEX, 0.45, 2)
	var scree := _field(FastNoiseLite.TYPE_SIMPLEX, 1.1, 2)
	var scree_b := _field(FastNoiseLite.TYPE_SIMPLEX, 0.8, 2)
	var t3 := Time.get_ticks_usec()
	_h.resize(n)
	_h.fill(-TUCK)
	_base.resize(n)
	var unit := 1.0 / 255.0
	for idx in pts.size():
		var k := pts[idx]
		var x := float(pis[idx]) / RES
		var z := float(pjs[idx]) / RES
		_base[k] = _ground(x, z)
		var u0 := depth[k]
		if u0 <= -SCREE_REACH:
			continue   # too far out over open ground for the foot or the scree to reach
		# How deep into the rock this point lies, read through the warp, so the face bends in and out. The face's foot
		# wanders from a quarter square out over the open ground to well in under the rock (never further out than that,
		# whatever the warp says), and the face stands where the point is deeper than the foot.
		var uw := _sample(depth, x + WARP * (warp_x[k] * unit * 2.0 - 1.0), z + WARP * (warp_z[k] * unit * 2.0 - 1.0))
		var shift := lerpf(-FOOT_OUT, FOOT_WANDER, foot[k] * unit)
		var t := minf(uw - shift, u0 + FOOT_OUT)
		var h := 0.0
		if t > 0.0:
			var m := mass[k] * unit            # 0..1: saddle to peak
			var r := ridge[k] * unit           # ridged: crests along the mass
			var face_in := lerpf(FACE_IN, FACE_IN * 4.0, sheer[k] * unit)
			var face := FACE * (1.0 - exp(-t / face_in))
			var climb := CLIMB * minf(t, DEEP) * (0.35 + 1.3 * m * m)
			h = (face + climb) * (0.78 + 0.44 * r) + 0.1 * (rough[k] * unit * 2.0 - 1.0) * minf(t, 1.0)
			h *= smoothstep(0.0, 0.2, t)   # down to the ground where the foot is
		if u0 > 0.0 and _floor > 0.0:
			# A thin band of rock keeps its height: half a square in from open ground it stands at least this tall, less
			# at the saddles and more at the peaks along its crest, and the crest meanders with the warp.
			var crest := lerpf(CREST_LOW, CREST_HIGH, 0.45 * mass[k] * unit + 0.55 * sheer[k] * unit)
			h = maxf(h, _floor * crest * smoothstep(0.0, 0.5, maxf(uw, 0.0)))
		h *= _scale
		# The scree apron: a low skirt round the foot that thins to nothing out over the open ground, and is gone by
		# the middle of the walkable square beside it.
		var spread := lerpf(0.12, SCREE_REACH - FOOT_OUT, scree[k] * unit)
		var skirt := SCREE * lerpf(0.55, 1.0, scree_b[k] * unit) * (1.0 - smoothstep(0.0, spread, maxf(-t, 0.0)))
		skirt *= 1.0 - smoothstep(0.3, SCREE_REACH, maxf(-u0, 0.0))
		h = maxf(h, skirt)
		_h[k] = h if h > TUCK else -TUCK
	var t4 := Time.get_ticks_usec()
	_normals(pts, pis, pjs)
	_reach_into_open_squares(act)
	_scatter_boulders()
	var t5 := Time.get_ticks_usec()
	plan_ms = {"squares": (t1 - t0) / 1000.0, "distance": (t2 - t1) / 1000.0, "noise": (t3 - t2) / 1000.0,
		"heights": (t4 - t3) / 1000.0, "normals": (t5 - t4) / 1000.0}


## One noise field over the whole grid, a byte a grid point (0..255 for -1..1), from the place's seed.
func _field(kind: int, frequency: float, octaves: int, fractal: int = FastNoiseLite.FRACTAL_FBM) -> PackedByteArray:
	var f := FastNoiseLite.new()
	f.seed = _rng.randi()
	f.noise_type = kind
	f.frequency = frequency / RES   # per grid point: frequency per square
	f.fractal_type = fractal if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	f.fractal_octaves = octaves
	return f.get_image(_nx, _nz, false, false, false).get_data()


## `field` (one value a grid point) at point (x, z) in squares, read between its points.
func _sample(field: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x * RES, 0.0, _nx - 1.001)
	var fz := clampf(z * RES, 0.0, _nz - 1.001)
	var i := floori(fx)
	var j := floori(fz)
	var u := fx - i
	var v := fz - j
	var k := j * _nx + i
	return lerpf(lerpf(field[k], field[k + 1], u), lerpf(field[k + _nx], field[k + _nx + 1], u), v)


## Smooth normals over the whole surface, the same at a point every piece shares, so the pieces shade as one.
func _normals(pts: PackedInt32Array, pis: PackedInt32Array, pjs: PackedInt32Array) -> void:
	_n.resize(_nx * _nz)
	for idx in pts.size():
		var i := pis[idx]
		var j := pjs[idx]
		var l := _at(maxi(i - 1, 0), j)
		var r := _at(mini(i + 1, _nx - 1), j)
		var u := _at(i, maxi(j - 1, 0))
		var d := _at(i, mini(j + 1, _nz - 1))
		_n[pts[idx]] = (d - u).cross(r - l).normalized()


## The height (world units) of the ground under point (x, z): the board's own (natural ground's slope, else floor).
func _ground(x: float, z: float) -> float:
	var p := Vector2(clampf(x, 0.001, _w - 0.001), clampf(z, 0.001, _d - 0.001))
	var here := Vector2i(floori(p.x), floori(p.y))
	var g := board.grid
	if not (g.has_flag(here, CombatGrid.VOID) or g.has_flag(here, CombatGrid.WATER)):
		return board.ground_y(p)
	# A point on the edge of a drop or a lake belongs to the empty square too, whose ground isn't the rock's: take the
	# ground of the squares that touch it that people can stand on.
	var total := 0.0
	var count := 0
	for dz: int in [-1, 0]:
		for dx: int in [-1, 0]:
			var o := Vector2i(floori(x) + dx, floori(z) + dz)
			if not g.in_bounds(o) or g.has_flag(o, CombatGrid.VOID) or g.has_flag(o, CombatGrid.WATER):
				continue
			total += board.ground_y(Vector2(clampf(x, o.x + 0.001, o.x + 0.999), clampf(z, o.y + 0.001, o.y + 0.999)))
			count += 1
	return total / count if count > 0 else board.ground_y(p)


func _at(i: int, j: int) -> Vector3:
	var k := j * _nx + i
	return Vector3(float(i) / RES, _base[k] + _h[k], float(j) / RES)


## Gives each quad of a walkable square that the face or the scree rises into to the rock square nearest it, so that
## square's piece draws it (and it fades with that piece).
func _reach_into_open_squares(act: PackedByteArray) -> void:
	_margin.clear()
	var qw := _w * RES
	for sz in _d:
		for sx in _w:
			var sq := Vector2i(sx, sz)
			if act[sz * _w + sx] == 0 or cells.has(sq):
				continue
			if board.grid.has_flag(sq, CombatGrid.VOID) or board.grid.has_flag(sq, CombatGrid.WATER):
				continue   # nobody stands there, and its ground isn't the rock's (a drop's floor, a lake's)
			for b in RES:
				for a in RES:
					var i := sx * RES + a
					var j := sz * RES + b
					var k := j * _nx + i
					if _h[k] <= -TUCK and _h[k + 1] <= -TUCK and _h[k + _nx] <= -TUCK and _h[k + _nx + 1] <= -TUCK:
						continue   # all under the ground: nothing to draw
					var mid := Vector2((i + 0.5) / RES, (j + 0.5) / RES)
					var best := Vector2i(-1, -1)
					var best_d := INF
					for dz in range(-1, 2):
						for dx in range(-1, 2):
							var o := sq + Vector2i(dx, dz)
							if not cells.has(o):
								continue
							var nearest := Vector2(clampf(mid.x, o.x, o.x + 1.0), clampf(mid.y, o.y, o.y + 1.0))
							var dist := mid.distance_squared_to(nearest)
							if dist < best_d:
								best_d = dist
								best = o
					if best.x >= 0:
						# Not down a cliff: where the walkable ground beside the rock is far from the rock's own level
						# the rock doesn't spread onto it (a cliff's foot is CliffFace's).
						var low := (_base[k] + _base[k + 1] + _base[k + _nx] + _base[k + _nx + 1]) / 4.0
						if absf(low - board.floor_y(best)) > MARGIN_STEP:
							continue
						if not _margin.has(best):
							_margin[best] = [] as Array[int]
						(_margin[best] as Array[int]).append(j * qw + i)


## Boulders along the foot: for each side of a rock square that a walkable square touches, one or two (rarely three), a
## little off the grid line and along it, sized and spaced unevenly, seeded by the place.
func _scatter_boulders() -> void:
	_boulders.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(board.place) + 7
	for c: Vector2i in cells:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var o := c + d
			if cells.has(o) or o.x < 0 or o.y < 0 or o.x >= _w or o.y >= _d:
				continue
			var g := board.grid
			if g.has_flag(o, CombatGrid.WALL) or g.has_flag(o, CombatGrid.VOID) or g.has_flag(o, CombatGrid.WATER):
				continue   # nobody stands there
			var count := floori(BOULDERS_A_SIDE) + (1 if rng.randf() < BOULDERS_A_SIDE - floorf(BOULDERS_A_SIDE) else 0)
			if rng.randf() < 0.15:
				count += 1
			for q in count:
				var along := clampf((q + 0.5) / count + rng.randf_range(-0.25, 0.25) / count, 0.05, 0.95)
				var radius := rng.randf_range(BOULDER_RADIUS.x, BOULDER_RADIUS.y)
				if rng.randf() < 0.12:
					radius = BOULDER_BIG
				var out := rng.randf_range(radius * 0.4, BOULDER_REACH - radius * 0.8)
				var tall := minf(radius * rng.randf_range(0.7, 1.15), BOULDER_TALL)
				# The point `out` from the shared side, `along` it: this square's side is the one facing `d`.
				var at := Vector2(c.x + 0.5 + d.x * (0.5 + out) + (1 - absi(d.x)) * (along - 0.5),
						c.y + 0.5 + d.y * (0.5 + out) + (1 - absi(d.y)) * (along - 0.5))
				if not _boulders.has(c):
					_boulders[c] = []
				(_boulders[c] as Array).append([Vector3(at.x, _ground(at.x, at.y) + tall * 0.25, at.y), radius, tall, rng.randi()])


## Adds a boulder to the arrays (relative to `origin`): a unit icosahedron stretched to its size, each corner pushed in or
## out by the boulder's own seed so no two match, faces shaded flat.
static func boulder(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, b: Array, origin: Vector3) -> void:
	if _ico.is_empty():
		var t := (1.0 + sqrt(5.0)) / 2.0
		var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
				Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
				Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
		for i in v.size():
			v[i] = v[i].normalized()
		for f: Array in [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
				[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
				[6, 2, 10], [8, 6, 7], [9, 8, 1]]:
			_ico.append([v[f[0] as int], v[f[1] as int], v[f[2] as int]])
	var at := b[0] as Vector3
	var radius := float(b[1])
	var tall := float(b[2])
	var seed_ := int(b[3])
	var scale := Vector3(radius, tall, radius * lerpf(0.75, 1.0, float(seed_ % 7) / 6.0))
	var spin := float(seed_ % 360) * PI / 180.0
	for face: Array in _ico:
		var p: Array[Vector3] = []
		for corner: Vector3 in face:
			# A different push for each corner, from the seed and where the corner is.
			var push := 0.78 + 0.44 * fposmod(sin(corner.x * 12.9898 + corner.y * 78.233 + corner.z * 37.719 + float(seed_ % 97)) * 43758.5453, 1.0)
			var w := (corner * push * scale).rotated(Vector3.UP, spin)
			w.y = maxf(w.y, -tall * 0.5)   # what's under the ground doesn't matter
			p.append(at + w - origin)
		_tri(verts, norms, uvs, p[0], p[2], p[1])


## The patch of the surface over square `c` as its own piece, standing at the square's middle, in material `mat`.
func piece(c: Vector2i, mat: Material) -> MeshInstance3D:
	if not _meshes.has(c):
		_meshes[c] = _mesh(c)
	var made := _meshes[c] as Array
	var mi := MeshInstance3D.new()
	mi.name = "Crag"
	mi.mesh = made[0] as ArrayMesh
	mi.position = Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	mi.material_override = mat
	mi.set_meta("crag", c)
	mi.set_meta("on_floor", true)   # already on the ground under it (ArenaBoard._lift passes it by)
	# How far from the party a crag this tall still stands in the camera's way (ArenaBoard.fade_occluders).
	mi.set_meta("fade_reach", maxf(4.0, float(made[1]) * 0.8))
	return mi


## Square `c`'s mesh (its own quads of the surface, the walkable squares' quads that go with it, and the face down past
## the ground on each side at the map's edge) and the height of its top.
func _mesh(c: Vector2i) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var origin := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	var top := -INF
	for b in RES:
		for a in RES:
			top = maxf(top, _quad(verts, norms, uvs, c.x * RES + a, c.y * RES + b, origin))
	# The walkable squares' quads that this square's face and scree reach into.
	var qw := _w * RES
	for q: int in _margin.get(c, [] as Array[int]):
		top = maxf(top, _quad(verts, norms, uvs, q % qw, floori(float(q) / qw), origin))
	for bl: Array in _boulders.get(c, []):
		Crags.boulder(verts, norms, uvs, bl, origin)
	# The map's edge, where the rock carries on past it: a face down past the ground on each outer side, so the surface
	# doesn't end in a bare slice.
	for side in 4:
		var d: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
		var o := c + d
		if o.x >= 0 and o.y >= 0 and o.x < _w and o.y < _d:
			continue
		for s in RES:
			var e0: Vector2i
			var e1: Vector2i
			match side:
				0: e0 = Vector2i(c.x * RES + s + 1, c.y * RES); e1 = Vector2i(c.x * RES + s, c.y * RES)
				1: e0 = Vector2i((c.x + 1) * RES, c.y * RES + s + 1); e1 = Vector2i((c.x + 1) * RES, c.y * RES + s)
				2: e0 = Vector2i(c.x * RES + s, (c.y + 1) * RES); e1 = Vector2i(c.x * RES + s + 1, (c.y + 1) * RES)
				_: e0 = Vector2i(c.x * RES, c.y * RES + s); e1 = Vector2i(c.x * RES, c.y * RES + s + 1)
			var a_top := _at(e0.x, e0.y) - origin
			var b_top := _at(e1.x, e1.y) - origin
			var a_low := Vector3(a_top.x, _base[e0.y * _nx + e0.x] - 0.3, a_top.z)
			var b_low := Vector3(b_top.x, _base[e1.y * _nx + e1.x] - 0.3, b_top.z)
			_tri(verts, norms, uvs, a_top, b_top, b_low)
			_tri(verts, norms, uvs, a_top, b_low, a_low)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [mesh, top]


## The quad of the surface at grid cell (i, j), two triangles relative to `origin`, added to the arrays; returns the
## highest point's height.
func _quad(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, i: int, j: int, origin: Vector3) -> float:
	var p00 := _at(i, j) - origin
	var p10 := _at(i + 1, j) - origin
	var p11 := _at(i + 1, j + 1) - origin
	var p01 := _at(i, j + 1) - origin
	var n00 := _n[j * _nx + i]
	var n10 := _n[j * _nx + i + 1]
	var n11 := _n[(j + 1) * _nx + i + 1]
	var n01 := _n[(j + 1) * _nx + i]
	# Alternate the diagonal so the triangles don't line up in rows. Clockwise seen from above (Godot's front faces),
	# with the surface's own normals.
	if (i + j) % 2 == 0:
		_smooth(verts, norms, uvs, p00, p10, p11, n00, n10, n11)
		_smooth(verts, norms, uvs, p00, p11, p01, n00, n11, n01)
	else:
		_smooth(verts, norms, uvs, p00, p10, p01, n00, n10, n01)
		_smooth(verts, norms, uvs, p10, p11, p01, n10, n11, n01)
	return maxf(maxf(p00.y, p10.y), maxf(p11.y, p01.y))


static func _smooth(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
		a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	norms.append(na)
	norms.append(nb)
	norms.append(nc)
	uvs.append(Vector2(a.x, a.z))
	uvs.append(Vector2(b.x, b.z))
	uvs.append(Vector2(c.x, c.z))


## One triangle, clockwise seen from outside (Godot's front faces), shaded flat.
static func _tri(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var nrm := (c - a).cross(b - a).normalized()
	for v: Vector3 in [a, b, c]:
		verts.append(v)
		norms.append(nrm)
		uvs.append(Vector2(v.x, v.z))


## The rock's height along each side of the map's edge: the surface's height at the edge where the square beside it is
## rock, 0 where it isn't, blurred over a square either way so the rock ramps down beside a way out instead of ending
## in a cliff.
func _build_profiles() -> void:
	_edge_prof.clear()
	for side in 4:
		var length := _w if side % 2 == 0 else _d
		var n := length * RES + 1
		var raw := PackedFloat32Array()
		raw.resize(n)
		for t in n:
			var a := minf(float(t) / RES, length - 0.001)
			var cell := Vector2i.ZERO
			var pt := Vector2.ZERO
			match side:
				0:
					cell = Vector2i(floori(a), 0)
					pt = Vector2(a, 0.0)
				1:
					cell = Vector2i(_w - 1, floori(a))
					pt = Vector2(_w, a)
				2:
					cell = Vector2i(floori(a), _d - 1)
					pt = Vector2(a, _d)
				_:
					cell = Vector2i(0, floori(a))
					pt = Vector2(0.0, a)
			raw[t] = maxf(top_at(pt.x, pt.y), 0.0) if cells.has(cell) else 0.0
		var blurred := PackedFloat32Array()
		blurred.resize(n)
		for t in n:
			var sum := 0.0
			for o in range(-RES, RES + 1):
				sum += raw[clampi(t + o, 0, n - 1)]
			blurred[t] = sum / (2 * RES + 1)
		_edge_prof.append(blurred)


## The rock's height along `side` of the map's edge at `along` squares from its start, read between its values.
func _profile(side: int, along: float) -> float:
	if _edge_prof.is_empty():
		_build_profiles()
	var arr := _edge_prof[side] as PackedFloat32Array
	var f := clampf(along * RES, 0.0, arr.size() - 1.001)
	var i := floori(f)
	return lerpf(arr[i], arr[i + 1], f - i)


## How high (world units above the ground) the rock stands at point `p` on the map's edge line, where the land past the
## edge starts (0 anywhere else, and where the edge square beside it isn't rock).
func edge_rise(p: Vector2) -> float:
	if p.y == 0.0 and p.x >= 0.0 and p.x <= _w:
		return _profile(0, p.x)
	if p.y == _d and p.x >= 0.0 and p.x <= _w:
		return _profile(2, p.x)
	if p.x == 0.0 and p.y >= 0.0 and p.y <= _d:
		return _profile(3, p.y)
	if p.x == _w and p.y >= 0.0 and p.y <= _d:
		return _profile(1, p.y)
	return 0.0


## How high (world units above the land) the rock stands at point `p` past the map's edge (N8: the range carries on):
## the rock's height at the edge beside it, settling into the land over BEYOND squares and ridged by noise so it isn't
## a ramp. 0 on the map, where the edge square beside it isn't rock and further out than BEYOND.
func beyond_edge(p: Vector2) -> float:
	var ox := maxf(maxf(-p.x, p.x - _w), 0.0)
	var oz := maxf(maxf(-p.y, p.y - _d), 0.0)
	var out := sqrt(ox * ox + oz * oz)
	if out <= 0.0 or out >= BEYOND:
		return 0.0
	var rise := 0.0
	if oz >= ox:
		rise = _profile(0 if p.y < 0.0 else 2, p.x)
	else:
		rise = _profile(3 if p.x < 0.0 else 1, p.y)
	if rise <= 0.001:
		return 0.0
	if _beyond_noise == null:
		_beyond_noise = FastNoiseLite.new()
		_beyond_noise.seed = hash(board.place) if board != null else 1
		_beyond_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_beyond_noise.frequency = 0.35
	return rise * (1.0 - smoothstep(0.0, BEYOND, out)) * (0.8 + 0.35 * _beyond_noise.get_noise_2d(p.x, p.y))


## Every boulder along the foot (tests, art QA): [centre, radius, height, seed].
func boulders() -> Array:
	var all := []
	for c: Vector2i in _boulders:
		all.append_array(_boulders[c] as Array)
	return all


## The surface's height above the ground at grid point (i, j) (tests, art QA).
func height_at(i: int, j: int) -> float:
	return _h[j * _nx + i]


## The height (world units, from the ground) of the surface at point (x, z) in squares, read between its grid points.
func top_at(x: float, z: float) -> float:
	return _sample(_h, x, z)


## The highest the surface stands over square `c` (world units above the ground).
func top_of(c: Vector2i) -> float:
	var best := 0.0
	for b in RES + 1:
		for a in RES + 1:
			best = maxf(best, _h[(c.y * RES + b) * _nx + c.x * RES + a])
	return best
