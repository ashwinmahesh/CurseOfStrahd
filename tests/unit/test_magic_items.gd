extends TestCase
## Magic items (ADR 0011, docs/contracts/magic_items.md): items built on a base weapon or armor, worn slots, attunement
## requirements, charges and dawn, curses, potions and item powers in a fight.


func _comp() -> Compendium:
	return Compendium.shared()


# --- The rules layer -------------------------------------------------------------------------------

func test_variants_build_on_a_base_item_and_keep_its_proficiency_and_mastery() -> void:
	var d := _comp().item_data("weapon_plus_1__longsword")
	assert_eq(str(d.get("name", "")), "+1 Longsword")
	assert_eq(str(d.get("base_item", "")), "longsword")
	assert_eq(str((d["weapon"] as Dictionary)["damage"]), "1d8")
	assert_true(_comp().item_data("weapon_plus_1__plate_armor").is_empty(), "a weapon template doesn't fit armor")
	var ilse := TestChars.pregen("ilse_varga", 3)
	ilse.add_item("weapon_plus_1__longsword")
	var plain := WeaponProfile.build(ilse, _comp().item_data("longsword"))
	var magic := WeaponProfile.build(ilse, d)
	assert_eq(magic.attack.total(), plain.attack.total() + 1, "+1 to hit")
	assert_eq(magic.damage_bonus.total(), plain.damage_bonus.total() + 1, "+1 damage")
	assert_eq(magic.proficient, plain.proficient, "proficiency from the base weapon")
	assert_eq(magic.mastery, plain.mastery, "mastery from the base weapon")
	var other := WeaponProfile.build(ilse, _comp().item_data("greatsword"))
	assert_eq(other.attack.total(), plain.attack.total(), "the bonus stays on its own weapon")


func test_magic_armor_adds_to_ac_only_while_worn() -> void:
	var ilse := TestChars.pregen("ilse_varga", 3)
	var before := ilse.ac_value()
	ilse.add_item("armor_plus_1__chain_mail")
	assert_eq(ilse.ac_value(), before, "carried, not worn")
	ilse.equip("armor_plus_1__chain_mail", "armor")
	assert_eq(ilse.ac_value(), 16 + 1 + (2 if ilse.equipped("off_hand").has("armor") else 0), "Chain Mail 16 + 1 (+ Shield)")


func test_worn_items_work_only_in_their_slot_and_rings_take_two() -> void:
	var ilse := TestChars.pregen("ilse_varga", 3)
	var base := ilse.ac_value()
	ilse.add_item("cloak_of_protection")
	assert_true(ilse.attune("cloak_of_protection"))
	assert_eq(ilse.ac_value(), base, "attuned but not worn")
	assert_true(ilse.wear("cloak_of_protection"))
	assert_eq(ilse.ac_value(), base + 1)
	ilse.add_item("ring_of_protection")
	ilse.add_item("ring_of_warmth")
	ilse.add_item("ring_of_swimming")
	assert_true(ilse.wear("ring_of_protection"))
	assert_true(ilse.wear("ring_of_warmth"))
	assert_true(ilse.wear("ring_of_swimming"))
	assert_eq(ilse.equipped_all("ring").size(), 2, "two rings at most: the first came off")


func test_attunement_requirements_and_one_copy() -> void:
	var ilse := TestChars.pregen("ilse_varga", 3)
	ilse.add_item("wand_of_fireballs")
	assert_true(ilse.attune_blocker("wand_of_fireballs").begins_with("Requires attunement"), "a fighter isn't a spellcaster")
	var silvain := TestChars.pregen("silvain_aster", 5)
	silvain.add_item("wand_of_fireballs")
	silvain.add_item("wand_of_fireballs")
	assert_eq(silvain.attune_blocker("wand_of_fireballs"), "")
	assert_true(silvain.attune("wand_of_fireballs"))
	assert_eq(silvain.attune_blocker("wand_of_fireballs"), "Already attuned", "one copy at a time")


func test_charges_start_full_and_come_back_at_dawn() -> void:
	var silvain := TestChars.pregen("silvain_aster", 5)
	silvain.add_item("wand_of_magic_missiles")
	assert_eq(silvain.charges_left("wand_of_magic_missiles"), 7)
	assert_true(silvain.spend_charges("wand_of_magic_missiles", 5))
	var lines := silvain.on_dawn(DiceRoller.new(3))
	assert_eq(lines.size(), 1)
	assert_between(silvain.charges_left("wand_of_magic_missiles"), 4, 7, "1d6 + 1 back, never above 7")


func test_item_state_travels_with_the_item() -> void:
	var a := TestChars.pregen("silvain_aster", 5)
	var b := TestChars.pregen("hedda_ironvow", 5)
	a.add_item("wand_of_magic_missiles")
	a.spend_charges("wand_of_magic_missiles", 4)
	var state := a.remove_one("wand_of_magic_missiles")
	b.add_item("wand_of_magic_missiles", 1, state)
	assert_eq(b.charges_left("wand_of_magic_missiles"), 3, "charges don't refill on the way")
	var copy := Character.from_dict(b.to_dict())
	assert_eq(copy.charges_left("wand_of_magic_missiles"), 3, "saved with the game")


# --- Potions and powers in a fight -------------------------------------------------------------------

func test_greater_healing_potion_is_a_bonus_action_and_can_be_given() -> void:
	var e := TestCombat.open_field()
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	TestCombat.foe(e, "wolf", Vector2i(10, 6))
	(hedda.creature as Character).add_item("potion_of_healing_greater", 2)
	TestCombat.start_with(e, hedda)
	ilse.creature.hp = 1
	var r := e.items.use(hedda, "potion_of_healing_greater", "drink", [ilse])
	assert_true(r.ok, r.reason)
	assert_between(ilse.creature.hp, 9, 21, "4d4 + 4")
	assert_false(hedda.bonus_available, "a Bonus Action")
	assert_true(hedda.action_available)
	assert_eq(e.item_count(hedda, "potion_of_healing_greater"), 1)
	var again := e.items.use(hedda, "potion_of_healing_greater", "drink", [hedda])
	assert_false(again.ok, "one Bonus Action a turn")


func test_giant_strength_and_fire_breath_potions() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var wolf := TestCombat.punching_bag(e, Vector2i(6, 2))
	var ch := ilse.creature as Character
	ch.add_item("potion_of_giant_strength_fire")
	ch.add_item("potion_of_fire_breath")
	TestCombat.start_with(e, ilse)
	assert_true(e.items.use(ilse, "potion_of_giant_strength_fire", "drink", [ilse]).ok)
	assert_eq(ch.ability_score(&"str"), 25)
	ilse.bonus_available = true
	assert_true(e.items.use(ilse, "potion_of_fire_breath", "drink", [ilse]).ok)
	assert_true(e.items.find_power(ilse, "potion_of_fire_breath", "breath").size() > 0, "the breath is granted")
	var hp := wolf.creature.hp
	ilse.bonus_available = true
	var r := e.items.use(ilse, "potion_of_fire_breath", "breath", [wolf])
	assert_true(r.ok, r.reason)
	assert_true(wolf.creature.hp < hp, "4d6 Fire")
	for i in 2:
		ilse.bonus_available = true
		e.items.use(ilse, "potion_of_fire_breath", "breath", [wolf])
	assert_true(e.items.find_power(ilse, "potion_of_fire_breath", "breath").is_empty(), "three breaths and it's done")


func test_wand_casts_its_spell_at_its_own_dc_and_spends_charges() -> void:
	var e := TestCombat.open_field()
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 5)
	var bag := TestCombat.punching_bag(e, Vector2i(8, 2))
	var ch := silvain.creature as Character
	ch.add_item("wand_of_fireballs")
	assert_true(ch.attune("wand_of_fireballs"))
	TestCombat.start_with(e, silvain)
	var hp := bag.creature.hp
	var r := e.items.use(silvain, "wand_of_fireballs", "fireball", [], Vector2(8.5, 2.5), Vector2.ZERO, 4)
	assert_true(r.ok, r.reason)
	assert_true(bag.creature.hp < hp)
	assert_eq(ch.charges_left("wand_of_fireballs"), 5, "a level 4 Fireball: 2 charges")
	assert_eq(ch.slots_left(3), ch.spell_slots()[2], "no spell slot spent")
	assert_true(silvain.magic_action_used)
