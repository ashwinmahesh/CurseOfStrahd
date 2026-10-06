class_name Treasure
extends RefCounted
## Random magic items in the world (ADR 0012): each location's containers get a few magic items chosen for the party's
## level there (data/treasure/levels.json, after the 2024 DMG's treasure guidance), different in every playthrough.
## They're rolled the first time the location is entered, from the playthrough's seed, and kept in its saved state, so
## a save always holds the same treasure. Curse of Strahd's own fixed treasures and the Tarokka's stay where the story
## put them. Generic scrolls ("a level 1 spell scroll") become a particular spell here too.

const PATH := "res://data/treasure/levels.json"
const THEMES: Array[String] = ["arcana", "armaments", "implements", "relics"]

static var _cfg: Dictionary = {}
## rarity -> theme -> [{id, weight}] built once from the magic item data.
static var _pools: Dictionary = {}


static func config() -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed as Dictionary if parsed is Dictionary else {}
	return _cfg


## Forget the cached tables (tests that add items).
static func reset() -> void:
	_cfg = {}
	_pools = {}


## The party level a location's treasure is chosen for.
static func level_for(loc_id: String) -> int:
	var loc := Compendium.shared().get_entry("locations", loc_id)
	if loc.has("treasure_level"):
		return int(loc["treasure_level"])
	var levels := config().get("region_levels", {}) as Dictionary
	return int(levels.get(str(loc.get("region", "")), 5))


## Rarity weights for a party level.
static func rarity_weights(level: int) -> Dictionary:
	for band: Variant in config().get("rarity_by_level", []):
		var b := band as Dictionary
		if level <= int(b.get("max_level", 20)):
			return b.get("weights", {}) as Dictionary
	return {"uncommon": 1}


static func theme_of(item: Dictionary) -> String:
	if item.has("theme"):
		return str(item["theme"])
	match str(item.get("category", "")):
		"weapon", "armor", "shield", "ammunition":
			return "armaments"
		"ring", "rod", "staff", "wand", "scroll":
			return "arcana"
	return "implements"


## Items that can be rolled: magic items not marked off the random tables, not artifacts, not story items. One entry per
## `variant_of` group (a Ring of Resistance is one roll, then its damage type).
static func pools() -> Dictionary:
	if not _pools.is_empty():
		return _pools
	var groups := {}
	for d in Compendium.shared().all("magic_items"):
		var id := str(d["id"])
		if not MagicItems.is_magic(d) or bool(d.get("quest_locked", false)) or str(d.get("category", "")) == "quest":
			continue
		if not bool((d.get("treasure", {}) as Dictionary).get("random", true)) or MagicItems.rarity(d) == "artifact":
			continue
		if str((d.get("source", {}) as Dictionary).get("book", "")) == "CoS":
			continue
		var key := str(d.get("variant_of", id))
		if not groups.has(key):
			groups[key] = {"ids": [], "rarity": MagicItems.rarity(d), "theme": theme_of(d), "category": str(d.get("category", ""))}
		(groups[key]["ids"] as Array).append(id)
	var gw := config().get("group_weights", {}) as Dictionary
	for key: String in groups:
		var g := groups[key] as Dictionary
		for id: Variant in g["ids"]:
			# A variant group rolls at each member's own rarity (Potions of Giant Strength run uncommon to legendary).
			var d2 := Compendium.shared().item_data(str(id))
			var r := MagicItems.rarity(d2)
			if not _pools.has(r):
				_pools[r] = {}
			var by_theme := _pools[r] as Dictionary
			var th := theme_of(d2)
			if not by_theme.has(th):
				by_theme[th] = []
			var w := float(gw.get(str(g["category"]), 1.0)) / float((g["ids"] as Array).size())
			(by_theme[th] as Array).append({"id": str(id), "weight": w})
	# Spell Scrolls: one entry per rarity, the spell picked when it's rolled.
	for r2: String in ["common", "uncommon", "rare", "very_rare", "legendary"]:
		if not _pools.has(r2):
			_pools[r2] = {}
		var bt := _pools[r2] as Dictionary
		if not bt.has("arcana"):
			bt["arcana"] = []
		(bt["arcana"] as Array).append({"id": "spell_scroll", "weight": float(gw.get("spell_scroll", 1.0))})
	return _pools


static func _weighted(rng: DiceRoller, choices: Array, label: String) -> Dictionary:
	var total := 0.0
	for c: Variant in choices:
		total += float((c as Dictionary).get("weight", 1.0))
	if total <= 0.0:
		return {}
	var roll := float(rng.roll_one(10000, label)) / 10000.0 * total
	for c2: Variant in choices:
		roll -= float((c2 as Dictionary).get("weight", 1.0))
		if roll <= 0.0:
			return c2 as Dictionary
	return choices.back() as Dictionary


## One random magic item for a party of `level`: {id, qty, ...its own state}.
static func roll_item(rng: DiceRoller, level: int) -> Dictionary:
	var weights := rarity_weights(level)
	var rchoices: Array = []
	for r: String in weights:
		rchoices.append({"r": r, "weight": float(weights[r])})
	var rarity := str(_weighted(rng, rchoices, "Treasure rarity").get("r", "uncommon"))
	var by_theme := pools().get(rarity, {}) as Dictionary
	var themes: Array = []
	for th: String in THEMES:
		if not (by_theme.get(th, []) as Array).is_empty():
			themes.append({"t": th, "weight": 1.0})
	if themes.is_empty():
		return {}
	var theme := str(_weighted(rng, themes, "Treasure theme")["t"])
	var pick := str(_weighted(rng, by_theme[theme] as Array, "Treasure item").get("id", ""))
	if pick == "spell_scroll":
		return {"id": _scroll_for_rarity(rng, rarity), "qty": 1}
	var data := Compendium.shared().item_data(pick)
	var id := pick
	if MagicItems.is_template(data):
		var bases := Compendium.shared().template_bases(pick)
		if bases.is_empty():
			return {}
		id = "%s%s%s" % [pick, MagicItems.SEP, bases[rng.roll_one(bases.size(), "Treasure base") - 1]]
		data = Compendium.shared().item_data(id)
	var out := {"id": id, "qty": 1}
	if bool(data.get("stackable", false)):
		if str(data.get("category", "")) == "ammunition":
			out["qty"] = rng.roll_one(10, "Ammunition") + 2
	else:
		var st := MagicItems.init_state(data, rng, Compendium.shared())
		st["made"] = true
		out.merge(st)
	return out


## A Spell Scroll of the rarity: a spell of a matching level (cantrip or 1 common, 2-3 uncommon, 4-5 rare, 6-8 very
## rare, 9 legendary).
static func _scroll_for_rarity(rng: DiceRoller, rarity: String) -> String:
	var levels := {"common": [0, 1], "uncommon": [2, 3], "rare": [4, 5], "very_rare": [6, 7, 8], "legendary": [9]}
	var opts := levels.get(rarity, [1]) as Array
	var lvl := int(opts[rng.roll_one(opts.size(), "Scroll level") - 1])
	return scroll_of_level(rng, lvl)


static func scroll_of_level(rng: DiceRoller, lvl: int) -> String:
	return MagicItems.scroll_of_level(rng, lvl, Compendium.shared())


## The magic items placed in a location's containers this playthrough: {container id: [items]}. Rolled the first time
## and saved in the location's state.
static func placed(st: StoryState, loc_id: String) -> Dictionary:
	var ls := st.loc_state(loc_id)
	if ls.has("treasure"):
		return ls["treasure"] as Dictionary
	var out := {}
	var loc := Compendium.shared().get_entry("locations", loc_id)
	var containers: Array[String] = []
	for c: Variant in loc.get("containers", []):
		var cd := c as Dictionary
		if not bool(cd.get("no_random_loot", false)):
			containers.append(str(cd["id"]))
	if not containers.is_empty() and not bool(loc.get("no_random_loot", false)):
		var rng := DiceRoller.new(hash("%d:%s:treasure" % [st.playthrough_seed, loc_id]))
		var per := config().get("items_per_location", {}) as Dictionary
		var roll := rng.roll_one(100, "Treasure count")
		var n := 0 if roll <= int(per.get("none", 35)) else (1 if roll <= int(per.get("none", 35)) + int(per.get("one", 50)) else 2)
		if containers.size() >= int(per.get("extra_if_containers", 4)) and rng.roll_one(100, "Extra treasure") <= int(per.get("extra_chance", 30)):
			n += 1
		var level := level_for(loc_id)
		for i in n:
			var it := roll_item(rng, level)
			if it.is_empty():
				continue
			var cid := containers[rng.roll_one(containers.size(), "Treasure container") - 1]
			if not out.has(cid):
				out[cid] = []
			(out[cid] as Array).append(it)
	ls["treasure"] = out
	return out


## Replaces generic scrolls ("a level 1 spell scroll") in a list of loot with particular ones, the same each time for
## the same `key` in this playthrough.
static func specify_scrolls(items: Array, st: StoryState, key: String) -> Array:
	var out: Array = []
	var rng := DiceRoller.new(hash("%d:%s:scrolls" % [st.playthrough_seed if st != null else 0, key]))
	for it: Variant in items:
		var d := (it as Dictionary).duplicate()
		var id := str(d.get("id", ""))
		if MagicItems.GENERIC_SCROLLS.has(id):
			var qty := int(d.get("qty", 1))
			for i in qty:
				out.append({"id": scroll_of_level(rng, int(MagicItems.GENERIC_SCROLLS[id])), "qty": 1})
			continue
		out.append(d)
	return out


