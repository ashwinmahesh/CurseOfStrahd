class_name StrahdPresence
extends RefCounted
## Strahd's presence across the campaign (ADR 0014, docs/regions/strahd_presence.md). He watches, writes, visits at
## night, tests the party in fights he leaves, comes for Ireena where she shelters and sends his black carriage. Each
## visit is data (data/strahd/visits.json): a trigger (an arrival, a Long Rest, a leg of a journey; a least number of
## days in Barovia; night, outdoors, which places), a condition, `once` or a cooldown, and its steps (a Narrator line,
## a conversation, a fight with a `withdraw` block, the carriage to a location), then the first `then` entry whose
## condition holds once the conversation is over. Pure logic: the game root asks due() at its hooks and plays the
## steps; what happened is kept in StoryState.flags["_strahd"], so it survives saves.

const PATH := "res://data/strahd/visits.json"
## Where the visits' memory lives in StoryState.flags: {fired: {visit id: {n, last}}, last: minute, pending: {}}.
const MEMORY := "_strahd"
const EVENTS: Array[String] = ["arrive", "rest", "travel"]
## The open floor a placed monster may stand on (as in tools/data/validate_data.py).
const OPEN_FLOOR := ".~1234"

static var _data: Dictionary = {}


## The visits file (loaded once).
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed as Dictionary if parsed is Dictionary else {"visits": []}
	return _data


## Tests swap in their own visits; use({}) goes back to the file.
static func use(d: Dictionary) -> void:
	_data = d


static func visit(id: String) -> Dictionary:
	for v: Variant in data().get("visits", []):
		if str((v as Dictionary)["id"]) == id:
			return v as Dictionary
	return {}


static func memory(st: StoryState) -> Dictionary:
	if not st.flags.get(MEMORY, null) is Dictionary:
		st.flags[MEMORY] = {"fired": {}, "last": -1000000, "pending": {}}
	return st.flags[MEMORY] as Dictionary


## How many times a visit has happened this playthrough.
static func times(st: StoryState, id: String) -> int:
	return int(((memory(st)["fired"] as Dictionary).get(id, {}) as Dictionary).get("n", 0))


# --- When a visit happens -------------------------------------------------------------------------

## The visit that happens now, at `on` (arrive, rest or travel), or {}. It is marked as happened. `ctx` may give
## {location (default st.location; "" on the road), night (default st.is_night()), outdoors (default the location's
## map)}. One visit at a time, in file order; `gap_hours` apart unless the visit is urgent.
static func due(st: StoryState, on: String, ctx: Dictionary = {}) -> Dictionary:
	if not on in EVENTS:
		return {}
	var loc_id := str(ctx.get("location", st.location))
	var loc := Compendium.shared().get_entry("locations", loc_id) if loc_id != "" else {}
	var region := str(loc.get("region", ""))
	var night := bool(ctx.get("night", st.is_night()))
	var outdoors := bool(ctx.get("outdoors", bool((loc.get("map", {}) as Dictionary).get("outdoors", false))))
	var d := data()
	if region != "" and region in (d.get("quiet_regions", []) as Array):
		return {}
	var mem := memory(st)
	var now := st.total_minutes()
	var gap := roundi(float(d.get("gap_hours", 0)) * 60.0)
	for v: Variant in d.get("visits", []):
		var vis := v as Dictionary
		if not bool(vis.get("urgent", false)) and now - int(mem["last"]) < gap:
			continue
		if fires(vis, st, on, loc_id, region, night, outdoors):
			_mark(st, vis)
			return vis
	return {}


## Whether `vis` happens at this event (its trigger, quiet places, once / cooldown / max, and its condition).
static func fires(vis: Dictionary, st: StoryState, on: String, loc_id: String, region: String, night: bool, outdoors: bool) -> bool:
	var t := vis.get("trigger", {}) as Dictionary
	var ons := t.get("on", []) as Array
	if not on in ons and not "days" in ons:
		return false
	if st.day - 1 < int(t.get("days", 0)):
		return false
	if t.has("night") and bool(t["night"]) != night:
		return false
	if t.has("outdoors") and bool(t["outdoors"]) != outdoors:
		return false
	var at := t.get("at", []) as Array
	if not at.is_empty() and not loc_id in at:
		return false
	if at.is_empty() and loc_id in (data().get("quiet_at", []) as Array):
		return false
	var regions := t.get("region", []) as Array
	if not regions.is_empty() and not region in regions:
		return false
	var id := str(vis["id"])
	var n := times(st, id)
	if bool(vis.get("once", false)) and n > 0:
		return false
	if vis.has("max") and n >= int(vis["max"]):
		return false
	if vis.has("cooldown_hours") and n > 0:
		var last := int(((memory(st)["fired"] as Dictionary)[id] as Dictionary).get("last", -1000000))
		if st.total_minutes() - last < roundi(float(vis["cooldown_hours"]) * 60.0):
			return false
	return StoryConditions.check(str(vis.get("when", "")), st)


static func _mark(st: StoryState, vis: Dictionary) -> void:
	var mem := memory(st)
	var fired := mem["fired"] as Dictionary
	var id := str(vis["id"])
	fired[id] = {"n": times(st, id) + 1, "last": st.total_minutes()}
	mem["last"] = st.total_minutes()
	mem["pending"] = {}


## Whether any of the time from `start` to `end` (total minutes) was night: a Long Rest "through the night".
static func night_between(start: int, end: int) -> bool:
	var probe := StoryState.new()
	var t := start
	while t <= end:
		probe.minute_of_day = posmod(t, 24 * 60)
		if probe.is_night():
			return true
		t += 30
	return false


# --- Playing a visit ------------------------------------------------------------------------------

## The visit's first step: {go, narration, dialogue | encounter} (any of them). Remembers what comes after it: the
## visit's `then` once its conversation ends, or the fight's `after` conversation.
static func begin(st: StoryState, vis: Dictionary) -> Dictionary:
	var step := {}
	for k: String in ["go", "narration", "dialogue", "encounter"]:
		if vis.has(k):
			step[k] = vis[k]
	_expect(st, step, str(vis["id"]))
	return step


## After a conversation `ref` ends: the visit's next step (the first `then` entry whose `when` holds), or {}.
static func after_dialogue(st: StoryState, ref: String) -> Dictionary:
	var mem := memory(st)
	var pending := mem["pending"] as Dictionary
	if str(pending.get("stage", "")) != "dialogue" or str(pending.get("ref", "")) != ref:
		return {}
	mem["pending"] = {}
	var vis := visit(str(pending.get("visit", "")))
	if not bool(pending.get("then", true)):
		return {}
	for e: Variant in vis.get("then", []):
		var entry := e as Dictionary
		if StoryConditions.check(str(entry.get("when", "")), st):
			var step := entry.duplicate(true)
			step.erase("when")
			_expect(st, step, str(vis["id"]), false)
			return step
	return {}


## After a fight ends (`outcome` victory / defeat / ...): the visit fight's `after` conversation, or {}.
static func after_encounter(st: StoryState, outcome: String) -> Dictionary:
	var mem := memory(st)
	var pending := mem["pending"] as Dictionary
	if str(pending.get("stage", "")) != "encounter":
		return {}
	mem["pending"] = {}
	var after := str(pending.get("after", ""))
	if outcome == "defeat" or after == "":
		return {}
	var step := {"dialogue": after}
	_expect(st, step, str(pending.get("visit", "")), false)
	return step


static func _expect(st: StoryState, step: Dictionary, visit_id: String, then: bool = true) -> void:
	var mem := memory(st)
	if step.has("dialogue") and not step.has("encounter"):
		mem["pending"] = {"stage": "dialogue", "ref": str(step["dialogue"]), "visit": visit_id, "then": then}
	elif step.has("encounter"):
		mem["pending"] = {"stage": "encounter", "after": str((step["encounter"] as Dictionary).get("after", "")), "visit": visit_id}
	else:
		mem["pending"] = {}


## Where a visit on the road plays: its `map`, else the road's random encounter map, else the Old Svalich Road.
static func road_map(vis: Dictionary, road: Dictionary) -> String:
	if str(vis.get("map", "")) != "":
		return str(vis["map"])
	var table := Compendium.shared().get_entry("random_encounters", str(road.get("table", "")))
	return str(table.get("map", "road_ambush")) if not table.is_empty() else "road_ambush"


# --- Placing a visit's fight ----------------------------------------------------------------------

## The encounter with a cell for every monster that has none: open floor reachable from `near` (the leader), about
## four squares off, never on a `taken` square (party, guests, people, doors, exits) and with room for its size.
static func placed(enc: Dictionary, rows: Array, taken: Array[Vector2i], near: Vector2i) -> Dictionary:
	var out := enc.duplicate(true)
	var used := {}
	for c in taken:
		used[c] = true
	for mo: Variant in out.get("monsters", []):
		var md := mo as Dictionary
		if md.has("cell"):
			for c in CombatGrid.footprint(Vector2i(int((md["cell"] as Array)[0]), int((md["cell"] as Array)[1])), _size(str(md["monster"]))):
				used[c] = true
	var dist := _distances(rows, near)
	var cells: Array = dist.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(int(dist[a]) - 4)
		var db := absi(int(dist[b]) - 4)
		if da != db:
			return da < db
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for mo: Variant in out.get("monsters", []):
		var md := mo as Dictionary
		if md.has("cell"):
			continue
		var size := _size(str(md["monster"]))
		# Three squares off at least; in a cramped room, anywhere it fits.
		for least: int in [3, 1]:
			for c: Variant in cells:
				var anchor: Vector2i = c
				if int(dist[anchor]) < least:
					continue
				var fits := true
				for f in CombatGrid.footprint(anchor, size):
					if used.has(f) or not dist.has(f):
						fits = false
						break
				if not fits:
					continue
				md["cell"] = [anchor.x, anchor.y]
				for f in CombatGrid.footprint(anchor, size):
					used[f] = true
				# A little room between foes, so they come at the party from more than one side.
				for dv in CombatGrid.DIRS:
					used[anchor + dv] = true
				break
			if md.has("cell"):
				break
	# A foe with nowhere to stand stays out of the fight (the first, Strahd, always finds room).
	out["monsters"] = (out.get("monsters", []) as Array).filter(func(m: Variant) -> bool: return (m as Dictionary).has("cell"))
	return out


## Steps from `start` to every open square it can reach (8 directions).
static func _distances(rows: Array, start: Vector2i) -> Dictionary:
	var out := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for dv in CombatGrid.DIRS:
			var n := c + dv
			if out.has(n) or n.y < 0 or n.y >= rows.size():
				continue
			var row := str(rows[n.y])
			if n.x < 0 or n.x >= row.length() or not OPEN_FLOOR.contains(row[n.x]):
				continue
			out[n] = int(out[c]) + 1
			queue.append(n)
	return out


static func _size(monster_id: String) -> int:
	var m := Compendium.shared().monster_data(monster_id)
	return CombatGrid.size_cells_for(StringName(str(m.get("size", "medium"))))
