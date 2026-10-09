class_name AtmosphereWeather
extends RefCounted
## A place's weather (Atmosphere, docs/art/atmosphere.md): falling leaves, rain with splashes, snow, will-o'-wisps
## and fireflies, crows circling overhead, chimney smoke, embers over fires and candlelight from lit windows. Every
## piece draws opaque, hard-edged shapes in palette colours, so the screen pass snaps it like the rest of the world and
## nothing adds grain. The kinds a mood lists in `weather` are built here; each may be a name or {kind, ...settings}.

const LEAF_SHADER := preload("res://shaders/atmosphere/leaf.gdshader")
const SMOKE_SHADER := preload("res://shaders/atmosphere/smoke_puff.gdshader")
const STREAK_SHADER := preload("res://shaders/atmosphere/streak.gdshader")
const RING_SHADER := preload("res://shaders/atmosphere/ring.gdshader")
const MOTE_SHADER := preload("res://shaders/atmosphere/mote.gdshader")
const CROW_SHADER := preload("res://shaders/atmosphere/crow.gdshader")

## Pieces that follow the camera (rain, snow, leaves, crows): the Atmosphere moves them to the camera's focus, keeping
## each one's offset from it (`offset` meta).
var follow: Array[Node3D] = []
## Lights this added (lit windows), shown only after dark.
var night_lights: Array[OmniLight3D] = []
## Pieces seen only after dark (wisps, fireflies).
var night_only: Array[Node3D] = []
## The rain (and its splashes) and snow, which the world's weather can change while the party is here
## (rebuild_falling).
var falling: Array[Node3D] = []
var _parent: Node
var _board: ArenaBoard
var _wind := Vector2(0.3, 0.1)


static func build(parent: Node, board: ArenaBoard, mood: Dictionary, outdoors: bool, view: Node) -> AtmosphereWeather:
	var w := AtmosphereWeather.new()
	w._parent = parent
	w._board = board
	var wind := (mood.get("mist", {}) as Dictionary).get("wind", [0.3, 0.1]) as Array
	w._wind = Vector2(float(wind[0]), float(wind[1]))
	for k: Variant in mood.get("weather", []):
		var spec := {"kind": str(k)} if not (k is Dictionary) else (k as Dictionary)
		if not outdoors and not bool(spec.get("indoors", false)):
			continue
		match str(spec["kind"]):
			"leaves":
				w._leaves(spec)
			"rain":
				w._rain(spec)
			"snow":
				w._snow(spec)
			"wisps":
				w._wisps(spec)
			"dust":
				w._dust(spec)
			"crows":
				w._crows(spec)
			"chimney_smoke":
				w._chimney_smoke()
			"smoke":
				w._smoke_at(spec)
			"window_light":
				w._window_light()
			"embers":
				w._embers(view)
	# Sunbeams and moonbeams through the gaps in the trees and between the houses (Visual Polish Plan 2).
	if outdoors and parent is Atmosphere:
		SunShafts.build(parent as Atmosphere, board, view)
		# Dust, snow or a splash where the party's feet land (Visual Polish Plan 4).
		StepPuffs.build(parent as Atmosphere, view)
	return w


func _particles(name: String, amount: int, lifetime: float, box: Vector3, height: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-box.x - 4, -height - 4, -box.z - 4), Vector3(2 * box.x + 8, 2 * height + 12, 2 * box.z + 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, height, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	p.process_material = pm
	_parent.add_child(p)
	follow.append(p)
	return p


## Dead leaves drifting down through the view.
func _leaves(spec: Dictionary) -> void:
	var p := _particles("Leaves", int(spec.get("amount", 70)), 10.0, Vector3(16, 1.2, 16), 4.2)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(_wind.x, -0.4, _wind.y).normalized()
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(_wind.x * 0.5, -0.32, _wind.y * 0.5)
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.25)
	var mat := ShaderMaterial.new()
	mat.shader = LEAF_SHADER
	var cols := spec.get("colours", ["rust", "ember", "umber"]) as Array
	mat.set_shader_parameter("colour_a", Look.color(str(cols[0])))
	mat.set_shader_parameter("colour_b", Look.color(str(cols[1 % cols.size()])))
	mat.set_shader_parameter("colour_c", Look.color(str(cols[2 % cols.size()])))
	quad.material = mat
	p.draw_pass_1 = quad


## The world's weather turned (Atmosphere.refresh_weather): the rain and snow go and the dressed mood's come, outdoors;
## everything else (leaves, crows, smoke, embers, lit windows) stays as it is.
func rebuild_falling(mood: Dictionary, outdoors: bool) -> void:
	for n in falling:
		if is_instance_valid(n):
			follow.erase(n)
			n.queue_free()
	falling.clear()
	if not outdoors:
		return
	for k: Variant in mood.get("weather", []):
		var spec := {"kind": str(k)} if not (k is Dictionary) else (k as Dictionary)
		match str(spec["kind"]):
			"rain":
				_rain(spec)
			"snow":
				_snow(spec)


## Rain slanting down on the wind, and rings where it lands.
func _rain(spec: Dictionary) -> void:
	var fall := Vector3(_wind.x * 0.6, -7.0, _wind.y * 0.6)
	var p := _particles("Rain", int(spec.get("amount", 500)), 1.1, Vector3(14, 0.5, 14), 7.0)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = fall.normalized()
	pm.spread = 2.0
	pm.initial_velocity_min = fall.length() * 0.9
	pm.initial_velocity_max = fall.length() * 1.1
	pm.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = STREAK_SHADER
	mat.set_shader_parameter("colour", Look.color(str(spec.get("colour", "mist_blue"))))
	mat.set_shader_parameter("fall", fall)
	mat.set_shader_parameter("length_units", float(spec.get("length", 0.5)))
	quad.material = mat
	p.draw_pass_1 = quad
	var s := _particles("RainSplashes", int(spec.get("splashes", 120)), 0.45, Vector3(12, 0.0, 12), 0.03)
	var spm := s.process_material as ParticleProcessMaterial
	spm.gravity = Vector3.ZERO
	spm.initial_velocity_min = 0.0
	spm.initial_velocity_max = 0.0
	spm.scale_min = 0.18
	spm.scale_max = 0.3
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("colour", Look.color(str(spec.get("splash_colour", "moonlight"))))
	plane.material = rm
	s.draw_pass_1 = plane
	falling.append(p)
	falling.append(s)


## Snow drifting down on the wind; a higher `wind` drives it nearly sideways. The wind is the flakes' starting
## speed (gravity here is only a gentle sink and sway), so they cross the view instead of racing off it.
func _snow(spec: Dictionary) -> void:
	var gale := float(spec.get("wind", 1.0))
	var p := _particles("Snow", int(spec.get("amount", 260)), 5.0, Vector3(14, 2.5, 14), 4.0)
	var pm := p.process_material as ParticleProcessMaterial
	var drift := Vector3(_wind.x * gale, -0.6, _wind.y * gale)
	pm.direction = drift.normalized()
	pm.spread = 10.0
	pm.initial_velocity_min = drift.length() * 0.7
	pm.initial_velocity_max = drift.length() * 1.1
	pm.gravity = Vector3(0, -0.15, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.1
	# Start them upwind, so the whole view fills.
	p.position -= Vector3(_wind.x, 0, _wind.y).normalized() * minf(gale * 2.0, 8.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat := ShaderMaterial.new()
	mat.shader = MOTE_SHADER
	mat.set_shader_parameter("core", Look.color("ivory"))
	mat.set_shader_parameter("rim", Look.color("frost"))
	mat.set_shader_parameter("glow", true)
	quad.material = mat
	p.draw_pass_1 = quad
	falling.append(p)


## Will-o'-wisps or fireflies wandering low over the ground after dark, pulsing in and out of sight.
func _wisps(spec: Dictionary) -> void:
	var p := _particles("Wisps", int(spec.get("amount", 24)), 9.0, Vector3(13, 0.6, 13), 0.9)
	var pm := p.process_material as ParticleProcessMaterial
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.3
	var size := float(spec.get("size", 0.12))
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = MOTE_SHADER
	mat.set_shader_parameter("core", Look.color(str(spec.get("core", "wick"))))
	mat.set_shader_parameter("rim", Look.color(str(spec.get("rim", "bile"))))
	mat.set_shader_parameter("glow", true)
	mat.set_shader_parameter("pulse", 1.0)
	quad.material = mat
	p.draw_pass_1 = quad
	if bool(spec.get("night_only", true)):
		night_only.append(p)


## Dust hanging in the air of a shut-up room, drifting slowly and catching the light.
func _dust(spec: Dictionary) -> void:
	var p := _particles("Dust", int(spec.get("amount", 60)), 12.0, Vector3(11, 1.0, 11), 1.4)
	var pm := p.process_material as ParticleProcessMaterial
	pm.gravity = Vector3(0, -0.01, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	pm.turbulence_noise_scale = 2.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	var size := float(spec.get("size", 0.035))
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = MOTE_SHADER
	mat.set_shader_parameter("core", Look.color(str(spec.get("core", "parchment"))))
	mat.set_shader_parameter("rim", Look.color(str(spec.get("rim", "bone"))))
	mat.set_shader_parameter("pulse", 0.4)
	quad.material = mat
	p.draw_pass_1 = quad


## A few crows wheeling high over the place.
func _crows(spec: Dictionary) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = CROW_SHADER
	mat.set_shader_parameter("colour", Look.color("void"))
	mat.set_shader_parameter("radius", float(spec.get("radius", 7.0)))
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = int(spec.get("amount", 5))
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Crows"
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 10, 28))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = Vector3(0, float(spec.get("height", 7.5)), 0)
	_parent.add_child(mmi)
	follow.append(mmi)


## Smoke curling up from every chimney in town, bent by the wind.
func _chimney_smoke() -> void:
	if _board == null:
		return
	for b: Dictionary in _board.buildings:
		var upper := b["upper"] as Node3D
		for c in upper.get_children():
			var mi := c as MeshInstance3D
			if mi == null or not (mi.mesh is BoxMesh) or absf((mi.mesh as BoxMesh).size.x - 0.38) > 0.01:
				continue
			var top := mi.position + Vector3(0, (mi.mesh as BoxMesh).size.y / 2.0, 0)
			upper.add_child(_plume(top, "ChimneySmoke"))


## Smoke rising from fixed points (a mood's weather {"kind": "smoke", "at": [[x, y, z], ...]}, world units): Old
## Bonegrinder's pipe, a camp's cookfire. Lane 28, 2026-10-08.
func _smoke_at(spec: Dictionary) -> void:
	if _board == null:
		return
	for a: Variant in spec.get("at", []):
		var at := a as Array
		if at.size() == 3:
			_board.add_child(_plume(Vector3(float(at[0]), float(at[1]), float(at[2])), "Smoke"))


## One plume of smoke drifting up on the wind from `top`.
func _plume(top: Vector3, name_: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name_
	p.amount = 7
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(_wind.x * 0.35, 0.04, _wind.y * 0.35)
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	pm.scale_min = 0.8
	pm.scale_max = 1.15
	pm.scale_curve = _swell_curve()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE_SHADER
	mat.set_shader_parameter("light_tone", Look.color("silver"))
	mat.set_shader_parameter("dark_tone", Look.color("pewter"))
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = top
	return p


static func _swell_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.35, 0.85))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	return ct


## Candlelight spilling from the lit windows onto the street after dark. A window is a painted sprite (lit when its
## art is the lit window) or, on a house built from the kit, a marker where its glass is (meta "lit"); either faces
## out of the house along its +z, or says which way is out in its meta "out".
func _window_light() -> void:
	if _board == null:
		return
	for key: String in _board.windows:
		var w := _board.windows[key] as Node3D
		if w == null or not _lit_window(w):
			continue
		var l := OmniLight3D.new()
		l.name = "WindowLight"
		l.light_color = Look.color("candle")
		l.omni_range = 3.2
		l.light_energy = 1.3
		l.omni_attenuation = 1.4
		var out := (w.get_meta("out", w.basis.z) as Vector3).normalized()
		l.position = w.position + out * 0.7 + Vector3(0, -0.2, 0)
		w.get_parent().add_child(l)
		night_lights.append(l)


static func _lit_window(w: Node3D) -> bool:
	if w is Sprite3D:
		var sp := w as Sprite3D
		return sp.texture != null and sp.texture.resource_path.contains("window_lit")
	return bool(w.get_meta("lit", false))


## Sparks rising off every open fire (the flames the location's lights and burning props put up).
func _embers(view: Node) -> void:
	if view == null:
		return
	var flame := Look.color("flame")
	for n in view.find_children("*", "CandleFlicker", true, false):
		var l := n as CandleFlicker
		if not l.light_color.is_equal_approx(flame):
			continue
		var p := GPUParticles3D.new()
		p.name = "Embers"
		p.amount = 10
		p.lifetime = 1.8
		p.preprocess = 1.8
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.15
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 25.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.2
		pm.gravity = Vector3(_wind.x * 0.3, 0.2, _wind.y * 0.3)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.0
		pm.turbulence_noise_scale = 1.5
		pm.scale_curve = _fade_curve()
		p.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.05, 0.05)
		var mat := ShaderMaterial.new()
		mat.shader = MOTE_SHADER
		mat.set_shader_parameter("core", Look.color("wick"))
		mat.set_shader_parameter("rim", Look.color("candle"))
		mat.set_shader_parameter("glow", true)
		quad.material = mat
		p.draw_pass_1 = quad
		l.get_parent().add_child(p)
		p.position = l.position


static func _fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	return ct
