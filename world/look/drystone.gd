class_name Drystone
extends RefCounted
## A yard's outer wall and its low walls as old dry stone (owner 2026-10-19: "Things should look natural"; the vault's
## Natural Maps Plan, N7). Each square of the churchyard's wall was a full-size box at its own random height, so the
## wall stepped up and down in cubes; each square of a low wall was one smooth plank. Here a wall is made of coping
## stones laid along its run: three to a square, each its own height a few inches off a slow swell that carries on
## across the squares, with a worn bevel, the top of each a little askew; here and there a stone has broken, and
## now and then one is missing, but a wall never drops below half its height (a ruin, place_looks `ruin`, below three
## fifths, and breaks more). The outer wall stands on a rough footing the width of its square, with its thinner body set
## back from the yard by a changing few inches; corners are a post a little taller than either arm. Low walls run from
## the middle of their square toward each low neighbour and join where they meet. Cosmetic only: the wall's squares
## block (outer) or give cover (low) exactly as before, and every piece stays inside its own square.
## Modern only (Classic keeps its boxes).

## Off in tests and timing runs that compare the old walls with these (Modern only either way).
static var enabled := true

## The height of the footing under an outer wall.
const FOOT_H := 0.2
## How far a coping stone's top is rounded off.
const BEVEL := 0.035
## How far a stone is sunk, so it never shows a gap on uneven ground.
const SUNK := 0.1


## Whether this board's walls are dry stone: the Modern look.
static func wanted() -> bool:
	return enabled and Look.modern()


## The mesh being built: flat-shaded quads, so every stone's faces catch the light on their own.
class Builder extends RefCounted:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	## How uneven the wall is laid, 0 (as even as a built wall) to 1 (place_looks `rough`: a castle's parapet is laid
	## almost straight).
	var rough := 1.0
	var top := 0.0

	## A quad (any winding), turned to face `out` and shaded flat.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
		var n := (c - a).cross(b - a)
		if n.length() < 0.000001:
			n = (d - a).cross(c - a)
		if n.dot(out) < 0.0:
			var t := b
			b = d
			d = t
			n = -n
		n = n.normalized()
		var first := pos.size()
		for v: Vector3 in [a, b, c, d]:
			pos.append(v)
			nrm.append(n)
		idx.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))

	## A rough block between x0..x1 and z0..z1 (local to the square), from `y0` up to a top whose four corners
	## (x0 z0, x1 z0, x1 z1, x0 z1) stand at `h`, its top edge rounded off.
	func stone(x0: float, x1: float, z0: float, z1: float, y0: float, h: Array[float]) -> void:
		var cx: Array[float] = [x0, x1, x1, x0]
		var cz: Array[float] = [z0, z0, z1, z1]
		var bev := minf(BEVEL, minf(x1 - x0, z1 - z0) * 0.3)
		var base: Array[Vector3] = []
		var mid: Array[Vector3] = []
		var tp: Array[Vector3] = []
		for i in 4:
			var inx := bev if cx[i] == x0 else -bev
			var inz := bev if cz[i] == z0 else -bev
			base.append(Vector3(cx[i], y0, cz[i]))
			mid.append(Vector3(cx[i] + rng.randf_range(-0.008, 0.008), h[i] - bev, cz[i] + rng.randf_range(-0.008, 0.008)))
			tp.append(Vector3(cx[i] + inx, h[i] + rng.randf_range(-0.012, 0.012), cz[i] + inz))
			top = maxf(top, h[i])
		var outward: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
		for i in 4:
			var j := (i + 1) % 4
			quad(base[i], base[j], mid[j], mid[i], outward[i])
			quad(mid[i], mid[j], tp[j], tp[i], outward[i] + Vector3.UP)
		quad(tp[0], tp[1], tp[2], tp[3], Vector3.UP)

	func mesh() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## The outer wall's piece on border wall square `c`: its footing and coping stones along the border, toward each border
## neighbour that is wall too, and a corner post where two arms meet. `height` is the wall's full height, `ruin` how far
## it has fallen (0 whole, 1 well broken: place_looks `ruin`). Null for a square that isn't on the border.
static func outer(board: ArenaBoard, c: Vector2i, mat: Material, height: float, ruin: float = 0.0) -> MeshInstance3D:
	var w := board.grid.width
	var d := board.grid.depth
	var north := c.y == 0
	var south := c.y == d - 1
	var west := c.x == 0
	var east := c.x == w - 1
	if not (north or south or west or east):
		return null
	var sh := Builder.new()
	sh.rng.seed = hash("%s|outer|%d|%d" % [board.place, c.x, c.y])
	sh.rough = clampf(float(board._look.get("rough", 1.0)), 0.0, 1.0)
	var noise := _noise(board)
	var frame := frame_of(height, ruin)
	height = frame.x
	var min_frac := frame.y
	var tops: Array[float] = []
	# An arm along x (on a north or south edge), then one along z (on a west or east edge).
	if north or south:
		tops.append(_arm(sh, board, noise, c, true, 0.0 if north else 1.0, height, min_frac, ruin))
	if west or east:
		tops.append(_arm(sh, board, noise, c, false, 0.0 if west else 1.0, height, min_frac, ruin))
	if tops.size() == 2:
		# A corner: a post over where the two arms cross, a little taller than either.
		var t := 0.9
		var x0 := 0.0 if west else 1.0 - t
		var z0 := 0.0 if north else 1.0 - t
		var hh := maxf(tops[0], tops[1]) + 0.05
		var post: Array[float] = [hh, hh - 0.02, hh - 0.04, hh - 0.01]
		sh.stone(x0, x0 + t, z0, z0 + t, -SUNK, post)
	var mi := MeshInstance3D.new()
	mi.name = "OuterWall"
	mi.mesh = sh.mesh()
	mi.material_override = mat
	mi.position = Vector3(c.x, 0.0, c.y)
	mi.set_meta("drystone", "outer")
	return mi


## One arm of an outer wall through square `c`: along x when `along_x` (its outside edge at z = `edge`, 0 or 1), else
## along z (outside edge at x = `edge`). Returns the height of the highest stone, for the corner post.
static func _arm(sh: Builder, board: ArenaBoard, noise: FastNoiseLite, c: Vector2i, along_x: bool, edge: float, height: float,
		min_frac: float, ruin: float) -> float:
	var stones := _stones(sh.rng, noise, float(c.x) if along_x else float(c.y), height, min_frac, ruin, 2, sh.rough)
	var best := 0.0
	for s: Dictionary in stones:
		var u0 := float(s["u0"])
		var u1 := float(s["u1"])
		# The body's thickness wanders slowly along the wall, so its face is never a straight line, nor does it jump.
		var t := 0.88 + 0.07 * noise.get_noise_2d(((float(c.x) if along_x else float(c.y)) + (u0 + u1) / 2.0) * 0.9, 7.7 + edge * 5.0) \
			+ sh.rng.randf_range(-0.01, 0.01)
		var foot := sh.rng.randf_range(FOOT_H * 0.8, FOOT_H * 1.25)
		var hs := _corners(sh.rng, along_x, float(s["h0"]), float(s["h1"]))
		var fs := _corners(sh.rng, along_x, foot, foot + sh.rng.randf_range(-0.03, 0.03))
		var v0 := 0.0 if edge < 0.5 else 1.0 - t
		if along_x:
			sh.stone(u0, u1, 0.0, 1.0, -SUNK, fs)   # the footing, the width of the square
			sh.stone(u0 + 0.004, u1 - 0.004, v0, v0 + t, foot * 0.8, hs)
		else:
			sh.stone(0.0, 1.0, u0, u1, -SUNK, fs)
			sh.stone(v0, v0 + t, u0 + 0.004, u1 - 0.004, foot * 0.8, hs)
		best = maxf(best, maxf(float(s["h0"]), float(s["h1"])))
	return best


## The low wall's piece on square `c` (low squares beside it are `left`, `right`, `up`, `down`): a run of coping stones
## along the way it runs, and an arm toward each neighbour across it. Null when no low square touches it.
static func low(board: ArenaBoard, c: Vector2i, mat: Material, height: float, ruin: float = 0.0) -> MeshInstance3D:
	var grid := board.grid
	var left := grid.has_flag(c + Vector2i(-1, 0), CombatGrid.LOW)
	var right := grid.has_flag(c + Vector2i(1, 0), CombatGrid.LOW)
	var up := grid.has_flag(c + Vector2i(0, -1), CombatGrid.LOW)
	var down := grid.has_flag(c + Vector2i(0, 1), CombatGrid.LOW)
	if not (left or right or up or down):
		return null
	var sh := Builder.new()
	sh.rng.seed = hash("%s|low|%d|%d" % [board.place, c.x, c.y])
	sh.rough = clampf(float(board._look.get("rough", 1.0)), 0.0, 1.0)
	var noise := _noise(board)
	var frame := frame_of(height, ruin)
	height = frame.x
	var min_frac := frame.y
	var along_x := left or right
	var base := board.floor_y(c)
	# The way it runs, the whole square across; an arm from the middle toward each neighbour the other way.
	if along_x:
		_low_arm(sh, board, noise, c, true, 0.0, 1.0, base, height, min_frac, ruin)
		if up:
			_low_arm(sh, board, noise, c, false, 0.0, 0.5, base, height, min_frac, ruin)
		if down:
			_low_arm(sh, board, noise, c, false, 0.5, 1.0, base, height, min_frac, ruin)
	else:
		_low_arm(sh, board, noise, c, false, 0.0, 1.0, base, height, min_frac, ruin)
	var mi := MeshInstance3D.new()
	mi.name = "LowWall"
	mi.mesh = sh.mesh()
	mi.material_override = mat
	mi.position = Vector3(c.x, base, c.y)
	mi.set_meta("drystone", "low")
	return mi


## An arm of a low wall through square `c`, along x or z from `from` to `to` (0..1 along that way).
static func _low_arm(sh: Builder, board: ArenaBoard, noise: FastNoiseLite, c: Vector2i, along_x: bool, from: float, to: float,
		base: float, height: float, min_frac: float, ruin: float) -> void:
	var t := sh.rng.randf_range(0.4, 0.5)
	var mid := 0.5 + sh.rng.randf_range(-0.03, 0.03)
	var span := to - from
	var stones := _stones(sh.rng, noise, (float(c.x) if along_x else float(c.y)) + from, height, min_frac, ruin, 2, sh.rough)
	for s: Dictionary in stones:
		var u0 := from + float(s["u0"]) * span
		var u1 := from + float(s["u1"]) * span
		var hs := _corners(sh.rng, along_x, float(s["h0"]), float(s["h1"]))
		var lift: Array[float] = []
		for i in 4:
			# Corner i's place along the arm: the stone's near end (u0) or its far end (u1).
			var near := (i == 0 or i == 3) if along_x else (i == 0 or i == 1)
			lift.append(hs[i] + _ground_off(board, c, base, u0 if near else u1, mid, along_x))
		if along_x:
			sh.stone(u0 + 0.004, u1 - 0.004, mid - t / 2.0, mid + t / 2.0, -SUNK, lift)
		else:
			sh.stone(mid - t / 2.0, mid + t / 2.0, u0 + 0.004, u1 - 0.004, -SUNK, lift)


## A yard wall's piece on wall square `c` of a place in ruin (a town's lines of wall one square thick; the building
## kit's yard wall stands whole, so a ruin draws its own): an arm of old dry stone from the middle toward each
## neighbouring wall or gate, and a pier where the wall turns, ends or branches, every one broken to its own height
## (never below three fifths of the wall at the most fallen). `gates` are the squares of the place's gateways.
static func yard(board: ArenaBoard, c: Vector2i, mat: Material, height: float, ruin: float, gates: Dictionary) -> MeshInstance3D:
	var grid := board.grid
	var dirs: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if grid.in_bounds(n) and (grid.has_flag(n, CombatGrid.WALL) or gates.has(n)):
			dirs.append(d)
	var sh := Builder.new()
	sh.rng.seed = hash("%s|yard|%d|%d" % [board.place, c.x, c.y])
	sh.rough = clampf(float(board._look.get("rough", 1.0)), 0.0, 1.0)
	var noise := _noise(board)
	var frame := frame_of(height, ruin)
	height = frame.x
	var min_frac := frame.y
	var straight := dirs.size() == 2 and dirs[0] == -dirs[1]
	var base := board.floor_y(c)
	if straight:
		_yard_arm(sh, noise, c, dirs[0].x != 0, 0.0, 1.0, height, min_frac, ruin)
	else:
		for d: Vector2i in dirs:
			# From the middle to the square's edge.
			var span := Vector2(0.5, 1.0) if d.x > 0 or d.y > 0 else Vector2(0.0, 0.5)
			_yard_arm(sh, noise, c, d.x != 0, span.x, span.y, height, min_frac, ruin)
		# The pier where it turns, ends or branches: a little taller than the wall, if it hasn't fallen.
		var w := sh.rng.randf_range(0.56, 0.68)
		var h := _stones(sh.rng, noise, float(c.x) + float(c.y), height * 1.12, min_frac, ruin, 2, sh.rough)[0] as Dictionary
		var top := _corners(sh.rng, true, float(h["h0"]), float(h["h1"]))
		sh.stone(0.5 - w / 2.0, 0.5 + w / 2.0, 0.5 - w / 2.0, 0.5 + w / 2.0, -SUNK, top)
	var mi := MeshInstance3D.new()
	mi.name = "YardWall"
	mi.mesh = sh.mesh()
	mi.material_override = mat
	mi.position = Vector3(c.x, base, c.y)
	mi.set_meta("on_floor", true)   # (on its square's floor already: ArenaBoard._lift leaves it be)
	mi.set_meta("drystone", "yard")
	return mi


## An arm of a yard wall through square `c`, along x or z from `from` to `to` (0..1 along that way), centred in it.
static func _yard_arm(sh: Builder, noise: FastNoiseLite, c: Vector2i, along_x: bool, from: float, to: float, height: float,
		min_frac: float, ruin: float) -> void:
	var t := sh.rng.randf_range(0.42, 0.52)
	var span := to - from
	for s: Dictionary in _stones(sh.rng, noise, (float(c.x) if along_x else float(c.y)) + from, height, min_frac, ruin, 2, sh.rough):
		var u0 := from + float(s["u0"]) * span
		var u1 := from + float(s["u1"]) * span
		var hs := _corners(sh.rng, along_x, float(s["h0"]), float(s["h1"]))
		if along_x:
			sh.stone(u0 + 0.004, u1 - 0.004, 0.5 - t / 2.0, 0.5 + t / 2.0, -SUNK, hs)
		else:
			sh.stone(0.5 - t / 2.0, 0.5 + t / 2.0, u0 + 0.004, u1 - 0.004, -SUNK, hs)


## How far the natural ground at (u along the wall, v across it) stands above the square's own height (0 on level
## ground), so a wall on a slope follows it.
static func _ground_off(board: ArenaBoard, c: Vector2i, base: float, u: float, v: float, along_x: bool) -> float:
	if not board.grid.has_flag(c, CombatGrid.NATURAL):
		return 0.0
	var p := Vector2(float(c.x) + u, float(c.y) + v) if along_x else Vector2(float(c.x) + v, float(c.y) + u)
	return board.ground_y(p) - base


## The stones of one arm: n of them between u = 0 and 1, each {u0, u1, h0, h1}: the height of its top at each end. They
## follow a swell that carries on across the squares (`u_world` is the arm's start along the wall, in squares), a stone
## standing a hair above or below its neighbour; now and then one has broken (lower, and slanting), or is missing. In a
## ruin the wall has also fallen in stretches: where a slow noise along it is high the wall is down to its lowest
## (`min_frac`), and stands where it is low, so a ruin is long standing runs and long fallen ones, not a scatter of chips.
static func _stones(rng: RandomNumberGenerator, noise: FastNoiseLite, u_world: float, height: float, min_frac: float,
		ruin: float, n: int, rough: float = 1.0) -> Array[Dictionary]:
	var cuts: Array[float] = [0.0]
	if n == 3:
		cuts.append(rng.randf_range(0.22, 0.42))
		cuts.append(rng.randf_range(0.58, 0.8))
	else:
		cuts.append(rng.randf_range(0.34, 0.66))
	cuts.append(1.0)
	var out: Array[Dictionary] = []
	for i in n:
		var jitter := rng.randf_range(-0.02, 0.02) * rough
		var h0 := height * (1.0 + 0.1 * rough * noise.get_noise_2d((u_world + cuts[i]) * 0.5, 3.1)) + jitter
		var h1 := height * (1.0 + 0.1 * rough * noise.get_noise_2d((u_world + cuts[i + 1]) * 0.5, 3.1)) + jitter
		if ruin > 0.0:
			h0 = lerpf(h0, height * min_frac * 1.08, _fallen(noise, u_world + cuts[i]) * ruin)
			h1 = lerpf(h1, height * min_frac * 1.08, _fallen(noise, u_world + cuts[i + 1]) * ruin)
		var roll := rng.randf()
		if roll < 0.07 * rough + 0.06 * ruin:
			# Broken: its top slants down from one end.
			h0 = height * rng.randf_range(min_frac, min_frac + 0.3)
			h1 = height * rng.randf_range(min_frac, min_frac + 0.3)
		elif roll < 0.1 * rough + 0.1 * ruin:
			h0 = height * min_frac   # missing
			h1 = height * min_frac
		out.append({"u0": cuts[i], "u1": cuts[i + 1], "h0": maxf(h0, height * min_frac), "h1": maxf(h1, height * min_frac)})
	return out


## How far a ruin's wall has fallen at `u` squares along it: 0 standing, 1 down to its lowest, in stretches.
static func _fallen(noise: FastNoiseLite, u: float) -> float:
	return smoothstep(0.3, 0.7, 0.5 + 0.5 * noise.get_noise_2d(u * 0.3, 9.3))


## The four corners' heights (x0 z0, x1 z0, x1 z1, x0 z1) of a stone whose top is `h0` at its near end along the wall
## and `h1` at its far end, a little askew.
static func _corners(rng: RandomNumberGenerator, along_x: bool, h0: float, h1: float) -> Array[float]:
	var k: Array[float] = []
	k.assign([h0, h1, h1, h0] if along_x else [h0, h0, h1, h1])
	for i in 4:
		k[i] += rng.randf_range(-0.012, 0.012)
	return k


## The height a wall's stones stand to and the share of it none falls below, for a wall `height` high whole: a ruin
## stands a little lower, and no stone is ever below half the whole wall's height (three fifths in a ruin).
static func frame_of(height: float, ruin: float) -> Vector2:
	var low := (0.5 + 0.1 * ruin) * height
	var h := height * (1.0 - 0.12 * ruin)
	return Vector2(h, low / h)


## The place's swell of height along its walls, made once a board (seeded by the place).
static func _noise(board: ArenaBoard) -> FastNoiseLite:
	if board.has_meta("drystone_noise"):
		return board.get_meta("drystone_noise") as FastNoiseLite
	var n := FastNoiseLite.new()
	n.seed = hash(board.place) if board.place != "" else 77
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	board.set_meta("drystone_noise", n)
	return n
