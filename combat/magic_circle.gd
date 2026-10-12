class_name MagicCircle
extends RefCounted
## Magic Circle in a fight (2024 PHB; docs/rules/deviations.md, Wards and rests): cast while exploring within the hour
## before a fight in the same place (story/wards.gd), it stands around its caster as the fight starts. Celestials,
## Elementals, Fey, Fiends and Undead can't step into it, and make their attack rolls against anyone inside it at
## Disadvantage.

const TYPES: Array[String] = ["celestial", "elemental", "fey", "fiend", "undead"]
const FEET := 10


## Puts the circle on the board around `caster`.
static func place(e: Encounter, caster: Combatant) -> void:
	var o := FieldObject.new(FieldObject.Kind.ZONE, "magic_circle", "Magic Circle")
	o.caster_id = caster.id
	o.cell = caster.cell
	o.origin = e.center_of(caster)
	o.cells = e.grid.area_cells("emanation", FEET, o.origin, Vector2.RIGHT, 5, caster.cell, caster.size_cells)
	for f in caster.footprint():   # the circle is drawn around its caster, who stands inside it
		if not f in o.cells:
			o.cells.append(f)
	o.rules = {"triggers": [], "affects": "none", "colour": "gilt", "size": FEET}
	e.spells.zones.add(o, CombatResult.new())
	e.log.add("spell", "%s's Magic Circle stands around them" % caster.name(), caster.id)


## The squares a warded creature can't step into: every Magic Circle's, unless it's already inside.
static func blocks(e: Encounter, c: Combatant) -> Dictionary:
	var out := {}
	if not str(c.creature.creature_type) in TYPES:
		return out
	for o in e.spells.zones.live():
		if o.spell_id != "magic_circle" or c.footprint().any(func(f: Vector2i) -> bool: return f in o.cells):
			continue
		for cell in o.cells:
			out[cell] = true
	return out


## Whether a Magic Circle shields `target` from `attacker`'s attack (Disadvantage).
static func shields(e: Encounter, attacker: Combatant, target: Combatant) -> bool:
	if not str(attacker.creature.creature_type) in TYPES:
		return false
	for o in e.spells.zones.live():
		if o.spell_id == "magic_circle" and target.footprint().any(func(f: Vector2i) -> bool: return f in o.cells):
			return true
	return false
