class_name StandingStone
extends RefCounted
## Shrine pillars as weathered standing stones (owner 2026-10-19: "Things should look natural"; the vault's Natural Maps
## Plan, N7). A yard's inner '#' that is no part of a building was a square box under a flat square cap, the same on
## every square. Now each is its own stone: a slab thicker one way than the other, tapering as it climbs, leaning a few
## degrees, its sides wobbling where the weather has taken them, and a top that is rounded, cut slantwise, split into
## two horns or broken ragged. A free-standing block of 2 x 2 is one bigger tor. The surface is a ring grid, shaded
## smooth, mapped by the world's own textures, so it needs no UVs; the pieces stand inside their square (a token in its
## neighbours' middles and its ring stay clear) and are cosmetic only: the square still blocks as '#' does.
## Modern only (Classic keeps its boxes).

## Rings up the stone, and sides round it.
const RINGS := 9
const SIDES := 12
## How far into the ground the foot is set (world units), so it never shows a gap on a slope.
const SUNK := 0.12
## The most a stone may reach out from the middle of its square (a quarter of a square less than the square's half
## width is kept clear for the tor; one square's stone stays inside its own).
const REACH := 0.46

## Off in tests and timing runs that compare the old pillars with these (Modern only either way).
static var enabled := true

## The look a stone takes, by number (its top).
const ROUND := 0
const CHISEL := 1
const SPLIT := 2
const RAGGED := 3


## Whether pillars are standing stones: the Modern look.
static func wanted() -> bool:
	return enabled and Look.modern()


## The stone for square `c`'s pillar, or null when `c` is one of the other squares of a tor that stands on its first.
## `max_h` is the tallest a pillar of the place stands (ArenaBoard.WALL_H); `mat` its surface.
static func make(board: ArenaBoard, c: Vector2i, mat: Material, max_h: float) -> MeshInstance3D:
	var block := _block(board, c)
	if block != Rect2i() and block.position != c:
		return null   # a tor of four squares is built once, on the first
	var tor := block != Rect2i()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d" % [board.place, c.x, c.y])
	var spec := {}
	spec["tor"] = tor
	spec["height"] = max_h * (rng.randf_range(0.68, 0.84) if tor else rng.randf_range(0.74, 0.96))
	var reach := REACH + (1.0 if tor else 0.0)
	spec["ax"] = rng.randf_range(0.32, 0.42) if not tor else rng.randf_range(0.7, 0.86)
	spec["az"] = rng.randf_range(0.26, 0.34) if not tor else rng.randf_range(0.6, 0.74)
	spec["taper"] = rng.randf_range(0.5, 0.76)
	spec["top"] = rng.randi() % 4
	spec["yaw"] = rng.randf_range(0.0, PI)
	spec["lean"] = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.03, 0.16 if not tor else 0.08) * float(spec["height"])
	spec["top_yaw"] = rng.randf_range(0.0, TAU)
	spec["wobble"] = rng.randf_range(0.07, 0.12)
	spec["seed"] = rng.randi()
	# Keep the whole stone inside the square (inside the tor's four).
	var top_r := maxf(float(spec["ax"]), float(spec["az"])) * float(spec["taper"]) * 1.08
	var lean := spec["lean"] as Vector2
	var room := maxf(reach - top_r, 0.0)
	if lean.length() > room:
		spec["lean"] = lean.normalized() * room
	var mi := MeshInstance3D.new()
	mi.name = "Pillar"
	mi.mesh = _mesh(spec)
	mi.material_override = mat
	mi.position = Vector3(block.position.x + 1.0, 0.0, block.position.y + 1.0) if tor else Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	mi.set_meta("standing_stone", true)
	return mi


## The 2 x 2 block of free-standing pillar squares that holds `c` (its Rect2i), the first such block in reading order
## when blocks overlap; an empty Rect2i() for a lone pillar. Pillar squares are inner wall squares no building or rock
## claims.
static func _block(board: ArenaBoard, c: Vector2i) -> Rect2i:
	for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var a := c + o
		var ok := true
		for dz in 2:
			for dx in 2:
				if not _free(board, a + Vector2i(dx, dz)):
					ok = false
		if ok and _first_block(board, a):
			return Rect2i(a, Vector2i(2, 2))
	return Rect2i()


## Whether the 2 x 2 at `a` is the one that wins its squares: no free block started earlier in reading order shares a
## square with it.
static func _first_block(board: ArenaBoard, a: Vector2i) -> bool:
	for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0)]:
		var b := a + o
		var ok := true
		for dz in 2:
			for dx in 2:
				if not _free(board, b + Vector2i(dx, dz)):
					ok = false
		if ok and _first_block(board, b):
			return false
	return true


static func _free(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL) and not board.house_cells.has(c) \
		and not board._on_border(c) and not _rock(board, c) and not (board.theme == "camp" and board._wagon_cells.has(c))


## Whether `c` is drawn as rock (a place with `rock_walls`): ArenaBoard._rocky where it has one, else what that was.
static func _rock(board: ArenaBoard, c: Vector2i) -> bool:
	if board.has_method("_rocky"):
		return bool(board.call("_rocky", c))
	return board._rock_tex != null and not board._tree_wall(c)


## The stone as a mesh centred on its middle, its foot at -SUNK.
static func _mesh(spec: Dictionary) -> ArrayMesh:
	var height := float(spec["height"])
	var ax := float(spec["ax"])
	var az := float(spec["az"])
	var taper := float(spec["taper"])
	var top := int(spec["top"])
	var yaw := float(spec["yaw"])
	var top_yaw := float(spec["top_yaw"])
	var lean := spec["lean"] as Vector2
	var wobble := float(spec["wobble"])
	var noise := FastNoiseLite.new()
	noise.seed = int(spec["seed"])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	var sides := SIDES + (4 if bool(spec["tor"]) else 0)
	var pts: Array[Vector3] = []
	# The height each column of the top stands at, by its angle: the top's cut.
	for k in RINGS + 1:
		var t := float(k) / RINGS
		var shrink := lerpf(1.0, taper, pow(t, 1.15)) * (1.0 + 0.06 * sin(t * 3.7 + top_yaw))
		for a in sides:
			var th := TAU * float(a) / sides
			var w := 1.0 + wobble * noise.get_noise_3d(cos(th) * 1.4, sin(th) * 1.4, t * 2.4)
			var top_h := height * _cut(top, th - top_yaw, noise)
			var local := Vector2(cos(th) * ax, sin(th) * az) * shrink * w
			var drift := lean * pow(t, 1.4)
			local += drift
			var p := Vector3(local.x, lerpf(-SUNK, top_h, t), local.y)
			pts.append(p.rotated(Vector3.UP, yaw))
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	# The sides: ring grid, wrapping round.
	for p: Vector3 in pts:
		pos.append(p)
		nrm.append(Vector3.ZERO)
	for k in RINGS:
		for a in sides:
			var b := (a + 1) % sides
			var p00 := k * sides + a
			var p10 := k * sides + b
			var p01 := (k + 1) * sides + a
			var p11 := (k + 1) * sides + b
			_face(pos, nrm, idx, p00, p10, p01)
			_face(pos, nrm, idx, p10, p11, p01)
	# The cap: its own vertices, so the top's edge shades crisp where the cut is, smooth where it is rounded.
	var ring0 := RINGS * sides
	var cap_first := pos.size()
	for a in sides:
		pos.append(pos[ring0 + a])
		nrm.append(Vector3.ZERO)
	var apex_lift := 0.0
	match top:
		ROUND:
			apex_lift = 0.2 * height
		CHISEL:
			apex_lift = 0.03 * height
		SPLIT:
			apex_lift = -0.1 * height
		_:
			apex_lift = 0.05 * height
	var mid := Vector3.ZERO
	for a in sides:
		mid += pos[ring0 + a]
	mid /= float(sides)
	var apex := pos.size()
	pos.append(mid + Vector3(0.0, apex_lift, 0.0))
	nrm.append(Vector3.ZERO)
	if top == ROUND:
		# A dome: one ring pulled in and lifted between the rim and the apex.
		var dome_first := pos.size()
		for a in sides:
			var rim := pos[ring0 + a]
			pos.append(Vector3(lerpf(rim.x, mid.x, 0.5), rim.y + apex_lift * 0.7, lerpf(rim.z, mid.z, 0.5)))
			nrm.append(Vector3.ZERO)
		for a in sides:
			var b := (a + 1) % sides
			_face(pos, nrm, idx, cap_first + a, cap_first + b, dome_first + a)
			_face(pos, nrm, idx, cap_first + b, dome_first + b, dome_first + a)
			_face(pos, nrm, idx, apex, dome_first + a, dome_first + b)
	else:
		for a in sides:
			var b := (a + 1) % sides
			_face(pos, nrm, idx, apex, cap_first + a, cap_first + b)
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length() > 0.0001 else Vector3.UP
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The top's height (as a share of the stone's) at angle `th` round it: level, slanting one way, split into two horns
## with a notch between them, or broken ragged.
static func _cut(top: int, th: float, noise: FastNoiseLite) -> float:
	match top:
		CHISEL:
			return 1.0 + 0.17 * cos(th)
		SPLIT:
			var s := cos(2.0 * th)
			return 1.0 + 0.2 * signf(s) * pow(absf(s), 0.6)
		RAGGED:
			return 1.0 + 0.12 * noise.get_noise_2d(cos(th) * 3.0 + 9.0, sin(th) * 3.0 + 4.0) * 2.0
	return 1.0


## One triangle (clockwise seen from outside: Godot's front faces), its face normal added to its corners'.
static func _face(pos: PackedVector3Array, nrm: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int) -> void:
	idx.append(a)
	idx.append(b)
	idx.append(c)
	var n := (pos[c] - pos[a]).cross(pos[b] - pos[a])
	nrm[a] += n
	nrm[b] += n
	nrm[c] += n


## How far from the middle of its square the stone's outline reaches (tests, art QA): the widest of its vertices.
static func reach_of(mi: MeshInstance3D) -> float:
	var arrays := mi.mesh.surface_get_arrays(0)
	var best := 0.0
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		best = maxf(best, maxf(absf(v.x), absf(v.z)))
	return best
