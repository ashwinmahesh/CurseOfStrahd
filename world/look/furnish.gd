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
static func dress(board: ArenaBoard, loc: Dictionary) -> int:
	var cfg := SetDressing.catalog().get("furnish", {}) as Dictionary
	if cfg.is_empty() or bool(loc.get("furnish", true)) == false:
		return 0
	var keep_clear := _keep_clear(board, loc)
	var placed := 0
	# Each square belongs to the smallest area holding it (a room inside a hall is its own room).
	var areas := loc.get("areas", []) as Array
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if not _open(board, c) or board.occupied.has(c) or keep_clear.has(c):
				continue
			var ai := _area_of(areas, c)
			var rule := _rule(cfg, board, areas[ai] as Dictionary if ai >= 0 else {})
			if rule.is_empty():
				continue
			# A wall piece: on the face of the wall beside this square that a piece hung from here takes (the first
			# wall in SetDressing.FACES order, as SetDressing._hang picks it), about one square in `wall_every`.
			var hung := false
			var walls_beside := 0
			for d in SetDressing.FACES:
				if board.grid.in_bounds(c + d) and board.grid.has_flag(c + d, CombatGrid.WALL):
					walls_beside += 1
			for d in SetDressing.FACES:
				if walls_beside > 1:
					break   # a room's corner: a piece hung there would meet the one on the other wall
				var w := c - d
				if not board.grid.in_bounds(w) or not board.grid.has_flag(w, CombatGrid.WALL):
					continue
				var face := "%d,%d,%d,%d" % [w.x, w.y, d.x, d.y]
				var h := _hash(board.place, c, 11)
				var arts := _arts(rule.get("wall", []) as Array)
				if not keep_clear.has(w) and not board.used_faces.has(face) and h % int(cfg.get("wall_every", 3)) == 0 \
						and not arts.is_empty():
					var root := SetDressing.place(board, {"id": "furnish_%d_%d_w" % [c.x, c.y], "cell": [c.x, c.y],
						"model": arts[(h / 7) % arts.size()]})
					if root != null:
						root.set_meta("furnish", true)
						hung = true
						placed += 1
				break
			# A floor piece: on a free square along a wall, about one in `floor_every`, never two side by side.
			if hung or not _beside_wall(board, c) or board.grid.has_flag(c, CombatGrid.LOW) \
					or board.grid.has_flag(c, CombatGrid.DIFFICULT) or _furnished_beside(board, c):
				continue
			var hf := _hash(board.place, c, 5)
			var floor_arts := _arts(rule.get("floor", []) as Array)
			if hf % int(cfg.get("floor_every", 4)) != 0 or floor_arts.is_empty():
				continue
			var piece := SetDressing.place(board, {"id": "furnish_%d_%d" % [c.x, c.y], "cell": [c.x, c.y],
				"model": floor_arts[(hf / 13) % floor_arts.size()]})
			if piece != null:
				piece.set_meta("furnish", true)
				board.occupied[c] = "furnish"
				placed += 1
	return placed


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
