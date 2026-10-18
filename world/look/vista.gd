class_name Vista
extends Node3D
## What lies past a map's edge in the Modern look (Improvement Ideas W13, docs/art/atmosphere.md "Vistas"): the
## mountains round the valley as four painted ridges on a far ring, Castle Ravenloft on its crag at its true bearing
## from here (or as near it as the tilted camera frames, on_skyline), the regions' own landmarks (Mount Ghakis, Krezk
## on its cliff, Vallaki's palisade ...) where they're near, and Lake Zarovich stretching away where it's near. They're seen when the camera tilts toward the horizon
## past its farthest zoom (CameraRig.horizon); in play they lie past the camera's far plane and cost nothing.
## They draw after the screen pass (blended, Look.make_post_process draws first among those), so the land's fade
## into the haze doesn't swallow them; nearer land and trees still hide them. Each frame they take the haze colour the
## screen pass gives the far land, so they sit in the same air at every hour. Places and sizes: art/vistas/vistas.json.

const CONFIG_JSON := "res://art/vistas/vistas.json"
const RING_SHADER := preload("res://shaders/atmosphere/vista.gdshader")
const CARD_SHADER := preload("res://shaders/atmosphere/vista_card.gdshader")
const LAKE_SHADER := preload("res://shaders/atmosphere/vista_lake.gdshader")
## Their order among blended things after the screen pass: the farthest first.
const RING_PRIORITY := 1
const LAKE_PRIORITY := 2
const CARD_PRIORITY := 3
## How many of the regions' painted landmarks a place shows at most (the nearest), besides the castle.
const MAX_LANDMARKS := 4
## A landmark whose bearing is closer than this (radians) to one already shown stands aside, so none hides another.
const SPREAD := 0.22
## How far either side of a diagonal a landmark's middle may stand on the skyline (radians, 18 degrees). The play camera
## only ever looks along a diagonal (north-east, north-west, south-west, south-east), and tilted to the horizon its
## frame reaches about 24 degrees either side on a 16:10 screen (27 on 16:9): this keeps even a broad mountain's
## middle well inside, so a landmark due north, east, south or west of a place still shows (on_skyline).
const IN_VIEW := PI / 10.0

static var _config: Dictionary = {}

var centre := Vector3.ZERO
var _materials: Array[ShaderMaterial] = []
var _post: ShaderMaterial = null
var _haze := Color(-1, -1, -1)


static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_JSON)) as Dictionary
	return _config


## Where a place lies on the travel art (x east, y south, fractions), or null if it isn't on it.
static func place_at(place: String) -> Variant:
	var at: Variant = (config().get("places", {}) as Dictionary).get(place, null)
	if at == null:
		return null
	return Vector2(float((at as Array)[0]), float((at as Array)[1]))


## The vistas round `board`'s place, in the mountains of plant set `set_id` (art/plants/flora.json); null if the
## place isn't on the travel art.
static func build(board: ArenaBoard, set_id: String) -> Vista:
	var here: Variant = place_at(board.place)
	if here == null:
		return null
	var cfg := config()
	var v := Vista.new()
	v.name = "Vista"
	v.centre = Vector3(board.grid.width / 2.0, 0.0, board.grid.depth / 2.0)
	var styles := cfg.get("styles", {}) as Dictionary
	v._ring(styles.get(set_id, styles.get("forest", {})) as Dictionary, float(cfg.get("radius", 230.0)))
	var castle := seen_from(cfg.get("castle", {}) as Dictionary, board.place)   # (its `from` for a place that sees it from afar)
	var c_at := Vector2(float((castle["at"] as Array)[0]), float((castle["at"] as Array)[1]))
	var c_far := (here as Vector2).distance_to(c_at)
	var taken: Array[float] = []
	if c_far > 0.02 and c_far < float(castle.get("within", 0.5)) and ResourceLoader.exists("res://" + str(castle["art"])):
		var way := on_skyline(c_at - (here as Vector2), taken)
		v._card("CastleRavenloft", castle, Vector2.from_angle(way), c_far)
		taken.append(way)
	v._landmarks(cfg.get("landmarks", {}) as Dictionary, here as Vector2, taken, board.place)
	var lake := cfg.get("lake", {}) as Dictionary
	var l_at := Vector2(float((lake["at"] as Array)[0]), float((lake["at"] as Array)[1]))
	if (here as Vector2).distance_to(l_at) < float(lake.get("within", 0.15)):
		v._lake(lake, l_at - (here as Vector2))
	return v


## The mountains: a ring round the map's middle, open at top and foot, painted by vista.gdshader.
func _ring(style: Dictionary, radius: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 120.0
	cyl.radial_segments = 160
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var m := _material(RING_SHADER, RING_PRIORITY)
	m.set_shader_parameter("centre", centre)
	var layers := style.get("layers", []) as Array
	for i in mini(layers.size(), 4):
		var l := layers[i] as Array
		m.set_shader_parameter("ridge%d" % i, Vector4(float(l[0]), float(l[1]), float(l[2]), float(l[3])))
	m.set_shader_parameter("snow_line", float(style.get("snow_line", 40.0)))
	m.set_shader_parameter("treeline", float(style.get("treeline", 0.5)))
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = cyl
	mi.material_override = m
	mi.position = centre + Vector3(0, 20.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The regions' landmarks (the vault's Region Variety Plan: a place's own thing on the horizon, not only the castle):
## the nearest few within their `within` on the travel art, leaving out a place's own (nearer than `near`) and any
## with no room left in the camera's view beside those already shown. A landmark is placed as seen from this place
## (seen_from), where the tilted camera frames it (on_skyline).
func _landmarks(all: Dictionary, here: Vector2, taken: Array[float], place: String) -> void:
	var seen: Array = []
	for id: String in all:
		var spec := seen_from(all[id] as Dictionary, place)
		var at := Vector2(float((spec["at"] as Array)[0]), float((spec["at"] as Array)[1]))
		var toward := at - here
		if spec.has("bearing"):
			var turn := deg_to_rad(float(spec["bearing"]))
			toward = Vector2(sin(turn), -cos(turn)) * float(spec.get("far", toward.length()))
		var far := toward.length()
		if far > float(spec.get("near", 0.02)) and far < float(spec.get("within", 0.3)) \
				and ResourceLoader.exists("res://" + str(spec["art"])):
			seen.append([far, id, toward, spec])
	seen.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var shown := 0
	for e: Array in seen:
		if shown >= MAX_LANDMARKS:
			break
		var way := on_skyline(e[2] as Vector2, taken)
		if is_nan(way):
			continue
		taken.append(way)
		_card("Landmark_" + str(e[1]), e[3] as Dictionary, Vector2.from_angle(way), float(e[0]))
		shown += 1


## Which way a landmark truly `toward` stands on the skyline (an angle, as Vector2.angle: x east, y south): where it
## is, if the tilted camera frames it there, else turned into the arc the camera frames round the nearest diagonal
## (IN_VIEW either side), on its own side of that diagonal. Due north of a place, where the camera never looks, a
## landmark stands a little east or west of north, the way it leans (Mount Baratok from Krezk). Where one already
## `taken` stands within SPREAD, it stands just past that one instead, on whichever side is nearer its true way while
## still in the arc; NAN when there's no room.
static func on_skyline(toward: Vector2, taken: Array[float]) -> float:
	var truly := toward.angle()
	var diagonal := floorf(truly / (PI / 2.0)) * (PI / 2.0) + PI / 4.0
	var tries: Array[float] = [diagonal + clampf(angle_difference(diagonal, truly), -IN_VIEW, IN_VIEW)]
	for t: float in taken:
		tries.append(t + SPREAD)
		tries.append(t - SPREAD)
	var best := NAN
	for way: float in tries:
		if absf(angle_difference(diagonal, way)) > IN_VIEW + 0.001:
			continue
		var clear := true
		for t: float in taken:
			if absf(angle_difference(t, way)) < SPREAD - 0.001:
				clear = false
		if clear and (is_nan(best) or absf(angle_difference(truly, way)) < absf(angle_difference(truly, best))):
			best = way
	return best


## A landmark as seen from `place`: its own numbers, with its `from` entry for that place laid over them where a place's
## own map knows better than the travel art. There `bearing` is the way it stands from that place (degrees clockwise
## from north) instead of its bearing on the travel art, `far` how far off it seems (travel-art units), and `height`
## and `sink` its size and how deep its foot sinks. The Abbey of St. Markovia is due north of Krezk on the travel art;
## from Krezk's maps it stands north-north-east instead, up the mountain the track to it climbs, where the camera's
## first view finds it, and Krezk south-south-west of the Abbey's.
static func seen_from(spec: Dictionary, place: String) -> Dictionary:
	var from: Variant = (spec.get("from", {}) as Dictionary).get(place, null)
	return spec.merged(from as Dictionary, true) if from is Dictionary else spec


## A painted landmark (Castle Ravenloft on its crag, a mountain, a town on its cliff), `toward` it on the skyline
## and `far` off on the travel art: smaller and deeper in the haze the farther it is, its foot sunk below the land's edge.
func _card(node_name: String, castle: Dictionary, toward: Vector2, far: float) -> void:
	var tex := load("res://" + str(castle["art"])) as Texture2D
	var near := clampf(0.3 / maxf(far, 0.01), 0.45, 1.0)
	var h := float(castle.get("height", 26.0)) * near
	var quad := QuadMesh.new()
	quad.size = Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)
	quad.center_offset = Vector3(0, h / 2.0, 0)
	var m := _material(CARD_SHADER, CARD_PRIORITY)
	m.set_shader_parameter("art", tex)
	m.set_shader_parameter("hazing", clampf(0.12 + far * 0.5, 0.12, 0.6))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = quad
	mi.material_override = m
	var dir := toward.normalized()
	mi.position = centre + Vector3(dir.x, 0, dir.y) * float(castle.get("distance", 170.0)) \
		- Vector3(0, float(castle.get("sink", 7.0)) * near, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Lake Zarovich `toward` it, lying across the view.
func _lake(lake: Dictionary, toward: Vector2) -> void:
	var size := lake.get("size", [80, 46]) as Array
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(size[0]), float(size[1]))
	var m := _material(LAKE_SHADER, LAKE_PRIORITY)
	var mi := MeshInstance3D.new()
	mi.name = "LakeZarovich"
	mi.mesh = plane
	mi.material_override = m
	var dir := toward.normalized() if toward.length() > 0.001 else Vector2(0, -1)
	mi.position = centre + Vector3(dir.x, 0, dir.y) * float(lake.get("distance", 95.0)) - Vector3(0, 0.4, 0)
	# Its long side across the line of sight.
	mi.rotation.y = atan2(dir.x, dir.y) + PI / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _material(shader: Shader, priority: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = priority
	_materials.append(m)
	return m


## The haze colour of the far land, from the screen pass that draws it (a child of the camera).
func _find_post() -> ShaderMaterial:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return null
	for n in cam.get_children():
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var m := mi.material_override if mi.material_override != null else (mi.mesh.surface_get_material(0) if mi.mesh != null else null)
			if m is ShaderMaterial and (m as ShaderMaterial).shader == Look.POST_SHADER:
				return m as ShaderMaterial
	return null


func _process(_delta: float) -> void:
	if _post == null or not is_instance_valid(_post):
		_post = _find_post()
		if _post == null:
			return
	var c: Variant = _post.get_shader_parameter("land_color")
	if not (c is Color) or (c as Color).is_equal_approx(_haze):
		return
	_haze = c as Color
	var shade := _haze.darkened(0.85)
	var rim := _haze.lightened(0.25)
	for m in _materials:
		m.set_shader_parameter("haze", _haze)
		m.set_shader_parameter("shade", shade)
		m.set_shader_parameter("rim", rim)
		m.set_shader_parameter("deep", _haze.darkened(0.8))
