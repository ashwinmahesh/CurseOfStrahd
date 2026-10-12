extends TestCase
## Bringing back the dead outside a fight (owner, 2026-10-12: Revivify worked only inside the fight, and a party caster's
## Raise Dead used up its diamond and did nothing): Revivify right after the fight that killed them, Raise Dead and
## Reincarnate within 10 days, Resurrection and True Resurrection from long ago, and Gentle Repose stopping the clock.
## Each spends its slot, its component and its casting time (FieldCasting.revive).


## A cleric at `level` who prepares `spells`, with their components, and a fighter who has just died.
func _party(spells: Array, level: int = 9) -> StoryState:
	var st := StoryState.new()
	var cleric := TestChars.custom("cleric", "human", level)
	var prepared := (cleric.spellcasting[0] as Dictionary)["prepared"] as Array
	for s: Variant in spells:
		if not str(s) in prepared:
			prepared.append(str(s))
	TestCombat.give_components(cleric, spells)
	cleric.finish_long_rest()
	var fighter := TestChars.pregen("ilse_varga", mini(level, 9))
	st.party.append(cleric)
	st.party.append(fighter)
	fighter.hp = 0
	fighter.dead = true
	st.advance_minutes(1)   # the fight that killed them ends (LocationFights)
	return st


func _option(st: StoryState, id: String) -> Dictionary:
	for o in FieldCasting.revival_options(st, st.party[0]):
		if str(o["id"]) == id:
			return o
	return {}


func test_revivify_right_after_the_fight() -> void:
	var st := _party(["revivify"])
	var cleric := st.party[0]
	var fighter := st.party[1]
	var o := _option(st, "revivify")
	assert_true(bool(o["legal"]), str(o["reason"]))
	assert_eq(o["targets"], [fighter])
	var slots := cleric.slots_left(3)
	var res := FieldCasting.revive(st, cleric, "revivify", 0, fighter)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_false(fighter.dead)
	assert_eq(fighter.hp, 1)
	assert_eq(cleric.slots_left(3), slots - 1)
	assert_eq(cleric.material_worth("diamond"), 0.0, "the diamond is used up")


func test_revivify_is_too_late_after_a_few_minutes() -> void:
	var st := _party(["revivify"])
	st.advance_minutes(5)
	var o := _option(st, "revivify")
	assert_false(bool(o["legal"]))
	assert_true(str(o["reason"]).contains("dead too long"), str(o["reason"]))
	assert_false(bool(FieldCasting.revive(st, st.party[0], "revivify", 0, st.party[1])["ok"]))
	assert_true(st.party[1].dead)


func test_raise_dead_within_ten_days_and_its_ordeal() -> void:
	var st := _party(["raise_dead"])
	var cleric := st.party[0]
	var fighter := st.party[1]
	st.advance_minutes(3 * 24 * 60)
	cleric.finish_long_rest()
	var before := st.total_minutes()
	var res := FieldCasting.revive(st, cleric, "raise_dead", 0, fighter)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_false(fighter.dead)
	assert_eq(fighter.hp, 1)
	assert_true(fighter.effects.any(func(fx: Effect) -> bool: return fx.name == "Back from the dead"), "-4 on D20 Tests for 10 days")
	assert_eq(st.total_minutes() - before, 60, "an hour's casting")
	assert_eq(cleric.material_worth("diamond"), 0.0)


func test_raise_dead_is_too_late_after_ten_days() -> void:
	var st := _party(["raise_dead"])
	st.advance_minutes(11 * 24 * 60)
	assert_false(bool(_option(st, "raise_dead")["legal"]))


func test_gentle_repose_stops_the_clock() -> void:
	var st := _party(["gentle_repose", "raise_dead"])
	var cleric := st.party[0]
	var fighter := st.party[1]
	st.advance_minutes(8 * 24 * 60)
	var res := FieldCasting.revive(st, cleric, "gentle_repose", 0, fighter)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_true(fighter.dead, "it keeps the body; it doesn't bring them back")
	st.advance_minutes(6 * 24 * 60)
	assert_true(Services.dead_for(st, fighter) < 10 * 24 * 60, "the days under Gentle Repose don't count: %d" % Services.dead_for(st, fighter))
	cleric.finish_long_rest()
	assert_true(bool(_option(st, "raise_dead")["legal"]), "still in time for Raise Dead after 14 days")


func test_reincarnate_pays_for_its_oils_and_comes_back_whole() -> void:
	var st := _party(["reincarnate"])
	var fighter := st.party[1]
	st.gold = 500.0
	assert_false(bool(_option(st, "reincarnate")["legal"]), "the purse can't buy the oils")
	st.gold = 1500.0
	var res := FieldCasting.revive(st, st.party[0], "reincarnate", 0, fighter)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_eq(fighter.hp, fighter.max_hp())
	assert_eq(roundi(st.gold), 500)


func test_resurrection_and_true_resurrection_reach_far_back() -> void:
	for id: String in ["resurrection", "true_resurrection"]:
		var st := _party([id], 17)
		var fighter := st.party[1]
		st.advance_minutes(40 * 24 * 60)
		st.party[0].finish_long_rest()
		var res := FieldCasting.revive(st, st.party[0], id, 0, fighter)
		assert_true(bool(res["ok"]), "%s: %s" % [id, res["text"]])
		assert_eq(fighter.hp, fighter.max_hp(), id)
