class_name SaveTransfer
extends RefCounted
## Files are inspected without loading a campaign. Import always creates a new atomic slot after review.

const MAX_BYTES := 16 * 1024 * 1024


static func inspect(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "That file couldn't be opened."}
	if file.get_length() > MAX_BYTES:
		return {"error": "That file is too large to be a save."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"error": "That file isn't a readable game save."}
	var data := parser.data as Dictionary
	if not data.get("version") is float and not data.get("version") is int:
		return {"error": "That file isn't a game save."}
	if not is_finite(float(data["version"])) or float(data["version"]) != floorf(float(data["version"])):
		return {"error": "That save has an invalid version."}
	if int(data["version"]) > GameState.SAVE_VERSION:
		return {"error": "That save needs a newer version of the game."}
	if int(data["version"]) < 1 or not data.get("story") is Dictionary or not (data["story"] as Dictionary).get("party") is Array:
		return {"error": "That save has no readable campaign."}
	if not _shape(data, GameState.to_dict()) or not _points(data.get("party_positions", []), 3) or not _story(data["story"] as Dictionary):
		return {"error": "That save contains invalid campaign data."}
	var story := data["story"] as Dictionary
	var names: Array[String] = []
	for member: Dictionary in story["party"]:
		names.append(str((member.get("build", {}) as Dictionary).get("name", "Adventurer")))
	var location := str(story.get("location", ""))
	if location != "" and Compendium.shared().get_entry("locations", location).is_empty():
		return {"error": "That save uses a location missing from this build."}
	return {"data": data, "party": ", ".join(names), "location": str(Compendium.shared().get_entry("locations", location).get("name", "New adventure")), "day": int(story.get("day", 1))}


static func commit(review: Dictionary) -> Dictionary:
	if not review.get("data") is Dictionary:
		return {"error": "No save is ready to import."}
	var data := (review["data"] as Dictionary).duplicate(true)
	var slot := SaveSystem.new_slot_name()
	# A transferred autosave belongs to its new local slot, never a similarly named local campaign.
	data.erase("home_slot")
	data.erase("kind")
	var err := AtomicJson.write(SaveSystem.slot_path(slot), data)
	return {"slot": slot} if err == OK else {"error": "The save couldn't be imported. Free some storage and try again."}


static func share_copy(path: String, destination: String) -> Error:
	var data := AtomicJson.read(path)
	if data.is_empty():
		return ERR_FILE_CORRUPT
	return AtomicJson.write(destination, data)


static func _shape(value: Variant, sample: Variant, depth: int = 0) -> bool:
	if depth > 40:
		return false
	if sample is Dictionary:
		if not value is Dictionary:
			return false
		for key: Variant in sample:
			if (value as Dictionary).has(key) and not _shape(value[key], sample[key], depth + 1):
				return false
	elif sample is Array:
		if not value is Array:
			return false
		if not (sample as Array).is_empty():
			for element: Variant in value:
				if not _shape(element, sample[0], depth + 1):
					return false
	elif sample is int or sample is float:
		return (value is int or value is float) and is_finite(float(value))
	elif typeof(value) != typeof(sample):
		return false
	return true


static func _story(story: Dictionary) -> bool:
	if not _shape(story, StoryState.new().to_dict()):
		return false
	for key: String in ["quests", "location_states", "shops", "active_spells", "bestiary"]:
		if not _map_values(story.get(key, {}), {}):
			return false
	for guest: Variant in story.get("guests", []):
		if not guest is Dictionary or not (guest as Dictionary).get("npc") is String or not _shape(guest, {"state": {}}):
			return false
	var exemplar := Pregens.build("godrick_pendlebrook", 1).to_dict()
	for list: String in ["party", "bench"]:
		for member: Variant in story.get(list, []):
			if not member is Dictionary or not (member as Dictionary).get("build") is Dictionary or not _shape(member, exemplar) or not _character(member as Dictionary):
				return false
	if not _points(story.get("positions", []), 2):
		return false
	for list: String in ["stash", "guests", "fallen"]:
		for entry: Variant in story.get(list, []):
			if not entry is Dictionary:
				return false
	return true


static func _points(value: Variant, dimensions: int) -> bool:
	if not value is Array:
		return false
	for point: Variant in value:
		if not point is Array or (point as Array).size() != dimensions or not _shape(point, [0]):
			return false
	return true


static func _map_values(value: Variant, sample: Variant) -> bool:
	if not value is Dictionary:
		return false
	for entry: Variant in (value as Dictionary).values():
		if not _shape(entry, sample):
			return false
	return true


static func _character(member: Dictionary) -> bool:
	var build := member.get("build", {}) as Dictionary
	if not _map_values(build.get("choices", {}), [""]):
		return false
	var state := member.get("state", {}) as Dictionary
	if not _map_values(state.get("conditions", {}), [""]) or not _map_values(state.get("resources_used", {}), 0):
		return false
	for effect: Variant in state.get("effects", []):
		if not effect is Dictionary or not _shape(effect, {"modifiers": [{"data": {}}], "conditions": [""], "data": {}, "concentration": {}, "repeat_save": {}, "escape": {}, "consume_on": [""], "ends_on": [""]}):
			return false
		for modifier: Dictionary in (effect as Dictionary).get("modifiers", []):
			if not modifier.get("data") is Dictionary:
				return false
	var concentration := state.get("concentration", {}) as Dictionary
	if not concentration.is_empty() and (not concentration.get("source") is String or not concentration.get("name") is String):
		return false
	for item: Variant in member.get("inventory", []):
		if not item is Dictionary or not (item as Dictionary).get("id") is String or not _shape(item, {"qty": 0, "beads": [""]}):
			return false
	return true
