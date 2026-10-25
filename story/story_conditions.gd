class_name StoryConditions
extends RefCounted
## Evaluates dialogue and location conditions (docs/contracts/dialogue.md): `flag.x`, `flag.x >= 2`, `class:cleric`,
## `species:elf`, `background:acolyte`, `tag:pious`, `name:ilse_varga`, `item:holy_symbol_amulet`,
## `quest.q == stage`, `quest.q >= stage` (by stage order), `quest_days.q >= 3` (whole days since the quest last
## moved; never true before it begins), `days_since.flag >= 2` (whole days since a flag was stamped with `set flag = now`;
## never true while it isn't), `attitude.npc == friendly`, `visited:loc`, `night`,
## `day`, `hour >= 20`, `gold >= 25` (the party's purse), `level >= 3` (the lowest character level in the party),
## `tarokka.drawn`, `tarokka.sword == swords_3`, `tarokka.ally.npc == ezmerelda` (ADR 0010), `tarokka.enemy.roam`,
## `final_room:<room>` (the room Strahd waits in: the enemy card's, or the roam pick for `mists`, ADR 0014), `guest:ireena`,
## `treasure_at:<place>` (a treasure the reading put there, not yet found) and `gift:<dark gift>` (ADR 0011),
## `gifted:liriel_dawnsong` (that hero, by pregen id, has taken a dark gift), `fallen:thistle` (that hero is lost for good:
## StoryState.fallen, the altar beneath Death House or the Deck of Many Things),
## `approval.thistle >= close` (a companion's approval tier, or a score; story/approval.gd),
## `attention >= marked` (Strahd's attention, a number or a tier; story/strahd_presence.gd), `weather == fog` (where
## the party is; story/weather.gd), `indoors` (the party's map is under a roof or a dungeon: CampSite.setting; a night's
## line written for sleeping behind walls carries it, so an outdoor camp doesn't say it),
## `leader:name:thistle` (the party member speaking for the party matches the selector after `leader:`),
## `hero_named:vesper` (any party member is called that, whoever speaks; the name a player typed for a custom hero),
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
## given, and he isn't destroyed, or already beaten and misted down to his coffin (Wiki finding 69: only the catacombs'
## final battles asked, so the chapel's or the study's could start again with him in it).
static func final_battle_condition(room: String) -> String:
	return "final_room:%s and quest.strahds_lair >= foretold and not flag.strahd_destroyed and not flag.strahd_in_coffin" % room


## A region's truce (owner, 2026-10-15): while it holds, the region's fights that start on their own as the party walks
## into a room wait, and come back once it ends. Fights the party starts (by a word, by opening or breaking something,
## a check gone wrong) still come. Each truce holds `while` its condition does, until the party leaves the region
## (note_departure sets its `over` flag, for good). Castle Ravenloft: Strahd's invited guests are not set on by his
## house until dinner is over, thanked or affronted, or until they leave the castle (owner, 2026-10-15: "end it once
## they leave Castle Ravenloft ... when they return, it's back to how it was"; docs/regions/castle_ravenloft_gates.md §8).
const TRUCES := {"castle_ravenloft": {"while": "flag.strahd_invitation == \"accepted\" and not flag.castle_dinner",
	"over": "castle_truce_over"}}


## The condition `region`'s truce holds under ("" for a region without one).
static func truce_condition(region: String) -> String:
	if not TRUCES.has(region):
		return ""
	var t := TRUCES[region] as Dictionary
	return "(%s) and not flag.%s" % [t["while"], t["over"]]


## Whether `region`'s truce holds now.
static func truce_holds(region: String, state: StoryState) -> bool:
	return TRUCES.has(region) and check(truce_condition(region), state)


## The party moves from location `from_id` to a location in `region`: leaving a region whose truce holds ends that
## truce for good (its `over` flag), so coming back finds the place's fights as they were.
static func note_departure(state: StoryState, from_id: String, region: String) -> void:
	var from_region := str(Compendium.shared().get_entry("locations", from_id).get("region", "")) if from_id != "" else ""
	if from_region != region and truce_holds(from_region, state):
		state.set_flag(str((TRUCES[from_region] as Dictionary)["over"]), true)


## A location encounter's full condition: its `when`, and for a `final_battle` the final battle's own. Given the
## location's `region`, a fight that starts as the party walks in also waits out the region's truce (TRUCES); without
## it, the condition picks which of a fight's entries is the one, as before.
static func encounter_when(spec: Dictionary, region: String = "") -> String:
	var when := str(spec.get("when", "")).strip_edges()
	var room := str(spec.get("final_battle", ""))
	if room != "":
		when = final_battle_condition(room) if when == "" else "(%s) and %s" % [when, final_battle_condition(room)]
	if TRUCES.has(region) and str(spec.get("trigger", "")).begins_with("enter_area:"):
		var truce := truce_condition(region)
		when = "not (%s)" % truce if when == "" else "(%s) and not (%s)" % [when, truce]
	return when


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
	if t == "indoors":
		return st.location != "" and CampSite.setting(Compendium.shared().get_entry("locations", st.location)) == CampSite.INDOORS
	if t == "hour":
		return _compare(st.minute_of_day / 60, op if op != "" else ">=", _literal(rhs) if op != "" else 0)
	if t.begins_with("tarokka."):
		var path := t.substr(8)
		if path == "drawn":
			return not st.tarokka.is_empty()
		var value := Campaign.module().field(st, path)
		if op == "":
			return value != ""
		return (value == str(_literal(rhs))) == (op == "==")
	if t.begins_with("final_room:"):
		return Campaign.module().final_room(st) == t.substr(11) and t.substr(11) != ""
	if t.begins_with("guest:"):
		return t.substr(6) in st.guest_ids
	if t.begins_with("treasure_at:"):
		return not Campaign.module().treasures_at(t.substr(12), st).is_empty()
	if t.begins_with("gift:"):
		for ch in st.party:
			if ch.dark_gifts().has(t.substr(5)):
				return true
		return false
	if t.begins_with("gifted:"):
		# A hero who has taken a dark gift, by pregen id (a custom hero never answers for one: member_matches).
		for ch in st.party:
			if StoryState.member_matches(ch, "name:" + t.substr(7)) and not ch.dark_gifts().is_empty():
				return true
		return false
	if t.begins_with("fallen:"):
		# A hero lost for good (StoryState.lose_member), by pregen id: their personal quest can't be finished.
		for f: Dictionary in st.fallen:
			if str(f.get("id", "")) == t.substr(7):
				return true
		return false
	if t.begins_with("spell:"):
		return st.spell_active(t.substr(6))
	if t.begins_with("at:"):
		return st.location == t.substr(3)
	if t.begins_with("region:"):
		# Anywhere in a region (data/locations/*.json `region`): `region:castle_ravenloft` for any of its parts.
		return st.location != "" and str(Compendium.shared().get_entry("locations", st.location).get("region", "")) == t.substr(7)
	if t.begins_with("option:"):
		return bool(st.options.get(t.substr(7), false))
	if t == "check.last":
		return st.last_check
	if t == "attention":
		# Strahd's attention (F9): a number, or a tier's name (`attention >= marked`).
		var want: Variant = 0
		if op != "":
			var named := Campaign.module().presence_tier_min(rhs)
			want = named if named >= 0 else _literal(rhs)
		return _compare(Campaign.module().presence_attention(st), op if op != "" else ">", want)
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
	if t.begins_with("quest_days."):
		var passed := st.quest_days(t.substr(11))
		return passed >= 0 and _compare(passed, op if op != "" else ">", _literal(rhs) if op != "" else 0)
	if t.begins_with("days_since."):
		var gone := st.days_since(t.substr(11))
		return gone >= 0 and _compare(gone, op if op != "" else ">", _literal(rhs) if op != "" else 0)
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
	if t.begins_with("hero_named:"):
		return hero_named(st, t.substr(11))
	if t.contains(":"):
		if t.begins_with("item:"):
			return st.party_has_item(t.substr(5))
		if actor != null:
			return StoryState.member_matches(actor, t)
		return st.find_member(t) != null
	push_warning("Unknown condition term: %s" % t)
	return false


## `hero_named:<name>`: some party member goes by that name, whoever is speaking. It reads the name a player typed for a
## custom hero. Case doesn't matter; the whole name or its first word will do (`vesper` is "Vesper Brightwater"), and a
## `_` stands for a space (`vesper_brightwater`).
static func hero_named(state: StoryState, wanted: String) -> bool:
	var want := wanted.replace("_", " ").strip_edges().to_lower()
	if want == "":
		return false
	for ch in state.party:
		var full := ch.name.strip_edges().to_lower()
		if full == want or full.get_slice(" ", 0) == want:
			return true
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
