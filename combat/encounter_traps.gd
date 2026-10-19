class_name EncounterTraps
extends RefCounted
## A location's traps in a fight (owner, 2026-10-08): any creature, friend or foe, that moves onto the square of a trap
## that hasn't gone off springs it, found or not, walking or shoved: the trap's saving throw, then its damage (half on a
## success) and its condition on a failure; a pit drops it the pit's depth instead (2024 falling) on a failure. A sprung
## trap is spent. LocationFights hands the location's traps over as the fight starts (`add`) and marks the ones that
## went off afterwards (`sprung_ids`); a saved fight keeps them (`to_dict`).

## Minutes a condition a trap gives lasts when its entry names none (`condition_minutes`): a minute for a fright, ten
## for anything else, so nothing a trap does stays on a hero for good (owner todo, 2026-10-17).
const CONDITION_MINUTES := {"frightened": 1}
const DEFAULT_CONDITION_MINUTES := 10

var _enc: WeakRef
## The fight's traps: [{id, cells: Array[Vector2i], spec: the location's trap entry, found: bool, sprung: bool}].
var list: Array[Dictionary] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## A location trap (its entry from the location's data) armed for this fight.
func add(spec: Dictionary, found: bool = false) -> void:
	var cells: Array[Vector2i] = []
	for c: Variant in spec.get("cells", []):
		cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
	list.append({"id": str(spec.get("id", "")), "cells": cells, "spec": spec, "found": found, "sprung": false})


## The trap on `cell` that hasn't gone off, or {}.
func armed_at(cell: Vector2i) -> Dictionary:
	for t in list:
		if not bool(t["sprung"]) and cell in (t["cells"] as Array):
			return t
	return {}


## The ids of the traps that went off in this fight.
func sprung_ids() -> Array[String]:
	var out: Array[String] = []
	for t in list:
		if bool(t["sprung"]):
			out.append(str(t["id"]))
	return out


## `c` has just moved onto a square (EncounterMovement._after_step): any armed trap under it goes off.
func stepped(c: Combatant) -> void:
	if not c.is_alive() or c.altitude > 0:
		return   # a flyer passes over
	for cell in c.footprint():
		var t := armed_at(cell)
		if not t.is_empty():
			spring(t, c)
			return


## Springs trap `t` on `victim`: its save, then damage and condition, or a pit's drop.
func spring(t: Dictionary, victim: Combatant) -> void:
	var e := enc()
	t["sprung"] = true
	var spec := t["spec"] as Dictionary
	var label := str(spec.get("label", "a trap"))
	e.log.add("info", "%s sets off %s" % [victim.name(), label], victim.id)
	e.events.append({"type": "trap", "id": victim.id, "trap": str(t["id"]), "cells": (t["cells"] as Array).duplicate()})
	var save := spec.get("save", {}) as Dictionary
	var success := false
	var lines: Array[String] = []
	if not save.is_empty():
		var ability := StringName(str(save.get("ability", "dex")))
		var test := victim.creature.roll_save(e.dice, ability, int(save.get("dc", 10)), [], [],
			"%s save vs %s (%s)" % [Creature.ABILITY_NAMES.get(ability, "Dexterity"), label, victim.name()])
		success = test.success
		lines.append(test.describe())
	var pit := int(spec.get("pit_ft", 0))
	if pit > 0:
		if success:
			e.log.add("info", "%s catches the edge of %s" % [victim.name(), label], victim.id, lines)
			return
		# A pit whose own damage is bludgeoning (an oubliette) already counts the fall; stakes add to it.
		var own_fall := str(spec.get("damage_type", "")) == "bludgeoning" and str(spec.get("damage", "")) != ""
		if not own_fall:
			e.fall(victim, pit, label)
		_damage(victim, spec, false, lines)
		if victim.is_alive() and not victim.creature.has_condition(&"prone"):
			victim.creature.add_condition(&"prone", label)
			e.events.append({"type": "condition", "id": victim.id})
		return
	_damage(victim, spec, success, lines)
	if str(spec.get("condition", "")) != "" and not success and victim.is_alive():
		give_condition(victim.creature, spec, victim.id)
		e.events.append({"type": "condition", "id": victim.id})


## Gives `creature` the condition trap entry `spec` names (its `condition`, for `condition_minutes`): a lasting effect
## that runs out with the clock, in a fight too (`owner_id`: whose turns count its rounds there), not a condition nothing
## ever takes off. Prone is the exception, a state and not a duration: in a fight the creature spends movement to stand,
## outside one the party stands up (LocationCare.stand_up). True if it took hold (an immunity can stop it).
static func give_condition(creature: Creature, spec: Dictionary, owner_id: String = "") -> bool:
	var cond := StringName(str(spec.get("condition", "")))
	var label := str(spec.get("label", "a trap"))
	if cond == &"" or cond == &"prone":
		return cond != &"" and creature.add_condition(cond, label)
	var fx := Effect.new(label.left(1).to_upper() + label.substr(1), &"trap", str(spec.get("id", "")))
	fx.conditions.append(cond)
	fx.ends = Effect.Ends.MINUTES
	fx.minutes_left = maxi(1, int(spec.get("condition_minutes", int(CONDITION_MINUTES.get(str(cond), DEFAULT_CONDITION_MINUTES)))))
	fx.turn_owner_id = owner_id
	return creature.add_effect(fx)


func _damage(victim: Combatant, spec: Dictionary, halved: bool, lines: Array[String]) -> void:
	var e := enc()
	if str(spec.get("damage", "")) == "":
		if not lines.is_empty():
			e.log.add("info", "%s %s" % [victim.name(), "avoids it" if halved else "is caught"], victim.id, lines)
		return
	var label := str(spec.get("label", "a trap"))
	var rolled := e._roll_damage_dice(str(spec["damage"]), false, 0, "Trap: %s" % label)
	var amount := int(rolled["total"])
	if halved:
		amount /= 2
	lines.append(str(rolled["text"]))
	if amount > 0:
		e.deal_damage(null, victim, [{"amount": amount, "type": str(spec.get("damage_type", "bludgeoning"))}], false, label, lines)


func to_dict() -> Dictionary:
	var out: Array = []
	for t in list:
		out.append({"spec": t["spec"], "found": t["found"], "sprung": t["sprung"]})
	return {"list": out}


func from_dict(d: Dictionary) -> void:
	list.clear()
	for v: Variant in d.get("list", []):
		var td := v as Dictionary
		add(td.get("spec", {}) as Dictionary, bool(td.get("found", false)))
		list[list.size() - 1]["sprung"] = bool(td.get("sprung", false))
