class_name StepPuffs
extends Node3D
## What the party's feet kick up as they land (Visual Polish Plan 4, docs/art/atmosphere.md "Footstep puffs"): a little
## dust on dry roads, earth and scree, snow kicked up where it lies, a splash in marsh mud and on any ground in the
## rain. Out of doors in the Modern finish only; built with the place's weather (AtmosphereWeather.build). The ground
## is read as the footprints read it (the floor's `surface`, Atmosphere.wetness and snow_cover). Cosmetic only.

## How far a figure walks between puffs (world units: about a stride).
const STEP := 0.6
## Puffs of each kind alive at once; the oldest is used again.
const POOL := 10
## Each kind: particles, seconds, the cone they leave in (degrees from straight up), speeds, the fall, the slowing,
## sizes (world units), palette colour and how solid.
const KINDS := {
	"dust": {"amount": 6, "life": 0.7, "spread": 70.0, "speed": [0.15, 0.3], "gravity": -0.1, "damping": 0.8,
		"size": [0.16, 0.26], "colour": "tan", "alpha": 0.32},
	"snow": {"amount": 7, "life": 0.5, "spread": 35.0, "speed": [0.45, 0.7], "gravity": -2.6, "damping": 0.2,
		"size": [0.06, 0.1], "colour": "moonlight", "alpha": 0.9},
	"splash": {"amount": 9, "life": 0.38, "spread": 30.0, "speed": [0.7, 1.0], "gravity": -7.0, "damping": 0.0,
		"size": [0.04, 0.07], "colour": "frost", "alpha": 0.75},
}
## Ground (the floor's `surface` holds the word) that takes each kind dry, besides the roads the shaped ground lays
## between the ways out (GroundRelief.roads, dusty); any outdoor ground splashes in the rain.
const DUSTY: Array[String] = ["road", "earth", "dirt", "sand", "scree", "gravel", "path", "ash"]
const SPLASHY: Array[String] = ["marsh", "bog", "water", "shallow"]
const SNOWY: Array[String] = ["snow"]

## Captures and the perf probe turn the puffs off to compare (perf_run.py --effects StepPuffs).
static var enabled := true
static var _dot: Texture2D = null

var atmosphere: Atmosphere
var view: Node
## Puffs made so far, per kind, and which to use next.
var _pools: Dictionary = {}
var _next: Dictionary = {}
## Where each party member's last puff was (member id -> Vector3).
var _last: Dictionary = {}
## The squares the shaped ground's roads run over (cell -> true), worked out on first use.
var _roads: Dictionary = {}
var _roads_done := false


static func set_enabled(on: bool) -> void:
	enabled = on


## The puffs for an outdoor place in the Modern finish, added to `atmo`; null anywhere else.
static func build(atmo: Atmosphere, view_: Node) -> StepPuffs:
	if not Look.modern() or atmo.board == null or not atmo.outdoors:
		return null
	var s := StepPuffs.new()
	s.name = "StepPuffs"
	s.atmosphere = atmo
	s.view = view_
	atmo.add_child(s)
	return s


## What a step on square `c` kicks up: "dust", "snow", "splash" or "" for nothing.
func kind_at(c: Vector2i) -> String:
	var board := atmosphere.board
	if not board.grid.in_bounds(c):
		return ""
	var box := board.floor_box(c)
	var m := box.material_override as ShaderMaterial if box != null else null
	var surface := str(m.get_meta("surface", "")) if m != null else ""
	if surface == "":
		return ""
	if atmosphere.snow_cover >= Atmosphere.SNOW_GROUND or SNOWY.any(func(w: String) -> bool: return surface.contains(w)):
		return "snow"
	if atmosphere.wetness > 0.0 or SPLASHY.any(func(w: String) -> bool: return surface.contains(w)):
		return "splash"
	if DUSTY.any(func(w: String) -> bool: return surface.contains(w)) or _on_road(c):
		return "dust"
	return ""


## Whether one of the roads the shaped ground lays between the ways out crosses square `c` (W11).
func _on_road(c: Vector2i) -> bool:
	if not _roads_done:
		_roads_done = true
		var land := atmosphere.land
		if land != null and land.relief != null:
			for line: PackedVector2Array in land.relief.roads():
				for p: Vector2 in line:
					_roads[Vector2i(floori(p.x), floori(p.y))] = true
	return _roads.has(c)


func _process(_delta: float) -> void:
	if not enabled or view == null:
		return
	# Only an exploring view has a party walking about (as Atmosphere._footprints reads it).
	var got_members: Variant = view.get("members")
	var got_tokens: Variant = view.get("tokens")
	if not (got_members is Array) or not (got_tokens is Dictionary):
		return
	var tokens := got_tokens as Dictionary
	for cb: Variant in got_members as Array:
		if not is_instance_valid(cb):
			continue
		var id := str((cb as Object).get("id"))
		var raw: Variant = tokens.get(id)
		if not is_instance_valid(raw) or not (raw is Node3D):
			continue
		var tok := raw as Node3D
		if not tok.is_visible_in_tree():
			continue
		var at := tok.global_position
		if not _last.has(id):
			_last[id] = at
			continue
		var from := _last[id] as Vector3
		if Vector2(at.x - from.x, at.z - from.z).length() < STEP:
			continue
		_last[id] = at
		var kind := kind_at(Vector2i(floori(at.x), floori(at.z)))
		if kind != "":
			puff(kind, at)


## A puff of `kind` at `at` (on the ground under a foot).
func puff(kind: String, at: Vector3) -> GPUParticles3D:
	if not enabled:
		return null
	var pool := _pools.get_or_add(kind, []) as Array
	var i := int(_next.get(kind, 0))
	var p: GPUParticles3D
	if i < pool.size():
		p = pool[i] as GPUParticles3D
	else:
		p = _make(KINDS[kind] as Dictionary)
		p.name = "%sPuff%d" % [kind.capitalize(), i]
		add_child(p)
		pool.append(p)
	_next[kind] = (i + 1) % POOL
	p.global_position = at + Vector3(0.0, 0.04, 0.0)
	p.restart()
	p.emitting = true
	return p


static func _make(k: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(k["amount"])
	p.lifetime = float(k["life"])
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 2.0, 2.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3.UP
	pm.spread = float(k["spread"])
	var speed := k["speed"] as Array
	pm.initial_velocity_min = float(speed[0])
	pm.initial_velocity_max = float(speed[1])
	pm.gravity = Vector3(0.0, float(k["gravity"]), 0.0)
	pm.damping_min = float(k["damping"])
	pm.damping_max = float(k["damping"])
	var size := k["size"] as Array
	# Each particle a random share of the quad's size (the quad below is the largest).
	pm.scale_min = float(size[0]) / float(size[1])
	pm.scale_max = 1.0
	var colour := Look.color(str(k["colour"]))
	var fade := Gradient.new()
	fade.set_color(0, Color(colour, float(k["alpha"])))
	fade.set_color(1, Color(colour, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	# Sized by the quad itself: the process material's scale alone didn't change how big they were drawn here.
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(size[1])
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	quad.material = m
	p.draw_pass_1 = quad
	return p


## A soft round dot, white in the middle fading out at the edge (made once).
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot
