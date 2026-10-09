extends TestCase
## The Nursemaid's Grave (docs/story/side_quests.md): Old Mihail's girl at the churchyard wall, Veta's name and wish, her
## bones from the attic trunk, Walter's empty crypt, the house's keepers, and the stone left on the lid.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func test_mihail_and_the_girl_at_the_wall() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "village_of_barovia", 10)
	var beats := SideQuestPlay.play(st, "village_of_barovia/townsfolk:gravedigger", ["Anyone you couldn't bury?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("a nursemaid's cap"))
	assert_eq(st.quest_stage("the_nursemaids_grave"), "rumored")
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "durst_nursemaid"), "", "only by night")
	st.minute_of_day = 22 * 60
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "durst_nursemaid"), "village_of_barovia/the_nursemaids_grave:wall")
	st.set_flag("death_house_nursemaid_calmed")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_nursemaids_grave:wall", ["Why can't you go in?"])
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("You sang it"), "she knows who hummed her the lullaby")
	assert_true(said.contains("My name's Veta"))
	assert_eq(st.quest_stage("the_nursemaids_grave"), "asked")


func test_the_bones_the_empty_crypt_and_the_stone() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "death_house_attic", 12)
	st.set_quest_stage("the_nursemaids_grave", "asked")
	var beats := SideQuestPlay.play(st, "death_house/attic:nursemaid_trunk", ["Wrap her in the sheet"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("nursemaid_bones_taken", false))
	assert_eq(st.quest_stage("the_nursemaids_grave"), "carried")
	st.location = "death_house_dungeon_1"
	beats = SideQuestPlay.play(st, "death_house/dungeon:crypt_walter", ["Bring his mother to him", "Lay her in it anyway"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("There was never a baby in it"))
	assert_eq(SideQuestPlay.combat_of(beats), "nursemaid_keepers")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, "death_house_dungeon_1", "nursemaid_keepers"), "Gustav Durst"))
	st.set_flag("death_house_dursts_destroyed")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, "death_house_dungeon_1", "nursemaid_keepers"), "The Robed One Who Carried Him"))
	st.set_flag("nursemaid_keepers_beaten")
	st.set_quest_stage("the_nursemaids_grave", "laid")
	beats = SideQuestPlay.play(st, "death_house/dungeon:crypt_walter", ["Bring his mother to him"])
	assert_true(SideQuestPlay.text(beats).contains("warm as a hand"))
	assert_eq(st.quest_stage("the_nursemaids_grave"), "done")
	assert_true(st.party_has_item("stone_of_good_luck"))
	beats = SideQuestPlay.play(st, "death_house/dungeon:crypt_walter")
	assert_false(SideQuestPlay.text(beats).contains("warm as a hand"), "once")
