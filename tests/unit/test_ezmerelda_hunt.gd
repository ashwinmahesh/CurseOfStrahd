extends TestCase
## Ezmerelda on the hunt (Story Allies Presence Plan, package M1; narrative/allies/ezmerelda_hunt.dialogue, data/visits/
## ezmerelda.json, her entries in data/locations/vallaki_blue_water_inn.json and van_richtens_tower.json). After the
## party tells her where Van Richten is she leaves her camp (ezmerelda_left_tower) and waits in the Blue Water Inn's
## stable yard; the reunion the tower would have played happens there. If he has left the inn before she finds him she is
## back on the shore and the tower's own scenes go on. While she is met and not travelling with the party she turns up
## three times in the middle of her own hunting (Svalich road at night, the Berez scarecrows, below Argynvostholt).

const INN := "vallaki_blue_water_inn"
const TOWER := "van_richtens_tower"
const YARD := "allies/ezmerelda_hunt:yard"
const BACK := "allies/ezmerelda_hunt:shore_return"
const AT_THE_TOWER := "van_richtens_tower/ezmerelda:start"
const QUEST := "the_hunters_tower"


func _party(location: String = INN) -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], 6, location, 12)


## The party has told Ezmerelda where Van Richten is: she left her camp that night.
func _left(st: StoryState) -> StoryState:
	st.set_flag("ezmerelda_met")
	st.set_flag("ezmerelda_met_at_tower")
	st.set_flag("ezmerelda_told_rictavio")
	st.set_flag("ezmerelda_left_tower")
	st.set_quest_stage(QUEST, "heard")
	st.set_quest_stage(QUEST, "told")
	return st


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


func _menu(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					out.append(str((o as Dictionary)["text"]))
	return out


func _has_option(beats: Array[Dictionary], words: String) -> bool:
	for t in _menu(beats):
		if t.contains(words):
			return true
	return false


# --- Where she stands --------------------------------------------------------------------------------------------------

func test_she_stays_at_her_camp_until_she_leaves_and_then_waits_in_the_yard_while_he_is_at_the_inn() -> void:
	var st := _party()
	assert_eq(SideQuestPlay.standing(st, TOWER, "ezmerelda"), AT_THE_TOWER, "at her camp")
	assert_eq(SideQuestPlay.standing(st, INN, "ezmerelda"), "", "not in Vallaki")
	_left(st)
	assert_eq(SideQuestPlay.standing(st, INN, "ezmerelda"), YARD, "in the stable yard, by his wagon")
	assert_eq(SideQuestPlay.standing(st, TOWER, "ezmerelda"), "", "her camp is empty")
	var yard := {}
	for n: Variant in Compendium.shared().get_entry("locations", INN)["npcs"]:
		if str((n as Dictionary)["npc"]) == "ezmerelda":
			yard = n as Dictionary
	assert_true(int(yard.get("approach", 0)) > 0, "she speaks first when the party comes into the yard")
	var cell := yard["cell"] as Array
	var rows := Compendium.shared().get_entry("locations", INN)["map"]["rows"] as Array
	assert_eq(str((rows[int(cell[1])] as String)[int(cell[0])]), ".", "and stands on open floor")


func test_she_is_back_on_the_shore_if_he_has_gone_when_she_looks_for_him() -> void:
	var gone := _left(_party())
	gone.set_flag("rictavio_gone")
	assert_eq(SideQuestPlay.standing(gone, INN, "ezmerelda"), "", "he went home: nobody in the yard")
	assert_eq(SideQuestPlay.standing(gone, TOWER, "ezmerelda"), BACK, "she is back at her camp")
	var along := _left(_party())
	assert_true(along.add_guest("rictavio"))
	assert_eq(SideQuestPlay.standing(along, INN, "ezmerelda"), "", "he walks with the party")
	assert_eq(SideQuestPlay.standing(along, TOWER, "ezmerelda"), BACK)
	var wachter := _left(_party())
	wachter.set_flag("vallaki_backed", "wachter")
	assert_eq(SideQuestPlay.standing(wachter, TOWER, "ezmerelda"), BACK, "the Baron's town sent him away: he is not at the inn")
	assert_eq(SideQuestPlay.standing(wachter, INN, "ezmerelda"), "")
	var ally := _left(_party())
	ally.set_flag("vallaki_backed", "wachter")
	ally.tarokka = {"ally": "artifact"}   # the cards name Rictavio: he stays at the inn, though the town bowed
	assert_eq(SideQuestPlay.standing(ally, INN, "ezmerelda"), YARD, "so she finds him")
	assert_eq(SideQuestPlay.standing(ally, TOWER, "ezmerelda"), "")


func test_once_she_is_back_at_camp_the_towers_own_entries_stand_as_if_she_never_left() -> void:
	var st := _left(_party())
	st.set_flag("rictavio_gone")
	st.set_flag("ezmerelda_back_at_camp")
	assert_eq(SideQuestPlay.standing(st, TOWER, "ezmerelda"), AT_THE_TOWER, "the tower's own scene")
	assert_eq(SideQuestPlay.standing(st, TOWER, "rictavio"), "", "not by the fire before they are reunited")
	st.set_flag("van_richten_reunited")
	assert_eq(SideQuestPlay.standing(st, TOWER, "rictavio"), "van_richtens_tower/van_richten:shore", "the pair at the fire")
	assert_eq(SideQuestPlay.standing(st, INN, "ezmerelda"), "", "and nobody in the yard")


func test_after_a_reunion_in_the_yard_she_stays_there_unless_he_goes_home() -> void:
	var st := _left(_party())
	st.set_flag("van_richten_reunited")
	st.set_flag("ezmerelda_reunited_in_vallaki")
	assert_eq(SideQuestPlay.standing(st, INN, "ezmerelda"), YARD, "still in the yard")
	assert_eq(SideQuestPlay.standing(st, TOWER, "ezmerelda"), "")
	assert_eq(SideQuestPlay.standing(st, TOWER, "rictavio"), "", "he is at his inn")
	st.set_flag("rictavio_gone")
	assert_eq(SideQuestPlay.standing(st, INN, "ezmerelda"), "", "he went home: she went with him")
	assert_eq(SideQuestPlay.standing(st, TOWER, "ezmerelda"), AT_THE_TOWER, "and the pair are at the fire on the shore")
	assert_eq(SideQuestPlay.standing(st, TOWER, "rictavio"), "van_richtens_tower/van_richten:shore")


func test_travelling_with_the_party_she_stands_nowhere() -> void:
	var st := _left(_party())
	assert_true(st.add_guest("ezmerelda"))
	assert_eq(SideQuestPlay.standing(st, INN, "ezmerelda"), "")
	assert_eq(SideQuestPlay.standing(st, TOWER, "ezmerelda"), "")


# --- The yard and the reunion -------------------------------------------------------------------------------------------

func test_the_first_talk_in_the_yard_has_her_say_why_she_has_not_gone_in_and_every_menu_has_an_exit() -> void:
	var st := _left(_party())
	var first := SideQuestPlay.play(st, YARD, ["Why haven't you gone inside"])
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true(_says(first, "singing to a turnip"), "first sight of her")
	assert_true(_says(first, "I'll shoot the hat first"), "and her answer")
	assert_true(bool(st.get_flag("ezmerelda_yard_met", false)))
	assert_false(bool(st.get_flag("van_richten_reunited", false)), "nothing happened to the reunion")
	assert_eq(st.quest_stage(QUEST), "told")
	var again := SideQuestPlay.play(st, YARD)
	assert_true(_says(again, "Still here, still counting feathers"), "back before the reunion")
	assert_true(_has_option(again, "bring him out"), "the way on")
	assert_eq(str(again[-1].get("kind", "")), "end", "and she lets the party go")
	assert_false(bool(st.get_flag("van_richten_reunited", false)))


func test_bringing_him_out_reunites_them_pays_once_and_leaves_a_hub() -> void:
	var st := _left(_party())
	var beats := SideQuestPlay.play(st, YARD, ["We can bring him out"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "Friends, I must warn you"), "he arrives in his act")
	assert_true(_says(beats, "Say something a vampire wouldn't say."), "her test")
	assert_true(_says(beats, "I am sorry."), "and his answer")
	assert_true(_says(beats, "hits him hard in the arm"), "the arm")
	assert_false(_says(beats, "You gave me your word"), "no promise was broken")
	assert_true(bool(st.get_flag("van_richten_reunited", false)), "the Hunter's Tower's own flag")
	assert_true(bool(st.get_flag("ezmerelda_reunited_in_vallaki", false)), "and the venue")
	assert_eq(st.quest_stage(QUEST), "reunited")
	assert_eq(int(st.get_flag("ezmerelda_trust", 0)), 2, "trust as at the tower")
	assert_true(bool(st.get_flag("ezmerelda_gift_given", false)), "her gift")
	assert_true(st.party_has_item("holy_water") and st.party_has_item("crossbow_bolt") and st.party_has_item("potion_of_healing_greater"))
	assert_true(st.party_has_item("glamoured_studded_leather__studded_leather_armor"), "and the coat")
	assert_eq(str(beats[-1].get("kind", "")), "end", "the scene ends")
	var hub := SideQuestPlay.play(st, YARD, ["How is Rudolph"])
	assert_true(_says(hub, "keeping watch on the wagon"), "afterwards she is the hub's")
	assert_true(_says(hub, "false moustache drying"), "and answers about him")
	assert_false(_says(hub, "Take these"), "the gift is not given twice")
	assert_true(_has_option(hub, "Hunt with us"), "she will hunt with the party (trust 2)")


func test_when_he_knows_the_party_knows_he_comes_out_as_himself_and_a_broken_promise_is_taken_on_her() -> void:
	var st := _left(_party())
	st.set_flag("rictavio_unmasked")
	var beats := SideQuestPlay.play(st, YARD, ["We can bring him out"])
	assert_true(_says(beats, "freezes with his hand still on the latch"), "unmasked")
	assert_false(_says(beats, "Friends, I must warn you"), "no showman act")
	assert_false(_says(beats, "You gave me your word"), "no promise to keep")
	var kept := _left(_party())
	kept.set_flag("rictavio_unmasked")
	kept.set_flag("rictavio_secret_kept")
	var promise := SideQuestPlay.play(kept, YARD, ["We can bring him out"])
	assert_true(_says(promise, "You gave me your word that name would not leave that room."))
	assert_true(_says(promise, "I wrung it out of them."), "she takes the blame")
	assert_true(bool(kept.get_flag("van_richten_reunited", false)))


func test_a_party_she_does_not_trust_gets_the_reunion_but_no_gift() -> void:
	var st := _left(_party())
	st.set_flag("ezmerelda_trust", -2)   # her wagon robbed
	SideQuestPlay.play(st, YARD, ["We can bring him out"])
	assert_true(bool(st.get_flag("van_richten_reunited", false)), "the reunion is not the party's to deny her")
	assert_eq(int(st.get_flag("ezmerelda_trust", 0)), 0)
	assert_false(bool(st.get_flag("ezmerelda_gift_given", false)), "but the gift waits for trust")
	var hub := SideQuestPlay.play(st, YARD)
	assert_false(_has_option(hub, "Hunt with us"), "and so does hunting together")


func test_hunting_with_the_party_from_the_yard_joins_her_and_ends_the_tower_quest_when_it_was_searched_empty() -> void:
	var st := _left(_party())
	SideQuestPlay.play(st, YARD, ["We can bring him out"])
	SideQuestPlay.play(st, YARD, ["Hunt with us"])
	assert_true("ezmerelda" in st.guest_ids, "she walks with the party")
	assert_eq(st.quest_stage(QUEST), "reunited")
	var searched := _party(TOWER)
	searched.set_flag("ezmerelda_met")
	searched.set_flag("ezmerelda_trust", 2)
	searched.set_quest_stage(QUEST, "heard")
	searched.set_quest_stage(QUEST, "inside")
	SideQuestPlay.play(searched, "allies/ezmerelda_hunt:join")
	assert_true("ezmerelda" in searched.guest_ids)
	assert_eq(searched.quest_stage(QUEST), "with_her", "as at the tower: searched and empty")
	var upstairs := _party(TOWER)
	upstairs.set_flag("rictavio_gone")
	upstairs.set_flag("ezmerelda_trust", 2)
	upstairs.set_quest_stage(QUEST, "heard")
	upstairs.set_quest_stage(QUEST, "inside")
	SideQuestPlay.play(upstairs, "allies/ezmerelda_hunt:join")
	assert_ne(upstairs.quest_stage(QUEST), "with_her", "but not while he is upstairs: the reunion ends it")


# --- If he has gone ------------------------------------------------------------------------------------------------------

func test_back_at_camp_she_sends_the_party_in_and_the_towers_reunion_works_again() -> void:
	var st := _left(_party(TOWER))
	st.set_flag("rictavio_gone")
	st.set_quest_stage(QUEST, "inside")
	# Before she comes back, Van Richten has no word about her outside.
	var before := SideQuestPlay.play(st, "van_richtens_tower/van_richten:menu")
	assert_false(_has_option(before, "Ezmerelda is outside"), "she left for Vallaki: nobody is outside")
	var beats := SideQuestPlay.play(st, BACK)
	assert_true(_says(beats, "the bird had already flown"), "her return")
	assert_true(_says(beats, "chopping the door into kindling"), "and her message for him")
	assert_true(bool(st.get_flag("ezmerelda_back_at_camp", false)))
	assert_eq(str(beats[-1].get("kind", "")), "end", "the tower's menu lets her go")
	var after := SideQuestPlay.play(st, "van_richtens_tower/van_richten:menu", ["Ezmerelda is outside", "She'll get in eventually"])
	assert_eq(SideQuestPlay.missing(after), "")
	assert_true(bool(st.get_flag("van_richten_reunited", false)), "the tower's own reunion")
	assert_eq(st.quest_stage(QUEST), "reunited")
	assert_false(bool(st.get_flag("ezmerelda_reunited_in_vallaki", false)), "not the yard's")
	assert_eq(SideQuestPlay.standing(st, TOWER, "rictavio"), "van_richtens_tower/van_richten:shore", "they sit by the fire")
	var fire := SideQuestPlay.play(st, AT_THE_TOWER)
	assert_true(_says(fire, "He's making tea"), "her own scene afterwards")
	var shore := SideQuestPlay.play(st, "van_richtens_tower/van_richten:shore")
	assert_true(_says(shore, "He's agreed. He just doesn't know it yet."), "and his: she did not leave for good")


func test_back_at_camp_with_him_beside_the_party_the_reunion_plays_and_she_does_not_send_them_away() -> void:
	var st := _left(_party(TOWER))
	assert_true(st.add_guest("rictavio"))
	var beats := SideQuestPlay.play(st, BACK)
	assert_true(_says(beats, "empty yard"), "she walked to Vallaki for nothing")
	assert_true(_says(beats, "You look like a chicken that's been to a wedding"), "and the tower's reunion plays")
	assert_true(bool(st.get_flag("van_richten_reunited", false)))
	assert_false(_says(beats, "Now go away"), "she does not dismiss them now that he is here")
	assert_eq(int(st.get_flag("ezmerelda_trust", 0)), 2)
	assert_true(bool(st.get_flag("ezmerelda_gift_given", false)), "and her gift comes with it")


func test_the_towers_first_meeting_is_unchanged() -> void:
	var st := _party(TOWER)
	var beats := SideQuestPlay.play(st, AT_THE_TOWER, ["We know where Van Richten is"])
	assert_true(_says(beats, "Say something a vampire wouldn't say."), "she greets them as she always did")
	var told := _party(TOWER)
	told.set_flag("ezmerelda_met_at_tower")
	told.set_flag("ezmerelda_met")
	told.set_flag("van_richten_identity_known")
	told.set_quest_stage(QUEST, "heard")
	told.set_quest_stage(QUEST, "inside")
	var tell := SideQuestPlay.play(told, AT_THE_TOWER, ["We know where Van Richten is", "He's at the Blue Water Inn"])
	assert_eq(SideQuestPlay.missing(tell), "")
	assert_true(_says(tell, "Now go away. I have a wagon to hitch"), "telling her still sends her off to Vallaki")
	assert_true(bool(told.get_flag("ezmerelda_left_tower", false)))
	assert_false(bool(told.get_flag("ezmerelda_back_at_camp", false)))


# --- On the road ---------------------------------------------------------------------------------------------------------

const ROAD_NIGHT := {"location": "svalich_crossroads", "night": true}


func _met(st: StoryState) -> StoryState:
	st.set_flag("ezmerelda_met")
	return st


func test_the_svalich_meeting_comes_at_night_on_the_road_or_at_a_camp_beside_it() -> void:
	StrahdPresence.use({})
	var st := _met(_party("svalich_crossroads"))
	assert_true(StrahdPresence.due(st, "arrive", {"location": "svalich_crossroads", "night": false}).is_empty(), "not by day")
	assert_true(StrahdPresence.due(st, "arrive", {"location": "tser_pool", "night": true}).is_empty(), "not in her people's camp")
	assert_true(StrahdPresence.due(st, "arrive", {"location": "vallaki", "night": true}).is_empty(), "not in the town")
	var v := StrahdPresence.due(st, "arrive", ROAD_NIGHT)
	assert_eq(str(v.get("id", "")), "ezmerelda_svalich_staking")
	assert_true(StrahdPresence.is_ally(v), "an ally's visit")
	assert_eq(str(StrahdPresence.begin(st, v).get("dialogue", "")), "allies/ezmerelda_hunt:road_svalich")
	st.minute_of_day += 13 * 60
	assert_true(StrahdPresence.due(st, "arrive", ROAD_NIGHT).is_empty(), "once")
	var camped := _met(_party("roadside_graves"))
	var c := StrahdPresence.due(camped, "rest", {"location": "roadside_graves", "night": true})
	assert_eq(str(c.get("id", "")), "ezmerelda_svalich_staking", "a Long Rest through the night beside the road")
	assert_false(StrahdPresence.may_fight(c), "words only: the rest goes on")


func test_the_berez_and_argynvostholt_meetings_wait_for_what_they_show() -> void:
	StrahdPresence.use({})
	var berez := _met(_party("berez"))
	assert_eq(str(StrahdPresence.due(berez, "arrive", {"location": "berez"}).get("id", "")), "ezmerelda_berez_scarecrows")
	var burned := _met(_party("berez"))
	burned.set_flag("berez_scarecrows_burned")
	assert_true(StrahdPresence.due(burned, "arrive", {"location": "berez"}).is_empty(), "nothing left to cut down")
	var dead := _met(_party("berez"))
	dead.set_flag("lysaga_dead")
	assert_true(StrahdPresence.due(dead, "arrive", {"location": "berez"}).is_empty(), "the witch is dead")
	var manor := _met(_party("argynvostholt"))
	assert_true(StrahdPresence.due(manor, "arrive", {"location": "argynvostholt_hall"}).is_empty(), "outside, not in the hall")
	assert_eq(str(StrahdPresence.due(manor, "arrive", {"location": "argynvostholt"}).get("id", "")), "ezmerelda_manor_watch")
	var lit := _met(_party("argynvostholt"))
	lit.set_flag("argynvost_beacon_lit")
	assert_true(StrahdPresence.due(lit, "arrive", {"location": "argynvostholt"}).is_empty(), "the beacon burns: no revenants to watch")


func test_she_turns_up_only_when_she_has_been_met_and_is_not_travelling_with_the_party() -> void:
	StrahdPresence.use({})
	var strangers := _party("berez")
	assert_true(StrahdPresence.due(strangers, "arrive", {"location": "berez"}).is_empty(), "never met")
	var along := _met(_party("berez"))
	assert_true(along.add_guest("ezmerelda"))
	assert_true(StrahdPresence.due(along, "arrive", {"location": "berez"}).is_empty(), "already with them")


func test_a_meeting_raises_her_trust_by_one_and_ends_in_a_menu_with_a_way_out() -> void:
	for scene: String in ["road_svalich", "road_berez", "road_manor"]:
		var st := _met(_party())
		var beats := SideQuestPlay.play(st, "allies/ezmerelda_hunt:" + scene)
		assert_eq(int(st.get_flag("ezmerelda_trust", 0)), 1, scene + ": trust")
		assert_eq(str(beats[-1].get("kind", "")), "end", scene + ": the scene ends")
		assert_false(_has_option(beats, "Hunt with us"), scene + ": not trusted enough to hunt together")
		assert_false(bool(st.get_flag("ezmerelda_gift_given", false)), scene + ": and no gift yet")
		var again := _met(_party())
		again.set_flag("ezmerelda_trust", 1)
		var second := SideQuestPlay.play(again, "allies/ezmerelda_hunt:" + scene)
		assert_true(_has_option(second, "Hunt with us"), scene + ": the second meeting is trusted enough")
		assert_true(bool(again.get_flag("ezmerelda_gift_given", false)), scene + ": her gift on the way out")


func test_hunt_with_us_on_the_road_joins_her_unless_she_is_waiting_at_the_inn_for_him() -> void:
	var st := _met(_party())
	st.set_flag("ezmerelda_trust", 1)
	SideQuestPlay.play(st, "allies/ezmerelda_hunt:road_berez", ["Hunt with us"])
	assert_true("ezmerelda" in st.guest_ids, "she walks with the party")
	var waiting := _left(_party())
	waiting.set_flag("ezmerelda_trust", 1)
	var beats := SideQuestPlay.play(waiting, "allies/ezmerelda_hunt:road_manor", ["Hunt with us"])
	assert_true(_says(beats, "Not until I've looked Rudolph in the eye"), "she will not go before the reunion")
	assert_false("ezmerelda" in waiting.guest_ids)
	assert_true(_says(beats, "Blue Water Inn's stable yard"), "and says where to find her")


func test_her_answer_about_rudolph_depends_on_where_the_two_of_them_stand() -> void:
	var seeking := _met(_party())
	var s := SideQuestPlay.play(seeking, "allies/ezmerelda_hunt:road_svalich", ["Have you found any sign of your teacher"])
	assert_true(_says(s, "cold ashes and bad lies"), "still looking")
	var waiting := _left(_party())
	var w := SideQuestPlay.play(waiting, "allies/ezmerelda_hunt:road_svalich", ["Have you gone in to speak with Rudolph"])
	assert_true(_says(w, "so I don't have to knock"), "at the inn, with no nerve to knock")
	var gone := _left(_party())
	gone.set_flag("rictavio_gone")
	var g := SideQuestPlay.play(gone, "allies/ezmerelda_hunt:road_svalich", ["Have you found any sign of your teacher"])
	assert_true(_says(g, "cold ashes and bad lies"), "he left the inn: she is looking again")
	var reunited := _left(_party())
	reunited.set_flag("van_richten_reunited")
	var r := SideQuestPlay.play(reunited, "allies/ezmerelda_hunt:road_svalich", ["How is Rudolph holding up"])
	assert_true(_says(r, "completely unbearable"), "reconciled")


func test_the_story_bot_leaves_each_meeting_by_its_goodbye() -> void:
	for scene: String in ["road_svalich", "road_berez", "road_manor"]:
		var r := DialogueRunner.new(_met(_party()), DiceRoller.new(5))
		assert_true(r.start("allies/ezmerelda_hunt:" + scene))
		var b := r.next()
		for i in 20:
			if str(b["kind"]) == "options":
				break
			b = r.next()
		assert_eq(str(b["kind"]), "options", scene + " asks")
		var opts := b["options"] as Array
		var at := AllyVisitAnswer.exit_option(r, opts)
		assert_true(at >= 0, scene + ": the bot has a way out")
		assert_eq(str((opts[at] as Dictionary)["text"]), "Goodbye.", scene + ": and it is the goodbye")
