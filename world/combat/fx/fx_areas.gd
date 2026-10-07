class_name FxAreas
extends RefCounted
## Effects that fill an area (docs/art/spell_effects.md): an explosion, a cone or line from the caster's hands, a
## shockwave out from the caster, a strike from the sky, a cloud, a wall, the ground erupting, an aura. Each is sized to
## the spell's own squares, so the same effect serves a 5-foot Thunderclap and a 60-foot Sunburst.


## The middle of `cells` on the floor, how far the area reaches from it (world units) and its floor height.
static func extent(cells: Array, board: ArenaBoard) -> Dictionary:
	var mid := Vector3.ZERO
	for c: Variant in cells:
		mid += board.cell_center(c as Vector2i)
	mid /= float(maxi(1, cells.size()))
	var radius := 0.5
	for c: Variant in cells:
		var p := board.cell_center(c as Vector2i)
		radius = maxf(radius, Vector2(p.x - mid.x, p.z - mid.z).length() + 0.5)
	return {"mid": mid, "radius": radius, "floor": mid.y}


## The squares' floor points, at most `cap` of them spread evenly (a big wall or cloud needs no emitter per square).
static func spots(cells: Array, board: ArenaBoard, cap: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var step := maxi(1, ceili(float(cells.size()) / float(cap)))
	for i in range(0, cells.size(), step):
		out.append(board.cell_center(cells[i] as Vector2i))
	return out


# --- Burst ----------------------------------------------------------------------------------------------

## A bead streaks from the caster's hand to the middle of `cells` and explodes over them.
static func burst(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	if cells.is_empty():
		return
	var ex := extent(cells, board)
	var radius := float(ex["radius"]) * float(cue.get("size", 1.0))
	var mid := ex["mid"] as Vector3
	var centre := Vector3(mid.x, float(ex["floor"]) + minf(radius * 0.2, 0.9), mid.z)
	var from := SpellFx.hand(caster, centre)
	var bead := Node3D.new()
	bead.name = "Bead_" + str(cue["key"])
	fx.add_child(bead)
	bead.global_position = from
	fx.quad(bead, 0.55, FxKit.Shape.GLOW, cols["glow"], cols["core"], 3.0)
	fx.quad(bead, 0.2, FxKit.Shape.GLOW, cols["core"], cols["core"], 4.0)
	var tail := FxKit.particles({"amount": 16, "lifetime": 0.18, "one_shot": false, "local": true, "emit": "sphere", "radius": 0.05,
		"speed": Vector2(0.1, 0.4), "size": 0.4, "grow": FxKit.curve(0.6, 1.0, 0.2),
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.PUFF, cols["core"], 2.2)})
	bead.add_child(tail)
	tail.emitting = true
	var bl := OmniLight3D.new()
	bl.light_color = cols["light"]
	bl.light_energy = 2.0
	bl.omni_range = 3.0
	bead.add_child(bl)
	var dist := from.distance_to(centre)
	var time := clampf(dist / 16.0, 0.22, 0.6) * fx.pace()
	var arc := clampf(dist * 0.12, 0.3, 1.4)
	var streak := FxMissiles.comet(fx, cols, 0.42)
	var tw := bead.create_tween()
	tw.tween_method(func(k: float) -> void:
		var at := from.lerp(centre, k) + Vector3(0, sin(k * PI) * arc, 0)
		bead.global_position = at
		var kb := maxf(0.0, k - 1.8 / maxf(dist, 0.01))
		FxMissiles._aim_comet(streak, from.lerp(centre, kb) + Vector3(0, sin(kb * PI) * arc, 0), at), 0.0, 1.0, time)
	await tw.finished
	FxMissiles._drop_comet(fx, streak)
	tail.emitting = false
	for ch in bead.get_children():
		if ch is MeshInstance3D or ch is OmniLight3D:
			ch.queue_free()
	FxKit.free_after(bead, 0.5)
	explode(fx, cue, centre, float(ex["floor"]), radius)
	await fx.wait(0.28)


## The explosion: a churning ball the size of the area, a shockwave along the floor, flames, sparks, smoke, light.
static func explode(fx: SpellFx, cue: Dictionary, centre: Vector3, floor_y: float, radius: float) -> void:
	var cols := cue["colours"] as Dictionary
	var ball := FxKit.blast(fx, centre, cols, 2.4)
	ball.scale = Vector3.ONE * radius * 0.1
	var grow := ball.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	grow.tween_property(ball, "scale", Vector3(1.0, 0.75, 1.0) * radius * 0.55, 0.45 * fx.pace())
	FxKit.tween_param(ball, "progress", 0.0, 1.0, 1.25 * fx.pace(), Tween.EASE_IN_OUT, Tween.TRANS_SINE).finished.connect(ball.queue_free)
	FxKit.flash(fx, centre + Vector3(0, 0.8, 0), cols["light"], 6.0, radius * 2.4, 0.04, 1.0)
	var ground := Vector3(centre.x, floor_y, centre.z)
	shockwave(fx, cue, ground, radius * 2.6, 0.5)
	var scorch := FxKit.ring(fx, ground, radius * 2.0, cols, 0.0, 1.2)
	(scorch.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0)
	(scorch.material_override as ShaderMaterial).set_shader_parameter("radius", 0.9)
	FxKit.tween_param(scorch, "fade", 0.9, 0.0, 1.4 * fx.pace(), Tween.EASE_IN).finished.connect(scorch.queue_free)
	var flames := FxKit.particles({"amount": 40, "lifetime": 0.85, "emit": "shell", "radius": radius * 0.2,
		"speed": Vector2(1.2, 2.4) * radius, "damping": Vector2(4.0, 6.0) * radius, "size": radius * 0.36,
		"grow": FxKit.curve(0.4, 1.0, 0.5, 0.25), "gravity": Vector3(0, 1.2, 0),
		"colours": [cols["glow"], cols["edge"], cols["smoke"]], "material": FxKit.glow_material(FxKit.Shape.PUFF, cols["core"], 1.6)})
	var sparks := FxKit.particles({"amount": 80, "lifetime": 1.1, "emit": "sphere", "radius": radius * 0.2,
		"speed": Vector2(2.5, 6.5) * sqrt(radius), "damping": Vector2(0.5, 1.5), "gravity": Vector3(0, -7.0, 0),
		"size": Vector2(0.05, 0.3), "align": true, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.2, false)})
	var smoke := FxKit.particles({"amount": 16, "lifetime": 2.0, "emit": "sphere", "radius": radius * 0.4,
		"speed": Vector2(0.3, 0.9), "gravity": Vector3(0, 0.7, 0), "damping": Vector2(0.3, 0.6), "size": radius * 0.5,
		"grow": FxKit.curve(0.4, 1.0, 1.4, 0.35), "fade_in": true, "explosiveness": 0.6,
		"colours": [Color(cols["smoke"], 0.55), Color(cols["smoke"], 0.3)], "material": FxKit.smoke_material(0.6)})
	var embers := FxKit.particles({"amount": 30, "lifetime": 1.8, "emit": "box", "box": Vector3(radius * 0.8, 0.1, radius * 0.8),
		"speed": Vector2(0.2, 0.8), "dir": Vector3.UP, "spread": 25.0, "gravity": Vector3(0, 0.4, 0), "size": 0.09,
		"explosiveness": 0.3, "turbulence": 0.6, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 3.0)})
	fx.emit(smoke, centre)
	fx.emit(flames, centre)
	fx.emit(sparks, centre)
	fx.emit(embers, ground + Vector3(0, 0.15, 0))
	fx.shake(clampf(radius * 0.035, 0.03, 0.14), 0.35)


## A ring of the flavour's light racing out across the floor, `size` across.
static func shockwave(fx: SpellFx, cue: Dictionary, ground: Vector3, size: float, seconds: float) -> void:
	var wave := FxKit.ring(fx, ground, size, cue["colours"] as Dictionary, 0.0, 2.6)
	FxKit.tween_param(wave, "radius", 0.08, 0.96, seconds * fx.pace())
	FxKit.tween_param(wave, "width", 0.16, 0.05, seconds * fx.pace())
	FxKit.tween_param(wave, "fade", 1.0, 0.0, seconds * 1.3 * fx.pace(), Tween.EASE_IN).finished.connect(wave.queue_free)


# --- From the caster's hands: cone and line -------------------------------------------------------------

## A spray from the caster's hands over the cone's squares: flame, frost, light or force rushing out and fanning wide.
static func cone(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	if cells.is_empty():
		return
	var ex := extent(cells, board)
	var mid := ex["mid"] as Vector3
	var from := SpellFx.hand(caster, mid)
	var flat := Vector3(mid.x - from.x, 0, mid.z - from.z)
	var reach := 0.5
	for c: Variant in cells:
		var p := board.cell_center(c as Vector2i)
		reach = maxf(reach, Vector2(p.x - from.x, p.z - from.z).length() + 0.5)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var life := 0.55
	var speed := reach / life * 1.6
	var flavour := str(cue["flavour"])
	var shape := FxKit.Shape.PUFF if SpellFx.fiery(flavour) else FxKit.Shape.GLOW
	var spray := FxKit.particles({"amount": int(clampf(reach * 22.0, 40.0, 220.0)), "lifetime": life, "explosiveness": 0.55,
		"emit": "sphere", "radius": 0.08, "dir": dir, "spread": 26.0, "speed": Vector2(speed * 0.7, speed),
		"damping": Vector2(speed * 0.8, speed * 1.2), "size": 0.45 + reach * 0.12, "grow": FxKit.curve(0.3, 1.0, 1.4, 0.3),
		"colours": [cols["core"], cols["glow"], cols["edge"], cols["smoke"]], "material": FxKit.glow_material(shape, cols["core"], 2.4)})
	var shards := FxKit.particles({"amount": int(clampf(reach * 10.0, 20.0, 90.0)), "lifetime": life * 1.1, "explosiveness": 0.6,
		"dir": dir, "spread": 24.0, "speed": Vector2(speed * 0.6, speed * 1.1), "damping": Vector2(speed * 0.5, speed),
		"size": Vector2(0.05, 0.3), "align": true, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
	fx.emit(spray, from)
	fx.emit(shards, from)
	FxKit.flash(fx, from, cols["light"], 3.5, 3.0, 0.04, 0.5)
	FxKit.flash(fx, from + dir * reach * 0.6, cols["light"], 4.0, reach * 1.2, 0.12, 0.6)
	await fx.wait(0.32)


## Energy along the line's squares from the caster: a forked lightning bolt, or a wide rushing beam of light or wind.
static func line(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	if cells.is_empty():
		return
	var ex := extent(cells, board)
	var from := SpellFx.hand(caster, ex["mid"] as Vector3)
	var far := from
	for c: Variant in cells:
		var p := board.cell_center(c as Vector2i) + Vector3(0, from.y - board.cell_center(c as Vector2i).y, 0)
		if p.distance_to(from) > far.distance_to(from):
			far = p
	var root := Node3D.new()
	root.name = "Line_" + str(cue["key"])
	fx.add_child(root)
	var lightning := str(cue["flavour"]) == "lightning"
	var strands: Array[MeshInstance3D] = []
	if lightning:
		strands.append(FxKit.beam(root, from, far, 0.35, cols, 0.9, 3.4))
		strands.append(FxKit.beam(root, from, far, 0.18, cols, 1.4, 3.0))
		strands.append(FxKit.beam(root, from, far, 0.12, cols, 1.8, 2.4))
	else:
		strands.append(FxKit.beam(root, from, far, 1.1, cols, 0.0, 1.8))
		strands.append(FxKit.beam(root, from, far, 0.4, cols, 0.04, 2.8))
	for b in strands:
		FxKit.tween_param(b, "reach", 0.0, 1.0, 0.08 * fx.pace())
		(b.material_override as ShaderMaterial).set_shader_parameter("jag_rate", 14.0)
	var axis := far - from
	var rush := FxKit.particles({"amount": int(clampf(axis.length() * 12.0, 30.0, 200.0)), "lifetime": 0.6, "explosiveness": 0.4,
		"emit": "box", "box": Vector3(0.25, 0.25, axis.length() / 2.0), "dir": Vector3(0, 0, -1), "spread": 15.0,
		"speed": Vector2(1.0, 4.0), "size": Vector2(0.05, 0.3), "align": true, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
	root.add_child(rush)
	rush.global_transform = Transform3D(Basis.looking_at(axis.normalized(), Vector3.UP), from.lerp(far, 0.5))
	FxKit.fire(rush)
	for i in 3:
		FxKit.flash(root, from.lerp(far, (i + 0.5) / 3.0), cols["light"], 4.0, axis.length() / 2.0 + 1.5, 0.03, 0.5)
	var out := root.create_tween()
	out.tween_interval(0.3 * fx.pace())
	for b in strands:
		out.parallel().tween_method(func(v: float) -> void: (b.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.35 * fx.pace())
	out.tween_callback(root.queue_free)
	fx.shake(0.06, 0.25)
	await fx.wait(0.3)


# --- Around the caster: nova and aura ------------------------------------------------------------------

## A shockwave bursting out of the caster over the area: a ring racing across the floor, a shell of the flavour's
## light, sparks flung out.
static func nova(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	var feet := caster.global_position
	var radius := 1.6
	for c: Variant in cells:
		var p := board.cell_center(c as Vector2i)
		radius = maxf(radius, Vector2(p.x - feet.x, p.z - feet.z).length() + 0.5)
	radius *= float(cue.get("size", 1.0))
	shockwave(fx, cue, feet, radius * 2.2, 0.4)
	var shell := FxKit.particles({"amount": int(clampf(radius * 30.0, 40.0, 200.0)), "lifetime": 0.55, "explosiveness": 0.95,
		"emit": "sphere", "radius": 0.3, "speed": Vector2(radius * 2.4, radius * 3.0), "damping": Vector2(radius * 3.0, radius * 4.0),
		"size": 0.35 + radius * 0.1, "grow": FxKit.curve(0.4, 1.0, 0.6, 0.2), "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 2.2)})
	var sparks := FxKit.particles({"amount": 50, "lifetime": 0.6, "emit": "sphere", "radius": 0.3, "speed": Vector2(radius * 2.0, radius * 4.0),
		"damping": Vector2(2.0, 4.0), "size": Vector2(0.05, 0.28), "align": true, "colours": [cols["core"], cols["glow"]],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
	var at := SpellFx.chest(caster)
	fx.emit(shell, at)
	fx.emit(sparks, at)
	FxKit.flash(fx, at + Vector3(0, 0.5, 0), cols["light"], 6.0, radius * 2.5, 0.04, 0.6)
	fx.shake(clampf(radius * 0.02, 0.02, 0.1), 0.25)
	await fx.wait(0.25)


## An aura settling round the caster: a circle of glyphs opening to the area's edge, motes circling, a soft glow.
static func aura(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	var feet := caster.global_position
	var radius := 1.5
	for c: Variant in cells:
		var p := board.cell_center(c as Vector2i)
		radius = maxf(radius, Vector2(p.x - feet.x, p.z - feet.z).length() + 0.5)
	var circle := FxKit.ring(fx, feet, radius * 2.2, cols, 1.0, 2.2)
	var cm := circle.material_override as ShaderMaterial
	cm.set_shader_parameter("width", 0.03)
	cm.set_shader_parameter("spin", 0.4)
	cm.set_shader_parameter("fill", 0.25)
	FxKit.tween_param(circle, "radius", 0.1, 0.9, 0.5 * fx.pace())
	fx.pulse(circle, 0.15, 0.7, 0.8)
	var motes := FxKit.particles({"amount": int(clampf(radius * 14.0, 24.0, 120.0)), "lifetime": 1.4, "explosiveness": 0.4,
		"emit": "ring", "radius": radius * 0.9, "inner": radius * 0.4, "dir": Vector3.UP, "spread": 10.0, "speed": Vector2(0.3, 0.9),
		"orbit": Vector2(0.1, 0.2), "size": 0.16, "grow": FxKit.curve(0.2, 1.0, 0.0, 0.3), "fade_in": true,
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.6)})
	fx.emit(motes, feet + Vector3(0, 0.1, 0))
	FxKit.flash(fx, SpellFx.chest(caster), cols["light"], 2.5, radius * 2.0, 0.2, 1.0)
	await fx.wait(0.35)


# --- On the area: strike, cloud, wall, ground ------------------------------------------------------------

## Something coming down from the sky: a pillar of light or fire, a lightning bolt, hail. On the area's squares (a
## column the area's size) or on each target.
static func strike(fx: SpellFx, cue: Dictionary, caster: CombatToken, targets: Array[CombatToken], cells: Array, board: ArenaBoard) -> void:
	var places: Array[Dictionary] = []
	if not cells.is_empty():
		var ex := extent(cells, board)
		places.append({"at": ex["mid"], "radius": float(ex["radius"])})
	else:
		for t in targets:
			if t != caster:
				places.append({"at": t.global_position, "radius": 0.55})
	for pl in places:
		_strike_one(fx, cue, pl["at"] as Vector3, float(pl["radius"]) * float(cue.get("size", 1.0)))
		await fx.wait(0.08)
	await fx.wait(0.25)


static func _strike_one(fx: SpellFx, cue: Dictionary, ground: Vector3, radius: float) -> void:
	var cols := cue["colours"] as Dictionary
	var flavour := str(cue["flavour"])
	var sky := ground + Vector3(0.3, 9.0, -0.2)
	if flavour == "lightning":
		var root := Node3D.new()
		fx.add_child(root)
		var strands: Array[MeshInstance3D] = [FxKit.beam(root, sky, ground, 0.45, cols, 1.2, 3.6), FxKit.beam(root, sky, ground, 0.2, cols, 1.8, 3.0)]
		for b in strands:
			FxKit.tween_param(b, "reach", 0.0, 1.0, 0.06 * fx.pace())
		var out := root.create_tween()
		out.tween_interval(0.25 * fx.pace())
		for b in strands:
			out.parallel().tween_method(func(v: float) -> void: (b.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.3 * fx.pace())
		out.tween_callback(root.queue_free)
	elif flavour in ["cold", "water"] or str(cue["key"]) == "ice_storm":
		var hail := FxKit.particles({"amount": int(clampf(radius * 30.0, 30.0, 220.0)), "lifetime": 0.55, "explosiveness": 0.3,
			"emit": "box", "box": Vector3(radius * 0.8, 0.2, radius * 0.8), "dir": Vector3.DOWN, "spread": 5.0,
			"speed": Vector2(14.0, 18.0), "damping": Vector2.ZERO, "size": Vector2(0.06, 0.45), "align": true,
			"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 2.8, false)})
		fx.emit(hail, ground + Vector3(0, 8.0, 0))
	var shaft := FxKit.column(fx, ground, radius * 0.85, radius * 1.05, 9.0, cols, 2.4)
	var sm := shaft.material_override as ShaderMaterial
	sm.set_shader_parameter("scroll", 5.0)
	var down := shaft.create_tween()
	down.tween_method(func(v: float) -> void: sm.set_shader_parameter("fade", v), 0.0, 1.0, 0.06)
	down.tween_interval(0.12 * fx.pace())
	down.tween_property(shaft, "scale", Vector3(0.2, 1.0, 0.2), 0.45 * fx.pace()).set_ease(Tween.EASE_IN)
	down.parallel().tween_method(func(v: float) -> void: sm.set_shader_parameter("fade", v), 1.0, 0.0, 0.45 * fx.pace())
	down.tween_callback(shaft.queue_free)
	var t := fx.get_tree().create_timer(0.08 * fx.pace())
	t.timeout.connect(func() -> void:
		shockwave(fx, cue, ground, radius * 3.0, 0.4)
		var splash := FxKit.particles({"amount": int(clampf(radius * 26.0, 24.0, 160.0)), "lifetime": 0.7, "emit": "ring",
			"radius": radius * 0.6, "inner": 0.0, "dir": Vector3.UP, "spread": 40.0, "speed": Vector2(2.0, 5.0), "damping": Vector2(2.0, 4.0),
			"gravity": Vector3(0, -6.0, 0), "size": 0.4, "grow": FxKit.curve(0.5, 1.0, 0.2),
			"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.PUFF if SpellFx.fiery(flavour) else FxKit.Shape.GLOW, cols["core"], 2.4)})
		fx.emit(splash, ground + Vector3(0, 0.1, 0))
		FxKit.flash(fx, ground + Vector3(0, 1.0, 0), cols["light"], 7.0, radius * 3.0 + 2.0, 0.03, 0.7)
		fx.shake(clampf(radius * 0.03, 0.03, 0.12), 0.3))


## A cloud billowing out over the squares, thick at first and settling into the lingering zone the field shows.
static func cloud(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	if cells.is_empty():
		return
	var ex := extent(cells, board)
	var radius := float(ex["radius"])
	var ground := ex["mid"] as Vector3
	var billow := FxKit.particles({"amount": int(clampf(cells.size() * 2.0, 24.0, 160.0)), "lifetime": 2.4, "explosiveness": 0.75,
		"emit": "box", "box": Vector3(radius * 0.75, 0.3, radius * 0.75), "dir": Vector3.UP, "spread": 60.0,
		"speed": Vector2(0.3, 1.2), "damping": Vector2(0.5, 1.0), "size": 1.4, "grow": FxKit.curve(0.3, 1.0, 1.3, 0.3), "fade_in": true,
		"colours": [Color(cols["edge"], 0.8), Color(cols["smoke"], 0.7), Color(cols["smoke"], 0.4)], "material": FxKit.smoke_material(0.65)})
	var glow := FxKit.particles({"amount": int(clampf(cells.size(), 12.0, 80.0)), "lifetime": 1.6, "explosiveness": 0.6,
		"emit": "box", "box": Vector3(radius * 0.7, 0.4, radius * 0.7), "speed": Vector2(0.1, 0.5), "size": 0.9,
		"grow": FxKit.curve(0.3, 1.0, 0.5, 0.4), "fade_in": true, "colours": [cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.PUFF, cols["core"], 1.2)})
	fx.emit(billow, ground + Vector3(0, 0.5, 0))
	fx.emit(glow, ground + Vector3(0, 0.6, 0))
	var from := SpellFx.hand(caster, ground)
	if from.distance_to(ground) > 1.5:
		FxMissiles.bolt(fx, cue, from, ground + Vector3(0, 0.6, 0), true, true)
	await fx.wait(0.4)


## A wall rising along its squares: a sheet of the flavour's fire, force, stone or ice climbing out of the floor.
static func wall(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	var flavour := str(cue["flavour"])
	var places := spots(cells, board, 24)
	var i := 0
	for p in places:
		var rise := FxKit.particles({"amount": 18, "lifetime": 1.1, "explosiveness": 0.5, "emit": "box", "box": Vector3(0.45, 0.05, 0.45),
			"dir": Vector3.UP, "spread": 8.0, "speed": Vector2(1.6, 3.2), "damping": Vector2(1.0, 2.0), "size": 0.6,
			"grow": FxKit.curve(0.5, 1.0, 0.3, 0.3), "colours": [cols["core"], cols["glow"], cols["edge"], cols["smoke"]],
			"material": FxKit.glow_material(FxKit.Shape.PUFF if SpellFx.fiery(flavour) else FxKit.Shape.GLOW, cols["core"], 2.2)})
		fx.get_tree().create_timer(i * 0.025 * fx.pace()).timeout.connect(func() -> void: fx.emit(rise, p))
		var sheet := FxKit.column(fx, p, 0.5, 0.5, 2.2, cols, 1.6)
		fx.pulse(sheet, 0.12 + i * 0.025, 0.4, 0.6)
		i += 1
	if not places.is_empty():
		FxKit.flash(fx, places[places.size() / 2] + Vector3(0, 1.0, 0), cols["light"], 4.0, 4.0 + places.size() * 0.3, 0.1, 0.8)
	await fx.wait(0.4)


## The ground erupting over the squares: vines, spikes, tentacles or webbing thrown up, dust and a circle of glyphs.
static func ground(fx: SpellFx, cue: Dictionary, caster: CombatToken, cells: Array, board: ArenaBoard) -> void:
	var cols := cue["colours"] as Dictionary
	if cells.is_empty():
		return
	var ex := extent(cells, board)
	var radius := float(ex["radius"])
	var mid := ex["mid"] as Vector3
	var spikes := FxKit.particles({"amount": int(clampf(cells.size() * 3.0, 30.0, 200.0)), "lifetime": 0.8, "explosiveness": 0.7,
		"emit": "box", "box": Vector3(radius * 0.8, 0.02, radius * 0.8), "dir": Vector3.UP, "spread": 18.0, "speed": Vector2(1.5, 3.5),
		"damping": Vector2(3.0, 5.0), "size": Vector2(0.08, 0.5), "align": true, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 2.4, false)})
	var dust := FxKit.particles({"amount": int(clampf(cells.size() * 1.2, 16.0, 90.0)), "lifetime": 1.6, "explosiveness": 0.8,
		"emit": "box", "box": Vector3(radius * 0.8, 0.05, radius * 0.8), "dir": Vector3.UP, "spread": 50.0, "speed": Vector2(0.3, 0.9),
		"size": 0.9, "grow": FxKit.curve(0.3, 1.0, 1.2, 0.3), "fade_in": true,
		"colours": [Color(cols["smoke"], 0.6), Color(cols["smoke"], 0.3)], "material": FxKit.smoke_material(0.55)})
	fx.emit(spikes, mid + Vector3(0, 0.05, 0))
	fx.emit(dust, mid + Vector3(0, 0.2, 0))
	var circle := FxKit.ring(fx, mid, radius * 2.2, cols, 0.7, 1.6)
	(circle.material_override as ShaderMaterial).set_shader_parameter("radius", 0.88)
	(circle.material_override as ShaderMaterial).set_shader_parameter("fill", 0.3)
	fx.pulse(circle, 0.15, 0.5, 0.8)
	fx.shake(0.04, 0.3)
	await fx.wait(0.35)
