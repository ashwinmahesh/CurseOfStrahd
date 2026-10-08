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
## A cut-away interior wall's height (ArenaBoard's interior walls, and what the kit's copings are made for).
const CUT_TOP := 1.15
const SPRITE_SHADER := preload("res://shaders/cel_sprite.gdshader")
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


## The model that stands in for 2D `art` on this board, or "". A catalog entry can depend on the board's theme
## ({theme: model, "*": model}): wooden stairs in houses, stone ones in dungeons and churches.
## A list of models is a set of variants (pines, boulders): `pick` (from where the piece stands) chooses one.
static func for_art(board: ArenaBoard, art: String, pick: int = 0) -> String:
	if art == "" or not in_use(board):
		return ""
	var entry: Variant = (settings().get("art", {}) as Dictionary).get(art, "")
	if entry is Dictionary:
		entry = (entry as Dictionary).get(board.theme, (entry as Dictionary).get("*", ""))
	if entry is Array:
		var options := entry as Array
		entry = options[posmod(pick, options.size())] if not options.is_empty() else ""
	var id := str(entry)
	return id if has_model(id) else ""


## A number for a square, to pick a variant and a heading that stay the same every time the place is built.
static func hash_cell(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


## A new copy of model `id` with its surfaces in the game's materials (by material name: pal_<colour>,
## glow_<colour>, tex_<theme>__<surface>). The model's file is opened once: after that a copy is its meshes in new
## MeshInstance3Ds (a place's 900-odd pieces cost a fifth of what opening the scene each time did; perf pass).
static func instance(id: String) -> Node3D:
	var key := id + "|" + Look.style()
	if not _parts.has(key):
		_parts[key] = _read_parts(id)
	var root := Node3D.new()
	root.name = "Model_" + id
	for part: Array in _parts[key]:
		var mi := MeshInstance3D.new()
		mi.name = str(part[3])
		mi.mesh = part[0] as Mesh
		mi.transform = part[1] as Transform3D
		var mats := part[2] as Array
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i] as Material)
		root.add_child(mi)
	root.set_meta("model", id)
	return root


static var _parts: Dictionary = {}


## Model `id`'s meshes as [mesh, transform under the model's root, the game's material per surface, node name].
static func _read_parts(id: String) -> Array:
	var info := manifest()[id] as Dictionary
	var scene := (load("res://" + str(info["file"])) as PackedScene).instantiate() as Node3D
	var out: Array = []
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != scene and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var mats: Array = []
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			mats.append(material(src.resource_name if src != null else ""))
		out.append([mi.mesh, xf, mats, mi.name])
	scene.free()
	return out


## The game material for a model surface named in Blender.
static func material(name: String) -> Material:
	var key := name + "|" + Look.style()   # a change of look gets fresh materials
	if _materials.has(key):
		return _materials[key] as Material
	var m: Material = null
	if name.begins_with("pal_"):
		m = Look.cel(name.trim_prefix("pal_"))
	elif name.begins_with("glow_"):
		var g := Look.cel(name.trim_prefix("glow_"))
		g.set_shader_parameter("emission", Look.color(name.trim_prefix("glow_")) * 1.6)
		m = g
	elif name.begins_with("tex_"):
		m = Look.cel_textured(name.trim_prefix("tex_").replace("__", "/"))
	elif name.begins_with("spr_") and SetDressing.has_art(name.trim_prefix("spr_")):
		# Painted with its own 2D art (a piece sculpted from its sprite).
		var sm := ShaderMaterial.new()
		sm.shader = SPRITE_SHADER
		sm.set_shader_parameter("albedo_tex", load("res://" + str((SetDressing.manifest()[name.trim_prefix("spr_")] as Dictionary)["file"])) as Texture2D)
		m = sm
	if m == null:
		m = Look.cel("pewter")
	_materials[key] = m
	return m


# --- Placing ----------------------------------------------------------------------------------------------------

## A standing piece on `cell` (SetDressing.stand_piece and exits): a holder on the square, turned to face into the
## room, with the model in it. Against-the-wall furniture stands with its back on the wall face. Returns the holder.
static func stand(board: ArenaBoard, parent: Node3D, id: String, art: String, cell: Vector2i,
		at_override: Variant = null, scale_: float = 1.0) -> Node3D:
	var info := manifest()[id] as Dictionary
	var mount := str(info.get("mount", "free"))
	var holder := Node3D.new()
	holder.name = "Model_" + id
	holder.position = board.cell_center(cell) if at_override == null else at_override as Vector3
	holder.set_meta("art", art)
	holder.set_meta("model", id)
	parent.add_child(holder)
	var model := instance(id)
	model.scale = Vector3.ONE * scale_
	holder.add_child(model)
	if bool(info.get("turns", false)):
		# Nature has no front: each copy gets its own heading, the same every time the place is built.
		holder.rotation.y = float(hash_cell(cell) % 360) * PI / 180.0
		holder.set_meta("nature", true)
		_extras(model, info)
		return holder
	if mount == "stairs_up" or mount == "stairs_down":
		var e := entry_side(board, cell)
		holder.rotation.y = atan2(float(e.x), float(e.y))   # the steps start on the side the party walks in from
		if mount == "stairs_down":
			_open_floor(board, holder, cell)
		return holder
	var back := backing_side(board, cell)
	var faces := Vector2i(0, 1) if back == Vector2i.ZERO else -back
	holder.rotation.y = atan2(float(faces.x), float(faces.y))
	if bool(info.get("big", false)) and at_override == null:
		# Building-sized (a wagon, a market stall): it keeps its size and clears the trees it stands among, as the
		# 2D big pieces do, but shrinks where it would reach something else standing near it (no overlaps).
		var size := info.get("size", [1, 1, 1]) as Array
		var foot := footprint_of(model, holder.rotation.y)
		var fit := big_fit(board, cell, foot)
		model.scale *= fit
		var mine := [cell, Rect2(Vector2(cell.x + 0.5, cell.y + 0.5) + foot.position * fit, foot.size * fit)]
		var feet: Array = board.get_meta("big_feet", [])
		feet.append(mine)
		board.set_meta("big_feet", feet)
		holder.tree_exiting.connect(func() -> void:
			if is_instance_valid(board):
				(board.get_meta("big_feet", []) as Array).erase(mine))   # props rebuilt after a talk stand again
		SetDressing._clear_trees_around(board, parent, cell, maxf(float(size[0]), float(size[2])) * fit)
	if mount == "against_wall" or mount == "wall":
		# A wall piece with no wall face free beside it stands on its square like furniture against a wall.
		var depth := float((info.get("size", [1, 1, 0.3]) as Array)[2])
		holder.set_meta("against_wall", true)
		if back != Vector2i.ZERO:
			model.position = Vector3(0, 0, -0.5 + GAP)
			board.used_faces["%d,%d,%d,%d" % [cell.x + back.x, cell.y + back.y, -back.x, -back.y]] = true   # no portrait behind it
		else:
			model.position = Vector3(0, 0, -depth / 2.0)
	_extras(model, info)
	return holder


## A 3D tree for 2D tree art `kind` (a pine, a dead tree) standing at `at`, as tall as the 2D tree drawn at `size`
## of its art, turned by `yaw`; null when this place has no model for it. The board's trees and the land around a map
## use it; the caller fades it (ArenaBoard.mesh_occluders).
static func tree(board: ArenaBoard, kind: String, at: Vector3, size: float, pick: int, yaw: float) -> Node3D:
	if Flora.enabled():
		# The Modern look's trees (W9, Flora) where the place's set of plants has one for this kind: so a tree put
		# back on its square (ArenaBoard.restore_cell, after a building-sized piece leaves) is the new tree too.
		var f := _flora(board)
		var fid := f.tree_for(kind, pick)
		if fid != "":
			return f.node(fid, at, f.tree_scale(fid, "map", pick), yaw)
	var id := for_art(board, kind, pick)
	if id == "":
		return null
	var holder := Node3D.new()
	holder.name = "Model_" + id
	holder.position = at
	holder.rotation.y = yaw
	holder.set_meta("model", id)
	holder.set_meta("nature", true)
	var model := instance(id)
	model.scale = Vector3.ONE * tree_scale(kind, id, size)
	holder.add_child(model)
	return holder


## The place's set of plants (Flora), made once per board: only which plants it has, not its wind (the land sets that).
static func _flora(board: ArenaBoard) -> Flora:
	if board.has_meta("flora"):
		return board.get_meta("flora") as Flora
	var loc := Compendium.shared().get_entry("locations", board.place) if board.place != "" \
		and Compendium.shared().has("locations", board.place) else {}
	var f := Flora.new()
	f.set_id = Flora.set_for(Atmosphere.mood_for(board.place, loc) if not loc.is_empty() else "")
	f.spec = Flora.resolve(f.set_id)
	board.set_meta("flora", f)
	return f


## How much to scale model `id` so it stands as tall as 2D tree art `kind` drawn at `size`.
static func tree_scale(kind: String, id: String, size: float) -> float:
	var art_h := float((SetDressing.manifest().get(kind, {}) as Dictionary).get("world_height", 4.0)) * size
	var model_h := float(((manifest()[id] as Dictionary).get("size", [1, 3, 1]) as Array)[1])
	return art_h / maxf(model_h, 0.01)


## A tall 3D piece (a tower, the Gulthias Tree) fades like the trees when it stands between the camera and the party.
static func fade_with_trees(board: ArenaBoard, piece: Node3D) -> void:
	board.mesh_occluders.append(piece)
	piece.tree_exiting.connect(func() -> void:
		if is_instance_valid(board):
			board.mesh_occluders.erase(piece))


## Fades a 3D piece standing between the camera and the party (0 drawn solid, 1 gone), as the trees' billboards fade.
static func set_fade(node: Node3D, amount: float) -> void:
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = amount


const INSTANCED_SHADER := preload("res://shaders/cel_instanced.gdshader")
static var _tree_meshes: Dictionary = {}


## Model `id` as one mesh whose surfaces carry their own cel materials that take each instance's colour (the land's
## MultiMesh of trees darkens the far ones).
static func tree_mesh(id: String) -> Mesh:
	if _tree_meshes.has(id):
		return _tree_meshes[id] as Mesh
	var src: Mesh = null
	var root := (load("res://" + str((manifest()[id] as Dictionary)["file"])) as PackedScene).instantiate()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		src = (n as MeshInstance3D).mesh
		break
	root.free()
	if src == null:
		return null
	var mesh := src.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var name := mesh.surface_get_material(i).resource_name if mesh.surface_get_material(i) != null else ""
		var m := ShaderMaterial.new()
		m.shader = INSTANCED_SHADER
		var colour := name.substr(name.find("_") + 1) if name.begins_with("pal_") or name.begins_with("glow_") else "bog_deep"
		m.set_shader_parameter("albedo", Look.color(colour))
		mesh.surface_set_material(i, m)
	_tree_meshes[id] = mesh
	return mesh


## How much a building-sized piece must shrink so its footprint (`foot`: its x and z extent about its node, already
## turned) keeps clear of the location's other things standing near `cell`: 1 where there's room.
static func big_fit(board: ArenaBoard, cell: Vector2i, foot: Rect2) -> float:
	var centre := Vector2(cell.x + 0.5, cell.y + 0.5)
	var s := 1.0
	while s > 0.4:
		var rect := Rect2(centre + foot.position * s, foot.size * s)
		var clear := true
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var c := cell + Vector2i(dx, dz)
				if c == cell or not board.grid.in_bounds(c):
					continue
				# The location's own things; the board's furniture, stumps and brambles under it are cleared away.
				if board.occupied.has(c) and rect.intersects(Rect2(c.x, c.y, 1, 1).grow(-0.12)):
					clear = false
		for other: Variant in board.get_meta("big_feet", []):
			# Another building-sized piece already standing near (one on this very square is the data's own pairing).
			if (other as Array)[0] != cell and rect.intersects(((other as Array)[1] as Rect2).grow(-0.04)):
				clear = false
		if clear:
			return s
		s -= 0.05
	return 0.4


## A model's footprint about its holder (x and z), turned by `yaw`.
static func footprint_of(model: Node3D, yaw: float) -> Rect2:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := (model.transform * mi.transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var turn := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	var r := turn * box
	return Rect2(r.position.x, r.position.z, r.size.x, r.size.z)


## A wall piece (a fireplace) on the face of wall square `wall` looking along `normal`, under `root`. Where the square
## in front of it holds something else (a table, a brazier), a deep piece is flattened to keep clear of it.
static func hang(board: ArenaBoard, root: Node3D, id: String, art: String, wall: Vector2i, normal: Vector2i,
		own := Vector2i(-9999, -9999)) -> Node3D:
	var info := manifest()[id] as Dictionary
	var holder := Node3D.new()
	holder.name = "Model_" + id
	var c := board.cell_center(wall)
	var n := Vector3(normal.x, 0, normal.y)
	holder.position = Vector3(c.x, board.floor_y(wall + normal), c.z) + n * (0.5 + GAP)
	holder.rotation.y = atan2(n.x, n.z)
	holder.set_meta("art", art)
	holder.set_meta("model", id)
	holder.set_meta("hung", true)
	root.add_child(holder)
	var model := instance(id)
	holder.add_child(model)
	var depth := float((info.get("size", [1, 1, 0.1]) as Array)[2])
	var front := wall + normal
	var tall := float((info.get("size", [1, 1, 0.1]) as Array)[1]) >= 0.85
	if board.occupied.has(front) and front != own and not tall and depth > 0.03:
		# A small piece (a crest, a plaque) over something standing against this wall (a throne) lies flat on it.
		model.scale.z = 0.03 / depth
		depth = 0.03
	elif depth > 0.2 and (board.grid.has_flag(front, CombatGrid.LOW) or (board.occupied.has(front) and front != own)):
		model.scale.z = 0.2 / depth
		depth = 0.2
	if str(info.get("mount", "wall")) != "wall":
		# A piece modelled round its middle (a door leaf hung as a picture) stands just in front of the face.
		model.position = Vector3(0, 0, depth / 2.0)
	_extras(model, info)
	return holder


## Wall piece `art` as a model for a house wall (TownBuilder's windows): its lowest point at the node, facing +z,
## its foot where the 2D piece's would be; null if there's no model.
static func wall_model(board: ArenaBoard, art: String) -> Node3D:
	var id := for_art(board, art)
	if id == "":
		return null
	var holder := Node3D.new()
	holder.name = "Model_" + id
	holder.set_meta("model", id)
	var model := instance(id)
	holder.add_child(model)
	_extras(model, manifest()[id] as Dictionary)
	var low := INF
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		low = minf(low, (mi.transform * mi.mesh.get_aabb()).position.y)
	if low < INF:
		model.position.y = -low
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
## Then the building kit's own (docs/art/building_kit.md): the place's interior style puts a face module (the castle's
## blind arcade, a church's plinth and string course) where no panelling does, and a moulded coping along the cut top
## of every open face; those are merged into one mesh. Added under one holder on the wall square, so it hides and
## shows with the wall.
## `top` is how high the wall stands (the coping goes along it): the cut-away height, or a full storey's (W8,
## InteriorWalls); `parent` takes the holder instead of the board (InteriorWalls keeps a wall's full and cut versions
## under one node on its square).
static func dress_wall(board: ArenaBoard, c: Vector2i, wall_mat: Material, top: float = CUT_TOP, parent: Node3D = null) -> void:
	if wall_mat == null or not in_use(board):
		return
	var id := ""
	for surface: String in settings().get("walls", {}):
		if Look.cel_textured(surface) == wall_mat:
			id = str((settings()["walls"] as Dictionary)[surface])
	if not has_model(id):
		id = ""
	var style := BuildingKit.interior_style(board)
	var face_id := "kit_%s_face" % style
	var coping := "kit_%s_coping" % style
	var kit_parts: Array = []
	var holder: Node3D = null
	for d: Vector2i in BACKS:
		var n := c + d
		if not board.grid.in_bounds(n) or board.grid.has_flag(n, CombatGrid.WALL) or board.grid.has_flag(n, CombatGrid.VOID):
			continue
		var dir := Vector3(d.x, 0, d.y)
		var foot := dir * (0.5 + GAP * 0.5) + Vector3(0, board.floor_y(n), 0)
		var yaw := atan2(dir.x, dir.z)
		if BuildingKit.has(coping):
			kit_parts.append([coping, Transform3D(Basis(Vector3.UP, yaw), foot + Vector3(0, top - CUT_TOP, 0))])
		if board.grid.in_bounds(n + d) and board.grid.has_flag(n + d, CombatGrid.WALL):
			continue   # a one-square gap in the wall: a doorway
		if id == "":
			if BuildingKit.has(face_id):
				kit_parts.append([face_id, Transform3D(Basis(Vector3.UP, yaw), foot)])
			continue
		if holder == null:
			holder = _wall_holder(board, c, id, parent)
		var face := instance(id)
		face.position = foot
		face.rotation.y = yaw
		holder.add_child(face)
	if kit_parts.is_empty():
		return
	if holder == null:
		holder = _wall_holder(board, c, "", parent)
	var mi := BuildingKit.merge(kit_parts)
	if mi != null:
		mi.name = "KitFaces"
		holder.add_child(mi)


static func _wall_holder(board: ArenaBoard, c: Vector2i, id: String, parent: Node3D = null) -> Node3D:
	var holder := Node3D.new()
	holder.name = "WallModules"
	holder.set_meta("wall_modules", id)
	if parent != null:
		parent.add_child(holder)   # the parent stands on the square
	else:
		holder.position = board.cell_center(c)
		board.add_child(holder)
	return holder


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
## 2D piece by pixel region and set at a socket, facing out) and the flame at a "flame" socket (a hearth's fire;
## SetDressing.flame, 3D in the Modern look, green in a green brazier).
static func _extras(model: Node3D, info: Dictionary) -> void:
	var sockets := info.get("sockets", {}) as Dictionary
	for key: String in sockets:
		if not key.begins_with("flame"):
			continue
		var at := sockets[key] as Array
		var f := SetDressing.flame(0.32, "bile" if "glow_bile" in (info.get("materials", []) as Array) else "")
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
			if bool(decal.get("lie", false)):
				sp.axis = Vector3.AXIS_Y   # lying on the floor (a rug)
			sp.rotation.y = deg_to_rad(float(decal.get("turn", 0.0)))   # 180: the back face of a door
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
			var key := "tint" if m.shader == SPRITE_SHADER else Look.tint_key(m)
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
