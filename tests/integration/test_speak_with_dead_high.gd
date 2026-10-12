extends TestCase
## Speak with Dead in the high places (docs/story/talking_creatures.md, batch 4): Marina in Berez, the last sister in
## the abbey garden, the first Pidlwick and a shackled prisoner in Castle Ravenloft, Sergei in his tomb, and a traveller
## frozen inside the Amber Temple's doors. Liriel prepares the spell; each conversation casts it with a 3rd-level slot.


func _party(location: String, hour: int = 12) -> StoryState:
	var st := SideQuestPlay.party(["liriel_dawnsong", "thistle"], 9, location, hour)
	((st.party[0].spellcasting[0] as Dictionary)["prepared"] as Array).append("speak_with_dead")
	return st


func _found(st: StoryState, location: String, prop: String) -> bool:
	return bool((st.loc_state(location)["found"] as Dictionary).get(prop, false))


func _offered(beats: Array[Dictionary], text: String) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options" and (b["options"] as Array).any(
		func(o: Variant) -> bool: return str((o as Dictionary)["text"]).contains(text)))


func _speak(st: StoryState, ref: String) -> Array[Dictionary]:
	var slots := st.party[0].slots_left(3)
	var beats := SideQuestPlay.play(st, ref, ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.party[0].slots_left(3), slots - 1, "a 3rd-level slot")
	return beats


func test_marina_heard_the_witch_singing() -> void:
	var st := _party("berez_marinas_monument")
	_speak(st, "berez/marina:bier")
	assert_true(bool(st.get_flag("marina_truth_known", false)), "as the Arcana deduction would")
	assert_eq(st.quest_stage("the_witch_of_berez"), "truth")


func test_the_last_sister_knew_what_the_abbot_is_and_where_the_holy_water_is() -> void:
	var st := _party("abbey_of_st_markovia_garden")
	_speak(st, "abbey_of_st_markovia/nuns_graves:graves")
	assert_true(bool(st.get_flag("abbot_nature_known", false)))
	assert_true(_found(st, "abbey_of_st_markovia_garden", "grave_holy_water"))


func test_the_first_pidlwick_says_who_pushed_him() -> void:
	var st := _party("castle_ravenloft_catacombs")
	_speak(st, "castle_ravenloft/catacombs_jester:crypt")
	assert_true(bool(st.get_flag("pidlwick_crypt_told", false)))
	assert_true(_found(st, "castle_ravenloft_catacombs", "jester_cape"), "the cape under the false bottom")
	st.location = "castle_ravenloft_spires"
	assert_true(_offered(SideQuestPlay.play(st, "castle_ravenloft/spires_pidlwick:menu"), "We know what happened to the first Pidlwick"))


func test_the_prisoner_heard_of_the_heart_and_warns_of_the_floor() -> void:
	var st := _party("castle_ravenloft_larders_dungeon")
	_speak(st, "castle_ravenloft/larders_prisoner:skeleton")
	assert_eq(st.quest_stage("the_heart_of_sorrow"), "heard")
	assert_eq(str((st.loc_state("castle_ravenloft_larders_dungeon")["traps"] as Dictionary).get("larders_open_cell_pit", "")), "found",
		"a warned-of trap shows as found")


func test_sergei_sends_tatyana_to_the_pool() -> void:
	var st := _party("castle_ravenloft_catacombs_tombs")
	_speak(st, "castle_ravenloft/catacombs_sergei:sarcophagus")
	assert_true(bool(st.get_flag("sergei_spoke", false)))
	assert_eq(st.quest_stage("the_pool_of_the_white_sun"), "rumored")


func test_the_frozen_traveller_gives_up_the_sword() -> void:
	var st := _party("amber_temple_entrance")
	_speak(st, "amber_temple/frozen_traveller:traveller")
	assert_true(_found(st, "amber_temple_entrance", "frozen_hand_sword"))
