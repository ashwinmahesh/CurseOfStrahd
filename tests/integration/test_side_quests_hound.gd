extends TestCase
## The Burgomaster's Hound (docs/story/side_quests.md): Bildrath's news, Lupu by the mansion, the cold corner of the
## study, Kolyan's note, and the two ends: the wall sealed again, or opened with the hound beside you. Each pays once.

const SIX: Array[String] = ["thistle", "liriel_dawnsong", "godrick_pendlebrook", "ratatoille"]


func _village(hour: int = 11) -> StoryState:
	return SideQuestPlay.party(SIX, 2, "village_of_barovia", hour)


## Lupu befriended (Thistle leads, a ranger, for the Animal Handling roll), whatever the dice.
func _befriend(st: StoryState) -> void:
	for seed: int in [1, 2, 3, 5, 8, 13]:
		SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:lupu", ["Crouch down"], seed)
		if bool(st.get_flag("lupu_friend", false)):
			return


func test_the_dog_the_note_and_the_tenant() -> void:
	var st := _village()
	st.location = "bildraths_mercantile"
	var beats := SideQuestPlay.play(st, "village_of_barovia/bildrath:news", ["The dog at the burgomaster's house", "Enough news", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("howls at the wall"))
	assert_eq(st.quest_stage("the_burgomasters_hound"), "rumored")
	st.location = "village_of_barovia"
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "lupu"), "village_of_barovia/the_burgomasters_hound:lupu")
	_befriend(st)
	assert_true(bool(st.get_flag("lupu_friend", false)), "some roll lets him come")
	assert_eq(st.quest_stage("the_burgomasters_hound"), "asked")
	st.location = "burgomaster_mansion"
	assert_true(SideQuestPlay.shown(st, "burgomaster_mansion", "study_bricks"))
	var found := false
	for seed: int in [1, 2, 3, 5, 8]:
		beats = SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks", ["Look for anything pushed in", "Leave it"], seed)
		if bool(st.get_flag("sergiu_known", false)):
			found = true
			assert_true(SideQuestPlay.text(beats).contains("Sergiu. My first."))
			break
	assert_true(found, "some roll finds the note")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks", ["Break the bricks open"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Lupu comes through the study door"))
	assert_eq(SideQuestPlay.combat_of(beats), "hound_tenant")
	assert_true("lupu" in st.guest_ids, "the hound fights beside the party")
	var enc := SideQuestPlay.encounter(st, "burgomaster_mansion", "hound_tenant")
	assert_true(SideQuestPlay.has_foe(enc, "The Tenant"))
	st.set_flag("tenant_slain")
	st.gold = 0
	beats = SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks")
	assert_true(SideQuestPlay.text(beats).contains("against exactly this"))
	assert_eq(st.quest_stage("the_burgomasters_hound"), "done")
	assert_eq(roundi(st.gold), 60)
	assert_true(st.party_has_item("mithral_armor"))
	assert_false("lupu" in st.guest_ids, "back to his step")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks")
	assert_true(SideQuestPlay.text(beats).contains("an open doorway now"))
	assert_eq(roundi(st.gold), 60, "paid once")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:lupu")
	assert_true(SideQuestPlay.text(beats).contains("like an ordinary dog"))


func test_sealing_the_wall() -> void:
	var sealed := false
	for seed: int in [1, 2, 3, 5, 8, 13]:
		var st := _village()
		st.location = "burgomaster_mansion"
		st.set_quest_stage("the_burgomasters_hound", "asked")
		st.gold = 0
		SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks", ["Bless the bricks", "Leave it"], seed)
		if st.quest_stage("the_burgomasters_hound") == "sealed":
			sealed = true
			assert_eq(roundi(st.gold), 60)
			assert_false(st.party_has_item("mithral_armor"))
			var beats := SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks")
			assert_true(SideQuestPlay.text(beats).contains("fresh garlic nailed above it"))
			break
	assert_true(sealed, "Liriel's Religion seals it on some roll")
