class_name SpellZones
extends RefCounted
## Lingering spells on the grid (ADR 0007, docs/contracts/spells.md): areas such as Spirit Guardians, Cloud of
## Daggers, Web, Grease, Entangle, Fog Cloud, Darkness, Silence, Stinking Cloud and Sleet Storm, and spell objects
## such as Spiritual Weapon's weapon or Flaming Sphere. Each is a FieldObject built from the spell's `zone` and
## `object` data. This class runs their rules: the triggers (when the area appears, when a creature enters it or
## the area moves into it, at the start or end of a creature's turn), "once per turn", Difficult Terrain, auras
## that change creatures while they're inside (Silence's Deafened, Crusader's Mantle's extra damage), and what
## the area does to sight (Heavily Obscured, magical Darkness, light and sunlight).

var _enc: WeakRef
var objects: Array[FieldObject] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func spells() -> SpellCaster:
	return enc().spells


# --- Making and finding objects ---------------------------------------------------------------------

## Adds `o` to the field and runs its "cast" trigger on everyone already inside.
func add(o: FieldObject, r: CombatResult) -> void:
	objects.append(o)
	enc().events.append({"type": "object", "id": o.id, "kind": FieldObject.kind_name(o.kind), "cell": o.cell})
	refresh_auras()
	if o.has_trigger("cast"):
		var shared := {}
		for t in _inside(o):
			_affect(o, t, "cast", r, shared)


func get_object(object_id: String) -> FieldObject:
	for o in objects:
		if o.id == object_id:
			return o
	return null


## The caster's live object of a spell (Spiritual Weapon, Flaming Sphere, Cloud of Daggers), or null.
func object_of(caster_id: String, spell_id: String) -> FieldObject:
	for o in objects:
		if o.caster_id == caster_id and o.spell_id == spell_id and not o.expired():
			return o
	return null


func live() -> Array[FieldObject]:
	var out: Array[FieldObject] = []
	for o in objects:
		if not o.expired():
			out.append(o)
	return out


## Drops objects whose Concentration ended or whose time ran out (and the auras they gave).
func prune() -> void:
	var gone := false
	for o: FieldObject in objects.duplicate():
		if o.expired():
			objects.erase(o)
			enc().events.append({"type": "object_gone", "id": o.id})
			enc().log.add("info", "%s ends" % o.name, o.caster_id)
			gone = true
	if gone:
		refresh_auras()


## Ends every object a spell keeps (the spell ended some other way).
func end_spell(caster_id: String, spell_id: String) -> void:
	for o in objects:
		if o.caster_id == caster_id and o.spell_id == spell_id:
			o.ended = true
	prune()


# --- Where things are -------------------------------------------------------------------------------

func _inside(o: FieldObject) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for t in enc().living():
		if o.covers(t) and _affects(o, t):
			out.append(t)
	return out


## Whether the zone's rules apply to `t` at all: "affects" is all (default), others (not the caster), enemies (the
## caster's foes: "creatures of your choice" defaulting to the hostile ones), allies (the caster and its allies).
func _affects(o: FieldObject, t: Combatant) -> bool:
	if t.id in o.spared:
		return false
	var caster := enc().get_c(o.caster_id)
	match str(o.rule("affects", "all")):
		"others":
			return t.id != o.caster_id
		"enemies":
			return caster == null or caster.hostile_to(t)
		"allies":
			return caster != null and (t == caster or caster.allied_with(t))
	return true


## Re-centres areas that move with their caster (Emanations).
func _follow(c: Combatant) -> void:
	for o in objects:
		if o.follows_caster and o.caster_id == c.id and not o.expired():
			var before := o.cells.duplicate()
			o.cells = enc().grid.area_cells("emanation", int(o.rule("size", 15)), enc().center_of(c), Vector2.RIGHT, 5,
				c.cell, c.size_cells)
			o.cell = c.cell
			if before != o.cells:
				enc().events.append({"type": "object", "id": o.id, "kind": "zone", "cell": o.cell})
				# The Emanation moving into a creature's space counts (Spirit Guardians).
				if o.has_trigger("moved_into"):
					for t in _inside(o):
						var was := false
						for cell in t.footprint():
							if cell in before:
								was = true
						if not was:
							_affect(o, t, "moved_into", CombatResult.new(), {})


# --- Triggers ---------------------------------------------------------------------------------------

## A creature moved one square (walking or forced): zones it entered, Emanations that follow it, auras.
func on_moved(c: Combatant, from: Vector2i) -> void:
	_follow(c)
	for o: FieldObject in objects.duplicate():
		if o.expired() or not o.covers(c) or not _affects(o, c):
			continue
		if not (o.has_trigger("enter") or o.has_trigger("moved_into")):
			continue
		var was := false
		for cell in CombatGrid.footprint(from, c.size_cells):
			if cell in o.cells:
				was = true
		if not was:
			_affect(o, c, "enter", CombatResult.new(), {})
	refresh_auras()


## An object moved or an area was moved onto creatures (Cloud of Daggers teleported, Flaming Sphere rolled).
func moved_object(o: FieldObject, r: CombatResult) -> void:
	enc().events.append({"type": "object", "id": o.id, "kind": FieldObject.kind_name(o.kind), "cell": o.cell})
	if o.has_trigger("moved_into"):
		for t in _inside(o):
			_affect(o, t, "moved_into", r, {})
	refresh_auras()


func turn_start(c: Combatant) -> void:
	for o in objects:
		if o.caster_id == c.id and o.rounds_left > 0:
			o.rounds_left -= 1
	prune()
	for o: FieldObject in objects.duplicate():
		if o.expired():
			continue
		if o.has_trigger("start_turn") and o.covers(c) and _affects(o, c):
			_affect(o, c, "start_turn", CombatResult.new(), {})
		if o.has_trigger("near_start_turn") and _near(o, c) and _affects(o, c):
			_affect(o, c, "start_turn", CombatResult.new(), {})


func turn_end(c: Combatant) -> void:
	for o in objects:
		if o.caster_id == c.id and o.rules.has("caster_turn_ends"):
			o.rules["caster_turn_ends"] = int(o.rules["caster_turn_ends"]) - 1
			if int(o.rules["caster_turn_ends"]) <= 0:
				o.ended = true
	prune()
	for o: FieldObject in objects.duplicate():
		if o.expired():
			continue
		if o.has_trigger("end_turn") and o.covers(c) and _affects(o, c):
			_affect(o, c, "end_turn", CombatResult.new(), {})
		elif o.has_trigger("near_end_turn") and _near(o, c) and _affects(o, c):
			_affect(o, c, "end_turn", CombatResult.new(), {})


## Within the object's reach (Flaming Sphere: within 5 ft of the sphere).
func _near(o: FieldObject, c: Combatant) -> bool:
	return enc().grid.distance_ft(o.cell, 1, c.cell, c.size_cells) <= int(o.rule("reach", 5))


## One creature caught by a zone: the save, damage (rolled once per trigger for everyone when `shared` is passed
## in), effects on a failure. Most areas affect a creature no more than once per turn.
func _affect(o: FieldObject, t: Combatant, trigger: String, r: CombatResult, shared: Dictionary) -> void:
	var e := enc()
	if not t.is_alive():
		return
	var turn_key := "%d:%d" % [e.round_no, e.turn_index]
	if bool(o.rule("once_per_turn", true)) and str(o.hit_on_turn.get(t.id, "")) == turn_key:
		return
	var has_save := o.rules.has("save")
	var has_damage := not (o.rule("damage", []) as Array).is_empty()
	var effects := o.rule("effects", []) as Array
	if not has_save and not has_damage and effects.is_empty():
		return
	o.hit_on_turn[t.id] = turn_key
	var ctx := spells().context_for_object(o)
	if ctx.is_empty():
		return
	var label := "%s (%s)" % [o.name, _trigger_words(trigger)]
	var failed := true
	var details: Array[String] = []
	if has_save:
		var ab := StringName(str(o.rules["save"]))
		var test := t.creature.roll_save(e.dice, ab, o.save_dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], o.name, t.name()])
		failed = not test.success
		details.append(test.describe())
	if has_damage:
		var rolled: Dictionary = shared.get("rolled", {}) as Dictionary
		if rolled.is_empty():
			rolled = spells().roll_damage_parts(ctx, o.rule("damage", []) as Array, false, t)
			if trigger == "cast":
				shared["rolled"] = rolled
		var amount := int(rolled["total"])
		if not failed:
			amount = amount / 2 if bool(o.rule("half", false)) else 0
		details.append(str(rolled["text"]))
		if amount > 0:
			e.deal_damage(e.get_c(o.caster_id), t, [{"amount": amount, "type": str(rolled["type"]), "spell": true}], false, label, details)
		else:
			r.lines.append(e.log.add("info", "%s avoids %s" % [t.name(), label], t.id, details))
	elif has_save:
		r.lines.append(e.log.add("info", "%s %s the %s save" % [t.name(), "fails" if failed else "succeeds on", o.name], t.id, details))
	if t.is_alive():
		spells().apply_effect_entries(ctx, t, effects, "fail" if failed else "success", r)


static func _trigger_words(trigger: String) -> String:
	match trigger:
		"cast":
			return "as it appears"
		"enter":
			return "entering it"
		"moved_into":
			return "it moves onto them"
		"start_turn":
			return "starting a turn there"
		"end_turn":
			return "ending a turn there"
	return trigger


# --- Auras: rules that hold while a creature is inside --------------------------------------------------

## Puts each zone's `inside` effect on the creatures inside it and takes it off those that left (Silence's
## Deafened and Thunder immunity, Pass without Trace's +10 Stealth, Crusader's Mantle's extra Radiant damage).
func refresh_auras() -> void:
	var e := enc()
	if e == null:
		return
	for t in e.combatants:
		for fx: Effect in t.creature.effects.duplicate():
			if fx.stack_key.begins_with("zone:"):
				var o := get_object(fx.stack_key.substr(5))
				if o == null or o.expired() or not o.covers(t) or not _affects(o, t):
					t.creature.remove_effect(fx)
	for o in objects:
		if o.expired() or not o.rules.has("inside"):
			continue
		var inside := o.rules["inside"] as Dictionary
		for t in _inside(o):
			var key := "zone:%s" % o.id
			if t.creature.effects.any(func(x: Effect) -> bool: return x.stack_key == key):
				continue
			var fx := Effect.new(o.name, &"spell", o.spell_id)
			fx.stack_key = key
			fx.caster_id = o.caster_id
			for md: Variant in inside.get("modifiers", []):
				fx.modifiers.append(Modifier.make((md as Dictionary).duplicate(true), o.name, &"spell", o.spell_id))
			for cond: Variant in inside.get("conditions", []):
				fx.conditions.append(StringName(str(cond)))
			if not fx.modifiers.is_empty() or not fx.conditions.is_empty():
				t.creature.add_effect(fx)


# --- Terrain and sight ------------------------------------------------------------------------------

## Squares that are Difficult Terrain for `c` because of spells (Web, Grease, Entangle, Sleet Storm; Spirit
## Guardians halves the Speed of the creatures it affects, which costs the same).
func difficult_cells(c: Combatant) -> Dictionary:
	var out := {}
	for o in objects:
		if o.expired() or str(o.rule("terrain", "")) != "difficult":
			continue
		if bool(o.rule("terrain_affected_only", false)) and not _affects(o, c):
			continue
		for cell in o.cells:
			out[cell] = true
	return out


## "heavy", "light" or "" for a square (Fog Cloud, Darkness, Stinking Cloud, Sleet Storm are Heavily Obscured; Web
## is Lightly Obscured).
func obscured(cell: Vector2i) -> String:
	var best := ""
	for o in objects:
		if o.expired() or not cell in o.cells:
			continue
		var ob := str(o.rule("obscured", ""))
		if ob == "heavy":
			return "heavy"
		if ob == "light":
			best = "light"
	return best


## Magical Darkness covers this square (Darkvision can't see through it).
func magical_darkness(cell: Vector2i) -> bool:
	for o in objects:
		if not o.expired() and bool(o.rule("darkness", false)) and cell in o.cells:
			return true
	return false


## No sound in this square (Silence): Verbal spells can't be cast there.
func silenced(cell: Vector2i) -> bool:
	for o in objects:
		if not o.expired() and bool(o.rule("silence", false)) and cell in o.cells:
			return true
	return false


## Light from spells: "bright", "dim" or "" for a square, and whether it's sunlight (Daylight).
func spell_light(cell: Vector2i) -> Dictionary:
	var level := ""
	var sun := false
	for o in objects:
		if o.expired() or not o.rules.has("light"):
			continue
		var l := o.rules["light"] as Dictionary
		var src := o.cell
		if str(o.rule("light_on", "")) == "caster" or o.follows_caster:
			var cc := enc().get_c(o.caster_id)
			if cc != null:
				src = cc.cell
		elif str(o.rule("light_on", "")) == "target":
			var tt := enc().get_c(str(o.rule("light_target", "")))
			if tt != null:
				src = tt.cell
		var d := enc().grid.distance_ft(src, 1, cell, 1)
		var bright := int(l.get("bright", 0))
		var dim := int(l.get("dim", 0))
		if d <= bright:
			level = "bright"
			sun = sun or bool(l.get("sunlight", false))
		elif d <= bright + dim and level == "":
			level = "dim"
	return {"level": level, "sunlight": sun}


## Whether the straight line between two squares passes through a Heavily Obscured or magically dark square
## (the end squares count too).
func line_obscured(a: Vector2i, a_size: int, b: Vector2i, b_size: int) -> bool:
	if objects.is_empty():
		return false
	var from := Vector2(a.x + a_size / 2.0, a.y + a_size / 2.0)
	var to := Vector2(b.x + b_size / 2.0, b.y + b_size / 2.0)
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		var cell := Vector2i(floori(p.x), floori(p.y))
		if obscured(cell) == "heavy":
			return true
	return false
