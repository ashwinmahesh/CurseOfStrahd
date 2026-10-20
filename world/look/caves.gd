class_name Caves
extends RefCounted
## Caves as caves (the vault's Natural Maps Plan, I2; owner 2026-10-19: "Ex cave rooms should have natural shapes
## instead of it all being square rooms"). A cave's rock was drawn like a house's walls: a block a square, a full storey
## high, its top a flat black cap, so a great cave was a rectangle cut out of a slab. Here the place's rock squares share
## one surface instead, planned once for the whole board (catalog place_looks `cave: true`, or `cave: "hewn"` for rooms
## cut into rock, a smoother face with less lean, rubble and stone; Modern only, Classic keeps its blocks):
##   - the cave's outline is one smooth contour round the floor the rules grid gives it. The grid's boundary is traced
##     into loops and its corners rounded as far as the walls beside each allow (a corner between two long walls takes
##     a radius of a square or more, a one-square niche hardly any), so a rectangular room becomes a rounded chamber and
##     a passage stays a passage;
##   - noise seeded by the place then swells the contour out into the rock behind it (bays, niches, a wall that bows
##     out), by no more than that rock's thickness leaves, and lets it wander in over the floor by up to a quarter of a
##     square (Natural Maps Plan, rule 2: a token in a square's middle and its ring stay clear), so no wall runs along a
##     grid line. Things hung on a wall (a prop on a wall square, a door, an exit) keep a straight stretch of wall;
##   - the wall is a rock surface over that contour (like Crags' mountain, turned on its side): a steep face leaning
##     over the cave, ragged at its top, with a slope of rubble and loose stones at its foot reaching up to half a square
##     into the floor. Its top is the dark cut of the cave's rock, as every interior's wall top is;
##   - bays the walls swell into get floor of the room's own and stalagmites; the floor carries loose stones and, where
##     the place suits it (look `cave_puddles`), puddles.
## A place look's `built_areas` name areas that stay built (Ghakis's keepers' post): a wall that faces only those, and a
## free-standing stack of shelves, are still InteriorWalls'. Each rock square gets its own piece of the surface (the patch
## over it, so it fades where it hides the party like any wall (SeeThrough), a prop can take its square, and a hidden area hides
## it); nothing here touches the rules grid.

## Grid points per square: the surface's quads are a third of a square across.
const RES := 3
const STEP := 1.0 / RES
## How far (world units) the surface tucks under the floor where it gives way to it.
const TUCK := 0.04
## The rubble at a wall's foot: its height at the face, and how far (squares) it runs out over the floor.
const TALUS := 0.3
const TALUS_W := 0.55
## How far the top of a face leans over the cave, for each unit of its height.
const LEAN := 0.07
## How far in (squares) the contour may come over the floor: a quarter of a square (rule 2).
const IN := 0.2
const INTRUSION := 0.25
## The cave swells out into the rock this far on average (squares).
const SWELL := 0.1
## The longest tangent (squares) a corner between long walls is rounded with.
const ROUND := 2.0
const FAR := 1.0e6
## Squares across a chunk of the plain rock far from any cave (three squares are under SeeThrough.LARGE).
const FAR_CHUNK := 3
const AMOUNTS := {
	"full": {"round": 1.0, "wander": 1.0, "bays": 1.0, "lean": 1.0, "talus": 1.0, "decor": 1.0, "face": 0.13},
	"hewn": {"round": 1.0, "wander": 1.0, "bays": 1.0, "lean": 0.6, "talus": 0.7, "decor": 0.5, "face": 0.2},
}

var board: ArenaBoard
var look: Dictionary = {}
var amt: Dictionary = {}
var _w := 0
var _d := 0
var _tw := 0   ## texels across (RES to a square)
var _td := 0
var _vw := 0   ## grid points across (a texel's corners)
var _vd := 0
var _open := PackedByteArray()        ## per square: 1 where the rules grid has floor
var _rock := PackedByteArray()        ## per square: 1 where this draws the rock
var _flat := PackedByteArray()        ## per square: 1 where the rock is far from any cave (a plain top)
var _base_sq := PackedFloat32Array()  ## per square: the floor's level, a wall square's being its nearest floor's
var _thick := PackedFloat32Array()    ## per square: how far the cave may swell into it (squares)
var _keep: Array[Vector2i] = []       ## squares with something on the wall, or a doorway: their wall stays straight
var _keepw := PackedFloat32Array()    ## per point: 0 beside such a square, 1 away from them
var _vbase := PackedFloat32Array()    ## per point: the floor's level
var _s := PackedFloat32Array()        ## per point: the contour field (squares), positive in the cave, 0 on the wall's foot
var _s0 := PackedFloat32Array()       ## per point: the same for the rules grid's own outline, unrounded and unmoved
var _h := PackedFloat32Array()        ## per point: the rock's height above its floor (below it where the floor shows)
var _pos := PackedVector3Array()      ## per point: where it stands (a face's top is leaned over)
var _nrm := PackedVector3Array()
var _quads: Dictionary = {}           ## rock square -> the quads (ids) of the surface it draws
var _decor_done := false
## How long planning took (milliseconds), for the audit.
var plan_ms := 0.0
## What each planning stage took, and how long drawing the pieces has taken so far (milliseconds).
var stages: Dictionary = {}
var build_ms := 0.0
var _stage_at := 0
var _mat_face: Material = null
var _mat_top: Material = null
var _mat_talus: Material = null
var _n1: FastNoiseLite = null
var _n2: FastNoiseLite = null
var _nbay: FastNoiseLite = null
var _nwind: FastNoiseLite = null
var _ndepth: FastNoiseLite = null
var _ntop: FastNoiseLite = null
var _nrough: FastNoiseLite = null
var _ncrack: FastNoiseLite = null
var _rng := RandomNumberGenerator.new()
## Caves planned on earlier visits, by place and what shaped them (a place comes out the same every time): the newest few.
static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []
const KEEP := 8


## The board's cave, planned the first time it's asked for; null where the place isn't one (or isn't Modern).
static func of(board_: ArenaBoard) -> Caves:
	if board_.has_meta("caves"):
		var v: Variant = board_.get_meta("caves")
		return v as Caves if v is Caves else null
	var kind: Variant = board_._look.get("cave", false)
	var on := (kind is bool and bool(kind)) or (kind is String and str(kind) != "")
	if not on or not Look.modern() or board_.theme in ArenaBoard.WILD or board_.theme in ArenaBoard.TOWNS:
		board_.set_meta("caves", false)
		return null
	var k := Caves.new()
	k.board = board_
	k.look = board_._look
	k.amt = AMOUNTS["hewn" if kind is String and str(kind) == "hewn" else "full"] as Dictionary
	var key := "%s|%dx%d|%d|%d" % [board_.place, board_.grid.width, board_.grid.depth, board_.occupied.size(), hash(str(board_._look))]
	if _kept.has(key):
		k._adopt(_kept[key] as Caves)
	else:
		var began := Time.get_ticks_usec()
		k._plan()
		k.plan_ms = (Time.get_ticks_usec() - began) / 1000.0
		_kept[key] = k
		_kept_order.append(key)
		while _kept_order.size() > KEEP:
			_kept.erase(_kept_order.pop_front())
	board_.set_meta("caves", k)
	return k


## Whether the cave draws wall square `c` (not the keepers' post's walls, nor a stack of shelves).
static func owns(board_: ArenaBoard, c: Vector2i) -> bool:
	var k := of(board_)
	return k != null and k.claims(c)


func claims(c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and _rock[c.y * _w + c.x] == 1


## Draws rock square `c`: its patch of the surface, the floor under it where the cave has swelled into it, and what
## stands in it (rubble, stalagmites). The first call also lays the floor's loose stones and puddles.
func build(c: Vector2i) -> void:
	var began := Time.get_ticks_usec()
	if not _decor_done:
		_decor_done = true
		_floor_decor()
		_far_rock()
	if _flat[c.y * _w + c.x] == 1:
		return   # drawn with all the rock far from any cave (_far_rock)
	var piece := _piece(c)
	if piece != null:
		board.add_child(piece)
		SeeThrough.mark(piece)
	if _swells(c):
		var y := _base_sq[c.y * _w + c.x]
		var floor_box := board.add_box("Floor", Vector3(1, 0.2 + y, 1), Vector3(c.x + 0.5, (y - 0.2) / 2.0, c.y + 0.5), board.floor_material())
		floor_box.set_meta("on_floor", true)
	build_ms += (Time.get_ticks_usec() - began) / 1000.0


# --- Planning -------------------------------------------------------------------------------------------------

## Takes the plan an earlier visit made (its arrays are shared and never written again).
func _adopt(k: Caves) -> void:
	_w = k._w
	_d = k._d
	_tw = k._tw
	_td = k._td
	_vw = k._vw
	_vd = k._vd
	_open = k._open
	_rock = k._rock
	_flat = k._flat
	_base_sq = k._base_sq
	_thick = k._thick
	_keep = k._keep
	_keepw = k._keepw
	_vbase = k._vbase
	_s = k._s
	_s0 = k._s0
	_h = k._h
	_pos = k._pos
	_nrm = k._nrm
	_quads = k._quads
	_mat_face = board.wall_material()
	_mat_top = Look.cel(ArenaBoard.CUT_FACE)
	_mat_talus = board.floor_material()


func _plan() -> void:
	var g := board.grid
	_w = g.width
	_d = g.depth
	_tw = _w * RES
	_td = _d * RES
	_vw = _tw + 1
	_vd = _td + 1
	_rng.seed = hash(board.place + "|cave")
	_n1 = _noise(0.32, 2)
	_n2 = _noise(0.95, 1)
	_nbay = _noise(0.16, 1)
	_nwind = _noise(0.11, 1)
	_ndepth = _noise(0.5, 1)
	_ntop = _noise(0.22, 1)
	_nrough = _noise(0.8, 1)
	_ncrack = _noise(1.4, 1)
	_mat_face = board.wall_material()
	_mat_top = Look.cel(ArenaBoard.CUT_FACE)
	_mat_talus = board.floor_material()
	_stage("start")
	_classify()
	_thickness()
	_keeps()
	_stage("classify")
	var sd0 := _signed(_square_mask())
	_stage("signed 0")
	var loops := _loops()
	_stage("loops")
	var polys := _round(loops)
	_stage("round")
	var mask := _fill(polys)
	_stage("fill")
	var sd1 := _signed(mask)
	_stage("signed 1")
	_blur(sd1)
	_stage("blur")
	_field(sd0, sd1)
	_stage("field")
	_shape()
	_stage("shape")
	_assign()
	_stage("assign")


## Notes how long the planning stage that just ended took (milliseconds), for the audit.
func _stage(what: String) -> void:
	var now := Time.get_ticks_usec()
	if _stage_at > 0:
		stages[what] = (now - _stage_at) / 1000.0
	_stage_at = now


func _noise(frequency: float, octaves: int) -> FastNoiseLite:
	var f := FastNoiseLite.new()
	f.seed = _rng.randi()
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f.frequency = frequency
	f.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	f.fractal_octaves = octaves
	return f


func _is_open(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _w and c.y < _d and _open[c.y * _w + c.x] == 1


## Which squares are floor, which are rock this draws, and each square's floor level.
func _classify() -> void:
	var g := board.grid
	_open.resize(_w * _d)
	_rock.resize(_w * _d)
	_flat.resize(_w * _d)
	_base_sq.resize(_w * _d)
	var built: Array[String] = []
	for b: Variant in look.get("built_areas", []):
		built.append(str(b))
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			_open[z * _w + x] = 0 if g.has_flag(c, CombatGrid.WALL) or g.has_flag(c, CombatGrid.VOID) else 1
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if not g.has_flag(c, CombatGrid.WALL) or g.has_flag(c, CombatGrid.VOID):
				continue
			if not InteriorWalls._anchored(board, c):
				continue   # a free-standing stack or pillar: built as before
			var beside := 0
			var in_built := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dz)
					if (dx != 0 or dz != 0) and _is_open(n):
						beside += 1
						if not built.is_empty() and str(board.area_at(n).get("id", "")) in built:
							in_built += 1
			if beside > 0 and in_built == beside:
				continue   # a wall that faces only a built room (the keepers' post)
			_rock[z * _w + x] = 1
	# A floor level for every square: a floor square's own, a wall's its nearest floor's (breadth first over the eight
	# neighbours), which the rock's foot stands on.
	var queue: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(_w * _d)
	for z in _d:
		for x in _w:
			if _open[z * _w + x] == 1:
				var c := Vector2i(x, z)
				_base_sq[z * _w + x] = board.floor_y(c)
				seen[z * _w + x] = 1
				queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dz)
				if g.in_bounds(n) and seen[n.y * _w + n.x] == 0:
					seen[n.y * _w + n.x] = 1
					_base_sq[n.y * _w + n.x] = _base_sq[c.y * _w + c.x]
					queue.append(n)


## How far the cave may swell into each wall square: what the wall's thickness leaves, so a wall between two rooms keeps
## a square of rock (a one square wall seven tenths) however both bow (a run of wall squares along each axis, the shorter
## counting; the map's edge counts as three squares more, the rock carries on past it).
func _thickness() -> void:
	var runx := PackedInt32Array()
	var runz := PackedInt32Array()
	runx.resize(_w * _d)
	runz.resize(_w * _d)
	for z in _d:
		var x := 0
		while x < _w:
			if _open[z * _w + x] == 1:
				x += 1
				continue
			var x1 := x
			while x1 < _w and _open[z * _w + x1] == 0:
				x1 += 1
			var run := x1 - x + (3 if x == 0 else 0) + (3 if x1 == _w else 0)
			for k in range(x, x1):
				runx[z * _w + k] = run
			x = x1
	for x in _w:
		var z := 0
		while z < _d:
			if _open[z * _w + x] == 1:
				z += 1
				continue
			var z1 := z
			while z1 < _d and _open[z1 * _w + x] == 0:
				z1 += 1
			var run := z1 - z + (3 if z == 0 else 0) + (3 if z1 == _d else 0)
			for k in range(z, z1):
				runz[k * _w + x] = run
			z = z1
	_thick.resize(_w * _d)
	for k in _w * _d:
		_thick[k] = 0.0 if _open[k] == 1 else clampf((float(mini(runx[k], runz[k])) - 1.0) * 0.5, 0.15, 2.2)
	# A floor square takes the limit of the rock beside it, so the contour between them reads the rock's.
	var at_floor := _thick.duplicate()
	for z in _d:
		for x in _w:
			if _open[z * _w + x] == 0:
				continue
			var best := 0.0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var n := Vector2i(x + dx, z + dz)
					if n.x >= 0 and n.y >= 0 and n.x < _w and n.y < _d and _open[n.y * _w + n.x] == 0:
						best = maxf(best, _thick[n.y * _w + n.x])
			at_floor[z * _w + x] = best
	_thick = at_floor


## The squares whose wall must stay straight: something hangs on a wall square (a prop, a door's frame, an exit), or a
## door stands in a gap. Their wall is plumb and unmoved for a square or so each way (_field fades it back in).
func _keeps() -> void:
	_keep.clear()
	for c: Variant in board.occupied:
		var cell := c as Vector2i
		var kind := str(board.occupied[cell])
		if board.grid.in_bounds(cell) and (board.grid.has_flag(cell, CombatGrid.WALL) or kind == "doors" or kind == "exits"):
			_keep.append(cell)
	_keepw.resize(_vw * _vd)
	_keepw.fill(1.0)
	for cell in _keep:
		var cx := cell.x + 0.5
		var cz := cell.y + 0.5
		for j in range(maxi(int((cz - 1.6) * RES), 0), mini(int((cz + 1.6) * RES) + 1, _vd)):
			for i in range(maxi(int((cx - 1.6) * RES), 0), mini(int((cx + 1.6) * RES) + 1, _vw)):
				var dist := Vector2(i * STEP - cx, j * STEP - cz).length()
				var k := j * _vw + i
				_keepw[k] = minf(_keepw[k], smoothstep(0.7, 1.5, dist))


# --- The outline ------------------------------------------------------------------------------------------------

## Each texel's floor, from the rules grid alone.
func _square_mask() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(_tw * _td)
	for tz in _td:
		var z := floori(float(tz) / RES)
		for tx in _tw:
			m[tz * _tw + tx] = _open[z * _w + floori(float(tx) / RES)]
	return m


## The floor's outline as closed loops of corner points (squares), the floor on the left of each edge. A grid point
## where two floor squares touch only at a corner keeps them apart: the walk turns left there, round its own floor.
func _loops() -> Array:
	var starts := {}
	for z in _d:
		for x in _w:
			if _open[z * _w + x] == 0:
				continue
			if not _is_open(Vector2i(x, z - 1)):
				_edge(starts, x + 1, z, x, z)
			if not _is_open(Vector2i(x + 1, z)):
				_edge(starts, x + 1, z + 1, x + 1, z)
			if not _is_open(Vector2i(x, z + 1)):
				_edge(starts, x, z + 1, x + 1, z + 1)
			if not _is_open(Vector2i(x - 1, z)):
				_edge(starts, x, z, x, z + 1)
	var loops: Array = []
	var ring := _w + 1
	for k0: int in starts.keys():
		while not (starts[k0] as Array).is_empty():
			var pts := PackedVector2Array()
			var cur: int = k0
			var dir := Vector2i.ZERO
			var guard := 0
			while guard < 200000:
				guard += 1
				var outs := starts.get(cur, []) as Array
				if outs.is_empty():
					break
				var pick := 0
				if outs.size() > 1 and dir != Vector2i.ZERO:
					var best := 99
					for q in outs.size():
						var e: int = outs[q]
						var step := Vector2i(signi((e % ring) - (cur % ring)), signi(floori(float(e) / ring) - floori(float(cur) / ring)))
						var rank := 0 if step == Vector2i(dir.y, -dir.x) else (1 if step == dir else 2)
						if rank < best:
							best = rank
							pick = q
				var nxt: int = outs[pick]
				outs.remove_at(pick)
				var cx := cur % ring
				var cz := floori(float(cur) / ring)
				pts.append(Vector2(cx, cz))
				dir = Vector2i(signi((nxt % ring) - cx), signi(floori(float(nxt) / ring) - cz))
				cur = nxt
				if cur == k0:
					break
			if pts.size() >= 4:
				loops.append(_simplify(pts))
	return loops


func _edge(starts: Dictionary, x0: int, z0: int, x1: int, z1: int) -> void:
	var ring := _w + 1
	var k := z0 * ring + x0
	if not starts.has(k):
		starts[k] = []
	(starts[k] as Array).append(z1 * ring + x1)


## `pts` without the points that lie on a straight run.
static func _simplify(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[(i + n - 1) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var ab := b - a
		var bc := c - b
		if absf(ab.x * bc.y - ab.y * bc.x) > 0.001 or ab.dot(bc) < 0.0:
			out.append(b)
	return out


## Every corner rounded: a curve from the point `t` back along the edge in to the point `t` along the edge out, bent
## about the corner. `t` is at most half of the shorter edge beside the corner, so a wall one square long barely rounds
## and two neighbouring corners never overlap: a room's corners round wide, a passage's stay close. A corner of the
## floor (which a rounding cuts into) takes the amount's full tangent where the rock behind it is thick enough to give
## the floor back: the curve's control point is pushed out into the rock so the cut over the floor stays about a fifth
## of a square, however wide the corner rounds (rule 2: a quarter at most). A corner of the rock, which the floor
## spills round, rounds less.
func _round(loops: Array) -> Array:
	var out: Array = []
	var cut := ROUND * float(amt["round"])
	for l: Variant in loops:
		var p := l as PackedVector2Array
		var n := p.size()
		var q := PackedVector2Array()
		for i in n:
			var a := p[(i + n - 1) % n]
			var b := p[i]
			var c := p[(i + 1) % n]
			var da := b - a
			var db := c - b
			var la := da.length()
			var lb := db.length()
			if la < 0.001 or lb < 0.001:
				continue
			da /= la
			db /= lb
			var floor_corner := da.x * db.y - da.y * db.x < 0.0
			var t := minf(cut if floor_corner else cut * 0.5, minf(la, lb) * 0.5)
			var ctrl := b
			if floor_corner:
				# How much rock there is to give the floor back round this corner.
				var behind := _sq_at(_thick, b.x + (da.x - db.x) * 0.5, b.y + (da.y - db.y) * 0.5)
				t = minf(t, 0.8 + 2.0 * behind)
				ctrl = b + (da - db) * maxf(t * 0.5 - 0.4, 0.0)
			if t < 0.06:
				q.append(b)
				continue
			var p0 := b - da * t
			var p2 := b + db * t
			var steps := maxi(3, ceili(t * 6.0))
			for s in steps + 1:
				var u := float(s) / steps
				q.append(p0.lerp(ctrl, u).lerp(ctrl.lerp(p2, u), u))
		out.append(q)
	return out


## The texels inside the polygons (their centres, by the even-odd rule).
func _fill(polys: Array) -> PackedByteArray:
	var rows: Array[PackedFloat32Array] = []
	for j in _td:
		rows.append(PackedFloat32Array())
	for l: Variant in polys:
		var p := l as PackedVector2Array
		var n := p.size()
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			if absf(a.y - b.y) < 0.00001:
				continue
			var j0 := maxi(ceili(minf(a.y, b.y) * RES - 0.5), 0)
			var j1 := mini(ceili(maxf(a.y, b.y) * RES - 0.5) - 1, _td - 1)
			for j in range(j0, j1 + 1):
				var zc := (j + 0.5) / RES
				var r: PackedFloat32Array = rows[j]
				r.append(a.x + (zc - a.y) / (b.y - a.y) * (b.x - a.x))
				rows[j] = r
	var m := PackedByteArray()
	m.resize(_tw * _td)
	for j in _td:
		var xs: PackedFloat32Array = rows[j]
		if xs.size() < 2:
			continue
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			var i0 := maxi(ceili(xs[k] * RES - 0.5), 0)
			var i1 := mini(ceili(xs[k + 1] * RES - 0.5) - 1, _tw - 1)
			for i in range(i0, i1 + 1):
				m[j * _tw + i] = 1
	return m


## The signed distance (squares) from each texel to the mask's edge: positive inside it, negative outside. The texels
## beside the edge start half a texel from it, the rest follow by a chamfer sweep.
func _signed(mask: PackedByteArray) -> PackedFloat32Array:
	var n := _tw * _td
	var dist := PackedFloat32Array()
	dist.resize(n)
	var near := STEP * 0.5
	for j in _td:
		for i in _tw:
			var k := j * _tw + i
			var m := mask[k]
			var edge := (i > 0 and mask[k - 1] != m) or (i < _tw - 1 and mask[k + 1] != m) \
				or (j > 0 and mask[k - _tw] != m) or (j < _td - 1 and mask[k + _tw] != m)
			dist[k] = near if edge else FAR
	_chamfer(dist)
	for k in n:
		if mask[k] == 0:
			dist[k] = -dist[k]
	return dist


## Distance (squares) to the nearest texel at 0, by two sweeps of a 3 x 3 chamfer.
func _chamfer(dist: PackedFloat32Array) -> void:
	var diag := STEP * 1.41421356
	for j in _td:
		for i in _tw:
			var k := j * _tw + i
			var v := dist[k]
			if i > 0:
				v = minf(v, dist[k - 1] + STEP)
			if j > 0:
				v = minf(v, dist[k - _tw] + STEP)
				if i > 0:
					v = minf(v, dist[k - _tw - 1] + diag)
				if i < _tw - 1:
					v = minf(v, dist[k - _tw + 1] + diag)
			dist[k] = v
	for j in range(_td - 1, -1, -1):
		for i in range(_tw - 1, -1, -1):
			var k := j * _tw + i
			var v := dist[k]
			if i < _tw - 1:
				v = minf(v, dist[k + 1] + STEP)
			if j < _td - 1:
				v = minf(v, dist[k + _tw] + STEP)
				if i < _tw - 1:
					v = minf(v, dist[k + _tw + 1] + diag)
				if i > 0:
					v = minf(v, dist[k + _tw - 1] + diag)
			dist[k] = v


## A small blur over the texels (1 2 1, across and down): it takes the texels' steps out of the contour and leaves a
## straight wall where it is.
func _blur(field: PackedFloat32Array) -> void:
	var tmp := field.duplicate()
	for j in _td:
		for i in _tw:
			var k := j * _tw + i
			tmp[k] = 0.25 * field[k - 1 if i > 0 else k] + 0.5 * field[k] + 0.25 * field[k + 1 if i < _tw - 1 else k]
	for j in _td:
		for i in _tw:
			var k := j * _tw + i
			field[k] = 0.25 * tmp[k - _tw if j > 0 else k] + 0.5 * tmp[k] + 0.25 * tmp[k + _tw if j < _td - 1 else k]


## The contour field at every grid point: the rounded outline's (a blur of its texels, averaged to the point), moved out
## into the rock by the noise (bays, a wall that bows) and a little in over the floor, never more than a quarter of a
## square in over what the rules grid calls floor.
func _field(sd0: PackedFloat32Array, sd1: PackedFloat32Array) -> void:
	var n := _vw * _vd
	_s.resize(n)
	_s0.resize(n)
	_vbase.resize(n)
	var bays := float(amt["bays"])
	var wander := float(amt["wander"])
	for j in _vd:
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j, _td - 1)
		var z := j * STEP
		var zs0 := clampi(floori(z - 0.001), 0, _d - 1)
		var zs1 := clampi(floori(z + 0.001), 0, _d - 1)
		for i in _vw:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i, _tw - 1)
			var x := i * STEP
			var k := j * _vw + i
			var f1 := 0.25 * (sd1[j0 * _tw + i0] + sd1[j0 * _tw + i1] + sd1[j1 * _tw + i0] + sd1[j1 * _tw + i1])
			var f0 := 0.25 * (sd0[j0 * _tw + i0] + sd0[j0 * _tw + i1] + sd0[j1 * _tw + i0] + sd0[j1 * _tw + i1])
			_s0[k] = f0
			f1 = f0 + (f1 - f0) * _keepw[k]   # a wall with something on it keeps its corners
			var xs0 := clampi(floori(x - 0.001), 0, _w - 1)
			var xs1 := clampi(floori(x + 0.001), 0, _w - 1)
			_vbase[k] = 0.25 * (_base_sq[zs0 * _w + xs0] + _base_sq[zs0 * _w + xs1] + _base_sq[zs1 * _w + xs0] + _base_sq[zs1 * _w + xs1])
			if absf(f1) > 3.0:
				_s[k] = f1
				continue
			var smax := _sq_at(_thick, x, z)
			var o := SWELL * wander + (_nwind.get_noise_2d(x, z) * 0.3 + _n1.get_noise_2d(x, z) * 0.3 + _n2.get_noise_2d(x, z) * 0.1) * wander
			if bays > 0.0:
				var bay := smoothstep(-0.05, 0.4, _nbay.get_noise_2d(x, z)) * bays
				if bay > 0.0:
					o += bay * smax * (0.55 + 0.45 * (0.5 + 0.5 * _ndepth.get_noise_2d(x, z)))
			o = clampf(o, -IN, smax) * _keepw[k]
			if o > 0.0:
				o = minf(o, maxf(minf(minf(x, _w - x), minf(z, _d - z)) - 0.4, 0.0))   # a bay never reaches the map's own edge
			_s[k] = maxf(f1 + o, f0 - INTRUSION)


## `arr` (one value a square) at point (x, z), in squares, read between the squares' middles.
func _sq_at(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x - 0.5, 0.0, _w - 1.001)
	var fz := clampf(z - 0.5, 0.0, _d - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var u := fx - ix
	var v := fz - iz
	var k := iz * _w + ix
	return lerpf(lerpf(arr[k], arr[k + 1], u), lerpf(arr[k + _w], arr[k + _w + 1], u), v)


# --- The rock's surface -------------------------------------------------------------------------------------------

## Heights and positions at every grid point: the wall's face rising steeply from its foot (the rubble's slope) to a
## ragged top, leaning over the cave toward its top; the floor's own level where the cave is wide. Near the contour the
## grid is first drawn onto it, each point moved along the field to the nearest level a third of a square apart (0 the
## foot, -1 the first row up the face ...), so the rows of the surface run along the wall instead of stepping along the
## grid. Then the surface's normals.
func _shape() -> void:
	var n := _vw * _vd
	_h.resize(n)
	_pos.resize(n)
	_nrm.resize(n)
	var moved := PackedVector2Array()   # where each point goes from its grid place
	var along := PackedVector2Array()   # the field's direction there, into the cave
	var level := PackedFloat32Array()   # its field once moved
	moved.resize(n)
	along.resize(n)
	level.resize(n)
	for j in _vd:
		for i in _vw:
			var k := j * _vw + i
			var s := _s[k]
			level[k] = s
			if absf(s) >= 1.2:
				continue
			var gx := _s[k + 1 if i < _vw - 1 else k] - _s[k - 1 if i > 0 else k]
			var gz := _s[k + _vw if j < _vd - 1 else k] - _s[k - _vw if j > 0 else k]
			var mag := sqrt(gx * gx + gz * gz)
			if mag < 0.0001:
				continue
			# How fast the field changes over a square: about 1 beside a wall, down to 0 along the middle of a thin wall or
			# a narrow passage, where there is no one direction into the cave, so nothing there is moved or leaned (it
			# folded the thin walls' tops).
			var rate := mag / (2.0 * STEP)
			var trust := smoothstep(0.5, 0.9, rate)
			along[k] = Vector2(gx / mag, gz / mag) * trust
			var d := (roundf(s / STEP) * STEP - s) * (1.0 - smoothstep(0.7, 1.2, absf(s))) * trust
			moved[k] = Vector2(gx / mag, gz / mag) * (d / clampf(rate, 0.5, 2.0))
			level[k] = s + d
	_s = level
	var top := float(look.get("cave_height", 2.6))
	var lean := LEAN * float(amt["lean"])
	var tal0 := TALUS * float(amt["talus"])
	var face_w := float(amt["face"])
	for j in _vd:
		for i in _vw:
			var k := j * _vw + i
			var x := i * STEP
			var z := j * STEP
			var s := _s[k]
			var px := x + moved[k].x
			var pz := z + moved[k].y
			var h := -TUCK
			if s < TALUS_W:
				var hw := top * (0.95 + 0.05 * _ntop.get_noise_2d(x, z))
				if s < -2.5:
					h = hw
				else:
					hw += (0.3 * _nrough.get_noise_2d(x, z) + 0.2 * _ncrack.get_noise_2d(x, z)) * (1.0 - smoothstep(0.1, 1.5, -s))   # a ragged lip
					var keep := _keepw[k]
					var tal := tal0 * (0.7 + 0.3 * _nrough.get_noise_2d(x, z)) * (0.35 + 0.65 * keep)
					if s >= 0.0:
						var u := 1.0 - s / TALUS_W
						h = tal * u * u
					else:
						var t := -s
						var rise := 1.0 - exp(-t / (face_w * (1.0 + 0.4 * _ncrack.get_noise_2d(x, z))))
						h = tal + (hw - tal) * rise
						var push := lean * hw * rise * (1.0 - smoothstep(0.3, 0.9, t)) * keep
						px += along[k].x * push
						pz += along[k].y * push
					if h < 0.02:
						h = -TUCK
			_h[k] = h
			_pos[k] = Vector3(px, _vbase[k] + h, pz)
	for j in _vd:
		for i in _vw:
			var k := j * _vw + i
			if _s[k] < -2.6:
				_nrm[k] = Vector3.UP   # deep in the rock: a plain top
				continue
			var l := _pos[k - 1 if i > 0 else k]
			var r := _pos[k + 1 if i < _vw - 1 else k]
			var u := _pos[k - _vw if j > 0 else k]
			var d := _pos[k + _vw if j < _vd - 1 else k]
			var nrm := (d - u).cross(r - l)
			_nrm[k] = nrm.normalized() if nrm.length_squared() > 0.000001 else Vector3.UP


## Which quads each rock square draws: its own, except where the whole square is far from any cave (a plain top), and
## the rubble's quads over the floor squares beside it, each given to the nearest rock square.
func _assign() -> void:
	_quads.clear()
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			var k := z * _w + x
			if _rock[k] == 1:
				var nearest := 99.0
				for j in range(z * RES, (z + 1) * RES + 1):
					for i in range(x * RES, (x + 1) * RES + 1):
						nearest = minf(nearest, absf(_s[j * _vw + i]))
				if nearest > 2.2 and _s[(z * RES + (RES >> 1)) * _vw + x * RES + (RES >> 1)] < 0.0:
					_flat[k] = 1
					continue
				for b in RES:
					for a in RES:
						_give(c, x * RES + a, z * RES + b)
			elif _open[k] == 1:
				var rocks: Array[Vector2i] = []
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var n := c + Vector2i(dx, dz)
						if claims(n):
							rocks.append(n)
				if rocks.is_empty():
					continue
				for b in RES:
					for a in RES:
						var qx := x * RES + a
						var qz := z * RES + b
						var qc := Vector2((qx + 0.5) * STEP, (qz + 0.5) * STEP)
						var best := rocks[0]
						var best_d := 99.0
						for r in rocks:
							var gap := Vector2(maxf(maxf(r.x - qc.x, qc.x - (r.x + 1.0)), 0.0), maxf(maxf(r.y - qc.y, qc.y - (r.y + 1.0)), 0.0)).length()
							if gap < best_d:
								best_d = gap
								best = r
						_give(best, qx, qz)


## Quad (qx, qz) goes to `owner` unless the floor's own boxes hide all of it.
func _give(owner: Vector2i, qx: int, qz: int) -> void:
	var k := qz * _vw + qx
	if minf(minf(_s[k], _s[k + 1]), minf(_s[k + _vw], _s[k + _vw + 1])) >= TALUS_W:
		return
	# No rubble over a step in the floor (a ledge's end): the ground it would slope up from is two levels at once.
	if 0.25 * (_s[k] + _s[k + 1] + _s[k + _vw] + _s[k + _vw + 1]) >= -0.02 \
			and maxf(maxf(_vbase[k], _vbase[k + 1]), maxf(_vbase[k + _vw], _vbase[k + _vw + 1])) \
			- minf(minf(_vbase[k], _vbase[k + 1]), minf(_vbase[k + _vw], _vbase[k + _vw + 1])) > 0.5:
		return
	var list: PackedInt32Array = _quads.get(owner, PackedInt32Array())
	list.append(qz * _tw + qx)
	_quads[owner] = list


## Whether the cave has swelled into rock square `c` far enough that floor shows in it.
func _swells(c: Vector2i) -> bool:
	for j in range(c.y * RES, (c.y + 1) * RES + 1):
		for i in range(c.x * RES, (c.x + 1) * RES + 1):
			if _s[j * _vw + i] > 0.02:
				return true
	return false


## Rock square `c`'s patch of the surface, as a piece standing at the square's middle; null when it draws nothing.
func _piece(c: Vector2i) -> MeshInstance3D:
	var origin := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	var verts: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var norms: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d" % [board.place, c.x, c.y])
	var decor := float(amt["decor"])
	for qid: int in (_quads.get(c, PackedInt32Array()) as PackedInt32Array):
		var qz := floori(float(qid) / _tw)
		var qx := qid - qz * _tw
		var k00 := qz * _vw + qx
		var k10 := k00 + 1
		var k01 := k00 + _vw
		var k11 := k01 + 1
		var sa := 0.25 * (_s[k00] + _s[k10] + _s[k01] + _s[k11])
		var slot := 0
		if sa >= -0.02:
			slot = 2
		elif 0.25 * (_nrm[k00].y + _nrm[k10].y + _nrm[k01].y + _nrm[k11].y) >= 0.78:
			slot = 1
		if (qx + qz) % 2 == 0:
			_tri(verts[slot], norms[slot], k00, k10, k11, origin)
			_tri(verts[slot], norms[slot], k00, k11, k01, origin)
		else:
			_tri(verts[slot], norms[slot], k00, k10, k01, origin)
			_tri(verts[slot], norms[slot], k10, k11, k01, origin)
		if decor > 0.0:
			var mid := 0.25 * (_pos[k00] + _pos[k10] + _pos[k01] + _pos[k11])
			if slot == 2 and sa < 0.5 and rng.randf() < 0.2 * decor:
				_rubble(verts[0], norms[0], mid - origin, rng.randf_range(0.05, 0.16), rng)
			elif sa > 0.2 and _s0[k00] < 0.0 and rng.randf() < 0.09 * decor and not board.occupied.has(Vector2i(floori(mid.x), floori(mid.z))):
				_stalagmite(verts[0], norms[0], mid - origin + Vector3(0, TUCK, 0), rng)
	if c.x == 0 or c.y == 0 or c.x == _w - 1 or c.y == _d - 1:
		_skirts(c, verts[1], norms[1], origin)
	if verts[0].is_empty() and verts[1].is_empty() and verts[2].is_empty():
		return null
	var mesh := ArrayMesh.new()
	var mats: Array[Material] = [_mat_face, _mat_top, _mat_talus]
	for slot in 3:
		if verts[slot].is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts[slot]
		arrays[Mesh.ARRAY_NORMAL] = norms[slot]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[slot])
	var mi := MeshInstance3D.new()
	mi.name = "CaveRock"
	mi.mesh = mesh
	mi.position = origin
	mi.set_meta("on_floor", true)   # already on the floor under it (ArenaBoard._lift passes it by)
	mi.set_meta("cave", c)
	return mi


## The map's edge, where the rock carries on past it: a face down past the floor on each outer side of square `c`, so the
## surface doesn't end in a bare sheet.
func _skirts(c: Vector2i, verts: PackedVector3Array, norms: PackedVector3Array, origin: Vector3) -> void:
	for side in 4:
		var out_dir: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
		if board.grid.in_bounds(c + out_dir):
			continue
		var outward := Vector3(out_dir.x, 0, out_dir.y)
		for q in RES:
			var ka := 0
			match side:
				0: ka = c.y * RES * _vw + c.x * RES + q
				1: ka = (c.y * RES + q) * _vw + (c.x + 1) * RES
				2: ka = (c.y + 1) * RES * _vw + c.x * RES + q
				_: ka = (c.y * RES + q) * _vw + c.x * RES
			var kb := ka + (1 if side == 0 or side == 2 else _vw)
			var a := _pos[ka] - origin
			var b := _pos[kb] - origin
			var a_low := Vector3(a.x, _vbase[ka] - 0.3, a.z)
			var b_low := Vector3(b.x, _vbase[kb] - 0.3, b.z)
			var mid := (a + b + a_low + b_low) * 0.25
			_out(verts, norms, a, b, b_low, mid - outward)
			_out(verts, norms, a, b_low, a_low, mid - outward)


## The rock far from any cave: a plain top, in chunks of FAR_CHUNK squares each way (not a node a square, which cost a tenth
## more to build than the blocks it replaces, nor one piece for the whole map, which the fade (SeeThrough) would take whole
## whenever a line of sight crossed any of it: a chunk narrower than SeeThrough.LARGE fades where its box is crossed).
## `stays` keeps a prop that takes one of those squares from putting the rest away.
func _far_rock() -> void:
	var chunk_verts: Dictionary = {}   # chunk -> PackedVector3Array (an array is a value: it is put back after it is added to)
	var chunk_norms: Dictionary = {}
	for z in _d:
		for x in _w:
			if _flat[z * _w + x] == 0:
				continue
			var key := Vector2i(x / FAR_CHUNK, z / FAR_CHUNK)
			var verts: PackedVector3Array = chunk_verts.get(key, PackedVector3Array())
			var norms: PackedVector3Array = chunk_norms.get(key, PackedVector3Array())
			var k00 := z * RES * _vw + x * RES
			var k10 := k00 + RES
			var k01 := k00 + RES * _vw
			var k11 := k01 + RES
			for tri: Array in [[k00, k10, k11], [k00, k11, k01]]:
				for k: int in tri:
					verts.append(_pos[k])
					norms.append(_nrm[k])
			if x == 0 or z == 0 or x == _w - 1 or z == _d - 1:
				_skirts(Vector2i(x, z), verts, norms, Vector3.ZERO)
			chunk_verts[key] = verts
			chunk_norms[key] = norms
	for key: Vector2i in chunk_verts:
		var far := _mesh_of("CaveRockFar", chunk_verts[key] as PackedVector3Array, chunk_norms[key] as PackedVector3Array, _mat_top)
		far.set_meta("stays", true)
		far.set_meta("cave", true)
		board.add_child(far)
		SeeThrough.mark(far)


## One triangle of the surface, from three grid points, in `origin`'s frame.
func _tri(verts: PackedVector3Array, norms: PackedVector3Array, a: int, b: int, c: int, origin: Vector3) -> void:
	verts.append(_pos[a] - origin)
	verts.append(_pos[b] - origin)
	verts.append(_pos[c] - origin)
	norms.append(_nrm[a])
	norms.append(_nrm[b])
	norms.append(_nrm[c])


# --- Things in the cave ------------------------------------------------------------------------------------------

## A pile of broken stone: a six-sided heap, shaded flat.
static func _rubble(verts: PackedVector3Array, norms: PackedVector3Array, at: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var ring: Array[Vector3] = []
	var turn := rng.randf() * TAU
	for q in 6:
		var a := turn + TAU * q / 6.0
		var rr := r * rng.randf_range(0.7, 1.1)
		ring.append(at + Vector3(cos(a) * rr, -0.03, sin(a) * rr * 0.85))
	var apex := at + Vector3(rng.randf_range(-0.2, 0.2) * r, r * rng.randf_range(0.55, 0.95), rng.randf_range(-0.2, 0.2) * r)
	for q in 6:
		_out(verts, norms, apex, ring[q], ring[(q + 1) % 6], at)


## A stalagmite: a tapering spike, a little bent, from the floor at `at` up 0.35 to 1.0 units.
static func _stalagmite(verts: PackedVector3Array, norms: PackedVector3Array, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.4, 1.3)
	var r0 := rng.randf_range(0.07, 0.2) * (0.6 + h * 0.5)
	var bend := Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))
	var turn := rng.randf() * TAU
	var base: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for q in 6:
		var a := turn + TAU * q / 6.0
		base.append(at + Vector3(cos(a) * r0, -0.05, sin(a) * r0))
		mid.append(at + bend * 0.5 + Vector3(cos(a) * r0 * 0.55, h * 0.5, sin(a) * r0 * 0.55))
	var apex := at + bend + Vector3(0, h, 0)
	var pivot := at + Vector3(0, h * 0.4, 0)
	for q in 6:
		var q1 := (q + 1) % 6
		_out(verts, norms, base[q], base[q1], mid[q], pivot)
		_out(verts, norms, base[q1], mid[q1], mid[q], pivot)
		_out(verts, norms, mid[q], mid[q1], apex, pivot)


## A triangle facing away from `pivot`, shaded flat.
static func _out(verts: PackedVector3Array, norms: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, pivot: Vector3) -> void:
	var nrm := (c - a).cross(b - a)
	if nrm.length_squared() < 0.0000001:
		return
	nrm = nrm.normalized()
	var p := b
	var q := c
	if nrm.dot((a + b + c) / 3.0 - pivot) < 0.0:
		p = c
		q = b
		nrm = -nrm
	verts.append(a)
	verts.append(p)
	verts.append(q)
	for i in 3:
		norms.append(nrm)


## The floor's loose stones, and puddles where the place has them (look `cave_puddles`), on floor squares nothing
## stands on: one node, marked `stays` so a prop taking the square it was built in doesn't put it away.
func _floor_decor() -> void:
	var decor := float(amt["decor"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(board.place + "|floor")
	var stones_v := PackedVector3Array()
	var stones_n := PackedVector3Array()
	var puddles_v := PackedVector3Array()
	var puddles_n := PackedVector3Array()
	var puddles := bool(look.get("cave_puddles", false))
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if _open[z * _w + x] == 0 or board.occupied.has(c):
				continue
			if (board.grid.flags(c) & (CombatGrid.LOW | CombatGrid.DIFFICULT | CombatGrid.WATER | CombatGrid.NATURAL)) != 0:
				continue
			var y := _base_sq[z * _w + x]
			for q in 3:
				if rng.randf() < 0.1 * decor:
					var at := Vector3(x + rng.randf_range(0.15, 0.85), y, z + rng.randf_range(0.15, 0.85))
					_rubble(stones_v, stones_n, at, rng.randf_range(0.04, 0.1), rng)
			if puddles and rng.randf() < 0.05 * decor:
				var centre := Vector3(x + rng.randf_range(0.3, 0.7), y + 0.012, z + rng.randf_range(0.3, 0.7))
				var rx := rng.randf_range(0.16, 0.34)
				var rz := rng.randf_range(0.14, 0.3)
				var turn := rng.randf() * TAU
				var rim: Array[Vector3] = []
				for q in 9:
					var a := turn + TAU * q / 9.0
					var wob := rng.randf_range(0.75, 1.05)
					rim.append(centre + Vector3(cos(a) * rx * wob, 0.0, sin(a) * rz * wob))
				for q in 9:
					puddles_v.append(centre)
					puddles_v.append(rim[(q + 1) % 9])
					puddles_v.append(rim[q])
					for e in 3:
						puddles_n.append(Vector3.UP)
	var root := Node3D.new()
	root.name = "CaveDecor"
	root.set_meta("stays", true)
	board.add_child(root)
	if not stones_v.is_empty():
		root.add_child(_mesh_of("Stones", stones_v, stones_n, _mat_face))
	if not puddles_v.is_empty():
		var water := Look.cel_textured("wild/water")
		var wet: Material = water
		if water != null:
			var dark := water.duplicate() as ShaderMaterial
			dark.set_shader_parameter("tint", Color(0.5, 0.56, 0.62))
			wet = dark
		else:
			wet = Look.cel("night")
		root.add_child(_mesh_of("Puddles", puddles_v, puddles_n, wet))


static func _mesh_of(n: String, verts: PackedVector3Array, norms: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.set_meta("on_floor", true)
	return mi


# --- Asking the cave ---------------------------------------------------------------------------------------------

## The contour field at (x, z) in squares: positive in the cave, 0 on the wall's foot.
func field_at(x: float, z: float) -> float:
	var fx := clampf(x * RES, 0.0, _tw - 0.001)
	var fz := clampf(z * RES, 0.0, _td - 0.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := j * _vw + i
	return lerpf(lerpf(_s[k], _s[k + 1], u), lerpf(_s[k + _vw], _s[k + _vw + 1], u), v)


## The rules grid's own outline at (x, z) in squares: positive in floor, negative in rock (distance to the nearest edge).
func outline_at(x: float, z: float) -> float:
	var fx := clampf(x * RES, 0.0, _tw - 0.001)
	var fz := clampf(z * RES, 0.0, _td - 0.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := j * _vw + i
	return lerpf(lerpf(_s0[k], _s0[k + 1], u), lerpf(_s0[k + _vw], _s0[k + _vw + 1], u), v)


## The floor's level under (x, z): its square's, or its nearest floor's where the square is rock.
func floor_at(x: float, z: float) -> float:
	return _base_sq[clampi(floori(z), 0, _d - 1) * _w + clampi(floori(x), 0, _w - 1)]


## How far, on average, the contour stands off the rules grid's outline where the two are within half a square of each
## other (squares): how wavy the walls are.
func wobble() -> float:
	var total := 0.0
	var count := 0
	for k in _vw * _vd:
		if absf(_s0[k]) < 0.5 and absf(_s[k]) < 0.5:
			total += absf(_s[k] - _s0[k])
			count += 1
	return total / maxf(float(count), 1.0)


## How far in over the rules grid's floor the contour comes, at the worst point (squares).
func deepest_intrusion() -> float:
	var worst := 0.0
	for k in _vw * _vd:
		if _s[k] <= 0.0 and _s0[k] > worst:
			worst = _s0[k]
	return worst


## How far the contour stands out in the rock past the rules grid's, at the furthest point (squares).
func widest_swell() -> float:
	var worst := 0.0
	for k in _vw * _vd:
		if _s[k] >= 0.0 and _s0[k] < worst:
			worst = _s0[k]
	return -worst


## The squares this draws.
func rock_squares() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in _d:
		for x in _w:
			if _rock[z * _w + x] == 1:
				out.append(Vector2i(x, z))
	return out


## The rock's highest point over square `c` (world units above its floor).
func top_of(c: Vector2i) -> float:
	var best := 0.0
	for j in range(c.y * RES, (c.y + 1) * RES + 1):
		for i in range(c.x * RES, (c.x + 1) * RES + 1):
			best = maxf(best, _h[j * _vw + i])
	return best


## What the piece over square `c` holds, for the audit: each surface's triangle count and height range.
func describe(c: Vector2i) -> String:
	var piece := _piece(c)
	if piece == null:
		return "%s: nothing (rock %d flat %d swells %s)" % [c, _rock[c.y * _w + c.x], _flat[c.y * _w + c.x], _swells(c)]
	var out := "%s: flat %d swells %s" % [c, _flat[c.y * _w + c.x], _swells(c)]
	var k := (c.y * RES + (RES >> 1)) * _vw + c.x * RES + (RES >> 1)
	out += " | middle point: s %.2f h %.2f normal %s pos %s" % [_s[k], _h[k], _nrm[k], _pos[k]]
	var mesh := piece.mesh as ArrayMesh
	for i in mesh.get_surface_count():
		var v := mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var lo := INF
		var hi := -INF
		for p in v:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		out += " | surface %d: %d tris, y %.2f..%.2f" % [i, v.size() / 3, lo, hi]
	piece.free()
	return out
