class_name Clutter
extends RefCounted
## Clutter and decals (Improvement Ideas W10, docs/art/decals.md): marks laid over a board's floors and walls by rule
## (cracks, stains, moss, blood, puddles, leaves, straw, dust, soot, damp), so a room or a street stops reading as one
## tile repeated, and mud fringes where cobbles meet mud so materials blend instead of meeting at a square's edge.
## The marks are Godot Decals: they take the scene's light and never block a square. Which marks go where is in
## art/sprites/props/catalog.json "clutter"; every placement is picked from the square, so a place looks the same
## every time it's built. Decals only show in the Modern look (Classic is frozen as it was).

const MANIFEST_JSON := "res://art/textures/decals/manifest.json"
## How deep a decal's box reaches through the surface it lies on (it fades at both ends).
const DEPTH := 0.24

static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}


## Every decal: id -> {file, normal_file, view (floor | wall), aspect, sheet}.
static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_JSON):
		_manifest = (JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON)) as Dictionary).get("decals", {}) as Dictionary
	return _manifest


## The decal ids a rule names: a sheet's name stands for its four marks.
static func ids_for(names: Array) -> Array[String]:
	var out: Array[String] = []
	for n: Variant in names:
		var name := str(n)
		if manifest().has(name):
			out.append(name)
			continue
		for id: String in manifest():
			if str((manifest()[id] as Dictionary).get("sheet", "")) == name:
				out.append(id)
	out.sort()
	return out


## The rules for a board: its place's own (by the start of the place's id), else its theme's.
static func rules_for(board: ArenaBoard) -> Array:
	var cfg := SetDressing.catalog().get("clutter", {}) as Dictionary
	var best := ""
	for prefix: String in cfg.get("places", {}):
		if board.place.begins_with(prefix) and prefix.length() > best.length():
			best = prefix
	if best != "":
		return (cfg["places"] as Dictionary)[best] as Array
	return (cfg.get("themes", {}) as Dictionary).get(board.theme, []) as Array


## Lays the board's decals, by its rules (ArenaBoard asks once the board is built). Returns how many.
static func dress(board: ArenaBoard) -> int:
	if not Look.modern() or manifest().is_empty():
		return 0
	var rules := rules_for(board)
	if rules.is_empty():
		return 0
	var root := Node3D.new()
	root.name = "Clutter"
	board.add_child(root)
	var placed := 0
	for ri in rules.size():
		var rule := rules[ri] as Dictionary
		var ids := ids_for(rule.get("decals", []) as Array)
		if ids.is_empty():
			continue
		var chance := float(rule.get("chance", 0.05))
		var cap := int(rule.get("max", 60))
		var size := rule.get("size", [0.7, 1.3]) as Array
		var count := 0
		for z in board.grid.depth:
			for x in board.grid.width:
				if count >= cap:
					break
				var c := Vector2i(x, z)
				var h := _hash(board.place, c, ri)
				if float(h % 10007) / 10007.0 >= chance:
					continue
				var spots := _spots(board, c, str(rule.get("on", "floor")))
				if spots.is_empty():
					continue
				var spot := spots[(h / 7) % spots.size()] as Dictionary
				var id := ids[(h / 131) % ids.size()]
				var s := lerpf(float(size[0]), float(size[1]), float((h / 977) % 1000) / 1000.0)
				var d := _decal(id, s, spot, h)
				if d != null:
					root.add_child(d)
					count += 1
		placed += count
	return placed


## Where a rule's mark can go on square `c`: [{at: Vector3 (the surface point), normal: Vector3 (out of the
## surface), wall: bool}]. on: floor (any open floor), edge (open floor beside a wall), difficult (rough ground),
## boundary (open floor beside rough ground: the mark sits on the line between them), wall (an open face of a wall
## square, at eye height), wall_foot (the same, at the foot).
static func _spots(board: ArenaBoard, c: Vector2i, on: String) -> Array:
	var g := board.grid
	var out: Array = []
	var open := not g.has_flag(c, CombatGrid.WALL) and not g.has_flag(c, CombatGrid.VOID) and not g.has_flag(c, CombatGrid.WATER)
	var y := board.floor_y(c)
	var mid := Vector3(c.x + 0.5, y, c.y + 0.5)
	match on:
		"floor":
			if open and not g.has_flag(c, CombatGrid.DIFFICULT):
				out.append({"at": mid, "normal": Vector3.UP, "wall": false})
		"difficult":
			if open and g.has_flag(c, CombatGrid.DIFFICULT):
				out.append({"at": mid, "normal": Vector3.UP, "wall": false})
		"edge", "boundary":
			if not open or g.has_flag(c, CombatGrid.DIFFICULT):
				return out
			for d: Vector2i in SetDressing.FACES:
				var n := c + d
				if not g.in_bounds(n):
					continue
				var hit := g.has_flag(n, CombatGrid.WALL) if on == "edge" else g.has_flag(n, CombatGrid.DIFFICULT)
				if hit:
					var toward := Vector3(d.x, 0, d.y) * (0.32 if on == "edge" else 0.5)
					out.append({"at": mid + toward, "normal": Vector3.UP, "wall": false})
		"wall", "wall_foot":
			if not g.has_flag(c, CombatGrid.WALL) or board.is_tree(c):
				return out
			for d: Vector2i in SetDressing.FACES:
				var n := c + d
				if not g.in_bounds(n) or g.has_flag(n, CombatGrid.WALL) or g.has_flag(n, CombatGrid.VOID):
					continue
				var nv := Vector3(d.x, 0, d.y)
				out.append({"at": Vector3(c.x + 0.5, board.floor_y(n), c.y + 0.5) + nv * 0.5, "normal": nv, "wall": true,
					"foot": on == "wall_foot"})
	return out


static func _decal(id: String, s: float, spot: Dictionary, h: int) -> Decal:
	var info := manifest()[id] as Dictionary
	var tex := _texture(str(info.get("file", "")))
	if tex == null:
		return null
	var d := Decal.new()
	d.name = "Decal_" + id
	d.texture_albedo = tex
	var nm := _texture(str(info.get("normal_file", "")))
	if nm != null:
		d.texture_normal = nm
	var aspect := float(info.get("aspect", 1.0))
	var w := s * sqrt(aspect)
	var tall := s / sqrt(aspect)
	var at := spot["at"] as Vector3
	if bool(spot["wall"]):
		# On a wall face: the box's -y points into the wall, the picture's foot (its +z) down.
		var n := spot["normal"] as Vector3
		var x := Vector3.UP.cross(n).normalized()
		d.transform = Transform3D(Basis(x, n, x.cross(n)), Vector3.ZERO)
		tall = minf(tall, 1.05)
		var y0 := 0.02 if bool(spot.get("foot", false)) else 0.25 + float(h % 40) / 100.0
		d.position = at + Vector3(0, y0 + tall / 2.0, 0) + x * (float((h / 3) % 50) / 100.0 - 0.25)
		d.size = Vector3(minf(w, 0.95), DEPTH, tall)
	else:
		d.rotation.y = float(h % 360) * PI / 180.0
		var jitter := Vector3(float((h / 11) % 40) / 100.0 - 0.2, 0, float((h / 13) % 40) / 100.0 - 0.2)
		d.position = at + jitter + Vector3(0, 0.02, 0)
		d.size = Vector3(w, DEPTH, tall)
	d.upper_fade = 0.25
	d.lower_fade = 0.25
	d.normal_fade = 0.3
	return d


static func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = load("res://" + path) as Texture2D if ResourceLoader.exists("res://" + path) else null
	return _textures[path] as Texture2D


static func _hash(place: String, c: Vector2i, salt: int) -> int:
	return absi(hash(place) ^ (c.x * 73856093) ^ (c.y * 19349663) ^ (salt * 83492791))
