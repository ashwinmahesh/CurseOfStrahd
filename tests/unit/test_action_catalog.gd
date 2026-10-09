extends TestCase
## The hotbar's action catalog (combat view spec): what each pregen can do, why not, and the previews.


func _ids(list: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for a in list:
		out.append(str(a["id"]))
	return out


func test_every_standard_action_is_on_common() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var ids := _ids(cat.actions_for(ilse))
	for want: String in ["attack:weapon:greatsword", "grapple", "shove_prone", "shove_push", "dash", "disengage", "dodge",
			"help", "hide", "search", "study", "ready", "stabilize", "influence", "utilize", "second_wind", "action_surge"]:
		assert_true(want in ids, "%s on the hotbar" % want)
	assert_eq(cat.class_tab(ilse), "Fighter")
	assert_true(ActionCatalog.SPELLS not in cat.tabs_for(ilse), "no Spells tab for a Fighter")


func test_greyed_slots_say_why() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 100
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	assert_true(cat.perform(ilse, cat.find(ilse, "attack:weapon:greatsword"), [z]).ok)
	var dash := cat.find(ilse, "dash")
	assert_false(bool(dash["legal"]))
	assert_eq(str(dash["reason"]), "Action already used")
	assert_true(bool(cat.find(ilse, "second_wind")["legal"]), "Bonus Action still free")
	assert_false(bool(cat.find(ilse, "influence")["legal"]))


func test_cleric_and_wizard_tabs() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2))
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	TestCombat.foe(e, "zombie", Vector2i(5, 2))
	TestCombat.start_with(e, h)
	var cat := ActionCatalog.new(e)
	var hid := _ids(cat.actions_for(h))
	for want: String in ["turn_undead", "divine_spark_heal", "divine_spark_harm", "preserve_life", "spell:healing_word",
			"spell:spiritual_weapon", "spell:sanctuary", "spell:bless", "spell:toll_the_dead", "spell:command:grovel",
			"spell:command:halt", "spell:command:flee"]:
		assert_true(want in hid, want)
	assert_true(bool(cat.find(h, "turn_undead")["legal"]), "a zombie is within 30 ft")
	var sleep := cat.find(s, "spell:sleep")
	assert_eq(str(sleep["targeting"]), "point")
	assert_eq(str(cat.find(s, "spell:thunderwave")["targeting"]), "direction")
	assert_eq(str(cat.find(s, "spell:magic_missile")["targeting"]), "multi")
	assert_eq(cat.slot_choices(s, "magic_missile"), [1, 2] as Array[int])


func test_attack_preview_shows_odds_and_sources() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	w.creature.add_condition(&"prone")
	TestCombat.start_with(e, t)
	var cat := ActionCatalog.new(e)
	var pv := cat.attack_preview(t, cat.find(t, "attack:weapon:shortsword"), w)
	var text := "\n".join(pv["lines"] as Array)
	assert_true(text.contains("hit "), text)
	assert_true(text.contains("Advantage: target Prone within 5 ft"), text)
	assert_true(text.contains("Sneak Attack"), text)
	assert_true(text.contains("defenses unknown"), text)
	assert_true(float(pv["chance"]) > 0.8)


func test_spell_preview_lists_who_is_in_the_area() -> void:
	var e := TestCombat.open_field()
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	TestCombat.foe(e, "wolf", Vector2i(3, 3))
	TestCombat.foe(e, "zombie", Vector2i(4, 4))
	TestCombat.start_with(e, s)
	var cat := ActionCatalog.new(e)
	var pv := cat.spell_preview(s, cat.find(s, "spell:thunderwave"), Vector2.INF, Vector2.RIGHT)
	var lines: Array[String] = []
	for w: Dictionary in pv["creatures"]:
		lines.append(str(w["line"]))
	assert_eq(lines.size(), 3, str(lines))
	assert_true((pv["warnings"] as Array).any(func(x: String) -> bool: return x.contains("Friendly fire") and x.contains(ilse.name())))
	assert_true(lines.any(func(x: String) -> bool: return x.contains("Con save DC 13")), str(lines))


func test_move_preview_warns_about_opportunity_attacks() -> void:
	var e := TestCombat.open_field()
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	TestCombat.foe(e, "wolf", Vector2i(3, 3))
	TestCombat.start_with(e, s)
	var cat := ActionCatalog.new(e)
	var mp := cat.move_preview(s, Vector2i(0, 3))
	assert_true(bool(mp["ok"]))
	assert_eq(int(mp["cost"]), 10)
	assert_eq(int(mp["left"]), 20)
	assert_true((mp["warnings"] as Array).any(func(x: String) -> bool: return x.contains("Opportunity Attack")))
	assert_false(bool(cat.move_preview(s, Vector2i(3, 3))["ok"]), "occupied")


func test_prone_move_preview_includes_standing_up() -> void:
	var e := TestCombat.open_field()
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	TestCombat.foe(e, "zombie", Vector2i(10, 7))
	TestCombat.start_with(e, s)
	s.creature.add_condition(&"prone")
	var cat := ActionCatalog.new(e)
	var mp := cat.move_preview(s, Vector2i(4, 3))
	assert_eq(int(mp["cost"]), 25, "15 ft to stand, 10 ft to walk")
	var r := e.move(s, Vector2i(4, 3))
	assert_true(r.ok)
	assert_eq(s.movement_left, 5)


func test_details_for_weapons_spells_and_features() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 4))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var w := cat.details(ilse, cat.find(ilse, "attack:weapon:greatsword"))
	var wt := "\n".join(w["lines"] as Array)
	assert_eq(str(w["title"]), "Greatsword")
	assert_true(wt.contains("Attack: ") and wt.contains("2d6+3 Slashing"), wt)
	assert_true(wt.contains("Mastery, Graze"), wt)
	assert_true(wt.contains("Heavy:") and wt.contains("Two-handed:"), wt)
	assert_true(wt.contains("Critical Hit on a 19-20"), "Improved Critical")
	var sp := cat.details(s, cat.find(s, "spell:sleep"))
	var st := "\n".join(sp["lines"] as Array)
	assert_true(st.contains("Level 1 Enchantment"), st)
	assert_true(st.contains("Concentration, up to 1 minute"), st)
	assert_true(st.contains("Wisdom saving throw, DC"), st)
	assert_true(st.contains("Your slots: 1st 4/4 · 2nd 2/2"), st)
	var sw := cat.details(ilse, cat.find(ilse, "second_wind"))
	assert_true("\n".join(sw["lines"] as Array).contains("1d10"), str(sw))
	var dash := cat.details(ilse, cat.find(ilse, "dash"))
	assert_true("\n".join(dash["lines"] as Array).contains("extra movement"), str(dash))


func test_slot_pips() -> void:
	var e := TestCombat.open_field()
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 4))
	var i := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, s)
	var cat := ActionCatalog.new(e)
	(s.creature as Character).expend_slot(1)
	var pips := cat.slot_pips(s)
	assert_eq(pips.size(), 2)
	assert_eq(int(pips[0]["left"]), 3)
	assert_eq(int(pips[0]["total"]), 4)
	assert_true(cat.slot_pips(i).is_empty(), "no slots for a Fighter")



func test_attacks_cant_target_their_own_user_but_self_spells_can() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(4, 2))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	assert_eq(cat.target_why(ilse, cat.find(ilse, "attack:weapon:greatsword"), ilse), "Can't attack yourself", "no swinging at yourself")
	var bolt := {}
	var heal := {}
	for a in cat.actions_for(silvain):
		if str(a.get("spell_id", "")) == "fire_bolt":
			bolt = a
	for a2 in cat.actions_for(hedda):
		if str(a2.get("spell_id", "")) == "healing_word":
			heal = a2
	assert_false(bolt.is_empty() or heal.is_empty())
	assert_eq(cat.target_why(silvain, bolt, silvain), "Can't attack yourself", "an attack-roll spell can't target its caster")
	assert_eq(cat.target_why(hedda, heal, hedda), "", "a spell for a creature you can see can still be cast on yourself")


func test_warding_bond_goes_on_another_creature_and_an_ally_spell_on_yourself() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	(((hedda.creature as Character).spellcasting[0] as Dictionary)["prepared"] as Array).append_array(["warding_bond",
		"protection_from_evil_and_good"])
	TestCombat.start_with(e, hedda)
	var cat := ActionCatalog.new(e)
	var spells := {}
	for a in cat.actions_for(hedda):
		spells[str(a.get("spell_id", ""))] = a
	assert_true(spells.has("warding_bond") and spells.has("protection_from_evil_and_good"), str(spells.keys()))
	assert_eq(cat.target_why(hedda, spells["warding_bond"], hedda), "Choose another creature", "the 2024 spell bonds another")
	assert_eq(cat.target_why(hedda, spells["warding_bond"], ilse), "")
	assert_eq(cat.target_why(hedda, spells["protection_from_evil_and_good"], hedda), "", "a willing creature you touch: you too")


func test_advantage_and_disadvantage_are_flagged_in_the_preview_and_the_roll() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 100
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	z.creature.add_condition(&"prone", "test")
	var pv := cat.attack_preview(ilse, cat.find(ilse, "attack:weapon:greatsword"), z)
	assert_eq(str(pv["edge"]), "advantage")
	assert_true(str(pv["title"]).ends_with("ADVANTAGE"), str(pv["title"]))
	e.events.clear()
	e.attack(ilse, z, "weapon:greatsword")
	var ev := {}
	for x: Dictionary in e.events:
		if str(x["type"]) == "attack":
			ev = x
	assert_eq(str((ev.get("edge", {}) as Dictionary).get("kind", "")), "advantage", "the roll carries its edge for the display")
	assert_true(((ev["edge"] as Dictionary)["why"] as Array).size() > 0, "and why")


func test_right_click_square_menu_lists_move_and_what_you_can_do_to_whoever_is_there() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var on_foe := cat.square_actions(ilse, z.cell)
	var ids: Array = on_foe.map(func(x: Dictionary) -> String: return str(x["id"]))
	assert_true("move" in ids and "info" in ids)
	assert_true("act:attack:weapon:greatsword" in ids, str(ids))
	var mv := on_foe[0] as Dictionary
	assert_false(bool(mv["enabled"]), "can't stop in a foe's square")
	var on_ally := cat.square_actions(ilse, hedda.cell)
	assert_true(str((on_ally[0] as Dictionary)["why"]).contains("through"), "an ally's square: pass through, don't stop")
	assert_false(on_ally.any(func(x: Dictionary) -> bool: return str(x["id"]).begins_with("act:attack")), "no attacking a friend from the menu by accident")
	var empty := cat.square_actions(ilse, Vector2i(6, 5))
	assert_eq(empty.size(), 1, "an empty square: just Move here")
	assert_true(bool((empty[0] as Dictionary)["enabled"]))


func test_lay_on_hands_heals_the_chosen_amount_and_smites_wait_for_a_hit() -> void:
	var e := TestCombat.open_field()
	var ch := TestChars.custom("paladin", "human", 3)
	var p := e.add(ch, &"party", Vector2i(2, 2))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 200
	TestCombat.start_with(e, p)
	var cat := ActionCatalog.new(e)
	ally.creature.hp = 5
	var loh := cat.find(p, "feat:cf:lay_on_hands")
	assert_false((loh.get("choices", []) as Array).is_empty(), "amounts to pick from")
	var three := loh.duplicate(true)
	three["opts"] = {"choice": "3"}
	assert_true(cat.perform(p, three, [ally]).ok)
	assert_eq(ally.creature.hp, 8, "exactly the 3 points chosen")
	assert_eq(ch.resource_left("lay_on_hands"), 12, "15 - 3 left in the pool")
	# Divine Smite from the Spells tab arms it; a miss spends nothing.
	p.bonus_available = true
	assert_true(cat.perform(p, cat.find(p, "spell:divine_smite")).ok)
	assert_true("smite:divine_smite" in p.armed, "armed for the next hit")
	var free := ch.resource_left("spell:divine_smite")
	var slots := ch.slots_left(1)
	TestCombat.next_d20(e, 1)
	var miss := e.attack(p, z, str(e.attack_options(p)[0]["id"]))
	# A human's Heroic Inspiration offers a reroll on the miss: decline it.
	if miss.is_paused():
		e.answer_reaction(false)
	assert_eq(ch.resource_left("spell:divine_smite"), free, "the free smite isn't spent on a miss")
	assert_eq(ch.slots_left(1), slots, "nor a slot")
	assert_true("smite:divine_smite" in p.armed, "still armed for a later hit")
