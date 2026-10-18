class_name Treasure
extends RefCounted
## Random magic items in the world (ADR 0012): each location's containers get a few magic items chosen for the party's
## level there (data/treasure/levels.json, after the 2024 DMG's treasure guidance), different in every playthrough.
## They're rolled the first time the location is entered, from the playthrough's seed, and kept in its saved state, so
## a save always holds the same treasure. Curse of Strahd's own fixed treasures and the Tarokka's stay where the story
## put them. Generic scrolls ("a level 1 spell scroll") become a particular spell here too. Each lasting item turns up
## once (Ashwin, 2026-10-17): a roll never gives a kind of item the story places, or one already rolled or carried
## (taken_kinds), and items with no use in a fight come up a quarter as often (levels.json `support_items`).

const PATH := "res://data/treasure/levels.json"
const THEMES: Array[String] = ["arcana", "armaments", "implements", "relics"]

static var _cfg: Dictionary = {}
## rarity -> theme -> [{id, weight}] built once from the magic item data.
static var _pools: Dictionary = {}
## Kinds of item the story places for good (placed_kinds): kind -> true, built once.
static var _placed: Dictionary = {}
static var _placed_built := false


static func config() -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed as Dictionary if parsed is Dictionary else {}
	return _cfg


## Forget the cached tables (tests that add items).
static func reset() -> void:
	_cfg = {}
	_pools = {}
	_placed = {}
	_placed_built = false


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
	for d in Compendium.shared().all_playable("magic_items"):
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
	var support := config().get("support_items", []) as Array
	var support_weight := float(config().get("support_weight", 1.0))
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
			if str(id) in support:
				w *= support_weight
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


## One random magic item for a party of `level`: {id, qty, ...its own state}; both of a pair. Never one of the `taken`
## kinds (taken_kinds), so each lasting item turns up once; {} when nothing of the rarity is left.
static func roll_item(rng: DiceRoller, level: int, taken: Dictionary = {}) -> Dictionary:
	var weights := rarity_weights(level)
	var rchoices: Array = []
	for r: String in weights:
		rchoices.append({"r": r, "weight": float(weights[r])})
	var rarity := str(_weighted(rng, rchoices, "Treasure rarity").get("r", "uncommon"))
	var by_theme := _untaken(pools().get(rarity, {}) as Dictionary, taken)
	# Each kind of item (theme) gets an even share, except one with only a handful of items to give: its share shrinks
	# with its pool (theme_full_weight), so none of them turns up in one roll in five (owner, 2026-10-12: the Amulet of
	# Proof against Detection and Location was 3 of every 4 uncommon relics).
	var full := float(config().get("theme_full_weight", 8.0))
	var themes: Array = []
	for th: String in THEMES:
		var pool := by_theme.get(th, []) as Array
		if not pool.is_empty():
			var total := 0.0
			for it: Variant in pool:
				total += float((it as Dictionary)["weight"])
			themes.append({"t": th, "weight": minf(1.0, total / full)})
	if themes.is_empty():
		return {}
	var theme := str(_weighted(rng, themes, "Treasure theme")["t"])
	var pick := str(_weighted(rng, by_theme[theme] as Array, "Treasure item").get("id", ""))
	if pick == "spell_scroll":
		return {"id": _scroll_for_rarity(rng, rarity), "qty": 1}
	var data := Compendium.shared().item_data(pick)
	var id := pick
	if MagicItems.is_template(data):
		var bases := Compendium.shared().template_bases(pick).filter(func(b: String) -> bool:
			return not taken.has(kind_of("%s%s%s" % [pick, MagicItems.SEP, b])))
		if bases.is_empty():
			return {}
		id = "%s%s%s" % [pick, MagicItems.SEP, bases[rng.roll_one(bases.size(), "Treasure base") - 1]]
		data = Compendium.shared().item_data(id)
	var out := {"id": id, "qty": 2 if bool(data.get("pair", false)) else 1}   # a pair comes whole (Boon Companions' Bands)
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
		var taken := taken_kinds(st)
		for i in n:
			var it := roll_item(rng, level, taken)
			if it.is_empty():
				continue
			_add_kind(taken, str(it["id"]))
			var cid := containers[rng.roll_one(containers.size(), "Treasure container") - 1]
			if not out.has(cid):
				out[cid] = []
			(out[cid] as Array).append(it)
		# And potions (owner, 2026-10-12: more of them): a healing potion for the place's tier, or any potion.
		var pp := config().get("potions_per_location", {}) as Dictionary
		var proll := rng.roll_one(100, "Treasure potions")
		var np := 0 if proll <= int(pp.get("none", 100)) else (1 if proll <= int(pp.get("none", 100)) + int(pp.get("one", 0)) else 2)
		for i in np:
			var pot := roll_potion(rng, level, int(pp.get("healing", 60)))
			if pot.is_empty():
				continue
			var pcid := containers[rng.roll_one(containers.size(), "Treasure container") - 1]
			if not out.has(pcid):
				out[pcid] = []
			(out[pcid] as Array).append(pot)
	ls["treasure"] = out
	return out


## `by_theme` (theme -> [{id, weight}]) without the entries whose kind is `taken`. An item made on a base stays while
## any of its bases is free (roll_item picks among those).
static func _untaken(by_theme: Dictionary, taken: Dictionary) -> Dictionary:
	if taken.is_empty():
		return by_theme
	var out := {}
	for th: String in by_theme:
		out[th] = (by_theme[th] as Array).filter(func(e: Dictionary) -> bool: return _free(str(e["id"]), taken))
	return out


static func _free(id: String, taken: Dictionary) -> bool:
	if id == "spell_scroll":
		return true
	var data := Compendium.shared().item_data(id)
	if MagicItems.is_template(data) and str(data.get("variant_of", "")) in (config().get("kind_by_base", []) as Array):
		return Compendium.shared().template_bases(id).any(func(b: String) -> bool:
			return not taken.has(kind_of("%s%s%s" % [id, MagicItems.SEP, b])))
	return not taken.has(kind_of(id))


## An item's kind, for keeping lasting treasure distinct (Ashwin, 2026-10-17; levels.json `_distinct_note`): a +1, +2
## or +3 of one item, or variants that work the same way (Belt of Giant Strength, Ring of Resistance, Bag of Tricks),
## are one kind, except the `distinct_variants` (each Ioun Stone, each Figurine); a plain +N weapon, armor or shield
## counts by its base ("weapon_plus:longsword"); any other item made on a base by its template ("flame_tongue"). "" for
## what can repeat: anything mundane or consumable (potions, scrolls, ammunition, oils and dusts).
static func kind_of(id: String) -> String:
	if id == "":
		return ""
	var comp := Compendium.shared()
	var data := comp.item_data(id)
	if data.is_empty() or not MagicItems.is_magic(data) or MagicItems.is_consumable(data):
		return ""
	if str(data.get("category", "")) in ["ammunition", "potion", "scroll"]:
		return ""
	var tid := id.get_slice(MagicItems.SEP, 0)
	var tdata := comp.item_data(tid) if tid != id else data
	var group := str(tdata.get("variant_of", tid))
	if group in (config().get("distinct_variants", []) as Array):
		group = tid
	if group in (config().get("kind_by_base", []) as Array):
		var base := id.get_slice(MagicItems.SEP, 1) if id.contains(MagicItems.SEP) else \
			str((tdata.get("template", {}) as Dictionary).get("default", ""))
		return "%s:%s" % [group, base]
	return group


static func _add_kind(kinds: Dictionary, id: String) -> void:
	var k := kind_of(id)
	if k != "":
		kinds[k] = true


## The kinds of item the story places for good: every location's search finds, check rewards and containers, and
## every dialogue's `give` (gifts, rewards, hoards handed over). Built once.
static func placed_kinds() -> Dictionary:
	if _placed_built:
		return _placed
	_placed_built = true
	for loc: Dictionary in Compendium.shared().all("locations"):
		if not str(loc["id"]).begins_with("test_"):
			_collect_location_items(loc, _placed)
	for path in _dialogue_paths(DialogueFile.ROOT):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var l := line.strip_edges()
			if l.begins_with("give "):
				_add_kind(_placed, l.get_slice(" ", 1))
	return _placed


## Every item a location's data hands out: a prop's `item`, and the `items` of its containers and checks.
static func _collect_location_items(v: Variant, kinds: Dictionary) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		if d.get("item", null) is String:
			_add_kind(kinds, str(d["item"]))
		for k: Variant in d:
			if str(k) == "items" and d[k] is Array:
				for it: Variant in d[k]:
					if it is Dictionary:
						_add_kind(kinds, str((it as Dictionary).get("id", "")))
			elif d[k] is Dictionary or d[k] is Array:
				_collect_location_items(d[k], kinds)
	elif v is Array:
		for e: Variant in v:
			_collect_location_items(e, kinds)


static func _dialogue_paths(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".dialogue"):
			out.append(dir.path_join(f))
	for sub in da.get_directories():
		out.append_array(_dialogue_paths(dir.path_join(sub)))
	return out


## The kinds random treasure won't roll this playthrough: what the story places, what's already been rolled into a
## place's chests, and what the party carries or keeps in the stash (a road's find among them).
static func taken_kinds(st: StoryState) -> Dictionary:
	var out := placed_kinds().duplicate()
	if st == null:
		return out
	for loc_id: Variant in st.location_states:
		var tr := (st.location_states[loc_id] as Dictionary).get("treasure", {}) as Dictionary
		for items: Variant in tr.values():
			for it: Variant in items:
				_add_kind(out, str((it as Dictionary).get("id", "")))
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			_add_kind(out, str(e.get("id", "")))
	for e2: Dictionary in st.stash:
		_add_kind(out, str(e2.get("id", "")))
	return out


## A potion for a place of `level`: `healing` percent of the time a healing potion of the party's tier
## (RoadSpoils.POTIONS), else any potion off the random tables at a rarity for the level.
static func roll_potion(rng: DiceRoller, level: int, healing: int) -> Dictionary:
	if rng.roll_one(100, "Treasure potion: healing") <= healing:
		for p: Array in RoadSpoils.POTIONS:
			if level <= int(p[0]):
				return {"id": str(p[1]), "qty": 1}
	var weights := rarity_weights(level)
	var rchoices: Array = []
	for r: String in weights:
		rchoices.append({"r": r, "weight": float(weights[r])})
	var rarity := str(_weighted(rng, rchoices, "Treasure potion rarity").get("r", "uncommon"))
	var choices: Array = []
	for th: String in THEMES:
		for it: Variant in (pools().get(rarity, {}) as Dictionary).get(th, []):
			var id := str((it as Dictionary)["id"])
			if str(Compendium.shared().item_data(id).get("category", "")) == "potion":
				choices.append({"id": id, "weight": float((it as Dictionary)["weight"])})
	if choices.is_empty():
		return {}
	var id2 := str(_weighted(rng, choices, "Treasure potion").get("id", ""))
	var out := {"id": id2, "qty": 1}
	out.merge(MagicItems.init_state(Compendium.shared().item_data(id2), rng, Compendium.shared()))
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


