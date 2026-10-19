class_name Crags
extends RefCounted
## A place's rock walls as one shaped mountain (catalog place_looks `rock_shape: "crags"`, Modern only; owner
## 2026-10-19: "why are all of our mountain tops flat? ... Things should look natural"). `rock_walls` drew every '#' as
## its own flat-topped box, so a mountain's crags were a field of square pillars. Here the board's rock squares share
## one surface instead: it rises out of the ground the party walks on in a steep, ragged face, climbs the deeper the
## rock runs (the land past the map's edge counts as more mountain) and breaks into ridges, peaks and saddles from
## seeded noise, so no two places come out alike. Each square still gets its own piece of that surface (the patch over
## it), so a crag fades in the party's way like the old columns did and a prop can still take its square.
## Cosmetic only: the rules grid never sees any of it.

## Grid points per square: the surface's triangles are a quarter square across.
const RES := 4
## The face's height (world units) a short way in from the open ground, and how quickly it gets there (squares).
const FACE := 1.5
const FACE_IN := 0.32
## How much higher the rock climbs for each square deeper into it, and the depth past which it climbs no more.
const CLIMB := 0.62
const DEEP := 7.0
## How far in from the open ground the face's foot may wander (squares), so it never runs straight along the grid.
const FOOT_WANDER := 0.65
## Where the surface is this low or lower it tucks under the ground beside it.
const TUCK := 0.04
## How far (squares) the face's line is bent off the grid.
const WARP := 0.55

var board: ArenaBoard
var cells: Dictionary = {}
var _w := 0
var _d := 0
var _nx := 0   ## grid points across (_w * RES + 1)
var _nz := 0
## The surface's height (world units, from the ground under it) at every grid point, and the ground's under it.
var _h := PackedFloat32Array()
var _base := PackedFloat32Array()
var _n := PackedVector3Array()   ## the surface's normal at every grid point
var _rng := RandomNumberGenerator.new()


## Plans the surface over `cells` (square -> true), the board's rock squares, once for the whole board.
static func plan(board_: ArenaBoard, cells_: Dictionary) -> Crags:
	var k := Crags.new()
	k.board = board_
	k.cells = cells_
	k._w = board_.grid.width
	k._d = board_.grid.depth
	k._nx = k._w * RES + 1
	k._nz = k._d * RES + 1
	k._rng.seed = hash(board_.place)
	k._heights()
	return k


## Whether square `c` is rock (off the map counts as rock: the mountain carries on past the edge).
func _rock(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _d:
		return true
	return cells.has(c)


func _heights() -> void:
	var n := _nx * _nz
	# The distance (squares) from every grid point to the nearest point on open ground: 0 on a point any open square
	# touches, then a two-pass chamfer sweep (1 along, 1.414 across) in grid steps.
	var dist := PackedFloat32Array()
	dist.resize(n)
	var far := 1e6
	for j in _nz:
		for i in _nx:
			var open := false
			for q in 4:
				# The squares meeting at this point (one, two or four of them).
				var c := Vector2i(floori(float(i - 1 + (q & 1)) / RES), floori(float(j - 1 + (q >> 1)) / RES))
				if not _rock(c):
					open = true
					break
			dist[j * _nx + i] = 0.0 if open else far
	var s := 1.0 / RES
	var diag := s * sqrt(2.0)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var v := dist[k]
			if i > 0:
				v = minf(v, dist[k - 1] + s)
			if j > 0:
				v = minf(v, dist[k - _nx] + s)
				if i > 0:
					v = minf(v, dist[k - _nx - 1] + diag)
				if i < _nx - 1:
					v = minf(v, dist[k - _nx + 1] + diag)
			dist[k] = v
	for j in range(_nz - 1, -1, -1):
		for i in range(_nx - 1, -1, -1):
			var k := j * _nx + i
			var v := dist[k]
			if i < _nx - 1:
				v = minf(v, dist[k + 1] + s)
			if j < _nz - 1:
				v = minf(v, dist[k + _nx] + s)
				if i < _nx - 1:
					v = minf(v, dist[k + _nx + 1] + diag)
				if i > 0:
					v = minf(v, dist[k + _nx - 1] + diag)
			dist[k] = v
	# Noise, seeded by the place: broad swells (which stretches are peaks, which saddles), ridges along them, a little
	# roughness on top, how sheer the face is along its length (buttresses and gullies) and a warp that bends the face's
	# line off the grid.
	var mass := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.075, 1)
	var ridge := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.14, 2, FastNoiseLite.FRACTAL_RIDGED)
	var rough := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.9, 1)
	var sheer := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.32, 1)
	var foot := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.6, 2)
	var warp_x := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.45, 2)
	var warp_z := _noise(FastNoiseLite.TYPE_SIMPLEX, 0.45, 2)
	_h.resize(n)
	_base.resize(n)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var x := float(i) / RES
			var z := float(j) / RES
			_base[k] = _ground(x, z)
			var t0 := dist[k]
			if t0 <= 0.0:
				_h[k] = -TUCK
				continue
			# How deep into the rock this point lies, read through the warp, so the face bends in and out.
			var t := _sample(dist, x + WARP * warp_x.get_noise_2d(x, z), z + WARP * warp_z.get_noise_2d(x, z))
			t = maxf(t - FOOT_WANDER * (0.5 + 0.5 * foot.get_noise_2d(x, z)), 0.0)
			var m := 0.5 + 0.5 * mass.get_noise_2d(x, z)          # 0..1: saddle to peak
			var r := 0.5 + 0.5 * ridge.get_noise_2d(x, z)         # ridged: crests along the mass
			var face_in := lerpf(FACE_IN, FACE_IN * 4.0, 0.5 + 0.5 * sheer.get_noise_2d(x, z))
			var face := FACE * (1.0 - exp(-t / face_in))
			var climb := CLIMB * minf(t, DEEP) * (0.35 + 1.3 * m * m)
			var h := (face + climb) * (0.78 + 0.44 * r) + 0.1 * rough.get_noise_2d(x, z) * minf(t, 1.0)
			h *= smoothstep(0.0, 0.3, t0)   # down to the ground right at the open square's edge, whatever the warp says
			_h[k] = h if h > TUCK else -TUCK
	# Points on the map's border carry no open ground past them, so the surface would stand on it as a sheer slice:
	# the pieces on the border close their outer sides with a face down to the ground (piece()).
	_normals()


func _noise(kind: int, frequency: float, octaves: int, fractal: int = FastNoiseLite.FRACTAL_FBM) -> FastNoiseLite:
	var f := FastNoiseLite.new()
	f.seed = _rng.randi()
	f.noise_type = kind
	f.frequency = frequency
	f.fractal_type = fractal if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	f.fractal_octaves = octaves
	return f


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
func _normals() -> void:
	_n.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var l := _at(maxi(i - 1, 0), j)
			var r := _at(mini(i + 1, _nx - 1), j)
			var u := _at(i, maxi(j - 1, 0))
			var d := _at(i, mini(j + 1, _nz - 1))
			_n[j * _nx + i] = (d - u).cross(r - l).normalized()


## The height (world units) of the ground under point (x, z): the board's own (natural ground's slope, else floor).
func _ground(x: float, z: float) -> float:
	var p := Vector2(clampf(x, 0.001, _w - 0.001), clampf(z, 0.001, _d - 0.001))
	return board.ground_y(p)


func _at(i: int, j: int) -> Vector3:
	var k := j * _nx + i
	return Vector3(float(i) / RES, _base[k] + _h[k], float(j) / RES)


## The patch of the surface over square `c` as its own piece, standing at the square's middle, in material `mat`.
func piece(c: Vector2i, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	var top := -INF
	for b in RES:
		for a in RES:
			var i := c.x * RES + a
			var j := c.y * RES + b
			var p00 := _at(i, j) - origin
			var p10 := _at(i + 1, j) - origin
			var p11 := _at(i + 1, j + 1) - origin
			var p01 := _at(i, j + 1) - origin
			top = maxf(top, maxf(maxf(p00.y, p10.y), maxf(p11.y, p01.y)))
			var n00 := _n[j * _nx + i]
			var n10 := _n[j * _nx + i + 1]
			var n11 := _n[(j + 1) * _nx + i + 1]
			var n01 := _n[(j + 1) * _nx + i]
			# Alternate the diagonal so the triangles don't line up in rows.
			if (i + j) % 2 == 0:
				_smooth(st, [p00, p10, p11], [n00, n10, n11])
				_smooth(st, [p00, p11, p01], [n00, n11, n01])
			else:
				_smooth(st, [p00, p10, p01], [n00, n10, n01])
				_smooth(st, [p10, p11, p01], [n10, n11, n01])
	# The map's edge, where the rock carries on past it: a face down past the ground on each outer side, so the surface
	# doesn't end in a bare slice.
	for side in 4:
		var d: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
		if board.grid.in_bounds(c + d):
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
			_tri(st, a_top, b_top, b_low)
			_tri(st, a_top, b_low, a_low)
	var mi := MeshInstance3D.new()
	mi.name = "Crag"
	mi.mesh = st.commit()
	mi.position = origin
	mi.material_override = mat
	mi.set_meta("crag", c)
	mi.set_meta("on_floor", true)   # already on the ground under it (ArenaBoard._lift passes it by)
	# How far from the party a crag this tall still stands in the camera's way (ArenaBoard.fade_occluders).
	mi.set_meta("fade_reach", maxf(4.0, top * 0.8))
	return mi


## One triangle of the surface, clockwise seen from above (Godot's front faces), with the surface's own normals.
static func _smooth(st: SurfaceTool, v: Array, nrm: Array) -> void:
	for q in 3:
		st.set_normal(nrm[q] as Vector3)
		st.set_uv(Vector2((v[q] as Vector3).x, (v[q] as Vector3).z))
		st.add_vertex(v[q] as Vector3)


## One triangle, clockwise seen from outside (Godot's front faces), shaded flat.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var nrm := (c - a).cross(b - a).normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(nrm)
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)


## The surface's height above the ground at grid point (i, j) (tests, art QA).
func height_at(i: int, j: int) -> float:
	return _h[j * _nx + i]


## The highest the surface stands over square `c` (world units above the ground).
func top_of(c: Vector2i) -> float:
	var best := 0.0
	for b in RES + 1:
		for a in RES + 1:
			best = maxf(best, _h[(c.y * RES + b) * _nx + c.x * RES + a])
	return best
