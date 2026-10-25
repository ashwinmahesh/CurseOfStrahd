class_name Cutscenes
extends RefCounted
## Story cutscenes (Improvement Ideas G4; docs/ui/cutscenes.md): a full-screen still illustration for a moment the
## game's own views can't show faithfully (owner rule, 2026-10-07), such as Strahd on his black horse up on a ridge.
## Each data/cutscenes/<id>.json names its picture, art/cutscenes/<image>.jpg, in takes with a `when` (the first that
## holds is shown, none holding skips it). A conversation plays one with `cutscene <id>`: its lines then read as
## captions over the picture until `cutscene end` or the conversation's end. A cutscene with a `trigger` (a Narrator
## key such as examine:bonegrinder_lookout) plays while exploring, with the narrator's line as its caption.
## Pure logic, like all of story/: the UI (ui/cutscene/) loads and shows the picture.

const ROOT := "res://data/cutscenes/"
const ART := "res://art/cutscenes/%s.jpg"
## The story flag that remembers a place's cutscene was shown (internal, like the runner's `_approve/` marks).
const PLAYED := "_cutscene/%s"

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


## The cutscene a Narrator key plays while exploring (examine:bonegrinder_lookout), or "" if none fits now (or it plays
## `once` and has).
static func for_trigger(key: String, st: StoryState) -> String:
	for c in all():
		var id := str(c["id"])
		if str(c.get("trigger", "")) == key and image(id, st) != "" and not (bool(c.get("once", false)) and played(id, st)):
			return id
	return ""


## The scene that follows `id` (data `then`: a cutscene with its own picture and a `caption` Narrator key), or "".
static func then_of(id: String) -> String:
	return str(get_cutscene(id).get("then", ""))


## The Narrator key whose line reads over a follow-on scene's picture (data `caption`), or "".
static func caption_key(id: String) -> String:
	return str(get_cutscene(id).get("caption", ""))


## The Narrator keys whose lines read over `id`'s picture after its first caption (data `more`), in order.
static func more_keys(id: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in get_cutscene(id).get("more", []):
		out.append(str(k))
	return out


## What a trigger plays, in order (owner rule, 2026-10-14: every cutscene is at least two scenes): `id` with
## `first_caption` over it, then each scene that follows it (data `then`, chained) that has a picture for this story now
## and a Narrator line to read over it. Each is {id, lines}: a scene's `lines` are its caption and then any further
## captions over the same picture (data `more`: the Tome's four pictures read three each). A follow-on with no picture or
## no line ends the chain, so without a Narrator (tests, tools) it is the first scene alone.
static func scenes(id: String, first_caption: String, st: StoryState, narrator: Narrator, actor: Character = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": id, "lines": _with_more(id, [first_caption] as Array[String], st, narrator, actor)}]
	var seen := {id: true}
	var next := then_of(id)
	while next != "" and not seen.has(next) and narrator != null:
		seen[next] = true
		var key := caption_key(next)
		if key == "" or image(next, st) == "":
			break
		var text := narrator.line(key, st, actor)
		if text == "":
			break
		out.append({"id": next, "lines": _with_more(next, [text] as Array[String], st, narrator, actor)})
		next = then_of(next)
	return out


## `lines` and then the scene's further captions (data `more`) that have a Narrator line now.
static func _with_more(id: String, lines: Array[String], st: StoryState, narrator: Narrator, actor: Character) -> Array[String]:
	if narrator == null:
		return lines
	for key in more_keys(id):
		var text := narrator.line(key, st, actor)
		if text != "":
			lines.append(text)
	return lines


## The caption under a treasure's picture (`find:<item>`), in our own words.
static func found_line(item_id: String) -> String:
	var name := Compendium.shared().display_name("magic_items", item_id)
	var campaign_name := Campaign.module().treasure_name(item_id)   # "The Sunsword", as Madam Eva names them
	if campaign_name != "":
		name = campaign_name
	return "%s, in your hands at last." % name


## Records that a place's cutscene has played (kept with the story, so a `once` one never comes back).
static func mark_played(id: String, st: StoryState) -> void:
	st.flags[PLAYED % id] = true


static func played(id: String, st: StoryState) -> bool:
	return bool(st.flags.get(PLAYED % id, false))


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
