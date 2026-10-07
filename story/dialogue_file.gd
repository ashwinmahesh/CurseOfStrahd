class_name DialogueFile
extends RefCounted
## A parsed narrative/**/*.dialogue file (docs/contracts/dialogue.md): nodes of statements. Parsing mirrors
## tools/data/dialogue_lint.py, which validates the same files in `make validate`.
##
## Statement dictionaries ({"t": type, ...}):
##   line {speaker, mood, text} · option {text, ok, fail, cond, check: {skill, dc}, selector} · jump {to}
##   if {cond} · elif {cond} · else · endif · set {flag, op, value} · quest {id, stage} · give/take {item, qty}
##   gold {amount} · attitude {npc, value} · xp · check {skill, dc, ok, fail} · interject {selector, text}
##   combat {encounter} · narrate {key} · variant {cond, text} · cooldown {n} · once · end_game (ADR 0014)

const ROOT := "res://narrative/"
const CLASS_TAGS := ["fighter", "rogue", "cleric", "wizard", "barbarian", "bard", "druid", "monk", "paladin", "ranger",
	"sorcerer", "warlock"]

static var _cache: Dictionary = {}

var key: String = ""
var nodes: Dictionary = {}       ## node id -> Array[Dictionary]
var order: Array[String] = []
var errors: Array[String] = []


## "death_house/rose_thorn" -> the parsed file (cached), or null if it doesn't exist.
static func load_key(file_key: String) -> DialogueFile:
	if _cache.has(file_key):
		return _cache[file_key] as DialogueFile
	var path := ROOT + file_key + ".dialogue"
	if not FileAccess.file_exists(path):
		return null
	var f := DialogueFile.parse(FileAccess.get_file_as_string(path), file_key)
	_cache[file_key] = f
	return f


static func clear_cache() -> void:
	_cache.clear()


## Makes a parsed file loadable by its key (tests and tools).
static func register(f: DialogueFile) -> void:
	_cache[f.key] = f


static func parse(text: String, file_key: String = "") -> DialogueFile:
	var f := DialogueFile.new()
	f.key = file_key
	var node := ""
	var re_line := RegEx.create_from_string("^([A-Za-z][A-Za-z_ ]*?)(?:\\s*\\[([a-z]+)\\])?:\\s+(.+)$")
	var re_option := RegEx.create_from_string("^\\*\\s+(.*?)\\s*->\\s*([A-Za-z0-9_:/]+|END)(?:\\s*\\|\\s*([A-Za-z0-9_:/]+|END))?\\s*$")
	var re_tag := RegEx.create_from_string("^\\[([^\\]]+)\\]\\s*")
	var re_check_tag := RegEx.create_from_string("^([A-Za-z][A-Za-z ]*?)\\s+DC\\s+(\\d+)$")
	var re_set := RegEx.create_from_string("^set\\s+([a-z][a-z0-9_]*)(?:\\s*(=|\\+=|-=)\\s*(.+))?$")
	var re_check := RegEx.create_from_string("^check\\s+([A-Za-z][A-Za-z ]*?)\\s+DC\\s+(\\d+)\\s*->\\s*([A-Za-z0-9_:/]+|END)(?:\\s*\\|\\s*([A-Za-z0-9_:/]+|END))?$")
	var re_interject := RegEx.create_from_string("^interject\\s+([a-z]+:[a-z0-9_]+):\\s+(.+)$")
	var re_variant := RegEx.create_from_string("^\\|\\s*(?:\\[([^\\]]+)\\]\\s*)?(.+)$")
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("~ "):
			node = line.substr(2).strip_edges()
			f.nodes[node] = [] as Array[Dictionary]
			f.order.append(node)
			continue
		if node == "":
			f.errors.append("%s:%d: statement before the first node" % [file_key, n])
			continue
		var list := f.nodes[node] as Array[Dictionary]
		var st := _statement(line, re_line, re_option, re_tag, re_check_tag, re_set, re_check, re_interject, re_variant)
		if st.is_empty():
			f.errors.append("%s:%d: can't read: %s" % [file_key, n, line])
			continue
		st["n"] = n
		list.append(st)
	return f


static func _statement(line: String, re_line: RegEx, re_option: RegEx, re_tag: RegEx, re_check_tag: RegEx, re_set: RegEx,
		re_check: RegEx, re_interject: RegEx, re_variant: RegEx) -> Dictionary:
	if line == "once":
		return {"t": "once"}
	if line.begins_with("cooldown "):
		return {"t": "cooldown", "n": int(line.substr(9))}
	if line.begins_with("|"):
		var mv := re_variant.search(line)
		if mv != null:
			return {"t": "variant", "cond": mv.get_string(1), "text": mv.get_string(2)}
	var mo := re_option.search(line)
	if mo != null:
		var label := mo.get_string(1)
		var opt := {"t": "option", "ok": mo.get_string(2), "fail": mo.get_string(3), "cond": "", "check": {}, "selector": "", "tags": [] as Array[String]}
		while true:
			var mt := re_tag.search(label)
			if mt == null:
				break
			var tag := mt.get_string(1).strip_edges()
			label = label.substr(mt.get_end())
			var mc := re_check_tag.search(tag)
			if mc != null:
				opt["check"] = {"skill": mc.get_string(1).strip_edges().to_lower().replace(" ", "_"), "dc": int(mc.get_string(2)), "label": tag}
			elif tag.begins_with("if "):
				opt["cond"] = tag.substr(3)
			elif tag.contains(":"):
				opt["selector"] = tag
			elif tag.to_lower() in CLASS_TAGS:
				opt["selector"] = "class:" + tag.to_lower()
				(opt["tags"] as Array[String]).append(tag)
			else:
				(opt["tags"] as Array[String]).append(tag)
		opt["text"] = label.strip_edges()
		return opt
	if line.begins_with("->"):
		return {"t": "jump", "to": line.substr(2).strip_edges()}
	if line.begins_with("if "):
		return {"t": "if", "cond": line.substr(3)}
	if line.begins_with("elif "):
		return {"t": "elif", "cond": line.substr(5)}
	if line == "else":
		return {"t": "else"}
	if line == "endif":
		return {"t": "endif"}
	var ms := re_set.search(line)
	if ms != null:
		return {"t": "set", "flag": ms.get_string(1), "op": ms.get_string(2) if ms.get_string(2) != "" else "=",
			"value": StoryConditions._literal(ms.get_string(3).strip_edges()) if ms.get_string(3) != "" else true}
	var parts := line.split(" ", false)
	match parts[0]:
		"quest":
			if parts.size() == 3:
				return {"t": "quest", "id": parts[1], "stage": parts[2]}
		"give", "take":
			if parts.size() >= 2:
				return {"t": parts[0], "item": parts[1], "qty": int(parts[2]) if parts.size() > 2 else 1}
		"gold":
			if parts.size() == 2:
				return {"t": "gold", "amount": float(parts[1])}
		"attitude":
			if parts.size() == 3:
				return {"t": "attitude", "npc": parts[1], "value": parts[2]}
		"xp":
			return {"t": "xp"}
		"sacrifice":
			return {"t": "sacrifice"}
		"tarokka":
			if parts.size() >= 2 and parts[1] == "draw":
				return {"t": "tarokka_draw"}
			if parts.size() >= 3 and parts[1] == "read":
				return {"t": "tarokka_read", "slot": parts[2], "speaker": parts[3] if parts.size() > 3 else "madam_eva"}
			if parts.size() == 3 and parts[1] == "give":
				return {"t": "tarokka_give", "place": parts[2]}
		"dark_gift":
			if parts.size() == 2:
				return {"t": "dark_gift", "gift": parts[1]}
		"shop":
			return {"t": "shop"}
		"respec":
			return {"t": "respec"}
		"end_game":
			if parts.size() == 1:
				return {"t": "end_game"}
		"time":
			if parts.size() == 2 and parts[1].begins_with("+"):
				return {"t": "time", "minutes": int(parts[1].substr(1))}
			if parts.size() == 3 and parts[1] == "until":
				return {"t": "time_until", "hour": int(parts[2])}
		"join", "leave":
			if parts.size() == 2:
				return {"t": parts[0], "npc": parts[1]}
		"appear":
			if parts.size() == 2:
				return {"t": "appear", "npc": parts[1], "at": ""}
			if parts.size() == 4 and parts[2] == "at":
				return {"t": "appear", "npc": parts[1], "at": parts[3]}
		"vanish":
			if parts.size() == 2:
				return {"t": "vanish", "npc": parts[1]}
		"combat":
			if parts.size() == 2:
				return {"t": "combat", "encounter": parts[1]}
		"narrate":
			if parts.size() == 2:
				return {"t": "narrate", "key": parts[1]}
	var mc2 := re_check.search(line)
	if mc2 != null:
		return {"t": "check", "skill": mc2.get_string(1).strip_edges().to_lower().replace(" ", "_"), "dc": int(mc2.get_string(2)),
			"ok": mc2.get_string(3), "fail": mc2.get_string(4)}
	var mi := re_interject.search(line)
	if mi != null:
		return {"t": "interject", "selector": mi.get_string(1), "text": mi.get_string(2)}
	var ml := re_line.search(line)
	if ml != null:
		return {"t": "line", "speaker": ml.get_string(1).strip_edges(), "mood": ml.get_string(2), "text": ml.get_string(3)}
	return {}
