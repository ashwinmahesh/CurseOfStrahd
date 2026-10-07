extends TestCase
## Booming Blade and Green-Flame Blade (Tasha's Cauldron, added by the owner on 2026-10-07): a melee weapon attack
## cast as a cantrip. Booming Blade's thunder goes off when the target moves of its own will before the caster's next
## turn; Green-Flame Blade's fire leaps to another enemy beside the target. Both scale at levels 5, 11 and 17.


## A human Wizard at `level` who knows `spell_id` and holds a dagger, beside a punching bag, on its turn.
func _setup(spell_id: String, level: int = 9, weapon: String = "dagger") -> Dictionary:
	var e := TestCombat.open_field()
	e.default_player_reaction = "never"
	var ch := TestChars.custom("wizard", "human", level)
	(ch.spellcasting[0]["cantrips"] as Array).append(spell_id)
	if weapon != "":
		ch.inventory.append({"id": weapon, "qty": 1, "slot": ""})
		ch.equip(weapon, "main_hand")
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["heroic_inspiration"] = "never"
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	return {"e": e, "c": c, "ch": ch, "t": t}


func _logged(e: Encounter, text: String) -> bool:
	return e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains(text))


func _booming(t: Combatant) -> bool:
	return t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "booming_blade")


func test_both_are_wizard_cantrips() -> void:
	var ids: Array = Compendium.shared().spells_for("wizard", 0).map(func(s: Dictionary) -> String: return str(s["id"]))
	assert_true("booming_blade" in ids and "green_flame_blade" in ids, str(ids))


func test_booming_blade_goes_off_when_the_target_walks_away() -> void:
	var s := _setup("booming_blade")
	var e := s.e as Encounter
	var c := s.c as Combatant
	var t := s.t as Combatant
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	var r := e.spells.cast(c, "booming_blade", 0, [t])
	assert_true(r.ok and r.hit, "the dagger hits")
	assert_true(_booming(t), "wrapped in booming energy")
	assert_false(c.action_available, "the Magic action is spent")
	e.end_turn()
	assert_eq(e.current(), t)
	var hp := t.creature.hp
	assert_true(e.move(t, Vector2i(5, 3)).ok)
	var lost := hp - t.creature.hp
	assert_true(lost >= 2 and lost <= 16, "2d8 Thunder at level 9: %d" % lost)
	assert_true(_logged(e, "bursts as it moves"))
	assert_false(_booming(t), "the spell ends")
	var hp2 := t.creature.hp
	assert_true(e.move(t, Vector2i(6, 3)).ok)
	assert_eq(t.creature.hp, hp2, "only once")


func test_booming_blade_ends_at_the_casters_next_turn_and_ignores_being_shoved() -> void:
	var s := _setup("booming_blade", 3)
	var e := s.e as Encounter
	var c := s.c as Combatant
	var t := s.t as Combatant
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(c, "booming_blade", 0, [t]).hit)
	var hp := t.creature.hp
	e.forced_move(t, e.center_of(c), 10)
	assert_eq(t.creature.hp, hp, "being pushed isn't moving willingly")
	assert_true(_booming(t))
	e.end_turn()
	e.end_turn()
	assert_eq(e.current(), c)
	assert_false(_booming(t), "gone at the start of the caster's next turn")


func test_green_flame_blade_leaps_to_the_weakest_enemy_beside_the_target() -> void:
	var s := _setup("green_flame_blade")
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	var t := s.t as Combatant
	var hale := TestCombat.punching_bag(e, Vector2i(4, 3), 200)
	var hurt := TestCombat.punching_bag(e, Vector2i(3, 4), 60)
	var far := TestCombat.punching_bag(e, Vector2i(6, 6), 30)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(c, "green_flame_blade", 0, [t]).hit)
	var mod := ch.ability_mod(&"int")
	var lost := 60 - hurt.creature.hp
	assert_true(lost >= 1 + mod and lost <= 8 + mod, "1d8 + %d Fire at level 9: %d" % [mod, lost])
	assert_eq(hale.creature.hp, 200, "the fire leaps to one creature")
	assert_eq(far.creature.hp, 30, "only within 5 ft of the target")
	assert_true(_logged(e, "Green fire leaps"))


func test_green_flame_blade_never_leaps_to_an_ally() -> void:
	var s := _setup("green_flame_blade", 3)
	var e := s.e as Encounter
	var c := s.c as Combatant
	var t := s.t as Combatant
	var ally := e.add(TestChars.pregen("ilse_varga", 3), &"party", Vector2i(4, 3))
	TestCombat.start_with(e, c)
	var ally_hp := ally.creature.hp
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(c, "green_flame_blade", 0, [t]).hit)
	assert_eq(ally.creature.hp, ally_hp)
	assert_false(_logged(e, "Green fire leaps"))


func test_green_flame_blade_below_level_5_deals_the_modifier_alone() -> void:
	var s := _setup("green_flame_blade", 3)
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	var t := s.t as Combatant
	var other := TestCombat.punching_bag(e, Vector2i(3, 4), 50)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(c, "green_flame_blade", 0, [t]).hit)
	assert_eq(50 - other.creature.hp, ch.ability_mod(&"int"), "the spellcasting modifier alone before level 5")


func test_without_a_melee_weapon_the_cast_is_refused_before_anything_is_spent() -> void:
	var s := _setup("booming_blade", 9, "")
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	var t := s.t as Combatant
	# Any weapon carried could be drawn for the attack, so the Wizard carries none.
	ch.inventory.assign(ch.inventory.filter(func(x: Dictionary) -> bool: return not Gear.is_weapon(Compendium.shared().item_data(str(x["id"])))))
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "booming_blade", 0, [t])
	assert_false(r.ok)
	assert_true(r.reason.contains("melee weapon"), r.reason)
	assert_true(c.action_available, "nothing spent")


func test_a_bladesinger_can_swap_an_attack_for_booming_blade() -> void:
	var e := TestCombat.open_field()
	e.default_player_reaction = "never"
	var ch := TestChars.custom("wizard", "human", 6, {"wizard_subclass": ["bladesinger"]})
	(ch.spellcasting[0]["cantrips"] as Array).append("booming_blade")
	ch.inventory.append({"id": "rapier", "qty": 1, "slot": ""})
	ch.equip("rapier", "main_hand")
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["heroic_inspiration"] = "never"
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var catalog := ActionCatalog.new(e)
	var action := catalog.find(c, "war_magic:booming_blade")
	assert_false(action.is_empty(), "Booming Blade can replace an attack")
	TestCombat.next_d20(e, 19)
	assert_true(catalog.perform(c, action, [t]).ok)
	assert_true(_booming(t))
	assert_eq(c.attacks_left, 1, "one attack left")
