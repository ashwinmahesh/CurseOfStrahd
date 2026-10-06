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
