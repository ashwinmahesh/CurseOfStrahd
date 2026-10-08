class_name ObjectFire
extends RefCounted
## Fire that spreads and barrels that burst (F5 piece 3, our rulings: deviations.md), owned by EncounterObjects as
## `fire`:
## - At the end of each round fire spreads one square from what burns then: oil on the floor beside a fire lights, a
##   barrel of lamp oil beside one bursts, and a flammable object beside one catches on a d6 roll of 4 or more.
## - A barrel of lamp oil that fire reaches (Fire damage, catching fire, burning oil or coals spreading to it) bursts
##   (its kind's `bursts`): each creature within its radius, measured with how high it flies, makes the save, taking
##   the damage on a failure and half on a success; the objects there take it too and flammable ones catch fire (another
##   barrel bursts in turn); oil there lights and webs burn; and the floor around it is left burning.

## A flammable object beside a fire catches at the end of a round on a d6 roll of at least this.
const SPREAD_ON := 4

var _enc: WeakRef
## Bursts under way (object id -> true), so a chain of barrels goes off one at a time.
var _bursting: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func objs() -> EncounterObjects:
	return enc().objects


## The squares on fire: burning objects' and burning squares' (oil, webs, coals).
func fire_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o in objs().list:
		if o.burning and not o.destroyed:
			out.append_array(objs().cells_of(o))
	for sq in objs().squares:
		if bool(sq.get("lit", false)):
			out.append(sq["cell"] as Vector2i)
	return out


## Whether any of `cells` is on or beside (within 5 ft of) one of `fires`.
static func beside(cells: Array[Vector2i], fires: Array[Vector2i]) -> bool:
	for c in cells:
		for f in fires:
			if maxi(absi(c.x - f.x), absi(c.y - f.y)) <= 1:
				return true
	return false


## The end of a round (EncounterObjects.round_started): fire spreads from the fires burning now (not from what catches
## along the way): oil lights, barrels of lamp oil burst, a flammable object catches on a d6 of 4 or more.
func spread() -> void:
	var e := enc()
	var fires := fire_cells()
	if fires.is_empty():
		return
	for sq: Dictionary in objs().squares.duplicate():
		var here: Array[Vector2i] = [sq["cell"] as Vector2i]
		if bool(sq.get("oil", false)) and not bool(sq.get("lit", false)) and beside(here, fires):
			objs()._light(sq, "The fire spreads to the oil on the floor")
	for o: BattleObject in objs().list.duplicate():
		if o.destroyed or o.burning or o.hangs or o.holds != "" or not beside(objs().cells_of(o), fires):
			continue
		if not o.bursts.is_empty():
			burst(o, null)
			continue
		if not o.flammable:
			continue
		var d6 := e.dice.roll_one(6, "Fire spreading to %s" % o.name)
		if d6 >= SPREAD_ON:
			e.log.add("info", "The fire spreads to %s" % o.the(), "", ["d6: %d (%d or more catches)" % [d6, SPREAD_ON]])
			objs().ignite(o)


## `o` bursts (its kind's `bursts`: radius, save, dc, damage, type, oil). `by`: whoever set it off, if anyone.
func burst(o: BattleObject, by: Combatant) -> void:
	var e := enc()
	if o.destroyed or o.bursts.is_empty() or _bursting.has(o.id):
		return
	_bursting[o.id] = true
	var b := o.bursts
	var at := o.cells[0]
	var radius := int(b.get("radius", 10))
	objs().clear_squares(o)
	o.destroyed = true
	o.hp = 0
	o.burning = false
	objs().fires_changed()
	var area := e.grid.area_cells("sphere", radius, Vector2(at) + Vector2(0.5, 0.5))
	if not at in area:
		area.append(at)
	e.events.append({"type": "object_burst", "id": o.id, "cells": area})
	e.log.add("info", "%s bursts in a sheet of flame" % o.title(), by.id if by != null else "")
	var rolled := e._roll_damage_dice(str(b.get("damage", "2d6")), false, 0, "The bursting %s" % o.name)
	var ab := StringName(str(b.get("save", "dex")))
	var ty := str(b.get("type", "fire"))
	for t in e.living():
		# Within the radius as the game measures it, height and all: a flyer high enough above it is out of reach.
		if t.has_meta("left_fight") or t.creature.has_flag("ethereal") \
				or e.grid.distance_ft(at, 1, t.cell, t.size_cells, 0, t.altitude) > radius:
			continue
		var sv := t.creature.roll_save(e.dice, ab, int(b.get("dc", 12)), [], [], "%s save vs the bursting %s (%s)" % [Creature.ABILITY_NAMES[ab], o.name, t.name()])
		var amount := int(rolled["total"]) if not sv.success else int(rolled["total"]) / 2
		if amount > 0:
			e.deal_damage(by, t, [{"amount": amount, "type": ty}], false, "The bursting %s" % o.name, [sv.describe(), str(rolled["text"])])
	for o2: BattleObject in objs().list.duplicate():
		if o2 == o or o2.destroyed or o2.holds != "" or o2.hangs or not objs().cells_of(o2).any(func(cell: Vector2i) -> bool: return cell in area):
			continue
		objs().damage(o2, [{"amount": int(rolled["total"]), "type": ty}], by, "the bursting %s" % o.name, [str(rolled["text"])])
		if ty == "fire" and not o2.destroyed:
			objs().ignite(o2)
	if bool(b.get("oil", false)):
		for cell in area:
			if maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= 1 and not e.grid.has_flag(cell, CombatGrid.LOW) \
					and objs().square_at(cell).is_empty():
				objs().burning_square(cell, "Burning oil spills across the floor")
	if ty == "fire":
		objs().expose_to_fire(area, by)
	_bursting.erase(o.id)
