class_name GroundRelief
extends RefCounted
## Ground with shape in the Modern look (Improvement Ideas W11, docs/art/atmosphere.md "Ground with shape"). On an
## outdoor wild map the ground people walk on is drawn as one shaped skin with shallow hollows; it never rises above
## the squares' floor level, so tokens, grid overlays and spell templates still stand on the same 5 ft grid (real
## heights are F4's), and the board's own flat floor boxes under it stop drawing themselves (ArenaBoard.floor_box).
## Under the map's woods the ground rises into banks with mounds, and the land past the edge carries on from both.
## The roads between the map's ways out are laid here for anything that follows them (the surfaces lane's wheel-rut
## decals). Cosmetic only: the rules grid never sees any of it.
## On a map with natural ground (map `elevation`, owner 2026-10-08) the skin also follows its slopes
## (ArenaBoard.ground_y): it takes the rolling natural squares, and the board's own columns keep cliff edges and
## built floors.
##
## Natural Maps plan N2: the skin is on every outdoor map but the built-floor ones (towns, yards, outdoor ruins, the road
## and the castle gates, not the Amber Temple's doors or a roof), and it is one mesh with one blended material
## (Look.blend_ground, lit_world_blend.gdshader): up to four of the place's surfaces (its floor, its difficult ground, an
## area's floor, the woods' bank ground) melt into each other at their edges, noise-broken and softened over about half a
## square, so mud, drifts, a path of flags and the banks under the trees have no square tiles. Paving and the squares
## props stand on are drawn by the blend too but kept flat. A surface's own square keeps its middle 60%.
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
const PAVED := 4   ## drawn by the blend like the walked ground, but flat: paving, and the square a prop stands on
const SHORE := 5   ## a water square the ground reaches out over (Shores): drawn by the blend, in the ground beside it
## Surfaces that are built, not ground: a room's boards and tiles, the Amber Temple's black stone, the kit's wood and stone.
## Their squares keep the board's own boxes.
const BUILT_SURFACES: Array[String] = ["interior/", "amber/", "kit/", "tent/", "dungeon/"]
## Surfaces that are paved (their squares stay flat, and edges between them and earth are what blends).
const PAVED_SURFACES: Array[String] = ["cobble", "flag", "courtyard", "stone_floor"]
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
## The surfaces blended (the floor materials of the squares drawn, and the woods' bank ground), at most
## Look.BLEND_SLOTS, and each square's slot in them (255 where nothing is blended).
var _slots: Array[ShaderMaterial] = []
## Which squares roll (ArenaBoard.rolling), once worked out.
var _rolling := PackedByteArray()
## Squares of the skin kept flat (paving, a prop's square): cell -> true.
var _flat: Dictionary = {}
var _slot_of := PackedByteArray()
## The blend's control map and the material made from it, once there are meshes to draw.
var _control: ImageTexture = null
var _blend: ShaderMaterial = null
## Each map square's kind (FLAT, WOODS, SKIN, OPEN), row by row.
var _kind := PackedByteArray()
## The height at every grid point, and the natural ground's under it (0 on a map without any).
var _h := PackedFloat32Array()
var _b := PackedFloat32Array()
## The ways between the map's ways out, as smoothed lines through square middles.
var _roads: Array[PackedVector2Array] = []
## The place's shore (Natural Maps plan N3): the ground dips along its contour and reaches out over the water squares beside it.
var shore: Shores = null


static func enabled() -> bool:
	return Look.modern() and not off


## `loc` is the location's data (its exits lay the roads, its traps keep their squares as the board drew them). The
## skin is drawn on wild outdoor maps only.
static func build(board_: ArenaBoard, loc: Dictionary, woods: ShaderMaterial = null) -> GroundRelief:
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
		r._slots = k._slots
		r._flat = k._flat
		r._slot_of = k._slot_of
		r._control = k._control
		r._kind = k._kind
		r._h = k._h
		r._b = k._b
		r._nx = k._nx
		r._nz = k._nz
		r._roads = k._roads
		r.shore = k.shore
		return r
	if eligible(board_, loc):
		r._choose_skin(AtmosphereLand._trap_cells(loc), woods)
		r._take_shore()
	if board_.theme in ArenaBoard.WILD:
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
	return k == FLAT or k == SKIN or k == PAVED


## Whether the skin is drawn on this place: every outdoor map but the ones whose floors are built (an outdoor dungeon
## map: the Amber Temple's doors, Daern's roof, the tower roofs, the castle's spires), and a board with no place.
static func eligible(board_: ArenaBoard, loc: Dictionary) -> bool:
	if board_.theme in ArenaBoard.WILD:
		return true
	return bool((loc.get("map", {}) as Dictionary).get("outdoors", false)) and board_.theme != "dungeon"


## Whether a floor material can be blended: a textured ground surface, not a built one (boards, tiles, black stone).
static func blendable(m: ShaderMaterial) -> bool:
	var surface := str(m.get_meta("surface", "")) if m != null else ""
	if surface == "":
		return false
	for built in BUILT_SURFACES:
		if surface.begins_with(built):
			return false
	return true


static func paved(m: ShaderMaterial) -> bool:
	var surface := str(m.get_meta("surface", ""))
	for p in PAVED_SURFACES:
		if surface.contains(p):
			return true
	return false


## Whether square `c` is under the woods: a tree square on rolling ground, which the banks rise under.
func _is_woods(c: Vector2i) -> bool:
	# (a crag's square is drawn flat in the place's own ground, which its foot rises out of)
	return board.is_tree(c) and (not board.has_terrain() or _rolls(c)) \
			and not (board.crags != null and board.crags.cells.has(c))


## ArenaBoard.rolling for square `c`, worked out once each (it looks at the eight squares round it).
func _rolls(c: Vector2i) -> bool:
	if _rolling.is_empty():
		_rolling.resize(_w * _d)
		_rolling.fill(2)
	var k := c.y * _w + c.x
	if _rolling[k] == 2:
		_rolling[k] = 1 if board.rolling(c) else 0
	return _rolling[k] == 1


## The squares whose ground is drawn by the blend: walked ground whose floor is a plain box at floor level (or, on rolling
## natural ground, rolling) in a ground surface, that no door, house or trap lies under (a pit opens its floor box), at
## most Look.BLEND_SLOTS surfaces, the most used first, with the woods' bank ground always one of them. Paving and the
## squares props stand on stay flat (PAVED); the rest take hollows (SKIN).
func _choose_skin(traps: Dictionary, woods: ShaderMaterial) -> void:
	var g := board.grid
	var terrain := board.has_terrain()
	var picks := {}    # cell -> floor material
	var counts := {}   # material -> squares
	var usable := {}   # material -> whether it can be blended (worked out once each)
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			var f := g.flags(c)
			if (f & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)) != 0:
				continue
			# Raised ground only where it rolls (natural slopes); built floors and cliff edges stay the board's.
			var level := _rolls(c) if terrain else board.floor_y(c) == 0.0
			if not level:
				continue
			if board.door_cells.has(c) or board.house_cells.has(c) or traps.has(c):
				continue
			var box := board.floor_box(c)
			var m := box.material_override as ShaderMaterial if box != null else null
			if m == null:
				continue
			if not usable.has(m):
				usable[m] = blendable(m)
			if not usable[m]:
				continue
			picks[c] = m
			counts[m] = int(counts.get(m, 0)) + 1
	var tree_squares := 0
	if woods != null:
		for z in _d:
			for x in _w:
				if _is_woods(Vector2i(x, z)):
					tree_squares += 1
		if tree_squares > 0:
			counts[woods] = int(counts.get(woods, 0)) + tree_squares
	var ranked: Array = counts.keys()
	ranked.sort_custom(func(a: ShaderMaterial, b: ShaderMaterial) -> bool:
		if a == woods or b == woods:
			return a == woods and b != woods   # (the bank ground first: the woods are drawn only by it)
		var ca := int(counts[a])
		var cb := int(counts[b])
		return ca > cb or (ca == cb and str(a.get_meta("surface")) < str(b.get_meta("surface"))))
	_slots.clear()
	for m: ShaderMaterial in ranked:
		if _slots.size() < Look.BLEND_SLOTS:
			_slots.append(m)
	_slot_of.resize(_w * _d)
	_slot_of.fill(255)
	var slot_of := {}   # material -> its slot, and whether it is paving
	for i in _slots.size():
		slot_of[_slots[i]] = [i, paved(_slots[i])]
	for c: Vector2i in picks:
		var info: Variant = slot_of.get(picks[c])
		if info != null:
			_skin[c] = picks[c]
			_slot_of[c.y * _w + c.x] = int((info as Array)[0])
			if bool((info as Array)[1]) or board.occupied.has(c):
				_flat[c] = true
	if woods != null and tree_squares > 0:
		var woods_slot := _slots.find(woods)
		for z in _d:
			for x in _w:
				if _is_woods(Vector2i(x, z)) and woods_slot >= 0:
					_slot_of[z * _w + x] = woods_slot


## The shore of the place's water (Shores): the water squares it draws take the ground of the walkable squares beside them.
func _take_shore() -> void:
	shore = Shores.build(board, _skin, _flat)
	if shore == null:
		return
	for c: Vector2i in shore.water_squares():
		var votes := {}
		for d: Vector2i in CombatGrid.DIRS:
			var n := c + d
			if _skin.has(n):
				var slot := int(_slot_of[n.y * _w + n.x])
				votes[slot] = int(votes.get(slot, 0)) + 1
		var best := 255
		var most := 0
		for slot: int in votes:
			if int(votes[slot]) > most:
				most = int(votes[slot])
				best = slot
		_slot_of[c.y * _w + c.x] = best


func _kinds() -> void:
	var g := board.grid
	_kind.resize(_w * _d)
	for z in _d:
		for x in _w:
			var c := Vector2i(x, z)
			var k := FLAT
			if _skin.has(c):
				k = PAVED if _flat.has(c) else SKIN
			elif _is_woods(c):
				k = WOODS
			elif shore != null and shore.water_squares().has(c):
				k = SHORE
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
			var kind := _kind_of(Vector2i(x - 1, z - 1))
			bit[z * (_w + 2) + x] = 1 << (FLAT if kind == PAVED or kind == SHORE else kind)   # (paving is flat ground, and so is a shore's)
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
	_b.resize(_nx * _nz)
	var terrain := board.has_terrain()
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var p := Vector2(float(i) / RES - MARGIN, float(j) / RES - MARGIN)
			var h := 0.0
			_b[k] = board.ground_y(p) if terrain else 0.0
			if (touch[k] & (1 << SKIN)) != 0:
				var settle := smoothstep(0.0, SETTLE, skin_d[k])
				if settle > 0.0:
					h = maxf(-HOLLOW * smoothstep(0.42, 0.78, _noise(p * 0.8 + Vector2(11.3, 2.7))) * settle, -DEEPEST)
			elif bank_d[k] > 0.0:
				var d := bank_d[k]
				var n := _noise(p * 0.55) * 0.65 + _noise(p * 1.3 + Vector2(4.7, 1.9)) * 0.35
				h = BANK * smoothstep(0.0, RISE, d) + (n - 0.42) * MOUNDS * smoothstep(0.3, RISE, d) * 2.0
			if shore != null:
				h = shore.lower(h, p, _b[k])   # the bank and the shelf under the water (Shores)
			_h[k] = h + _b[k]


## The ground's height at a point of the map (0 on squares drawn flat, else the natural ground's), read off the grid.
func height(p: Vector2) -> float:
	return _read(_h, p)


## The skin's own shape at a point: its hollows and banks, without the natural ground under them.
func shape(p: Vector2) -> float:
	return _read(_h, p) - _read(_b, p)


## Whether the shaped ground draws square `c` (its walked skin, or the banks under its woods).
func draws(c: Vector2i) -> bool:
	var k := _kind_of(c)
	return k == SKIN or k == WOODS or k == PAVED or k == SHORE


func _read(a: PackedFloat32Array, p: Vector2) -> float:
	var fi := clampf((p.x + MARGIN) * RES, 0.0, _nx - 1.001)
	var fj := clampf((p.y + MARGIN) * RES, 0.0, _nz - 1.001)
	var i := floori(fi)
	var j := floori(fj)
	var fx := fi - i
	var fz := fj - j
	var k := j * _nx + i
	return lerpf(lerpf(a[k], a[k + 1], fx), lerpf(a[k + _nx], a[k + _nx + 1], fx), fz)


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


## The surfaces the blend draws, the most used first (for tests and QA).
func slots() -> Array[ShaderMaterial]:
	return _slots


## The surface (as `Look.cel_textured` names it, "village/mud_road") the shaped ground shows at point `p` of the map, or ""
## where the blend doesn't draw it (the caller asks the square's floor box). A square's middle 60% is its own surface; past
## that, the squares round it as the blend shader reads them without its noise: the surface whose weight is the most.
func surface_at(p: Vector2) -> String:
	var c := Vector2i(floori(p.x), floori(p.y))
	var own := _slot_at(c)
	if own < 0:
		return ""
	var f := Vector2(p.x - c.x - 0.5, p.y - c.y - 0.5)
	if maxf(absf(f.x), absf(f.y)) <= 0.3:
		return str(_slots[own].get_meta("surface", ""))
	# The four squares whose middles are nearest, weighed bilinearly.
	var x0 := c.x - (1 if f.x < 0.0 else 0)
	var z0 := c.y - (1 if f.y < 0.0 else 0)
	var tx := p.x - (x0 + 0.5)
	var tz := p.y - (z0 + 0.5)
	var weight := {}
	for dz in 2:
		for dx in 2:
			var slot := _slot_at(Vector2i(x0 + dx, z0 + dz))
			if slot >= 0:
				weight[slot] = float(weight.get(slot, 0.0)) + (tx if dx == 1 else 1.0 - tx) * (tz if dz == 1 else 1.0 - tz)
	var best := own
	for slot: int in weight:
		if float(weight[slot]) > float(weight.get(best, 0.0)) + 0.0001:
			best = slot
	return str(_slots[best].get_meta("surface", ""))


## The blend slot the shaped ground has on square `c` (-1 where it blends nothing).
func _slot_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _d or _slot_of.is_empty():
		return -1
	var k := _kind[c.y * _w + c.x]
	if k != SKIN and k != WOODS and k != PAVED and k != SHORE:
		return -1
	var slot := _slot_of[c.y * _w + c.x]
	return slot if slot < _slots.size() else -1


## The slots whose squares are mostly difficult ground (a 1 in their channel): mud, drifts, litter. They spill into the
## ground beside them and keep their own squares' middle 60%.
func _difficult_slots() -> Vector4:
	var hard := [0, 0, 0, 0]
	var all := [0, 0, 0, 0]
	for c: Vector2i in _skin:
		var slot := int(_slot_of[c.y * _w + c.x])
		if slot < Look.BLEND_SLOTS:
			all[slot] += 1
			if board.grid.has_flag(c, CombatGrid.DIFFICULT):
				hard[slot] += 1
	var v := Vector4.ZERO
	for i in Look.BLEND_SLOTS:
		v[i] = 1.0 if all[i] > 0 and hard[i] * 2 > all[i] else 0.0
	return v


## The blend's control map: a texel for every square of the map, a channel for each slot, set where the square is
## drawn with that slot's surface.
func _control_map() -> ImageTexture:
	if _control == null:
		var img := Image.create(_w, _d, false, Image.FORMAT_RGBA8)
		for z in _d:
			for x in _w:
				var slot := _slot_at(Vector2i(x, z))
				if slot >= 0:
					img.set_pixel(x, z, Color(1.0 if slot == 0 else 0.0, 1.0 if slot == 1 else 0.0, 1.0 if slot == 2 else 0.0, 1.0 if slot == 3 else 0.0))
		_control = ImageTexture.create_from_image(img)
	return _control


## The shaped ground, leaving out the `hidden` squares: the walked squares and the woods' banks as one mesh, in one blended
## material (Look.blend_ground) with the squares' surfaces melting into each other. One grid of points for the whole of it;
## the mesh only indexes the squares it draws.
func meshes(hidden: Dictionary = {}) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _slots.is_empty():
		return out
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
	var drawn := PackedInt32Array()
	for z in _d:
		for x in _w:
			if _slot_at(Vector2i(x, z)) >= 0 and not hidden.has(Vector2i(x, z)):
				drawn.append(z * _w + x)
	if drawn.is_empty():
		return out
	var idx := PackedInt32Array()
	idx.resize(drawn.size() * RES * RES * 6)
	var f := 0
	for cell in drawn:
		var x := cell % _w
		var z := cell / _w
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
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _blend == null:
		_blend = Look.blend_ground(_slots, _control_map(), Vector2(_w, _d), _difficult_slots())
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = _blend
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.append(mi)
	return out
