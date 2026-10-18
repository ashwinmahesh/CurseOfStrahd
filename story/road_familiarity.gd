class_name RoadFamiliarity
extends RefCounted
## Familiar ground on the roads (Ashwin, 2026-10-18: "if we are travelling a path to visit somewhere we have already
## been, reduce the rate of combat random encounters"). A leg of a journey is familiar when the party has walked its road
## before (noted as each leg ends, either way along it), or when the journey is going somewhere the party has already been
## (the destination's location is in `visited`, which also covers a save from before roads were noted). A familiar leg
## rolls SCALE of its table's own chance (Travel.roll). Strahd's attention and the weather are added after that, so his
## eyes and a storm are not quieted by a road the party knows. A first visit, a story fight, Strahd's own visits on the
## road (StrahdPresence) and the walk-in fights of a place are never touched.

## A familiar leg's share of its table's chance: 15% by day becomes 6%, 40% by night 16%.
const SCALE := 0.4
## The saved set of roads walked: {road id: true}. An underscore flag is the story's own, never a quest's.
const FLAG := "_roads_walked"


## Whether the party has walked the road (by id) before.
static func walked(st: StoryState, road_id: String) -> bool:
	return road_id != "" and (st.flags.get(FLAG, {}) as Dictionary).has(road_id)


## Notes a road as walked once a leg along it is over (after its encounter roll, so the first walk is not yet familiar).
static func note(st: StoryState, road: Dictionary) -> void:
	var id := str(road.get("id", ""))
	if id == "":
		return
	var roads := st.flags.get(FLAG, {}) as Dictionary
	roads[id] = true
	st.flags[FLAG] = roads


## Whether a leg on `road` is familiar: its road walked before, or `journey_to` (the place the journey is bound for, "" when
## unknown) a place whose location the party has already visited.
static func familiar(st: StoryState, road: Dictionary, journey_to: String = "") -> bool:
	if walked(st, str(road.get("id", ""))):
		return true
	if journey_to == "":
		return false
	var loc := str(Travel.place(journey_to).get("location", "")).get_slice(":", 0)
	return loc != "" and st.visited.has(loc)


## What a leg's chance is multiplied by: SCALE on familiar ground, else 1.
static func scale(st: StoryState, road: Dictionary, journey_to: String = "") -> float:
	return SCALE if familiar(st, road, journey_to) else 1.0
