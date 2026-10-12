extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's findings in the opening, the Village of Barovia and Vallaki ("QA - Wiki
## Walkthrough Findings" in the vault), each played the way a party meets it.


## Finding 2: the arrival in the mists (and every personal quest with it) played only if the party looked back at the
## mist. The wolf in the narrows plays it now when it hasn't, then the standoff goes on.
func test_the_arrival_plays_at_the_wolves() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook"], 1, "into_the_mists_road", 9)
	var beats := SideQuestPlay.play(st, "into_the_mists/wolves:start", ["Wait for them"])
	assert_eq(SideQuestPlay.missing(beats), "", "the standoff's choices after the arrival")
	assert_true(bool(st.get_flag("mists_arrived", false)))
	assert_eq(st.quest_stage("the_ladle"), "the_errand", "Godrick's own quest begins")
	assert_true(st.quest_stage("into_the_mists") != "", "and Into the Mists")


## Finding 8: leaving by the west road before the burial counted as refusing Ireena, and the burial then put a yes
## back to "ready". Neither now.
func test_the_escort_keeps_its_answer_through_the_burial() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 2, "village_of_barovia", 12)
	st.set_flag("ismark_met")
	st.set_quest_stage("escort_ireena", "asked")
	SideQuestPlay.play(st, "village_of_barovia/road_west:depart_alone")
	assert_eq(str(st.get_flag("ireena_escort", "")), "", "not a refusal before she's been asked")
	assert_eq(st.quest_stage("escort_ireena"), "asked")
	st.set_quest_stage("escort_ireena", "accepted")
	SideQuestPlay.play(st, "village_of_barovia/burial:lowered", ["Goodbye"])
	assert_ne(st.quest_stage("escort_ireena"), "ready", "the burial doesn't undo a yes")


## Finding 9: Snowdrop's bell started the pasture wolves every time; once they're beaten it leads on to her choice.
func test_the_pasture_wolves_come_once() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 2, "barovia_high_pasture", 18)
	st.set_quest_stage("the_goatherds_count", "asked")
	assert_eq(SideQuestPlay.combat_of(SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:bell")), "pasture_wolves")
	st.set_flag("pasture_wolves_beaten")
	assert_eq(SideQuestPlay.combat_of(SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:bell")), "",
		"no second fight")


## Finding 10: with Parriwimple travelling with the party, nobody could tell it about the hollow. He blurts it out at
## Bildrath's.
func test_parriwimple_in_the_party_tells_of_the_hollow() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 2, "village_of_barovia", 12)
	assert_true(st.add_guest("parriwimple"))
	SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:bildrath_news")
	assert_true(bool(st.get_flag("hollow_known", false)), "the north path opens")
	assert_eq(st.quest_stage("the_oat_thief"), "asked")


## Finding 15: when Arabelle was the Tarokka ally, either answer to her ended the talk before Luvash's reward.
func test_luvash_pays_whatever_arabelle_does() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki_vistani_camp", 12)
	st.tarokka = {"ally": "tempter"}   # Arabelle
	var gold := st.gold
	SideQuestPlay.play(st, "vallaki/vistani_camp:luvash_grateful", ["keep her safe"])
	assert_eq(st.gold, gold + 50.0)
	assert_true(st.party_has_item("cloak_of_the_manta_ray"), "his grandmother's cloak")
	assert_true("arabelle" in st.guest_ids, "and she comes along")


## Finding 19: Victor travelling with the party still vanished from his attic in Lady Wachter's ending.
func test_victor_with_the_party_doesnt_vanish() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki", 13)
	st.set_quest_stage("victors_circle", "found")
	assert_true(st.add_guest("victor_vallakovich"))
	SideQuestPlay.play(st, "vallaki/aftermath:wachter_close")
	assert_false(bool(st.get_flag("victor_vanished", false)))
	assert_eq(st.quest_stage("victors_circle"), "found")


## Finding 20: Strahd taking Ireena left Sanctuary open with nothing to do; it ends now. Finding 22: Lady Wachter
## slipping away ends her plot.
func test_sanctuary_and_the_book_club_end() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki", 23)
	st.set_quest_stage("sanctuary_for_ireena", "at_inn")
	SideQuestPlay.play(st, "strahd/ireena:taken")
	assert_eq(st.quest_stage("sanctuary_for_ireena"), "taken")
	assert_eq(_status(st, "sanctuary_for_ireena"), "failure")
	st.set_quest_stage("wachter_plot", "slipped_away")
	assert_eq(_status(st, "wachter_plot"), "success")


func _status(st: StoryState, quest_id: String) -> String:
	for q in QuestLog.journal(st):
		if str(q["id"]) == quest_id:
			return str(q["status"])
	return ""
