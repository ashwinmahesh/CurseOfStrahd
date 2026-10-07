class_name SkirmishLibrary
extends RefCounted
## Saved Skirmish setups (N1) and fights from the encounter editor (N9): one JSON file each in user://skirmish/,
## named after the setup's title. Separate from the story's saves, so neither list sees the other.

static var dir := "user://skirmish/"


## Every saved setup, newest first: {file, title, map, saved_at, heroes, foes}.
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if not f.ends_with(".json"):
			continue
		var d := _read(dir.path_join(f))
		if d.is_empty():
			continue
		out.append({"file": f.get_basename(), "title": str(d.get("title", f.get_basename())), "map": str(d.get("map", "")),
			"saved_at": str(d.get("saved_at", "")), "heroes": (d.get("party", []) as Array).size(),
			"foes": (d.get("foes", []) as Array).size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["saved_at"]) > str(b["saved_at"]))
	return out


## Saves `setup` under its title (replacing a setup of the same name). Returns the file name it went to.
static func save(setup: SkirmishSetup) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := file_for(setup.title)
	var d := setup.to_dict()
	d["saved_at"] = Time.get_datetime_string_from_system()
	var fa := FileAccess.open(dir.path_join(file + ".json"), FileAccess.WRITE)
	if fa == null:
		return ""
	fa.store_string(JSON.stringify(d, "\t"))
	fa.close()
	return file


static func load_setup(file: String) -> SkirmishSetup:
	var d := _read(dir.path_join(file + ".json"))
	return null if d.is_empty() else SkirmishSetup.from_dict(d)


static func delete(file: String) -> void:
	DirAccess.remove_absolute(dir.path_join(file + ".json"))


static func has(title: String) -> bool:
	return FileAccess.file_exists(dir.path_join(file_for(title) + ".json"))


## A file name from a title: letters, digits and underscores ("Wolves at night" -> "wolves_at_night").
static func file_for(title: String) -> String:
	var out := ""
	for ch in title.strip_edges().to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return out if out != "" else "skirmish"


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
