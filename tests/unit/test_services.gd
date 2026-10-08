extends TestCase
## Services (F14, story/services.gd): St. Andral's spells at the 2024 PHB's prices (Cure Wounds, Lesser Restoration,
## Remove Curse, and Raise Dead read from a scroll for its fee and the 500 gp diamond), when the party's dead died,
## the raised hero's 10 days at -4, and the Blue Water Inn's rooms, whose comforts come with the next Long Rest there.


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 3))
	st.party.append(TestChars.pregen("silvain_aster", 3))
	for ch in st.party:
		ch.finish_long_rest()
	st.gold = 5000.0
	st.location = "vallaki_st_andrals"
	return st


func _line(st: StoryState, npc: String, id: String) -> Dictionary:
	for l in Services.offered(st, npc):
		if str(l["id"]) == id:
			return l
	return {}


func test_st_andrals_offers_its_spells_at_phb_prices() -> void:
	var st := _party()
	var ids: Array[String] = []
	for l in Services.offered(st, "father_lucian"):
		ids.append(str(l["id"]))
		assert_true(bool(l["scroll"]), "Lucian reads every one from a scroll")
	assert_eq(ids, ["cure_wounds", "lesser_restoration", "remove_curse", "raise_dead"] as Array[String])
	assert_eq(float(_line(st, "father_lucian", "cure_wounds")["price"]), 50.0)
	assert_eq(float(_line(st, "father_lucian", "lesser_restoration")["price"]), 200.0)
	assert_eq(float(_line(st, "father_lucian", "remove_curse")["price"]), 300.0)
	var raise := _line(st, "father_lucian", "raise_dead")
	assert_eq(float(raise["price"]), 2000.0)
	assert_eq(Services.cost(raise), 2500.0, "the fee and the diamond")
	st.attitudes["father_lucian"] = "friendly"
	assert_eq(float(_line(st, "father_lucian", "cure_wounds")["price"]), 45.0, "a friend's price")


func test_cure_wounds_heals_the_hurt_for_a_fee() -> void:
	var st := _party()
	var ilse := st.party[0]
	var line := _line(st, "father_lucian", "cure_wounds")
	assert_ne(Services.why_not(st, line, ilse), "", "not hurt, nothing to buy")
	ilse.hp = 3
	assert_eq(Services.why_not(st, line, ilse), "")
	var said := Services.buy(st, "father_lucian", line, ilse, DiceRoller.new(5))
	assert_true(said.contains("heals"), said)
	assert_true(ilse.hp >= 3 + 2 + 2, "2d8 + Lucian's Wisdom (+2): %d" % ilse.hp)
	assert_eq(st.gold, 4950.0)


func test_lesser_restoration_ends_a_condition() -> void:
	var st := _party()
	var ch := st.party[1]
	var line := _line(st, "father_lucian", "lesser_restoration")
	assert_ne(Services.why_not(st, line, ch), "")
	ch.add_effect(Effect.new("Poisoned", &"monster", "test_poison").with_condition(&"poisoned"))
	assert_true(ch.has_condition(&"poisoned"))
	assert_eq(Services.why_not(st, line, ch), "")
	assert_true(Services.buy(st, "father_lucian", line, ch, DiceRoller.new(1)).contains("Poisoned"))
	assert_false(ch.has_condition(&"poisoned"))
	assert_eq(st.gold, 4800.0)


func test_remove_curse_lifts_curses_and_frees_a_cursed_item() -> void:
	var st := _party()
	var ch := st.party[0]
	var line := _line(st, "father_lucian", "remove_curse")
	assert_eq(Services.why_not(st, line, ch), "%s bears no curse" % ch.name.get_slice(" ", 0))
	ch.add_effect(Effect.new("Cursed: Lycanthropy", &"monster", "lycanthropy").with_modifier("flag", {"value": "curse:lycanthropy"}))
	var axe := "berserker_axe__greataxe"
	assert_true(MagicItems.is_cursed(Compendium.shared().item_data(axe)), "the Berserker Axe is cursed")
	ch.add_item(axe)
	assert_true(ch.attune(axe))
	assert_ne(ch.end_attunement_blocker(axe), "", "its curse holds on")
	assert_eq(Services.why_not(st, line, ch), "")
	Services.buy(st, "father_lucian", line, ch, DiceRoller.new(1))
	assert_true(Services.curses(ch).is_empty(), "the lycanthropy is gone")
	assert_false(axe in ch.attuned, "the axe lets go")
	assert_true(bool(ch.entry_of(axe).get("curse_lifted", false)))


func test_raise_dead_within_ten_days_with_the_ordeal() -> void:
	var st := _party()
	var dead := st.party[1]
	dead.hp = 0
	dead.dead = true
	var line := _line(st, "father_lucian", "raise_dead")
	assert_eq(Services.why_not(st, line, st.party[0]), "%s is alive" % st.party[0].name.get_slice(" ", 0))
	st.advance_minutes(3 * 24 * 60)
	assert_eq(Services.dead_for(st, dead), 3 * 24 * 60, "noted as the clock moved on")
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(Services.dead_for(copy, copy.party[1]), 3 * 24 * 60, "and remembered in a save")
	assert_eq(Services.why_not(st, line, dead), "")
	var said := Services.buy(st, "father_lucian", line, dead, DiceRoller.new(1))
	assert_true(said.contains("breathes again"), said)
	assert_false(dead.dead)
	assert_eq(dead.hp, 1, "back with 1 Hit Point")
	assert_eq(st.gold, 2500.0)
	var ordeal: Effect = null
	for fx in dead.effects:
		if fx.source_id == "raise_dead":
			ordeal = fx
	assert_true(ordeal != null, "the ordeal is on")
	var weak := dead.ability_check_bonus(&"dex").total()
	dead.remove_effect(ordeal)
	assert_eq(weak - dead.ability_check_bonus(&"dex").total(), Services.ORDEAL_PENALTY, "-4 on D20 Tests")
	dead.add_effect(ordeal)
	st.advance_minutes(9 * 24 * 60)
	assert_true(dead.effects.any(func(fx: Effect) -> bool: return fx.source_id == "raise_dead"), "still weak on day 9")
	st.advance_minutes(24 * 60 + 1)
	assert_false(dead.effects.any(func(fx: Effect) -> bool: return fx.source_id == "raise_dead"), "gone after 10 days")


func test_too_long_dead_and_the_sacrificed_cant_be_raised() -> void:
	var st := _party()
	var dead := st.party[1]
	dead.hp = 0
	dead.dead = true
	st.advance_minutes(10 * 24 * 60 + 30)
	var line := _line(st, "father_lucian", "raise_dead")
	assert_eq(Services.why_not(st, line, dead), "%s has been dead more than 10 days" % dead.name.get_slice(" ", 0))
	var st2 := _party()
	var gone := st2.party[1]
	st2.lose_member(gone, "the altar")
	assert_eq(st2.party.size(), 1, "the Death House sacrifice leaves the party for good, out of Raise Dead's reach")


func test_rooms_comfort_the_next_long_rest_there() -> void:
	var st := _party()
	st.location = "vallaki_blue_water_inn"
	var modest := _line(st, "urwin_martikov", "room_modest")
	assert_eq(float(modest["each"]), 1.0, "5 sp a head, rounded up to a whole gold piece")
	assert_eq(float(modest["price"]), 2.0, "1 gp a head for two")
	assert_eq(Services.buy(st, "urwin_martikov", modest, st.party[0], DiceRoller.new(1)).contains("yours for the night"), true)
	assert_eq(Services.why_not(st, modest, st.party[0]), "Already yours for tonight")
	for ch in st.party:
		ch.finish_long_rest()
	assert_true(Services.after_long_rest(st).contains("temporary Hit Points"))
	for ch in st.party:
		assert_eq(ch.temp_hp, ch.character_level(), "%s: level in temporary Hit Points" % ch.name)
	assert_eq(Services.after_long_rest(st), "", "a booking lasts one night")
	var best := _line(st, "urwin_martikov", "room_wealthy")
	Services.buy(st, "urwin_martikov", best, null, DiceRoller.new(1))
	st.party[0].exhaustion = 2
	st.party[0].finish_long_rest()
	Services.after_long_rest(st)
	assert_eq(st.party[0].exhaustion, 0, "the bath takes one more level")
	assert_eq(st.party[0].temp_hp, 2 * st.party[0].character_level())
	Services.buy(st, "urwin_martikov", modest, null, DiceRoller.new(1))
	st.location = "vallaki"
	assert_eq(Services.after_long_rest(st), "", "a room only comforts a rest taken there")


func test_the_church_and_the_inn_open_their_services_from_dialogue() -> void:
	for ref: String in ["vallaki/lucian:church_help", "vallaki/martikovs:room", "village_of_barovia/arik:rooms"]:
		var st := _party()
		var r := DialogueRunner.new(st, DiceRoller.new(1), null)
		r.npc_id = ref.get_slice("/", 1).get_slice(":", 0)
		assert_true(r.start(ref), ref)
		var kinds: Array[String] = []
		for i in 8:
			var beat := r.next()
			kinds.append(str(beat["kind"]))
			if str(beat["kind"]) in ["services", "end", "options"]:
				break
		assert_true("services" in kinds, "%s opens the services screen: %s" % [ref, str(kinds)])
