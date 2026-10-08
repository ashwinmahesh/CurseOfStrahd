extends TestCase
## The Warm Snow (docs/story/side_quests.md): Sergeant Valcu's log, the north shoulder of Ghakis on the travel map, the
## count's tithe freed from the cart, the keepers' log and their three tricks (the salted carcass, the chain hauled in,
## the vents drowned), each one changing the fight, the pin pulled from her collar, and the hoard's lead and silver.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _lair() -> StoryState:
	var st := SideQuestPlay.party(FOUR, 10, "ghakis_lair", 12)
	st.set_quest_stage("the_warm_snow", "found")
	return st


func _her(enc: Dictionary) -> Dictionary:
	for m: Variant in enc.get("monsters", []):
		if str((m as Dictionary)["monster"]) == "sarkhaza":
			return m as Dictionary
	return {}


func test_the_sergeants_log_puts_ghakis_on_the_map() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "tsolenka_pass_guard_tower", 12)
	st.set_flag("tsolenka_watch_met")
	st.set_flag("tsolenka_watch_fate", "passed")
	st.visited["tsolenka_pass"] = true
	assert_false(Travel.known(st).any(func(p: Dictionary) -> bool: return str(p["id"]) == "ghakis_shoulder"), "unheard of")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/watch:sergeant", ["Anything to report"])
	assert_true(SideQuestPlay.text(beats).contains("nine pilgrims"), "the pilgrims come first")
	assert_eq(st.quest_stage("the_warm_snow"), "", "one entry at a time")
	beats = SideQuestPlay.play(st, "tsolenka_pass/watch:sergeant", ["Anything to report"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("faces in the cage"))
	assert_eq(st.quest_stage("the_warm_snow"), "rumored")
	assert_true(Travel.known(st).any(func(p: Dictionary) -> bool: return str(p["id"]) == "ghakis_shoulder"), "now on the map")
	st.set_flag("ghakis_prisoners_freed")
	beats = SideQuestPlay.play(st, "tsolenka_pass/watch:sergeant", ["Anything to report"])
	assert_true(SideQuestPlay.text(beats).contains("charcoal-burners came down"))


func test_the_tithe_on_the_cart() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "ghakis_shoulder", 12)
	st.set_quest_stage("the_warm_snow", "rumored")
	assert_eq(SideQuestPlay.standing(st, "ghakis_shoulder", "ghakis_doina"), "mount_ghakis/the_warm_snow:prisoners")
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:prisoners")
	assert_true(SideQuestPlay.text(beats).contains("not while they're watching"))
	var enc := SideQuestPlay.encounter(st, "ghakis_shoulder", "ghakis_keepers")
	assert_true(SideQuestPlay.has_foe(enc, "A Keeper") and SideQuestPlay.has_foe(enc, "A Chain-Warden"))
	st.set_flag("ghakis_keepers_slain")
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:prisoners", ["What did the keepers say", "Break their chains"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("open the sluice before you go down"))
	assert_true(st.get_flag("ghakis_prisoners_freed", false))
	assert_eq(st.quest_stage("the_warm_snow"), "found")
	assert_eq(SideQuestPlay.standing(st, "ghakis_shoulder", "ghakis_doina"), "", "gone home")


func test_the_log_and_the_keepers_tricks() -> void:
	var st := _lair()
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:log", ["Read the keepers' notes"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Her name is Sarkhaza"))
	assert_eq(st.quest_stage("the_warm_snow"), "chained")
	# Nothing done: her stat block as written, with her lair.
	var plain := SideQuestPlay.encounter(st, "ghakis_lair", "sarkhaza")
	assert_false(_her(plain).has("hp"))
	assert_true(bool(plain.get("lair", false)))
	assert_eq(str(plain.get("surprise", "")), "")
	# The larder: a carcass salted, well or badly (Sleight of Hand), and the menu closes either way.
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:larder", ["Work grave-salt"], 3)
	assert_true(st.get_flag("ghakis_carcass_salted", false) or st.get_flag("ghakis_carcass_crude", false))
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:larder")
	assert_true(SideQuestPlay.text(beats).contains("One hook is empty"))
	# The drum and the sluice.
	st.set_flag("wyrm_chain_drawn")
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:sluice", ["Heave the sluice gate up"])
	assert_true(st.get_flag("ghakis_sluice_open", false))
	var choked := SideQuestPlay.encounter(st, "ghakis_lair", "sarkhaza")
	assert_eq(str(choked.get("surprise", "")), "enemies", "hauled in, she starts the fight choking")
	assert_false(bool(choked.get("lair", true)), "the drowned vents can't answer her")
	assert_true(int(_her(choked).get("hp", 999)) < 200)
	st.set_flag("wyrm_salted")
	var all := SideQuestPlay.encounter(st, "ghakis_lair", "sarkhaza")
	assert_true(int(_her(all).get("hp", 999)) < int(_her(choked)["hp"]), "salted too")


func test_feeding_her_and_reading_her() -> void:
	var st := _lair()
	st.set_flag("ghakis_carcass_salted")
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:wyrm", ["Throw her the carcass", "What are you doing down here?", "Watch her", "Draw your weapons"], 5)
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("My name is Sarkhaza"))
	assert_true(said.contains("Clever, clever"))
	assert_true(said.contains("burn him out of it"))
	assert_true(st.get_flag("wyrm_salted", false))
	assert_true(st.get_flag("wyrm_read", false), "the Insight check is spent either way")
	assert_eq(SideQuestPlay.combat_of(beats), "sarkhaza")
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:wyrm", ["Watch her"])
	assert_true(SideQuestPlay.missing(beats).contains("Watch her"), "not twice")


func test_the_pin_and_the_lead() -> void:
	var st := _lair()
	st.set_flag("wyrm_story_heard")
	st.set_flag("wyrm_met")
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:wyrm", ["Pull the pin", "Pull it."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("so very hungry"))
	assert_eq(SideQuestPlay.combat_of(beats), "sarkhaza")
	var free := SideQuestPlay.encounter(st, "ghakis_lair", "sarkhaza")
	assert_true(int(_her(free).get("hp", 0)) > 200, "off her chain she's at her strongest")
	assert_eq(str(free.get("surprise", "")), "")
	# The lead, seen from across the cavern and thrown at her.
	st = _lair()
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:hoard", ["Look hard"], 2)
	assert_true(st.get_flag("ghakis_gilt_seen", false) or st.get_flag("ghakis_gilt_tried", false))
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:hoard")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	st.set_flag("ghakis_gilt_seen")
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:wyrm", ["Your gold is lead"])
	assert_true(SideQuestPlay.text(beats).contains("On lead"))
	assert_eq(SideQuestPlay.combat_of(beats), "sarkhaza")


func test_the_hoard_after() -> void:
	var st := _lair()
	st.set_flag("sarkhaza_slain")
	st.set_quest_stage("the_warm_snow", "slain")
	assert_eq(SideQuestPlay.standing(st, "ghakis_lair", "sarkhaza"), "", "dead on her gold")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:hoard")
	assert_true(SideQuestPlay.text(beats).contains("The silver's own"))
	assert_eq(st.quest_stage("the_warm_snow"), "done")
	assert_eq(roundi(st.gold), 900)
	assert_true(st.party_has_item("dragon_scale_mail_silver"))
	beats = SideQuestPlay.play(st, "mount_ghakis/the_warm_snow:hoard")
	assert_true(SideQuestPlay.text(beats).contains("worth nothing"))
	assert_eq(roundi(st.gold), 900, "paid once")
