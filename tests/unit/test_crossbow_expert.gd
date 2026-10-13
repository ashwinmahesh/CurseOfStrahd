extends TestCase
## Crossbow Expert's Dual Wielding (2024 PHB): the extra attack of the Light property keeps the ability modifier on its
## damage when it's made with a crossbow that has the Light property, a magic Hand Crossbow as much as a plain one.

const MAGIC := "weapon_plus_1__hand_crossbow"


func _shooter(off_hand: String, expert: bool = true) -> Character:
	var ch := TestChars.custom("ranger", "human", 4, {".4.ability_score_improvement": ["crossbow_expert" if expert else "ability_score_improvement"]})
	assert_eq(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "crossbow_expert"), expert, "Crossbow Expert taken: %s" % expert)
	for id: String in ["hand_crossbow", off_hand]:
		ch.add_item(id)
	ch.add_item("crossbow_bolt", 20)
	assert_true(ch.equip("hand_crossbow", "main_hand"), "a Hand Crossbow in the main hand")
	assert_true(ch.equip(off_hand, "off_hand"), "%s in the other" % off_hand)
	return ch


func _option(e: Encounter, c: Combatant, item_id: String) -> String:
	for o in e.attack_options(c):
		if (o["profile"] as WeaponProfile).item_id == item_id and int(o.get("set", 1)) == 1:
			return str(o["id"])
	return ""


func test_a_magic_hand_crossbow_is_the_mundane_one_underneath() -> void:
	var ch := _shooter(MAGIC)
	var p := WeaponProfile.build(ch, Compendium.shared().item_data(MAGIC))
	assert_eq(p.base_item, "hand_crossbow")
	assert_true("light" in p.properties, "still Light")
	assert_eq(p.with_ability(&"wis", ch).base_item, "hand_crossbow", "kept by with_ability")


func test_dual_wielding_keeps_the_modifier_on_a_magic_hand_crossbow() -> void:
	for expert: bool in [true, false]:
		var e := TestCombat.open_field()
		var c := e.add(_shooter(MAGIC, expert), &"party", Vector2i(2, 3))
		var t := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
		TestCombat.start_with(e, c)
		assert_true(c.creature.ability_mod(&"dex") > 0, "a Dexterity modifier to add")
		var main := _option(e, c, "hand_crossbow")
		var extra := _option(e, c, MAGIC)
		assert_false(main == "" or extra == "", "both crossbows can shoot: %s, %s" % [main, extra])
		assert_true(e.attack(c, t, main).ok)
		TestCombat.next_d20(e, 15)
		var r := e.offhand_attack(c, t, extra)
		assert_true(r.ok, r.reason)
		assert_true(r.hit, "the extra shot hits")
		assert_eq(str(e.log.entries).contains("Light extra attack: no ability modifier"), not expert,
			"the modifier dropped only without Crossbow Expert (%s)" % expert)
