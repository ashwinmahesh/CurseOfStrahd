extends TestCase
## The Rod of Lordly Might (2024 DMG): a magic Mace with +3; its first button makes a fiery Longsword or Shortsword
## (2d6 Fire, light, no +3 of its own), its second a +3 Battleaxe, its third a +3 Spear. Each form is that weapon in the
## rules: its dice, properties, grip, proficiency and Weapon Mastery (the wielder's, for that weapon). Paralyze and
## Drain Life are Constitution saves on a melee hit; the Flame Tongue blade is covered in test_magic_item_rules.

const ROD := "rod_of_lordly_might__mace"


func after_each() -> void:
	GameState.reset()


## A Fighter (all weapons) wielding the rod, in a fight with a punching bag: [encounter, Fighter, bag].
func _wielder(pregen: String = "ilse_varga", masteries: Array[String] = ["mace", "longsword", "shortsword", "battleaxe", "spear"]) -> Array:
	var e := TestCombat.open_field()
	e.ambient_light = "dark"   # so what the rod's fire lights is what the square shows
	var c := TestCombat.hero(e, pregen, Vector2i(2, 2), 5)
	var ch := c.creature as Character
	ch.add_item(ROD)
	ch.attune(ROD)
	ch.equip(ROD, "main_hand")
	ch.weapon_masteries = masteries.duplicate()
	var bag := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, c)
	return [e, c, bag]


func _press(e: Encounter, c: Combatant, form: String) -> void:
	c.bonus_available = true
	var r := e.items.use(c, ROD, "form", [], Vector2.INF, Vector2.ZERO, 0, {"choice": form})
	assert_true(r.ok, "%s: %s" % [form, r.reason])


func _profile(e: Encounter, c: Combatant, thrown: bool = false) -> WeaponProfile:
	return e.option_by_id(c, ("thrown:" if thrown else "weapon:") + ROD)["profile"] as WeaponProfile


func _hit(e: Encounter, c: Combatant, bag: Combatant, thrown: bool = false) -> Array[Dictionary]:
	var opt := e.option_by_id(c, ("thrown:" if thrown else "weapon:") + ROD)
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	return e.items.hit_damage_dice(c, bag, opt, st)


func test_the_rod_is_a_plus_3_mace_with_the_maces_mastery() -> void:
	var run := _wielder()
	var p := _profile(run[0], run[1])
	assert_eq(p.base_item, "mace")
	assert_eq(p.damage_dice, "1d6")
	assert_eq(str(p.damage_type), "bludgeoning")
	assert_eq(p.damage_bonus.value_of("Rod of Lordly Might"), 3)
	assert_eq(p.attack.value_of("Rod of Lordly Might"), 3)
	assert_eq(p.mastery, "sap", "Sap, because the wielder has chosen the Mace")
	assert_eq((_hit(run[0], run[1], run[2])).size(), 0, "no fire in the Mace form")


func test_a_mastery_the_wielder_has_not_chosen_stays_off() -> void:
	var run := _wielder("ilse_varga", ["longsword"] as Array[String])
	assert_eq(_profile(run[0], run[1]).mastery, "", "the Mace's Sap isn't theirs")
	_press(run[0], run[1], "longsword")
	assert_eq(_profile(run[0], run[1]).mastery, "sap", "but the Longsword's is")
	_press(run[0], run[1], "battleaxe")
	assert_eq(_profile(run[0], run[1]).mastery, "", "the Battleaxe's Topple isn't")


func test_the_first_button_is_a_longsword_of_fire_without_a_plus_3_of_its_own() -> void:
	var run := _wielder()
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	var mace := _profile(e, c)
	_press(e, c, "longsword")
	assert_false(c.bonus_available, "a Bonus Action")
	var p := _profile(e, c)
	assert_eq(p.base_item, "longsword")
	assert_eq(str(p.damage_type), "slashing")
	assert_true("versatile" in p.properties, "a Longsword's Versatile")
	assert_eq(p.damage_dice, "1d10", "two-handed with the other hand free")
	assert_eq(p.mastery, "sap")
	assert_false(p.damage_bonus.has_part("Rod of Lordly Might"), "no +3 on the blade")
	assert_false(p.attack.has_part("Rod of Lordly Might"))
	assert_eq(mace.attack.total() - p.attack.total(), 3, "three less to hit than the Mace")
	assert_eq(mace.damage_bonus.total() - p.damage_bonus.total(), 3)
	var dice := _hit(e, c, run[2])
	assert_eq(dice.size(), 1)
	assert_eq(str(dice[0]["dice"]), "2d6")
	assert_eq(str(dice[0]["type"]), "fire")
	assert_eq(str(e.light_at(Vector2i(10, 2))), "bright", "its fire lights 40 ft")
	assert_eq(str(e.light_at(Vector2i(14, 2))), "dim", "and 40 more dimly")


func test_the_blade_can_be_a_shortsword_with_finesse_and_vex() -> void:
	var run := _wielder()
	_press(run[0], run[1], "shortsword")
	var p := _profile(run[0], run[1])
	assert_eq(p.base_item, "shortsword")
	assert_eq(str(p.damage_type), "piercing")
	assert_true("finesse" in p.properties and "light" in p.properties)
	assert_eq(p.mastery, "vex")
	assert_eq(_hit(run[0], run[1], run[2]).size(), 1, "the fire is the blade's, Longsword or Shortsword")
	assert_eq(str((run[0] as Encounter).light_at(Vector2i(10, 2))), "bright")


func test_the_second_and_third_buttons_are_plus_3_weapons_with_their_own_mastery() -> void:
	var run := _wielder()
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	_press(e, c, "battleaxe")
	var axe := _profile(e, c)
	assert_eq(axe.base_item, "battleaxe")
	assert_eq(axe.damage_bonus.value_of("Rod of Lordly Might"), 3)
	assert_eq(axe.mastery, "topple")
	assert_true("versatile" in axe.properties)
	assert_eq(_hit(e, c, run[2]).size(), 0, "no fire")
	assert_eq(str(e.light_at(Vector2i(10, 2))), "dark", "no blade, no flames")
	_press(e, c, "spear")
	var spear := _profile(e, c)
	assert_eq(spear.base_item, "spear")
	assert_eq(str(spear.damage_type), "piercing")
	assert_eq(spear.attack.value_of("Rod of Lordly Might"), 3)
	assert_eq(spear.mastery, "sap")
	var hurled := e.option_by_id(c, "thrown:" + ROD)
	assert_false(hurled.is_empty(), "a Spear can be thrown")
	assert_eq((hurled["range"] as Array), [20, 60])
	assert_eq((hurled["profile"] as WeaponProfile).damage_bonus.value_of("Rod of Lordly Might"), 3, "the +3 goes with it")


func test_a_form_is_the_weapon_to_the_wielders_proficiency() -> void:
	# A Warlock is trained in Simple weapons: the Mace and the Spear are fine, a Longsword and a Battleaxe are Martial.
	var run := _wielder("kip_smudgewick")
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	assert_true(_profile(e, c).proficient, "Mace")
	_press(e, c, "spear")
	assert_true(_profile(e, c).proficient, "Spear")
	_press(e, c, "longsword")
	assert_false(_profile(e, c).proficient, "Longsword is Martial")
	_press(e, c, "battleaxe")
	assert_false(_profile(e, c).proficient, "Battleaxe is Martial")


func test_the_same_button_again_or_the_mace_puts_it_back() -> void:
	var run := _wielder()
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	_press(e, c, "longsword")
	_press(e, c, "longsword")
	assert_eq(_profile(e, c).base_item, "mace", "the same button again")
	assert_eq(ItemSpecials.lordly_form_of(c, ROD), "mace")
	assert_eq(_hit(e, c, run[2]).size(), 0)
	_press(e, c, "battleaxe")
	_press(e, c, "mace")
	assert_eq(_profile(e, c).base_item, "mace", "or the Mace's")
	_press(e, c, "blade")   # an older save's button
	assert_eq(ItemSpecials.lordly_form_of(c, ROD), "longsword")


func test_a_form_lasts_through_a_save_and_the_next_fight_relights_the_blade() -> void:
	var run := _wielder()
	var c := run[1] as Combatant
	_press(run[0], c, "shortsword")
	var ch := c.creature as Character
	var back := Character.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())) as Dictionary)
	var e2 := TestCombat.open_field()
	e2.ambient_light = "dark"
	var c2 := e2.add(back, &"party", Vector2i(2, 2))
	var bag2 := TestCombat.punching_bag(e2, Vector2i(3, 2), 300)
	TestCombat.start_with(e2, c2)
	assert_eq(ItemSpecials.lordly_form_of(c2, ROD), "shortsword")
	assert_eq(_profile(e2, c2).base_item, "shortsword")
	assert_eq(_hit(e2, c2, bag2).size(), 1, "still burning")
	assert_eq(str(e2.light_at(Vector2i(10, 2))), "bright", "and lit again in the new fight")


func test_putting_the_blade_away_puts_the_fire_out() -> void:
	var run := _wielder()
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	_press(e, c, "longsword")
	assert_eq(str(e.light_at(Vector2i(10, 2))), "bright")
	_press(e, c, "mace")
	assert_eq(str(e.light_at(Vector2i(10, 2))), "dark", "the light goes with the blade")


func _strong_con_bag(e: Encounter) -> Combatant:
	return e.add(TestChars.dummy(300, false, {"type": "humanoid", "ac": 1,
		"abilities": {"str": 10, "dex": 10, "con": 30, "int": 10, "wis": 10, "cha": 10}}), &"enemy", Vector2i(3, 3))


## Arms Paralyze and hits the Constitution 30 creature with the save rolling `d20`: [the encounter, the creature].
func _paralyze_with(d20: int) -> Array:
	var run := _wielder()
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	var bag := _strong_con_bag(e)
	var armed := e.items.use(c, ROD, "paralyze")
	assert_true(armed.ok, armed.reason)
	var opt := e.option_by_id(c, "weapon:" + ROD)
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	TestCombat.next_d20(e, d20)
	e.items.after_hit(c, bag, opt, DamageResult.new(), st, CombatResult.new())
	return [e, bag]


func test_paralyze_is_a_constitution_save_on_a_melee_hit() -> void:
	# Constitution 30 (+10) beats the DC 17 with a 20 but not with a 1; a Strength 10 save could not tell the two apart.
	assert_false(((_paralyze_with(20)[1]) as Combatant).creature.has_condition(&"paralyzed"), "20 + 10 makes the save")
	assert_true(((_paralyze_with(1)[1]) as Combatant).creature.has_condition(&"paralyzed"), "1 + 10 does not")


func test_paralyze_and_drain_life_wait_for_a_melee_hit() -> void:
	var run := _wielder()
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	_press(e, c, "spear")
	var bag := run[2] as Combatant
	assert_true(e.items.use(c, ROD, "paralyze").ok)
	var thrown := e.option_by_id(c, "thrown:" + ROD)
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": thrown, "critical": false}
	TestCombat.next_d20(e, 1)
	e.items.after_hit(c, bag, thrown, DamageResult.new(), st, CombatResult.new())
	assert_false(bag.creature.has_condition(&"paralyzed"), "a thrown Spear is not a melee attack")
	assert_true(e.items.toggled(c, ROD, "paralyze"), "and the power stays armed")
