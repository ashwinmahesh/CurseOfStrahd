extends TestCase
## Dark One's Blessing (Fiend Patron 3, 2024 PHB): when the warlock reduces an enemy to 0 Hit Points, or someone else
## reduces one within 10 ft of the warlock, the warlock gains Temporary Hit Points equal to its Charisma modifier plus
## its Warlock level (at least 1). Temporary Hit Points don't stack: the higher amount stays. Kip is a level 6 Fiend.


func _kip(e: Encounter, cell: Vector2i) -> Combatant:
	return TestCombat.hero(e, "kip_smudgewick", cell, 6)


func _blessing(kip: Combatant) -> int:
	return maxi(1, kip.creature.ability_mod(&"cha") + 6)


## A foe with every save and AC as low as they go, one hit from dropping.
func _weak(e: Encounter, cell: Vector2i) -> Combatant:
	var f := TestCombat.punching_bag(e, cell, 80)
	f.creature.hp = 1
	return f


## A new turn's worth of actions, so one test can try every way of dropping a foe.
func _fresh(c: Combatant) -> void:
	c.action_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	c.attacks_left = 0


func _blow(e: Encounter, by: Combatant, t: Combatant) -> void:
	e.deal_damage(by, t, [{"amount": 50, "type": "slashing"}], false, "A blow")


func test_kips_own_kills_weapon_eldritch_blast_burning_hands_and_hellish_rebuke() -> void:
	var e := TestCombat.open_field(5)
	var kip := _kip(e, Vector2i(2, 3))
	var a := _weak(e, Vector2i(3, 3))
	var b := _weak(e, Vector2i(7, 3))
	var c := _weak(e, Vector2i(2, 4))
	var d := _weak(e, Vector2i(3, 2))
	TestCombat.start_with(e, kip)
	var amount := _blessing(kip)
	assert_true(amount >= 9, "Charisma +3 or more, and 6 levels: %d" % amount)
	var weapon := ""
	for o in e.attack_options(kip):
		if str(o["kind"]) == "weapon" and bool(o["melee"]):
			weapon = str(o["id"])
	assert_ne(weapon, "", "Kip carries a melee weapon")
	TestCombat.next_d20(e, 18)
	e.attack(kip, a, weapon)
	assert_true(a.is_down(), "the dagger drops it")
	assert_eq(kip.creature.temp_hp, amount, "a weapon kill")
	kip.creature.temp_hp = 0
	_fresh(kip)
	TestCombat.next_d20(e, 18)
	e.spells.cast(kip, "eldritch_blast", 0, [b, b])
	assert_true(b.is_down())
	assert_eq(kip.creature.temp_hp, amount, "a spell attack's kill")
	kip.creature.temp_hp = 0
	_fresh(kip)
	e.spells.cast(kip, "burning_hands", 3, [], Vector2.INF, Vector2.DOWN)
	assert_true(c.is_down())
	assert_eq(kip.creature.temp_hp, amount, "a saving-throw spell's kill")
	kip.creature.temp_hp = 0
	e.spells.cast_reaction_spell(kip, "hellish_rebuke", d, 3)
	assert_true(d.is_down())
	assert_eq(kip.creature.temp_hp, amount, "a reaction's kill")


func test_someone_elses_kill_counts_within_10_ft_of_kip_and_not_beyond() -> void:
	var e := TestCombat.open_field(5)
	var kip := _kip(e, Vector2i(2, 3))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(9, 3))
	var near := _weak(e, Vector2i(4, 3))
	var far := _weak(e, Vector2i(10, 3))
	TestCombat.start_with(e, kip)
	_blow(e, ilse, far)
	assert_eq(kip.creature.temp_hp, 0, "dropped 40 ft from Kip")
	_blow(e, ilse, near)
	assert_eq(kip.creature.temp_hp, _blessing(kip), "dropped 10 ft from Kip")


func test_a_summons_kill_and_a_foes_own_misfire_near_kip_count_too() -> void:
	var e := TestCombat.open_field(5)
	var kip := _kip(e, Vector2i(2, 3))
	var wolf := e.add(TestCombat.monster("wolf"), &"party", Vector2i(4, 4))
	wolf.set_meta("summoner", kip.id)
	var a := _weak(e, Vector2i(3, 4))
	var b := _weak(e, Vector2i(3, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 6))
	TestCombat.start_with(e, kip)
	_blow(e, wolf, a)
	assert_eq(kip.creature.temp_hp, _blessing(kip), "a creature on Kip's side dropped it beside him")
	kip.creature.temp_hp = 0
	_blow(e, foe, b)
	assert_eq(kip.creature.temp_hp, _blessing(kip), "\"someone else\": even a foe that fells its own side within 10 ft")


func test_temporary_hit_points_dont_stack_the_higher_stays() -> void:
	var e := TestCombat.open_field(5)
	var kip := _kip(e, Vector2i(2, 3))
	var a := _weak(e, Vector2i(3, 3))
	var b := _weak(e, Vector2i(3, 4))
	TestCombat.start_with(e, kip)
	kip.creature.temp_hp = 30
	_blow(e, kip, a)
	assert_eq(kip.creature.temp_hp, 30, "30 is more than the blessing")
	kip.creature.temp_hp = 2
	_blow(e, kip, b)
	assert_eq(kip.creature.temp_hp, _blessing(kip), "the blessing replaces 2")


func test_power_word_kill_from_the_warlock_counts() -> void:
	var e := TestCombat.open_field(5)
	var kip := _kip(e, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 90)
	TestCombat.start_with(e, kip)
	var ctx := {"c": kip, "s": Compendium.shared().spell_data("power_word_kill"), "slot": 9, "opts": {}}
	e.spells.specials.high.power_word_kill(ctx, foe, CombatResult.new())
	assert_true(foe.creature.dead, "100 Hit Points or fewer: dead")
	assert_eq(kip.creature.temp_hp, _blessing(kip), "killed outright is still reduced to 0 Hit Points")
