class_name SpellTargeting
extends RefCounted
## Where a spell reaches in a fight (SpellCaster): its range (with Spell Sniper and the like), how many targets it
## takes, the squares its area covers, the creatures in them, and checking a cast's targets and point before anything is
## spent. Walls are drawn square by square (opts.path); Crown of Madness's caster names the creature the crowned one
## must attack (opts.crown_victim, and again when keeping control).

## Walls with a length are drawn square by square, unless the cast-time choice makes a ring, a globe or a dome; a
## Tsunami is aimed at a point instead (it rolls away from its caster).
const NOT_DRAWN := ["tsunami"]
const RING_CHOICES := ["ring", "globe", "dome"]
## Straight walls: Blade Barrier's, and Prismatic Wall's flat plane. Every step goes the way the first one went.
const STRAIGHT_WALLS := ["blade_barrier", "prismatic_wall"]
## Walls that rise "from a point you choose within range": only their first square has to be in range. Every square
## of the others (on a surface "within range", or appearing "within range") must be.
const FROM_A_POINT := ["wind_wall", "wall_of_stone", "wall_of_force"]

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Range in feet. A Self-range spell that still targets a creature (Vampiric Touch) reaches as far as a melee
## attack; Touch is 5 ft; cantrips like Spare the Dying grow with level (`cantrip_scaling.range`).
func range_ft(s: Dictionary, caster: Combatant = null) -> int:
	var r := s.get("range", {}) as Dictionary
	var rh := enc().ravenloft.spell_range(caster, s) if enc() != null else -1
	if rh >= 0:
		return rh
	match str(r.get("kind", "self")):
		"feet":
			var ft := int(r.get("feet", 0))
			# Spell Sniper: +60 ft for attack-roll spells of 10 ft or more; Improved Illusions: +60 ft for Illusions.
			if caster != null and ft >= 10 and ((s.has("attack") and enc().features.has_feat(caster, "spell_sniper")) \
					or (str(s.get("school", "")) == "illusion" and CombatFeatures.has_feature(caster, "improved_illusions"))):
				ft += 60
			# Eldritch Spear: a damaging Warlock cantrip reaches 30 ft × Warlock level.
			if caster != null and int(s.get("level", 0)) == 0 and s.has("damage") and ClassFeatures.knows_invocation(caster, "eldritch_spear") and "warlock" in (s.get("classes", []) as Array):
				ft = maxi(ft, 30 * ClassFeatures.level_of(caster, "warlock"))
			var sc := s.get("cantrip_scaling", {}) as Dictionary
			if sc.has("range_doubles") and caster != null:
				ft *= int(pow(2, Spellcasting.cantrip_tier(caster.creature.character_level())))
			return ft
		"touch":
			return 5
		"self":
			if (s.get("targets", {}) as Dictionary).has("within"):
				return int((s["targets"] as Dictionary)["within"])
			if s.has("attack") and not s.has("area"):
				return 5
			if s.has("object") or s.has("sustain"):
				return int((s.get("object", {}) as Dictionary).get("range", 0))
			return 0
	return 9999


func target_count(s: Dictionary, slot: int) -> int:
	var t := s.get("targets", {}) as Dictionary
	if str(t.get("count", "")) == "any":
		return 99
	var base := int(t.get("count", 1))
	var up := s.get("upcast", {}) as Dictionary
	var extra := maxi(0, slot - int(s.get("level", 0)))
	return base + int(up.get("targets", 0)) * extra + int(up.get("projectiles", 0)) * extra


## The area a spell would cover: cells around the point of origin.
func area_for(c: Combatant, s: Dictionary, point: Vector2, direction: Vector2, slot: int = 0) -> Array[Vector2i]:
	var area := s.get("area", {}) as Dictionary
	if area.is_empty():
		return []
	var shape := str(area["shape"])
	var size := int(area["size"]) + int((s.get("upcast", {}) as Dictionary).get("area", 0)) * maxi(0, slot - int(s.get("level", 0)))
	var g := enc().grid
	var center := enc().center_of(c)
	var self_origin := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	if shape == "emanation" and self_origin:
		return g.area_cells("emanation", size, center, Vector2.RIGHT, 5, c.cell, c.size_cells)
	if shape == "emanation":
		# An Emanation from something placed at the point (Conjure Animals' Large pack, Guardian of Faith): its own
		# squares count too.
		var osz := int(area.get("origin_size", 1))
		var oc := Vector2i(floori(point.x - osz / 2.0 + 0.5), floori(point.y - osz / 2.0 + 0.5)) if osz > 1 else Vector2i(floori(point.x), floori(point.y))
		var em := g.area_cells("emanation", size, Vector2(oc) + Vector2(osz / 2.0, osz / 2.0), Vector2.RIGHT, 5, oc, osz)
		for f in CombatGrid.footprint(oc, osz):
			if g.in_bounds(f) and not f in em:
				em.append(f)
		return em
	if self_origin and shape == "cone":
		var aim := direction if direction.length() > 0.01 else Vector2(c.facing)
		if aim.length() < 0.01:
			aim = Vector2.RIGHT
		return g.cone_from(c.cell, c.size_cells, center + aim, size)
	if self_origin:
		var dir := direction.normalized() if direction.length() > 0.01 else Vector2(c.facing)
		if dir.length() < 0.01:
			dir = Vector2.RIGHT
		var origin := center + dir * (c.size_cells / 2.0)
		return g.area_cells(shape, size, origin, dir, int(area.get("width", 5)))
	if shape == "cylinder":
		shape = "sphere"
	return g.area_cells(shape, size, point, direction, int(area.get("width", 5)))


func creatures_in(cells: Array[Vector2i]) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in enc().living():
		for cell in o.footprint():
			if cell in cells:
				out.append(o)
				break
	return out


## Who an area spell affects among the creatures in it: everyone (default for a point), everyone but the caster
## (default for areas from yourself), or "creatures of your choice" (`area_targets`: enemies / allies).
func _area_victims(c: Combatant, s: Dictionary, cells: Array[Vector2i], choice: String = "") -> Array[Combatant]:
	var spells := sp()
	var self_area := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	var mode := str(s.get("area_targets", "others" if self_area else "all"))
	mode = str((s.get("area_targets_by_choice", {}) as Dictionary).get(choice, mode))
	var out: Array[Combatant] = []
	for v in creatures_in(cells):
		if enc().items.spell_blocked(c, v) != "":
			continue
		# A conjured object (Bigby's Hand) is only hurt by what targets it.
		if v.creature.has_flag("spell_object"):
			continue
		match mode:
			"others":
				if v == c:
					continue
			"enemies":
				if not c.hostile_to(v):
					continue
			"allies":
				if v != c and not c.allied_with(v):
					continue
		out.append(v)
	out.assign(out.filter(func(v: Combatant) -> bool: return not spells.specials.high.in_antimagic(v) or str(s.get("id", "")) == "antimagic_field"))
	out.assign(out.filter(func(v: Combatant) -> bool: return not spells.specials.mid.globe_blocks(c, v, int(s.get("level", 0)))))
	var cap := int(s.get("area_max_targets", 0))
	if cap > 0 and out.size() > cap:
		out.sort_custom(func(a: Combatant, b: Combatant) -> bool: return enc().distance(c, a) < enc().distance(c, b))
		out.resize(cap)
	return out


## A cast-time choice ("choice": {kind, from}) resolved from opts: the picked value, or the first option.
static func choice_of(s: Dictionary, opts: Dictionary) -> String:
	var ch := s.get("choice", {}) as Dictionary
	if ch.is_empty():
		return ""
	var from := ch.get("from", []) as Array
	var pick := str(opts.get("choice", opts.get("damage_type", opts.get("word", ""))))
	if pick in from.map(func(x: Variant) -> String: return str(x)):
		return pick
	return str(from[0]) if not from.is_empty() else ""


## Validates targets, range and line of effect. {why, targets: Array[Combatant], cell: Vector2i}
func _check_targets(c: Combatant, s: Dictionary, slot: int, targets: Array, point: Vector2, opts: Dictionary) -> Dictionary:
	var spells := sp()
	var e := enc()
	var tgt: Array[Combatant] = []
	for t: Variant in targets:
		if t is Combatant:
			tgt.append(t as Combatant)
	var out := {"why": "", "targets": tgt, "cell": Vector2i(-1, -1)}
	if not s.has("attack") and str(s["id"]) != "magic_missile" and not bool(s.get("repeat_targets", false)):
		var seen_targets: Array[String] = []
		for target in tgt:
			if target.id in seen_targets:
				out["why"] = "Choose distinct creatures"
				return out
			seen_targets.append(target.id)
	var rng := range_ft(s, c)
	# Gaze of Two Minds: range and line of effect from the linked ally's space.
	var from := e.class_features.cast_origin(c)
	# Distant Spell: double range, Touch becomes 30 ft.
	if bool(opts.get("range_mult", false)):
		rng = 30 if str((s.get("range", {}) as Dictionary).get("kind", "")) == "touch" else rng * 2
	var id := str(s["id"])
	if id == "mordenkainens_lucubration":
		var selected := str(opts.get("choice", "auto"))
		if selected != "auto":
			var slots := {}
			var parts := selected.split("+")
			for word in parts:
				var lv := int(word)
				slots[str(lv)] = int(slots.get(str(lv), 0)) + 1
				if parts.size() > 2 or lv < 1 or lv > slot / 2 or spells.caster_char(c) == null or int(slots[str(lv)]) > spells.caster_char(c).expended_slots(lv):
					out["why"] = "Choose up to two expended slots of level %d or lower" % (slot / 2)
					return out
	if id == "catnap":
		for t in tgt:
			if t.creature.has_flag("catnap_rested"):
				out["why"] = "%s needs a Long Rest before benefiting from Catnap again" % t.name()
				return out
	var tkind := str((s.get("targets", {}) as Dictionary).get("kind", "creature"))
	var placed := s.has("object") or id in ["misty_step", "dimension_door"] or id in SpellCaster.SUMMON_SPELLS
	if placed:
		var cell: Vector2i = opts.get("cell", Vector2i(-1, -1))
		if cell.x < 0 and point != Vector2.INF:
			cell = Vector2i(floori(point.x), floori(point.y))
		if cell.x < 0 and not tgt.is_empty():
			cell = spells._beside(c, tgt[0])
		if cell.x < 0:
			out["why"] = "Choose a square"
			return out
		if not e.grid.in_bounds(cell) or e.grid.is_solid(cell):
			out["why"] = "Can't go there"
			return out
		if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > rng:
			out["why"] = "That square is out of range (%d ft)" % rng
			return out
		if (id in ["misty_step", "dimension_door", "flaming_sphere"] or id in SpellCaster.SUMMON_SPELLS) and e.occupant_at(cell) != null:
			out["why"] = "That square is occupied"
			return out
		if spells.specials.high.antimagic_at(cell) and (id in ["misty_step", "dimension_door"] or id in SpellCaster.SUMMON_SPELLS):
			out["why"] = "Magic can't reach into the Antimagic Field"
			return out
		if id == "misty_step" and not e.can_see_space(c, cell):
			out["why"] = "You must see the square you teleport to"
			return out
		if id in SpellCaster.SUMMON_SPELLS:
			var block := SummonBlocks.for_spell(id, slot, choice_of(s, opts), {})
			var footprint := CombatGrid.size_cells_for(StringName(str(block.get("size", "medium"))))
			if not spells._room_for(cell, footprint):
				out["why"] = "The summoned creature needs an unoccupied space large enough for it"
				return out
			if id.begins_with("summon_") and not e.can_see_space(c, cell, footprint):
				out["why"] = "You must see the summoned creature's space"
				return out
		if s.has("object") and bool((s["object"] as Dictionary).get("pick_attack_targets", false)):
			var od := s["object"] as Dictionary
			if tgt.size() > int(od.get("attacks", 1)):
				out["why"] = "Too many attack targets"
				return out
			for victim in tgt:
				if victim.creature.dead or e.grid.distance_ft(cell, 1, victim.cell, victim.size_cells) > int(od.get("reach", 5)):
					out["why"] = "Choose living targets within the spell object's reach"
					return out
		if bool(opts.get("splintered", false)):
			var points := opts.get("points", []) as Array
			if points.size() != 2 or not points[1] is Vector2:
				out["why"] = "Choose two separate spaces for the spirits"
				return out
			var other_opts := opts.duplicate()
			other_opts.erase("splintered")
			other_opts.erase("cell")
			var other := _check_targets(c, s, slot, [], points[1] as Vector2, other_opts)
			if str(other["why"]) != "":
				return other
			var block := SummonBlocks.for_spell(id, slot, choice_of(s, opts), {})
			var size := CombatGrid.size_cells_for(StringName(str(block.get("size", "medium"))))
			var first := CombatGrid.footprint(cell, size)
			for square in CombatGrid.footprint(other["cell"] as Vector2i, size):
				if square in first:
					out["why"] = "The spirits' spaces must not overlap"
					return out
		out["cell"] = cell
		return out
	if id in ["animate_objects"]:
		return out
	if tkind == "self" and not s.has("area"):
		tgt = [c]
		out["targets"] = tgt
		return out
	# A wall drawn square by square: its squares, and a Wall of Fire's burning side, instead of a point.
	if opts.has("path") and drawn_wall(s, choice_of(s, opts)):
		out["why"] = wall_path_why(c, s, slot, path_of(opts), opts)
		if str(out["why"]) == "" and opts.has("side") and sp().placement.chosen_side(path_of(opts), opts) == "":
			out["why"] = "Choose a square on one side of the wall"
		return out
	if s.has("area") and str((s.get("range", {}) as Dictionary).get("kind", "")) != "self" and not s.has("attack"):
		if point == Vector2.INF:
			out["why"] = "Choose a point"
			return out
		var pc := Vector2i(floori(point.x), floori(point.y))
		if e.grid.distance_ft(c.cell, c.size_cells, pc, 1) > rng and e.grid.distance_ft(from.cell, from.size_cells, pc, 1) > rng:
			out["why"] = "That point is out of range (%d ft)" % rng
		return out
	if s.has("area") and not s.has("attack"):
		return out
	if tgt.is_empty():
		out["why"] = "Choose a target"
		return out
	if tgt.size() > target_count(s, slot) and not id in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		out["why"] = "Too many targets (%d max)" % target_count(s, slot)
		return out
	if id == "eldritch_blast" and tgt.size() > spells.specials.beams(c):
		var beams := spells.specials.beams(c)
		out["why"] = "Eldritch Blast has %d beam%s" % [beams, "" if beams == 1 else "s"]
		return out
	for t in tgt:
		if bool(s.get("requires_sight", false)) and not e.can_see(from, t) and not e.can_see(c, t):
			out["why"] = "You must see the target"
			return out
		if id == "revivify":
			if not t.creature.dead:
				out["why"] = "%s isn't dead" % t.name()
				return out
		elif t.creature.dead:
			out["why"] = "%s is dead" % t.name()
			return out
		if e.distance(from, t) > rng and e.distance(c, t) > rng:
			out["why"] = "%s is out of range (%d ft)" % [t.name(), rng]
			return out
		if t != c and int(e.cover(from, t)["cover"]) == CombatGrid.Cover.TOTAL and int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL:
			out["why"] = "No line of effect to %s" % t.name()
			return out
		var only := str((s.get("targets", {}) as Dictionary).get("creature_type", ""))
		if only == "" and str((s.get("targets", {}) as Dictionary).get("description", "")).contains("Humanoid"):
			only = "humanoid"
		if only != "" and str(t.creature.creature_type) != only:
			out["why"] = "%s only affects %ss" % [s["name"], only.capitalize()]
			return out
		if t != c and spells.specials.mid.wall_between(c, t):
			out["why"] = "A wall is in the way"
			return out
		if t != c and spells.specials.mid.globe_blocks(c, t, slot):
			out["why"] = "A Globe of Invulnerability turns the spell aside"
			return out
		if spells.specials.high.in_antimagic(t) and t != c:
			out["why"] = "%s is inside an Antimagic Field" % t.name()
			return out
		if t != c and spells.specials.high.box_between(c, t):
			out["why"] = "A wall of force is in the way"
			return out
		if t != c and spells.specials.sphere_blocks(c, t):
			out["why"] = "A sphere of force stands between you and %s" % t.name()
			return out
		if (s.has("attack") or s.has("damage")) and t != c:
			var sb := spells.sanctuary_blocks(c, t)
			if sb != "":
				out["why"] = sb
				return out
			var charm := e.charm_blocks(c, t)
			if charm != "":
				out["why"] = charm
				return out
	# Crown of Madness: the creature the crowned one must attack ("" is no one).
	var victim_id := str(opts.get("crown_victim", ""))
	if victim_id != "" and not tgt.is_empty():
		out["why"] = crown_victim_why(c, tgt[0], e.get_c(victim_id))
	return out


# --- Walls drawn square by square ------------------------------------------------------------------

## Whether a wall spell is drawn square by square (opts.path) with this cast-time choice: a wall with a length, not
## its ring, globe or dome, and not a Tsunami.
static func drawn_wall(s: Dictionary, choice: String = "") -> bool:
	return str((s.get("area", {}) as Dictionary).get("shape", "")) == "wall" and not str(s.get("id", "")) in NOT_DRAWN \
		and not choice in RING_CHOICES


## The squares drawn for a wall (opts.path: squares as Vector2i, or [x, y] pairs), in drawing order.
static func path_of(opts: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Variant in opts.get("path", []):
		if v is Vector2i:
			out.append(v as Vector2i)
		elif v is Vector2:
			out.append(Vector2i(floori((v as Vector2).x), floori((v as Vector2).y)))
		elif v is Array and (v as Array).size() >= 2:
			out.append(Vector2i(int((v as Array)[0]), int((v as Array)[1])))
	return out


## How many squares long a wall can be: its length in feet (a Wall of Stone's or Force's ten 10-ft panels laid end to
## end are 100 ft) over 5 ft a square, diagonal steps included (the grid counts them as 5 ft).
func wall_squares(s: Dictionary, slot: int) -> int:
	var area := s.get("area", {}) as Dictionary
	var feet := int(area.get("size", 0)) + int((s.get("upcast", {}) as Dictionary).get("area", 0)) * maxi(0, slot - int(s.get("level", 0)))
	return maxi(1, feet / CombatGrid.FEET)


## Why `cell` can't be the next square of the wall `path` being drawn ("" if it can): a square of the map that isn't
## solid, not in the wall yet, touching the last square (diagonally too, but not across the corner of a wall or other
## solid square), the wall no longer than the spell allows, within range (only the first square for a wall that rises
## from a point), and for a straight wall in line with its first step.
func wall_step_why(c: Combatant, s: Dictionary, slot: int, path: Array[Vector2i], cell: Vector2i, opts: Dictionary = {}) -> String:
	var e := enc()
	if not e.grid.in_bounds(cell) or e.grid.is_solid(cell):
		return "The wall can't go through a solid square"
	if cell in path:
		return "That square is already part of the wall"
	var most := wall_squares(s, slot)
	if path.size() >= most:
		return "The wall is already as long as it gets (%d ft)" % (most * CombatGrid.FEET)
	if path.is_empty() or not str(s.get("id", "")) in FROM_A_POINT:
		var rng := range_ft(s, c)
		if bool(opts.get("range_mult", false)):
			rng *= 2
		var from := e.class_features.cast_origin(c)
		if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > rng and e.grid.distance_ft(from.cell, from.size_cells, cell, 1) > rng:
			return "That square is out of range (%d ft)" % rng
	if path.is_empty():
		return ""
	var last := path[path.size() - 1]
	var step := cell - last
	if maxi(absi(step.x), absi(step.y)) != 1:
		return "Each square must touch the last one"
	if step.x != 0 and step.y != 0 and (e.grid.is_solid(last + Vector2i(step.x, 0)) or e.grid.is_solid(last + Vector2i(0, step.y))):
		return "The wall can't pass the corner of a solid square"
	if str(s.get("id", "")) in STRAIGHT_WALLS and path.size() >= 2 and step != path[1] - path[0]:
		return "%s is a straight wall" % str(s.get("name", "The wall"))
	return ""


## Why the drawn wall `path` can't be cast ("" if it can): every square checked as if added one at a time.
func wall_path_why(c: Combatant, s: Dictionary, slot: int, path: Array[Vector2i], opts: Dictionary = {}) -> String:
	if path.is_empty():
		return "Draw the wall: choose its squares"
	var so_far: Array[Vector2i] = []
	for cell in path:
		var why := wall_step_why(c, s, slot, so_far, cell, opts)
		if why != "":
			return why
		so_far.append(cell)
	return ""


## A wall spell's squares from its cast-time shape (the hook in SpellCasting's and CombatItems' casts): the squares
## drawn (opts.path), a ring around the point (`area.ring` ft across from it, 10 when left out) or a globe (15 ft),
## else `cells` (a straight wall through the point, along the cast's direction: east-west without one).
func wall_cells(s: Dictionary, opts: Dictionary, point: Vector2, cells: Array[Vector2i]) -> Array[Vector2i]:
	var area := s.get("area", {}) as Dictionary
	if str(area.get("shape", "")) != "wall":
		return cells
	var choice := choice_of(s, opts)
	if choice in ["ring", "globe"] and point != Vector2.INF:
		return sp()._ring(point, int(area.get("ring", 10)) if choice == "ring" else 15)
	var path := path_of(opts)
	if not path.is_empty() and drawn_wall(s, choice):
		return path
	return cells


# --- Crown of Madness ------------------------------------------------------------------------------

## Why `victim` can't be the creature Crown of Madness's `crowned` must attack ("" if it can; null is no one): any
## creature but the crowned one, and not the caster, whom the Charmed creature can't attack.
func crown_victim_why(caster: Combatant, crowned: Combatant, victim: Combatant) -> String:
	if victim == null:
		return ""
	if not victim.is_alive():
		return "%s is dead" % victim.name()
	if victim == crowned:
		return "It must attack a creature other than itself"
	if victim == caster:
		return "It is Charmed by you and can't attack you"
	return ""


## Names the creature `crowned` must attack on its turns (an id, or "" for no one): at casting (opts.crown_victim) and
## each time its caster keeps control.
func set_crown_victim(crowned: Combatant, victim_id: String) -> void:
	crowned.set_meta("crown_victim", victim_id)


## The attack Crown of Madness forces on `crowned` this turn, by the choice of a player's caster: {target, option}
## when the chosen creature is alive and within reach of one of its melee attacks, else {} (it acts normally).
func crown_attack(crowned: Combatant) -> Dictionary:
	var e := enc()
	var victim := e.get_c(str(crowned.get_meta("crown_victim", "")))
	if victim == null or not victim.is_alive() or victim == crowned:
		return {}
	var best := {}
	for o in e.attack_options(crowned):
		if bool(o["melee"]) and e.weapons.attack_legal(crowned, victim, o) == "" \
				and (best.is_empty() or (o["profile"] as WeaponProfile).average_damage() > (best["profile"] as WeaponProfile).average_damage()):
			best = o
	return {} if best.is_empty() else {"target": victim, "option": best}
