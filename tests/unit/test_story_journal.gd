extends TestCase
## Storyline QA (2026-10-08): the journal and the scenes that read it keep step with the story.


## Escort Ireena had no ending stage: once she was through Vallaki's gate it stayed open for the rest of the game, still
## saying "Follow the Old Svalich Road west". The gate closes it now, as Sanctuary for Ireena begins.
func test_escort_ireena_ends_at_the_vallaki_gate() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 3, "vallaki", 12)
	st.set_quest_stage("escort_ireena", "departed")
	assert_true(st.add_guest("ireena"))
	var beats := SideQuestPlay.play(st, "vallaki/gate:rules")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(_status(st, "escort_ireena"), "success", "the escort is over once she's inside the walls")
	assert_eq(st.quest_stage("sanctuary_for_ireena"), "arrived", "and the search for sanctuary begins")
	assert_eq(_status(st, "sanctuary_for_ireena"), "active")


## Sanctuary ends whichever way Ireena chooses: holy ground, or the road with the party.
func test_sanctuary_ends_when_ireena_chooses_the_road() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki", 12)
	st.set_quest_stage("sanctuary_for_ireena", "at_inn")
	assert_eq(_status(st, "sanctuary_for_ireena"), "active")
	assert_false((_entry(st, "sanctuary_for_ireena")["objectives"] as Array).is_empty(), "the inn says what's left to do")
	st.set_quest_stage("sanctuary_for_ireena", "travels_on")
	assert_eq(_status(st, "sanctuary_for_ireena"), "success")
	st.set_quest_stage("sanctuary_for_ireena", "leaving_vallaki")
	assert_eq(_status(st, "sanctuary_for_ireena"), "success")


## `quest.the_fine_print >= free` also held for Kip's failure ending (strahds_debtor comes after free), so his letter
## home about saving everyone, and his joy at a rotten apricot nobody owns, played after he sold his contract to Strahd.
func test_kips_freedom_scenes_need_him_free() -> void:
	var st := SideQuestPlay.party(["kip_smudgewick", "thistle"], 9, "vallaki", 20)
	var home := CampTalk.opening_condition(DialogueFile.load_key("camp/kip"), "talk_home")
	st.set_quest_stage("the_fine_print", "strahds_debtor")
	assert_false(StoryConditions.check(home, st), "no letter home about being free when Strahd holds the contract")
	assert_true(Banter._lines("banter/party_six:kip_free_apricots", st).is_empty(), "nor the free apricot")
	st.set_quest_stage("the_fine_print", "free")
	assert_true(StoryConditions.check(home, st), "the letter home once he's free")
	assert_false(Banter._lines("banter/party_six:kip_free_apricots", st).is_empty(), "and the apricot")


## A save writes its keys sorted, so after a load the journal came back in alphabetical order, and the HUD's newest
## objective (the last open quest's) became whichever open quest sorted last, not the one that moved last.
func test_the_journal_keeps_its_order_through_a_save() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 3, "vallaki", 12)
	st.set_quest_stage("the_priests_son", "heard")
	st.advance_minutes(30)
	st.set_quest_stage("escort_ireena", "departed")
	st.advance_minutes(30)
	st.set_quest_stage("sanctuary_for_ireena", "arrived")
	var before := _ids(st)
	assert_eq(before.back(), "sanctuary_for_ireena", "the quest that moved last is the newest open one")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(_ids(back), before, "the same order after a save and load")


func _ids(st: StoryState) -> Array:
	return QuestLog.journal(st).map(func(q: Dictionary) -> String: return str(q["id"]))


func _entry(st: StoryState, quest_id: String) -> Dictionary:
	for q in QuestLog.journal(st):
		if str(q["id"]) == quest_id:
			return q
	return {}


func _status(st: StoryState, quest_id: String) -> String:
	return str(_entry(st, quest_id).get("status", ""))
