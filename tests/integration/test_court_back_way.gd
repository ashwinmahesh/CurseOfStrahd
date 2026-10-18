extends TestCase
## The back way behind the study hearth (Dungeon Expansion Plan C3, docs/regions/castle_ravenloft_court.md §15): the hearth
## that has to be out before the party crawls through, the false treasury's trapped chest and its sconces, the hall of
## webs, the belfry's rope and the stair down to the treasury, the smokestack from the keep roof, and Strahd's tower in the
## treasury. The belfry's fight is tuned in test_scaled_fights_castle_belfry.

const WAY := "castle_ravenloft_court_belfry"
const COURT := "castle_ravenloft_court"
const ROOFS := "castle_ravenloft_spires_roofs"
const TREASURY := "castle_ravenloft_court_treasury"
const WEEPING := "castle_ravenloft_court_weeping"
const FILE := "castle_ravenloft/court_way:"

## The treasury's rows as they were before the tower: no walkable square of it may be closed (rule 2).
const TREASURY_ROWS: Array[String] = [
	"################",
	"#######..#######",
	"#######..#######",
	"####........####",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"################"]


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _party(location: String = COURT) -> StoryState:
	return SideQuestPlay.party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"], 10, location, 12)


func _prop(loc_id: String, prop_id: String) -> Dictionary:
	for p: Variant in _loc(loc_id)["props"]:
		if str((p as Dictionary)["id"]) == prop_id:
			return p as Dictionary
	return {}


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


## The squares of `rows` reachable on foot (no diagonals, doors count as open) from `from`.
func _reach(rows: Array, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
				continue
			if str(rows[n.y])[n.x] in ["#", " ", "w"]:
				continue
			seen[n] = true
			todo.append(n)
	return seen


func _moved(beats: Array[Dictionary]) -> Dictionary:
	return (beats[-1] as Dictionary).get("move", {}) as Dictionary


# --- The map ----------------------------------------------------------------------------------------------------------

func test_the_back_way_is_one_walk_from_the_hearth_to_the_treasury_stair() -> void:
	var loc := _loc(WAY)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	var spawns := loc["spawns"] as Dictionary
	var reach := _reach(rows, _cell(spawns["from_study"]))
	for e: Variant in loc["exits"]:
		assert_true(reach.has(_cell((e as Dictionary)["cell"])), "the exit %s can be walked to" % (e as Dictionary)["id"])
	for p: Variant in loc["props"]:
		assert_true(reach.has(_cell((p as Dictionary)["cell"])) or str(rows[_cell((p as Dictionary)["cell"]).y])[_cell((p as Dictionary)["cell"]).x] == "#",
			"%s is on a walkable or a wall square" % (p as Dictionary)["id"])
	for c: Variant in loc["containers"]:
		assert_true(reach.has(_cell((c as Dictionary)["cell"])), "%s can be reached" % (c as Dictionary)["id"])
	for d: Variant in loc["doors"]:
		assert_true(reach.has(_cell((d as Dictionary)["cell"])), "%s sits on the way" % (d as Dictionary)["id"])
	assert_true(reach.has(_cell(spawns["from_treasury"])), "the stair's arrival is on the way too")
	for x in range(20, 36):
		assert_true(reach.has(Vector2i(x, 14)), "the path cut through the hall of webs is whole at x=%d" % x)
	assert_eq(str(rows[14]).substr(21, 14), ".".repeat(14), "and it is clear floor, the webs lie either side of it")
	for e: Variant in loc["encounters"]:
		for m: Variant in (e as Dictionary)["monsters"]:
			assert_true(reach.has(_cell((m as Dictionary)["cell"])), "a spider stands on open floor")


func test_the_way_down_leads_to_the_old_vault_stair_and_the_hearth_to_the_study() -> void:
	var loc := _loc(WAY)
	var down := {}
	var up := {}
	for e: Variant in loc["exits"]:
		if str((e as Dictionary)["id"]) == "court_way_stair_down":
			down = e as Dictionary
		if str((e as Dictionary)["id"]) == "court_way_to_study":
			up = e as Dictionary
	assert_eq(str(down["to"]), TREASURY)
	assert_eq(str(down["spawn"]), "from_court", "the treasury's own arrival at the foot of the portrait stair: nothing new in its rows")
	assert_eq(str(up["to"]), COURT)
	assert_true((_loc(COURT)["spawns"] as Dictionary).has(str(up["spawn"])), "the study has the arrival the passage leads back to")
	assert_true((_loc(COURT)["spawns"] as Dictionary).has("from_chimney"))
	assert_true((_loc(WEEPING)["spawns"] as Dictionary).has("from_gas"), "the guest room is where the gas leaves the party")


func test_the_study_hearth_prop_keeps_its_old_squares_and_checks() -> void:
	var court := _loc(COURT)
	var spawns := court["spawns"] as Dictionary
	assert_eq(_cell(spawns["default"]), Vector2i(22, 21), "the old spawns stand where they were")
	assert_eq(_cell(spawns["from_treasury"]), Vector2i(12, 13))
	assert_eq(_cell(_prop(COURT, "court_study_hearth")["cell"]), Vector2i(4, 0), "the hearth itself did not move")
	assert_false((_prop(COURT, "court_study_hearth")["checks"] as Array).is_empty(), "and it still has its walls check")
	var grate := _prop(COURT, "court_hearth_grate")
	assert_eq(_cell(grate["cell"]), Vector2i(4, 1), "the grate is in front of it")


func test_the_treasury_gained_a_tower_and_lost_no_square() -> void:
	var loc := _loc(TREASURY)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	assert_eq(rows.size(), TREASURY_ROWS.size())
	for i in rows.size():
		assert_eq(str(rows[i]), TREASURY_ROWS[i], "row %d of the treasury is as it was" % i)
	var fs := loc["fortress"] as Dictionary
	var origin := _cell(fs["cell"])
	var plot := FortressSite.footprint(origin)
	for c in plot:
		assert_eq(str(rows[c.y])[c.x], "#", "the tower stands on wall squares only: %s" % c)
	assert_true(_cell(fs["door"]) in plot, "its door is in its footprint")
	assert_false(_cell(fs["front"]) in plot)
	assert_true(str(rows[_cell(fs["front"]).y])[_cell(fs["front"]).x] == ".", "and the square before it is open floor")
	for key: String in ["props", "containers"]:
		for t: Variant in loc[key]:
			assert_false(_cell((t as Dictionary)["cell"]) in plot, "%s is not under the tower" % (t as Dictionary)["id"])
	for sp: Variant in (loc["spawns"] as Dictionary).values():
		assert_false(_cell(sp) in plot)
	for enc: Variant in loc["encounters"]:
		for m: Variant in (enc as Dictionary)["monsters"]:
			assert_false(_cell((m as Dictionary)["cell"]) in plot, "no foe starts under the tower")
	var hoard := {}
	for c: Variant in loc["containers"]:
		if str((c as Dictionary)["id"]) == "court_treasury_hoard":
			hoard = c as Dictionary
	assert_eq(_cell(hoard["cell"]), Vector2i(7, 8), "the Tarokka hoard keeps its square")
	assert_eq(str(((loc["treasure_spots"] as Dictionary)["castle_ravenloft_treasury"] as Dictionary)["container"]), "court_treasury_hoard")
	assert_true(float(hoard["gold"]) > 1200.0, "the heaps of coin are bigger than they were")


func test_the_tower_door_stays_shut() -> void:
	var door := {}
	for e: Variant in _loc(TREASURY)["exits"]:
		if str((e as Dictionary)["id"]) == FortressSite.ENTRY:
			door = e as Dictionary
	assert_false(door.is_empty(), "the tower is clickable through its door")
	assert_false(StoryConditions.check(str(door["when"]), _party(TREASURY)), "and it never opens: only its owner's word does")
	assert_true(str(door["locked_text"]) != "")
	assert_eq(str(door["to"]), TREASURY, "its way leads back to the treasury, so the castle and the tower's own maps are not one building")
	assert_eq(RestRules.building_of(FortressSite.UPPER).size(), 3, "the party's own fortress is still one building of three maps")


# --- The study hearth -------------------------------------------------------------------------------------------------

func test_the_hearth_gives_nothing_away_until_the_passage_is_found() -> void:
	var st := _party()
	var beats := SideQuestPlay.play(st, FILE + "grate")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_moved(beats).is_empty(), "nothing to crawl into yet")
	assert_false(st.get_flag("court_hearth_out"))


func test_waiting_out_the_fire_costs_three_hours_and_then_the_way_is_open() -> void:
	var st := _party()
	st.set_flag("court_hearth_found")
	var before := st.total_minutes()
	var beats := SideQuestPlay.play(st, FILE + "grate", ["Wait for the fire", "Crawl through"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("court_hearth_out"))
	assert_eq(st.total_minutes() - before, 180, "three hours")
	assert_eq(str(_moved(beats).get("location", "")), WAY)
	assert_eq(str(_moved(beats).get("spawn", "")), "from_study")


func test_a_bucket_of_water_puts_it_out_at_once_and_only_for_a_party_that_carries_one() -> void:
	var st := _party()
	st.set_flag("court_hearth_found")
	var none := SideQuestPlay.play(st, FILE + "grate", ["bucket"])
	assert_true(SideQuestPlay.missing(none) != "", "no bucket, no such option")
	st.give_item("bucket", 1)
	var before := st.total_minutes()
	var beats := SideQuestPlay.play(st, FILE + "grate", ["bucket", "Crawl through"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("court_hearth_out"))
	assert_eq(st.total_minutes() - before, 0, "no time passes")
	assert_eq(str(_moved(beats).get("location", "")), WAY)


func test_a_cold_hearth_with_a_found_passage_offers_the_crawl_and_a_way_out() -> void:
	var st := _party()
	st.set_flag("court_hearth_found")
	st.set_flag("court_hearth_out")
	var beats := SideQuestPlay.play(st, FILE + "grate")
	assert_true(_moved(beats).is_empty(), "the last option is to leave it alone")
	assert_eq(str((beats[-2] as Dictionary).get("kind", "")), "options")


func test_the_hearth_checks_come_in_their_order() -> void:
	var st := _party()
	var grate := _prop(COURT, "court_hearth_grate")
	var open: Array[String] = []
	for c: Variant in grate["checks"]:
		if WorldChecks.open(st, COURT, c as Dictionary):
			open.append(str((c as Dictionary)["id"]))
	assert_eq(open, ["hearth_flue", "hearth_draught"] as Array[String], "two ways to find the passage, and the smothering waits for it")
	st.set_flag("court_hearth_found")
	open.clear()
	for c: Variant in grate["checks"]:
		if WorldChecks.open(st, COURT, c as Dictionary):
			open.append(str((c as Dictionary)["id"]))
	assert_true("hearth_smother" in open, "once found, the fire can be beaten out with a cloak")
	st.set_flag("court_hearth_out")
	assert_false(WorldChecks.open(st, COURT, WorldChecks.find(grate, "hearth_smother")), "and not once it is out")


func test_both_ways_of_finding_it_set_the_same_flag_and_the_smothering_burns() -> void:
	var grate := _prop(COURT, "court_hearth_grate")
	for id: String in ["hearth_flue", "hearth_draught"]:
		var win := (WorldChecks.find(grate, id)["success"]) as Dictionary
		assert_eq(str(win["flag"]), "court_hearth_found")
	var smother := WorldChecks.find(grate, "hearth_smother")
	assert_eq(str((smother["success"] as Dictionary)["damage_type"]), "fire", "passing a lit hearth burns, win or lose")
	assert_eq(str((smother["failure"] as Dictionary)["damage_type"]), "fire")
	assert_eq(str((smother["success"] as Dictionary)["flag"]), "court_hearth_out")


# --- The false treasury -----------------------------------------------------------------------------------------------

func test_the_trapped_chest_gasses_the_party_when_the_breath_is_not_held() -> void:
	var st := _party(WAY)
	var before := st.total_minutes()
	var gold := st.gold
	var beats := SideQuestPlay.play(st, FILE + "gas_chest", ["Open the chest"], TestChars.seed_for_d20(1))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("court_way_gassed"))
	assert_eq(st.total_minutes() - before, 240, "four hours asleep")
	assert_eq(str(_moved(beats).get("location", "")), WEEPING, "they wake in the guest room")
	assert_eq(str(_moved(beats).get("spawn", "")), "from_gas")
	assert_eq(st.gold, gold, "and the money is still in the chest")


func test_the_money_waits_in_the_chest_for_whoever_comes_back() -> void:
	var st := _party(WAY)
	SideQuestPlay.play(st, FILE + "gas_chest", ["Open the chest"], TestChars.seed_for_d20(1))
	var gold := st.gold
	SideQuestPlay.play(st, FILE + "gas_chest")
	assert_eq(st.gold - gold, 35.0, "a little money")
	SideQuestPlay.play(st, FILE + "gas_chest")
	assert_eq(st.gold - gold, 35.0, "once")


func test_a_held_breath_keeps_the_party_awake_and_takes_the_money() -> void:
	var st := _party(WAY)
	var gold := st.gold
	var before := st.total_minutes()
	var beats := SideQuestPlay.play(st, FILE + "gas_chest", ["Open the chest"], TestChars.seed_for_d20(20))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_moved(beats).is_empty())
	assert_true(st.get_flag("court_way_gassed") and st.get_flag("court_way_chest_taken"))
	assert_eq(st.gold - gold, 35.0)
	assert_eq(st.total_minutes() - before, 0)


func test_a_rope_opens_the_chest_from_across_the_room_without_a_roll() -> void:
	var st := _party(WAY)
	var none := SideQuestPlay.play(st, FILE + "gas_chest", ["rope"])
	assert_true(SideQuestPlay.missing(none) != "", "no rope, no such option")
	st.give_item("rope", 1)
	var gold := st.gold
	var beats := SideQuestPlay.play(st, FILE + "gas_chest", ["rope"], TestChars.seed_for_d20(1))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_moved(beats).is_empty(), "even a natural 1 does nothing: nobody rolls")
	assert_eq(st.gold - gold, 35.0)


func test_a_close_look_finds_the_vent_and_makes_opening_it_easier() -> void:
	var st := _party(WAY)
	var beats := SideQuestPlay.play(st, FILE + "gas_chest", ["Look closely"], TestChars.seed_for_d20(20))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("court_way_gas_known"))


func test_the_empty_sconce_takes_a_torch_and_opens_the_panel() -> void:
	var st := _party(WAY)
	var door := {}
	for d: Variant in _loc(WAY)["doors"]:
		if str((d as Dictionary)["id"]) == "court_way_panel":
			door = d as Dictionary
	assert_false(StoryConditions.check(str(door["when"]), st), "the panel won't budge")
	var none := SideQuestPlay.play(st, FILE + "sconce", ["Set a torch"])
	assert_true(SideQuestPlay.missing(none) != "", "nothing to set in it without a torch")
	assert_false(StoryConditions.check(str(door["when"]), st))
	st.give_item("torch", 1)
	var beats := SideQuestPlay.play(st, FILE + "sconce", ["Set a torch"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(StoryConditions.check(str(door["when"]), st), "it slides open")
	assert_false(st.party_has_item("torch"), "the torch stays in the sconce")


func test_the_dead_adventurer_has_a_torch_for_a_party_that_has_none() -> void:
	var skeleton := _prop(WAY, "court_way_skeleton")
	assert_eq(str(skeleton["item"]), "torch")


# --- The belfry -------------------------------------------------------------------------------------------------------

func test_pulling_the_rope_starts_the_spiders_fight_once() -> void:
	var st := _party(WAY)
	assert_false(SideQuestPlay.encounter(st, WAY, "court_way_spiders").is_empty(), "the fight is there to be had")
	var beats := SideQuestPlay.play(st, FILE + "rope", ["Pull the hanging rope"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "court_way_spiders")
	assert_true(st.get_flag("court_way_bell_rung"))
	var again := SideQuestPlay.play(st, FILE + "rope")
	assert_eq(SideQuestPlay.combat_of(again), "", "the bell has rung: the rope only hangs there")
	st.set_flag("court_way_spiders_cleared")
	assert_true(SideQuestPlay.encounter(st, WAY, "court_way_spiders").is_empty(), "and won, the fight is over for good")


func test_the_secret_door_to_the_treasury_is_hidden_until_searched_for() -> void:
	for d: Variant in _loc(WAY)["doors"]:
		if str((d as Dictionary)["id"]) == "court_way_vault_door":
			assert_true(int((d as Dictionary)["secret_dc"]) > 0)
			return
	assert_true(false, "the belfry has its secret door")


# --- The smokestack ---------------------------------------------------------------------------------------------------

func test_the_smokestack_burns_only_while_the_study_fire_does() -> void:
	var st := _party(ROOFS)
	var stack := _prop(ROOFS, "spires_smokestack")
	var smoke := WorldChecks.find(stack, "stack_smoke")
	var cold := WorldChecks.find(stack, "stack_climb")
	assert_true(WorldChecks.open(st, ROOFS, smoke) and not WorldChecks.open(st, ROOFS, cold), "the fire burns: the smoke is in the flue")
	assert_eq(str((smoke["failure"] as Dictionary)["damage_type"]), "poison")
	st.set_flag("court_hearth_out")
	assert_true(WorldChecks.open(st, ROOFS, cold) and not WorldChecks.open(st, ROOFS, smoke), "the fire is out: a plain climb")
	assert_false((cold["failure"] as Dictionary).has("damage_type") and str((cold["failure"] as Dictionary)["damage_type"]) == "poison")
	for c: Dictionary in [smoke, cold]:
		assert_eq(str(((c as Dictionary)["success"] as Dictionary)["flag"]), "court_stack_climbed")


func test_the_way_down_the_stack_opens_once_someone_has_climbed_it() -> void:
	var st := _party(ROOFS)
	var shut := SideQuestPlay.play(st, FILE + "stack", ["Climb down"])
	assert_true(SideQuestPlay.missing(shut) != "", "not before somebody has climbed it")
	st.set_flag("court_stack_climbed")
	var beats := SideQuestPlay.play(st, FILE + "stack", ["Climb down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(str(_moved(beats).get("location", "")), COURT)
	assert_eq(str(_moved(beats).get("spawn", "")), "from_chimney")


# --- The words --------------------------------------------------------------------------------------------------------

func test_every_new_place_and_thing_has_its_narrator_line() -> void:
	var n := Narrator.new(1)
	var st := _party(WAY)
	for key: String in ["enter:castle_ravenloft_court_belfry", "enter:court_way_false_treasury", "enter:court_way_hall_of_webs",
			"enter:court_way_belfry", "enter:court_vault_dome", "examine:court_way_skeleton", "examine:court_way_webs",
			"open:court_way_bronze_doors", "check:investigation:hearth_flue:success", "check:investigation:hearth_flue:failure",
			"check:perception:hearth_draught:success", "check:perception:hearth_draught:failure",
			"check:dex:hearth_smother:success", "check:dex:hearth_smother:failure", "examine:spires_smokestack",
			"check:athletics:stack_climb:success", "check:athletics:stack_climb:failure",
			"check:athletics:stack_smoke:success", "check:athletics:stack_smoke:failure"]:
		assert_true(n.line(key, st, null) != "", "the Narrator says something for %s" % key)
	var cold := _party(WAY)
	cold.set_flag("court_hearth_out")
	assert_true(n.line("examine:spires_smokestack", cold, null) != "", "and another once the fire is out")


func test_the_dome_gets_its_own_area_over_the_whole_vault() -> void:
	var dome := {}
	var vault := {}
	for a: Variant in _loc(TREASURY)["areas"]:
		if str((a as Dictionary)["id"]) == "court_vault_dome":
			dome = a as Dictionary
		if str((a as Dictionary)["id"]) == "court_treasury":
			vault = a as Dictionary
	assert_eq(dome["cells"], vault["cells"], "it covers what the final battle's area covers, with nothing of its own to override")
	assert_false(dome.has("floor") or dome.has("walls") or dome.has("light"))
