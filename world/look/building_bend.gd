class_name BuildingBend
extends RefCounted
## Natural shapes for buildings (the vault's Natural Maps Plan, B1 and rule 4; owner 2026-10-19: "We can give buildings
## natural shapes instead of their straight lines. Natural edges can bend into a square the party can stand on."). A
## bend is one smooth displacement of a building's vertices, worked out once when its meshes are merged
## (BuildingKit.merge): the walls lean a few degrees and bow along their length, corners drift off true, a timber
## house's upper storey juts out a touch, the roof ridge sags toward its middle and the eaves wave, a chimney leans.
## Only vertices move (no new art), so a window, a door bay or a beam goes with the wall it is in, and anything hung on a
## wall asks `frame` where the wall is now (TownBuilder.face_taken). The same field serves a yard wall, a palisade of
## logs and a building-sized prop (ModelPiece), each with its own scale.
## Rule 2 of the plan: nothing moves more than the style's reach sideways (MAX_OUT, a quarter of a square, unless the catalog
## says more: Ashwin chose half a square for timber walls, 2026-10-19), so a token in the middle of the
## square beside a bent wall and its ring stay clear and pickable. The rules grid is never touched.
## How far a building bends is per style (catalog building_kit "bend"): timber most, stone less, Castle Ravenloft none.
## The Classic look is frozen and never bends.

## The farthest any part of a building moves sideways (squares): a wall is taller than a token's knee, so a quarter.
const MAX_OUT := 0.25
## What the field itself is held to: a module bent whole (fold) can reach a few hundredths past the field at its far corners.
const FIELD_MAX := 0.2
## A roof is overhead, not a wall a token stands beside: over the walls' top the field may reach further, up to this at the
## ridge (which stands over the middle of the building, so it moves within the footprint, not into the street).
const ROOF_MAX := 0.45
## What simplex noise (about +-0.7 at most) is scaled by to run about +-1.
const NORM := 1.2

const HOUSE := 0
const WALL := 1
const LOGS := 2
const PROP := 3

var kind := HOUSE
var amount := 1.0
## How far a wall of this building may reach sideways (catalog building_kit.bend.reach, else MAX_OUT), what the field itself is
## held to (a little under, since a module bent whole overshoots at its far corners) and what the roof may reach at its ridge.
var reach := MAX_OUT
var _field_max := FIELD_MAX
var _roof_max := ROOF_MAX
var _noise := _plain_noise()
## The height the lean is measured over (the walls' top, for a house), and the roof's rise over it.
var _h := 2.2
var _rise := 1.0
## The lean (sideways at height _h), how much it varies from place to place (a palisade's logs lean each their own
## way), and the noise scale of that.
var _lean := Vector2.ZERO
var _lean_var := 0.0
var _lean_freq := 1.0
## A palisade's logs take their lean along the line from the wave's own noise (one sample less for each of its 50,000 points).
var _lean_shares_wave := false
## How far the walls bow and drift sideways, the noise scale across and up, and how much of that the foot keeps.
var _bow := 0.07
## (A house is bent module by module, to first order, so its field stays smooth over a square: waves ten squares long.)
var _freq := 0.1
var _freq_y := 0.16
var _foot := 0.85
## How far the upper storey juts out.
var _over := 0.0
## The roof ridge's sag in the middle, its ends, and how much the eaves and wall tops wave (up and down).
var _sag := 0.0
var _ridge_a := Vector2.ZERO
var _ridge_b := Vector2.ZERO
var _wave := 0.0
var _wave_freq := 0.28
## How far the whole building is turned about its middle at the footing and how much further at the eaves (radians): a
## footprint a few degrees off the grid is the plainest way to see a building was not laid out by a ruler.
var _turn0 := 0.0
var _turn1 := 0.0
var _centre := Vector2.ZERO
## The roof over the walls: how much further it is turned at the ridge, how far the ridge bows sideways (across `_ridge_n`),
## how lopsided its sag is, and how much its slopes rise and fall.
var _roof_turn := 0.0
var _ridge_n := Vector2.ZERO
var _ridge_bow := 0.0
var _sag_skew := 0.0
## How far the walls' top plate dips with the ridge (the long walls sag in the middle, the gable walls stay level).
var _eave_sag := 0.0
var _roof_wave := 0.0
## The parts of the building's footprint (world x, z), for which way is out.
var _parts: Array[Rect2] = []


## Smooth noise of one scale (FastNoiseLite's fractal default adds four finer octaves, too much detail for a bend that
## is folded module by module).
static func _plain_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.frequency = 1.0
	return n


# --- Making a bend ------------------------------------------------------------------------------------------------

## How much a board's buildings of `style` bend, 0 to 1: the catalog's building_kit "bend" (the place's own, else the
## style's); 0 in the Classic look.
static func amount_for(board: ArenaBoard, style: String) -> float:
	if board == null or not Look.modern():
		return 0.0
	var cfg := BuildingKit.settings().get("bend", {}) as Dictionary
	var places := cfg.get("places", {}) as Dictionary
	if places.has(board.place):
		return float(places[board.place])
	return float((cfg.get("styles", {}) as Dictionary).get(style, 0.0))


## How far a style's walls may reach sideways, in squares: the catalog's building_kit.bend.reach, else MAX_OUT.
static func reach_for(style: String) -> float:
	var cfg := BuildingKit.settings().get("bend", {}) as Dictionary
	return float((cfg.get("reach", {}) as Dictionary).get(style, MAX_OUT))


## Sets what the reach means for this bend: the field held a little under it (more under, for a wide reach, since a module bent whole overshoots by its lean over its height), the roof allowed a quarter square beyond that at its ridge.
func _set_reach(reach_: float) -> void:
	reach = reach_
	_field_max = reach_ - (0.05 if reach_ <= MAX_OUT else 0.14)
	_roof_max = _field_max + (ROOF_MAX - FIELD_MAX)


## A number for a place that stays the same every time it is built.
static func place_seed(board: ArenaBoard) -> int:
	return absi(board.place.hash()) % 1000003


## The bend of a house, shared by every part of an L-shaped building: `parts` are its rectangles, `main` the one the
## ridge runs along, `height` its walls', `rise` the main roof's. Its points are the board's x and z and the height
## above its foot. Null where the style stays straight.
static func for_house(board: ArenaBoard, style: String, parts: Array[Rect2], main: Rect2, height: float, rise: float) -> BuildingBend:
	var a := amount_for(board, style)
	if a <= 0.0:
		return null
	var b := BuildingBend.new()
	b.kind = HOUSE
	b.amount = a
	b._set_reach(reach_for(style))
	var s := place_seed(board) * 7919 + int(main.position.x) * 73856093 + int(main.position.y) * 19349663 + int(main.size.x) * 83492791
	b._noise.seed = absi(s) % 2147483647
	b._noise.frequency = 1.0
	b._h = maxf(height, 0.5)
	b._rise = maxf(rise, 0.3)
	b._parts = parts
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(s)
	# Every house its own amount: some barely off true, some properly crooked.
	var k := a * lerpf(0.85, 1.4, rng.randf()) * pow(b.reach / MAX_OUT, 0.5)   # (a wider reach, a bigger bend to fill it)
	# A lean of several degrees toward some side.
	var ang := rng.randf() * TAU
	b._lean = Vector2(cos(ang), sin(ang)) * lerpf(0.6, 1.0, rng.randf()) * 0.09 * b._h * k
	b._bow = 0.13 * k
	b._over = _overhang(style) * k
	var whole := parts[0]
	for r: Rect2 in parts:
		whole = whole.merge(r)
	b._centre = whole.get_center()
	var reach := maxf(1.5, whole.size.length() / 2.0)
	b._turn0 = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.16, 0.26, rng.randf()) * k / reach
	b._turn1 = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.04, 0.09, rng.randf()) * k / reach
	# The roof goes further than the walls, and stiffer styles (stone, a church) less: its terms grow with the amount to the
	# power of one and a half.
	var kr := pow(a, 1.5) * lerpf(0.85, 1.4, rng.randf())
	b._roof_turn = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.25, 0.45, rng.randf()) * kr / reach
	# The ridge sags toward its middle (more on a long roof, and not the same each side of it), bows sideways and its
	# slopes rise and fall.
	var along_x := main.size.x >= main.size.y
	var mid := main.get_center()
	var length := main.size.x if along_x else main.size.y
	b._ridge_a = Vector2(main.position.x, mid.y) if along_x else Vector2(mid.x, main.position.y)
	b._ridge_b = Vector2(main.end.x, mid.y) if along_x else Vector2(mid.x, main.end.y)
	b._ridge_n = Vector2(0.0, 1.0) if along_x else Vector2(1.0, 0.0)
	var long_roof := clampf(length / 4.0, 0.55, 1.1)
	b._sag = lerpf(0.35, 0.55, rng.randf()) * minf(kr, 1.1) * long_roof
	b._eave_sag = b._sag * 0.4
	b._sag_skew = lerpf(-0.45, 0.45, rng.randf())
	b._ridge_bow = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.15, 0.32, rng.randf()) * kr * long_roof
	b._roof_wave = 0.12 * kr
	b._wave = 0.06 * a
	return b


## The bend of a yard wall or a town wall of height `height`: one field for the whole place (the world's x and z), so
## the squares of a wall carry on from each other.
static func for_wall(board: ArenaBoard, style: String, height: float) -> BuildingBend:
	return _of_place(board, style, height, WALL)


## The bend of a palisade of logs `height` high: every log leans its own way and the tops are uneven.
static func for_logs(board: ArenaBoard, style: String, height: float) -> BuildingBend:
	return _of_place(board, style, height, LOGS)


static func _of_place(board: ArenaBoard, style: String, height: float, kind_: int) -> BuildingBend:
	var a := amount_for(board, style)
	if a <= 0.0:
		return null
	var key := "bend_%d_%d" % [kind_, roundi(height * 100.0)]   # (a meta name can't hold a '.')
	if board.has_meta(key):
		return board.get_meta(key) as BuildingBend
	var b := BuildingBend.new()
	b.kind = kind_
	b.amount = a
	b._noise.seed = place_seed(board) * 31 + kind_
	b._noise.frequency = 1.0
	b._h = maxf(height, 0.5)
	b._rise = 0.0
	b._foot = 0.8
	if kind_ == LOGS:
		# Logs: each its own lean (a log is about a third of a square across), uneven tops, a slow drift along the line.
		b._lean_var = 0.05 * b._h * a
		b._lean_freq = 2.1
		b._lean_shares_wave = true
		b._bow = 0.0
		b._freq = 0.35
		b._freq_y = 0.3
		b._wave = 0.09 * a
		b._wave_freq = 1.7
	else:
		# A wall: a lean of a few degrees that changes along its length, a slow bow, an uneven coping.
		b._lean_var = 0.06 * b._h * a
		b._lean_freq = 0.14
		b._bow = 0.11 * a
		b._freq = 0.12
		b._freq_y = 0.16
		b._wave = 0.035 * a
		b._wave_freq = 0.3
	board.set_meta(key, b)
	return b


## The bend of a building-sized piece (a cottage, a mill) standing at the origin of its model: `box` is the model's
## extent, `seed_` where it stands. Null where the amount is 0.
static func for_prop(amount_: float, box: AABB, seed_: int) -> BuildingBend:
	if amount_ <= 0.0:
		return null
	var b := BuildingBend.new()
	b.kind = PROP
	b.amount = amount_
	b._noise.seed = absi(seed_) % 2147483647
	b._noise.frequency = 1.0
	b._h = maxf(box.size.y * 0.6, 0.5)
	b._rise = maxf(box.size.y * 0.4, 0.3)
	var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	b._parts = [rect] as Array[Rect2]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_)
	var k := amount_ * lerpf(0.9, 1.3, rng.randf())
	var ang := rng.randf() * TAU
	b._lean = Vector2(cos(ang), sin(ang)) * lerpf(0.6, 1.0, rng.randf()) * 0.08 * b._h * k
	b._bow = 0.1 * k
	b._centre = rect.get_center()
	var reach := maxf(1.5, rect.size.length() / 2.0)
	b._turn0 = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.16, 0.26, rng.randf()) * k / reach
	b._turn1 = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.04, 0.09, rng.randf()) * k / reach
	b._roof_turn = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.25, 0.45, rng.randf()) * k / reach
	b._freq = 0.22
	b._freq_y = 0.25
	b._over = 0.0
	var along_x := rect.size.x >= rect.size.y
	var mid := rect.get_center()
	var length := rect.size.x if along_x else rect.size.y
	b._ridge_a = Vector2(rect.position.x, mid.y) if along_x else Vector2(mid.x, rect.position.y)
	b._ridge_b = Vector2(rect.end.x, mid.y) if along_x else Vector2(mid.x, rect.end.y)
	b._ridge_n = Vector2(0.0, 1.0) if along_x else Vector2(1.0, 0.0)
	var long_roof := clampf(length / 4.0, 0.55, 1.25)
	b._sag = 0.4 * k * long_roof
	b._eave_sag = b._sag * 0.4
	b._sag_skew = lerpf(-0.45, 0.45, rng.randf())
	b._ridge_bow = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.15, 0.32, rng.randf()) * k * long_roof
	b._roof_wave = 0.12 * k
	b._wave = 0.05 * k
	return b


## How far a style's upper storey juts out over its lower one at full amount (catalog building_kit "bend" "overhang").
static func _overhang(style: String) -> float:
	var cfg := BuildingKit.settings().get("bend", {}) as Dictionary
	return float((cfg.get("overhang", {}) as Dictionary).get(style, 0.0))


## What makes this bend this bend, for the key of a mesh kept from an earlier visit.
func signature() -> String:
	return "%d|%.3f|%d|%.3f" % [kind, amount, _noise.seed, _lean.x + _turn0 * 100.0]


# --- The displacement ----------------------------------------------------------------------------------------------

## Where point `p` (world x and z, y up from the building's foot) is once bent. Continuous, so two meshes that meet
## before still meet, and horizontal moves never pass `_field_max` (a little under the reach).
func apply(p: Vector3) -> Vector3:
	var u := p.y / _h
	var uw := clampf(u, 0.0, 1.0)
	var w := _foot + (1.0 - _foot) * uw   # the footing drifts less than the eaves do
	var nx := _noise.get_noise_3d(p.x * _freq, p.y * _freq_y, p.z * _freq)
	var nz := _noise.get_noise_3d(p.x * _freq + 17.3, p.y * _freq_y + 9.1, p.z * _freq + 41.7)
	var lean := _lean
	if _lean_var > 0.0:
		if _lean_shares_wave:
			lean += Vector2(0.7 * _noise.get_noise_2d(p.x * _wave_freq + 5.0, p.z * _wave_freq - 7.0),
				_noise.get_noise_2d(p.x * _lean_freq, p.z * _lean_freq + 93.0)) * (_lean_var * NORM)
		else:
			lean += Vector2(_noise.get_noise_2d(p.x * _lean_freq + 71.0, p.z * _lean_freq),
				_noise.get_noise_2d(p.x * _lean_freq, p.z * _lean_freq + 93.0)) * (_lean_var * NORM)
	var dx := lean.x * u + _bow * w * nx * NORM
	var dz := lean.y * u + _bow * w * nz * NORM
	if _turn0 != 0.0 or _turn1 != 0.0:
		var ang := _turn0 + _turn1 * uw
		var cx := p.x - _centre.x
		var cz := p.z - _centre.y
		dx += -ang * cz - 0.5 * ang * ang * cx
		dz += ang * cx - 0.5 * ang * ang * cz
	if _over > 0.0 and uw > 0.0:
		var o := _outward(p.x, p.z)
		var j := _over * uw
		dx += o.x * j
		dz += o.y * j
	var cap := _field_max
	var dy := 0.0
	var wave_k := 0.0
	if u > 0.55:
		wave_k = _wave * NORM * smoothstep(0.55, 1.0, u)
	if p.y > _h and _rise > 0.0:
		# The roof: further turned toward the ridge, the ridge bowed sideways, the slopes rising and falling.
		var rw := minf((p.y - _h) / _rise, 1.0)
		if _roof_turn != 0.0:
			var ang2 := _roof_turn * rw
			dx += -ang2 * (p.z - _centre.y)
			dz += ang2 * (p.x - _centre.x)
		var prof := _ridge_profile(p.x, p.z)
		if _ridge_bow != 0.0:
			dx += _ridge_n.x * _ridge_bow * rw * prof
			dz += _ridge_n.y * _ridge_bow * rw * prof
		cap += (_roof_max - _field_max) * minf((p.y - _h) / (0.35 * _rise), 1.0)
		wave_k += _roof_wave * NORM * minf((p.y - _h) / 0.3, 1.0)
		if _sag > 0.0:
			dy -= _sag * rw * prof * (1.0 + _sag_skew * (2.0 * _ridge_t(p.x, p.z) - 1.0))
	var l2 := dx * dx + dz * dz
	if l2 > cap * cap:
		var k := cap / sqrt(l2)
		dx *= k
		dz *= k
	if wave_k > 0.0:
		# The top plate and the eaves wave up and down, the roof more (the logs of a palisade are uneven in height).
		dy += wave_k * _noise.get_noise_2d(p.x * _wave_freq + 5.0, p.z * _wave_freq - 7.0)
	if _eave_sag > 0.0 and u > 0.55:
		dy -= _eave_sag * smoothstep(0.55, 1.0, u) * _ridge_profile(p.x, p.z) * (1.0 + _sag_skew * (2.0 * _ridge_t(p.x, p.z) - 1.0))
	return Vector3(p.x + dx, p.y + dy, p.z + dz)


## How far along the main ridge (x, z) stands: 0 at one end, 1 at the other.
func _ridge_t(x: float, z: float) -> float:
	var ab := _ridge_b - _ridge_a
	var len2 := ab.length_squared()
	if len2 <= 0.0001:
		return 0.5
	return clampf((Vector2(x, z) - _ridge_a).dot(ab) / len2, 0.0, 1.0)


## 0 at the ends of the main ridge, 1 in the middle (a parabola), 0 beyond them.
func _ridge_profile(x: float, z: float) -> float:
	var t := _ridge_t(x, z)
	return 4.0 * t * (1.0 - t)


## Which way is out of the building at (x, z): the footprint part the point is most inside, toward the nearest side,
## growing from nothing at its middle to a full step at its walls (so the roof, over the middle, hardly moves out).
func _outward(x: float, z: float) -> Vector2:
	var best := INF
	var out := Vector2.ZERO
	for r: Rect2 in _parts:
		var c := r.get_center()
		var qx := (x - c.x) / maxf(r.size.x * 0.5, 0.01)
		var qz := (z - c.y) / maxf(r.size.y * 0.5, 0.01)
		var m := maxf(absf(qx), absf(qz))
		if m < best:
			best = m
			out = Vector2(signf(qx) * absf(qx) * qx * qx, signf(qz) * absf(qz) * qz * qz)
	return out


## `verts` (a merged mesh's points, in a node standing at `at` in x and z) bent. Returns a new array. This is `apply`
## over a whole array, written out so the loop stays cheap (a village's roofs are 40,000 points): change them together
## (test_building_bend checks they agree).
func bent(verts: PackedVector3Array, at: Vector2 = Vector2.ZERO) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(verts.size())
	var noise := _noise
	var inv_h := 1.0 / _h
	var foot := _foot
	var bow := _bow * NORM
	var fxz := _freq
	var fy := _freq_y
	var lean := _lean
	var lean_var := _lean_var * NORM
	var lean_freq := _lean_freq
	var share := _lean_shares_wave
	var over := _over
	var wave := _wave * NORM
	var wave_freq := _wave_freq
	var sag := _sag
	var skew := _sag_skew
	var roof_turn := _roof_turn
	var ridge_bow := _ridge_bow
	var ridge_n := _ridge_n
	var eave_sag := _eave_sag
	var roof_wave := _roof_wave * NORM
	var h := _h
	var rise := _rise
	var inv_rise := 1.0 / maxf(_rise, 0.01)
	var field_max := _field_max
	var roof_extra := _roof_max - _field_max
	var max2 := field_max * field_max
	var turn0 := _turn0
	var turn1 := _turn1
	var centre := _centre
	var turns := turn0 != 0.0 or turn1 != 0.0
	var ra := _ridge_a
	var ab := _ridge_b - _ridge_a
	var inv_len2 := 1.0 / maxf(ab.length_squared(), 0.0001)
	var has_ridge := ab.length_squared() > 0.0001
	for i in verts.size():
		var v := verts[i]
		var x := v.x + at.x
		var y := v.y
		var z := v.z + at.y
		var u := y * inv_h
		var uw := u
		if uw < 0.0:
			uw = 0.0
		elif uw > 1.0:
			uw = 1.0
		var w := foot + (1.0 - foot) * uw
		var dx := lean.x * u
		var dz := lean.y * u
		if bow > 0.0:
			dx += bow * w * noise.get_noise_3d(x * fxz, y * fy, z * fxz)
			dz += bow * w * noise.get_noise_3d(x * fxz + 17.3, y * fy + 9.1, z * fxz + 41.7)
		if turns:
			var ang := turn0 + turn1 * uw
			var cx := x - centre.x
			var cz := z - centre.y
			dx += -ang * cz - 0.5 * ang * ang * cx
			dz += ang * cx - 0.5 * ang * ang * cz
		if lean_var > 0.0:
			if share:
				dx += lean_var * u * 0.7 * noise.get_noise_2d(x * wave_freq + 5.0, z * wave_freq - 7.0)
			else:
				dx += lean_var * u * noise.get_noise_2d(x * lean_freq + 71.0, z * lean_freq)
			dz += lean_var * u * noise.get_noise_2d(x * lean_freq, z * lean_freq + 93.0)
		if over > 0.0 and uw > 0.0:
			var o := _outward(x, z)
			var j := over * uw
			dx += o.x * j
			dz += o.y * j
		var cap2 := max2
		var dy := 0.0
		# The one wave: the top plate and eaves (above u 0.55) and the roof over them (more, from the walls' top up).
		var wave_k := 0.0
		if u > 0.55:
			var st := (u - 0.55) * 2.2222222
			if st > 1.0:
				st = 1.0
			wave_k = wave * st * st * (3.0 - 2.0 * st)
		var t := 0.5
		var prof := 1.0
		if has_ridge and (eave_sag > 0.0 and u > 0.55 or y > h):
			t = (Vector2(x, z) - ra).dot(ab) * inv_len2
			if t < 0.0:
				t = 0.0
			elif t > 1.0:
				t = 1.0
			prof = 4.0 * t * (1.0 - t)
		if y > h and rise > 0.0:
			var rw := (y - h) * inv_rise
			if rw > 1.0:
				rw = 1.0
			if roof_turn != 0.0:
				var ang2 := roof_turn * rw
				dx += -ang2 * (z - centre.y)
				dz += ang2 * (x - centre.x)
			if ridge_bow != 0.0:
				dx += ridge_n.x * ridge_bow * rw * prof
				dz += ridge_n.y * ridge_bow * rw * prof
			var rc := (y - h) / (0.35 * rise)
			if rc > 1.0:
				rc = 1.0
			var cap := field_max + roof_extra * rc
			cap2 = cap * cap
			var rl := (y - h) * 3.3333333
			if rl > 1.0:
				rl = 1.0
			wave_k += roof_wave * rl
			if sag > 0.0:
				dy -= sag * rw * prof * (1.0 + skew * (2.0 * t - 1.0))
		var l2 := dx * dx + dz * dz
		if l2 > cap2:
			var k := sqrt(cap2 / l2)
			dx *= k
			dz *= k
		if wave_k > 0.0:
			dy += wave_k * noise.get_noise_2d(x * wave_freq + 5.0, z * wave_freq - 7.0)
		if eave_sag > 0.0 and u > 0.55:
			var se := (u - 0.55) * 2.2222222
			if se > 1.0:
				se = 1.0
			dy -= eave_sag * se * se * (3.0 - 2.0 * se) * prof * (1.0 + skew * (2.0 * t - 1.0))
		out[i] = Vector3(v.x + dx, y + dy, v.z + dz)
	return out


## A part's placement `xf` (in a node standing at `at` in x and z) with the bend folded in to first order about the
## part's middle `centre` (in the part's own space): the part goes to where the bend puts its middle and is turned and
## sheared the way the bend turns and shears the space round it. A small wall module bent whole costs a few points of
## the field, not a point of the field for every vertex (a village's walls are 200,000 of them); the modules overlap a
## little and the field is smooth over a square, so neighbours part by a hair at most.
func fold(xf: Transform3D, centre: Vector3, at: Vector2) -> Transform3D:
	var c := xf * centre
	var cw := Vector3(c.x + at.x, c.y, c.z + at.y)
	var f0 := apply(cw)
	var e := 0.25
	var jx := (apply(cw + Vector3(e, 0.0, 0.0)) - f0) / e
	var jy := (apply(cw + Vector3(0.0, e, 0.0)) - f0) / e
	var jz := (apply(cw + Vector3(0.0, 0.0, e)) - f0) / e
	var j := Basis(jx, jy, jz)
	var moved := Vector3(f0.x - at.x, f0.y, f0.z - at.y)
	return Transform3D(j, moved - j * c) * xf


# --- Things that go on a bent building ----------------------------------------------------------------------------

## Where a piece standing at `p` on the building, its front (+z) turned `yaw` about y, goes once the building is bent:
## at the bent point, turned and tilted to follow the wall (a lantern on a leaning wall leans with it). `lift` stands it
## off the wall a little (a bent wall between a mesh's points is a line, not the field's curve).
func frame(p: Vector3, yaw: float, lift: float = 0.0) -> Transform3D:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var front := Vector3(sin(yaw), 0.0, cos(yaw))
	var e := 0.15
	var x := (apply(p + right * e) - apply(p - right * e)).normalized()
	var y := (apply(p + Vector3.UP * e) - apply(p - Vector3.UP * e)).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z).orthonormalized(), apply(p) + z * lift)


## The point `p`'s way up once bent: a chimney box set at the bent point tilts with the roof under it.
func up_at(p: Vector3) -> Vector3:
	var e := 0.2
	return (apply(p + Vector3.UP * e) - apply(p - Vector3.UP * e)).normalized()
