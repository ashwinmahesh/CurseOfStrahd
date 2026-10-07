class_name Atmosphere
extends Node
## How a place looks as a whole (docs/art/atmosphere.md): its light by time of day (a key light from the moon or a low
## sun, ambient light and sky colours), contact shadows, the screen pass's ground mist, cloud shadows, colour grade and
## vignette, water, the land drawn around the map so it never floats in a void (AtmosphereLand) and its weather
## (AtmosphereWeather). Each place has a mood in art/atmosphere/moods.json. It changes nothing the rules see.
##
## A plain Node, so HiddenAreas never treats its sun or its weather as something standing on a square; anything here
## that belongs to one square (a window's light, a chimney's smoke, a fire's embers) hangs on that square's piece so
## it hides with it.

const MOODS_JSON := "res://art/atmosphere/moods.json"
const WATER_SHADER := preload("res://shaders/atmosphere/water.gdshader")
## Seconds a change in the time of day takes to settle.
const TRANSITION := 3.0
## Lights that light the mist around them (the screen pass takes this many).
const MAX_GLOWS := 8
## The map's light level scales the ambient light (and the key light indoors).
const LEVELS := {"bright": 1.6, "dim": 1.0, "dark": 0.55}

static var _moods: Dictionary = {}

var env: Environment
var sun: DirectionalLight3D
var mood: Dictionary = {}
var mood_id := ""
var phase := ""
var board: ArenaBoard
var loc: Dictionary = {}
var outdoors := false
var light_level := "dim"
var land: AtmosphereLand = null
var weather: AtmosphereWeather = null
var water: ShaderMaterial = null

var _post: ShaderMaterial = null
var _rig: CameraRig = null
var _from: Dictionary = {}
var _to: Dictionary = {}
var _blend := 1.0
var _time := 0.0
var _lights: Array[OmniLight3D] = []
var _light_scan := 0.0
var _flash := 0.0
var _next_flash := 0.0
var _rng := RandomNumberGenerator.new()


static func create(loc_id: String, loc_: Dictionary, board_: ArenaBoard) -> Atmosphere:
	var a := Atmosphere.new()
	a.name = "Atmosphere"
	a.loc = loc_
	a.board = board_
	a.outdoors = bool((loc_.get("map", {}) as Dictionary).get("outdoors", false))
	a.light_level = str((loc_.get("map", {}) as Dictionary).get("light", "dim"))
	a.mood_id = mood_for(loc_id, loc_)
	a.mood = resolve(a.mood_id)
	a._rng.seed = hash(loc_id)   # cosmetic only, never rules
	a._build()
	return a


static func moods() -> Dictionary:
	if _moods.is_empty():
		_moods = JSON.parse_string(FileAccess.get_file_as_string(MOODS_JSON)) as Dictionary
	return _moods


## The mood a location uses: its own (`places`), else the longest of `prefixes` its id starts with, else its region's
## (`regions`: "<region>", or "<region>/indoors" for its indoor maps), else its map theme's (`themes`, the same way),
## else the outdoor or indoor default.
static func mood_for(loc_id: String, loc_: Dictionary) -> String:
	var m := moods()
	var places := m.get("places", {}) as Dictionary
	if places.has(loc_id):
		return str(places[loc_id])
	var best := ""
	for pre: String in m.get("prefixes", {}) as Dictionary:
		if loc_id.begins_with(pre) and pre.length() > best.length():
			best = pre
	if best != "":
		return str((m["prefixes"] as Dictionary)[best])
	var map := loc_.get("map", {}) as Dictionary
	var outdoor := bool(map.get("outdoors", false))
	var suffix := "" if outdoor else "/indoors"
	var regions := m.get("regions", {}) as Dictionary
	var region := str(loc_.get("region", ""))
	if regions.has(region + suffix):
		return str(regions[region + suffix])
	var themes := m.get("themes", {}) as Dictionary
	var theme := str(map.get("theme", ""))
	if themes.has(theme + suffix):
		return str(themes[theme + suffix])
	return str(m.get("outdoors" if outdoor else "indoors", "indoors"))


## A mood with what it's `like` filled in (nested settings merge; its own win).
static func resolve(id: String) -> Dictionary:
	var all := moods().get("moods", {}) as Dictionary
	var own := all.get(id, {}) as Dictionary
	if not own.has("like"):
		return own.duplicate(true)
	var base := resolve(str(own["like"]))
	_merge(base, own)
	base.erase("like")
	return base


static func _merge(into: Dictionary, over: Dictionary) -> void:
	for k: Variant in over:
		if into.get(k) is Dictionary and over[k] is Dictionary:
			_merge(into[k] as Dictionary, over[k] as Dictionary)
		else:
			into[k] = over[k] if not (over[k] is Dictionary or over[k] is Array) else (over[k] as Variant).duplicate(true)


static func _vec2(v: Variant) -> Vector2:
	var a := v as Array
	return Vector2(float(a[0]), float(a[1]))


# --- Building -------------------------------------------------------------------------------------

func _build() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Distance is normally the screen pass's job (the land fading past the map's edge, the mist): Godot's depth fog
	# draws rings around the camera once the palette snap bands it. A mood may still ask for a light haze.
	var haze := float(mood.get("fog_density", 0.0))
	env.fog_enabled = haze > 0.0
	env.fog_density = haze
	# Contact shadows where things meet the ground and walls meet floors (the palette snap makes them flat bands).
	var ao := float(mood.get("ambient_occlusion", 0.0))
	env.ssao_enabled = ao > 0.0
	env.ssao_radius = 0.9
	env.ssao_intensity = ao
	env.ssao_power = 1.4
	env.ssao_detail = 0.4
	env.ssao_light_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_opacity = float(mood.get("shadow_opacity", 1.0))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	if Look.modern():
		_modern_finish()
	if board == null:
		return
	if mood.has("water"):
		_build_water()
	if outdoors and not (mood.get("surround", {}) as Dictionary).is_empty():
		land = AtmosphereLand.build(board, mood, _rng, water)
		add_child(land.root)
		board.occluders.append_array(land.occluders)
		board.mesh_occluders.append_array(land.mesh_occluders)


## The modern finish (Look.modern, docs/plans/ui_polish.md): filmic tone, bloom on what burns, deeper contact shadows
## with light bounced off the walls, a thin haze that catches lantern light, and softer shadow edges. The mood's own
## settings (its haze, its contact shadows) still count; this only adds to them.
func _modern_finish() -> void:
	env.tonemap_mode = MODERN_TONEMAP
	env.tonemap_exposure = MODERN_EXPOSURE
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = maxf(float(mood.get("ambient_occlusion", 0.0)), 1.8)
	env.ssao_power = 1.5
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004 if outdoors else 0.006
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.15
	sun.shadow_blur = 1.8


const MODERN_TONEMAP := Environment.TONE_MAPPER_AGX
const MODERN_EXPOSURE := 1.35
const MODERN_GRADE := 0.4


## The board's water squares get the moving water (one material for the whole place, the land's lakes included).
func _build_water() -> void:
	var spec := mood.get("water", {}) as Dictionary
	water = ShaderMaterial.new()
	water.shader = WATER_SHADER
	var info := ((Look.textures().get("themes", {}) as Dictionary).get("wild", {}) as Dictionary).get("water", {}) as Dictionary
	if not info.is_empty() and ResourceLoader.exists("res://" + str(info.get("file", ""))):
		water.set_shader_parameter("albedo_tex", load("res://" + str(info["file"])) as Texture2D)
		water.set_shader_parameter("tile_units", float(info.get("tile_world_units", 3.0)))
	water.set_shader_parameter("deep", Look.color(str(spec.get("deep", "night_deep"))))
	water.set_shader_parameter("shallow", Look.color(str(spec.get("shallow", "moon_blue"))))
	water.set_shader_parameter("foam", Look.color(str(spec.get("foam", "frost"))))
	water.set_shader_parameter("glint", Look.color(str(spec.get("glint", "moonlight"))))
	water.set_shader_parameter("flow", _vec2(spec.get("flow", [0.12, 0.05])))
	water.set_shader_parameter("water_mask", AtmosphereLand.water_mask(board.grid))
	water.set_shader_parameter("map_rect", Vector4(0, 0, board.grid.width, board.grid.depth))
	water.set_shader_parameter("use_mask", true)
	var old := Look.cel_textured("wild/water")
	for n in board.get_children():
		var mi := n as MeshInstance3D
		if mi != null and mi.material_override != null and (mi.material_override == old or str(mi.name).begins_with("Water")):
			mi.material_override = water
	_open_the_lake()


## A map's frame of trees standing across a lake (the border squares the data walls off) reads as a row of trees in
## the water: where the square inside it is water, the frame becomes open water running on past the edge. Only the
## look changes; the square stays a wall for the rules.
func _open_the_lake() -> void:
	var g := board.grid
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if not board._on_border(c) or not g.has_flag(c, CombatGrid.WALL) or not board.is_tree(c):
				continue
			var inward := Vector2i(clampi(x, 1, g.width - 2), clampi(z, 1, g.depth - 2))
			if not g.has_flag(inward, CombatGrid.WATER):
				continue
			for n: Node3D in board.dressing.get(c, []):
				n.visible = false
				if n is Sprite3D:
					board.occluders.erase(n)
				else:
					board.mesh_occluders.erase(n)
			for n in board.get_children():
				var mi := n as MeshInstance3D
				if mi != null and str(mi.name).begins_with("Ground") and absf(mi.position.x - (x + 0.5)) < 0.01 \
						and absf(mi.position.z - (z + 0.5)) < 0.01:
					mi.visible = false
			var w := board.add_box("Water", Vector3(1, 0.1, 1), Vector3(x + 0.5, -0.18, z + 0.5), water)
			w.name = "WaterEdge"


## Called once the camera and screen pass exist (LocationView._ready): weather follows the camera, the pass gets the
## mist and grade.
func attach(rig: CameraRig, post: MeshInstance3D) -> void:
	_rig = rig
	_post = (post.mesh as QuadMesh).material as ShaderMaterial if post != null and post.mesh is QuadMesh else null
	_apply_static()
	weather = AtmosphereWeather.build(self, board, mood, outdoors, get_parent())
	_show_night_pieces()
	_scan_lights()
	_apply(1.0)
	_next_flash = _rng.randf_range(4.0, 10.0)


func _apply_static() -> void:
	if _post == null:
		return
	var mist := mood.get("mist", {}) as Dictionary
	_post.set_shader_parameter("mist_height", float(mist.get("height", 1.2)))
	_post.set_shader_parameter("mist_cover", float(mist.get("cover", 0.5)))
	_post.set_shader_parameter("mist_scale", float(mist.get("scale", 0.12)))
	_post.set_shader_parameter("mist_wind", _vec2(mist.get("wind", [0.3, 0.1])))
	_post.set_shader_parameter("mist_thickness", float(mist.get("thickness", 1.4)))
	_post.set_shader_parameter("mist_bands", float(mist.get("bands", 3)))
	_post.set_shader_parameter("mist_stretch", float(mist.get("stretch", 0.5)))
	_post.set_shader_parameter("mist_wisps", float(mist.get("wisps", 0.9)))
	_post.set_shader_parameter("mist_beyond", outdoors)
	if board != null:
		_post.set_shader_parameter("mist_mask", mist_mask(board.grid, float(mist.get("open", 0.35))))
		_post.set_shader_parameter("use_mist_mask", true)
	var clouds := mood.get("clouds", {}) as Dictionary
	_post.set_shader_parameter("cloud_cover", float(clouds.get("cover", 0.5)))
	_post.set_shader_parameter("cloud_scale", float(clouds.get("scale", 0.035)))
	_post.set_shader_parameter("cloud_wind", _vec2(clouds.get("wind", [0.6, 0.25])))
	_post.set_shader_parameter("contrast", float(mood.get("contrast", 1.0)))
	_post.set_shader_parameter("vignette", float(mood.get("vignette", 0.0)))
	_post.set_shader_parameter("ground_variation", float(mood.get("ground_variation", 0.0)) if outdoors else 0.0)
	_post.set_shader_parameter("vignette_color", Look.color("void"))
	_post.set_shader_parameter("keep_greys", bool(mood.get("keep_greys", false)))
	if board != null and land != null:
		_post.set_shader_parameter("land_rect", Vector4(0, 0, board.grid.width, board.grid.depth))
		var fade := mood.get("land_fade", [5.0, 12.0]) as Array
		_post.set_shader_parameter("land_fade", Vector2(float(fade[0]), float(fade[1])))
	var mists := str(mood.get("mists_edge", ""))
	if mists != "" and board != null:
		var w := float(board.grid.width)
		var d := float(board.grid.depth)
		# Its billowing edge (±3.5) stays at least a square clear of the map.
		var wall := {"east": Vector4(1, 0, w + 2.0, 5.0), "west": Vector4(-1, 0, 2.0, 5.0),
			"south": Vector4(0, 1, d + 2.0, 5.0), "north": Vector4(0, -1, 2.0, 5.0)}.get(mists, Vector4.ZERO) as Vector4
		_post.set_shader_parameter("mist_wall", wall)


## Where the mist gathers on a map, one texel per square: thickest among the trees (wall squares), over water and
## empty ground and in brambles and mud, thinning to `open` in the middle of clearings and roads.
static func mist_mask(grid: CombatGrid, open: float) -> ImageTexture:
	var img := Image.create(grid.width, grid.depth, false, Image.FORMAT_R8)
	var dist := {}
	var todo: Array[Vector2i] = []
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			if grid.has_flag(c, CombatGrid.WALL) or grid.has_flag(c, CombatGrid.VOID):
				dist[c] = 0
				todo.append(c)
	var i := 0
	while i < todo.size():
		var c := todo[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if grid.in_bounds(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				todo.append(n)
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			var w := lerpf(open, 1.0, clampf(1.0 - (float(dist.get(c, 99)) - 1.0) / 3.0, 0.0, 1.0))
			if grid.has_flag(c, CombatGrid.DIFFICULT):
				w = minf(1.0, w + 0.25)
			elif grid.has_flag(c, CombatGrid.WATER):
				w = minf(w, 0.45)   # a lake keeps its face
			img.set_pixel(x, z, Color(w, w, w))
	return ImageTexture.create_from_image(img)


# --- Time of day ----------------------------------------------------------------------------------

## The look for "day", "dusk", "dawn" or "night" (indoors: "any"); a change after the first settles over TRANSITION.
func set_phase(p: String) -> void:
	var times := mood.get("times", {}) as Dictionary
	if not times.has(p):
		p = "any" if times.has("any") else ("dusk" if p == "dawn" and times.has("dusk") else "day")
	if p == phase:
		return
	var first := phase == ""
	phase = p
	_from = _to.duplicate() if not first else _target(p)
	_to = _target(p)
	_blend = 1.0 if first else 0.0
	_apply(_blend)
	_show_night_pieces()


## Lit windows and wisps only after dark (and always indoors, where "any" is the only time).
func _show_night_pieces() -> void:
	if weather == null:
		return
	var dark := phase != "day"
	for l in weather.night_lights:
		l.visible = dark
	for n in weather.night_only:
		n.visible = dark


## Jumps to the current time of day's look at once (captures).
func settle() -> void:
	_blend = 1.0
	_apply(1.0)


## Overrides one of the screen pass's numbers (art QA: atmosphere_preview --set).
func debug_set(uniform: String, value: float) -> void:
	if _post != null:
		_post.set_shader_parameter(uniform, value)


## Turns off everything this adds over the old look (art QA: atmosphere_preview --compare).
func debug_bare(bare: bool) -> void:
	if land != null:
		land.root.visible = not bare
	if weather != null:
		for w in weather.follow:
			w.visible = not bare
		for l in weather.night_lights:
			l.visible = not bare and phase != "day"
	if _post != null:
		for u: String in ["mist_strength", "cloud_strength", "grade_amount", "vignette", "ground_variation"]:
			_post.set_shader_parameter(u, 0.0)
		if not bare:
			_apply_static()
			_apply(1.0)


## The settings a time of day resolves to (colours, energies, the key light's angle), scaled for the map's light.
func _target(p: String) -> Dictionary:
	var t := (mood.get("times", {}) as Dictionary).get(p, {}) as Dictionary
	var grade := t.get("grade", {}) as Dictionary
	var level := float(LEVELS.get(light_level, 1.0))
	var angle := _vec2(t.get("key_angle", mood.get("key_angle", [-40, 30])))
	return {
		"sky": Look.color(str(t.get("sky", "grave"))),
		"fog": Look.color(str(t.get("fog", t.get("sky", "grave")))),
		"ambient": Look.color(str(t.get("ambient", "bruise"))),
		"ambient_energy": float(t.get("ambient_energy", 0.8)) * level,
		"key": Look.color(str(t.get("key", "moonlight"))),
		"key_energy": float(t.get("key_energy", 0.6)) * (level if not outdoors else 1.0),
		"key_angle": Vector3(angle.x, angle.y, 0.0),
		"mist": Look.color(str(t.get("mist", "lilac"))),
		"mists": Look.color(str(t.get("mists", "pewter"))),
		"mist_strength": float(t.get("mist_strength", 0.0)),
		"clouds": float(t.get("clouds", 0.0)) * float((mood.get("clouds", {}) as Dictionary).get("strength", 0.0)),
		"exposure": float(t.get("exposure", 1.0)),
		"saturation": float(t.get("saturation", mood.get("saturation", 1.0))),
		"grade_shadows": Look.color(str(grade.get("shadows", "pewter"))) if not grade.is_empty() else Color(0.5, 0.5, 0.5),
		"grade_lights": Look.color(str(grade.get("lights", "pewter"))) if not grade.is_empty() else Color(0.5, 0.5, 0.5),
		"grade_amount": float(grade.get("amount", 0.0)),
	}


func _apply(k: float) -> void:
	if _to.is_empty():
		return
	var v := {}
	for key: String in _to:
		var a: Variant = _from.get(key, _to[key])
		var b: Variant = _to[key]
		if b is Color:
			v[key] = (a as Color).lerp(b as Color, k)
		elif b is Vector3:
			v[key] = (a as Vector3).lerp(b as Vector3, k)
		else:
			v[key] = lerpf(float(a), float(b), k)
	env.background_color = v["sky"] as Color
	env.fog_light_color = v["fog"] as Color
	if env.volumetric_fog_enabled:
		env.volumetric_fog_albedo = v["fog"] as Color
	env.ambient_light_color = v["ambient"] as Color
	env.ambient_light_energy = float(v["ambient_energy"]) * (1.0 + _flash * 2.5)
	sun.light_color = (v["key"] as Color).lerp(Look.color("frost"), _flash)
	sun.light_energy = float(v["key_energy"]) * (1.0 + _flash * 3.0)
	sun.rotation_degrees = v["key_angle"] as Vector3
	if water != null:
		water.set_shader_parameter("reflection", (v["sky"] as Color).lerp(Look.color("moon_blue"), 0.5))
	if _post == null:
		return
	_post.set_shader_parameter("land_color", v["fog"] as Color)
	_post.set_shader_parameter("mist_color", v["mist"] as Color)
	_post.set_shader_parameter("mist_wall_color", v["mists"] as Color)
	_post.set_shader_parameter("mist_strength", float(v["mist_strength"]))
	_post.set_shader_parameter("cloud_strength", float(v["clouds"]))
	_post.set_shader_parameter("exposure", float(v["exposure"]))
	_post.set_shader_parameter("saturation", float(v["saturation"]))
	_post.set_shader_parameter("grade_shadows", v["grade_shadows"] as Color)
	_post.set_shader_parameter("grade_lights", v["grade_lights"] as Color)
	# Without the palette snap pulling colours back to the palette, the full gradient map tints too hard (grass
	# turns pink); the modern finish uses less of it.
	_post.set_shader_parameter("grade_amount", float(v["grade_amount"]) * (MODERN_GRADE if Look.modern() else 1.0))


# --- Every frame ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var dirty := false
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / TRANSITION)
		dirty = true
	if bool(mood.get("lightning", false)):
		dirty = _lightning(delta) or dirty
	if dirty:
		_apply(smoothstep(0.0, 1.0, _blend))
	if water != null:
		water.set_shader_parameter("atmo_time", _time)
	if _rig == null or not is_instance_valid(_rig):
		return
	if weather != null:
		for wx in weather.follow:
			if not wx.has_meta("offset"):
				wx.set_meta("offset", Vector3(wx.position.x, 0.0, wx.position.z))
			var off := wx.get_meta("offset") as Vector3
			wx.global_position = Vector3(_rig.global_position.x + off.x, wx.global_position.y, _rig.global_position.z + off.z)
	if _post == null:
		return
	_post.set_shader_parameter("atmo_time", _time)
	_light_scan -= delta
	if _light_scan <= 0.0:
		_light_scan = 1.0
		_scan_lights()
	_update_glows()


## A storm's lightning: now and then the sky flashes, once or twice, lighting everything cold for an instant (indoors,
## through the windows).
func _lightning(delta: float) -> bool:
	var was := _flash
	_next_flash -= delta
	if _next_flash <= 0.0:
		_flash = 1.0
		# A second, weaker flicker follows half the time.
		_next_flash = _rng.randf_range(0.12, 0.2) if _rng.randf() < 0.5 and was < 0.5 else _rng.randf_range(7.0, 16.0)
	_flash = maxf(0.0, _flash - delta * 6.0)
	return _flash > 0.0 or was > 0.0


## Every light in the place that can light the mist: the location's lamps and fires, the party's lantern, windows.
func _scan_lights() -> void:
	_lights.clear()
	var view := get_parent()
	if view == null:
		return
	for n in view.find_children("*", "OmniLight3D", true, false):
		_lights.append(n as OmniLight3D)


## The lit lights nearest the camera's focus go to the screen pass.
func _update_glows() -> void:
	var focus := _rig.global_position
	var near: Array[Array] = []
	for l in _lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy <= 0.01:
			continue
		near.append([l.global_position.distance_squared_to(focus), l])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var pos := PackedVector4Array()
	var col := PackedVector4Array()
	pos.resize(MAX_GLOWS)
	col.resize(MAX_GLOWS)
	var n := mini(near.size(), MAX_GLOWS)
	for i in n:
		var l := near[i][1] as OmniLight3D
		var p := l.global_position
		pos[i] = Vector4(p.x, p.y, p.z, l.omni_range * 0.85)
		var c := l.light_color
		col[i] = Vector4(c.r, c.g, c.b, clampf(l.light_energy * 0.45, 0.0, 1.2))
	_post.set_shader_parameter("glow_count", n)
	_post.set_shader_parameter("glow_pos", pos)
	_post.set_shader_parameter("glow_col", col)
