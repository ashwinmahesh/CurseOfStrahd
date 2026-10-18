class_name FortressSite
extends RefCounted
## Daern's Instant Fortress standing on the map (docs/story/fortress.md). The item's first power sets a square adamantine
## tower, 20 ft on a side and 30 ft high, down on open ground in front of the party; its one door faces them and opens
## into the tower's three maps (daerns_fortress: the ground floor, daerns_fortress_upper: the second floor and
## daerns_fortress_roof: the battlement behind the trapdoor), whose way out leads back to the map the tower stands on.
## The second power shrinks it back into the statuette, which works only when nobody is inside (the item's text).
## What stands is kept in StoryState.flags[FLAG] (an underscore key: bookkeeping, so it survives saves without a new
## save version). The view reads it through overlay() (LocationView.create) and LocationFortress.stand().
## Pure story logic: dressing a view with it is LocationFortress (world/exploration/location_fortress.gd).

const FLAG := "_fortress"
const ITEM := "daerns_instant_fortress"
const GROUND := "daerns_fortress"
const UPPER := "daerns_fortress_upper"
const ROOF := "daerns_fortress_roof"
const INTERIORS: Array[String] = [GROUND, UPPER, ROOF]
## The exit on the outside map that is the tower's door, and the spawn on that map just in front of it.
const ENTRY := "fortress_entry"
const OUT := "fortress_door"
const FRONT := "from_fortress"
## 20 ft each way.
const SIDE := 4
## How far from the leader a plot is looked for, in squares, and how far it may sit from the party to be "where the
## party stands".
const REACH := 5
## How uneven the ground under a tower may be, in feet: its footing (FortressTower) makes up the difference.
const SLOPE_FT := 10
## Which way a door looks (the direction from the tower to the square in front of its door). The opening camera looks
## north from the south, so a door that looks south shows best.
const LOOKS := {"south": Vector2i(0, 1), "east": Vector2i(1, 0), "west": Vector2i(-1, 0), "north": Vector2i(0, -1)}
const LOOK_COST := {"south": 0, "east": 3, "west": 3, "north": 6}


# --- What stands --------------------------------------------------------------------------------------------------

## {at: the map's id, cell: [x, y] of the tower's north-west square, door: [x, y], front: [x, y], looks: a LOOKS key,
## by: the character id who raised it}; {} when no fortress stands.
static func state(st: StoryState) -> Dictionary:
	var d: Variant = st.flags.get(FLAG, null)
	return d as Dictionary if d is Dictionary else {}


static func standing(st: StoryState) -> bool:
	return not state(st).is_empty()


## Whether the party is inside the tower (on any of its three maps).
static func inside(st: StoryState) -> bool:
	return st.location in INTERIORS


## The map the tower stands on, for one of the tower's own maps (the roof's view of the valley), else "".
static func outside_of(place: String, st: StoryState) -> String:
	return str(state(st).get("at", "")) if place in INTERIORS else ""


## The name of the map the tower stands on, for what the item says.
static func where(st: StoryState) -> String:
	var at := str(state(st).get("at", ""))
	return str(Compendium.shared().get_entry("locations", at).get("name", at))


## The 16 squares a tower with its north-west square at `cell` covers.
static func footprint(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in SIDE:
		for dx in SIDE:
			out.append(cell + Vector2i(dx, dy))
	return out


static func cell_of(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


# --- Raising it ---------------------------------------------------------------------------------------------------

## Why the item's first power can't be used now, or "" (there may still be no room for the tower: NO_ROOM).
static func why_not_raise(st: StoryState) -> String:
	if standing(st):
		return "The fortress already stands in %s. Fold it up first." % where(st)
	if inside(st):
		return "The tower is already around you."
	var loc := Compendium.shared().get_entry("locations", st.location)
	if loc.is_empty() or not open_air(loc):
		return "There's no room for a tower here. Raise it in the open air."
	return ""


const NO_ROOM := "No clear, level ground for a tower 20 feet square here. Find some open ground."


## Why the second power can't be used now, or "".
static func why_not_fold(st: StoryState) -> String:
	if not standing(st):
		return "No fortress stands to be folded up."
	if inside(st):
		return "Not from inside: the tower folds up only when nobody is in it."
	if st.location != str(state(st).get("at", "")):
		return "The fortress stands in %s, out of earshot of the word." % where(st)
	return ""


## Raises the fortress on `plot` (plan()) for `by`: what stands is recorded; the view builds it.
static func raise(st: StoryState, plot: Dictionary, by: Character) -> void:
	var d := plot.duplicate()
	d["at"] = st.location
	d["by"] = by.id if by != null else ""
	st.flags[FLAG] = d


## Folds it back into the statuette. (Nobody is inside: why_not_fold.)
static func fold(st: StoryState) -> void:
	st.flags.erase(FLAG)


## A map a tower can stand on: out of doors, and not a dungeon's open-air stonework (a castle's roofs).
static func open_air(loc: Dictionary) -> bool:
	var map := loc.get("map", {}) as Dictionary
	return bool(map.get("outdoors", false)) and str(map.get("theme", "")) != "dungeon" and str(loc.get("id", "")) not in INTERIORS


## Where a tower goes on the map `loc` for a party whose leader stands at `leader`, `party` being every square a
## character of the party or its guests stands on and `people` the squares others stand on: a plot of SIDE x SIDE
## open squares on ground that is level or at most SLOPE_FT out (the tower's footing makes up the difference), clear of
## the place's things, with a square in front of the door that is open and no more than a step from the door's, and
## the way to the rest of the map kept (nothing the party could reach before is cut off). The nearest plot to the
## leader, flatter ground and a door that looks south first. {cell, door, front, looks}, or {} when there is no room.
static func plan(loc: Dictionary, grid: CombatGrid, leader: Vector2i, party: Array[Vector2i], people: Array[Vector2i] = []) -> Dictionary:
	var taken := CampSite.things_at(loc, false)   # not the fights' areas: the tower is walls, and no one walks into them
	for c in people:
		taken[c] = true
	var before := _reach(grid, leader)
	var best := {}
	var best_score := 1 << 30
	for y in range(leader.y - REACH - SIDE, leader.y + REACH + 1):
		for x in range(leader.x - REACH - SIDE, leader.x + REACH + 1):
			var origin := Vector2i(x, y)
			var spread := _spread(grid, origin, taken, party)
			if spread < 0:
				continue
			for looks: String in LOOKS:
				for door in _doors_for(origin, looks, leader):
					var front := door + (LOOKS[looks] as Vector2i)
					if not _front_ok(grid, front, taken, origin) or absi(grid.height(front) - grid.height(door)) > CombatGrid.FEET:
						continue
					var score := _distance(leader, front) * 10 + int(LOOK_COST[looks]) + spread / CombatGrid.FEET * 2
					if score >= best_score or not _keeps_the_way(grid, origin, before, leader):
						continue
					best_score = score
					best = {"cell": [origin.x, origin.y], "door": [door.x, door.y], "front": [front.x, front.y], "looks": looks}
	return best


## How far apart the heights of the plot's squares are, in feet (0: level), or -1 when it won't do: a square off the map,
## closed, under a character of the party or the place's things, ground that is partly natural, or too uneven (SLOPE_FT).
static func _spread(grid: CombatGrid, origin: Vector2i, taken: Dictionary, party: Array[Vector2i]) -> int:
	if not grid.in_bounds(origin):
		return -1
	var lo := 1 << 20
	var hi := -(1 << 20)
	var natural := grid.has_flag(origin, CombatGrid.NATURAL)
	for c in footprint(origin):
		if not grid.in_bounds(c) or grid.flags(c) & CampSite.ROUGH != 0 or taken.has(c) or c in party \
				or grid.has_flag(c, CombatGrid.NATURAL) != natural:
			return -1
		lo = mini(lo, grid.height(c))
		hi = maxi(hi, grid.height(c))
	return hi - lo if hi - lo <= SLOPE_FT else -1


## The two squares of the tower's `looks` face that can hold the door (the corners can't), nearest `leader` first.
static func _doors_for(origin: Vector2i, looks: String, leader: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: int in [1, SIDE - 2]:
		match looks:
			"south":
				out.append(Vector2i(origin.x + k, origin.y + SIDE - 1))
			"north":
				out.append(Vector2i(origin.x + k, origin.y))
			"east":
				out.append(Vector2i(origin.x + SIDE - 1, origin.y + k))
			_:
				out.append(Vector2i(origin.x, origin.y + k))
	if _distance(leader, out[1]) < _distance(leader, out[0]):
		out.reverse()
	return out


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _front_ok(grid: CombatGrid, front: Vector2i, taken: Dictionary, origin: Vector2i) -> bool:
	return grid.in_bounds(front) and grid.flags(front) & CampSite.ROUGH == 0 and not taken.has(front) and front not in footprint(origin)


## The squares the party can walk to from `from`.
static func _reach(grid: CombatGrid, from: Vector2i) -> Dictionary:
	var reach := grid.reachable(from, 1, grid.width * grid.depth * CombatGrid.FEET * 2, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	reach[from] = {"cost": 0}
	return reach


## Whether every square the party could reach before, but those under the tower, can still be reached with it there.
static func _keeps_the_way(grid: CombatGrid, origin: Vector2i, before: Dictionary, leader: Vector2i) -> bool:
	var plot := footprint(origin)
	for c in plot:
		grid.set_flag(c, CombatGrid.WALL, true)
	var after := _reach(grid, leader)
	for c in plot:
		grid.set_flag(c, CombatGrid.WALL, false)
	for c: Vector2i in before:
		if not c in plot and not after.has(c):
			return false
	return true


# --- On the map ---------------------------------------------------------------------------------------------------

## Lays the fortress over a location's data before its view is built (LocationView.create): on the map the tower
## stands on, a door out of the tower's front row and the square in front of it to arrive at; on the tower's own maps,
## the way out leads to that map. `loc` is the view's own copy.
static func overlay(loc: Dictionary, st: StoryState) -> void:
	var fs := state(st)
	if fs.is_empty():
		return
	var id := str(loc.get("id", ""))
	if id == str(fs.get("at", "")):
		var exits := loc.get_or_add("exits", []) as Array
		exits.append({"id": ENTRY, "cell": fs["door"], "to": GROUND, "spawn": "default", "label": "Enter Daern's Instant Fortress"})
		(loc.get_or_add("spawns", {}) as Dictionary)[FRONT] = fs["front"]
		loc["fortress"] = fs.duplicate()
	elif id in INTERIORS:
		var out := Compendium.shared().get_entry("locations", str(fs.get("at", "")))
		for ex: Variant in loc.get("exits", []):
			var e := ex as Dictionary
			if str(e.get("id", "")) == OUT:
				e["to"] = str(fs["at"])
				e["spawn"] = FRONT
		if id == ROOF and not out.is_empty():
			loc["region"] = str(out.get("region", loc.get("region", "")))


## A plot for the party from the saved state alone: the map's data and the squares the party stands on. What the
## inventory uses when it has no live map to ask (tests).
static func plot_for(st: StoryState) -> Dictionary:
	var loc := Compendium.shared().get_entry("locations", st.location)
	if loc.is_empty() or not open_air(loc):
		return {}
	var map := loc["map"] as Dictionary
	var grid := CombatGrid.from_rows(map["rows"] as Array, map.get("elevation", []) as Array)
	var spawn := (loc.get("spawns", {}) as Dictionary).get("default", [1, 1]) as Array
	var party: Array[Vector2i] = st.positions.duplicate() if st.positions.size() == st.party.size() else []
	var leader := party[0] if not party.is_empty() else cell_of(spawn)
	return plan(loc, grid, leader, party)
