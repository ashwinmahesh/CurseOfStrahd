class_name BuildingKit
extends RefCounted
## The building kit (Improvement Ideas W7, docs/art/building_kit.md): Blender modules (blender/building_kit.py,
## art/models/kit) that TownBuilder puts a town's houses together from, one style per region: Barovian timber
## framing over plaster, Vallaki's painted clapboard, and coursed stone for Krezk and the Abbey. A house's modules are
## merged into a few meshes, one surface per material, so a village costs a handful of draws per house.

const MANIFEST_JSON := "res://art/models/kit/manifest.json"
const PAINTED_WOOD := "kit/painted_wood"

static var _manifest: Dictionary = {}
static var _constants: Dictionary = {}
static var _meshes: Dictionary = {}


## Every module: id -> {file, part, size, materials, span, rise, paint}.
static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_JSON):
		var data := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON)) as Dictionary
		_manifest = data.get("models", {}) as Dictionary
		_constants = data.get("constants", {}) as Dictionary
	return _manifest


## A number the modules were made to (H, LOW_TOP, FOOT, EAVE, VERGE).
static func constant(key: String) -> float:
	manifest()
	return float(_constants.get(key, 0.0))


static func has(id: String) -> bool:
	return manifest().has(id) and ResourceLoader.exists("res://" + str((manifest()[id] as Dictionary).get("file", "")))


## The catalog's kit settings (art/sprites/props/catalog.json "building_kit").
static func settings() -> Dictionary:
	return SetDressing.catalog().get("building_kit", {}) as Dictionary


## The style this board's houses are built in ("timber", "clapboard", "stone"), or "" for the plain boxes: the place's
## own style first, then the board theme's.
static func style_for(board: ArenaBoard) -> String:
	var cfg := settings()
	var style := str((cfg.get("places", {}) as Dictionary).get(board.place, (cfg.get("themes", {}) as Dictionary).get(board.theme, "")))
	return style if has("kit_%s_corner" % _short(style)) else ""


## Module ids use a short form of the style for walls (clap, not clapboard).
static func _short(style: String) -> String:
	return "clap" if style == "clapboard" else style


## A wall module's id for `style` and `part` ("low_a", "up_win", "door", "corner", "window_lit" ...).
static func wall_id(style: String, part: String) -> String:
	return "kit_%s_%s" % [_short(style), part]


## How high a roof of this style climbs over a span of `w` squares (the modules' own rise).
static func rise(style: String, kind: String, w: int) -> float:
	var info := manifest().get("kit_%s_%s_w%d" % [style, kind, w], {}) as Dictionary
	if info.has("rise"):
		return float(info["rise"])
	var pitch := float(((_constants.get("pitch", {}) as Dictionary).get(style, 0.9)))
	return clampf(w / 2.0 * pitch, 0.55, 3.2)


## The roof module for a span (and its end over a gable), or "" when the kit has none that wide.
static func roof_id(style: String, kind: String, w: int, end: bool) -> String:
	var id := "kit_%s_%s_w%d%s" % [style, kind, w, "_end" if end else ""]
	return id if has(id) else ""


## The mesh of module `id` (loaded once).
static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id] as Mesh
	var found: Mesh = null
	if has(id):
		var root := (load("res://" + str((manifest()[id] as Dictionary)["file"])) as PackedScene).instantiate()
		for n in root.find_children("*", "MeshInstance3D", true, false):
			found = (n as MeshInstance3D).mesh
			break
		root.free()
	_meshes[id] = found
	return found


## A house's modules merged into one mesh: `parts` is [[id, Transform3D], ...] (or [mesh, Transform3D, material
## name] for a mesh made in code); a module's `paint` surfaces take `paint` (a palette colour) instead. Each material
## is one surface. Null when nothing was drawn.
static func merge(parts: Array, paint: String = "") -> MeshInstance3D:
	var tools := {}
	var order: Array[String] = []
	for part: Array in parts:
		var m: Mesh = null
		var own := ""
		var repaint := ""
		if part[0] is Mesh:
			m = part[0] as Mesh
			own = str(part[2])
		else:
			m = mesh(str(part[0]))
			repaint = str((manifest().get(str(part[0]), {}) as Dictionary).get("paint", ""))
		if m == null:
			continue
		var xf := part[1] as Transform3D
		for i in m.get_surface_count():
			var name := own
			if name == "":
				var src := m.surface_get_material(i)
				name = src.resource_name if src != null else "pal_pewter"
			if repaint != "" and name == repaint and paint != "":
				name = "paint:" + paint
			if not tools.has(name):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[name] = st
				order.append(name)
			(tools[name] as SurfaceTool).append_from(m, i, xf)
	if order.is_empty():
		return null
	var am := ArrayMesh.new()
	for name in order:
		(tools[name] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, material(name))
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi


## The game's material for a module surface (ModelPiece's names: pal_, glow_, tex_), or a texture set by its own path
## ("interior/plaster_wall") for a house's core.
static func material(name: String) -> Material:
	if name.begins_with("paint:"):
		return painted(name.trim_prefix("paint:"))
	if name.contains("/"):
		var m := Look.cel_textured(name)
		return m if m != null else Look.cel("bone_dark")
	return ModelPiece.material(name)


static var _paints: Dictionary = {}


## A house's paint (Vallaki's clapboard): the kit's weathered painted wood (W4) tinted the palette colour `colour`,
## so each house is its own colour with the same worn, flaking paint; a flat colour where that wood isn't there.
static func painted(colour: String) -> Material:
	var key := "%s|%s" % [colour, Look.style()]
	if _paints.has(key):
		return _paints[key] as Material
	var base := Look.cel_textured(PAINTED_WOOD)
	var m: Material = null
	if base != null:
		var d := base.duplicate() as ShaderMaterial
		# The wood is pale grey, so its tint is the colour itself, lifted a little to keep it from going muddy.
		d.set_shader_parameter("tint", Look.color(colour).lightened(0.25))
		m = d
	else:
		m = Look.cel(colour)
	_paints[key] = m
	return m


## A transform on a wall face: at `base` (the face's foot), facing along `yaw`, stretched by `s` above `pivot`.
static func face_xf(base: Vector3, yaw: float, s: float = 1.0, pivot: float = 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0, s, 1.0))
	return Transform3D(b, base + Vector3(0, pivot * (1.0 - s), 0))


# --- Interiors ------------------------------------------------------------------------------------------------

## The interior style of a board (catalog building_kit "interiors"): the place's own (by the start of its id, so every
## room of Castle Ravenloft is "castle"), else its board theme's; "" for none.
static func interior_style(board: ArenaBoard) -> String:
	var cfg := settings().get("interiors", {}) as Dictionary
	var best := ""
	var best_len := 0
	for prefix: String in cfg.get("places", {}):
		if board.place.begins_with(prefix) and prefix.length() > best_len:
			best = str((cfg["places"] as Dictionary)[prefix])
			best_len = prefix.length()
	if best == "":
		best = str((cfg.get("themes", {}) as Dictionary).get(board.theme, ""))
	return best


## ArenaBoard's interior and dungeon wall squares come here (its one hook): a lone square is a pillar, and in the
## Modern look, where the catalog turns them on, rooms get full-height walls that cut away toward the camera with the
## ground outside (InteriorWalls, W8). False leaves the square to ArenaBoard's own cut-away wall.
static func interior_wall(board: ArenaBoard, c: Vector2i, wall_mat: Material) -> bool:
	var floor := board.floor_material()
	for d in SetDressing.FACES:
		var fb := board.floor_box(c + d) if board.grid.in_bounds(c + d) else null
		if fb != null:
			floor = fb.material_override   # the room's own floor, from a square beside it already built
			break
	if pillar(board, c, floor):
		return true
	return InteriorWalls.build(board, c, wall_mat)


## A lone wall square inside a room (no wall beside it) is a pillar in the board's interior style, standing on the
## room's floor (`floor`), taller than the cut-away walls and fading when it hides the party. False when the square
## isn't a lone pillar or the style has none, so ArenaBoard builds its block as before.
static func pillar(board: ArenaBoard, c: Vector2i, floor: Material) -> bool:
	var id := "kit_pillar_" + interior_style(board)
	if not has(id) or c.x <= 0 or c.y <= 0 or c.x >= board.grid.width - 1 or c.y >= board.grid.depth - 1:
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if board.grid.has_flag(c + d, CombatGrid.WALL) or board.grid.has_flag(c + d, CombatGrid.VOID):
			return false
	var at := board.cell_center(c)
	board.add_box("Floor", Vector3(1, 0.2, 1), Vector3(at.x, board.floor_y(c) - 0.1, at.z), floor)
	var mi := merge([[id, Transform3D(Basis(), Vector3(at.x, board.floor_y(c), at.z))]])
	if mi == null:
		return false
	mi.name = "Pillar"
	board.add_child(mi)
	ModelPiece.fade_with_trees(board, mi)
	return true
