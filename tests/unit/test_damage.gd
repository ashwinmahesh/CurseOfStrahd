extends TestCase
## 2024 PHB "Damage and Healing": order of Resistance and Vulnerability, Immunity, Temporary Hit Points,
## healing cap, dropping to 0, Massive Damage, damage at 0 Hit Points.


func test_phb_order_of_application_example() -> void:
	# PHB: Resistance to all damage, Vulnerability to Fire, an aura reducing damage by 5; 28 Fire damage
	# -> 23 -> halved 11 -> doubled 22. The caller applies the -5; the creature does the rest.
	var c := TestChars.dummy(100)
	c.base_resistances.append("all")
	c.base_vulnerabilities.append("fire")
	var r := c.take_damage(28 - 5, &"fire")
	assert_eq(r.final, 22)
	assert_eq(c.hp, 78)


func test_resistance_rounds_down_and_immunity_blocks() -> void:
	var c := TestChars.dummy(30)
	c.base_resistances.append("cold")
	c.base_immunities.append("poison")
	assert_eq(c.take_damage(7, &"cold").final, 3)
	assert_eq(c.take_damage(50, &"poison").final, 0)
	assert_eq(c.hp, 27)


func test_resistances_from_modifiers_name_their_source() -> void:
	var hedda := TestChars.pregen("hedda_ironvow")
	var r := hedda.take_damage(9, &"poison")
	assert_eq(r.final, 4)
	assert_true(", ".join(r.notes).contains("Dwarven Resilience"), ", ".join(r.notes))


func test_temporary_hit_points_absorb_first_and_dont_stack() -> void:
	var c := TestChars.dummy(20)
	c.add_temp_hp(5)
	c.take_damage(7, &"slashing")
	assert_eq(c.temp_hp, 0)
	assert_eq(c.hp, 18, "PHB: 5 temp HP and 7 damage loses 2 HP")
	assert_true(c.add_temp_hp(10))
	assert_true(c.add_temp_hp(12), "higher replaces")
	assert_false(c.add_temp_hp(8), "lower doesn't stack or replace")
	assert_eq(c.temp_hp, 12)


func test_healing_cannot_exceed_maximum() -> void:
	var c := TestChars.dummy(20)
	c.take_damage(6, &"bludgeoning")
	assert_eq(c.heal(8), 6, "PHB: 8 healing at 14/20 restores 6")
	assert_eq(c.hp, 20)


func test_massive_damage_kills_a_character() -> void:
	# PHB: Hit Point maximum 12, at 6 HP, takes 18 -> 12 remains -> dies.
	var c := TestChars.dummy(12, true)
	c.take_damage(6, &"slashing")
	var r := c.take_damage(18, &"slashing")
	assert_true(r.instant_death)
	assert_true(c.dead)


func test_character_at_zero_falls_unconscious() -> void:
	var c := TestChars.dummy(12, true)
	var r := c.take_damage(15, &"slashing")
	assert_true(r.dropped_to_zero)
	assert_false(c.dead)
	assert_true(c.has_condition(&"unconscious"))
	assert_true(c.has_condition(&"incapacitated"), "Unconscious implies Incapacitated")
	assert_true(c.has_condition(&"prone"), "and Prone")


func test_damage_at_zero_is_a_death_save_failure_and_crits_count_twice() -> void:
	var c := TestChars.dummy(12, true)
	c.take_damage(12, &"slashing")
	c.take_damage(1, &"slashing")
	assert_eq(c.death_failures, 1)
	c.take_damage(1, &"slashing", true)
	assert_eq(c.death_failures, 3)
	assert_true(c.dead, "three failures")


func test_damage_at_zero_equal_to_maximum_kills() -> void:
	var c := TestChars.dummy(12, true)
	c.take_damage(12, &"slashing")
	c.take_damage(12, &"slashing")
	assert_true(c.dead)


func test_monsters_die_at_zero() -> void:
	var wolf := Monster.from_data(Compendium.shared().monster_data("wolf"))
	assert_eq(wolf.hp, 11)
	wolf.take_damage(11, &"piercing")
	assert_true(wolf.dead)


func test_healing_at_zero_wakes_but_leaves_prone() -> void:
	var c := TestChars.dummy(10, true)
	c.take_damage(10, &"slashing")
	c.heal(3)
	assert_false(c.has_condition(&"unconscious"))
	assert_true(c.has_condition(&"prone"), "still Prone when Unconscious ends")
	assert_eq(c.death_failures, 0)


func test_two_damage_types_meet_defenses_separately() -> void:
	var c := TestChars.dummy(40)
	c.base_resistances.append("necrotic")
	var r := c.take_damage_parts([{"amount": 5, "type": "piercing"}, {"amount": 4, "type": "necrotic"}])
	assert_eq(r.final, 7, "5 piercing + 4 necrotic halved to 2")


func test_concentration_dc() -> void:
	assert_eq(Concentration.save_dc(7), 10)
	assert_eq(Concentration.save_dc(22), 11)
	assert_eq(Concentration.save_dc(100), 30, "capped at 30")


func test_a_hit_of_two_damage_types_names_both() -> void:
	var c := TestChars.dummy(50)
	var r := c.take_damage_parts([{"amount": 6, "type": "piercing"}, {"amount": 4, "type": "necrotic"}])
	assert_eq(r.final, 10)
	assert_true(r.describe("Ilse").begins_with("Ilse takes 10 Piercing + Necrotic damage"), r.describe("Ilse"))
