class_name CampSite
extends RefCounted
## Where and how the party makes camp (F16, lane 24; docs/story/camp.md). A Long Rest taken anywhere the place's own
## rest is risky (the wild, the road, a town's streets, a house, a dungeon) pitches a camp on the place's own map, near
## where the party stands: a fire with a stew pot and a woodpile beside it, the company round it (the party, the
## companions waiting at camp, the story's guests), a bedroll behind each of them, and out of doors a tent and packs
## where there's room. A safe place (an inn, a house that takes the party in, a booked room) keeps the rest screen.
## Pure story logic: LocationCamp puts it on the map, and these are the rules it follows.

## Board themes of the open places a camp is made in (not towns, villages or the ruins of a dungeon).
const WILD_THEMES: Array[String] = ["forest", "riverside", "road", "svalich_road", "wilderness", "shrine_yard", "camp"]
## The camp's settings (setting()): the wild, a town's or village's streets, and indoors (under a roof, or in a dungeon).
const WILD := "wild"
const TOWN := "town"
const INDOORS := "indoors"
## How far from the party (in feet, walking) the fire should be; with no room that near, anywhere the party can walk to.
const REACH_FT := 40
## The lowest score of a whole camp within REACH_FT (_site_score): found there, the search goes no further.
const WHOLE_NEAR := 4_000_000
## Squares round the fire where people sit, in the order they take them (x east, y south: the camera looks north).
const SEATS: Array[Vector2i] = [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(-2, 1),
	Vector2i(2, 1), Vector2i(0, -2), Vector2i(-2, -1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 2)]
## How far from the fire (in feet, walking) someone without a seat stands, in a camp too cramped for everyone to sit.
const STAND_FT := 30
## Ratatouille's place at the stew pot, and the pot's (beside the fire).
const COOK := Vector2i(2, -1)
const POT := Vector2i(1, -1)
const WOOD := Vector2i(-1, -1)
## The tent, at the back of the camp, and the packs beside it.
const TENT := Vector2i(0, -4)
const PACKS := Vector2i(2, -3)
## The companion who cooks (the stew pot is his).
const COOK_ID := "ratatoille"
## How far a camp's ground may rise or fall from the fire's (one step of a slope).
const STEP_FT := 5
## Grid flags a camp's square can't have: walls and low clutter, water, the void, rough ground.
const ROUGH := CombatGrid.WALL | CombatGrid.LOW | CombatGrid.VOID | CombatGrid.WATER | CombatGrid.DIFFICULT


## Whether a Long Rest at `loc` makes camp: wherever the place's own rest is risky (decided on the place's own rule,
## not the Story difficulty's safe rests). A safe place (an inn, a house that takes the party in, a sanctuary) keeps
## the rest screen, and a place that allows no rest allows none. The rest screen also keeps it for a room booked for
## the night, the tutorial and the magic items' rests.
static func makes_camp(loc: Dictionary) -> bool:
	return loc.has("map") and str(loc.get("rest", "risky")) == "risky"


## Where a camp at `loc` is: INDOORS (under a roof, or in a dungeon), WILD (an open place: WILD_THEMES), else TOWN (a
## town's or village's streets). It picks the camp's pieces (no tent indoors), the Narrator's lines and the night's
## visitors.
static func setting(loc: Dictionary) -> String:
	var map := loc.get("map", {}) as Dictionary
	var theme := str(map.get("theme", ""))
	if not bool(map.get("outdoors", false)) or theme == "dungeon":
		return INDOORS
	return WILD if theme in WILD_THEMES else TOWN


## The Narrator's triggers for `key` at a camp in `where` (setting()), the setting's own first: camp:pitch:indoors,
## then camp:pitch.
static func keys_for(key: String, where: String) -> Array[String]:
	return [key + ":" + where, key]


## The Narrator's triggers for the night slept at a camp at `loc_id` in `region`, in `where` (setting()), in order: the
## place's own night, its region's, the camp's for the setting, the camp's, and anyone's. A place's or region's night
## written for sleeping behind walls carries [indoors] (and one for the open air [not indoors]), so a camp where it
## doesn't fit passes over it to the camp's own.
static func night_keys(loc_id: String, region: String, where: String) -> Array[String]:
	var out: Array[String] = ["rest:long:" + loc_id, "rest:long:" + region]
	out.append_array(keys_for("camp:night", where))
	out.append("rest:long")
	return out


## The squares the place's own things stand on (props, containers, doors, ways out, lights, its people's spots and
## traps), and (with `fights`, for the camp itself) the areas a fight starts in as the party walks in, as a set.
static func things_at(loc: Dictionary, fights := true) -> Dictionary:
	var out := {}
	for list: String in ["props", "containers", "doors", "exits", "lights", "npcs"]:
		for t: Variant in loc.get(list, []):
			var spec := t as Dictionary
			if not spec.has("cell"):
				continue
			var at := _cell(spec["cell"])
			var span := spec.get("span", [1, 1]) as Array
			for dy in int(span[1]) if span.size() == 2 else 1:
				for dx in int(span[0]) if span.size() == 2 else 1:
					out[at + Vector2i(dx, dy)] = true
	for t: Variant in loc.get("traps", []):
		for c: Variant in (t as Dictionary).get("cells", []):
			out[_cell(c)] = true
	if not fights:
		return out
	var ambush := {}
	for en: Variant in loc.get("encounters", []):
		var trigger := str((en as Dictionary).get("trigger", ""))
		if trigger.begins_with("enter_area:"):
			ambush[trigger.substr(11)] = true
	for a: Variant in loc.get("areas", []):
		var area := a as Dictionary
		var corners := area.get("cells", []) as Array
		if not ambush.has(str(area.get("id", ""))) or corners.size() != 2:
			continue
		var p := _cell(corners[0])
		var q := _cell(corners[1])
		for y in range(mini(p.y, q.y), maxi(p.y, q.y) + 1):
			for x in range(mini(p.x, q.x), maxi(p.x, q.x) + 1):
				out[Vector2i(x, y)] = true
	return out


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


## Whether a camp can use square `c`: open, within a step of the fire's ground (`height`: a gentle slope will do, a
## ledge won't), and free of the place's things (`taken`).
static func open_square(grid: CombatGrid, c: Vector2i, height: int, taken: Dictionary) -> bool:
	return grid.in_bounds(c) and grid.flags(c) & ROUGH == 0 and absi(grid.height(c) - height) <= STEP_FT and not taken.has(c)


## The fire's square for a camp near `near` for `people` people, or (-1, -1) when no square the party can walk to
## will take a fire (then the party sleeps where it stands). In order: the square within REACH_FT whose neighbours are
## all open with a seat for everyone and the most open ground round it; else the nearest such square anywhere the
## party can walk to; else a smaller camp (fewer seats and bedrolls, the rest standing where there's room), the most
## seats first and the nearest, within reach before further off.
static func find_center(grid: CombatGrid, near: Vector2i, taken: Dictionary, people: int) -> Vector2i:
	var reach := grid.reachable(near, 1, grid.width * grid.depth * CombatGrid.FEET * 2, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	reach[near] = {"cost": 0}
	var need := mini(people, SEATS.size())
	var best := Vector2i(-1, -1)
	var best_score := -1
	# Within reach first (the usual camp), then, with no whole camp there, the rest of the map.
	for far: bool in [false, true]:
		for c: Vector2i in reach:
			var cost := int((reach[c] as Dictionary).get("cost", 0))
			if (cost > REACH_FT) != far:
				continue
			var score := _site_score(grid, c, taken, need, cost)
			if score > best_score:
				best_score = score
				best = c
		if best_score >= WHOLE_NEAR:
			break
	return best


## How a camp round the fire at `c` ranks (find_center), `cost` feet from the party: -1 if no fire can go there. A whole
## camp (its eight neighbours open, a seat for everyone) near the party: room counts most, then level ground, and a
## square nearer the party breaks a tie. Further off, the nearest whole camp. A smaller camp: the most seats, then the
## fullest ring round the fire, then the nearest, within reach before further off.
static func _site_score(grid: CombatGrid, c: Vector2i, taken: Dictionary, need: int, cost: int) -> int:
	var h := grid.height(c)
	if not open_square(grid, c, h, taken):
		return -1
	var ring := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and open_square(grid, c + Vector2i(dx, dy), h, taken):
				ring += 1
	var seats := 0
	for s in SEATS:
		if open_square(grid, c + s, h, taken):
			seats += 1
	var near_enough := cost <= REACH_FT
	if ring < 8 or seats < need:
		return (2_000_000 if near_enough else 1_000_000) + seats * 50_000 + ring * 5_000 - mini(cost, 4_999)
	if not near_enough:
		return 3_000_000 - mini(cost, 9_999) * 10
	var room := 0
	var level := 0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if open_square(grid, c + Vector2i(dx, dy), h, taken):
				room += 1
				if grid.height(c + Vector2i(dx, dy)) == h:
					level += 1
	return WHOLE_NEAR + room * 1000 + level * 10 - cost


## The camp round the fire at `center` for `people` people (the cook first when `cook`; a tent at the back when
## `tent`, out of doors): {props: [location props], seats: [squares, in order], cook: square or (-1, -1)}. Pieces that
## don't fit are left out; in a camp too cramped for everyone to sit, the rest stand where there's room nearby.
static func layout(grid: CombatGrid, center: Vector2i, taken: Dictionary, people: int, cook: bool, tent := true) -> Dictionary:
	var h := grid.height(center)
	var used := {center: true}
	var props: Array[Dictionary] = [_piece("camp_fire", center, "campfire", "examine", "The campfire")]
	var cook_at := Vector2i(-1, -1)
	if open_square(grid, center + POT, h, taken):
		props.append(_piece("camp_stewpot", center + POT, "stewpot", "examine", "The stew pot"))
		used[center + POT] = true
		if cook and open_square(grid, center + COOK, h, taken):
			cook_at = center + COOK
			used[cook_at] = true
	if open_square(grid, center + WOOD, h, taken):
		props.append(_piece("camp_woodpile", center + WOOD, "woodpile", "decor", "Firewood"))
		used[center + WOOD] = true
	var seats: Array[Vector2i] = []
	var want := people - (1 if cook_at.x >= 0 else 0)
	for s in SEATS:
		if seats.size() >= want:
			break
		var c := center + s
		if open_square(grid, c, h, taken) and not used.has(c):
			seats.append(c)
			used[c] = true
	if seats.size() < want:
		for c in _standing(grid, center, taken, used, want - seats.size()):
			seats.append(c)
			used[c] = true
	# A bedroll behind each seat, its head away from the fire.
	var sleepers: Array[Vector2i] = []
	if cook_at.x >= 0:
		sleepers.append(cook_at)
	sleepers.append_array(seats)
	var n := 0
	for c in sleepers:
		var out_step := Vector2i(signi(c.x - center.x), signi(c.y - center.y))
		for bed: Vector2i in [c + out_step, c + Vector2i(out_step.x, 0), c + Vector2i(0, out_step.y)]:
			if bed != c and open_square(grid, bed, h, taken) and not used.has(bed):
				n += 1
				var p := _piece("camp_bedroll_%d" % n, bed, "bedroll", "decor", "A bedroll")
				p["facing"] = _facing(center - bed)
				props.append(p)
				used[bed] = true
				break
	# The tent at the back, with room either side of it; the packs beside it.
	var back := center + TENT
	if tent and open_square(grid, back, h, taken) and open_square(grid, back + Vector2i(-1, 0), h, taken) \
			and open_square(grid, back + Vector2i(1, 0), h, taken) and not used.has(back):
		var p2 := _piece("camp_tent", back, "tent", "examine", "The tent")
		p2["facing"] = "south"
		props.append(p2)
		used[back] = true
	if open_square(grid, center + PACKS, h, taken) and not used.has(center + PACKS):
		props.append(_piece("camp_packs", center + PACKS, "sack_pile", "decor", "The packs"))
	return {"props": props, "seats": seats, "cook": cook_at}


## Up to `n` squares where people without a seat stand in a cramped camp: open ground within STAND_FT of the fire
## that can be walked to from it, nearest first, clear of the place's things and the camp's own.
static func _standing(grid: CombatGrid, center: Vector2i, taken: Dictionary, used: Dictionary, n: int) -> Array[Vector2i]:
	var reach := grid.reachable(center, 1, STAND_FT, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	var spots: Array[Vector2i] = []
	for c: Vector2i in reach:
		if grid.in_bounds(c) and grid.flags(c) & ROUGH == 0 and not taken.has(c) and not used.has(c):
			spots.append(c)
	spots.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		var cp := int((reach[p] as Dictionary)["cost"])
		var cq := int((reach[q] as Dictionary)["cost"])
		return cp < cq or (cp == cq and (p.y < q.y or (p.y == q.y and p.x < q.x))))
	return spots.slice(0, n)


static func _piece(id: String, cell: Vector2i, model: String, kind: String, label: String) -> Dictionary:
	return {"id": id, "cell": [cell.x, cell.y], "model": model, "kind": kind, "label": label, "camp": true}


## The compass word for a direction on the map (props' `facing`).
static func _facing(dir: Vector2i) -> String:
	var ns := "north" if dir.y < 0 else ("south" if dir.y > 0 else "")
	var ew := "west" if dir.x < 0 else ("east" if dir.x > 0 else "")
	return ns + ew if ns + ew != "" else "south"


# --- Who is at camp, and what they have to say --------------------------------------------------------------------

## The companions waiting at camp who are by the fire when the party makes camp: the bench, living, and never one of
## the companions retired from the roster (the original four, kept for old saves only).
static func company(st: StoryState) -> Array[Character]:
	var out: Array[Character] = []
	for ch in st.bench:
		if not ch.dead and not retired(ch):
			out.append(ch)
	return out


## Whether `ch` is a pregenerated companion no longer on the roster (data/pregens `roster: false`).
static func retired(ch: Character) -> bool:
	var pregen := Compendium.shared().get_entry("pregens", ch.id)
	return not pregen.is_empty() and not bool(pregen.get("roster", false)) \
		and not bool((ch.build.get("appearance", {}) as Dictionary).get("custom", false))


## The talks waiting at camp, by who asks (CampTalk, narrative/camp/): {asker's id (a character id, or `guest_<npc>`):
## talk ref}, one each, leaving out anyone in `had` (who has had their word this evening, or this morning).
static func talks(st: StoryState, had: Dictionary) -> Dictionary:
	var out := {}
	for t in CampTalk.available(st):
		var ref := str(t["ref"])
		var who := asker(st, ref)
		if who != "" and not had.has(who) and not out.has(who):
			out[who] = ref
	return out


## Who asks for a talk: the first companion or travelling guest its condition names who is here (CampTalk.who_asks, as
## CampTalk.label_for reads it), as the id the camp seats them by (`people`): a character id, or `guest_<npc>` for a
## story ally; "" if none of them is.
static func asker(st: StoryState, ref: String) -> String:
	var df := DialogueFile.load_key(ref.get_slice(":", 0))
	if df == null:
		return ""
	var cond := CampTalk.opening_condition(df, ref.get_slice(":", 1))
	return str(CampTalk.who_asks(cond, st).get("id", ""))


## The Narrator's triggers for what someone at camp in `where` (setting()) is doing when they've nothing particular to
## say: a companion's own (`camp:<id>`), a guest's (`camp:guest:<npc>`), else anyone's (`camp:someone`), each with the
## setting's own lines first (`camp:thistle:indoors`).
static func idle_keys(id: String, guest: bool, where := WILD) -> Array[String]:
	var out: Array[String] = []
	for key: String in (["camp:guest:" + id, "camp:guest"] if guest else ["camp:" + id, "camp:someone"]):
		out.append_array(keys_for(key, where))
	return out


# --- Night visitors --------------------------------------------------------------------------------------------------

## What comes for a camp in the night (data/camp/night_visitors.json): groups by the lie of the land (a town's streets
## and indoors have their own, else the region's) and the party's level, each played to the end by the test autopilot
## (hard, but winnable).
const VISITORS := "res://data/camp/night_visitors.json"
## How far from the fire the night's visitors come out of the dark (squares); where that has no room for one (a
## cramped house), anywhere from CLOSE_NEAR to CLOSE_FAR.
const DARK_NEAR := 5
const DARK_FAR := 8
const CLOSE_NEAR := 3
const CLOSE_FAR := 12
static var _visitors: Dictionary = {}


static func visitors() -> Dictionary:
	if _visitors.is_empty():
		_visitors = JSON.parse_string(FileAccess.get_file_as_string(VISITORS)) as Dictionary
	return _visitors


## The lie of the land for the night visitors of a camp in `region`, in `where` (setting()): a town's or indoors' own
## (the file's `settings`), else the region's (forest, marsh, mountain, castle).
static func land_of(region: String, where := WILD) -> String:
	var d := visitors()
	var own := str((d.get("settings", {}) as Dictionary).get(where, ""))
	return own if own != "" else str((d["lands"] as Dictionary).get(region, d["default_land"]))


## The groups that may come for a camp in `region`, in `where`, when the party is at `level`.
static func groups_for(region: String, level: int, where := WILD) -> Array[Dictionary]:
	var land := land_of(region, where)
	var out: Array[Dictionary] = []
	for g: Variant in visitors()["groups"]:
		var group := g as Dictionary
		var levels := group["levels"] as Array
		if str(group["land"]) == land and level >= int(levels[0]) and level <= int(levels[1]):
			out.append(group)
	return out


## The night's fight at a camp round `center`: a group for the place (a town's streets, indoors, else the region) and
## level (a die picks among several), its monsters placed out in the dark round the fire, spread so they come from more
## than one side, on open ground they can walk to the fire from (none on `taken`). {} when nothing fits.
static func night_fight(grid: CombatGrid, center: Vector2i, taken: Dictionary, region: String, level: int, dice: DiceRoller,
		where := WILD) -> Dictionary:
	var groups := groups_for(region, level, where)
	if groups.is_empty():
		return {}
	var group := groups[0] if groups.size() == 1 else groups[dice.roll_one(groups.size(), "Night visitors") - 1]
	return fight_for(group, grid, center, taken)


## `group`'s fight round the fire at `center` (night_fight, once the group is chosen): {id, text, monsters}, or {}.
static func fight_for(group: Dictionary, grid: CombatGrid, center: Vector2i, taken: Dictionary) -> Dictionary:
	var reach := grid.reachable(center, 1, CLOSE_FAR * CombatGrid.FEET * 2, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	var used := taken.duplicate()
	var monsters: Array = []
	var turn := 0
	for mid: Variant in group["monsters"]:
		var size := CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(str(mid)).get("size", "medium"))))
		var spot := _dark_spot(grid, center, reach, used, size, turn)
		turn += 1
		if spot.x < 0:
			continue
		for f in CombatGrid.footprint(spot, size):
			used[f] = true
		for dv in CombatGrid.DIRS:
			used[spot + dv] = true   # a little room between them
		monsters.append({"monster": str(mid), "cell": [spot.x, spot.y]})
	if monsters.is_empty():
		return {}
	return {"id": "camp_night_" + str(group["id"]), "text": str(group["text"]), "monsters": monsters}


## A square out in the dark for the `turn`th visitor of `size` squares: DARK_NEAR to DARK_FAR squares from the fire,
## reachable from it, in the next of eight directions round it (so they come from all sides); where none of those fits,
## CLOSE_NEAR to CLOSE_FAR squares away. (-1, -1) if nowhere does.
static func _dark_spot(grid: CombatGrid, center: Vector2i, reach: Dictionary, used: Dictionary, size: int, turn: int) -> Vector2i:
	var want := Vector2(1, 0).rotated(TAU * float((turn * 3) % 8) / 8.0)
	# [nearest, furthest, the furthest walk to the fire in feet]
	for band: Array in [[DARK_NEAR, DARK_FAR, DARK_FAR * CombatGrid.FEET + 10], [CLOSE_NEAR, CLOSE_FAR, CLOSE_FAR * CombatGrid.FEET * 2]]:
		var best := Vector2i(-1, -1)
		var best_score := -INF
		for c: Vector2i in reach:
			var off := Vector2(c - center)
			var far := maxi(absi(c.x - center.x), absi(c.y - center.y))
			if far < int(band[0]) or far > int(band[1]) or int((reach[c] as Dictionary)["cost"]) > int(band[2]):
				continue
			var fits := true
			for f in CombatGrid.footprint(c, size):
				if not grid.in_bounds(f) or grid.flags(f) & ROUGH != 0 or used.has(f):
					fits = false
					break
			if not fits:
				continue
			var score := off.normalized().dot(want) * 10.0 - absf(off.length() - float(DARK_NEAR + 1))
			if score > best_score:
				best_score = score
				best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
