class_name StoryConditions
extends RefCounted
## Evaluates dialogue and location conditions (docs/contracts/dialogue.md): `flag.x`, `flag.x >= 2`, `class:cleric`,
## `species:elf`, `background:acolyte`, `tag:pious`, `name:ilse_varga`, `item:holy_symbol_amulet`,
## `quest.q == stage`, `quest.q >= stage` (by stage order), `attitude.npc == friendly`, `visited:loc`, `night`,
## `day`, `hour >= 20`, `gold >= 25` (the party's purse), `level >= 3` (the lowest character level in the party),
## `tarokka.drawn`, `tarokka.sword == swords_3`, `tarokka.ally.npc == ezmerelda` (ADR 0010), `tarokka.enemy.roam`,
## `final_room:<room>` (the room Strahd waits in: the enemy card's, or the roam pick for `mists`, ADR 0014), `guest:ireena`,
## `treasure_at:<place>` (a treasure the reading put there, not yet found) and `gift:<dark gift>` (ADR 0011),
## `approval.thistle >= close` (a companion's approval tier, or a score; story/approval.gd),
## `attention >= marked` (Strahd's attention, a number or a tier; story/strahd_presence.gd), `weather == fog` (where
## the party is; story/weather.gd),
## `leader:name:thistle` (the party member speaking for the party matches the selector after `leader:`),
## `check.last`, `true`, `false`, with `and`, `or`, `not` and parentheses. An empty condition is true.

var st: StoryState
## When set (the Narrator reacting to someone), class:, species:, tag:, name: and background: terms ask about this
## character rather than anyone in the party.
var actor: Character = null
var _tokens: Array[String] = []
var _i := 0


func _init(state: StoryState) -> void:
	st = state


## What a final battle (ADR 0014) needs besides its own `when`: Strahd waits in `room`, the reading's quest has been
## given, and he isn't destroyed.
static func final_battle_condition(room: String) -> String:
	return "final_room:%s and quest.strahds_lair >= foretold and not flag.strahd_destroyed" % room


## A location encounter's full condition: its `when`, and for a `final_battle` the final battle's own.
static func encounter_when(spec: Dictionary) -> String:
	var when := str(spec.get("when", "")).strip_edges()
	var room := str(spec.get("final_battle", ""))
	if room == "":
		return when
	return final_battle_condition(room) if when == "" else "(%s) and %s" % [when, final_battle_condition(room)]


static func check(expr: String, state: StoryState, who: Character = null) -> bool:
	if expr.strip_edges() == "":
		return true
	var c := StoryConditions.new(state)
	c.actor = who
	return c.evaluate(expr)


func evaluate(expr: String) -> bool:
	_tokens = _tokenize(expr)
	_i = 0
	var v := _or()
	return v


static func _tokenize(expr: String) -> Array[String]:
	var out: Array[String] = []
	var i := 0
	while i < expr.length():
		var c := expr[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if c in ["(", ")"]:
			out.append(c)
			i += 1
			continue
		if c in ["=", "!", ">", "<"]:
			var op := c
			if i + 1 < expr.length() and expr[i + 1] == "=":
				op += "="
				i += 1
			out.append(op)
			i += 1
			continue
		if c == "\"":
			var j := expr.find("\"", i + 1)
			if j < 0:
				j = expr.length()
			out.append(expr.substr(i, j - i + 1))
			i = j + 1
			continue
		var start := i
		while i < expr.length() and not expr[i] in [" ", "\t", "(", ")", "=", "!", ">", "<"]:
			i += 1
		out.append(expr.substr(start, i - start))
	return out


func _peek() -> String:
	return _tokens[_i] if _i < _tokens.size() else ""


func _next() -> String:
	var t := _peek()
	_i += 1
	return t


func _or() -> bool:
	var v := _and()
	while _peek() == "or":
		_next()
		var r := _and()
		v = v or r
	return v


func _and() -> bool:
	var v := _not()
	while _peek() == "and":
		_next()
		var r := _not()
		v = v and r
	return v


func _not() -> bool:
	if _peek() == "not":
		_next()
		return not _not()
	if _peek() == "(":
		_next()
		var v := _or()
		if _peek() == ")":
			_next()
		return v
	return _term()


func _term() -> bool:
	var t := _next()
	var op := ""
	var rhs := ""
	if _peek() in ["==", "!=", ">=", "<=", ">", "<", "="]:
		op = _next()
		if op == "=":
			op = "=="
		rhs = _next()
	if t == "true":
		return true
	if t == "false":
		return false
	if t == "night":
		return st.is_night()
	if t == "day":
		return not st.is_night()
	if t == "hour":
		return _compare(st.minute_of_day / 60, op if op != "" else ">=", _literal(rhs) if op != "" else 0)
	if t.begins_with("tarokka."):
		var path := t.substr(8)
		if path == "drawn":
			return not st.tarokka.is_empty()
		var value := Tarokka.field(st, path)
		if op == "":
			return value != ""
		return (value == str(_literal(rhs))) == (op == "==")
	if t.begins_with("final_room:"):
		return Tarokka.final_room(st) == t.substr(11) and t.substr(11) != ""
	if t.begins_with("guest:"):
		return t.substr(6) in st.guest_ids
	if t.begins_with("treasure_at:"):
		return not Tarokka.treasures_at(t.substr(12), st).is_empty()
	if t.begins_with("gift:"):
		for ch in st.party:
			if ch.dark_gifts().has(t.substr(5)):
				return true
		return false
	if t.begins_with("spell:"):
		return st.spell_active(t.substr(6))
	if t.begins_with("at:"):
		return st.location == t.substr(3)
	if t.begins_with("option:"):
		return bool(st.options.get(t.substr(7), false))
	if t == "check.last":
		return st.last_check
	if t == "attention":
		# Strahd's attention (F9): a number, or a tier's name (`attention >= marked`).
		var want: Variant = 0
		if op != "":
			var named := StrahdPresence.tier_min(rhs)
			want = named if named >= 0 else _literal(rhs)
		return _compare(StrahdPresence.attention(st), op if op != "" else ">", want)
	if t == "weather":
		# The weather where the party is (F12, story/weather.gd): `weather == fog`; bare `weather` is anything but overcast.
		var now := Weather.now(st)
		if op == "":
			return now != "overcast"
		return (now == rhs) == (op == "==")
	if t == "gold":
		return _compare(st.gold, op if op != "" else ">", _literal(rhs) if op != "" else 0)
	if t == "level":
		var lowest := 20
		for ch in st.party:
			lowest = mini(lowest, ch.character_level())
		return _compare(lowest, op if op != "" else ">", _literal(rhs) if op != "" else 0)
	if t.begins_with("flag."):
		var value: Variant = st.get_flag(t.substr(5), false)
		if op == "":
			return _truthy(value)
		return _compare(value, op, _literal(rhs))
	if t.begins_with("quest."):
		var qid := t.substr(6)
		var stage := st.quest_stage(qid)
		if op == "":
			return stage != ""
		if op in ["==", "!="]:
			return (stage == rhs) == (op == "==")
		return _compare(st.quest_stage_index(qid, stage), op, st.quest_stage_index(qid, rhs)) and stage != ""
	if t.begins_with("attitude."):
		var att := st.attitude(t.substr(9))
		if op == "":
			return att != "hostile"
		return (att == rhs) == (op == "==")
	if t.begins_with("visited:"):
		return st.visited.has(t.substr(8))
	if t.begins_with("approval."):
		return Approval.compare(st, t.substr(9), op, rhs)
	if t.begins_with("leader:"):
		# The party member speaking for the party: `leader:name:thistle` (so a scene can pick someone else).
		var lead := st.leader_character()
		return lead != null and StoryState.member_matches(lead, t.substr(7))
	if t.contains(":"):
		if t.begins_with("item:"):
			return st.party_has_item(t.substr(5))
		if actor != null:
			return StoryState.member_matches(actor, t)
		return st.find_member(t) != null
	push_warning("Unknown condition term: %s" % t)
	return false


static func _truthy(v: Variant) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return str(v) != ""
	return v != null


static func _literal(s: String) -> Variant:
	if s.begins_with("\""):
		return s.trim_prefix("\"").trim_suffix("\"")
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	return s


static func _compare(a: Variant, op: String, b: Variant) -> bool:
	if (a is int or a is float or a is bool) and (b is int or b is float or b is bool):
		var x := float(a)
		var y := float(b)
		match op:
			"==":
				return x == y
			"!=":
				return x != y
			">=":
				return x >= y
			"<=":
				return x <= y
			">":
				return x > y
			"<":
				return x < y
	match op:
		"==":
			return str(a) == str(b)
		"!=":
			return str(a) != str(b)
	return false
