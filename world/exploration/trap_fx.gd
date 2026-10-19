class_name TrapFx
extends RefCounted
## What a trap going off looks like on whoever it catches outside a fight (owner todo 2026-10-17): the fights' own 3D
## effects (world/combat/fx, docs/art/spell_effects.md) picked by what the trap does, so fire bursts over a lamp's victim,
## a glyph calls down lightning, blades slash, needles and bolts fly in, a floor or a beam gives way in dust and debris.
## art/vfx/effects.json holds the picks: `traps` by trap id, `checks` by a check's id (a failed climb or swim that
## hurts), then `trap_damage` by damage type, each "<family>@<flavour>" or an object {family, flavour, size, count, from}.
## Besides the fights' families (burst, strike, nova, cloud, psychic, slash, ward) two are a trap's own: `darts`
## (count of them flying in `from` above, the side or below) and `crash` (a falling weight or a failing floor: chunks,
## dust, a shockwave and a shake). LocationHurt plays them when the roll has been seen; nothing here touches the rules.

## The families a trap's look can use.
const FAMILIES: Array[String] = ["burst", "strike", "nova", "cloud", "psychic", "slash", "ward", "darts", "crash", "ground"]
## A successful save still springs the trap, but it plays smaller (the half damage it did).
const SAVED_SIZE := 0.6
## Physical harm that sounds as a blow lands (CombatSfx.hit_kind's kinds); anything else sounds as its family does.
const BLOWS := {&"slashing": "blade", &"bludgeoning": "blunt", &"piercing": "point"}


## The look for `id` in `source` ("traps" or "checks") that did `type` damage: {family, flavour, size, colours, key, ...}.
## `pit`: the floor dropped away (a pit is a crash, whatever its stakes do). `saved`: the save held, so it plays smaller.
static func cue(source: String, id: String, type: StringName, pit: bool = false, saved: bool = false) -> Dictionary:
	var table := SpellFx.data()
	var spec := SpellFx._spec((table.get(source, {}) as Dictionary).get(id, ""))
	if spec.is_empty() and pit:
		spec = {"family": "crash", "flavour": "earth"}
	if spec.is_empty():
		spec = SpellFx._spec((table.get("trap_damage", {}) as Dictionary).get(str(type), ""))
	if not str(spec.get("family", "")) in FAMILIES:
		spec = {"family": "burst"}   # a kind of harm nobody gave a look still flashes
	if str(spec.get("flavour", "")) == "":
		spec["flavour"] = str((table.get("damage_flavours", {}) as Dictionary).get(str(type), "arcane"))
	if saved:
		spec["size"] = float(spec.get("size", 1.0)) * SAVED_SIZE
	spec["key"] = "%s:%s" % [source, id]
	spec["type"] = str(type)
	spec["colours"] = SpellFx.colours(str(spec["flavour"]))
	return spec


## The sound of a blow for physical harm of `type`, or "" (an element sounds as its effect does).
static func blow(type: StringName) -> String:
	return str(BLOWS.get(type, ""))


## Plays `cue` on `victim` (its token) with `fx`, a SpellFx in the view. Starts the effect and returns: its parts free
## themselves.
static func play(fx: SpellFx, cue: Dictionary, victim: CombatToken, view: LocationView) -> void:
	var size := float(cue.get("size", 1.0))
	var feet := victim.global_position
	var cell := victim.combatant.cell
	match str(cue["family"]):
		"burst":
			var radius := 1.1 * size
			FxAreas.explode(fx, cue, feet + Vector3(0, minf(radius * 0.2, 0.9), 0), feet.y, radius)
		"strike":
			CombatSfx.cast(cue)
			FxAreas.strike(fx, cue, victim, [] as Array[CombatToken], [cell], view.board)
		"nova":
			CombatSfx.cast(cue)
			FxAreas.nova(fx, cue, victim, [], view.board)
		"cloud":
			CombatSfx.cast(cue)
			FxAreas.cloud(fx, cue, victim, _around(view, cell), view.board)
		"ground":
			CombatSfx.cast(cue)
			FxAreas.ground(fx, cue, victim, [cell], view.board)
		"psychic":
			CombatSfx.cast(cue)
			FxBodies.psychic(fx, cue, null, victim)
		"ward":
			CombatSfx.cast(cue)
			FxBodies.ward(fx, cue, victim)
		"slash":
			FxBodies.slash(fx, cue, null, victim, false)
			var again: WeakRef = weakref(victim)
			_later(fx, 0.14, func() -> void:
				var v := again.get_ref() as CombatToken
				if v != null:
					FxBodies.slash(fx, cue, null, v, false))
		"darts":
			_darts(fx, cue, victim)
		"crash":
			_crash(fx, cue, victim)


## The squares round `cell` that are open floor, for a cloud that fills more than one.
static func _around(view: LocationView, cell: Vector2i) -> Array:
	var out: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := cell + Vector2i(dx, dy)
			if view.grid.in_bounds(c) and (c == cell or not view.grid.has_flag(c, CombatGrid.WALL)):
				out.append(c)
	return out


## Needles, bolts or shards flying in at the victim, one after another, each landing in a small burst.
static func _darts(fx: SpellFx, cue: Dictionary, victim: CombatToken) -> void:
	var n := maxi(1, int(cue.get("count", 4)))
	var from_where := str(cue.get("from", "above"))
	var feet := victim.global_position
	for i in n:
		var to := SpellFx.chest(victim) + Vector3(fx.rng.randf_range(-0.18, 0.18), fx.rng.randf_range(-0.35, 0.3), fx.rng.randf_range(-0.18, 0.18))
		var scatter := Vector3(fx.rng.randf_range(-0.5, 0.5), 0.0, fx.rng.randf_range(-0.5, 0.5))
		var from := to + scatter + Vector3(0, 3.2, 0)
		if from_where == "side":
			from = to + Vector3(-3.4, 0.3, 0.8) + scatter
		elif from_where == "below":
			from = feet + scatter * 0.4 + Vector3(0, -0.1, 0)
		_later(fx, 0.07 * i, func() -> void: FxMissiles.bolt(fx, cue, from, to, true, true))


## A weight coming down or a floor giving way: streaks and lumps falling, a burst of dust and flecks where they land, a
## flash of light to read it by, a ring across the floor.
static func _crash(fx: SpellFx, cue: Dictionary, victim: CombatToken) -> void:
	var cols := cue["colours"] as Dictionary
	var size := float(cue.get("size", 1.0))
	var feet := victim.global_position
	CombatSfx.impact({"family": "burst", "flavour": cue["flavour"], "key": cue["key"]})
	var streaks := FxKit.particles({"amount": 18, "lifetime": 0.7, "explosiveness": 0.6, "emit": "box", "box": Vector3(0.4, 0.05, 0.4) * size,
		"dir": Vector3.DOWN, "spread": 12.0, "speed": Vector2(4.0, 7.0), "damping": Vector2.ZERO, "gravity": Vector3(0, -9.0, 0),
		"size": Vector2(0.06, 0.34) * size, "align": true, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["glow"], 1.6, false)})
	var lumps := FxKit.particles({"amount": 12, "lifetime": 0.75, "explosiveness": 0.6, "emit": "box", "box": Vector3(0.45, 0.05, 0.45) * size,
		"dir": Vector3.DOWN, "spread": 14.0, "speed": Vector2(2.0, 4.0), "damping": Vector2.ZERO, "gravity": Vector3(0, -8.0, 0),
		"size": Vector2(0.14, 0.3) * size, "colours": [cols["glow"], cols["edge"], cols["smoke"]],
		"material": FxKit.glow_material(FxKit.Shape.PUFF, cols["glow"], 1.1)})
	fx.emit(streaks, feet + Vector3(0, 2.6, 0))
	fx.emit(lumps, feet + Vector3(0, 2.4, 0))
	_later(fx, 0.32, func() -> void:
		var dust := FxKit.particles({"amount": 32, "lifetime": 1.8, "explosiveness": 0.85, "emit": "sphere", "radius": 0.35 * size,
			"dir": Vector3.UP, "spread": 75.0, "speed": Vector2(0.8, 2.4), "damping": Vector2(1.5, 3.0), "size": 1.5 * size,
			"grow": FxKit.curve(0.3, 1.0, 1.3, 0.3), "fade_in": true,
			"colours": [Color(cols["glow"], 0.85), Color(cols["edge"], 0.6), Color(cols["smoke"], 0.2)], "material": FxKit.smoke_material(0.8)})
		fx.emit(dust, feet + Vector3(0, 0.2, 0))
		var flecks := FxKit.particles({"amount": 24, "lifetime": 0.7, "emit": "sphere", "radius": 0.15 * size,
			"dir": Vector3.UP, "spread": 60.0, "speed": Vector2(1.5, 3.5), "damping": Vector2(1.0, 2.0), "gravity": Vector3(0, -7.0, 0),
			"size": Vector2(0.04, 0.2) * size, "align": true, "colours": [cols["core"], cols["glow"], cols["edge"]],
			"material": FxKit.glow_material(FxKit.Shape.STREAK, cols["glow"], 1.8, false)})
		fx.emit(flecks, feet + Vector3(0, 0.2, 0))
		FxKit.flash(fx, feet + Vector3(0, 0.8, 0), cols["light"], 3.5, 3.5 * size, 0.04, 0.6)
		FxAreas.shockwave(fx, cue, feet, 2.2 * size, 0.35)
		fx.shake(0.06 * size, 0.3))


## Runs `call` after `seconds` (at the combat speed) on a tween of the effect's own: it goes with the effect if the view
## is freed first (a timer's lambda that captured freed nodes would be called all the same, with an error), and stands
## still with the particles when a cutscene pauses the tree.
static func _later(fx: SpellFx, seconds: float, call: Callable) -> void:
	var tw := fx.create_tween()
	tw.tween_interval(maxf(0.001, seconds * fx.pace()))
	tw.tween_callback(call)
