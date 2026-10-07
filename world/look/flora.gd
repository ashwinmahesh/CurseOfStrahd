class_name Flora
extends RefCounted
## The Modern look's trees and plants (Improvement Ideas W9, docs/art/plants.md): Barovian spruces, dead trees, ferns,
## bracken, grass, undergrowth and reeds, modelled in Blender (blender/plants_3d.py) with leaf cards cut from a painted
## atlas, all swaying in the place's wind. AtmosphereLand plants them: the map's own trees, the trees of the land past
## its edge, and ground plants by the thousand over that land and the map's own wild ground. What grows where comes
## from art/plants/flora.json, by the place's mood. The Classic look keeps its old trees (frozen, owner 2026-10-07).
## Cosmetic only: the rules grid never sees any of it.

const MANIFEST_JSON := "res://art/plants/manifest.json"
const CONFIG_JSON := "res://art/plants/flora.json"
const FOLIAGE_SHADER := preload("res://shaders/atmosphere/foliage.gdshader")
const BARK_SHADER := preload("res://shaders/atmosphere/bark.gdshader")
const CARDS := preload("res://art/plants/cards.png")
## The plants are drawn in square chunks this many units a side, so the camera only draws the chunks it can see.
const CHUNK := 10.0
## How each kind of plant bends in the wind (wind.gdshaderinc `stiffness`, per unit of height squared) and how much
## its cards flutter.
const SWAY := {"tree": [0.010, 0.03], "dead": [0.008, 0.05], "fern": [0.9, 0.05], "grass": [2.4, 0.035],
	"bush": [0.5, 0.04], "reeds": [0.45, 0.03]}

static var _manifest: Dictionary = {}
static var _config: Dictionary = {}
static var _meshes: Dictionary = {}       ## plant id -> its Mesh, with the shared materials below
static var _materials: Dictionary = {}    ## "<material>|<kind>" -> ShaderMaterial

var set_id := "forest"
var spec: Dictionary = {}
var rng := RandomNumberGenerator.new()


## True where the Modern look's plants are drawn.
static func enabled() -> bool:
	return Look.modern() and FileAccess.file_exists(MANIFEST_JSON)


static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_JSON):
		_manifest = (JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON)) as Dictionary).get("plants", {}) as Dictionary
	return _manifest


static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_JSON)) as Dictionary
	return _config


## The set of plants for mood `mood_id`: its own, else the one of the mood it is `like`, else the forest's.
static func set_for(mood_id: String) -> String:
	var named := config().get("moods", {}) as Dictionary
	var moods := Atmosphere.moods().get("moods", {}) as Dictionary
	var id := mood_id
	for i in 8:
		if named.has(id):
			return str(named[id])
		id = str((moods.get(id, {}) as Dictionary).get("like", ""))
		if id == "":
			break
	return "forest"


## A set with what it is `like` filled in (its own lists win whole).
static func resolve(id: String) -> Dictionary:
	var own := ((config().get("sets", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)
	if not own.has("like"):
		return own
	var base := resolve(str(own["like"]))
	base.merge(own, true)
	base.erase("like")
	return base


## The plants for the place `board` stands for, in this mood's wind. Sets the shared materials' wind, tint and snow.
static func for_place(board: ArenaBoard, mood_id: String, mood: Dictionary) -> Flora:
	var f := Flora.new()
	f.set_id = set_for(mood_id)
	f.spec = resolve(f.set_id)
	f.rng.seed = hash(board.place + "/flora")   # cosmetic only, never rules
	var mist := mood.get("mist", {}) as Dictionary
	var w := mist.get("wind", [0.35, 0.12]) as Array
	var dir := Vector2(float(w[0]), float(w[1]))
	var strength := 0.12 + 0.38 * dir.length()
	for e: Variant in mood.get("weather", []) as Array:
		var kind := str((e as Dictionary).get("kind", "")) if e is Dictionary else str(e)
		if kind == "rain":
			strength += 0.1
	if bool(mood.get("lightning", false)):
		strength += 0.1
	f._apply(dir if dir.length() > 0.01 else Vector2(0.9, 0.35), clampf(strength, 0.08, 1.0))
	return f


func _apply(dir: Vector2, strength: float) -> void:
	var tint := Color(str(spec.get("tint", "#ffffff")))
	var snow := float(spec.get("snow", 0.0))
	var bark := spec.get("bark", {}) as Dictionary
	for key: String in _all_material_keys():
		var m := _material(key)
		m.set_shader_parameter("wind_dir", dir.normalized())
		m.set_shader_parameter("wind_strength", strength)
		if key.begins_with("leaf|"):
			m.set_shader_parameter("tint", tint)
			m.set_shader_parameter("snow", snow if key.ends_with("|tree") or key.ends_with("|dead") else snow * 0.6)
		else:
			var b := bark.get(key.get_slice("|", 0).trim_prefix("bark_"), []) as Array
			if b.size() >= 4:
				m.set_shader_parameter("ridge", Color(str(b[0])))
				m.set_shader_parameter("furrow", Color(str(b[1])))
				m.set_shader_parameter("lichen", Color(str(b[2])))
				m.set_shader_parameter("lichen_amount", float(b[3]))


static func _all_material_keys() -> Array[String]:
	var out: Array[String] = []
	for kind: String in SWAY:
		out.append("leaf|" + kind)
	for kind: String in ["tree", "dead"]:
		for bark: String in ["bark_spruce", "bark_dead"]:
			out.append(bark + "|" + kind)
	return out


static func _material(key: String) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	var kind := key.get_slice("|", 1)
	var sway := SWAY.get(kind, [0.01, 0.03]) as Array
	if key.begins_with("leaf"):
		m.shader = FOLIAGE_SHADER
		m.set_shader_parameter("cards", CARDS)
		# Ground plants are lit more evenly than a tree's crown, which shades its own inside.
		m.set_shader_parameter("shade_floor", 0.4 if kind in ["tree", "dead"] else 0.6)
	else:
		m.shader = BARK_SHADER
	m.set_shader_parameter("stiffness", float(sway[0]))
	m.set_shader_parameter("flutter_amount", float(sway[1]))
	_materials[key] = m
	return m


## Plant `id`'s mesh with the game's materials on it (the leaf atlas and bark), or null.
static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id] as Mesh
	var info := manifest().get(id, {}) as Dictionary
	if info.is_empty() or not ResourceLoader.exists("res://" + str(info.get("file", ""))):
		return null
	var root := (load("res://" + str(info["file"])) as PackedScene).instantiate()
	var src: Mesh = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		src = (n as MeshInstance3D).mesh
		break
	root.free()
	if src == null:
		return null
	var kind := str(info.get("kind", "tree"))
	var out := src.duplicate() as Mesh
	out.resource_name = id
	for i in out.get_surface_count():
		var mat := out.surface_get_material(i)
		var name := mat.resource_name if mat != null else "leaf"
		out.surface_set_material(i, _material(("leaf" if name.begins_with("leaf") else name) + "|" + kind))
	_meshes[id] = out
	return out


static func height_of(id: String) -> float:
	return float(((manifest().get(id, {}) as Dictionary).get("size", [1, 3, 1]) as Array)[1])


## The plant standing in for 2D tree art `kind` ("pine", "dead_tree") here, picked by `pick`; "" if this set has none.
func tree_for(kind: String, pick: int) -> String:
	var options := (spec.get("trees", {}) as Dictionary).get(kind, []) as Array
	if options.is_empty():
		return ""
	var id := str(options[posmod(pick, options.size())])
	return id if mesh(id) != null else ""


## How much to scale tree `id` in the map (`where` "map") or on the land ("land"), picked by `pick`: a share of its
## modelled height from the set's `scale`, kept between its `shortest` and `tallest` there (the map's trees stay 10 to
## 20 ft, as the old ones were, so they don't wall in the squares beside them).
func tree_scale(id: String, where: String, pick: int) -> float:
	var r := (spec.get("scale", {}) as Dictionary).get(where, [0.9, 1.1]) as Array
	var s := lerpf(float(r[0]), float(r[1]), float(posmod(pick * 7919, 1000)) / 1000.0)
	var h := maxf(height_of(id), 0.1)
	var shortest := float((spec.get("shortest", {}) as Dictionary).get(where, 0.0))
	var tallest := float((spec.get("tallest", {}) as Dictionary).get(where, 100.0))
	return clampf(s, shortest / h, tallest / h)


## A plant as its own node: a tree the map stands on its squares, or one of the land's first rows (they fade when they
## stand between the camera and the party).
func node(id: String, at: Vector3, s: float, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Plant_" + id
	holder.position = at
	holder.rotation.y = yaw
	holder.set_meta("model", id)
	holder.set_meta("nature", true)
	holder.add_child(instance(id, s))
	return holder


static func instance(id: String, s: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh(id)
	mi.scale = Vector3.ONE * s
	return mi


## Draws many copies of plants, grouped by chunk so the camera culls them: `items` is plant id -> Array of
## [Transform3D, Color]. Trees cast shadows where `shadows` says so. Each chunk keeps where its copies stand (meta
## "origins"), since a MultiMesh without a renderer (headless) keeps none.
static func plant_all(parent: Node3D, items: Dictionary, shadows: bool, label: String) -> void:
	for id: String in items:
		var m := mesh(id)
		if m == null:
			continue
		var chunks := {}
		for it: Array in items[id] as Array:
			var t := it[0] as Transform3D
			var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
			if not chunks.has(key):
				chunks[key] = []
			(chunks[key] as Array).append(it)
		for key: Vector2i in chunks:
			var list := chunks[key] as Array
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = m
			mm.instance_count = list.size()
			var origins := PackedVector3Array()
			for i in list.size():
				var t := (list[i] as Array)[0] as Transform3D
				mm.set_instance_transform(i, t)
				mm.set_instance_color(i, (list[i] as Array)[1] as Color)
				origins.append(t.origin)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s_%d_%d" % [label, id, key.x, key.y]
			mmi.multimesh = mm
			mmi.set_meta("origins", origins)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)


## A plant from weighted list `choices` ([[id, weight], ...]), or "".
func pick_from(choices: Array) -> String:
	var total := 0.0
	for c: Array in choices:
		total += float(c[1])
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for c: Array in choices:
		r -= float(c[1])
		if r <= 0.0:
			return str(c[0])
	return str((choices[-1] as Array)[0])


## How many plants a list puts on a square, in all.
static func density(choices: Array) -> float:
	var total := 0.0
	for c: Array in choices:
		total += float(c[1])
	return total


## A copy of a ground plant: turned its own way, a little bigger or smaller, a touch lighter or darker.
func ground_item(at: Vector3, s: float) -> Array:
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s * rng.randf_range(0.75, 1.2))
	var v := rng.randf_range(0.82, 1.08)
	return [Transform3D(b, at), Color(v, v * rng.randf_range(0.97, 1.03), v * rng.randf_range(0.92, 1.0))]


## Ground plants on the map's own squares: thick under its trees, ferns and undergrowth spilling out of the woods
## onto the side of a square that faces them, short and sparse grass elsewhere where people walk on wild ground
## (never in the middle of a square, so feet and the selection rings stay clear), reeds on the shore. Squares a
## location's things stand on, buildings and furniture are left bare.
func dress_map(board: ArenaBoard, parent: Node3D) -> void:
	var g := board.grid
	var under := spec.get("under", []) as Array
	var open := spec.get("open", []) as Array
	var shore := spec.get("shore", []) as Array
	var edge := spec.get("edge", []) as Array
	var wild := board.theme in ArenaBoard.WILD
	var open_scale := float(spec.get("open_scale", 0.6))
	var items := {}
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if board.occupied.has(c) or board.house_cells.has(c) or board.door_cells.has(c):
				continue
			var f := g.flags(c)
			if (f & (CombatGrid.WATER | CombatGrid.VOID)) != 0:
				continue
			if board.is_tree(c):
				_scatter_square(items, c, under, 1.0, 0.0, 0.0)
				continue
			if (f & CombatGrid.WALL) != 0 or not wild or board.floor_y(c) > 0.0:
				continue
			if board.dressing.has(c) and not (board.dressing[c] as Array).is_empty():
				continue
			var by_water := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if g.in_bounds(c + d) and g.has_flag(c + d, CombatGrid.WATER):
					by_water = true
			var woods := Vector2.ZERO
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1),
					Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if g.in_bounds(c + d) and board.is_tree(c + d):
					woods += Vector2(d)
			if by_water and not shore.is_empty():
				_scatter_square(items, c, shore, 0.8, 0.3, 0.0)
			elif woods != Vector2.ZERO and not edge.is_empty():
				_scatter_edge(items, c, edge, woods.normalized())
			else:
				_scatter_square(items, c, open, open_scale, 0.32, 0.0)
	plant_all(parent, items, false, "MapPlants")


## Scatters `choices` along the side of square `c` toward `toward` (the woods beside it), in a band from 0.3 to 0.5
## off its middle.
func _scatter_edge(items: Dictionary, c: Vector2i, choices: Array, toward: Vector2) -> void:
	var n := density(choices)
	var count := floori(n) + (1 if rng.randf() < n - floorf(n) else 0)
	var across := Vector2(-toward.y, toward.x)
	for i in count:
		var id := pick_from(choices)
		if id == "":
			continue
		var p := Vector2(0.5, 0.5) + toward * rng.randf_range(0.32, 0.5) + across * rng.randf_range(-0.45, 0.45)
		p = p.clamp(Vector2(0.02, 0.02), Vector2(0.98, 0.98))
		if (p - Vector2(0.5, 0.5)).length() < 0.3:
			continue
		if not items.has(id):
			items[id] = []
		(items[id] as Array).append(ground_item(Vector3(c.x + p.x, 0.0, c.y + p.y), 0.85))


## Scatters `choices` over square `c` (its density per square), keeping `clear` units off the square's middle.
func _scatter_square(items: Dictionary, c: Vector2i, choices: Array, s: float, clear: float, y: float) -> void:
	var n := density(choices)
	var count := floori(n) + (1 if rng.randf() < n - floorf(n) else 0)
	for i in count:
		var id := pick_from(choices)
		if id == "":
			continue
		var p := Vector2(rng.randf(), rng.randf())
		if clear > 0.0:
			# Pushed out toward the square's edges and corners.
			var off := p - Vector2(0.5, 0.5)
			if off.length() < clear:
				off = (off.normalized() if off.length() > 0.01 else Vector2.RIGHT.rotated(rng.randf() * TAU)) * rng.randf_range(clear, 0.5)
			p = Vector2(0.5, 0.5) + off
		var at := Vector3(c.x + p.x, y, c.y + p.y)
		if not items.has(id):
			items[id] = []
		(items[id] as Array).append(ground_item(at, s))
