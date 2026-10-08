class_name EncounterSight
extends RefCounted
## What creatures in a fight can see (Encounter): line of sight, light and darkness, obscured squares, invisibility,
## hiding and special senses, sunlight, and cover from walls and other creatures.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Squares other creatures stand in, with their names, for cover (creatures give Half Cover).
func creature_cells(exclude: Array = []) -> Dictionary:
	var e := enc()
	var out := {}
	for c in e.combatants:
		if c.is_alive() and not c in exclude and not c.is_down():
			for cell in c.footprint():
				out[cell] = c.name()
	return out


func cover(attacker: Combatant, target: Combatant) -> Dictionary:
	var e := enc()
	var key := [_layout_hash(), attacker.cell, attacker.size_cells, target.cell, target.size_cells, attacker.id, target.id].hash()
	if e._cover_cache.has(key):
		return e._cover_cache[key] as Dictionary
	if e._cover_cache.size() > 20000:
		e._cover_cache.clear()
	var result := e.grid.cover_between(attacker.cell, attacker.size_cells, target.cell, target.size_cells,
		creature_cells([attacker, target]))
	e._cover_cache[key] = result
	return result


## Where everyone stands and who is up: cover from creatures depends on it.
func _layout_hash() -> int:
	var e := enc()
	var parts: Array = []
	for c in e.combatants:
		if c.is_alive() and not c.is_down():
			parts.append(c.cell)
			parts.append(c.size_cells)
	return parts.hash()


func can_see_space(a: Combatant, cell: Vector2i, size: int = 1) -> bool:
	var marker := Combatant.new(Creature.new(), &"neutral", cell)
	marker.size_cells = size
	return can_see(a, marker)


## Whether `a` can see `b`: line of sight through walls, Heavily Obscured squares (Fog Cloud, Darkness), light
## (Darkvision in the dark; nothing but Blindsight or Truesight in magical Darkness), and `b` being Invisible,
## hidden or on the Ethereal Plane (See Invisibility and Truesight see the Invisible; Faerie Fire and Starry Wisp
## take its benefit away; Mind Spike's caster always knows where its target is).
func can_see(a: Combatant, b: Combatant) -> bool:
	var e := enc()
	# Echo Avatar: the knight sees through its echoes instead of its own (Blinded) eyes.
	if e.echo_knight.in_avatar(a):
		return e.echo_knight.echo_sees(a, b)
	var dist := e.distance(a, b)
	var blind := a.creature.sense_range("blindsight")
	var truesight := a.creature.sense_range("truesight")
	var by_sense := (blind > 0 and dist <= blind) or (truesight > 0 and dist <= truesight)
	if b.creature.has_flag("ethereal"):
		return truesight > 0 and dist <= truesight and e.grid.can_see(a.cell, a.size_cells, b.cell, b.size_cells)
	if not e.grid.can_see(a.cell, a.size_cells, b.cell, b.size_cells):
		return false
	if b.creature.has_flag("tracked_by:%s" % a.id):
		return true
	if blind > 0 and dist <= blind:
		return true
	if a.creature.has_flag("cant_see"):
		return false
	var outlined := b.creature.has_flag("no_invisible")
	if b.hidden and not outlined:
		return false
	if b.creature.has_condition(&"invisible") and not outlined:
		var sees_invisible := a.creature.has_flag("see_invisibility") or (truesight > 0 and dist <= truesight) or e.items.reveals_invisible(a, b)
		if not sees_invisible:
			return false
	# Devil's Sight (invocation): normal sight in Darkness, magical or not, within 120 ft.
	var devil := (a.creature.has_flag("devils_sight") and dist <= 120) or e.ravenloft.sees_through_darkness(a)
	if e.spells.zones.line_obscured(a.cell, a.size_cells, b.cell, b.size_cells, devil) and not by_sense:
		return false
	# Umbral Sight (Gloom Stalker): unseen in Darkness by creatures that rely on Darkvision.
	var umbral := b.creature.has_flag("umbral_sight") and light_at(b.cell) == "dark"
	match light_at(b.cell):
		"magic_dark":
			return by_sense or devil
		"dark":
			return by_sense or devil or (a.creature.darkvision() >= dist and a.creature.darkvision() > 0 and not umbral) or outlined
	return true


## The light on a square: "bright", "dim", "dark", or "magic_dark" (Darkness), from the map's light, spells and fires
## (burning objects and oil, EncounterObjects).
func light_at(cell: Vector2i) -> String:
	var e := enc()
	if e.spells.zones.magical_darkness(cell):
		return "magic_dark"
	var sl := e.spells.zones.spell_light(cell)
	var lvl := str(sl["level"])
	var fire := e.objects.light_at(cell)
	if lvl == "bright" or fire == "bright" or e.ambient_light == "bright":
		return "bright"
	if lvl == "dim" or fire == "dim" or e.ambient_light == "dim":
		return "dim"
	return "dark"


## Whether sunlight falls on a creature (Daylight, or a sunlit map): Sunlight Sensitivity and Hypersensitivity.
func in_sunlight(c: Combatant) -> bool:
	var e := enc()
	if e.sunlit:
		return true
	for cell in c.footprint():
		if bool(e.spells.zones.spell_light(cell)["sunlight"]) and not e.spells.zones.magical_darkness(cell):
			return true
	return false


## High ground (owner's house rule, 2026-10-07, from Baldur's Gate 3): a ranged attack from 10 ft or more above its
## target gets +2 to hit, one from 10 ft or more below gets -2. Heights count the floor and how far each is off it.
## Returns the bonus (+2, -2 or 0).
func height_edge(c: Combatant, target: Combatant, option: Dictionary) -> int:
	var e := enc()
	if bool(option.get("melee", true)):
		return 0
	var from: Vector2i = option.get("origin_cell", c.cell)
	var up := 0 if option.has("origin_cell") else c.altitude
	var rise := (e.grid.height(from) + up) - (e.grid.height(target.cell) + target.altitude)
	if rise > CombatGrid.FEET:
		return HIGH_GROUND
	if rise < -CombatGrid.FEET:
		return -HIGH_GROUND
	return 0


const HIGH_GROUND := 2
