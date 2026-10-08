extends TestCase
## Vallaki's batch 2 side quests (docs/story/side_quests.md): Ribbons (Daciana's lists, Dobre selling them three
## times, the stake-out, the endings) and The Hunters at the Inn (Szoldar's offer, Yevgeni's warning, the hunt for Old
## Greytooth at the lake, and the bounty paid once).

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func _vallaki(level: int = 5, hour: int = 11) -> StoryState:
	var st := SideQuestPlay.party(SIX, level, "vallaki", hour)
	st.set_flag("vallaki_arrived")
	return st


# --- Ribbons ---

func test_daciana_the_lamp_and_dobre_followed_to_the_gate() -> void:
	var st := _vallaki()
	var beats := SideQuestPlay.play(st, "vallaki/townsfolk:ribbon_girl", ["No, thank you"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("ribbons"), "rumored")
	beats = SideQuestPlay.play(st, "vallaki/townsfolk:ribbon_girl", ["Who wants to know", "We'll see who comes for it"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("ribbons"), "asked")
	assert_true(SideQuestPlay.shown(st, "vallaki", "ribbon_lamp"))
	# Following Dobre is a Stealth roll; try a few dice for each way it can go.
	var followed := false
	for seed: int in [1, 2, 3, 5, 8, 13]:
		# Thistle leads (the speaker rolls the Stealth); Godrick's plate would give it Disadvantage.
		var copy := SideQuestPlay.party(["thistle", "wren_featherfoot", "liriel_dawnsong", "ratatoille"], 5, "vallaki", 11)
		copy.flags = st.flags.duplicate(true)
		copy.quests = st.quests.duplicate(true)
		beats = SideQuestPlay.play(copy, "vallaki/ribbons:lamp", ["Wait for whoever comes", "Follow him", "Step out now"], seed)
		if SideQuestPlay.combat_of(beats) == "ribbons_gate":
			followed = true
			assert_true(SideQuestPlay.text(beats).contains("Wachterhaus"), "the three hand-offs are seen")
			assert_eq(copy.quest_stage("ribbons"), "sold_three_times")
			assert_true(copy.is_night())
			break
	assert_true(followed, "some roll follows him to the gate")


func test_confronting_dobre_and_the_endings() -> void:
	var st := _vallaki()
	st.set_flag("ribbons_list_known")
	st.set_quest_stage("ribbons", "asked")
	var beats := SideQuestPlay.play(st, "vallaki/ribbons:lamp", ["Wait for whoever comes", "A word about that paper", "Draw steel"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "ribbons_street")
	var enc := SideQuestPlay.encounter(st, "vallaki", "ribbons_street")
	assert_true(SideQuestPlay.has_foe(enc, "Watchman Dobre"))
	assert_true(SideQuestPlay.xp(enc) >= 2800, "four veterans at level 5")
	st.set_flag("dobre_beaten")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_patrol"), "", "Dobre's off his beat")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_ribbon_girl"), "vallaki/ribbons:after")
	st.gold = 0
	beats = SideQuestPlay.play(st, "vallaki/ribbons:after", ["Give the lists to Father Lucian"])
	assert_true(SideQuestPlay.text(beats).contains("little black horse"), "the satchel shows the three buyers")
	assert_eq(st.quest_stage("ribbons"), "done")
	assert_eq(str(st.get_flag("ribbons_ending", "")), "town")
	assert_eq(roundi(st.gold), 250)
	assert_true(st.party_has_item("arcane_grimoire_plus_2"))
	SideQuestPlay.play(st, "vallaki/ribbons:after")
	assert_eq(roundi(st.gold), 250, "the satchel is emptied once")
	beats = SideQuestPlay.play(st, "vallaki/townsfolk:ribbon_girl")
	assert_true(SideQuestPlay.text(beats).contains("bread"))


# --- The Hunters at the Inn ---

func test_yevgenis_warning_turns_szoldar_and_the_wolf_is_hunted() -> void:
	var st := _vallaki(6, 20)
	st.location = "vallaki_blue_water_inn"
	var beats := SideQuestPlay.play(st, "vallaki/martikovs:urwin", ["Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("hunters_at_the_inn"), "rumored")
	beats = SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:szoldar", ["We're in"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("hunters_at_the_inn"), "asked")
	st.gold = 10
	beats = SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:yevgeni", ["Buy him a drink"])
	assert_true(bool(st.get_flag("hunt_trap_known", false)))
	assert_true(SideQuestPlay.text(beats).contains("Arrigal"))
	assert_eq(st.quest_stage("hunters_at_the_inn"), "the_trap")
	# Szoldar, confronted: Intimidation turns him; a failure leaves him at the inn. Either way he isn't on the rise.
	beats = SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:szoldar", ["We know who pays you", "You've got one now"])
	assert_true(bool(st.get_flag("szoldar_turned", false)) or bool(st.get_flag("szoldar_stays", false)))
	st.location = "lake_zarovich"
	st.minute_of_day = 15 * 60
	beats = SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:shore", ["Wait here for the wolf"])
	assert_eq(SideQuestPlay.combat_of(beats), "greytooth_hunt")
	var enc := SideQuestPlay.encounter(st, "lake_zarovich", "greytooth_hunt")
	assert_true(SideQuestPlay.has_foe(enc, "old_greytooth"))
	assert_false(SideQuestPlay.has_foe(enc, "Szoldar"), "not shooting at you")
	assert_true(SideQuestPlay.xp(enc) >= 4800, "Greytooth and his pack: %d" % SideQuestPlay.xp(enc))
	st.set_flag("greytooth_beaten")
	st.set_quest_stage("hunters_at_the_inn", "hunted")
	st.gold = 0
	beats = SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:yevgeni")
	assert_eq(st.quest_stage("hunters_at_the_inn"), "done")
	assert_eq(roundi(st.gold), 300)
	assert_true(st.party_has_item("horn_of_valhalla_silver"))
	SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:yevgeni")
	assert_eq(roundi(st.gold), 300, "paid once")


func test_without_the_warning_szoldar_shoots_from_the_rise() -> void:
	var st := _vallaki(7, 15)
	st.location = "lake_zarovich"
	st.set_quest_stage("hunters_at_the_inn", "asked")
	var beats := SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:shore", ["Wait here for the wolf"])
	assert_eq(SideQuestPlay.combat_of(beats), "greytooth_hunt")
	var enc := SideQuestPlay.encounter(st, "lake_zarovich", "greytooth_hunt")
	assert_true(SideQuestPlay.has_foe(enc, "Szoldar"), "he's on the rise with his bow")
	assert_true(SideQuestPlay.has_foe(enc, "werewolf"), "a castle wolf at level 7")
	assert_eq(str((enc["withdraw"] as Dictionary)["flag"]), "szoldar_fled", "he runs if it goes badly")
	assert_eq(SideQuestPlay.standing(st, "vallaki_blue_water_inn", "szoldar"), "vallaki/hunters_at_the_inn:szoldar")
	st.set_flag("greytooth_beaten")
	assert_eq(SideQuestPlay.standing(st, "vallaki_blue_water_inn", "szoldar"), "", "he doesn't come back to the inn")


func test_old_greytooth_is_a_boss() -> void:
	var g := Compendium.shared().get_entry("monsters", "old_greytooth")
	assert_eq(str(g["size"]), "huge")
	assert_eq(int(g["cr"]), 8)
	assert_eq(int((g["legendary_actions"] as Dictionary)["per_round"]), 3)
	assert_eq(str(g["art"]), "dire_wolf", "drawn with the dire wolf's sprite")
	assert_true(g.has("actions"))
