extends TestCase
## Six Feet (docs/story/side_quests.md): Arik's rumour, Old Mihail's weekly graves, Goodwife Petra's story of the bride
## in the well, bringing Zinaida up (talked down by her name, or a fight), and the burial that pays once.


func _party(level: int = 3) -> StoryState:
	var st := StoryState.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		st.party.append(Pregens.build(id, level))
	st.location = "village_of_barovia"
	st.minute_of_day = 11 * 60
	return st


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


func _text(beats: Array[Dictionary]) -> String:
	var all := ""
	for b in beats:
		all += str(b.get("text", "")) + "\n"
	return all


func _prop_shown(st: StoryState, id: String) -> bool:
	for p: Variant in Compendium.shared().get_entry("locations", "village_of_barovia")["props"]:
		if str((p as Dictionary)["id"]) == id:
			return StoryConditions.check(str((p as Dictionary).get("when", "")), st)
	return false


func test_her_name_brings_her_up_quietly_and_mihail_buries_her() -> void:
	var st := _party()
	st.set_quest_stage("cut_after_noon", "rumored")
	st.set_quest_stage("polite_caller", "rumored")
	_play(st, "village_of_barovia/arik:start", ["Heard anything interesting?", "Goodbye"])
	assert_eq(st.quest_stage("six_feet"), "rumored", "Arik's third rumour")
	assert_false(_prop_shown(st, "well_lip"))
	_play(st, "village_of_barovia/townsfolk:gravedigger", ["Arik says you dig your graves early", "We'll find out who she is"])
	assert_eq(st.quest_stage("six_feet"), "asked")
	assert_true(_prop_shown(st, "well_lip") and _prop_shown(st, "sixfeet_grave"))
	_play(st, "village_of_barovia/townsfolk:goodwife", ["Your brother Mihail is worried"])
	assert_eq(st.quest_stage("six_feet"), "the_bride")
	# Down the rope (an Athletics check): the bones come up, and so does she.
	st.set_flag("bride_bones_raised")
	var beats := _play(st, "village_of_barovia/six_feet:climb", ["Nobody's marrying you"])
	assert_true(bool(st.get_flag("bride_calmed", false)), "her name is enough")
	assert_eq(str(beats[-1].get("combat", "")), "", "no fight")
	st.gold = 0
	var burial := _play(st, "village_of_barovia/six_feet:grave", ["Lay her in it"])
	assert_eq(st.quest_stage("six_feet"), "buried")
	assert_true(_text(burial).contains("They were all for you"))
	assert_eq(roundi(st.gold), 60)
	assert_true(st.party_has_item("amulet_of_proof_against_detection_and_location"))
	assert_false(_prop_shown(st, "sixfeet_grave"), "the grave is filled")
	var petra := _play(st, "village_of_barovia/townsfolk:goodwife")
	assert_true(_text(petra).contains("herb") or _text(petra).contains("garden"))


func test_without_her_name_she_fights() -> void:
	var st := _party()
	st.set_quest_stage("six_feet", "asked")
	var beats := _play(st, "village_of_barovia/six_feet:climb", ["Stand your ground"])
	assert_eq(str(beats[-1].get("combat", "")), "well_bride")
	_play(st, "village_of_barovia/six_feet:grave")
	assert_ne(st.quest_stage("six_feet"), "buried", "not before she's beaten")
	st.set_flag("bride_beaten")
	_play(st, "village_of_barovia/six_feet:grave", ["Lay her in it"])
	assert_eq(st.quest_stage("six_feet"), "buried")
