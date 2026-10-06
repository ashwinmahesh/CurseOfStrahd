extends Node3D
## Art QA scene for P4-09 (docs/art/textures.md): each texture theme on 5 ft boxes with the cel lighting and the
## palette pass, plus the billboard props, one camera shot per theme. Not part of the game.
##   make capture SCENE=res://tools/art/preview/texture_preview.tscn NAME=p4_09_textures FRAMES=30

const SHADER := preload("res://tools/art/preview/world_uv_cel.gdshader")
const TEXTURES := "res://art/textures/manifest.json"
const PROPS := "res://art/sprites/props/manifest.json"
const SPACING := 40.0
const SHOTS: Array[String] = ["village", "vallaki", "tavern", "church", "dungeon"]

var _tex: Dictionary = {}
var _props: Dictionary = {}
var _camera: Camera3D


func _ready() -> void:
	_tex = (JSON.parse_string(FileAccess.get_file_as_string(TEXTURES)) as Dictionary)["themes"] as Dictionary
	_props = (JSON.parse_string(FileAccess.get_file_as_string(PROPS)) as Dictionary)["props"] as Dictionary
	_environment()
	_village(_origin(0))
	_vallaki(_origin(1))
	_tavern(_origin(2))
	_church(_origin(3))
	_dungeon(_origin(4))
	_camera = Camera3D.new()
	_camera.fov = 42.0
	add_child(_camera)
	_camera.current = true
	_camera.add_child(Look.make_post_process())
	_look_at(0)


func capture_shots(tool: Node, out: String) -> void:
	for i in SHOTS.size():
		_look_at(i)
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_%s.png" % [out, SHOTS[i]])


func _origin(i: int) -> Vector3:
	return Vector3(i * SPACING, 0, 0)


func _look_at(i: int) -> void:
	var c := _origin(i)
	_camera.position = c + Vector3(0, 8.5, 9.0)
	_camera.look_at(c + Vector3(0, 0.4, -0.6))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Look.color("void")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("bruise")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.color("moonlight")
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)


func _mat(key: String, band: bool = false) -> ShaderMaterial:
	var parts := key.split("/")
	var entry := (_tex[parts[0]] as Dictionary)[parts[1]] as Dictionary
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", load("res://" + str(entry["file"])) as Texture2D)
	m.set_shader_parameter("tile_units", float(entry["tile_world_units"]))
	m.set_shader_parameter("wall_band", band)
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)


## A floor of 1 x 1 cells; `pick` chooses each cell's material key.
func _floor(o: Vector3, w: int, d: int, pick: Callable) -> void:
	var cache := {}
	for z in d:
		for x in w:
			var key := str(pick.call(x, z))
			if not cache.has(key):
				cache[key] = _mat(key)
			_box(Vector3(1, 0.2, 1), o + Vector3(x - w / 2.0 + 0.5, -0.1, z - d / 2.0 + 0.5), cache[key] as Material)


func _wall_row(o: Vector3, x0: int, x1: int, z: float, h: float, mat: Material) -> void:
	for x in range(x0, x1):
		_box(Vector3(1, h, 1), o + Vector3(x + 0.5, h / 2.0, z), mat)


func _prop(id: String, pos: Vector3) -> void:
	var entry := _props[id] as Dictionary
	var s := Sprite3D.new()
	s.texture = load("res://" + str(entry["file"])) as Texture2D
	s.pixel_size = float(entry["pixel_size"])
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.shaded = true
	s.offset = Vector2(0, int(entry["height_px"]) / 2.0)
	s.position = pos
	add_child(s)


func _village(o: Vector3) -> void:
	_floor(o, 12, 9, func(x: int, z: int) -> String:
		if z == 4 or z == 5:
			return "village/cobbles"
		if x >= 8 and z > 5:
			return "village/mud_road"
		return "village/grass")
	var wall := _mat("village/house_wall")
	_wall_row(o, -6, -2, -3.5, 2.0, wall)
	_box(Vector3(4.1, 0.25, 1.1), o + Vector3(-4.0, 2.12, -3.5), _mat("village/roof_thatch"))
	_wall_row(o, 1, 5, -3.5, 2.0, wall)
	_box(Vector3(4.1, 0.25, 1.1), o + Vector3(3.0, 2.12, -3.5), _mat("village/roof_slate"))
	_prop("well", o + Vector3(-0.5, 0, -1.5))
	_prop("dead_tree", o + Vector3(-5.0, 0, 2.5))
	_prop("lantern_post", o + Vector3(1.2, 0, 0.0))
	_prop("market_stall", o + Vector3(-2.5, 0, 2.6))
	_prop("wagon", o + Vector3(3.6, 0, 2.8))
	_prop("pine", o + Vector3(5.6, 0, -2.0))


func _vallaki(o: Vector3) -> void:
	_floor(o, 12, 9, func(x: int, z: int) -> String:
		return "village/cobbles" if z >= 7 else "vallaki/cobbled_square")
	_wall_row(o, -6, 6, -4.0, 2.4, _mat("vallaki/palisade_logs"))
	_wall_row(o, -4, 0, -2.0, 2.0, _mat("vallaki/house_wall"))
	_box(Vector3(4.1, 0.25, 1.1), o + Vector3(-2.0, 2.12, -2.0), _mat("village/roof_slate"))
	_prop("barrel", o + Vector3(1.0, 0, -1.6))
	_prop("crate", o + Vector3(1.9, 0, -1.4))
	_prop("lantern_post", o + Vector3(-1.0, 0, 1.0))
	_prop("market_stall", o + Vector3(3.2, 0, 1.0))


func _tavern(o: Vector3) -> void:
	_floor(o, 12, 9, func(x: int, z: int) -> String:
		return "interior/rug" if (x >= 4 and x < 8 and z >= 3 and z < 6) else "interior/wood_planks")
	_wall_row(o, -6, 0, -4.0, 1.15, _mat("interior/plaster_wall"))
	var wainscot := _mat("interior/wainscot_wall", true)
	_wall_row(o, 0, 6, -4.0, 1.15, wainscot)
	_prop("table", o + Vector3(0.0, 0, 0.5))
	_prop("bed", o + Vector3(-4.0, 0, -2.0))
	_prop("bookshelf", o + Vector3(3.0, 0, -3.2))
	_prop("barrel", o + Vector3(-4.5, 0, 2.5))
	_prop("crate", o + Vector3(4.5, 0, 2.0))


func _church(o: Vector3) -> void:
	_floor(o, 12, 9, func(_x: int, _z: int) -> String:
		return "church/stone_flags")
	_wall_row(o, -6, 6, -4.0, 1.15, _mat("church/stone_wall"))
	_prop("gravestone", o + Vector3(-2.0, 0, 0.0))
	_prop("gravestone", o + Vector3(2.0, 0, 0.5))
	_prop("lantern_post", o + Vector3(0.0, 0, -2.5))


func _dungeon(o: Vector3) -> void:
	_floor(o, 12, 9, func(_x: int, _z: int) -> String:
		return "dungeon/stone_floor")
	_wall_row(o, -6, 0, -4.0, 1.15, _mat("dungeon/stone_wall"))
	_wall_row(o, 0, 6, -4.0, 1.15, _mat("dungeon/damp_brick"))
	_prop("crate", o + Vector3(-2.0, 0, -2.5))
	_prop("barrel", o + Vector3(2.5, 0, -2.5))
