class_name GroundRelief
extends RefCounted
## Ground with shape in the Modern look (Improvement Ideas W11, docs/art/atmosphere.md "Ground with shape"): the
## ground under a map's woods rises from the edge of the clearings into banks, with low mounds and hollows among the
## trees, and the land past the map's edge carries on from it. The squares people walk on stay flat at their floor
## level, so everyone still stands on the same 5 ft grid (real heights are F4's); only the woods' squares (ArenaBoard
## tree squares) are shaped. Cosmetic only: the rules grid never sees any of it.

## Samples of the distance field per square.
const RES := 4
## How far past the map the field reaches (squares), so the land's first rows can follow the banks.
const MARGIN := 3
## A bank's height (world units) a square or two into the woods, and the mounds and hollows on top of it.
const BANK := 0.34
const MOUNDS := 0.14
## How far into the woods the bank takes to rise (squares).
const RISE := 1.8
## Set by art QA tools only, to shoot a place as it was before (tools/capture/land_capture.gd LAND_NO_RELIEF).
static var off := false

var board: ArenaBoard
var _w := 0
var _d := 0
var _nx := 0
var _nz := 0
## Distance (squares) from each sample to the nearest flat square: one the board draws flat (walked on, built on,
## water), anything on the map but a tree square or empty ground.
var _dist := PackedFloat32Array()


static func enabled() -> bool:
	return Look.modern() and not off


static func build(board_: ArenaBoard) -> GroundRelief:
	var r := GroundRelief.new()
	r.board = board_
	r._w = board_.grid.width
	r._d = board_.grid.depth
	r._field()
	return r


## A square the board draws flat at its floor level: on the map and neither a tree square nor empty ground.
func is_flat(c: Vector2i) -> bool:
	var g := board.grid
	if not g.in_bounds(c):
		return false
	if board.is_tree(c):
		return false
	return not (g.has_flag(c, CombatGrid.VOID) and not g.has_flag(c, CombatGrid.WATER))


func _field() -> void:
	_nx = (_w + 2 * MARGIN) * RES + 1
	_nz = (_d + 2 * MARGIN) * RES + 1
	_dist.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var p := _point(i, j)
			# A sample on a flat square's edge or inside it is at distance 0 (the squares' corners are shared).
			var flat := false
			for dz: float in [-0.001, 0.001]:
				for dx: float in [-0.001, 0.001]:
					if is_flat(Vector2i(floori(p.x + dx), floori(p.y + dz))):
						flat = true
			_dist[j * _nx + i] = 0.0 if flat else 1e6
	var s := 1.0 / RES
	var diag := s * 1.41421
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var v := _dist[k]
			if i > 0:
				v = minf(v, _dist[k - 1] + s)
			if j > 0:
				v = minf(v, _dist[k - _nx] + s)
				if i > 0:
					v = minf(v, _dist[k - _nx - 1] + diag)
				if i < _nx - 1:
					v = minf(v, _dist[k - _nx + 1] + diag)
			_dist[k] = v
	for j in range(_nz - 1, -1, -1):
		for i in range(_nx - 1, -1, -1):
			var k := j * _nx + i
			var v := _dist[k]
			if i < _nx - 1:
				v = minf(v, _dist[k + 1] + s)
			if j < _nz - 1:
				v = minf(v, _dist[k + _nx] + s)
				if i < _nx - 1:
					v = minf(v, _dist[k + _nx + 1] + diag)
				if i > 0:
					v = minf(v, _dist[k + _nx - 1] + diag)
			_dist[k] = v


func _point(i: int, j: int) -> Vector2:
	return Vector2(float(i) / RES - MARGIN, float(j) / RES - MARGIN)


## How far a point is from the nearest flat square (squares; 0 on one), read off the field.
func distance(p: Vector2) -> float:
	var fi := clampf((p.x + MARGIN) * RES, 0.0, _nx - 1.001)
	var fj := clampf((p.y + MARGIN) * RES, 0.0, _nz - 1.001)
	var i := floori(fi)
	var j := floori(fj)
	var fx := fi - i
	var fz := fj - j
	var a := _dist[j * _nx + i]
	var b := _dist[j * _nx + i + 1]
	var c := _dist[(j + 1) * _nx + i]
	var e := _dist[(j + 1) * _nx + i + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, e, fx), fz)


## The ground's height at a point of the map (0 on and beside the flat squares): a bank rising into the woods with
## mounds and hollows on it.
func height(p: Vector2) -> float:
	var d := distance(p)
	if d <= 0.0:
		return 0.0
	var bank := BANK * smoothstep(0.0, RISE, d)
	var n := _noise(p * 0.55) * 0.65 + _noise(p * 1.3 + Vector2(4.7, 1.9)) * 0.35
	return bank + (n - 0.42) * MOUNDS * smoothstep(0.3, RISE, d) * 2.0


func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


## The shaped ground over the map's tree squares, RES quads a side per square, in `material`. Where it meets the
## clearing it tucks just under the board's own ground so the two never flicker.
func mesh(material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			if not board.is_tree(c):
				continue
			any = true
			for sj in RES:
				for si in RES:
					var p0 := Vector2(x + float(si) / RES, z + float(sj) / RES)
					var q := 1.0 / RES
					var corners: Array[Vector2] = [p0, p0 + Vector2(q, 0), p0 + Vector2(0, q), p0 + Vector2(q, q)]
					var v: Array[Vector3] = []
					for p in corners:
						v.append(Vector3(p.x, height(p) - 0.012, p.y))
					for t: Vector3 in [v[0], v[1], v[2], v[1], v[3], v[2]]:
						st.add_vertex(t)
	if not any:
		return null
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Relief"
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
