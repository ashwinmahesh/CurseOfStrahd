extends TestCase
## The Mage's Lost Pages (docs/story/side_quests.md): Mordenkainen's missing pages, the three letters on Mount Baratok
## (found by a roll or dug out the slow way), Corvina's name, what he really did on the stair, and the ring given once.

const SIX: Array[String] = ["ratatoille", "liriel_dawnsong", "godrick_pendlebrook", "thistle"]


func _hut() -> StoryState:
	var st := SideQuestPlay.party(SIX, 9, "mount_baratok_hut", 12)
	st.set_flag("mordenkainen_met")
	st.set_flag("mordenkainen_restored")
	return st


func test_the_letters_the_name_and_the_stair() -> void:
	var st := _hut()
	var beats := SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("There are pages missing"))
	assert_eq(st.quest_stage("the_mages_lost_pages"), "asked")
	st.location = "mount_baratok"
	for id: String in ["corvina_letter_birds", "corvina_letter_ring", "corvina_letter_overlook"]:
		assert_true(SideQuestPlay.shown(st, "mount_baratok", id), id)
	beats = SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_birds", ["Chip the whole shell away"])
	assert_true(bool(st.get_flag("corvina_letter_1", false)))
	beats = SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_ring", ["Break the glass around it"])
	assert_true(SideQuestPlay.text(beats).contains("Corvina. Corvina. Corvina."))
	beats = SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_overlook", ["Dig the whole drift out"])
	assert_true(SideQuestPlay.text(beats).contains("She holds my doors still. S."))
	beats = SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_overlook")
	assert_true(SideQuestPlay.text(beats).contains("nothing in the snow"), "found once")
	st.location = "mount_baratok_hut"
	beats = SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "Let him rage", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("I ran") or said.contains("I went"))
	assert_eq(st.quest_stage("the_mages_lost_pages"), "named")
	assert_true(bool(st.get_flag("corvina_name_known", false)))
	assert_true(st.party_has_item("ring_of_telekinesis"))
	beats = SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("I say it every morning"), "given once")


func test_a_promise_keeps_him_on_the_mountain() -> void:
	var st := _hut()
	st.set_flag("mordenkainen_promised_aid")
	st.set_quest_stage("the_mages_lost_pages", "asked")
	for f: String in ["corvina_letter_1", "corvina_letter_2", "corvina_letter_3"]:
		st.set_flag(f)
	var beats := SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "You promised to come with us", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_false(SideQuestPlay.text(beats).contains("He rages"), "the promise holds him")
	assert_eq(st.quest_stage("the_mages_lost_pages"), "named")
