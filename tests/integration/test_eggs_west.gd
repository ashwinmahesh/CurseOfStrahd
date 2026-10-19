extends TestCase
## Package R4 of the small-winks plan (docs/plans/gemini_eggs/r4/): four things to find at Old Bonegrinder, the Wizard of
## Wines and Krezk. Each hides where the player has to look (a book's back pages, a hidden find, a notice, a cheese to
## lift), each is walked with the roll failed and then passed, none moves a main story flag, and every conversation
## they touch still has its way out.

const PARTY: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]

var root: Node
var said: Array[String] = []


func before_each() -> void:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "old_bonegrinder_hill"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	get_tree().paused = false
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _enter(loc_id: String) -> LocationView:
	root.call("enter_location", loc_id, "")
	await _frames(2)
	said.clear()
	var v := _view()
	v.narration.connect(func(text: String) -> void: said.append(text))
	v.toast.connect(func(text: String) -> void: said.append(text))
	return v


func _spec(loc_id: String, list: String, id: String) -> Dictionary:
	for t: Variant in Compendium.shared().get_entry("locations", loc_id).get(list, []):
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


func _cell(spec: Dictionary) -> Vector2i:
	return LocationView._cell(spec["cell"])


func _action(cell: Vector2i, id: String) -> Dictionary:
	for a: Variant in _view().actions_at(cell)["actions"]:
		if str((a as Dictionary)["id"]) == id:
			return a as Dictionary
	return {}


func _said(part: String) -> bool:
	return said.any(func(s: String) -> bool: return s.contains(part))


func test_the_receipt_books_back_pages_hold_a_letter_from_an_aunt() -> void:
	var v := await _enter("old_bonegrinder")
	var spec := _spec("old_bonegrinder", "props", "bonegrinder_receipt_book")
	var cell := _cell(spec)
	assert_false(v.thing_at(cell).is_empty(), "the book is on the board")
	assert_true(_action(cell, "check:receipt_back_pages").is_empty(), "the back pages wait until the front has been read")
	GameState.story.set_flag("bonegrinder_recipe_read")
	var line := _action(cell, "check:receipt_back_pages")
	assert_false(line.is_empty(), "then they are on its menu: %s" % [v.actions_at(cell)["actions"]])
	assert_true(str(line["label"]).begins_with("Read the back pages (Investigation DC 12"), str(line["label"]))
	var check := WorldChecks.find(spec, "receipt_back_pages")
	var who := v.leader().creature as Character
	# Every roll failed: the pages stay stuck, nothing is learned, and the way on is still there.
	WorldChecks.record(GameState.story, "old_bonegrinder", check, who, false)
	LocationChecks._resolve(v, spec, check, who, false)
	assert_false("aunt_by_the_river" in GameState.story.codex, "a failed look finds nothing")
	assert_true(_said("glued together"), "the Narrator has a line for it: %s" % [said])
	assert_false(_said("It doesn't give"), "and it is not the plain fallback")
	assert_false(WorldChecks.done(GameState.story, "old_bonegrinder", check), "someone else may still try")
	# Passed: the letter goes in the codex.
	var next := WorldChecks.roller(GameState.story, "old_bonegrinder", check)
	assert_true(next != null and next != who, "the next best hand takes the next try")
	WorldChecks.record(GameState.story, "old_bonegrinder", check, next, true)
	LocationChecks._resolve(v, spec, check, next, true)
	assert_true(_said("folded letter"), str(said))
	assert_true("aunt_by_the_river" in GameState.story.codex)
	var entry := JournalScreen._codex_entry("aunt_by_the_river")
	assert_eq(str(entry["title"]), "A letter from the river")
	assert_true(WorldChecks.done(GameState.story, "old_bonegrinder", check), "a success is done")
	assert_true(str(entry["text"]).contains("stayed for good") and str(entry["text"]).ends_with("Your loving aunt, by the river"),
		"the letter is in the aunt's words, signed")


func test_the_sail_lashings_hide_a_pair_of_spectacles_for_a_close_look() -> void:
	var v := await _enter("old_bonegrinder_hill")
	var spec := _spec("old_bonegrinder_hill", "props", "sail_lashings")
	assert_eq(str(spec["kind"]), "search", "a hidden find")
	assert_eq(str(spec["item"]), "tiny_brass_spectacles")
	var item := Compendium.shared().item_data("tiny_brass_spectacles")
	assert_false(item.is_empty(), "the trinket exists")
	assert_eq(str(item["category"]), "gear")
	assert_eq(float(item["cost_gp"]), 15.0)
	assert_true(Compendium.playable(item))
	var cell := _cell(spec)
	assert_true(v.thing_at(cell).is_empty(), "it is not on the board until someone looks")
	# Searching from beside the sails (the roll made easy for the test) finds it, and using it takes the trinket.
	LocationChecks._move_party(v, cell + Vector2i(-1, 0))
	var original_dc := int(spec["search_dc"])
	var live := _spec_in_view(v, "sail_lashings")
	live["search_dc"] = 1
	said.clear()
	v.search()
	live["search_dc"] = original_dc
	assert_true(bool(GameState.story.loc_state("old_bonegrinder_hill")["found"].get("sail_lashings", false)), "a search near the sails finds it")
	assert_false(v.thing_at(cell).is_empty(), "and it is on the board")
	v.interact(v.thing_at(cell))
	assert_true(GameState.story.party.any(func(ch: Character) -> bool: return ch.carries("tiny_brass_spectacles")), "the spectacles are taken")
	assert_true(_said("spectacles"), "the Narrator says what they are: %s" % [said])


func _spec_in_view(v: LocationView, id: String) -> Dictionary:
	for t: Variant in v.loc.get("props", []):
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


func test_the_finder_s_kind_shapes_the_line_about_the_spectacles() -> void:
	var narrator := Narrator.new(3)
	var st := GameState.story
	var tamsin := st.party[1]
	assert_true(narrator.line("search:sail_lashings", st, tamsin).contains("halfling"), "a halfling finds a halfling's frames")
	var ilse := st.party[0]
	assert_false(narrator.line("search:sail_lashings", st, ilse).contains("halfling"), "someone else gets the plain line")
	assert_true(narrator.has_trigger("search:sail_lashings"))


func test_the_notice_in_the_press_house_is_davians() -> void:
	var v := await _enter("wizard_of_wines_press_house")
	var spec := _spec("wizard_of_wines_press_house", "props", "press_notice")
	assert_eq(str(spec["kind"]), "book")
	assert_eq(str(spec["model"]), "sign")
	var text := str(spec["text"])
	assert_true(text.contains("LAMP-OIL BARRELS") and text.contains("blights") and text.contains("terms"), text)
	assert_between(float(text.split(" ").size()), 25.0, 70.0, "a notice, not a speech")
	assert_false(v.thing_at(_cell(spec)).is_empty(), "it hangs where the party can read it")


func test_lifting_a_cheese_at_krezk_shows_a_stair_a_purse_and_a_glove() -> void:
	var v := await _enter("krezk")
	var spec := _spec("krezk", "props", "goat_cheeses")
	var cell := _cell(spec)
	var line := _action(cell, "check:lift_a_cheese")
	assert_false(line.is_empty(), "the cheeses offer a lift: %s" % [v.actions_at(cell)["actions"]])
	assert_true(str(line["label"]).begins_with("Lift one (Athletics DC 8"), str(line["label"]))
	var glove := _spec("krezk", "props", "cheese_stair_glove")
	assert_true(v.thing_at(_cell(glove)).is_empty(), "the glove is not on the board yet")
	var check := WorldChecks.find(spec, "lift_a_cheese")
	var who := v.leader().creature as Character
	var gold := GameState.story.gold
	# Failed: the wheel doesn't move, and nothing changes.
	WorldChecks.record(GameState.story, "krezk", check, who, false)
	LocationChecks._resolve(v, spec, check, who, false)
	assert_true(_said("millstone"), "the Narrator has a line for the failure: %s" % [said])
	assert_eq(GameState.story.gold, gold)
	assert_false(bool(GameState.story.get_flag("eggs_cheese_stair_found", false)))
	assert_true(v.thing_at(_cell(glove)).is_empty())
	# Passed: a stair, 30 gold, the glove shown and the flag the watchman reads.
	said.clear()
	var next := WorldChecks.roller(GameState.story, "krezk", check)
	assert_true(next != null and next != who, "someone else lifts next")
	WorldChecks.record(GameState.story, "krezk", check, next, true)
	LocationChecks._resolve(v, spec, check, next, true)
	assert_true(_said("stair up the house wall"), str(said))
	assert_eq(GameState.story.gold, gold + 30.0, "a purse under the lowest step")
	assert_true(bool(GameState.story.get_flag("eggs_cheese_stair_found", false)))
	assert_false(v.thing_at(_cell(glove)).is_empty(), "the glove shows")
	assert_false(GameState.story.party.any(func(ch: Character) -> bool: return ch.carries("potion_of_climbing")), "the vial is still in it")
	said.clear()
	v.interact(v.thing_at(_cell(glove)))
	assert_true(GameState.story.party.any(func(ch: Character) -> bool: return ch.carries("potion_of_climbing")), "using the glove hands the vial over")
	assert_true(_said("The cheese, to its credit, holds."), str(said))
	assert_true(_action(cell, "check:lift_a_cheese").is_empty(), "a success is done")


func test_lazar_says_no_to_the_cheese_only_once_the_stair_is_found() -> void:
	var st := SideQuestPlay.party(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"], 6, "krezk", 10)
	var plain := SideQuestPlay.play(st, "krezk/townsfolk:wall_watch")
	assert_eq(SideQuestPlay.missing(plain), "")
	assert_false(SideQuestPlay.text(plain).contains("cheese"), "he says nothing of it before the stair is found")
	assert_eq(str(plain[-1]["kind"]), "end", "and the talk ends")
	st.set_flag("eggs_cheese_stair_found")
	var told := SideQuestPlay.play(st, "krezk/townsfolk:wall_watch")
	assert_eq(SideQuestPlay.missing(told), "")
	assert_true(SideQuestPlay.text(told).contains("nobody climbs the cheese"), SideQuestPlay.text(told))
	assert_eq(str(told[-1]["kind"]), "end", "the way out is there with the flag set too")


func test_sprig_is_proud_of_its_first_pat_and_the_menu_always_ends() -> void:
	var st := SideQuestPlay.party(PARTY, 6, "wizard_of_wines", 10)
	assert_false(st.get_flag("eggs_dog_sprig", false))
	var first := SideQuestPlay.play(st, "wizard_of_wines/sprig:start", ["Pat it", "Leave it"])
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true(SideQuestPlay.text(first).contains("lone leaf standing bolt upright"), SideQuestPlay.text(first))
	assert_true(st.get_flag("eggs_dog_sprig", false), "it counts as a good dog")
	assert_eq(str(first[-1]["kind"]), "end", "and the talk ends")
	var again := SideQuestPlay.play(st, "wizard_of_wines/sprig:start", ["Pat it", "Leave it"])
	assert_eq(SideQuestPlay.missing(again), "")
	var text := SideQuestPlay.text(again)
	assert_false(text.contains("bolt upright"), "the proud line is the first pat's alone")
	assert_true(text.contains("trembles from root to thorn"), "a later pat is the old one")
	assert_eq(str(again[-1]["kind"]), "end")


func test_new_squares_keep_two_from_every_fight_start() -> void:
	var placed := {
		"old_bonegrinder_hill": ["sail_lashings"],
		"wizard_of_wines_press_house": ["press_notice"],
		"krezk": ["cheese_stair_glove"],
	}
	for loc_id: String in placed:
		var loc := Compendium.shared().get_entry("locations", loc_id)
		var starts: Array[Vector2i] = []
		for e: Variant in loc.get("encounters", []):
			for m: Variant in (e as Dictionary).get("monsters", []):
				if (m as Dictionary).has("cell"):
					starts.append(LocationView._cell((m as Dictionary)["cell"]))
		for id: String in placed[loc_id]:
			var c := _cell(_spec(loc_id, "props", id))
			for s in starts:
				assert_true(maxi(absi(c.x - s.x), absi(c.y - s.y)) >= 2, "%s %s at %s is within 2 of a fight start at %s" % [loc_id, id, c, s])


func test_the_winks_set_only_side_flags() -> void:
	# The cheese stair's flag is a world-check flag and Sprig's mark is the package's own: neither is a story flag.
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/world_checks.json"))
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_west.json"))
	var world_ids: Array = (world["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	var own_ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	assert_true("eggs_cheese_stair_found" in world_ids, "a check's flag is registered with the world checks")
	assert_true("eggs_dog_sprig" in own_ids, "a conversation's flag is in the package's own file")
	assert_eq(own_ids.size(), 1, "and that is all the package sets")
