extends TestCase
## The three Tarokka treasures' powers (Curse of Strahd, Phase 5): the Sunsword's blade of sunlight, the Holy Symbol of
## Ravenkind holding vampires and calling up sunlight, and the Tome of Strahd read into the codex.


func _armed(e: Encounter, item_id: String, cell: Vector2i, pregen: String) -> Combatant:
	var c := TestCombat.hero(e, pregen, cell, 9)
	var ch := c.creature as Character
	ch.add_item(item_id)
	assert_eq(ch.attune_blocker(item_id), "", "%s can attune" % ch.name)
	ch.attune(item_id)
	return c


func test_the_sunsword_cuts_with_sunlight_and_burns_the_dead() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "sunsword", Vector2i(2, 2), "ilse_varga")
	(c.creature as Character).equip("sunsword", "main_hand")
	var living := TestCombat.punching_bag(e, Vector2i(3, 2))
	var dead := TestCombat.punching_bag(e, Vector2i(3, 3), 80, "undead")
	TestCombat.start_with(e, c)
	var opt := e.option_by_id(c, "weapon:sunsword")
	assert_false(opt.is_empty(), "the Sunsword is a weapon in hand")
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	assert_eq(e.items.hit_damage_dice(c, living, opt, st).size(), 0)
	var extra := e.items.hit_damage_dice(c, dead, opt, st)
	assert_eq(extra.size(), 1, "an extra die against the Undead")
	assert_eq(str(extra[0]["type"]), "radiant")
	assert_true(e.in_sunlight(dead), "its blade sheds true sunlight")


func test_the_holy_symbol_holds_vampires_and_not_other_dead() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "holy_symbol_of_ravenkind", Vector2i(2, 2), "hedda_ironvow")
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(5, 2))
	var zombie := TestCombat.foe(e, "zombie", Vector2i(5, 4))
	TestCombat.start_with(e, c)
	var before := (c.creature as Character).charges_left("holy_symbol_of_ravenkind")
	assert_eq(before, 10)
	var held := false
	for i in 10:
		var r := e.items.use(c, "holy_symbol_of_ravenkind", "hold_vampires")
		assert_true(r.ok, r.reason)
		if spawn.creature.has_condition(&"paralyzed"):
			held = true
			break
		e.end_turn()
		while e.current() != c:
			e.end_turn()
	assert_true(held, "a vampire spawn fails a save sooner or later and is Paralyzed")
	assert_false(zombie.creature.has_condition(&"paralyzed"), "a zombie isn't a vampire")
	assert_true((c.creature as Character).charges_left("holy_symbol_of_ravenkind") < before, "it spends charges")


func test_the_holy_symbol_calls_up_sunlight() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "holy_symbol_of_ravenkind", Vector2i(2, 2), "hedda_ironvow")
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(5, 2))
	TestCombat.start_with(e, c)
	assert_false(e.in_sunlight(spawn))
	var r := e.items.use(c, "holy_symbol_of_ravenkind", "sunlight")
	assert_true(r.ok, r.reason)
	assert_true(e.in_sunlight(spawn), "true sunlight 30 ft around the bearer")
	assert_eq((c.creature as Character).charges_left("holy_symbol_of_ravenkind"), 5, "5 charges")


func test_reading_the_tome_fills_the_codex_and_tells_strahd() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("silvain_aster", 5)
	st.party.append(ch)
	ch.add_item("tome_of_strahd")
	var opts := FieldItems.options(st.party, ch, "tome_of_strahd", DiceRoller.new(1))
	assert_true(opts.any(func(o: Dictionary) -> bool: return str(o["power_id"]) == "read" and bool(o["legal"])), "it can be read")
	var start := st.total_minutes()
	var res := FieldItems.use(st, ch, "tome_of_strahd", "read", ch, DiceRoller.new(1))
	assert_true(bool(res.get("ok", false)), str(res))
	assert_true("tome_of_strahd" in st.codex)
	assert_true(bool(st.get_flag("strahd_knows_tome_read", false)))
	assert_eq(st.total_minutes() - start, 180, "a few hours")
	var entry := JournalScreen._codex_entry("tome_of_strahd")
	assert_eq(str(entry["title"]), "The Tome of Strahd")
