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


## A dead hero stays with the party (Ashwin, 2026-10-15: a body sent to camp could never be raised): camp turns them
## away, and one an older save left there comes back along, or takes a place in the party, to be raised.
func test_a_dead_hero_stays_with_the_party() -> void:
	var st := _party([])
	var fighter := st.party[1]
	assert_false(st.send_to_camp(fighter), "the body stays")
	assert_true(fighter in st.party)
	# An older save: the body went to camp before this.
	st.party.erase(fighter)
	st.bench.append(fighter)
	assert_true(st.bring_along(fighter), "brought back along")
	assert_true(fighter in st.party and not fighter in st.bench)
	var line := Services.offered(st, "father_lucian").filter(func(l: Dictionary) -> bool: return str(l["id"]) == "raise_dead")[0] as Dictionary
	st.gold = 5000.0
	assert_eq(Services.why_not(st, line, fighter), "", "and raised at the temple")
	# Swapping: a dead hero can come in from camp, and can't be swapped out to it.
	st.party.erase(fighter)
	st.bench.append(fighter)
	var spare := TestChars.pregen("thistle", 9)
	st.party.append(spare)
	assert_true(st.swap_members(spare, fighter), "the body takes a living hero's place")
	assert_false(st.swap_members(fighter, spare), "and doesn't go back")


## The scroll's or rod's power on `target`, as the inventory's "<power> on <hero>" uses it.
func _use_on(st: StoryState, ch: Character, item_id: String, target: Character) -> Dictionary:
	var opts := FieldItems.options(st.party, ch, item_id, DiceRoller.new(1))
	var revive := opts.filter(func(o: Dictionary) -> bool: return bool(o.get("revive", false)))
	assert_false(revive.is_empty(), "%s offers a way back: %s" % [item_id, str(opts)])
	if revive.is_empty():
		return {}
	assert_true(bool((revive[0] as Dictionary)["legal"]), str((revive[0] as Dictionary)["reason"]))
	return FieldItems.use(st, ch, item_id, str((revive[0] as Dictionary)["power_id"]), target, DiceRoller.new(1))


## Items that bring back the dead work outside a fight (Ashwin, 2026-10-15): a Spell Scroll of Revivify right after the
## fight, needing no diamond (2024 DMG: a scroll's spell needs no Material components); one of Raise Dead within 10
## days, with its ordeal; the Rod of Resurrection's 5 charges long after. Nothing is spent on someone out of reach.
func test_scrolls_and_the_rod_bring_back_the_dead() -> void:
	var st := _party([])
	var cleric := st.party[0]
	var fighter := st.party[1]
	assert_eq(cleric.material_worth("diamond"), 0.0, "no diamonds")
	cleric.add_item("spell_scroll__revivify", 2)
	var res := _use_on(st, cleric, "spell_scroll__revivify", fighter)
	assert_true(bool(res.get("ok", false)), str(res.get("text", "")))
	assert_false(fighter.dead, "Revivify from a scroll")
	assert_eq(fighter.hp, 1)
	assert_eq(_count(cleric, "spell_scroll__revivify"), 1, "one scroll read")
	# Too late for Revivify: nothing spent.
	fighter.hp = 0
	fighter.dead = true
	st.advance_minutes(10)
	var late := FieldItems.use(st, cleric, "spell_scroll__revivify", _revive_power(st, cleric, "spell_scroll__revivify"), fighter, DiceRoller.new(1))
	assert_false(bool(late["ok"]))
	assert_true(str(late["text"]).contains("dead too long"), str(late["text"]))
	assert_eq(_count(cleric, "spell_scroll__revivify"), 1, "the scroll is kept")
	# Raise Dead from a scroll, three days on.
	st.advance_minutes(3 * 24 * 60)
	cleric.add_item("spell_scroll__raise_dead")
	res = _use_on(st, cleric, "spell_scroll__raise_dead", fighter)
	assert_true(bool(res.get("ok", false)), str(res.get("text", "")))
	assert_false(fighter.dead, "Raise Dead from a scroll")
	assert_true(fighter.effects.any(func(fx: Effect) -> bool: return fx.source_id == "raise_dead"), "with its ordeal")
	# The Rod of Resurrection, a month on (Resurrection: within a century).
	fighter.hp = 0
	fighter.dead = true
	st.advance_minutes(30 * 24 * 60)
	cleric.add_item("rod_of_resurrection")
	assert_true(cleric.attune("rod_of_resurrection"), "a cleric attunes to it")
	var charges := cleric.charges_left("rod_of_resurrection")
	res = _use_on(st, cleric, "rod_of_resurrection", fighter)
	assert_true(bool(res.get("ok", false)), str(res.get("text", "")))
	assert_false(fighter.dead, "Resurrection from the rod")
	assert_eq(fighter.hp, fighter.max_hp(), "with every Hit Point")
	assert_eq(cleric.charges_left("rod_of_resurrection"), charges - 5, "five charges")


func _count(ch: Character, id: String) -> int:
	var n := 0
	for e in ch.inventory:
		if str(e["id"]) == id:
			n += int(e["qty"])
	return n


func _revive_power(st: StoryState, ch: Character, item_id: String) -> String:
	for o in FieldItems.options(st.party, ch, item_id, DiceRoller.new(1)):
		if bool(o.get("revive", false)):
			return str(o["power_id"])
	return ""


## In a fight, Revivify on someone dead more than a minute (10 rounds) is refused before anything is spent (Ashwin,
## 2026-10-15: the slot and diamonds, or the scroll, went for nothing).
func test_revivify_in_a_fight_refuses_the_long_dead_first() -> void:
	var e := TestCombat.open_field(3)
	var cleric := TestChars.custom("cleric", "human", 9)
	var prepared := (cleric.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "revivify" in prepared:
		prepared.append("revivify")
	TestCombat.give_components(cleric, ["revivify"])
	cleric.add_item("spell_scroll__revivify")
	cleric.finish_long_rest()
	var c := e.add(cleric, &"party", Vector2i(2, 2))
	var fallen := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2), 9)
	var foe := TestCombat.punching_bag(e, Vector2i(9, 5))
	TestCombat.start_with(e, c)
	fallen.creature.hp = 0
	fallen.creature.dead = true
	fallen.set_meta("died_round", e.round_no - 11)
	var slots := cleric.slots_left(3)
	var diamonds := cleric.material_worth("diamond")
	var r := e.spells.cast(c, "revivify", 3, [fallen])
	assert_false(r.ok, "too late")
	assert_true(r.reason.contains("dead too long"), r.reason)
	assert_eq(cleric.slots_left(3), slots, "the slot is kept")
	assert_eq(cleric.material_worth("diamond"), diamonds, "and the diamonds")
	var power := ""
	for p in e.items.powers(c):
		if str(p["item_id"]) == "spell_scroll__revivify":
			power = str((p["power"] as Dictionary).get("id", ""))
	var ir := e.items.use(c, "spell_scroll__revivify", power, [fallen])
	assert_false(ir.ok, "the scroll too")
	assert_eq(_count(cleric, "spell_scroll__revivify"), 1, "and the scroll is kept")
	# Within the minute it works.
	fallen.set_meta("died_round", e.round_no)
	assert_true(e.spells.cast(c, "revivify", 3, [fallen]).ok)
	assert_false(fallen.creature.dead)
	assert_true(foe != null)
