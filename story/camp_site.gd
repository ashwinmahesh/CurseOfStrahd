class_name CampSite
extends RefCounted
## Where and how the party makes camp in the wild (F16, lane 24; docs/story/camp.md). A Long Rest taken out of doors,
## away from towns and buildings, pitches a camp on the place's own map, near where the party stands: a fire with a stew
## pot and a woodpile beside it, the company round it (the party, the companions waiting at camp, the story's guests),
## a bedroll behind each of them, and a tent and packs where there's room. Pure story logic: LocationCamp puts it on the
## map, and these are the rules it follows.

## Board themes of the open places a camp is made in (not towns, villages or the ruins of a dungeon).
const WILD_THEMES: Array[String] = ["forest", "riverside", "road", "svalich_road", "wilderness", "shrine_yard", "camp"]
## How far from the party (in feet, walking) the fire may be.
const REACH_FT := 40
## Squares round the fire where people sit, in the order they take them (x east, y south: the camera looks north).
const SEATS: Array[Vector2i] = [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(-2, 1),
	Vector2i(2, 1), Vector2i(0, -2), Vector2i(-2, -1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 2)]
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


## Whether a Long Rest at `loc` makes camp: an open place in the wild that allows a rest.
static func is_wild(loc: Dictionary) -> bool:
	var map := loc.get("map", {}) as Dictionary
	return bool(map.get("outdoors", false)) and str(map.get("theme", "")) in WILD_THEMES and str(loc.get("rest", "risky")) != "no"


## The squares the place's own things stand on (props, containers, doors, ways out, lights, its people's spots and
## traps), and the areas a fight starts in as the party walks in, as a set.
static func things_at(loc: Dictionary) -> Dictionary:
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
	var fights := {}
	for en: Variant in loc.get("encounters", []):
		var trigger := str((en as Dictionary).get("trigger", ""))
		if trigger.begins_with("enter_area:"):
			fights[trigger.substr(11)] = true
	for a: Variant in loc.get("areas", []):
		var area := a as Dictionary
		var corners := area.get("cells", []) as Array
		if not fights.has(str(area.get("id", ""))) or corners.size() != 2:
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


## The fire's square for a camp near `near` for `people` people: the reachable square within REACH_FT whose
## neighbours are all open and with the most open ground round it, the nearest of those; (-1, -1) if nowhere will do
## (then the rest stays a plain rest).
static func find_center(grid: CombatGrid, near: Vector2i, taken: Dictionary, people: int) -> Vector2i:
	var reach := grid.reachable(near, 1, REACH_FT, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false)
	reach[near] = {"cost": 0}
	var best := Vector2i(-1, -1)
	var best_score := -1
	for c: Vector2i in reach:
		var h := grid.height(c)
		if not open_square(grid, c, h, taken):
			continue
		var ring := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not open_square(grid, c + Vector2i(dx, dy), h, taken):
					ring = false
		if not ring:
			continue
		var seats := 0
		for s in SEATS:
			if open_square(grid, c + s, h, taken):
				seats += 1
		if seats < mini(people, SEATS.size()):
			continue
		var room := 0
		var level := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if open_square(grid, c + Vector2i(dx, dy), h, taken):
					room += 1
					if grid.height(c + Vector2i(dx, dy)) == h:
						level += 1
		# Room counts most, then level ground; a square nearer the party breaks a tie.
		var score := room * 1000 + level * 10 - int((reach[c] as Dictionary).get("cost", 0))
		if score > best_score:
			best_score = score
			best = c
	return best


## The camp round the fire at `center` for `people` people (the cook first when `cook`): {props: [location props],
## seats: [squares, in order], cook: square or (-1, -1)}. Pieces that don't fit are left out.
static func layout(grid: CombatGrid, center: Vector2i, taken: Dictionary, people: int, cook: bool) -> Dictionary:
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
	for s in SEATS:
		if seats.size() >= people - (1 if cook_at.x >= 0 else 0):
			break
		var c := center + s
		if open_square(grid, c, h, taken) and not used.has(c):
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
	var tent := center + TENT
	if open_square(grid, tent, h, taken) and open_square(grid, tent + Vector2i(-1, 0), h, taken) \
			and open_square(grid, tent + Vector2i(1, 0), h, taken) and not used.has(tent):
		var p2 := _piece("camp_tent", tent, "tent", "examine", "The tent")
		p2["facing"] = "south"
		props.append(p2)
		used[tent] = true
	if open_square(grid, center + PACKS, h, taken) and not used.has(center + PACKS):
		props.append(_piece("camp_packs", center + PACKS, "sack_pile", "decor", "The packs"))
	return {"props": props, "seats": seats, "cook": cook_at}


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


## The talks waiting at camp, by who asks (CampTalk, narrative/camp/): {character id: talk ref}, one each, leaving out
## anyone in `had` (who has had their word this evening, or this morning).
static func talks(st: StoryState, had: Dictionary) -> Dictionary:
	var out := {}
	for t in CampTalk.available(st):
		var ref := str(t["ref"])
		var who := asker(st, ref)
		if who != "" and not had.has(who) and not out.has(who):
			out[who] = ref
	return out


## Who asks for a talk: the first companion its condition names who is here (as CampTalk.label_for reads it), as a
## character id; "" if none of them is.
static func asker(st: StoryState, ref: String) -> String:
	var df := DialogueFile.load_key(ref.get_slice(":", 0))
	if df == null:
		return ""
	var cond := CampTalk.opening_condition(df, ref.get_slice(":", 1))
	var re := RegEx.create_from_string("name:([a-z0-9_]+)")
	for m in re.search_all(cond):
		var who := st.find_member("name:" + m.get_string(1))
		if who != null:
			return who.id
	return ""


## The Narrator's trigger for what someone at camp is doing when they've nothing particular to say: a companion's own
## (`camp:<id>`), a guest's (`camp:guest:<npc>`), else anyone's (`camp:someone`).
static func idle_keys(id: String, guest: bool) -> Array[String]:
	if guest:
		return ["camp:guest:" + id, "camp:guest"]
	return ["camp:" + id, "camp:someone"]


# --- Night visitors --------------------------------------------------------------------------------------------------

## What comes for a camp in the night (data/camp/night_visitors.json): groups by the lie of the land and the party's
## level, each played to the end by the test autopilot (hard, but winnable).
const VISITORS := "res://data/camp/night_visitors.json"
## How far from the fire the night's visitors come out of the dark (squares).
const DARK_NEAR := 5
const DARK_FAR := 8
static var _visitors: Dictionary = {}


static func visitors() -> Dictionary:
	if _visitors.is_empty():
		_visitors = JSON.parse_string(FileAccess.get_file_as_string(VISITORS)) as Dictionary
	return _visitors


## The lie of the land a region has for its night visitors (forest, marsh, mountain, castle).
static func land_of(region: String) -> String:
	var d := visitors()
	return str((d["lands"] as Dictionary).get(region, d["default_land"]))


## The groups that may come for a camp in `region` when the party is at `level`.
static func groups_for(region: String, level: int) -> Array[Dictionary]:
	var land := land_of(region)
	var out: Array[Dictionary] = []
	for g: Variant in visitors()["groups"]:
		var group := g as Dictionary
		var levels := group["levels"] as Array
		if str(group["land"]) == land and level >= int(levels[0]) and level <= int(levels[1]):
			out.append(group)
	return out


## The night's fight at a camp round `center`: a group for the region and level (a die picks among several), its
## monsters placed out in the dark round the fire, spread so they come from more than one side, on open ground they can
## walk to the fire from (none on `taken`). {} when nothing fits.
static func night_fight(grid: CombatGrid, center: Vector2i, taken: Dictionary, region: String, level: int, dice: DiceRoller) -> Dictionary:
	var groups := groups_for(region, level)
	if groups.is_empty():
		return {}
	var group := groups[0] if groups.size() == 1 else groups[dice.roll_one(groups.size(), "Night visitors") - 1]
	return fight_for(group, grid, center, taken)


## `group`'s fight round the fire at `center` (night_fight, once the group is chosen): {id, text, monsters}, or {}.
static func fight_for(group: Dictionary, grid: CombatGrid, center: Vector2i, taken: Dictionary) -> Dictionary:
	var reach := grid.reachable(center, 1, DARK_FAR * 5 + 10, func(_c: Vector2i) -> bool: return false,
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
## reachable from it, in the next of eight directions round it (so they come from all sides), else anywhere that fits.
static func _dark_spot(grid: CombatGrid, center: Vector2i, reach: Dictionary, used: Dictionary, size: int, turn: int) -> Vector2i:
	var want := Vector2(1, 0).rotated(TAU * float((turn * 3) % 8) / 8.0)
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for c: Vector2i in reach:
		var off := Vector2(c - center)
		var far := maxi(absi(c.x - center.x), absi(c.y - center.y))
		if far < DARK_NEAR or far > DARK_FAR:
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
	return best

