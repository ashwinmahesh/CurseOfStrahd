class_name FxMissiles
extends RefCounted
## Effects that travel from one creature to another (docs/art/spell_effects.md): a bolt with its trail, a thin ray,
## a crackling beam, an arrow or thrown rock, a touch, life drawn out of a victim. Each returns a signal for the
## moment it lands, so the view shows the damage then.


## Sends `family`'s missile from `from` to `to`; the signal fires when it lands (or flies past on a miss).
static func fly(fx: SpellFx, family: String, cue: Dictionary, from: Vector3, to: Vector3, hit: bool) -> Signal:
	match family:
		"beam":
			return beam(fx, cue, from, to, hit, false)
		"ray":
			return beam(fx, cue, from, to, hit, true)
		"touch":
			return touch(fx, cue, from, to, hit)
		"drain":
			return drain(fx, cue, from, to, hit)
		"shot":
			return bolt(fx, cue, from, to, hit, true)
	return bolt(fx, cue, from, to, hit, false)


static func _fiery(cue: Dictionary) -> bool:
	return str(cue["flavour"]) in ["fire", "radiant", "necrotic", "acid", "poison", "nature", "earth", "blood"]


## Where a missed missile ends: past the target and a little to one side.
static func _past(fx: SpellFx, from: Vector3, to: Vector3, beyond: float) -> Vector3:
	var past := (to - from).normalized()
	var side := past.cross(Vector3.UP).normalized() * (0.5 if fx.rng.randf() < 0.5 else -0.5)
	return to + past * beyond + side + Vector3(0, 0.25, 0)


## A glowing missile with a flickering body and a trail left in the world; `small` makes it an arrow or a stone
## (a bright streak, no halo or light).
static func bolt(fx: SpellFx, cue: Dictionary, from: Vector3, to: Vector3, hit: bool, small: bool) -> Signal:
	var cols := cue["colours"] as Dictionary
	var size := float(cue.get("size", 1.0)) * (0.45 if small else 1.0)
	var fiery := _fiery(cue)
	var root := Node3D.new()
	root.name = "Bolt_" + str(cue["key"])
	fx.add_child(root)
	root.global_position = from
	var parts: Array[GPUParticles3D] = []
	if not small:
		fx.quad(root, 0.7 * size, FxKit.Shape.GLOW, cols["glow"], cols["core"], 2.2)
		var body := FxKit.particles({"amount": 16, "lifetime": 0.18, "one_shot": false, "local": true, "emit": "sphere",
			"radius": 0.06 * size, "speed": Vector2(0.1, 0.4), "size": 0.42 * size, "grow": FxKit.curve(0.6, 1.0, 0.2),
			"colours": [cols["core"], cols["glow"], cols["edge"]],
			"material": FxKit.glow_material(FxKit.Shape.PUFF if fiery else FxKit.Shape.GLOW, cols["core"], 2.4)})
		parts.append(body)
	fx.quad(root, 0.28 * size, FxKit.Shape.GLOW, cols["core"], cols["core"], 3.5)
	if not small:
		var sparks := FxKit.particles({"amount": 30, "lifetime": 0.35, "one_shot": false, "speed": Vector2(0.4, 1.4),
			"size": Vector2(0.03, 0.16) * size, "align": true, "gravity": Vector3(0, -2.5 if fiery else 0.0, 0),
			"colours": [cols["core"], cols["glow"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
		parts.append(sparks)
		var light := OmniLight3D.new()
		light.light_color = cols["light"]
		light.light_energy = 2.2
		light.omni_range = 2.8
		light.shadow_enabled = false
		root.add_child(light)
	for p in parts:
		root.add_child(p)
		p.emitting = true
	var end := to if hit else _past(fx, from, to, 2.5)
	var dist := from.distance_to(end)
	var time := clampf(dist / (26.0 if small else 20.0), 0.14, 0.55) * fx.pace()
	var arc := minf(dist * (0.06 if small else 0.04), 0.4)
	# A comet's tail: a ribbon from a little behind the missile to the missile, thin at the back.
	var tail := comet(fx, cols, (0.5 if not small else 0.14) * size)
	var tail_len := (1.6 if not small else 0.9) * size
	var tw := root.create_tween()
	tw.tween_method(func(k: float) -> void:
		var at := from.lerp(end, k) + Vector3(0, sin(k * PI) * arc, 0)
		root.global_position = at
		var back := from.lerp(end, maxf(0.0, k - tail_len / maxf(dist, 0.01))) + Vector3(0, sin(maxf(0.0, k - tail_len / maxf(dist, 0.01)) * PI) * arc, 0)
		_aim_comet(tail, back, at), 0.0, 1.0, time)
	tw.tween_callback(func() -> void:
		_drop_comet(fx, tail)
		for p in parts:
			p.emitting = false
		for ch in root.get_children():
			if ch is MeshInstance3D:
				(ch as MeshInstance3D).hide()
			elif ch is OmniLight3D:
				ch.queue_free()
		if hit:
			impact(fx, cue, end, size * (0.6 if small else 1.0))
		else:
			fizzle(fx, cue, end)
		FxKit.free_after(root, 0.6))
	return tw.finished


## A tapering ribbon of light that trails a missile (move it with _aim_comet; _drop_comet fades it).
static func comet(fx: SpellFx, cols: Dictionary, width: float) -> MeshInstance3D:
	var c := FxKit.beam(fx, Vector3.ZERO, Vector3(0, 0, 0.01), width, cols, 0.0, 2.2)
	var m := c.material_override as ShaderMaterial
	m.set_shader_parameter("taper", 1.0)
	m.set_shader_parameter("flow", 14.0)
	return c


static func _aim_comet(c: MeshInstance3D, back: Vector3, front: Vector3) -> void:
	var m := c.material_override as ShaderMaterial
	m.set_shader_parameter("p0", back)
	m.set_shader_parameter("p1", front + (front - back).normalized() * 0.05)


static func _drop_comet(fx: SpellFx, c: MeshInstance3D) -> void:
	var m := c.material_override as ShaderMaterial
	var tw := c.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, 0.18 * fx.pace())
	tw.tween_callback(c.queue_free)


## A beam (crackling, wide) or a ray (thin, straight, quick) joining hand and target for a moment.
static func beam(fx: SpellFx, cue: Dictionary, from: Vector3, to: Vector3, hit: bool, thin: bool) -> Signal:
	var cols := cue["colours"] as Dictionary
	var size := float(cue.get("size", 1.0))
	var lightning := str(cue["flavour"]) == "lightning"
	var end := to if hit else _past(fx, from, to, 1.8)
	var root := Node3D.new()
	root.name = ("Ray_" if thin else "Beam_") + str(cue["key"])
	fx.add_child(root)
	var strands: Array[MeshInstance3D] = []
	if thin:
		strands.append(FxKit.beam(root, from, end, 0.2 * size, cols, 0.25 if lightning else 0.0, 3.0))
		strands.append(FxKit.beam(root, from, end, 0.55 * size, cols, 0.0, 0.9))
	else:
		# The beam, and crackles of its own colour (no white core) wound round it.
		var dim := cols.duplicate()
		dim["core"] = cols["glow"]
		dim["glow"] = cols["edge"]
		strands.append(FxKit.beam(root, from, end, 0.5 * size, cols, 0.3 if lightning else 0.03, 2.6))
		var crackle := FxKit.beam(root, from, end, 0.14 * size, dim, 0.45 if lightning else 0.16, 2.6)
		(crackle.material_override as ShaderMaterial).set_shader_parameter("jag_rate", 24.0)
		strands.append(crackle)
		strands.append(FxKit.beam(root, from, end, 0.1 * size, dim, 0.12, 2.2))
	var grow := (0.05 if thin else 0.07) * fx.pace()
	for b in strands:
		FxKit.tween_param(b, "reach", 0.0, 1.0, grow)
	var flare := FxKit.particles({"amount": 18, "lifetime": 0.35, "emit": "sphere", "radius": 0.05, "speed": Vector2(0.4, 1.6),
		"size": 0.22 * size, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.6)})
	fx.emit(flare, from, root)
	FxKit.flash(root, from, cols["light"], 2.5, 2.5, 0.04, 0.4)
	FxKit.flash(root, from.lerp(end, 0.5), cols["light"], 3.0, from.distance_to(end) * 0.6 + 1.5, 0.05, 0.45)
	var hold := (0.14 if thin else 0.22) * fx.pace()
	var tw := root.create_tween()
	tw.tween_interval(grow)
	tw.tween_callback(func() -> void:
		if hit:
			impact(fx, cue, end, (0.7 if thin else 0.9) * size)
		else:
			fizzle(fx, cue, end))
	tw.tween_interval(hold)
	var landed := tw.finished
	var out := root.create_tween()
	out.tween_interval(grow + hold)
	for b in strands:
		out.parallel().tween_method(func(v: float) -> void: (b.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.28 * fx.pace())
	out.tween_callback(root.queue_free)
	return landed


## A hand reaching out: a short flare from hand to target and a tight burst on the hit.
static func touch(fx: SpellFx, cue: Dictionary, from: Vector3, to: Vector3, hit: bool) -> Signal:
	var cols := cue["colours"] as Dictionary
	var mid := from.lerp(to, 0.6)
	var grip := FxKit.particles({"amount": 22, "lifetime": 0.3, "emit": "sphere", "radius": 0.08, "speed": Vector2(0.3, 1.2),
		"size": 0.3, "colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.6)})
	fx.emit(grip, from)
	FxKit.flash(fx, from, cols["light"], 2.0, 2.0, 0.04, 0.3)
	var t := fx.get_tree().create_timer(0.12 * fx.pace())
	t.timeout.connect(func() -> void:
		if hit:
			impact(fx, cue, mid.lerp(to, 0.7), 0.7)
		else:
			fizzle(fx, cue, mid))
	return t.timeout


## Life drawn out of the target into the caster: a thin dark ray, then motes streaming back along it.
static func drain(fx: SpellFx, cue: Dictionary, from: Vector3, to: Vector3, hit: bool) -> Signal:
	var landed := beam(fx, cue, from, to, hit, true)
	if not hit:
		return landed
	var cols := cue["colours"] as Dictionary
	var back := to.direction_to(from)
	var dist := to.distance_to(from)
	var stream := FxKit.particles({"amount": 34, "lifetime": 0.5, "emit": "sphere", "radius": 0.15, "dir": back, "spread": 6.0,
		"speed": Vector2(dist / 0.55, dist / 0.45), "damping": Vector2.ZERO, "size": 0.2, "explosiveness": 0.2,
		"colours": [cols["glow"], cols["core"], cols["edge"]], "fade_in": true, "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 2.4)})
	var t := fx.get_tree().create_timer(0.1 * fx.pace())
	t.timeout.connect(func() -> void:
		fx.emit(stream, to)
		FxKit.flash(fx, from, cols["light"], 2.0, 2.4, 0.3, 0.5))
	return landed


## A missile lands: a flash of the flavour's light, a puff of its fire, sparks and a glint.
static func impact(fx: SpellFx, cue: Dictionary, at: Vector3, size: float) -> void:
	var cols := cue["colours"] as Dictionary
	var fiery := _fiery(cue)
	FxKit.flash(fx, at, cols["light"], 4.5 * size, 4.0 * size, 0.03, 0.55)
	var puff := FxKit.particles({"amount": 26, "lifetime": 0.5, "emit": "sphere", "radius": 0.1 * size, "speed": Vector2(0.8, 2.6) * size,
		"damping": Vector2(4.0, 6.0), "size": 0.5 * size, "grow": FxKit.curve(0.5, 1.0, 0.3),
		"colours": [cols["glow"], cols["edge"], cols["smoke"]],
		"material": FxKit.glow_material(FxKit.Shape.PUFF if fiery else FxKit.Shape.GLOW, cols["core"], 1.8)})
	var sparks := FxKit.particles({"amount": 28, "lifetime": 0.55, "speed": Vector2(2.0, 5.0) * size, "damping": Vector2(2.0, 4.0),
		"size": Vector2(0.035, 0.22) * size, "align": true, "gravity": Vector3(0, -5.0, 0),
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
	var glint := FxKit.particles({"amount": 1, "lifetime": 0.28, "speed": Vector2.ZERO, "size": 1.1 * size,
		"grow": FxKit.curve(0.3, 1.0, 0.0, 0.25), "spin": Vector2.ZERO, "colours": [cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.2)})
	var smoke := FxKit.particles({"amount": 6, "lifetime": 1.1, "emit": "sphere", "radius": 0.15 * size, "speed": Vector2(0.2, 0.6),
		"gravity": Vector3(0, 0.6, 0), "size": 0.6 * size, "grow": FxKit.curve(0.5, 1.0, 1.3, 0.3), "fade_in": true,
		"colours": [Color(cols["smoke"], 0.6), Color(cols["smoke"], 0.3)], "material": FxKit.smoke_material(0.6)})
	for p: GPUParticles3D in [smoke, puff, sparks, glint]:
		fx.emit(p, at)


## A missile that missed fades out where it ends.
static func fizzle(fx: SpellFx, cue: Dictionary, at: Vector3) -> void:
	var cols := cue["colours"] as Dictionary
	var p := FxKit.particles({"amount": 12, "lifetime": 0.4, "emit": "sphere", "radius": 0.08, "speed": Vector2(0.3, 1.0),
		"size": 0.25, "colours": [cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 1.6)})
	fx.emit(p, at)
