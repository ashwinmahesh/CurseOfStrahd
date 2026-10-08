extends TestCase
## Endings and epilogues (ADR 0014, story/endings.gd): which ending holds for which flags, the slides each shows (own
## before inherited, one per topic), `end_game` in a conversation, the end after a fight, every ending's narration
## playing through without a choice, and the finished save.

const ENDINGS: Array[String] = ["strahd_destroyed", "strahd_triumphant", "ireena_given_up", "ireena_at_peace",
	"new_darklord"]


func before_each() -> void:
	Endings.clear_cache()


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("hedda_ironvow", 3))
	st.party.append(TestChars.pregen("silvain_aster", 3))
	return st


func _topics(slides: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for s in slides:
		out.append(str(s["topic"]))
	return out


func _slide(slides: Array[Dictionary], topic: String) -> Dictionary:
	for s in slides:
		if str(s["topic"]) == topic:
			return s
	return {}


func test_every_ending_is_complete() -> void:
	var all := Endings.all()
	for id in ENDINGS:
		var e := Endings.get_ending(id)
		assert_false(e.is_empty(), "ending %s exists" % id)
		if e.is_empty():
			continue
		var ref := str(e["narration"])
		var f := DialogueFile.load_key(ref.get_slice(":", 0))
		assert_true(f != null and f.nodes.has(ref.get_slice(":", 1)), "%s: narration %s exists" % [id, ref])
		assert_true(f != null and f.errors.is_empty(), "%s: narration parses %s" % [id, f.errors if f != null else []])
		assert_false((e["epilogue"] as Array).is_empty() and str(e.get("epilogue_from", "")) == "", "%s has slides" % id)
		if str(e.get("epilogue_from", "")) != "":
			assert_false(Endings.get_ending(str(e["epilogue_from"])).is_empty(), "%s: epilogue_from exists" % id)
		for s: Variant in e["epilogue"]:
			var art := str((s as Dictionary).get("portrait", ""))
			if art != "" and art != "{name}":
				assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % art), "%s: portrait %s exists" % [id, art])
	for i in all.size() - 1:
		assert_true(int(all[i]["priority"]) >= int(all[i + 1]["priority"]), "highest priority first")


func test_the_ending_follows_the_flags() -> void:
	var st := _party()
	assert_eq(str(Endings.pick(st)["id"]), "strahd_triumphant", "Strahd still stands: he wins")
	st.set_flag("strahd_parley", "yield")
	assert_eq(str(Endings.pick(st)["id"]), "strahd_triumphant", "yielding at the parley")
	st.set_flag("strahd_parley", "ireena")
	assert_eq(str(Endings.pick(st)["id"]), "ireena_given_up", "handing Ireena over")
	st.set_flag("strahd_parley", "fight")
	st.set_flag("strahd_destroyed", true)
	assert_eq(str(Endings.pick(st)["id"]), "strahd_destroyed", "destroyed in his coffin")
	st.set_flag("ireena_pool_choice", "stayed")
	assert_eq(str(Endings.pick(st)["id"]), "strahd_destroyed", "Ireena chose her own life")
	st.set_flag("ireena_pool_choice", "promised")
	assert_eq(str(Endings.pick(st)["id"]), "ireena_at_peace", "Ireena keeps her promise to Sergei")
	st.party[1].accept_dark_gift("gift_of_the_hollow")
	assert_eq(str(Endings.pick(st)["id"]), "new_darklord", "the Second Thirst takes his place")
	assert_eq(Endings.heir(st), st.party[1])


func test_request_records_the_ending_once() -> void:
	var st := _party()
	assert_eq(Endings.reached(st), "")
	st.set_flag("strahd_parley", "ireena")
	assert_true(Endings.parley_ends(st))
	assert_eq(Endings.request(st), "ireena_given_up")
	assert_eq(str(st.get_flag("campaign_ending")), "ireena_given_up")
	st.set_flag("strahd_destroyed", true)
	assert_eq(Endings.request(st), "ireena_given_up", "the ending reached never changes")
	var back := StoryState.from_dict(st.to_dict())
	assert_eq(Endings.reached(back), "ireena_given_up", "saved with the story")
	st.set_flag("strahd_parley", "fight")
	assert_false(Endings.parley_ends(st), "only yield and ireena end the game at the parley")


func test_only_a_final_battle_wipe_or_strahds_destruction_ends_the_game() -> void:
	var st := _party()
	assert_eq(Endings.after_fight(st, {"id": "wolves"}, "defeat"), "", "an ordinary wipe is a game over")
	assert_eq(Endings.after_fight(st, {"id": "harassment", "final_battle": ""}, "victory"), "")
	assert_eq(Endings.reached(st), "")
	var final := {"id": "strahd_waits", "final_battle": "castle_ravenloft_study", "lair": true}
	assert_eq(Endings.after_fight(st, final, "victory"), "", "he turns to mist and flees: the game goes on")
	assert_eq(Endings.after_fight(st, final, "defeat"), "strahd_triumphant", "a wipe in the final battle")
	var st2 := _party()
	st2.set_flag("strahd_destroyed", true)
	assert_eq(Endings.after_fight(st2, {"id": "coffin"}, "victory"), "strahd_destroyed", "the coffin fight won")


func test_slides_follow_each_region_and_inherit_by_topic() -> void:
	var st := _party()
	st.set_flag("strahd_destroyed", true)
	st.set_flag("vallaki_backed", "wachter")
	st.set_flag("order_fate", "ride")
	st.set_flag("abbot_fate", "repentant")
	st.set_flag("wolf_pack_leader", "emil")
	st.set_flag("kasimir_bargain", "made")
	st.set_flag("winery_wine_flows", true)
	st.set_flag("mordenkainen_restored", true)
	var slides := Endings.slides(Endings.get_ending("strahd_destroyed"), st)
	var topics := _topics(slides)
	for t: String in ["land", "party", "ireena", "ismark", "vallaki", "order", "krezk", "pack", "kasimir", "wine",
			"mordenkainen"]:
		assert_true(t in topics, "a %s slide" % t)
	for t: String in ["berez", "bonegrinder", "van_richten", "amber", "ilya"]:
		assert_false(t in topics, "no %s slide without its flags" % t)
	assert_eq(topics.count("vallaki"), 1, "one slide per topic")
	assert_true(str(_slide(slides, "vallaki")["text"]).contains("Wachter"), "Lady Wachter's Vallaki")
	assert_eq(str(_slide(slides, "vallaki")["portrait"]), "lady_wachter")
	assert_true(str(_slide(slides, "order")["text"]).contains("rode with you"), "the Order that rode")
	assert_true(str(_slide(slides, "ireena")["text"]).contains("free"), "the plain Ireena slide without her in the party")
	# The bride: her own Ireena slide replaces the dark one, the rest are inherited from Strahd's triumph.
	var st2 := _party()
	st2.set_flag("strahd_parley", "ireena")
	st2.set_flag("vallaki_backed", "baron")
	var bride := Endings.slides(Endings.get_ending("ireena_given_up"), st2)
	assert_eq(str(bride[0]["topic"]), "ireena", "the ending's own slides come first")
	assert_true(str(bride[0]["text"]).contains("wed"), "the bride's own slide")
	assert_eq(_topics(bride).count("ireena"), 1)
	assert_true(str(_slide(bride, "vallaki")["text"]).contains("festival"), "the Baron's Vallaki in the dark")
	assert_true(str(_slide(bride, "party")["text"]).contains("free to go"), "the price paid")


func test_the_new_lord_and_the_fallen_are_named() -> void:
	var st := _party()
	st.set_flag("strahd_destroyed", true)
	st.party[1].accept_dark_gift("gift_of_the_hollow")
	var lost := TestChars.pregen("tamsin_tealeaf", 3)
	st.party.append(lost)
	st.lose_member(lost, "fell in the castle")
	var slides := Endings.slides(Endings.get_ending("new_darklord"), st)
	var heir := _slide(slides, "heir")
	assert_true(str(heir["text"]).begins_with("Silvain"), "{name} is the heir: %s" % heir.get("text", ""))
	assert_eq(str(heir["portrait"]), DialogueRunner.portrait_of(st.party[1]), "the heir's own portrait")
	assert_true(str(slides.back()["text"]).contains("Tamsin"), "the fallen are remembered last")
	assert_false(_slide(slides, "land").is_empty())
	assert_true(str(_slide(slides, "land")["text"]).contains("new name"), "the heir ending's own land slide")


func test_end_game_in_a_conversation() -> void:
	var f := DialogueFile.parse("~ start\nNarrator: He names his price.\nset strahd_parley = \"yield\"\nend_game\nNarrator: Never shown.\n", "test/end_game")
	assert_true(f.errors.is_empty(), str(f.errors))
	assert_eq(str((f.nodes["start"] as Array)[2]["t"]), "end_game")
	DialogueFile.register(f)
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/end_game:start"))
	assert_eq(str(r.next()["kind"]), "line")
	var b := r.next()
	assert_eq(str(b["kind"]), "end")
	assert_true(bool(b["end_game"]), "the end beat says the campaign ended")
	assert_true(r.ended_game and r.finished)
	assert_eq(Endings.reached(st), "strahd_triumphant", "yielding: Strahd triumphant")


func test_every_narration_plays_through_without_a_choice() -> void:
	var states: Array[StoryState] = []
	for i in 3:
		var st := _party()
		if i >= 1:
			st.add_guest("ireena")
			st.add_guest("ismark")
		if i == 2:
			st.set_flag("strahd_parley", "yield")
		states.append(st)
	for id in ENDINGS:
		for st in states:
			var r := DialogueRunner.new(st, DiceRoller.new(1))
			assert_true(r.start(str(Endings.get_ending(id)["narration"])), id)
			var lines := 0
			for i in 60:
				var b := r.next()
				var kind := str(b["kind"])
				if kind == "end":
					break
				if kind == "cutscene":   # an ending's picture (story/cutscenes.gd), shown between lines
					assert_ne(str(b["id"]), "", id)
					continue
				assert_eq(kind, "line", "%s: narration is lines and pictures only" % id)
				assert_ne(str(b["text"]), "", id)
				assert_false(str(b["text"]).contains("{"), "%s: every placeholder filled" % id)
				lines += 1
			assert_true(r.finished, "%s ends" % id)
			assert_between(lines, 3, 20, "%s: a few lines" % id)


func test_the_finished_save_lists_last_with_its_ending() -> void:
	GameState.reset()
	var st := GameState.story
	st.party.append(TestChars.pregen("hedda_ironvow", 3))
	st.set_flag("strahd_destroyed", true)
	Endings.request(st)
	SaveSystem.current_slot = "unit_test_ongoing"
	assert_eq(SaveSystem.save_round("unit_test_ongoing"), OK)
	SaveSystem.current_slot = "unit_test_finished"
	assert_eq(SaveSystem.save_finished("strahd_destroyed", "Dawn over Barovia"), OK)
	assert_eq(SaveSystem.current_slot, "unit_test_finished")
	var slots := SaveSystem.list_slots()
	var ongoing := -1
	var done := -1
	for i in slots.size():
		if str(slots[i]["slot"]) == "unit_test_ongoing":
			ongoing = i
		elif str(slots[i]["slot"]) == "unit_test_finished":
			done = i
	assert_true(ongoing >= 0 and done > ongoing, "unfinished games list first (Continue loads them)")
	if done >= 0:
		assert_eq(str(slots[done]["finished"]), "Dawn over Barovia")
		assert_true(str(slots[done]["location"]).contains("Dawn over Barovia"), "the menu shows the ending")
	GameState.reset()
	assert_eq(SaveSystem.load_slot("unit_test_finished"), OK)
	assert_eq(Endings.reached(GameState.story), "strahd_destroyed", "the loaded game knows it is over")
	SaveSystem.delete_slot("unit_test_ongoing")
	SaveSystem.delete_slot("unit_test_finished")
	SaveSystem.current_slot = ""
	GameState.reset()
