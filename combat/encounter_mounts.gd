class_name EncounterMounts
extends RefCounted
## Mounted combat in a fight (Encounter, 2024 PHB): mounting and dismounting, a controlled mount carrying its rider,
## and a rider's save to stay in the saddle when the mount is moved against its will.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func mount_of(c: Combatant) -> Combatant:
	var e := enc()
	if not c.has_meta("mounted_on"):
		return null
	var m := e.get_c(str(c.get_meta("mounted_on")))
	return m if m != null and m.is_alive() else null


func rider_of(c: Combatant) -> Combatant:
	var e := enc()
	if not c.has_meta("ridden_by"):
		return null
	var r := e.get_c(str(c.get_meta("ridden_by")))
	return r if r != null and r.is_alive() else null


## A willing creature at least one size larger, within 5 ft, not already carrying someone.
func mount_why(rider: Combatant, steed: Combatant) -> String:
	var e := enc()
	if steed == null or steed == rider:
		return "Choose a mount"
	if mount_of(rider) != null:
		return "Already mounted"
	if rider_of(steed) != null or mount_of(steed) != null:
		return "%s already carries someone" % steed.name()
	if not rider.allied_with(steed) or steed.is_down():
		return "%s isn't willing" % steed.name()
	if Creature.SIZES.find(steed.creature.size) <= Creature.SIZES.find(rider.creature.size):
		return "%s must be at least one size larger" % steed.name()
	if e.distance(rider, steed) > 5:
		return "Move within 5 ft first"
	if rider.movement_left < rider.speed() / 2:
		return "Needs half your Speed"
	return ""


## Mounting costs half your Speed; you then share the mount's space and ride it.
func mount(rider: Combatant, steed: Combatant) -> CombatResult:
	var e := enc()
	var why := e._turn_check(rider)
	if why == "":
		why = mount_why(rider, steed)
	if why != "":
		return CombatResult.fail(why)
	rider.movement_left -= rider.speed() / 2
	var from := rider.cell
	rider.cell = steed.cell
	rider.set_meta("mounted_on", steed.id)
	steed.set_meta("ridden_by", rider.id)
	e.events.append({"type": "move", "id": rider.id, "from": from, "to": rider.cell, "mounted": true})
	e.log.add("move", "%s mounts %s" % [rider.name(), steed.name()], rider.id)
	return CombatResult.new()


## Dismounting costs half your Speed (none when thrown); you land in a free space within 5 ft of the mount.
func dismount(rider: Combatant, prone: bool = false, voluntary: bool = true) -> CombatResult:
	var e := enc()
	var steed := e.get_c(str(rider.get_meta("mounted_on", "")))
	if steed == null:
		return CombatResult.fail("Not mounted")
	if voluntary:
		var why := e._turn_check(rider)
		if why == "" and rider.movement_left < rider.speed() / 2:
			why = "Needs half your Speed"
		if why != "":
			return CombatResult.fail(why)
		rider.movement_left -= rider.speed() / 2
	rider.remove_meta("mounted_on")
	steed.remove_meta("ridden_by")
	var from := rider.cell
	var spot := e.spells._free_cell_near(steed.cell, rider.size_cells)
	rider.cell = spot
	e.events.append({"type": "move", "id": rider.id, "from": from, "to": spot, "forced": not voluntary})
	if prone:
		rider.creature.add_condition(&"prone", "Thrown from the mount")
		e.events.append({"type": "condition", "id": rider.id})
	e.log.add("move", "%s %s %s" % [rider.name(), "is thrown from" if prone else "dismounts", steed.name()], rider.id)
	return CombatResult.new()


## A controlled mount (Find Steed's, or any willing ally a creature rides): it moves when its rider moves.
func controlled_mount(rider: Combatant) -> Combatant:
	var m := mount_of(rider)
	return m if m != null and m.allied_with(rider) else null


## The mount was moved against its will: the rider makes a DC 10 Dexterity save or falls off Prone; a rider moved
## alone leaves its mount.
func _forced_mount_check(target: Combatant) -> void:
	var e := enc()
	var r := rider_of(target)
	if r != null:
		var sv := r.creature.roll_save(e.dice, &"dex", 10, [], [], "Dexterity save to stay mounted (%s)" % r.name())
		if sv.success:
			var from := r.cell
			r.cell = target.cell
			e.events.append({"type": "move", "id": r.id, "from": from, "to": r.cell, "forced": true, "mounted": true})
		else:
			e.log.add("info", "%s loses the saddle" % r.name(), r.id, [sv.describe()])
			dismount(r, true, false)
	elif mount_of(target) != null and target.cell != mount_of(target).cell:
		var m := mount_of(target)
		target.remove_meta("mounted_on")
		m.remove_meta("ridden_by")
		e.log.add("info", "%s is knocked from %s" % [target.name(), m.name()], target.id)
