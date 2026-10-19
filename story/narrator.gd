class_name Narrator
extends RefCounted
## The unseen storyteller (plan §5.7). Lines come from narrative/narrator/*.dialogue, one node per trigger key
## (`enter:death_house_foyer`, `examine:portrait`, `combat:crit` ...), each `|` line a variant. A variant with a
## [condition] is preferred when it holds (it reacts to who acts and what they rolled); variants don't repeat until
## the others have played; `cooldown n` (game minutes, or rounds in combat) and `once` limit how often a trigger
## speaks. A variant written `[once]` or `[once and <condition>]` plays one time a playthrough and then drops out, while
## the trigger's other lines go on; until it has played (and while its condition holds) it comes before every other line.
## Its memory lives in StoryState.narrator so it survives saves.

var _variants: Dictionary = {}     ## trigger -> [{cond, once, text}]
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
		# A trigger written in several region files gathers all their variants (each region conditions its own).
		var list: Array[Dictionary] = _variants.get(key, [] as Array[Dictionary]) as Array[Dictionary]
		for s: Dictionary in f.nodes[key]:
			match str(s["t"]):
				"variant":
					list.append({"cond": str(s["cond"]), "once": bool(s.get("once", false)), "text": str(s["text"])})
				"line":
					if str(s["speaker"]).to_lower() == "narrator":
						list.append({"cond": "", "once": false, "text": str(s["text"])})
				"cooldown":
					_cooldown[key] = maxi(int(_cooldown.get(key, 0)), int(s["minutes"]))
				"once":
					_once[key] = true
		_variants[key] = list


func has_trigger(key: String) -> bool:
	return _variants.has(key)


## The line for a trigger, or "" (no lines, all conditions fail, or it's cooling down). Marks it played.
## `actor` fills {name}; `extra` may hold {target: name, round: int, fight: id} (combat cooldowns count rounds, within
## one fight: a new fight's rounds start again from 1).
func line(key: String, st: StoryState, actor: Character = null, extra: Dictionary = {}) -> String:
	if not _variants.has(key):
		return ""
	var mem := st.narrator.get(key, {"played": [], "last": -100000, "done": false}) as Dictionary
	if bool(mem.get("done", false)):
		return ""
	var now := int(extra.get("round", st.total_minutes()))
	var fight := str(extra.get("fight", ""))
	if _cooldown.has(key) and now - int(mem.get("last", -100000)) < int(_cooldown[key]) \
			and str(mem.get("fight", "")) == fight:
		return ""
	var list := _variants[key] as Array[Dictionary]
	var ctx := st
	var spent := mem.get("spent", []) as Array
	var eligible: Array[int] = []
	var specific: Array[int] = []
	var one_offs: Array[int] = []
	for i in list.size():
		var cond := str(list[i]["cond"])
		var once := bool(list[i]["once"])
		if once and _once_id(list[i]) in spent:
			continue
		var ok := cond == "" or _holds(cond, ctx, actor)
		if not ok:
			continue
		eligible.append(i)
		if once:
			one_offs.append(i)
		elif cond != "":
			specific.append(i)
	# A `[once]` line that hasn't played and holds comes before every other line, so a one-off plays as soon as its
	# moment comes; then conditioned lines before plain ones.
	var pool := one_offs if not one_offs.is_empty() else (specific if not specific.is_empty() else eligible)
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
	if fight != "":
		mem["fight"] = fight
	else:
		mem.erase("fight")
	if _once.has(key):
		mem["done"] = true
	if bool(list[pick]["once"]):
		spent.append(_once_id(list[pick]))
		mem["spent"] = spent
	st.narrator[key] = mem
	var text := str(list[pick]["text"])
	var name := actor.name.get_slice(" ", 0) if actor != null else ""
	return text.replace("{name}", name).replace("{target}", str(extra.get("target", "")))


## How a `[once]` variant is remembered: by its text, not its place in the list, so lines added to a trigger (or a file
## read in another order) don't move which ones have played.
static func _once_id(variant: Dictionary) -> String:
	return str(variant["text"]).sha1_text().substr(0, 12)


## A variant's condition is checked against the acting character first (class:, species:, tag: ...), then the
## party and the story.
static func _holds(cond: String, st: StoryState, actor: Character) -> bool:
	return StoryConditions.check(cond, st, actor)
