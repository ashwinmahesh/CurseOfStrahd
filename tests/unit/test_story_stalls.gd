extends TestCase
## Storyline QA (2026-10-12): the worst stalls the Wiki lane found writing the walkthroughs ("QA - Wiki Walkthrough
## Findings" in the vault), each played through the way a party meets it, and saves made before the fix catching up.


## Finding 1: Into the Mists closed only when the party spoke to Rose and Thorn, and nothing made it. They run up to
## the party on the road now (approach), meeting them closes it, and a party already in the village is past the mists.
func test_into_the_mists_closes_at_the_village_edge() -> void:
	var rose := {}
	for n: Variant in Compendium.shared().get_entry("locations", "into_the_mists_road")["npcs"]:
		if str((n as Dictionary)["dialogue"]) == "death_house/rose_thorn:start" and str((n as Dictionary)["npc"]) == "rose":
			rose = n as Dictionary
	assert_true(int(rose.get("approach", 0)) > 0, "Rose comes up to the party")
	var st := SideQuestPlay.party(["ilse_varga"], 1, "into_the_mists_road", 9)
	st.set_quest_stage("into_the_mists", "the_pack")
	SideQuestPlay.play(st, "death_house/rose_thorn:start", ["Where is your house"])
	assert_eq(st.quest_stage("into_the_mists"), "village_edge")
	var old := SideQuestPlay.party(["ilse_varga"], 1, "village_of_barovia", 9)
	old.set_quest_stage("into_the_mists", "the_pack")
	old.visited["village_of_barovia"] = true
	assert_eq(_loaded(old).quest_stage("into_the_mists"), "village_edge", "an old save already in the village")


## Finding 6: the escort ended only at the gate's first-arrival scene, so a party that had been to Vallaki without
## Ireena could never finish it, nor begin Sanctuary. The guard sees her in the first time she comes.
func test_ireenas_escort_ends_on_her_first_time_through_the_gate() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 4, "vallaki", 12)
	st.set_flag("vallaki_arrived")
	st.set_quest_stage("escort_ireena", "departed")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_guard"), "vallaki/gate:guard", "no scene without her")
	assert_true(st.add_guest("ireena"))
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_guard"), "vallaki/gate:ireena_arrives")
	SideQuestPlay.play(st, "vallaki/gate:ireena_arrives")
	assert_eq(st.quest_stage("escort_ireena"), "arrived")
	assert_eq(st.quest_stage("sanctuary_for_ireena"), "arrived", "and Sanctuary begins")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_guard"), "vallaki/gate:guard", "once")


## Finding 40: with the witch's stone found first, Davian's pledge put The Third Stone back to "told", and its hand-over
## needs "found", so the stone could never go home. A begun quest doesn't start over now.
func test_the_berez_stone_found_first_still_goes_home() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines", 12)
	st.set_quest_stage("the_third_stone", "found")
	var beats := SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["clear your house", "witch's stone"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_third_stone"), "returned", "Davian takes the stone")
	var old := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines", 12)
	old.set_quest_stage("the_third_stone", "found")
	(old.quests["the_third_stone"] as Dictionary)["stage"] = "told"   # what the pledge did before
	(old.quests["the_third_stone"]["history"] as Array).append("told")
	assert_eq(_loaded(old).quest_stage("the_third_stone"), "found", "an old save catches up")


## Finding 41: a stone handed over before the druids were out never started the press, and the reclaiming didn't
## either, so the wine never flowed (no wine to buy, no first cart). The reclaiming starts it now, and an old save's
## next talk with Davian does.
func test_the_wine_flows_whichever_comes_first() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines", 12)
	st.set_flag("davian_met")
	for f: String in ["winery_stone_recovered", "winery_hall_cleared", "press_house_cleared"]:
		st.set_flag(f)
	SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["founder's cask", "Goodbye"])
	assert_false(bool(st.get_flag("winery_wine_flows", false)), "not before the house is his")
	SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["out of your house", "To Vallaki"])
	assert_true(bool(st.get_flag("winery_wine_flows", false)), "the reclaiming starts the press")
	assert_eq(str(st.get_flag("winery_first_cart", "")), "vallaki")
	var old := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines", 12)
	for f: String in ["davian_met", "winery_reclaimed", "winery_stone_returned"]:
		old.set_flag(f)
	old.set_flag("winery_stones_returned", 1)
	SideQuestPlay.play(old, "wizard_of_wines/davian:start", ["To Krezk"])
	assert_true(bool(old.get_flag("winery_wine_flows", false)), "an old save's next talk")


## Finding 66: the ally's quest reached "found" only where a scene said so, and Ismark's, Kolyan's and Parriwimple's
## didn't; the Darklord card, which names no one, left it open for good. The one the cards named joining finds them,
## whenever it happens, and the Darklord closes the quest at the reading.
func test_the_tarokka_ally_is_found_when_they_join() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 3, "village_of_barovia", 12)
	st.tarokka = {"ally": "executioner"}   # Ismark
	st.set_quest_stage("find_the_ally", "foretold")
	assert_true(st.add_guest("ismark"))
	assert_eq(st.quest_stage("find_the_ally"), "found")
	var early := SideQuestPlay.party(["ilse_varga"], 3, "village_of_barovia", 12)
	early.tarokka = {"ally": "innocent"}   # Parriwimple, travelling with the party before the reading
	assert_true(early.add_guest("parriwimple"))
	early.set_quest_stage("find_the_ally", "foretold")
	assert_eq(early.quest_stage("find_the_ally"), "found", "already with the party at the reading")
	var alone := SideQuestPlay.party(["ilse_varga"], 3, "svalich_road", 12)
	alone.tarokka = {"ally": "darklord"}
	alone.set_quest_stage("find_the_ally", "foretold")
	assert_eq(alone.quest_stage("find_the_ally"), "alone")
	assert_eq(str(_entry(alone, "find_the_ally")["status"]), "success")
	var old := SideQuestPlay.party(["ilse_varga"], 3, "village_of_barovia", 12)
	old.tarokka = {"ally": "horseman"}   # Kolyan
	old.guest_ids.append("kolyan_indirovich")   # joined before the fix: the quest never moved
	old.guests.append(StoryState.make_guest("kolyan_indirovich"))
	(old.quests as Dictionary)["find_the_ally"] = {"stage": "foretold", "history": ["foretold"], "at": 0}
	assert_eq(_loaded(old).quest_stage("find_the_ally"), "found", "an old save catches up")


## Finding 69: only the catacombs' final battles asked whether Strahd was already beaten and misted to his coffin, so the
## chapel's, the study's and the rest could start a whole final battle with him in it. Every final battle asks now.
func test_no_final_battle_with_strahd_in_his_coffin() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "castle_ravenloft_court", 22)
	st.tarokka = {"enemy": "seer"}   # the study
	st.set_quest_stage("strahds_lair", "foretold")
	var study := {}
	for e: Variant in Compendium.shared().get_entry("locations", "castle_ravenloft_court")["encounters"]:
		if str((e as Dictionary)["id"]) == "court_final_study":
			study = e as Dictionary
	assert_true(StoryConditions.check(StoryConditions.encounter_when(study), st), "he waits in the study")
	st.set_flag("strahd_in_coffin")
	assert_false(StoryConditions.check(StoryConditions.encounter_when(study), st), "not once he's in his coffin")


## Starting a begun quest over, or reopening a finished one, is refused; a later stage, or another ending, isn't.
func test_a_quest_never_starts_over() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 3, "village_of_barovia", 12)
	st.set_quest_stage("escort_ireena", "accepted")
	assert_false(st.set_quest_stage("escort_ireena", "asked"), "not back to its first stage")
	assert_eq(st.quest_stage("escort_ireena"), "accepted")
	st.set_quest_stage("escort_ireena", "declined")
	assert_true(st.set_quest_stage("escort_ireena", "accepted"), "a change of mind still can")


func _loaded(st: StoryState) -> StoryState:
	return StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)


func _entry(st: StoryState, quest_id: String) -> Dictionary:
	for q in QuestLog.journal(st):
		if str(q["id"]) == quest_id:
			return q
	return {}
