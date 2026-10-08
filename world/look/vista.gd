class_name Vista
extends Node3D
## What lies past a map's edge in the Modern look (Improvement Ideas W13, docs/art/atmosphere.md "Vistas"): the
## mountains round the valley as four painted ridges on a far ring, Castle Ravenloft on its crag at its true bearing
## from here, and Lake Zarovich stretching away where it's near. They're seen when the camera tilts toward the horizon
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
	var castle := cfg.get("castle", {}) as Dictionary
	var c_at := Vector2(float((castle["at"] as Array)[0]), float((castle["at"] as Array)[1]))
	var c_far := (here as Vector2).distance_to(c_at)
	if c_far > 0.02 and c_far < float(castle.get("within", 0.5)) and ResourceLoader.exists("res://" + str(castle["art"])):
		v._castle(castle, c_at - (here as Vector2), c_far)
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


## Castle Ravenloft on its crag, `toward` it on the travel art and `far` off: smaller and deeper in the haze the
## farther it is, its foot sunk below the land's edge.
func _castle(castle: Dictionary, toward: Vector2, far: float) -> void:
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
	mi.name = "CastleRavenloft"
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
