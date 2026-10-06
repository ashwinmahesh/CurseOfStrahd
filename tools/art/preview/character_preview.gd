extends Node3D
## Art QA scene for character walk sheets and portraits (docs/art/p4_cast_art_pass.md): a line-up of DirectionalSprites
## on a cobbled floor with the cel lighting and the palette pass, and each character's portraits on a UI layer (drawn
## after the pass, like the dialogue frame). Not part of the game.
##   make capture SCENE=res://tools/art/preview/character_preview.tscn NAME=p4_cast FRAMES=30
## Running Godot directly, `-- --ids=a,b,c` shows other sheets.

## Suggested height_units for this pass's sheets, in CombatToken.HEIGHTS units (a human is about 1.2 to 1.3).
const HEIGHTS := {"milivoj": 1.3, "henrik": 1.22, "gunther_arasek": 1.3, "luvash": 1.38, "arabelle": 0.75,
	"kasimir_velikov": 1.32, "bluto": 1.22, "stanimir": 1.38, "arrigal": 1.3, "vistana": 1.22}
const DEFAULT_IDS: Array[String] = ["milivoj", "henrik", "gunther_arasek", "luvash", "arabelle", "kasimir_velikov",
	"bluto", "stanimir"]
const MOODS := ["neutral", "smile", "angry", "afraid", "sad", "sly", "weary"]
const SPACING := 1.55

var _camera: Camera3D
var _ids: Array[String] = []
var _sprites: Array[DirectionalSprite] = []
var _strip: CanvasLayer


func _ready() -> void:
	_ids = DEFAULT_IDS.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			_ids.assign(Array(a.get_slice("=", 1).split(",", false)))
	_environment()
	_floor()
	for i in _ids.size():
		var path := "res://art/sprites/%s/walk.tres" % _ids[i]
		if not ResourceLoader.exists(path):
			push_warning("no walk sheet: " + path)
			continue
		var s := DirectionalSprite.create(load(path) as SpriteFrames, float(HEIGHTS.get(_ids[i], 1.25)))
		s.position = Vector3((i - (_ids.size() - 1) / 2.0) * SPACING, 0, 0)
		add_child(s)
		_sprites.append(s)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	add_child(_camera)
	_camera.current = true
	_camera.add_child(Look.make_post_process())
	_strip = _portrait_strip()
	add_child(_strip)
	_wide()


func capture_shots(tool: Node, out: String) -> void:
	_wide()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_lineup.png")
	# Walking in place, each one facing a different one of the 8 directions.
	for i in _sprites.size():
		var a := deg_to_rad(45.0 * ((i + 1) % 8))
		_sprites[i].facing = Vector3(sin(a), 0, cos(a))
		_sprites[i].moving = true
	await tool.call("wait_frames", 23)
	tool.call("_shot", out + "_walk.png")
	for s in _sprites:
		s.facing = Vector3.BACK
		s.moving = false
	_strip.visible = false
	_close(int(_sprites.size() / 2.0) - 1)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_close.png")


func _wide() -> void:
	_camera.position = Vector3(0, 2.6, 10.5)
	_camera.look_at(Vector3(0, 0.15, 0))


## Close on three neighbours, centred on the middle one.
func _close(i: int) -> void:
	var x := (i + 1 - (_ids.size() - 1) / 2.0) * SPACING
	_camera.position = Vector3(x, 1.25, 4.4)
	_camera.look_at(Vector3(x, 0.75, 0))


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
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)


func _floor() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(16, 0.2, 8)
	mi.mesh = bm
	mi.position = Vector3(0, -0.1, -1.5)
	var mat: Material = Look.cel_textured("village/cobbles")
	mi.material_override = mat if mat != null else Look.cel("grave")
	add_child(mi)


## Each character's portraits (the default face, then its moods), with the name underneath.
func _portrait_strip() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -132
	row.offset_bottom = -8
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _ids:
		var col := VBoxContainer.new()
		var faces := HBoxContainer.new()
		faces.add_theme_constant_override("separation", 2)
		for mood: String in MOODS:
			var path := "res://art/portraits/%s.png" % id if mood == "neutral" else "res://art/portraits/%s_%s.png" % [id, mood]
			if not ResourceLoader.exists(path):
				continue
			var tr := TextureRect.new()
			tr.texture = load(path) as Texture2D
			tr.custom_minimum_size = Vector2(86, 86)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			faces.add_child(tr)
		col.add_child(faces)
		var label := Label.new()
		label.text = id
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Look.color("vellum"))
		label.add_theme_font_size_override("font_size", 13)
		col.add_child(label)
		row.add_child(col)
	layer.add_child(row)
	return layer
