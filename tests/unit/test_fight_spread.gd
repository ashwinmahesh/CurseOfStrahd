extends TestCase
## No fight starts with its foes bunched under one Fireball (owner, 2026-10-14: "enemies shouldn't ALL be in range for
## a single fireball"). For every fight of three foes or more, as a location's data sets them out and as RoadGrounds
## puts a road fight down on each ground it may play out on, no point a 20 ft sphere can be centred on (a grid corner,
## as CombatGrid.area_cells measures it, walls stopping it) catches every foe, nor more than three quarters of a band of
## eight or more. Fights in rooms smaller than one burst are listed in CRAMPED with why; boss fights wait in PENDING
## until their retune lands. No foe starts on a wall, in the void or in another foe's space.

const BURST_FT := 20
## Fights whose whole room is about the size of one burst: no spread without moving the fight out of its room.
const CRAMPED := {
	"amber_temple_entrance:frozen_watch": "the east guardroom is 6 by 5 squares",
	"castle_ravenloft_catacombs:cat_gargoyle_watch": "the gargoyle tomb is 6 by 7, behind its gate",
	"castle_ravenloft_catacombs:cat_sleepers": "the sleepers' crypt is 6 by 5, behind its gate",
	"castle_ravenloft_larders_dungeon:larders_jailers": "the jailers' post is 5 by 5",
	"castle_ravenloft_spires_rooms:escher_fight": "Escher's suite is 8 by 9 and two of the three are Large swarms",
	"death_house_dungeon_1:den_mimic": "The Door is the shrine's door, and the shrine is 7 by 5",
	"death_house_dungeon_1:durst_reunion": "the Dursts' chamber is 4 by 5",
	"death_house_dungeon_1:durst_reunion_shaken": "the Dursts' chamber is 4 by 5",
	"death_house_dungeon_1:larder_grick": "the larder is 6 by 4",
	"death_house_dungeon_1:shrine_shadows": "the shrine is 7 by 5 with its doors shut",
	"death_house_third:storage_broom": "a closet 4 by 3",
	"vallaki_coffin_maker:storeroom_spawn": "the storeroom is 6 by 6",
	"vallaki_wachter_house:stella_shadow": "Stella's room is 7 by 5 with its door shut",
}
## Fights other lanes are retuning now (coordinator, 2026-10-14): the boss fights going to 3 in 8, and the Tser Falls
## wisps. Each is spread once its retune lands, and leaves this list then.
const PENDING := {
	"abbey_of_st_markovia_shrine:abbot_wrath": true, "amber_temple_library:exethanter_wrath": true,
	"argynvostholt:squires_vigil": true, "argynvostholt_beacon:beacon_stand": true, "argynvostholt_hall:vladimir_duel": true,
	"berez:creeping_hut_masterless": true, "berez:lysaga_at_monument": true, "berez:rag_queen": true,
	"berez_baba_lysagas_hut:lysaga_in_hut": true, "burgomaster_mansion:hound_tenant": true,
	"castle_ravenloft_catacombs:cat_horseman_final": true, "castle_ravenloft_catacombs:corvina": true,
	"castle_ravenloft_catacombs_tombs:cat_sergei_final": true, "castle_ravenloft_court:court_final_audience_hall": true,
	"castle_ravenloft_court:court_final_study": true, "castle_ravenloft_court:court_rahadin_fight": true,
	"castle_ravenloft_court_treasury:court_final_treasury": true,
	"castle_ravenloft_court_weeping:court_rahadin_chamber_fight": true, "castle_ravenloft_larders_dungeon:larders_donjon": true,
	"castle_ravenloft_overlook:crg_overlook_final_battle": true, "castle_ravenloft_spires_heart:heart_of_sorrow_final": true,
	"castle_ravenloft_spires_heart:heart_strahd_test": true, "castle_ravenloft_spires_roofs:querreth": true,
	"amber_deep:dreamed_eyes": true, "ghakis_lair:vent_fire": true, "ghakis_shoulder:ghakis_keepers": true,
	"into_the_mists_road:bone_marshal": true, "into_the_mists_road:ilarion_wolves": true, "krezk:grandsire": true,
	"krezk_road_waystone:waystone_wolves": true, "lake_zarovich:greytooth_hunt": true, "lake_zarovich:drowned_landing": true,
	"lake_zarovich_trail:raven_trap": true, "old_bonegrinder:bakery_offalia": true, "old_bonegrinder_loft:bella_betrayed": true,
	"old_bonegrinder_loft:coven_last_stand": true, "old_bonegrinder_track:bella_on_the_road": true,
	"old_bonegrinder_track:granny_ash": true, "old_bonegrinder_track:offalia_on_the_road": true,
	"svalich_crossroads:the_hunt": true, "svalich_roadhouse:roadhouse_cellar": true, "tsolenka_pass:last_egg": true,
	"tsolenka_pass:the_penitent": true, "tser_falls:falls_wisps": true, "vallaki:izek_duel": true,
	"werewolf_den_caves:den_reckoning": true, "werewolf_den_caves:pack_challenge": true,
	"wizard_of_wines:vine_mother": true, "woodcutters_hollow:oat_hunters": true, "zarovich_reed_island:reed_isle_boatmen": true,
}


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


func _size(monster_id: String) -> int:
	return CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(monster_id).get("size", "medium"))))


## The most a fight's foes one burst can catch: `n` (and the point `at`, a grid corner) of the `monsters` entries
## ({monster, cell, side}) on the side "enemy". A foe is caught when one of its squares is in the sphere: the square's
## centre within 20 ft of the point with no wall between (CombatGrid.area_cells).
static func most_caught(grid: CombatGrid, monsters: Array) -> Dictionary:
	var r := BURST_FT / float(CombatGrid.FEET) + 0.001
	var reach := ceili(r)
	var counts := {}
	for mo: Variant in monsters:
		var md := mo as Dictionary
		if str(md.get("side", "enemy")) != "enemy" or not md.has("cell"):
			continue
		var anchor := Vector2i(int((md["cell"] as Array)[0]), int((md["cell"] as Array)[1]))
		var size := CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(str(md["monster"])).get("size", "medium"))))
		var points := {}
		for sq in CombatGrid.footprint(anchor, size):
			if not grid.in_bounds(sq) or grid.has_flag(sq, CombatGrid.WALL) or grid.has_flag(sq, CombatGrid.VOID):
				continue
			var centre := Vector2(sq.x + 0.5, sq.y + 0.5)
			for z in range(maxi(0, sq.y - reach), mini(grid.depth, sq.y + reach + 1) + 1):
				for x in range(maxi(0, sq.x - reach), mini(grid.width, sq.x + reach + 1) + 1):
					var p := Vector2(x, z)
					if not points.has(p) and p.distance_to(centre) <= r and not grid._wall_between(p, centre):
						points[p] = true
		for p: Vector2 in points:
			counts[p] = int(counts.get(p, 0)) + 1
	var best := {"n": 0, "at": Vector2.ZERO}
	for p: Vector2 in counts:
		if int(counts[p]) > int(best["n"]):
			best = {"n": int(counts[p]), "at": p}
	return best


## The most of `n` foes one burst may catch: all but one, and from eight foes up three quarters.
static func most_allowed(n: int) -> int:
	return n - 1 if n < 8 else ceili(n * 0.75)


static func _foes(monsters: Array) -> int:
	return monsters.filter(func(m: Variant) -> bool: return str((m as Dictionary).get("side", "enemy")) == "enemy").size()


func test_the_measure_counts_as_a_fireball_does() -> void:
	var g := CombatGrid.from_rows(["..........", "..........", "..........", "..........", "..........",
		"..........", "..........", "..........", "..........", ".........."])
	var close := [{"monster": "wolf", "cell": [1, 1]}, {"monster": "wolf", "cell": [4, 4]}, {"monster": "wolf", "cell": [7, 1]}]
	assert_eq(int(most_caught(g, close)["n"]), 3, "three wolves within 30 ft of each other fit under one burst")
	var apart := [{"monster": "wolf", "cell": [0, 0]}, {"monster": "wolf", "cell": [9, 9]}, {"monster": "wolf", "cell": [5, 5]}]
	assert_eq(int(most_caught(g, apart)["n"]), 2, "corner to corner they don't")
	var walled := CombatGrid.from_rows(["....#....", "....#....", "....#....", "....#....", "....#...."])
	var split := [{"monster": "wolf", "cell": [3, 2]}, {"monster": "wolf", "cell": [5, 2]}, {"monster": "wolf", "cell": [3, 3]}]
	assert_eq(int(most_caught(walled, split)["n"]), 2, "a wall between stops the burst")
	var big := [{"monster": "ogre", "cell": [0, 0]}, {"monster": "wolf", "cell": [7, 0]}, {"monster": "wolf", "cell": [8, 1]}]
	assert_eq(int(most_caught(g, big)["n"]), 3, "a Large foe is caught by any of its squares")
	var small := [{"monster": "wolf", "cell": [0, 0]}, {"monster": "wolf", "cell": [7, 0]}, {"monster": "wolf", "cell": [8, 1]}]
	assert_eq(int(most_caught(g, small)["n"]), 2, "where a Medium one on its corner square isn't")
	var ally := [{"monster": "wolf", "cell": [1, 1]}, {"monster": "wolf", "cell": [2, 1], "side": "ally"}]
	assert_eq(int(most_caught(g, ally)["n"]), 1, "only foes count")
	# The same squares the game's own area takes.
	var at := most_caught(g, close)["at"] as Vector2
	var cells := g.area_cells("sphere", BURST_FT, at)
	for m: Variant in close:
		assert_true(cells.has(_cell((m as Dictionary)["cell"])), "%s is in the game's burst at %s" % [m, at])


func test_no_location_fight_starts_under_one_fireball() -> void:
	var c := Compendium.shared()
	var bad: Array[String] = []
	var checked := 0
	for id: String in c.table("locations"):
		var loc := c.get_entry("locations", id)
		if not loc.has("map") or (loc.get("encounters", []) as Array).is_empty():
			continue
		var grid := LocationView.grid_for(loc)
		var encounters := loc["encounters"] as Array
		for i in encounters.size():
			var e := encounters[i] as Dictionary
			var key := "%s:%s" % [id, e["id"]]
			var n := _foes(e["monsters"] as Array)
			if n < 3 or CRAMPED.has(key) or PENDING.has(key):
				continue
			checked += 1
			var most := most_caught(grid, e["monsters"] as Array)
			if int(most["n"]) > most_allowed(n):
				bad.append("%s #%d: one burst at %s catches %d of %d" % [key, i, most["at"], most["n"], n])
	assert_true(checked > 200, "a good many fights measured (%d)" % checked)
	assert_true(bad.is_empty(), "foes bunched under one Fireball:\n  %s" % "\n  ".join(bad))


func test_no_road_fight_starts_under_one_fireball_on_any_ground() -> void:
	var c := Compendium.shared()
	var pools := {}
	for tid: Variant in c.table("random_encounters").keys():
		pools[str(tid)] = RoadGrounds.pool(c.get_entry("random_encounters", str(tid)), {})
	for f: Variant in c.table("travel").values():
		for r: Variant in (f as Dictionary).get("roads", []):
			var road := r as Dictionary
			if road.has("grounds") and str(road.get("table", "")) != "":
				for g: String in RoadGrounds.pool({}, road):
					if not (pools[str(road["table"])] as Array).has(g):
						(pools[str(road["table"])] as Array).append(g)
	var bad: Array[String] = []
	var checked := 0
	for tid: String in pools:
		var t := c.get_entry("random_encounters", tid)
		var grounds := (pools[tid] as Array).duplicate()
		if not grounds.has(str(t["map"])):
			grounds.append(str(t["map"]))
		for g: Variant in grounds:
			var grid := LocationView.grid_for(c.get_entry("locations", str(g)))
			for e: Variant in t["entries"]:
				var mons := (e as Dictionary).get("monsters", []) as Array
				var n := _foes(mons)
				if n < 3:
					continue
				checked += 1
				var most := most_caught(grid, RoadGrounds.placed(mons, str(t["map"]), str(g)))
				if int(most["n"]) > most_allowed(n):
					bad.append("%s/%s on %s: one burst at %s catches %d of %d" % [tid, (e as Dictionary)["id"], g, most["at"], most["n"], n])
	assert_true(checked > 150, "a good many road fights measured (%d)" % checked)
	assert_true(bad.is_empty(), "road foes bunched under one Fireball:\n  %s" % "\n  ".join(bad))


func test_night_visitors_come_from_all_sides() -> void:
	var rows: Array = []
	for z in 41:
		rows.append(".".repeat(41))
	var grid := CombatGrid.from_rows(rows)
	for g: Variant in CampSite.visitors()["groups"]:
		var group := g as Dictionary
		var spec := CampSite.fight_for(group, grid, Vector2i(20, 20), {})
		var n := _foes(spec.get("monsters", []) as Array)
		if n < 3:
			continue
		var most := most_caught(grid, spec["monsters"] as Array)
		assert_true(int(most["n"]) <= most_allowed(n), "%s: one burst catches %d of %d" % [group["id"], most["n"], n])


func test_no_foe_starts_in_a_wall_or_on_another() -> void:
	var c := Compendium.shared()
	var bad: Array[String] = []
	for id: String in c.table("locations"):
		var loc := c.get_entry("locations", id)
		if not loc.has("map"):
			continue
		var grid := LocationView.grid_for(loc)
		var encounters := loc.get("encounters", []) as Array
		for i in encounters.size():
			var e := encounters[i] as Dictionary
			if PENDING.has("%s:%s" % [id, e["id"]]):
				continue
			var taken := {}
			for m: Variant in e["monsters"]:
				var md := m as Dictionary
				for sq in CombatGrid.footprint(_cell(md["cell"]), _size(str(md["monster"]))):
					var solid := not grid.in_bounds(sq) or grid.has_flag(sq, CombatGrid.WALL) or grid.has_flag(sq, CombatGrid.VOID) \
						or grid.has_flag(sq, CombatGrid.LOW)
					if solid or taken.has(sq):
						bad.append("%s:%s #%d %s at %s: %s" % [id, e["id"], i, md["monster"], sq, "blocked" if solid else "on another foe"])
					taken[sq] = true
	assert_true(bad.is_empty(), "foes starting where no one can stand:\n  %s" % "\n  ".join(bad))
