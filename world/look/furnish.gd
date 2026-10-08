class_name Furnish
extends RefCounted
## Lived-in rooms (docs/art/interiors.md; owner, 2026-10-08: "really make it look like the place where she lives",
## then "we want this upgraded interior pattern ... rolled out to every other interior"): besides the things a
## location's data names, each room gets what a room of its kind holds, on wall faces nobody hangs anything on and on
## free squares along its walls. A kitchen gets herbs drying and jars on its walls and sacks, baskets and barrels by
## them; a bedroom paintings and a mirror over trunks and candles; a cell chains and bones. What goes where is in
## art/sprites/props/catalog.json "furnish", matched on words in the room's name like the room styles, else by the board
## theme; every pick comes from the square, so a place is furnished the same way every time.
##
## The location's own things come first: no piece goes on a wall square that holds one of them, on a square anything
## stands on, beside a door, an exit, a spawn or a person, or on difficult ground. Nothing here changes the rules grid.


## Furnishes `board`'s rooms (ArenaBoard calls it once its squares are dressed). Returns how many pieces it placed.
## Density (owner, 2026-10-08: "add more props, for that really lived in feeling"): a piece on most free wall faces
## (`wall_fill`), on most free squares along the walls (`floor_fill`, side by side allowed, never in a passage one
## square wide), now and then a low thing on the open floor (`centre_fill`: books, a bucket, a basket), a rug under the
## middle of a room whose rule names one (`rug`), and a little light from the lanterns and candles it puts out (`lit`,
## at most `lights_per_room`).
static func dress(board: ArenaBoard, loc: Dictionary) -> int:
	var cfg := SetDressing.catalog().get("furnish", {}) as Dictionary
	if cfg.is_empty() or bool(loc.get("furnish", true)) == false:
		return 0
	var keep_clear := _keep_clear(board, loc)
	var paths := _paths(board, loc)
	var placed := 0
	var lit := cfg.get("lit", []) as Array
	var lights := {}      # area index -> lights added
	var squares := {}     # area index -> its open squares (for the rug)
	# Each square belongs to the smallest area holding it (a room inside a hall is its own room).
	var areas := loc.get("areas", []) as Array
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if not _open(board, c):
				continue
			var ai := _area_of(areas, c)
			if not squares.has(ai):
				squares[ai] = [] as Array[Vector2i]
			(squares[ai] as Array[Vector2i]).append(c)
			if board.occupied.has(c) or keep_clear.has(c):
				continue
			var rule := _rule(cfg, board, areas[ai] as Dictionary if ai >= 0 else {})
			if rule.is_empty():
				continue
			var art := ""
			var hung := false
			# A wall piece: on the face of the wall beside this square that a piece hung from here takes (the first
			# wall in SetDressing.FACES order, as SetDressing._hang picks it). Not in a room's corner, where a piece
			# hung there would meet the one on the other wall.
			var wall_dir := Vector2i.ZERO
			var walls_beside := 0
			for d in SetDressing.FACES:
				if board.grid.in_bounds(c + d) and board.grid.has_flag(c + d, CombatGrid.WALL):
					walls_beside += 1
			for d in SetDressing.FACES:
				var w := c - d
				if board.grid.in_bounds(w) and board.grid.has_flag(w, CombatGrid.WALL):
					wall_dir = -d
					break
			if walls_beside == 1 and wall_dir != Vector2i.ZERO:
				var w := c + wall_dir
				var face := "%d,%d,%d,%d" % [w.x, w.y, -wall_dir.x, -wall_dir.y]
				var arts := _arts(rule.get("wall", []) as Array)
				var h := _hash(board.place, c, 11)
				if not keep_clear.has(w) and not board.used_faces.has(face) and not arts.is_empty() \
						and h % 100 < int(float(cfg.get("wall_fill", 0.75)) * 100.0):
					art = arts[(h / 7) % arts.size()]
					var root := SetDressing.place(board, {"id": "furnish_%d_%d_w" % [c.x, c.y], "cell": [c.x, c.y], "model": art})
					if root != null:
						root.set_meta("furnish", true)
						hung = true
						placed += 1
						_light(board, c, wall_dir, art, lit, lights, ai, cfg)
			if hung or board.grid.has_flag(c, CombatGrid.LOW) or board.grid.has_flag(c, CombatGrid.DIFFICULT):
				continue
			var key := "floor"
			var fill := float(cfg.get("floor_fill", 0.6))
			if not _beside_wall(board, c):
				key = "centre"
				fill = float(cfg.get("centre_fill", 0.08))
				if paths.has(c) or _furnished_around(board, c) >= 2:
					continue   # the ways between the doors stay clear, and the middle isn't packed solid
			elif _passage(board, c):
				continue   # a passage one square wide stays clear
			var hf := _hash(board.place, c, 5)
			var floor_arts := _arts(rule.get(key, []) as Array)
			if floor_arts.is_empty() or hf % 100 >= int(fill * 100.0):
				continue
			art = floor_arts[(hf / 13) % floor_arts.size()]
			var piece := SetDressing.place(board, {"id": "furnish_%d_%d" % [c.x, c.y], "cell": [c.x, c.y], "model": art})
			if piece != null:
				piece.set_meta("furnish", true)
				board.occupied[c] = "furnish"
				placed += 1
				_light(board, c, Vector2i.ZERO, art, lit, lights, ai, cfg)
	for ai: int in squares:
		var rule := _rule(cfg, board, areas[ai] as Dictionary if ai >= 0 else {})
		if str(rule.get("rug", "")) != "":
			_rug(board, squares[ai] as Array[Vector2i], str(rule["rug"]))
	return placed


## The squares on the shortest ways from the spawn to every door, exit and person (the ways the party walks): the
## open middle of a room is furnished, but not across them.
static func _paths(board: ArenaBoard, loc: Dictionary) -> Dictionary:
	var g := board.grid
	var starts: Array[Vector2i] = []
	for s: Variant in (loc.get("spawns", {}) as Dictionary).values():
		starts.append(_cell(s))
	var goals: Array[Vector2i] = []
	for key: String in ["doors", "exits", "npcs"]:
		for t: Variant in loc.get(key, []):
			goals.append(_cell((t as Dictionary).get("cell", [])))
	var out := {}
	if starts.is_empty():
		return out
	# One search from the first spawn; each goal walks back along it.
	var from := {starts[0]: starts[0]}
	var open: Array[Vector2i] = [starts[0]]
	var i := 0
	while i < open.size():
		var c: Vector2i = open[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not g.in_bounds(n) or from.has(n):
				continue
			var goal := n in goals
			if not goal and (g.has_flag(n, CombatGrid.WALL) or g.has_flag(n, CombatGrid.VOID) or g.has_flag(n, CombatGrid.WATER)):
				continue
			from[n] = c
			if not goal:
				open.append(n)
	var ends: Array[Vector2i] = goals.duplicate()
	ends.append_array(starts.slice(1))
	for goal: Vector2i in ends:
		var c: Vector2i = goal
		var guard := 0
		while from.has(c) and c != starts[0] and guard < 4096:
			out[c] = true
			c = from[c] as Vector2i
			guard += 1
	return out


## A passage one square wide (walls on both sides of it): it stays clear for walking.
static func _passage(board: ArenaBoard, c: Vector2i) -> bool:
	var g := board.grid
	var ns := g.has_flag(c + Vector2i(0, -1), CombatGrid.WALL) and g.has_flag(c + Vector2i(0, 1), CombatGrid.WALL)
	var we := g.has_flag(c + Vector2i(-1, 0), CombatGrid.WALL) and g.has_flag(c + Vector2i(1, 0), CombatGrid.WALL)
	return ns or we


## The little light of a lantern or candles it put out (`lit`), at most `lights_per_room` in a room.
static func _light(board: ArenaBoard, c: Vector2i, wall_dir: Vector2i, art: String, lit: Array, lights: Dictionary, ai: int,
		cfg: Dictionary) -> void:
	if not art in lit or int(lights.get(ai, 0)) >= int(cfg.get("lights_per_room", 2)):
		return
	lights[ai] = int(lights.get(ai, 0)) + 1
	var l := CandleFlicker.new()
	l.name = "FurnishLight"
	l.light_color = Look.color("candle")
	l.omni_range = 3.5
	l.base_energy = 0.9
	l.position = board.cell_center(c) + Vector3(wall_dir.x, 0, wall_dir.y) * 0.3 + Vector3(0, 1.1 if wall_dir != Vector2i.ZERO else 0.5, 0)
	board.add_child(l)


## A rug under the middle of a room: as big as the room's open middle allows (up to 4 by 3 squares), the surface
## `surface` (a texture set, world-mapped like the floors) over a dark border, lying flat, blocking nothing.
static func _rug(board: ArenaBoard, cells: Array[Vector2i], surface: String) -> void:
	if cells.size() < 9:
		return
	var lo := cells[0]
	var hi := cells[0]
	var open := {}
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		open[c] = true
	var w := mini(hi.x - lo.x - 1, 4)
	var d := mini(hi.y - lo.y - 1, 3)
	if w < 2 or d < 2:
		return
	var x0 := lo.x + (hi.x - lo.x + 1 - w) / 2
	var z0 := lo.y + (hi.y - lo.y + 1 - d) / 2
	for i in w:
		for j in d:
			var c := Vector2i(x0 + i, z0 + j)
			if not open.has(c) or board.grid.has_flag(c, CombatGrid.DIFFICULT) or board.floor_y(c) != board.floor_y(Vector2i(x0, z0)):
				return   # only on a plain level floor, all of it in the room
	var mat: Material = Look.cel_textured(surface, 0.0)
	if mat == null:
		return
	var y := board.floor_y(Vector2i(x0, z0))
	var centre := Vector3(x0 + w / 2.0, y, z0 + d / 2.0)
	var border := board.add_box("FurnishRugEdge", Vector3(w - 0.1, 0.01, d - 0.1), centre + Vector3(0, 0.005, 0), Look.cel("blood_deep"))
	border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top := board.add_box("FurnishRug", Vector3(w - 0.3, 0.012, d - 0.3), centre + Vector3(0, 0.008, 0), mat)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The squares nothing may be put on or hung beside: doors and exits and the squares round them, spawns and the squares
## round them (the party stands there on arriving), the squares people stand on and beside, lights' squares (a torch
## stands there), and the wall squares holding the location's own things (their pieces hang there).
static func _keep_clear(board: ArenaBoard, loc: Dictionary) -> Dictionary:
	var out := {}
	var around: Array[Vector2i] = []
	for key: String in ["doors", "exits"]:
		for t: Variant in loc.get(key, []):
			around.append(_cell((t as Dictionary).get("cell", [])))
	for s: Variant in (loc.get("spawns", {}) as Dictionary).values():
		around.append(_cell(s))
	for n: Variant in loc.get("npcs", []):
		around.append(_cell((n as Dictionary).get("cell", [])))
	for l: Variant in loc.get("lights", []):
		out[_cell((l as Dictionary).get("cell", []))] = true   # a torch stands there; a fire burns there
	for c in around:
		for dz: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				out[c + Vector2i(dx, dz)] = true
	for key: String in ["props", "containers"]:
		for t: Variant in loc.get(key, []):
			var spec := t as Dictionary
			var c := _cell(spec.get("cell", []))
			if board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL):
				out[c] = true
				for d in SetDressing.FACES:
					out[c + d] = true   # and the floor in front of it: nothing stands over a named thing on the wall
			# A building-sized piece (a stall, a wagon) reaches over the squares round its own.
			var art := str(SetDressing.look_for(spec, key == "containers").get("art", ""))
			var model := ModelPiece.for_art(board, art) if art != "" else ""
			if art != "" and (SetDressing.is_big(art) or (model != "" and bool((ModelPiece.manifest()[model] as Dictionary).get("big", false)))):
				for dz: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						out[c + Vector2i(dx, dz)] = true
	return out


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	if a == null or a.size() < 2:
		return Vector2i(-99, -99)
	return Vector2i(int(a[0]), int(a[1]))


static func _open(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID) \
		and not board.grid.has_flag(c, CombatGrid.WATER)


static func _beside_wall(board: ArenaBoard, c: Vector2i) -> bool:
	for d in SetDressing.FACES:
		if board.grid.in_bounds(c + d) and board.grid.has_flag(c + d, CombatGrid.WALL):
			return true
	return false


## How many of the four squares beside this one already hold a furnishing piece (the middle of a room gets clusters,
## not solid rows).
static func _furnished_around(board: ArenaBoard, c: Vector2i) -> int:
	var n := 0
	for d in SetDressing.FACES:
		if str(board.occupied.get(c + d, "")) == "furnish":
			n += 1
	return n


## A furnishing piece already on a square beside this one (they don't crowd up in rows).
static func _furnished_beside(board: ArenaBoard, c: Vector2i) -> bool:
	for d in SetDressing.FACES:
		if str(board.occupied.get(c + d, "")) == "furnish":
			return true
	return false


## The index of the smallest area holding `c`, or -1.
static func _area_of(areas: Array, c: Vector2i) -> int:
	var best := -1
	var best_size := 1 << 30
	for i in areas.size():
		var cells := (areas[i] as Dictionary).get("cells", []) as Array
		if cells.size() < 2:
			continue
		var p0 := _cell(cells[0])
		var p1 := _cell(cells[1])
		var r := Rect2i(Vector2i(mini(p0.x, p1.x), mini(p0.y, p1.y)), (p1 - p0).abs() + Vector2i.ONE)
		if r.has_point(c) and r.get_area() < best_size:
			best = i
			best_size = r.get_area()
	return best


## The furnishing rule for a room: the first `rooms` rule whose words are in its name (else its id), else the board
## theme's.
static func _rule(cfg: Dictionary, board: ArenaBoard, area: Dictionary) -> Dictionary:
	var own: Variant = SetDressing.room_rule(cfg.get("rooms", []) as Array, area) if not area.is_empty() else null
	if own != null:
		return own as Dictionary
	return (cfg.get("themes", {}) as Dictionary).get(board.theme, {}) as Dictionary


## The art ids of a rule's list that exist.
static func _arts(names: Array) -> Array[String]:
	var out: Array[String] = []
	for n: Variant in names:
		if SetDressing.has_art(str(n)):
			out.append(str(n))
	return out


static func _hash(place: String, c: Vector2i, salt: int) -> int:
	return absi(hash("%s|%d|%d|%d" % [place, c.x, c.y, salt]))
