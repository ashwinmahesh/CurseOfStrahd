extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's findings at the Wizard of Wines, Yester Hill and Lake Zarovich ("QA - Wiki
## Walkthrough Findings" in the vault, #43 and #45), each played the way a party meets it.


## Finding 43: leaving Ostap before the boat came made every later visit end at once, so the Baron's Island stuck.
func test_the_reed_isle_waits_for_the_party_to_come_back() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "zarovich_reed_island", 20)
	st.set_quest_stage("the_barons_island", "asked")
	SideQuestPlay.play(st, "lake_zarovich/the_barons_island:ostap", ["Leave them to their fires"])
	assert_true(bool(st.get_flag("reed_isle_met", false)))
	var beats := SideQuestPlay.play(st, "lake_zarovich/the_barons_island:ostap", ["Come back with us", "Wait at the landing"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "reed_isle_boatmen", "the boat comes on the second visit")


## Finding 45: the level 7 Wintersplinter had fewer hit points than level 6's.
func test_wintersplinter_grows_with_the_party() -> void:
	var hp := {}
	for level: int in [5, 6, 7]:
		var st := SideQuestPlay.party(["ilse_varga"], level, "yester_hill_gulthias_tree", 20)
		var enc := SideQuestPlay.encounter(st, "yester_hill_gulthias_tree", "summit_ritual")
		hp[level] = int(((enc["monsters"] as Array)[0] as Dictionary).get("hp", 0))
	assert_true(int(hp[6]) > int(hp[5]) and int(hp[7]) > int(hp[6]), "more each level: %s" % [hp])


## Finding 45: Davian counted "Two" and "Three" whatever was in the ground.
func test_davian_counts_the_stones_in_the_ground() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "wizard_of_wines", 12)
	st.set_flag("yester_stone_recovered")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "wizard_of_wines/davian:return_hill"))
	assert_true(said.contains("One in the ground."), said)
	st.set_quest_stage("the_third_stone", "found")
	said = SideQuestPlay.text(SideQuestPlay.play(st, "wizard_of_wines/davian:return_berez"))
	assert_true(said.contains("It isn't three, not yet."), said)
	assert_false(str(QuestLog.journal(st).filter(func(q: Dictionary) -> bool: return str(q["id"]) == "the_third_stone")).contains("All three"),
		"nor does the journal")
	var all := SideQuestPlay.party(["ilse_varga"], 5, "wizard_of_wines", 12)
	all.set_flag("winery_stones_returned", 2)
	all.set_quest_stage("the_third_stone", "found")
	said = SideQuestPlay.text(SideQuestPlay.play(all, "wizard_of_wines/davian:return_berez"))
	assert_true(said.contains("...Three."), "the third of three: %s" % said)


## Finding 45: while the lantern on Yester Hill was his news, Davian never told a party who'd only heard of the Black Row.
func test_davian_tells_of_the_seventh_row_first() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 7, "wizard_of_wines", 12)
	st.set_flag("winery_reclaimed")
	st.set_flag("gulthias_tree_burned")
	st.set_quest_stage("the_black_row", "rumored")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "wizard_of_wines/the_black_row:davian_news", ["Goodbye"]))
	assert_true(said.contains("The Seventh Row."), said)
	assert_eq(st.quest_stage("the_black_row"), "asked")
	said = SideQuestPlay.text(SideQuestPlay.play(st, "wizard_of_wines/the_black_row:davian_news", ["Goodbye"]))
	assert_true(said.contains("lantern on Yester Hill"), "then the lantern: %s" % said)


## Finding 45: "Cast Water Breathing" at the drowned bell cast nothing; it casts now, and an active spell is enough.
func test_water_breathing_takes_the_party_down_to_the_bell() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "lake_zarovich", 12)
	SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:cast_water_breathing")
	assert_false(bool(st.get_flag("bell_silenced", false)), "nobody here can cast it")
	st.active_spells["water_breathing"] = {"until": st.total_minutes() + 600}
	var beats := SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:bell", ["breathing water"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("bell_silenced", false)))


## Finding 45: Zorica said Mother burned with the tree even when Ruxandra had fled or been let go.
func test_zorica_knows_mother_lived() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 7, "yester_hill_gulthias_tree", 22)
	st.set_flag("yester_druids_fate", "spared")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "yester_hill/the_druid_who_came_back:zorica", ["Leave her"]))
	assert_false(said.contains("and Mother with it"), said)
	assert_true(said.contains("Mother's gone where none of us can find her"), said)


## Finding 45: the Blue Water's talk of the wine set the hook without the quest, and Krezk's watchman then kept quiet.
func test_the_blue_water_puts_the_winery_in_the_journal() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 4, "vallaki_blue_water_inn", 12)
	SideQuestPlay.play(st, "vallaki/martikovs:wine")
	assert_true(bool(st.get_flag("wizard_of_wines_hook", false)))
	assert_eq(st.quest_stage("wizard_of_wines"), "rumored")


## Finding 45: the first cart sent to Krezk opens its gate for the party, as Davian said it might.
func test_the_first_cart_opens_krezks_gate() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "krezk", 12)
	st.set_flag("winery_first_cart", "krezk")
	st.set_flag("wizard_of_wines_hook")
	var beats := SideQuestPlay.play(st, "krezk/gate:start", ["beside the Martikovs' cart"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("krezk_gate_open", false)))
	var offered := ""
	for b in beats:
		if str(b["kind"]) == "options":
			offered += str((b["options"] as Array).map(func(o: Variant) -> String: return str((o as Dictionary)["text"])))
	assert_false(offered.contains("We know why it stopped"), "not the old news as well: %s" % offered)
