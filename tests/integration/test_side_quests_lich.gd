extends TestCase
## The Name Over the Door (docs/story/side_quests.md): Mordenkainen's news of Khazan, the cold hearthstone and the stair
## under it, the lich in his study with the party's names in his book, his phylactery found out (the name over the
## tower door), the name unmade at the door, and the last fight, kinder if he's given his name to die with.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _undercroft() -> StoryState:
	var st := SideQuestPlay.party(FOUR, 10, "khazan_undercroft", 12)
	st.set_quest_stage("the_name_over_the_door", "found")
	st.set_flag("khazan_stair_open")
	return st


func _shown(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func test_mordenkainens_news_and_the_hearthstone() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "mount_baratok_hut", 12)
	st.set_flag("mordenkainen_met")
	st.set_flag("mordenkainen_restored")
	st.set_flag("corvina_name_known")
	var beats := SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("They move downstairs"))
	assert_eq(st.quest_stage("the_name_over_the_door"), "rumored")
	# Too soon, and he talks about Corvina instead.
	var young := SideQuestPlay.party(FOUR, 9, "mount_baratok_hut", 12)
	young.set_flag("mordenkainen_met")
	young.set_flag("mordenkainen_restored")
	young.set_flag("corvina_name_known")
	beats = SideQuestPlay.play(young, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "Goodbye"])
	assert_false(SideQuestPlay.text(beats).contains("downstairs"))
	assert_false(SideQuestPlay.shown(young, "van_richtens_tower_interior", "vrt_hearthstone"), "not at level 9 without the news")
	# The hearthstone, and the stair under it.
	st.location = "van_richtens_tower_interior"
	assert_true(SideQuestPlay.shown(st, "van_richtens_tower_interior", "vrt_hearthstone"))
	assert_false(_shown(st, "van_richtens_tower_interior", "vrt_undercroft_stair"))
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:hearthstone", ["Look for the edge"])
	assert_true(SideQuestPlay.text(beats).contains("pages turning"))
	assert_true(st.get_flag("khazan_stair_open", false))
	assert_eq(st.quest_stage("the_name_over_the_door"), "found")
	assert_true(_shown(st, "van_richtens_tower_interior", "vrt_undercroft_stair"))


func test_the_book_and_what_holds_him() -> void:
	var st := _undercroft()
	assert_eq(SideQuestPlay.standing(st, "khazan_undercroft", "khazan"), "van_richtens_tower/the_name_over_the_door:khazan")
	var beats := SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:khazan", ["Who are you?", "Leave him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("a name for a name"))
	assert_eq(st.quest_stage("the_name_over_the_door"), "met")
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:book")
	assert_true(SideQuestPlay.text(beats).contains("the ink still wet"))
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:khazan", ["You keep yourself alive in that book", "We're going to break the name"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Over the door"))
	assert_true(st.get_flag("khazan_jar_known", false))
	assert_eq(SideQuestPlay.combat_of(beats), "khazan_named")
	var enc := SideQuestPlay.encounter(st, "khazan_undercroft", "khazan_named")
	assert_true(bool(enc.get("lair", false)), "his undercroft answers him while the name stands")
	assert_eq(str((enc["withdraw"] as Dictionary)["who"]), "khazan", "and he can't be destroyed, only driven back")


func test_the_name_over_the_door_is_unmade() -> void:
	var st := _undercroft()
	st.location = "van_richtens_tower"
	st.set_flag("tower_door_opened")
	var beats := SideQuestPlay.play(st, "van_richtens_tower/tower:door")
	assert_true(SideQuestPlay.text(beats).contains("The door stands open"), "nothing to do at the door yet")
	st.set_flag("khazan_withdrawn")
	st.set_quest_stage("the_name_over_the_door", "named")
	beats = SideQuestPlay.play(st, "van_richtens_tower/tower:door", ["Chisel the name out"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("a very long breath"))
	assert_true(st.get_flag("khazan_name_broken", false))
	assert_true(st.get_flag("khazan_jar_known", false), "the dust in the letters told them")
	assert_eq(st.quest_stage("the_name_over_the_door"), "unnamed")
	beats = SideQuestPlay.play(st, "van_richtens_tower/tower:door")
	assert_true(SideQuestPlay.text(beats).contains("The door stands open"), "the door is only a door again")


func test_the_last_fight_and_his_name_given_back() -> void:
	var st := _undercroft()
	st.set_flag("khazan_met")
	st.set_flag("khazan_withdrawn")
	assert_eq(SideQuestPlay.standing(st, "khazan_undercroft", "khazan"), "", "back in his name")
	var beats := SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:chair")
	assert_true(SideQuestPlay.text(beats).contains("toward the door"))
	st.set_flag("khazan_name_broken")
	assert_eq(SideQuestPlay.standing(st, "khazan_undercroft", "khazan"), "van_richtens_tower/the_name_over_the_door:unnamed")
	var plain := SideQuestPlay.encounter(st, "khazan_undercroft", "khazan_unmade")
	assert_eq(str(plain.get("surprise", "")), "")
	assert_false(plain.has("withdraw"), "this body is the last")
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:unnamed", ["Khazan."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Be quick"))
	assert_eq(SideQuestPlay.combat_of(beats), "khazan_unmade")
	var kind := SideQuestPlay.encounter(st, "khazan_undercroft", "khazan_unmade")
	assert_eq(str(kind.get("surprise", "")), "enemies", "given his name, he doesn't lift a hand at first")
	# Destroyed: the coffer, a blank book.
	st.set_flag("khazan_destroyed")
	st.set_quest_stage("the_name_over_the_door", "unmade")
	assert_true(SideQuestPlay.shown(st, "khazan_undercroft", "khazan_coffer"))
	assert_eq(SideQuestPlay.standing(st, "khazan_undercroft", "khazan"), "")
	beats = SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:book")
	assert_true(SideQuestPlay.text(beats).contains("every page is blank"))
