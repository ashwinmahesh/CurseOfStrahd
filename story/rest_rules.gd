class_name RestRules
extends RefCounted
## When and where the party may start a Long Rest (owner rules, 2026-10-09):
## - not within 16 hours of finishing the last one (2024 PHB), so two back to back can't clear Exhaustion or the Raise
##   Dead penalty twice in a night;
## - not in a dungeon or any building while enemies remain in it, on any of its floors (docs/rules/deviations.md). A
##   building is its walled maps (indoors, and a dungeon's open-air ones such as Castle Ravenloft's roofs) joined by
##   their exits. Enemies remain while one of its fights would still start on its own (entering an area, opening a door
##   or a chest, examining something) or one was begun and not won; a fight only a conversation can start doesn't
##   count. Towns, inns, camps and the open road are unaffected, and so are the magic items that make a safe place to
##   sleep (Daern's Instant Fortress, the Rod of Security), which still keep the 16 hours.
## Short Rests are never refused here. Pure story logic: no nodes.

const WAIT_MINUTES := 16 * 60
## st.flags: the game minute the party last finished a Long Rest (an underscore key: bookkeeping, not story).
const DONE_AT := "_long_rest_at"
## Triggers of fights that come for the party on their own.
const SELF_STARTING: Array[String] = ["enter_area", "open", "examine"]


## Why the party can't start a Long Rest where it stands, one sentence per reason; [] when it can.
static func long_rest_refusals(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	if not waiting_fights(st, st.location).is_empty():
		out.append("Enemies still prowl this place, on this floor or another. Clear them out, or rest somewhere else.")
	var wait := minutes_until_long_rest(st)
	if wait > 0:
		out.append("The last Long Rest ended less than 16 hours ago: the next can start in %s." % duration(wait))
	return out


## Why an item's safe Long Rest (Daern's Instant Fortress, the Rod of Security) can't start yet, or "".
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
		for en: Variant in Compendium.shared().get_entry("locations", loc_id).get("encounters", []):
			var spec := en as Dictionary
			var state: Variant = states.get(str(spec.get("id", "")), false)
			if state is bool and bool(state):
				continue
			var begun := str(state) == "started"
			if not begun and not str(spec.get("trigger", "")).get_slice(":", 0) in SELF_STARTING:
				continue
			if not StoryConditions.check(StoryConditions.encounter_when(spec), st):
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
