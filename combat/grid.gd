class_name CombatGrid
extends RefCounted
## The 5 ft combat grid laid over a level (plan §5.3, ADR 0004, ADR 0007). Pure data and math, no nodes:
## cells with floor height, walls, low cover and Difficult Terrain; creature footprints; movement costs and
## pathfinding by the 2024 "Playing on a Grid" rules; line of sight and cover by the corner-line method.
##
## Cell (x, z) covers world x..x+1, z..z+1 (1 world unit = 5 ft). Height is the floor's height in feet.
##
## 2024 grid rules used: entering an adjacent square (orthogonal or diagonal) costs 5 ft, Difficult Terrain 10 ft;
## a diagonal step can't cut the corner of a wall; range counts squares by the shortest route; you can pass
## through an ally, an Incapacitated creature, a Tiny creature or one two sizes different, and another creature's
## space is Difficult Terrain unless it's Tiny or your ally; you can't end your move in an occupied space.

const FEET := 5
## Cell flags.
const WALL := 1          ## fills the square to full height: blocks movement, sight and lines of effect
const LOW := 2           ## crate, low wall, rubble heap: blocks movement, gives Half Cover, doesn't block sight
const DIFFICULT := 4     ## rubble, bog, undergrowth: each square costs double
const VOID := 8          ## outside the map
const WATER := 16        ## deep water (`w`): with VOID, not walkable (swimming comes later); doesn't block sight

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

enum Cover { NONE, HALF, THREE_QUARTERS, TOTAL }
const COVER_NAMES: Array[String] = ["no cover", "Half Cover", "Three-Quarters Cover", "Total Cover"]
const COVER_BONUS: Array[int] = [0, 2, 5, 0]

var width: int = 0
var depth: int = 0
var _flags: PackedInt32Array
var _height: PackedInt32Array
## Movable obstacles that occupy a square, set by the encounter: cell -> occupant id.
var occupant: Dictionary = {}
## How far the map's open void falls (a chasm, a tower's well), from the map's `drop_ft`: a creature forced over
## the edge into a void square falls this far and out of the fight. 0: the void is the map's edge and nothing crosses.
var drop_ft: int = 0
## The ceiling's height in feet over a floor at 0 (a room's, a cave's); 0 under the open sky, where flyers go up to
## SKY_FT.
var ceiling_ft: int = 0
const SKY_FT := 60
## can_see results by footprints (walls don't move; cleared when the map changes).
var _sight_cache: Dictionary = {}


func _init(w: int = 0, d: int = 0) -> void:
	resize(w, d)


func resize(w: int, d: int) -> void:
	width = w
	depth = d
	_flags = PackedInt32Array()
	_flags.resize(w * d)
	_height = PackedInt32Array()
	_height.resize(w * d)


## Builds a grid from rows of characters (data/encounters): `.` floor, `#` wall, `=` low cover, `~` difficult,
## digits 1-4 raise the floor by 5 ft per step (a platform), ` ` void.
static func from_rows(rows: Array) -> CombatGrid:
	var d := rows.size()
	var w := 0
	for r: Variant in rows:
		w = maxi(w, str(r).length())
	var g := CombatGrid.new(w, d)
	for z in d:
		var row := str(rows[z])
		for x in w:
			var c := row[x] if x < row.length() else " "
			match c:
				"#":
					g.set_flag(Vector2i(x, z), WALL)
				"=":
					g.set_flag(Vector2i(x, z), LOW)
				"~":
					g.set_flag(Vector2i(x, z), DIFFICULT)
				" ":
					g.set_flag(Vector2i(x, z), VOID)
				"w":
					g.set_flag(Vector2i(x, z), VOID | WATER)
				"1", "2", "3", "4":
					g.set_height(Vector2i(x, z), int(c) * FEET)
	return g


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < depth


func _i(c: Vector2i) -> int:
	return c.y * width + c.x


func flags(c: Vector2i) -> int:
	return _flags[_i(c)] if in_bounds(c) else VOID


func has_flag(c: Vector2i, f: int) -> bool:
	return (flags(c) & f) != 0


func set_flag(c: Vector2i, f: int, on: bool = true) -> void:
	_sight_cache.clear()
	if in_bounds(c):
		_flags[_i(c)] = (_flags[_i(c)] | f) if on else (_flags[_i(c)] & ~f)


func height(c: Vector2i) -> int:
	return _height[_i(c)] if in_bounds(c) else 0


func set_height(c: Vector2i, feet: int) -> void:
	_sight_cache.clear()
	if in_bounds(c):
		_height[_i(c)] = feet


## Squares a creature can never stand in.
func is_solid(c: Vector2i) -> bool:
	return (flags(c) & (WALL | LOW | VOID)) != 0


## World position of a cell's center on its floor.
func world_center(c: Vector2i, size_cells: int = 1) -> Vector3:
	return Vector3(c.x + size_cells / 2.0, height(c) / float(FEET), c.y + size_cells / 2.0)


func cell_at(world: Vector3) -> Vector2i:
	return Vector2i(floori(world.x), floori(world.z))


## Squares a creature of `size_cells` occupies when its top-left square is `anchor`.
static func footprint(anchor: Vector2i, size_cells: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in size_cells:
		for dx in size_cells:
			out.append(anchor + Vector2i(dx, dz))
	return out


static func size_cells_for(size: StringName) -> int:
	match size:
		&"large":
			return 2
		&"huge":
			return 3
		&"gargantuan":
			return 4
	return 1


## Distance in feet between two footprints, counting squares by the shortest route (diagonals 5 ft) and the
## height difference as extra squares when it's larger (2024 "Ranges" on a grid). A creature is as tall as it is wide
## (a Large one fills two 5 ft levels); `a_up` and `b_up` are how far each is off its floor (flying, levitating).
func distance_ft(a: Vector2i, a_size: int, b: Vector2i, b_size: int, a_up: int = 0, b_up: int = 0) -> int:
	var dx := _axis_gap(a.x, a_size, b.x, b_size)
	var dz := _axis_gap(a.y, a_size, b.y, b_size)
	var dy := _axis_gap((height(a) + a_up) / FEET, a_size, (height(b) + b_up) / FEET, b_size)
	return maxi(maxi(dx, dz), dy) * FEET


static func _axis_gap(a: int, a_size: int, b: int, b_size: int) -> int:
	if a + a_size - 1 < b:
		return b - (a + a_size - 1)
	if b + b_size - 1 < a:
		return a - (b + b_size - 1)
	return 0


## Feet to step from `from` to the adjacent `to` for a creature of `size_cells`, or -1 if it can't.
## `blocked(cell)` says whether another creature bars the square; `slowed(cell)` whether one makes it
## Difficult Terrain. A rise or drop of more than 5 ft is climbed: 1 extra foot per foot climbed.
## Movement modes for step costs: flying ignores ground Difficult Terrain and heights; climbing (a Climb Speed,
## Spider Climb) pays nothing extra to climb.
const MOVE_FLY := 1
const MOVE_CLIMB := 2
## Incorporeal Movement: through walls and creatures, as Difficult Terrain.
const MOVE_INCORPOREAL := 4
## Difficult Terrain doesn't hinder it (Freedom of Movement).
const MOVE_UNHINDERED := 8
## The map's own Difficult Terrain costs nothing extra (Tramontane Armor: snow, ice, rubble, undergrowth).
const MOVE_TERRAIN := 16
## Flying 5 ft or more off the floor: over low walls, crates and furniture (with MOVE_FLY).
const MOVE_ALOFT := 32


func step_cost(from: Vector2i, to: Vector2i, size_cells: int, blocked: Callable, slowed: Callable, mode: int = 0) -> int:
	var d := to - from
	if absi(d.x) > 1 or absi(d.y) > 1 or d == Vector2i.ZERO:
		return -1
	# Feet spent per foot moved: 2 in Difficult Terrain, more where a spell says so (`slowed` may return a number:
	# Plant Growth's overgrowth costs 4).
	var mult := 1
	for c in footprint(to, size_cells):
		if (mode & MOVE_INCORPOREAL) != 0:
			if not in_bounds(c) or has_flag(c, VOID):
				return -1
			if is_solid(c) or bool(blocked.call(c)):
				mult = maxi(mult, 2)
			if (mode & MOVE_UNHINDERED) == 0:
				if has_flag(c, DIFFICULT) and (mode & (MOVE_FLY | MOVE_TERRAIN)) == 0:
					mult = maxi(mult, 2)
				var incorporeal_slow: Variant = slowed.call(c)
				if incorporeal_slow is int and int(incorporeal_slow) > 1:
					mult = maxi(mult, int(incorporeal_slow))
				elif bool(incorporeal_slow):
					mult = maxi(mult, 2)
			continue
		if (is_solid(c) and not _flies_over(c, mode)) or bool(blocked.call(c)):
			return -1
		if (mode & MOVE_UNHINDERED) != 0:
			continue
		if has_flag(c, DIFFICULT) and (mode & (MOVE_FLY | MOVE_TERRAIN)) == 0:
			mult = maxi(mult, 2)
		var sv: Variant = slowed.call(c)
		if sv is int and int(sv) > 1:
			mult = maxi(mult, int(sv))
		elif bool(sv):
			mult = maxi(mult, 2)
	if d.x != 0 and d.y != 0 and (mode & MOVE_INCORPOREAL) == 0:
		# Diagonals can't cut the corner of a wall or other square-filling feature (a flyer's corners are walls only).
		for c: Vector2i in [from + Vector2i(d.x, 0), from + Vector2i(0, d.y)]:
			for fc in footprint(c, size_cells):
				if (flags(fc) & (WALL | LOW | VOID)) != 0 and not _flies_over(fc, mode):
					return -1
	var cost := FEET * mult
	if (mode & MOVE_FLY) != 0:
		# Keeping its height over the floor, a flyer rises and sinks with it: a step that also climbs 10 ft costs 10.
		return maxi(cost, absi(height(to) - height(from)))
	# Climbing (2024): every foot climbed, up or down, costs 1 extra foot (2 extra in Difficult Terrain), nothing extra
	# with a Climb Speed. A rise or drop of 5 ft is a step (stairs, a dais) and costs nothing more.
	var climb := absi(height(to) - height(from))
	if climb > FEET:
		cost += climb * (mult if (mode & MOVE_CLIMB) != 0 else mult + 1)
	return cost


## How far a creature falls going over into `c`: the map's drop for an open void square inside the map, else 0.
func drop_at(c: Vector2i) -> int:
	return drop_ft if in_bounds(c) and (flags(c) & (VOID | WATER)) == VOID else 0


## Whether a flyer (`mode`) crosses square `c` that walkers can't: a chasm and deep water, and low walls, crates and
## furniture once it's 5 ft or more off the floor. Walls stop it (they reach the ceiling, or are trees and towers).
func _flies_over(c: Vector2i, mode: int) -> bool:
	if (mode & MOVE_FLY) == 0 or has_flag(c, WALL):
		return false
	if drop_at(c) > 0 or has_flag(c, WATER):
		return true
	return has_flag(c, LOW) and (mode & MOVE_ALOFT) != 0


## The highest a creature `size_cells` across can fly over square `c`'s floor: up to the ceiling, or SKY_FT outdoors.
func max_altitude(c: Vector2i, size_cells: int) -> int:
	if ceiling_ft <= 0:
		return SKY_FT
	return maxi(0, ceiling_ft - height(c) - size_cells * FEET)


## Every square reachable within `budget` feet: {cell: {"cost": int, "prev": Vector2i}}. Squares other creatures
## occupy may be passed through (when `blocked` allows) but are marked "occupied" so moves can't end there.
func reachable(start: Vector2i, size_cells: int, budget: int, blocked: Callable, slowed: Callable,
		occupied: Callable, mode: int = 0) -> Dictionary:
	var best := {start: {"cost": 0, "prev": start, "occupied": false}}
	# Dijkstra with a bucket per cost in feet (costs are small whole numbers).
	var buckets := {0: [start]}
	for cost in budget + 1:
		if not buckets.has(cost):
			continue
		for cur: Vector2i in buckets[cost]:
			if int((best[cur] as Dictionary)["cost"]) != cost:
				continue
			for d in DIRS:
				var nxt := cur + d
				var step := step_cost(cur, nxt, size_cells, blocked, slowed, mode)
				if step < 0:
					continue
				var total := cost + step
				if total > budget:
					continue
				if not best.has(nxt) or total < int((best[nxt] as Dictionary)["cost"]):
					var occ := false
					for c in footprint(nxt, size_cells):
						if bool(occupied.call(c)):
							occ = true
					best[nxt] = {"cost": total, "prev": cur, "occupied": occ}
					if not buckets.has(total):
						buckets[total] = []
					(buckets[total] as Array).append(nxt)
	return best


static func path_to(reach: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not reach.has(goal):
		return out
	var cur := goal
	while true:
		out.push_front(cur)
		var prev: Vector2i = (reach[cur] as Dictionary)["prev"]
		if prev == cur:
			break
		cur = prev
	return out


# --- Line of sight and cover ----------------------------------------------------------------------

## Cover a target at `target` (footprint `t_size`) has against an attacker at `attacker` (`a_size`), by the
## corner method: from the attacker corner that sees best, trace lines to the four corners of the target square
## that is easiest to see. Walls blocking 2 lines give Half Cover (one isn't enough), 3 Three-Quarters, 4 Total; low obstacles and
## other creatures (`creature_cells`) give at most Half Cover. An attacker standing 10+ ft above a low obstacle sees over it.
## Returns {cover: Cover, blocked: int, by: String}.
func cover_between(attacker: Vector2i, a_size: int, target: Vector2i, t_size: int,
		creature_cells: Dictionary = {}, a_up: int = 0, t_up: int = 0) -> Dictionary:
	var best := {"cover": Cover.TOTAL, "blocked": 4, "by": "walls"}
	# How high the line runs: the attacker's height, or a flying target's when that's higher (over a low wall).
	var a_h := height(attacker) + a_up
	if t_up > 0:
		a_h = maxi(a_h, height(target) + t_up)
	var a_cells := footprint(attacker, a_size)
	var t_cells := footprint(target, t_size)
	for ac in a_cells:
		for corner_a in _corners(ac):
			for tc in t_cells:
				var wall_blocked := 0
				var soft_blocked := 0
				var soft_by := ""
				for corner_t in _corners(tc):
					var hit := _line_blockers(corner_a, corner_t, a_cells, t_cells, creature_cells, a_h)
					if bool(hit["wall"]):
						wall_blocked += 1
					elif str(hit["soft"]) != "":
						soft_blocked += 1
						soft_by = str(hit["soft"])
				var cover := _cover_from(wall_blocked, soft_blocked)
				if cover < int(best["cover"]) or (cover == int(best["cover"]) and wall_blocked + soft_blocked < int(best["blocked"])):
					var by := "walls" if wall_blocked > 0 else soft_by
					best = {"cover": cover, "blocked": wall_blocked + soft_blocked, "by": by}
				if int(best["cover"]) == Cover.NONE:
					return best
	return best


## Degrees don't add: walls decide Three-Quarters and Total; creatures and low obstacles give at most Half. Cover
## needs the obstacle to block at least half the target (2024 rules), so one clipped line of four is no cover: a
## wall or crate merely beside the target, not between, gives nothing.
static func _cover_from(wall: int, soft: int) -> int:
	if wall >= 4:
		return Cover.TOTAL
	if wall == 3:
		return Cover.THREE_QUARTERS
	if wall + soft >= 2:
		return Cover.HALF
	return Cover.NONE


static func _corners(c: Vector2i) -> Array[Vector2]:
	return [Vector2(c.x, c.y), Vector2(c.x + 1, c.y), Vector2(c.x, c.y + 1), Vector2(c.x + 1, c.y + 1)]


## What blocks the segment a->b: {"wall": bool, "soft": "" or what gave cover}. Squares belonging to the
## attacker or target never block. Touching a square's edge or corner doesn't count.
func _line_blockers(a: Vector2, b: Vector2, a_cells: Array[Vector2i], t_cells: Array[Vector2i],
		creature_cells: Dictionary, attacker_height: int) -> Dictionary:
	var soft := ""
	var minx := floori(minf(a.x, b.x)) - 1
	var maxx := floori(maxf(a.x, b.x)) + 1
	var minz := floori(minf(a.y, b.y)) - 1
	var maxz := floori(maxf(a.y, b.y)) + 1
	var any_creatures := not creature_cells.is_empty()
	var d := b - a
	for z in range(minz, maxz + 1):
		# Only the squares of this row the segment can reach (the AI asks for thousands of lines a turn, and the whole
		# box around a long diagonal is mostly squares it never comes near): where it runs between z and z + 1, with
		# a square of margin each side. The row is still read in order, so the same blocker is found first.
		var row_lo := minx
		var row_hi := maxx
		if absf(d.y) > 0.000001:
			var ta := clampf((z - 0.001 - a.y) / d.y, 0.0, 1.0)
			var tb := clampf((z + 1.001 - a.y) / d.y, 0.0, 1.0)
			row_lo = maxi(minx, floori(minf(a.x + d.x * ta, a.x + d.x * tb)) - 1)
			row_hi = mini(maxx, floori(maxf(a.x + d.x * ta, a.x + d.x * tb)) + 1)
		for x in range(row_lo, row_hi + 1):
			var f := _flags[z * width + x] if x >= 0 and z >= 0 and x < width and z < depth else VOID
			var c := Vector2i(x, z)
			var is_creature := any_creatures and creature_cells.has(c)
			if (f & (WALL | LOW)) == 0 and not is_creature:
				continue
			if c in a_cells or c in t_cells:
				continue
			if (f & WALL) != 0:
				if _segment_hits_wall(a, b, c):
					return {"wall": true, "soft": ""}
				continue
			if not _segment_crosses_square(a, b, c):
				continue
			if (f & LOW) != 0 and attacker_height < height(c) + 2 * FEET:
				soft = "a low obstacle"
			elif is_creature and soft == "":
				soft = str(creature_cells[c])
	return {"wall": false, "soft": soft}


## True if the open segment a-b passes through the interior of square c (shrunk slightly so grazing an edge
## or a corner doesn't count).
static func _segment_crosses_square(a: Vector2, b: Vector2, c: Vector2i) -> bool:
	const E := 0.02
	var lo := Vector2(c.x + E, c.y + E)
	var hi := Vector2(c.x + 1 - E, c.y + 1 - E)
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var p := a[axis]
		var dd := d[axis]
		if absf(dd) < 0.000001:
			if p < lo[axis] or p > hi[axis]:
				return false
			continue
		var ta := (lo[axis] - p) / dd
		var tb := (hi[axis] - p) / dd
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return t1 > 0.0 and t0 < 1.0


## True if segment a-b runs through wall square c or along one of its edges; touching only a corner doesn't count.
## (Two wall squares side by side leave no gap to see through along their shared edge.)
static func _segment_hits_wall(a: Vector2, b: Vector2, c: Vector2i) -> bool:
	var lo := Vector2(c.x, c.y)
	var hi := Vector2(c.x + 1, c.y + 1)
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var p := a[axis]
		var dd := d[axis]
		if absf(dd) < 0.000001:
			if p < lo[axis] or p > hi[axis]:
				return false
			continue
		var ta := (lo[axis] - p) / dd
		var tb := (hi[axis] - p) / dd
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return (t1 - t0) * d.length() > 0.05


## Line of sight (and of effect) between two footprints: anything short of Total Cover.
func can_see(a: Vector2i, a_size: int, b: Vector2i, b_size: int) -> bool:
	var key := Vector4i(a.x, a.y, b.x, b.y) * 16 + Vector4i(a_size, 0, b_size, 0)
	if _sight_cache.has(key):
		return bool(_sight_cache[key])
	var seen := int(cover_between(a, a_size, b, b_size)["cover"]) != Cover.TOTAL
	_sight_cache[key] = seen
	return seen


# --- Areas of effect ------------------------------------------------------------------------------

## Squares in an area of effect (2024 glossary): a square is in the area if its center is inside the shape
## and a line from the point of origin to it isn't blocked by Total Cover (walls).
##   sphere/cylinder: origin = grid point (corner), size = radius ft
##   emanation: around the footprint `origin_cell` x `origin_size`, size = ft (origin squares excluded)
##   cube: origin = grid point on a face, `direction` = which way it extends, size = side ft
##   cone: origin = grid point at the caster, `direction` = aim vector, size = length ft
##   line: origin = grid point, `direction`, size = length ft, width ft (default 5)
func area_cells(shape: String, size_ft: int, origin: Vector2, direction: Vector2 = Vector2.RIGHT,
		width_ft: int = 5, origin_cell: Vector2i = Vector2i(-1, -1), origin_size: int = 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := size_ft / float(FEET)
	var dir := direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	var check_origin := origin
	var excluded: Array[Vector2i] = []
	if shape == "emanation" and origin_cell.x >= 0:
		excluded = footprint(origin_cell, origin_size)
		check_origin = Vector2(origin_cell.x + origin_size / 2.0, origin_cell.y + origin_size / 2.0)
	for z in depth:
		for x in width:
			var c := Vector2i(x, z)
			if has_flag(c, VOID) or has_flag(c, WALL) or c in excluded:
				continue
			var p := Vector2(x + 0.5, z + 0.5)
			var inside := false
			match shape:
				"sphere", "cylinder":
					inside = p.distance_to(origin) <= r + 0.001
				"emanation":
					var dx := _axis_gap(origin_cell.x, origin_size, x, 1)
					var dz := _axis_gap(origin_cell.y, origin_size, z, 1)
					inside = maxi(dx, dz) * FEET <= size_ft
				"cube":
					var along := (p - origin).dot(dir)
					var side := Vector2(-dir.y, dir.x)
					var across := (p - origin).dot(side)
					inside = along >= 0.0 and along <= r and absf(across) <= r / 2.0
				"cone":
					inside = _cone_covers(c, origin, dir, r)
				"wall":
					# A straight wall one square thick, centred on the point and running along `direction`.
					var v4 := p - origin
					var along4 := absf(v4.dot(dir))
					var across4 := absf(v4.dot(Vector2(-dir.y, dir.x)))
					var thick := maxf(1.0, floorf(width_ft / float(FEET)))
					inside = along4 <= r / 2.0 + 0.001 and across4 <= thick / 2.0 + 0.001
				"line":
					var v2 := p - origin
					var along3 := v2.dot(dir)
					var across3 := absf(v2.dot(Vector2(-dir.y, dir.x)))
					inside = along3 > 0.0 and along3 <= r + 0.001 and across3 <= width_ft / float(FEET) / 2.0 + 0.001
			if inside and not _wall_between(check_origin, p):
				out.append(c)
	return out


## A square is in a cone when at least a quarter of it lies inside the cone's triangle (its width at any distance
## equals that distance): that gives the even, symmetric templates of the grid rules (a 15-ft cone straight out is
## 1, 3, 3 squares; diagonally 2, 3, 1) instead of the thin, lopsided shapes a square's centre alone gives.
func _cone_covers(c: Vector2i, origin: Vector2, dir: Vector2, r: float) -> bool:
	var side := Vector2(-dir.y, dir.x)
	var hit := 0
	for i in 4:
		for j in 4:
			var v := Vector2(c.x + (i + 0.5) / 4.0, c.y + (j + 0.5) / 4.0) - origin
			var along := v.dot(dir)
			if along > 0.0 and along <= r + 0.001 and absf(v.dot(side)) <= along / 2.0 + 0.001:
				hit += 1
	return hit >= 4


## A cone from a creature toward `toward`: aimed along the nearest of the eight grid directions, starting at the
## middle of the creature's facing edge (straight out) or at its corner (diagonally).
func cone_from(cell: Vector2i, size_cells: int, toward: Vector2, size_ft: int) -> Array[Vector2i]:
	var center := Vector2(cell.x + size_cells / 2.0, cell.y + size_cells / 2.0)
	var aim := toward - center
	if aim.length() < 0.01:
		aim = Vector2.RIGHT
	var step := Vector2(roundf(cos(snappedf(aim.angle(), PI / 4.0))), roundf(sin(snappedf(aim.angle(), PI / 4.0))))
	var origin := center + step * (size_cells / 2.0)
	var out := area_cells("cone", size_ft, origin, step.normalized())
	for f in footprint(cell, size_cells):
		out.erase(f)
	return out


func _wall_between(a: Vector2, b: Vector2) -> bool:
	var minx := floori(minf(a.x, b.x)) - 1
	var maxx := floori(maxf(a.x, b.x)) + 1
	var minz := floori(minf(a.y, b.y)) - 1
	var maxz := floori(maxf(a.y, b.y)) + 1
	var end_cell := Vector2i(floori(b.x), floori(b.y))
	for z in range(minz, maxz + 1):
		for x in range(minx, maxx + 1):
			var c := Vector2i(x, z)
			if c != end_cell and has_flag(c, WALL) and _segment_hits_wall(a, b, c):
				return true
	return false
