extends TestCase
## Only equipped weapons attack (owner 2026-10-09, deviations.md: Weapon sets): the weapons in hand and the second set,
## which an attack or Swap weapons takes in hand; a weapon only in the pack can't be used, by the party or the AI.


func _option_ids(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for o in e.attack_options(c):
		out.append(str(o["id"]))
	return out


func _attacks_made(e: Encounter, by: Combatant) -> Array[String]:
	var out: Array[String] = []
	for ev: Variant in e.events:
		var d := ev as Dictionary
		if str(d.get("type", "")) == "attack" and str(d.get("attacker", "")) == by.id:
			out.append(str(d.get("action", "")))
	return out


func test_a_new_hero_holds_what_they_would_reach_for() -> void:
	# Thistle carries a scimitar, a shortsword and two bows: two Light blades in hand, the better bow in set II.
	var th := TestChars.pregen("thistle", 5)
	assert_eq(th.held_id("main_hand"), "scimitar")
	assert_eq(th.held_id("off_hand"), "shortsword", "a second Light weapon in the free off hand")
	assert_eq(str(th.weapon_set_2.get("main_hand", "")), "longbow", "the better bow in the second set")
	# Ilse's greatsword takes both hands; her shortbow goes in the second set.
	var il := TestChars.pregen("ilse_varga", 5)
	assert_eq(il.held_id("main_hand"), "greatsword")
	assert_eq(il.held_id("off_hand"), "")
	assert_eq(str(il.weapon_set_2.get("main_hand", "")), "shortbow")


func test_weapons_only_in_the_pack_cant_attack() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 100
	TestCombat.start_with(e, ilse)
	var ids := _option_ids(e, ilse)
	assert_true("weapon:greatsword" in ids, "the greatsword in hand")
	assert_true("weapon:shortbow" in ids, "the shortbow in the second set")
	for gone: String in ["weapon:flail", "weapon:spear", "thrown:spear", "weapon:javelin", "thrown:javelin"]:
		assert_false(gone in ids, "%s is only in the pack" % gone)
	var cat := ActionCatalog.new(e)
	assert_true(cat.find(ilse, "attack:weapon:flail").is_empty(), "no hotbar slot for a weapon in the pack")
	assert_false(e.attack(ilse, z, "weapon:flail").ok, "and no attack with it")
	assert_true(str(cat.find(ilse, "attack:weapon:shortbow")["sub"]).ends_with("set II"), "the second set's weapon says so")


func test_attacking_with_the_second_set_takes_it_in_hand() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(8, 2))
	z.creature.hp = 100
	TestCombat.start_with(e, ilse)
	var ch := ilse.creature as Character
	assert_true(e.attack(ilse, z, "weapon:shortbow").ok)
	assert_eq(ch.held_id("main_hand"), "shortbow", "the bow is in hand now")
	assert_eq(str(ch.weapon_set_2.get("main_hand", "")), "greatsword", "and the greatsword in the second set")
	assert_true(e.log.entries.any(func(en: Dictionary) -> bool: return str(en["text"]).contains("takes up Shortbow")), "the log says so")
	assert_eq(ilse.attacks_left, 1, "the swap cost nothing: the second attack of the Attack action is left")
	assert_eq(int(e.option_by_id(ilse, "weapon:greatsword").get("set", 0)), 2, "the greatsword is the other set now")


func test_swap_weapons_is_free_and_goes_both_ways() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var ch := ilse.creature as Character
	var cat := ActionCatalog.new(e)
	var swap := cat.find(ilse, "swap_weapons")
	assert_false(swap.is_empty(), "Swap weapons is on the hotbar")
	assert_eq(str(swap["cost"]), "free")
	assert_eq(str(swap["sub"]), "to Shortbow")
	assert_true(cat.perform(ilse, swap).ok)
	assert_eq(ch.held_id("main_hand"), "shortbow")
	assert_true(cat.perform(ilse, cat.find(ilse, "swap_weapons")).ok, "again, the same turn")
	assert_eq(ch.held_id("main_hand"), "greatsword")
	assert_true(ilse.action_available and ilse.bonus_available and ilse.free_interaction_available, "nothing spent")
	# A hero with nothing in the second set has no Swap weapons.
	ch.weapon_set_2 = {}
	assert_true(cat.find(ilse, "swap_weapons").is_empty())


func test_the_second_sets_grip_counts() -> void:
	# A spear in the second set, alone, is held in two hands (Versatile 1d8), though a Shield is in hand now.
	var e := TestCombat.open_field()
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, god)
	var ch := god.creature as Character
	assert_eq(ch.held_id("off_hand"), "shield")
	ch.add_item("spear")
	ch.weapon_set_2 = {"main_hand": "spear"}
	var spear := e.option_by_id(god, "weapon:spear")
	assert_eq(int(spear["set"]), 2)
	assert_eq((spear["profile"] as WeaponProfile).damage_dice, "1d8", "two-handed in its own set")


func test_the_light_extra_attack_needs_a_light_weapon_in_hand() -> void:
	var e := TestCombat.open_field()
	var tam := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 100
	TestCombat.start_with(e, tam)
	var ch := tam.creature as Character
	assert_eq(ch.held_id("off_hand"), "dagger", "a dagger in the off hand beside the shortsword")
	var cat := ActionCatalog.new(e)
	assert_true(e.attack(tam, z, "weapon:shortsword").ok)
	assert_false(cat.find(tam, "offhand:weapon:dagger").is_empty(), "the off-hand dagger can follow")
	# With the dagger put away in the pack, it can't.
	ch.unequip("off_hand")
	assert_true(cat.find(tam, "offhand:weapon:dagger").is_empty())
	assert_false(e.offhand_attack(tam, z, "weapon:dagger").ok)


func test_the_ai_uses_only_what_its_creature_holds() -> void:
	# A foe with a character sheet whose weapons are all in its pack fights with its fists.
	var e := TestCombat.open_field()
	var foe := e.add(TestChars.pregen("ilse_varga", 5), &"enemy", Vector2i(3, 2))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 5)
	hedda.creature.hp = 300
	var ch := foe.creature as Character
	ch.unequip("main_hand")
	ch.weapon_set_2 = {}
	TestCombat.start_with(e, foe)
	assert_true(_option_ids(e, foe).filter(func(id: String) -> bool: return not id.contains("unarmed")).is_empty(),
		"nothing but an Unarmed Strike")
	e.run_ai_turn()
	var made := _attacks_made(e, foe)
	assert_false(made.is_empty(), "it attacked")
	for id in made:
		assert_true(id.contains("unarmed"), "with its fists, not %s" % id)


func test_an_older_save_gets_its_sets_once() -> void:
	var th := TestChars.pregen("thistle", 5)
	th.unequip("off_hand")
	th.weapon_set_2 = {}
	var d := th.to_dict()
	d.erase("sets_seeded")
	var loaded := Character.from_dict(d)
	assert_eq(loaded.held_id("off_hand"), "shortsword", "filled as it loads")
	assert_eq(str(loaded.weapon_set_2.get("main_hand", "")), "longbow")
	# A save written since keeps what the player set, empty hands included.
	var again := loaded.to_dict()
	var hands := Character.from_dict(again)
	hands.unequip("off_hand")
	hands.weapon_set_2 = {}
	var kept := Character.from_dict(hands.to_dict())
	assert_eq(kept.held_id("off_hand"), "")
	assert_true(kept.weapon_set_2.is_empty())
	# The player's own second set is never replaced.
	var own := TestChars.pregen("thistle", 5)
	own.weapon_set_2 = {"main_hand": "shortbow"}
	var od := own.to_dict()
	od.erase("sets_seeded")
	assert_eq(str(Character.from_dict(od).weapon_set_2.get("main_hand", "")), "shortbow")
