class_name RoadGrounds
extends RefCounted
## Where a random fight on the road plays out (Ashwin, 2026-10-12: "We should have a variety of these to randomly pick
## from"). A random encounter table names the battle maps of its land in `grounds` (a fork in the road, a clearing, a
## ravine, a ford, a wayside shrine, graves by the road, a moor, a pass), and a road whose land differs from the rest
## of its table's names its own. Each fight picks one, never the one picked last. Pure logic: game_root enters the
## ground and starts the fight with the foes placed() on it.
##
## A table's meetings stay on its own `map`, where their conversations' fights are written. Its fights' cells are
## written for that map too: on another ground each foe takes the free `foe_spots` square nearest where the table put
## it round the party, so foes written on both sides of the road come from both sides here as well.

## How many of the last grounds are remembered (the `_road_grounds` flag, newest last).
const REMEMBER := 4
## A ground's weight in the pick: one not fought on lately, one fought on lately, and the last one (never, while
## there's another).
const FRESH := 3
const LATELY := 1
## Where the party stands, and the squares round it it fills (LocationParty): no foe starts this close.
const PARTY_ROOM := 2
## The squares a foe may start on (open floor, rough ground, raised floor, a low dais).
const OPEN_FLOOR := ".~1234_"


## The battle maps a fight on `road` (a travel road) from `table` may play out on: the road's own `grounds`, else
## the table's, else just the table's map.
static func pool(table: Dictionary, road: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var listed := road.get("grounds", table.get("grounds", [table.get("map", "")])) as Array
	for g: Variant in listed:
		if str(g) != "" and not out.has(str(g)):
			out.append(str(g))
	return out


## Picks the ground for a fight now and remembers it. Never the last one picked while there's another; one picked
## lately is a third as likely as one not seen for a while. Its own dice, from the playthrough's seed, the table and
## the hour, so the fight's own rolls are what they'd have been.
static func choose(table: Dictionary, road: Dictionary, st: StoryState) -> String:
	var options := pool(table, road)
	if options.is_empty():
		return str(table.get("map", ""))
	var recent := (st.flags.get("_road_grounds", []) as Array).duplicate()
	var last := str(recent.back()) if not recent.is_empty() else ""
	var weights: Array[int] = []
	var total := 0
	for g in options:
		var w := FRESH
		if g == last and options.size() > 1:
			w = 0
		elif recent.has(g):
			w = LATELY
		weights.append(w)
		total += w
	var dice := DiceRoller.new(hash("%d:road_grounds:%s:%d" % [st.playthrough_seed, str(table.get("id", "")), st.total_minutes()]))
	var roll := dice.roll_one(maxi(total, 1), "Where the road fight is")
	var pick := options[0]
	for i in options.size():
		if weights[i] == 0:
			continue
		roll -= weights[i]
		if roll <= 0:
			pick = options[i]
			break
	recent.append(pick)
	while recent.size() > REMEMBER:
		recent.pop_front()
	st.flags["_road_grounds"] = recent
	return pick


## The fight's `monsters` ({monster, cell, ...}, cells written for the table's map `home`) standing on `ground`: as
## written on `home`; elsewhere each on the free foe spot nearest where its table put it, measured from the party's
## spawn on each map, with room for its size (the biggest placed first). A foe with no spot left takes open ground
## about four squares from the party; one with nowhere at all stays out of the fight.
static func placed(monsters: Array, home: String, ground: String) -> Array:
	if ground == home:
		return monsters.duplicate(true)
	var c := Compendium.shared()
	var to := c.get_entry("locations", ground)
	var rows := (to.get("map", {}) as Dictionary).get("rows", []) as Array
	var from_spawn := _spawn(c.get_entry("locations", home))
	var to_spawn := _spawn(to)
	var used := {}
	for dz in range(-PARTY_ROOM, PARTY_ROOM + 1):
		for dx in range(-PARTY_ROOM, PARTY_ROOM + 1):
			used[to_spawn + Vector2i(dx, dz)] = true
	for ex: Variant in to.get("exits", []):
		used[_cell((ex as Dictionary)["cell"])] = true
	var spots: Array[Vector2i] = []
	for s: Variant in to.get("foe_spots", []):
		spots.append(_cell(s))
	var out: Array = []
	var order: Array[int] = []
	for i in monsters.size():
		out.append((monsters[i] as Dictionary).duplicate(true))
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa := _size(str((out[a] as Dictionary)["monster"]))
		var sb := _size(str((out[b] as Dictionary)["monster"]))
		return sa > sb if sa != sb else a < b)
	var homeless := false
	for i in order:
		var md := out[i] as Dictionary
		var size := _size(str(md["monster"]))
		var want := to_spawn + (_cell(md.get("cell", [from_spawn.x, from_spawn.y])) - from_spawn)
		var best := Vector2i(-1, -1)
		var best_d := INF
		for s in spots:
			if not _fits(rows, used, s, size):
				continue
			var d := Vector2(s - want).length()
			if d < best_d:
				best_d = d
				best = s
		if best.x < 0:
			md.erase("cell")
			homeless = true
			continue
		md["cell"] = [best.x, best.y]
		for f in CombatGrid.footprint(best, size):
			used[f] = true
	if homeless:
		# No spot left: open ground round the party, as a visit from Strahd finds it.
		var taken: Array[Vector2i] = []
		for k: Variant in used.keys():
			taken.append(k as Vector2i)
		var rest := Campaign.module().place_visitors({"monsters": out}, rows, taken, to_spawn)
		out = rest["monsters"] as Array
	return out


static func _fits(rows: Array, used: Dictionary, anchor: Vector2i, size: int) -> bool:
	for f in CombatGrid.footprint(anchor, size):
		if used.has(f) or f.y < 0 or f.y >= rows.size():
			return false
		var row := str(rows[f.y])
		if f.x < 0 or f.x >= row.length() or not OPEN_FLOOR.contains(row[f.x]):
			return false
	return true


static func _size(monster_id: String) -> int:
	return CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(monster_id).get("size", "medium"))))


static func _spawn(loc: Dictionary) -> Vector2i:
	return _cell((loc.get("spawns", {}) as Dictionary).get("default", [0, 0]))


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))
