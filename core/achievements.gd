class_name Achievements
extends RefCounted
## Local achievements (N8): earned in the story (from its run stats, its fights and its endings) and in Skirmish, and
## kept across playthroughs in achievements.json beside the saves (SaveSystem.save_dir, so a test run keeps its own),
## apart from any one save. Nothing is sent anywhere. Captures never earn any.
## Besides the sixteen in LIST and the endings' own, hidden ones are defined in data/achievements/*.json (one file per
## easter-egg package, docs/story/eggs.md): the panel reads "A secret" for each until it is earned. A package earns its
## own in code (the for_* functions here) or with a `when` condition that check_story evaluates against the story.

## Where they're kept; "" means beside the saves.
static var path := ""
## The hidden ones' data files, and what a hidden, unearned achievement reads as in the list.
const DATA := "res://data/achievements/"
const HIDDEN_NAME := "A secret"
const HIDDEN_TEXT := "Hidden until it is earned."
## Foes knocked out (the Knock Out rule), over one playthrough, for Knocked, Not Killed.
const KNOCKED_OUT_NEEDED := 10

static var _defs: Array[Dictionary] = []
static var _loaded := false
## The `when` achievements check_story has already seen earned, for the earned file it last read.
static var _settled := {}
static var _settled_for := ""


static func file() -> String:
	return path if path != "" else SaveSystem.save_dir.path_join("achievements.json")

## id -> [name, how it's earned]. The endings' own come from data/endings (ending_<id>).
const LIST := {
	"first_victory": ["First Blood", "Win a fight in the story."],
	"critical": ["Fortune Favours", "Land a Critical Hit."],
	"crits_25": ["Deadly Aim", "Land 25 Critical Hits in one playthrough."],
	"snake_eyes": ["Cursed Dice", "Roll 20 natural 1s in one playthrough."],
	"kills_100": ["Hunter of the Night", "Defeat 100 foes in one playthrough."],
	"wolves_25": ["Wolfsbane", "Defeat 25 wolves, dire wolves and werewolves in one playthrough."],
	"undead_50": ["Rest in Peace", "Put 50 undead to rest in one playthrough."],
	"big_hit": ["Overwhelming Force", "Deal 50 damage or more with one blow."],
	"untouched": ["Not a Scratch", "Win a fight against four foes or more without a hero taking damage."],
	"last_stand": ["Last One Standing", "Win a fight with only one hero still on their feet."],
	"death_save_20": ["Not Today", "Roll a natural 20 on a Death Saving Throw."],
	"purse_1000": ["Burgomaster's Purse", "Hold 1,000 gp at once."],
	"none_lost": ["None Left Behind", "Reach an ending without losing a hero for good."],
	"skirmish_win": ["Proving Grounds", "Win a Skirmish."],
	"skirmish_beyond": ["Against All Odds", "Win a Skirmish rated beyond High."],
}
## LIST and the campaign's own (CampaignModule.extra_achievements).
static func listed() -> Dictionary:
	var out := LIST.duplicate()
	out.merge(Campaign.module().extra_achievements())
	return out


const WOLVES: Array[String] = ["wolf", "dire_wolf", "werewolf", "winter_wolf"]


## Watches a story fight from its start (the game's combat_started): when it's over, adds it to the run (RunStats)
## and reports any achievement earned to `toast` (a Callable taking the text).
static func watch(cv: CombatView, st: StoryState, toast: Callable = Callable()) -> void:
	cv.finished.connect(func(_outcome: String) -> void:
		var t := RunStats.add_fight(st, cv.e, CombatToken.art_for)
		note_fight(st, cv.e, t)
		for n in earn(st, for_story_fight(st, cv.e, t)):
			if toast.is_valid():
				toast.call("Achievement: %s" % n))


## What a story fight leaves in the run's side flags (data/flags/eggs_engine.json; the camp's banter and the castle's
## gargoyle read them): a foe sent over a map's open drop on a hero's turn, a barrel of lamp oil burst, an improvised
## object thrown. Side flags only: nothing in the main story reads them.
static func note_fight(st: StoryState, e: Encounter, t: Dictionary) -> void:
	var rows := FightTally.side_rows(e, t, "party")
	if rows.any(func(r: Dictionary) -> bool: return int(r["pushed_over"]) > 0):
		st.set_flag("eggs_pushed_over_edge", true)
	if e.objects.fire.bursts > 0:
		st.set_flag("eggs_barrel_burst", true)
	if rows.any(func(r: Dictionary) -> bool: return int(r["improvised"]) > 0):
		st.set_flag("eggs_threw_furniture", true)


## Earns the hidden achievements whose `when` holds in the story now, toasting each new one. Called whenever the party's
## state may have changed (the game's refresh), so it is cheap: an achievement already seen earned is skipped.
static func check_story(st: StoryState, toast: Callable = Callable()) -> Array[String]:
	if _settled_for != file():
		_settled.clear()
		_settled_for = file()
	var ids: Array[String] = []
	for d in hidden_defs():
		var id := str(d["id"])
		if not _settled.has(id) and str(d.get("when", "")) != "" and StoryConditions.check(str(d["when"]), st):
			ids.append(id)
	var names: Array[String] = []
	if ids.is_empty():
		return names
	names = earn(st, ids)
	for id in ids:
		_settled[id] = true
	if toast.is_valid():
		for n in names:
			toast.call("Achievement: %s" % n)
	return names


## Grants achievements reached in this run and notes the new ones in it (the ending lists them); returns their names.
static func earn(st: StoryState, ids: Array[String]) -> Array[String]:
	var names: Array[String] = []
	var mine := st.run_stats.get("earned", []) as Array
	for id in grant(ids):
		mine.append(id)
		names.append(name_of(id))
	st.run_stats["earned"] = mine
	return names


## Every achievement in order, the hidden ones before the endings: [{id, name, text, earned (a date or ""), hidden}].
## A hidden one that isn't earned yet comes with HIDDEN_NAME and HIDDEN_TEXT, so nothing that lists them can give one away.
static func all() -> Array[Dictionary]:
	var got := earned()
	var out: Array[Dictionary] = []
	var list := listed()
	for id: String in list:
		out.append({"id": id, "name": str(list[id][0]), "text": str(list[id][1]), "earned": str(got.get(id, "")), "hidden": false})
	for d in hidden_defs():
		var id := str(d["id"])
		var secret := bool(d.get("hidden", true)) and not got.has(id)
		out.append({"id": id, "name": HIDDEN_NAME if secret else str(d["name"]), "text": HIDDEN_TEXT if secret else str(d["text"]),
			"earned": str(got.get(id, "")), "hidden": bool(d.get("hidden", true))})
	for e in Campaign.module().endings():
		var id := "ending_" + str(e["id"])
		out.append({"id": id, "name": str(e.get("title", e["id"])), "text": "Reach this ending: %s" % str(e.get("summary", "")),
			"earned": str(got.get(id, "")), "hidden": false})
	return out


## The hidden achievements' definitions from data/achievements/*.json, in file order: [{id, name, text, hidden, when}].
static func hidden_defs() -> Array[Dictionary]:
	_load()
	return _defs


## Adds a definition as if it were in a data file (tests and tools); clear_cache drops it.
static func register(def: Dictionary) -> void:
	_load()
	_defs.append(def)


## Drops the loaded files and what check_story has seen (tests that change the earned file or add definitions).
static func clear_cache() -> void:
	_defs.clear()
	_loaded = false
	_settled.clear()
	_settled_for = ""


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DATA)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA + f))
		if not parsed is Dictionary:
			continue
		for a: Variant in (parsed as Dictionary).get("achievements", []) as Array:
			if a is Dictionary and (a as Dictionary).has("id"):
				_defs.append(a as Dictionary)


## {id: when it was earned (an ISO date and time)}.
static func earned() -> Dictionary:
	if not FileAccess.file_exists(file()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file()))
	return ((parsed as Dictionary).get("earned", {}) as Dictionary) if parsed is Dictionary else {}


static func has(id: String) -> bool:
	return earned().has(id)


## Marks the ids earned; returns those that weren't earned before. A capture run (the capture tool's --scene=) earns
## nothing.
static func grant(ids: Array[String]) -> Array[String]:
	var fresh: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			return fresh
	var got := earned()
	for id in ids:
		if got.has(id) or id in fresh:
			continue
		got[id] = Time.get_datetime_string_from_system()
		fresh.append(id)
	if not fresh.is_empty():
		DirAccess.make_dir_recursive_absolute(file().get_base_dir())
		var f := FileAccess.open(file(), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"earned": got}, "\t"))
			f.close()
	return fresh


static func name_of(id: String) -> String:
	var list := listed()
	if list.has(id):
		return str(list[id][0])
	if id.begins_with("ending_"):
		return str(Campaign.module().ending(id.trim_prefix("ending_")).get("title", id))
	for d in hidden_defs():
		if str(d["id"]) == id:
			return str(d["name"])
	return id


# --- What earns them ------------------------------------------------------------------------------

## The story's achievements a run's stats and the fight just tallied (`t`, FightTally) have reached.
static func for_story_fight(st: StoryState, e: Encounter, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rs := st.run_stats
	var totals := RunStats.totals(st)
	if e.outcome == "victory":
		out.append("first_victory")
	if int(totals["crits"]) >= 1:
		out.append("critical")
	if int(totals["crits"]) >= 25:
		out.append("crits_25")
	if int(totals["nat1"]) >= 20:
		out.append("snake_eyes")
	if int(totals["kills"]) >= 100:
		out.append("kills_100")
	var kinds := rs.get("kills_by_kind", {}) as Dictionary
	var wolves := 0
	for k: String in WOLVES:
		wolves += int(kinds.get(k, 0))
	if wolves >= 25:
		out.append("wolves_25")
	if int((rs.get("kills_by_type", {}) as Dictionary).get("undead", 0)) >= 50:
		out.append("undead_50")
	if float(rs.get("gold_most", 0.0)) >= 1000.0:
		out.append("purse_1000")
	if int(totals["knocked_out"]) >= KNOCKED_OUT_NEEDED:
		out.append("knocked_not_killed")
	out.append_array(for_fight(e, t))
	return out


## What one fight earns anywhere (the story or Skirmish): the hardest blows, untouched and last-stand wins, a natural
## 20 on a Death Saving Throw, a foe sent over a map's open drop, one burst barrel that caught two foes or more.
static func for_fight(e: Encounter, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var heroes := FightTally.side_rows(e, t, "party")
	var foes := FightTally.side_rows(e, t, "enemy")
	if heroes.any(func(r: Dictionary) -> bool: return int(r["best_hit"]) >= 50):
		out.append("big_hit")
	if heroes.any(func(r: Dictionary) -> bool: return int(r["death_save_20"]) > 0):
		out.append("death_save_20")
	if heroes.any(func(r: Dictionary) -> bool: return int(r["pushed_over"]) > 0):
		out.append("a_little_push")
	if e.objects.fire.most_foes_hit >= 2:
		out.append("spark_and_barrel")
	if e.outcome == "victory":
		if foes.size() >= 4 and heroes.all(func(r: Dictionary) -> bool: return int(r["damage_taken"]) == 0):
			out.append("untouched")
		var standing := 0
		var party := 0
		for c in e.combatants:
			if c.side == &"party":
				party += 1
				if c.creature.hp > 0:
					standing += 1
		if party >= 2 and standing == 1:
			out.append("last_stand")
	return out


## What a Skirmish fight earns: a win, a win rated beyond High, Strahd defeated, and anything a fight earns.
static func for_skirmish(setup: SkirmishSetup, e: Encounter, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if e.outcome == "victory":
		out.append("skirmish_win")
		if setup.difficulty() == "beyond high":
			out.append("skirmish_beyond")
		var foes: Array[String] = []
		for f in setup.foes:
			foes.append(str(f["monster"]))
		out.append_array(Campaign.module().skirmish_achievements(foes))
	out.append_array(for_fight(e, t))
	return out


## What reaching an ending earns: that ending's own, and None Left Behind when no hero was lost for good.
static func for_ending(st: StoryState, ending_id: String) -> Array[String]:
	var out: Array[String] = ["ending_" + ending_id]
	if st.fallen.is_empty():
		out.append("none_lost")
	return out
