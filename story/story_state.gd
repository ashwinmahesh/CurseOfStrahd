class_name StoryState
extends RefCounted
## Everything about a playthrough's story and party that outlives a scene (plan §4.3 "single game state"): the
## party's characters, money and stash, story flags, quest stages, NPC attitudes, places visited, the codex, the
## Narrator's memory, milestone level-ups, game time, and each location's state (doors, loot, traps, fights).
## Pure data with to_dict()/from_dict(); GameState (core/) holds one and saves it.

var party: Array[Character] = []
## Index into party of the character leading in exploration and speaking in dialogue.
var leader: int = 0
var gold: float = 0.0
var stash: Array[Dictionary] = []          ## [{id, qty}] at safe places
var flags: Dictionary = {}
var quests: Dictionary = {}                ## quest id -> {stage, history: [stage ids]}
var attitudes: Dictionary = {}             ## npc id -> hostile | indifferent | friendly
var visited: Dictionary = {}               ## location or area id -> true
var codex: Array[String] = []              ## lore read (book props, letters)
var narrator: Dictionary = {}              ## trigger key -> {played: [variant indexes], last_minute, done}
var milestones: int = 0                    ## story milestones reached (milestone levelling)
var start_level: int = 1
var day: int = 1
var minute_of_day: int = 18 * 60           ## the party arrives at dusk
var location: String = ""
var positions: Array[Vector2i] = []        ## grid cells of party members in the current location
var location_states: Dictionary = {}      ## location id -> {doors: {id: "open"|"unlocked"}, looted: {}, traps: {id: state}, encounters: {}, props: {}}
## The result of the last check a dialogue or the world made (for `check.last`).
var last_check: bool = false


# --- Flags, quests, attitudes ---------------------------------------------------------------------

func get_flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)


func set_flag(id: String, value: Variant = true) -> void:
	flags[id] = value


func quest_stage(quest_id: String) -> String:
	return str((quests.get(quest_id, {}) as Dictionary).get("stage", ""))


## Moves a quest to `stage` (data/quests). Returns false if the quest or stage doesn't exist.
func set_quest_stage(quest_id: String, stage: String) -> bool:
	var q := Compendium.shared().get_entry("quests", quest_id)
	if q.is_empty():
		return false
	var ok := false
	for s: Variant in q.get("stages", []):
		if str((s as Dictionary)["id"]) == stage:
			ok = true
	if not ok:
		return false
	var entry := quests.get(quest_id, {"stage": "", "history": []}) as Dictionary
	entry["stage"] = stage
	var hist := entry.get("history", []) as Array
	if not stage in hist:
		hist.append(stage)
	entry["history"] = hist
	quests[quest_id] = entry
	return true


## The order of a quest's stages, for >= comparisons in conditions (-1 if not reached / unknown).
func quest_stage_index(quest_id: String, stage: String) -> int:
	var q := Compendium.shared().get_entry("quests", quest_id)
	var i := 0
	for s: Variant in q.get("stages", []):
		if str((s as Dictionary)["id"]) == stage:
			return i
		i += 1
	return -1


func attitude(npc_id: String) -> String:
	if attitudes.has(npc_id):
		return str(attitudes[npc_id])
	return str(Compendium.shared().get_entry("npcs", npc_id).get("attitude", "indifferent"))


# --- Party ----------------------------------------------------------------------------------------

func leader_character() -> Character:
	if party.is_empty():
		return null
	return party[clampi(leader, 0, party.size() - 1)]


## The first party member (in marching order) that matches a selector: class:x, species:x, background:x,
## tag:x, name:x, item:x.
func find_member(selector: String) -> Character:
	for ch in party:
		if member_matches(ch, selector):
			return ch
	return null


static func member_matches(ch: Character, selector: String) -> bool:
	var kind := selector.get_slice(":", 0)
	var value := selector.get_slice(":", 1)
	match kind:
		"class":
			return ch.class_level_of(value) > 0
		"species":
			return str(ch.build.get("species", "")) == value or ch.lineage == value
		"background":
			return str(ch.build.get("background", "")) == value
		"tag":
			var identity := ch.build.get("identity", {}) as Dictionary
			return value in (identity.get("tags", []) as Array)
		"name":
			return ch.id == value or ch.name.to_snake_case() == value
		"item":
			for e in ch.inventory:
				if str(e["id"]) == value and int(e["qty"]) > 0:
					return true
	return false


func party_has_item(item_id: String) -> bool:
	if find_member("item:" + item_id) != null:
		return true
	for e in stash:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			return true
	return false


## Gives an item to `ch` (or the stash if nobody's given).
func give_item(item_id: String, qty: int, ch: Character = null) -> void:
	if ch != null:
		ch.add_item(item_id, qty)
		return
	for e in stash:
		if str(e["id"]) == item_id:
			e["qty"] = int(e["qty"]) + qty
			return
	stash.append({"id": item_id, "qty": qty})


## Takes up to `qty` of an item from the party (stash last). Returns how many were taken.
func take_item(item_id: String, qty: int) -> int:
	var left := qty
	for ch in party:
		for e: Dictionary in ch.inventory.duplicate():
			if left <= 0:
				break
			if str(e["id"]) == item_id and int(e["qty"]) > 0:
				var n := mini(left, int(e["qty"]))
				e["qty"] = int(e["qty"]) - n
				left -= n
				if int(e["qty"]) <= 0 and str(e.get("slot", "")) == "":
					ch.inventory.erase(e)
	for e: Dictionary in stash.duplicate():
		if left <= 0:
			break
		if str(e["id"]) == item_id:
			var n2 := mini(left, int(e["qty"]))
			e["qty"] = int(e["qty"]) - n2
			left -= n2
			if int(e["qty"]) <= 0:
				stash.erase(e)
	return qty - left


## Milestone levelling (plan §5.6): the level the party may reach now.
func target_level() -> int:
	return mini(20, start_level + milestones)


func can_level_up(ch: Character) -> bool:
	return ch.character_level() < target_level()


# --- Time -----------------------------------------------------------------------------------------

func total_minutes() -> int:
	return (day - 1) * 24 * 60 + minute_of_day


func advance_minutes(minutes: int) -> void:
	minute_of_day += minutes
	while minute_of_day >= 24 * 60:
		minute_of_day -= 24 * 60
		day += 1
	for ch in party:
		ch.advance_minutes(minutes)


func is_night() -> bool:
	return minute_of_day < 6 * 60 or minute_of_day >= 19 * 60


# --- Locations ------------------------------------------------------------------------------------

func loc_state(location_id: String) -> Dictionary:
	if not location_states.has(location_id):
		location_states[location_id] = {"doors": {}, "looted": {}, "traps": {}, "encounters": {}, "props": {}, "found": {}}
	return location_states[location_id] as Dictionary


# --- Saving ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var members: Array = []
	for ch in party:
		members.append(ch.to_dict())
	var pos: Array = []
	for p in positions:
		pos.append([p.x, p.y])
	return {"party": members, "leader": leader, "gold": gold, "stash": stash.duplicate(true), "flags": flags.duplicate(true),
		"quests": quests.duplicate(true), "attitudes": attitudes.duplicate(true), "visited": visited.duplicate(true),
		"codex": codex.duplicate(), "narrator": narrator.duplicate(true), "milestones": milestones, "start_level": start_level,
		"day": day, "minute_of_day": minute_of_day, "location": location, "positions": pos,
		"location_states": location_states.duplicate(true), "last_check": last_check}


static func from_dict(d: Dictionary) -> StoryState:
	var st := StoryState.new()
	for m: Variant in d.get("party", []):
		var ch := Character.from_dict(m as Dictionary)
		if ch != null:
			st.party.append(ch)
	st.leader = int(d.get("leader", 0))
	st.gold = float(d.get("gold", 0.0))
	for e: Variant in d.get("stash", []):
		st.stash.append((e as Dictionary).duplicate())
	st.flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	st.quests = (d.get("quests", {}) as Dictionary).duplicate(true)
	st.attitudes = (d.get("attitudes", {}) as Dictionary).duplicate(true)
	st.visited = (d.get("visited", {}) as Dictionary).duplicate(true)
	for c: Variant in d.get("codex", []):
		st.codex.append(str(c))
	st.narrator = (d.get("narrator", {}) as Dictionary).duplicate(true)
	st.milestones = int(d.get("milestones", 0))
	st.start_level = int(d.get("start_level", 1))
	st.day = int(d.get("day", 1))
	st.minute_of_day = int(d.get("minute_of_day", 18 * 60))
	st.location = str(d.get("location", ""))
	for p: Variant in d.get("positions", []):
		var a := p as Array
		st.positions.append(Vector2i(int(a[0]), int(a[1])))
	st.location_states = (d.get("location_states", {}) as Dictionary).duplicate(true)
	st.last_check = bool(d.get("last_check", false))
	return st
