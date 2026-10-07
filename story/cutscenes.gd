class_name Cutscenes
extends RefCounted
## Story cutscenes (Improvement Ideas G4; docs/ui/cutscenes.md): a full-screen still illustration for a moment the
## game's own views can't show faithfully (owner rule, 2026-10-07), such as Strahd on his black horse up on a ridge.
## Each data/cutscenes/<id>.json names its picture, art/cutscenes/<image>.png, in takes with a `when` (the first that
## holds is shown, none holding skips it). A conversation plays one with `cutscene <id>`: its lines then read as
## captions over the picture until `cutscene end` or the conversation's end. A cutscene with a `trigger` (a Narrator
## key such as examine:bonegrinder_lookout) plays while exploring, with the narrator's line as its caption.
## Pure logic, like all of story/: the UI (ui/cutscene/) loads and shows the picture.

const ROOT := "res://data/cutscenes/"
const ART := "res://art/cutscenes/%s.png"

static var _table: Dictionary = {}
static var _loaded := false


static func get_cutscene(id: String) -> Dictionary:
	_load()
	return _table.get(id, {}) as Dictionary


## Every cutscene, by id.
static func all() -> Array[Dictionary]:
	_load()
	var ids := _table.keys()
	ids.sort()
	var out: Array[Dictionary] = []
	for id: Variant in ids:
		out.append(_table[id] as Dictionary)
	return out


## Drops the loaded files (tests that add cutscenes).
static func clear_cache() -> void:
	_table.clear()
	_loaded = false


## Adds a cutscene as if it were a data file (tests and tools).
static func register(cutscene: Dictionary) -> void:
	_load()
	_table[str(cutscene["id"])] = cutscene


## The picture to show for `id` now (a res:// path): its first take whose `when` holds, or "" (no such cutscene, or no
## take fits, so it's skipped).
static func image(id: String, st: StoryState) -> String:
	for take: Variant in get_cutscene(id).get("images", []):
		var t := take as Dictionary
		if StoryConditions.check(str(t.get("when", "")), st):
			return ART % str(t["image"])
	return ""


## Where the slow push-in closes on, as a share of the picture's size.
static func focus(id: String) -> Vector2:
	var f := get_cutscene(id).get("focus", []) as Array
	return Vector2(float(f[0]), float(f[1])) if f.size() == 2 else Vector2(0.5, 0.5)


## The cutscene a Narrator key plays while exploring (examine:bonegrinder_lookout), or "" if none fits now.
static func for_trigger(key: String, st: StoryState) -> String:
	for c in all():
		if str(c.get("trigger", "")) == key and image(str(c["id"]), st) != "":
			return str(c["id"])
	return ""


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + f))
		if parsed is Dictionary:
			_table[str((parsed as Dictionary).get("id", f.get_basename()))] = parsed
		else:
			push_error("Cutscenes: %s is not a JSON object" % f)
