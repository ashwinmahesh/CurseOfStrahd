class_name FxZones
extends RefCounted
## How a lingering spell area looks for as long as it lasts (docs/art/spell_effects.md): Darkness as a dome of black
## mist, Wall of Fire burning, Spike Growth's thorns, Entangle's vines, Web's strands, Grease's slick, clouds of fog
## and poison, spirits circling Spirit Guardians, a shaft of moonlight. The field view (world/combat/field_view.gd)
## puts one under each zone it draws; art/vfx/effects.json `zones` picks the look and flavour per spell. Everything
## here runs on its own (looping particles, swaying meshes, flickering light) until the zone is freed.

## Most squares a look puts its own emitter or growth on (big areas spread them out).
const MAX_SPOTS := 36
## Every look `dress` builds.
const LOOKS: Array[String] = ["mist", "dark", "flames", "spikes", "vines", "tentacles", "web", "slick", "frost", "daggers",
	"swarm", "spirits", "aura", "dome", "beam", "light", "storm", "quake", "wind", "water", "prism"]


## The look picked for a lingering spell: {look, flavour, ...} or {} (the flat tint alone).
static func pick(spell_id: String) -> Dictionary:
	var spec := SpellFx._spec((SpellFx.data().get("zones", {}) as Dictionary).get(spell_id, ""))
	if spec.is_empty():
		return {}
	spec["look"] = spec["family"]
	if str(spec.get("flavour", "")) == "":
		var cue := SpellFx.spell_cue(spell_id)
		spec["flavour"] = str(cue.get("flavour", "arcane"))
	return spec


## Builds the look for zone `f` under `parent` (positions in world space, as the zone's squares are).
static func dress(parent: Node3D, f: FieldObject, board: ArenaBoard, spec: Dictionary) -> void:
	if f.cells.is_empty():
		return
	var flavour := str(spec["flavour"])
	var cols := SpellFx.colours(flavour)
	var names := SpellFx.colour_names(flavour)
	var ex := FxAreas.extent(f.cells, board)
	var heavy := str(f.rule("obscured", "")) == "heavy"
	match str(spec["look"]):
		"mist":
			mist(parent, f.cells, ex, cols, 0.75 if heavy else 0.4, false)
			if SpellFx.fiery(flavour) and flavour == "fire":
				embers(parent, ex, cols)
		"dark":
			mist(parent, f.cells, ex, {"edge": Look.color("ink"), "smoke": Look.color("void")}, 0.92, true)
		"flames":
			flames(parent, f.cells, board, cols)
		"spikes":
			growth(parent, f.cells, board, names, "spikes", float(spec.get("size", 1.0)))
		"vines":
			growth(parent, f.cells, board, names, "vines", float(spec.get("size", 1.0)))
		"tentacles":
			growth(parent, f.cells, board, names, "tentacles", float(spec.get("size", 1.0)))
		"web":
			growth(parent, f.cells, board, names, "web", 1.0)
			mist(parent, f.cells, ex, {"edge": Look.color("bone"), "smoke": Look.color("vellum")}, 0.15, false)
		"slick":
			slick(parent, f.cells, board, cols, 0.0)
		"frost":
			slick(parent, f.cells, board, cols, 1.0)
			if heavy:
				mist(parent, f.cells, ex, cols, 0.6, false)
		"daggers":
			daggers(parent, ex, f.cells.size(), cols)
		"swarm":
			swarm(parent, ex, f.cells.size(), cols)
			mist(parent, f.cells, ex, cols, 0.18, false)
		"spirits":
			spirits(parent, ex, cols)
			edge_ring(parent, ex, cols, 0.5)
		"aura":
			edge_ring(parent, ex, cols, 0.7)
			motes(parent, ex, f.cells.size(), cols)
		"dome":
			dome(parent, ex, cols)
		"beam":
			beam(parent, ex, cols)
		"light":
			glow_light(parent, ex, cols, 3.5)
			motes(parent, ex, f.cells.size(), cols)
		"storm":
			storm(parent, ex, cols)
		"quake":
			mist(parent, f.cells, ex, cols, 0.3, false)
		"wind":
			wind(parent, f.cells, ex, cols)
		"water":
			flames(parent, f.cells, board, cols)
			mist(parent, f.cells, ex, cols, 0.3, false)
		"prism":
			prism(parent, f.cells, board)


## A looping emitter that starts already full (preprocess), so a zone repainted as its caster moves never pops.
static func _loop(o: Dictionary) -> GPUParticles3D:
	o["one_shot"] = false
	var p := FxKit.particles(o)
	p.preprocess = p.lifetime
	p.emitting = true
	return p


static func _add(parent: Node3D, p: Node3D, at: Vector3) -> void:
	parent.add_child(p)
	if parent.is_inside_tree():
		p.global_position = at
	else:
		p.position = at - parent.position


## A cloud over the squares, thick (`density` up to 1) for what blocks sight. `dark` makes it the black of Darkness.
static func mist(parent: Node3D, cells: Array, ex: Dictionary, cols: Dictionary, density: float, dark: bool) -> void:
	var r := float(ex["radius"])
	var a := clampf(density, 0.1, 1.0)
	var p := _loop({"amount": int(clampf(cells.size() * (4.0 if dark else 1.6), 16.0, 360.0)), "lifetime": 4.0,
		"emit": "box", "box": Vector3(r * 0.72, 0.6 if dark else 0.45, r * 0.72), "speed": Vector2(0.03, 0.15), "spread": 180.0,
		"damping": Vector2(0.0, 0.1), "size": 2.1 if dark else 1.5, "grow": FxKit.curve(0.6, 1.0, 1.15, 0.4), "turbulence": 0.25,
		"colours": [Color(cols["edge"], 0.0), Color(cols["smoke"], a), Color(cols["edge"], a * 0.8), Color(cols["smoke"], 0.0)],
		"material": FxKit.smoke_material(0.85 if dark else 0.6)})
	(p.process_material as ParticleProcessMaterial).color_ramp = FxKit.ramp([Color(cols["edge"], 0.0), Color(cols["smoke"], a), Color(cols["edge"], a * 0.8), Color(cols["smoke"], 0.0)], false, false)
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.75, 0))


static func embers(parent: Node3D, ex: Dictionary, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var p := _loop({"amount": int(clampf(r * 20.0, 12.0, 120.0)), "lifetime": 2.0, "emit": "box", "box": Vector3(r * 0.7, 0.3, r * 0.7),
		"dir": Vector3.UP, "spread": 25.0, "speed": Vector2(0.3, 0.9), "gravity": Vector3(0, 0.3, 0), "size": 0.08, "turbulence": 0.6,
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 3.0)})
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.3, 0))


## Flames climbing from each square (Wall of Fire; tinted, a tsunami's spray), with light that flickers on what's near.
static func flames(parent: Node3D, cells: Array, board: ArenaBoard, cols: Dictionary) -> void:
	var places := FxAreas.spots(cells, board, MAX_SPOTS)
	var fire := FxKit.glow_material(FxKit.Shape.PUFF, cols["core"], 1.8)
	for p in places:
		var e := _loop({"amount": 22, "lifetime": 0.9, "emit": "box", "box": Vector3(0.45, 0.05, 0.45), "dir": Vector3.UP, "spread": 10.0,
			"speed": Vector2(0.9, 2.0), "damping": Vector2(0.5, 1.0), "size": 0.7, "grow": FxKit.curve(0.6, 1.0, 0.25, 0.3),
			"colours": [cols["core"], cols["glow"], cols["edge"], cols["smoke"]], "material": fire})
		_add(parent, e, p + Vector3(0, 0.05, 0))
	var sparks := _loop({"amount": int(clampf(places.size() * 6.0, 12.0, 160.0)), "lifetime": 1.6, "emit": "box",
		"box": Vector3(maxf(1.0, places.size() * 0.3), 0.3, maxf(1.0, places.size() * 0.3)), "dir": Vector3.UP, "spread": 20.0,
		"speed": Vector2(0.8, 2.0), "size": 0.06, "turbulence": 0.8, "colours": [cols["core"], cols["glow"]],
		"material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 3.0)})
	_add(parent, sparks, FxAreas.extent(cells, board)["mid"] as Vector3 + Vector3(0, 0.4, 0))
	var step := maxi(1, places.size() / 4)
	for i in range(0, places.size(), step):
		var l := CandleFlicker.new()
		l.light_color = cols["light"]
		l.base_energy = 1.4 * FxKit.LIGHT
		l.flicker = 0.4
		l.omni_range = 3.5
		l.shadow_enabled = false
		_add(parent, l, places[i] + Vector3(0, 1.0, 0))


## Things growing out of the floor, swaying: thorns, vines, tentacles or web strands, in the flavour's colours.
static func growth(parent: Node3D, cells: Array, board: ArenaBoard, names: Dictionary, kind: String, size: float) -> void:
	var rng := FxKit.rng
	var per := {"spikes": 9, "vines": 7, "tentacles": 1, "web": 7}[kind] as int
	var total := mini(cells.size() * per, 600)
	var mesh := CylinderMesh.new()
	var h := {"spikes": 0.5, "vines": 0.95, "tentacles": 1.6, "web": 1.1}[kind] as float
	h *= size
	mesh.height = h
	mesh.top_radius = {"spikes": 0.0, "vines": 0.01, "tentacles": 0.025, "web": 0.012}[kind] as float
	mesh.bottom_radius = {"spikes": 0.05, "vines": 0.04, "tentacles": 0.14, "web": 0.012}[kind] as float
	mesh.radial_segments = 6
	mesh.rings = 6 if kind != "spikes" else 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = total
	for i in total:
		var cell := cells[(i * cells.size()) / total] as Vector2i
		var spot := board.cell_center(cell) + Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
		var scale := rng.randf_range(0.6, 1.25)
		var b := Basis.IDENTITY
		if kind == "web":
			# Strands strung across the square at a slant, not standing up.
			b = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(1.0, 1.5))
			spot.y += rng.randf_range(0.15, 1.1)
		else:
			b = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
			spot.y += h * scale * 0.5
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(1, scale, 1)), spot))
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/fx/fx_sway.gdshader")
	var base := {"spikes": "edge", "vines": "edge", "tentacles": "edge", "web": "glow"}[kind] as String
	var tipc := {"spikes": "core", "vines": "glow", "tentacles": "glow", "web": "core"}[kind] as String
	m.set_shader_parameter("base", Look.color(str(names[base])))
	m.set_shader_parameter("tip", Look.color(str(names[tipc])))
	m.set_shader_parameter("height", h)
	m.set_shader_parameter("sway", {"spikes": 0.0, "vines": 0.08, "tentacles": 0.35, "web": 0.01}[kind] as float)
	m.set_shader_parameter("speed", 2.2 if kind == "tentacles" else 1.4)
	m.set_shader_parameter("glow", 0.6 if kind == "web" else 0.35)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# They push up out of the floor as the zone appears.
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("grow", v), 0.05, 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## A slick on each square: oily (Grease) or, with `glitter`, frost and ice.
static func slick(parent: Node3D, cells: Array, board: ArenaBoard, cols: Dictionary, glitter: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.0, 1.0)
	mm.mesh = pm
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, board.cell_center(cells[i] as Vector2i) + Vector3(0, 0.02, 0)))
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/fx/fx_slick.gdshader")
	m.set_shader_parameter("colour", Look.color("peat") if glitter == 0.0 else cols["edge"])
	m.set_shader_parameter("sheen", Look.color("tan") if glitter == 0.0 else cols["core"])
	m.set_shader_parameter("glitter", glitter)
	m.set_shader_parameter("opacity", 0.78 if glitter == 0.0 else 0.6)
	m.set_shader_parameter("noise_tex", FxKit.noise())
	m.render_priority = FxKit.FLOOR_PRIORITY
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Blades whirling round inside the area (Cloud of Daggers, Blade Barrier).
static func daggers(parent: Node3D, ex: Dictionary, n_cells: int, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var p := _loop({"amount": int(clampf(n_cells * 10.0, 20.0, 300.0)), "lifetime": 1.2, "emit": "box", "box": Vector3(r * 0.7, 0.5, r * 0.7),
		"speed": Vector2(1.0, 2.0), "orbit": Vector2(0.8, 1.4), "tangential": Vector2(2.0, 4.0), "size": Vector2(0.05, 0.28), "align": true,
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 2.6, false)})
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.8, 0))


## A swarm of tiny dark bodies boiling over the area (Insect Plague).
static func swarm(parent: Node3D, ex: Dictionary, n_cells: int, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var p := _loop({"amount": int(clampf(n_cells * 14.0, 40.0, 500.0)), "lifetime": 1.5, "emit": "box", "box": Vector3(r * 0.75, 0.7, r * 0.75),
		"speed": Vector2(0.5, 1.5), "turbulence": 2.5, "size": 0.07,
		"colours": [Color(Look.color("ink"), 0.9), Color(Look.color("peat"), 0.9)], "material": FxKit.smoke_material(1.0)})
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.9, 0))


## Spirits wheeling round the area's middle (Spirit Guardians, conjured spirits).
static func spirits(parent: Node3D, ex: Dictionary, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var p := _loop({"amount": int(clampf(r * 10.0, 10.0, 60.0)), "lifetime": 2.4, "emit": "ring", "radius": r * 0.75, "inner": r * 0.5,
		"ring_height": 0.6, "speed": Vector2(0.0, 0.1), "orbit": Vector2(0.18, 0.26), "damping": Vector2.ZERO, "size": 0.55,
		"grow": FxKit.curve(0.2, 1.0, 0.2, 0.5), "colours": [Color(cols["glow"], 0.0), cols["glow"], cols["edge"], Color(cols["edge"], 0.0)],
		"material": FxKit.glow_material(FxKit.Shape.PUFF, cols["core"], 1.4)})
	(p.process_material as ParticleProcessMaterial).color_ramp = FxKit.ramp([Color(cols["glow"], 0.0), cols["glow"], cols["edge"], Color(cols["edge"], 0.0)], false, false)
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.9, 0))


## A slowly turning circle of glyphs at the area's edge.
static func edge_ring(parent: Node3D, ex: Dictionary, cols: Dictionary, strength: float) -> void:
	var r := float(ex["radius"])
	var ring := FxKit.ring(parent, ex["mid"] as Vector3, r * 2.1, cols, 1.0, 1.4 * strength)
	var m := ring.material_override as ShaderMaterial
	m.set_shader_parameter("radius", 0.92)
	m.set_shader_parameter("width", 0.025)
	m.set_shader_parameter("spin", 0.15)
	m.set_shader_parameter("fill", 0.12)


## Motes of the flavour's light drifting up out of the area.
static func motes(parent: Node3D, ex: Dictionary, n_cells: int, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var p := _loop({"amount": int(clampf(n_cells * 1.5, 10.0, 120.0)), "lifetime": 2.5, "emit": "box", "box": Vector3(r * 0.7, 0.05, r * 0.7),
		"dir": Vector3.UP, "spread": 15.0, "speed": Vector2(0.2, 0.6), "size": 0.12, "grow": FxKit.curve(0.2, 1.0, 0.0, 0.3),
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.4)})
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.1, 0))


## A faint bubble over the area (Globe of Invulnerability, Antilife Shell, Silence).
static func dome(parent: Node3D, ex: Dictionary, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var shell := FxKit.shell(parent, ex["mid"] as Vector3, r, cols, 0.7)
	shell.scale = Vector3(1.0, 0.8, 1.0)
	edge_ring(parent, ex, cols, 0.6)


## A shaft of light standing on the area (Moonbeam, a celestial's light).
static func beam(parent: Node3D, ex: Dictionary, cols: Dictionary) -> void:
	var r := float(ex["radius"])
	var col := FxKit.column(parent, ex["mid"] as Vector3, r * 0.9, r * 0.9, 8.0, cols, 0.9)
	(col.material_override as ShaderMaterial).set_shader_parameter("scroll", -0.6)
	var fall := _loop({"amount": int(clampf(r * 18.0, 12.0, 80.0)), "lifetime": 2.0, "emit": "box", "box": Vector3(r * 0.6, 0.1, r * 0.6),
		"dir": Vector3.DOWN, "spread": 5.0, "speed": Vector2(1.5, 2.5), "size": 0.1, "colours": [cols["core"], cols["glow"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.4)})
	_add(parent, fall, (ex["mid"] as Vector3) + Vector3(0, 4.0, 0))
	glow_light(parent, ex, cols, 2.0)


static func glow_light(parent: Node3D, ex: Dictionary, cols: Dictionary, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = cols["light"]
	l.light_energy = energy * FxKit.LIGHT
	l.omni_range = float(ex["radius"]) * 2.0 + 2.0
	l.shadow_enabled = false
	_add(parent, l, (ex["mid"] as Vector3) + Vector3(0, 1.5, 0))


## A dark storm cloud over the area, lit from inside now and then by lightning that strikes down (Call Lightning).
static func storm(parent: Node3D, ex: Dictionary, cols: Dictionary) -> void:
	var r := maxf(float(ex["radius"]), 1.5)
	var cloud := _loop({"amount": int(clampf(r * 14.0, 20.0, 160.0)), "lifetime": 5.0, "emit": "box", "box": Vector3(r * 1.1, 0.4, r * 1.1),
		"speed": Vector2(0.05, 0.2), "size": 2.2, "turbulence": 0.2,
		"colours": [Color(Look.color("night"), 0.0), Color(Look.color("night_deep"), 0.8), Color(Look.color("night"), 0.7), Color(Look.color("night"), 0.0)],
		"material": FxKit.smoke_material(0.8)})
	(cloud.process_material as ParticleProcessMaterial).color_ramp = FxKit.ramp([Color(Look.color("night"), 0.0), Color(Look.color("night_deep"), 0.8), Color(Look.color("night"), 0.7), Color(Look.color("night"), 0.0)], false, false)
	var top := (ex["mid"] as Vector3) + Vector3(0, 5.5, 0)
	_add(parent, cloud, top)
	var flicker := CandleFlicker.new()
	flicker.light_color = cols["light"]
	flicker.base_energy = 0.8 * FxKit.LIGHT
	flicker.flicker = 0.9
	flicker.omni_range = r * 3.0
	flicker.shadow_enabled = false
	_add(parent, flicker, top)


## Wind streaming through the area (Gust of Wind, Wind Wall): streaks along its longer side.
static func wind(parent: Node3D, cells: Array, ex: Dictionary, cols: Dictionary) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Variant in cells:
		lo = lo.min(Vector2(c as Vector2i))
		hi = hi.max(Vector2(c as Vector2i))
	var span := hi - lo
	var dir := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var r := float(ex["radius"])
	var p := _loop({"amount": int(clampf(cells.size() * 4.0, 20.0, 240.0)), "lifetime": 0.9, "emit": "box",
		"box": Vector3(r * 0.7, 0.6, r * 0.7), "dir": dir, "spread": 6.0, "speed": Vector2(4.0, 7.0), "size": Vector2(0.03, 0.4),
		"align": true, "colours": [Color(cols["glow"], 0.0), cols["glow"], Color(cols["edge"], 0.0)],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 1.4, false)})
	_add(parent, p, (ex["mid"] as Vector3) + Vector3(0, 0.8, 0))


## A shimmering wall of many colours (Prismatic Wall): a sheet of light on each square, each its own hue.
static func prism(parent: Node3D, cells: Array, board: ArenaBoard) -> void:
	var hues: Array[String] = ["vampire_red", "candle", "wick", "bile", "mist_blue", "moon_blue", "orchid"]
	var places := FxAreas.spots(cells, board, MAX_SPOTS)
	for i in places.size():
		var h := Look.color(hues[i % hues.size()])
		FxKit.column(parent, places[i], 0.5, 0.5, 3.0, {"core": Look.color("ivory"), "glow": h}, 1.2)
