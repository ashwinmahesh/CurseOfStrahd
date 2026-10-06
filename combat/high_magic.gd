class_name HighMagic
extends RefCounted
## Spells of levels 7 to 9 whose fight rules need code (2024 PHB): the Power Words, Divine Word, Mass Heal, Prismatic
## Spray and Prismatic Wall, Maze, Forcecage, Time Stop, Reverse Gravity, True Polymorph, Shapechange, Animal Shapes,
## Delayed Blast Fireball's growing bead, Storm of Vengeance's later rounds, Tsunami's moving wall, Earthquake's
## end-of-turn tremors, Conjure Celestial's healing light, Regenerate, and Antimagic Field's suppression. SpellSpecials
## hands these casts here; the zone and turn hooks call the rest.

var _enc: WeakRef

const HANDLED := ["power_word_kill", "power_word_stun", "power_word_heal", "power_word_fortify", "mass_heal", "divine_word",
	"prismatic_spray", "maze", "time_stop", "reverse_gravity", "true_polymorph", "shapechange", "animal_shapes",
	"delayed_blast_fireball", "forcecage"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func resolve(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	var s := ctx["s"] as Dictionary
	match str(s["id"]):
		"power_word_kill":
			for t in tgt:
				power_word_kill(ctx, t, r)
		"power_word_stun":
			for t in tgt:
				power_word_stun(ctx, t, r)
		"power_word_heal":
			for t in tgt:
				power_word_heal(ctx, t, r)
		"power_word_fortify":
			power_word_fortify(ctx, tgt, r)
		"mass_heal":
			mass_heal(ctx, tgt, r)
		"divine_word":
			divine_word(ctx, tgt, r)
		"prismatic_spray":
			prismatic_spray(ctx, cells, r)
		"maze":
			for t in tgt:
				maze(ctx, t, r)
		"time_stop":
			time_stop(ctx, r)
		"reverse_gravity":
			reverse_gravity(ctx, cells, r)
		"true_polymorph":
			for t in tgt:
				true_polymorph(ctx, t, r)
		"shapechange":
			shapechange(ctx, r)
		"animal_shapes":
			animal_shapes(ctx, tgt, r)
		"delayed_blast_fireball":
			delayed_blast_fireball(ctx, cells, r)
		"forcecage":
			forcecage(ctx, cells, r)
		_:
			return false
	return true


func _log(ctx: Dictionary, text: String, who: Combatant, r: CombatResult, kind: String = "spell") -> void:
	r.lines.append(enc().log.add(kind, text, who.id if who != null else (ctx["c"] as Combatant).id))


func _dc(ctx: Dictionary) -> int:
	return (ctx["nums"]["dc"] as Breakdown).total()


## A save against the spell with the usual keys (Magic Resistance and the like). True on a success.
func _save(ctx: Dictionary, t: Combatant, ab: StringName, cond: String = "") -> bool:
	var e := enc()
	var s := ctx["s"] as Dictionary
	var keys := t.creature.save_keys(ab)
	keys.append("save_vs:spell")
	if cond != "":
		keys.append("save_vs:%s" % cond)
	var test := t.creature.roll_d20(e.dice, D20Test.Kind.SAVING_THROW, t.creature.save_bonus(ab), _dc(ctx), keys, [] as Array[String], [] as Array[String],
		"%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], s["name"], t.name()])
	e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if test.success else "fails", s["name"]], t.id, [test.describe()])
	return test.success


func _kill(t: Combatant, why: String) -> void:
	var e := enc()
	t.creature.hp = 0
	t.creature.dead = true
	e.log.add("death", "%s dies (%s)" % [t.name(), why], t.id)
	e.events.append({"type": "death", "id": t.id})
	e.class_features.on_drop(null, t)


func _timed(ctx: Dictionary, t: Combatant, name: String, until: String) -> Effect:
	var fx := Effect.new(name, &"spell", str((ctx["s"] as Dictionary)["id"]))
	fx.caster_id = (ctx["c"] as Combatant).id
	sp()._set_duration(fx, ctx, t, until)
	return fx


func _heal(ctx: Dictionary, t: Combatant, amount: int, r: CombatResult) -> int:
	var e := enc()
	var s := ctx["s"] as Dictionary
	if t.creature.has_flag("cant_regain_hp") or amount <= 0:
		return 0
	var got := t.creature.heal(amount, str(s["name"]))
	if t.creature.hp > 0:
		t.creature.remove_condition(&"unconscious", "0 Hit Points")
		t.creature.stable = false
	_log(ctx, "%s regains %d Hit Points (%s)" % [t.name(), got, s["name"]], t, r, "heal")
	e.events.append({"type": "heal", "id": t.id, "amount": got})
	return got


# --- Power Words, Divine Word, Mass Heal -------------------------------------------------------------------

## Power Word Kill: a creature with 100 Hit Points or fewer dies; otherwise 12d12 Psychic.
func power_word_kill(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	if t.creature.hp <= 100:
		_kill(t, "Power Word Kill")
		return
	var rolled := e._roll_damage_dice("12d12", false, 0, "Power Word Kill")
	r.damage += e.deal_damage(ctx["c"] as Combatant, t, [{"amount": int(rolled["total"]), "type": "psychic", "spell": true}], false, "Power Word Kill", [str(rolled["text"])]).final


## Power Word Stun: 150 Hit Points or fewer: Stunned, a Constitution save at the end of each of its turns; more:
## Speed 0 until the start of the caster's next turn.
func power_word_stun(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	if t.creature.hp <= 150:
		var fx := _timed(ctx, t, "Stunned (Power Word Stun)", "permanent").with_condition(&"stunned")
		fx.repeat_save = {"ability": "con", "dc": _dc(ctx), "when": "end"}
		t.creature.add_effect(fx)
		e.features.end_turning_from(t)
		_log(ctx, "%s is Stunned (Power Word Stun)" % t.name(), t, r, "condition")
	else:
		var slow := _timed(ctx, t, "Speed 0 (Power Word Stun)", "caster_turn_start").with_modifier("speed_set", {"value": 0})
		t.creature.add_effect(slow)
		_log(ctx, "%s is too mighty to stun, but stops in its tracks" % t.name(), t, r, "condition")
	e.events.append({"type": "condition", "id": t.id})


## Power Word Heal: all Hit Points back, and Charmed, Frightened, Paralyzed, Poisoned and Stunned end; a Prone target
## can stand with its Reaction.
func power_word_heal(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	_heal(ctx, t, t.creature.max_hp() - t.creature.hp, r)
	for cond: StringName in [&"charmed", &"frightened", &"paralyzed", &"poisoned", &"stunned"]:
		if t.creature.has_condition(cond):
			sp().cure(t, cond)
	if t.creature.has_condition(&"prone") and t.reaction_available:
		t.reaction_available = false
		t.creature.remove_condition(&"prone")
		_log(ctx, "%s springs to its feet" % t.name(), t, r, "info")
	e.events.append({"type": "condition", "id": t.id})


## Power Word Fortify: 120 Temporary Hit Points shared among up to six creatures (evenly, the remainder to the first).
func power_word_fortify(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	if tgt.is_empty():
		return
	var each := 120 / tgt.size()
	var extra := 120 - each * tgt.size()
	for i in tgt.size():
		var t := tgt[i]
		var amt := each + (extra if i == 0 else 0)
		if t.creature.add_temp_hp(amt, "Power Word Fortify"):
			_log(ctx, "%s gains %d Temporary Hit Points (Power Word Fortify)" % [t.name(), amt], t, r, "heal")


## Mass Heal: 700 Hit Points shared out, the most hurt first; each creature healed loses Blinded, Deafened and Poisoned.
func mass_heal(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var pool := 700
	var order := tgt.duplicate()
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return (a.creature.max_hp() - a.creature.hp) > (b.creature.max_hp() - b.creature.hp))
	for t: Combatant in order:
		if pool <= 0:
			break
		var need := mini(pool, t.creature.max_hp() - t.creature.hp)
		if need > 0:
			pool -= _heal(ctx, t, need, r)
		for cond: StringName in [&"blinded", &"deafened", &"poisoned"]:
			if t.creature.has_condition(cond):
				sp().cure(t, cond)


## Divine Word: chosen creatures make a Charisma save; a failure hurts by Hit Points left: 20 or fewer, dead; 30,
## Blinded, Deafened and Stunned for an hour; 40, Blinded and Deafened for 10 minutes; 50, Deafened for a minute. A
## Celestial, Elemental, Fey or Fiend that fails is sent home.
func divine_word(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var victims := tgt
	if victims.is_empty():
		for o in e.hostiles_of(c):
			if not o.is_down() and e.distance(c, o) <= 30 and e.can_see(c, o):
				victims.append(o)
	for t in victims:
		if _save(ctx, t, &"cha"):
			continue
		if str(t.creature.creature_type) in ["celestial", "elemental", "fey", "fiend"]:
			t.creature.dead = true
			t.cell = SpellSpecials.BANISHED_CELL
			e.events.append({"type": "vanish", "id": t.id})
			_log(ctx, "%s is hurled back to its home plane" % t.name(), t, r, "condition")
			continue
		var hp := t.creature.hp
		if hp <= 20:
			_kill(t, "Divine Word")
			continue
		var fx := Effect.new("Divine Word", &"spell", "divine_word")
		fx.caster_id = c.id
		if hp <= 30:
			fx.conditions.append_array([&"blinded", &"deafened", &"stunned"])
			fx.lasting({"kind": "hours", "amount": 1})
		elif hp <= 40:
			fx.conditions.append_array([&"blinded", &"deafened"])
			fx.lasting({"kind": "minutes", "amount": 10})
		elif hp <= 50:
			fx.conditions.append(&"deafened")
			fx.lasting({"kind": "minutes", "amount": 1})
		else:
			continue
		fx.turn_owner_id = t.id
		t.creature.add_effect(fx)
		e.events.append({"type": "condition", "id": t.id})
		e.features.end_turning_from(t)
		_log(ctx, "%s reels from the Divine Word" % t.name(), t, r, "condition")


# --- Prismatic Spray -------------------------------------------------------------------------------------

const PRISM := [["red", "fire"], ["orange", "acid"], ["yellow", "lightning"], ["green", "poison"], ["blue", "cold"]]


## Prismatic Spray: a d8 for each creature in the Cone picks its ray (an 8 means two rays, rerolling 8s).
func prismatic_spray(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var dmg := e._roll_damage_dice("12d6", false, 0, "Prismatic Spray")
	for t in sp()._area_victims(c, ctx["s"] as Dictionary, cells):
		var roll := e.dice.roll_one(8, "Prismatic Spray ray (%s)" % t.name())
		var rays: Array[int] = [roll]
		if roll == 8:
			rays = [e.dice.roll_one(7, "Prismatic Spray ray"), e.dice.roll_one(7, "Prismatic Spray ray")]
		for ray in rays:
			if t.is_alive():
				prism_ray(ctx, t, ray, int(dmg["total"]), r)


## One ray or layer (1-7): red to blue, Dexterity save for 12d6 (half on a success); indigo, Restrained and then Petrified
## after three failed Constitution saves; violet, Blinded and then sent to another plane after a failed Wisdom save.
func prism_ray(ctx: Dictionary, t: Combatant, ray: int, amount: int, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	if ray <= 5:
		var info := PRISM[ray - 1] as Array
		var ok := _save(ctx, t, &"dex")
		var amt := amount / 2 if ok else amount
		r.damage += e.deal_damage(c, t, [{"amount": amt, "type": str(info[1]), "spell": true}], false, "Prismatic %s ray" % str(info[0]).capitalize()).final
	elif ray == 6:
		if not _save(ctx, t, &"dex", "restrained"):
			var fx := _timed(ctx, t, "Restrained (indigo ray)", "permanent").with_condition(&"restrained")
			fx.data = {"prism": "indigo", "fails": 0, "wins": 0, "dc": _dc(ctx)}
			t.creature.add_effect(fx)
			_log(ctx, "%s is caught in the indigo ray: Restrained" % t.name(), t, r, "condition")
	else:
		if not _save(ctx, t, &"dex", "blinded"):
			var fx2 := _timed(ctx, t, "Blinded (violet ray)", "permanent").with_condition(&"blinded")
			fx2.data = {"prism": "violet", "dc": _dc(ctx), "caster": c.id}
			t.creature.add_effect(fx2)
			_log(ctx, "%s is blinded by the violet ray" % t.name(), t, r, "condition")
	e.events.append({"type": "condition", "id": t.id})


## The indigo ray's saves at the end of the creature's turns (three successes free it, three failures Petrify it) and
## the violet ray's Wisdom save at the start of the caster's next turn.
func prism_turn_end(t: Combatant) -> void:
	var e := enc()
	for fx: Effect in t.creature.effects.duplicate():
		if str(fx.data.get("prism", "")) != "indigo":
			continue
		var sv := t.creature.roll_save(e.dice, &"con", int(fx.data["dc"]), [], [], "Constitution save vs the indigo ray (%s)" % t.name())
		if sv.success:
			fx.data["wins"] = int(fx.data["wins"]) + 1
		else:
			fx.data["fails"] = int(fx.data["fails"]) + 1
		if int(fx.data["wins"]) >= 3:
			t.creature.remove_effect(fx)
			e.log.add("info", "%s breaks free of the indigo ray" % t.name(), t.id, [sv.describe()])
		elif int(fx.data["fails"]) >= 3:
			fx.conditions = [&"petrified"]
			fx.data["prism"] = "petrified"
			e.log.add("condition", "%s turns to stone (indigo ray)" % t.name(), t.id, [sv.describe()])
			e.events.append({"type": "condition", "id": t.id})


func prism_caster_turn_start(caster: Combatant) -> void:
	var e := enc()
	for t: Combatant in e.combatants.duplicate():
		for fx: Effect in t.creature.effects.duplicate():
			if str(fx.data.get("prism", "")) != "violet" or str(fx.data.get("caster", "")) != caster.id:
				continue
			var sv := t.creature.roll_save(e.dice, &"wis", int(fx.data["dc"]), [], [], "Wisdom save vs the violet ray (%s)" % t.name())
			if sv.success:
				t.creature.remove_effect(fx)
				e.log.add("info", "%s's sight clears" % t.name(), t.id, [sv.describe()])
			else:
				t.creature.remove_effect(fx)
				t.creature.dead = true
				t.cell = SpellSpecials.BANISHED_CELL
				e.events.append({"type": "vanish", "id": t.id})
				e.log.add("info", "%s is swept away to another plane (violet ray)" % t.name(), t.id, [sv.describe()])


# --- Maze, Forcecage, Time Stop, Reverse Gravity ---------------------------------------------------------

## Maze: no save; the target vanishes into a demiplane maze. At the start of each of its turns it tries a DC 20
## Intelligence (Investigation) check to escape (its action), returning to its space or the nearest free one.
func maze(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var fx := sp().specials._marker(ctx, t, "In a maze", ["banished", "ethereal", "mazed"], "unbanish", {"cell": [t.cell.x, t.cell.y], "round": 100000})
	if not sp().specials._attach(ctx, t, fx):
		return
	t.set_meta("banished", [t.cell.x, t.cell.y])
	t.cell = SpellSpecials.BANISHED_CELL
	e.events.append({"type": "vanish", "id": t.id})
	var tid := t.id
	fx.on_end = func() -> void: sp().specials.unbanish(tid, 100000)
	_log(ctx, "%s vanishes into a labyrinth (Maze)" % t.name(), t, r, "condition")


func maze_turn(t: Combatant) -> void:
	var e := enc()
	if not t.creature.has_flag("mazed"):
		return
	t.action_available = false
	t.movement_left = 0
	var test := t.creature.roll_check(e.dice, &"investigation", 20)
	e.log.add("info", "%s searches for a way out of the maze" % t.name(), t.id, [test.describe()])
	if test.success:
		for fx: Effect in t.creature.effects.duplicate():
			if fx.source_id == "maze":
				t.creature.remove_effect(fx)


## Forcecage: a cage of bars (20 ft) or a solid box (10 ft) at a point. Creatures wholly inside can't leave by
## walking (or be reached by walking in); partly inside are pushed out; a box also blocks attacks and spells across
## it; teleporting out takes a Charisma save.
func forcecage(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var box := str(ctx.get("choice", "")) == "box"
	var area := cells
	if box:
		var p := ctx["point"] as Vector2
		area = e.grid.area_cells("cube", 10, Vector2(floorf(p.x), floorf(p.y) + 1.0), Vector2.RIGHT)
	var o := FieldObject.new(FieldObject.Kind.ZONE, "forcecage", "Forcecage")
	o.caster_id = c.id
	o.cells = area
	o.cell = area[0] if not area.is_empty() else c.cell
	o.rules = {"triggers": [], "cage": "box" if box else "bars", "colour": "silver"}
	o.keep_with(ctx["conc"] as Concentration)
	sp().zones.add(o, r)
	# Creatures only partly inside are pushed out.
	for t in e.living():
		var inn := 0
		for f in t.footprint():
			if f in area:
				inn += 1
		if inn > 0 and inn < t.footprint().size():
			e.forced_move(t, Vector2(o.cell) + Vector2(0.5, 0.5), 10)
	_log(ctx, "A %s of force springs up" % ("solid box" if box else "cage"), c, r)


## The cage `c` is wholly inside, or null.
func cage_of(c: Combatant) -> FieldObject:
	for o in sp().zones.live():
		if not o.rules.has("cage"):
			continue
		var all := true
		for f in c.footprint():
			if not f in o.cells:
				all = false
		if all:
			return o
	return null


## Squares a creature can't step into because of a cage: out of its own cage, or into one it isn't in.
func cage_blocks(c: Combatant) -> Dictionary:
	var out := {}
	var mine := cage_of(c)
	for o in sp().zones.live():
		if not o.rules.has("cage"):
			continue
		if o == mine:
			for x in enc().grid.width:
				for y in enc().grid.depth:
					var cell := Vector2i(x, y)
					if not cell in o.cells:
						out[cell] = true
		else:
			for cell in o.cells:
				out[cell] = true
	return out


## A solid Forcecage box between two creatures (one inside, one out) blocks attacks and spells.
func box_between(a: Combatant, b: Combatant) -> bool:
	var ca := cage_of(a)
	var cb := cage_of(b)
	if ca == cb:
		return false
	for o: FieldObject in [ca, cb]:
		if o != null and str(o.rules["cage"]) == "box":
			return true
	return false


## Teleporting out of a cage: a Charisma save first; a failure wastes the attempt.
func teleport_blocked(ctx: Dictionary, c: Combatant) -> bool:
	var cage := cage_of(c)
	if cage == null:
		return false
	var e := enc()
	var cage_caster := e.get_c(cage.caster_id)
	var dc := cage.save_dc if cage.save_dc > 0 else 15
	if cage_caster != null and cage_caster.creature is Character:
		dc = (sp().numbers(cage_caster, sp()._entry_any(cage_caster, "forcecage"))["dc"] as Breakdown).total()
	var sv := c.creature.roll_save(e.dice, &"cha", dc, [], [], "Charisma save to teleport out of the Forcecage (%s)" % c.name())
	if not sv.success:
		e.log.add("info", "The Forcecage holds %s; the spell is wasted" % c.name(), c.id, [sv.describe()])
	return not sv.success


## Time Stop: 1d4 + 1 turns in a row for the caster; it ends early if the caster affects another creature (or its
## gear) or moves more than 1,000 ft away.
func time_stop(ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var turns := e.dice.roll_one(4, "Time Stop") + 1
	c.set_meta("time_stop", turns - 1)
	c.set_meta("time_stop_cell", [c.cell.x, c.cell.y])
	_log(ctx, "Time stops: %s takes %d turns in a row" % [c.name(), turns], c, r)


## The caster did something to another creature: Time Stop ends.
func time_stop_broken(c: Combatant, why: String) -> void:
	if c != null and c.has_meta("time_stop"):
		c.remove_meta("time_stop")
		enc().log.add("info", "Time flows again (%s)" % why, c.id)


## Reverse Gravity: everything in the Cylinder falls upward unless it makes a Dexterity save to hold on; aloft it
## can't walk and is out of reach of creatures on the ground. When the spell ends they fall back (1d6 per 10 ft,
## Prone).
func reverse_gravity(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	for t in sp().creatures_in(cells):
		if _save(ctx, t, &"dex"):
			continue
		var fx := sp().specials._marker(ctx, t, "Fallen upward (Reverse Gravity)", ["levitating", "aloft"], "fall", {"feet": 100})
		fx.modifiers.append(Modifier.of("speed_set", {"value": 0}, "Reverse Gravity", &"spell"))
		if sp().specials._attach(ctx, t, fx):
			var tid := t.id
			fx.on_end = func() -> void: fall(tid, 100)
			_log(ctx, "%s falls up into the sky" % t.name(), t, r, "condition")
			e.events.append({"type": "condition", "id": t.id})
	var o := FieldObject.new(FieldObject.Kind.ZONE, "reverse_gravity", "Reverse Gravity")
	o.caster_id = c.id
	o.cells = cells
	o.rules = {"triggers": [], "colour": "mist_blue"}
	o.keep_with(ctx["conc"] as Concentration)
	sp().zones.add(o, r)


func fall(tid: String, feet: int) -> void:
	var e := enc()
	if e == null:
		return
	var t := e.get_c(tid)
	if t == null or not t.is_alive():
		return
	var rolled := e._roll_damage_dice("%dd6" % mini(20, feet / 10), false, 0, "Falling")
	e.deal_damage(null, t, [{"amount": int(rolled["total"]), "type": "bludgeoning"}], false, "Falling", [str(rolled["text"])])
	if t.is_alive():
		t.creature.add_condition(&"prone", "Fell")
	e.events.append({"type": "condition", "id": t.id})


# --- Shapes ------------------------------------------------------------------------------------------

## Any creature form up to `max_cr` (True Polymorph, Shapechange): `types` limits it, `exclude` drops types.
static func forms(max_cr: float, types: Array = [], exclude: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table := Compendium.shared().tables.get("monsters", {}) as Dictionary
	for id: String in table:
		var d := table[id] as Dictionary
		var ty := str(d.get("type", ""))
		if float(d.get("cr", 0)) > max_cr + 0.001 or id.begins_with("swarm") or (not types.is_empty() and not ty in types) or ty in exclude:
			continue
		out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("cr", 0)) < float(b.get("cr", 0)))
	return out


func _pick(list: Array[Dictionary], pick: String, strongest: bool) -> Dictionary:
	if list.is_empty():
		return {}
	for f in list:
		if str(f.get("id", "")) == pick:
			return f
	return list[list.size() - 1] if strongest else list[0]


func _shape_marker(ctx: Dictionary, t: Combatant, m: Monster, label: String) -> void:
	var fx := sp().specials._marker(ctx, t, label, ["polymorphed"], "revert_shape")
	var conc := ctx["conc"] as Concentration
	if conc != null:
		conc.attach(m, fx)
	else:
		m.add_effect(fx)
	var tid := t.id
	fx.on_end = func() -> void: sp()._revert_shape(tid, "%s ended" % label)


## True Polymorph: a creature becomes another creature of Challenge Rating up to its own (or its level), gaining that
## form's Hit Points as Temporary Hit Points; an unwilling one makes a Wisdom save.
func true_polymorph(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	if t.creature.hp <= 0 or t.creature.has_flag("shapechanger"):
		_log(ctx, "True Polymorph has no effect on %s" % t.name(), t, r, "info")
		return
	if c.hostile_to(t) and _save(ctx, t, &"wis"):
		return
	var limit := float(t.creature.character_level()) if t.creature is Character else (t.creature as Monster).cr
	var form := _pick(forms(limit), str((ctx["opts"] as Dictionary).get("choice", "")), c.allied_with(t))
	if form.is_empty():
		return
	var m := enc().shapes.transform(t, form, {"temp_hp": int((form.get("hp", {}) as Dictionary).get("average", 1)), "ends_without_temp_hp": true, "label": "True Polymorph"})
	_shape_marker(ctx, t, m, "True Polymorph")


## Shapechange: the caster takes a form of Challenge Rating up to its level (not a Construct or Undead), keeping its
## mind and Hit Points, with the form's Hit Points as Temporary Hit Points.
func shapechange(ctx: Dictionary, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var form := _pick(forms(float(c.creature.character_level()), [], ["construct", "undead"]), str((ctx["opts"] as Dictionary).get("choice", "")), true)
	if form.is_empty():
		_log(ctx, "No form fits", c, r, "info")
		return
	var m := enc().shapes.transform(c, form, {"temp_hp": int((form.get("hp", {}) as Dictionary).get("average", 1)), "keep_mind": true, "label": "Shapechange"})
	_shape_marker(ctx, c, m, "Shapechange")


## Animal Shapes: willing creatures become Large or smaller Beasts of Challenge Rating 4 or lower (the strongest that
## fits, or the cast-time pick), gaining the Beast's Hit Points as Temporary Hit Points.
func animal_shapes(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var beasts: Array[Dictionary] = []
	for f in forms(4.0, ["beast"]):
		if Creature.SIZES.find(StringName(str(f.get("size", "medium")))) <= Creature.SIZES.find(&"large"):
			beasts.append(f)
	for t in tgt:
		if not c.allied_with(t) or t.creature.hp <= 0:
			continue
		var form := _pick(beasts, str((ctx["opts"] as Dictionary).get("choice", "")), true)
		if form.is_empty():
			return
		var m := enc().shapes.transform(t, form, {"temp_hp": int((form.get("hp", {}) as Dictionary).get("average", 1)), "ends_without_temp_hp": true, "keep_mind": true, "label": "Animal Shapes"})
		_shape_marker(ctx, t, m, "Animal Shapes")


# --- Lingering storms ---------------------------------------------------------------------------------

## Delayed Blast Fireball: a bead at the point holding 12d6 (more with higher slots), growing 1d6 at the end of each of
## the caster's turns; it bursts when the spell ends (Concentration lost or dropped, or the minute is up).
func delayed_blast_fireball(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var o := FieldObject.new(FieldObject.Kind.SPHERE, "delayed_blast_fireball", "Fireball bead")
	o.caster_id = c.id
	var p := ctx["point"] as Vector2
	o.cell = Vector2i(floori(p.x), floori(p.y))
	o.cells = [o.cell]
	o.origin = p
	o.slot = int(ctx["slot"])
	o.save_dc = _dc(ctx)
	o.rules = {"triggers": [], "bead_dice": 12 + maxi(0, int(ctx["slot"]) - int(s.get("level", 7))), "burst_cells": cells.map(func(x: Vector2i) -> Array: return [x.x, x.y])}
	o.rounds_left = 10
	sp().zones.add(o, r)
	var conc := ctx["conc"] as Concentration
	if conc != null:
		var fx := Effect.new("Delayed Blast Fireball", &"spell", "delayed_blast_fireball")
		fx.caster_id = c.id
		fx.modifiers.append(Modifier.of("flag", {"value": "holding_bead"}, "Delayed Blast Fireball", &"spell"))
		fx.data["on_end"] = {"kind": "burst_bead", "target": c.id, "object": o.id}
		var oid := o.id
		fx.on_end = func() -> void: burst_bead(oid)
		conc.attach(c.creature, fx)
	_log(ctx, "A glowing bead of fire hangs in the air (%dd6)" % int(o.rules["bead_dice"]), c, r)


func burst_bead(object_id: String) -> void:
	var e := enc()
	if e == null:
		return
	var o := e.spells.zones.get_object(object_id)
	if o == null or bool(o.rules.get("burst", false)):
		return
	o.rules["burst"] = true
	o.ended = true
	var ctx := e.spells.context_for_object(o)
	if ctx.is_empty():
		return
	var cells: Array[Vector2i] = []
	for a: Variant in o.rules.get("burst_cells", []):
		cells.append(Vector2i(int((a as Array)[0]), int((a as Array)[1])))
	e.events.append({"type": "spell", "caster": o.caster_id, "spell": "delayed_blast_fireball", "cells": cells, "targets": []})
	e.log.add("spell", "The bead bursts (%dd6 Fire)" % int(o.rules["bead_dice"]), o.caster_id)
	var s2 := (ctx["s"] as Dictionary).duplicate()
	s2["damage"] = [{"dice": "%dd6" % int(o.rules["bead_dice"]), "type": "fire", "scales": false}]
	s2.erase("upcast")
	ctx["s"] = s2
	e.spells._save_spell(ctx, e.spells.creatures_in(cells), CombatResult.new())
	e.spells.zones.prune()


## The caster's end of turn: beads grow, Earthquake shakes everyone in it, Storm of Vengeance and Tsunami run their round.
func caster_turn_end(c: Combatant) -> void:
	for o: FieldObject in sp().zones.live():
		if o.caster_id != c.id:
			continue
		if o.spell_id == "delayed_blast_fireball" and not bool(o.rules.get("burst", false)):
			o.rules["bead_dice"] = int(o.rules["bead_dice"]) + 1
			if o.rounds_left == 1:
				burst_bead(o.id)
		if o.has_trigger("caster_end_turn"):
			for t in sp().zones._inside(o):
				o.hit_on_turn.erase(t.id)
				sp().zones._affect(o, t, "end_turn", CombatResult.new(), {})


func caster_turn_start(c: Combatant) -> void:
	var e := enc()
	prism_caster_turn_start(c)
	# Time Stop: more turns come straight after; the caster mustn't stray more than 1,000 ft.
	for o: FieldObject in sp().zones.live():
		if o.caster_id != c.id:
			continue
		if bool(o.rules.get("fissures", false)) and not bool(o.rules.get("fissures_open", false)):
			o.rules["fissures_open"] = true
			open_fissures(o, c)
		if o.rules.has("storm_round"):
			_storm_round(o)
		if o.rules.has("tsunami"):
			_tsunami(o, c)
		if o.rules.has("drift_away"):
			var away := Vector2(o.cell) - e.center_of(c)
			if away.length() > 0.01:
				var dv := Vector2i(roundi(away.normalized().x * 2), roundi(away.normalized().y * 2))
				var moved: Array[Vector2i] = []
				for cl in o.cells:
					moved.append(cl + dv)
				o.cells = moved
				o.cell += dv
				sp().zones.moved_object(o, CombatResult.new())


## Earthquake's fissures (the start of the caster's next turn): 1d6 of them, each 10 ft wide and running straight
## across the quake. The caster lays them through its foes (the nearest first, along the row or column that catches
## the most foes and the fewest friends). A creature where one opens makes a Dexterity save: a failure drops it
## 1d10 x 10 ft (falling damage, Prone) and it must climb out (an action and a DC 15 Strength (Athletics) check); a
## success leaves it on the edge, moved to the nearest solid ground.
func open_fissures(o: FieldObject, c: Combatant) -> void:
	var e := enc()
	var area := {}
	for cl in o.cells:
		area[cl] = true
	var count := e.dice.roll_one(6, "Earthquake fissures")
	var crack := {}
	var placed := 0
	var foes := e.hostiles_of(c).filter(func(h: Combatant) -> bool: return area.has(h.cell) and not h.is_down())
	foes.sort_custom(func(a: Combatant, b: Combatant) -> bool: return e.distance(c, a) < e.distance(c, b))
	for f: Combatant in foes:
		if placed >= count:
			break
		if crack.has(f.cell):
			continue
		var best: Array[Vector2i] = []
		var best_score := -1000000000
		for horizontal: bool in [true, false]:
			var line: Array[Vector2i] = []
			for cl: Vector2i in o.cells:
				var along := cl.y if horizontal else cl.x
				var mine := f.cell.y if horizontal else f.cell.x
				if along == mine or along == mine + 1:
					line.append(cl)
			var score := 0
			for x in e.living():
				if x.footprint().any(func(q: Vector2i) -> bool: return q in line):
					score += 2 if c.hostile_to(x) else -3
			if score > best_score:
				best_score = score
				best = line
		for cl2 in best:
			crack[cl2] = true
		placed += 1
	if crack.is_empty():
		e.log.add("info", "The ground splits, but no fissure opens beneath anyone", c.id)
		return
	var f2 := FieldObject.new(FieldObject.Kind.ZONE, "earthquake", "Fissures")
	f2.caster_id = c.id
	f2.cells.assign(crack.keys())
	f2.cell = f2.cells[0]
	f2.rules = {"triggers": [], "terrain": "difficult"}
	sp().zones.add(f2, CombatResult.new())
	e.log.add("spell", "%d fissure%s tear open across the ground" % [placed, "s" if placed > 1 else ""], c.id)
	for t in e.living():
		if t.is_down() or not t.footprint().any(func(q: Vector2i) -> bool: return crack.has(q)):
			continue
		var test := t.creature.roll_save(e.dice, &"dex", o.save_dc, [], [], "Dex save vs a fissure (%s)" % t.name(), ["save_vs:spell"])
		if test.success:
			var from := t.cell
			var spot := _solid_ground(t, crack)
			if spot != from:
				t.cell = spot
				e.events.append({"type": "move", "id": t.id, "from": from, "to": spot})
			e.log.add("info", "%s keeps to the fissure's edge" % t.name(), t.id, [test.describe()])
			continue
		var depth := e.dice.roll_one(10, "Fissure depth") * 10
		e.log.add("condition", "%s falls %d ft into a fissure" % [t.name(), depth], t.id, [test.describe()])
		fall(t.id, depth)
		if t.is_alive():
			var pit := Effect.new("In a fissure", &"spell", "earthquake_fissure").with_modifier("speed_set", {"value": 0})
			pit.caster_id = c.id
			pit.ends = Effect.Ends.NEVER
			pit.escape = {"skill": "athletics", "dc": 15}
			t.creature.add_effect(pit)


## The nearest square off the fissures (and not taken) for a creature that kept its feet.
func _solid_ground(t: Combatant, crack: Dictionary) -> Vector2i:
	var e := enc()
	var best := t.cell
	var best_d := 1 << 30
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var cl := t.cell + Vector2i(dx, dy)
			if crack.has(cl) or not e.grid.in_bounds(cl) or e.grid.is_solid(cl):
				continue
			var o := e.occupant_at(cl)
			if o != null and o != t:
				continue
			var d := absi(dx) + absi(dy)
			if d < best_d:
				best_d = d
				best = cl
	return best


## Storm of Vengeance's later rounds (counted at the start of the caster's turns): 2, 4d6 Acid to everyone under the
## cloud; 3, six lightning bolts (Dex save, 10d6, half on a success) at the caster's foes; 4, 2d6 Bludgeoning hail;
## 5-10, 1d6 Cold, and the area is Difficult Terrain and Heavily Obscured and ranged weapon attacks across it fail.
func _storm_round(o: FieldObject) -> void:
	var e := enc()
	o.rules["storm_round"] = int(o.rules["storm_round"]) + 1
	var round := int(o.rules["storm_round"])
	var ctx := sp().context_for_object(o)
	if ctx.is_empty():
		return
	var c := ctx["c"] as Combatant
	var inside := sp().creatures_in(o.cells)
	match round:
		2:
			e.log.add("spell", "Acid rain pours from the storm", o.caster_id)
			for t in inside:
				var a := e._roll_damage_dice("4d6", false, 0, "Acid rain")
				e.deal_damage(c, t, [{"amount": int(a["total"]), "type": "acid", "spell": true}], false, "Storm of Vengeance")
		3:
			e.log.add("spell", "Lightning lances down from the storm", o.caster_id)
			var bolts := 0
			for t in inside:
				if bolts >= 6 or not c.hostile_to(t):
					continue
				bolts += 1
				var l := e._roll_damage_dice("10d6", false, 0, "Lightning bolt")
				var ok := _save(ctx, t, &"dex")
				e.deal_damage(c, t, [{"amount": int(l["total"]) / 2 if ok else int(l["total"]), "type": "lightning", "spell": true}], false, "Storm of Vengeance")
		4:
			e.log.add("spell", "Hailstones hammer down", o.caster_id)
			for t in inside:
				var h := e._roll_damage_dice("2d6", false, 0, "Hail")
				e.deal_damage(c, t, [{"amount": int(h["total"]), "type": "bludgeoning", "spell": true}], false, "Storm of Vengeance")
		_:
			if round >= 5:
				o.rules["terrain"] = "difficult"
				o.rules["obscured"] = "heavy"
				o.rules["deflects_missiles"] = true
				e.log.add("spell", "Freezing gusts howl through the storm", o.caster_id)
				for t in inside:
					e.deal_damage(c, t, [{"amount": e.dice.roll_one(6, "Cold wind"), "type": "cold", "spell": true}], false, "Storm of Vengeance")
				e.events.append({"type": "object", "id": o.id, "kind": "zone", "cell": o.cell})


## Tsunami: at the start of each of the caster's later turns the wall moves 50 ft away from the caster, crashing
## onto creatures (Strength save, half on a success), and loses a die of damage until it's gone.
func _tsunami(o: FieldObject, c: Combatant) -> void:
	var e := enc()
	var away := Vector2(o.cell) - e.center_of(c)
	if away.length() < 0.01:
		away = Vector2.RIGHT
	var dv := Vector2i(roundi(away.normalized().x * 10), roundi(away.normalized().y * 10))
	var moved: Array[Vector2i] = []
	for cl in o.cells:
		var n := cl + dv
		if e.grid.in_bounds(n):
			moved.append(n)
	o.cells = moved
	o.cell += dv
	var dice := int(o.rules["tsunami"]) - 1
	o.rules["tsunami"] = dice
	if dice <= 0 or moved.is_empty():
		o.ended = true
		e.log.add("info", "The tsunami subsides", c.id)
		return
	o.rules["damage"] = [{"dice": "%dd10" % dice, "type": "bludgeoning", "scales": false}]
	o.hit_on_turn.clear()
	sp().zones.moved_object(o, CombatResult.new())


# --- Antimagic Field ------------------------------------------------------------------------------------

## Whether `cell` lies in an Antimagic Field.
func antimagic_at(cell: Vector2i) -> bool:
	for o in sp().zones.live():
		if o.spell_id == "antimagic_field" and cell in o.cells:
			return true
	return false


func in_antimagic(c: Combatant) -> bool:
	if c == null:
		return false
	for f in c.footprint():
		if antimagic_at(f):
			return true
	return false


## Spell effects on creatures inside a field are suppressed (set aside, their time still running) and come back
## when the creature leaves, if they haven't ended meanwhile.
var _suppressed: Dictionary = {}   ## combatant id -> Array[Effect]


func refresh_antimagic() -> void:
	var e := enc()
	if e == null:
		return
	for c in e.combatants:
		var inside := in_antimagic(c)
		var held := _suppressed.get(c.id, []) as Array
		# Magic items go quiet inside: their bonuses, properties and powers (the bearer's real self too, if shapechanged).
		for who: Creature in [c.creature, e.shapes.original(c)]:
			if who is Character and (who as Character).magic_suppressed != inside:
				(who as Character).magic_suppressed = inside
		if inside:
			for fx: Effect in c.creature.effects.duplicate():
				if fx.source_kind in [&"spell", &"item"] and fx.source_id != "antimagic_field" and not fx.stack_key.begins_with("zone:"):
					c.creature.effects.erase(fx)
					held.append(fx)
			if not held.is_empty():
				_suppressed[c.id] = held
		elif not held.is_empty():
			for fx: Effect in held:
				var conc := fx.concentration
				if fx.concentration == null and fx.data.has("needs_conc"):
					continue
				if conc != null and conc.ended:
					continue
				c.creature.effects.append(fx)
			_suppressed.erase(c.id)
			e.events.append({"type": "condition", "id": c.id})


## Time keeps running for suppressed effects.
func tick_suppressed(owner_id: String, start: bool) -> void:
	for cid: String in _suppressed:
		var held := _suppressed[cid] as Array
		for fx: Effect in held.duplicate():
			var done := fx.on_turn_start(owner_id) if start else fx.on_turn_end(owner_id)
			if done:
				held.erase(fx)


# --- Holy Aura, Prismatic Wall -------------------------------------------------------------------------

## Holy Aura: a Fiend or Undead that hits a creature in the aura with a melee attack makes a Constitution save or is
## Blinded until the end of its next turn.
func holy_aura_hit(attacker: Combatant, target: Combatant) -> void:
	var e := enc()
	if not target.creature.has_flag("holy_aura") or not str(attacker.creature.creature_type) in ["fiend", "undead"] or not attacker.is_alive():
		return
	for o in sp().zones.live():
		if o.spell_id == "holy_aura" and o.covers(target):
			var sv := attacker.creature.roll_save(e.dice, &"con", o.save_dc, [], [], "Constitution save vs Holy Aura (%s)" % attacker.name())
			if not sv.success:
				var fx := Effect.new("Blinded (Holy Aura)", &"spell", "holy_aura").with_condition(&"blinded")
				fx.ends = Effect.Ends.END_OF_TURN
				fx.turn_owner_id = attacker.id
				fx.skip_turn_ends = e.own_turn_skip(attacker)
				attacker.creature.add_effect(fx)
				e.log.add("condition", "Holy light blinds %s" % attacker.name(), attacker.id, [sv.describe()])
				e.events.append({"type": "condition", "id": attacker.id})
			return


## The start of any creature's turn: Maze escapes, and Prismatic Wall's glare (other creatures within 20 ft make a
## Constitution save or are Blinded for a minute).
func creature_turn_start(c: Combatant) -> void:
	var e := enc()
	maze_turn(c)
	for o in sp().zones.live():
		if not bool(o.rules.get("prismatic", false)) or o.caster_id == c.id:
			continue
		var near := false
		for cell in o.cells:
			if e.grid.distance_ft(cell, 1, c.cell, c.size_cells) <= 20:
				near = true
				break
		if near and not c.creature.has_condition(&"blinded"):
			var glare_keys: Array[String] = ["save_vs:blinded"]
			var sv := c.creature.roll_save(e.dice, &"con", o.save_dc, [], [], "Constitution save vs Prismatic Wall's glare (%s)" % c.name(), glare_keys)
			if not sv.success:
				var fx := Effect.new("Blinded (Prismatic Wall)", &"spell", "prismatic_wall").with_condition(&"blinded")
				fx.lasting({"kind": "minutes", "amount": 1})
				fx.turn_owner_id = c.id
				c.creature.add_effect(fx)
				e.log.add("condition", "%s is dazzled blind by the Prismatic Wall" % c.name(), c.id, [sv.describe()])


## Passing into the Prismatic Wall: every layer in turn, red to violet.
func prismatic_layers(o: FieldObject, t: Combatant) -> void:
	var e := enc()
	var ctx := sp().context_for_object(o)
	if ctx.is_empty():
		return
	var dmg := e._roll_damage_dice("12d6", false, 0, "Prismatic Wall")
	e.log.add("spell", "%s passes through the Prismatic Wall's layers" % t.name(), t.id)
	for ray in range(1, 8):
		if not t.is_alive():
			return
		prism_ray(ctx, t, ray, int(dmg["total"]), CombatResult.new())
