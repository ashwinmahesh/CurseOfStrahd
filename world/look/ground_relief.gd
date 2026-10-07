class_name GroundRelief
extends RefCounted
## Ground with shape in the Modern look (Improvement Ideas W11, docs/art/atmosphere.md "Ground with shape"). On an
## outdoor wild map the ground people walk on is drawn as one shaped skin with shallow hollows; it never rises above
## the squares' floor level, so tokens, grid overlays and spell templates still stand on the same 5 ft grid (real
## heights are F4's), and the board's own flat floor boxes under it stop drawing themselves (ArenaBoard.floor_box).
## Under the map's woods the ground rises into banks with mounds, and the land past the edge carries on from both.
## The roads between the map's ways out are laid here for anything that follows them (the surfaces lane's wheel-rut
## decals). Cosmetic only: the rules grid never sees any of it.
##
## Built for speed (a place is built on every arrival): the height of every grid point is worked out once, from
## distance fields over flat arrays, and the meshes index that one grid.

## Grid points per square, and how far past the map the grid reaches (squares), so the land's first rows can follow
## the banks.
const RES := 2
const MARGIN := 3
## A bank's height (world units) a square or two into the woods, and the mounds and hollows on top of it.
const BANK := 0.34
const MOUNDS := 0.14
## How far into the woods the bank takes to rise (squares).
const RISE := 1.8
## The walked ground: how deep its hollows go (never deeper, so feet are at most this far above the ground), and how
## far from a square drawn flat they take to reach full depth.
const HOLLOW := 0.08
const DEEPEST := 0.1
const SETTLE := 0.7
## Each square's kind on the grid of cells.
const FLAT := 0
const WOODS := 1
const SKIN := 2
const OPEN := 3   ## empty ground the land covers, and everything past the map
## Set by art QA tools only, to shoot a place as it was before (tools/capture/land_capture.gd LAND_NO_RELIEF).
static var off := false
## Reliefs built on earlier visits, by place and board shape (a place comes out the same every time); the newest few.
static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []

var board: ArenaBoard
var _w := 0
var _d := 0
## Grid points across and down (over the map and MARGIN round it).
var _nx := 0
var _nz := 0
## Squares whose ground the skin draws: cell -> the material their floor box had.
var _skin: Dictionary = {}
## Each map square's kind (FLAT, WOODS, SKIN, OPEN), row by row.
var _kind := PackedByteArray()
## The height at every grid point.
var _h := PackedFloat32Array()
## The ways between the map's ways out, as smoothed lines through square middles.
var _roads: Array[PackedVector2Array] = []


static func enabled() -> bool:
	return Look.modern() and not off


## `loc` is the location's data (its exits lay the roads, its traps keep their squares as the board drew them). The
## skin is drawn on wild outdoor maps only.
static func build(board_: ArenaBoard, loc: Dictionary) -> GroundRelief:
	var key := "%s|%dx%d|%d|%d" % [board_.place, board_.grid.width, board_.grid.depth, board_.occupied.size(),
		board_.house_cells.size()]
	var r := GroundRelief.new()
	r.board = board_
	r._w = board_.grid.width
	r._d = board_.grid.depth
	if _kept.has(key):
		# Built on an earlier visit, the same then as now: share its arrays (its floors' materials are the board's
		# own, cached by Look).
		var k := _kept[key] as GroundRelief
		r._skin = k._skin
		r._kind = k._kind
		r._h = k._h
		r._nx = k._nx
		r._nz = k._nz
		r._roads = k._roads
		return r
	if board_.theme in ArenaBoard.WILD:
		r._choose_skin(AtmosphereLand._trap_cells(loc))
		r._lay_roads(loc)
	r._kinds()
	r._heights()
	_kept[key] = r
	_kept_order.append(key)
	while _kept_order.size() > AtmosphereLand.KEEP:
		_kept.erase(_kept_order.pop_front())
	return r


## A square drawn at its floor level that the woods' banks rise away from: on the map and neither a tree square nor
## empty ground.
func is_flat(c: Vector2i) -> bool:
	var k := _kind_of(c)
	return k == FLAT or k == SKIN


## The squares people walk on whose ground is a plain floor box at floor level in the place's floor (or mud)
## material, that nothing stands on and no trap lies under (a pit opens its floor box).
func _choose_skin(traps: Dictionary) -> void:
	var g := board.grid
	var plain := board.floor_material()
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			var f := g.flags(c)
			if (f & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)) != 0 or board.floor_y(c) != 0.0:
				continue
			if board.occupied.has(c) or board.door_cells.has(c) or board.house_cells.has(c) or traps.has(c):
				continue
			var box := board.floor_box(c)
			if box == null or box.material_override == null:
				continue
			if box.material_override != plain and (f & CombatGrid.DIFFICULT) == 0:
				continue   # a room's own floor, a yard's flags: left as the board drew them
			_skin[c] = box.material_override


func _kinds() -> void:
	var g := board.grid
	_kind.resize(_w * _d)
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			var k := FLAT
			if _skin.has(c):
				k = SKIN
			elif board.is_tree(c):
				k = WOODS
			elif g.has_flag(c, CombatGrid.VOID) and not g.has_flag(c, CombatGrid.WATER):
				k = OPEN
			_kind[z * _w + x] = k


func _kind_of(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _d:
		return OPEN
	return _kind[c.y * _w + c.x]


## Roads run along the shortest walk between each two ways out on the map's edge that are apart.
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


## The roads between the ways out (smoothed lines through square middles), for anything that follows them.
func roads() -> Array[PackedVector2Array]:
	return _roads


## Does the skin draw the ground of square `c`?
func skinned(c: Vector2i) -> bool:
	return _skin.has(c)


## Distance (squares) from each grid point to the nearest point touching a square of the kinds in `zero` (a mask).
func _field(touch: PackedInt32Array, zero: int) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(_nx * _nz)
	for k in _nx * _nz:
		f[k] = 0.0 if (touch[k] & zero) != 0 else 1e6
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


## Every grid point's height, once: on a point touching the walked ground, its hollows (never above 0), settling to 0
## toward any square drawn flat; elsewhere the woods' bank rising from the flat and walked squares, with mounds.
func _heights() -> void:
	_nx = (_w + 2 * MARGIN) * RES + 1
	_nz = (_d + 2 * MARGIN) * RES + 1
	# The kinds of the squares touching each grid point, as a bit mask (1 << kind): a point on a square's edge touches
	# the squares either side, a point inside one only that one. Worked out per column and row once.
	var cols := PackedInt32Array()
	cols.resize(_nx * 2)
	for i in _nx:
		var x := i / RES - MARGIN
		cols[i * 2] = x - 1 if i % RES == 0 else x
		cols[i * 2 + 1] = x
	var rows := PackedInt32Array()
	rows.resize(_nz * 2)
	for j in _nz:
		var z := j / RES - MARGIN
		rows[j * 2] = z - 1 if j % RES == 0 else z
		rows[j * 2 + 1] = z
	var bit := PackedInt32Array()
	bit.resize((_w + 2) * (_d + 2))
	for z in _d + 2:
		for x in _w + 2:
			bit[z * (_w + 2) + x] = 1 << _kind_of(Vector2i(x - 1, z - 1))
	var touch := PackedInt32Array()
	touch.resize(_nx * _nz)
	var out_bit := 1 << OPEN
	for j in _nz:
		var z0 := rows[j * 2]
		var z1 := rows[j * 2 + 1]
		for i in _nx:
			var x0 := cols[i * 2]
			var x1 := cols[i * 2 + 1]
			var m := 0
			for c: Vector2i in [Vector2i(x0, z0), Vector2i(x1, z0), Vector2i(x0, z1), Vector2i(x1, z1)]:
				if c.x < -1 or c.y < -1 or c.x > _w or c.y > _d:
					m |= out_bit
				else:
					m |= bit[(c.y + 1) * (_w + 2) + c.x + 1]
			touch[j * _nx + i] = m
	var bank_d := _field(touch, (1 << FLAT) | (1 << SKIN))
	var skin_d := _field(touch, (1 << FLAT) | (1 << WOODS) | (1 << OPEN))
	_h.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var p := Vector2(float(i) / RES - MARGIN, float(j) / RES - MARGIN)
			var h := 0.0
			if (touch[k] & (1 << SKIN)) != 0:
				var settle := smoothstep(0.0, SETTLE, skin_d[k])
				if settle > 0.0:
					h = maxf(-HOLLOW * smoothstep(0.42, 0.78, _noise(p * 0.8 + Vector2(11.3, 2.7))) * settle, -DEEPEST)
			elif bank_d[k] > 0.0:
				var d := bank_d[k]
				var n := _noise(p * 0.55) * 0.65 + _noise(p * 1.3 + Vector2(4.7, 1.9)) * 0.35
				h = BANK * smoothstep(0.0, RISE, d) + (n - 0.42) * MOUNDS * smoothstep(0.3, RISE, d) * 2.0
			_h[k] = h


## The ground's height at a point of the map (0 on squares drawn flat), read off the grid.
func height(p: Vector2) -> float:
	var fi := clampf((p.x + MARGIN) * RES, 0.0, _nx - 1.001)
	var fj := clampf((p.y + MARGIN) * RES, 0.0, _nz - 1.001)
	var i := floori(fi)
	var j := floori(fj)
	var fx := fi - i
	var fz := fj - j
	var k := j * _nx + i
	return lerpf(lerpf(_h[k], _h[k + 1], fx), lerpf(_h[k + _nx], _h[k + _nx + 1], fx), fz)


func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


## The walked squares' floor boxes stop drawing themselves (render layers 0): the skin draws that ground.
func quiet_floors() -> void:
	for c: Vector2i in _skin:
		var box := board.floor_box(c)
		if box != null:
			box.layers = 0


## The shaped ground, leaving out the `hidden` squares: the skin over the walked squares in their floor's material(s)
## and the banks over the woods in `woods` (tucked just under the board's own ground where they meet the clearing, so
## the two never flicker). One grid of points for both; each mesh only indexes the squares it draws.
func meshes(woods: Material, hidden: Dictionary = {}) -> Array[MeshInstance3D]:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(_nx * _nz)
	normals.resize(_nx * _nz)
	var e := 2.0 / RES
	for j in _nz:
		var row := j * _nx
		for i in _nx:
			var k := row + i
			verts[k] = Vector3(float(i) / RES - MARGIN, _h[k], float(j) / RES - MARGIN)
			var dx := _h[mini(i + 1, _nx - 1) + row] - _h[maxi(i - 1, 0) + row]
			var dz := _h[mini(j + 1, _nz - 1) * _nx + i] - _h[maxi(j - 1, 0) * _nx + i]
			normals[k] = Vector3(-dx, e, -dz).normalized()
	# The materials drawn, then each one's squares in a pass of its own (an index array held in a dictionary would be
	# copied every time it grew).
	var mats: Array[Material] = []
	var cell_mat: Array[Material] = []
	cell_mat.resize(_w * _d)
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if hidden.has(c):
				continue
			var m: Material = null
			match _kind[z * _w + x]:
				SKIN:
					m = _skin[c] as Material
				WOODS:
					m = woods
			cell_mat[z * _w + x] = m
			if m != null and not m in mats:
				mats.append(m)
	var groups := {}
	for m in mats:
		var n := 0
		for k in _w * _d:
			if cell_mat[k] == m:
				n += 1
		var idx := PackedInt32Array()
		idx.resize(n * RES * RES * 6)
		var f := 0
		for z in _d:
			for x in _w:
				if cell_mat[z * _w + x] != m:
					continue
				var i0 := (x + MARGIN) * RES
				var j0 := (z + MARGIN) * RES
				for sj in RES:
					for si in RES:
						var a := (j0 + sj) * _nx + i0 + si
						idx[f] = a
						idx[f + 1] = a + 1
						idx[f + 2] = a + _nx
						idx[f + 3] = a + 1
						idx[f + 4] = a + _nx + 1
						idx[f + 5] = a + _nx
						f += 6
		groups[m] = idx
	var out: Array[MeshInstance3D] = []
	var walked := 0
	for mat: Material in groups:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = groups[mat]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "Banks" if mat == woods else "Walked%d" % walked
		if mat != woods:
			walked += 1
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mat == woods:
			mi.position.y = -0.012
		out.append(mi)
	return out
