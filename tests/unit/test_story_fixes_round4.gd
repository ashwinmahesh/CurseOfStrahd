extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's fourth round of findings ("QA - Wiki Walkthrough Findings" in the vault,
## #91-#98), each played the way a party meets it.


## Findings 91 and 92: Krezk still talked of the wine stopping after the party brought the Martikovs' cart up.
func test_krezk_knows_the_wine_came_back() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "krezk", 12)
	st.set_flag("krezk_gate_open")
	st.set_flag("winery_wine_flows")
	st.set_flag("winery_first_cart", "krezk")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "krezk/gate:news"))
	assert_false(said.contains("the wine's stopped"), said)
	assert_true(said.contains("first cart is in the shrine cellar"), said)
	st.set_flag("wizard_of_wines_hook")
	var beats := SideQuestPlay.play(st, "krezk/dmitri:menu", ["About the wine that stopped coming"])
	assert_ne(SideQuestPlay.missing(beats), "", "Dmitri doesn't ask after it")


## Finding 93: the Abbot left broken by the Bride's defeat was never seen again.
func test_the_broken_abbot_sits_on_the_altar_step() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 8, "abbey_of_st_markovia_shrine", 12)
	st.set_flag("abbot_met")
	st.set_flag("bride_defeated")
	st.set_flag("abbot_fate", "broken")
	assert_eq(SideQuestPlay.standing(st, "abbey_of_st_markovia_shrine", "abbot"), "abbey_of_st_markovia/abbot:start")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "abbey_of_st_markovia/abbot:start"))
	assert_true(said.contains("He sits on the altar step"), said)


## Finding 94: a Liriel who missed the first meeting met him on no later visit, and with him gone for good before she
## did, her talk after his fate never came.
func test_liriel_meets_the_abbot_on_a_later_visit() -> void:
	var st := SideQuestPlay.party(["liriel_dawnsong"], 7, "abbey_of_st_markovia_shrine", 12)
	st.set_quest_stage("carry_the_dawn", "a_spark")
	st.set_flag("abbot_met")
	SideQuestPlay.play(st, "abbey_of_st_markovia/abbot:start", ["Goodbye"])
	assert_eq(st.quest_stage("carry_the_dawn"), "the_angel")
	var never := SideQuestPlay.party(["liriel_dawnsong"], 7, "krezk", 22)
	never.set_quest_stage("carry_the_dawn", "the_silence")
	never.set_flag("abbot_fate", "slain")
	var cond := CampTalk.opening_condition(DialogueFile.load_key("camp/liriel"), "talk_faith")
	assert_true(StoryConditions.check(cond, never), "her talk once he's gone for good")


## Findings 95 and 96: the skull still hung on the wall once taken, and the bier read as headless once it was home.
func test_the_skull_is_where_the_party_left_it() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "castle_ravenloft_court", 12)
	assert_true(SideQuestPlay.shown(st, "castle_ravenloft_court", "court_dragon_skull"))
	st.set_flag("argynvost_skull_taken")
	assert_false(SideQuestPlay.shown(st, "castle_ravenloft_court", "court_dragon_skull"), "gone from the wall")
	st.set_flag("argynvost_skull_home")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "argynvostholt/mausoleum:bones"))
	assert_false(said.contains("nothing at all"), said)
	assert_true(said.contains("where it belongs"), said)


## Finding 97: with The Unnamed Crypt done first, Mordenkainen spoke of Corvina without his letters, and his lost
## pages could never start or end.
func test_mordenkainens_pages_come_first() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "mount_baratok_hut", 12)
	st.set_flag("mordenkainen_restored")
	st.set_quest_stage("the_unnamed_crypt", "done")
	st.set_flag("corvina_name_known")
	SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:news", ["Goodbye"])
	assert_eq(st.quest_stage("the_mages_lost_pages"), "asked", "his pages start")
	assert_false(bool(st.get_flag("corvina_thanks_given", false)), "no thanks for a name he doesn't have yet")
	for n: String in ["1", "2", "3"]:
		st.set_flag("corvina_letter_" + n)
	SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:news", ["Let him rage", "Goodbye"])
	assert_eq(st.quest_stage("the_mages_lost_pages"), "named")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:news", ["Goodbye"]))
	assert_true(said.contains("You found her."), "then his thanks: %s" % said)


## Finding 98: the Second Thirst borrowed Strahd's win's slides, so the count came for Nadia after he was destroyed.
func test_the_second_thirst_has_its_own_larder_slides() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "castle_ravenloft_court", 12)
	st.set_flag("larders_nadia_fate", "waits")
	st.set_flag("larders_cyrus_met")
	var texts := Endings.slides(Endings.get_ending("new_darklord"), st).map(func(sl: Dictionary) -> String: return str(sl["text"]))
	assert_false(str(texts).contains("the count, at dinnertime"), str(texts))
	assert_false(str(texts).contains("The master is pleased with him"), str(texts))
	assert_true(str(texts).contains("the new lord let her go"), str(texts))
