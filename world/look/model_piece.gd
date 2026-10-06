class_name ModelPiece
extends RefCounted
## 3D set pieces (docs/art/models.md): furniture, fireplaces, stairs, doors and panelled walls modelled in Blender
## (blender/models_3d.py, `make models`) from the 2D props they stand in for. The catalog's "models3d" names the
## places that use them (a pilot, owner request 2026-10-06) and which art each model replaces; everywhere else, and
## for anything without a model, the 2D piece is drawn as before. Characters and creatures always stay 2D.
## A model keeps its place and facing like the 2D pieces: furniture backs onto the wall (or doorway) beside it, else
## faces south; a wall piece stands on the wall face looking into the room. Its surfaces use the board's cel shading,
## so it takes the scene's lights and shadows, and the screen pass outlines it and snaps it to the palette.

const MANIFEST_JSON := "res://art/models/manifest.json"
## How far a piece standing against a wall keeps off the wall face.
const GAP := 0.004
## Sides of a square in the order furniture looks for a wall to back onto: north first, so it faces the camera.
const BACKS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]

static var _manifest: Dictionary = {}
static var _materials: Dictionary = {}
static var _triangles: Dictionary = {}


## Every model: id -> {file, mount, size [w, h, d], stands_for, sockets ...} (art/models/manifest.json).
static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_JSON):
		_manifest = (JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON)) as Dictionary).get("models", {}) as Dictionary
	return _manifest


static func settings() -> Dictionary:
	return SetDressing.catalog().get("models3d", {}) as Dictionary


static func has_model(id: String) -> bool:
	var info := manifest().get(id, {}) as Dictionary
	return not info.is_empty() and ResourceLoader.exists("res://" + str(info.get("file", "")))


## Does this board's place use the 3D pieces?
static func in_use(board: ArenaBoard) -> bool:
	var places := settings().get("places", []) as Array
	return board != null and ("*" in places or board.place in places)


## The model that stands in for 2D `art` on this board, or "".
static func for_art(board: ArenaBoard, art: String) -> String:
	if art == "" or not in_use(board):
		return ""
	var id := str((settings().get("art", {}) as Dictionary).get(art, ""))
	return id if has_model(id) else ""


## A new copy of model `id` with its surfaces in the game's materials (by material name: pal_<colour>,
## glow_<colour>, tex_<theme>__<surface>).
static func instance(id: String) -> Node3D:
	var info := manifest()[id] as Dictionary
	var root := (load("res://" + str(info["file"])) as PackedScene).instantiate() as Node3D
	root.name = "Model_" + id
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			mi.set_surface_override_material(i, material(src.resource_name if src != null else ""))
	root.set_meta("model", id)
	return root


## The game material for a model surface named in Blender.
static func material(name: String) -> Material:
	if _materials.has(name):
		return _materials[name] as Material
	var m: Material = null
	if name.begins_with("pal_"):
		m = Look.cel(name.trim_prefix("pal_"))
	elif name.begins_with("glow_"):
		var g := Look.cel(name.trim_prefix("glow_"))
		g.set_shader_parameter("emission", Look.color(name.trim_prefix("glow_")) * 1.6)
		m = g
	elif name.begins_with("tex_"):
		m = Look.cel_textured(name.trim_prefix("tex_").replace("__", "/"))
	if m == null:
		m = Look.cel("pewter")
	_materials[name] = m
	return m


# --- Placing ----------------------------------------------------------------------------------------------------

## A standing piece on `cell` (SetDressing.stand_piece and exits): a holder on the square, turned to face into the
## room, with the model in it. Against-the-wall furniture stands with its back on the wall face. Returns the holder.
static func stand(board: ArenaBoard, parent: Node3D, id: String, art: String, cell: Vector2i,
		at_override: Variant = null) -> Node3D:
	var info := manifest()[id] as Dictionary
	var mount := str(info.get("mount", "free"))
	var holder := Node3D.new()
	holder.name = "Model_" + id
	holder.position = board.cell_center(cell) if at_override == null else at_override as Vector3
	holder.set_meta("art", art)
	holder.set_meta("model", id)
	parent.add_child(holder)
	var model := instance(id)
	holder.add_child(model)
	if mount == "stairs_up" or mount == "stairs_down":
		var e := entry_side(board, cell)
		holder.rotation.y = atan2(float(e.x), float(e.y))   # the steps start on the side the party walks in from
		if mount == "stairs_down":
			_open_floor(board, holder, cell)
		return holder
	var back := backing_side(board, cell)
	var faces := Vector2i(0, 1) if back == Vector2i.ZERO else -back
	holder.rotation.y = atan2(float(faces.x), float(faces.y))
	if mount == "against_wall":
		var depth := float((info.get("size", [1, 1, 0.3]) as Array)[2])
		if back != Vector2i.ZERO:
			model.position = Vector3(0, 0, -0.5 + GAP)
			board.used_faces["%d,%d,%d,%d" % [cell.x + back.x, cell.y + back.y, -back.x, -back.y]] = true   # no portrait behind it
		else:
			model.position = Vector3(0, 0, -depth / 2.0)
	_extras(model, info)
	return holder


## A wall piece (a fireplace) on the face of wall square `wall` looking along `normal`, under `root`.
static func hang(board: ArenaBoard, root: Node3D, id: String, art: String, wall: Vector2i, normal: Vector2i) -> Node3D:
	var info := manifest()[id] as Dictionary
	var holder := Node3D.new()
	holder.name = "Model_" + id
	var c := board.cell_center(wall)
	var n := Vector3(normal.x, 0, normal.y)
	holder.position = Vector3(c.x, board.floor_y(wall + normal), c.z) + n * (0.5 + GAP)
	holder.rotation.y = atan2(n.x, n.z)
	holder.set_meta("art", art)
	holder.set_meta("model", id)
	root.add_child(holder)
	var model := instance(id)
	holder.add_child(model)
	_extras(model, info)
	return holder


## A door leaf as a model (SetDressing.door), sized to the opening; named "Leaf" so opening and finding it work as
## for the 2D leaf.
static func door_leaf(id: String, width: float, height: float) -> Node3D:
	var size := (manifest()[id] as Dictionary).get("size", [0.86, 1.15, 0.06]) as Array
	var leaf := instance(id)
	leaf.name = "Leaf"
	leaf.scale = Vector3(width / float(size[0]), height / float(size[1]), 1.0)
	return leaf


## The board's panelled-wall modules: on each open face of wall square `c` painted with a surface that has a model
## (catalog models3d "walls"), a module standing on the face. A doorway's sides are left plain (the frame is there).
## Added under one holder on the wall square, so it hides and shows with the wall.
static func dress_wall(board: ArenaBoard, c: Vector2i, wall_mat: Material) -> void:
	if not in_use(board) or wall_mat == null:
		return
	var id := ""
	for surface: String in settings().get("walls", {}):
		if Look.cel_textured(surface) == wall_mat:
			id = str((settings()["walls"] as Dictionary)[surface])
	if not has_model(id):
		return
	var holder: Node3D = null
	for d: Vector2i in BACKS:
		var n := c + d
		if not board.grid.in_bounds(n) or board.grid.has_flag(n, CombatGrid.WALL) or board.grid.has_flag(n, CombatGrid.VOID):
			continue
		if board.grid.in_bounds(n + d) and board.grid.has_flag(n + d, CombatGrid.WALL):
			continue   # a one-square gap in the wall: a doorway
		if holder == null:
			holder = Node3D.new()
			holder.name = "WallModules"
			holder.set_meta("wall_modules", id)
			holder.position = board.cell_center(c)
			board.add_child(holder)
		var face := instance(id)
		var dir := Vector3(d.x, 0, d.y)
		face.position = dir * (0.5 + GAP * 0.5) + Vector3(0, board.floor_y(n), 0)
		face.rotation.y = atan2(dir.x, dir.z)
		holder.add_child(face)


## The side of `cell` with a wall or a door next to it, that furniture backs onto (Vector2i.ZERO if none).
static func backing_side(board: ArenaBoard, cell: Vector2i) -> Vector2i:
	for d: Vector2i in BACKS:
		var n := cell + d
		if board.grid.in_bounds(n) and (board.grid.has_flag(n, CombatGrid.WALL) or board.door_cells.has(n)):
			return d
	return Vector2i.ZERO


## The side of a stair's square the party comes in from: an open neighbour, the ones the opening camera faces first.
static func entry_side(board: ArenaBoard, cell: Vector2i) -> Vector2i:
	for d in SetDressing.FACES:
		var n := cell + d
		if board.grid.in_bounds(n) and not board.grid.has_flag(n, CombatGrid.WALL) and not board.grid.has_flag(n, CombatGrid.VOID):
			return d
	return Vector2i(0, 1)


## A stairwell opens its square's floor while it shows (a secret stair nobody has found leaves the floor whole).
static func _open_floor(board: ArenaBoard, holder: Node3D, cell: Vector2i) -> void:
	var floors: Array[Node3D] = []
	for n in board.get_children():
		if _is_floor_box(board, n, cell):
			floors.append(n as Node3D)
	var sync := func() -> void:
		for f in floors:
			if is_instance_valid(f):
				f.visible = not (is_instance_valid(holder) and holder.is_visible_in_tree())
	holder.visibility_changed.connect(sync)
	holder.tree_entered.connect(sync)
	holder.tree_exiting.connect(func() -> void:
		for f in floors:
			if is_instance_valid(f):
				f.visible = true)
	sync.call()


## The board's ground box on `cell`: a square slab whose top is the square's floor.
static func _is_floor_box(board: ArenaBoard, n: Node, cell: Vector2i) -> bool:
	if not (n is MeshInstance3D) or not ((n as MeshInstance3D).mesh is BoxMesh):
		return false
	var mi := n as MeshInstance3D
	var size := (mi.mesh as BoxMesh).size
	var at := board.cell_center(cell)
	return absf(mi.position.x - at.x) < 0.01 and absf(mi.position.z - at.z) < 0.01 and is_equal_approx(size.x, 1.0) \
		and absf(mi.position.y + size.y / 2.0 - board.floor_y(cell)) < 0.01


## What a model takes from the 2D art (manifest "decals": a painting's canvas, figurines on a mantel, cut from the
## 2D piece by pixel region and set at a socket, facing out) and the 2D flame at a "flame" socket (a hearth's fire).
static func _extras(model: Node3D, info: Dictionary) -> void:
	var sockets := info.get("sockets", {}) as Dictionary
	for key: String in sockets:
		if not key.begins_with("flame"):
			continue
		var at := sockets[key] as Array
		var f := SetDressing.flame(0.32)
		if f != null:
			f.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
			model.add_child(f)
	for d: Variant in info.get("decals", []):
		var decal := d as Dictionary
		var art := str(decal.get("art", ""))
		var at := sockets.get(str(decal.get("socket", "")), []) as Array
		if not SetDressing.has_art(art) or at.size() != 3:
			continue
		var r := decal["region"] as Array
		var px := float(decal.get("width", 0.5)) / float(r[2])
		var middle := float(r[0]) + float(r[2]) / 2.0
		# A row of small things (figurines on a mantel) is cut into one sprite each, turning to the camera.
		var parts: Array = decal.get("split", [[float(r[0]), float(r[0]) + float(r[2])]]) as Array
		for part: Variant in parts:
			var x0 := float((part as Array)[0])
			var x1 := float((part as Array)[1])
			var sp := Sprite3D.new()
			sp.name = "Decal_" + str(decal.get("socket", ""))
			sp.texture = load("res://" + str((SetDressing.manifest()[art] as Dictionary)["file"])) as Texture2D
			sp.region_enabled = true
			sp.region_rect = Rect2(x0, float(r[1]), x1 - x0, float(r[3]))
			sp.pixel_size = px
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if decal.has("split") else BaseMaterial3D.BILLBOARD_DISABLED
			sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sp.shaded = true
			if str(decal.get("anchor", "center")) == "bottom":
				sp.offset = Vector2(0, float(r[3]) / 2.0)
			sp.position = Vector3(float(at[0]) + ((x0 + x1) / 2.0 - middle) * px, float(at[1]), float(at[2]))
			model.add_child(sp)


# --- Looks and picking ------------------------------------------------------------------------------------------

## An emptied container dims (as SetDressing.mark_looted does for sprites).
static func dim(node: Node3D) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null:
				continue
			# A flat colour's albedo, or a texture's tint, darkened.
			var key := "albedo" if m.shader == Look.CEL_SHADER else ("tint" if m.shader == Look.CEL_WORLD_SHADER else "")
			if key == "":
				continue
			var d := m.duplicate() as ShaderMaterial
			d.set_shader_parameter(key, colour_of(m.get_shader_parameter(key)) * Color(0.55, 0.5, 0.55))
			mi.set_surface_override_material(i, d)


## A shader colour parameter as a Color (a vec3 may come back as a Vector3; unset is white).
static func colour_of(v: Variant) -> Color:
	if v is Color:
		return v as Color
	if v is Vector3:
		var w := v as Vector3
		return Color(w.x, w.y, w.z)
	return Color.WHITE


## Distance along a ray to the nearest model surface under `node` (itself and its children), or INF, so pointing at
## any drawn part of a piece picks it (SpritePick.hit).
static func hit(node: Node3D, origin: Vector3, dir: Vector3) -> float:
	var best := INF
	if node == null or not node.is_visible_in_tree():
		return best
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var inv := mi.global_transform.affine_inverse()
		var tm := _triangle_mesh(mi.mesh)
		var res := tm.intersect_ray(inv * origin, inv.basis * dir)
		if res.is_empty():
			continue
		var p := mi.global_transform * (res["position"] as Vector3)
		best = minf(best, (p - origin).dot(dir) / dir.length_squared())   # as SpritePick: origin + dir * t
	return best


static func _triangle_mesh(mesh: Mesh) -> TriangleMesh:
	var key := mesh.get_rid()
	if not _triangles.has(key):
		_triangles[key] = mesh.generate_triangle_mesh()
	return _triangles[key] as TriangleMesh
