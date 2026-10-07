class_name GoldenSaves
extends RefCounted
## Golden saves (P4): the playthrough tests keep a save at the start of each chapter when `make golden-saves` runs
## them (GOLDEN_SAVES set to the commit), so the saves are made by the same auto-player and the same game as a player's
## would be. They go to tests/saves as v<save version>_<chapter>.json and are never made again: a golden save is worth
## keeping because an older build wrote it, and tests/integration/test_golden_saves.gd loads every one in every run.
## A new save version gets its own set beside the old ones. Test-only.

const DIR := "res://tests/saves/"


## The commit `make golden-saves` was run on, or "" when the tests are only testing.
static func commit() -> String:
	return OS.get_environment("GOLDEN_SAVES")


## The file a chapter's save goes to at this save version.
static func path(chapter: String) -> String:
	return DIR + "v%d_%s.json" % [GameState.SAVE_VERSION, chapter]


## Keeps the game as it stands now as `chapter`'s golden save, the way SaveSystem writes a save (`extra` adds what a
## special save has, like a finished game's ending), with a note of where it came from. Only under make golden-saves,
## only once per chapter and save version, and never mid-fight. True if written.
static func keep(chapter: String, made_by: String, extra: Dictionary = {}) -> bool:
	if commit() == "" or FileAccess.file_exists(ProjectSettings.globalize_path(path(chapter))) or not SaveSystem.can_save():
		return false
	var data := GameState.to_dict()
	data["home_slot"] = SaveSystem.current_slot
	data.merge(extra, true)
	data["golden"] = {"chapter": chapter, "commit": commit(), "made_by": made_by,
		"made": Time.get_date_string_from_system()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(ProjectSettings.globalize_path(path(chapter)), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("  kept golden save ", path(chapter).get_file())
	return true
