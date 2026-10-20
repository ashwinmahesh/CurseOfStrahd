extends TestCase
## Package R1 of the small-winks plan (docs/story/eggs.md, docs/plans/gemini_eggs/r1/): the Village of Barovia and the
## road in. The Vistani sisters' tale of the man who fell from the sky, a pat for Lupu, and the first of a dead pedlar's
## three buried tins, dug up with a shovel in the Charcoal-Burners' Hollow. Each waits where the player has to look,
## none moves a main story flag, and every conversation they touch keeps its way out.

const PARTY: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]

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
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = loc_id
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


func _action(v: LocationView, cell: Vector2i, id: String) -> Dictionary:
	for a: Variant in v.actions_at(cell)["actions"]:
		if str((a as Dictionary)["id"]) == id:
			return a as Dictionary
	return {}


func _said(part: String) -> bool:
	return said.any(func(s: String) -> bool: return s.contains(part))


func test_the_sisters_tell_of_the_man_who_fell_from_the_sky_once_they_have_met_you() -> void:
	var st := SideQuestPlay.party(PARTY, 3, "blood_of_the_vine", 20)
	var early := SideQuestPlay.play(st, "village_of_barovia/vistani:start", ["Seen any other strangers"])
	assert_ne(SideQuestPlay.missing(early), "", "the question waits until they have said who they are")
	var told := SideQuestPlay.play(st, "village_of_barovia/vistani:start", ["Who are you", "Seen any other strangers"])
	assert_eq(SideQuestPlay.missing(told), "")
	var text := SideQuestPlay.text(told)
	assert_true(text.contains("shaped like a great squid") and text.contains("through his eye") and text.contains("stye"), text)
	assert_true(st.get_flag("eggs_sky_man_heard", false), "part one of the sky-man's three is heard")
	assert_eq(str(told[-1]["kind"]), "end", "and the talk still ends")
	var again := SideQuestPlay.play(st, "village_of_barovia/vistani:start", ["Seen any other strangers"])
	assert_ne(SideQuestPlay.missing(again), "", "they tell it once")


func test_lupu_leans_on_your_leg_by_day_by_night_and_when_it_is_over() -> void:
	var day := SideQuestPlay.party(PARTY, 3, "village_of_barovia", 11)
	var by_day := SideQuestPlay.play(day, "village_of_barovia/the_burgomasters_hound:lupu", ["Pet him"])
	assert_eq(SideQuestPlay.missing(by_day), "")
	assert_true(SideQuestPlay.text(by_day).contains("warm as a hearthstone"), SideQuestPlay.text(by_day))
	assert_true(day.get_flag("eggs_dog_lupu", false), "Lupu counts as a good dog")
	assert_eq(str(by_day[-1]["kind"]), "end")
	var twice := SideQuestPlay.play(day, "village_of_barovia/the_burgomasters_hound:lupu", ["Pet him"])
	assert_ne(SideQuestPlay.missing(twice), "", "one pat is the wink; the menu doesn't keep offering it")

	var night := SideQuestPlay.party(PARTY, 3, "village_of_barovia", 23)
	var by_night := SideQuestPlay.play(night, "village_of_barovia/the_burgomasters_hound:lupu", ["Pet him"])
	assert_eq(SideQuestPlay.missing(by_night), "")
	assert_true(SideQuestPlay.text(by_night).contains("the howl catches in his throat"), SideQuestPlay.text(by_night))

	var after := SideQuestPlay.party(PARTY, 3, "village_of_barovia", 11)
	after.set_quest_stage("the_burgomasters_hound", "rumored")
	after.set_quest_stage("the_burgomasters_hound", "done")
	var at_rest := SideQuestPlay.play(after, "village_of_barovia/the_burgomasters_hound:lupu", ["Pet him"])
	assert_eq(SideQuestPlay.missing(at_rest), "")
	assert_true(SideQuestPlay.text(at_rest).contains("goes back to sleep"), SideQuestPlay.text(at_rest))
	assert_eq(str(at_rest[-1]["kind"]), "end")
	var asleep := SideQuestPlay.play(after, "village_of_barovia/the_burgomasters_hound:lupu")
	assert_eq(str(asleep[-1]["kind"]), "end", "with nothing picked, the sleeping dog's menu still lets you go")


func test_the_stamped_earth_needs_a_shovel_and_holds_the_pedlars_first_tin() -> void:
	var v := await _boot("woodcutters_hollow")
	var spec := _spec("woodcutters_hollow", "hollow_stamped_earth")
	var cell := LocationView._cell(spec["cell"])
	assert_false(v.thing_at(cell).is_empty(), "the stamped earth is on the board")
	assert_true(_action(v, cell, "check:hollow_dig").is_empty(), "no shovel, no digging")
	var digger := v.leader().creature as Character
	digger.add_item("shovel")
	var line := _action(v, cell, "check:hollow_dig")
	assert_false(line.is_empty(), "with a shovel in the party it can be dug: %s" % [v.actions_at(cell)["actions"]])
	assert_true(str(line["label"]).begins_with("Dig here (Athletics DC 8"), str(line["label"]))
	var check := WorldChecks.find(spec, "hollow_dig")
	var gold := GameState.story.gold
	# Failed: roots and needles; nothing found, and another hand may still try.
	WorldChecks.record(GameState.story, "woodcutters_hollow", check, digger, false)
	LocationChecks._resolve(v, spec, check, digger, false)
	assert_true(_said("knotted root"), "the Narrator has a line for it: %s" % [said])
	assert_eq(GameState.story.gold, gold)
	assert_false("pedlar_note_hollow" in GameState.story.codex)
	assert_false(WorldChecks.done(GameState.story, "woodcutters_hollow", check))
	# Passed: the tin, its coins and the note pointing on to the lake.
	said.clear()
	var next := WorldChecks.roller(GameState.story, "woodcutters_hollow", check)
	assert_true(next != null and next != digger, "the next best hand digs next")
	WorldChecks.record(GameState.story, "woodcutters_hollow", check, next, true)
	LocationChecks._resolve(v, spec, check, next, true)
	assert_true(_said("rusted tin box"), str(said))
	assert_eq(GameState.story.gold, gold + 15.0)
	assert_true(bool(GameState.story.get_flag("eggs_spade_first", false)))
	assert_true("pedlar_note_hollow" in GameState.story.codex)
	var entry := JournalScreen._codex_entry("pedlar_note_hollow")
	assert_eq(str(entry["title"]), "A pedlar's note, buried")
	assert_true(str(entry["text"]).contains("where the reeds hide the lake from the road"), "it points on to the next hole")
	assert_true(str(entry["text"]).ends_with("A man who trusts his spade"), "signed, and never named")
	assert_true(WorldChecks.done(GameState.story, "woodcutters_hollow", check), "a success is done")
	var narrator := Narrator.new(3)
	assert_true(narrator.line("examine:hollow_stamped_earth", GameState.story, next).contains("the hole you dug"),
		"once dug, the earth says so")


func test_bildrath_sells_the_shovel_the_hole_wants() -> void:
	var sells := Compendium.shared().get_entry("npcs", "bildrath")["shop"]["sells"] as Array
	assert_true(sells.any(func(s: Variant) -> bool: return str((s as Dictionary)["id"]) == "shovel"),
		"a shovel is for sale in the same village")


func test_the_dig_keeps_two_from_every_fight_start() -> void:
	var loc := Compendium.shared().get_entry("locations", "woodcutters_hollow")
	var c := LocationView._cell(_spec("woodcutters_hollow", "hollow_stamped_earth")["cell"])
	for e: Variant in loc.get("encounters", []):
		for m: Variant in (e as Dictionary).get("monsters", []):
			if (m as Dictionary).has("cell"):
				var s := LocationView._cell((m as Dictionary)["cell"])
				assert_true(maxi(absi(c.x - s.x), absi(c.y - s.y)) >= 2, "the dig at %s is within 2 of a fight start at %s" % [c, s])


func test_the_winks_set_only_side_flags() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/world_checks.json"))
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_village.json"))
	var world_ids: Array = (world["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	var own_ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	assert_true("eggs_spade_first" in world_ids, "the dig's flag is registered with the world checks")
	assert_eq(own_ids, ["eggs_sky_man_heard", "eggs_dog_lupu"], "the conversations' flags are the package's own, and that is all")
