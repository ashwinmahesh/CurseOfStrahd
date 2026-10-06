class_name Concentration
extends RefCounted
## A caster's Concentration on one spell or effect, plus every Effect it keeps alive on any creature
## (2024 PHB glossary "Concentration"). Ending it removes those effects. Targets are held weakly so a
## dead or freed creature doesn't stay alive through this link.

var source_id: String
var name: String
var _caster: WeakRef
var _links: Array[Dictionary] = []   ## {creature: WeakRef, effect: Effect}
var ended: bool = false


func _init(caster: Creature, source_id_: String, name_: String) -> void:
	_caster = weakref(caster)
	source_id = source_id_
	name = name_


func caster() -> Creature:
	return _caster.get_ref() as Creature


## Puts `effect` on `target` and ties it to this Concentration.
func attach(target: Creature, effect: Effect) -> bool:
	effect.concentration = self
	var c := caster()
	if c != null and effect.caster_id == "":
		effect.caster_id = c.id
	if not target.add_effect(effect):
		return false
	_links.append({"creature": weakref(target), "effect": effect})
	return true


## Restores a link after loading a save (the effect is already on the target).
func relink(target: Creature, effect: Effect) -> void:
	effect.concentration = self
	_links.append({"creature": weakref(target), "effect": effect})


func effect_count() -> int:
	return _links.size()


## Ends Concentration: every linked effect is removed from its creature.
func end(reason: String = "") -> void:
	if ended:
		return
	ended = true
	for link in _links:
		var target := (link["creature"] as WeakRef).get_ref() as Creature
		if target != null:
			target.remove_effect(link["effect"] as Effect)
	_links.clear()
	var c := caster()
	if c != null and c.concentration == self:
		c.concentration = null
		c.log_event({"type": "concentration_ended", "creature": c.id, "source": source_id, "reason": reason})


## Concentration save DC after taking damage: 10 or half the damage (round down), whichever is higher,
## up to 30.
static func save_dc(damage: int) -> int:
	return mini(30, maxi(10, floori(damage / 2.0)))
