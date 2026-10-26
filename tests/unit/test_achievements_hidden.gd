extends TestCase
## Hidden achievements and the fight counts behind them (easter-egg package E1, docs/story/eggs.md): the data files in
## data/achievements, the panel's "A secret" row until one is earned, what a fight tallies (foes knocked out, foes sent
## over a map's open drop, improvised throws), the burst barrels, the run's knock-out count, the side flags a story
## fight leaves, and an achievement whose `when` holds in the story.

const PUSH := "a_little_push"
const BARREL := "spark_and_barrel"
const KNOCKED := "knocked_not_killed"


func before_each() -> void:
	Achievements.path = "user://test_achievements_hidden_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(Achievements.path)
	Achievements.clear_cache()


func after_each() -> void:
	DirAccess.remove_absolute(Achievements.path)
	Achievements.path = ""
	Achievements.clear_cache()


func _row(id: String) -> Dictionary:
	for a in Achievements.all():
		if str(a["id"]) == id:
			return a
	return {}


func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	for l in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


## Ilse beside a bandit at 1 Hit Point, her Knock Out rule on `rule`, with a far foe so the fight goes on.
func _knock_fight(rule: String) -> Dictionary:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	(ilse.creature as Character).heroic_inspiration = false
	if rule != "":
		ilse.reaction_rules["knock_out"] = rule
	var bandit := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	bandit.creature.hp = 1
	TestCombat.next_d20(e, 19)
	e.attack(ilse, bandit, str(e.best_melee_option(ilse, bandit)["id"]))
	while e.pending != null:
		e.answer_reaction(false)
	return {"e": e, "ilse": ilse, "bandit": bandit}


## A map with a chasm along its bottom edge: whatever is shoved off row 1 goes over.
func _chasm() -> Encounter:
	var e := TestCombat.encounter(["......", "......", "      ", "      "], 5)
	e.grid.drop_ft = 200
	return e


func _place(e: Encounter, kind: String, cell: Vector2i) -> BattleObject:
	var one: Array[Vector2i] = [cell]
	return e.objects.add(kind, one, {})


# --- The list -------------------------------------------------------------------------------------

func test_hidden_achievements_load_from_data_and_stay_secret_until_earned() -> void:
	for id: String in [PUSH, BARREL, KNOCKED]:
		var row := _row(id)
		assert_false(row.is_empty(), "%s is listed" % id)
		assert_true(bool(row.get("hidden", false)), "%s is hidden" % id)
		assert_eq(str(row.get("name", "")), Achievements.HIDDEN_NAME, "%s says nothing yet" % id)
		assert_eq(str(row.get("text", "")), Achievements.HIDDEN_TEXT)
		assert_eq(str(row.get("earned", "x")), "")
	assert_eq(Achievements.name_of(PUSH), "A Little Push", "the toast and the ending name it")
	assert_eq(Achievements.grant([PUSH] as Array[String]), [PUSH] as Array[String])
	var got := _row(PUSH)
	assert_eq(str(got["name"]), "A Little Push", "earned: its own name")
	assert_true(str(got["text"]).length() > 10 and str(got["text"]) != Achievements.HIDDEN_TEXT, "and how it is earned")
	assert_ne(str(got["earned"]), "")
	assert_eq(str(_row(BARREL)["name"]), Achievements.HIDDEN_NAME, "the others stay secret")


func test_the_list_keeps_its_order_and_every_id_once() -> void:
	var ids: Array[String] = []
	for a in Achievements.all():
		ids.append(str(a["id"]))
	var seen := {}
	for id in ids:
		assert_false(seen.has(id), "%s listed twice" % id)
		seen[id] = true
	var last_listed := 0
	for id: String in Achievements.listed():
		last_listed = maxi(last_listed, ids.find(id))
	assert_true(ids.find(PUSH) > last_listed, "the hidden ones follow the sixteen")
	var first_ending := ids.size()
	for i in ids.size():
		if ids[i].begins_with("ending_"):
			first_ending = mini(first_ending, i)
	assert_true(ids.find(KNOCKED) < first_ending, "and come before the endings")
	for def in Achievements.hidden_defs():
		assert_false(Achievements.listed().has(str(def["id"])), "no clash with a listed one")


func test_the_panel_shows_a_secret_row_until_it_is_earned() -> void:
	var before := AchievementsPanel.list(900.0)
	var texts := _labels(before)
	assert_true(Achievements.HIDDEN_NAME in texts, "a row reading A secret")
	assert_false("A Little Push" in texts, "its name stays out of the panel")
	assert_false("Knocked, Not Killed" in texts)
	before.free()
	Achievements.grant([PUSH] as Array[String])
	var after := AchievementsPanel.list(900.0)
	texts = _labels(after)
	assert_true("A Little Push" in texts, "earned: named")
	assert_true(Achievements.HIDDEN_NAME in texts, "the rest are still secret")
	after.free()


# --- What a fight tallies -------------------------------------------------------------------------

func test_a_knock_out_is_counted_and_is_not_a_kill() -> void:
	var f := _knock_fight("auto")
	var e := f["e"] as Encounter
	var ilse := f["ilse"] as Combatant
	assert_true((f["bandit"] as Combatant).creature.has_flag("knocked_out"), "the setup knocked it out")
	var t := FightTally.tally(e)
	assert_eq(int((t[ilse.id] as Dictionary)["knocked_out"]), 1, "credited to the one who struck")
	assert_eq(int((t[ilse.id] as Dictionary)["kills"]), 0, "the bandit lives")
	assert_eq(int((t[(f["bandit"] as Combatant).id] as Dictionary)["died"]), 0)
	var killed := _knock_fight("")
	var t2 := FightTally.tally(killed["e"] as Encounter)
	var row := t2[(killed["ilse"] as Combatant).id] as Dictionary
	assert_eq([int(row["knocked_out"]), int(row["kills"])], [0, 1], "with the rule off it is a kill, as ever")


func test_a_foe_sent_over_the_drop_on_a_heros_turn_is_counted_for_that_hero() -> void:
	var e := _chasm()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 0))
	var bag := TestCombat.punching_bag(e, Vector2i(2, 1), 500)
	TestCombat.start_with(e, hero)
	e.forced_move(bag, e.center_of(hero), 5)
	assert_true(bag.has_meta("left_fight"), "over the edge")
	var t := FightTally.tally(e)
	assert_eq(int((t[hero.id] as Dictionary)["pushed_over"]), 1)
	assert_true(PUSH in Achievements.for_fight(e, t), "A Little Push")


func test_a_hero_going_over_or_a_foes_push_does_not_count() -> void:
	var e := _chasm()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 1))
	var bag := TestCombat.punching_bag(e, Vector2i(2, 0), 500)
	TestCombat.start_with(e, bag)   # the foe's turn
	e.forced_move(hero, e.center_of(bag), 5)
	assert_true(hero.has_meta("left_fight"), "the hero went over")
	var t := FightTally.tally(e)
	for id: String in t:
		assert_eq(int((t[id] as Dictionary)["pushed_over"]), 0)
	assert_false(PUSH in Achievements.for_fight(e, t))
	# A foe the hero shoves only along the ground goes nowhere near the drop.
	var flat := TestCombat.open_field()
	var h2 := TestCombat.hero(flat, "ilse_varga", Vector2i(2, 3))
	var b2 := TestCombat.punching_bag(flat, Vector2i(3, 3), 500)
	TestCombat.start_with(flat, h2)
	flat.forced_move(b2, flat.center_of(h2), 5)
	assert_false(PUSH in Achievements.for_fight(flat, FightTally.tally(flat)))


func test_a_thrown_chair_is_an_improvised_throw_and_a_javelin_from_the_ground_is_not() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var chair := _place(e, "chair", Vector2i(3, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	TestCombat.start_with(e, ilse)
	var flung := {}
	for o in e.attack_options(ilse):
		if str(o["id"]) == "improvised:o:" + chair.id:
			flung = o
	assert_false(flung.is_empty(), "a chair within reach is a weapon")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(ilse, bag, str(flung["id"])).ok)
	var t := FightTally.tally(e)
	assert_eq(int((t[ilse.id] as Dictionary)["improvised"]), 1)
	e.ground.land(ilse, "javelin", {}, "", null, Vector2i(2, 4))
	ilse.free_interaction_available = true
	ilse.action_available = true
	var javelin := {}
	for o in e.attack_options(ilse):
		if str(o["id"]).begins_with("improvised:g:"):
			javelin = o
	assert_false(javelin.is_empty())
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(ilse, bag, str(javelin["id"])).ok)
	assert_eq(int((FightTally.tally(e)[ilse.id] as Dictionary)["improvised"]), 1, "a thrown weapon is thrown as itself")


# --- Burst barrels --------------------------------------------------------------------------------

func _barrel_fight(foes: int) -> Encounter:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3))
	var barrel := _place(e, "oil_barrel", Vector2i(5, 3))
	for i in foes:
		var bag := TestCombat.punching_bag(e, Vector2i(6, 3 + i * 2 - 1), 80)
		bag.creature.add_condition(&"stunned", "test")
	TestCombat.start_with(e, ilse)
	e.objects.damage(barrel, [{"amount": 1, "type": "fire"}], ilse, "a torch")
	assert_true(barrel.destroyed, "it bursts")
	return e


func test_one_burst_barrel_that_catches_two_foes_earns_spark_and_barrel() -> void:
	var two := _barrel_fight(2)
	assert_eq([two.objects.fire.bursts, two.objects.fire.most_foes_hit], [1, 2])
	assert_true(BARREL in Achievements.for_fight(two, FightTally.tally(two)))
	var one := _barrel_fight(1)
	assert_eq([one.objects.fire.bursts, one.objects.fire.most_foes_hit], [1, 1])
	assert_false(BARREL in Achievements.for_fight(one, FightTally.tally(one)), "one foe is not two")
	var none := TestCombat.open_field()
	assert_eq([none.objects.fire.bursts, none.objects.fire.most_foes_hit], [0, 0])


func test_two_barrels_one_foe_each_is_not_one_burst_catching_two() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	var a := _place(e, "oil_barrel", Vector2i(5, 1))
	var b := _place(e, "oil_barrel", Vector2i(5, 7))
	var bag_a := TestCombat.punching_bag(e, Vector2i(6, 1), 80)
	var bag_b := TestCombat.punching_bag(e, Vector2i(6, 7), 80)
	bag_a.creature.add_condition(&"stunned", "test")
	bag_b.creature.add_condition(&"stunned", "test")
	TestCombat.start_with(e, ilse)
	e.objects.damage(a, [{"amount": 1, "type": "fire"}], ilse, "a torch")
	e.objects.damage(b, [{"amount": 1, "type": "fire"}], ilse, "a torch")
	assert_eq([e.objects.fire.bursts, e.objects.fire.most_foes_hit], [2, 1])
	assert_false(BARREL in Achievements.for_fight(e, FightTally.tally(e)))


# --- The run ---------------------------------------------------------------------------------------

func test_the_run_adds_up_knock_outs_and_ten_earn_knocked_not_killed() -> void:
	var f := _knock_fight("auto")
	var e := f["e"] as Encounter
	var st := StoryState.new()
	st.party.append((f["ilse"] as Combatant).creature as Character)
	var t := RunStats.add_fight(st, e)
	assert_eq(int(RunStats.totals(st)["knocked_out"]), 1)
	assert_false(KNOCKED in Achievements.for_story_fight(st, e, t))
	var key := RunStats.hero_key((f["ilse"] as Combatant).creature as Character)
	((st.run_stats["heroes"] as Dictionary)[key] as Dictionary)["knocked_out"] = 9
	assert_false(KNOCKED in Achievements.for_story_fight(st, e, t), "nine is not ten")
	((st.run_stats["heroes"] as Dictionary)[key] as Dictionary)["knocked_out"] = 10
	assert_true(KNOCKED in Achievements.for_story_fight(st, e, t), "ten, over the run")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(int(RunStats.totals(back)["knocked_out"]), 10, "the count saves with the game")


func test_a_story_fight_leaves_its_side_flags() -> void:
	var st := StoryState.new()
	var quiet := TestCombat.open_field()
	TestCombat.start_with(quiet, TestCombat.hero(quiet, "ilse_varga", Vector2i(2, 3)))
	TestCombat.punching_bag(quiet, Vector2i(9, 3))
	Achievements.note_fight(st, quiet, FightTally.tally(quiet))
	for flag: String in ["eggs_pushed_over_edge", "eggs_barrel_burst", "eggs_threw_furniture"]:
		assert_false(st.get_flag(flag, false), "%s waits for the deed" % flag)
	var pushed := _chasm()
	var hero := TestCombat.hero(pushed, "ilse_varga", Vector2i(2, 0))
	var bag := TestCombat.punching_bag(pushed, Vector2i(2, 1), 500)
	TestCombat.start_with(pushed, hero)
	pushed.forced_move(bag, pushed.center_of(hero), 5)
	Achievements.note_fight(st, pushed, FightTally.tally(pushed))
	assert_true(bool(st.get_flag("eggs_pushed_over_edge", false)))
	assert_false(bool(st.get_flag("eggs_barrel_burst", false)))
	var boom := _barrel_fight(1)
	Achievements.note_fight(st, boom, FightTally.tally(boom))
	assert_true(bool(st.get_flag("eggs_barrel_burst", false)), "any burst barrel, even one that catches no one")
	var chairs := TestCombat.open_field()
	var ilse := TestCombat.hero(chairs, "ilse_varga", Vector2i(2, 3))
	var chair := _place(chairs, "chair", Vector2i(3, 3))
	var target := TestCombat.punching_bag(chairs, Vector2i(6, 3), 80)
	TestCombat.start_with(chairs, ilse)
	TestCombat.next_d20(chairs, 19)
	chairs.attack(ilse, target, "improvised:o:" + chair.id)
	Achievements.note_fight(st, chairs, FightTally.tally(chairs))
	assert_true(bool(st.get_flag("eggs_threw_furniture", false)))


# --- An achievement the story earns ---------------------------------------------------------------

func test_a_data_achievement_with_a_when_is_earned_once_when_it_holds() -> void:
	Achievements.register({"id": "test_flagged", "name": "Test Flagged", "text": "Set the flag.", "hidden": true,
		"when": "flag.test_flagged_deed"})
	var st := StoryState.new()
	var toasts: Array[String] = []
	var say := func(t: String) -> void: toasts.append(t)
	assert_eq(Achievements.check_story(st, say), [] as Array[String], "nothing yet")
	assert_false(Achievements.has("test_flagged"))
	st.set_flag("test_flagged_deed", true)
	assert_eq(Achievements.check_story(st, say), ["Test Flagged"] as Array[String])
	assert_eq(toasts, ["Achievement: Test Flagged"] as Array[String])
	assert_true(Achievements.has("test_flagged"))
	assert_eq(st.run_stats["earned"], ["test_flagged"], "the run notes it for the ending")
	assert_eq(Achievements.check_story(st, say), [] as Array[String], "once")
	assert_eq(toasts.size(), 1)
	Achievements.clear_cache()
	assert_true(_row("test_flagged").is_empty(), "a test's own entry goes with the cache")
