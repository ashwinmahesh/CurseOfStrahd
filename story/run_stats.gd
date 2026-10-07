class_name RunStats
extends RefCounted
## A playthrough's record (N8), shown at the ending: for each hero, their kills, Critical Hits, natural 20s and 1s,
## hits and misses, damage dealt and taken, hardest blow, falls and deaths, added up from every story fight's combat
## log (FightTally); and for the party, fights won, rounds fought, foes defeated by kind, and gold. Kept in
## StoryState.run_stats, so it saves with the game. Gold is read at each fight's end and at the ending: what came in
## and went out between two readings counts as found or spent. Pure data with no autoloads (make lint compiles story/
## on its own); Achievements (core/) watches the game's fights and calls add_fight.

## The purse a new game starts with (main_menu.gd, game_root.gd).
const START_GOLD := 10.0
const HERO_KEYS: Array[String] = ["fights", "kills", "crits", "nat20", "nat1", "hits", "misses", "damage_dealt",
	"damage_taken", "downs", "deaths"]


## Adds one fight to the run and returns its tally. `art_of(character) -> String` names each hero's portrait (the
## game passes the combat tokens' art lookup), kept for heroes who later leave the company.
static func add_fight(st: StoryState, e: Encounter, art_of: Callable = Callable()) -> Dictionary:
	var t := FightTally.tally(e)
	var rs := st.run_stats
	rs["fights"] = int(rs.get("fights", 0)) + 1
	if e.outcome == "victory":
		rs["won"] = int(rs.get("won", 0)) + 1
	rs["rounds"] = int(rs.get("rounds", 0)) + e.round_no
	var heroes := rs.get("heroes", {}) as Dictionary
	var by_kind := rs.get("kills_by_kind", {}) as Dictionary
	var by_type := rs.get("kills_by_type", {}) as Dictionary
	var ours := {}
	for c in e.combatants:
		var row := t[c.id] as Dictionary
		if c.side in [&"party", &"guest"] and c.creature is Character:
			ours[c.id] = true
			var key := hero_key(c.creature as Character)
			var h := heroes.get(key, {"name": c.creature.name}) as Dictionary
			h["name"] = c.creature.name
			if art_of.is_valid():
				h["art"] = str(art_of.call(c.creature))
			for k in HERO_KEYS:
				if k == "fights":
					h[k] = int(h.get(k, 0)) + 1
				elif k == "deaths":
					h[k] = int(h.get(k, 0)) + int(row["died"])
				else:
					h[k] = int(h.get(k, 0)) + int(row[k])
			h["best_hit"] = maxi(int(h.get("best_hit", 0)), int(row["best_hit"]))
			heroes[key] = h
			if int(row["best_hit"]) > int((rs.get("best_hit", {}) as Dictionary).get("amount", 0)):
				rs["best_hit"] = {"name": c.creature.name, "amount": int(row["best_hit"])}
	for c in e.combatants:
		var row := t[c.id] as Dictionary
		if c.side == &"enemy" and int(row["died"]) > 0 and ours.has(str(row["killed_by"])) and c.creature is Monster:
			var data := (c.creature as Monster).data
			var kind := str(data.get("id", ""))
			by_kind[kind] = int(by_kind.get(kind, 0)) + 1
			var type := str(data.get("type", "")).get_slice(" ", 0)
			by_type[type] = int(by_type.get(type, 0)) + 1
	rs["heroes"] = heroes
	rs["kills_by_kind"] = by_kind
	rs["kills_by_type"] = by_type
	observe_gold(st)
	return t


## The id a hero's record is kept under (their character id, which saves keep).
static func hero_key(ch: Character) -> String:
	return ch.id if ch.id != "" else ch.name


## Reads the party's gold: anything more than at the last reading was found, anything less spent. The first reading
## compares with the purse every new game starts with.
static func observe_gold(st: StoryState) -> void:
	var rs := st.run_stats
	var now := st.gold
	var diff := now - float(rs.get("gold_seen", START_GOLD))
	rs["gold_found"] = float(rs.get("gold_found", 0.0))
	rs["gold_spent"] = float(rs.get("gold_spent", 0.0))
	if diff > 0.0:
		rs["gold_found"] = float(rs.get("gold_found", 0.0)) + diff
	elif diff < 0.0:
		rs["gold_spent"] = float(rs.get("gold_spent", 0.0)) - diff
	rs["gold_seen"] = now
	rs["gold_most"] = maxf(float(rs.get("gold_most", 0.0)), now)


## The whole party's totals over the run (HERO_KEYS summed).
static func totals(st: StoryState) -> Dictionary:
	var out := {}
	for k in HERO_KEYS:
		out[k] = 0
	for h: Variant in (st.run_stats.get("heroes", {}) as Dictionary).values():
		for k in HERO_KEYS:
			out[k] = int(out[k]) + int((h as Dictionary).get(k, 0))
	return out


## The heroes' records for the ending, the travelling party first, then those at camp, then anyone else who fought;
## `art_of` as for add_fight.
static func hero_rows(st: StoryState, art_of: Callable = Callable()) -> Array[Dictionary]:
	var heroes := st.run_stats.get("heroes", {}) as Dictionary
	var out: Array[Dictionary] = []
	var seen := {}
	for ch in st.roster():
		var key := hero_key(ch)
		var h := (heroes.get(key, {}) as Dictionary).duplicate()
		h["name"] = ch.name
		if art_of.is_valid():
			h["art"] = str(art_of.call(ch))
		h["status"] = "dead" if ch.dead else ("at camp" if ch in st.bench else "")
		out.append(h)
		seen[key] = true
	for key: String in heroes:
		if not seen.has(key):
			var h := (heroes[key] as Dictionary).duplicate()
			h["status"] = "fallen" if st.fallen.any(func(f: Dictionary) -> bool: return str(f.get("id", "")) == key) else "gone"
			out.append(h)
	return out


## The foes the party defeated most, as "12 Wolf" lines, most first.
static func top_kills(st: StoryState, n: int = 5) -> Array[String]:
	var by_kind := st.run_stats.get("kills_by_kind", {}) as Dictionary
	var keys := by_kind.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(by_kind[a]) > int(by_kind[b]))
	var out: Array[String] = []
	for k: Variant in keys.slice(0, n):
		out.append("%d %s" % [int(by_kind[k]), str(Compendium.shared().monster_data(str(k)).get("name", k))])
	return out
