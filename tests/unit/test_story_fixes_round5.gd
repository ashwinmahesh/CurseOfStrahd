extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's fifth round of findings ("QA - Wiki Walkthrough Findings" in the vault,
## #109-#113), each played the way a party meets it.


## Finding 110: the dragon-slayer's sword still hung "above the dragon's skull" once the skull was lifted down.
func test_the_sword_hangs_over_empty_hooks() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "castle_ravenloft_court", 12)
	st.set_flag("argynvost_skull_taken")
	var said := Narrator.new().line("search:trophy_dragon_slayer", st, null)
	assert_false(said.contains("Above the dragon's skull"), said)
	assert_true(said.contains("empty hooks"), said)


## Finding 111: with Corvina already at rest, Mordenkainen still asked the party to find her and say her name.
func test_mordenkainen_knows_shes_at_rest() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 10, "mount_baratok_hut", 12)
	st.set_flag("mordenkainen_restored")
	st.set_quest_stage("the_unnamed_crypt", "done")
	for n: String in ["1", "2", "3"]:
		st.set_flag("corvina_letter_" + n)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:news", ["Let him rage", "Goodbye"]))
	assert_false(said.contains("say her name to her"), said)
	assert_true(said.contains("You put it on her box"), said)
	assert_eq(st.quest_stage("the_mages_lost_pages"), "named")
	said = SideQuestPlay.text(SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:news", ["Goodbye"]))
	assert_false(said.contains("You found her."), "no second thanks: %s" % said)


## Finding 112: "we'll wait here for dusk" goes straight on to dusk.
func test_mordenkainen_waits_for_dusk_at_the_glass() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "mount_baratok", 12)
	st.set_flag("mordenkainen_restored")
	assert_true(st.add_guest("mordenkainen"))
	var beats := SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:glass", ["Stand your ground"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.minute_of_day >= 19 * 60, "it's dusk")
	assert_eq(SideQuestPlay.combat_of(beats), "forgotten_storm")


## Finding 113: any ally the cards name may be gone before the reading: Victor vanished, Emil dead or handed back,
## Pidlwick refused, Sir Godfrey at rest, Arabelle drowned. find_the_ally ends lost at the reading and on load.
func test_an_ally_gone_before_the_reading_is_lost() -> void:
	var cases := {
		"donjon": {"victor_vanished": true},
		"beast": {"wolf_pack_leader": "kiril"},
		"marionette": {"pidlwick_refused": true},
		"ghost": {"order_fate": "rest"},
		"tempter": {"arabelle_lost": true},
	}
	for card: String in cases:
		var st := SideQuestPlay.party(["ilse_varga"], 5, "tser_pool_eva_tent", 20)
		st.tarokka = {"tome": "coins_3", "symbol": "swords_6", "sword": "stars_6", "ally": card, "enemy": "donjon" if card != "donjon" else "mists"}
		var flags := cases[card] as Dictionary
		for f: String in flags:
			st.set_flag(f, flags[f])
		assert_true(StoryConditions.check("tarokka.ally.lost", st), "%s: lost" % card)
		st.set_quest_stage("find_the_ally", "foretold")
		var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
		assert_eq(back.quest_stage("find_the_ally"), "lost", card)
	var fine := SideQuestPlay.party(["ilse_varga"], 5, "tser_pool_eva_tent", 20)
	fine.tarokka = {"ally": "beast"}
	assert_false(StoryConditions.check("tarokka.ally.lost", fine), "Emil still waiting")
	var at_rest_with_us := SideQuestPlay.party(["ilse_varga"], 5, "argynvostholt", 20)
	at_rest_with_us.tarokka = {"ally": "ghost"}
	at_rest_with_us.set_flag("order_fate", "rest")
	assert_true(at_rest_with_us.add_guest("sir_godfrey_gwilym"))
	assert_false(StoryConditions.check("tarokka.ally.lost", at_rest_with_us), "Godfrey riding with the party isn't lost")
