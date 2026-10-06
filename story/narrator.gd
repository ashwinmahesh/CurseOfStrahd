class_name Narrator
extends RefCounted
## The unseen storyteller (plan §5.7). Lines come from narrative/narrator/*.dialogue, one node per trigger key
## (`enter:death_house_foyer`, `examine:portrait`, `combat:crit` ...), each `|` line a variant. A variant with a
## [condition] is preferred when it holds (it reacts to who acts and what they rolled); variants don't repeat until
## the others have played; `cooldown n` (game minutes, or rounds in combat) and `once` limit how often a trigger
## speaks. Its memory lives in StoryState.narrator so it survives saves.

var _variants: Dictionary = {}     ## trigger -> [{cond, text}]
var _cooldown: Dictionary = {}     ## trigger -> minutes
var _once: Dictionary = {}
## Cosmetic randomness for picking among equal variants (never a rules roll).
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 7) -> void:
	_rng.seed = seed_value
	var dir := DirAccess.open(DialogueFile.ROOT + "narrator")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".dialogue"):
			add_file(DialogueFile.load_key("narrator/" + f.get_basename()))


func add_file(f: DialogueFile) -> void:
	if f == null:
		return
	for key: String in f.order:
		var list: Array[Dictionary] = []
		for s: Dictionary in f.nodes[key]:
			match str(s["t"]):
				"variant":
					list.append({"cond": str(s["cond"]), "text": str(s["text"])})
				"line":
					if str(s["speaker"]).to_lower() == "narrator":
						list.append({"cond": "", "text": str(s["text"])})
				"cooldown":
					_cooldown[key] = int(s["n"])
				"once":
					_once[key] = true
		_variants[key] = list


func has_trigger(key: String) -> bool:
	return _variants.has(key)


## The line for a trigger, or "" (no lines, all conditions fail, or it's cooling down). Marks it played.
## `actor` fills {name}; `extra` may hold {target: name, round: int (combat cooldowns count rounds)}.
func line(key: String, st: StoryState, actor: Character = null, extra: Dictionary = {}) -> String:
	if not _variants.has(key):
		return ""
	var mem := st.narrator.get(key, {"played": [], "last": -100000, "done": false}) as Dictionary
	if bool(mem.get("done", false)):
		return ""
	var now := int(extra.get("round", st.total_minutes()))
	if _cooldown.has(key) and now - int(mem.get("last", -100000)) < int(_cooldown[key]):
		return ""
	var list := _variants[key] as Array[Dictionary]
	var ctx := st
	var eligible: Array[int] = []
	var specific: Array[int] = []
	for i in list.size():
		var cond := str(list[i]["cond"])
		var ok := cond == "" or _holds(cond, ctx, actor)
		if not ok:
			continue
		eligible.append(i)
		if cond != "":
			specific.append(i)
	var pool := specific if not specific.is_empty() else eligible
	if pool.is_empty():
		return ""
	var played := mem.get("played", []) as Array
	var fresh: Array[int] = []
	for i in pool:
		if not i in played:
			fresh.append(i)
	if fresh.is_empty():
		for i in pool:
			played.erase(i)
		fresh = pool
	var pick := fresh[_rng.randi_range(0, fresh.size() - 1)]
	played.append(pick)
	mem["played"] = played
	mem["last"] = now
	if _once.has(key):
		mem["done"] = true
	st.narrator[key] = mem
	var text := str(list[pick]["text"])
	var name := actor.name.get_slice(" ", 0) if actor != null else ""
	return text.replace("{name}", name).replace("{target}", str(extra.get("target", "")))


## A variant's condition is checked against the acting character first (class:, species:, tag: ...), then the
## party and the story.
static func _holds(cond: String, st: StoryState, actor: Character) -> bool:
	if actor != null and not cond.contains(" ") and cond.contains(":") and not cond.begins_with("visited:") and not cond.begins_with("item:"):
		return StoryState.member_matches(actor, cond)
	return StoryConditions.check(cond, st)
