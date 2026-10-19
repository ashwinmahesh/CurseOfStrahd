class_name RoadFamiliarity
extends RefCounted
## Familiar ground on the roads (Ashwin, 2026-10-18: "if we are travelling a path to visit somewhere we have already
## been, reduce the rate of combat random encounters"; again 2026-10-19: "still too many random combat encounters for
## paths we've already travelled"). A leg of a journey is familiar when the party has walked its road before (noted as
## each leg ends, either way along it), when the leg ends at a place the party has already been, or when the journey is
## going somewhere it has already been (a place's location is in `visited`, which also covers a save from before roads
## were noted). The leg test is what quiets the stretches of a journey to somewhere new that run over known ground. A
## familiar leg rolls SCALE of its table's own chance (Travel.roll). Strahd's attention and the weather are added after
## that, so his eyes and a storm are not quieted by a road the party knows. A first visit, a story fight, Strahd's own
## visits on the road (StrahdPresence) and the walk-in fights of a place are never touched.

## A familiar leg's share of its table's chance: 15% by day becomes 1.5%, 40% by night 4% (it was 40% of the chance,
## 6% and 16%, which on a four-leg known route still met something on one journey in four by day and one in two by night).
const SCALE := 0.1
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


## Whether the party has been to the travel place (by id): its location is in `visited`.
static func been(st: StoryState, place_id: String) -> bool:
	if place_id == "":
		return false
	var loc := str(Travel.place(place_id).get("location", "")).get_slice(":", 0)
	return loc != "" and st.visited.has(loc)


## Whether a leg on `road` is familiar: its road walked before, or the place it ends at (`leg_to`, "" when unknown) or
## `journey_to` (the place the journey is bound for, "" when unknown) a place the party has already been to.
static func familiar(st: StoryState, road: Dictionary, journey_to: String = "", leg_to: String = "") -> bool:
	return walked(st, str(road.get("id", ""))) or been(st, leg_to) or been(st, journey_to)


## What a leg's chance is multiplied by: SCALE on familiar ground, else 1.
static func scale(st: StoryState, road: Dictionary, journey_to: String = "", leg_to: String = "") -> float:
	return SCALE if familiar(st, road, journey_to, leg_to) else 1.0
