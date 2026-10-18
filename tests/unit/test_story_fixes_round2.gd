extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's second round of findings ("QA - Wiki Walkthrough Findings" in the vault,
## #75-#80), each played the way a party meets it. Finding 79, the talking props' skill tips, is in
## test_world_checks_in_place.


## Finding 75: after a party cleric's rites the village gossip still said "No priest, mind."
func test_the_gossip_knows_a_cleric_buried_the_burgomaster() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 2, "village_of_barovia", 12)
	st.set_flag("burgomaster_buried")
	st.set_flag("burial_method", "cleric_rites")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "village_of_barovia/townsfolk:gossip"))
	assert_false(said.contains("No priest"), said)
	assert_true(said.contains("said the prayers over him"), said)
	# Vasile and Petre tell the burial once now (NPC plan batch 1), so the other rites are a fresh telling.
	st = SideQuestPlay.party(["ilse_varga"], 2, "village_of_barovia", 12)
	st.set_flag("burgomaster_buried")
	st.set_flag("burial_method", "lay_rites")
	said = SideQuestPlay.text(SideQuestPlay.play(st, "village_of_barovia/townsfolk:gossip"))
	assert_true(said.contains("No priest, mind."), "a burial without one still says so")


## Finding 76: when the arrival in the mists plays at the wolves, the party's nerves still come after it.
func test_kip_still_talks_to_the_wolves_after_a_late_arrival() -> void:
	var st := SideQuestPlay.party(["kip_smudgewick"], 1, "into_the_mists_road", 9)
	var beats := SideQuestPlay.play(st, "into_the_mists/wolves:start", ["Wait for them"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("mists_arrived", false)), "the arrival played")
	assert_true(SideQuestPlay.text(beats).contains("Good dog. Nice dog."), "and Kip spoke to the wolves")


## Finding 77: with Arabelle as the Tarokka ally, leaving her with her father replayed the whole parting on every talk
## with Luvash. Later visits ask briefly, and she can still come.
func test_arabelle_remembers_she_stayed() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki_vistani_camp", 12)
	st.tarokka = {"ally": "tempter"}   # Arabelle
	SideQuestPlay.play(st, "vallaki/vistani_camp:luvash_grateful", ["stay with your father"])
	assert_true(bool(st.get_flag("arabelle_stayed", false)))
	assert_false("arabelle" in st.guest_ids)
	var beats := SideQuestPlay.play(st, "vallaki/vistani_camp:luvash_grateful", ["Not yet"])
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Have you come back for me?"), said)
	assert_false(said.contains("I only just got you back"), "not the whole parting again")
	assert_false("arabelle" in st.guest_ids)
	beats = SideQuestPlay.play(st, "vallaki/vistani_camp:luvash_grateful", ["Come with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true("arabelle" in st.guest_ids, "she comes when asked")


## Finding 78: the blank page's fight is Dobre's lads on Main Street; the scene brings the party back there first.
func test_the_blank_page_fight_is_back_on_main_street() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 4, "vallaki", 20)
	st.set_flag("ribbons_list_blank")
	var beats := SideQuestPlay.play(st, "vallaki/ribbons:follow", ["blank page"])
	assert_eq(SideQuestPlay.combat_of(beats), "ribbons_street")
	assert_true(SideQuestPlay.text(beats).contains("back under the lamp on Main Street"))


## Finding 80: the dead prisoner in the larders tells of the heart, so the party knows what it does.
func test_the_larders_prisoner_tells_what_the_heart_does() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "castle_ravenloft_larders_dungeon", 12)
	SideQuestPlay.play(st, "castle_ravenloft/larders_prisoner:speaks")
	assert_true(bool(st.get_flag("heart_of_sorrow_known", false)))
	assert_eq(st.quest_stage("the_heart_of_sorrow"), "heard")
