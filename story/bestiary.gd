class_name Bestiary
extends RefCounted
## What the party has learned about the creatures it has fought (Improvement Ideas U8; the journal's Bestiary tab),
## kept in StoryState.bestiary: monster id -> {n: the order it was met in, met: the day it was first fought, where:
## that place's id, defeated: how many fell, studied: true once a Study placed it}. What the journal shows grows with
## it: meeting one gives its look and a line about it; felling one, how tough it is and how it fights; studying one,
## its defenses and traits.
## A creature studied once stays known, so later fights show its defenses from the start (Encounter.studied).


## A fight begins, new or picked up from its round's save: its creatures are met, and those the party has studied
## show their defenses from the start.
static func before_fight(st: StoryState, e: Encounter) -> void:
	for c in e.combatants:
		var id := monster_id(c)
		if id == "":
			continue
		if bool(_entry(st, id).get("studied", false)):
			e.studied[id] = true


## The fight is over: who fell, and what the party studied during it.
static func after_fight(st: StoryState, e: Encounter) -> void:
	for c in e.combatants:
		var id := monster_id(c)
		if id == "":
			continue
		var entry := _entry(st, id)
		if c.creature.dead or c.creature.hp <= 0:
			entry["defeated"] = int(entry.get("defeated", 0)) + 1
	for id: String in e.studied:
		if not Compendium.shared().monster_data(id).is_empty():
			_entry(st, id)["studied"] = true


## The monster id of a creature the party fights (not its own members, guests or summons), or "".
static func monster_id(c: Combatant) -> String:
	if c.side in [&"party", &"guest"] or not c.creature is Monster:
		return ""
	return str((c.creature as Monster).data.get("id", ""))


static func _entry(st: StoryState, id: String) -> Dictionary:
	if not st.bestiary.has(id):
		st.bestiary[id] = {"n": st.bestiary.size(), "met": st.day, "where": st.location, "defeated": 0}
	return st.bestiary[id] as Dictionary


## How much the party knows: 0 unknown, 1 met, 2 felled one (toughness and attacks), 3 studied (defenses, traits).
static func level(st: StoryState, id: String) -> int:
	if not st.bestiary.has(id):
		return 0
	var entry := st.bestiary[id] as Dictionary
	if bool(entry.get("studied", false)):
		return 3
	return 2 if int(entry.get("defeated", 0)) > 0 else 1


## The creatures met, in the order the party first fought them.
static func met(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for id: String in st.bestiary:
		if not Compendium.shared().monster_data(id).is_empty():
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return int((st.bestiary[a] as Dictionary).get("n", 0)) < int((st.bestiary[b] as Dictionary).get("n", 0)))
	return out
