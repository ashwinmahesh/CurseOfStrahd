class_name Endings
extends RefCounted
## The campaign's endings and epilogues (ADR 0014; docs/contracts/campaign.md "Endings"). Each data/endings/<id>.json
## has a `when`, a `priority`, a narration node and epilogue slides. When the game ends (the `end_game` statement, the
## parley's yield or ireena, a wipe in a final battle, a won fight that leaves Strahd destroyed) the highest-priority
## ending whose `when` holds is recorded in the flag `campaign_ending`; the ending screen (ui/screens/ending_screen.gd)
## plays its narration and the slides whose `when` holds, then marks the save finished. Pure logic, like all of story/.

const ROOT := "res://data/endings/"
## The flag that records the ending reached (data/flags/endings.json).
const FLAG := "campaign_ending"
## The Vampyr's gift (the Amber Temple's Second Thirst): its bearer can take the dead lord's place.
const HEIR_GIFT := "gift_of_the_hollow"
## What the parley (strahd/final:parley) sets that ends the game instead of starting the battle.
const PARLEY_ENDS: Array[String] = ["yield", "ireena"]

static var _table: Dictionary = {}
static var _loaded := false


## Every ending, highest priority first (ties by id).
static func all() -> Array[Dictionary]:
	_load()
	var out: Array[Dictionary] = []
	for id: String in _table:
		out.append(_table[id] as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return str(a["id"]) < str(b["id"]))
	return out


static func get_ending(id: String) -> Dictionary:
	_load()
	return _table.get(id, {}) as Dictionary


## Drops the loaded files (tests that add or change endings).
static func clear_cache() -> void:
	_table.clear()
	_loaded = false


## Adds an ending as if it were a data file (tests and tools).
static func register(ending: Dictionary) -> void:
	_load()
	_table[str(ending["id"])] = ending


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + f))
		if parsed is Dictionary:
			var e := parsed as Dictionary
			_table[str(e.get("id", f.get_basename()))] = e
		else:
			push_error("Endings: %s is not a JSON object" % f)


## The highest-priority ending whose `when` holds now, or {} if none does.
static func pick(st: StoryState) -> Dictionary:
	for e in all():
		if StoryConditions.check(str(e.get("when", "")), st):
			return e
	return {}


## The ending this playthrough reached, or "" while it goes on.
static func reached(st: StoryState) -> String:
	var v: Variant = st.get_flag(FLAG, "")
	return str(v) if v is String else ""


## Ends the game: picks the ending and records it (once; later calls return the same id). "" if no ending holds.
static func request(st: StoryState) -> String:
	var done := reached(st)
	if done != "":
		return done
	var e := pick(st)
	if e.is_empty():
		push_warning("Endings: the game ended but no ending's condition holds")
		return ""
	st.set_flag(FLAG, str(e["id"]))
	return str(e["id"])


## Whether the parley ended the game (Strahd's price paid or the party yielding: no battle).
static func parley_ends(st: StoryState) -> bool:
	return str(st.get_flag("strahd_parley", "")) in PARLEY_ENDS


## A location encounter that is a final battle (ADR 0014: `"final_battle": "<room id>"`).
static func is_final_battle(spec: Dictionary) -> bool:
	return str(spec.get("final_battle", "")) != ""


## After a fight: a wipe in a final battle, or any won fight that leaves Strahd destroyed, ends the game. Returns the
## ending reached, or "" if the game goes on.
static func after_fight(st: StoryState, spec: Dictionary, outcome: String) -> String:
	if outcome == "defeat" and is_final_battle(spec):
		return request(st)
	if outcome == "victory" and bool(st.get_flag("strahd_destroyed", false)):
		return request(st)
	return ""


## The party member who carries the Second Thirst (the new lord in new_darklord), or null.
static func heir(st: StoryState) -> Character:
	for ch in st.party:
		if HEIR_GIFT in ch.dark_gifts():
			return ch
	return null


## {name}: the heir's first name (else the leader's); {leader}: the leader's.
static func fill(text: String, st: StoryState) -> String:
	var lead := st.leader_character()
	var who := heir(st)
	if who == null:
		who = lead
	return text.replace("{name}", _first(who)).replace("{leader}", _first(lead))


static func _first(ch: Character) -> String:
	return ch.name.get_slice(" ", 0) if ch != null else "you"


## The epilogue slides to show, in order: this ending's slides whose `when` holds, then those of the ending it takes
## its epilogue from (`epilogue_from`, and so on). A slide's `topic` is shown once (the first that holds), so an
## ending's own slide replaces the inherited one. Last, the party members lost on the way, if any.
## Each slide: {topic, title, text, portrait} with {name} filled in ("{name}" as a portrait is the heir's portrait).
static func slides(ending: Dictionary, st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var topics := {}
	var seen := {}
	var e := ending
	while not e.is_empty() and not seen.has(str(e.get("id", ""))):
		seen[str(e.get("id", ""))] = true
		for s: Variant in e.get("epilogue", []):
			var slide := s as Dictionary
			var topic := str(slide.get("topic", ""))
			if topic != "" and topics.has(topic):
				continue
			if not StoryConditions.check(str(slide.get("when", "")), st):
				continue
			if topic != "":
				topics[topic] = true
			out.append(_shown(slide, st))
		e = get_ending(str(e.get("epilogue_from", "")))
	if not st.fallen.is_empty():
		var names: Array[String] = []
		for f in st.fallen:
			names.append(str(f.get("name", "")))
		out.append({"topic": "fallen", "title": "The Fallen", "portrait": "",
			"text": "Not everyone who walked into the mists walked out of this story. Remember %s." % _list(names)})
	return out


static func _shown(slide: Dictionary, st: StoryState) -> Dictionary:
	var portrait := str(slide.get("portrait", ""))
	if portrait == "{name}":
		var who := heir(st)
		if who == null:
			who = st.leader_character()
		portrait = DialogueRunner.portrait_of(who) if who != null else ""
	return {"topic": str(slide.get("topic", "")), "title": fill(str(slide.get("title", "")), st), "text": fill(str(slide["text"]), st),
		"portrait": portrait}


## "A", "A and B", "A, B and C".
static func _list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]
