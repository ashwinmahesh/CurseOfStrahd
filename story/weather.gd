class_name Weather
extends RefCounted
## Weather as world state (F12; data/weather/barovia.json, docs/regions/weather.md). Each region has a climate (the
## valley's fog and rain, Krezk's and the Abbey's highland snow, the mountains' blizzards, Strahd's own storms over the
## castle); the weather holds for a spell of six hours, picked from the climate's weights by the playthrough's seed, the
## day and the spell, so nothing is saved and a reload never changes it. Strahd's attention (F9) brings more storms.
## What it does: slows journeys (`travel`), brings more on the roads (`road_day`, `road_night`), obscures sight in the
## open (`obscures`: Disadvantage on Perception that relies on sight, so -5 to passive), and is a condition
## (`weather == fog`). Lane 6's Atmosphere dresses a place's look from it (dress_mood); the fight half (obscured
## squares, Call Lightning's storm) is lane 2's and reads now().

const PATH := "res://data/weather/barovia.json"
const SPELL_HOURS := 6

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed as Dictionary if parsed is Dictionary else {"kinds": {}, "climates": {}}
	return _data


## Tests swap in their own; use({}) goes back to the file.
static func use(d: Dictionary) -> void:
	_data = d


## The climate a location lies in (its region's, else the default).
static func climate_of(location_id: String) -> String:
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", ""))
	return str((data().get("regions", {}) as Dictionary).get(region, data().get("default_climate", "valley")))


## The weather at a location now (where the party is, by default): a kind id from data's `kinds`.
static func now(st: StoryState, location_id: String = "") -> String:
	return at(st, location_id if location_id != "" else st.location, st.total_minutes())


## The weather at a location at a moment (total minutes): the same answer every time for the same playthrough.
static func at(st: StoryState, location_id: String, minute: int) -> String:
	var climate := climate_of(location_id)
	var weights := ((data().get("climates", {}) as Dictionary).get(climate, {}) as Dictionary).duplicate()
	if weights.is_empty():
		return "overcast"
	# Strahd's temper (F9): the more he has noticed the party, the more storms over his valley.
	if weights.has("storm"):
		var tier := str(StrahdPresence.tier(st).get("id", ""))
		weights["storm"] = float(weights["storm"]) * float((data().get("storm_by_attention", {}) as Dictionary).get(tier, 1.0))
	var spell := floori(float(minute) / (SPELL_HOURS * 60))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d:weather" % [st.playthrough_seed, climate, spell])
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var pick := rng.randf() * total
	var ids: Array = weights.keys()
	ids.sort()   # the same order every run, whatever order the file lists them in
	for k: String in ids:
		pick -= float(weights[k])
		if pick <= 0.0:
			return k
	return str(ids[ids.size() - 1])


## What a kind does: {label, travel, road_day, road_night, obscures, flames_out, look, line}.
static func kind(id: String) -> Dictionary:
	return (data().get("kinds", {}) as Dictionary).get(id, {}) as Dictionary


static func label(st: StoryState, location_id: String = "") -> String:
	var id := now(st, location_id)
	return str(kind(id).get("label", id.capitalize()))


## How much longer a journey takes setting out from a location now (1.0: no slower).
static func travel_mult(st: StoryState, location_id: String = "") -> float:
	return float(kind(now(st, location_id)).get("travel", 1.0))


## How much likelier something is met on the road in this weather (added to the table's chance).
static func road_bonus(st: StoryState, location_id: String = "") -> float:
	return float(kind(now(st, location_id)).get("road_night" if st.is_night() else "road_day", 0.0))


## The Disadvantage sources for sight-based Perception out in the open here ([] indoors, or in clear enough weather).
static func sight_penalty(st: StoryState, location_id: String = "") -> Array[String]:
	var loc_id := location_id if location_id != "" else st.location
	var out: Array[String] = []
	var loc := Compendium.shared().get_entry("locations", loc_id)
	if not bool((loc.get("map", {}) as Dictionary).get("outdoors", false)):
		return out
	var k := kind(now(st, loc_id))
	if bool(k.get("obscures", false)):
		out.append(str(k.get("label", "Weather")))
	return out


## A place's look (lane 6's mood, art/atmosphere/moods.json) dressed for the weather: outdoors, its own rain and snow
## give way to the world's (a kind's `look`: rain or snow and how much) and fog thickens its mist. Indoors it is
## unchanged.
static func dress_mood(st: StoryState, location_id: String, mood: Dictionary, outdoors: bool) -> Dictionary:
	if not outdoors:
		return mood
	var look := kind(now(st, location_id)).get("look", {}) as Dictionary
	var out := mood.duplicate(true)
	var pieces: Array = []
	for w: Variant in mood.get("weather", []):
		var k := str(w) if not (w is Dictionary) else str((w as Dictionary).get("kind", ""))
		if not k in ["rain", "snow"]:
			pieces.append(w)
	for k: String in ["rain", "snow"]:
		if look.has(k):
			pieces.append({"kind": k, "amount": int(look[k])})
	out["weather"] = pieces
	if look.has("strikes"):
		out["strikes"] = (look["strikes"] as Dictionary).duplicate()   # lightning now and then (Atmosphere._lightning)
	if look.has("mist"):
		var mist := (out.get("mist", {}) as Dictionary).duplicate()
		var strength := float(mist.get("strength", 1.0)) * float((look["mist"] as Dictionary).get("strength", 1.0))
		mist.merge(look["mist"] as Dictionary, true)
		mist["strength"] = strength   # the weather scales the place's own (a town's fog lighter than the woods')
		out["mist"] = mist
	return out
