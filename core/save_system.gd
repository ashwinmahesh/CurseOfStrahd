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
