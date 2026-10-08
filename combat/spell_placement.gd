class_name SpellPlacement
extends RefCounted
## Spells that put something on the field (SpellCaster): lingering zones and walls (which side a wall faces, rings,
## several areas at once), light against darkness, and spell objects such as Spiritual Weapon and where they stand.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Rebuilds the casting context for something a spell left behind (an area's save DC and damage on later turns).
func context_for_object(o: FieldObject) -> Dictionary:
	var spells := sp()
	var c := enc().get_c(o.caster_id)
	if c == null:
		return {}
	var s := _comp().spell_data(o.spell_id)
	var entry := spells._entry_any(c, o.spell_id) if spells.caster_char(c) != null else {}
	var nums := spells.numbers(c, entry) if spells.caster_char(c) != null else {"dc": Breakdown.new("DC").add("DC", o.save_dc), "attack": Breakdown.new("Attack"), "mod": 0}
	return {"c": c, "s": s, "slot": o.slot, "nums": nums, "conc": o.concentration, "opts": {}, "choice": str(o.rules.get("choice", ""))}


## A lingering area (`zone` data) from the cast's cells.
func _place_zone(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var z := (s["zone"] as Dictionary).duplicate(true)
	var o := FieldObject.new(FieldObject.Kind.ZONE, str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cells = cells
	o.cell = c.cell if cells.is_empty() else cells[0]
	# Call Lightning: the storm cloud spreads wider than the first bolt.
	if z.has("storm_radius") and (ctx["point"] as Vector2) != Vector2.INF:
		o.cells = enc().grid.area_cells("sphere", int(z["storm_radius"]), ctx["point"] as Vector2)
	o.origin = ctx["point"] as Vector2 if (ctx["point"] as Vector2) != Vector2.INF else enc().center_of(c)
	o.follows_caster = str((s.get("area", {}) as Dictionary).get("shape", "")) == "emanation" \
		and str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	z["size"] = int((s.get("area", {}) as Dictionary).get("size", 5))
	if not z.has("damage") and s.has("damage") and bool(z.get("uses_spell_damage", true)):
		z["damage"] = s["damage"]
	if not z.has("save") and s.has("save"):
		z["save"] = s["save"]
	if not z.has("half") and str(s.get("save_success", "")) == "half":
		z["half"] = true
	if not z.has("effects") and s.has("effects") and not bool(z.get("resolve_on_cast", false)):
		z["effects"] = s["effects"]
	z["choice"] = str(ctx.get("choice", ""))
	if str(z.get("damage_type_choice", "")) != "" and z.has("damage"):
		var parts := (z["damage"] as Array).duplicate(true)
		for p: Variant in parts:
			if not (p as Dictionary).has("type"):
				(p as Dictionary)["type"] = spells._damage_type(ctx, p as Dictionary)
		z["damage"] = parts
	# Cordon of Arrows: pieces of ammunition, two more per slot level above the spell's.
	if z.has("charges"):
		z["charges"] = int(z["charges"]) + int(z.get("charges_per_slot", 0)) * maxi(0, int(ctx["slot"]) - int(s.get("level", 0)))
	# The squares of what the area spreads from (Conjure Animals' pack).
	var area_d := s.get("area", {}) as Dictionary
	if int(area_d.get("origin_size", 1)) > 1 and (ctx["point"] as Vector2) != Vector2.INF:
		var osz := int(area_d["origin_size"])
		var pt := ctx["point"] as Vector2
		var oc := Vector2i(floori(pt.x - osz / 2.0 + 0.5), floori(pt.y - osz / 2.0 + 0.5))
		z["core_cells"] = CombatGrid.footprint(oc, osz).map(func(x: Vector2i) -> Array: return [x.x, x.y])
		o.cell = oc
	# Wall of Fire: the side that burns, 10 ft deep along the wall (the side `direction` points to).
	if z.has("side_ft") and str(area_d.get("shape", "")) == "wall":
		var drawn := SpellTargeting.path_of(ctx.get("opts", {}) as Dictionary)
		if str(ctx.get("choice", "")) == "ring":
			# A ring burns on its inside.
			var inside: Array = []
			var pt2 := ctx["point"] as Vector2
			for x in enc().grid.width:
				for y in enc().grid.depth:
					var cc := Vector2i(x, y)
					if (Vector2(cc) + Vector2(0.5, 0.5)).distance_to(pt2) < 10 / float(CombatGrid.FEET) - 0.5 and not cc in cells:
						inside.append([x, y])
			z["side_cells"] = inside
		elif not drawn.is_empty() and SpellTargeting.drawn_wall(s, str(ctx.get("choice", ""))):
			# A wall drawn square by square burns on the side its caster picked (opts.side).
			var dir0: Vector2 = ctx.get("direction", Vector2.ZERO)
			var side := chosen_side(drawn, ctx.get("opts", {}) as Dictionary, dir0)
			z["side_cells"] = path_side(drawn, side if side != "" else "left", int(z["side_ft"]), dir0)
		else:
			z["side_cells"] = _wall_side(ctx, cells, int(z["side_ft"]))
	o.rules = z
	if bool(z.get("spare_allies", false)):
		for a in enc().allies_of(c):
			o.spared.append(a.id)
		o.spared.append(c.id)
	var d := s.get("duration", {}) as Dictionary
	o.keep_with(ctx["conc"] as Concentration)
	if ctx["conc"] == null:
		o.rounds_left = int(d.get("amount", 1)) * (10 if str(d.get("kind", "")) == "minutes" else (600 if str(d.get("kind", "")) == "hours" else 1))
	# Lasts until the end of the caster's next turn (Ice Storm's hail): counted down at the end of the caster's turns.
	if z.has("caster_turn_ends"):
		o.rounds_left = -1
	if z.has("rounds") and ctx["conc"] == null:
		o.rounds_left = int(z["rounds"])
	_light_vs_darkness(o, int(ctx["slot"]))
	spells.zones.add(o, r)
	r.lines.append(enc().log.add("spell", "%s fills %d squares" % [s["name"], cells.size()], c.id))


## The union of several small areas (a creature in more than one is still affected once).
func multi_area(c: Combatant, spell_id: String, points: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var g := enc().grid
	var cap := 10 if spell_id == "fire_storm" else 4
	for i in mini(cap, points.size()):
		var p: Vector2 = points[i]
		var part: Array[Vector2i] = g.area_cells("cube", 10, Vector2(floorf(p.x), floorf(p.y) + 1.0), Vector2.RIGHT) if spell_id == "fire_storm" else g.area_cells("sphere", 40, p)
		for cell in part:
			if not cell in out:
				out.append(cell)
	return out


## The squares of a ring wall `radius_ft` from its centre.
func _ring(center: Vector2, radius_ft: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var g := enc().grid
	var r := radius_ft / float(CombatGrid.FEET)
	for x in g.width:
		for z in g.depth:
			var p := Vector2(x + 0.5, z + 0.5)
			if absf(p.distance_to(center) - r) <= 0.5 and not g.is_solid(Vector2i(x, z)):
				out.append(Vector2i(x, z))
	return out


## Squares within `feet` of a wall on one side of it: the side the cast's direction's left-hand normal points to.
func _wall_side(ctx: Dictionary, wall: Array[Vector2i], feet: int) -> Array:
	var e := enc()
	var dir := (ctx["direction"] as Vector2) if ctx.has("direction") and (ctx["direction"] as Vector2).length() > 0.01 else Vector2.RIGHT
	dir = dir.normalized()
	var normal := Vector2(-dir.y, dir.x)
	var origin := ctx["point"] as Vector2
	var out: Array = []
	var depth := feet / float(CombatGrid.FEET)
	for cell in wall:
		for step in range(1, int(depth) + 1):
			var p := Vector2(cell) + Vector2(0.5, 0.5) + normal * step
			var sc := Vector2i(floori(p.x), floori(p.y))
			if e.grid.in_bounds(sc) and not sc in wall and not [sc.x, sc.y] in out and (p - origin).dot(normal) > 0:
				out.append([sc.x, sc.y])
	return out


# --- The burning side of a drawn wall ---------------------------------------------------------------
# A wall drawn square by square (opts.path) burns on one side, the caster's pick: "left" or "right" of the way it was
# drawn, looking down on the map (x east, y south: drawn eastward, left is north). Along a bent wall each square takes
# the side of the stretch of wall nearest it, so the burning side follows the bends.

## The side a cast picked for its drawn wall (opts.side: "left", "right", or a square on that side), or "".
func chosen_side(path: Array[Vector2i], opts: Dictionary, direction: Vector2 = Vector2.ZERO) -> String:
	var v: Variant = opts.get("side", "")
	if v is Vector2i:
		return side_of(path, v as Vector2i, direction)
	if v is Array and (v as Array).size() >= 2:
		return side_of(path, Vector2i(int((v as Array)[0]), int((v as Array)[1])), direction)
	var named := str(v)
	return named if named in ["left", "right"] else ""


## Which side of the drawn wall `path` the square `cell` is on: "left", "right", or "" for a square of the wall, one in
## line past an end, or one two stretches of the wall are equally near from opposite sides.
func side_of(path: Array[Vector2i], cell: Vector2i, direction: Vector2 = Vector2.ZERO) -> String:
	if path.is_empty() or cell in path:
		return ""
	var signs := _nearest_sides(path, cell, direction)
	if signs.has(-1) and not signs.has(1):
		return "left"
	if signs.has(1) and not signs.has(-1):
		return "right"
	return ""


## The squares within `feet` of the drawn wall `path` (counted as on the grid) on its `side`: a square counts when the
## stretch of the wall nearest it has that side toward it (either of two equally near stretches will do). Squares in
## line past an end are on neither side. As [x, y] pairs, the way a zone keeps them.
func path_side(path: Array[Vector2i], side: String, feet: int, direction: Vector2 = Vector2.ZERO) -> Array:
	var e := enc()
	var out: Array = []
	if path.is_empty():
		return out
	var depth := feet / CombatGrid.FEET
	var want := -1 if side == "left" else 1
	var lo := path[0]
	var hi := path[0]
	for p in path:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	for x in range(lo.x - depth, hi.x + depth + 1):
		for y in range(lo.y - depth, hi.y + depth + 1):
			var cell := Vector2i(x, y)
			if not e.grid.in_bounds(cell) or cell in path:
				continue
			var near := false
			for p in path:
				if maxi(absi(p.x - x), absi(p.y - y)) <= depth:
					near = true
					break
			if near and _nearest_sides(path, cell, direction).has(want):
				out.append([x, y])
	return out


## The sides (-1 left, 1 right) the stretches of the wall nearest `cell` turn toward it; a stretch it lies in line with
## gives none. A one-square wall is a stretch along `direction` (east-west without one).
func _nearest_sides(path: Array[Vector2i], cell: Vector2i, direction: Vector2) -> Array[int]:
	var stretches: Array[PackedVector2Array] = []
	for i in range(1, path.size()):
		stretches.append(PackedVector2Array([Vector2(path[i - 1]) + Vector2(0.5, 0.5), Vector2(path[i]) + Vector2(0.5, 0.5)]))
	if stretches.is_empty():
		var along := direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
		var mid := Vector2(path[0]) + Vector2(0.5, 0.5)
		stretches.append(PackedVector2Array([mid - along * 0.5, mid + along * 0.5]))
	var q := Vector2(cell) + Vector2(0.5, 0.5)
	var best := INF
	var out: Array[int] = []
	for st in stretches:
		var a := st[0]
		var d := st[1] - a
		var t := clampf((q - a).dot(d) / d.length_squared(), 0.0, 1.0)
		var dist := q.distance_to(a + d * t)
		if dist > best + 0.001:
			continue
		if dist < best - 0.001:
			best = dist
			out.clear()
		# Looking down on the map with y south, a positive cross product is to the right of the drawing direction.
		var cross := d.x * (q - a).y - d.y * (q - a).x
		if absf(cross) > 0.001:
			out.append(1 if cross > 0.0 else -1)
	return out


## Darkness dispels light from spells of level 2 or lower that it overlaps; Daylight dispels Darkness of level 3
## or lower.
func _light_vs_darkness(o: FieldObject, slot: int) -> void:
	var spells := sp()
	if bool(o.rule("darkness", false)):
		for other in spells.zones.live():
			if other.rules.has("light") and int(_comp().spell_data(other.spell_id).get("level", 0)) <= 2:
				for cell in o.cells:
					if str(spells.zones.spell_light(cell)["level"]) != "":
						other.ended = true
						enc().log.add("info", "%s snuffs out %s" % [o.name, other.name], o.caster_id)
						break
	var up_to := int(o.rule("dispels_darkness", 0))
	if up_to > 0:
		for other in spells.zones.live():
			if bool(other.rule("darkness", false)) and other.slot <= maxi(up_to, slot):
				for cell in other.cells:
					if cell in o.cells or o.cells.is_empty():
						other.ended = true
						enc().log.add("info", "%s dispels %s" % [o.name, other.name], o.caster_id)
						break
	spells.zones.prune()


## Spiritual Weapon, Flaming Sphere, Dancing Lights, Mage Hand: an object on a square, kept by Concentration (or
## its duration), with the actions it grants. Spiritual Weapon attacks a creature within 5 ft when it appears.
func _place_object(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var od := s["object"] as Dictionary
	var kinds := {"weapon": FieldObject.Kind.WEAPON, "sphere": FieldObject.Kind.SPHERE, "lights": FieldObject.Kind.LIGHTS, "hand": FieldObject.Kind.HAND,
		"hound": FieldObject.Kind.HOUND, "vine": FieldObject.Kind.VINE}
	var o := FieldObject.new(kinds.get(str(od.get("kind", "weapon")), FieldObject.Kind.WEAPON), str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cell = ctx["cell"] as Vector2i
	o.cells = [o.cell]
	o.rules = (od.get("rules", {}) as Dictionary).duplicate(true)
	if s.has("damage") and not o.rules.has("damage") and o.rules.has("save"):
		o.rules["damage"] = s["damage"]
	o.keep_with(ctx["conc"] as Concentration)
	if ctx["conc"] == null:
		o.rounds_left = _duration_rounds(s.get("duration", {}) as Dictionary)
	spells.zones.add(o, r)
	enc().events.append({"type": "summon", "caster": c.id, "cell": o.cell})
	r.lines.append(enc().log.add("spell", "%s appears" % s["name"], c.id))
	if str(s["id"]) == "bigbys_hand":
		spells.specials.mid.spawn_hand(c, o)
	if s.has("sustain") and not bool(ctx.get("ended_on_save", false)):
		spells._grant_sustained(ctx, tgt)
	if str(od.get("on_appear", "")) == "attack":
		# It strikes a creature within its reach as it appears (Spiritual Weapon 5 ft; Grasping Vine 30 ft): the one
		# chosen, else the nearest enemy.
		var reach := int(od.get("reach", 5))
		var near: Combatant = null
		for t in tgt:
			if enc().grid.distance_ft(o.cell, 1, t.cell, t.size_cells) <= reach:
				near = t
		if near == null and tgt.is_empty():
			var best := 1 << 30
			for h in enc().hostiles_of(c):
				var dh := enc().grid.distance_ft(o.cell, 1, h.cell, h.size_cells)
				if not h.is_down() and dh <= reach and dh < best:
					best = dh
					near = h
		if near != null and near.is_alive():
			ctx["pull_origin"] = Vector2(o.cell) + Vector2(0.5, 0.5)
			ctx["attack_origin"] = o.cell
			var chosen: Array[Combatant] = []
			chosen.assign(tgt if not tgt.is_empty() else [near])
			for i in int(od.get("attacks", 1)):
				var victim := chosen[i % chosen.size()]
				if victim.is_alive():
					spells.spell_attack(ctx, victim, r)


## How many rounds a duration lasts (1 minute = 10 rounds).
static func _duration_rounds(d: Dictionary) -> int:
	match str(d.get("kind", "")):
		"rounds":
			return int(d.get("amount", 1))
		"minutes":
			return int(d.get("amount", 1)) * 10
		"hours":
			return int(d.get("amount", 1)) * 600
		"days":
			return int(d.get("amount", 1)) * 14400
	return 10


func weapon_of(c: Combatant) -> FieldObject:
	var spells := sp()
	return spells.zones.object_of(c.id, "spiritual_weapon")


func has_spiritual_weapon(c: Combatant) -> bool:
	return weapon_of(c) != null


## A free square next to `t`, the one closest to `c` (where a summoned weapon appears).
func _beside(c: Combatant, t: Combatant) -> Vector2i:
	var best := t.cell
	var best_d := 1 << 30
	for dx in range(-1, t.size_cells + 1):
		for dy in range(-1, t.size_cells + 1):
			var cell := t.cell + Vector2i(dx, dy)
			if cell in t.footprint() or not enc().grid.in_bounds(cell) or enc().grid.is_solid(cell):
				continue
			if enc().occupant_at(cell) != null:
				continue
			var d := enc().grid.distance_ft(c.cell, c.size_cells, cell, 1)
			if d < best_d:
				best_d = d
				best = cell
	return best


## The Bonus Action follow-up: move the weapon up to 20 ft to `cell`, then attack a creature within 5 ft of it.
func spiritual_weapon_attack(c: Combatant, target: Combatant, cell: Vector2i) -> CombatResult:
	var spells := sp()
	var a := spells.sustained_for(c, "spiritual_weapon")
	if a.is_empty():
		return CombatResult.fail("No Spiritual Weapon")
	return spells.use_sustained(c, str(a["id"]), [target] if target != null else [], Vector2(cell.x + 0.5, cell.y + 0.5))
