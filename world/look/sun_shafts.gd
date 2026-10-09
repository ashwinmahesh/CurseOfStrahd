class_name SunShafts
extends Node3D
## Sunbeams and moonbeams out of doors (Visual Polish Plan 2, docs/art/atmosphere.md "Sunbeams and moonbeams"): a few
## slanted beams of light where it breaks through gaps in the trees and between the houses, each with a soft patch of
## light where it lands and motes turning in it. They lie along the key light (Atmosphere.sun), so they slant low and
## warm at dusk and dawn, thin and pale through the overcast by day and cold under the moon, turn with it as the time
## of day changes, fade in rain and thin in snow. Only in the Modern finish, out of doors; built with the place's
## weather (AtmosphereWeather.build). Cosmetic: its own random numbers, never the rules'.

const SHADER := preload("res://shaders/world/sun_shaft.gdshader")
## How bright the beams are at each time of day, and how much of that rain and snow leave.
const PHASE_STRENGTH := {"dawn": 0.16, "dusk": 0.17, "day": 0.13, "night": 0.1}
const RAIN := 0.2
const SNOW := 0.55
## Seconds a change of strength takes to settle (as Atmosphere.TRANSITION).
const FADE := 3.0
## How high above the ground a beam starts, the longest it gets when the light is low, and its width.
const TOP := 4.5
const MAX_LENGTH := 12.0
const RADIUS_TOP := 0.32
const RADIUS_FOOT := 0.55
## The beams never lean flatter than this (their slope, 1 = straight down): the play camera looks down from the
## south, and a beam much flatter would lie across the ground as a band instead of standing in the air.
const LOWEST := 0.72
## Where beams fall: on open squares with this many squares of shade (walls, trees, houses) in the 5 x 5 round them,
## so the light breaks through gaps rather than over open fields or deep in a wood; at least SPACING squares apart,
## one for every PER_OPEN open squares, between FEWEST and MOST.
const SHADE_MIN := 3
const SHADE_MAX := 15
const SPACING := 5
const PER_OPEN := 45
const FEWEST := 3
const MOST := 9
## Seconds between checks of the weather and of squares hidden behind secret doors.
const CHECK_EVERY := 0.5

## Captures and the perf probe turn the beams off to compare (perf_run.py --effects SunShafts).
static var enabled := true
## Every place's beams, so a switch shows at once.
const GROUP := &"sun_shafts"

var atmosphere: Atmosphere
var view: Node
## Each beam: {"cell": Vector2i, "foot": Vector3, "beam": MeshInstance3D, "pool": MeshInstance3D}
var beams: Array[Dictionary] = []
var shown := 0.0
var _weather := 1.0
var _check := 0.0


static func set_enabled(on: bool) -> void:
	enabled = on
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for n in tree.get_nodes_in_group(GROUP):
			(n as SunShafts)._update(0.0, true)


## The beams for an outdoor place in the Modern finish, added to `atmo`; null anywhere else.
static func build(atmo: Atmosphere, board: ArenaBoard, view_: Node) -> SunShafts:
	if not Look.modern() or board == null or not atmo.outdoors:
		return null
	var s := SunShafts.new()
	s.name = "SunShafts"
	s.atmosphere = atmo
	s.view = view_
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(atmo.loc_id + "/sun_shafts")
	for c in spots(board.grid, rng):
		s._add_beam(board, c, rng)
	atmo.add_child(s)
	return s


## Where the beams fall on a map: open squares (or water) with some shade round them, spread out.
static func spots(grid: CombatGrid, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var scored: Array[Array] = []
	var open := 0
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			if not _open(grid, c):
				continue
			open += 1
			var shade := 0
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var n := c + Vector2i(dx, dz)
					if grid.in_bounds(n) and grid.has_flag(n, CombatGrid.WALL):
						shade += 1
			if shade >= SHADE_MIN and shade <= SHADE_MAX:
				# Best halfway between open ground and the thick of the wood.
				scored.append([-absf(shade - 8.0) + rng.randf() * 4.0, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var want := clampi(open / PER_OPEN, FEWEST, MOST)
	var out: Array[Vector2i] = []
	for s in scored:
		var c := s[1] as Vector2i
		if out.any(func(o: Vector2i) -> bool: return maxi(absi(o.x - c.x), absi(o.y - c.y)) < SPACING):
			continue
		out.append(c)
		if out.size() >= want:
			break
	return out


static func _open(grid: CombatGrid, c: Vector2i) -> bool:
	if grid.has_flag(c, CombatGrid.WALL):
		return false
	return not grid.has_flag(c, CombatGrid.VOID) or grid.has_flag(c, CombatGrid.WATER)


func _add_beam(board: ArenaBoard, c: Vector2i, rng: RandomNumberGenerator) -> void:
	var foot := board.cell_center(c) + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
	var seed_ := rng.randf()
	var cone := CylinderMesh.new()
	cone.top_radius = RADIUS_TOP
	cone.bottom_radius = RADIUS_FOOT
	cone.height = 1.0   # scaled to the light's slope each frame
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := MeshInstance3D.new()
	beam.name = "SunBeam"
	beam.mesh = cone
	beam.material_override = _material(seed_, false)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var patch := PlaneMesh.new()
	patch.size = Vector2.ONE
	var pool := MeshInstance3D.new()
	pool.name = "SunPool"
	pool.mesh = patch
	pool.material_override = _material(seed_, true)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	beams.append({"cell": c, "foot": foot, "beam": beam, "pool": pool})


static func _material(seed_: float, pool: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = 1   # with the window shafts: after the screen pass, before the floor's rings and the figures
	m.set_shader_parameter("seed", seed_)
	m.set_shader_parameter("pool", pool)
	m.set_shader_parameter("shaft_length", 1.0)
	return m


func _ready() -> void:
	add_to_group(GROUP)
	_update(0.0, true)


func _process(delta: float) -> void:
	_update(delta, false)


## How strong the beams should be now: the time of day, then the weather.
func target() -> float:
	if not enabled or atmosphere == null:
		return 0.0
	return float(PHASE_STRENGTH.get(atmosphere.phase, 0.0)) * _weather


func _update(delta: float, now: bool) -> void:
	_check -= delta
	if now or _check <= 0.0:
		_check = CHECK_EVERY
		_weather = RAIN if atmosphere.has_weather("rain") else (SNOW if atmosphere.has_weather("snow") else 1.0)
		var place := view as LocationView
		for b in beams:
			var hide := place != null and HiddenAreas.hides(place, b["cell"] as Vector2i)
			(b["beam"] as Node3D).set_meta("hidden", hide)
	var goal := target()
	shown = goal if now else lerpf(shown, goal, clampf(delta * 3.0 / FADE, 0.0, 1.0))
	var on := shown > 0.003
	visible = on
	if not on:
		return
	# Along the key light: down the way it shines, never flatter than LOWEST.
	var down := -atmosphere.sun.global_basis.z.normalized()
	if down.y > -LOWEST:
		var flat := Vector2(down.x, down.z).normalized() * sqrt(1.0 - LOWEST * LOWEST)
		down = Vector3(flat.x, -LOWEST, flat.y)
	var up := -down
	var length := minf(TOP / up.y, MAX_LENGTH)
	var across := Vector3(down.x, 0.0, down.z)
	across = across.normalized() if across.length() > 0.01 else Vector3.FORWARD
	var side := across.cross(Vector3.UP).normalized()
	var colour := atmosphere.sun.light_color.lerp(Color.WHITE, 0.35)
	var stretch := 1.0 / maxf(up.y, LOWEST)
	for b in beams:
		var beam := b["beam"] as MeshInstance3D
		var pool := b["pool"] as MeshInstance3D
		var hide := bool(beam.get_meta("hidden", false))
		beam.visible = not hide
		pool.visible = not hide
		if hide:
			continue
		var foot := b["foot"] as Vector3
		beam.global_transform = Transform3D(Basis(side, up * length, side.cross(up)), foot + up * length * 0.5)
		pool.global_transform = Transform3D(Basis(side * RADIUS_FOOT * 2.2, Vector3.UP, across * RADIUS_FOOT * 2.2 * stretch),
			foot + Vector3(0.0, 0.05, 0.0))
		for m: ShaderMaterial in [beam.material_override as ShaderMaterial, pool.material_override as ShaderMaterial]:
			m.set_shader_parameter("strength", shown)
			m.set_shader_parameter("colour", colour)
