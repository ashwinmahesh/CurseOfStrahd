class_name Xp
extends RefCounted
## Experience-point levelling (docs/plans/xp_mode.md; Ashwin's ask, 2026-10-14). A playthrough picks how heroes grow when it
## begins: Milestones (the default, and every save made before this) or Experience. In Experience, foes beaten, quests
## finished, places found and things noticed fill one pool of XP (StoryState.xp) that sets StoryState.target_level(); the
## characters still take each level on the level-up screen. Two guardrails keep every fight at the level it is tuned for:
## a region milestone lifts the pool to the level milestone mode would give (the floor), and the pool never reaches the
## level two above that (the ceiling). One-time XP over the ceiling waits in StoryState.xp_reserve and is paid at the next
## milestone; XP from the road, the camp and Strahd's visits, which can be had again, is lost over it.
## Every number is data/progression/xp.json's (2024 PHB level table, 2024 DMG XP budget per character); tools/balance/
## xp_sim.py replays it against the fight data. Pure rules over a StoryState: Milestone mode never gets here (each hook
## asks active() first), so nothing in the game changes for it.

const PATH := "res://data/progression/xp.json"
const OPTION := "levelling"
const MILESTONE := "milestone"
const EXPERIENCE := "xp"
## The flag a once-only award leaves in StoryState.flags (the `xp milestone` line's keys start the same way).
const KEY := "_xp/%s/%s"
const COLUMNS: Array[String] = ["low", "moderate", "high"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed as Dictionary if parsed is Dictionary else {}
	return _data


## Tests swap in their own; use({}) goes back to the file.
static func use(d: Dictionary) -> void:
	_data = d


# --- The mode -------------------------------------------------------------------------------------

## The levelling a set of playthrough options names: `xp` or `milestone`. Anything else, and a save that never picked
## (every save before this), is milestones.
static func mode_of(options: Dictionary) -> String:
	return EXPERIENCE if str(options.get(OPTION, MILESTONE)) == EXPERIENCE else MILESTONE


static func active(st: StoryState) -> bool:
	return st != null and mode_of(st.options) == EXPERIENCE


# --- The tables -----------------------------------------------------------------------------------

## The XP a party needs to reach `level` (2024 PHB). Past the table, its last entry.
static func threshold(level: int) -> int:
	var t := data().get("thresholds", [0]) as Array
	return int(t[clampi(level - 1, 0, t.size() - 1)])


## The level `xp` is worth, up to the game's cap.
static func level_for(xp: int) -> int:
	var level := 1
	for l in range(2, StoryState.LEVEL_CAP + 1):
		if xp >= threshold(l):
			level = l
	return level


## XP still needed for the next level, 0 at the cap.
static func to_next(xp: int) -> int:
	var level := level_for(xp)
	return 0 if level >= StoryState.LEVEL_CAP else threshold(level + 1) - xp


## How far `xp` is through its level, 0 to 1 (1 at the cap), for a progress bar.
static func progress(xp: int) -> float:
	var level := level_for(xp)
	if level >= StoryState.LEVEL_CAP:
		return 1.0
	return clampf(float(xp - threshold(level)) / float(threshold(level + 1) - threshold(level)), 0.0, 1.0)


## The 2024 DMG's XP budget for one character at `level`: column `low`, `moderate` or `high`.
static func budget(level: int, column: String) -> int:
	var rows := data().get("budgets", [[0, 0, 0]]) as Array
	var row := rows[clampi(level - 1, 0, rows.size() - 1)] as Array
	return int(row[maxi(0, COLUMNS.find(column))])


## What an award of `kind` is worth to each hero now: its budget column at the party's XP level, times its share, at
## least 1. 0 for a kind the table doesn't have.
static func amount_for(st: StoryState, kind: String) -> int:
	var a := (data().get("awards", {}) as Dictionary).get(kind, {}) as Dictionary
	if a.is_empty():
		return 0
	return maxi(1, roundi(float(budget(level_for(st.xp), str(a["budget"]))) * float(a["times"])))


## The most XP the pool can hold now: one short of the level two above the story's, so the party is never more than one
## level ahead of milestone mode (at the end, the cap's own threshold).
static func ceiling(st: StoryState) -> int:
	var s := st.story_level()
	if s + 2 <= StoryState.LEVEL_CAP:
		return threshold(s + 2) - 1
	return threshold(StoryState.LEVEL_CAP)


# --- Gaining --------------------------------------------------------------------------------------

## Puts `amount` into the pool under the ceiling. What doesn't fit waits in the reserve for the next milestone, or, when
## `repeatable` (the road, the camp, Strahd's visits: things that can be had again) or the story has reached the cap,
## is lost. Returns {gained, held, lost}. A level the pool reaches is said at once (StoryState.xp_gained), unless the caller
## says it in its own notice (`announce` false: a milestone).
static func gain(st: StoryState, amount: int, repeatable: bool = false, announce: bool = true) -> Dictionary:
	var before := level_for(st.xp)
	var take := mini(maxi(0, ceiling(st) - st.xp), maxi(0, amount))
	st.xp += take
	if announce and level_for(st.xp) > before:
		st.xp_gained.emit("The party reaches level %d" % level_for(st.xp))
	var rest := maxi(0, amount) - take
	var held := 0
	var lost := 0
	if rest > 0:
		if repeatable or st.story_level() >= StoryState.LEVEL_CAP:
			lost = rest
		else:
			held = rest
			st.xp_reserve += rest
	return {"gained": take, "held": held, "lost": lost}


## A one-time award of `kind` for `key` (a find, a check, a place, a quest): paid the first time only, in Experience mode
## only. Returns what it came to, {gained, held, lost}, all 0 when nothing was paid.
static func pay(st: StoryState, kind: String, key: String) -> Dictionary:
	var none := {"gained": 0, "held": 0, "lost": 0}
	if not active(st):
		return none
	var flag := KEY % [kind, key]
	if st.flags.has(flag):
		return none
	st.flags[flag] = true
	return gain(st, amount_for(st, kind))


## `pay`, for the callers that show what it came to inside a notice of their own: the XP gained.
static func award(st: StoryState, kind: String, key: String) -> int:
	return int(pay(st, kind, key)["gained"])


## " (+25 XP)", for the end of a notice (Found a Potion of Healing (+25 XP)); "" when there is nothing to show.
static func tag(n: int) -> String:
	return " (+%s XP)" % fmt(n) if n > 0 else ""


## 15240 -> "15,240".
static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Region milestones ----------------------------------------------------------------------------

## A region milestone (the dialogue line `xp milestone`, after StoryState.milestones went up): the DMG's High award, then
## the floor (the pool is lifted to the level the story now gives), then the reserve is paid up to the new ceiling.
## Returns the notice.
static func milestone(st: StoryState) -> String:
	var before := level_for(st.xp)
	var start := st.xp
	gain(st, amount_for(st, "milestone"), false, false)   # the notice below says if a level came of it
	var s := st.story_level()
	if st.xp < threshold(s):
		st.xp = threshold(s)
	if st.xp_reserve > 0:
		var pay_now := mini(st.xp_reserve, maxi(0, ceiling(st) - st.xp))
		st.xp += pay_now
		st.xp_reserve -= pay_now
	if s >= StoryState.LEVEL_CAP:
		st.xp_reserve = 0   # nothing is left to wait for
	var text := "Milestone: +%s XP" % fmt(st.xp - start)
	if level_for(st.xp) > before:
		text += ", the party reaches level %d" % level_for(st.xp)
	return text


# --- Fights ---------------------------------------------------------------------------------------

## Each hero's share of a won fight: the foes' stat-block XP times the foe share, over the fixed split (guests and a short
## party don't change it), summed over every enemy that was overcome (killed, routed, withdrew or taken). Neutral
## creatures and summons give nothing. A foe that leaves alive and is named in `withdraw_pays` (Strahd's visits) is paid
## that award instead of its stat block: his own XP waits for his end.
static func foes_xp(st: StoryState, e: Encounter) -> int:
	var summoned := {}
	for ids: Variant in e.spells.summoned.values():
		for id: Variant in ids as Array:
			summoned[str(id)] = true
	var stat := 0
	var extra := 0
	var pays := data().get("withdraw_pays", {}) as Dictionary
	for c in e.combatants:
		if c.side != &"enemy" or not c.creature is Monster or c.has_meta("summoner") or summoned.has(c.id) \
				or c.creature.has_flag("spell_object"):
			continue
		var mon := (c.creature as Monster).data
		if str(e.legendary.departed.get(c.id, "")) == "withdraw" and pays.has(str(mon.get("id", ""))):
			extra += amount_for(st, str(pays[str(mon["id"])]))
		else:
			stat += int(mon.get("xp", 0))
	return _share(stat) + extra


## The same, for an encounter's data before it is fought (a fight talked away): every enemy in `spec`.
static func spec_xp(spec: Dictionary) -> int:
	var stat := 0
	for m: Variant in spec.get("monsters", []):
		var md := m as Dictionary
		if str(md.get("side", "enemy")) == "enemy":
			stat += int(Compendium.shared().monster_data(str(md["monster"])).get("xp", 0))
	return _share(stat)


static func _share(stat: int) -> int:
	return roundi(float(stat) * float(data().get("foe_share", 0.4)) / float(maxi(1, int(data().get("split", 4)))))


## A won fight. `encounter_id` is the place's own fight, paid once (it is also what `talked_away` leaves its mark under,
## so a fight avoided and fought later pays once); `repeatable` fights (a road meeting, a night at camp, Strahd's visit)
## are paid every time but are lost over the ceiling. Returns the notice, "" when nothing was paid.
static func fight(st: StoryState, e: Encounter, encounter_id: String, repeatable: bool) -> String:
	if not active(st):
		return ""
	if not repeatable:
		var flag := KEY % ["fight", encounter_id]
		if st.flags.has(flag):
			return ""
		st.flags[flag] = true
	return _notice("", gain(st, foes_xp(st, e), repeatable))


## A fight a conversation put an end to (the dialogue line `xp fight <encounter id>`): the party earns what winning the
## version it would have met pays (2024 DMG: foes count as overcome when cleverly avoided). Returns the notice.
static func talked_away(st: StoryState, encounter_id: String) -> String:
	if not active(st):
		return ""
	var flag := KEY % ["fight", encounter_id]
	if st.flags.has(flag):
		return ""
	var spec := encounter_spec(st, encounter_id)
	if spec.is_empty():
		return ""
	st.flags[flag] = true
	return _notice("", gain(st, spec_xp(spec)))


## The entry a fight with `encounter_id` uses now, wherever it is fought: of the entries sharing the id, the first whose
## `when` holds (else the last), as LocationFights.spec_for picks it. {} if there is none.
static func encounter_spec(st: StoryState, encounter_id: String) -> Dictionary:
	var spec := {}
	for loc in Compendium.shared().all("locations"):
		for en: Variant in loc.get("encounters", []):
			if str((en as Dictionary)["id"]) == encounter_id \
					and (spec.is_empty() or not StoryConditions.check(StoryConditions.encounter_when(spec), st)):
				spec = en as Dictionary
	return spec


# --- Places, quests and the rest ------------------------------------------------------------------

## The party arrives at `loc_id` for the first time: a place on the travel map is a discovery (a minor milestone), any
## other map a new location. Said to the player through StoryState.xp_gained for a place; a location is quiet.
static func arrive(st: StoryState, loc_id: String) -> void:
	if not active(st):
		return
	var place := Travel.place_for_location(loc_id)
	if place == "":
		pay(st, "location", loc_id)
		return
	var said := _notice("Discovered %s" % Travel.place(place).get("name", place), pay(st, "place", place))
	if said != "":
		st.xp_gained.emit(said)


## A quest reached a stage that ends in success: a main-quest goal (Moderate) or a side or companion quest (half of Low).
## A region's own climax quest, whose milestone pays for it, and the walk out of the mists pay nothing. Returns what it
## said ("" when nothing was paid), which StoryState.quest_notice shows in place of its own "Quest complete".
static func quest_done(st: StoryState, quest_id: String) -> String:
	if not active(st):
		return ""
	if quest_id in (data().get("milestone_quests", []) as Array) or quest_id in (data().get("no_xp_quests", []) as Array):
		return ""
	var q := Compendium.shared().get_entry("quests", quest_id)
	var kind := "main_quest" if str(q.get("kind", "")) == "main" else "side_quest"
	var said := _notice("Quest complete: %s" % q.get("name", quest_id), pay(st, kind, quest_id))
	if said != "":
		st.xp_gained.emit(said)
	return said


## The Deck of Many Things' Sun card in Experience mode: enough XP for the next level. One-time, so the ceiling holds the
## rest in the reserve. Returns the XP gained.
static func sun(st: StoryState) -> int:
	return int(gain(st, to_next(st.xp))["gained"])


## "Quest complete: The Grey Mare, +125 XP", with what the ceiling held back for the next milestone. "" when the award
## came to nothing at all (road XP lost over the ceiling).
static func _notice(lead: String, got: Dictionary) -> String:
	var parts: Array[String] = []
	if int(got["gained"]) > 0:
		parts.append("+%s XP" % fmt(int(got["gained"])))
	if int(got["held"]) > 0:
		parts.append("%s XP held for the next milestone" % fmt(int(got["held"])))
	if parts.is_empty():
		return ""
	return (lead + ", " if lead != "" else "") + ", ".join(parts)


# --- What the screens say -------------------------------------------------------------------------

## "Level 6 · 15,240 / 23,000 XP"; at the cap "Level 11 · 85,000 XP".
static func line(st: StoryState) -> String:
	var level := level_for(st.xp)
	if level >= StoryState.LEVEL_CAP:
		return "Level %d · %s XP" % [level, fmt(st.xp)]
	return "Level %d · %s / %s XP" % [level, fmt(st.xp), fmt(threshold(level + 1))]


## What waits for the next milestone, or "".
static func reserve_line(st: StoryState) -> String:
	return "Held for the next milestone: %s XP" % fmt(st.xp_reserve) if st.xp_reserve > 0 else ""


## Why the reserve is held (its tip).
static func reserve_tip() -> String:
	return "The party never runs more than one level ahead of the story. XP earned past that waits here, and a region milestone pays it out."
