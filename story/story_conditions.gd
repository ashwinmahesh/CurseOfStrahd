class_name StoryConditions
extends RefCounted
## Evaluates dialogue and location conditions (docs/contracts/dialogue.md): `flag.x`, `flag.x >= 2`, `class:cleric`,
## `species:elf`, `background:acolyte`, `tag:pious`, `name:ilse_varga`, `item:holy_symbol_amulet`,
## `quest.q == stage`, `quest.q >= stage` (by stage order), `attitude.npc == friendly`, `visited:loc`, `night`,
## `day`, `hour >= 20`, `gold >= 25` (the party's purse), `level >= 3` (the lowest character level in the party),
## `tarokka.drawn`, `tarokka.sword == swords_3`, `tarokka.ally.npc == ezmerelda` (ADR 0010), `guest:ireena`,
## `check.last`, `true`, `false`, with `and`, `or`, `not` and parentheses. An empty condition is true.

var st: StoryState
## When set (the Narrator reacting to someone), class:, species:, tag:, name: and background: terms ask about this
## character rather than anyone in the party.
var actor: Character = null
var _tokens: Array[String] = []
var _i := 0


func _init(state: StoryState) -> void:
	st = state


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
	if t.begins_with("guest:"):
		return t.substr(6) in st.guest_ids
	if t.begins_with("spell:"):
		return st.spell_active(t.substr(6))
	if t == "check.last":
		return st.last_check
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
