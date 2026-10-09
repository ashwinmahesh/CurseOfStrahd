extends TestCase
## The Amber Debt (docs/story/side_quests.md): Exethanter's old note, the weeping crack in the vault floor and the stair
## under it, the wardens' book (the mirrors, the lullaby, and what his forgetting is for), each trick changing the fight
## with the Eye Below, and its hoard.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _deep() -> StoryState:
	var st := SideQuestPlay.party(FOUR, 10, "amber_deep", 12)
	st.set_quest_stage("the_amber_debt", "found")
	st.set_flag("deep_stair_open")
	return st


func _exit_open(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func _eye(enc: Dictionary) -> Dictionary:
	for m: Variant in enc.get("monsters", []):
		if str((m as Dictionary)["monster"]) == "the_eye_below":
			return m as Dictionary
	return {}


func test_the_old_note_and_the_weeping_crack() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "amber_temple_library", 12)
	st.set_flag("exethanter_met")
	st.set_flag("exethanter_note_given")
	var beats := SideQuestPlay.play(st, "amber_temple/exethanter:start", ["There's an older note", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("YOU DO NOT REMEMBER WHY"))
	assert_eq(st.quest_stage("the_amber_debt"), "rumored")
	st.location = "amber_temple_vault"
	assert_true(SideQuestPlay.shown(st, "amber_temple_vault", "vault_weeping_crack"))
	assert_false(_exit_open(st, "amber_temple_vault", "vault_deep_stair"))
	beats = SideQuestPlay.play(st, "amber_temple/the_amber_debt:crack", ["Lever the slab up"])
	assert_true(SideQuestPlay.text(beats).contains("into the dark"))
	assert_eq(st.quest_stage("the_amber_debt"), "found")
	assert_true(_exit_open(st, "amber_temple_vault", "vault_deep_stair"))
	var young := SideQuestPlay.party(FOUR, 8, "amber_temple_vault", 12)
	assert_false(SideQuestPlay.shown(young, "amber_temple_vault", "vault_weeping_crack"), "not before level 10 without the note")


func test_the_wardens_book_and_the_tricks() -> void:
	var st := _deep()
	var beats := SideQuestPlay.play(st, "amber_temple/the_amber_debt:notes", ["Read about the mirrors", "Read about the singing", "Read the last entry", "Close the book"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("fight the glass and not us"))
	assert_true(said.contains("If I ever start to remember, run"))
	assert_eq(st.quest_stage("the_amber_debt"), "read")
	assert_true(st.get_flag("deep_mirrors_known", false) and st.get_flag("deep_lullaby_known", false))
	var plain := SideQuestPlay.encounter(st, "amber_deep", "the_eye_below")
	assert_true(bool(plain.get("lair", false)))
	assert_true(SideQuestPlay.has_foe(plain, "dream_gazer"))
	beats = SideQuestPlay.play(st, "amber_temple/the_amber_debt:mirrors", ["Turn the mirrors"])
	assert_true(st.get_flag("deep_mirrors_turned", false))
	var mirrored := SideQuestPlay.encounter(st, "amber_deep", "the_eye_below")
	assert_false(bool(mirrored.get("lair", true)), "its dreamed eyes fight the glass")
	assert_false(SideQuestPlay.has_foe(mirrored, "dream_gazer"))
	st.set_flag("deep_lullaby_sung")
	var sung := SideQuestPlay.encounter(st, "amber_deep", "the_eye_below")
	assert_eq(str(sung.get("surprise", "")), "enemies")
	assert_true(int(_eye(sung).get("hp", 999)) < 180, "half back in its amber")


func test_meeting_the_eye_and_the_lullaby() -> void:
	var st := _deep()
	st.set_flag("deep_lullaby_known")
	var beats := SideQuestPlay.play(st, "amber_temple/the_amber_debt:eye", ["What are you?", "Sing the wardens' lullaby"], 4)
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Stand still while I dream you better"))
	assert_true(said.contains("someone has been giving it back to him"))
	assert_true(st.get_flag("deep_lullaby_tried", false), "one try, sung well or badly")
	assert_eq(SideQuestPlay.combat_of(beats), "the_eye_below")
	beats = SideQuestPlay.play(st, "amber_temple/the_amber_debt:eye", ["Sing the wardens' lullaby"])
	assert_true(SideQuestPlay.missing(beats).contains("lullaby"), "not twice")


func test_the_hoard_and_exethanter() -> void:
	var st := _deep()
	var beats := SideQuestPlay.play(st, "amber_temple/the_amber_debt:hoard")
	assert_true(SideQuestPlay.text(beats).contains("A beholder collects what it looks at"))
	st.set_flag("eye_below_slain")
	st.set_quest_stage("the_amber_debt", "slain")
	assert_eq(SideQuestPlay.standing(st, "amber_deep", "the_eye_below"), "")
	st.gold = 0
	beats = SideQuestPlay.play(st, "amber_temple/the_amber_debt:hoard")
	assert_true(SideQuestPlay.text(beats).contains("a single great eye worked in silver"))
	assert_eq(st.quest_stage("the_amber_debt"), "done")
	assert_eq(roundi(st.gold), 700)
	assert_true(st.party_has_item("spellguard_shield"))
	beats = SideQuestPlay.play(st, "amber_temple/the_amber_debt:hoard")
	assert_eq(roundi(st.gold), 700, "paid once")
	st.location = "amber_temple_library"
	st.set_flag("exethanter_met")
	st.set_flag("exethanter_note_given")
	beats = SideQuestPlay.play(st, "amber_temple/exethanter:start", ["The thing under the vault is dead", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I think I owe you for something"))
