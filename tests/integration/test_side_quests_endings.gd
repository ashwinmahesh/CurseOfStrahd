extends TestCase
## Side-quest endings the per-quest tests didn't reach (the sidequests lane's QA pass, docs/story/side_quests.md):
## Teodor going into the woods (The Polite Caller) and Sorin going back up the mountain (Lighter Than It Should Be).

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]


func test_teodor_goes_into_the_woods() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "village_of_barovia", 5)
	st.set_quest_stage("polite_caller", "held")
	st.add_guest("teodor")
	var beats := SideQuestPlay.play(st, "village_of_barovia/polite_caller:woods")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("The woods, then"))
	assert_true(said.contains("I'll leave the shutter as it is"))
	assert_eq(st.quest_stage("polite_caller"), "woods")
	assert_eq(str(st.get_flag("teodor_fate", "")), "woods")
	assert_false("teodor" in st.guest_ids, "he goes alone")


func test_sorin_goes_back_up_the_mountain() -> void:
	var st := SideQuestPlay.party(FOUR, 7, "krezk_burgomaster_house", 14)
	st.set_quest_stage("lighter_than_it_should_be", "sorin_known")
	st.set_flag("sorin_brought")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "krezk/lighter_than_it_should_be:to_mountain")
	assert_true(SideQuestPlay.text(beats).contains("I'll keep every one"))
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "mountain")
	assert_eq(str(st.get_flag("sorin_fate", "")), "mountain")
	assert_eq(roundi(st.gold), 400)
	assert_true(st.party_has_item("armor_plus_1") or st.party.any(func(c: Character) -> bool: return c.carries("armor_plus_1__chain_mail")),
		"the grandfather's mail")
	assert_eq(SideQuestPlay.standing(st, "krezk_burgomaster_house", "sorin_krezkov"), "", "not at the house")
	assert_eq(SideQuestPlay.standing(st, "krezk_pool_of_the_white_sun", "sorin_krezkov"), "", "not at the pool")
