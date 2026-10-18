class_name AiHazards
extends RefCounted
## Dangerous ground as the AI sees it (owner, 2026-10-13: "creatures shouldn't willingly move into dangerous terrain
## unless their intelligence is really low"): lingering areas that would hurt or hold a creature (Spirit Guardians,
## Hunger of Hadar, Cloud of Daggers, Moonbeam, Wall of Fire and its burning side, Spike Growth, Web, the heat beside a
## Flaming Sphere), burning oil, coals and webs on the floor, and traps the party has found. A creature whose
## Intelligence is above MINDLESS_INT heeds the ones it knows of (AiBrain): it walks round them, attacks from outside
## them, leaves one it starts in, and goes in only when no foe can be reached any other way. Then it goes in at once
## rather than waste its turn at the edge (owner, 2026-10-18: "as long as it won't kill them"), but never where the
## ground at its worst could drop it (View.deadly). Zombies, beasts, oozes and plants walk straight in, and so does
## anyone made to move (Command, Transfix, Turn Undead).
## Sunlight is dangerous ground too for a creature it burns (Sunlight Hypersensitivity: Strahd and his spawn, owner
## 2026-10-13): the squares a Sunsword, a Daylight or a Sunbeam lights brightly, where it would start its turn burning
## and fight at Disadvantage.
## What it knows: an area it can see, or one it stands in. Spike Growth is camouflaged (2024; its zone's `camouflaged`):
## only those who could see the area as it was cast, or were hurt by it since, know it's there (SpellZones keeps them
## in the area's `known_by`). A trap is known once the party has found it.

## Creatures this clever or less (their Intelligence) don't heed dangerous ground.
const MINDLESS_INT := 3
## A condition the ground would put on a creature (Web's Restrained, Grease's Prone) weighs as this much damage.
const CONDITION_COST := 5.0
## Sunlight Hypersensitivity's burn at the start of a turn, and what fighting at Disadvantage in it weighs as.
const SUNLIGHT_BURN := 20.0
const SUNLIGHT_DISADVANTAGE := 5.0
## A save takes some of the harm away: the expected harm of a hit with a save is the full harm times this.
const SAVE_SHARE := 0.75
## Prismatic Wall's layers, all at once: what they weigh, and their worst (five layers of 12d6).
const PRISMATIC_COST := 60.0
const PRISMATIC_WORST := 360.0
## Going in has to leave it standing at the ground's worst (every die at its highest, every save failed): its Hit
## Points and Temporary Hit Points, less that worst, keep at least this share of its Hit Point maximum, 1 at least.
const KEEP_SHARE := 0.1
## Conditions that count as harm (AiSpells weighs the same ones).
const HARMFUL := ["paralyzed", "stunned", "unconscious", "petrified", "incapacitated", "restrained", "blinded",
	"frightened", "charmed", "poisoned", "prone", "grappled"]

static var _dice_re: RegEx = RegEx.create_from_string("^(?:(\\d*)d(\\d+))?([+-]\\d+)?$|^(\\d+)$")
## Off, no creature heeds dangerous ground: what heeding it changes, measured in one sitting (a fight series' A/B).
static var heeded: bool = true

var _enc: WeakRef


## One creature's picture of the dangerous ground this turn (AiHazards.read).
class View:
	extends RefCounted
	## Each place that would hurt it: {touch: the squares where its space would overlap the place, raw: the place's own
	## squares, enter: a hit on stepping in, end: a hit on ending a turn there, hit: that hit's expected harm, once: it
	## hits at most once a turn, used: it already hit this creature this turn, step: harm for every square walked inside
	## (Spike Growth), start: harm as its next turn starts there (Hunger of Hadar's cold, a burning web), inside: the
	## creature stands in it now, sun: it is sunlight that burns it; worst, worst_step, worst_start: hit, step and start
	## at their worst, in Hit Points: every die at its highest, no save made, conditions left out}.
	var places: Array[Dictionary] = []
	## The squares its walk keeps out of: every place it isn't already standing in (EncounterMovement.reachable_for).
	var avoid: Dictionary = {}
	## Every place's squares, the ones it stands in included.
	var all: Dictionary = {}
	## The most the ground may take from it at its worst on a walk that still leaves it standing (KEEP_SHARE); raised to
	## the least it can get away with when every square it can end on costs more (AiBrain._least_harm).
	var room := 0.0

	## What walking `path` (squares from where it stands) and ending its turn on the last one would cost it: a hit for
	## each place it steps into or ends in (most hit once a turn), Spike Growth's every square, and what hits as its
	## next turn starts there.
	func cost(path: Array[Vector2i]) -> float:
		return _sum(path, "hit", "step", "start")

	## The Hit Points walking `path` and ending its turn on the last square could take from it at the worst: the same
	## hits as `cost`, each at its highest with every save failed.
	func worst(path: Array[Vector2i]) -> float:
		return _sum(path, "worst", "worst_step", "worst_start")

	## Whether walking `path` could drop it: its worst is more than it has `room` for.
	func deadly(path: Array[Vector2i]) -> bool:
		return worst(path) > room + 0.01

	func _sum(path: Array[Vector2i], hit_key: String, step_key: String, start_key: String) -> float:
		if path.is_empty():
			return 0.0
		var total := 0.0
		var last: Vector2i = path.back()
		for p in places:
			var touch := p["touch"] as Dictionary
			var step := float(p[step_key])
			var was := touch.has(path[0])
			var entered := false
			for i in range(1, path.size()):
				var now := touch.has(path[i])
				if now:
					total += step
					entered = entered or not was
				was = now
			var ends := touch.has(last)
			var hits := 0
			if entered and bool(p["enter"]):
				hits += 1
			if ends and bool(p["end"]):
				hits += 1
			if bool(p["once"]):
				hits = 0 if bool(p["used"]) else mini(hits, 1)
			total += hits * float(p[hit_key])
			if ends:
				total += float(p[start_key])
		return total

	## The sunlight burn waiting for it on `cell` as its next turn starts (Sunlight Hypersensitivity), 0 when none.
	func sun_burn(cell: Vector2i) -> float:
		var burn := 0.0
		for p in places:
			if bool(p.get("sun", false)) and (p["touch"] as Dictionary).has(cell):
				burn = maxf(burn, float(p["start"]))
		return burn

	## Whether its space on `cell` touches none of the dangerous ground.
	func clear(cell: Vector2i) -> bool:
		for p in places:
			if (p["touch"] as Dictionary).has(cell):
				return false
		return true


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## `c`'s picture of the dangerous ground it knows of, or null when there's none or it doesn't heed any (MINDLESS_INT, or
## the `mindless` profile: twig blights shamble on like zombies).
func read(c: Combatant) -> View:
	var e := enc()
	if not heeded or (e.spells.zones.objects.is_empty() and e.objects.squares.is_empty() and e.traps.list.is_empty()):
		return null
	if c.creature.ability_score(&"int") <= MINDLESS_INT or str(c.ai_profile) == "mindless":
		return null
	var v := View.new()
	var turn := "%d:%d" % [e.round_no, e.turn_index]
	for o in e.spells.zones.live():
		_zone(v, c, o, turn)
	_fires(v, c, turn)
	_traps(v, c)
	_sunlight(v, c)
	if v.places.is_empty():
		return null
	for p in v.places:
		for cell: Vector2i in p["raw"]:
			v.all[cell] = true
			if not bool(p["inside"]):
				v.avoid[cell] = true
	v.room = room_for(c)
	return v


## The most dangerous ground may take from `c` at its worst and leave it standing: its Hit Points and Temporary Hit
## Points less a tenth of its Hit Point maximum (KEEP_SHARE), 1 at least.
static func room_for(c: Combatant) -> float:
	var keep := maxf(1.0, ceilf(KEEP_SHARE * float(c.creature.max_hp())))
	return float(c.creature.hp + c.creature.temp_hp) - keep


## The squares `c` reaches within `budget` feet (its movement left by default) keeping out of the dangerous ground it
## knows of; {} when it heeds none (a legendary move walks this way when it can).
func calm_reach(c: Combatant, budget: int = -1) -> Dictionary:
	var v := read(c)
	return {} if v == null else enc().reachable_for(c, budget, false, v.avoid)


## Whether `c` knows area `o` is there: one it can see, or stands in; a camouflaged one (Spike Growth) only once it saw
## it cast or was hurt by it.
func knows(c: Combatant, o: FieldObject) -> bool:
	if bool(o.rule("camouflaged", false)):
		return c.id == o.caster_id or c.id in (o.rule("known_by", []) as Array)
	return o.covers(c) or not c.creature.has_condition(&"blinded")


## The foes among `foes` that `c` could strike (in the reach or range of one of `options`) from a square clear of the
## dangerous ground, walking only round it, however many turns that takes: when there's one, going in isn't needed.
## The ground it stands in it may cross only as far as `now` (this turn's walk) takes it: a long stretch of it ahead
## isn't a way round, so it pushes on through rather than turning back out of it every other turn. A square another
## creature stands on is none to strike from: the hole a Spirit Guardians cleric's own square makes in her spirits
## is no way round them (it had foes beside her closing on her instead of striking, every other turn).
func reachable_foes(c: Combatant, v: View, foes: Array[Combatant], options: Array[Dictionary],
		now: Dictionary = {}) -> Array[Combatant]:
	var e := enc()
	var g := e.grid
	var range_ft := 5
	for o in options:
		var p := o["profile"] as WeaponProfile
		range_ft = maxi(range_ft, p.reach if bool(o["melee"]) else (p.long_range if p.long_range > 0 else p.normal_range))
	var ground := v.all
	var taken := {}
	for o in e.combatants:
		if o != c and o.is_alive():
			for f in o.footprint():
				taken[f] = true
	var walk := g.reachable(c.cell, c.size_cells, 4000, func(x: Vector2i) -> bool: return ground.has(x) and not now.has(x),
		func(_x: Vector2i) -> bool: return false, func(x: Vector2i) -> bool: return taken.has(x), e.move_mode(c))
	var out: Array[Combatant] = []
	for t in foes:
		for cell: Vector2i in walk:
			if bool((walk[cell] as Dictionary)["occupied"]):
				continue
			if v.clear(cell) and g.distance_ft(cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) <= range_ft:
				out.append(t)
				break
	return out


# --- What the ground does -------------------------------------------------------------------------------------------

## A lingering area or spell object (SpellZones) that would harm `c`: its squares, and the burning side or the heat
## around it.
func _zone(v: View, c: Combatant, o: FieldObject, turn: String) -> void:
	var e := enc()
	if not e.spells.zones.affects(o, c) or not knows(c, o):
		return
	var caster := e.get_c(o.caster_id)
	var friend := caster != null and (caster == c or caster.allied_with(c))
	if friend and (o.rules.has("heal_allies") or o.rules.has("ally_effects")):
		return
	if bool(o.rule("prismatic", false)):
		_place(v, c, o.cells, {"enter": true, "hit": PRISMATIC_COST, "worst": PRISMATIC_WORST})
		return
	var triggers := o.rule("triggers", []) as Array
	var hit := _harm(c, o)
	var top := _harm(c, o, true)
	var once := bool(o.rule("once_per_turn", true))
	var used := once and str(o.hit_on_turn.get(c.id, "")) == turn
	var start := 0.0
	var top_start := 0.0
	if o.rules.has("start_damage"):
		start = _dice(c, o.rules["start_damage"] as Array)   # Hunger of Hadar's cold: no save
		top_start = _dice(c, o.rules["start_damage"] as Array, true)
	elif "start_turn" in triggers:
		start = hit
		top_start = top
	var enter := hit > 0.0 and "enter" in triggers
	var end := hit > 0.0 and ("end_turn" in triggers or "caster_start_turn" in triggers)
	var per_square := "per_square" in triggers
	var step := hit if per_square else 0.0
	if enter or end or step > 0.0 or start > 0.0:
		_place(v, c, o.cells, {"enter": enter, "end": end, "hit": hit, "once": once, "used": used, "step": step,
			"start": start, "worst": top, "worst_step": top if per_square else 0.0, "worst_start": top_start})
	# Wall of Fire: ending a turn on its burning side.
	var side := o.rule("side_cells", []) as Array
	if end and not side.is_empty():
		var burning: Array[Vector2i] = []
		for sc: Variant in side:
			burning.append(Vector2i(int((sc as Array)[0]), int((sc as Array)[1])))
		_place(v, c, burning, {"end": true, "hit": hit, "once": once, "used": used, "worst": top})
	# Flaming Sphere: ending (or starting) a turn within reach of it.
	var near_end := "near_end_turn" in triggers
	if hit > 0.0 and (near_end or "near_start_turn" in triggers):
		var reach := int(o.rule("reach", 5))
		var k := reach / CombatGrid.FEET
		var around: Array[Vector2i] = []
		for dx in range(-k, k + 1):
			for dy in range(-k, k + 1):
				around.append(o.cell + Vector2i(dx, dy))
		_place(v, c, around, {"end": near_end, "hit": hit, "once": once, "used": used, "start": 0.0 if near_end else hit,
			"worst": top, "worst_start": 0.0 if near_end else top})


## Burning oil and coals on the floor (a flyer above them is safe), and burning webs.
func _fires(v: View, c: Combatant, turn: String) -> void:
	for sq: Dictionary in enc().objects.squares:
		if not bool(sq.get("lit", false)) or (c.altitude > 0 and not bool(sq.get("web", false))):
			continue
		var fire: Array = [{"dice": str(sq.get("damage", "5")), "type": "fire"}]
		var harm := _dice(c, fire)
		if harm <= 0.0:
			continue
		var top := _dice(c, fire, true)
		var on := sq.get("on", []) as Array
		var used := str((sq.get("hit", {}) as Dictionary).get(c.id, "")) == turn
		_place(v, c, [sq["cell"] as Vector2i], {"enter": "enter" in on, "end": "end" in on, "hit": harm, "used": used,
			"start": harm if "start" in on else 0.0, "worst": top, "worst_start": top if "start" in on else 0.0})


## Traps the party has found that haven't gone off (a flyer passes over them).
func _traps(v: View, c: Combatant) -> void:
	if c.altitude > 0:
		return
	for t: Dictionary in enc().traps.list:
		if bool(t["sprung"]) or not bool(t["found"]):
			continue
		var spec := t["spec"] as Dictionary
		var harm := 0.0
		var top := 0.0
		if str(spec.get("damage", "")) != "":
			var dmg: Array = [{"dice": str(spec["damage"]), "type": str(spec.get("damage_type", "bludgeoning"))}]
			harm += _dice(c, dmg)
			top += _dice(c, dmg, true)
		var tens := float(int(spec.get("pit_ft", 0)) / 10)
		harm += tens * 3.5   # the fall: 1d6 for every 10 ft
		top += tens * 6.0
		if str(spec.get("condition", "")) != "":
			harm += CONDITION_COST
		if not (spec.get("save", {}) as Dictionary).is_empty():
			harm *= SAVE_SHARE
		if harm > 0.0:
			_place(v, c, t["cells"] as Array, {"enter": true, "hit": harm, "worst": top})


## The bright sunlight that burns `c` (Sunlight Hypersensitivity), from every light source shedding it: none on a sunlit
## map, where there's nowhere out of it.
func _sunlight(v: View, c: Combatant) -> void:
	var e := enc()
	if e.sunlit or e.monster_actions.sunlight(c) != "hypersensitivity":
		return
	for o in e.spells.zones.live():
		var l := o.rules.get("light", {}) as Dictionary
		if not bool(l.get("sunlight", false)):
			continue
		var src := o.cell
		if str(o.rule("light_on", "")) == "caster" or o.follows_caster:
			var cc := e.get_c(o.caster_id)
			if cc != null:
				src = cc.cell
		elif str(o.rule("light_on", "")) == "target":
			var tt := e.get_c(str(o.rule("light_target", "")))
			if tt != null:
				src = tt.cell
		var k := int(l.get("bright", 0)) / CombatGrid.FEET
		var lit: Array[Vector2i] = []
		for dx in range(-k, k + 1):
			for dy in range(-k, k + 1):
				var cell := src + Vector2i(dx, dy)
				if e.grid.in_bounds(cell) and e.grid.distance_ft(src, 1, cell, 1) <= int(l.get("bright", 0)) \
						and not e.spells.zones.magical_darkness(cell):
					lit.append(cell)
		_place(v, c, lit, {"end": true, "hit": SUNLIGHT_DISADVANTAGE, "start": SUNLIGHT_BURN, "worst_start": SUNLIGHT_BURN,
			"sun": true})


## Adds a place on `raw` squares to `v`, with the squares where `c`'s space would touch it.
func _place(v: View, c: Combatant, raw: Array, fields: Dictionary) -> void:
	var cells := {}
	for x: Variant in raw:
		cells[x as Vector2i] = true
	var touch := {}
	var n := c.size_cells
	for cell: Vector2i in cells:
		for dx in n:
			for dy in n:
				touch[cell - Vector2i(dx, dy)] = true
	var inside := false
	for f in c.footprint():
		inside = inside or cells.has(f)
	var p := {"touch": touch, "raw": cells.keys(), "enter": false, "end": false, "hit": 0.0, "once": true, "used": false,
		"step": 0.0, "start": 0.0, "inside": inside, "worst": 0.0, "worst_step": 0.0, "worst_start": 0.0}
	p.merge(fields, true)
	v.places.append(p)


## The expected harm of one hit of area `o` on `c`: its damage (what `c` is immune to left out, what it resists halved)
## and the conditions it would put on it, less what a save takes away. `worst`: the damage alone at its highest, the
## save failed.
func _harm(c: Combatant, o: FieldObject, worst: bool = false) -> float:
	var harm := _dice(c, o.rule("damage", []) as Array, worst)
	if worst:
		return harm
	for raw: Variant in o.rule("effects", []):
		var fx := raw as Dictionary
		if str(fx.get("effect", "")) != "condition":
			continue
		var cond := str((fx.get("params", {}) as Dictionary).get("condition", ""))
		var sn := StringName(cond)
		if cond in HARMFUL and not c.creature.is_condition_immune(sn) and not c.creature.has_condition(sn):
			harm += CONDITION_COST
	if o.rules.has("save"):
		harm *= SAVE_SHARE
	return harm


## The average of damage `parts` ({dice, type}) to `c`; `worst`, the highest they can roll (doubled where it's
## vulnerable).
func _dice(c: Combatant, parts: Array, worst: bool = false) -> float:
	var total := 0.0
	for raw: Variant in parts:
		var part := raw as Dictionary
		var expr := str(part.get("dice", "0")).replace(" ", "").to_lower()
		if _dice_re.search(expr) == null:
			continue
		var type := StringName(str(part.get("type", "")))
		if type != &"" and c.creature.immunity_source(type) != "":
			continue
		var x := DiceRoller.parse_expr(expr)
		var avg := float(x["count"]) * (float(x["sides"]) + 1.0) / 2.0 + float(x["modifier"])
		if worst:
			avg = float(x["count"]) * float(x["sides"]) + float(x["modifier"])
			if type != &"" and c.creature.vulnerability_source(type) != "":
				avg *= 2.0
		if type != &"" and c.creature.resistance_source(type) != "":
			avg /= 2.0
		total += avg
	return total
