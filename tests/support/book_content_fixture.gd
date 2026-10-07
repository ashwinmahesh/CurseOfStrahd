class_name BookContentFixture
extends RefCounted
## Exercise unreleased book mechanics without changing their on-disk readiness flags.
## Restore after each test/capture, so ordinary builder and gate tests still see production data.

var _entries: Array[Dictionary] = []

func _init() -> void:
	for folder: String in ["backgrounds", "feats", "spells", "subclasses", "magic_items"]:
		for entry in Compendium.shared().all(folder):
			if str((entry.get("source", {}) as Dictionary).get("book", "")) not in ["FRHoF", "FRAiF", "AU"]:
				continue
			_entries.append({"entry": entry, "had_flag": entry.has("playable"), "playable": entry.get("playable", true)})
			entry["playable"] = true

func restore() -> void:
	for saved in _entries:
		var entry := saved["entry"] as Dictionary
		if bool(saved["had_flag"]):
			entry["playable"] = saved["playable"]
		else:
			entry.erase("playable")
	_entries.clear()
