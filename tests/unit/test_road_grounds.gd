extends TestCase
## Where a random fight on the road plays out (story/road_grounds.gd): a road's or its table's pool of battle grounds,
## picked so the same ground never comes twice running, and the fight's foes standing on the ground picked: as written
## on the table's own map, on the ground's foe spots elsewhere, every foe of every table's fights finding room on every
## ground in its pools.

const OPEN := ".~1234_"


func _st(minutes: int = 600) -> StoryState:
	var st := StoryState.new()
	st.playthrough_seed = 7
	st.minute_of_day = minutes % 1440
	return st


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


func _size(monster_id: String) -> int:
	return CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(monster_id).get("size", "medium"))))


func test_a_road_s_own_grounds_win_then_its_table_s_then_the_table_s_map() -> void:
	var table := {"id": "t", "map": "road_ambush", "grounds": ["road_ambush", "road_fork"]}
	assert_eq(str(RoadGrounds.pool(table, {})), str(["road_ambush", "road_fork"]), "the table's pool")
	assert_eq(str(RoadGrounds.pool(table, {"grounds": ["barrow_moor"]})), str(["barrow_moor"]), "a road's own land")
	assert_eq(str(RoadGrounds.pool({"id": "t", "map": "road_ambush"}, {})), str(["road_ambush"]), "no pool: its map")


func test_the_same_ground_never_comes_twice_running_and_every_one_comes_up() -> void:
	var table := {"id": "svalich_road", "map": "road_ambush",
		"grounds": ["road_ambush", "road_fork", "wayside_shrine", "roadside_graves", "stream_ford"]}
	var st := _st()
	var seen := {}
	var last := ""
	for i in 200:
		st.advance_minutes(97)
		var g := RoadGrounds.choose(table, {}, st)
		assert_true(g != last, "not %s twice running (fight %d)" % [g, i])
		last = g
		seen[g] = int(seen.get(g, 0)) + 1
	assert_eq(seen.size(), 5, "every ground in the pool comes up: %s" % seen)
	for g: String in seen:
		assert_true(int(seen[g]) >= 20, "%s isn't starved (%d of 200)" % [g, int(seen[g])])
	assert_eq((st.flags["_road_grounds"] as Array).size(), RoadGrounds.REMEMBER, "only the last few are remembered")


func test_the_pick_is_its_own_dice_the_same_for_the_same_fight() -> void:
	var table := {"id": "svalich_woods", "map": "road_forest", "grounds": ["road_forest", "forest_clearing", "road_ravine"]}
	var a := RoadGrounds.choose(table, {}, _st(700))
	var b := RoadGrounds.choose(table, {}, _st(700))
	assert_eq(a, b, "the same playthrough, table and hour pick the same ground")
	Dice.reseed(5)
	var before := Dice.roller.roll_one(1000)
	Dice.reseed(5)
	RoadGrounds.choose(table, {}, _st(800))
	assert_eq(Dice.roller.roll_one(1000), before, "the game's dice aren't touched")


func test_one_ground_is_picked_every_time() -> void:
	var table := {"id": "t", "map": "road_ambush"}
	var st := _st()
	for i in 3:
		assert_eq(RoadGrounds.choose(table, {}, st), "road_ambush", "a pool of one")


func test_on_the_table_s_own_map_the_foes_stand_where_written() -> void:
	var table := Compendium.shared().get_entry("random_encounters", "svalich_road")
	for e: Variant in table["entries"]:
		var mons := (e as Dictionary).get("monsters", []) as Array
		if mons.is_empty():
			continue
		assert_eq(str(RoadGrounds.placed(mons, "road_ambush", "road_ambush")), str(mons), "as written")


## Every table's every fight, on every ground its table or its roads may pick: every foe finds room, on open floor,
## clear of the party's squares and the ways out, nobody overlapping.
func test_every_fight_finds_room_on_every_ground_it_can_play_out_on() -> void:
	var c := Compendium.shared()
	var pools := {}
	for tid: Variant in c.table("random_encounters").keys():
		var t := c.get_entry("random_encounters", str(tid))
		pools[str(tid)] = RoadGrounds.pool(t, {})
	for f: Variant in c.table("travel").values():
		for r: Variant in (f as Dictionary).get("roads", []):
			var road := r as Dictionary
			if road.has("grounds") and str(road.get("table", "")) != "":
				var both := (pools[str(road["table"])] as Array).duplicate()
				for g: String in RoadGrounds.pool({}, road):
					if not both.has(g):
						both.append(g)
				pools[str(road["table"])] = both
	var checked := 0
	for tid: String in pools:
		var t := c.get_entry("random_encounters", tid)
		for g: Variant in pools[tid]:
			var ground := str(g)
			var loc := c.get_entry("locations", ground)
			var rows := (loc["map"] as Dictionary)["rows"] as Array
			var spawn := _cell((loc["spawns"] as Dictionary)["default"])
			var exits := {}
			for ex: Variant in loc.get("exits", []):
				exits[_cell((ex as Dictionary)["cell"])] = true
			for e: Variant in t["entries"]:
				var mons := (e as Dictionary).get("monsters", []) as Array
				if mons.is_empty() or ground == str(t["map"]):
					continue
				var out := RoadGrounds.placed(mons, str(t["map"]), ground)
				assert_eq(out.size(), mons.size(), "%s/%s on %s: everyone finds room" % [tid, (e as Dictionary).get("id", ""), ground])
				var taken := {}
				for m: Variant in out:
					var md := m as Dictionary
					var at := _cell(md["cell"])
					for sq in CombatGrid.footprint(at, _size(str(md["monster"]))):
						var where := "%s/%s %s at %s on %s" % [tid, (e as Dictionary).get("id", ""), md["monster"], sq, ground]
						assert_true(sq.y >= 0 and sq.y < rows.size() and sq.x >= 0 and sq.x < str(rows[sq.y]).length()
							and OPEN.contains(str(rows[sq.y])[sq.x]), "%s: open floor" % where)
						assert_false(taken.has(sq), "%s: nobody overlaps" % where)
						assert_false(exits.has(sq), "%s: not on a way out" % where)
						assert_true(maxi(absi(sq.x - spawn.x), absi(sq.y - spawn.y)) > RoadGrounds.PARTY_ROOM,
							"%s: clear of the party" % where)
						taken[sq] = true
				checked += 1
	assert_true(checked > 100, "a good many fights placed (%d)" % checked)


## Foes the table put on both sides of the road come from both sides on another ground too.
func test_foes_keep_their_side_of_the_party_on_another_ground() -> void:
	var c := Compendium.shared()
	var home := c.get_entry("locations", "road_ambush")
	var from := _cell((home["spawns"] as Dictionary)["default"])
	var mons := [{"monster": "wolf", "cell": [from.x - 6, from.y - 4]}, {"monster": "wolf", "cell": [from.x + 7, from.y + 4]}]
	var ground := c.get_entry("locations", "road_fork")
	var to := _cell((ground["spawns"] as Dictionary)["default"])
	var out := RoadGrounds.placed(mons, "road_ambush", "road_fork")
	var west := _cell((out[0] as Dictionary)["cell"])
	var east := _cell((out[1] as Dictionary)["cell"])
	assert_true(west.x < to.x and east.x > to.x, "one west of the party, one east (%s, %s; party %s)" % [west, east, to])
	var spots: Array = (ground["foe_spots"] as Array).map(func(s: Variant) -> String: return str(_cell(s)))
	assert_true(spots.has(str(west)) and spots.has(str(east)), "both on the ground's foe spots")


## The maps a journey stops on (Travel.is_road_scene), from the game's own data: the road maps and every battle ground
## a table or a road names, never a town or a lair.
func test_the_road_scenes_in_the_game_s_data() -> void:
	for id: String in ["road_ambush", "mountain_pass", "frozen_tarn", "wayside_shrine", "lake_inlet", "barrow_moor"]:
		assert_true(Travel.is_road_scene(id), "%s is a road scene" % id)
	for id: String in ["vallaki", "ghakis_lair", "ghakis_shoulder", "tsolenka_pass", "village_of_barovia"]:
		assert_false(Travel.is_road_scene(id), "%s is not" % id)
	for t: Variant in Compendium.shared().table("random_encounters").values():
		var table := t as Dictionary
		assert_true(Travel.is_road_scene(str(table["map"])), "%s (table %s's own map)" % [table["map"], table.get("id", "")])
		for id: Variant in RoadGrounds.pool(table, {}):
			assert_true(Travel.is_road_scene(str(id)), "%s (table %s)" % [id, table.get("id", "")])
	# A road's own grounds as well: every fight and meeting a journey can stop for plays on one of them.
	for r: Variant in Travel.map_data().get("roads", []):
		var road := r as Dictionary
		var table := Compendium.shared().get_entry("random_encounters", str(road.get("table", "")))
		if table.is_empty():
			continue
		for id: Variant in RoadGrounds.pool(table, road):
			assert_true(Travel.is_road_scene(str(id)), "%s (road %s)" % [id, road["id"]])
