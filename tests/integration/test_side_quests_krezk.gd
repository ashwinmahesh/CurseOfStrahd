extends TestCase
## Krezk's side quest (docs/story/side_quests.md): the watchman's rumours (Ilya, the wine, the stolen children and the
## toys on the Krezkov graves), Lighter Than It Should Be (the vigil, Sorin's name in his mother's voice, the abbey's
## pursuers while the Abbot holds it, and the family scene's three endings), paying once.


func _party(level: int = 7) -> StoryState:
	var st := StoryState.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		st.party.append(Pregens.build(id, level))
	st.location = "krezk"
	st.minute_of_day = 11 * 60
	st.set_flag("krezk_gate_open")
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


func _standing(st: StoryState, location: String, npc: String) -> String:
	for n: Variant in Compendium.shared().get_entry("locations", location)["npcs"]:
		var e := n as Dictionary
		if str(e["npc"]) == npc and StoryConditions.check(str(e.get("when", "")), st):
			return str(e["dialogue"])
	return ""


func test_the_watchman_tells_everything_krezk_is_afraid_of() -> void:
	var st := _party()
	_play(st, "krezk/gate:guard", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("the_burgomasters_son"), "heard", "Ilya")
	assert_eq(st.quest_stage("wizard_of_wines"), "rumored", "the wine")
	assert_true(bool(st.get_flag("werewolf_rumor", false)), "the den goes on the map")
	assert_eq(st.quest_stage("wolves_in_the_hills"), "heard")
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "rumored", "the toys")
	st.set_quest_stage("lighter_than_it_should_be", "seen")
	_play(st, "krezk/gate:guard", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "seen", "never back to a rumour")


func test_the_vigil_names_him_and_the_abbey_sends_for_him() -> void:
	var st := _party()
	st.location = "krezk_pool_of_the_white_sun"
	_play(st, "krezk/kasha:start", ["Whose graves are these?"])
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "rumored", "Kasha mentions the toys")
	_play(st, "krezk/lighter_than_it_should_be:toys", ["Wait here after midnight"])
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "toys")
	assert_true(st.is_night())
	assert_eq(_standing(st, "krezk_pool_of_the_white_sun", "sorin_krezkov"), "krezk/lighter_than_it_should_be:sorin")
	var beats := _play(st, "krezk/lighter_than_it_should_be:sorin", ["Stay very still"])
	assert_true(bool(st.get_flag("sorin_known", false)))
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "sorin_known")
	assert_true(_text(beats).contains("come in, it's dark"), "his name in his mother's voice")
	assert_eq(str(beats[-1].get("combat", "")), "sorin_pursuers", "the Abbot still holds the abbey: they come for him")
	st.set_flag("sorin_pursuers_beaten")
	assert_eq(_standing(st, "krezk_pool_of_the_white_sun", "sorin_krezkov"), "krezk/lighter_than_it_should_be:sorin_after")
	_play(st, "krezk/lighter_than_it_should_be:sorin_after", ["Come with us"])
	assert_eq(_standing(st, "krezk_burgomaster_house", "sorin_krezkov"), "krezk/lighter_than_it_should_be:family")


func test_with_the_abbot_gone_nobody_comes_and_ilya_settles_it() -> void:
	var st := _party()
	st.set_flag("abbot_fate", "repentant")
	st.set_flag("ilya_fate", "healed")
	st.set_flag("sorin_vigil")
	st.minute_of_day = 60
	var beats := _play(st, "krezk/lighter_than_it_should_be:sorin", ["Stay very still"])
	assert_eq(str(beats[-1].get("combat", "")), "", "no pursuers")
	assert_eq(_standing(st, "krezk_pool_of_the_white_sun", "sorin_krezkov"), "krezk/lighter_than_it_should_be:sorin_after")
	_play(st, "krezk/lighter_than_it_should_be:sorin_after", ["Come with us"])
	st.gold = 0
	var family := _play(st, "krezk/lighter_than_it_should_be:family", ["Let Ilya meet his brother"])
	assert_eq(str(st.get_flag("sorin_fate", "")), "home")
	assert_eq(st.quest_stage("lighter_than_it_should_be"), "home")
	assert_true(_text(family).contains("carve a wolf"))
	assert_eq(roundi(st.gold), 400)
	assert_true(st.party_has_item("armor_plus_1") or st.party.any(func(c: Character) -> bool: return c.carries("armor_plus_1__chain_mail")),
		"Dmitri's grandfather's mail")
	assert_eq(_standing(st, "krezk_burgomaster_house", "sorin_krezkov"), "krezk/lighter_than_it_should_be:sorin_home")


func test_the_coffin_of_stones_and_the_way_to_the_pool() -> void:
	var st := _party()
	st.location = "krezk_pool_of_the_white_sun"
	st.set_quest_stage("lighter_than_it_should_be", "toys")
	_play(st, "krezk/lighter_than_it_should_be:toys", ["Dig up the eldest's grave"])
	assert_true(bool(st.get_flag("sorin_grave_opened", false)))
	st.set_flag("sorin_known")
	st.set_flag("sorin_brought")
	st.set_quest_stage("lighter_than_it_should_be", "sorin_known")
	_play(st, "krezk/lighter_than_it_should_be:family", ["Kasha needs a groundskeeper"])
	assert_eq(str(st.get_flag("sorin_fate", "")), "pool")
	assert_eq(_standing(st, "krezk_pool_of_the_white_sun", "sorin_krezkov"), "krezk/lighter_than_it_should_be:sorin_pool")
	assert_eq(_standing(st, "krezk_burgomaster_house", "sorin_krezkov"), "", "not at the house")
	var st2 := _party()
	st2.set_flag("sorin_grave_opened")
	st2.set_flag("sorin_brought")
	_play(st2, "krezk/lighter_than_it_should_be:family", ["Tell him what you found in the coffin"])
	assert_eq(str(st2.get_flag("sorin_fate", "")), "home", "the coffin of stones turns Dmitri")
