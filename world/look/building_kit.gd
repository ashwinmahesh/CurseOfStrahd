class_name BuildingKit
extends RefCounted
## The building kit (Improvement Ideas W7, docs/art/building_kit.md): Blender modules (blender/building_kit.py,
## art/models/kit) that TownBuilder puts a town's houses together from, one style per region: Barovian timber
## framing over plaster, Vallaki's painted clapboard, and coursed stone for Krezk and the Abbey. A house's modules are
## merged into a few meshes, one surface per material, so a village costs a handful of draws per house.

const MANIFEST_JSON := "res://art/models/kit/manifest.json"
const PAINTED_WOOD := "kit/painted_wood"
## A module no bigger than this across (x and z) and high is bent whole (merge's `whole_modules`): a wall face or a corner.
const WHOLE_ACROSS := 1.3
const WHOLE_HIGH := 3.4

static var _manifest: Dictionary = {}
static var _constants: Dictionary = {}
static var _meshes: Dictionary = {}
## Each module's surfaces as arrays in memory (Arrays), read from its mesh once: see `merge`.
static var _arrays: Dictionary = {}
## Each module's box, read once.
static var _extents: Dictionary = {}
## Merged meshes from earlier visits (a place comes out the same every time it is built), by the key their caller gave
## `merge` (a bent roof is 40,000 points of work): the newest KEPT_MESHES.
static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []
const KEPT_MESHES := 90


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
## With a `bend` (BuildingBend, natural maps B1) the merged mesh is bent once, here; `at` is where its node will stand in
## x and z when its parts are about its own middle (a yard wall's square), else the origin. With a `keep` key the mesh is
## kept for the next visit to the same place (the key says everything the mesh depends on). A small module goes whole
## when `whole_modules` is set (a house's wall faces: BuildingBend.fold, no work per vertex); everything else, the roofs,
## a palisade's logs, the core and the gables made in code, has its points moved one by one.
static func merge(parts: Array, paint: String = "", bend: BuildingBend = null, at: Vector2 = Vector2.ZERO,
		whole_modules: bool = false, keep: String = "") -> MeshInstance3D:
	if keep != "" and _kept.has(keep):
		var again := MeshInstance3D.new()
		again.mesh = _kept[keep] as Mesh
		return again
	var tools := {}
	var order: Array[String] = []
	for part: Array in parts:
		var m: Mesh = null
		var own := ""
		var repaint := ""
		var from: Mesh = null
		if part[0] is Mesh:
			m = part[0] as Mesh
			own = str(part[2])
			from = _primitive_arrays(m as PrimitiveMesh) if m is PrimitiveMesh else m
		else:
			m = mesh(str(part[0]))
			repaint = str((manifest().get(str(part[0]), {}) as Dictionary).get("paint", ""))
			from = _module_arrays(str(part[0]), m)
		if m == null:
			continue
		var xf := part[1] as Transform3D
		var by_points := false
		if bend != null:
			var box := _extent(str(part[0]), m) if whole_modules and not (part[0] is Mesh) else AABB()
			if box.size.x > 0.0 and maxf(box.size.x, box.size.z) <= WHOLE_ACROSS and box.size.y <= WHOLE_HIGH:
				xf = bend.fold(xf, box.get_center(), at)
			else:
				by_points = true
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
			if by_points:
				(tools[name] as SurfaceTool).append_from(_bent_surface(from, i, xf, bend, at), 0, Transform3D.IDENTITY)
			else:
				(tools[name] as SurfaceTool).append_from(from, i, xf)
	if order.is_empty():
		return null
	var am := ArrayMesh.new()
	for name in order:
		(tools[name] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, material(name))
	var mi := MeshInstance3D.new()
	mi.mesh = am
	if keep != "":
		_kept[keep] = am
		_kept_order.append(keep)
		while _kept_order.size() > KEPT_MESHES:
			_kept.erase(_kept_order.pop_front())
	return mi


## Forgets the kept meshes (a tool timing first arrivals, a test that changes what a place is built from).
static func forget() -> void:
	_kept.clear()
	_kept_order.clear()


## The box of module `id` (loaded once).
static func _extent(id: String, m: Mesh) -> AABB:
	if not _extents.has(id):
		_extents[id] = m.get_aabb()
	return _extents[id] as AABB


## Surface `i` of `from` (arrays in memory) placed by `xf` and then bent point by point: a one-surface mesh in memory,
## for SurfaceTool.append_from.
static func _bent_surface(from: Mesh, i: int, xf: Transform3D, bend: BuildingBend, at: Vector2) -> Mesh:
	var arrays := from.surface_get_arrays(i).duplicate()
	arrays[Mesh.ARRAY_VERTEX] = bend.bent(xf * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array), at)
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		var normals := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		var scale := xf.basis.get_scale()
		if absf(scale.x - 1.0) + absf(scale.y - 1.0) + absf(scale.z - 1.0) > 0.01:
			for k in normals.size():
				normals[k] = normals[k].normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	var a := Arrays.new()
	a.surfaces.append(arrays)
	a.primitives.append(Mesh.PRIMITIVE_TRIANGLES)
	return a


## Module `id`'s mesh `m` with its surfaces held in memory, read once a session.
static func _module_arrays(id: String, m: Mesh) -> Mesh:
	if m == null:
		return null
	if not _arrays.has(id):
		_arrays[id] = Arrays.of(m)
	return _arrays[id] as Mesh


## A box, cylinder or other primitive made in code with its surface held in memory, read once a session for each shape
## (a town's footings and copings come in a few hundred, mostly the same sizes).
static func _primitive_arrays(m: PrimitiveMesh) -> Mesh:
	var key := var_to_str(m)
	if not _arrays.has(key):
		_arrays[key] = Arrays.of(m)
	return _arrays[key] as Mesh


## A mesh whose surfaces are arrays held in memory, for SurfaceTool.append_from. Appending from a loaded mesh reads its
## arrays back from the GPU every time, a wait on the GPU per module of every house: 3.2 s of building the village,
## 4.2 s of Vallaki and 1 s of the castle's main floor in a window (the loading lane, 2026-10-08; headless keeps meshes
## in memory, so it never showed there).
class Arrays extends Mesh:
	var surfaces: Array[Array] = []
	var primitives: Array[int] = []

	static func of(m: Mesh) -> Arrays:
		var a := Arrays.new()
		for i in m.get_surface_count():
			a.surfaces.append(m.surface_get_arrays(i))
			a.primitives.append((m as ArrayMesh).surface_get_primitive_type(i) if m is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES)
		return a

	func _get_surface_count() -> int:
		return surfaces.size()

	func _surface_get_arrays(index: int) -> Array:
		return surfaces[index]

	func _surface_get_primitive_type(index: int) -> int:
		return primitives[index]

	func _surface_get_array_len(index: int) -> int:
		return (surfaces[index][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	func _surface_get_array_index_len(index: int) -> int:
		var ix: Variant = surfaces[index][Mesh.ARRAY_INDEX]
		return (ix as PackedInt32Array).size() if ix is PackedInt32Array else 0

	func _surface_get_format(_index: int) -> int:
		return 0

	func _surface_get_blend_shape_arrays(_index: int) -> Array[Array]:
		return [] as Array[Array]

	func _surface_get_lods(_index: int) -> Dictionary:
		return {}

	func _surface_get_material(_index: int) -> Material:
		return null

	func _surface_set_material(_index: int, _material: Material) -> void:
		pass

	func _get_blend_shape_count() -> int:
		return 0

	func _get_blend_shape_name(_index: int) -> StringName:
		return &""

	func _set_blend_shape_name(_index: int, _name: StringName) -> void:
		pass

	func _get_aabb() -> AABB:
		return AABB()


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
## Modern look, where the catalog turns them on, rooms get full-height walls with the ground outside (InteriorWalls,
## W8). False leaves the square to ArenaBoard's own cut-away wall.
static func interior_wall(board: ArenaBoard, c: Vector2i, wall_mat: Material) -> bool:
	if CampaignLook.current().claims(board, c):
		return true   # Castle Ravenloft's roofs: the castle's own walls (W19)
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
## room's floor (`floor`), taller than the cut-away walls; it stands solid and opens round the party when it hides it,
## as the walls do (SeeThrough: a faded pillar left the Amber Temple's glowing veins floating in the dark). False when
## the square isn't a lone pillar or the style has none, so ArenaBoard builds its block as before.
static func pillar(board: ArenaBoard, c: Vector2i, floor: Material) -> bool:
	var id := "kit_pillar_" + interior_style(board)
	if not has(id) or c.x <= 0 or c.y <= 0 or c.x >= board.grid.width - 1 or c.y >= board.grid.depth - 1:
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if board.grid.has_flag(c + d, CombatGrid.WALL) or board.grid.has_flag(c + d, CombatGrid.VOID):
			return false
	var at := board.cell_center(c)
	board.add_box("Floor", Vector3(1, 0.2, 1), Vector3(at.x, board.floor_y(c) - 0.1, at.z), floor).set_meta("on_floor", true)
	var mi := merge([[id, Transform3D(Basis(), Vector3(at.x, board.floor_y(c), at.z))]])
	if mi == null:
		return false
	mi.name = "Pillar"
	mi.set_meta("on_floor", true)   # (on the room's floor already: ArenaBoard._lift leaves it be on a hill)
	board.add_child(mi)
	SeeThrough.mark(mi)
	return true
