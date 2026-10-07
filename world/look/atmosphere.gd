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
## The Modern finish's water (W14): ripples that bend the light, glints, a smooth depth colour, soft foam.
const LIT_WATER_SHADER := preload("res://shaders/world/lit_water.gdshader")
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

## Atmospheres on screen, for a change of graphics preset (Graphics.set_preset).
const GROUP := &"atmosphere"


## The window's renderer follows the graphics preset (anti-aliasing, shadow maps) from the place that opens on.
func _ready() -> void:
	add_to_group(GROUP)
	Graphics.apply(get_viewport())


func _build() -> void:
	for l: Variant in loc.get("lights", []):
		var cell := (l as Dictionary).get("cell", []) as Array
		if cell.size() == 2:
			_data_lights[Vector2i(int(cell[0]), int(cell[1]))] = str((l as Dictionary).get("kind", "lamp"))
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
	if Look.modern():
		_flat_floors_cast_no_shadow()
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
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	env.volumetric_fog_density = 0.004 if outdoors else 0.006
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.15
	sun.shadow_blur = 1.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	# The flat sky colour isn't reflected: it would lay a grey sheen over every surface and wash the colour out.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.25
	apply_graphics()


## What the graphics preset decides in the Modern finish (W17; Graphics): the sun's splits and softness (W2: packed
## round what the camera sees, _fit_sun_shadows following the zoom; the light's size softens a shadow the further it
## falls from what casts it), light bounced off walls, the haze, reflections on polished and wet floors (W3) and the
## lamp shadow budget (W2). Called as the place is built and again when the preset changes.
func apply_graphics() -> void:
	if not Look.modern():
		return
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if Graphics.sun_splits() == 4 \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.light_angular_distance = SUN_SIZE if Graphics.sun_soft() else 0.0
	_fitted_distance = -1.0
	env.ssil_enabled = Graphics.bounce()
	env.volumetric_fog_enabled = Graphics.haze()
	var steps := Graphics.reflection_steps()
	env.ssr_enabled = steps > 0
	env.ssr_max_steps = maxi(steps, 1)
	for l in _lights:
		if is_instance_valid(l) and l.has_meta("light_kind"):
			var kind := LIGHT_KINDS[str(l.get_meta("light_kind"))] as Dictionary
			l.light_size = float(kind["size"]) if Graphics.lamp_soft() else 0.0
	if is_inside_tree():
		_update_lamp_shadows()


## The sun or moon's apparent size in degrees for the Modern finish's soft shadows (Godot's PCSS): sharp where a post
## meets the ground, softer at the far end of a long dusk shadow.
const SUN_SIZE := 1.2
var _fitted_distance := -1.0


## The sun's shadow reaches only as far as the camera can see, in splits packed round the ground in view (the camera
## looks 40 degrees down with a 32 degree field, so the ground in view runs from about 0.75 to 1.5 times its distance
## to the party), so a square near the party gets four times the shadow detail it had with one 60 unit reach.
func _fit_sun_shadows() -> void:
	if _rig == null or not Look.modern() or is_equal_approx(_rig.distance, _fitted_distance):
		return
	_fitted_distance = _rig.distance
	var d := _rig.distance
	var far := d * 1.7 + 12.0
	sun.directional_shadow_max_distance = far
	if sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
		sun.directional_shadow_split_1 = d * 0.9 / far
		sun.directional_shadow_split_2 = d * 1.15 / far
		sun.directional_shadow_split_3 = d * 1.45 / far
	else:
		sun.directional_shadow_split_1 = d * 1.15 / far


## Shadows for the lights near the party, up to the graphics preset's budget (W2): lamps, hearths, lit windows, the
## party's lantern and spell lights all can, nearest first; the rest light without. A light already casting keeps its
## shadow until another is clearly nearer, so shadows don't flicker on and off as the party walks; shadows fade out
## a little past the party. A light with the meta `no_shadow` never casts one.
const LAMP_SHADOW_KEEP := 0.7
var _shadow_scan := 0.0


func _update_lamp_shadows() -> void:
	var budget := Graphics.lamp_shadows()
	if _rig == null or not Look.modern():
		return
	var focus := _rig.global_position
	var ranked: Array[Array] = []
	for l in _lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy <= 0.01 or l.has_meta("no_shadow"):
			continue
		var d2 := l.global_position.distance_squared_to(focus)
		ranked.append([d2 * (LAMP_SHADOW_KEEP if l.shadow_enabled else 1.0), l])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var keep := {}
	for i in mini(budget, ranked.size()):
		keep[ranked[i][1]] = true
	# The nearest few flames that cast shadows sway with their flicker, so their shadows stir (W5; CandleFlicker).
	var sway := Graphics.swaying_flames()
	for i in ranked.size():
		var l := ranked[i][1] as OmniLight3D
		var swaying := i < budget and sway > 0 and l is CandleFlicker \
			and str(l.get_meta("light_kind", "")) in ["candle", "lamp", "torch", "fire"]
		if swaying:
			sway -= 1
		l.set_meta("sway", swaying)
	var fade := _rig.distance + 12.0
	for l in _lights:
		if not is_instance_valid(l):
			continue
		# Only real changes are set: setting a light's shadow again, even to the same value, can make Godot redraw its
		# shadow map.
		var want := keep.has(l)
		if want != l.shadow_enabled:
			if want:
				l.shadow_bias = 0.04
				l.shadow_normal_bias = 1.0
				l.shadow_blur = 1.0
				l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
				l.distance_fade_enabled = true
				# Only the shadow fades with distance; the light itself still reaches the far side of the map.
				l.distance_fade_begin = 500.0
				l.distance_fade_length = 10.0
			l.shadow_enabled = want
		if want and not is_equal_approx(l.distance_fade_shadow, fade):
			l.distance_fade_shadow = fade


## A level floor or ground square can't shadow anything (nothing stands under it), yet each is its own box that every
## shadow map would draw again: the sun's splits and every shadowed lamp's six faces (W17: the sun's shadows doubled
## the draw calls). Raised floors (a dais, steps) keep their shadows.
func _flat_floors_cast_no_shadow() -> void:
	for n in board.get_children():
		var mi := n as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		var name_ := str(mi.name)
		if not (name_.begins_with("Floor") or name_.begins_with("Ground") or name_.begins_with("Water")):
			continue
		if mi.position.y + (mi.mesh as BoxMesh).size.y / 2.0 <= 0.02:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The Modern finish's depth of field, as a strength the owner picks from (docs/plans/ui_polish.md): how soft
## (Godot's 0..1), where the far blur starts (the camera's distance to the party plus `start` plus `per_zoom` of
## that distance), how far it takes to come in, and whether anything near the lens blurs.
const DOF_STRENGTHS := {
	"old": {"amount": 0.14, "start": 1.0, "per_zoom": 0.12, "transition": 3.5, "transition_per_zoom": 0.25, "near": true},
	"light": {"amount": 0.08, "start": 3.0, "per_zoom": 0.15, "transition": 6.0, "transition_per_zoom": 0.3, "near": false},
	"lighter": {"amount": 0.05, "start": 6.0, "per_zoom": 0.2, "transition": 10.0, "transition_per_zoom": 0.0, "near": false},
}
## Light unless the owner picks another (2026-10-07: "old" read as a smear at the top of the screen).
static var dof_strength := "light"
var _dof: CameraAttributesPractical = null


## The sharp band follows the camera's zoom.
func _focus_dof() -> void:
	if _dof == null or _rig == null:
		return
	var d := _rig.distance
	var k := DOF_STRENGTHS[dof_strength] as Dictionary
	_dof.dof_blur_amount = float(k["amount"])
	_dof.dof_blur_near_enabled = bool(k["near"])
	_dof.dof_blur_far_distance = d + float(k["start"]) + d * float(k["per_zoom"])
	_dof.dof_blur_far_transition = float(k["transition"]) + d * float(k["transition_per_zoom"])
	_dof.dof_blur_near_distance = maxf(1.0, d - 2.0 - d * 0.08)
	_dof.dof_blur_near_transition = 2.0


const MODERN_TONEMAP := Environment.TONE_MAPPER_AGX
const MODERN_EXPOSURE := 1.35
## The Modern finish's grade, one per mood (Improvement Ideas W16; the screen pass's tone_split), in place of the
## gradient map Classic keeps: the shade takes the place's cool `shade` colour by `amount` and keeps only some of its
## colour (`shade_saturation`), its blacks sink (`black`), `pivot` is the brightness where shade turns to light, and
## `ambient` is how much of the mood's ambient light fills the shade. Lamplight keeps its own warm colour, so it pools
## warm against cool, dark shade (direction B's tone). A mood's "tone" changes any of them, a time of day's "tone"
## within it changes them again: Berez and the larders take a sick green shade, the brides' court crimson, a tavern
## warm peat.
const MODERN_TONE := {"shade": "night", "amount": 0.55, "shade_saturation": 0.6, "black": 0.03, "pivot": 0.36,
	"ambient": 0.8}
## An overcast day is still day: blue-grey shade, more of the ground counts as lit, the shade keeps more colour and
## all its fill.
const DAY_TONE := {"shade": "slate", "amount": 0.45, "pivot": 0.24, "shade_saturation": 0.8, "ambient": 1.0}
## Indoors the shade is the deep night blue of a dark house.
const INDOOR_TONE := {"shade": "night_deep"}


## The Modern grade for a time of day: MODERN_TONE, a day's DAY_TONE or an indoor INDOOR_TONE, then the mood's own
## "tone", then the time's.
func _tone(p: String) -> Dictionary:
	var t := MODERN_TONE.duplicate()
	if p == "day":
		t.merge(DAY_TONE, true)
	elif p == "any":
		t.merge(INDOOR_TONE, true)
	t.merge(mood.get("tone", {}) as Dictionary, true)
	t.merge(((mood.get("times", {}) as Dictionary).get(p, {}) as Dictionary).get("tone", {}) as Dictionary, true)
	return t


## Whether the mood's weather includes a kind ("rain", "snow" ...).
func has_weather(kind: String) -> bool:
	for w: Variant in mood.get("weather", []):
		if str(w) == kind or (w is Dictionary and str((w as Dictionary).get("kind", "")) == kind):
			return true
	return false


## The board's water squares get the moving water (one material for the whole place, the land's lakes included).
func _build_water() -> void:
	var spec := mood.get("water", {}) as Dictionary
	water = ShaderMaterial.new()
	water.shader = LIT_WATER_SHADER if Look.modern() else WATER_SHADER
	if Look.modern():
		water.set_shader_parameter("rain", 1.0 if has_weather("rain") else 0.0)
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
	if Look.modern() and GameSettings.depth_blur() and rig != null and rig.camera != null:
		# A light depth of field behind the party (DOF_STRENGTHS): the far edge of the screen softens while the party,
		# foes and anything that can be clicked stay crisp. Settings > Depth blur turns it off.
		_dof = CameraAttributesPractical.new()
		_dof.dof_blur_far_enabled = true
		rig.camera.attributes = _dof
		_focus_dof()
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
	var tone := _tone(p)
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
		"tone_shade": Look.color(str(tone["shade"])),
		"tone_amount": float(tone["amount"]),
		"tone_sat": float(tone["shade_saturation"]),
		"tone_black": float(tone["black"]),
		"tone_pivot": float(tone["pivot"]),
		"tone_ambient": float(tone["ambient"]),
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
	var fill := float(v["tone_ambient"]) if Look.modern() else 1.0
	env.ambient_light_energy = float(v["ambient_energy"]) * fill * (1.0 + _flash * 2.5)
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
	# The Modern finish tints only the shade (tone_split), by MODERN_TONE's share of the mood's amount.
	_post.set_shader_parameter("grade_amount", float(v["grade_amount"]))
	if Look.modern():
		_post.set_shader_parameter("tone_shade", v["tone_shade"] as Color)
		_post.set_shader_parameter("tone_amount", float(v["tone_amount"]))
		_post.set_shader_parameter("tone_shade_saturation", float(v["tone_sat"]))
		_post.set_shader_parameter("tone_black", float(v["tone_black"]))
		_post.set_shader_parameter("tone_pivot", float(v["tone_pivot"]))


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
	_focus_dof()
	_fit_sun_shadows()
	_shadow_scan -= delta
	if _shadow_scan <= 0.0:
		_shadow_scan = 0.25
		_update_lamp_shadows()
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
		var l := n as OmniLight3D
		_lights.append(l)
		if Look.modern() and not l.has_meta("light_kind"):
			_dress_light(l)


# --- Lights (W5) -----------------------------------------------------------------------------------

## How each kind of light behaves in the Modern finish (Improvement Ideas W5): `size` is how soft its shadows are
## (Godot's light_size: a candle's crisp, a hearth's soft), `fog` how strongly it lights the haze around it, `steady`
## that it doesn't flicker. A window indoors is the moon or the day coming in: cold, steady, with a shaft of light
## through the haze (_window_shaft).
const LIGHT_KINDS := {
	"candle": {"size": 0.03, "fog": 1.0},
	"lamp": {"size": 0.06, "fog": 1.2},
	"lantern": {"size": 0.08, "fog": 1.2},
	"torch": {"size": 0.12, "fog": 1.8},
	"fire": {"size": 0.25, "fog": 2.0},
	"magic": {"size": 0.12, "fog": 1.6, "steady": true},
	"window": {"size": 0.4, "fog": 0.5, "steady": true},
	"lit_window": {"size": 0.3, "fog": 1.0},
	"spell": {"size": 0.1, "fog": 1.5},
}
## Shafts through windows (W5): how far above the floor the light comes in, how much the spot lights the haze, and
## the glowing cone drawn along it (shaders/world/light_shaft.gdshader: Godot's fog volumes are too coarse to show a
## beam's edges at this camera distance).
const SHAFT_HEIGHT := 2.6
const SHAFT_FOG := 2.0
const SHAFT_GLOW := 0.3
const SHAFT_SHADER := preload("res://shaders/world/light_shaft.gdshader")
var _data_lights: Dictionary = {}


## What a light is: the location's own lights by their square and kind in its data; lit windows from the weather;
## the party's lantern; a flame (the flame colour); anything else a spell's.
func _light_kind(l: OmniLight3D) -> String:
	var view := get_parent()
	if view != null and view.get("lantern") == l:
		return "lantern"
	if str(l.name).begins_with("WindowLight"):
		return "lit_window"
	var c := Vector2i(floori(l.global_position.x), floori(l.global_position.z))
	if _data_lights.has(c):
		var k := str(_data_lights[c])
		return k if LIGHT_KINDS.has(k) else "lamp"
	if l is CandleFlicker:
		return "fire" if l.light_color.is_equal_approx(Look.color("flame")) else "lamp"
	return "spell"


func _dress_light(l: OmniLight3D) -> void:
	var kind := _light_kind(l)
	var spec := LIGHT_KINDS[kind] as Dictionary
	l.set_meta("light_kind", kind)
	l.light_size = float(spec["size"]) if Graphics.lamp_soft() else 0.0
	l.light_volumetric_fog_energy = float(spec["fog"])
	if bool(spec.get("steady", false)) and l is CandleFlicker:
		(l as CandleFlicker).flicker = 0.0
	if kind == "window" and not outdoors:
		# The moon or the day, not a candle: the key light's colour, and its shaft through the haze.
		l.light_color = sun.light_color
		_window_shaft(l)


## A shaft of the key light (the moon, or the day) coming in through a window over the wall beside the window's
## square, down across the room through the haze; a child of the window's light, so it hides with it.
func _window_shaft(l: OmniLight3D) -> void:
	if board == null:
		return
	var c := Vector2i(floori(l.global_position.x), floori(l.global_position.z))
	var out := Vector2i.ZERO
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if board.grid.in_bounds(c + d) and board.grid.has_flag(c + d, CombatGrid.WALL):
			out = d
			break
	if out == Vector2i.ZERO:
		return
	var inward := Vector3(-out.x, 0.0, -out.y)
	var from := board.cell_center(c) - inward * 1.2 + Vector3(0, SHAFT_HEIGHT, 0)
	var spot := SpotLight3D.new()
	spot.name = "WindowShaft"
	spot.light_color = sun.light_color
	spot.light_energy = 2.0
	spot.light_volumetric_fog_energy = SHAFT_FOG
	spot.spot_range = 8.0
	spot.spot_angle = 14.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	spot.light_size = 0.3
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 40.0
	spot.distance_fade_length = 10.0
	l.add_child(spot)
	var dir := (inward + Vector3(0, -1.1, 0)).normalized()
	spot.look_at_from_position(from, from + dir)
	# The cone of lit haze from the window down to where the light meets the floor.
	var to := from + dir * (from.y / -dir.y)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 0.8
	cone.height = from.distance_to(to)
	cone.cap_top = false
	cone.cap_bottom = false
	var glow := ShaderMaterial.new()
	glow.shader = SHAFT_SHADER
	glow.render_priority = 1
	glow.set_shader_parameter("colour", sun.light_color)
	glow.set_shader_parameter("strength", SHAFT_GLOW)
	glow.set_shader_parameter("shaft_length", cone.height)
	var beam := MeshInstance3D.new()
	beam.name = "WindowBeam"
	beam.mesh = cone
	beam.material_override = glow
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.add_child(beam)
	var up := -dir
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	beam.global_transform = Transform3D(Basis(side, up, side.cross(up)), (from + to) / 2.0)


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
