extends TestCase
## Vallaki's side quests (docs/story/side_quests.md): the watch's and Urwin's rumours (and the wiring into the bones,
## Arabelle and Lady Wachter), The Cat in the Window (Stella's ribbon, broken three ways or cut in vain) and Black Roses
## (Ilie's secret, Ana at Mila's window, her grave by day, and the bitter way out), each paying once.


func _party(ids: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"], level: int = 5) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		st.party.append(Pregens.build(id, level))
	st.location = "vallaki"
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


func _encounter(st: StoryState, location: String, id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", location)["encounters"]:
		var enc := e as Dictionary
		if str(enc["id"]) == id and StoryConditions.check(str(enc.get("when", "")), st):
			return enc
	return {}


func _standing(st: StoryState, location: String, npc: String) -> String:
	for n: Variant in Compendium.shared().get_entry("locations", location)["npcs"]:
		var e := n as Dictionary
		if str(e["npc"]) == npc and StoryConditions.check(str(e.get("when", "")), st):
			return str(e["dialogue"])
	return ""


# --- Rumours ---

func test_the_watch_and_urwin_put_vallakis_troubles_in_the_journal() -> void:
	var st := _party()
	st.set_flag("vallaki_arrived")
	_play(st, "vallaki/gate:guard", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("bones_of_st_andral"), "rumored")
	assert_eq(st.quest_stage("missing_arabelle"), "rumored")
	assert_eq(st.quest_stage("wachter_plot"), "rumored")
	assert_eq(st.quest_stage("cat_in_the_window"), "rumored")
	_play(st, "vallaki/martikovs:urwin", ["Heard anything interesting?", "Goodbye"])
	assert_eq(st.quest_stage("black_roses"), "rumored")
	# Already further along: the rumours never send a quest back.
	st.set_quest_stage("bones_of_st_andral", "milivoj_confessed")
	st.set_quest_stage("missing_arabelle", "clue")
	_play(st, "vallaki/gate:guard", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("bones_of_st_andral"), "milivoj_confessed")
	assert_eq(st.quest_stage("missing_arabelle"), "clue")
	var st2 := _party()
	_play(st2, "vallaki/arasek:start", ["Heard anything interesting on the roads?", "Goodbye"])
	assert_true(bool(st2.get_flag("bonegrinder_rumor", false)), "Arasek puts the windmill on the map")


# --- The Cat in the Window ---

func test_stella_freed_with_remove_curse_goes_to_lucian_and_pays_once() -> void:
	var st := _party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"], 6)
	st.location = "vallaki_wachter_house"
	st.set_flag("stella_rumor")
	st.set_quest_stage("cat_in_the_window", "rumored")
	# Detect Magic or Arcana finds the ribbon; Liriel prepares Remove Curse from level 6.
	st.set_flag("stella_bound_known")
	st.set_quest_stage("cat_in_the_window", "bound")
	assert_true(StoryConditions.check("knows:remove_curse", st), "someone can cast Remove Curse")
	var beats := _play(st, "vallaki/cat_in_the_window:stella", ["Free her", "Cast Remove Curse"])
	assert_eq(str(beats[-1].get("combat", "")), "stella_shadow", "her shadow stands up")
	var enc := _encounter(st, "vallaki_wachter_house", "stella_shadow")
	assert_true((enc["monsters"] as Array).any(func(m: Variant) -> bool: return str((m as Dictionary)["monster"]) == "wraith"))
	st.set_flag("stella_shadow_beaten")
	st.set_quest_stage("cat_in_the_window", "freed")
	assert_eq(_standing(st, "vallaki_wachter_house", "stella_wachter"), "vallaki/cat_in_the_window:after_fight")
	var after := _play(st, "vallaki/cat_in_the_window:after_fight")
	assert_true(bool(st.get_flag("stella_at_church", false)))
	assert_true(_text(after).contains("Father Lucian"))
	assert_eq(_standing(st, "vallaki_wachter_house", "stella_wachter"), "", "she's left the house")
	assert_eq(_standing(st, "vallaki_st_andrals", "stella_wachter"), "vallaki/cat_in_the_window:church")
	st.gold = 0
	var church := _play(st, "vallaki/cat_in_the_window:church")
	assert_eq(st.quest_stage("cat_in_the_window"), "with_lucian")
	assert_eq(roundi(st.gold), 250)
	assert_true(st.party_has_item("cloak_of_the_bat"), "the master's birthday present")
	assert_true(_text(church).contains("third shelf"), "she tells you how the cellar panel opens")
	_play(st, "vallaki/cat_in_the_window:church")
	assert_eq(roundi(st.gold), 250, "she pays once")


func test_without_the_spell_lucian_gives_the_scroll_and_cutting_only_rings_the_bell() -> void:
	var st := _party(["godrick_pendlebrook", "thistle", "wren_featherfoot", "kip_smudgewick"], 4)
	st.set_flag("stella_bound_known")
	st.set_quest_stage("cat_in_the_window", "bound")
	assert_false(StoryConditions.check("knows:remove_curse", st))
	_play(st, "vallaki/cat_in_the_window:stella", ["Free her", "Cut the ribbon"])
	assert_true(bool(st.get_flag("stella_bell_rung", false)), "the bell rings")
	assert_eq(st.quest_stage("cat_in_the_window"), "bound", "and nothing is broken")
	st.set_flag("lucian_met")
	_play(st, "vallaki/lucian:start", ["Lady Wachter's daughter is under a curse"])
	assert_true(st.party_has_item("spell_scroll__remove_curse"), "Lucian's last scroll")
	var beats := _play(st, "vallaki/cat_in_the_window:stella", ["Free her", "Read a Scroll of Remove Curse"])
	assert_false(st.party_has_item("spell_scroll__remove_curse"), "read and spent")
	assert_eq(str(beats[-1].get("combat", "")), "stella_shadow")


# --- Black Roses ---

func test_ilies_secret_the_vigil_and_the_grave_by_day() -> void:
	var st := _party()
	st.minute_of_day = 21 * 60
	st.set_flag("roses_rumor")
	st.set_quest_stage("black_roses", "rumored")
	_play(st, "vallaki/townsfolk:lamplighter", ["black roses on the chandler's step", "We'll watch the house"])
	assert_eq(st.quest_stage("black_roses"), "asked")
	assert_true(bool(st.get_flag("roses_vigil", false)))
	assert_eq(_standing(st, "vallaki", "ana"), "vallaki/black_roses:ana", "Ana comes to Mila's window")
	var ana := _play(st, "vallaki/black_roses:ana", ["Where do you sleep", "Attack"])
	assert_true(bool(st.get_flag("ana_grave_known", false)))
	assert_eq(str(ana[-1].get("combat", "")), "roses_street")
	assert_eq(_standing(st, "vallaki", "ana"), "", "she's gone from the street")
	var night := _encounter(st, "vallaki", "roses_street")
	assert_eq((night["monsters"] as Array).filter(func(m: Variant) -> bool: return str((m as Dictionary)["monster"]) == "vampire_spawn").size(), 2,
		"Ana and Irina at level 5")
	# By day her grave is the easier way; the dig fight starts with the girls asleep.
	st.minute_of_day = 11 * 60
	var dig := _play(st, "vallaki/black_roses:grave", ["Dig them up"])
	assert_eq(str(dig[-1].get("combat", "")), "roses_graves")
	var day := _encounter(st, "vallaki", "roses_graves")
	assert_eq(str(day["surprise"]), "enemies", "they wake too late")
	st.set_flag("roses_spawn_destroyed")
	st.minute_of_day = 21 * 60
	var told := _play(st, "vallaki/townsfolk:lamplighter")
	assert_eq(st.quest_stage("black_roses"), "ended")
	assert_true(st.party_has_item("ring_of_resistance_necrotic"), "Ana's mother's ring")
	assert_true(_text(told).contains("keep the night out"))
	st.minute_of_day = 11 * 60
	st.gold = 0
	_play(st, "vallaki/black_roses:chandler")
	assert_eq(roundi(st.gold), 200, "Pyotr pays for Mila's life")
	_play(st, "vallaki/black_roses:chandler")
	_play(st, "vallaki/black_roses:ilie")
	assert_eq(roundi(st.gold), 200, "nobody pays twice")
	assert_true(st.party.any(func(c: Character) -> bool: return c.carries("ring_of_resistance_necrotic")))


func test_letting_ana_go_home_costs_her_father() -> void:
	var st := _party()
	st.minute_of_day = 22 * 60
	st.set_quest_stage("black_roses", "fed")
	st.set_flag("roses_vigil")
	_play(st, "vallaki/black_roses:ana", ["Let her go home"])
	assert_eq(str(st.get_flag("ilie_fate", "")), "lost")
	assert_eq(st.quest_stage("black_roses"), "ilie_lost")
	assert_eq(_standing(st, "vallaki", "vallaki_lamplighter"), "", "nobody lights the lamps")
	st.minute_of_day = 11 * 60
	st.gold = 0
	_play(st, "vallaki/black_roses:chandler")
	assert_eq(roundi(st.gold), 200, "Mila lived, and her father pays")
	assert_false(st.party_has_item("ring_of_resistance_necrotic"), "but there's nobody to give you the ring")
