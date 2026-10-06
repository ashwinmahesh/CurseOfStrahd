class_name Compendium
extends RefCounted
## Every rules data file (data/<folder>/*.json), loaded once and looked up by id (ADR 0005). The engine
## reads content only through here, so a new subclass, feat or spell is a data file, never new code.

const FOLDERS: Array[String] = ["classes", "subclasses", "species", "backgrounds", "feats", "spells", "items",
	"monsters", "conditions", "pregens", "encounters", "locations", "npcs", "quests", "tarokka", "travel",
	"random_encounters", "magic_items", "dark_gifts"]

static var _shared: Compendium = null

var root: String = ""
## folder -> {id: Dictionary}
var tables: Dictionary = {}
## Magic items built on a base weapon or armor, by id (filled on first use).
var _variants: Dictionary = {}


## The game's compendium, loaded from res://data on first use.
static func shared() -> Compendium:
	if _shared == null:
		_shared = Compendium.new()
		_shared.load_all("res://data")
	return _shared


## Drops the shared compendium (tests and shutdown), so nothing outlives the scene tree.
static func release() -> void:
	_shared = null


func load_all(root_path: String) -> void:
	root = root_path
	for folder in FOLDERS:
		var table := {}
		var dir := DirAccess.open(root_path.path_join(folder))
		if dir != null:
			var files := dir.get_files()
			files.sort()
			for f in files:
				if not f.ends_with(".json"):
					continue
				var text := FileAccess.get_file_as_string(root_path.path_join(folder).path_join(f))
				var parsed: Variant = JSON.parse_string(text)
				if parsed is Dictionary:
					var entry := parsed as Dictionary
					table[str(entry.get("id", f.get_basename()))] = entry
				else:
					push_error("Compendium: %s/%s is not a JSON object" % [folder, f])
		tables[folder] = table
	_register_item_recipes()


## Magic items' own powers that work like spells (a Wand of Paralysis's ray, a Necklace of Fireballs' bead) are
## spell recipes inside the item (`recipes`); they're looked up as spells by "<item id>__<recipe>" (ADR 0012).
func _register_item_recipes() -> void:
	var recipes := {}
	var all_items: Array = table("magic_items").values()
	all_items.append_array(table("items").values())
	for item: Variant in all_items:
		var d := item as Dictionary
		var rs := MagicItems.recipes_of(d)
		for key: String in rs:
			var r := (rs[key] as Dictionary).duplicate(true)
			r["id"] = "%s__%s" % [d["id"], key]
			if not r.has("name"):
				r["name"] = str(d.get("name", ""))
			if not r.has("level"):
				r["level"] = 0
			r["item"] = str(d["id"])
			recipes[str(r["id"])] = r
	tables["item_spells"] = recipes
	_variants.clear()


func table(folder: String) -> Dictionary:
	return tables.get(folder, {}) as Dictionary


func has(folder: String, id: String) -> bool:
	return table(folder).has(id)


func get_entry(folder: String, id: String) -> Dictionary:
	return table(folder).get(id, {}) as Dictionary


## All entries of a folder, sorted by name.
func all(folder: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in table(folder).values():
		out.append(v as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return out


func class_data(id: String) -> Dictionary:
	return get_entry("classes", id)


func subclass_data(id: String) -> Dictionary:
	return get_entry("subclasses", id)


func species_data(id: String) -> Dictionary:
	return get_entry("species", id)


func background_data(id: String) -> Dictionary:
	return get_entry("backgrounds", id)


func feat_data(id: String) -> Dictionary:
	return get_entry("feats", id)


## A spell, or an item power written as a spell recipe (`<item id>__<recipe>`).
func spell_data(id: String) -> Dictionary:
	var d := get_entry("spells", id)
	return d if not d.is_empty() else get_entry("item_spells", id)


## An item: mundane gear (data/items), a magic item (data/magic_items), or a magic item built on a base weapon or
## armor ("weapon_plus_1__longsword", MagicItems.combine).
func item_data(id: String) -> Dictionary:
	var d := get_entry("items", id)
	if not d.is_empty():
		return d
	d = get_entry("magic_items", id)
	if not d.is_empty() or not id.contains(MagicItems.SEP):
		return d
	return variant(id)


## "<template>__<base>" built on first use; {} if the base can't carry the template.
func variant(id: String) -> Dictionary:
	if _variants.has(id):
		return _variants[id] as Dictionary
	var t := get_entry("magic_items", id.get_slice(MagicItems.SEP, 0))
	var out := {}
	if str((t.get("template", {}) as Dictionary).get("on", "")) == "spell":
		var sp := get_entry("spells", id.get_slice(MagicItems.SEP, 1))
		if not sp.is_empty():
			out = MagicItems.combine_scroll(t, sp, id)
		_variants[id] = out
		return out
	var b := get_entry("items", id.get_slice(MagicItems.SEP, 1))
	if not t.is_empty() and not b.is_empty() and MagicItems.template_fits(t, b):
		out = MagicItems.combine(t, b, id)
	_variants[id] = out
	return out


## Every mundane item a template can sit on.
func template_bases(template_id: String) -> Array[String]:
	return MagicItems.bases_for(get_entry("magic_items", template_id), all("items"))


func monster_data(id: String) -> Dictionary:
	return get_entry("monsters", id)


func condition_data(id: String) -> Dictionary:
	return get_entry("conditions", id)


func subclasses_of(class_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in all("subclasses"):
		if str(s.get("class", "")) == class_id:
			out.append(s)
	return out


## Spells on a class's list (`list` = class id). level -1 = any level.
func spells_for(list: String, level: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in all("spells"):
		if level >= 0 and int(s.get("level", -1)) != level:
			continue
		if list != "" and not list in (s.get("classes", []) as Array):
			continue
		out.append(s)
	return out


func feats_in(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in all("feats"):
		if category == "" or str(f.get("category", "")) == category:
			out.append(f)
	return out


func items_where(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in all("items"):
		if str(i.get("category", "")) == category:
			out.append(i)
	return out


func display_name(folder: String, id: String) -> String:
	var e := get_entry(folder, id)
	if e.is_empty() and folder == "items":
		e = item_data(id)
	return str(e.get("name", id.capitalize()))
