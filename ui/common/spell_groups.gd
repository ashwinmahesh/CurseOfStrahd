class_name SpellGroups
extends RefCounted
## The one order every spell list uses (owner, 2026-10-07): grouped by spell level, cantrips first, each level under
## its own heading, and alphabetical within a level. Choice lists (creation, level up, preparing, feat picks such as
## Fey Touched), the character sheet, a found spellbook and the combat Spells tab all go through here.


static func level_of(spell_id: String) -> int:
	return int(Compendium.shared().spell_data(spell_id).get("level", 0))


static func name_of(spell_id: String) -> String:
	return str(Compendium.shared().spell_data(spell_id).get("name", spell_id))


## "Cantrips", "Level 1" ... the heading over a level's spells.
static func heading(level: int) -> String:
	return "Cantrips" if level == 0 else "Level %d" % level


## `items` grouped: [{level, heading, items}], levels ascending, each group's items by name. `id_of(item)` gives an
## item's spell id (the items themselves when they're ids); `level_of_item` overrides the spell's own level (a spell
## cast with a higher slot sits under that slot's level in a fight).
static func groups(items: Array, id_of: Callable = Callable(), level_of_item: Callable = Callable()) -> Array[Dictionary]:
	var by_level := {}
	for it: Variant in items:
		var id := str(id_of.call(it)) if id_of.is_valid() else str(it)
		var lv := int(level_of_item.call(it)) if level_of_item.is_valid() else level_of(id)
		if not by_level.has(lv):
			by_level[lv] = []
		(by_level[lv] as Array).append([name_of(id).to_lower(), it])
	var levels: Array = by_level.keys()
	levels.sort()
	var out: Array[Dictionary] = []
	for lv: int in levels:
		var pairs := by_level[lv] as Array
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
		out.append({"level": lv, "heading": heading(lv), "items": pairs.map(func(p: Array) -> Variant: return p[1])})
	return out


## The same items flattened back into that order.
static func sorted(items: Array, id_of: Callable = Callable(), level_of_item: Callable = Callable()) -> Array:
	var out: Array = []
	for g in groups(items, id_of, level_of_item):
		out.append_array(g["items"] as Array)
	return out
