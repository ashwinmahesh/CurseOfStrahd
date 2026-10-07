class_name GroundRelief
extends RefCounted
## Ground with shape in the Modern look (Improvement Ideas W11, docs/art/atmosphere.md "Ground with shape"). On an
## outdoor wild map the ground people walk on is drawn as one shaped skin: shallow hollows, and wheel ruts along the
## way between its ways out. It never rises above the squares' floor level, so tokens, grid overlays and spell
## templates still stand on the same 5 ft grid (real heights are F4's); each square's piece hangs on the board's own
## floor box (ArenaBoard.floor_box), which stops drawing itself, so hiding the box hides the ground. Under the map's
## woods the ground rises into banks with mounds and hollows, and the land past the edge carries on from both.
## Cosmetic only: the rules grid never sees any of it.

## Samples of the distance fields per square, and quads a side of the woods' mesh per square; the walked ground's
## skin has twice as many, so the wheel ruts have a shape.
const RES := 4
const SKIN_RES := 8
## How far past the map the fields reach (squares), so the land's first rows can follow the banks.
const MARGIN := 3
## A bank's height (world units) a square or two into the woods, and the mounds and hollows on top of it.
const BANK := 0.34
const MOUNDS := 0.14
## How far into the woods the bank takes to rise (squares).
const RISE := 1.8
## The walked ground: how deep its hollows and ruts go (never deeper, so feet are at most this far above the ground),
## and how far from a square drawn flat they take to reach full depth.
const HOLLOW := 0.08
const RUT := 0.09
const DEEPEST := 0.12
const SETTLE := 0.7
## Set by art QA tools only, to shoot a place as it was before (tools/capture/land_capture.gd LAND_NO_RELIEF).
static var off := false

var board: ArenaBoard
var _w := 0
var _d := 0
var _nx := 0
var _nz := 0
## Squares whose ground the skin draws: cell -> the material their floor box had.
var _skin: Dictionary = {}
## Distance (squares) from each sample to the nearest square that isn't the woods' (walked on, built on, water), and
## to the nearest square the skin doesn't draw.
var _bank_d := PackedFloat32Array()
var _skin_d := PackedFloat32Array()
## The ways between the map's ways out, as smoothed lines through square middles (wheel ruts run along them).
var _roads: Array[PackedVector2Array] = []


static func enabled() -> bool:
	return Look.modern() and not off


## `loc` is the location's data (its exits lay the roads). The skin is drawn on wild outdoor maps only.
static func build(board_: ArenaBoard, loc: Dictionary) -> GroundRelief:
	var r := GroundRelief.new()
	r.board = board_
	r._w = board_.grid.width
	r._d = board_.grid.depth
	if board_.theme in ArenaBoard.WILD:
		r._choose_skin()
		r._lay_roads(loc)
	r._nx = (r._w + 2 * MARGIN) * RES + 1
	r._nz = (r._d + 2 * MARGIN) * RES + 1
	r._bank_d = r._field(r.is_flat)
	r._skin_d = r._field(func(c: Vector2i) -> bool: return not r._skin.has(c))
	return r


## A square drawn at its floor level that the woods' banks rise away from: on the map and neither a tree square nor
## empty ground.
func is_flat(c: Vector2i) -> bool:
	var g := board.grid
	if not g.in_bounds(c):
		return false
	if board.is_tree(c):
		return false
	return not (g.has_flag(c, CombatGrid.VOID) and not g.has_flag(c, CombatGrid.WATER))


## The squares people walk on whose ground is a plain floor box at floor level in the place's floor (or mud)
## material, and that nothing stands on.
func _choose_skin() -> void:
	var g := board.grid
	var plain := board.floor_material()
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			var f := g.flags(c)
			if (f & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)) != 0 or board.floor_y(c) != 0.0:
				continue
			if board.occupied.has(c) or board.door_cells.has(c) or board.house_cells.has(c):
				continue
			var box := board.floor_box(c)
			if box == null or box.material_override == null:
				continue
			if box.material_override != plain and (f & CombatGrid.DIFFICULT) == 0:
				continue   # a room's own floor, a yard's flags: left as the board drew them
			_skin[c] = box.material_override


## Wheel ruts run along the shortest walk between each two ways out on the map's edge that are apart.
func _lay_roads(loc: Dictionary) -> void:
	var outs: Array[Vector2i] = []
	for e: Variant in loc.get("exits", []) as Array:
		var a := (e as Dictionary).get("cell", []) as Array
		if a.size() < 2:
			continue
		var c := Vector2i(int(a[0]), int(a[1]))
		if c.x == 0 or c.y == 0 or c.x == _w - 1 or c.y == _d - 1:
			outs.append(c)
	for i in outs.size():
		for j in range(i + 1, outs.size()):
			if (outs[i] - outs[j]).length() < 6.0:
				continue
			var path := _walk(outs[i], outs[j])
			if path.size() > 2:
				_roads.append(_smoothed(path))


## The shortest walk between two squares over walkable ground (four ways), as square middles; empty if none.
func _walk(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var g := board.grid
	var prev := {from: from}
	var todo: Array[Vector2i] = [from]
	var i := 0
	while i < todo.size():
		var c := todo[i]
		i += 1
		if c == to:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not g.in_bounds(n) or prev.has(n):
				continue
			if g.has_flag(n, CombatGrid.WALL) or g.has_flag(n, CombatGrid.WATER) or g.has_flag(n, CombatGrid.VOID):
				continue
			prev[n] = c
			todo.append(n)
	var out := PackedVector2Array()
	if not prev.has(to):
		return out
	var c := to
	while c != from:
		out.append(Vector2(c) + Vector2(0.5, 0.5))
		c = prev[c] as Vector2i
	out.append(Vector2(from) + Vector2(0.5, 0.5))
	out.reverse()
	return out


## Corners cut twice (Chaikin), so a road bends instead of turning on the grid.
static func _smoothed(pts: PackedVector2Array) -> PackedVector2Array:
	var cur := pts
	for k in 2:
		var nxt := PackedVector2Array([cur[0]])
		for i in cur.size() - 1:
			nxt.append(cur[i].lerp(cur[i + 1], 0.25))
			nxt.append(cur[i].lerp(cur[i + 1], 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


## A distance field (squares) from the squares `zero` says yes to, RES samples a square over the map and MARGIN.
func _field(zero: Callable) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var p := _point(i, j)
			# A sample on such a square's edge or inside it is at distance 0 (the squares' corners are shared).
			var on := false
			for dz: float in [-0.001, 0.001]:
				for dx: float in [-0.001, 0.001]:
					if bool(zero.call(Vector2i(floori(p.x + dx), floori(p.y + dz)))):
						on = true
			f[j * _nx + i] = 0.0 if on else 1e6
	var s := 1.0 / RES
	var diag := s * 1.41421
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var v := f[k]
			if i > 0:
				v = minf(v, f[k - 1] + s)
			if j > 0:
				v = minf(v, f[k - _nx] + s)
				if i > 0:
					v = minf(v, f[k - _nx - 1] + diag)
				if i < _nx - 1:
					v = minf(v, f[k - _nx + 1] + diag)
			f[k] = v
	for j in range(_nz - 1, -1, -1):
		for i in range(_nx - 1, -1, -1):
			var k := j * _nx + i
			var v := f[k]
			if i < _nx - 1:
				v = minf(v, f[k + 1] + s)
			if j < _nz - 1:
				v = minf(v, f[k + _nx] + s)
				if i < _nx - 1:
					v = minf(v, f[k + _nx + 1] + diag)
				if i > 0:
					v = minf(v, f[k + _nx - 1] + diag)
			f[k] = v
	return f


func _point(i: int, j: int) -> Vector2:
	return Vector2(float(i) / RES - MARGIN, float(j) / RES - MARGIN)


func _sample(f: PackedFloat32Array, p: Vector2) -> float:
	var fi := clampf((p.x + MARGIN) * RES, 0.0, _nx - 1.001)
	var fj := clampf((p.y + MARGIN) * RES, 0.0, _nz - 1.001)
	var i := floori(fi)
	var j := floori(fj)
	var fx := fi - i
	var fz := fj - j
	return lerpf(lerpf(f[j * _nx + i], f[j * _nx + i + 1], fx), lerpf(f[(j + 1) * _nx + i], f[(j + 1) * _nx + i + 1], fx), fz)


## How far a point is from the nearest square that isn't the woods' (squares; 0 on one).
func distance(p: Vector2) -> float:
	return _sample(_bank_d, p)


## The roads the wheel ruts run along (smoothed lines through square middles), for anything that follows them.
func roads() -> Array[PackedVector2Array]:
	return _roads


## Does the skin draw the ground of square `c`?
func skinned(c: Vector2i) -> bool:
	return _skin.has(c)


## The ground's height at a point of the map: the walked ground's hollows and ruts (never above 0), a bank rising
## into the woods with mounds on it, 0 on squares drawn flat.
func height(p: Vector2) -> float:
	var c := Vector2i(floori(p.x), floori(p.y))
	if _skin.has(c):
		return _walked(p)
	var d := distance(p)
	if d <= 0.0:
		return 0.0
	var bank := BANK * smoothstep(0.0, RISE, d)
	var n := _noise(p * 0.55) * 0.65 + _noise(p * 1.3 + Vector2(4.7, 1.9)) * 0.35
	return bank + (n - 0.42) * MOUNDS * smoothstep(0.3, RISE, d) * 2.0


## The walked ground: broad shallow hollows, a fine unevenness, and two wheel ruts along each road, settling to 0
## toward any square drawn flat.
func _walked(p: Vector2) -> float:
	var settle := smoothstep(0.0, SETTLE, _sample(_skin_d, p))
	if settle <= 0.0:
		return 0.0
	var broad := _noise(p * 0.8 + Vector2(11.3, 2.7))
	var h := -HOLLOW * smoothstep(0.42, 0.78, broad) - 0.015 * _noise(p * 1.9 + Vector2(3.1, 8.4))
	var r := _road_distance(p)
	if r < 0.7:
		h -= RUT * exp(-pow((r - 0.21) / 0.08, 2.0))
	return maxf(h * settle, -DEEPEST)


## How far a point is from the middle of the nearest road (squares; a large number with no road).
func _road_distance(p: Vector2) -> float:
	var best := 1e6
	for line in _roads:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


## The walked ground's skin, square by square: each skinned square's floor box gets its shaped piece as a child and
## stops drawing itself (render layers 0), so whatever hides or shows the box (HiddenAreas, a pit opening, a stairwell)
## hides or shows its piece of ground too.
func dress_floors() -> void:
	for c: Vector2i in _skin:
		var box := board.floor_box(c)
		if box == null:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_square(st, c, 0.0, SKIN_RES, box.position)
		_skirts(st, c, box.position)
		var mi := MeshInstance3D.new()
		mi.name = "Shaped"
		mi.mesh = st.commit()
		mi.material_override = box.material_override
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.add_child(mi)
		box.layers = 0


## The banks over the map's tree squares, leaving out the `hidden` ones, in `material`; null if there are none. Where
## they meet the clearing they tuck just under the board's own ground so the two never flicker.
func woods_mesh(material: Material, hidden: Dictionary = {}) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if board.is_tree(c) and not hidden.has(c):
				_square(st, c, -0.012, RES, Vector3.ZERO)
				any = true
	if not any:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Banks"
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The ground's slope at a point, as a normal, from the height either side, so neighbouring pieces meet smoothly.
func normal_at(p: Vector2) -> Vector3:
	var e := 0.04
	var dx := height(p + Vector2(e, 0)) - height(p - Vector2(e, 0))
	var dz := height(p + Vector2(0, e)) - height(p - Vector2(0, e))
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Square `c` cut into res x res quads on the ground's height (plus `lift`), less `origin` (the node it hangs on).
func _square(st: SurfaceTool, c: Vector2i, lift: float, res: int, origin: Vector3) -> void:
	var q := 1.0 / res
	for sj in res:
		for si in res:
			var p0 := Vector2(c.x + si * q, c.y + sj * q)
			var corners: Array[Vector2] = [p0, p0 + Vector2(q, 0), p0 + Vector2(0, q), p0 + Vector2(q, q)]
			for k: int in [0, 1, 2, 1, 3, 2]:
				var p := corners[k]
				st.set_normal(normal_at(p))
				st.add_vertex(Vector3(p.x, height(p) + lift, p.y) - origin)


## Walls of earth down the sides of square `c` facing a square the skin doesn't draw (the shore of the water beside
## it), as the floor box's sides were; drawn both ways round, so they show from either side.
func _skirts(st: SurfaceTool, c: Vector2i, origin: Vector3) -> void:
	var x := float(c.x)
	var z := float(c.y)
	var sides := {Vector2i(0, -1): [Vector2(x, z), Vector2(x + 1, z)], Vector2i(1, 0): [Vector2(x + 1, z), Vector2(x + 1, z + 1)],
		Vector2i(0, 1): [Vector2(x, z + 1), Vector2(x + 1, z + 1)], Vector2i(-1, 0): [Vector2(x, z), Vector2(x, z + 1)]}
	for side: Vector2i in sides:
		if _skin.has(c + side):
			continue
		var ends := sides[side] as Array
		var n := Vector3(side.x, 0, side.y)
		for k in SKIN_RES:
			var p0 := (ends[0] as Vector2).lerp(ends[1] as Vector2, float(k) / SKIN_RES)
			var p1 := (ends[0] as Vector2).lerp(ends[1] as Vector2, float(k + 1) / SKIN_RES)
			var t0 := Vector3(p0.x, height(p0), p0.y) - origin
			var t1 := Vector3(p1.x, height(p1), p1.y) - origin
			var b0 := Vector3(p0.x, -0.2, p0.y) - origin
			var b1 := Vector3(p1.x, -0.2, p1.y) - origin
			for v: Vector3 in [t0, t1, b0, t1, b1, b0]:
				st.set_normal(n)
				st.add_vertex(v)
			for v: Vector3 in [t0, b0, t1, t1, b0, b1]:
				st.set_normal(n)
				st.add_vertex(v)
