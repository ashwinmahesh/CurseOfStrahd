class_name Woods
extends RefCounted
## The map's woods in the Modern look (the vault's Natural Maps Plan, N4; owner 2026-10-19: "we don't need to draw our
## real world maps as a battle grid. It can look like a real natural map that we just overlay a grid on top
## afterwards"). ArenaBoard._tree stood one tree a hand's breadth off the middle of every wood square, so a wood read
## as rows of spruces and its edge ran dead straight along a grid line. Here each wood square's trees stand where the
## place's seed and a noise put them: sizes, leans and kinds vary, the edge of the crowns wanders in and out over the
## grid line (a trunk never more than a quarter of a square into the open square beside it, so a token in that square's
## middle and its ring stay clear), a smaller tree or two fringe the edge, and the open ground beside a wood is feathered
## with saplings, undergrowth and deadfall that reach out into it by up to half a square (Flora.dress_map calls feather).
## Every wood square keeps a crown over its middle, so it still reads as the wall the rules make it; each tree still
## belongs to its square (ArenaBoard.dressing: a prop on the square hides them all) and fades in the party's way.
## Cosmetic only: the rules grid never sees any of it. The Classic look is frozen and keeps its one tree a square.

## How far past the grid line a trunk may stand into an open square: a quarter of a square less the trunk's own girth.
const TRUNK_OUT := 0.18
## How far a crown's edge reaches past the grid line over an open square: from a bay (it draws back inside the wood
## square) to a headland.
const BAY := -0.38
const HEADLAND := 0.78
## A trunk stands within this many squares of its own square's middle across the edge, and at most this share of its
## crown's radius from the middle (so the crown always covers it: the square still reads as blocking).
const ACROSS := 0.42
const HOLD := 0.93
## The map's trees stay 10 to 20 ft (docs/art/plants.md): they don't wall in the squares beside them. A leaning tree's
## box is a little taller than the tree, so a tree is fitted to the box (test_flora and test_models_3d measure 2 to 4).
const HEIGHT_MIN := 2.1
const HEIGHT_MAX := 3.7
## The box of a tree as drawn (leaning, whatever its model's own box) stays between these.
const BOX_MIN := 2.1
const BOX_MAX := 3.86
## The feathered edge: how far plants reach into an open square from the wood's grid line (ground plants), how far
## saplings and fallen trees do (taller than a token's knee: a quarter of a square less their own girth), and how far
## from the open square's middle every plant stays (feet and the selection ring).
const FEATHER_REACH := 0.5
const TALL_REACH := 0.2
const MIDDLE_CLEAR := 0.3
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Set by art QA tools only, to shoot a place as it was before (the natural audit's NA_NO_WOODS).
static var off := false


## Value noise 0..1, smooth over a square or so.
static func noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


## Value noise pulled apart toward 0 and 1 (a sum of two octaves of it hugs the middle), for bays and headlands.
static func swing(p: Vector2, q: Vector2) -> float:
	return clampf((noise(p) * 0.65 + noise(q) * 0.35 - 0.5) * 3.0 + 0.5, 0.0, 1.0)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


## Where a place's noise starts, so no two places wander alike (shapes come from noise seeded by the place).
static func _seed_of(place: String) -> Vector2:
	var h := absi(hash(place))
	return Vector2(float(h % 1013), float(h / 1013 % 1013)) * 0.173


## The squares beside wood square `c` that the party can stand on and nothing of the location's stands on: a trunk
## may stand a little over the grid line into these.
static func open_sides(board: ArenaBoard, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in SIDES:
		var n := c + d
		if not board.grid.in_bounds(n) or (board.grid.flags(n) & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)) != 0:
			continue
		if board.occupied.has(n) or board.door_cells.has(n) or board.house_cells.has(n):
			continue
		out.append(d)
	return out


## Whether the board drew wall square `c` as a tree (a Flora plant, meta `nature`), not as a rock column.
static func is_wood(board: ArenaBoard, c: Vector2i) -> bool:
	if not board.is_tree(c):
		return false
	for n: Variant in board.dressing.get(c, []):
		if is_instance_valid(n) and (n as Node).has_meta("nature"):
			return true
	return false


## The radius of plant `id`'s crown at scale `s`.
static func crown(id: String, s: float) -> float:
	var size := (Flora.manifest().get(id, {}) as Dictionary).get("size", [2.0, 3.0, 2.0]) as Array
	return maxf(float(size[0]), float(size[2])) * 0.5 * s


## Reshapes `anchor`, the tree ArenaBoard._tree stood on wood square `c`, and returns the square's other trees (each
## belongs to `c`: the board adds them to its dressing and fades them). Nothing in the Classic look, or where the tree
## isn't one of Flora's.
static func plant(board: ArenaBoard, c: Vector2i, anchor: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var id := str(anchor.get_meta("model", ""))
	if off or not board.has_meta("flora") or not Flora.manifest().has(id) or anchor.get_child_count() == 0:
		return out   # (Classic's tree, or one of the old models: left as it is)
	var f := board.get_meta("flora") as Flora
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/wood/%d/%d" % [board.place, c.x, c.y])   # cosmetic only, never rules
	var seed_at := _seed_of(board.place)
	var open := open_sides(board, c)
	var mid := Vector2(c) + Vector2(0.5, 0.5)
	# Size: along an edge, bays of smaller trees and headlands of bigger ones.
	var mi := anchor.get_child(0) as MeshInstance3D
	var height := Flora.height_of(id)
	var grove := swing(Vector2(c) * 0.2 + seed_at + Vector2(31.7, 9.2), Vector2(c) * 0.5 + seed_at + Vector2(3.1, 17.3))
	var m := exp(rng.randfn(0.0, 0.1)) * lerpf(0.7, 1.3, grove)   # groves of tall trees, patches of young ones
	var wob := _wobble(c, open, seed_at)
	if not open.is_empty():
		m *= lerpf(0.66, 1.1, clampf(wob.z + rng.randf_range(-0.15, 0.15), 0.0, 1.0))   # bays hold the small trees
	var s := clampf(mi.scale.x * m, HEIGHT_MIN / height, HEIGHT_MAX / height)
	mi.scale = Vector3.ONE * s
	var at := _stand(open, wob, crown(id, s), rng)
	anchor.position.x = mid.x + at.x
	anchor.position.z = mid.y + at.y
	_lean(anchor, id, open, rng)
	_tone(anchor, grove, rng)
	var dens := density_of(f)
	if not open.is_empty():
		# One smaller tree in the crowns' edge (more of them in a thick wood), a second on a headland.
		var chance := lerpf(0.3, 0.6, clampf((dens - 1.0) / 0.25, 0.0, 1.0))
		var fringe := (1 if rng.randf() < chance else 0) + (1 if wob.z > 0.75 and rng.randf() < 0.35 else 0)
		for i in fringe:
			var e := _fringe(board, f, c, mid, open, wob, at, rng)
			if e != null:
				_tone(e, grove, rng)
				out.append(e)
	elif rng.randf() < (dens - 1.0) * 0.5:   # and, in a thicker wood, one more among the rest
		var e := _among(board, f, c, mid, rng)
		if e != null:
			out.append(e)
	return out


## Trees to a wood square, from the plant set: its `wood_density`, else from its `tree_density` (the land's forest:
## 0.45 is 1.15, a thinner wood 1.0, a thicker one 1.3). Above 1, the extra trees are the chance of one more.
static func density_of(f: Flora) -> float:
	if f.spec.has("wood_density"):
		return float(f.spec["wood_density"])
	return clampf(1.0 + (float(f.spec.get("tree_density", 0.45)) - 0.25) * 0.75, 1.0, 1.4)


## How far the crowns' edge reaches past the grid line along each open side of `c`: x on a side along x, y on a side
## along z (0..1, low a bay, high a headland), smooth along the edge and different on each face of a wood; z is the mean
## of the sides it has.
static func _wobble(c: Vector2i, open: Array[Vector2i], seed_at: Vector2) -> Vector3:
	var out := Vector3(0.5, 0.5, 0.5)
	var sum := 0.0
	for d: Vector2i in open:
		var n := swing(Vector2(c) * 0.33 + Vector2(d) * 4.7 + seed_at, Vector2(c) * 0.95 + Vector2(d) * 1.9 + seed_at)
		if d.x != 0:
			out.x = n
		else:
			out.y = n
		sum += n
	if not open.is_empty():
		out.z = sum / open.size()
	return out


## Where a trunk whose crown has radius `r` stands on its wood square, from the square's middle: anywhere across an
## edge, and along the way out to an open side so the crown's edge lands where the wobble says (a bay or a headland),
## never more than TRUNK_OUT past the grid line.
static func _stand(open: Array[Vector2i], wob: Vector3, r: float, rng: RandomNumberGenerator) -> Vector2:
	var o := Vector2(rng.randf_range(-ACROSS, ACROSS), rng.randf_range(-ACROSS, ACROSS))
	var east := open.has(Vector2i(1, 0))
	var west := open.has(Vector2i(-1, 0))
	var south := open.has(Vector2i(0, 1))
	var north := open.has(Vector2i(0, -1))
	if east != west:
		var edge_x := 0.5 + lerpf(BAY, HEADLAND, wob.x)
		o.x = clampf(edge_x - r, -0.45, 0.5 + TRUNK_OUT) * (1.0 if east else -1.0) + rng.randf_range(-0.06, 0.06)
	if south != north:
		var edge_z := 0.5 + lerpf(BAY, HEADLAND, wob.y)
		o.y = clampf(edge_z - r, -0.45, 0.5 + TRUNK_OUT) * (1.0 if south else -1.0) + rng.randf_range(-0.06, 0.06)
	return o.limit_length(maxf(HOLD * r, 0.05))


## Tilts a tree a few degrees, toward the open side if it stands on an edge (trees lean to the light), more for the
## dead ones.
static func _lean(tree: Node3D, id: String, open: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var dead := str((Flora.manifest().get(id, {}) as Dictionary).get("kind", "tree")) == "dead"
	var dir := Vector2.from_angle(rng.randf() * TAU)
	if not open.is_empty() and rng.randf() < 0.7:
		dir = (dir * 0.5 + Vector2(open[rng.randi() % open.size()])).normalized()
	var tilt := deg_to_rad(clampf(absf(rng.randfn(0.0, 4.0 if dead else 2.5)), 0.0, 8.0 if dead else 5.5))
	tree.basis = Basis(Vector3(dir.y, 0.0, -dir.x), tilt) * Basis(Vector3.UP, tree.rotation.y)   # (the lean in the world's frame)
	var mi := tree.get_child(0) as MeshInstance3D
	if mi != null and mi.mesh != null:
		var h := (Transform3D(tree.basis * Basis.from_scale(mi.scale), Vector3.ZERO) * mi.mesh.get_aabb()).size.y
		if h > 0.01 and (h < BOX_MIN or h > BOX_MAX):
			mi.scale *= clampf(h, BOX_MIN, BOX_MAX) / h


## The tree's leaves a shade warmer or cooler, lighter or darker (the foliage shader's instance `hue`): groves of yellower
## trees and of bluer ones across a wood, and a touch of its own on every tree.
static func _tone(tree: Node3D, grove: float, rng: RandomNumberGenerator) -> void:
	var mi := tree.get_child(0) as GeometryInstance3D
	if mi == null:
		return
	var warm := (grove - 0.5) * 0.2 + rng.randf_range(-0.04, 0.04)   # -0.1 .. 0.1
	var light := 1.0 + (0.5 - grove) * 0.18 + rng.randf_range(-0.06, 0.06)
	mi.set_instance_shader_parameter("hue", Vector3((1.0 + warm) * light, (1.0 + warm * 0.4) * light, (1.0 - warm * 1.4) * light))


## A second, smaller tree in the crowns' edge on an edge square, on the other side of the line the anchor stands on.
static func _fringe(board: ArenaBoard, f: Flora, c: Vector2i, mid: Vector2, open: Array[Vector2i], wob: Vector3,
		anchor_at: Vector2, rng: RandomNumberGenerator) -> Node3D:
	var d := open[rng.randi() % open.size()]
	var along := Vector2(d)
	var across := Vector2(-along.y, along.x)
	var tree := _made(f, c, "dead_tree" if rng.randf() < 0.1 else "pine", 0.82, rng)
	if tree == null:
		return null
	var w := wob.x if d.x != 0 else wob.y
	var r := crown(str(tree.get_meta("model")), (tree.get_child(0) as Node3D).scale.x)
	var reach := clampf(lerpf(BAY, HEADLAND, w) + rng.randf_range(0.0, 0.12), BAY, HEADLAND)
	var side := signf(anchor_at.dot(across))
	var shift := (-side if side != 0.0 else 1.0) * rng.randf_range(0.2, 0.42)
	var p := along * clampf(0.5 + reach - r, -0.2, 0.5 + TRUNK_OUT) + across * shift
	tree.position = Vector3(mid.x + p.x, 0.0, mid.y + p.y)
	return tree


## A tree among the rest of a wood square (above a density of 1).
static func _among(board: ArenaBoard, f: Flora, c: Vector2i, mid: Vector2, rng: RandomNumberGenerator) -> Node3D:
	var tree := _made(f, c, "pine", 0.75, rng)
	if tree == null:
		return null
	var p := Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
	tree.position = Vector3(mid.x + p.x, 0.0, mid.y + p.y)
	(tree.get_child(0) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tone(tree, rng.randf(), rng)
	return tree


## One more tree of the square, `shrink` of the size the set gives, standing at the origin, or null where the set has
## none of that kind.
static func _made(f: Flora, c: Vector2i, kind: String, shrink: float, rng: RandomNumberGenerator) -> Node3D:
	var pick := ModelPiece.hash_cell(c) + rng.randi_range(1, 9973)
	var id := f.tree_for(kind, pick)
	if id == "":
		return null
	var height := Flora.height_of(id)
	var s := clampf(f.tree_scale(id, "map", pick) * shrink, HEIGHT_MIN / height, HEIGHT_MAX / height)
	var tree := f.node(id, Vector3.ZERO, s, rng.randf() * TAU)
	var none: Array[Vector2i] = []
	_lean(tree, id, none, rng)
	return tree


# --- The feathered edge ---------------------------------------------------------------------------------------------

## Ground plants, saplings and fallen trees on open square `c` beside a wood: not a strip along the grid line but a
## band whose depth wanders, from nothing to half a square, thinning as it goes, with the odd sapling and fallen dead
## tree against the line. `items` is Flora.dress_map's (plant id -> [[Transform3D, Color], ...]); `choices` the set's
## edge plants.
static func feather(f: Flora, items: Dictionary, board: ArenaBoard, c: Vector2i, choices: Array) -> void:
	var boxes: Array[Rect2] = []
	var wood := false
	for d: Vector2i in CombatGrid.DIRS:
		var n := c + d
		if board.grid.in_bounds(n) and board.is_tree(n):
			boxes.append(Rect2(Vector2(n), Vector2.ONE))
			wood = wood or is_wood(board, n)
	if boxes.is_empty():
		return
	var seed_at := _seed_of(board.place)
	var mid := Vector2(c) + Vector2(0.5, 0.5)
	var rng := f.rng
	for i in ceili(Flora.density(choices) * 8.0):
		var p := Vector2(c) + Vector2(rng.randf(), rng.randf())
		if (p - mid).length() < MIDDLE_CLEAR:
			continue
		var gap := _gap(boxes, p)
		var reach := lerpf(0.03, FEATHER_REACH, swing(p * 0.8 + seed_at, p * 2.3 + seed_at))
		if gap >= reach or rng.randf() > pow(1.0 - gap / reach, 0.6):
			continue
		var id := f.pick_from(choices)
		if id == "":
			continue
		if not items.has(id):
			items[id] = []
		(items[id] as Array).append(f.ground_item(Vector3(p.x, 0.0, p.y), 0.85))
	if not wood:
		return
	# Saplings (up to two) against the line, where the noise says the wood is spreading.
	var pine := (f.spec.get("trees", {}) as Dictionary).get("pine", []) as Array
	if not pine.is_empty() and noise(mid * 0.9 + seed_at + Vector2(7.3, 1.1)) > 0.3:
		for k in 2:
			if rng.randf() > (0.6 if k == 0 else 0.35):
				continue
			for attempt in 4:
				var p := Vector2(c) + Vector2(rng.randf(), rng.randf())
				if _gap(boxes, p) >= TALL_REACH or (p - mid).length() < MIDDLE_CLEAR:
					continue
				var id := str(pine[rng.randi() % pine.size()])
				if Flora.mesh(id) == null:
					break
				var s := rng.randf_range(1.0, 2.0) / Flora.height_of(id)
				if not items.has(id):
					items[id] = []
				var v := rng.randf_range(0.85, 1.05)
				(items[id] as Array).append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0.0, p.y)), Color(v, v, v)])
				break
	# A fallen dead tree lying along the line of the wood, now and then.
	var dead := (f.spec.get("trees", {}) as Dictionary).get("dead_tree", []) as Array
	if not dead.is_empty() and rng.randf() < 0.16:
		for d: Vector2i in SIDES:
			if not board.is_tree(c + d):
				continue
			var id := str(dead[rng.randi() % dead.size()])
			if Flora.mesh(id) == null:
				break
			var axis := Vector2(-d.y, d.x)   # along the wood's edge
			var length := rng.randf_range(0.65, 0.85)   # (short enough that its base stays on this square)
			var s := length / Flora.height_of(id)
			var depth := rng.randf_range(0.1, TALL_REACH)
			var p := mid + Vector2(d) * (0.5 - depth) + axis * rng.randf_range(-0.08, 0.08)
			var heading := atan2(axis.x, axis.y) + rng.randf_range(-0.2, 0.2)
			# On its side (the model's trunk runs up its y axis; tipped onto z), centred on p.
			var basis := (Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, deg_to_rad(86.0 + rng.randf_range(-4.0, 4.0)))).scaled(Vector3.ONE * s)
			var base := Vector3(p.x, 0.0, p.y) - basis.y.normalized() * (length * 0.5)
			if not items.has(id):
				items[id] = []
			var v := rng.randf_range(0.85, 1.05)
			(items[id] as Array).append([Transform3D(basis, base), Color(v, v, v)])
			break


## How far point `p` is from the nearest of the boxes (0 inside one), blended between them so the reach rounds off round
## the inside corner of a clearing instead of following its square corner.
static func _gap(boxes: Array[Rect2], p: Vector2) -> float:
	var sum := 0.0
	for b: Rect2 in boxes:
		var dx := maxf(maxf(b.position.x - p.x, p.x - b.end.x), 0.0)
		var dz := maxf(maxf(b.position.y - p.y, p.y - b.end.y), 0.0)
		sum += exp(-8.0 * sqrt(dx * dx + dz * dz))
	return maxf(-log(sum) / 8.0, 0.0) if sum > 0.0 else INF
