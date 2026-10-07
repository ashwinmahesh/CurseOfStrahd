class_name Achievements
extends RefCounted
## Local achievements (N8): earned in the story (from its run stats, its fights and its endings) and in Skirmish, and
## kept across playthroughs in achievements.json beside the saves (SaveSystem.save_dir, so a test run keeps its own),
## apart from any one save. Nothing is sent anywhere. Captures never earn any.

## Where they're kept; "" means beside the saves.
static var path := ""


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
	"skirmish_strahd": ["Dress Rehearsal", "Defeat Strahd in a Skirmish."],
}
const WOLVES: Array[String] = ["wolf", "dire_wolf", "werewolf", "winter_wolf"]


## Every achievement in order, the endings' last: [{id, name, text, earned (a date or "")}].
static func all() -> Array[Dictionary]:
	var got := earned()
	var out: Array[Dictionary] = []
	for id: String in LIST:
		out.append({"id": id, "name": str(LIST[id][0]), "text": str(LIST[id][1]), "earned": str(got.get(id, ""))})
	for e in Endings.all():
		var id := "ending_" + str(e["id"])
		out.append({"id": id, "name": str(e.get("title", e["id"])), "text": "Reach this ending: %s" % str(e.get("summary", "")),
			"earned": str(got.get(id, ""))})
	return out


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
	if LIST.has(id):
		return str(LIST[id][0])
	if id.begins_with("ending_"):
		return str(Endings.get_ending(id.trim_prefix("ending_")).get("title", id))
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
	out.append_array(for_fight(e, t))
	return out


## What one fight earns anywhere (the story or Skirmish): the hardest blows, untouched and last-stand wins, a natural
## 20 on a Death Saving Throw.
static func for_fight(e: Encounter, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var heroes := FightTally.side_rows(e, t, "party")
	var foes := FightTally.side_rows(e, t, "enemy")
	if heroes.any(func(r: Dictionary) -> bool: return int(r["best_hit"]) >= 50):
		out.append("big_hit")
	if heroes.any(func(r: Dictionary) -> bool: return int(r["death_save_20"]) > 0):
		out.append("death_save_20")
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
		if setup.foes.any(func(f: Dictionary) -> bool: return str(f["monster"]) == "strahd_von_zarovich"):
			out.append("skirmish_strahd")
	out.append_array(for_fight(e, t))
	return out


## What reaching an ending earns: that ending's own, and None Left Behind when no hero was lost for good.
static func for_ending(st: StoryState, ending_id: String) -> Array[String]:
	var out: Array[String] = ["ending_" + ending_id]
	if st.fallen.is_empty():
		out.append("none_lost")
	return out
