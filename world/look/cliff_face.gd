class_name CliffFace
extends RefCounted
## Cliffs and drops with shape (the vault's Natural Maps Plan, N6; owner 2026-10-19: "make our maps look more natural
## (not just like a battle grid)"). Where natural ground drops 15 ft or more between two squares (CombatGrid.is_cliff), or
## over an empty square (ArenaBoard._over_a_drop), the board drew a straight vertical slab of rock down the grid line, with
## the ground a flat step on either side. Here the squares round each cliff share one height field instead, in the Modern
## look only: the ground steps from the high level to the low through a face whose line wanders in and out (a quarter of a
## square either way: the plan's rule 2), is rounded at the corners, has a bench where the noise says so, leans out into a
## talus at its foot and is skirted there by a low apron of scree reaching half a square onto the low ground. Over a drop
## the lip reaches out over the empty square by a tenth to half a square. Where the surface is steep it is the place's rock,
## else its ground. Seeded by the place, so no two cliffs come out alike.
## The squares' own sides and tops are untouched away from a cliff, and every square's middle stays within a hair of
## where a token stands (ArenaBoard.ground_y): the shape reaches 0.55 of a square from the cliff line at most.
## Cosmetic only: the rules grid never sees any of it.
## A place is built on every arrival, and comes out the same each time: what a plan works out is kept for the newest KEEP
## places (as Crags does).

## Grid points per square in the squares round a cliff.
const RES := 6
## How far (squares) from a cliff line its shape reaches, how far its line wanders either way, and (over a drop) how far
## the lip reaches out over the empty square.
const REACH := 0.55
const WANDER := 0.17
## The flutes and gullies on top of it (squares), so the line never goes beyond a quarter square either way.
const FLUTES := 0.08
const DROP_OUT_MIN := 0.1
const DROP_OUT_MAX := 0.5
## How wide the face's foot spreads (the lean) and its lip rounds off (squares).
const FOOT := 0.3
const LIP := 0.12
## The scree apron at the foot: its height (world units) and how far it reaches onto the low ground (squares).
const APRON := 0.25
const APRON_REACH := 0.4
## Where a drop's face ends (the board's old rock face did): the land or the water under it.
const DROP_BASE := -0.2
## Triangles steeper than this (the normal's up) are rock, and a cell's apron is rock where it's higher than the other.
const ROCK_Y := 0.8
const ROCK_APRON := 0.03
## How round the lip goes at a plateau's corner (squares): the smooth minimum's radius.
const ROUND := 0.09
## How many places' plans are kept.
const KEEP := 8

## Set by art QA tools only, to shoot a place as it was before (tools/capture/crags_views.gd CV_NOCLIFFS).
static var off := false
static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []
## What the last plan took, phase by phase (milliseconds).
static var plan_ms: Dictionary = {}

var board: ArenaBoard
var _w := 0
var _d := 0
var _nx := 0
var _nz := 0
## Each cliff or drop side, as a unit edge: where it starts, which way it runs, which way is up (toward the high square),
## the high square, whether it is a drop over an empty square, and (a value every 1/RES along it) the ground's height on
## the high side and on the low side.
var _p0 := PackedVector2Array()
var _dir := PackedVector2Array()
var _hi := PackedVector2Array()
var _high: Array[Vector2i] = []
var _drop := PackedByteArray()
var _edge_h := PackedFloat32Array()
var _edge_l := PackedFloat32Array()
## Square (y * width + x) -> the sides within reach of its points.
var _near: Dictionary = {}
## Per square: 1 where the field draws its whole top (natural ground with a column), 2 where only the face reaches (an
## empty square, water, a built floor).
var _zone := PackedByteArray()
## Per grid point (RES per square): the height, its normal, the apron's share of it, how far up the face it is (0 the low
## ground, 1 the high) and the side it belongs to (-1 none).
var _h := PackedFloat32Array()
var _n := PackedVector3Array()
var _ap := PackedFloat32Array()
var _prof := PackedFloat32Array()
var _seg := PackedInt32Array()
## Triangles (three grid point indices each) of the ground and of the rock, by the square whose column draws them: the
## ground's by the square they lie in, the rock's by the high square of the side they hang from.
var _ground: Dictionary = {}   ## square -> Array[int] of grid point indices, three a triangle
var _rock: Dictionary = {}
var _meshes: Dictionary = {}
## Boulders at the foot of each cliff side, by the high square they hang from: [centre, radius, height, seed] (Crags.boulder).
var _boulders: Dictionary = {}
## Squares whose column asked for its pieces (ArenaBoard._terrain_column), so the rock of the rest can be drawn on the board.
var _claimed: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Plans the cliffs of `board` (null where it has none, or in the Classic look), or takes the plan kept from an earlier
## visit.
static func plan(board_: ArenaBoard) -> CliffFace:
	if off or not Look.modern() or not board_.has_terrain():
		return null
	var key := "%s|%d|%d|%d" % [board_.place, board_.grid.width, board_.grid.depth, hash(board_._corner_h)]
	if _kept.has(key):
		var kept := _kept[key] as CliffFace
		if kept != null:
			kept.board = board_
			kept._claimed.clear()
		_kept_order.erase(key)
		_kept_order.append(key)
		plan_ms = {"kept": 0.0}
		return kept
	var f := CliffFace.new()
	f.board = board_
	f._w = board_.grid.width
	f._d = board_.grid.depth
	f._rng.seed = hash(board_.place)
	f._sides()
	var made: CliffFace = f if not f._high.is_empty() else null
	if made != null:
		made._field_and_triangles()
	_kept[key] = made
	_kept_order.append(key)
	while _kept_order.size() > KEEP:
		_kept.erase(_kept_order.pop_front())
	return made


## Every side of a natural square that is a cliff or a drop (the board's own tests), with the ground's height along it on
## both sides, and the squares each is near.
func _sides() -> void:
	var t0 := Time.get_ticks_usec()
	var g := board.grid
	_zone.resize(_w * _d)
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if not g.has_flag(c, CombatGrid.NATURAL) or g.has_flag(c, CombatGrid.VOID):
				continue
			var h := board.floor_y(c)
			for i in 4:
				var o := c + ArenaBoard._SIDES[i]
				var drop := false
				if not g.in_bounds(o):
					continue
				if g.has_flag(o, CombatGrid.VOID):
					# Over an empty square with no natural ground of its own, 15 ft or more down (ArenaBoard._over_a_drop).
					if g.has_flag(o, CombatGrid.NATURAL):
						continue
					var edge := minf(board.corner_height(c, ArenaBoard._CORNERS[i]), board.corner_height(c, ArenaBoard._CORNERS[(i + 1) % 4]))
					if not board._over_a_drop(o, edge):
						continue
					drop = true
				elif not (g.is_cliff(c, o) and board.floor_y(o) < h):
					continue
				var hi := Vector2(-ArenaBoard._SIDES[i].x, -ArenaBoard._SIDES[i].y)
				var p0 := Vector2(c.x + (1 if i == 1 else 0), c.y + (1 if i == 2 else 0))
				var dir := Vector2(1, 0) if i % 2 == 0 else Vector2(0, 1)
				var idx := _high.size()
				_p0.append(p0)
				_dir.append(dir)
				_hi.append(hi)
				_high.append(c)
				_drop.append(1 if drop else 0)
				# The ground's height on each side along the edge: its top is straight between the two ends.
				var h0 := board.ground_y(p0 + hi * 0.001)
				var h1 := board.ground_y(p0 + dir + hi * 0.001)
				var l0 := DROP_BASE if drop else board.ground_y(p0 - hi * 0.001)
				var l1 := DROP_BASE if drop else board.ground_y(p0 + dir - hi * 0.001)
				for t in RES + 1:
					_edge_h.append(lerpf(h0, h1, float(t) / RES))
					_edge_l.append(lerpf(l0, l1, float(t) / RES))
				# The six squares round the edge's two ends.
				for e: Vector2i in [Vector2i(int(p0.x), int(p0.y)), Vector2i(int(p0.x + dir.x), int(p0.y + dir.y))]:
					for q: Vector2i in [e + Vector2i(-1, -1), e + Vector2i(0, -1), e + Vector2i(-1, 0), e]:
						if not g.in_bounds(q):
							continue
						var key := q.y * _w + q.x
						if not _near.has(key):
							_near[key] = [] as Array[int]
						if not (_near[key] as Array[int]).has(idx):
							(_near[key] as Array[int]).append(idx)
						var natural := g.has_flag(q, CombatGrid.NATURAL) and not g.has_flag(q, CombatGrid.VOID)
						_zone[key] = 1 if natural else 2
	plan_ms = {"sides": (Time.get_ticks_usec() - t0) / 1000.0}


## Noise over the grid points, a byte each (0..255 for -1..1), from the place's seed.
func _noise(frequency: float, octaves: int) -> PackedByteArray:
	var f := FastNoiseLite.new()
	f.seed = _rng.randi()
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX
	f.frequency = frequency / RES
	f.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	f.fractal_octaves = octaves
	return f.get_image(_nx, _nz, false, false, false).get_data()


func _field_and_triangles() -> void:
	var t0 := Time.get_ticks_usec()
	_nx = _w * RES + 1
	_nz = _d * RES + 1
	var n := _nx * _nz
	var unit := 1.0 / 255.0
	var wander := _noise(0.45, 2)
	var flutes := _noise(1.5, 2)
	var bench := _noise(0.28, 1)
	var rough := _noise(1.6, 2)
	var scree := _noise(0.9, 2)
	_h.resize(n)
	_ap.resize(n)
	_prof.resize(n)
	_seg.resize(n)
	_seg.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	var pts := PackedInt32Array()
	# The sides near each square: its own and its four neighbours' (a point on a square's edge belongs to both).
	var cand_of := {}
	var zone_squares: Array[Vector2i] = []
	for z in _d:
		for x in _w:
			if _zone[z * _w + x] == 0:
				continue
			var q := Vector2i(x, z)
			zone_squares.append(q)
			var list: Array[int] = []
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o := q + d
				if o.x < 0 or o.y < 0 or o.x >= _w or o.y >= _d:
					continue
				for s: int in _near.get(o.y * _w + o.x, [] as Array[int]):
					if not list.has(s):
						list.append(s)
			cand_of[q] = list
	var near_s := PackedFloat32Array()
	var near_i := PackedInt32Array()
	for q in zone_squares:
		var cand := cand_of[q] as Array[int]
		for b in RES + 1:
			for a in RES + 1:
				var i := q.x * RES + a
				var j := q.y * RES + b
				var k := j * _nx + i
				if done[k] != 0:
					continue
				done[k] = 1
				pts.append(k)
				var p := Vector2(float(i) / RES, float(j) / RES)
				# The sides within reach, and the signed distance to each (positive on the high side).
				near_s.clear()
				near_i.clear()
				var best := INF
				var best_at := -1
				for s in cand:
					var rel := p - _p0[s]
					var along := rel.dot(_dir[s])
					var perp := rel.dot(_hi[s])
					var ex := maxf(maxf(-along, along - 1.0), 0.0)
					var dist := sqrt(perp * perp + ex * ex)
					if dist > REACH + ROUND * 3.0:
						continue
					var signed := dist if perp >= 0.0 else -dist
					near_s.append(signed)
					near_i.append(s)
					if dist < best:
						best = dist
						best_at = near_s.size() - 1
				if best_at < 0 or best > REACH:
					_h[k] = board.ground_y(p)
					continue
				var s0 := near_i[best_at]
				var side := 1.0 if near_s[best_at] >= 0.0 else -1.0
				# The smooth minimum of the distances to the sides on the same side as the nearest: rounds a plateau's corner.
				var soft := 0.0
				for m in near_s.size():
					if (near_s[m] >= 0.0) == (side > 0.0):
						soft += exp(-(absf(near_s[m]) - best) / ROUND)
				var s_dist := best - ROUND * log(soft)
				var s_signed := side * s_dist
				var drop := _drop[s0] != 0
				var hi := _hi[s0]
				var g := DROP_BASE if (drop and side < 0.0) else board.ground_y(p + hi * side * 0.001)
				# The step down the edge nearest this point.
				var along0 := clampf((p - _p0[s0]).dot(_dir[s0]), 0.0, 1.0) * RES
				var t0i := mini(floori(along0), RES - 1)
				var ft := along0 - t0i
				var base := s0 * (RES + 1) + t0i
				var step := lerpf(_edge_h[base] - _edge_l[base], _edge_h[base + 1] - _edge_l[base + 1], ft)
				# Where the face stands: its line wanders (out over the empty square by a tenth to half a square at a drop).
				var wn := float(wander[k]) * unit
				# (simplex noise rarely reaches its ends, so it is stretched to use the whole quarter square)
				var lobe := clampf((wn * 2.0 - 1.0) * 1.8, -1.0, 1.0)
				var flute := clampf((float(flutes[k]) * unit * 2.0 - 1.0) * 1.8, -1.0, 1.0)
				var off := lerpf(DROP_OUT_MIN, DROP_OUT_MAX, wn) if drop else WANDER * lobe + FLUTES * flute
				var se := s_signed + off
				var sp := se + (LIP - FOOT) * 0.5   # (the face's mid-height sits on its line, not off to one side)
				var bench_m := smoothstep(0.55, 0.8, float(bench[k]) * unit)
				var pm := smoothstep(-FOOT, LIP, sp)
				var pb := 0.5 * smoothstep(-FOOT, -0.12, sp) + 0.5 * smoothstep(-0.02, LIP, sp)   # (a shelf half way up)
				var prof := lerpf(pm, pb, bench_m)
				var crumble := (float(rough[k]) * unit * 2.0 - 1.0) * 0.06 * 4.0 * prof * (1.0 - prof)
				var h := 0.0
				var apron := 0.0
				if side > 0.0:
					h = g - (1.0 - prof) * step + crumble
				else:
					if not drop:
						var out := maxf(-s_signed - 0.05, 0.0)
						apron = APRON * pow(clampf(1.0 - out / APRON_REACH, 0.0, 1.0), 2.0) * lerpf(0.35, 1.0, float(scree[k]) * unit) * (1.0 - prof)
					h = g + prof * step + crumble + apron
				_h[k] = h
				_ap[k] = apron
				_prof[k] = prof
				_seg[k] = s0
	var t1 := Time.get_ticks_usec()
	# Normals over the points made (a point beside one that wasn't takes its own height there).
	_n.resize(n)
	for k in pts:
		var i := k % _nx
		var hc := _h[k]
		var hl := _h[k - 1] if i > 0 and done[k - 1] != 0 else hc
		var hr := _h[k + 1] if i < _nx - 1 and done[k + 1] != 0 else hc
		var hu := _h[k - _nx] if k >= _nx and done[k - _nx] != 0 else hc
		var hd := _h[k + _nx] if k < n - _nx and done[k + _nx] != 0 else hc
		_n[k] = Vector3(-(hr - hl) * RES * 0.5, 1.0, -(hd - hu) * RES * 0.5).normalized()
	var t2 := Time.get_ticks_usec()
	# Triangles: each cell of a zone square, ground or rock by how steep it is, rock hung from the high square of its side.
	for q in zone_squares:
		var full := _zone[q.y * _w + q.x] == 1
		for b in RES:
			for a in RES:
				var i := q.x * RES + a
				var j := q.y * RES + b
				var k00 := j * _nx + i
				var k10 := k00 + 1
				var k01 := k00 + _nx
				var k11 := k01 + 1
				if not full and maxf(maxf(_prof[k00], _prof[k10]), maxf(_prof[k01], _prof[k11])) < 0.03:
					continue   # an empty square beside a cliff: only where the face or the lip reaches out over it
				if not full and _seg[k00] < 0 and _seg[k10] < 0 and _seg[k01] < 0 and _seg[k11] < 0:
					continue
				var even := (i + j) % 2 == 0
				for half in 2:
					var k0 := k00
					var k1 := k10
					var k2 := k11
					if half == 0:
						k2 = k11 if even else k01
					else:
						k0 = k00 if even else k10
						k1 = k11
						k2 = k01
					var up := (_n[k0].y + _n[k1].y + _n[k2].y) / 3.0
					var apron := (_ap[k0] + _ap[k1] + _ap[k2]) / 3.0
					var s := maxi(maxi(_seg[k0], _seg[k1]), _seg[k2])
					if s >= 0 and (up < ROCK_Y or apron > ROCK_APRON):
						var owner := _high[s]
						if not _rock.has(owner):
							_rock[owner] = [] as Array[int]
						var rt := _rock[owner] as Array[int]
						rt.append(k0)
						rt.append(k1)
						rt.append(k2)
					elif full or s >= 0:
						var owner2 := q if full else _high[s]
						if not _ground.has(owner2):
							_ground[owner2] = [] as Array[int]
						var gt := _ground[owner2] as Array[int]
						gt.append(k0)
						gt.append(k1)
						gt.append(k2)
	_scatter_boulders()
	var t3 := Time.get_ticks_usec()
	plan_ms["field"] = (t1 - t0) / 1000.0
	plan_ms["normals"] = (t2 - t1) / 1000.0
	plan_ms["triangles"] = (t3 - t2) / 1000.0


## A few boulders along the foot of each cliff (not a drop), sized and spaced unevenly, none further than half a square from
## the line and none taller than a knee.
func _scatter_boulders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(board.place) + 11
	for s in _high.size():
		if _drop[s] != 0:
			continue
		var count := 3 + (1 if rng.randf() < 0.5 else 0)
		for q in count:
			var along := (q + rng.randf_range(0.15, 0.85)) / count
			var radius := rng.randf_range(0.11, 0.28)
			var out := rng.randf_range(radius * 0.6 + 0.12, 0.5 - radius * 0.8)
			var at := _p0[s] + _dir[s] * along - _hi[s] * out
			var tall := minf(radius * rng.randf_range(0.7, 1.15), 0.32)
			if not _boulders.has(_high[s]):
				_boulders[_high[s]] = []
			(_boulders[_high[s]] as Array).append([Vector3(at.x, board.ground_y(at) + tall * 0.25, at.y), radius, tall, rng.randi()])


## Whether the field draws square `c`'s top (so its column leaves it out), and notes that its column asked.
func draws(c: Vector2i) -> bool:
	if _zone[c.y * _w + c.x] != 1:
		return false
	_claimed[c] = true
	return true


## Square `c`'s ground (its top, the part of the field the rock doesn't take) as a mesh in the square's own frame, or null.
func ground_mesh(c: Vector2i) -> ArrayMesh:
	return _mesh_of(_ground, c, false)


## The rock hung from square `c`'s cliff and drop sides (its face and the scree at its foot) as a mesh in the square's own
## frame, or null.
func rock_mesh(c: Vector2i) -> ArrayMesh:
	return _mesh_of(_rock, c, true)


func _mesh_of(tris: Dictionary, c: Vector2i, rock: bool) -> ArrayMesh:
	if not tris.has(c) and not (rock and _boulders.has(c)):
		return null
	var key := [c, rock]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var list := (tris[c] as Array[int]) if tris.has(c) else ([] as Array[int])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var origin := Vector3(c.x, 0.0, c.y)
	for k in list:
		var i := k % _nx
		var j := floori(float(k) / _nx)
		var v := Vector3(float(i) / RES, _h[k], float(j) / RES)
		var nv := _n[k]
		verts.append(v - origin)
		norms.append(nv)
		uvs.append(Vector2(v.x, v.z) if nv.y > 0.5 else Vector2(v.x + v.z, -v.y))
	if rock:
		for b: Array in _boulders.get(c, []):
			Crags.boulder(verts, norms, uvs, b, origin)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	return mesh


## Rock hung from squares whose column never asked (a wall square at floor level draws none): [square, mesh] for each, to
## stand on the board itself.
func orphan_rock() -> Array:
	var out := []
	var owners := {}
	for c: Vector2i in _rock:
		owners[c] = true
	for c: Vector2i in _boulders:
		owners[c] = true
	for c: Vector2i in owners:
		if not _claimed.has(c):
			out.append([c, rock_mesh(c)])
	return out


## The height (world units) of the field at point `p` (tests, art QA): the board's own ground away from every cliff.
func height_at(p: Vector2) -> float:
	var fi := clampf(p.x * RES, 0.0, _nx - 1.001)
	var fj := clampf(p.y * RES, 0.0, _nz - 1.001)
	var i := floori(fi)
	var j := floori(fj)
	var k := j * _nx + i
	if _seg.is_empty() or (_seg[k] < 0 and _seg[k + 1] < 0 and _seg[k + _nx] < 0 and _seg[k + _nx + 1] < 0):
		return board.ground_y(p)
	return lerpf(lerpf(_h[k], _h[k + 1], fi - i), lerpf(_h[k + _nx], _h[k + _nx + 1], fi - i), fj - j)


## Triangles drawn against the triangles the squares drawn in full should have (tests): [drawn, expected].
func coverage() -> Array[int]:
	var drawn := 0
	for c: Vector2i in _ground:
		drawn += (_ground[c] as Array[int]).size() / 3
	for c: Vector2i in _rock:
		drawn += (_rock[c] as Array[int]).size() / 3
	var full := 0
	for z in _d:
		for x in _w:
			if _zone[z * _w + x] == 1:
				full += 1
	return [drawn, full * RES * RES * 2]


## How many sides the plan found (tests).
func side_count() -> int:
	return _high.size()


## The high square of side `i` and whether it is a drop (tests, art QA).
func side_high(i: int) -> Vector2i:
	return _high[i]


func side_is_drop(i: int) -> bool:
	return _drop[i] != 0


## How far (squares) point `p` is from the nearest cliff or drop line (tests, art QA).
func line_distance(p: Vector2) -> float:
	var best := INF
	for s in _high.size():
		var rel := p - _p0[s]
		var along := rel.dot(_dir[s])
		var perp := rel.dot(_hi[s])
		var ex := maxf(maxf(-along, along - 1.0), 0.0)
		best = minf(best, sqrt(perp * perp + ex * ex))
	return best


## Where the face of side `i` stands `t` (0..1) along it (tests, art QA): how far (squares) from the grid line toward the high
## square the surface passes a third and two thirds of the way down the step (so a shelf half way down doesn't matter),
## the two averaged, scanned across the line (positive toward the high square), or NAN where it never does within 0.6 of it.
func contour_at(i: int, t: float) -> float:
	var at := _p0[i] + _dir[i] * t
	var along := t * RES
	var base := i * (RES + 1) + mini(floori(along), RES - 1)
	var ft := along - floorf(along) if t < 1.0 else 1.0
	var top := lerpf(_edge_h[base], _edge_h[base + 1], ft)
	var low := lerpf(_edge_l[base], _edge_l[base + 1], ft)
	var crossings: Array[float] = []
	for level: float in [1.0 / 3.0, 2.0 / 3.0]:
		var want := lerpf(low, top, level)
		var prev := height_at(at - _hi[i] * 0.6)
		var s := -0.6
		var found := NAN
		while s < 0.6:
			s += 0.01
			var cur := height_at(at + _hi[i] * s)
			if (prev - want) * (cur - want) <= 0.0 and prev != cur:
				found = s - 0.01 * (cur - want) / (cur - prev)
				break
			prev = cur
		if is_nan(found):
			return NAN
		crossings.append(found)
	return 0.5 * (crossings[0] + crossings[1])
