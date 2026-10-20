extends TestCase
## Package R3 of the small-winks plan (docs/story/eggs.md, docs/plans/gemini_eggs/r3/): Vallaki. A puppet with no
## reflection on Blinsky's top shelf (and Emanoil, who wants it), the Baron's decree against shoving, two good dogs, a
## letter under the straps of Rictavio's sea chest, a chalk game on a notice board and a black tract at Wachterhaus.
## Each waits where the player has to look, none moves a main story flag, and every conversation they touch keeps its
## way out.

const PARTY: Array[String] = ["godrick_pendlebrook", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]
const V := "vallaki/"

var root: Node
var said: Array[String] = []


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	get_tree().paused = false
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(loc_id: String) -> LocationView:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = loc_id
	GameState.story.minute_of_day = 11 * 60
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	said.clear()
	var v := root.get("view") as LocationView
	v.narration.connect(func(text: String) -> void: said.append(text))
	v.toast.connect(func(text: String) -> void: said.append(text))
	return v


func _spec(loc_id: String, id: String) -> Dictionary:
	for t: Variant in Compendium.shared().get_entry("locations", loc_id).get("props", []):
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


func _said(part: String) -> bool:
	return said.any(func(s: String) -> bool: return s.contains(part))


func _st() -> StoryState:
	return SideQuestPlay.party(PARTY, 5, "vallaki", 11)


func _try(v: LocationView, loc_id: String, spec: Dictionary, check_id: String) -> void:
	var check := WorldChecks.find(spec, check_id)
	var who := v.leader().creature as Character
	WorldChecks.record(GameState.story, loc_id, check, who, false)
	LocationChecks._resolve(v, spec, check, who, false)
	var next := WorldChecks.roller(GameState.story, loc_id, check)
	assert_true(next != null and next != who, "another hand may still try")
	WorldChecks.record(GameState.story, loc_id, check, next, true)
	LocationChecks._resolve(v, spec, check, next, true)
	assert_true(WorldChecks.done(GameState.story, loc_id, check), "a success is done")


func test_the_top_shelf_holds_a_puppet_that_blinsky_then_sells() -> void:
	var v := await _boot("vallaki_blinsky_toys")
	var spec := _spec("vallaki_blinsky_toys", "toy_shelves")
	var sells := Compendium.shared().get_entry("npcs", "blinsky")["shop"]["sells"] as Array
	var line: Dictionary = {}
	for s: Variant in sells:
		if str((s as Dictionary)["id"]) == "vanity_puppet":
			line = s as Dictionary
	assert_eq(str(line.get("if", "")), "flag.eggs_puppet_seen", "on sale only once it has been seen")
	assert_false(StoryConditions.check(str(line["if"]), GameState.story))
	_try(v, "vallaki_blinsky_toys", spec, "top_shelf_look")
	assert_true(_said("tin drum with no sticks"), "the failure has its line: %s" % [said])
	assert_true(_said("thumb-sized looking glass"), "and the success: %s" % [said])
	assert_true(StoryConditions.check(str(line["if"]), GameState.story), "now Blinsky sells it")
	var item := Compendium.shared().item_data("vanity_puppet")
	assert_eq(str(item["category"]), "gear")
	assert_eq(float(item["cost_gp"]), 6.0)
	assert_true(Compendium.playable(item))
	var narrator := Narrator.new(3)
	assert_true(narrator.line("examine:toy_shelves", GameState.story, v.leader().creature as Character).contains("the pale puppet still preens"),
		"the shelves remember him while he's still for sale")


func test_emanoil_buys_the_puppet_twice_over_and_makes_a_couplet() -> void:
	var st := _st()
	var early := SideQuestPlay.play(st, V + "emanoil:start", ["Show him the pale puppet"])
	assert_ne(SideQuestPlay.missing(early), "", "nothing to show him without the puppet")
	st.party[0].add_item("vanity_puppet")
	var gold := st.gold
	var beats := SideQuestPlay.play(st, V + "emanoil:start", ["Show him the pale puppet"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("The glass keeps its secrets"), SideQuestPlay.text(beats))
	assert_eq(roundi(st.gold), roundi(gold) + 12, "twice what Blinsky asked")
	assert_false(st.party_has_item("vanity_puppet"), "he keeps it")
	assert_eq(str(beats[-1]["kind"]), "end")


func test_after_his_quest_emanoil_still_wants_the_puppet_and_the_scene_still_ends() -> void:
	var st := _st()
	st.set_flag("emanoil_met")
	st.set_quest_stage("emanoil_wants_to_be_bitten", "met")
	st.set_quest_stage("emanoil_wants_to_be_bitten", "done")
	var plain := SideQuestPlay.play(st, V + "emanoil:start")
	assert_true(SideQuestPlay.text(plain).contains("an ode to your company"))
	assert_false(plain.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"), "no menu without the puppet, as before")
	st.party[1].add_item("vanity_puppet")
	var beats := SideQuestPlay.play(st, V + "emanoil:start", ["Show him the pale puppet"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("carved out of pine"))
	assert_eq(str(beats[-1]["kind"]), "end")


func test_the_barons_fifth_decree_forbids_shoving_and_the_clocks_still_come_last() -> void:
	var st := _st()
	var texts: Array[String] = []
	for i in 7:
		texts.append(SideQuestPlay.text(SideQuestPlay.play(st, V + "baron:decree")))
	assert_true(texts[0].contains("wipe their eyes"), "the first decree is as before")
	assert_true(texts[4].contains("shove a neighbour off a roof"), texts[4])
	assert_true(texts[5].contains("'festive'") and texts[6].contains("'festive'"), "then the clocks, with feeling, for good")


func test_two_more_good_dogs_and_their_menus_still_let_you_go() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook", "ratatoille"], 5, "vallaki", 11)
	for spec: Array in [[V + "townsfolk:dog", "eggs_dog_vallaki", "only honest sound in the square"],
			[V + "camp_folk:dog", "eggs_dog_camp", "ladle resting on the rim"]]:
		var leave := SideQuestPlay.play(st, str(spec[0]))
		assert_eq(str(leave[-1]["kind"]), "end", "%s: leaving is always there" % spec[0])
		var pet := SideQuestPlay.play(st, str(spec[0]), ["Pet the dog"])
		assert_eq(SideQuestPlay.missing(pet), "")
		assert_true(SideQuestPlay.text(pet).contains(str(spec[2])), SideQuestPlay.text(pet))
		assert_true(st.get_flag(str(spec[1]), false))
		var after := SideQuestPlay.play(st, str(spec[0]))
		assert_false(after.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"),
			"%s: petted, and without the spell, it is only a dog again" % spec[0])


func test_a_letter_under_the_sea_chests_straps_calls_its_reader_child_and_never_names_him() -> void:
	var v := await _boot("vallaki_blue_water_inn")
	var spec := _spec("vallaki_blue_water_inn", "rictavio_trunk_marks")
	_try(v, "vallaki_blue_water_inn", spec, "trunk_strap_papers")
	assert_true(_said("knotted the buckles"), "the failure has its line: %s" % [said])
	assert_true(_said("soft as cloth"), str(said))
	assert_true("letter_under_the_straps" in GameState.story.codex)
	var text := str(JournalScreen._codex_entry("letter_under_the_straps")["text"])
	assert_true(text.begins_with("Child,") and text.ends_with("[a little harp and a crescent moon]"), text)
	for name: String in ["Rudolph", "Richten", "Rictavio", "hunter"]:
		assert_false(text.contains(name), "the letter keeps his secret: %s" % name)


func test_a_notice_board_off_the_square_carries_the_childrens_chalk_game() -> void:
	var spec := _spec("vallaki", "square_chalk_board")
	assert_eq(str(spec["kind"]), "examine")
	assert_eq(str(spec["model"]), "notice_board")
	var st := _st()
	var line := Narrator.new(3).line("examine:square_chalk_board", st, st.party[0])
	assert_true(line.contains("masked swordsman") and line.contains("lady in red"), line)


func test_a_black_tract_waits_on_the_book_clubs_chairs() -> void:
	var spec := _spec("vallaki_wachter_house", "black_tract")
	assert_eq(str(spec["kind"]), "book")
	var text := str(spec["text"])
	assert_true(text.contains("dark sister") and text.contains("flowers that open only at night"), text)


func test_new_props_keep_two_from_every_fight_start() -> void:
	for pair: Array in [["vallaki", "square_chalk_board"], ["vallaki_wachter_house", "black_tract"]]:
		var loc := Compendium.shared().get_entry("locations", str(pair[0]))
		var c := LocationView._cell(_spec(str(pair[0]), str(pair[1]))["cell"])
		for e: Variant in loc.get("encounters", []):
			for m: Variant in (e as Dictionary).get("monsters", []):
				if (m as Dictionary).has("cell"):
					var s := LocationView._cell((m as Dictionary)["cell"])
					assert_true(maxi(absi(c.x - s.x), absi(c.y - s.y)) >= 2, "%s at %s is within 2 of a fight start at %s" % [pair, c, s])


func test_the_winks_set_only_side_flags() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/world_checks.json"))
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_vallaki.json"))
	var world_ids: Array = (world["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	var own_ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	assert_true("eggs_puppet_seen" in world_ids, "the shelf's flag is registered with the world checks")
	assert_eq(own_ids, ["eggs_puppet_given", "eggs_dog_vallaki", "eggs_dog_camp"])
