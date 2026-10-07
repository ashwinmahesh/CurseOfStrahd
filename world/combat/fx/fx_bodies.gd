class_name FxBodies
extends RefCounted
## Effects that play on a creature (docs/art/spell_effects.md): healing welling up, a blessing, a curse settling, a
## mind assailed, a ward closing round it, a smite landing, a summoning circle, a jump through space, a change of
## shape, a small working of magic, a blow landing.


## Warm light wells up round `t`: a soft shaft, motes spiralling up and a circle of light at its feet.
static func heal(fx: SpellFx, cue: Dictionary, t: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var size := float(cue.get("size", 1.0))
	var feet := t.global_position
	var h := SpellFx.height_of(t)
	var shaft := FxKit.column(fx, feet, 0.4 * size, 0.24 * size, h * 1.5, cols, 0.55)
	(shaft.material_override as ShaderMaterial).set_shader_parameter("scroll", -1.6)
	(shaft.material_override as ShaderMaterial).set_shader_parameter("core", cols["edge"])
	fx.pulse(shaft, 0.25, 0.35, 0.8)
	var circle := FxKit.ring(fx, feet, 1.7 * size, cols, 0.8, 2.0)
	var cm := circle.material_override as ShaderMaterial
	cm.set_shader_parameter("spin", 0.6)
	cm.set_shader_parameter("width", 0.06)
	cm.set_shader_parameter("fill", 0.35)
	FxKit.tween_param(circle, "radius", 0.3, 0.62, 0.35 * fx.pace())
	fx.pulse(circle, 0.2, 0.5, 0.7)
	var motes := FxKit.particles({"amount": 34, "lifetime": 1.3, "emit": "ring", "radius": 0.42 * size, "inner": 0.2 * size,
		"explosiveness": 0.35, "dir": Vector3.UP, "spread": 12.0, "speed": Vector2(0.6, 1.3), "damping": Vector2(0.2, 0.6),
		"orbit": Vector2(0.25, 0.45), "size": 0.16 * size, "grow": FxKit.curve(0.2, 1.0, 0.0, 0.3),
		"colours": [cols["core"], cols["glow"], cols["edge"]], "fade_in": true, "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.8)})
	var glow := FxKit.particles({"amount": 8, "lifetime": 0.9, "emit": "sphere", "radius": 0.25, "speed": Vector2(0.1, 0.3),
		"dir": Vector3.UP, "size": 0.6 * size, "grow": FxKit.curve(0.4, 1.0, 0.6, 0.4), "explosiveness": 0.7,
		"colours": [cols["glow"], cols["edge"]], "fade_in": true, "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["glow"], 0.7)})
	fx.emit(motes, feet + Vector3(0, 0.05, 0))
	fx.emit(glow, SpellFx.chest(t))
	FxKit.flash(fx, SpellFx.chest(t) + Vector3(0, 0.3, 0), cols["light"], 1.6, 3.0, 0.25, 1.0)


## A blessing on `t`: a circle of glyphs at its feet, glints spiralling up round it and a crown of light overhead.
static func buff(fx: SpellFx, cue: Dictionary, t: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var feet := t.global_position
	var h := SpellFx.height_of(t)
	var circle := FxKit.ring(fx, feet, 1.6, cols, 1.0, 2.2)
	var cm := circle.material_override as ShaderMaterial
	cm.set_shader_parameter("width", 0.04)
	cm.set_shader_parameter("spin", -0.8)
	FxKit.tween_param(circle, "radius", 0.2, 0.7, 0.3 * fx.pace())
	fx.pulse(circle, 0.15, 0.45, 0.6)
	var spiral := FxKit.particles({"amount": 30, "lifetime": 0.9, "emit": "ring", "radius": 0.45, "inner": 0.4, "explosiveness": 0.2,
		"dir": Vector3.UP, "spread": 4.0, "speed": Vector2(1.6, 2.2), "damping": Vector2(1.0, 1.5), "orbit": Vector2(0.6, 0.8),
		"size": 0.14, "colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 3.0)})
	fx.emit(spiral, feet + Vector3(0, 0.05, 0))
	var crown := FxKit.ring(fx, feet + Vector3(0, h + 0.15, 0), 0.9, cols, 0.0, 2.6)
	(crown.material_override as ShaderMaterial).set_shader_parameter("width", 0.08)
	(crown.material_override as ShaderMaterial).render_priority = FxKit.PRIORITY
	FxKit.tween_param(crown, "radius", 0.9, 0.55, 0.35 * fx.pace())
	fx.pulse(crown, 0.25, 0.3, 0.5)
	FxKit.flash(fx, SpellFx.chest(t) + Vector3(0, 0.4, 0), cols["light"], 2.4, 2.6, 0.2, 0.8)


## A curse settling on `t`: dark wisps sinking onto it from above, a band of the flavour's light closing round its feet.
static func debuff(fx: SpellFx, cue: Dictionary, caster: CombatToken, t: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var feet := t.global_position
	var h := SpellFx.height_of(t)
	if caster != null and caster != t:
		FxMissiles.beam(fx, cue, SpellFx.hand(caster, SpellFx.chest(t)), SpellFx.chest(t), true, true)
	var wisps := FxKit.particles({"amount": 16, "lifetime": 1.2, "emit": "ring", "radius": 0.5, "inner": 0.2, "explosiveness": 0.4,
		"dir": Vector3.DOWN, "spread": 20.0, "speed": Vector2(0.6, 1.2), "gravity": Vector3(0, -0.6, 0), "size": 0.7,
		"grow": FxKit.curve(0.3, 1.0, 0.6, 0.3), "fade_in": true,
		"colours": [Color(cols["smoke"], 0.8), Color(cols["smoke"], 0.5)], "material": FxKit.smoke_material(0.7)})
	var sparks := FxKit.particles({"amount": 20, "lifetime": 1.0, "emit": "ring", "radius": 0.45, "inner": 0.3, "explosiveness": 0.4,
		"dir": Vector3.DOWN, "spread": 10.0, "speed": Vector2(0.8, 1.4), "orbit": Vector2(-0.4, -0.2), "size": 0.12,
		"colours": [cols["glow"], cols["edge"]], "fade_in": true, "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.4)})
	fx.emit(wisps, feet + Vector3(0, h + 0.6, 0))
	fx.emit(sparks, feet + Vector3(0, h + 0.5, 0))
	var band := FxKit.ring(fx, feet, 1.5, cols, 0.0, 1.8)
	(band.material_override as ShaderMaterial).set_shader_parameter("width", 0.1)
	FxKit.tween_param(band, "radius", 0.9, 0.45, 0.5 * fx.pace(), Tween.EASE_IN)
	fx.pulse(band, 0.15, 0.5, 0.6)


## A mind assailed: rings of the flavour's light rippling in round `t`'s head, glints and a pulse of light.
static func psychic(fx: SpellFx, cue: Dictionary, caster: CombatToken, t: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var head := t.global_position + Vector3(0, SpellFx.height_of(t) * 0.88, 0)
	var ripples := FxKit.particles({"amount": 5, "lifetime": 0.55, "one_shot": true, "explosiveness": 0.0, "speed": Vector2.ZERO,
		"size": 1.4, "grow": FxKit.curve(1.0, 0.6, 0.1, 0.1), "spin": Vector2.ZERO, "colours": [cols["glow"], cols["edge"]], "fade_in": true,
		"material": FxKit.glow_material(FxKit.Shape.RING, cols["core"], 2.6)})
	var glints := FxKit.particles({"amount": 14, "lifetime": 0.7, "emit": "sphere", "radius": 0.4, "speed": Vector2(0.1, 0.5),
		"size": 0.14, "colours": [cols["core"], cols["glow"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.8)})
	fx.emit(ripples, head)
	fx.emit(glints, head)
	FxKit.flash(fx, head, cols["light"], 2.4, 2.4, 0.1, 0.6)
	if caster != null and caster != t:
		var at := caster.global_position + Vector3(0, SpellFx.height_of(caster) * 0.88, 0)
		var out := FxKit.particles({"amount": 2, "lifetime": 0.4, "explosiveness": 0.0, "speed": Vector2.ZERO, "size": 0.8,
			"grow": FxKit.curve(0.1, 0.7, 1.0, 0.5), "spin": Vector2.ZERO, "colours": [cols["glow"], cols["edge"]],
			"material": FxKit.glow_material(FxKit.Shape.RING, cols["core"], 2.0)})
		fx.emit(out, at)


## A ward closing round `t`: a bubble of the flavour's light that pops into place and fades, with glints on its skin.
static func ward(fx: SpellFx, cue: Dictionary, t: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var h := SpellFx.height_of(t)
	var centre := t.global_position + Vector3(0, h * 0.5, 0)
	var bubble := FxKit.shell(fx, centre, maxf(0.55, h * 0.62), cols, 1.8)
	bubble.scale = Vector3.ONE * 0.6
	var pop := bubble.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pop.tween_property(bubble, "scale", Vector3.ONE, 0.25 * fx.pace())
	fx.pulse(bubble, 0.08, 0.45, 0.6)
	var glints := FxKit.particles({"amount": 22, "lifetime": 0.8, "emit": "shell", "radius": maxf(0.55, h * 0.62), "speed": Vector2(0.0, 0.2),
		"size": 0.13, "explosiveness": 0.6, "colours": [cols["core"], cols["glow"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.8)})
	fx.emit(glints, centre)
	FxKit.flash(fx, centre, cols["light"], 2.0, 2.6, 0.08, 0.7)


## The blow lands in a flare of light: a shaft strikes down on `target`, a burst and sparks at the wound, a ring
## races across the floor, and the striker glows.
static func smite(fx: SpellFx, cue: Dictionary, caster: CombatToken, target: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var size := float(cue.get("size", 1.0))
	var feet := target.global_position
	var at := SpellFx.chest(target)
	var h := SpellFx.height_of(target)
	var shaft := FxKit.column(fx, feet, 0.2 * size, 0.3 * size, h + 2.6, cols, 1.2)
	var sm := shaft.material_override as ShaderMaterial
	sm.set_shader_parameter("scroll", 4.0)
	sm.set_shader_parameter("core", cols["glow"])
	var down := shaft.create_tween()
	down.tween_method(func(v: float) -> void: sm.set_shader_parameter("fade", v), 0.0, 1.0, 0.05)
	down.tween_property(shaft, "scale", Vector3(0.25, 1.0, 0.25), 0.45 * fx.pace()).set_ease(Tween.EASE_IN)
	down.parallel().tween_method(func(v: float) -> void: sm.set_shader_parameter("fade", v), 1.0, 0.0, 0.45 * fx.pace())
	down.tween_callback(shaft.queue_free)
	FxAreas.shockwave(fx, cue, feet, 3.4 * size, 0.42)
	var star := FxKit.particles({"amount": 1, "lifetime": 0.35, "speed": Vector2.ZERO, "size": 1.8 * size, "spin": Vector2.ZERO,
		"grow": FxKit.curve(0.2, 1.0, 0.0, 0.2), "colours": [cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 1.8)})
	var burst := FxKit.particles({"amount": 30, "lifetime": 0.5, "emit": "sphere", "radius": 0.12, "speed": Vector2(1.0, 3.0),
		"damping": Vector2(4.0, 6.0), "size": 0.4 * size, "grow": FxKit.curve(0.5, 1.0, 0.2),
		"colours": [cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["glow"], 1.6)})
	var sparks := FxKit.particles({"amount": 46, "lifetime": 0.7, "speed": Vector2(3.0, 7.0), "damping": Vector2(2.0, 4.0),
		"gravity": Vector3(0, -6.0, 0), "size": Vector2(0.04, 0.26), "align": true,
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.2, false)})
	var motes := FxKit.particles({"amount": 24, "lifetime": 1.1, "emit": "sphere", "radius": 0.45, "dir": Vector3.UP, "spread": 20.0,
		"speed": Vector2(0.4, 1.2), "size": 0.12, "explosiveness": 0.5, "colours": [cols["core"], cols["glow"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.8)})
	for p: GPUParticles3D in [burst, sparks, star, motes]:
		fx.emit(p, at)
	FxKit.flash(fx, at + Vector3(0, 0.8, 0), cols["light"], 5.0, 5.0, 0.03, 0.7)
	if caster != null and caster != target:
		FxKit.flash(fx, SpellFx.chest(caster), cols["light"], 2.0, 2.2, 0.05, 0.45)
	fx.shake(0.05, 0.2)


## A summoning at `ground`: a circle of glyphs opens, light rises from it and a flash brings the creature or thing.
static func summon(fx: SpellFx, cue: Dictionary, ground: Vector3, size: float = 1.0) -> void:
	var cols := cue["colours"] as Dictionary
	var circle := FxKit.ring(fx, ground, 2.2 * size, cols, 1.0, 2.4)
	var cm := circle.material_override as ShaderMaterial
	cm.set_shader_parameter("width", 0.035)
	cm.set_shader_parameter("spin", 1.2)
	cm.set_shader_parameter("fill", 0.4)
	FxKit.tween_param(circle, "radius", 0.1, 0.8, 0.35 * fx.pace())
	fx.pulse(circle, 0.1, 0.7, 0.8)
	var pillar := FxKit.column(fx, ground, 0.6 * size, 0.45 * size, 3.0, cols, 1.8)
	(pillar.material_override as ShaderMaterial).set_shader_parameter("scroll", -3.0)
	fx.pulse(pillar, 0.15, 0.3, 0.6)
	var rise := FxKit.particles({"amount": 40, "lifetime": 1.1, "emit": "ring", "radius": 0.7 * size, "inner": 0.1, "explosiveness": 0.4,
		"dir": Vector3.UP, "spread": 8.0, "speed": Vector2(1.0, 2.6), "damping": Vector2(0.5, 1.0), "orbit": Vector2(0.2, 0.4),
		"size": 0.15, "colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.8)})
	fx.emit(rise, ground + Vector3(0, 0.05, 0))
	FxKit.flash(fx, ground + Vector3(0, 1.0, 0), cols["light"], 4.0, 3.5, 0.2, 0.7)


## A jump through space: mist and glints burst where the creature was and where it lands.
static func blink(fx: SpellFx, cue: Dictionary, at: Vector3, arriving: bool) -> void:
	var cols := cue["colours"] as Dictionary
	var mist := FxKit.particles({"amount": 16, "lifetime": 0.9, "emit": "sphere", "radius": 0.35, "speed": Vector2(0.4, 1.2),
		"damping": Vector2(1.5, 2.5), "size": 0.8, "grow": FxKit.curve(0.4, 1.0, 1.2, 0.3), "fade_in": true,
		"colours": [Color(cols["smoke"], 0.7), Color(cols["edge"], 0.4)], "material": FxKit.smoke_material(0.6)})
	var glints := FxKit.particles({"amount": 26, "lifetime": 0.6, "emit": "sphere", "radius": 0.3,
		"speed": Vector2(0.8, 2.4) if not arriving else Vector2(0.1, 0.4), "radial": Vector2.ZERO if not arriving else Vector2(-7.0, -5.0), "size": 0.16,
		"colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 3.0)})
	fx.emit(mist, at + Vector3(0, 0.6, 0))
	fx.emit(glints, at + Vector3(0, 0.7, 0))
	var swirl := FxKit.ring(fx, at, 1.6, cols, 0.6, 2.0)
	FxKit.tween_param(swirl, "radius", 0.7 if arriving else 0.2, 0.2 if arriving else 0.75, 0.35 * fx.pace())
	fx.pulse(swirl, 0.05, 0.2, 0.4)
	FxKit.flash(fx, at + Vector3(0, 0.8, 0), cols["light"], 3.0, 2.8, 0.04, 0.5)


## A change of shape or seeming: motes whirling round `t` from its feet to its head, and a flash at the end.
static func transform(fx: SpellFx, cue: Dictionary, t: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var feet := t.global_position
	var h := SpellFx.height_of(t)
	var whirl := FxKit.particles({"amount": 60, "lifetime": 0.9, "emit": "ring", "radius": 0.55, "inner": 0.45, "explosiveness": 0.1,
		"dir": Vector3.UP, "spread": 2.0, "speed": Vector2(h * 1.2, h * 1.6), "damping": Vector2(h, h * 1.4), "orbit": Vector2(1.2, 1.6),
		"size": 0.2, "colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 2.6)})
	fx.emit(whirl, feet + Vector3(0, 0.05, 0))
	var puff := FxKit.particles({"amount": 10, "lifetime": 0.9, "emit": "sphere", "radius": 0.4, "speed": Vector2(0.3, 0.8),
		"size": 0.9, "grow": FxKit.curve(0.4, 1.0, 1.2, 0.3), "fade_in": true,
		"colours": [Color(cols["edge"], 0.6), Color(cols["smoke"], 0.3)], "material": FxKit.smoke_material(0.5)})
	fx.get_tree().create_timer(0.45 * fx.pace()).timeout.connect(func() -> void:
		fx.emit(puff, SpellFx.chest(t))
		FxKit.flash(fx, SpellFx.chest(t), cols["light"], 3.0, 3.0, 0.03, 0.6))


## A small working (Detect Magic, Light, Mage Hand): a glimmer in the caster's hand and a few motes.
static func glimmer(fx: SpellFx, cue: Dictionary, caster: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var at := SpellFx.hand(caster, caster.global_position + caster.global_transform.basis.z)
	var p := FxKit.particles({"amount": 18, "lifetime": 0.8, "emit": "sphere", "radius": 0.15, "speed": Vector2(0.2, 0.7),
		"dir": Vector3.UP, "spread": 60.0, "size": 0.14, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 2.8)})
	fx.emit(p, at)
	FxKit.flash(fx, at, cols["light"], 1.6, 2.0, 0.1, 0.5)


## A blow landing (a claw, a bite, a blade): a crescent of light swept across the wound and sparks.
static func slash(fx: SpellFx, cue: Dictionary, attacker: CombatToken, target: CombatToken, critical: bool) -> void:
	var cols := cue["colours"] as Dictionary
	var at := SpellFx.chest(target)
	var from := attacker.global_position if attacker != null else at + Vector3.LEFT
	var toward := Vector3(at.x - from.x, 0, at.z - from.z).normalized()
	var side := toward.cross(Vector3.UP).normalized()
	var root := Node3D.new()
	fx.add_child(root)
	var sweep := FxKit.particles({"amount": 60, "lifetime": 0.22, "one_shot": false, "emit": "point", "speed": Vector2(0.0, 0.1),
		"size": 0.22 * (1.4 if critical else 1.0), "grow": FxKit.curve(1.0, 0.8, 0.0, 0.05), "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 3.0)})
	root.add_child(sweep)
	sweep.emitting = true
	var r := 0.45 * (1.3 if critical else 1.0)
	var tw := root.create_tween()
	tw.tween_method(func(k: float) -> void:
		var a := lerpf(-1.2, 1.2, k)
		root.global_position = at + side * sin(a) * r + Vector3(0, cos(a) * r * 0.9 - r * 0.3, 0) - toward * 0.1, 0.0, 1.0, 0.12 * fx.pace())
	tw.tween_callback(func() -> void: sweep.emitting = false)
	FxKit.free_after(root, 0.6)
	var sparks := FxKit.particles({"amount": 14 if not critical else 30, "lifetime": 0.4, "dir": toward, "spread": 50.0,
		"speed": Vector2(1.5, 4.0), "damping": Vector2(2.0, 4.0), "gravity": Vector3(0, -5.0, 0), "size": Vector2(0.03, 0.18), "align": true,
		"colours": [cols["core"], cols["glow"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
	fx.emit(sparks, at)
	if critical:
		FxKit.flash(fx, at, cols["light"], 3.0, 2.6, 0.03, 0.4)
