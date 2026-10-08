class_name DialogueRunner
extends RefCounted
## Plays a conversation from a .dialogue file one beat at a time (plan §5.4, docs/contracts/dialogue.md). The UI
## calls next() and shows what comes back; on an options beat it calls choose(i). Skill checks roll in the open with
## the speaking character's bonus. Effects (flags, quests, items, money, attitudes, milestones) go straight into the
## StoryState; a `combat` line ends the conversation with the encounter to start.
##
## Beats: {kind: "line", speaker_id, name, portrait, mood, text, narrator, party}
##        {kind: "options", options: [{text, label, check: {skill, dc, bonus, chance, who}, enabled}]}
##        {kind: "check", who, portrait, skill, dc, total, success, detail, said}
##        {kind: "notice", text}
##        {kind: "cutscene", id, image, focus}: a full-screen picture under what follows (id "" takes it away)
##        {kind: "end", combat: encounter id or "", end_game: the conversation ended the campaign (`end_game`)}

## The Narrator's portrait (art/portraits/narrator.png), on their lines here and in the exploration box.
const NARRATOR_PORTRAIT := "narrator"
const ABILITIES := {"strength": &"str", "dexterity": &"dex", "constitution": &"con", "intelligence": &"int",
	"wisdom": &"wis", "charisma": &"cha"}

## The way back out of each party picker (its last option).
const BACK_OUT := {"sacrifice": "No one. Not this.", "respec": "Never mind. No one sits."}

var st: StoryState
var dice: DiceRoller
var narrator: Narrator = null
var file: DialogueFile = null
var node: String = ""
var pc: int = 0
var finished: bool = false
var combat: String = ""
## The conversation reached `end_game` (ADR 0014): the campaign's ending is recorded (Endings) and the game shows it.
var ended_game: bool = false
## The party member speaking for the party (the leader unless an option's tag picks someone).
var speaker: Character = null
var _options: Array[Dictionary] = []
var _pending_jump: String = ""
var _guard: int = 0
var _picking := false       ## waiting for the player to choose a party member (`sacrifice`, `respec`)
var _pick_purpose := "sacrifice"
var _gift := ""                ## the dark gift on offer (`dark_gift`)
var _last_option_key := ""     ## the spent-option key of the last social check (see choose)
var _last_check: Dictionary = {}        ## {who, test, skill, said} of the last check rolled
var _check_jumps: Array[String] = []    ## [ok, fail] targets of the last check
var _queued: Array[Dictionary] = []   ## beats a statement produced beyond its first (a Tarokka card, then the verse)
## The NPC being spoken to (shops open for them).
var npc_id: String = ""


func _init(state: StoryState, dice_: DiceRoller, narrator_: Narrator = null) -> void:
	st = state
	dice = dice_
	narrator = narrator_


## Starts at "file_key:node" (e.g. "death_house/rose_thorn:start"). False if it doesn't exist.
func start(ref: String) -> bool:
	speaker = st.leader_character()
	_queued.clear()
	_picking = false
	finished = false
	combat = ""
	ended_game = false
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
	if _picking:
		return _pick_beat()
	if not _queued.is_empty():
		return _queued.pop_front()
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
			return {"kind": "end", "combat": combat, "end_game": ended_game}
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
				var sel := str(s["selector"])
				if sel.begins_with("guest:"):
					# A story ally travelling with the party says it (Ireena on the road).
					if sel.substr(6) in st.guest_ids:
						return _line_beat(sel.substr(6), "", str(s["text"]))
					continue
				var who := st.find_member(sel)
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
				var taker := speaker
				if str(s.get("to", "")) != "" and st.find_member(str(s["to"])) != null:
					taker = st.find_member(str(s["to"]))
				st.give_item(str(s["item"]), int(s["qty"]), taker)
				return {"kind": "notice", "text": "%s receives %s%s" % [_first(taker), Compendium.shared().display_name("items", str(s["item"])),
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
				_check_jumps = [str(s["ok"]), str(s["fail"])]
				_pending_jump = str(s["ok"]) if bool(beat["success"]) or str(s["fail"]) == "" else str(s["fail"])
				return beat
			"combat":
				combat = str(s["encounter"])
				finished = true
			"time":
				pc += 1
				st.advance_minutes(int(s["minutes"]))
			"time_until":
				pc += 1
				var target := int(s["hour"]) * 60
				var wait := target - st.minute_of_day
				if wait <= 0:
					wait += 24 * 60
				st.advance_minutes(wait)
			"tarokka_draw":
				pc += 1
				Tarokka.ensure_drawn(st)
			"tarokka_read":
				pc += 1
				var slot := str(s["slot"])
				Tarokka.ensure_drawn(st)
				var card_id := str(st.tarokka.get(slot, ""))
				if card_id == "":
					continue
				var o := Tarokka.outcome(slot, card_id)
				_queued.append(_line_beat(str(s["speaker"]), "", str(o.get("verse", ""))))
				return {"kind": "notice", "text": "%s: %s" % [Tarokka.SLOT_NAMES.get(slot, slot), Tarokka.card(card_id).get("name", card_id)],
					"card": card_id, "slot": slot}
			"tarokka_give":
				pc += 1
				# The treasures the reading hid here, handed to the party's leader (ADR 0011).
				var got := Tarokka.take_from(str(s["place"]), st)
				if got.is_empty():
					continue
				var taker := st.leader_character()
				for item in got:
					st.give_item(item, 1, taker)
				for item: Variant in got.slice(1):
					_queued.append({"kind": "notice", "text": "%s receives %s" % [_first(taker), Compendium.shared().display_name("items", str(item))]})
				var found := {"kind": "notice", "text": "%s receives %s" % [_first(taker), Compendium.shared().display_name("items", got[0])]}
				# The treasure's own picture first (story/cutscenes.gd `find:<item>`), the notices over it.
				for item in got:
					var cut := Cutscenes.for_trigger("find:" + item, st)
					if cut != "":
						Cutscenes.mark_played(cut, st)
						_queued.push_front(found)
						return {"kind": "cutscene", "id": cut, "image": Cutscenes.image(cut, st), "focus": Cutscenes.focus(cut)}
				return found
			"dark_gift":
				pc += 1
				if Compendium.shared().has("dark_gifts", str(s["gift"])) and not _living().is_empty():
					_picking = true
					_pick_purpose = "dark_gift"
					_gift = str(s["gift"])
					return _pick_beat()
			"shop", "services":
				pc += 1
				if npc_id != "":
					return {"kind": str(s["t"]), "npc": npc_id}
			"appear", "vanish":
				pc += 1
				return {"kind": "stage", "what": str(s["t"]), "npc": str(s["npc"]), "at": str(s.get("at", ""))}
			"join":
				pc += 1
				if st.add_guest(str(s["npc"])):
					return {"kind": "notice", "text": "%s joins the party" % Compendium.shared().display_name("npcs", str(s["npc"]))}
			"leave":
				pc += 1
				if st.remove_guest(str(s["npc"])):
					return {"kind": "notice", "text": "%s leaves the party" % Compendium.shared().display_name("npcs", str(s["npc"]))}
			"sacrifice":
				pc += 1
				st.last_check = true   # skipped with one left alive: the scene goes on as before
				if _living().size() >= 2:
					_picking = true
					_pick_purpose = "sacrifice"
					return _pick_beat()
			"respec":
				pc += 1
				st.last_check = false   # skipped (respec switched off): nobody was rebuilt
				if bool(st.options.get("respec", true)) and not _living().is_empty():
					_picking = true
					_pick_purpose = "respec"
					return _pick_beat()
			"approve", "inspire":
				# Companion approval (story/approval.gd) and Heroic Inspiration for playing in character
				# (story/in_character.gd). Each statement counts once a playthrough, however often its node runs.
				pc += 1
				var once := "_%s/%s:%s:%d" % [str(s["t"]), file.key, node, int(s["n"])]
				if st.flags.has(once):
					continue
				st.flags[once] = true
				var said := Approval.react(st, s["changes"] as Array, str(s["why"])) if str(s["t"]) == "approve" \
					else InCharacter.award(st, str(s["selector"]), str(s["why"]))
				if said != "":
					return {"kind": "notice", "text": said, "approval": str(s["t"]) == "approve"}
			"narrate":
				pc += 1
				if narrator != null:
					var text := narrator.line(str(s["key"]), st, speaker)
					if text != "":
						return _line_beat("Narrator", "", text)
			"cutscene":
				# A full-screen picture behind the lines that follow (story/cutscenes.gd); `cutscene end` takes it away.
				pc += 1
				var cut := "" if str(s["id"]) == "end" else str(s["id"])
				var img := Cutscenes.image(cut, st) if cut != "" else ""
				if cut == "" or img != "":
					return {"kind": "cutscene", "id": cut, "image": img, "focus": Cutscenes.focus(cut)}
			"end_game":
				# The campaign ends here (ADR 0014): the ending that holds now is recorded; the game plays it when the
				# conversation closes.
				Endings.request(st)
				ended_game = true
				finished = true
			_:
				pc += 1
	return {"kind": "end", "combat": combat, "end_game": ended_game}


func _living() -> Array[Character]:
	var out: Array[Character] = []
	for ch in st.party:
		if not ch.dead:
			out.append(ch)
	return out


func _pick_beat() -> Dictionary:
	var names: Array[String] = []
	for ch in _living():
		names.append(ch.name)
	var text := "Choose who it will be. They will not come back." if _pick_purpose == "sacrifice" \
		else "Whose fate will the cards read anew? (They return to level 1 and are built again; they keep their belongings.)"
	if _pick_purpose == "dark_gift":
		var g := Compendium.shared().get_entry("dark_gifts", _gift)
		text = "Who accepts %s? %s It can never be given back." % [g.get("name", _gift), g.get("summary", "")]
		names.append("No one")
	else:
		names.append(BACK_OUT[_pick_purpose])   # every picker has a way back (owner, 2026-10-08)
	return {"kind": "pick_member", "text": text, "members": names, "purpose": _pick_purpose}


## Answers a `pick_member` beat: the `i`th living party member is the one (sacrificed, rebuilt or given the gift).
## The option after them backs out: no one is picked, `check.last` is false and the conversation goes on, so the
## dialogue can return to its menu. Picking someone sets `check.last` true.
func pick_member(i: int) -> Dictionary:
	var living := _living()
	if _picking and _pick_purpose == "dark_gift" and i == living.size():
		_picking = false
		st.set_flag("refused_" + _gift, true)
		return {"kind": "notice", "text": "No one takes it."}
	if _picking and i == living.size():
		_picking = false
		st.last_check = false
		return next()
	if not _picking or i < 0 or i >= living.size():
		return next()
	_picking = false
	st.last_check = true
	var ch := living[i]
	if _pick_purpose == "dark_gift":
		ch.accept_dark_gift(_gift)
		return {"kind": "notice", "text": "%s accepts %s." % [ch.name, Compendium.shared().display_name("dark_gifts", _gift)]}
	if _pick_purpose == "respec":
		return {"kind": "respec", "index": st.party.find(ch), "name": ch.name}
	st.lose_member(ch, "gave their life on the altar beneath Death House")
	speaker = st.leader_character()
	return {"kind": "notice", "text": "%s is gone." % ch.name}


## Picks option `i` of the current menu. Returns the check beat for skill-check options, otherwise the next beat.
func choose(i: int) -> Dictionary:
	if i < 0 or i >= _options.size():
		return next()
	var opt := _options[i]
	if not bool(opt["enabled"]):
		return _options_beat()
	_options.clear()
	var who := opt["who"] as Character
	if who != null:
		speaker = who
	var check := opt["check"] as Dictionary
	if not check.is_empty():
		var beat := _roll(speaker, str(check["skill"]), int(check["dc"]), str(opt["text"]))
		_check_jumps = [str(opt["ok"]), str(opt["fail"])]
		_pending_jump = str(opt["ok"]) if bool(beat["success"]) or str(opt["fail"]) == "" else str(opt["fail"])
		# Owner rule (2026-10-06): a failed Persuasion, Intimidation, Deception, Performance or Insight attempt is spent;
		# the option doesn't come back (they won't fall for it twice, and a read face doesn't change).
		_last_option_key = _spent_key(str(opt["text"])) if _social(str(check["skill"])) else ""
		if _last_option_key != "" and not bool(beat["success"]):
			st.flags[_last_option_key] = true
		return beat
	_pending_jump = str(opt["ok"])
	return next()


## Skills whose failed attempt can't be repeated (owner, 2026-10-06): talking someone round, and reading them.
const SOCIAL_SKILLS: Array[String] = ["persuasion", "intimidation", "deception", "performance", "insight"]


static func _social(skill: String) -> bool:
	return skill.to_lower().replace(" ", "_") in SOCIAL_SKILLS


## Where a failed social attempt is remembered: an internal flag per conversation node and option (saved).
func _spent_key(option_text: String) -> String:
	return "_failed/%s:%s:%s" % [file.key if file != null else "", node, option_text]


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
			var spent_check := s["check"] as Dictionary
			if not spent_check.is_empty() and _social(str(spent_check["skill"])) and st.flags.has(_spent_key(str(s["text"]))):
				continue
			var who: Character = null
			if str(s["selector"]) != "":
				who = st.find_member(str(s["selector"]))
				if who == null:
					continue
			var check := s["check"] as Dictionary
			var info := _check_info(who if who != null else speaker, check)
			var tags := ""
			for tag: String in s["tags"]:
				tags += "[%s] " % tag
			var label := "%s%s" % ["[%s DC %d] " % [str(check["skill"]).replace("_", " ").capitalize(), int(check["dc"])] if not check.is_empty() else "", tags]
			# A purchase: an option whose node starts by paying is greyed out when the purse can't cover it.
			var price := _price_of(str(s["ok"]))
			var enabled := price <= 0.0 or st.gold >= price
			if not enabled:
				label = (label + " [%d gp]" % roundi(price)).strip_edges()
			_options.append({"text": str(s["text"]), "label": label.strip_edges(), "ok": str(s["ok"]), "fail": str(s["fail"]),
				"check": check, "check_info": info, "who": who, "enabled": enabled,
				"reason": "" if enabled else "Not enough gold"})
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


## An option's check as the menu shows it: who rolls, their bonus and the chance.
func _check_info(shown: Character, check: Dictionary) -> Dictionary:
	if check.is_empty() or shown == null:
		return {}
	var bonus := _bonus(shown, str(check["skill"]))
	var dc := int(check["dc"])
	return {"skill": str(check["skill"]), "dc": dc, "bonus": bonus,
		"chance": clampf((21.0 - (dc - bonus)) / 20.0, 0.05, 1.0), "who": shown.name}


## Q13: the player picks who speaks for the party. Party lines and the menu's checks (those no tag gives to someone
## else) go to them, and the options on screen show their bonus and chance.
func set_speaker(who: Character) -> void:
	if who == null or who.dead:
		return
	speaker = who
	for o in _options:
		if o["who"] == null:
			o["check_info"] = _check_info(who, o["check"] as Dictionary)


## What going to `ref` costs: the gold paid by its first statements (before any line or option), or 0.
func _price_of(ref: String) -> float:
	if ref == "END" or ref.contains(":"):
		return 0.0
	var list := file.nodes.get(ref, []) as Array
	for st_: Variant in list:
		var d := st_ as Dictionary
		match str(d["t"]):
			"gold":
				return maxf(0.0, -float(d["amount"]))
			"set", "give", "take", "quest", "attitude":
				continue
		break
	return 0.0


func _options_beat() -> Dictionary:
	var out: Array[Dictionary] = []
	for o in _options:
		out.append({"text": o["text"], "label": o["label"], "check": o["check_info"], "enabled": o["enabled"],
			"reason": o["reason"],
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
		return {"kind": "line", "speaker_id": "narrator", "name": "Narrator", "portrait": NARRATOR_PORTRAIT, "mood": "", "text": _fill(text),
			"narrator": true, "party": false}
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
	return {"kind": "line", "speaker_id": who.id, "name": who.name, "portrait": portrait_of(who), "mood": "",
		"text": _fill(text), "narrator": false, "party": true}


## A party member's portrait (art/portraits/<id>.png): the look picked in the creator, else one named after them.
static func portrait_of(who: Character) -> String:
	var look := str((who.build.get("appearance", {}) as Dictionary).get("art", ""))
	return look if look != "" else who.name.to_snake_case()


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
	var test := who.roll_check(dice, _skill_key(skill), dc, CheckAids.before_check(who, _skill_key(skill)))
	st.last_check = test.success
	_last_check = {"who": who, "test": test, "skill": skill, "said": said}
	return _check_beat()


## The beat for the last check, with what the roller could still spend on it (CheckAids).
func _check_beat() -> Dictionary:
	var who := _last_check["who"] as Character
	var test := _last_check["test"] as D20Test
	var parts: Array = []
	if test.breakdown != null:
		for part: Dictionary in test.breakdown.parts:
			parts.append({"label": str(part["label"]), "value": int(part["value"])})
	return {"kind": "check", "who": who.name, "portrait": portrait_of(who),
		"skill": str(_last_check["skill"]).replace("_", " ").capitalize(), "dc": test.target, "total": test.total, "success": test.success, "detail": test.describe(), "said": str(_last_check["said"]),
		"aids": CheckAids.options(who, test),
		# The dice themselves, for the big d20 (G11): both dice under Advantage or Disadvantage, the one kept, the bonuses.
		"rolls": test.rolls.duplicate(), "kept": test.kept, "modifier": test.modifier, "parts": parts, "extra": test.extra,
		"extra_label": test.extra_label, "advantage": test.advantage, "disadvantage": test.disadvantage,
		"auto_failed": test.auto_failed}


## Spends an aid on the last (failed) check: Heroic Inspiration or Tactical Mind. The branch follows the new result.
func use_aid(id: String) -> Dictionary:
	if _last_check.is_empty():
		return next()
	var test := CheckAids.apply(id, _last_check["who"] as Character, _last_check["test"] as D20Test, dice)
	st.last_check = test.success
	if test.success and _last_option_key != "":
		st.flags.erase(_last_option_key)
	if _check_jumps.size() == 2:
		_pending_jump = str(_check_jumps[0]) if test.success or str(_check_jumps[1]) == "" else str(_check_jumps[1])
	return _check_beat()
