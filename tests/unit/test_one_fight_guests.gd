extends TestCase
## A guest who stays for one fight (Sir Klutz Tripalotsky's ghost, the catacombs' crypt 33; Dungeon Expansion Plan C1):
## his NPC's `leaves_after_fight` sends him away when the next fight ends (StoryState.release_one_fight_guests, asked by
## LocationFights after every fight). Every other guest stays.


func test_sir_klutz_leaves_after_one_fight() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "castle_ravenloft_catacombs", 12)
	assert_true(st.add_guest("sir_klutz"), "he can join")
	assert_true(st.add_guest("ireena"), "and so can Ireena")
	var gone := st.release_one_fight_guests()
	assert_eq(gone, ["Sir Klutz Tripalotsky"] as Array[String], "his one battle is over")
	assert_false("sir_klutz" in st.guest_ids, "he is gone")
	assert_true("ireena" in st.guest_ids, "Ireena stays")
	assert_eq(st.release_one_fight_guests().size(), 0, "and nobody is left to release")


func test_a_guest_nobody_sends_home_is_not_released() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "wizard_of_wines", 12)
	assert_true(st.add_guest("adrian_martikov"))
	assert_eq(st.release_one_fight_guests().size(), 0, "an ordinary guest stays through the fight")
	assert_true("adrian_martikov" in st.guest_ids)
