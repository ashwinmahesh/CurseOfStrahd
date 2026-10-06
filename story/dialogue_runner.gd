class_name DialogueRunner
extends RefCounted
## Plays a conversation from a .dialogue file one beat at a time (plan §5.4, docs/contracts/dialogue.md). The UI
## calls next() and shows what comes back; on an options beat it calls choose(i). Skill checks roll in the open with
## the speaking character's bonus. Effects (flags, quests, items, money, attitudes, milestones) go straight into the
## StoryState; a `combat` line ends the conversation with the encounter to start.
##
## Beats: {kind: "line", speaker_id, name, portrait, mood, text, narrator, party}
##        {kind: "options", options: [{text, label, check: {skill, dc, bonus, chance, who}, enabled}]}
##        {kind: "check", who, skill, dc, total, success, detail, said}
##        {kind: "notice", text}
##        {kind: "end", combat: encounter id or ""}

const ABILITIES := {"strength": &"str", "dexterity": &"dex", "constitution": &"con", "intelligence": &"int",
	"wisdom": &"wis", "charisma": &"cha"}

var st: StoryState
var dice: DiceRoller
var narrator: Narrator = null
var file: DialogueFile = null
var node: String = ""
var pc: int = 0
var finished: bool = false
var combat: String = ""
## The party member speaking for the party (the leader unless an option's tag picks someone).
var speaker: Character = null
var _options: Array[Dictionary] = []
var _pending_jump: String = ""
var _guard: int = 0


func _init(state: StoryState, dice_: DiceRoller, narrator_: Narrator = null) -> void:
	st = state
	dice = dice_
	narrator = narrator_


## Starts at "file_key:node" (e.g. "death_house/rose_thorn:start"). False if it doesn't exist.
func start(ref: String) -> bool:
	speaker = st.leader_character()
	finished = false
	combat = ""
	return _goto(ref)


func _goto(ref: String) -> bool:
	if ref == "END" or ref == "":
		finished = true
		return true
	var file_key := file.key if file != null else ""
	var target := ref
	if ref.contains("/") and ref.contains(":"):
		file_key = ref.substr(0, ref.rfind(":"))
		target = ref.substr(ref.rfind(":") + 1)
	elif ref.contains(":") and file == null:
		file_key = ref.substr(0, ref.rfind(":"))
		target = ref.substr(ref.rfind(":") + 1)
	var f := DialogueFile.load_key(file_key) if file == null or file.key != file_key else file
	if f == null or not f.nodes.has(target):
		push_warning("Dialogue: no node '%s'" % ref)
		finished = true
		return false
	file = f
	node = target
	pc = 0
	return true


func _stmts() -> Array[Dictionary]:
	return file.nodes[node] as Array[Dictionary]


## The next beat. Options stay on screen until choose() is called.
func next() -> Dictionary:
	if not _options.is_empty():
		return _options_beat()
	if _pending_jump != "":
		var j := _pending_jump
		_pending_jump = ""
		_goto(j)
	_guard = 0
	while true:
		_guard += 1
		if _guard > 5000:
			push_warning("Dialogue: runaway loop in %s:%s" % [file.key, node])
			finished = true
		if finished:
			return {"kind": "end", "combat": combat}
		var list := _stmts()
		if pc >= list.size():
			finished = true
			continue
		var s := list[pc]
		match str(s["t"]):
			"line":
				pc += 1
				return _line_beat(str(s["speaker"]), str(s["mood"]), str(s["text"]))
			"interject":
				pc += 1
				var who := st.find_member(str(s["selector"]))
				if who == null:
					continue
				return _party_line(who, str(s["text"]))
			"option":
				_collect_options()
				if _options.is_empty():
					continue
				return _options_beat()
			"jump":
				_goto(str(s["to"]))
			"if":
				if StoryConditions.check(str(s["cond"]), st):
					pc += 1
				else:
					_skip_branch()
			"elif", "else":
				_skip_to_endif()
			"endif":
				pc += 1
			"set":
				_apply_set(s)
				pc += 1
			"quest":
				pc += 1
				if st.set_quest_stage(str(s["id"]), str(s["stage"])):
					return {"kind": "notice", "text": "Journal updated: %s" % Compendium.shared().display_name("quests", str(s["id"]))}
			"give":
				pc += 1
				st.give_item(str(s["item"]), int(s["qty"]), speaker)
				return {"kind": "notice", "text": "%s receives %s%s" % [_first(speaker), Compendium.shared().display_name("items", str(s["item"])),
					" ×%d" % int(s["qty"]) if int(s["qty"]) > 1 else ""]}
			"take":
				pc += 1
				var n := st.take_item(str(s["item"]), int(s["qty"]))
				if n > 0:
					return {"kind": "notice", "text": "Gave away %s%s" % [Compendium.shared().display_name("items", str(s["item"])), " ×%d" % n if n > 1 else ""]}
			"gold":
				pc += 1
				var amount := float(s["amount"])
				st.gold = maxf(0.0, st.gold + amount)
				return {"kind": "notice", "text": ("Gained %d gp" if amount >= 0 else "Paid %d gp") % absi(roundi(amount))}
			"attitude":
				pc += 1
				st.attitudes[str(s["npc"])] = str(s["value"])
				return {"kind": "notice", "text": "%s is now %s" % [Compendium.shared().display_name("npcs", str(s["npc"])), s["value"]]}
			"xp":
				pc += 1
				var key := "_xp/%s:%s:%d" % [file.key, node, int(s["n"])]
				if not st.flags.has(key):
					st.flags[key] = true
					st.milestones += 1
					return {"kind": "notice", "text": "Milestone: the party can advance to level %d" % st.target_level()}
			"check":
				pc += 1
				var who2 := _best_for(str(s["skill"]))
				var beat := _roll(who2, str(s["skill"]), int(s["dc"]), "")
				_pending_jump = str(s["ok"]) if bool(beat["success"]) or str(s["fail"]) == "" else str(s["fail"])
				return beat
			"combat":
				combat = str(s["encounter"])
				finished = true
			"narrate":
				pc += 1
				if narrator != null:
					var text := narrator.line(str(s["key"]), st, speaker)
					if text != "":
						return _line_beat("Narrator", "", text)
			_:
				pc += 1
	return {"kind": "end", "combat": combat}


## Picks option `i` of the current menu. Returns the check beat for skill-check options, otherwise the next beat.
func choose(i: int) -> Dictionary:
	if i < 0 or i >= _options.size():
		return next()
	var opt := _options[i]
	_options.clear()
	var who := opt["who"] as Character
	if who != null:
		speaker = who
	var check := opt["check"] as Dictionary
	if not check.is_empty():
		var beat := _roll(speaker, str(check["skill"]), int(check["dc"]), str(opt["text"]))
		_pending_jump = str(opt["ok"]) if bool(beat["success"]) or str(opt["fail"]) == "" else str(opt["fail"])
		return beat
	_pending_jump = str(opt["ok"])
	return next()


func _collect_options() -> void:
	_options.clear()
	var list := _stmts()
	while pc < list.size():
		var s := list[pc]
		var t := str(s["t"])
		if t == "option":
			pc += 1
			if not StoryConditions.check(str(s["cond"]), st):
				continue
			var who: Character = null
			if str(s["selector"]) != "":
				who = st.find_member(str(s["selector"]))
				if who == null:
					continue
			var shown := who if who != null else speaker
			var check := s["check"] as Dictionary
			var info := {}
			if not check.is_empty() and shown != null:
				var bonus := _bonus(shown, str(check["skill"]))
				var dc := int(check["dc"])
				info = {"skill": str(check["skill"]), "dc": dc, "bonus": bonus,
					"chance": clampf((21.0 - (dc - bonus)) / 20.0, 0.05, 1.0), "who": shown.name}
			var tags := ""
			for tag: String in s["tags"]:
				tags += "[%s] " % tag
			var label := "%s%s" % ["[%s DC %d] " % [str(check["skill"]).replace("_", " ").capitalize(), int(check["dc"])] if not check.is_empty() else "", tags]
			_options.append({"text": str(s["text"]), "label": label.strip_edges(), "ok": str(s["ok"]), "fail": str(s["fail"]),
				"check": check, "check_info": info, "who": who, "enabled": true})
		elif t in ["if", "elif", "else", "endif"]:
			if t == "if":
				if StoryConditions.check(str(s["cond"]), st):
					pc += 1
				else:
					_skip_branch()
			elif t == "endif":
				pc += 1
			else:
				_skip_to_endif()
		else:
			break


func _options_beat() -> Dictionary:
	var out: Array[Dictionary] = []
	for o in _options:
		out.append({"text": o["text"], "label": o["label"], "check": o["check_info"], "enabled": o["enabled"],
			"who": (o["who"] as Character).name if o["who"] != null else ""})
	return {"kind": "options", "options": out}


## From a false `if` (or `elif`): moves to the next branch that holds, or past the matching endif.
func _skip_branch() -> void:
	var list := _stmts()
	var depth := 0
	var j := pc + 1
	while j < list.size():
		var t := str(list[j]["t"])
		if t == "if":
			depth += 1
		elif t == "endif":
			if depth == 0:
				pc = j + 1
				return
			depth -= 1
		elif depth == 0 and t == "elif":
			if StoryConditions.check(str(list[j]["cond"]), st):
				pc = j + 1
				return
		elif depth == 0 and t == "else":
			pc = j + 1
			return
		j += 1
	pc = list.size()


func _skip_to_endif() -> void:
	var list := _stmts()
	var depth := 0
	var j := pc + 1
	while j < list.size():
		var t := str(list[j]["t"])
		if t == "if":
			depth += 1
		elif t == "endif":
			if depth == 0:
				pc = j + 1
				return
			depth -= 1
		j += 1
	pc = list.size()


func _apply_set(s: Dictionary) -> void:
	var flag := str(s["flag"])
	var value: Variant = s["value"]
	match str(s["op"]):
		"+=":
			st.set_flag(flag, float(st.get_flag(flag, 0)) + float(value) if value is float else int(st.get_flag(flag, 0)) + int(value))
		"-=":
			st.set_flag(flag, int(st.get_flag(flag, 0)) - int(value))
		_:
			st.set_flag(flag, value)


func _line_beat(speaker_name: String, mood: String, text: String) -> Dictionary:
	var low := speaker_name.to_lower()
	if low == "narrator":
		return {"kind": "line", "speaker_id": "narrator", "name": "Narrator", "portrait": "", "mood": "", "text": _fill(text), "narrator": true, "party": false}
	if low == "player":
		return _party_line(speaker, text)
	var npc := _npc_for(low)
	var nid := str(npc.get("id", low))
	var portrait := str(npc.get("portrait", nid))
	if mood != "" and mood != "neutral" and ResourceLoader.exists("res://art/portraits/%s_%s.png" % [portrait, mood]):
		portrait = "%s_%s" % [portrait, mood]
	return {"kind": "line", "speaker_id": nid, "name": str(npc.get("name", speaker_name)), "portrait": portrait, "mood": mood,
		"text": _fill(text), "narrator": false, "party": false}


func _party_line(who: Character, text: String) -> Dictionary:
	if who == null:
		return {"kind": "line", "speaker_id": "player", "name": "You", "portrait": "", "mood": "", "text": _fill(text), "narrator": false, "party": true}
	var look := str((who.build.get("appearance", {}) as Dictionary).get("art", ""))
	return {"kind": "line", "speaker_id": who.id, "name": who.name, "portrait": look if look != "" else who.name.to_snake_case(), "mood": "",
		"text": _fill(text), "narrator": false, "party": true}


static func _npc_for(low: String) -> Dictionary:
	var comp := Compendium.shared()
	var direct := comp.get_entry("npcs", low.replace(" ", "_"))
	if not direct.is_empty():
		return direct
	for n in comp.all("npcs"):
		var name := str(n.get("name", "")).to_lower()
		if name == low or name.get_slice(" ", 0) == low:
			return n
	return {}


func _fill(text: String) -> String:
	var who := speaker if speaker != null else st.leader_character()
	return text.replace("{name}", _first(who)).replace("{leader}", _first(st.leader_character()))


static func _first(ch: Character) -> String:
	return ch.name.get_slice(" ", 0) if ch != null else "you"


static func _skill_key(skill: String) -> StringName:
	if ABILITIES.has(skill):
		return ABILITIES[skill] as StringName
	return StringName(skill)


static func _bonus(ch: Character, skill: String) -> int:
	var key := _skill_key(skill)
	if Abilities.SKILLS.has(key):
		return ch.skill_bonus(key).total()
	return ch.ability_check_bonus(key).total()


func _best_for(skill: String) -> Character:
	var best: Character = null
	for ch in st.party:
		if ch.hp <= 0:
			continue
		if best == null or _bonus(ch, skill) > _bonus(best, skill):
			best = ch
	return best if best != null else speaker


func _roll(who: Character, skill: String, dc: int, said: String) -> Dictionary:
	if who == null:
		st.last_check = false
		return {"kind": "check", "who": "Nobody", "skill": skill, "dc": dc, "total": 0, "success": false, "detail": "", "said": said}
	var test := who.roll_check(dice, _skill_key(skill), dc)
	st.last_check = test.success
	return {"kind": "check", "who": who.name, "skill": skill.replace("_", " ").capitalize(), "dc": dc, "total": test.total,
		"success": test.success, "detail": test.describe(), "said": said}
