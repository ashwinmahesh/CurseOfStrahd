class_name Compendium
extends RefCounted
## Every rules data file (data/<folder>/*.json), loaded once and looked up by id (ADR 0005). The engine
## reads content only through here, so a new subclass, feat or spell is a data file, never new code.

const FOLDERS: Array[String] = ["classes", "subclasses", "species", "backgrounds", "feats", "spells", "items",
	"monsters", "conditions", "pregens", "encounters", "locations", "npcs", "quests", "tarokka", "travel",
	"random_encounters"]

static var _shared: Compendium = null

var root: String = ""
## folder -> {id: Dictionary}
var tables: Dictionary = {}


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


func spell_data(id: String) -> Dictionary:
	return get_entry("spells", id)


func item_data(id: String) -> Dictionary:
	return get_entry("items", id)


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
	return str(e.get("name", id.capitalize()))
