extends TestCase
## The Rooms of Weeping's west wing and the parapets (Dungeon Expansion Plan C6, docs/regions/castle_ravenloft_court.md §16;
## the book's K32, K34, K35, K36, K44, K45 and K46): one walk from the hall of weeping through the guardians' passage to the
## count's dining hall, the Hall of Heroes, the closet of capes, the maids' hall and the servants' upper rooms, the ladder
## behind the mirror down into the high tower, and the parapets outside the count's bedroom. Its two fights are tuned in
## test_scaled_fights_c6.

const WING := "castle_ravenloft_court_west_wing"
const PARAPETS := "castle_ravenloft_parapets"
const WEEPING := "castle_ravenloft_court_weeping"
const SPIRES := "castle_ravenloft_spires"
const FILE := "castle_ravenloft/court_west_wing:"


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _party(location: String = WING) -> StoryState:
	return SideQuestPlay.party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"], 10, location, 12)


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


func _entry(loc_id: String, key: String, id: String) -> Dictionary:
	for t: Variant in _loc(loc_id)[key]:
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


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


func _text(beats: Array[Dictionary]) -> String:
	return SideQuestPlay.text(beats)


# --- The maps ---------------------------------------------------------------------------------------------------------

## Every open square of the wing is one walk from where the hall of weeping lets the party in, so no room is cut off.
func test_the_wing_is_one_walk_from_the_hall_of_weeping() -> void:
	var loc := _loc(WING)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	assert_eq(rows.size(), 24)
	assert_eq(str(rows[0]).length(), 40)
	var reach := _reach(rows, _cell((loc["spawns"] as Dictionary)["from_weeping"]))
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] in [".", "="]:
				assert_true(reach.has(Vector2i(x, y)), "the square (%d, %d) can be walked to" % [x, y])
	for id: String in (loc["spawns"] as Dictionary):
		assert_true(reach.has(_cell((loc["spawns"] as Dictionary)[id])), "the arrival %s is on the walk" % id)
	for key: String in ["containers", "doors", "npcs"]:
		for t: Variant in loc[key]:
			assert_true(reach.has(_cell((t as Dictionary)["cell"])), "%s sits on the walk" % (t as Dictionary).get("id", ""))
	for e: Variant in loc["encounters"]:
		for m: Variant in (e as Dictionary)["monsters"]:
			assert_true(reach.has(_cell((m as Dictionary)["cell"])), "a foe of %s stands on open floor" % (e as Dictionary)["id"])
	for s: Variant in (loc["spawns"] as Dictionary).values():
		assert_true(str(rows[_cell(s).y])[_cell(s).x] in [".", "="], "no arrival is inside a wall")


## The doors between the rooms stand in the wall between them, on open floor.
func test_the_three_doors_stand_in_the_walls_between_the_rooms() -> void:
	var rows := (_loc(WING)["map"] as Dictionary)["rows"] as Array
	for d: Variant in _loc(WING)["doors"]:
		var c := _cell((d as Dictionary)["cell"])
		assert_eq(str(rows[c.y])[c.x], ".", "%s stands on open floor" % (d as Dictionary)["id"])
		assert_eq(str(rows[c.y])[c.x - 1], ".", "with a room to its west")
		assert_eq(str(rows[c.y])[c.x + 1], ".", "and a room to its east")
		assert_eq(str(rows[c.y - 1])[c.x], "#", "and wall above")
		assert_eq(str(rows[c.y + 1])[c.x], "#", "and wall below")


## A way out stands on a wall square beside open floor (the way the game's other exits do), and leads to a spawn that exists.
func test_every_exit_stands_in_a_wall_beside_open_floor_and_leads_somewhere_real() -> void:
	var exits: Array[Dictionary] = []
	for e: Variant in _loc(WING)["exits"]:
		exits.append({"from": WING, "exit": e})
	for e: Variant in _loc(PARAPETS)["exits"]:
		exits.append({"from": PARAPETS, "exit": e})
	for id: String in ["court_weeping_to_wing", "court_bedroom_window"]:
		exits.append({"from": WEEPING, "exit": _entry(WEEPING, "exits", id)})
	exits.append({"from": SPIRES, "exit": _entry(SPIRES, "exits", "spires_servants_ladder")})
	assert_eq(exits.size(), 8, "the two maps' five exits and the three joins")
	for x: Dictionary in exits:
		var e := x["exit"] as Dictionary
		var rows := (_loc(str(x["from"]))["map"] as Dictionary)["rows"] as Array
		var c := _cell(e["cell"])
		assert_eq(str(rows[c.y])[c.x], "#", "%s stands in a wall" % e["id"])
		var beside := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < str(rows[n.y]).length() and str(rows[n.y])[n.x] == ".":
				beside = true
		assert_true(beside, "%s has open floor beside it" % e["id"])
		var dest := _loc(str(e["to"]))
		assert_true((dest["spawns"] as Dictionary).has(str(e["spawn"])), "%s leads to a spawn that exists (%s)" % [e["id"], e["spawn"]])
		var arrival := _cell((dest["spawns"] as Dictionary)[str(e["spawn"])])
		var drows := (dest["map"] as Dictionary)["rows"] as Array
		assert_true(str(drows[arrival.y])[arrival.x] in [".", "="], "and it is on open floor")


## The joins are inserts: nothing stood on the new arrivals, the hall of weeping's and the tower's own arrivals are where they
## were, and no prop, container or person sits on a new arrival's square.
func test_the_joins_move_nothing_that_was_there() -> void:
	var weeping := _loc(WEEPING)
	assert_eq(_cell((weeping["spawns"] as Dictionary)["default"]), Vector2i(36, 10), "the hall of weeping's own arrival is where it was")
	assert_eq(_cell((weeping["spawns"] as Dictionary)["from_gas"]), Vector2i(19, 20))
	assert_eq(_cell(_entry(WEEPING, "exits", "court_weeping_stairs_down")["cell"]), Vector2i(38, 10))
	var spires := _loc(SPIRES)
	assert_eq(_cell((spires["spawns"] as Dictionary)["default"]), Vector2i(3, 12))
	assert_eq(_cell((spires["spawns"] as Dictionary)["from_court"]), Vector2i(19, 2))
	for pair: Array in [[WEEPING, "from_west_wing"], [WEEPING, "from_parapets"], [SPIRES, "from_servants"]]:
		var loc := _loc(str(pair[0]))
		var at := _cell((loc["spawns"] as Dictionary)[str(pair[1])])
		for key: String in ["props", "containers", "npcs", "doors"]:
			for t: Variant in loc.get(key, []):
				assert_ne(_cell((t as Dictionary)["cell"]), at, "nothing stands on %s's %s" % [pair[0], pair[1]])


func test_the_parapets_are_a_rain_slick_walk_over_a_drop() -> void:
	var loc := _loc(PARAPETS)
	var map := loc["map"] as Dictionary
	assert_true(bool(map["outdoors"]), "they are outside")
	assert_true(int(map["drop_ft"]) >= 500, "a long way down")
	var rows := map["rows"] as Array
	assert_eq(str(rows[5]), " " + "=".repeat(28) + " ", "a low parapet along the edge")
	var reach := _reach(rows, _cell((loc["spawns"] as Dictionary)["from_heroes"]))
	for y: int in [2, 3, 4]:
		for x in range(1, 29):
			assert_true(reach.has(Vector2i(x, y)), "the walk is whole at (%d, %d)" % [x, y])
	assert_eq(str(loc["rest"]), "no", "no Long Rest in the rain with the armour walking")
	var moods := (JSON.parse_string(FileAccess.get_file_as_string("res://art/atmosphere/moods.json")) as Dictionary)["places"] as Dictionary
	assert_eq(str(moods[PARAPETS]), "ravenloft_roofs", "the rain and the crows of the keep's roofs")


# --- The guardians' passage and the vermin ---------------------------------------------------------------------------------

func test_two_guards_stand_in_the_alcoves_until_the_vermin_are_gone() -> void:
	var st := _party()
	assert_true(SideQuestPlay.shown(st, WING, "court_vermin_guard_n"))
	assert_true(SideQuestPlay.shown(st, WING, "court_vermin_guard_s"))
	st.set_flag("court_vermin_cleared")
	assert_false(SideQuestPlay.shown(st, WING, "court_vermin_guard_n"), "the alcoves are empty once the rats are destroyed")
	assert_false(SideQuestPlay.shown(st, WING, "court_vermin_guard_s"))
	assert_true(SideQuestPlay.encounter(_party(), WING, "court_vermin").size() > 0, "the fight waits for a party that has not won it")
	assert_true(SideQuestPlay.encounter(st, WING, "court_vermin").is_empty(), "and is gone once it is won")
	var enc := SideQuestPlay.encounter(_party(), WING, "court_vermin")
	assert_eq(str(enc["trigger"]), "enter_area:court_vermin_door")
	for g: String in ["court_vermin_guard_n", "court_vermin_guard_s"]:
		var cell := _cell(_entry(WING, "props", g)["cell"])
		var found := false
		for m: Variant in enc["monsters"]:
			if _cell((m as Dictionary)["cell"]) == cell:
				found = true
		assert_true(found, "a swarm starts where %s stood" % g)


func test_the_parapets_are_watched_by_two_suits_of_armour_until_they_are_broken() -> void:
	var enc := SideQuestPlay.encounter(_party(PARAPETS), PARAPETS, "court_parapet_watch")
	assert_eq(str(enc["trigger"]), "enter_area:court_parapets")
	assert_true(bool(enc.get("waiting", false)), "they stand in plain view first")
	assert_eq((enc["monsters"] as Array).size(), 2, "two suits of animated armour")
	for m: Variant in enc["monsters"]:
		assert_eq(str((m as Dictionary)["monster"]), "strahds_animated_armor")
		assert_true((m as Dictionary).has("facing"), "each says which way it looks")
	var done := _party(PARAPETS)
	done.set_flag("court_parapets_cleared")
	assert_true(SideQuestPlay.encounter(done, PARAPETS, "court_parapet_watch").is_empty())


# --- The count's dining hall ------------------------------------------------------------------------------------------------

func test_taking_the_groom_sets_the_flag_and_the_figurine_leaves_the_floor() -> void:
	var st := _party()
	assert_true(SideQuestPlay.shown(st, WING, "court_groom_figurine"))
	var left := SideQuestPlay.play(st, FILE + "groom", ["Leave him"])
	assert_eq(SideQuestPlay.missing(left), "")
	assert_false(st.get_flag("court_groom_taken"), "leaving him is a choice")
	var beats := SideQuestPlay.play(st, FILE + "groom", ["Take the groom"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("court_groom_taken"))
	assert_false(SideQuestPlay.shown(st, WING, "court_groom_figurine"), "he is in somebody's pocket")


## The first time the cake is whole; walking back in after the groom has gone out, it has burst and the window is broken.
func test_the_cake_has_burst_when_the_party_comes_back_with_the_groom() -> void:
	var n := Narrator.new(1)
	var st := _party()
	var first := n.line("enter:court_count_dining", st, null)
	assert_true(first.contains("sagging wedding cake"), "whole the first time: %s" % first)
	st.set_flag("court_groom_taken")
	st.minute_of_day += 5
	var later := n.line("enter:court_count_dining", st, null)
	assert_true(later.contains("burst open"), "and burst when they come back: %s" % later)
	assert_true(later.contains("shattered outward"), "with the window broken outward, and nothing said of what went out")


func test_the_harp_calls_a_ghost_for_a_performance_or_a_blessing_and_a_bad_chord_costs_nothing() -> void:
	var bad := _party()
	var fail := SideQuestPlay.play(bad, FILE + "harp", ["Play the harp", "Speak the old blessing"], TestChars.seed_for_d20(1))
	assert_eq(SideQuestPlay.missing(fail), "")
	assert_false(bad.get_flag("court_pidlwick_ghost_met"), "a sour chord brings nobody")
	assert_true(_text(fail).contains("sour chord"))
	var good := _party()
	var beats := SideQuestPlay.play(good, FILE + "harp", ["Play the harp"], TestChars.seed_for_d20(20))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(good.get_flag("court_pidlwick_ghost_met"), "a clear note calls the first Pidlwick")
	assert_true(_text(beats).contains("Pidlwick, at your service"))
	var blessed := _party()
	var by_prayer := SideQuestPlay.play(blessed, FILE + "harp", ["Speak the old blessing"], TestChars.seed_for_d20(20))
	assert_eq(SideQuestPlay.missing(by_prayer), "")
	assert_true(blessed.get_flag("court_pidlwick_ghost_met"), "the old blessing does as well")
	var walked := _party()
	var away := SideQuestPlay.play(walked, FILE + "harp", ["Leave it"])
	assert_eq(SideQuestPlay.missing(away), "")
	assert_false(walked.get_flag("court_pidlwick_ghost_met"), "and the harp can be left alone")


func test_the_ghost_answers_three_questions_and_says_goodbye() -> void:
	var st := _party()
	st.set_flag("court_pidlwick_ghost_met")
	var again := SideQuestPlay.play(st, FILE + "harp")
	assert_true(_text(again).contains("still hum"), "once he has come, the harp only hums")
	var beats := SideQuestPlay.play(st, FILE + "ghost_menu", ["What happened at the feast", "How did you die", "clockwork double", "Thank you"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var all := _text(beats)
	assert_true(all.contains("blood on the hem"), "the feast")
	assert_true(all.contains("tumble down the high tower stair"), "his death, with no name for who helped")
	assert_true(all.contains("ticking shadow"), "his clockwork double")
	assert_true(all.contains("practised bow"), "and his bow")
	assert_eq(str(beats[-1]["kind"]), "end")


# --- The Hall of Heroes -------------------------------------------------------------------------------------------------------

func test_ten_statues_line_the_hall_and_each_opens_the_same_conversation() -> void:
	var count := 0
	var rows := (_loc(WING)["map"] as Dictionary)["rows"] as Array
	for p: Variant in _loc(WING)["props"]:
		var spec := p as Dictionary
		if not str(spec["id"]).begins_with("court_hero_statue_"):
			continue
		count += 1
		assert_eq(str(spec["dialogue"]), FILE + "statues")
		var c := _cell(spec["cell"])
		assert_true(c.x >= 24 and c.x <= 38 and c.y >= 1 and c.y <= 7, "%s stands in the hall" % spec["id"])
		assert_eq(str(rows[c.y])[c.x], ".")
	assert_eq(count, 10, "ten statues of armoured heroes")


func test_lightning_shows_the_faces_the_first_time_only() -> void:
	var st := _party()
	var first := SideQuestPlay.play(st, FILE + "statues", ["Step back"])
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true(st.get_flag("court_heroes_seen"))
	assert_true(_text(first).contains("mortal terror"), "the flash is the first thing")
	var second := SideQuestPlay.play(st, FILE + "statues", ["Step back"])
	assert_false(_text(second).contains("mortal terror"), "and not again")
	assert_eq(int(st.get_flag("court_heroes_asked")), 0, "stepping back asks nothing")


## The statues answer seven questions, once each, and the third and the seventh answers given are wrong, whichever
## questions they were. A statue can be left at any time.
func test_the_third_and_seventh_answers_are_false_in_whatever_order_they_are_asked() -> void:
	var st := _party()
	var ask: Array[String] = ["Where does the count sleep", "heart in the high tower", "woman in the portrait", "Where is his treasure",
			"old tombs", "castle's guards", "Can he be destroyed"]
	var beats := SideQuestPlay.play(st, FILE + "statues", ask)
	assert_eq(SideQuestPlay.missing(beats), "")
	var all := _text(beats)
	assert_eq(int(st.get_flag("court_heroes_asked")), 7)
	for q in range(1, 8):
		assert_true(st.get_flag("court_heroes_q%d" % q), "question %d was answered" % q)
	assert_true(all.contains("catacombs, at the foot of a black stair"), "question 1 told the truth")
	assert_true(all.contains("takes his wounds for him"), "question 2 told the truth")
	assert_true(all.contains("Queen Ravenovia, our mother"), "the third answer was false (the portrait is Tatyana)")
	assert_false(all.contains("whom his brother coveted"), "so the true one was never given")
	assert_true(all.contains("vault within a vault"), "question 4 told the truth")
	assert_true(all.contains("slain by his own brother's hand"), "question 5 told the truth")
	assert_true(all.contains("butchered them to the last man"), "question 6 told the truth")
	assert_true(all.contains("He has become the land itself"), "the seventh answer was false (a stake or the sun can end him)")
	assert_false(all.contains("Drive wood through his heart"), "so the true one was never given")
	assert_true(all.contains("only wet stone") or all.contains("No breath stirs"), "the hall is quiet once all seven have answered")
	assert_eq(str(beats[-1]["kind"]), "end")
	# Another order: the false answers land on whichever question is asked third and seventh.
	var other := _party()
	var order: Array[String] = ["Can he be destroyed", "Where does the count sleep", "heart in the high tower", "Step back"]
	var beats2 := SideQuestPlay.play(other, FILE + "statues", order)
	assert_eq(SideQuestPlay.missing(beats2), "")
	assert_true(_text(beats2).contains("snare of the dark powers"), "the third asked was the heart, and its answer was false")
	assert_true(_text(beats2).contains("Drive wood through his heart"), "while the first, the destruction, was true")


func test_an_answered_question_is_not_asked_twice() -> void:
	var st := _party()
	st.set_flag("court_heroes_q1")
	var beats := SideQuestPlay.play(st, FILE + "statues", ["Where does the count sleep"])
	assert_true(SideQuestPlay.missing(beats) != "", "the question is gone from the menu once answered")


# --- The servants' upper rooms ------------------------------------------------------------------------------------------------

func test_the_dress_dances_until_touched_or_left() -> void:
	var st := _party()
	var out := SideQuestPlay.play(st, FILE + "wardrobe", ["Open it", "Leave it dancing"])
	assert_eq(SideQuestPlay.missing(out), "")
	assert_false(st.get_flag("court_dress_stilled"), "left dancing, it still dances")
	assert_true(_text(out).contains("waltz"))
	var touched := SideQuestPlay.play(st, FILE + "wardrobe", ["Open it", "Touch the dancing dress"])
	assert_eq(SideQuestPlay.missing(touched), "")
	assert_true(st.get_flag("court_dress_stilled"))
	var after := SideQuestPlay.play(st, FILE + "wardrobe", ["Open it"])
	assert_true(SideQuestPlay.missing(after) != "", "once still, the wardrobe has nothing more to open")


func test_the_ladder_behind_the_mirror_joins_the_attic_to_the_high_towers_stair_both_ways() -> void:
	var down := _entry(WING, "exits", "court_wing_ladder_down")
	var up := _entry(SPIRES, "exits", "spires_servants_ladder")
	var st := _party()
	assert_false(StoryConditions.check(str(down["when"]), st), "the attic's ladder is hidden at first")
	assert_false(StoryConditions.check(str(up["when"]), st), "and so is the tower's")
	assert_true(str(down["locked_text"]) != "" and str(up["locked_text"]) != "", "each says what is there instead")
	var mirror := _entry(WING, "props", "court_servants_mirror")
	assert_eq(str(mirror["kind"]), "search", "the mirror is found by searching")
	var beats := SideQuestPlay.play(st, str(mirror["dialogue"]))
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("court_servants_ladder_found"))
	assert_true(StoryConditions.check(str(down["when"]), st), "found from the attic, it opens at both ends")
	assert_true(StoryConditions.check(str(up["when"]), st))
	assert_eq(str(down["to"]), SPIRES)
	assert_eq(str(up["to"]), WING)


# --- The words --------------------------------------------------------------------------------------------------------------------

func test_every_place_and_thing_has_its_narrator_line() -> void:
	var n := Narrator.new(1)
	var st := _party()
	for key: String in ["enter:court_vermin_passage", "examine:court_vermin_guard", "examine:court_steel_door_relief",
			"enter:court_count_dining", "examine:court_wedding_cake", "examine:court_wedding_lute", "enter:court_capes_closet",
			"enter:court_hall_of_heroes", "enter:court_maids_hall", "examine:court_maids_mirror", "enter:court_servants_upper",
			"enter:castle_ravenloft_parapets"]:
		assert_true(n.line(key, st, null) != "", "the Narrator says something for %s" % key)
	for id: String in ["court_vermin_guard_n", "court_vermin_guard_s"]:
		assert_eq(str(_entry(WING, "props", id)["say"]), "examine:court_vermin_guard", "both guards share one line")
	assert_eq(str((_loc(PARAPETS)["narration"] as Dictionary)["enter"]), "enter:castle_ravenloft_parapets")
