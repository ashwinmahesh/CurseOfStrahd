class_name RestRules
extends RefCounted
## When and where the party may start a Long Rest (owner rules, 2026-10-09):
## - not in a place that allows no sleep (`rest`: no; its `rest_text` says why);
## - not within 16 hours of finishing the last one (2024 PHB), so two back to back can't clear Exhaustion or the Raise
##   Dead penalty twice in a night;
## - not in a dungeon or any building while enemies remain in it, on any of its floors (docs/rules/deviations.md). A
##   building is its walled maps (indoors, and a dungeon's open-air ones such as Castle Ravenloft's roofs) joined by
##   their exits. Enemies remain while one of its fights would still start on its own (entering an area, opening a door
##   or a chest, examining something) or one was begun and not won; a fight only a conversation can start doesn't
##   count. Towns, inns, camps and the open road are unaffected, and so are the magic items that make a safe place to
##   sleep (the Rod of Security; Daern's Instant Fortress's floors are `safe` places, a building of their own), which still
##   keep the 16 hours.
## Leomund's Tiny Hut and Guards and Wards let a Long Rest start with enemies still in the building (story/wards.gd).
## A Short Rest (owner, 2026-10-12) is taken anywhere outside a fight, a dungeon and a place that allows no sleep
## included, unless a fight on this map was begun and not won (the party ran) or foes awake and in plain view of the
## party are about (LocationStealth.foes_in_sight). Neither starts while a Long Rest is broken (LongRest: what came in
## the night comes first). Pure story logic: no nodes.

const WAIT_MINUTES := 16 * 60
## st.flags: the game minute the party last finished a Long Rest (an underscore key: bookkeeping, not story).
const DONE_AT := "_long_rest_at"
## Why no rest starts while a Long Rest is broken (LongRest.BROKEN): what woke the party comes first, and the rest
## goes on by itself once that's over.
const BROKEN_NIGHT := "Something is out there in the dark. Face it first: the night's rest goes on once it's over."
## st.flags: the Short Rest whose changes (what a Short Rest lets you change: Fiendish Resilience's damage type) are
## still on offer: {at: the game minute it ended, location: where, picks: PrepareScreen.snapshot() as it ended, what a
## swap limit counts from, or {}}. An underscore key: bookkeeping, saved with the game.
const SHORT_CHANGE := "_short_rest_change"
## How long after a Short Rest its changes stay on offer (game minutes), as long as the party stays where it rested.
const CHANGE_MINUTES := 60
## Triggers of fights that come for the party on their own.
const SELF_STARTING: Array[String] = ["enter_area", "open", "examine"]


## Why the party can't start a Long Rest where it stands, one sentence per reason; [] when it can. A place that allows
## no sleep says so in its own words (`rest_text`), and nothing else needs saying.
static func long_rest_refusals(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	var loc := Compendium.shared().get_entry("locations", st.location)
	if str(loc.get("rest", "risky")) == "no":
		out.append(str(loc.get("rest_text", "This place won't let anyone sleep.")))
		return out
	if LongRest.broken(st):
		out.append(BROKEN_NIGHT)
	if not waiting_fights(st, st.location).is_empty() and Wards.shelter(st) == "":
		out.append("Enemies still prowl this place, on this floor or another. Clear them out, rest somewhere else, or ward the rest (Leomund's Tiny Hut, Guards and Wards).")
	var wait := minutes_until_long_rest(st)
	if wait > 0:
		out.append("The last Long Rest ended less than 16 hours ago: the next can start in %s." % duration(wait))
	return out


## A Short Rest has just ended here: its changes stay on offer (short_change) until the next rest, an hour, or the party
## moving on. `picks` is PrepareScreen.snapshot(st, "short_rest") when the caller has it.
static func note_short_rest(st: StoryState, picks: Dictionary = {}) -> void:
	st.flags[SHORT_CHANGE] = {"at": st.total_minutes(), "location": st.location, "picks": picks}


## The Short Rest whose changes are still on offer ({} if none): the party is where it finished, under an hour has gone, and
## no Long Rest has come since (that one offers them itself).
static func short_change(st: StoryState) -> Dictionary:
	var d: Variant = st.flags.get(SHORT_CHANGE, null)
	if not d is Dictionary:
		return {}
	var gone := st.total_minutes() - int((d as Dictionary).get("at", -1))
	if str((d as Dictionary).get("location", "")) != st.location or gone < 0 or gone > CHANGE_MINUTES:
		return {}
	return d as Dictionary


## Why the party can't start a Short Rest where it stands, one sentence per reason; [] when it can: a fight on this
## map begun and not won, or `foes` (the names of those awake and in plain view of the party, from
## LocationStealth.foes_in_sight) about.
static func short_rest_refusals(st: StoryState, foes: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	if LongRest.broken(st):
		out.append(BROKEN_NIGHT)
	if not unfinished_fights(st).is_empty():
		out.append("A fight here isn't over, and its enemies are still about. Finish it, or get well away first.")
	if not foes.is_empty():
		out.append("Foes in sight (%s): nobody rests for an hour in plain view of them. Get out of their sight first." % ", ".join(foes))
	return out


## The fights on the party's map that were begun and not won (the party ran): their ids.
static func unfinished_fights(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	var states := (st.location_states.get(st.location, {}) as Dictionary).get("encounters", {}) as Dictionary
	for en: Variant in Compendium.shared().get_entry("locations", st.location).get("encounters", []):
		var spec := en as Dictionary
		var id := str(spec.get("id", ""))
		if str(states.get(id, false)) == "started" and not id in out \
				and StoryConditions.check(StoryConditions.encounter_when(spec), st):
			out.append(id)
	return out


## Why an item's safe Long Rest (the Rod of Security) can't start yet, or "".
static func item_rest_refusal(st: StoryState) -> String:
	var wait := minutes_until_long_rest(st)
	return "" if wait <= 0 else "The last Long Rest ended less than 16 hours ago: the next can start in %s." % duration(wait)


## Minutes until the party may start another Long Rest (0 when it may now).
static func minutes_until_long_rest(st: StoryState) -> int:
	if not st.flags.has(DONE_AT):
		return 0
	return maxi(0, int(st.flags[DONE_AT]) + WAIT_MINUTES - st.total_minutes())


## Notes that the party has just finished a Long Rest.
static func note_long_rest(st: StoryState) -> void:
	st.flags[DONE_AT] = st.total_minutes()
	# 8-hour exploring spells (the house rule, Effect.until_long_rest) end with the rest.
	for id: String in st.active_spells.keys():
		if bool((st.active_spells[id] as Dictionary).get("long_rest", false)):
			st.active_spells.erase(id)


## An exploring spell running until the next Long Rest (Effect.until_long_rest): no clock on it.
static func keep_until_long_rest(st: StoryState, spell_id: String) -> void:
	var a := st.active_spells.get(spell_id, {}) as Dictionary
	if a.is_empty():
		return
	a["until"] = st.total_minutes() + 100 * 365 * 24 * 60
	a["long_rest"] = true


## "7 hours 30 minutes", "1 hour", "45 minutes".
static func duration(minutes: int) -> String:
	var h := minutes / 60
	var m := minutes % 60
	var parts: Array[String] = []
	if h > 0:
		parts.append("%d hour%s" % [h, "" if h == 1 else "s"])
	if m > 0 or h == 0:
		parts.append("%d minute%s" % [m, "" if m == 1 else "s"])
	return " ".join(parts)


## The maps of the building or dungeon `location_id` is part of: it and every walled map an exit joins it to, either
## way, and theirs. [] for a map in the open (a town, a road, a camp).
static func building_of(location_id: String) -> Array[String]:
	var out: Array[String] = []
	if not _walled(location_id):
		return out
	var links := _links()
	var todo: Array[String] = [location_id]
	while not todo.is_empty():
		var id: String = todo.pop_back()
		if id in out:
			continue
		out.append(id)
		for other: Variant in links.get(id, []):
			if not str(other) in out and _walled(str(other)):
				todo.append(str(other))
	return out


## The fights still waiting in the building or dungeon `location_id` is part of: [{location, id}] for each whose
## condition holds, that hasn't been won, and that starts on its own or was begun and not won.
static func waiting_fights(st: StoryState, location_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for loc_id in building_of(location_id):
		var states := (st.location_states.get(loc_id, {}) as Dictionary).get("encounters", {}) as Dictionary
		var loc := Compendium.shared().get_entry("locations", loc_id)
		for en: Variant in loc.get("encounters", []):
			var spec := en as Dictionary
			var state: Variant = states.get(str(spec.get("id", "")), false)
			if state is bool and bool(state):
				continue
			var begun := str(state) == "started"
			if not begun and not str(spec.get("trigger", "")).get_slice(":", 0) in SELF_STARTING:
				continue
			# One not begun yet waits out the region's truce (Strahd's dinner guests) like the fight itself.
			if not StoryConditions.check(StoryConditions.encounter_when(spec, "" if begun else str(loc.get("region", ""))), st):
				continue
			out.append({"location": loc_id, "id": str(spec.get("id", ""))})
	return out


## Indoors, or a dungeon's open-air map (a castle's roofs).
static func _walled(location_id: String) -> bool:
	var loc := Compendium.shared().get_entry("locations", location_id)
	if loc.is_empty():
		return false
	var map := loc.get("map", {}) as Dictionary
	return not bool(map.get("outdoors", false)) or str(map.get("theme", "")) == "dungeon"


## Location id -> the maps an exit leads to from it or comes to it from.
static func _links() -> Dictionary:
	var out := {}
	for l: Variant in Compendium.shared().all("locations"):
		var loc := l as Dictionary
		var id := str(loc.get("id", ""))
		for ex: Variant in loc.get("exits", []):
			var to := str((ex as Dictionary).get("to", ""))
			if to == "" or to == id:
				continue
			for pair: Array in [[id, to], [to, id]]:
				if not out.has(pair[0]):
					out[pair[0]] = []
				if not pair[1] in (out[pair[0]] as Array):
					(out[pair[0]] as Array).append(pair[1])
	return out
