class_name GroundCover
extends RefCounted
## Difficult ground as thickets, not a lattice (owner 2026-10-19: "Basically we want the world to look more natural";
## the vault's Natural Maps Plan, N7). Every '~' square of an outdoor map got one little bush at its middle, so a hedge
## of brambles, a bank of drifts round a frozen pond or a ring of reeds read as a grid of identical tufts. Here each
## map's difficult squares are planted together, once: clumps of the place's own dressing (catalog `difficult`) are
## scattered by noise over the runs of difficult squares, big where a run is deep and small at its rim, thick in some
## patches and thin in others, each turned and stretched its own way, standing wherever the noise puts them, across
## the squares' edges. A run's rim may reach a little way into the open ground beside it (rule 2: ground-level things
## up to half a square; here a third, so a token in the middle of that square and its ring stay clear) and never into
## water or the void. Every difficult square still carries a clump near its middle, so it reads as difficult.
## Indoors (I4) the same: rubble heaps and webs across the floor, never into a wall. Modern only (Classic keeps its one
## bush a square); cosmetic, the rules grid never sees any of it.

## The step (squares) the scatter's jittered lattice is laid on.
const SPACING := 0.6
## How far a clump's rim may reach into walkable ground that isn't difficult, and into water or the void.
const REACH_CLEAR := 0.3
const REACH_WET := 0.04
## The smallest and the largest a clump grows (times its model's own size), and the longest half-width it may have.
const MIN_SCALE := 0.75
const MAX_SCALE := 2.0
const MAX_HALF := 0.95
## Arts that are heaps of loose things (rubble), not banks or thickets: they grow no longer than this many times their
## model, are turned any way and not stretched long, and don't pile up higher deep in a run.
const HEAPS := {"rubble": 1.45}
## The tallest a clump grows (squares): a token's height, so a thicket never hides the party behind it.
const TALLEST := 0.9
## How close two clumps may stand, as a share of their two radii (so they grow into each other a little).
const CROWD := 1.1
## How likely each open square beside a run is to get a loose clump, and how far from the run's edge it may stand.
const SCATTER := 0.4
const RIM := 0.2
## A difficult square whose middle has no clump within this reach gets one.
const COVER := 0.4

## Off in tests and timing runs that compare the old one bush a square with these (Modern only either way).
static var enabled := true

## One clump: where, how big, which dressing, which way it faces and how it is stretched.
class Clump extends RefCounted:
	var at := Vector2.ZERO
	var scale := 1.0
	var radius := 0.4
	## Its smallest half-width (squares): the way across it that may not reach into water.
	var half_min := 0.3
	var yaw := 0.0
	var stretch := Vector3.ONE
	var art := ""
	var pick := 0
	## Which way the run's edge lies from the clump (a unit vector in x, z; zero in the deep of a run).
	var toward_edge := Vector2.ZERO

var board: ArenaBoard
## Difficult square -> the clumps whose middles are in it (Array[Clump]).
var _by_square: Dictionary = {}
var count := 0
## How many of them were put in to cover a square the scatter left bare.
var forced := 0
var _arts: Array[String] = []
var _r0: Dictionary = {}    ## art -> half the width of its model (squares)
var _low: Dictionary = {}   ## art -> whether it is a low thing (a drift, a patch of ice) rather than a bush
var _tall: Dictionary = {}  ## art -> how tall its model stands (squares)
## What each square is, for the scatter (worked out once): OPEN walkable ground, WET water or the void, DIFF difficult
## ground; anything else (walls) 0. And the clumps standing in each square, for the crowding check.
const OPEN := 1
const WET := 2
const DIFF := 3
const SOLID := 4   ## a wall, where walls are built (indoors, dungeons, rock), so a clump never reaches into one
var _w := 0
var _d := 0
var _cls := PackedByteArray()
var _near: Array = []
var _walled := false   ## whether the board's wall squares are built (not trees): clumps keep out of them


## Whether this board's '~' squares are planted as thickets: the Modern look, anywhere ('~' indoors is rubble and webs
## across the floor, Natural Maps Plan I4).
static func wanted(_board: ArenaBoard, _key: String) -> bool:
	return enabled and Look.modern()


## Plants the board's difficult squares with `choices` (catalog `difficult` art ids); null when none of them has art.
static func plan(board_: ArenaBoard, choices: Array) -> GroundCover:
	var g := GroundCover.new()
	g.board = board_
	for a: Variant in choices:
		var art := str(a)
		if SetDressing.has_art(art) and not art in g._arts:
			g._arts.append(art)
			g._r0[art] = _base_radius(art)
			g._low[art] = _is_low(art) and not HEAPS.has(art)
			g._tall[art] = _height_of(art)
	if g._arts.is_empty():
		return null
	g._plant()
	return g


## Puts square `c`'s clumps on the board (ArenaBoard._brambles asks for each difficult square in turn).
func stand(c: Vector2i) -> void:
	for k: Clump in _by_square.get(c, []):
		_place(c, k)


## The clumps whose middles are in square `c` (tests, art QA).
func clumps_in(c: Vector2i) -> Array:
	return _by_square.get(c, []) as Array


func _plant() -> void:
	var grid := board.grid
	_w = grid.width
	_d = grid.depth
	_cls.resize(_w * _d)
	_near.resize(_w * _d)
	_walled = not (board.theme in ArenaBoard.WILD or board.theme in ArenaBoard.TOWNS or board.theme == "shrine_yard")
	var diff: Array[Vector2i] = []
	var lo := Vector2i(_w, _d)
	var hi := Vector2i(-1, -1)
	for z in _d:
		for x in _w:
			var f := grid.flags(Vector2i(x, z))
			var k := 0
			if (f & (CombatGrid.WATER | CombatGrid.VOID)) != 0:
				k = WET
			elif (f & CombatGrid.WALL) != 0:
				k = SOLID if _walled else 0
			elif (f & CombatGrid.DIFFICULT) != 0:
				k = DIFF
				diff.append(Vector2i(x, z))
				lo = Vector2i(mini(lo.x, x), mini(lo.y, z))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, z))
			else:
				k = OPEN
			_cls[z * _w + x] = k
	if diff.is_empty():
		return
	var seed_ := hash(board.place) if board.place != "" else 77
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var patch := _noise(seed_, 0.3)
	var body := _noise(seed_ + 1, 0.5)
	var kind := _noise(seed_ + 2, 0.2)
	var step_z := SPACING * 0.87
	for j in range(int(floor(float(lo.y - 1) / step_z)), int(ceil(float(hi.y + 2) / step_z)) + 1):
		for i in range(int(floor(float(lo.x - 1) / SPACING)), int(ceil(float(hi.x + 2) / SPACING)) + 1):
			var p := Vector2((float(i) + 0.5 * float(j & 1)) * SPACING + rng.randf_range(-0.24, 0.24),
				float(j) * step_z + rng.randf_range(-0.2, 0.2))
			var cell := Vector2i(floori(p.x), floori(p.y))
			if _class_at(cell) != DIFF:
				continue
			# Thin patches and gaps between thickets; the coverage pass below still puts a clump near the middle of a
			# square that ends up bare.
			var dens := 0.5 + 0.5 * patch.get_noise_2d(p.x, p.y)
			if dens < 0.2 and rng.randf() < 0.7:
				continue
			if rng.randf() > lerpf(0.75, 1.0, dens):
				continue
			var art := _art_at(kind, p)
			var grown := lerpf(MIN_SCALE, MAX_SCALE, smoothstep(0.15, 0.85, 0.5 + 0.5 * body.get_noise_2d(p.x, p.y)))
			var k := _shape(p, art, grown * rng.randf_range(0.85, 1.15), MIN_SCALE, rng)
			if k != null:
				_add(cell, k)
	# Loose debris and tufts at the run's rim: small clumps just outside it, in the open squares beside it, so the run
	# doesn't stop at its squares' edge. Within a fifth of a square of the edge and small, so a token in the middle of
	# that square and its ring stay clear.
	for c: Vector2i in diff:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if _class_at(n) != OPEN or rng.randf() > SCATTER:
				continue
			var along := rng.randf_range(0.1, 0.9)
			var out := rng.randf_range(0.04, RIM)
			var p := Vector2(float(c.x) + (1.0 + out if d.x > 0 else -out if d.x < 0 else along), float(c.y) + (1.0 + out if d.y > 0 else -out if d.y < 0 else along))
			var k := _shape(p, _art_at(kind, p), rng.randf_range(0.5, 0.85), 0.45, rng)
			if k != null and k.radius <= RIM + 0.12:
				_add(c, k)
	# Every difficult square carries a clump near its middle.
	for c: Vector2i in diff:
		var mid := Vector2(c.x + 0.5, c.y + 0.5)
		if _covered(mid):
			continue
		var p := mid + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
		var k := _shape(p, _art_at(kind, p), rng.randf_range(0.8, 1.3), 0.5, rng)
		if k != null:
			_add(c, k, true)


func _class_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _d:
		return 0
	return _cls[c.y * _w + c.x]


## A clump of `art` at `p`, as big as `want` (times its model) allows: it may not reach farther out of the run than
## the squares round it permit (_room), measured along the way the run's edge lies, so a long thin clump lying along a
## shore stands closer to it than a round one could. Turned along the run's edge (with some scatter), stretched its own
## way (drifts long and low, thickets wider than they are tall). Null when it would come out smaller than `min_scale`.
func _shape(p: Vector2, art: String, want: float, min_scale: float, rng: RandomNumberGenerator) -> Clump:
	var r0 := float(_r0[art])
	var low := bool(_low[art])
	var heap := HEAPS.has(art)
	if heap:
		want = minf(want, float(HEAPS[art]))
	var sx := rng.randf_range(1.15, 1.9) if low else (rng.randf_range(0.9, 1.2) if heap else rng.randf_range(0.95, 1.3))
	var sz := rng.randf_range(0.62, 0.95) if low else (rng.randf_range(0.9, 1.2) if heap else rng.randf_range(0.85, 1.1))
	var open := _gap(p, OPEN)
	var wet := _gap(p, WET)
	var room := minf(open.x + REACH_CLEAR, wet.x + REACH_WET)
	# The way the nearest square a clump may not spread over (open ground, water, the void, a built wall) lies; none
	# where it is far.
	var near := open if open.x <= wet.x else wet
	if _walled:
		var solid := _gap(p, SOLID)
		room = minf(room, solid.x + REACH_WET)
		if solid.x < near.x:
			near = solid
	var edge := Vector2(near.y, near.z).normalized() if near.x < 1.4 and near.x > 0.0001 else Vector2.ZERO
	# Deep in a run the thicket grows big and tall, a mass with a ragged rim; at the rim it thins to small low tufts.
	var depth := minf(near.x, 3.0)
	var deep := 0.0 if heap else smoothstep(0.9, 2.4, depth)
	want *= lerpf(1.0, 1.6, deep)
	var max_half := MAX_HALF * lerpf(1.0, 1.7, deep)
	var yaw := rng.randf_range(0.0, TAU)
	var along := 0.0
	if edge != Vector2.ZERO and not heap:
		# Lying along the edge of the run, the long way, give or take (local x along the tangent, whose heading is
		# atan2(edge.x, edge.y) as a turn about y).
		yaw = atan2(edge.x, edge.y) + rng.randf_range(-0.55, 0.55)
		along = edge.dot(Vector2(cos(yaw), -sin(yaw)))
	# How far the clump reaches along the edge's direction, per unit of scale (r0 times the stretch's share of it).
	var across := sqrt(along * along * sx * sx + (1.0 - along * along) * sz * sz) if edge != Vector2.ZERO and not heap else maxf(sx, sz)
	var s := minf(want, minf(room / (r0 * across), max_half / (r0 * maxf(sx, sz))))
	if s < min_scale:
		return null
	var k := Clump.new()
	k.at = p
	k.scale = s
	k.radius = r0 * s * (sx + sz) / 2.0
	k.half_min = r0 * s * minf(sx, sz)
	k.art = art
	k.pick = rng.randi() % 7
	k.yaw = yaw
	var sy := (rng.randf_range(0.85, 1.2) if heap else lerpf(0.8, 1.5, smoothstep(0.3, 1.8, depth))) * rng.randf_range(0.9, 1.1)
	k.stretch = Vector3(sx, maxf(minf(sy, TALLEST / (float(_tall[art]) * s)), 0.7), sz)   # (never taller than a token)
	k.toward_edge = edge
	return k


func _add(cell: Vector2i, k: Clump, force: bool = false) -> void:
	var b := _bucket(k.at)
	if not force:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var list: Variant = _near_at(b + Vector2i(dx, dz))
				if list == null:
					continue
				for o: Clump in list as Array:
					if o.at.distance_to(k.at) < CROWD * (k.radius + o.radius):
						return
	if force:
		forced += 1
	var here: Array = _by_square.get(cell, [])
	here.append(k)
	_by_square[cell] = here
	var i := clampi(b.y, 0, _d - 1) * _w + clampi(b.x, 0, _w - 1)
	if _near[i] == null:
		_near[i] = []
	(_near[i] as Array).append(k)
	count += 1


func _bucket(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x), 0, _w - 1), clampi(floori(p.y), 0, _d - 1))


func _near_at(b: Vector2i) -> Variant:
	if b.x < 0 or b.y < 0 or b.x >= _w or b.y >= _d:
		return null
	return _near[b.y * _w + b.x]


## Whether a clump already covers the point `mid` (a difficult square's middle).
func _covered(mid: Vector2) -> bool:
	var b := _bucket(mid)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var list: Variant = _near_at(b + Vector2i(dx, dz))
			if list == null:
				continue
			for o: Clump in list as Array:
				if o.at.distance_to(mid) <= maxf(COVER, o.radius * 0.9):
					return true
	return false


## The nearest square of class `which` within two squares of `p`: Vector3(distance, x, z) with (x, z) the way to the
## nearest point of it (zero inside it); (9, 0, 0) where there is none near.
func _gap(p: Vector2, which: int) -> Vector3:
	var best := 9.0
	var dir := Vector2.ZERO
	var cx := floori(p.x)
	var cz := floori(p.y)
	for z in range(maxi(cz - 2, 0), mini(cz + 3, _d)):
		for x in range(maxi(cx - 2, 0), mini(cx + 3, _w)):
			if _cls[z * _w + x] != which:
				continue
			var dx := clampf(p.x, float(x), float(x + 1)) - p.x
			var dz := clampf(p.y, float(z), float(z + 1)) - p.y
			var dd := sqrt(dx * dx + dz * dz)
			if dd < best:
				best = dd
				dir = Vector2(dx, dz)
	return Vector3(best, dir.x, dir.y)


## Which of the place's dressing grows at `p`: kinds come in patches (live brambles here, dead ones there).
func _art_at(kind: FastNoiseLite, p: Vector2) -> String:
	var k := clampi(int((0.5 + 0.5 * kind.get_noise_2d(p.x, p.y)) * float(_arts.size())), 0, _arts.size() - 1)
	return _arts[k]


## The 3D model that stands for `art` (the first of a set of variants), "" where there is none.
static func _model_id(art: String) -> String:
	var entry: Variant = (ModelPiece.settings().get("art", {}) as Dictionary).get(art, "")
	if entry is Array and not (entry as Array).is_empty():
		return str((entry as Array)[0])
	return str(entry) if entry is String else ""


## Half the width of the art's 3D model (squares), else of its sprite, else a bush's.
static func _base_radius(art: String) -> float:
	var size := ((ModelPiece.manifest().get(_model_id(art), {}) as Dictionary).get("size", []) as Array)
	if size.size() == 3:
		return maxf(float(size[0]), float(size[2])) / 2.0
	var info := SetDressing.manifest().get(art, {}) as Dictionary
	return maxf(float(info.get("world_width", 0.76)) / 2.0, 0.2)


## How tall the art's model (else its sprite) stands (squares).
static func _height_of(art: String) -> float:
	var size := ((ModelPiece.manifest().get(_model_id(art), {}) as Dictionary).get("size", []) as Array)
	if size.size() == 3:
		return maxf(float(size[1]), 0.05)
	return maxf(float((SetDressing.manifest().get(art, {}) as Dictionary).get("world_height", 0.4)), 0.05)


## Whether the art's model is a low thing (a drift, a patch of ice) rather than a bush.
static func _is_low(art: String) -> bool:
	var size := ((ModelPiece.manifest().get(_model_id(art), {}) as Dictionary).get("size", []) as Array)
	return size.size() == 3 and float(size[1]) < 0.4


static func _noise(seed_: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	return n


## One clump on the board: its 3D model where the place has one, else the flat or standing sprite the old bush was.
func _place(c: Vector2i, k: Clump) -> void:
	var cell := Vector2i(floori(k.at.x), floori(k.at.y))
	var y := board.ground_y(k.at) if board.grid.has_flag(cell, CombatGrid.NATURAL) else board.floor_y(cell)
	var at := Vector3(k.at.x, y, k.at.y)
	var model := ModelPiece.for_art(board, k.art, k.pick)
	if model != "":
		var holder := ModelPiece.stand(board, board, model, k.art, c, at, k.scale)
		holder.rotation.y = k.yaw
		holder.scale = k.stretch
		holder.set_meta("ground_cover", true)
		return
	if str((SetDressing.manifest()[k.art] as Dictionary).get("mount", "stand")) == "floor":
		var flat := SetDressing.flat_sprite(k.art)
		flat.position = at + Vector3(0, SetDressing.WALL_GAP, 0)
		flat.rotation.y = k.yaw
		flat.scale = Vector3.ONE * k.scale
		flat.set_meta("ground_cover", true)
		board.add_child(flat)
		return
	var bush := board.prop_sprite(k.art, at, minf(k.scale, TALLEST / float(_tall.get(k.art, 0.5))))
	if bush != null:
		bush.flip_h = k.pick % 2 == 0   # (a web or a bush facing either way)
		bush.set_meta("ground_cover", true)   # brambles may grow into each other
