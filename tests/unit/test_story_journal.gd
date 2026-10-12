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


## Strahd's first visit to Marina's monument in Berez is once only, so a party that met him there before it learned
## what Baba Lysaga did could never tell him, one of the three ways The Witch of Berez offers (SL-17). He comes back by
## night until he's told.
func test_strahd_comes_back_to_hear_about_marina() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "berez", 22)
	assert_eq(SideQuestPlay.standing(st, "berez", "strahd"), "berez/marina:strahd", "the first night, he's at the monument")
	var beats := SideQuestPlay.play(st, "berez/marina:strahd", ["leave you with her"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.standing(st, "berez", "strahd"), "", "not again while there's nothing to tell him")
	st.set_flag("marina_truth_known")
	st.set_quest_stage("the_witch_of_berez", "truth")
	assert_eq(SideQuestPlay.standing(st, "berez", "strahd"), "berez/marina:strahd_again", "back by night once the party knows")
	st.advance_minutes(14 * 60)
	assert_eq(SideQuestPlay.standing(st, "berez", "strahd"), "", "but only by night")
	st.advance_minutes(10 * 60)
	beats = SideQuestPlay.play(st, "berez/marina:strahd_again", ["Your nurse did"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_witch_of_berez"), "strahd_told")
	assert_eq(SideQuestPlay.standing(st, "berez", "strahd"), "", "and once he's told, he's gone")


## Black Roses (Ashwin, 2026-10-12): winning the fight with Catalina and her girls, at the Petrovs' window or at their
## graves, left the journal at "Find where Catalina sleeps", and only her father, out on his lamp rounds, could end it.
## Every one of those fights moves the quest to "Tell Ignat" now, and he ends it.
func test_black_roses_says_to_tell_ignat_after_the_fight() -> void:
	var fights := 0
	for e: Variant in Compendium.shared().get_entry("locations", "vallaki")["encounters"]:
		var spec := e as Dictionary
		if str(spec["id"]) in ["roses_street", "roses_graves"]:
			fights += 1
			var q := spec.get("quest", {}) as Dictionary
			assert_eq("%s:%s" % [q.get("id", ""), q.get("stage", "")], "black_roses:slain", "%s moves the quest on" % spec["id"])
	assert_true(fights >= 2, "the street fight and the graves fight")
	var st := SideQuestPlay.party(["ilse_varga"], 6, "vallaki", 22)
	st.set_quest_stage("black_roses", "vigil")
	st.set_flag("roses_spawn_destroyed")
	st.set_quest_stage("black_roses", "slain")   # what winning either fight does
	assert_eq(_status(st, "black_roses"), "active")
	assert_true(str((_entry(st, "black_roses")["objectives"] as Array)[0]).contains("Ignat"), "the journal says who to tell")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_lamplighter"), "vallaki/townsfolk:lamplighter", "he's on his rounds")
	SideQuestPlay.play(st, "vallaki/townsfolk:lamplighter")
	assert_eq(_status(st, "black_roses"), "success")
	assert_true(st.party_has_item("ring_of_resistance_necrotic"), "his wife's ring")


## Ribbons (Ashwin, 2026-10-12): Daciana left the square for good when the festival ended, so a Ribbons begun before it
## could never move on. She stays in the square by day while the quest is open.
func test_daciana_stays_while_ribbons_is_open() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki", 12)
	st.set_flag("festival_over")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_ribbon_girl"), "", "no ribbons after the festival")
	st.set_quest_stage("ribbons", "rumored")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_ribbon_girl"), "vallaki/townsfolk:ribbon_girl",
		"but she's in the square while Ribbons is open")
	var beats := SideQuestPlay.play(st, "vallaki/townsfolk:ribbon_girl", ["We'll see who comes"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("ribbons"), "asked", "she says where the lists go")
	assert_true(SideQuestPlay.shown(st, "vallaki", "ribbon_lamp"))


## Izek (Ashwin, 2026-10-12): telling him Ireena is his sister ends his quest, but asking Blinsky about the dolls
## afterwards moved it back to "Learn what Izek wants with her". A finished quest stays finished now: no line moves it
## back to an earlier open stage, though it can still reach another ending.
func test_a_finished_quest_stays_finished() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki", 12)
	st.set_quest_stage("izek_obsession", "noticed")
	st.set_quest_stage("izek_obsession", "truth_told")
	st.set_flag("izek_dolls_seen")
	SideQuestPlay.play(st, "vallaki/blinsky:dolls")
	assert_eq(st.quest_stage("izek_obsession"), "truth_told", "Blinsky's dolls don't reopen it")
	assert_false(st.set_quest_stage("izek_obsession", "truth_guessed"), "nor does any other line")
	assert_eq(_status(st, "izek_obsession"), "success")
	assert_true(st.set_quest_stage("izek_obsession", "izek_slain"), "another ending still can")


## Saves from before these fixes catch up when loaded: a Black Roses fight already won moves the quest to "Tell
## Ignat", and a quest moved back out of its ending goes back to it (Ashwin's save had both).
func test_old_saves_catch_up() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "vallaki", 13)
	st.set_quest_stage("black_roses", "vigil")
	st.set_flag("roses_spawn_destroyed")
	(st.loc_state("vallaki")["encounters"] as Dictionary)["roses_graves"] = true
	st.set_quest_stage("izek_obsession", "noticed")
	st.set_quest_stage("izek_obsession", "truth_told")
	var izek := st.quests["izek_obsession"] as Dictionary
	izek["stage"] = "dolls_found"   # what Blinsky's line did before
	(izek["history"] as Array).append("dolls_found")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(back.quest_stage("black_roses"), "slain")
	assert_eq(back.quest_stage("izek_obsession"), "truth_told")


## A save made mid-fight holds the fight as "started", not won: it loads without an error, and the quest stays where
## it was until the fight is won (Game build's fix forward c90b0d531; StoryBot's _reload_fight hit it).
func test_a_save_mid_fight_loads_and_waits_for_the_win() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "vallaki", 23)
	st.set_quest_stage("black_roses", "vigil")
	(st.loc_state("vallaki")["encounters"] as Dictionary)["roses_graves"] = "started"
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(back.quest_stage("black_roses"), "vigil", "a fight under way hasn't been won")
	assert_eq(str((back.loc_state("vallaki")["encounters"] as Dictionary)["roses_graves"]), "started", "and stays under way")


func _ids(st: StoryState) -> Array:
	return QuestLog.journal(st).map(func(q: Dictionary) -> String: return str(q["id"]))


func _entry(st: StoryState, quest_id: String) -> Dictionary:
	for q in QuestLog.journal(st):
		if str(q["id"]) == quest_id:
			return q
	return {}


func _status(st: StoryState, quest_id: String) -> String:
	return str(_entry(st, quest_id).get("status", ""))
