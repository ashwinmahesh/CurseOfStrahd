class_name TownBuilder
extends RefCounted
## The buildings of a town board (the Village of Barovia, Vallaki), from the same '#' squares the rules see
## (docs/art/set_dressing.md). Solid blocks of wall (every square in some 2 x 2 of wall) become houses, put together
## from the building kit (BuildingKit, docs/art/building_kit.md) in the town's style: Barovian timber framing over
## plaster under deep thatch, Vallaki's painted clapboard, Krezk's coursed stone; each face of a house is a module
## (braced timbers, a casement with its shutters, a door bay where a door hangs), with corner posts or quoins, a stone
## footing, a roof with eaves and gables, and a chimney. Lines of wall one square thick are low stone yard walls. A
## building standing between the camera and the party is cut away: its roof and everything on its walls hide and the
## walls drop to a low band, like the cut-away interiors.

const HOUSE_H := 2.2
const YARD_WALL_H := 1.0
const EAVE := 0.18          ## how far a roof overhangs the walls
const CUT_H := 0.5          ## a cut-away building's wall height
const STONE := "church/stone_wall"
const STUB_WALL := 0.22      ## a cut-away kit house's walls, how thick
const STUB_FLOOR := "interior/wood_planks"


## Splits the board's inner walls into houses and yard walls, and builds the houses. Returns the yard-wall squares
## (built square by square in ArenaBoard._wall so props can take their place).
static func plan(board: ArenaBoard) -> Dictionary:
	var walls := {}
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if board.grid.has_flag(c, CombatGrid.WALL) and not _border(board, c):
				walls[c] = true
	var block := {}
	for c: Vector2i in walls:
		for o: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			var a := c + o
			if walls.has(a) and walls.has(a + Vector2i(1, 0)) and walls.has(a + Vector2i(0, 1)) and walls.has(a + Vector2i(1, 1)):
				block[c] = true
				break
	var lines := {}
	for c: Vector2i in walls:
		if not block.has(c):
			lines[c] = true
	# Which block of wall each square belongs to (an L-shaped block is split into several houses below).
	var group := {}
	var groups := 0
	for c: Vector2i in block:
		if group.has(c):
			continue
		var open: Array[Vector2i] = [c]
		group[c] = groups
		while not open.is_empty():
			var at: Vector2i = open.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if block.has(at + d) and not group.has(at + d):
					group[at + d] = groups
					open.append(at + d)
		groups += 1
	var taken := {}
	var cells: Array = block.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in cells:
		if taken.has(c):
			continue
		# The largest rectangle growing right, then down, from the first free square.
		var w := 1
		while block.has(c + Vector2i(w, 0)) and not taken.has(c + Vector2i(w, 0)):
			w += 1
		var d := 1
		while true:
			var row_ok := true
			for i in w:
				var n := c + Vector2i(i, d)
				if not block.has(n) or taken.has(n):
					row_ok = false
					break
			if not row_ok:
				break
			d += 1
		for i in w:
			for j in d:
				taken[c + Vector2i(i, j)] = true
		_house(board, Rect2i(c, Vector2i(w, d)), int(group[c]))
	return lines


static func _border(board: ArenaBoard, c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == board.grid.width - 1 or c.y == board.grid.depth - 1


## A low stone yard wall on one square: a post in the middle and an arm toward each neighbouring wall.
static func yard_wall(board: ArenaBoard, c: Vector2i, stone: Material) -> void:
	var base := Vector3(c.x + 0.5, 0, c.y + 0.5)
	# A walled town's wall is tall (catalog "town_walls": Krezk); elsewhere a yard wall is waist high.
	var h := float((SetDressing.catalog().get("town_walls", {}) as Dictionary).get(board.place, YARD_WALL_H))
	if _kit_yard(board, c, h):
		return
	board.add_box("YardWall", Vector3(0.5, h, 0.5), base + Vector3(0, h / 2.0, 0), stone)
	board.add_box("YardCap", Vector3(0.6, 0.1, 0.6), base + Vector3(0, h + 0.05, 0), Look.cel("stone_deep"))
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if not board.grid.in_bounds(n) or not (board.grid.has_flag(n, CombatGrid.WALL) or board.door_cells.has(n)):
			continue
		# Same material and height as the post, so where they overlap nothing shows.
		var off := Vector3(d.x * 0.25, 0, d.y * 0.25)
		board.add_box("YardWall", Vector3(0.5, h, 0.5), base + off + Vector3(0, h / 2.0, 0), stone)
		board.add_box("YardCap", Vector3(0.6, 0.1, 0.6), base + off + Vector3(0, h + 0.05, 0), Look.cel("stone_deep"))


## A yard wall square from the kit: an arm of coursed stone from the middle toward each neighbouring wall or door, and
## a capped pier where the wall turns, ends or branches (a straight run is one continuous wall). A town wall (Krezk's)
## is the taller wall with merlons. One mesh per square, so a prop that takes the square hides it.
static func _kit_yard(board: ArenaBoard, c: Vector2i, h: float) -> bool:
	var style := BuildingKit.style_for(board)
	if style == "":
		return false
	var tall := h > 1.6
	var arm := "kit_town_wall_arm" if tall else BuildingKit.wall_id(style, "yard_arm")
	var pier := "kit_town_wall_pier" if tall else BuildingKit.wall_id(style, "yard_pier")
	if not BuildingKit.has(arm) or not BuildingKit.has(pier):
		return false
	var s := h / float((BuildingKit.manifest()[arm] as Dictionary).get("height", 1.0))
	var base := Vector3(c.x + 0.5, board.floor_y(c), c.y + 0.5)
	var gates := _gates(board)
	var dirs: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if board.grid.in_bounds(n) and (board.grid.has_flag(n, CombatGrid.WALL) or gates.has(n)):
			dirs.append(d)
	var stretch := Basis.from_scale(Vector3(1.0, s, 1.0))
	var parts: Array = []
	for d in dirs:
		parts.append([arm, Transform3D(Basis(Vector3.UP, atan2(-float(d.y), float(d.x))) * stretch, base)])
	if not (dirs.size() == 2 and dirs[0] == -dirs[1]):
		parts.append([pier, Transform3D(stretch, base)])
	var half := float(((BuildingKit.manifest()[pier] as Dictionary).get("size", [0.66, 1, 0.66]) as Array)[0]) / 2.0
	for d in dirs:
		if gates.has(c + d):
			# A gate pier at the end of the wall, its face on the gateway.
			parts.append([pier, Transform3D(stretch, base + Vector3(d.x, 0, d.y) * (0.5 - half))])
	var mi := BuildingKit.merge(parts)
	if mi == null:
		return false
	mi.name = "YardWall"
	board.add_child(mi)
	return true


## The squares of the location's doors (its gates), known before SetDressing hangs them.
static func _gates(board: ArenaBoard) -> Dictionary:
	if board.has_meta("kit_gates"):
		return board.get_meta("kit_gates") as Dictionary
	var out := {}
	if board.place != "" and Compendium.shared().has("locations", board.place):
		for t: Variant in Compendium.shared().get_entry("locations", board.place).get("doors", []):
			var cell := (t as Dictionary).get("cell", []) as Array
			if cell.size() == 2:
				out[Vector2i(int(cell[0]), int(cell[1]))] = true
	board.set_meta("kit_gates", out)
	return out


## A town's palisade on border square `c` (ArenaBoard asks for it): ground under it and sharpened logs along the
## border (both ways on a corner). The logs of the whole border are one mesh, made once the last square asks.
## False when the kit has no palisade.
static func palisade(board: ArenaBoard, c: Vector2i, ground: Material) -> bool:
	if not BuildingKit.has("kit_palisade") or BuildingKit.style_for(board) == "":
		return false
	board.add_box("Ground", Vector3(1, 0.2, 1), Vector3(c.x + 0.5, -0.1, c.y + 0.5), ground)
	if not board.has_meta("palisade_parts"):
		var count := 0
		for z in board.grid.depth:
			for x in board.grid.width:
				var b := Vector2i(x, z)
				if _border(board, b) and board.grid.has_flag(b, CombatGrid.WALL):
					count += 1
		board.set_meta("palisade_parts", [])
		board.set_meta("palisade_left", count)
		_flush_palisade.bind(board).call_deferred()   # in case a border square was drawn some other way (rock)
	var parts := board.get_meta("palisade_parts") as Array
	var at := Vector3(c.x + 0.5, 0, c.y + 0.5)
	var w := board.grid.width
	var d := board.grid.depth
	# The module's rails (its -z) face into the town.
	if c.y == 0 or c.y == d - 1:
		parts.append(["kit_palisade", Transform3D(Basis(Vector3.UP, PI if c.y == 0 else 0.0), at)])
	if c.x == 0 or c.x == w - 1:
		parts.append(["kit_palisade", Transform3D(Basis(Vector3.UP, -PI / 2.0 if c.x == 0 else PI / 2.0), at)])
	var left := int(board.get_meta("palisade_left")) - 1
	board.set_meta("palisade_left", left)
	if left <= 0:
		_flush_palisade(board)
	return true


static func _flush_palisade(board: ArenaBoard) -> void:
	if not is_instance_valid(board) or not board.has_meta("palisade_parts"):
		return
	var mi := BuildingKit.merge(board.get_meta("palisade_parts") as Array)
	if mi != null:
		mi.name = "Palisade"
		board.add_child(mi)
	board.remove_meta("palisade_parts")

static func _house(board: ArenaBoard, r: Rect2i, group: int) -> void:
	var style := BuildingKit.style_for(board)
	if style != "":
		if _church_door(board, r) != Vector2i(-1, -1) and BuildingKit.has("kit_church_corner"):
			style = "church"   # the house with the church's doors is the church: stone, buttresses, a bell tower
		_house_kit(board, r, group, style)
		return
	var seed := absi(r.position.x * 73856093 ^ r.position.y * 19349663 ^ r.size.x * 83492791)
	var area := r.size.x * r.size.y
	var h := HOUSE_H + (0.4 if area >= 16 else 0.0) + float(seed % 3) * 0.15
	var root := Node3D.new()
	root.name = "Building"
	board.add_child(root)
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, h, r.size.y)
	walls.mesh = bm
	walls.position = Vector3(r.position.x + r.size.x / 2.0, h / 2.0, r.position.y + r.size.y / 2.0)
	walls.material_override = board.house_wall_material()
	root.add_child(walls)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	# A gable along the longer side; big houses get slate, small ones thatch (where the town has both).
	var along_x := r.size.x >= r.size.y
	var half := (r.size.y if along_x else r.size.x) / 2.0
	var rise := clampf(half * 0.62, 0.45, 2.0)
	var roof_mat := board.roof_material(area >= 30)
	upper.add_child(_gable(Vector2(r.position), Vector2(r.position + r.size), h - 0.02, rise, along_x, roof_mat,
		board.house_wall_material()))
	if seed % 3 != 2:
		var stone := Look.cel_textured(STONE)
		var t := 0.22 + float(seed % 5) * 0.12
		var at := Vector2(lerpf(r.position.x + 0.5, r.end.x - 0.5, t), r.position.y + r.size.y / 2.0) if along_x \
			else Vector2(r.position.x + r.size.x / 2.0, lerpf(r.position.y + 0.5, r.end.y - 0.5, t))
		var ch := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.38, rise + 0.7, 0.38)
		ch.mesh = cm
		ch.position = Vector3(at.x, h + (rise + 0.7) / 2.0, at.y)
		ch.material_override = stone if stone != null else Look.cel("stone")
		upper.add_child(ch)
	var idx := board.buildings.size()
	board.buildings.append({"root": root, "walls": walls, "upper": upper, "height": h, "extras": [],
		"aabb": AABB(Vector3(r.position.x - EAVE, 0, r.position.y - EAVE), Vector3(r.size.x + 2 * EAVE, h + rise + 0.2, r.size.y + 2 * EAVE)),
		"cut": false, "rect": r, "group": group})
	for i in r.size.x:
		for j in r.size.y:
			board.house_cells[r.position + Vector2i(i, j)] = idx
	_windows(board, r, upper, h, seed)


## Shuttered windows on the walls that face open ground, every few squares (one may show a light).
static func _windows(board: ArenaBoard, r: Rect2i, upper: Node3D, h: float, seed: int) -> void:
	var n := 0
	for i in r.size.x:
		for j in r.size.y:
			var c := r.position + Vector2i(i, j)
			for d in SetDressing.FACES:
				var out := c + d
				if r.has_point(out) or not board.grid.in_bounds(out) or board.grid.has_flag(out, CombatGrid.WALL):
					continue
				n += 1
				if (n + seed) % 3 != 0:
					continue
				var art := "window_lit" if (n * 7 + seed) % 5 == 0 else "window_shuttered"
				var nv := Vector3(d.x, 0, d.y)
				var sp: Node3D = ModelPiece.wall_model(board, art)   # 3D where there's a model (docs/art/models.md)
				if sp == null:
					sp = SetDressing.wall_sprite(art)
				if sp == null:
					return
				sp.position = Vector3(c.x + 0.5, minf(0.85, h - 1.0), c.y + 0.5) + nv * (0.5 + SetDressing.WALL_GAP)
				sp.rotation.y = atan2(nv.x, nv.z)
				upper.add_child(sp)
				board.windows["%d,%d,%d,%d" % [c.x, c.y, d.x, d.y]] = sp


# --- Houses from the building kit ----------------------------------------------------------------------------

## A house in `style` from the kit's modules. Every face of the house (one square's side) gets a lower and an upper
## module, picked by the square so the same house is always built the same way; windows go on faces over open ground
## as before (some lit, some shuttered); a door hung on a face later turns it into a door bay (face_taken). The walls
## and the roof are each merged into one mesh.
static func _house_kit(board: ArenaBoard, r: Rect2i, group: int, style: String) -> void:
	var seed := absi(r.position.x * 73856093 ^ r.position.y * 19349663 ^ r.size.x * 83492791)
	var area := r.size.x * r.size.y
	var h := HOUSE_H + (0.4 if area >= 16 else 0.0) + float(seed % 3) * 0.15
	var cfg := BuildingKit.settings()
	var roofs := (cfg.get("roofs", {}) as Dictionary).get(style, {}) as Dictionary
	var kind := str(roofs.get("grand", "slate")) if area >= int(cfg.get("grand_area", 30)) else str(roofs.get("small", "slate"))
	if BuildingKit.roof_id(style, kind, 2, false) == "":
		kind = "slate"
	var along_x := r.size.x >= r.size.y
	var span := r.size.y if along_x else r.size.x
	var rise := BuildingKit.rise(style, kind, span)
	var paints := cfg.get("paints", []) as Array
	var root := Node3D.new()
	root.name = "Building"
	board.add_child(root)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	var over := maxf(BuildingKit.constant("EAVE"), BuildingKit.constant("VERGE"))
	var b := {"root": root, "walls": null, "stub": null, "upper": upper, "height": h, "extras": [], "cut": false,
		"aabb": AABB(Vector3(r.position.x - over, 0, r.position.y - over), Vector3(r.size.x + 2 * over, h + rise + 0.5, r.size.y + 2 * over)),
		"rect": r, "group": group, "kit": style, "roof": kind, "rise": rise, "seed": seed,
		"paint": str(paints[seed % paints.size()]) if style == "clapboard" and not paints.is_empty() else "",
		"core": str((cfg.get("cores", {}) as Dictionary).get(style, "")), "faces": {}, "markers": []}
	var idx := board.buildings.size()
	board.buildings.append(b)
	for i in r.size.x:
		for j in r.size.y:
			board.house_cells[r.position + Vector2i(i, j)] = idx
	# Each face: its modules, picked by its square; windows on every third face over open ground.
	var lows := _variants(style, "low_")
	var ups := _variants(style, "up_")
	var faces := {}
	var n := 0
	for i in r.size.x:
		for j in r.size.y:
			var c := r.position + Vector2i(i, j)
			for d in SetDressing.FACES:
				var out := c + d
				if r.has_point(out):
					continue
				var pick := ModelPiece.hash_cell(c * 3 + d)
				var face := {"cell": c, "dir": d, "low": lows[pick % lows.size()], "up": ups[int(pick / 7.0) % ups.size()],
					"window": "", "door": ""}
				if board.grid.in_bounds(out) and not board.grid.has_flag(out, CombatGrid.WALL):
					n += 1
					if (n + seed) % 3 == 0:
						face["up"] = "up_win"
						face["window"] = "window_lit" if (n * 7 + seed) % 5 == 0 else ("window_shut" if (n * 3 + seed) % 4 == 0 else "window")
				faces["%d,%d,%d,%d" % [c.x, c.y, d.x, d.y]] = face
	b["faces"] = faces
	_kit_walls(board, idx)
	_kit_roof(board, b, along_x, span, seed)


## The square of a church's doors (an exit named for the church) on the house `r`, or (-1, -1).
static func _church_door(board: ArenaBoard, r: Rect2i) -> Vector2i:
	if board.place == "" or not Compendium.shared().has("locations", board.place):
		return Vector2i(-1, -1)
	for t: Variant in Compendium.shared().get_entry("locations", board.place).get("exits", []):
		var e := t as Dictionary
		var cell := e.get("cell", []) as Array
		var words := ("%s %s" % [str(e.get("id", "")), str(e.get("label", ""))]).to_lower()
		if cell.size() == 2 and words.contains("church") and r.has_point(Vector2i(int(cell[0]), int(cell[1]))):
			return Vector2i(int(cell[0]), int(cell[1]))
	return Vector2i(-1, -1)


## The lettered variants of a part the kit has for a style ("low_" -> ["low_a", "low_b" ...]).
static func _variants(style: String, part: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in ["a", "b", "c", "d"]:
		if BuildingKit.has(BuildingKit.wall_id(style, part + k)):
			out.append(part + k)
	if out.is_empty():
		out.append(part + "a")
	return out


## (Re)builds a kit house's walls from its faces: the core (plaster, boards or stone), each face's modules, the corner
## posts, and the low band a cut-away house shows (the core to CUT_H, the footing and a dark top), each one mesh.
static func _kit_walls(board: ArenaBoard, idx: int) -> void:
	var b := board.buildings[idx]
	for key: String in ["walls", "stub"]:
		if b[key] != null and is_instance_valid(b[key]):
			(b[key] as Node).free()
	for m: Variant in b["markers"]:
		if is_instance_valid(m):
			(m as Node).free()
	(b["markers"] as Array).clear()
	var r := b["rect"] as Rect2i
	var h := float(b["height"])
	var style := str(b["kit"])
	var root := b["root"] as Node3D
	var upper := b["upper"] as Node3D
	var core_name := str(b["core"]) if str(b["core"]) != "" else "pal_ink"
	var KH := BuildingKit.constant("H")
	var low_top := BuildingKit.constant("LOW_TOP")
	var foot := BuildingKit.constant("FOOT")
	var s_up := (h - low_top) / (KH - low_top)
	var s_door := (h - 2.04) / (KH - 2.04)
	var centre := Vector3(r.position.x + r.size.x / 2.0, 0, r.position.y + r.size.y / 2.0)
	var core := BoxMesh.new()
	core.size = Vector3(r.size.x, h, r.size.y)
	var parts: Array = [[core, Transform3D(Basis(), centre + Vector3(0, h / 2.0, 0)), core_name]]
	# Cut away, a house is its walls' foot round a floor of boards: a ring of core CUT_H high, capped dark like the
	# cut-away interiors' walls.
	var stub: Array = []
	var t := STUB_WALL
	for side: Array in [[Vector3(r.size.x, CUT_H, t), Vector3(0, 0, (r.size.y - t) / 2.0)],
			[Vector3(r.size.x, CUT_H, t), Vector3(0, 0, -(r.size.y - t) / 2.0)],
			[Vector3(t, CUT_H, r.size.y - 2 * t), Vector3((r.size.x - t) / 2.0, 0, 0)],
			[Vector3(t, CUT_H, r.size.y - 2 * t), Vector3(-(r.size.x - t) / 2.0, 0, 0)]]:
		var size := side[0] as Vector3
		var wall_box := BoxMesh.new()
		wall_box.size = size
		stub.append([wall_box, Transform3D(Basis(), centre + (side[1] as Vector3) + Vector3(0, CUT_H / 2.0, 0)), core_name])
		var cap := BoxMesh.new()
		cap.size = size + Vector3(0.03, 0.06 - CUT_H, 0.03)
		stub.append([cap, Transform3D(Basis(), centre + (side[1] as Vector3) + Vector3(0, CUT_H + 0.03, 0)), "pal_" + ArenaBoard.CUT_FACE])
	var boards := BoxMesh.new()
	boards.size = Vector3(r.size.x - 2 * t, 0.04, r.size.y - 2 * t)
	stub.append([boards, Transform3D(Basis(), centre + Vector3(0, 0.02, 0)), STUB_FLOOR])
	var faces := b["faces"] as Dictionary
	for key: String in faces:
		var face := faces[key] as Dictionary
		var c := face["cell"] as Vector2i
		var d := face["dir"] as Vector2i
		var nv := Vector3(d.x, 0, d.y)
		var base := Vector3(c.x + 0.5, 0, c.y + 0.5) + nv * 0.5
		var yaw := atan2(nv.x, nv.z)
		if str(face["door"]) != "":
			# A door bay round a leaf; a door with its own stone case (church doors) only needs the footing.
			parts.append([BuildingKit.wall_id(style, "door" if face["door"] == "bay" else "foot"), BuildingKit.face_xf(base, yaw)])
			parts.append([BuildingKit.wall_id(style, "door_top"), BuildingKit.face_xf(base, yaw, s_door, 2.04)])
		else:
			parts.append([BuildingKit.wall_id(style, str(face["low"])), BuildingKit.face_xf(base, yaw)])
			parts.append([BuildingKit.wall_id(style, str(face["up"])), BuildingKit.face_xf(base, yaw, s_up, low_top)])
		stub.append([BuildingKit.wall_id(style, "foot"), BuildingKit.face_xf(base, yaw)])
		var win := str(face["window"])
		if win != "" and str(face["door"]) == "":
			var wid := BuildingKit.wall_id(style, win)
			parts.append([wid, BuildingKit.face_xf(base, yaw)])
			# Where the glass is, for the lights that spill from lit windows after dark (meta "lit").
			var glass := ((BuildingKit.manifest().get(wid, {}) as Dictionary).get("sockets", {}) as Dictionary).get("glass", [0, 1.5, 0]) as Array
			var mark := Marker3D.new()
			mark.name = "Window"
			mark.position = base + Vector3(0, float(glass[1]), 0) + nv * 0.04
			mark.rotation.y = yaw
			mark.set_meta("lit", win == "window_lit")
			upper.add_child(mark)
			(b["markers"] as Array).append(mark)
			board.windows[key] = mark
	# Corner posts (or quoins, or corner boards): the house is +x, +z of a corner turned 0 (its south-west).
	var s_corner := (h - foot) / (KH - foot)
	for corner: Array in [[Vector3(r.position.x, 0, r.end.y), 0.0], [Vector3(r.end.x, 0, r.end.y), PI / 2.0],
			[Vector3(r.end.x, 0, r.position.y), PI], [Vector3(r.position.x, 0, r.position.y), -PI / 2.0]]:
		parts.append([BuildingKit.wall_id(style, "corner"), BuildingKit.face_xf(corner[0] as Vector3, float(corner[1]), s_corner, foot)])
		stub.append([BuildingKit.wall_id(style, "corner"), BuildingKit.face_xf(corner[0] as Vector3, float(corner[1]),
			(CUT_H + 0.06) / KH)])
	var walls := BuildingKit.merge(parts, str(b["paint"]))
	walls.name = "Walls"
	root.add_child(walls)
	root.move_child(walls, 0)
	var low := BuildingKit.merge(stub, str(b["paint"]))
	low.name = "Stub"
	root.add_child(low)
	var cut := bool(b["cut"])
	walls.visible = not cut
	low.visible = cut
	if cut:
		walls.scale.y = CUT_H / h
	b["walls"] = walls
	b["stub"] = low


## A kit house's roof: one module per square along the ridge, the ends that close it over each gable, the framing of
## each gable's triangle, and a chimney (its stack a box, which the chimney smoke finds, its cap a module).
static func _kit_roof(board: ArenaBoard, b: Dictionary, along_x: bool, span: int, seed: int) -> void:
	var r := b["rect"] as Rect2i
	var h := float(b["height"])
	var style := str(b["kit"])
	var kind := str(b["roof"])
	var rise := float(b["rise"])
	var upper := b["upper"] as Node3D
	var core_name := str(b["core"]) if str(b["core"]) != "" else "pal_ink"
	var length := r.size.x if along_x else r.size.y
	var cx := r.position.x + r.size.x / 2.0
	var cz := r.position.y + r.size.y / 2.0
	var slice := BuildingKit.roof_id(style, kind, span, false)
	var parts: Array = []
	if slice == "":
		# Wider than the kit's roofs: the plain gabled roof.
		upper.add_child(_gable(Vector2(r.position), Vector2(r.position + r.size), h - 0.02, rise, along_x,
			board.roof_material(kind == "slate"), BuildingKit.material(core_name)))
	else:
		for i in length:
			var at := Vector3(r.position.x + i + 0.5, h, cz) if along_x else Vector3(cx, h, r.position.y + i + 0.5)
			parts.append([slice, Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI / 2.0), at)])
		var end := BuildingKit.roof_id(style, kind, span, true)
		var gable := "kit_%s_gable_w%d" % [style, span]
		# [where the gable is, the roof end's heading (its +x outward), the gable framing's heading (facing out)]
		var gables: Array = [[Vector3(r.end.x, h, cz), 0.0, PI / 2.0], [Vector3(r.position.x, h, cz), PI, -PI / 2.0]] if along_x \
			else [[Vector3(cx, h, r.end.y), -PI / 2.0, 0.0], [Vector3(cx, h, r.position.y), PI / 2.0, PI]]
		for g: Array in gables:
			if end != "":
				parts.append([end, Transform3D(Basis(Vector3.UP, float(g[1])), g[0] as Vector3)])
			if BuildingKit.has(gable):
				parts.append([gable, Transform3D(Basis(Vector3.UP, float(g[2])), g[0] as Vector3)])
		parts.append([_gable_ends(r, h, rise, along_x), Transform3D.IDENTITY, core_name])
		if style == "church" and BuildingKit.has("kit_church_tower"):
			# The bell tower rises from the roof at the end with the church's doors.
			var door := _church_door(board, r)
			var west := door.x - r.position.x < r.end.x - door.x
			var north := door.y - r.position.y < r.end.y - door.y
			var tower := Vector3(r.position.x + 0.95 if west else r.end.x - 0.95, h, cz) if along_x \
				else Vector3(cx, h, r.position.y + 0.95 if north else r.end.y - 0.95)
			parts.append(["kit_church_tower", Transform3D(Basis(), tower)])
			var aabb := b["aabb"] as AABB
			aabb.size.y = maxf(aabb.size.y, h + float(((BuildingKit.manifest()["kit_church_tower"] as Dictionary).get("size", [1, 7, 1]) as Array)[1]))
			b["aabb"] = aabb
	if seed % 3 != 2:
		var stone := Look.cel_textured(STONE)
		var t := 0.22 + float(seed % 5) * 0.12
		var at := Vector2(lerpf(r.position.x + 0.5, r.end.x - 0.5, t), cz) if along_x \
			else Vector2(cx, lerpf(r.position.y + 0.5, r.end.y - 0.5, t))
		var ch := MeshInstance3D.new()
		ch.name = "Chimney"
		var cm := BoxMesh.new()
		cm.size = Vector3(0.38, rise + 0.7, 0.38)
		ch.mesh = cm
		ch.position = Vector3(at.x, h + (rise + 0.7) / 2.0, at.y)
		ch.material_override = stone if stone != null else Look.cel("stone")
		upper.add_child(ch)
		parts.append(["kit_chimney_cap", Transform3D(Basis(), Vector3(at.x, h + rise + 0.7, at.y))])
	if not parts.is_empty():
		var roof := BuildingKit.merge(parts, str(b["paint"]))
		roof.name = "Roof"
		upper.add_child(roof)


## The triangles of wall under each end of a gabled roof, in the house's core material.
static func _gable_ends(r: Rect2i, h: float, rise: float, along_x: bool) -> ArrayMesh:
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector2(r.position)
	var b := Vector2(r.end)
	var top := h + rise
	if along_x:
		var zc := (a.y + b.y) / 2.0
		_tri(gs, Vector3(a.x, h, a.y), Vector3(a.x, h, b.y), Vector3(a.x, top, zc), Vector3(-1, 0, 0))
		_tri(gs, Vector3(b.x, h, a.y), Vector3(b.x, h, b.y), Vector3(b.x, top, zc), Vector3(1, 0, 0))
	else:
		var xc := (a.x + b.x) / 2.0
		_tri(gs, Vector3(a.x, h, a.y), Vector3(b.x, h, a.y), Vector3(xc, top, a.y), Vector3(0, 0, -1))
		_tri(gs, Vector3(a.x, h, b.y), Vector3(b.x, h, b.y), Vector3(xc, top, b.y), Vector3(0, 0, 1))
	return gs.commit()


## Something has been hung on a house's face (SetDressing._hang): its window goes, and a door turns the face into a
## door bay, its leaf sized to the opening. `holder` is the hung piece (a 3D leaf's holder, or a 2D sprite).
static func face_taken(board: ArenaBoard, wall: Vector2i, normal: Vector2i, holder: Node3D, art: String) -> void:
	var key := "%d,%d,%d,%d" % [wall.x, wall.y, normal.x, normal.y]
	if not board.house_cells.has(wall):
		return
	var b := board.buildings[int(board.house_cells[wall])]
	var faces := b.get("faces", {}) as Dictionary
	if not faces.has(key):
		var window := board.windows.get(key, null) as Node3D
		if window != null and is_instance_valid(window):
			window.visible = false   # a box house's window sprite
		return
	var face := faces[key] as Dictionary
	var door := art.contains("door") or art.contains("gate")
	if str(face["window"]) == "" and not door:
		return
	face["window"] = ""
	board.windows.erase(key)
	if door:
		face["door"] = "bay"
		var info := ModelPiece.manifest().get(str(holder.get_meta("model", "")), {}) as Dictionary if holder != null else {}
		if str(info.get("mount", "door")) != "door":
			face["door"] = "facade"   # church doors, a manor's door case: they bring their own stonework
		elif holder != null and holder.has_meta("model") and holder.get_child_count() > 0:
			var size := info.get("size", [0.86, 1.15, 0.1]) as Array
			(holder.get_child(0) as Node3D).scale = Vector3(0.8 / float(size[0]), 1.9 / float(size[1]), 1.0)
	_kit_walls(board, int(board.house_cells[wall]))


## A gabled roof over the rectangle [a, b] (world x, z), its eaves at `eave`, the ridge `rise` above them, with
## gable ends in the wall material. Flat-shaded; texture comes from world position (cel_world.gdshader).
static func _gable(a: Vector2, b: Vector2, eave: float, rise: float, along_x: bool, roof: Material, gable: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := EAVE
	var top := eave + rise
	if along_x:
		var zc := (a.y + b.y) / 2.0
		var half := (b.y - a.y) / 2.0 + o
		var drop := o * rise / ((b.y - a.y) / 2.0)
		var lo := eave - drop
		var n_n := Vector3(0, half, -rise).normalized()
		var n_s := Vector3(0, half, rise).normalized()
		_quad(st, Vector3(a.x - o, lo, a.y - o), Vector3(b.x + o, lo, a.y - o), Vector3(b.x + o, top, zc), Vector3(a.x - o, top, zc), n_n)
		_quad(st, Vector3(a.x - o, lo, b.y + o), Vector3(b.x + o, lo, b.y + o), Vector3(b.x + o, top, zc), Vector3(a.x - o, top, zc), n_s)
	else:
		var xc := (a.x + b.x) / 2.0
		var half := (b.x - a.x) / 2.0 + o
		var drop := o * rise / ((b.x - a.x) / 2.0)
		var lo := eave - drop
		var n_w := Vector3(-rise, half, 0).normalized()
		var n_e := Vector3(rise, half, 0).normalized()
		_quad(st, Vector3(a.x - o, lo, a.y - o), Vector3(a.x - o, lo, b.y + o), Vector3(xc, top, b.y + o), Vector3(xc, top, a.y - o), n_w)
		_quad(st, Vector3(b.x + o, lo, a.y - o), Vector3(b.x + o, lo, b.y + o), Vector3(xc, top, b.y + o), Vector3(xc, top, a.y - o), n_e)
	var roof_mesh := st.commit()
	# The gable ends: triangles in the wall plane under the roof.
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	if along_x:
		var zc := (a.y + b.y) / 2.0
		_tri(gs, Vector3(a.x, eave, a.y), Vector3(a.x, eave, b.y), Vector3(a.x, top - 0.02, zc), Vector3(-1, 0, 0))
		_tri(gs, Vector3(b.x, eave, a.y), Vector3(b.x, eave, b.y), Vector3(b.x, top - 0.02, zc), Vector3(1, 0, 0))
	else:
		var xc := (a.x + b.x) / 2.0
		_tri(gs, Vector3(a.x, eave, a.y), Vector3(b.x, eave, a.y), Vector3(xc, top - 0.02, a.y), Vector3(0, 0, -1))
		_tri(gs, Vector3(a.x, eave, b.y), Vector3(b.x, eave, b.y), Vector3(xc, top - 0.02, b.y), Vector3(0, 0, 1))
	gs.commit(roof_mesh)
	roof_mesh.surface_set_material(0, roof)
	roof_mesh.surface_set_material(1, gable)
	var mi := MeshInstance3D.new()
	mi.name = "Roof"
	mi.mesh = roof_mesh
	return mi


static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	_tri(st, p0, p1, p2, n)
	_tri(st, p0, p2, p3, n)


## One triangle facing `n`: Godot draws clockwise triangles (seen from the front), so the winding is set from n.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


## Cuts away the buildings that hide `focus` (the party's leader) from the camera, and restores the others.
static func cut_away(board: ArenaBoard, camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	var target := focus + Vector3(0, 0.8, 0)
	for b: Dictionary in board.buildings:
		if bool(b.get("hidden", false)):
			continue
		if b.has("interior"):
			InteriorWalls.cut(b, camera_pos, focus, delta)   # an interior's full-height walls (W8)
			continue
		var aabb := b["aabb"] as AABB
		var hides: bool = aabb.intersects_segment(camera_pos, target) != null and not aabb.has_point(target)
		var h := float(b["height"])
		var goal := CUT_H / h if hides else 1.0
		if b.has("kit"):
			# The kit's walls squash down as they go, then the low band (footing and core) stands in their place.
			var kw := b["walls"] as Node3D
			var ks := move_toward(kw.scale.y, goal, delta * 4.0)
			if not is_equal_approx(ks, kw.scale.y):
				kw.scale.y = ks
			var low := hides and is_equal_approx(ks, goal)
			if kw.visible == low:
				kw.visible = not low
				(b["stub"] as Node3D).visible = low
		else:
			var walls := b["walls"] as MeshInstance3D
			var s := move_toward(walls.scale.y, goal, delta * 4.0)
			if not is_equal_approx(s, walls.scale.y):
				walls.scale.y = s
				walls.position.y = h * s / 2.0
		if hides != bool(b["cut"]):
			b["cut"] = hides
			(b["upper"] as Node3D).visible = not hides
			for e: Variant in b["extras"]:
				if is_instance_valid(e):
					(e as Node3D).visible = not hides
