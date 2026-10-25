class_name Travel
extends RefCounted
## Travelling Barovia (plan §5.2, ADR 0010): places joined by roads on data/travel/barovia.json. A journey follows
## the quickest known roads; each road takes its hours off the clock and rolls its random encounter table (the
## day or night chance, lowered on ground the party knows and raised by Strahd's attention and by fog, then a weighted
## entry whose condition holds); bad weather lengthens a leg (Weather, F12). Pure logic: the game root moves the party.

const MAP := "barovia"


## The one map: data/travel/barovia.json, then every region's own file (ADR 0011) in id order, places and roads
## merged, so writers of different regions never edit the same file.
static func map_data() -> Dictionary:
	var files := Compendium.shared().table("travel")
	var out := (files.get(MAP, {}) as Dictionary).duplicate()
	var places: Array = (out.get("places", []) as Array).duplicate()
	var roads: Array = (out.get("roads", []) as Array).duplicate()
	var ids: Array = files.keys()
	ids.sort()
	for id: Variant in ids:
		if str(id) == MAP:
			continue
		var f := files[id] as Dictionary
		places.append_array(f.get("places", []) as Array)
		roads.append_array(f.get("roads", []) as Array)
	out["places"] = places
	out["roads"] = roads
	return out


static func place(place_id: String) -> Dictionary:
	for p: Variant in map_data().get("places", []):
		if str((p as Dictionary)["id"]) == place_id:
			return p as Dictionary
	return {}


## Whether `location_id` is a map a journey stops on: a random encounter table's own map (where its meetings play and
## Strahd's visit on the road does), a battle ground the table or a road names (RoadGrounds), or the Old Svalich Road
## Strahd's visit falls back to. A journey that is waiting (StoryState.travel_resume) is only ever on such a map.
static func is_road_scene(location_id: String) -> bool:
	if location_id == "":
		return false
	if location_id == "road_ambush":
		return true
	for t: Variant in Compendium.shared().table("random_encounters").values():
		var table := t as Dictionary
		if str(table.get("map", "")) == location_id or (table.get("grounds", []) as Array).has(location_id):
			return true
	for r: Variant in map_data().get("roads", []):
		if ((r as Dictionary).get("grounds", []) as Array).has(location_id):
			return true
	return false


## The travel place whose location the party is in (or "").
static func place_for_location(location_id: String) -> String:
	for p: Variant in map_data().get("places", []):
		if str((p as Dictionary)["location"]).get_slice(":", 0) == location_id:
			return str((p as Dictionary)["id"])
	return ""


## Places the party knows of (owner decision 2026-10-06, "next stop"): where it has been, places one open road from
## there, and places it has heard of (their `when` holds). A place with no `when` is common knowledge only once the
## party is one road from it; a place with a `when` stays unknown until it holds, however close.
static func known(st: StoryState) -> Array[Dictionary]:
	var places := map_data().get("places", []) as Array
	var been := {}
	for p: Variant in places:
		if st.visited.has(str((p as Dictionary)["location"]).get_slice(":", 0)):
			been[str((p as Dictionary)["id"])] = true
	var near := {}
	for r: Variant in map_data().get("roads", []):
		var road := r as Dictionary
		if not StoryConditions.check(str(road.get("when", "")), st):
			continue
		if been.has(str(road["from"])):
			near[str(road["to"])] = true
		if been.has(str(road["to"])):
			near[str(road["from"])] = true
	var out: Array[Dictionary] = []
	for p: Variant in places:
		var pl := p as Dictionary
		var id := str(pl["id"])
		var when := str(pl.get("when", ""))
		if been.has(id) or (when == "" and near.has(id)) or (when != "" and StoryConditions.check(when, st)):
			out.append(pl)
	return out


## Roads open now (their `when` holds) between known places.
static func roads(st: StoryState) -> Array[Dictionary]:
	var ids := {}
	for p in known(st):
		ids[str(p["id"])] = true
	var out: Array[Dictionary] = []
	for r: Variant in map_data().get("roads", []):
		var road := r as Dictionary
		if ids.has(str(road["from"])) and ids.has(str(road["to"])) and StoryConditions.check(str(road.get("when", "")), st):
			out.append(road)
	return out


## The quickest way from one place to another: [{road, from, to, hours}], or [] if there's none.
static func route(from: String, to: String, st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if from == to:
		return out
	var dist := {from: 0.0}
	var prev := {}
	var open: Array[String] = [from]
	var rs := roads(st)
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool: return float(dist[a]) < float(dist[b]))
		var here := open.pop_front() as String
		if here == to:
			break
		for road in rs:
			var a := str(road["from"])
			var b := str(road["to"])
			if a != here and b != here:
				continue
			var there := b if a == here else a
			var d := float(dist[here]) + float(road["hours"])
			if not dist.has(there) or d < float(dist[there]):
				dist[there] = d
				prev[there] = {"road": road, "from": here}
				if not there in open:
					open.append(there)
	if not prev.has(to):
		return out
	var at := to
	while at != from:
		var p := prev[at] as Dictionary
		var road := p["road"] as Dictionary
		# Magic that speeds journeys (a Carpet of Flying, Horseshoes of Speed, a Feather Token's roc): fewer hours. Bad
		# weather where the leg sets out (a storm, snow, a blizzard; Weather, F12): more.
		var weather := Weather.travel_mult(st, str(place(str(p["from"])).get("location", "")).get_slice(":", 0))
		out.push_front({"road": road, "from": str(p["from"]), "to": at, "hours": float(road["hours"]) / FieldItems.travel_mult(st) * weather})
		at = str(p["from"])
	return out


static func hours(legs: Array[Dictionary]) -> float:
	var h := 0.0
	for l in legs:
		h += float(l["hours"])
	return h


## Rolls a road's random encounter table for one leg (at the time the leg ends). Returns {} for a quiet road, or
## {table, entry} for a fight or an event. Uses the dice (d100 for the chance, then the weights). `journey_to` is the
## place the journey is bound for and `leg_to` the place this leg ends at: a road the party has walked, or a place it
## has been, is familiar ground (RoadFamiliarity).
static func roll(road: Dictionary, st: StoryState, dice: DiceRoller, journey_to: String = "", leg_to: String = "") -> Dictionary:
	var tid := str(road.get("table", ""))
	if tid == "":
		return {}
	# Find the Path: the party knows the safe way while it lasts (a day).
	if st.spell_active("find_the_path"):
		return {}
	var table := Compendium.shared().get_entry("random_encounters", tid)
	if table.is_empty():
		return {}
	var chance := float(table["chance_night"]) if st.is_night() else float(table["chance_day"])
	# Ground the party knows is quieter (Ashwin, 2026-10-18); Strahd's eyes and the weather are added after.
	chance *= RoadFamiliarity.scale(st, road, journey_to, leg_to)
	# Strahd's attention (F9): the more he has noticed the party, the more of his eyes and patrols are on the roads.
	var watch := Campaign.module().presence_tier(st)
	chance = minf(0.95, chance + float(watch.get("road_night" if st.is_night() else "road_day", 0.0)) + Weather.road_bonus(st))
	var d100 := dice.roll_one(100, "Random encounter on %s" % road.get("name", road["id"]))
	if d100 > roundi(chance * 100.0):
		return {}
	var pool: Array[Dictionary] = []
	var total := 0
	var seen := st.flags.get("_random_seen", {}) as Dictionary
	for e: Variant in table["entries"]:
		var entry := e as Dictionary
		if not StoryConditions.check(str(entry.get("when", "")), st):
			continue
		if bool(entry.get("once", false)) and seen.has("%s:%s" % [tid, entry.get("id", "")]):
			continue
		pool.append(entry)
		total += int(entry["weight"])
	if pool.is_empty():
		return {}
	var pick := dice.roll_one(total, "Random encounter on %s: which" % road.get("name", road["id"]))
	for entry in pool:
		pick -= int(entry["weight"])
		if pick <= 0:
			if bool(entry.get("once", false)):
				seen["%s:%s" % [tid, entry.get("id", "")]] = true
				st.flags["_random_seen"] = seen
			return {"table": table, "entry": entry}
	return {}
