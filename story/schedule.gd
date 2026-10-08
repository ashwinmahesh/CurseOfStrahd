class_name Schedule
extends RefCounted
## Things that happen on a day and an hour (F2): the herald's call before a festival, the Baron's arrests at dawn, a
## prisoner let out of the stocks at dusk. Each event is data (data/schedule/<region>.json): `hour` (and `minute`), on
## every day or every `every_days` from `first_day`, while its `when` holds; `once` events happen a single time. When
## it happens it sets its flags wherever the party is, and if the party is at its `location` it also plays: a Narrator
## `narration` line or a `dialogue`. A `here_only` event waits for a day the party is there to see it.
## Pure logic: LocationClock asks catch_up() as the clock moves; what has happened is kept in
## StoryState.flags["_schedule"] ({last: minute, fired: {id: times}}), so it survives saves. People keeping hours is
## the NPC entries' `hours` (in_hours below).

const DIR := "res://data/schedule"
const MEMORY := "_schedule"
## An event the party arrives for this late still plays; later than this, it happened without them.
const FRESH_MINUTES := 60
const DAY := 24 * 60

static var _events: Array[Dictionary] = []


## Every region's events (loaded once, files in name order).
static func events() -> Array[Dictionary]:
	if _events.is_empty():
		var files := Array(DirAccess.get_files_at(DIR))
		files.sort()
		for f: String in files:
			if not f.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(f)))
			if parsed is Dictionary:
				for e: Variant in (parsed as Dictionary).get("events", []):
					_events.append(e as Dictionary)
	return _events


## Tests swap in their own events; use([]) goes back to the files.
static func use(list: Array[Dictionary]) -> void:
	_events = list


static func memory(st: StoryState) -> Dictionary:
	if not st.flags.get(MEMORY, null) is Dictionary:
		st.flags[MEMORY] = {"last": st.total_minutes(), "fired": {}}   # a new game, or an older save: from now on
	return st.flags[MEMORY] as Dictionary


static func times(st: StoryState, id: String) -> int:
	return int((memory(st)["fired"] as Dictionary).get(id, 0))


## The events whose time came since the last look, oldest first, each once however long the wait (a Long Rest over two
## of its days is one arrest, not two). Their flags are set; what returns is what the party sees play here, at
## `location`: [{event, at (total minutes)}].
static func catch_up(st: StoryState, location: String) -> Array[Dictionary]:
	var mem := memory(st)
	var from := int(mem["last"])
	var now := st.total_minutes()
	var shown: Array[Dictionary] = []
	if now <= from:
		return shown
	var due: Array[Dictionary] = []
	for e in events():
		var at := last_time(e, from, now)
		if at >= 0:
			due.append({"event": e, "at": at})
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	for d in due:
		var e := d["event"] as Dictionary
		var id := str(e["id"])
		if bool(e.get("once", false)) and times(st, id) > 0:
			continue
		if not StoryConditions.check(str(e.get("when", "")), st):
			continue
		var here := str(e.get("location", "")) == "" or str(e["location"]) == location
		var fresh := now - int(d["at"]) <= FRESH_MINUTES
		if bool(e.get("here_only", false)) and not (here and fresh):
			continue
		(mem["fired"] as Dictionary)[id] = times(st, id) + 1
		var flags := e.get("set", {}) as Dictionary
		for f: String in flags:
			st.set_flag(f, flags[f])
		if here and fresh and (e.has("narration") or e.has("dialogue")):
			shown.append(d)
	mem["last"] = now
	return shown


## The latest time in (from, to] that `e` comes round (total minutes), or -1.
static func last_time(e: Dictionary, from: int, to: int) -> int:
	var of_day := int(e.get("hour", 0)) * 60 + int(e.get("minute", 0))
	var every := maxi(1, int(e.get("every_days", 1)))
	var first := int(e.get("first_day", 1))
	var day := floori(float(to - of_day) / DAY) + 1   # StoryState days start at 1
	while day >= first:
		var t := (day - 1) * DAY + of_day
		if t <= from:
			return -1
		if t <= to and (day - first) % every == 0:
			return t
		day -= 1
	return -1


## Whether an NPC entry's `hours` ([from, to], to may pass midnight) take in the hour now. No `hours`: always.
static func in_hours(spec: Dictionary, st: StoryState) -> bool:
	var h := spec.get("hours", []) as Array
	if h.size() != 2:
		return true
	var now := st.minute_of_day / 60.0
	var a := float(h[0])
	var b := float(h[1])
	return (now >= a and now < b) if a <= b else (now >= a or now < b)
