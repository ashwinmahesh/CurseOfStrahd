extends TestCase
## The Village of Barovia's side quests (docs/story/side_quests.md): the rumours that start them, The Polite Caller
## (Teodor at Ileana's shutter) and Cut After Noon (the walking firewood), played through their conversations with the
## rewards arriving once, the fights' level variants, and the rumour wiring for quests already in the game.

const VILLAGE := "village_of_barovia"


func _party(level: int = 3) -> StoryState:
	var st := StoryState.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		st.party.append(Pregens.build(id, level))
	st.location = VILLAGE
	st.minute_of_day = 10 * 60
	return st


## Plays `ref`, taking at each menu the first enabled option whose text contains the next of `picks` (in order), and
## the last option once the picks run out. Returns every beat.
func _play(st: StoryState, ref: String, picks: Array[String] = [], seed: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(seed))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	var left := picks.duplicate()
	for i in 400:
		out.append(b)
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var pick := opts.size() - 1
				if not left.is_empty():
					var want := str(left.pop_front())
					pick = -1
					for j in opts.size():
						if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
							pick = j
							break
					assert_true(pick >= 0, "an option containing '%s' at %s: %s" % [want, ref, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
					if pick < 0:
						break
				b = r.choose(pick)
			_:
				b = r.next()
	return out


func _combat_of(beats: Array[Dictionary]) -> String:
	return str(beats[-1].get("combat", "")) if not beats.is_empty() else ""


func _text(beats: Array[Dictionary]) -> String:
	var all := ""
	for b in beats:
		all += str(b.get("text", "")) + "\n"
	return all


## The encounter a location would start for `id` now: the first entry whose condition holds.
func _encounter(st: StoryState, id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", VILLAGE)["encounters"]:
		var enc := e as Dictionary
		if str(enc["id"]) == id and StoryConditions.check(str(enc.get("when", "")), st):
			return enc
	return {}


## Who stands in the village now, by NPC id: the dialogue of the first entry whose condition holds.
func _standing(st: StoryState, npc: String) -> String:
	for n: Variant in Compendium.shared().get_entry("locations", VILLAGE)["npcs"]:
		var e := n as Dictionary
		if str(e["npc"]) != npc or not StoryConditions.check(str(e.get("when", "")), st):
			continue
		var hours := e.get("hours", []) as Array
		if not hours.is_empty():
			var h := st.minute_of_day / 60
			var from := int(hours[0])
			var to := int(hours[1])
			if not (h >= from and h < to if from < to else h >= from or h < to):
				continue
		return str(e["dialogue"])
	return ""


func _xp(enc: Dictionary) -> int:
	const XP := {0.125: 25, 0.25: 50, 0.5: 100, 1.0: 200, 2.0: 450, 3.0: 700, 4.0: 1100, 5.0: 1800}
	var total := 0
	for m: Variant in enc["monsters"]:
		var cr := float(Compendium.shared().get_entry("monsters", str((m as Dictionary)["monster"]))["cr"])
		total += int(XP.get(cr, 0))
	return total


# --- Rumours ---

func test_the_village_gossips_start_both_quests() -> void:
	var st := _party()
	var beats := _play(st, "village_of_barovia/townsfolk:vasile", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("polite_caller"), "rumored")
	assert_eq(st.quest_stage("cut_after_noon"), "rumored")
	assert_true(bool(st.get_flag("teodor_rumor", false)) and bool(st.get_flag("luca_rumor", false)))
	assert_true(_text(beats).contains("shutter"), "Ileana's shutter is the first rumour")
	# Asked again once both are under way: neither stage goes back to "rumored".
	st.set_quest_stage("polite_caller", "vigil")
	st.set_quest_stage("cut_after_noon", "seedwood")
	_play(st, "village_of_barovia/townsfolk:petre", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("polite_caller"), "vigil")
	assert_eq(st.quest_stage("cut_after_noon"), "seedwood")


func test_bildrath_and_arik_point_at_quests_old_and_new() -> void:
	var st := _party()
	_play(st, "village_of_barovia/bildrath:start", ["Heard anything interesting?", "pastry cart", "weeping", "Grigore", "Enough news", "Goodbye"])
	assert_true(bool(st.get_flag("bonegrinder_rumor", false)), "Morgantha's mill goes on the map")
	assert_eq(st.quest_stage("find_gertruda"), "heard", "Mary's daughter is in the journal")
	assert_eq(st.quest_stage("cut_after_noon"), "rumored", "Grigore's wood is Bildrath's story too")
	var st2 := _party()
	_play(st2, "village_of_barovia/arik:start", ["Where does the wine come from?", "Heard anything interesting?", "Goodbye"])
	assert_eq(st2.quest_stage("wizard_of_wines"), "rumored", "the dry tavern starts The Wizard of Wines")
	assert_eq(st2.quest_stage("cut_after_noon"), "rumored")


# --- The Polite Caller ---

func test_teodor_holds_the_door_and_sees_the_sunrise() -> void:
	var st := _party()
	st.set_flag("teodor_rumor")
	st.set_quest_stage("polite_caller", "rumored")
	_play(st, "village_of_barovia/townsfolk:widow", ["shutter open at night", "sit up with you"])
	assert_eq(st.quest_stage("polite_caller"), "asked")
	_play(st, "village_of_barovia/townsfolk:widow", ["wait with her until dark"])
	assert_true(st.is_night(), "the wait runs on to night")
	assert_eq(_standing(st, "teodor"), "village_of_barovia/polite_caller:teodor", "Teodor comes to the shutter")
	var beats := _play(st, "village_of_barovia/polite_caller:teodor", ["Why do you come here", "hold this door together"])
	assert_eq(_combat_of(beats), "teodor_errand", "the master's errand arrives")
	assert_true("teodor" in st.guest_ids, "Teodor stands with the party")
	assert_eq(st.quest_stage("polite_caller"), "the_errand")
	# The fight's victory, as the location sets it.
	st.set_flag("teodor_errand_beaten")
	st.set_quest_stage("polite_caller", "held")
	assert_eq(_standing(st, "barovia_widow"), "village_of_barovia/polite_caller:dawn", "Ileana comes to the party after it")
	var dawn := _play(st, "village_of_barovia/polite_caller:dawn", ["sunrise"])
	assert_eq(str(st.get_flag("teodor_fate", "")), "dawn")
	assert_eq(st.quest_stage("polite_caller"), "dawn")
	assert_false("teodor" in st.guest_ids, "he leaves the party at dawn")
	assert_true(bool(st.get_flag("teodor_cache_known", false)), "he tells you about his grave")
	assert_true(_text(dawn).contains("asked him in"), "Ileana says what she'd have done")
	var grave := {}
	for c: Variant in Compendium.shared().get_entry("locations", VILLAGE)["containers"]:
		if str((c as Dictionary)["id"]) == "teodor_grave":
			grave = c as Dictionary
	assert_true(StoryConditions.check(str(grave["when"]), st), "the cache opens once he has told you")
	assert_eq(int(grave["gold"]), 90)
	assert_true((grave["items"] as Array).any(func(i: Variant) -> bool: return str((i as Dictionary)["id"]) == "shield_plus_1"))
	assert_eq(_standing(st, "barovia_widow"), "", "nobody waits at the door once it's over (before her hours)")
	st.minute_of_day = 10 * 60
	var after := _play(st, "village_of_barovia/townsfolk:widow")
	assert_true(_text(after).contains("never any news"), "by day she tells them both the news")


func test_ending_teodor_before_the_fight_still_brings_the_errand() -> void:
	var st := _party()
	st.set_quest_stage("polite_caller", "asked")
	st.set_flag("teodor_vigil")
	st.minute_of_day = 22 * 60
	var beats := _play(st, "village_of_barovia/polite_caller:teodor", ["Draw steel", "End him now"])
	assert_eq(_combat_of(beats), "teodor_errand")
	assert_eq(str(st.get_flag("teodor_fate", "")), "ended")
	assert_false("teodor" in st.guest_ids)
	assert_true(bool(st.get_flag("teodor_cache_known", false)), "his last words are about the grave")
	st.set_flag("teodor_errand_beaten")
	_play(st, "village_of_barovia/polite_caller:dawn")
	assert_eq(st.quest_stage("polite_caller"), "ended")
	assert_eq(st.attitude("barovia_widow"), "hostile")


func test_the_errand_is_hard_at_every_level() -> void:
	# 2024 DMG budgets for four characters: level 3 High 1,600; level 4 High 2,000.
	for level: int in [2, 3, 4, 5]:
		var st := _party(level)
		var enc := _encounter(st, "teodor_errand")
		assert_false(enc.is_empty(), "a variant for level %d" % level)
		var spawn := (enc["monsters"] as Array).filter(func(m: Variant) -> bool: return str((m as Dictionary)["monster"]) == "vampire_spawn")
		assert_eq(spawn.size(), 1, "one coachman at level %d" % level)
	assert_true(_xp(_encounter(_party(4), "teodor_errand")) >= 2000, "High or more at level 4")
	assert_true(_xp(_encounter(_party(3), "teodor_errand")) >= 1600, "High or more at level 3 (before his reduced HP)")


# --- Cut After Noon ---

func test_the_late_wood_burned_by_day_and_luca_woken() -> void:
	var st := _party()
	st.set_flag("luca_rumor")
	st.set_quest_stage("cut_after_noon", "rumored")
	_play(st, "village_of_barovia/townsfolk:woodcutter", ["heard about your lad", "look at the wood"])
	assert_eq(st.quest_stage("cut_after_noon"), "asked")
	assert_eq(_standing(st, "barovia_luca"), "village_of_barovia/cut_after_noon:luca_look", "Luca sleeps in the yard")
	# The grain read (a Nature check), as the pile would give it.
	st.set_flag("seedwood_known")
	st.set_quest_stage("cut_after_noon", "seedwood")
	_play(st, "village_of_barovia/bildrath:start", ["wood you bought from Grigore", "blight-wood"])
	assert_true(bool(st.get_flag("bildrath_wood_taken", false)), "Bildrath hands his load over")
	st.gold = 50
	var beats := _play(st, "village_of_barovia/townsfolk:woodcutter", ["Burn the lot", "ten gold"])
	assert_eq(_combat_of(beats), "woodpile_burns")
	assert_eq(roundi(st.gold), 40, "ten gold for Grigore's winter")
	assert_false(st.is_night(), "burned by day")
	st.set_flag("late_wood_burned")
	st.set_quest_stage("cut_after_noon", "burned")
	assert_eq(_standing(st, "barovia_woodcutter"), "village_of_barovia/cut_after_noon:splinter")
	var woke := _play(st, "village_of_barovia/cut_after_noon:splinter", ["Just pull it out", "Take it"])
	assert_true(bool(st.get_flag("luca_awake", false)))
	assert_eq(st.quest_stage("cut_after_noon"), "luca_woke")
	assert_true(bool(st.get_flag("yester_hill_known", false)), "Luca's story puts Yester Hill on the map")
	assert_true(_text(woke).contains("bear's hide"))
	assert_eq(roundi(st.gold), 80, "Grigore's forty")
	# Grigore pays once.
	_play(st, "village_of_barovia/cut_after_noon:grigore_reward")
	assert_eq(roundi(st.gold), 80)
	# Bildrath's hush money.
	assert_false(st.party_has_item("wraps_of_unarmed_power_plus_1"))
	_play(st, "village_of_barovia/bildrath:start", ["About that firewood"])
	assert_true(st.party_has_item("wraps_of_unarmed_power_plus_1"), "the monk's wraps")
	assert_true(bool(st.get_flag("bildrath_discount", false)), "and ten percent off")
	var again := _play(st, "village_of_barovia/bildrath:start")
	assert_false(_text(again).contains("monk left these"), "he pays once")


func test_waiting_for_dusk_wakes_the_woodpile() -> void:
	var st := _party()
	st.set_quest_stage("cut_after_noon", "seedwood")
	st.set_flag("seedwood_known")
	var beats := _play(st, "village_of_barovia/townsfolk:woodcutter", ["sit with Luca till dark"])
	assert_eq(_combat_of(beats), "woodpile_wakes")
	assert_true(st.is_night())
	var enc := _encounter(st, "woodpile_wakes")
	assert_true((enc["monsters"] as Array).any(func(m: Variant) -> bool: return str((m as Dictionary)["monster"]) == "shambling_mound"),
		"the woodpile stands up as one thing")
	assert_eq(str((enc["quest"] as Dictionary)["stage"]), "stood_up")
	st.set_flag("gulthias_tree_burned")
	st.set_flag("woodpile_beaten")
	var woke := _play(st, "village_of_barovia/cut_after_noon:splinter", ["Just pull it out", "Keep it"])
	assert_false(bool(st.get_flag("yester_hill_known", false)), "no new lead once the hill has burned")
	assert_true(_text(woke).contains("burned his hill"))
