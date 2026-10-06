extends TestCase
## Weapon attack profiles and AttackResolver (2024 PHB "Equipment", "Critical Hits", conditions).


func _weapon(id: String) -> Dictionary:
	return Compendium.shared().item_data(id)


func test_finesse_uses_the_better_ability() -> void:
	var rogue := TestChars.pregen("tamsin_tealeaf")
	var p := WeaponProfile.build(rogue, _weapon("rapier"))
	assert_eq(p.ability, &"dex")
	assert_eq(p.attack.total(), 5)
	assert_false(p.proficient == false, "Rogues are proficient with martial Finesse weapons")


func test_versatile_two_handed_when_the_other_hand_is_free() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	var p := WeaponProfile.build(ilse, _weapon("longsword"))
	assert_eq(p.damage_dice, "1d10")
	assert_true("two_handed" in p.tags)


func test_great_weapon_fighting_raises_low_dice() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	ilse.build["choices"]["fighter.1.fighting_style"] = ["great_weapon_fighting"]
	ilse.refresh()
	var p := WeaponProfile.build(ilse, _weapon("greatsword"))
	assert_eq(p.die_minimum, 3)
	# Per die (3+3+3+4+5+6)/6 = 4, so 2d6 averages 8, plus Str 3.
	assert_between(p.average_damage(), 10.99, 11.01)


func test_dueling_and_archery() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	ilse.build["choices"]["fighter.1.fighting_style"] = ["dueling"]
	ilse.refresh()
	ilse.add_item("shield")
	ilse.equip("shield", "off_hand")
	var sword := WeaponProfile.build(ilse, _weapon("longsword"))
	assert_eq(sword.damage_dice, "1d8", "a Shield takes the second hand")
	assert_eq(sword.damage_bonus.value_of("Dueling"), 2)
	ilse.build["choices"]["fighter.1.fighting_style"] = ["archery"]
	ilse.refresh()
	assert_eq(WeaponProfile.build(ilse, _weapon("longbow")).attack.value_of("Archery"), 2)
	assert_eq(WeaponProfile.build(ilse, _weapon("longsword")).attack.value_of("Archery"), 0)


func test_no_proficiency_bonus_without_proficiency() -> void:
	var wiz := TestChars.pregen("silvain_aster")
	var p := WeaponProfile.build(wiz, _weapon("longsword"))
	assert_false(p.proficient)
	assert_false(p.attack.has_part("Proficiency"))


func test_critical_hit_doubles_dice_and_champion_crits_on_19() -> void:
	var ilse := TestChars.pregen("ilse_varga", 3)
	var target := TestChars.dummy(200)
	var p := WeaponProfile.build(ilse, _weapon("greatsword"))
	var r := AttackResolver.weapon_attack(DiceRoller.new(TestChars.seed_for_d20(19)), ilse, p, target)
	assert_true(r.critical, "Improved Critical")
	assert_eq(r.damage_rolls.size(), 4, "2d6 rolled twice")
	var plain := TestChars.pregen("ilse_varga", 2)
	var r2 := AttackResolver.weapon_attack(DiceRoller.new(TestChars.seed_for_d20(19)), plain, WeaponProfile.build(plain, _weapon("greatsword")), target)
	assert_false(r2.critical, "19 is not a Critical Hit before Champion")


func test_natural_1_misses() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	var r := AttackResolver.weapon_attack(DiceRoller.new(TestChars.seed_for_d20(1)), ilse,
		WeaponProfile.build(ilse, _weapon("greatsword")), TestChars.dummy(10))
	assert_false(r.hit)


func test_prone_and_paralyzed_targets() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	var p := WeaponProfile.build(ilse, _weapon("greatsword"))
	var prone := TestChars.dummy(200)
	prone.add_condition(&"prone")
	var near := AttackResolver.weapon_attack(DiceRoller.new(3), ilse, p, prone, {"distance_ft": 5})
	assert_true(near.test.advantage)
	var bow := WeaponProfile.build(ilse, _weapon("shortbow"))
	var far := AttackResolver.weapon_attack(DiceRoller.new(3), ilse, bow, prone, {"distance_ft": 30})
	assert_true(far.test.disadvantage)
	var held := TestChars.dummy(200)
	held.add_condition(&"paralyzed")
	var s := TestChars.seed_for_d20(15)
	var hit := AttackResolver.weapon_attack(DiceRoller.new(s), ilse, p, held, {"distance_ft": 5})
	assert_true(hit.hit)
	assert_true(hit.critical, "hits within 5 ft of a Paralyzed creature are Critical Hits")


func test_monster_attack_and_extra_damage_types() -> void:
	var ghoul := Monster.from_data(Compendium.shared().monster_data("ghoul"))
	var bite := ghoul.attack_profile("bite")
	assert_eq(bite.attack.total(), 4)
	assert_eq(bite.damage_dice, "1d6")
	assert_eq(bite.damage_bonus.total(), 2)
	var hedda := TestChars.pregen("hedda_ironvow")
	var s := TestChars.seed_for_d20(18)
	var r := AttackResolver.weapon_attack(DiceRoller.new(s), ghoul, bite, hedda, {"extra_dice": ghoul.extra_damage_dice("bite")})
	assert_true(r.hit)
	assert_eq(r.damage_rolls.size(), 2, "1d6 piercing + 1d6 necrotic")
	assert_eq(hedda.hp, hedda.max_hp() - r.damage.final)


func test_combat_log_explains_the_roll() -> void:
	var ilse := TestChars.pregen("ilse_varga")
	var r := AttackResolver.weapon_attack(DiceRoller.new(TestChars.seed_for_d20(12)), ilse,
		WeaponProfile.build(ilse, _weapon("greatsword")), TestChars.dummy(200))
	assert_true(r.describe().begins_with("Greatsword → Dummy: d20 12 + 5 = 17 vs AC 12, hit"), r.describe())
	assert_true(r.describe().contains("Damage: Greatsword 2d6"), r.describe())
