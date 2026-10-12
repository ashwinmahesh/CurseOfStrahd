extends TestCase
## A cantrip in place of an attack from the Spells tab (owner, 2026-10-12: "it should just intelligently let me select
## the cantrip from the cantrips tab"): a Bladesinger casts it as one attack of the Attack action, then swings.


func _bladesinger(e: Encounter) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 6, {"wizard_subclass": ["bladesinger"]})
	(ch.spellcasting[0]["cantrips"] as Array).append("fire_bolt")
	ch.inventory.append({"id": "rapier", "qty": 1, "slot": ""})
	ch.equip("rapier", "main_hand")
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["heroic_inspiration"] = "never"
	return c


func test_the_spells_tab_cantrip_is_an_attack_then_the_sword_follows() -> void:
	var e := TestCombat.open_field()
	var c := _bladesinger(e)
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var bolt := cat.find(c, "spell:fire_bolt")
	assert_eq(str(bolt["tab"]), ActionCatalog.SPELLS)
	assert_eq(str(bolt["cost"]), "attack", "one attack of the Attack action")
	assert_true(str(bolt["sub"]).begins_with("Attack cantrip"), str(bolt["sub"]))
	assert_true(cat.slots(c, cat.class_tab(c)).all(func(s: Dictionary) -> bool: return not str(s["label"]).begins_with("Cantrip attack")),
		"no separate entry on the class tab")
	assert_true(cat.perform(c, bolt, [t]).ok)
	assert_eq(c.attacks_left, 1, "the Attack action goes on")
	assert_false(c.magic_action_used, "not a Magic action")
	assert_true(bool(cat.find(c, "attack:weapon:rapier")["legal"]), "the rapier can follow")
	assert_true(e.attack(c, t, "weapon:rapier").ok)
	assert_eq(c.attacks_left, 0)


func test_after_a_sword_blow_the_cantrip_still_fits_one_attack() -> void:
	var e := TestCombat.open_field()
	var c := _bladesinger(e)
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	assert_true(e.attack(c, t, "weapon:rapier").ok, "the Attack action starts with the rapier")
	var bolt := cat.find(c, "spell:fire_bolt")
	assert_true(bool(bolt["legal"]), "the Action is spent, yet the cantrip fits the attack left: %s" % bolt["reason"])
	assert_true(cat.perform(c, bolt, [t]).ok)
	assert_eq(c.attacks_left, 0)
	assert_false(bool(cat.find(c, "spell:fire_bolt")["legal"]), "and now nothing's left")
