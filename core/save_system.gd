extends Node
## Writes GameState to one JSON file per slot. Saves are allowed anywhere outside combat
## (plan §10 Phase 3); the mode check lives here so every caller gets it.

var save_dir := "user://saves/"


func can_save() -> bool:
	return ModeController.mode != ModeController.Mode.COMBAT


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func save(slot: String) -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	EventBus.game_saved.emit(slot)
	return OK


func load_slot(slot: String) -> Error:
	if not FileAccess.file_exists(slot_path(slot)):
		return ERR_FILE_NOT_FOUND
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	var dict := data as Dictionary
	if int(dict.get("version", 0)) > GameState.SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	GameState.from_dict(dict)
	EventBus.game_loaded.emit(slot)
	return OK


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Every save on disk, newest first: [{slot, saved_at, location, day, party}].
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_dir.path_join(f)))
		if not data is Dictionary:
			continue
		var d := data as Dictionary
		var story := d.get("story", {}) as Dictionary
		var names: Array[String] = []
		for m: Variant in story.get("party", []):
			names.append(str(((m as Dictionary).get("build", {}) as Dictionary).get("name", "?")))
		var loc := Compendium.shared().get_entry("locations", str(story.get("location", "")))
		out.append({"slot": f.get_basename(), "saved_at": str(d.get("saved_at", "")), "location": str(loc.get("name", story.get("location", ""))),
			"day": int(story.get("day", 1)), "party": ", ".join(names)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["saved_at"]) > str(b["saved_at"]))
	return out


func delete_slot(slot: String) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(slot_path(slot))

