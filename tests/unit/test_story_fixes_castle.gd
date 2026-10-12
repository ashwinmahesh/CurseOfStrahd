extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's findings in Castle Ravenloft, the Amber Temple and the Tsolenka Pass ("QA -
## Wiki Walkthrough Findings" in the vault, #46-#53, with #57 and #58), each played the way a party meets it.


## Finding 46: with Pidlwick gone to Blinsky's, the Jester's Key stuck at Found.
func test_pidlwick_takes_his_key_at_the_toy_shop() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "vallaki_blinsky_toys", 12)
	st.set_flag("pidlwick_with_blinsky")
	st.set_flag("pidlwick_key_found")
	st.set_quest_stage("the_jesters_key", "asked")
	st.set_quest_stage("the_jesters_key", "found")
	var beats := SideQuestPlay.play(st, "vallaki/toymakers_masterpiece:pidlwick_home", ["We found your key"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_jesters_key"), "returned")
	assert_true(st.party_has_item("figurine_of_wondrous_power_ebony_fly"))
	assert_false("pidlwick_ii" in st.guest_ids, "and he stays at the shop")
	assert_false(SideQuestPlay.text(beats).contains("CAN I COME WITH YOU"))


## Findings 47, 57 and 58: a party that released or fought the Tsolenka watch lost the watchword, The Warm Snow and The
## Guide to the Temple with the sergeant. The watch log has them.
func test_the_watch_log_tells_what_the_sergeant_would_have() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "tsolenka_pass_guard_tower", 12)
	st.set_flag("tsolenka_watch_released")
	st.set_flag("tsolenka_watch_fate", "released")
	st.set_flag("tsolenka_gate_open")
	SideQuestPlay.play(st, "tsolenka_pass/watch:log")
	assert_true(bool(st.get_flag("tsolenka_watchword_known", false)), "the watchword")
	assert_eq(st.quest_stage("the_warm_snow"), "rumored")
	assert_eq(st.quest_stage("the_guide_to_the_temple"), "asked")
	var low := SideQuestPlay.party(["ilse_varga"], 8, "tsolenka_pass_guard_tower", 12)
	SideQuestPlay.play(low, "tsolenka_pass/watch:log")
	assert_eq(low.quest_stage("the_guide_to_the_temple"), "", "the guide waits for level 10 and the open gate")
	var on_desk := ""
	for p: Variant in Compendium.shared().get_entry("locations", "tsolenka_pass_guard_tower")["props"]:
		if str((p as Dictionary)["id"]) == "tower_watch_log":
			on_desk = str((p as Dictionary).get("dialogue", ""))
	assert_eq(on_desk, "tsolenka_pass/watch:log", "the log on the desk reads this way")


## Finding 48: naming Patrina before Kasimir came along kept their scene, and his peace, from ever playing.
func test_kasimir_meets_his_sister_after_she_was_named() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "amber_temple_faceless_god", 12)
	st.set_flag("patrina_met")
	st.set_flag("patrina_named")
	st.set_quest_stage("patrinas_wail", "named")
	assert_true(st.add_guest("kasimir_velikov"))
	var beats := SideQuestPlay.play(st, "amber_temple/patrina:start", ["Let him speak for himself"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("kasimir_at_peace", false)))


## Finding 50: Nadia hiding had nothing to say in the epilogue, nor did Doru or Cyrus.
func test_the_larders_people_have_their_slides() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "castle_ravenloft_larders", 12)
	st.set_flag("larders_nadia_fate", "waits")
	st.set_flag("larders_cyrus_met")
	st.set_flag("larders_doru_fate", "rest")
	var titles := Endings.slides(Endings.get_ending("strahd_destroyed"), st).map(func(sl: Dictionary) -> String: return str(sl["title"]))
	for who: String in ["Nadia Boteanu", "Doru", "Cyrus Belview"]:
		assert_true(who in titles, "%s's slide: %s" % [who, titles])


## Finding 51: Strahd's dinner could only end in thanks or steel. The party can excuse itself and come back.
func test_the_dinner_can_be_left_and_returned_to() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "castle_ravenloft_main_floor", 20)
	st.set_flag("strahd_invitation", "accepted")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(str(st.get_flag("castle_dinner", "")), "", "the dinner isn't over")
	beats = SideQuestPlay.play(st, "castle_ravenloft/gates_dinner:start", ["Thank him"])
	assert_true(SideQuestPlay.text(beats).contains("You came back."), SideQuestPlay.text(beats))
	assert_eq(str(st.get_flag("castle_dinner", "")), "dined")


## Finding 52: reading the pact in the vault after the broker was dealt with didn't move The Amber Temple on.
func test_the_pact_ledger_is_the_revelation() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "amber_temple_vault", 12)
	st.set_quest_stage("the_amber_temple", "arrived")
	st.set_quest_stage("the_amber_temple", "broker_banished")
	st.set_flag("vosk_fate", "banished")
	SideQuestPlay.play(st, "amber_temple/vault:pact_ledger", ["Read the last entry"])
	assert_eq(st.quest_stage("the_amber_temple"), "pact_learned")


## Finding 53: Corvina's name on the slip in her coat counts as knowing it, so the Forgotten Storm can hear it.
func test_corvinas_name_from_her_coat() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "castle_ravenloft_catacombs", 12)
	st.set_flag("corvina_slain")
	SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:after")
	assert_true(bool(st.get_flag("corvina_name_known", false)))
