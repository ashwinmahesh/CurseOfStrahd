extends Node
## Writes GameState to one JSON file per slot. Saves are allowed anywhere outside combat
## (plan §10 Phase 3); the mode check lives here so every caller gets it.

var save_dir := "user://saves/"
## The game's own save slot: the one it was last loaded from or saved to. Quicksave (F5) writes here; a new game
## starts with none, and its first quicksave makes one.
var current_slot := ""


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
	current_slot = slot
	EventBus.game_saved.emit(slot)
	return OK


## Quicksave (F5, the pause menu): over the game's current slot, or a new slot the first time.
func quick_save() -> Error:
	var slot := current_slot if current_slot != "" else "save_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	return save(slot)


## The fight's round-start save (plan §10 Phase 3): allowed in combat, written only by the game at the start of
## a round, when GameState.combat_snapshot holds the fight.
func save_round(slot: String = "round_start") -> Error:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	return OK


## The campaign's end (ADR 0014): the game's own slot (a new one if it has none) is written one last time, marked
## finished with the ending reached. Finished saves list last and show the ending instead of the place.
func save_finished(ending_id: String, title: String) -> Error:
	var slot := current_slot if current_slot != "" and current_slot != "round_start" \
		else "save_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data := GameState.to_dict()
	data["finished"] = {"ending": ending_id, "title": title}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	current_slot = slot
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
	# The fight's round-start save isn't the game's slot; a quicksave after it still goes to the game's own.
	if slot != "round_start":
		current_slot = slot
	EventBus.game_loaded.emit(slot)
	return OK


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Every save on disk, newest first (finished games last): [{slot, saved_at, location, day, party, finished: the
## ending's title or ""}].
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
		var ended := str((d.get("finished", {}) as Dictionary).get("title", ""))
		var place := str(loc.get("name", story.get("location", ""))) if ended == "" else "The End: %s" % ended
		out.append({"slot": f.get_basename(), "saved_at": str(d.get("saved_at", "")), "location": place,
			"day": int(story.get("day", 1)), "party": ", ".join(names), "finished": ended})
	# Unfinished games first (Continue picks the newest of them), finished ones after.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (str(a["finished"]) == "") != (str(b["finished"]) == ""):
			return str(a["finished"]) == ""
		return str(a["saved_at"]) > str(b["saved_at"]))
	return out


func delete_slot(slot: String) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(slot_path(slot))

