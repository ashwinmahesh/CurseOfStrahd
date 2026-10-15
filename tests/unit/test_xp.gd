extends TestCase
## XP levelling (story/xp.gd, data/progression/xp.json, docs/plans/xp_mode.md): the 2024 tables, what each thing earns at
## levels 1, 5 and 10, the floor a region milestone lifts the party to, the ceiling that keeps it within a level of the story
## (one-time XP waits in the reserve, repeatable XP over it is lost), the cap, the foe share and its split of four, every
## once-key paying once, and milestone mode left exactly as it was.


func _xp_state(xp: int = 0, milestones: int = 0) -> StoryState:
	var st := StoryState.new()
	st.options[Xp.OPTION] = Xp.EXPERIENCE
	st.xp = xp
	st.milestones = milestones
	return st


## A fight on an open field: two heroes (however many travel, the split is four) and `foes` (monster ids).
func _fight(foes: Array[String], heroes: int = 2) -> Encounter:
	var e := TestCombat.open_field()
	var ids: Array[String] = ["ilse_varga", "thistle", "godrick_pendlebrook", "kip_smudgewick"]
	for i in heroes:
		TestCombat.hero(e, ids[i], Vector2i(1, i))
	for i in foes.size():
		TestCombat.foe(e, foes[i], Vector2i(8, i))
	return e


# --- The 2024 tables ----------------------------------------------------------------------------------------------

func test_the_level_table_and_budgets_are_the_2024_ones() -> void:
	var thresholds := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000, 85000, 100000]
	for i in thresholds.size():
		assert_eq(Xp.threshold(i + 1), int(thresholds[i]), "XP for level %d" % (i + 1))
	var budgets := {1: [50, 75, 100], 2: [100, 150, 200], 3: [150, 225, 400], 4: [250, 375, 500], 5: [500, 750, 1100],
		6: [600, 1000, 1400], 7: [750, 1300, 1700], 8: [1000, 1700, 2100], 9: [1300, 2000, 2600], 10: [1600, 2300, 3100]}
	for level: int in budgets:
		for col in Xp.COLUMNS.size():
			assert_eq(Xp.budget(level, Xp.COLUMNS[col]), int((budgets[level] as Array)[col]), "level %d %s" % [level, Xp.COLUMNS[col]])


func test_levels_from_xp_stop_at_the_cap() -> void:
	assert_eq(Xp.level_for(0), 1)
	assert_eq(Xp.level_for(299), 1)
	assert_eq(Xp.level_for(300), 2)
	assert_eq(Xp.level_for(14000), 6)
	assert_eq(Xp.level_for(84999), 10)
	assert_eq(Xp.level_for(85000), 11)
	assert_eq(Xp.level_for(900000), StoryState.LEVEL_CAP, "the game stops at 11 however much XP there is")
	assert_eq(Xp.to_next(6500), 7500, "level 5 needs 7,500 more for 6")
	assert_eq(Xp.to_next(85000), 0, "nothing more at the cap")
	assert_between(Xp.progress(10250), 0.49, 0.51, "halfway through level 5")
	assert_eq(Xp.progress(85000), 1.0)


# --- What each thing is worth -------------------------------------------------------------------------------------

func test_the_awards_at_levels_1_5_and_10() -> void:
	# The plan's table: milestone, main quest, side quest and place, location, find and check, lore.
	var want := {1: [100, 75, 25, 5, 3, 1], 5: [1100, 750, 250, 50, 25, 13], 10: [3100, 2300, 800, 160, 80, 40]}
	for level: int in want:
		var st := _xp_state(Xp.threshold(level))
		var row := want[level] as Array
		assert_eq(Xp.amount_for(st, "milestone"), int(row[0]), "level %d milestone (High)" % level)
		assert_eq(Xp.amount_for(st, "main_quest"), int(row[1]), "level %d main quest (Moderate)" % level)
		assert_eq(Xp.amount_for(st, "side_quest"), int(row[2]), "level %d side quest (half of Low)" % level)
		assert_eq(Xp.amount_for(st, "place"), int(row[2]), "level %d place (half of Low)" % level)
		assert_eq(Xp.amount_for(st, "location"), int(row[3]), "level %d new location (Low / 10)" % level)
		assert_eq(Xp.amount_for(st, "trap_noticed"), int(row[4]), "level %d trap (Low / 20)" % level)
		assert_eq(Xp.amount_for(st, "find"), int(row[4]), "level %d find (Low / 20)" % level)
		assert_eq(Xp.amount_for(st, "check"), int(row[4]), "level %d check (Low / 20)" % level)
		assert_eq(Xp.amount_for(st, "lore"), int(row[5]), "level %d lore (Low / 40)" % level)
	assert_eq(Xp.amount_for(_xp_state(), "nonsense"), 0, "a kind the table doesn't have pays nothing")


func test_every_once_key_pays_once() -> void:
	var st := _xp_state()
	var first := Xp.award(st, "find", "tower:safe")
	assert_eq(first, 3, "a find at level 1")
	assert_eq(st.xp, 3)
	assert_eq(Xp.award(st, "find", "tower:safe"), 0, "the same find again pays nothing")
	assert_eq(Xp.award(st, "find", "tower:chest"), 3, "another find does")
	assert_eq(Xp.award(st, "check", "tower:safe"), 3, "the same key under another kind is another award")
	assert_eq(st.xp, 9)
	assert_true(st.flags.has("_xp/find/tower:safe"), "the key is kept in the flags")


func test_milestone_mode_gets_nothing_and_changes_nothing() -> void:
	var st := StoryState.new()
	assert_false(Xp.active(st))
	assert_eq(Xp.mode_of(st.options), Xp.MILESTONE, "a game that never picked is milestones")
	assert_eq(Xp.award(st, "find", "a"), 0)
	assert_eq(Xp.fight(st, _fight(["wolf", "wolf"]), "pack", false), "")
	assert_eq(Xp.talked_away(st, "doru_undercroft"), "")
	assert_eq(Xp.award(st, "lore", "book"), 0)
	Xp.arrive(st, "village_of_barovia")
	Xp.quest_done(st, "madam_evas_reading")
	assert_eq(st.xp, 0)
	assert_eq(st.xp_reserve, 0)
	assert_true(st.flags.is_empty(), "no award left a key behind")
	st.milestones = 2
	assert_eq(st.target_level(), 3, "milestones decide the level, as ever")
	assert_eq(st.story_level(), 3)
	assert_eq(st.add_codex("a_book"), 0, "lore is read for nothing")
	assert_eq(st.add_codex("a_book"), -1, "and only once")
	# Madam Eva's reading ends a main quest in success; in milestone mode that pays nothing.
	assert_true(st.set_quest_stage("madam_evas_reading", _success_stage("madam_evas_reading")))
	assert_eq(st.xp, 0)


func _success_stage(quest_id: String) -> String:
	for s: Variant in Compendium.shared().get_entry("quests", quest_id)["stages"]:
		if str((s as Dictionary).get("ends", "")) == "success":
			return str((s as Dictionary)["id"])
	return ""


# --- The guardrails -----------------------------------------------------------------------------------------------

func test_a_milestone_pays_the_high_award_and_lifts_a_short_party_to_the_story_level() -> void:
	var st := _xp_state(50)   # level 1, well short
	st.milestones += 1   # the dialogue line does this, then asks Xp
	var said := Xp.milestone(st)
	assert_eq(st.xp, 300, "High (100) leaves it at 150; the floor lifts it to level 2's 300")
	assert_eq(said, "Milestone: +250 XP, the party reaches level 2")
	assert_eq(st.target_level(), 2)


func test_a_milestone_does_not_lift_a_party_already_there() -> void:
	var st := _xp_state(258)   # 86% of the way through level 1
	st.milestones += 1
	assert_eq(Xp.milestone(st), "Milestone: +100 XP, the party reaches level 2", "the High award alone carries it past 300")
	assert_eq(st.xp, 358)
	var ahead := _xp_state(1500, 1)   # level 3 on 1,500 with the story at 2
	ahead.milestones += 1   # story 3
	assert_eq(Xp.milestone(ahead), "Milestone: +400 XP", "level 3's High award, and no new level to mention")
	assert_eq(ahead.xp, 1900)


func test_the_ceiling_keeps_the_party_within_one_level_of_the_story() -> void:
	var st := _xp_state(800)   # story level 1: the pool tops out one short of level 3's 900
	assert_eq(Xp.ceiling(st), 899)
	var got := Xp.gain(st, 500)
	assert_eq(got, {"gained": 99, "held": 401, "lost": 0})
	assert_eq(st.xp, 899)
	assert_eq(Xp.level_for(st.xp), 2, "one ahead of the story, never two")
	assert_eq(st.xp_reserve, 401, "the rest waits")
	assert_eq(Xp.reserve_line(st), "Held for the next milestone: 401 XP")
	# The next milestone pays the High award (200 at level 2) and then the reserve, up to the new ceiling.
	st.milestones += 1
	assert_eq(Xp.milestone(st), "Milestone: +601 XP, the party reaches level 3")
	assert_eq(st.xp, 1500, "899 + 200 + 401")
	assert_eq(st.xp_reserve, 0)
	assert_eq(Xp.reserve_line(st), "")


func test_a_reserve_the_new_ceiling_cannot_hold_all_of_stays_for_the_next() -> void:
	var st := _xp_state(2699, 1)   # story level 2: the ceiling is level 4's 2,699
	st.xp_reserve = 5000
	st.milestones += 1   # story 3: ceiling 6,499
	Xp.milestone(st)
	assert_eq(st.xp, 6499, "the pool fills to the ceiling")
	assert_eq(st.xp_reserve, 5000 + 400 - (6499 - 2699), "and what is left stays: the reserve and the High award, less what went in")


func test_repeatable_xp_over_the_ceiling_is_lost() -> void:
	var st := _xp_state(850)
	var got := Xp.gain(st, 500, true)
	assert_eq(got, {"gained": 49, "held": 0, "lost": 451})
	assert_eq(st.xp, 899)
	assert_eq(st.xp_reserve, 0, "grinding the road can't bank XP")


func test_the_cap_stops_the_pool_and_there_is_nothing_to_wait_for() -> void:
	var st := _xp_state(84000, 9)   # story level 10: level 11 (85,000) is the most the pool can hold
	assert_eq(Xp.ceiling(st), 85000)
	assert_eq(Xp.gain(st, 5000), {"gained": 1000, "held": 4000, "lost": 0}, "one ahead of the story is still allowed")
	st.milestones += 1   # story 11, the cap
	Xp.milestone(st)
	assert_eq(st.xp, 85000)
	assert_eq(st.xp_reserve, 0, "no milestone is left to pay it")
	assert_eq(Xp.gain(st, 100000), {"gained": 0, "held": 0, "lost": 100000})
	assert_eq(st.target_level(), StoryState.LEVEL_CAP)
	assert_eq(Xp.line(st), "Level 11 · 85,000 XP")


func test_target_level_follows_the_pool_and_levels_waiting_follows_it() -> void:
	var st := _xp_state(7000, 3)
	var ch := TestChars.pregen("ilse_varga", 3)
	st.party.append(ch)
	assert_eq(st.story_level(), 4, "the story's level is where it starts plus the milestones")
	assert_eq(st.target_level(), 5, "XP levelling uses the pool's")
	assert_true(st.can_level_up(ch))
	assert_eq(st.levels_waiting(ch), 2, "level 4 then 5")
	var benched := TestChars.pregen("thistle", 2)
	st.bench.append(benched)
	assert_eq(st.levels_waiting(benched), 3, "a hero back from camp takes the levels they missed, one at a time")
	assert_eq(Xp.line(st), "Level 5 · 7,000 / 14,000 XP")


# --- Fights -------------------------------------------------------------------------------------------------------

func test_a_won_fight_pays_the_foe_share_split_four_ways_whatever_the_party() -> void:
	var foes: Array[String] = ["wolf", "wolf", "wolf", "wolf"]   # 4 x 50 XP
	for heroes: int in [1, 2, 4]:
		var st := _xp_state()
		var said := Xp.fight(st, _fight(foes, heroes), "wolf_pack", false)
		assert_eq(st.xp, 20, "200 XP x 0.4 / 4 with %d heroes (guests take no share either)" % heroes)
		assert_eq(said, "+20 XP")


func test_a_story_fight_pays_once_and_a_road_fight_every_time() -> void:
	var foes: Array[String] = ["dire_wolf", "dire_wolf"]   # 2 x 200 XP -> 40
	var st := _xp_state()
	assert_eq(Xp.fight(st, _fight(foes), "bridge_wolves", false), "+40 XP")
	assert_eq(Xp.fight(st, _fight(foes), "bridge_wolves", false), "", "the place's own fight pays once")
	assert_eq(st.xp, 40)
	assert_eq(Xp.fight(st, _fight(foes), "random_a", true), "+40 XP")
	assert_eq(Xp.fight(st, _fight(foes), "random_b", true), "+40 XP", "a road meeting, a night at camp: every time")
	assert_eq(st.xp, 120)


func test_neutrals_and_summons_give_nothing() -> void:
	var e := _fight(["wolf"])
	e.add(TestCombat.monster("dire_wolf"), &"neutral", Vector2i(9, 5))
	var called := e.add(TestCombat.monster("dire_wolf"), &"enemy", Vector2i(9, 6))
	called.set_meta("summoner", "somebody")   # called by Children of the Night
	assert_eq(Xp.foes_xp(_xp_state(), e), 5, "only the wolf: 50 x 0.4 / 4")


func test_strahd_withdrawing_pays_the_high_award_and_his_end_pays_his_stat_block() -> void:
	var st := _xp_state(Xp.threshold(7), 6)   # level 7: High is 1,700
	var e := _fight(["strahd_von_zarovich", "dire_wolf", "dire_wolf"])
	var strahd := e.combatants[e.combatants.size() - 3]
	e.legendary.departed[strahd.id] = "withdraw"
	assert_eq(Xp.foes_xp(st, e), 40 + 1700, "his wolves count as foes; he leaves alive for the High award")
	var killed := _fight(["strahd_von_zarovich", "dire_wolf", "dire_wolf"])
	assert_eq(Xp.foes_xp(st, killed), 40 + 1300, "destroyed, his own 13,000 XP x 0.4 / 4")
	var mist := _fight(["strahd_von_zarovich"])
	mist.legendary.departed[mist.combatants[mist.combatants.size() - 1].id] = "mist"
	assert_eq(Xp.foes_xp(st, mist), 1300, "only a withdrawal is spared")


func test_a_fight_talked_away_pays_what_winning_would_and_only_once() -> void:
	var st := _xp_state()
	var spec := Xp.encounter_spec(st, "doru_undercroft")
	assert_false(spec.is_empty(), "the encounter is found wherever it is")
	var want := Xp.spec_xp(spec)
	assert_true(want > 0)
	assert_eq(Xp.talked_away(st, "doru_undercroft"), "+%d XP" % want)
	assert_eq(st.xp, want)
	assert_eq(Xp.talked_away(st, "doru_undercroft"), "", "once")
	assert_eq(Xp.fight(st, _fight(["wolf"]), "doru_undercroft", false), "", "and a fight that was talked away and then fought pays nothing more")
	assert_eq(Xp.talked_away(st, "no_such_fight"), "")


# --- Quests, places, lore -----------------------------------------------------------------------------------------

func test_quests_pay_by_kind_and_a_region_climax_is_paid_by_its_milestone() -> void:
	var st := _xp_state(Xp.threshold(5), 4)   # level 5: main 750, side 250
	# A main-quest goal (Moderate).
	assert_true(st.set_quest_stage("madam_evas_reading", _success_stage("madam_evas_reading")))
	assert_eq(st.xp, Xp.threshold(5) + 750)
	# A side quest (half of Low).
	assert_true(st.set_quest_stage("the_stolen_children", "freed"))
	assert_eq(st.xp, Xp.threshold(5) + 750 + 250)
	# A quest set again pays nothing more.
	st.set_quest_stage("the_stolen_children", "freed")
	assert_eq(st.xp, Xp.threshold(5) + 1000)
	# Failure pays nothing.
	var before := st.xp
	assert_true(st.set_quest_stage("the_witch_of_berez", "arrived"))
	st.set_quest_stage("children_of_the_mill", "children_abandoned")
	assert_eq(st.xp, before, "a quest that ends in failure pays nothing")
	# A region's climax quest is the milestone's; the walk out of the mists pays nothing.
	st.set_quest_stage("children_of_the_mill", "children_freed")
	st.set_quest_stage("death_house", "escaped_refused")
	st.set_quest_stage("into_the_mists", _success_stage("into_the_mists"))
	assert_eq(st.xp, before, "the milestone pays for the climax; the mists pay nothing")


func test_a_quest_notice_says_what_it_paid() -> void:
	var st := _xp_state(Xp.threshold(5), 4)
	var said: Array[String] = []
	st.xp_gained.connect(func(t: String) -> void: said.append(t))
	st.set_quest_stage("the_stolen_children", "freed")
	assert_eq(said.size(), 1)
	assert_eq(said[0], "Quest complete: %s, +250 XP" % Compendium.shared().display_name("quests", "the_stolen_children"))


func test_arriving_pays_a_place_or_a_location_once() -> void:
	var places := Travel.map_data()["places"] as Array
	var loc := str((places[0] as Dictionary)["location"]).get_slice(":", 0)
	var place := Travel.place(Travel.place_for_location(loc))
	var st := _xp_state()
	var said: Array[String] = []
	st.xp_gained.connect(func(t: String) -> void: said.append(t))
	Xp.arrive(st, loc)
	assert_eq(st.xp, Xp.amount_for(_xp_state(), "place"), "a place on the travel map: half of Low")
	assert_eq(said.size(), 1, "and it says so")
	assert_true(said[0].begins_with("Discovered %s" % place["name"]), said[0])
	Xp.arrive(st, loc)
	assert_eq(said.size(), 1, "a place is found once")
	var other := ""
	for l in Compendium.shared().all("locations"):
		if Travel.place_for_location(str(l["id"])) == "":
			other = str(l["id"])
			break
	var after := st.xp
	Xp.arrive(st, other)
	assert_eq(st.xp, after + Xp.amount_for(_xp_state(), "location"), "any other map: Low / 10")
	assert_eq(said.size(), 1, "a new location is quiet")


func test_the_codex_pays_lore_once_and_says_so() -> void:
	var st := _xp_state(Xp.threshold(5), 4)
	assert_eq(st.add_codex("a_letter"), 13, "level 5 lore")
	assert_eq(st.xp, Xp.threshold(5) + 13)
	assert_eq(st.add_codex("a_letter"), -1, "read already")
	assert_eq(Xp.tag(13), " (+13 XP)")
	assert_eq(Xp.tag(0), "")
	assert_eq(Xp.fmt(15240), "15,240")
	assert_eq(Xp.fmt(950), "950")
	assert_eq(Xp.fmt(1234567), "1,234,567")


func test_the_sun_card_is_a_level_in_xp_mode_and_a_milestone_otherwise() -> void:
	var st := _xp_state(1000, 1)   # story level 2, XP level 3 (900)
	var ch := TestChars.pregen("ilse_varga", 3)
	st.party.append(ch)
	DeckOfManyThings._card(st, ch, "sun", DiceRoller.new(1))
	assert_eq(st.xp, 2699, "level 4 needs 2,700, but the ceiling is one short of it")
	assert_eq(st.xp_reserve, 1, "the single XP over the ceiling waits")
	assert_eq(st.milestones, 1, "not a milestone")
	var plain := StoryState.new()
	var other := TestChars.pregen("ilse_varga", 1)
	plain.party.append(other)
	DeckOfManyThings._card(plain, other, "sun", DiceRoller.new(1))
	assert_eq(plain.milestones, 1, "milestone mode still counts a milestone")
	assert_eq(plain.xp, 0)


# --- Saves --------------------------------------------------------------------------------------------------------

func test_xp_and_the_mode_are_saved_and_an_old_save_is_milestones() -> void:
	var st := _xp_state(12345, 5)
	st.xp_reserve = 678
	var back := StoryState.from_dict(st.to_dict())
	assert_eq(back.xp, 12345)
	assert_eq(back.xp_reserve, 678)
	assert_true(Xp.active(back), "the mode comes back")
	var old := StoryState.from_dict({"milestones": 3, "options": {"respec": true}})
	assert_eq(old.xp, 0)
	assert_eq(old.xp_reserve, 0)
	assert_false(Xp.active(old), "a save that never picked is milestones")
	assert_eq(old.target_level(), 4)
	# The upgrade pins old saves, whatever their version, and leaves a pick alone.
	var up := SaveSystem.upgrade({"version": 2, "story": {"options": {"respec": true}}})
	assert_eq(((up["story"] as Dictionary)["options"] as Dictionary)["levelling"], "milestone")
	var kept := SaveSystem.upgrade({"version": 2, "story": {"options": {"levelling": "xp"}}})
	assert_eq(((kept["story"] as Dictionary)["options"] as Dictionary)["levelling"], "xp")
	var bare := SaveSystem.upgrade({"version": 2, "story": {}})
	assert_eq(((bare["story"] as Dictionary)["options"] as Dictionary)["levelling"], "milestone", "a story with no options at all")
	assert_false(SaveSystem.upgrade({"version": 1}).has("story"), "Phase 0's saves held no story and get none")
