extends TestCase
## Owner ask (2026-10-12): foes shouldn't all go for the hero with the lowest Armor Class. Over a sample of fights,
## blows land on several heroes.


func _picks(rounds: int, monster: String) -> Dictionary:
	var count := {}
	var lowest_id := ""
	for k in rounds:
		var e := TestCombat.open_field(10 + k)
		var heroes: Array[Combatant] = []
		var ids: Array[String] = ["hedda_ironvow", "ilse_varga", "tamsin_tealeaf", "silvain_aster"]
		for i in ids.size():
			heroes.append(TestCombat.hero(e, ids[i], Vector2i(8, 1 + i * 2), 5))
		var foes: Array[Combatant] = []
		for j in 3:
			foes.append(TestCombat.foe(e, monster, Vector2i(4, 1 + j * 3)))
		TestCombat.start_with(e, foes[0])
		var low := heroes[0]
		for h in heroes:
			if h.creature.ac_value() < low.creature.ac_value():
				low = h
		lowest_id = low.creature.name
		for f in foes:
			var plan := e.ai.plan_turn(f)
			var t := plan.get("target") as Combatant
			if t != null:
				count[t.creature.name] = int(count.get(t.creature.name, 0)) + 1
				e.ai.tactics.note_strike(t)   # as its attack would: the next foe knows who's been struck
	count["_lowest"] = lowest_id
	return count


func test_blows_spread_over_the_heroes() -> void:
	var picks := _picks(6, "bandit")
	var lowest := str(picks["_lowest"])
	picks.erase("_lowest")
	var total := 0
	for k: String in picks:
		total += int(picks[k])
	print("  picks over %d blows: %s" % [total, picks])
	assert_true(picks.size() >= 3, "several heroes are picked: %s" % [picks])
	assert_true(float(picks.get(lowest, 0)) / maxf(1.0, total) < 0.6, "the lowest Armor Class (%s) isn't everyone's pick: %s" % [lowest, picks])

