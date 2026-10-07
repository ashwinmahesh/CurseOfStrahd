class_name FxKit
extends RefCounted
## The parts spell and ability effects are built from (world/combat/fx/spell_fx.gd, docs/art/spell_effects.md):
## particle bursts and streams, beams, swelling blasts, rings on the floor, shafts of light and flashes of real light.
## Every colour is a palette colour handed in by the effect's flavour (art/vfx/effects.json). Effects draw after the
## palette pass like the character sprites (render priority), so they stay bright and bloom in the modern finish.

const PARTICLE_SHADER := preload("res://shaders/fx/fx_particle.gdshader")
const SMOKE_SHADER := preload("res://shaders/fx/fx_smoke.gdshader")
const BEAM_SHADER := preload("res://shaders/fx/fx_beam.gdshader")
const BLAST_SHADER := preload("res://shaders/fx/fx_blast.gdshader")
const RING_SHADER := preload("res://shaders/fx/fx_ring.gdshader")
const COLUMN_SHADER := preload("res://shaders/fx/fx_column.gdshader")
## Over the palette pass (0) and the character sprites (DirectionalSprite.RENDER_PRIORITY, 6).
const PRIORITY := 7
## Rings on the floor: over the palette pass and the grid marks (5), under the sprites.
const FLOOR_PRIORITY := 5

## One knob for how bright every effect is. The modern finish tone-maps with AgX at exposure 1.35 and blooms anything
## over 0.9, so colours much brighter than this wash out to white; the hot cores still go over and bloom.
const BRIGHT := 0.5
## Real lights (flashes) are scaled the same way.
const LIGHT := 0.55

## Particle shapes (fx_particle.gdshader).
enum Shape { GLOW, PUFF, STREAK, GLINT, RING }

static var _noise: Texture2D
## Cosmetic randomness has its own generator (CLAUDE.md): never the dice.
static var rng := RandomNumberGenerator.new()
static var _noise3: Texture3D


## Seamless noise the shaders break their edges with, made once (synchronously, so the first frame already has it).
static func noise() -> Texture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		n.fractal_octaves = 4
		n.seed = 7
		var img := n.get_seamless_image(128, 128)
		img.convert(Image.FORMAT_L8)
		_noise = ImageTexture.create_from_image(img)
	return _noise


static func noise3() -> Texture3D:
	if _noise3 == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.09
		n.fractal_octaves = 3
		n.seed = 11
		var layers := n.get_seamless_image_3d(32, 32, 32)
		var data: Array[Image] = []
		for l: Image in layers:
			l.convert(Image.FORMAT_L8)
			data.append(l)
		var t := ImageTexture3D.new()
		t.create(Image.FORMAT_L8, 32, 32, 32, false, data)
		_noise3 = t
	return _noise3


## Frees `node` after `seconds` (the effect has played out).
static func free_after(node: Node, seconds: float) -> void:
	if not node.is_inside_tree():
		return
	# Bound to the node itself, so the timer forgets it if something freed it first (a parent's effect ending).
	node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


## A gradient through `colours` (fading in from and out to transparent when `fade_in`/`fade_out`).
static func ramp(colours: Array[Color], fade_in: bool = false, fade_out: bool = true) -> GradientTexture1D:
	var g := Gradient.new()
	var cs: Array[Color] = colours.duplicate()
	if fade_in:
		cs.push_front(Color(colours[0], 0.0))
	if fade_out:
		cs.append(Color(colours[colours.size() - 1], 0.0))
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in cs.size():
		offsets.append(float(i) / float(maxi(1, cs.size() - 1)))
		cols.append(cs[i])
	g.offsets = offsets
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A size curve over a particle's life: from `a` to a peak `b` at `peak` and down to `c`.
static func curve(a: float, b: float, c: float, peak: float = 0.2) -> CurveTexture:
	var cv := Curve.new()
	cv.max_value = maxf(1.0, maxf(a, maxf(b, c)))
	cv.add_point(Vector2(0.0, a))
	cv.add_point(Vector2(peak, b))
	cv.add_point(Vector2(1.0, c))
	var t := CurveTexture.new()
	t.curve = cv
	return t


## An additive particle material: `shape` (Shape), the flavour's hot `core` colour, brightness.
static func glow_material(shape: int, core: Color, energy: float = 2.0, billboard: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PARTICLE_SHADER
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("energy", energy * BRIGHT)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("noise_tex", noise())
	m.render_priority = PRIORITY
	return m


static func smoke_material(density: float = 0.75) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SMOKE_SHADER
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("noise_tex", noise())
	m.render_priority = PRIORITY
	return m


## A particle emitter. `o` holds what differs from the defaults:
##   amount, lifetime (seconds; a Vector2 picks a random life in that range via randomness), one_shot, explosiveness,
##   emit ("point", "sphere", "shell", "ring", "box"), radius, box (Vector3), ring_axis (Vector3), dir (Vector3),
##   spread (degrees), speed (Vector2 min, max), gravity (Vector3), damping (Vector2), scale (Vector2), size (quad
##   size), grow (CurveTexture over life), colours (Array[Color], the ramp over life), fade_in, material, align
##   (stretch along the velocity), local (move with the emitter), turbulence, radial (Vector2), tangential (Vector2),
##   orbit (Vector2), spin (Vector2, degrees a second), fixed (process at 60 fps).
static func particles(o: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(o.get("amount", 24))
	p.lifetime = float(o.get("lifetime", 0.8))
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("explosiveness", 0.9 if p.one_shot else 0.0))
	p.randomness = float(o.get("randomness", 0.4))
	p.local_coords = bool(o.get("local", false))
	p.fixed_fps = 60
	p.interpolate = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	var pm := ParticleProcessMaterial.new()
	match str(o.get("emit", "point")):
		"sphere":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = float(o.get("radius", 0.2))
		"shell":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			pm.emission_sphere_radius = float(o.get("radius", 0.2))
		"ring":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_radius = float(o.get("radius", 0.5))
			pm.emission_ring_inner_radius = float(o.get("inner", float(o.get("radius", 0.5)) * 0.85))
			pm.emission_ring_height = float(o.get("ring_height", 0.05))
			pm.emission_ring_axis = o.get("ring_axis", Vector3.UP) as Vector3
		"box":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = o.get("box", Vector3(0.5, 0.1, 0.5)) as Vector3
		_:
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = o.get("dir", Vector3.UP) as Vector3
	pm.spread = float(o.get("spread", 180.0))
	var speed := o.get("speed", Vector2(0.5, 1.5)) as Vector2
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = o.get("gravity", Vector3.ZERO) as Vector3
	var damping := o.get("damping", Vector2(1.0, 2.0)) as Vector2
	pm.damping_min = damping.x
	pm.damping_max = damping.y
	var scale := o.get("scale", Vector2(0.8, 1.2)) as Vector2
	pm.scale_min = scale.x
	pm.scale_max = scale.y
	if o.has("grow"):
		pm.scale_curve = o["grow"] as CurveTexture
	if o.has("colours"):
		var cs: Array[Color] = []
		cs.assign(o["colours"] as Array)
		pm.color_ramp = ramp(cs, bool(o.get("fade_in", false)))
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var spin := o.get("spin", Vector2(-90.0, 90.0)) as Vector2
	pm.angular_velocity_min = spin.x
	pm.angular_velocity_max = spin.y
	if o.has("radial"):
		var rad := o["radial"] as Vector2
		pm.radial_accel_min = rad.x
		pm.radial_accel_max = rad.y
	if o.has("tangential"):
		var tan_a := o["tangential"] as Vector2
		pm.tangential_accel_min = tan_a.x
		pm.tangential_accel_max = tan_a.y
	if o.has("orbit"):
		var orb := o["orbit"] as Vector2
		pm.orbit_velocity_min = orb.x
		pm.orbit_velocity_max = orb.y
	if float(o.get("turbulence", 0.0)) > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = float(o["turbulence"])
		pm.turbulence_noise_scale = 2.5
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.2
	p.process_material = pm
	var quad := QuadMesh.new()
	var size: Variant = o.get("size", 0.3)
	quad.size = size as Vector2 if size is Vector2 else Vector2(float(size), float(size))
	if bool(o.get("align", false)):
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	quad.material = o.get("material", glow_material(Shape.GLOW, Color.WHITE)) as Material
	p.draw_pass_1 = quad
	return p


## Starts a one-shot emitter (after it's in the tree) and frees it when its particles are gone.
static func fire(p: GPUParticles3D, extra: float = 0.2) -> void:
	p.restart()
	p.emitting = true
	free_after(p, p.lifetime * (1.0 + p.randomness) + extra)


## A light that flares to `energy` over `rise` seconds and dies over `fall`; frees itself.
static func flash(parent: Node3D, at: Vector3, colour: Color, energy: float, radius: float, rise: float = 0.06, fall: float = 0.5) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = colour
	l.omni_range = radius
	l.omni_attenuation = 1.2
	l.light_energy = 0.0
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", energy * LIGHT, rise)
	tw.tween_property(l, "light_energy", 0.0, fall).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(l.queue_free)
	return l


## A ribbon of energy from `p0` to `p1` (fx_beam.gdshader); `jag` > 0 makes it lightning. It sits at the world
## origin and the shader places it, so it never needs moving: set p0/p1 on its material instead.
static func beam(parent: Node3D, p0: Vector3, p1: Vector3, width: float, cols: Dictionary, jag: float = 0.0, energy: float = 2.5) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.subdivide_width = 48
	var m := ShaderMaterial.new()
	m.shader = BEAM_SHADER
	m.set_shader_parameter("p0", p0)
	m.set_shader_parameter("p1", p1)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("jag", jag)
	m.set_shader_parameter("energy", energy * BRIGHT)
	m.set_shader_parameter("seed", rng.randf())
	m.set_shader_parameter("core", cols["core"])
	m.set_shader_parameter("glow", cols["glow"])
	m.set_shader_parameter("edge", cols["edge"])
	m.set_shader_parameter("noise_tex", noise())
	m.render_priority = PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	parent.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


## A churning ball of the flavour's fire (fx_blast.gdshader), radius 1 before scaling; tween `progress` 0 to 1.
static func blast(parent: Node3D, at: Vector3, cols: Dictionary, energy: float = 3.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 48
	s.rings = 24
	var m := ShaderMaterial.new()
	m.shader = BLAST_SHADER
	m.set_shader_parameter("core", cols["core"])
	m.set_shader_parameter("glow", cols["glow"])
	m.set_shader_parameter("edge", cols["edge"])
	m.set_shader_parameter("smoke", cols["smoke"])
	m.set_shader_parameter("energy", energy * BRIGHT)
	m.set_shader_parameter("noise3", noise3())
	m.render_priority = PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	return mi


## A ring of light lying on the floor, `size` across (fx_ring.gdshader); tween its material's radius and fade.
static func ring(parent: Node3D, at: Vector3, size: float, cols: Dictionary, runes: float = 0.0, energy: float = 2.0) -> MeshInstance3D:
	var pl := PlaneMesh.new()
	pl.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter("core", cols["core"])
	m.set_shader_parameter("glow", cols["glow"])
	m.set_shader_parameter("runes", runes)
	m.set_shader_parameter("energy", energy * BRIGHT)
	m.set_shader_parameter("noise_tex", noise())
	m.render_priority = FLOOR_PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = pl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 0.04, 0)
	return mi


## An open shaft of light `height` tall (fx_column.gdshader): a cylinder, or a cone when the radii differ.
static func column(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, cols: Dictionary, energy: float = 2.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top
	c.height = height
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 32
	c.rings = 8
	var m := ShaderMaterial.new()
	m.shader = COLUMN_SHADER
	m.set_shader_parameter("core", cols["core"])
	m.set_shader_parameter("glow", cols["glow"])
	m.set_shader_parameter("energy", energy * BRIGHT)
	m.set_shader_parameter("noise_tex", noise())
	m.render_priority = PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, height / 2.0, 0)
	return mi


## A bubble of light `radius` across its middle (fx_column.gdshader on a sphere: brightest round its rim).
static func shell(parent: Node3D, at: Vector3, radius: float, cols: Dictionary, energy: float = 1.8) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 32
	s.rings = 16
	var m := ShaderMaterial.new()
	m.shader = COLUMN_SHADER
	m.set_shader_parameter("core", cols["core"])
	m.set_shader_parameter("glow", cols["glow"])
	m.set_shader_parameter("energy", energy * BRIGHT)
	m.set_shader_parameter("top_fade", 1.6)
	m.set_shader_parameter("bottom_fade", -0.3)
	m.set_shader_parameter("streaks", 10.0)
	m.set_shader_parameter("noise_tex", noise())
	m.render_priority = PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	return mi


## Tweens a shader parameter of `mi`'s material from `a` to `b` over `seconds`.
static func tween_param(mi: GeometryInstance3D, param: String, a: Variant, b: Variant, seconds: float,
		ease_type: Tween.EaseType = Tween.EASE_OUT, trans: Tween.TransitionType = Tween.TRANS_QUAD) -> Tween:
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter(param, a)
	var tw := mi.create_tween()
	tw.tween_method(func(v: Variant) -> void: m.set_shader_parameter(param, v), a, b, seconds).set_ease(ease_type).set_trans(trans)
	return tw
