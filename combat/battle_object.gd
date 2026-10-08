class_name BattleObject
extends RefCounted
## Something on the battlefield that can be attacked and broken (2024 rules glossary, Breaking Objects): a door, a
## crate, a pew, a gravestone, the chain a chandelier hangs from, the webbing holding a giant spider's prey. Its Armor
## Class comes from what it's made of and its Hit Points from its size and sturdiness (data/objects/kinds.json); like
## every object it takes no Poison or Psychic damage and fails every saving throw. At 0 Hit Points it breaks, leaving
## open floor, an open doorway or Difficult Terrain rubble. Not a FieldObject (a spell's zone or object): the
## Encounter's EncounterObjects owns these, and the scene draws them from `kind` and `cells` (world/combat/object_view.gd).

var id: String = ""
## Its kind in data/objects/kinds.json ("door_wood", "crate", "chandelier", "spider_web" ...).
var kind: String = ""
## What it's called: the kind's name ("crate"), or a location door's or prop's own label ("the den door").
var name: String = ""
var cells: Array[Vector2i] = []
var substance: String = ""
var size: String = "medium"
var resilient: bool = true
var ac: int = 15
var hp: int = 18
var hp_max: int = 18
## The grid flag it puts on its squares while it stands: CombatGrid.WALL (a door), CombatGrid.LOW (furniture, a
## crate), or 0 (it hangs overhead, or it's a web around a creature).
var blocks: int = 0
var flammable: bool = false
## The Burning condition (2024 rules glossary): 1d4 Fire damage each round until it breaks.
var burning: bool = false
## What its squares become when it breaks: "floor", "rubble" (Difficult Terrain) or "doorway".
var leaves: String = "floor"
var immune: Array[String] = []
var resist: Array[String] = []
var vulnerable: Array[String] = []
## The location door or prop it is (BattleScenery puts things right after the fight; the view hides their art).
var door_id: String = ""
var prop_id: String = ""
## The board art standing on its square (the view hides it when it breaks).
var art: String = ""
## A chandelier: it hangs over its squares and falls on whoever is below when its chain breaks ({save, dc, damage,
## type, prone}, plus a location prop's `trap` or `flag`).
var fall: Dictionary = {}
var hangs: bool = false
## A giant spider's web: the creature it holds, and the source of the effect restraining it.
var holds: String = ""
var hold_source: String = ""
## Covered in oil (2024 Oil): rounds before it dries; the next Fire damage it takes is 5 more.
var oil_rounds: int = 0
var destroyed: bool = false


## A new object of `kind_id` from the kinds table (data/objects/kinds.json).
static func make(kind_id: String, table: Dictionary) -> BattleObject:
	var o := BattleObject.new()
	var k := (table.get("kinds", {}) as Dictionary).get(kind_id, {}) as Dictionary
	o.kind = kind_id
	o.name = str(k.get("name", kind_id))
	o.substance = str(k.get("substance", ""))
	o.size = str(k.get("size", "medium"))
	o.resilient = str(k.get("resilience", "resilient")) == "resilient"
	o.ac = int(k.get("ac", (table.get("substances", {}) as Dictionary).get(o.substance, 15)))
	var hps := (table.get("hit_points", {}) as Dictionary).get(o.size, {}) as Dictionary
	o.hp_max = int(k.get("hp", hps.get("resilient" if o.resilient else "fragile", 10)))
	o.hp = o.hp_max
	o.blocks = {"wall": CombatGrid.WALL, "low": CombatGrid.LOW}.get(str(k.get("blocks", "none")), 0) as int
	o.flammable = bool(k.get("flammable", false))
	o.leaves = str(k.get("leaves", "floor"))
	o.hangs = bool(k.get("hangs", false))
	o.fall = (k.get("fall", {}) as Dictionary).duplicate()
	o.immune.assign(["poison", "psychic"])
	for ty: Variant in k.get("immune", []):
		if not str(ty) in o.immune:
			o.immune.append(str(ty))
	o.resist.assign((k.get("resist", []) as Array).map(func(x: Variant) -> String: return str(x)))
	o.vulnerable.assign((k.get("vulnerable", []) as Array).map(func(x: Variant) -> String: return str(x)))
	return o


## "the crate", or a label that already says which ("the den door", "a carved crest").
func the() -> String:
	for lead: String in ["the ", "a ", "an "]:
		if name.to_lower().begins_with(lead):
			return name
	return "the " + name


## "The crate".
func title() -> String:
	var t := the()
	return t.substr(0, 1).to_upper() + t.substr(1)


func live() -> bool:
	return not destroyed


## "AC 15 · HP 4/4", then what's happening to it.
func describe() -> Array[String]:
	var out: Array[String] = ["AC %d · HP %d/%d" % [ac, hp, hp_max]]
	if burning:
		out.append("Burning: 1d4 Fire each round")
	if oil_rounds > 0:
		out.append("Covered in oil")
	if hangs:
		out.append("Hangs overhead: only ranged attacks and spells reach its chain")
	if not vulnerable.is_empty():
		out.append("Vulnerable to %s" % ", ".join(vulnerable.map(func(x: String) -> String: return x.capitalize())))
	return out


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "name": name, "cells": cells.map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"substance": substance, "size": size, "resilient": resilient, "ac": ac, "hp": hp, "hp_max": hp_max, "blocks": blocks,
		"flammable": flammable, "burning": burning, "leaves": leaves, "immune": immune.duplicate(), "resist": resist.duplicate(),
		"vulnerable": vulnerable.duplicate(), "door_id": door_id, "prop_id": prop_id, "art": art, "fall": fall.duplicate(true),
		"hangs": hangs, "holds": holds, "hold_source": hold_source, "oil_rounds": oil_rounds, "destroyed": destroyed}


static func from_dict(d: Dictionary) -> BattleObject:
	var o := BattleObject.new()
	o.id = str(d.get("id", ""))
	o.kind = str(d.get("kind", ""))
	o.name = str(d.get("name", ""))
	for c: Variant in d.get("cells", []):
		o.cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
	o.substance = str(d.get("substance", ""))
	o.size = str(d.get("size", "medium"))
	o.resilient = bool(d.get("resilient", true))
	o.ac = int(d.get("ac", 15))
	o.hp = int(d.get("hp", 1))
	o.hp_max = int(d.get("hp_max", o.hp))
	o.blocks = int(d.get("blocks", 0))
	o.flammable = bool(d.get("flammable", false))
	o.burning = bool(d.get("burning", false))
	o.leaves = str(d.get("leaves", "floor"))
	o.immune.assign((d.get("immune", ["poison", "psychic"]) as Array).map(func(x: Variant) -> String: return str(x)))
	o.resist.assign((d.get("resist", []) as Array).map(func(x: Variant) -> String: return str(x)))
	o.vulnerable.assign((d.get("vulnerable", []) as Array).map(func(x: Variant) -> String: return str(x)))
	o.door_id = str(d.get("door_id", ""))
	o.prop_id = str(d.get("prop_id", ""))
	o.art = str(d.get("art", ""))
	o.fall = (d.get("fall", {}) as Dictionary).duplicate(true)
	o.hangs = bool(d.get("hangs", false))
	o.holds = str(d.get("holds", ""))
	o.hold_source = str(d.get("hold_source", ""))
	o.oil_rounds = int(d.get("oil_rounds", 0))
	o.destroyed = bool(d.get("destroyed", false))
	return o
