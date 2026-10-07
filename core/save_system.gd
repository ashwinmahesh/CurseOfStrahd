extends Node
## Writes GameState to one JSON file per slot. Saves are allowed anywhere outside combat
## (plan §10 Phase 3); the mode check lives here so every caller gets it.
## Beside each save (Q9, docs/ui/saves.md): a thumbnail of the game as it was (<slot>.webp), and the player's own note
## on it (the save's "note"). A new build of the play copy copies every save into backups/ before it touches any.

var save_dir := "user://saves/"
## The game's own save slot: the one it was last loaded from or saved to. Quicksave (F5) writes here; a new game
## starts with none, and its first quicksave makes one.
var current_slot := ""
## The game's safety net (docs/plans/ui_polish.md): written on arriving somewhere new, after a rest and after a won
## fight, never during one. Like the round-start save it is never the game's own slot: it remembers that slot, and
## loading it goes back to it, so F5 still saves where it did. The newest is AUTOSAVE; the AUTOSAVES - 1 before it
## are autosave_2, autosave_3 ... (Q9), each moved one along by the next autosave.
const AUTOSAVE := "autosave"
const AUTOSAVES := 5
const ROUND_START := "round_start"
## Thumbnails (Q9): the middle 16:9 of the screen at this size, as WebP.
const THUMB := Vector2i(320, 180)
## The autosave on arriving somewhere is written before the place is on screen: its picture waits this long.
const THUMB_DELAY := 0.8
## Backups (Q9): the play copy's build (written by make play) and how many builds' backups are kept.
const BUILD_FILE := "res://builds/play_build.json"
const BACKUPS := "backups"
const BACKUPS_KEPT := 8

## The world as the pause menu opened over it (hold_view), for the thumbnail of a save made from its pages.
var _held: Image = null
var _held_by: WeakRef = null


func _ready() -> void:
	back_up_for_build(build_commit())


func can_save() -> bool:
	return ModeController.mode != ModeController.Mode.COMBAT


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func thumb_path(slot: String, dir: String = "") -> String:
	return (save_dir if dir == "" else dir).path_join(slot + ".webp")


## `note`: the player's own note on this save; null keeps the one the slot had.
func save(slot: String, note: Variant = null) -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	var data := GameState.to_dict()
	var keep := str(note) if note != null else str(_read(slot_path(slot)).get("note", ""))
	if keep != "":
		data["note"] = keep
	var err := _write(slot, data)
	if err != OK:
		return err
	_write_thumb(slot, _view())
	current_slot = slot
	EventBus.game_saved.emit(slot)
	return OK


## Quicksave (F5, the pause menu): over the game's current slot, or a new slot the first time.
func quick_save() -> Error:
	return save(current_slot if current_slot != "" else new_slot_name())


## A slot name no save has yet, from the time: save_<date>T<time>, with _2, _3 after it for a second save that second.
func new_slot_name() -> String:
	var base := "save_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	var slot := base
	var n := 2
	while has_slot(slot):
		slot = "%s_%d" % [base, n]
		n += 1
	return slot


## The fight's round-start save (plan §10 Phase 3): allowed in combat, written only by the game at the start of
## a round, when GameState.combat_snapshot holds the fight. It has no thumbnail (a picture every round would cost a
## frame each round).
func save_round(slot: String = ROUND_START) -> Error:
	return _write_beside(slot)


## The autosave (AUTOSAVE): anywhere a save is allowed, without making it the game's slot. The ones before it move one
## along (autosave_2 ...), and the oldest goes.
func autosave() -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	delete_slot(autosave_slot(AUTOSAVES))
	for n in range(AUTOSAVES - 1, 0, -1):
		_move(autosave_slot(n), autosave_slot(n + 1))
	var err := _write_beside(AUTOSAVE)
	if err == OK:
		_thumb_later(AUTOSAVE)
	return err


## The n-th newest autosave's slot (1 is AUTOSAVE).
static func autosave_slot(n: int) -> String:
	return AUTOSAVE if n <= 1 else "%s_%d" % [AUTOSAVE, n]


static func is_autosave(slot: String) -> bool:
	return slot == AUTOSAVE or (slot.begins_with(AUTOSAVE + "_") and slot.trim_prefix(AUTOSAVE + "_").is_valid_int())


## A save the game writes beside the player's (an autosave, the round start): never the game's own slot.
static func is_beside(slot: String) -> bool:
	return slot == ROUND_START or is_autosave(slot)


## A save that isn't the game's own slot (the round start, the autosave): it notes the game's slot as `home_slot`.
func _write_beside(slot: String) -> Error:
	var data := GameState.to_dict()
	data["home_slot"] = current_slot
	return _write(slot, data)


func _write(slot: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


## The campaign's end (ADR 0014): the game's own slot (a new one if it has none) is written one last time, marked
## finished with the ending reached. Finished saves list last and show the ending instead of the place.
func save_finished(ending_id: String, title: String) -> Error:
	var slot := current_slot if current_slot != "" and not is_beside(current_slot) else new_slot_name()
	var data := GameState.to_dict()
	data["finished"] = {"ending": ending_id, "title": title}
	var note := str(_read(slot_path(slot)).get("note", ""))
	if note != "":
		data["note"] = note
	var err := _write(slot, data)
	if err != OK:
		return err
	current_slot = slot
	EventBus.game_saved.emit(slot)
	return OK


func load_slot(slot: String) -> Error:
	return load_from(save_dir, slot)


## Loads the save `slot` in `dir`. One in the saves folder becomes the game's own slot (or, for the autosave and the
## round start, goes back to the one they were written for, so a quicksave after loading one still goes to the
## game's own). One from anywhere else (a backup) is a game without a slot until its first save.
func load_from(dir: String, slot: String) -> Error:
	var path := dir.path_join(slot + ".json")
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	var dict := data as Dictionary
	if int(dict.get("version", 0)) > GameState.SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	dict = upgrade(dict)
	GameState.from_dict(dict)
	if dir.simplify_path() != save_dir.simplify_path():
		current_slot = ""
	elif is_beside(slot):
		current_slot = str(dict.get("home_slot", current_slot))
	else:
		current_slot = slot
	EventBus.game_loaded.emit(slot)
	return OK


## Saves from older builds (P4). A change to what a save holds bumps GameState.SAVE_VERSION and adds a step here that
## takes a save of the version before it to the new one, so an old save is mended in one place before GameState reads
## it. Every save in tests/saves (made by older builds) goes through this in every test run
## (tests/integration/test_golden_saves.gd), so a missing or wrong step fails there first. Version 1 was Phase 0's;
## 2 has been the format since Phase 3. Mends that apply to every save whatever its version (a pregen's current look,
## the Dursts' book) stay in StoryState.from_dict. What only the saves lists read (the player's "note", a finished
## game's "finished", a beside save's "home_slot") is no part of the game and needs no step: a save without one has none.
static func upgrade(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var v := int(out.get("version", 1))
	while v < GameState.SAVE_VERSION:
		match v:
			1:
				pass   # Phase 0 saves held no story: the game starts them on the mists road as a new game does
		v += 1
		out["version"] = v
	return out


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Every save in `dir` (the saves folder, or a backup's), newest first (finished games last), as describe() gives them.
func list_slots(dir: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var from := save_dir if dir == "" else dir
	for f in _files(from):
		if not f.ends_with(".json"):
			continue
		var s := describe(f.get_basename(), from)
		if not s.is_empty():
			out.append(s)
	# Unfinished games first (Continue picks the newest of them), finished ones after.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (str(a["finished"]) == "") != (str(b["finished"]) == ""):
			return str(a["finished"]) == ""
		return str(a["saved_at"]) > str(b["saved_at"]))
	return out


## What a save says about itself for the lists, or {} when `slot` isn't a save: {slot, dir, saved_at, location,
## day, party, finished: the ending's title or "", kind: "autosave", "round" (a fight's round start) or "" for a save
## the player made, note: the player's own, thumb: its picture's path or ""}. Other files kept beside the saves
## (achievements.json, N8) aren't saves: every save says its version.
func describe(slot: String, dir: String = "") -> Dictionary:
	var from := save_dir if dir == "" else dir
	var raw := _read(from.path_join(slot + ".json"))
	if not raw.has("version"):
		return {}
	var d := upgrade(raw)
	var story := d.get("story", {}) as Dictionary
	var names: Array[String] = []
	for m: Variant in story.get("party", []):
		names.append(str(((m as Dictionary).get("build", {}) as Dictionary).get("name", "?")))
	var loc := Compendium.shared().get_entry("locations", str(story.get("location", "")))
	var ended := str((d.get("finished", {}) as Dictionary).get("title", ""))
	var place := str(loc.get("name", story.get("location", ""))) if ended == "" else "The End: %s" % ended
	var thumb := thumb_path(slot, from)
	return {"slot": slot, "dir": from, "saved_at": str(d.get("saved_at", "")), "location": place,
		"day": int(story.get("day", 1)), "party": ", ".join(names), "finished": ended,
		"kind": "autosave" if is_autosave(slot) else ("round" if slot == ROUND_START else ""),
		"note": str(d.get("note", "")), "thumb": thumb if FileAccess.file_exists(thumb) else ""}


## A save file as a dictionary ({} when it's missing or not JSON).
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data as Dictionary if data is Dictionary else {}


func delete_slot(slot: String) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(slot_path(slot))
	if FileAccess.file_exists(thumb_path(slot)):
		DirAccess.remove_absolute(thumb_path(slot))


## Moves a save (and its picture) to another slot's name, over whatever was there.
func _move(from: String, to: String) -> void:
	if not has_slot(from):
		return
	delete_slot(to)
	DirAccess.rename_absolute(slot_path(from), slot_path(to))
	if FileAccess.file_exists(thumb_path(from)):
		DirAccess.rename_absolute(thumb_path(from), thumb_path(to))


# --- Thumbnails -----------------------------------------------------------------------------------

## The pause menu holds the frame it opens over, so a save made from its pages shows the world, not the menu. The
## picture is good while `by` (the menu) is open; outside a fight only, since nothing can be saved in one.
func hold_view(by: Node) -> void:
	_held = _grab() if can_save() else null
	_held_by = weakref(by)


## The picture for a save made now: the held one while its menu is open, else the screen as it is.
func _view() -> Image:
	var by := _held_by.get_ref() as Node if _held_by != null else null
	if _held != null and by != null and by.is_inside_tree():
		return _held
	_held = null
	return _grab()


## The screen's last frame as a thumbnail, or null (no screen: headless runs and tests).
func _grab() -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex != null else null
	return thumbnail_of(img) if img != null and not img.is_empty() else null


## The middle 16:9 of `img`, at THUMB.
static func thumbnail_of(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cw := mini(w, roundi(h * 16.0 / 9.0))
	var ch := mini(h, roundi(w * 9.0 / 16.0))
	var out := img.get_region(Rect2i(int((w - cw) / 2.0), int((h - ch) / 2.0), cw, ch))
	out.convert(Image.FORMAT_RGB8)
	out.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	return out


func _write_thumb(slot: String, img: Image) -> void:
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	img.save_webp(thumb_path(slot), true, 0.8)


## A save written as the game arrives somewhere has its picture taken once the place is showing, if it's still the
## same save then.
func _thumb_later(slot: String) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var at := str(_read(slot_path(slot)).get("saved_at", ""))
	get_tree().create_timer(THUMB_DELAY).timeout.connect(func() -> void:
		if has_slot(slot) and str(_read(slot_path(slot)).get("saved_at", "")) == at:
			_write_thumb(slot, _grab()))


# --- Backups --------------------------------------------------------------------------------------

## The play copy's build (builds/play_build.json, which make play writes), or "" in a working checkout.
static func build_commit() -> String:
	if not FileAccess.file_exists(BUILD_FILE):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_FILE))
	return str((data as Dictionary).get("commit", "")) if data is Dictionary else ""


func backups_dir() -> String:
	return save_dir.path_join(BACKUPS)


## Before a new build (`commit`) reads any save, a copy of every save and its picture goes to
## backups/<date>T<time>_<commit>/ (Q9: "a copy of every save kept before each update"). Once per build; the newest
## BACKUPS_KEPT builds' copies are kept. Returns the folder made, or "".
func back_up_for_build(commit: String) -> String:
	if commit == "":
		return ""
	var mark := backups_dir().path_join("last_build.txt")
	if FileAccess.file_exists(mark) and FileAccess.get_file_as_string(mark).strip_edges() == commit:
		return ""
	var files: Array[String] = []
	for f in _files(save_dir):
		if f.ends_with(".json") or f.ends_with(".webp"):
			files.append(f)
	var made := ""
	if not files.is_empty():
		made = backups_dir().path_join("%s_%s" % [Time.get_datetime_string_from_system().replace(":", "-"), commit.left(8)])
		DirAccess.make_dir_recursive_absolute(made)
		for f in files:
			DirAccess.copy_absolute(save_dir.path_join(f), made.path_join(f))
	DirAccess.make_dir_recursive_absolute(backups_dir())
	var out := FileAccess.open(mark, FileAccess.WRITE)
	if out != null:
		out.store_string(commit)
		out.close()
	var kept := backups()
	for old: String in kept.slice(BACKUPS_KEPT):
		_remove_dir(backups_dir().path_join(old))
	return made


## The backups, newest first: folder names (<date>T<time>_<commit>, so their names sort by when they were made).
func backups() -> Array[String]:
	var out: Array[String] = []
	if DirAccess.dir_exists_absolute(backups_dir()):
		out.assign(DirAccess.get_directories_at(backups_dir()))
	out.sort()
	out.reverse()
	return out


## The files in `dir`, none if it doesn't exist (a new player has no saves folder yet).
static func _files(dir: String) -> PackedStringArray:
	return DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()


static func _remove_dir(dir: String) -> void:
	for f in _files(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
