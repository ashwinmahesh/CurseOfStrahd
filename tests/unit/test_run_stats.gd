extends TestCase
## Run stats and achievements (N8): each story fight's tally added to the run per hero (kills, crits, natural 20s and
## 1s, falls, deaths, the hardest blow), foes defeated by kind, gold read between fights, the record saved with the
## game, and local achievements earned once and kept beside the saves.


func before_each() -> void:
	Achievements.path = "user://test_achievements_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(Achievements.path)


func after_each() -> void:
	DirAccess.remove_absolute(Achievements.path)
	Achievements.path = ""


## The arena fight played out by the test autopilot, with its four heroes in a story's party.
func _story_fight(seed_value: int) -> Array:
	var e := EncounterSetup.load_id("arena_wolves_and_zombies", DiceRoller.new(seed_value))
	var st := StoryState.new()
	for c in e.combatants:
		if c.side == &"party":
			st.party.append(c.creature as Character)
	PartyAutopilot.new(e).run(30)
	return [st, e]


func test_a_fight_is_added_to_the_run() -> void:
	var pair := _story_fight(3)
	var st := pair[0] as StoryState
	var e := pair[1] as Encounter
	st.gold = 40.0
	RunStats.add_fight(st, e)
	var rs := st.run_stats
	assert_eq(int(rs["fights"]), 1)
	assert_eq(int(rs["won"]), 1 if e.outcome == "victory" else 0)
	assert_eq(int(rs["rounds"]), e.round_no)
	var t := FightTally.tally(e)
	var kills := 0
	for row in FightTally.side_rows(e, t, "party"):
		kills += int(row["kills"])
	assert_eq(int(RunStats.totals(st)["kills"]), kills)
	var by_kind := rs["kills_by_kind"] as Dictionary
	assert_eq(int(by_kind.get("wolf", 0)) + int(by_kind.get("dire_wolf", 0)) + int(by_kind.get("zombie", 0)), kills, str(by_kind))
	assert_eq(int((rs["kills_by_type"] as Dictionary).get("undead", 0)), int(by_kind.get("zombie", 0)))
	for ch in st.party:
		var h := (rs["heroes"] as Dictionary)[RunStats.hero_key(ch)] as Dictionary
		assert_eq(str(h["name"]), ch.name)
		assert_eq(int(h["fights"]), 1)
		assert_true(int(h["hits"]) + int(h["misses"]) > 0, "%s attacked" % ch.name)
	assert_true(int((rs["best_hit"] as Dictionary)["amount"]) > 0)
	# A second fight adds to the first.
	RunStats.add_fight(st, _story_fight(5)[1] as Encounter)
	assert_eq(int(st.run_stats["fights"]), 2)
	assert_eq(RunStats.hero_rows(st).size(), 4, "the same four heroes, not eight")


func test_gold_is_read_between_fights() -> void:
	var st := StoryState.new()
	st.gold = 10.0   # a new game's purse
	RunStats.observe_gold(st)
	assert_eq(float(st.run_stats["gold_found"]), 0.0)
	st.gold = 260.0   # a chest
	RunStats.observe_gold(st)
	st.gold = 60.0    # a shop
	RunStats.observe_gold(st)
	st.gold = 1100.0
	RunStats.observe_gold(st)
	assert_eq(float(st.run_stats["gold_found"]), 1290.0)
	assert_eq(float(st.run_stats["gold_spent"]), 200.0)
	assert_eq(float(st.run_stats["gold_most"]), 1100.0)


func test_the_record_saves_with_the_game() -> void:
	var pair := _story_fight(3)
	var st := pair[0] as StoryState
	RunStats.add_fight(st, pair[1] as Encounter)
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(int(back.run_stats["fights"]), 1)
	assert_eq(int(RunStats.totals(back)["kills"]), int(RunStats.totals(st)["kills"]))
	assert_eq(StoryState.new().run_stats, {}, "a new game starts with none")


func test_heroes_at_camp_and_the_fallen_are_listed() -> void:
	var st := StoryState.new()
	var a := Pregens.build("thistle", 1)
	var b := Pregens.build("kip_smudgewick", 1)
	st.party.append(a)
	st.bench.append(b)
	st.run_stats = {"heroes": {RunStats.hero_key(a): {"name": a.name, "kills": 3}, "lost_one": {"name": "Gone Hero", "kills": 9}}}
	st.fallen.append({"name": "Gone Hero", "id": "lost_one", "how": "slain", "day": 4})
	var rows := RunStats.hero_rows(st)
	assert_eq(rows.size(), 3)
	assert_eq(int(rows[0]["kills"]), 3)
	assert_eq(str(rows[1]["status"]), "at camp")
	assert_eq(str(rows[2]["status"]), "fallen")
	assert_eq(int(RunStats.totals(st)["kills"]), 12)


func test_achievements_are_earned_once_and_kept() -> void:
	assert_true(Achievements.earned().is_empty())
	var fresh := Achievements.grant(["first_victory", "critical"] as Array[String])
	assert_eq(fresh, ["first_victory", "critical"] as Array[String])
	assert_eq(Achievements.grant(["critical", "big_hit"] as Array[String]), ["big_hit"] as Array[String], "only the new one")
	assert_true(Achievements.has("first_victory"))
	var all := Achievements.all()
	assert_true(all.size() >= Achievements.LIST.size() + 5, "the list and an achievement for each ending")
	assert_eq(all.filter(func(a: Dictionary) -> bool: return str(a["earned"]) != "").size(), 3)
	assert_eq(Achievements.name_of("ending_strahd_destroyed"), "Dawn over Barovia")
	# A run notes what it earned.
	var st := StoryState.new()
	var names := RunStats.earn(st, ["first_victory", "snake_eyes"] as Array[String])
	assert_eq(names, ["Cursed Dice"] as Array[String])
	assert_eq(st.run_stats["earned"], ["snake_eyes"])


func test_what_earns_them() -> void:
	var st := StoryState.new()
	st.run_stats = {"kills_by_kind": {"wolf": 20, "werewolf": 5}, "kills_by_type": {"undead": 49},
		"heroes": {"a": {"crits": 25, "nat1": 20, "kills": 100}}, "gold_most": 1000.0}
	var pair := _story_fight(3)
	var e := pair[1] as Encounter
	var t := FightTally.tally(e)
	var got := Achievements.for_story_fight(st, e, t)
	for id: String in ["critical", "crits_25", "snake_eyes", "kills_100", "wolves_25", "purse_1000"]:
		assert_true(id in got, "%s in %s" % [id, got])
	assert_false("undead_50" in got, "49 isn't 50")
	assert_eq("first_victory" in got, e.outcome == "victory")
	# One fight: a hard blow, a natural 20 on a Death Saving Throw, a win with one hero standing.
	var row := FightTally.side_rows(e, t, "party")[0]
	row["best_hit"] = 52
	row["death_save_20"] = 1
	var one := Achievements.for_fight(e, t)
	assert_true("big_hit" in one and "death_save_20" in one, str(one))
	assert_eq(Achievements.for_ending(st, "strahd_destroyed"), ["ending_strahd_destroyed", "none_lost"] as Array[String])
	st.fallen.append({"name": "x", "id": "x"})
	assert_eq(Achievements.for_ending(st, "new_darklord"), ["ending_new_darklord"] as Array[String])


func test_skirmish_wins_earn_theirs() -> void:
	var s := SkirmishSetup.new()
	s.add_hero(HeroLab.pregen("godrick_pendlebrook", 3), "godrick_pendlebrook")
	s.add_foe("strahd_von_zarovich")
	var e := s.build(DiceRoller.new(2))
	e.start()
	for c in e.combatants:
		if c.side == &"enemy":
			e.deal_damage(e.combatants[0], c, [{"amount": 900, "type": "radiant"}], false, "test")
	e.call("_check_over")
	assert_eq(e.outcome, "victory")
	var got := Achievements.for_skirmish(s, e, FightTally.tally(e))
	for id: String in ["skirmish_win", "skirmish_beyond", "skirmish_strahd", "big_hit"]:
		assert_true(id in got, "%s in %s" % [id, got])


func test_the_tally_knows_the_hardest_blow_and_the_killer() -> void:
	var pair := _story_fight(3)
	var e := pair[1] as Encounter
	var t := FightTally.tally(e)
	for c in e.combatants:
		var row := t[c.id] as Dictionary
		if c.side == &"enemy" and int(row["died"]) > 0:
			assert_true(str(row["killed_by"]) != "" and e.get_c(str(row["killed_by"])).side == &"party", "%s's killer" % c.name())
	var best := 0
	for row in FightTally.side_rows(e, t, "party"):
		best = maxi(best, int(row["best_hit"]))
		assert_true(int(row["best_hit"]) <= int(row["damage_dealt"]))
	assert_true(best > 0)
