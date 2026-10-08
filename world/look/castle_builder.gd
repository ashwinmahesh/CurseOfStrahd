class_name CastleBuilder
extends RefCounted
## Castle Ravenloft from outside (Improvement Ideas W19, docs/art/building_kit.md), in the Modern look: the gates' and
## the overlook's wall squares become the castle instead of stone houses. Curtain walls stand 6 high on a battered foot
## under a crenellated parapet carried out on machicolations, with crossbow loops and stepped buttresses; the keep
## stands taller with its lancet windows; round towers with slated spires rise where the catalog puts them; an arch
## spans each passage through a wall; and the void beside the land is a chasm whose rock faces fall away into the mist.
##
## The pieces come from the building kit (blender/building_kit.py, kit_castle_* and kit_cliff_*), merged per piece of
## the castle. TownBuilder.plan hands a place to plan() before it looks for houses; the walls are buildings to the board
## (house_cells), so props hang on their faces, and a piece between the camera and the party is cut down to its foot
## (cut(), from TownBuilder.cut_away). Nothing here changes the rules grid. Placements are per place in the catalog
## (art/sprites/props/catalog.json building_kit.castle).

const CHUNK := 4            ## wall squares per cut-away piece along each axis
const CUT := 1.25           ## a cut-away castle piece's height: its battered foot and roll moulding
const CORE := "castle/ashlar"
const COPING := "kit/dressed_stone"
const PARAPET := 1.0        ## a low wall's height (catalog `parapets`: the cliff road's edge)
const LOW := 2.5            ## a piece lower than this is never in the way (a roof's parapet)
const DEEP := 21.0          ## how far the chasm's cliffs fall (the mist has them long before)
const CLIFF := 3.0          ## one cliff module's height
## Around the party, where a piece in the way of these points (beside the party, and past it) is cut too: a castle wall
## 6 high hides the ground five squares behind it.
const LOOK_SIDE := 2.6
const LOOK_PAST := 2.0


## This place's castle settings (catalog building_kit.castle.places), in the Modern look; empty elsewhere.
static func settings(board: ArenaBoard) -> Dictionary:
	if board.place == "" or not Look.modern():
		return {}
	var places := (BuildingKit.settings().get("castle", {}) as Dictionary).get("places", {}) as Dictionary
	return places.get(board.place, {}) as Dictionary


## Builds the castle on this board if the place is one (and the kit is there): its walls, keep, towers, gates and the
## chasm. False leaves the board to the houses.
static func plan(board: ArenaBoard) -> bool:
	var cfg := settings(board)
	if cfg.is_empty() or not BuildingKit.has("kit_castle_wall_top_a"):
		return false
	var g := board.grid
	var rect := _rect(cfg.get("rect", []), Rect2i(0, 0, g.width, g.depth))
	var keeps: Array[Rect2i] = []
	for r: Variant in cfg.get("keeps", []):
		keeps.append(_rect(r, Rect2i()))
	var wall_h := float(cfg.get("wall", 6.0))
	var keep_h := float(cfg.get("keep", 10.0))
	var low: Array[Rect2i] = []
	for r: Variant in cfg.get("parapets", []):
		low.append(_rect(r, Rect2i()))
	var cells := {}   # wall square -> its height
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, z)
			if not g.in_bounds(c) or not g.has_flag(c, CombatGrid.WALL):
				continue
			var h := wall_h
			for k in keeps:
				if k.has_point(c):
					h = keep_h
			for k in low:
				if k.has_point(c):
					h = PARAPET
			for hr: Variant in cfg.get("heights", []):
				var a := hr as Array
				if Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])).has_point(c):
					h = float(a[4])
			cells[c] = h
	# Blocks of the castle past the map's edge (the keep behind the overlook): wall squares with no square on the map.
	for blk: Variant in cfg.get("blocks", []):
		var a := blk as Array
		for z in int(a[3]):
			for x in int(a[2]):
				var c := Vector2i(int(a[0]) + x, int(a[1]) + z)
				if not g.in_bounds(c):
					cells[c] = float(a[4])
	if cells.is_empty():
		return false
	var st := {"cells": cells, "gates": {}, "keep": keep_h, "wall": wall_h, "below": float(cfg.get("below", 0.0))}
	board.set_meta("castle", st)
	var gates := _gates(board, cells)
	# The walls in pieces of CHUNK x CHUNK squares, each cut away on its own.
	var chunks := {}
	for c: Vector2i in cells:
		var key := Vector2i(floori(c.x / float(CHUNK)), floori(c.y / float(CHUNK)))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(c)
	var group := 0
	for key: Vector2i in chunks:
		_walls(board, st, chunks[key] as Array, group)
		group += 1
	for gate: Dictionary in gates:
		_gate(board, st, gate, group)
		group += 1
	for t: Variant in cfg.get("towers", []):
		_tower(board, t as Dictionary, group)
		group += 1
	_chasm(board, cfg)
	return true


static func _rect(v: Variant, fallback: Rect2i) -> Rect2i:
	var a := v as Array if v is Array else []
	if a.size() != 4:
		return fallback
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


## A castle piece the board knows as a building: its full version (`walls`), its cut-away foot (`stub`) and what hides
## with its walls (`upper`: spires).
static func _piece(board: ArenaBoard, name: String, cells: Array, group: int, h: float, aabb: AABB) -> Dictionary:
	var root := Node3D.new()
	root.name = name
	board.add_child(root)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	var r := Rect2i()
	var first := true
	for c: Vector2i in cells:
		r = Rect2i(c, Vector2i.ONE) if first else r.merge(Rect2i(c, Vector2i.ONE))
		first = false
	var b := {"root": root, "walls": null, "stub": null, "upper": upper, "height": h, "extras": [], "cut": false,
		"aabb": aabb, "rect": r, "group": group, "kit": "castle", "castle": true, "part": name.trim_prefix("Castle").to_lower(),
		"low": h < LOW}
	var idx := board.buildings.size()
	board.buildings.append(b)
	for c: Vector2i in cells:
		board.house_cells[c] = idx
	return b


static func _finish(b: Dictionary, parts: Array, stub: Array) -> void:
	var root := b["root"] as Node3D
	var walls := BuildingKit.merge(parts)
	if walls != null:
		walls.name = "Walls"
		root.add_child(walls)
		root.move_child(walls, 0)
	var low := BuildingKit.merge(stub)
	if low != null:
		low.name = "Stub"
		low.visible = false
		root.add_child(low)
	for key: String in ["walls", "stub"]:
		if (walls if key == "walls" else low) == null:
			var empty := Node3D.new()
			empty.name = key.capitalize()
			root.add_child(empty)
			b[key] = empty
		else:
			b[key] = walls if key == "walls" else low


static func _box(size: Vector3, at: Vector3, mat: String) -> Array:
	var bm := BoxMesh.new()
	bm.size = size
	return [bm, Transform3D(Basis(), at), mat]


## Is `n` beside the castle's walls open to the sky (a face to dress)? Floor, void, the map's edge, other walls.
static func _open(st: Dictionary, n: Vector2i) -> bool:
	return not (st["cells"] as Dictionary).has(n)


## A piece of curtain wall or keep: each square's body to its height, and on each open face a battered foot (not over
## the chasm), the parapet on its machicolations, and by the face's hash a crossbow loop, a buttress, or on the keep
## its lancet windows.
static func _walls(board: ArenaBoard, st: Dictionary, cells: Array, group: int) -> void:
	var heights := st["cells"] as Dictionary
	var hmax := 0.0
	var box := AABB()
	var first := true
	for c: Vector2i in cells:
		hmax = maxf(hmax, float(heights[c]))
		if float(heights[c]) <= PARAPET:
			continue   # a parapet is never in the way
		var cb := AABB(Vector3(c.x - 0.45, 0, c.y - 0.45), Vector3(1.9, float(heights[c]) + 1.3, 1.9))
		box = cb if first else box.merge(cb)
		first = false
	var b := _piece(board, "CastleWall", cells, group, hmax, box)
	var parts: Array = []
	var stub: Array = []
	var keep_h := float(st["keep"])
	var buttress_h := float((BuildingKit.manifest().get("kit_castle_buttress", {}) as Dictionary).get("height", 5.1))
	for c: Vector2i in cells:
		var h := float(heights[c])
		var centre := Vector3(c.x + 0.5, 0, c.y + 0.5)
		parts.append(_box(Vector3(1, h, 1), centre + Vector3(0, h / 2.0, 0), CORE))
		stub.append(_box(Vector3(1, CUT, 1), centre + Vector3(0, CUT / 2.0, 0), CORE))
		stub.append(_box(Vector3(1.04, 0.08, 1.04), centre + Vector3(0, CUT + 0.04, 0), COPING))
		if h <= PARAPET:
			# A low wall along the cliff road: coursed stone under a dressed coping.
			parts.append(_box(Vector3(1.06, 0.1, 1.06), centre + Vector3(0, h + 0.05, 0), COPING))
			continue
		for d in SetDressing.FACES:
			var n := c + d
			if not _open(st, n):
				continue
			var nv := Vector3(d.x, 0, d.y)
			var base := centre + nv * 0.5
			var yaw := atan2(nv.x, nv.z)
			var pick := ModelPiece.hash_cell(c * 5 + d)
			var chasm := board.grid.in_bounds(n) and board.grid.has_flag(n, CombatGrid.VOID)
			if not chasm and h >= LOW:   # (a roof's parapet stands on the roof, with no battered foot)
				parts.append(["kit_castle_wall_foot", BuildingKit.face_xf(base, yaw)])
				stub.append(["kit_castle_wall_foot", BuildingKit.face_xf(base, yaw)])
			# Machicolations on the faces looking out (over the chasm, off the map, the keep's); a plain parapet
			# on a curtain wall's inner face and on a roof's.
			var inner := h < LOW or (h <= float(st["wall"]) + 0.01 and board.grid.in_bounds(n) and not chasm \
				and not board.grid.has_flag(n, CombatGrid.WALL) and _inside(board, st, c, d))
			var top_id := "kit_castle_wall_top_c" if inner and BuildingKit.has("kit_castle_wall_top_c") \
				else ("kit_castle_wall_top_b" if pick % 3 == 0 else "kit_castle_wall_top_a")
			parts.append([top_id, BuildingKit.face_xf(base + Vector3(0, h, 0), yaw)])
			# What stands on the face: on the keep, windows in two storeys between buttresses; on the curtain
			# walls, a loop on every third face and a buttress on some of the faces over the chasm and the yards.
			var keep := h > float(st["wall"]) + 0.01
			var ahead := board.grid.in_bounds(n) and not board.grid.has_flag(n, CombatGrid.WALL) and not chasm
			if keep and h >= 7.0:
				if (c.x + c.y) % 2 == 0:
					for z: float in [3.6, 6.6]:
						if z + 2.4 < h:
							var lit := ModelPiece.hash_cell(c * 7 + d + Vector2i(int(z), 0)) % 5 == 0
							parts.append(["kit_castle_window_lit" if lit else "kit_castle_window",
								BuildingKit.face_xf(base + Vector3(0, z, 0), yaw)])
				elif not ahead or pick % 2 == 0:
					parts.append(["kit_castle_buttress", BuildingKit.face_xf(base, yaw, (h - 1.0) / buttress_h)])
			elif pick % 5 == 1 and not ahead:
				parts.append(["kit_castle_buttress", BuildingKit.face_xf(base, yaw, (h - 0.9) / buttress_h)])
			elif pick % 3 == 2 and h >= 4.0:
				parts.append(["kit_castle_slit", BuildingKit.face_xf(base + Vector3(0, h * 0.55, 0), yaw)])
	_finish(b, parts, stub)


## Does the face of wall square `c` looking along `d` look into the castle (a yard closed in by its walls) rather than
## out of it? Walking from the face's square away from the wall, there's more wall within a few squares.
static func _inside(board: ArenaBoard, st: Dictionary, c: Vector2i, d: Vector2i) -> bool:
	var cells := st["cells"] as Dictionary
	for k: int in range(2, 40):
		var n := c + d * k
		if not board.grid.in_bounds(n) or board.grid.has_flag(n, CombatGrid.VOID):
			return false
		if cells.has(n):
			return true
	return false


## The passages through the castle's walls: a run of up to three open squares between two wall squares, as deep as
## the wall (up to three squares). Each {cells, w, d, along_x, centre}.
static func _gates(board: ArenaBoard, cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var g := board.grid
	for along_x: bool in [true, false]:
		var step := Vector2i(1, 0) if along_x else Vector2i(0, 1)
		var across := Vector2i(0, 1) if along_x else Vector2i(1, 0)
		for c: Vector2i in cells:
			var start := c + step
			if not _passable(board, start) or seen.has(start):
				continue
			var w := 0
			while w < 4 and _passable(board, start + step * w):
				w += 1
			if w > 3 or not cells.has(start + step * w) or float(cells[c]) <= PARAPET:
				continue
			# As deep as the same run stays walled either side.
			var d0 := 0
			while d0 < 3 and _run(board, cells, start - across * (d0 + 1), step, w):
				d0 += 1
			var d1 := 0
			while d1 < 3 and _run(board, cells, start + across * (d1 + 1), step, w):
				d1 += 1
			var depth := d0 + d1 + 1
			if depth > 3:
				continue
			var top := start - across * d0
			var gc: Array[Vector2i] = []
			for i in w:
				for j in depth:
					gc.append(top + step * i + across * j)
					seen[top + step * i + across * j] = true
			var centre := Vector3(top.x, 0, top.y) + (Vector3(step.x, 0, step.y) * w + Vector3(across.x, 0, across.y) * depth) / 2.0
			out.append({"cells": gc, "w": w, "d": depth, "along_x": along_x, "centre": centre})
	return out


static func _passable(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID)


## The same run of w open squares from `start` along `step`, walled at both ends.
static func _run(board: ArenaBoard, cells: Dictionary, start: Vector2i, step: Vector2i, w: int) -> bool:
	if not cells.has(start - step) or not cells.has(start + step * w):
		return false
	for i in w:
		if not _passable(board, start + step * i):
			return false
	return true


## An arch over a passage, the wall going on over it to the walls' height with its parapet on both faces.
static func _gate(board: ArenaBoard, st: Dictionary, gate: Dictionary, group: int) -> void:
	var w := int(gate["w"])
	var d := int(gate["d"])
	var id := "kit_castle_gate_w%d_d%d" % [mini(w, 2), mini(d, 2)]
	if not BuildingKit.has(id):
		return
	var cells := gate["cells"] as Array
	var heights := st["cells"] as Dictionary
	var along_x := bool(gate["along_x"])
	var step := Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var first := cells[0] as Vector2i
	var h := maxf(float(heights.get(first - step, 6.0)), 0.0)
	var centre := gate["centre"] as Vector3
	var span := Vector3(w, 0, d) if along_x else Vector3(d, 0, w)
	var top := float((((BuildingKit.manifest()[id] as Dictionary).get("sockets", {}) as Dictionary).get("top", [0, 3.5, 0]) as Array)[1])
	if h < top + 0.4:
		return   # a gap in a wall too low for an arch (a roof's parapet) stays open to the sky
	var b := _piece(board, "CastleGate", [], group, h, AABB(centre - span / 2.0 - Vector3(0.3, 0, 0.3), span + Vector3(0.6, h + 1.3, 0.6)))
	(st["gates"] as Dictionary)[first] = b
	for c: Vector2i in cells:
		(st["gates"] as Dictionary)[c] = b
	var yaw := 0.0 if along_x else PI / 2.0
	# Wider or deeper passages than the arches made: the arch stretched to fit.
	var sx := float(w) / float(mini(w, 2))
	var sz := float(d) / float(mini(d, 2))
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, 1.0, sz)), centre)
	var parts: Array = [[id, xf]]
	if h > top:
		parts.append(_box(Vector3(span.x, h - top, span.z), centre + Vector3(0, (h + top) / 2.0, 0), CORE))
	var across := Vector2i(0, 1) if along_x else Vector2i(1, 0)
	for c: Vector2i in cells:
		for dir: Vector2i in [across, -across]:
			if (c + dir) in cells:
				continue
			var nv := Vector3(dir.x, 0, dir.y)
			parts.append(["kit_castle_wall_top_a", BuildingKit.face_xf(Vector3(c.x + 0.5, h, c.y + 0.5) + nv * 0.5, atan2(nv.x, nv.z))])
	_finish(b, parts, [])


## A round tower from the catalog: {at: [x, z] (squares), r, h, from (its foot's height: above 0 a turret rising out
## of the keep, below 0 a tower rising out of the drop beside the roofs), spire ("cone", "needle" or "none")}.
static func _tower(board: ArenaBoard, t: Dictionary, group: int) -> void:
	var at := t.get("at", [0, 0]) as Array
	var p := Vector3(float(at[0]), 0, float(at[1]))
	var r := float(t.get("r", 1.0))
	var h := float(t.get("h", 9.0))
	var from := float(t.get("from", 0.0))
	var spire := str(t.get("spire", "cone"))
	var spire_id := "kit_castle_spire_needle" if spire == "needle" else ("" if spire in ["", "none"] else "kit_castle_spire")
	var spire_h := float((BuildingKit.manifest().get(spire_id, {}) as Dictionary).get("height", 0.0)) * r if spire_id != "" else 0.0
	var cells: Array = []
	for z in range(floori(p.z - r), ceili(p.z + r)):
		for x in range(floori(p.x - r), ceili(p.x + r)):
			var c := Vector2i(x, z)
			if board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL) and not board.house_cells.has(c):
				cells.append(c)
	var b := _piece(board, "CastleTower", cells, group, h, AABB(p - Vector3(r * 1.4, 0, r * 1.4) + Vector3(0, from, 0),
		Vector3(r * 2.8, h - from + 1.3 + spire_h, r * 2.8)))
	var sc := Basis.from_scale(Vector3(r, 1.0, r))
	var foot := 1.23
	var parts: Array = []
	var stub: Array = []
	if from <= 0.0:
		# Its battered foot on the ground, or far down in the drop off the castle's roofs.
		parts.append(["kit_castle_tower_foot", Transform3D(sc, p + Vector3(0, from, 0))])
		stub.append(["kit_castle_tower_foot", Transform3D(sc, p + Vector3(0, from, 0))])
	var shaft_from := from + foot if from <= 0.0 else from
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h - shaft_from
	cyl.radial_segments = 24
	cyl.rings = 1
	parts.append([cyl, Transform3D(Basis(), p + Vector3(0, (h + shaft_from) / 2.0, 0)), CORE])
	parts.append(["kit_castle_tower_top", Transform3D(sc, p + Vector3(0, h, 0))])
	# Crossbow loops up the shaft, turned to the outside.
	var n := int((h - shaft_from) / 2.4)
	for i in n:
		var a := float(ModelPiece.hash_cell(Vector2i(int(p.x * 10.0), int(p.z * 10.0) + i)) % 628) / 100.0
		var out := Vector3(sin(a), 0, cos(a))
		parts.append(["kit_castle_slit", BuildingKit.face_xf(p + out * r + Vector3(0, shaft_from + 1.2 + i * 2.4, 0), a)])
	if from <= 0.0:
		var cap := CylinderMesh.new()
		cap.top_radius = r * 1.05
		cap.bottom_radius = r * 1.05
		cap.height = 0.08
		stub.append([cap, Transform3D(Basis(), p + Vector3(0, CUT + 0.04, 0)), COPING])
	_finish(b, parts, stub)
	if spire_id != "":
		var mi := BuildingKit.merge([[spire_id, Transform3D(Basis.from_scale(Vector3(r, r, r)), p + Vector3(0, h + 0.55, 0))]])
		if mi != null:
			mi.name = "Spire"
			(b["upper"] as Node3D).add_child(mi)


## The chasm: each edge where the land meets the void gets cliffs falling DEEP below it, facing into the void; a
## bridge (catalog `bridges`) spans it on its timbers instead. On the castle's roofs (catalog `cliffs` false) the void
## is the drop off the roof: the castle's masonry goes on down under every square beside it, `below` deep.
static func _chasm(board: ArenaBoard, cfg: Dictionary) -> void:
	if not bool(cfg.get("cliffs", true)):
		_drop(board, float(cfg.get("below", 12.0)))
		return
	var g := board.grid
	var bridges: Array[Rect2i] = []
	for r: Variant in cfg.get("bridges", []):
		bridges.append(_rect(r, Rect2i()))
	var parts: Array = []
	var ids := ["kit_cliff_a", "kit_cliff_b", "kit_cliff_c"]
	for z in g.depth:
		for x in g.width:
			var v := Vector2i(x, z)
			if not g.has_flag(v, CombatGrid.VOID):
				continue
			for d in SetDressing.FACES:
				var n := v - d   # the land, the void lying d from it
				if not g.in_bounds(n) or g.has_flag(n, CombatGrid.VOID):
					continue
				var bridged := false
				for r in bridges:
					bridged = bridged or r.has_point(n)
				if bridged:
					continue
				var nv := Vector3(d.x, 0, d.y)
				var base := Vector3(n.x + 0.5, 0, n.y + 0.5) + nv * 0.5
				var k := 0
				while k * CLIFF < DEEP:
					var pick := ModelPiece.hash_cell(n * 11 + d * 3 + Vector2i(k, k * 7))
					var yaw := atan2(nv.x, nv.z) + (float(pick % 9) - 4.0) * 0.02
					var out := nv * (0.04 * float(k))   # the face leans out a little as it falls
					parts.append([ids[pick % ids.size()], Transform3D(Basis(Vector3.UP, yaw), base + out + Vector3(0, -0.12 - k * CLIFF, 0))])
					k += 1
	for r in bridges:
		_bridge_timbers(r, parts)
	if parts.is_empty():
		return
	var mi := BuildingKit.merge(parts)
	if mi != null:
		mi.name = "Chasm"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.add_child(mi)


static func _drop(board: ArenaBoard, below: float) -> void:
	var g := board.grid
	var parts: Array = []
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if g.has_flag(c, CombatGrid.VOID):
				continue
			for d in SetDressing.FACES:
				var n := c + d
				if g.in_bounds(n) and g.has_flag(n, CombatGrid.VOID):
					parts.append(_box(Vector3(1, below, 1), Vector3(x + 0.5, -0.2 - below / 2.0, z + 0.5), CORE))
					break
	var mi := BuildingKit.merge(parts)
	if mi != null:
		mi.name = "Chasm"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.add_child(mi)


## Under a drawbridge: two great beams along it and cross-timbers, iron-strapped, so it spans the chasm.
static func _bridge_timbers(r: Rect2i, parts: Array) -> void:
	var along_z := r.size.y >= r.size.x
	var length := float(r.size.y if along_z else r.size.x)
	var width := float(r.size.x if along_z else r.size.y)
	var centre := Vector3(r.position.x + r.size.x / 2.0, 0, r.position.y + r.size.y / 2.0)
	for s: float in [-0.3, 0.3]:
		var off := Vector3(s * width, 0, 0) if along_z else Vector3(0, 0, s * width)
		var size := Vector3(0.36, 0.5, length + 0.6) if along_z else Vector3(length + 0.6, 0.5, 0.36)
		parts.append(_box(size, centre + off + Vector3(0, -0.47, 0), "kit/oak"))
	var k := 0.5
	while k < length:
		var at := Vector3(r.position.x + r.size.x / 2.0, -0.3, r.position.y + k) if along_z else Vector3(r.position.x + k, -0.3, r.position.y + r.size.y / 2.0)
		parts.append(_box(Vector3(width, 0.18, 0.24) if along_z else Vector3(0.24, 0.18, width), at, "kit/oak"))
		k += 1.0


## Each frame (TownBuilder.cut_away): a castle piece in the way of the party, or of the squares beside and just past
## it, squashes down to its foot; it stands again when it's clear.
static func cut(b: Dictionary, camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	if bool(b["low"]):
		return
	var aabb := b["aabb"] as AABB
	var view := Vector3(focus.x - camera_pos.x, 0, focus.z - camera_pos.z)
	if view.length() < 0.01:
		return
	view = view.normalized()
	var side := Vector3(-view.z, 0, view.x)
	var hides := false
	for off: Vector3 in [Vector3.ZERO, side * LOOK_SIDE, -side * LOOK_SIDE, view * LOOK_PAST]:
		var target := focus + off + Vector3(0, 0.8, 0)
		if aabb.intersects_segment(camera_pos, target) != null and not aabb.has_point(target):
			hides = true
			break
	var h := float(b["height"])
	var goal := CUT / h if hides else 1.0
	var walls := b["walls"] as Node3D
	var s := move_toward(walls.scale.y, goal, delta * 4.0)
	if not is_equal_approx(s, walls.scale.y):
		walls.scale.y = s
	var low := hides and is_equal_approx(s, goal)
	var stub := b["stub"] as Node3D
	if walls.visible == low:
		walls.visible = not low
		stub.visible = low
	if hides != bool(b["cut"]):
		b["cut"] = hides
		(b["upper"] as Node3D).visible = not hides
		for e: Variant in b["extras"]:
			if is_instance_valid(e):
				(e as Node3D).visible = not hides


## On a castle place whose walls the board builds as an interior's (the roofs among the spires, a dungeon theme): the
## castle takes wall square `c` (BuildingKit.interior_wall asks), planning the whole castle the first time.
static func claims(board: ArenaBoard, c: Vector2i) -> bool:
	if not board.has_meta("castle_tried"):
		board.set_meta("castle_tried", true)
		if not board.has_meta("castle"):
			plan(board)
	return board.has_meta("castle") and board.house_cells.has(c)


## A door hung in a passage through the castle's walls stands in its arch, with no frame of its own.
static func frames(board: ArenaBoard, c: Vector2i) -> bool:
	if not board.has_meta("castle"):
		return false
	return ((board.get_meta("castle") as Dictionary)["gates"] as Dictionary).has(c)
