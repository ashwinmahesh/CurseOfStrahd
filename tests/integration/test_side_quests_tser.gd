extends TestCase
## The Tser Pool camp's side quest (docs/story/side_quests.md): Zora's rumour of the black carriage, Radu's sold mare,
## saving or losing Steaua at the crossroads milestone, the carriage's escort, and Radu's payment once.


func _party(ids: Array[String], level: int = 4) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		st.party.append(Pregens.build(id, level))
	st.location = "tser_pool"
	st.minute_of_day = 18 * 60
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


func _encounter(st: StoryState, id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", "svalich_crossroads")["encounters"]:
		var enc := e as Dictionary
		if str(enc["id"]) == id and StoryConditions.check(str(enc.get("when", "")), st):
			return enc
	return {}


func _named(enc: Dictionary, name: String) -> bool:
	return (enc["monsters"] as Array).any(func(m: Variant) -> bool: return str((m as Dictionary).get("name", "")) == name)


func _prop_shown(st: StoryState, location: String, id: String) -> bool:
	for p: Variant in Compendium.shared().get_entry("locations", location)["props"]:
		if str((p as Dictionary)["id"]) == id:
			return StoryConditions.check(str((p as Dictionary).get("when", "")), st)
	return false


func test_zora_counts_the_grey_out_and_radu_admits_the_bargain() -> void:
	var st := _party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "kip_smudgewick"])
	assert_true(_prop_shown(st, "tser_pool", "tser_horse_grey"), "the grey is in the pen before the rumour")
	_play(st, "svalich_road/tser_camp:zora", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("the_grey_mare"), "rumored")
	assert_false(_prop_shown(st, "tser_pool", "tser_horse_grey"), "and gone from it once he's walked her down")
	st.set_flag("crossroads_gallows_seen")
	# Insight or Persuasion opens his bargain; the dice decide which way, so read the option that rolls.
	var beats := _play(st, "svalich_road/tser_camp:radu", ["walked your grey", "Why did you really sell her"], 3)
	assert_true(st.quest_stage("the_grey_mare") in ["asked", "bargain"], "the quest is under way: %s" % st.quest_stage("the_grey_mare"))
	assert_true(_text(beats).contains("milestone"), "he says where she is")
	assert_true(_prop_shown(st, "svalich_crossroads", "grey_mare_milestone"), "Steaua waits at the milestone")


func test_steaua_calmed_and_cured_runs_home_and_the_carriage_comes_early() -> void:
	var st := _party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "kip_smudgewick"])
	st.set_quest_stage("the_grey_mare", "asked")
	st.location = "svalich_crossroads"
	var beats := _play(st, "svalich_road/grey_mare:mare", ["Talk to her the way", "Protection from Evil and Good"])
	assert_true(bool(st.get_flag("mare_saved", false)), "Kip's ward breaks the brand")
	assert_eq(st.quest_stage("the_grey_mare"), "saved")
	assert_eq(str(beats[-1].get("combat", "")), "carriage_escort", "the carriage comes early")
	var enc := _encounter(st, "carriage_escort")
	assert_false(_named(enc, "Steaua"), "she's gone home, not in the fight")
	assert_true(_named(enc, "The Lead Horse"))
	assert_false(_prop_shown(st, "svalich_crossroads", "grey_mare_milestone"))
	st.set_flag("carriage_beaten")
	st.set_quest_stage("the_grey_mare", "carriage_beaten")
	assert_true(_prop_shown(st, "tser_pool", "tser_horse_grey"), "back in the pen")
	st.gold = 0
	_play(st, "svalich_road/tser_camp:radu", ["Luminita"])
	assert_eq(str(st.get_flag("mare_owner", "")), "luminita")
	assert_eq(st.quest_stage("the_grey_mare"), "home")
	assert_eq(roundi(st.gold), 120)
	assert_true(st.party_has_item("rod_of_the_pact_keeper_plus_1"))
	_play(st, "svalich_road/tser_camp:radu")
	assert_eq(roundi(st.gold), 120, "he pays once")


func test_waiting_without_a_cure_finishes_her_and_she_fights_for_the_carriage() -> void:
	var st := _party(["godrick_pendlebrook", "liriel_dawnsong", "wren_featherfoot", "ratatoille"])
	st.set_quest_stage("the_grey_mare", "asked")
	st.location = "svalich_crossroads"
	var beats := _play(st, "svalich_road/grey_mare:mare", ["Wait here for the carriage"])
	assert_eq(str(beats[-1].get("combat", "")), "carriage_escort")
	assert_eq(st.minute_of_day, 0, "midnight")
	assert_true(bool(st.get_flag("mare_lost", false)))
	assert_eq(st.quest_stage("the_grey_mare"), "lost")
	assert_true(_named(_encounter(st, "carriage_escort"), "Steaua"), "she fights for the carriage")
	st.set_flag("carriage_beaten")
	var back := _play(st, "svalich_road/tser_camp:radu")
	assert_eq(st.quest_stage("the_grey_mare"), "mourned")
	assert_true(_text(back).contains("black ribbon"))
	assert_true(st.party_has_item("rod_of_the_pact_keeper_plus_1"), "the reward doesn't depend on the horse living")


func test_the_escort_is_high_for_its_level() -> void:
	const XP := {0.25: 50, 1.0: 200, 3.0: 700}
	for level: int in [3, 4, 5]:
		var st := _party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "kip_smudgewick"], level)
		st.set_flag("mare_saved")
		var enc := _encounter(st, "carriage_escort")
		assert_false(enc.is_empty(), "a variant for level %d" % level)
		var total := 0
		for m: Variant in enc["monsters"]:
			total += int(XP.get(float(Compendium.shared().get_entry("monsters", str((m as Dictionary)["monster"]))["cr"]), 0))
		if level == 4:
			assert_true(total >= 2000, "High at level 4: %d" % total)
