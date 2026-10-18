extends TestCase
## Dungeon Expansion C7, the main floor and the chapel (K6, K7, K10, K11, K14, K28, K29): the entry's small stone dragons
## wake when the party turns to leave, a secret panel in the dining hall's south wall opens on the archers' post and its
## mirrors, knights line the chapel passage, a narrow stair in the chapel's chancel climbs to the king's balcony (two
## dead in its thrones), and the overlook hides a window a hundred and ten feet down that lands in King Barov and Queen
## Ravenovia's tomb. The fights' bands are held in test_scaled_fights_c7.gd.

const MAIN := "castle_ravenloft_main_floor"
const CHAPEL := "castle_ravenloft_chapel"
const BALCONY := "castle_ravenloft_chapel_balcony"
const OVERLOOK := "castle_ravenloft_overlook"
const TOMBS := "castle_ravenloft_catacombs_tombs"

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = null
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Boots `location` with the castle's band (the four pregens at level 10), the party at `at`, flags set first.
func _boot(location: String, at: Vector2i, flags: Dictionary = {}, visited: Array[String] = []) -> LocationView:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f: String in flags:
		GameState.story.set_flag(f, flags[f])
	for v: String in visited:
		GameState.story.visited[v] = true
	GameState.story.location = location
	GameState.story.positions = [at, at + Vector2i(0, 1), at + Vector2i(-1, 0), at + Vector2i(-1, 1)]
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()
	return root.get("view") as LocationView


func _party() -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"], 10, MAIN, 12)


static func _open(grid: CombatGrid, c: Vector2i) -> bool:
	return grid.in_bounds(c) and not grid.has_flag(c, CombatGrid.WALL) and not grid.has_flag(c, CombatGrid.VOID)


func _prop(loc_id: String, id: String) -> Dictionary:
	for p: Variant in Compendium.shared().get_entry("locations", loc_id)["props"]:
		if str((p as Dictionary)["id"]) == id:
			return p
	return {}


# ---- K7, the entry's small stone dragons

## The plinths beside the great doors call the dragons awake once the party has been further in and turns toward the
## doors; before that, and for a guest still at Strahd's table, they stay stone.
func test_the_dragons_wake_when_the_party_turns_to_leave() -> void:
	var v: LocationView = await _boot(MAIN, Vector2i(25, 22))
	var calls: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: calls.append(ref))
	v.leader().cell = Vector2i(25, 21)
	assert_false(LocationNpcs._check_calls(v), "arriving by the great doors, nothing stirs")
	v.st.visited["crg_great_entry"] = true
	v.st.set_flag("strahd_invitation", "accepted")
	assert_false(LocationNpcs._check_calls(v), "Strahd's invited guest walks out before dinner without a word from the stone")
	v.st.set_flag("castle_dinner", "dined")
	assert_true(LocationNpcs._check_calls(v), "having been further in, turning back toward the doors wakes them")
	assert_eq(calls, ["castle_ravenloft/entry_dragons:wake"] as Array[String], "and calls their scene")
	# Each plinth beside the doors calls the scene; the scene sets the flag that empties them all (the second plinth is skipped then).
	v.st.set_flag("crg_entry_dragons_woken", true)
	assert_false(LocationNpcs._check_calls(v), "and once they have woken, never again")


func test_the_dragons_are_not_woken_by_crossing_the_hall() -> void:
	var v: LocationView = await _boot(MAIN, Vector2i(25, 22), {}, ["crg_great_entry"] as Array[String])
	var calls: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: calls.append(ref))
	for cell: Vector2i in [Vector2i(23, 20), Vector2i(25, 20), Vector2i(26, 20), Vector2i(28, 20), Vector2i(25, 19)]:
		v.leader().cell = cell
		assert_false(LocationNpcs._check_calls(v), "walking the corridor along row 20 at %s (the way to the chapel and the crypt stair)" % cell)
	assert_true(calls.is_empty(), "no scene")


func test_the_wake_is_a_fight_and_empties_the_plinths() -> void:
	var st := _party()
	st.location = MAIN
	for id: String in ["crg_entry_dragon_1", "crg_entry_dragon_2", "crg_entry_dragon_3", "crg_entry_dragon_4"]:
		assert_true(SideQuestPlay.shown(st, MAIN, id), "%s stands on its plinth" % id)
	var beats := SideQuestPlay.play(st, "castle_ravenloft/entry_dragons:wake")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "crg_entry_dragons", "the stone dragons fight")
	assert_true(bool(st.get_flag("crg_entry_dragons_woken", false)), "and they have woken")
	for id: String in ["crg_entry_dragon_1", "crg_entry_dragon_2", "crg_entry_dragon_3", "crg_entry_dragon_4"]:
		assert_false(SideQuestPlay.shown(st, MAIN, id), "%s has left its plinth" % id)
	var enc := SideQuestPlay.encounter(st, MAIN, "crg_entry_dragons")
	assert_eq((enc["monsters"] as Array).size(), 4, "four of them, one off each plinth")
	assert_true(SideQuestPlay.has_foe(enc, "red_dragon_wyrmling"), "red dragon wyrmlings")
	st.set_flag("crg_entry_dragons_broken", true)
	assert_true(SideQuestPlay.shown(st, MAIN, "crg_entry_rubble_1"), "broken stone lies about after them")


# ---- K10 and K11, the archers' post

func test_the_archers_post_hides_behind_a_secret_panel_in_the_dining_hall() -> void:
	var v: LocationView = await _boot(MAIN, Vector2i(10, 13))
	var hidden := HiddenAreas.hidden_cells(v)
	for cell: Vector2i in [Vector2i(10, 16), Vector2i(3, 17), Vector2i(13, 21), Vector2i(8, 19)]:
		assert_true(hidden.has(cell), "%s, in the archers' post, is out of sight" % cell)
	assert_false(hidden.has(Vector2i(10, 14)), "the dining hall is not")
	assert_false(HiddenAreas.hides(v, Vector2i(25, 22)), "nor is the entry")
	var door: Dictionary = {}
	for d: Variant in v.loc["doors"]:
		if str((d as Dictionary)["id"]) == "crg_post_door":
			door = d
	assert_eq(int(door["secret_dc"]), 14, "found by a Search")
	assert_eq(LocationView._cell(door["cell"]), Vector2i(10, 15), "in the dining hall's south wall")
	(v.st.loc_state(MAIN)["found"] as Dictionary)["crg_post_door"] = true
	hidden = HiddenAreas.hidden_cells(v)
	assert_false(hidden.has(Vector2i(8, 19)), "once the panel is found, the post is no secret")


func test_the_post_holds_its_mirrors_and_answers_to_the_narrator() -> void:
	var mirrors := 0
	var loc := Compendium.shared().get_entry("locations", MAIN)
	var cells := {}
	for p: Variant in loc["props"]:
		var pr := p as Dictionary
		if str(pr["id"]).begins_with("crg_post_"):
			var c := (pr["cell"] as Array)
			assert_true(int(c[0]) >= 1 and int(c[0]) <= 14 and int(c[1]) >= 16 and int(c[1]) <= 21, "%s stands in the post" % pr["id"])
			assert_false(cells.has(c), "%s has a square of its own" % pr["id"])
			cells[c] = true
			if str(pr.get("model", "")).begins_with("mirror"):
				mirrors += 1
	assert_true(mirrors >= 4, "a good many mirrors (%d), taken down from around the castle" % mirrors)
	for key: String in ["examine:crg_post_mirror", "examine:crg_post_mirror_turned", "examine:crg_post_rack", "enter:crg_archers_post", "open:crg_post_door"]:
		assert_true(Narrator.new().has_trigger(key), "the Narrator has %s" % key)


# ---- K14, the knights of the chapel passage

func test_the_knights_line_the_chapel_passage_and_leave_the_way_open() -> void:
	var v: LocationView = await _boot(MAIN, Vector2i(43, 17))
	var knights: Array[Vector2i] = []
	for p: Variant in v.loc["props"]:
		if str((p as Dictionary)["id"]).begins_with("crg_faith_knight_"):
			knights.append(LocationView._cell((p as Dictionary)["cell"]))
	assert_eq(knights.size(), 6, "six knights")
	for k: Vector2i in knights:
		assert_true(k.x == 36 or k.x == 44, "%s stands against a wall of the passage" % k)
	# Every way through the passage is still walkable: from the chapel doors to the crypt stair, the turret's back door and
	# the passage door.
	for to: Vector2i in [Vector2i(44, 22), Vector2i(36, 20), Vector2i(38, 12), Vector2i(42, 22)]:
		assert_true(v.walk_to(to), "a way from the chapel doors to %s" % to)
		v.leader().cell = Vector2i(43, 17)
	var study: Dictionary = {}
	for c: Variant in _prop(MAIN, "crg_faith_knight_1")["checks"]:
		study = c
	assert_eq(str(study["skill"]), "investigation", "the trick is worked out with Investigation")
	assert_eq(int(study["dc"]), 13)
	for key: String in ["examine:crg_faith_knights", "check:investigation:faith_knights_study:success", "check:investigation:faith_knights_study:failure"]:
		assert_true(Narrator.new().has_trigger(key), "the Narrator has %s" % key)


# ---- K28 and K29, the king's balcony

func test_the_chancel_stair_and_the_balcony_join_both_ways() -> void:
	var c := Compendium.shared()
	var chapel := c.get_entry("locations", CHAPEL)
	var balcony := c.get_entry("locations", BALCONY)
	var ups: Array = (chapel["exits"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["to"]) == BALCONY)
	assert_eq(ups.size(), 2, "two squares of stair in the chancel's east wall")
	for e: Variant in ups:
		assert_eq(str((e as Dictionary)["spawn"]), "from_chapel")
		assert_true((balcony["spawns"] as Dictionary).has("from_chapel"), "the balcony has the spawn it is entered by")
	var downs: Array = (balcony["exits"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["to"]) == CHAPEL)
	assert_eq(downs.size(), 2, "and back down")
	for e: Variant in downs:
		assert_eq(str((e as Dictionary)["spawn"]), "from_balcony")
	assert_true((chapel["spawns"] as Dictionary).has("from_balcony"), "the chapel has the spawn it is returned to")
	assert_eq(LocationView._cell((chapel["spawns"] as Dictionary)["from_balcony"]), Vector2i(18, 2), "beside the stair, in the chancel")
	var grid := LocationView.grid_for(chapel)
	assert_true(_open(grid, Vector2i(18, 2)) and _open(grid, Vector2i(19, 2)) and _open(grid, Vector2i(19, 3)), "the opened wall squares are floor")


func test_the_party_climbs_to_the_thrones() -> void:
	var v: LocationView = await _boot(BALCONY, Vector2i(3, 8))
	assert_true(v.walk_to(Vector2i(3, 6)), "up to the landing")
	assert_true(v.walk_to(Vector2i(8, 2)), "and out along the gallery")
	var versions: Array[Dictionary] = []
	for e: Variant in v.loc["encounters"]:
		if str((e as Dictionary)["id"]) == "crg_balcony_zombies":
			versions.append(e)
	assert_eq(versions.size(), 3, "one version for each of levels 11, 10 and 9")
	for e: Dictionary in versions:
		assert_eq(str(e["surprise"]), "party", "an ambush")
		var monsters := e["monsters"] as Array
		# The book's two Strahd zombies slump in the thrones; the rest, Strahd's spawn at the rail, are the fight's own.
		assert_eq(str((monsters[0] as Dictionary)["monster"]), "strahd_zombie")
		assert_eq(str((monsters[1] as Dictionary)["monster"]), "strahd_zombie")
		assert_eq(LocationView._cell((monsters[0] as Dictionary)["cell"]), Vector2i(9, 2), "in front of the first throne")
		assert_eq(LocationView._cell((monsters[1] as Dictionary)["cell"]), Vector2i(13, 2), "and of the second")
		for m: Variant in monsters.slice(2):
			assert_eq(str((m as Dictionary)["monster"]), "vampire_spawn")
	for key: String in ["enter:crg_balcony_landing", "enter:crg_balcony", "examine:crg_balcony_throne"]:
		assert_true(Narrator.new().has_trigger(key), "the Narrator has %s" % key)


# ---- K6 to K88, the window below the overlook

func test_the_window_is_a_search_find_and_the_climb_lands_in_the_royal_tomb() -> void:
	var window := _prop(OVERLOOK, "crg_overlook_low_window")
	assert_eq(str(window["kind"]), "search", "found by searching the parapet")
	assert_eq(int(window["search_dc"]), 15, "the book's Perception 15")
	assert_eq(str(window["skill"]), "perception")
	var st := _party()
	st.location = OVERLOOK
	var ref := str(window["dialogue"])
	# A rope takes the party down without a roll.
	var with_rope := _party()
	with_rope.party[0].add_item("rope")
	var beats := SideQuestPlay.play(with_rope, ref, ["rope"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var move := (beats[-1] as Dictionary).get("move", {}) as Dictionary
	assert_eq(str(move.get("location", "")), TOMBS, "down to the royal tomb")
	assert_eq(str(move.get("spawn", "")), "from_overlook")
	# Without one the rope's option is shut, and the way out is still there.
	var shut := SideQuestPlay.play(st, ref, ["rope"])
	assert_ne(SideQuestPlay.missing(shut), "", "no rope, no rope option")
	var left := SideQuestPlay.play(st, ref, ["Step back"])
	assert_eq(SideQuestPlay.missing(left), "")
	assert_true((left[-1] as Dictionary).get("move", {}).is_empty(), "stepping back moves no one")
	# The bare rock is a hard climb: some tries land, some slip back to the parapet an hour later, and a slip isn't a spent check.
	var landed := false
	var slipped := false
	for seed_value: int in 24:
		var s := _party()
		var t0 := s.total_minutes()
		var b := SideQuestPlay.play(s, ref, ["bare", "Step back"], seed_value)
		assert_eq(SideQuestPlay.missing(b), "", "seed %d" % seed_value)
		var mv := (b[-1] as Dictionary).get("move", {}) as Dictionary
		if not mv.is_empty():
			landed = true
			assert_eq(str(mv["location"]), TOMBS)
			assert_true(s.total_minutes() - t0 >= 30, "a climb takes time")
		else:
			slipped = true
			assert_true(s.total_minutes() - t0 >= 60, "a slip costs an hour")
	assert_true(landed and slipped, "the bare climb can land and can slip (%s, %s)" % [landed, slipped])


func test_the_tomb_has_a_spawn_below_the_window() -> void:
	var tomb := Compendium.shared().get_entry("locations", TOMBS)
	var spawn := (tomb["spawns"] as Dictionary)["from_overlook"] as Array
	var grid := LocationView.grid_for(tomb)
	assert_true(_open(grid, Vector2i(int(spawn[0]), int(spawn[1]))), "an open square")
	var inside := false
	for a: Variant in tomb["areas"]:
		var area := a as Dictionary
		if str(area["id"]) == "castle_ravenloft_tomb_of_barov_and_ravenovia":
			var r := area["cells"] as Array
			inside = int(spawn[0]) >= int((r[0] as Array)[0]) and int(spawn[0]) <= int((r[1] as Array)[0]) and int(spawn[1]) >= int((r[0] as Array)[1]) and int(spawn[1]) <= int((r[1] as Array)[1])
	assert_true(inside, "in the royal tomb, under the window")
