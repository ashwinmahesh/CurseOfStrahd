extends TestCase
## The Heroes of Faerûn and Arcana Unleashed epic boons switched on in batch 8, taken at level 19 through the real
## level-up path and used in a fight (combat/faerun_features.gd and the data).

const BOONS := ["boon_of_bloodshed", "boon_of_exquisite_radiance", "boon_of_fluid_forms", "boon_of_magic_school_mastery",
	"boon_of_revelry", "boon_of_communication", "boon_of_the_bright_sun", "boon_of_erupting_spellpower", "boon_of_terror",
	"boon_of_the_soul_drinker", "boon_of_poison_mastery", "boon_of_the_furious_storm"]


func _with(class_id: String, boon: String, picks: Dictionary = {}) -> Character:
	var p := picks.duplicate()
	p[".19.epic_boon"] = [boon]
	var ch := TestChars.custom(class_id, "human", 19, p)
	assert_true(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == boon), "%s took %s" % [class_id, boon])
	return ch


func _hero(e: Encounter, class_id: String, boon: String, cell: Vector2i, picks: Dictionary = {}) -> Combatant:
	return e.add(_with(class_id, boon, picks), &"party", cell)


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _knows(c: Combatant, id: String) -> void:
	if not _ch(c).knows_spell(id):
		(_ch(c).spellcasting[0]["prepared"] as Array).append(id)


func _fresh_turn(c: Combatant) -> void:
	c.action_available = true
	c.bonus_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	c.reaction_available = true


func _dull(t: Combatant) -> void:
	t.creature.add_effect(Effect.new("Dull").with_modifier("auto_fail", {"on": "save:all"}))


func test_every_epic_boon_is_offered() -> void:
	var offered := Compendium.shared().feats_in("epic_boon").map(func(f: Dictionary) -> String: return str(f["id"]))
	for id: String in BOONS:
		assert_true(id in offered, "%s offered" % id)


func test_bloodshed_rewards_a_kill_and_bleeds_while_bloodied() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "fighter", "boon_of_bloodshed", Vector2i(2, 3))
	var weak := TestCombat.punching_bag(e, Vector2i(3, 3), 1)
	var foe := TestCombat.punching_bag(e, Vector2i(2, 4), 300)
	TestCombat.start_with(e, c)
	e.deal_damage(c, weak, [{"amount": 10, "type": "slashing"}], false, "test")
	assert_true(c.creature.has_flag("bloodshed_advantage"), "a foe fell in sight")
	assert_true((e.attack_situation(c, foe, e.attack_options(c)[0])["advantage"] as Array).has("Boon of Bloodshed"), "Advantage on the next attack")
	c.creature.hp = c.creature.max_hp() / 2 - 1
	var hp := foe.creature.hp
	assert_true(e.attack(c, foe, str(e.attack_options(c)[0]["id"])).hit, "the attack hits")
	assert_false(c.creature.has_flag("bloodshed_advantage"), "the Advantage is spent")
	assert_true(e.log.dump().contains("Boon of Bloodshed"), "Proficiency Bonus damage while Bloodied")
	assert_true(foe.creature.hp < hp)


func test_exquisite_radiance_maximizes_one_radiant_roll() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "cleric", "boon_of_exquisite_radiance", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	_dull(foe)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:radiance_arm")).ok, "armed")
	_knows(c, "sacred_flame")
	assert_true(e.spells.cast(c, "sacred_flame", 0, [foe]).ok)
	assert_eq(foe.creature.max_hp() - foe.creature.hp, 32, "Sacred Flame's 4d8 all at 8")
	assert_eq(_ch(c).resource_left("exquisite_radiance"), 0, "once per Long Rest")
	var weak := TestCombat.punching_bag(e, Vector2i(5, 5), 1)
	e.deal_damage(c, weak, [{"amount": 10, "type": "radiant"}], false, "test")
	assert_true(weak.has_meta("no_undead"), "it can't rise as Undead")


func test_fluid_forms_takes_a_shape_and_keeps_the_mind() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "wizard", "boon_of_fluid_forms", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var intel := c.creature.ability_score(&"int")
	var a := _find(e, c, "feat:fr:fluid_forms")
	assert_false((a.get("choices", []) as Array).is_empty(), "shapes to choose from")
	assert_true(ActionCatalog.new(e).perform(c, a, [], Vector2.INF, Vector2.ZERO, 0, {"choice": "brown_bear"}).ok)
	assert_true(e.shapes.is_shaped(c), "shaped")
	var bear := Compendium.shared().monster_data("brown_bear")
	assert_eq(c.creature.temp_hp, int((bear["hp"] as Dictionary)["average"]) + 20, "the bear's Hit Points and 20 more")
	assert_eq(c.creature.ability_score(&"int"), intel, "the mind kept")
	assert_true(e.shapes.keeps_spells(c), "spellcasting kept")
	_fresh_turn(c)
	assert_true(_find(e, c, "feat:cf:revert_shape").is_empty(), "not Wild Shape's Bonus Action")
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:fluid_forms_end")).ok, "a Magic action ends it")
	assert_false(e.shapes.is_shaped(c))


func test_magic_school_mastery_grants_an_at_will_spell_and_a_free_one() -> void:
	var ch := _with("wizard", "boon_of_magic_school_mastery", {"school_mastery_school": ["evocation"], "school_mastery_minor": ["magic_missile"],
		"school_mastery_major": ["fireball"]})
	assert_true(ch.knows_spell("magic_missile") and ch.knows_spell("fireball"))
	var e := TestCombat.open_field(4)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	var mm := e.spells.castable(c).filter(func(x: Dictionary) -> bool: return str(x["id"]) == "magic_missile")
	assert_true(not mm.is_empty() and bool((mm[0] as Dictionary).get("at_will", false)), "Magic Missile at will")
	var slots := ch.slots_left(1)
	assert_true(e.spells.cast(c, "magic_missile", 1, [foe]).ok)
	assert_eq(ch.slots_left(1), slots, "no slot")
	assert_true(e.faerun.waives_components(c, "magic_missile"), "no components")
	assert_eq(ch.resource_left("spell:fireball"), 1, "a free Fireball each Long Rest")


func test_revelry_dance_is_free_and_silences_the_dancer() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "bard", "boon_of_revelry", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, c)
	_dull(foe)
	assert_eq(_ch(c).resource_left("spell:ottos_irresistible_dance"), 1)
	assert_true(e.spells.cast(c, "ottos_irresistible_dance", 6, [foe]).ok)
	assert_true(foe.creature.has_condition(&"charmed"), "dancing")
	assert_true(foe.creature.has_flag("speechless"), "no Verbal spells")
	assert_true(c.creature.concentration_damage_protected(), "damage can't break the Concentration")


func test_bright_sun_shines_sunlight_and_heartens_allies() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "cleric", "boon_of_the_bright_sun", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	var far := TestCombat.punching_bag(e, Vector2i(11, 7))
	var dark := FieldObject.new(FieldObject.Kind.ZONE, "darkness", "Darkness")
	dark.cells = [Vector2i(5, 5)]
	dark.rules = {"darkness": true}
	e.spells.zones.add(dark, CombatResult.new())
	TestCombat.start_with(e, c)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:bright_sun")).ok)
	assert_true(e.in_sunlight(foe), "sunlight within 30 ft")
	assert_false(e.in_sunlight(far), "not beyond")
	assert_true(dark.expired(), "the Darkness is dispelled")
	e.faerun.turn_start(c)
	assert_eq(c.creature.temp_hp, 10, "10 Temporary Hit Points")
	assert_eq(ally.creature.temp_hp, 10, "for the ally too")


func test_erupting_spellpower_lifts_low_dice_and_topples() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "wizard", "boon_of_erupting_spellpower", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	_dull(foe)
	_knows(c, "fireball")
	assert_true(e.spells.cast(c, "fireball", 3, [foe], Vector2(6.5, 3.5)).ok)
	assert_true(foe.creature.max_hp() - foe.creature.hp >= 24, "8d6 with every die at least 3")
	assert_true(foe.creature.has_condition(&"prone"), "knocked Prone")
	assert_eq(_ch(c).resource_left("erupting_spellpower"), 0)
	e.faerun.before_initiative()
	assert_eq(_ch(c).resource_left("erupting_spellpower"), 1, "back when Initiative is rolled")


func test_terror_drives_a_frightened_foe_away() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "warlock", "boon_of_terror", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, c)
	var fx := Effect.new("Scared").with_condition(&"frightened")
	fx.caster_id = c.id
	foe.creature.add_effect(fx)
	_dull(foe)
	e.faerun.turn_start(foe)
	assert_true(foe.creature.has_flag("fear_flee"), "it flees")
	assert_eq(_ch(c).resource_left("boon_of_terror"), 0)
	assert_false(c.reaction_available, "a Reaction")


func test_soul_drinker_siphons_a_fallen_enemy() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "fighter", "boon_of_the_soul_drinker", Vector2i(2, 3))
	var weak := TestCombat.punching_bag(e, Vector2i(8, 3), 1)
	TestCombat.start_with(e, c)
	c.creature.hp = 20
	e.deal_damage(null, weak, [{"amount": 10, "type": "fire"}], false, "test")
	assert_eq(c.creature.hp, 70, "50 Hit Points back")
	assert_eq(_ch(c).resource_left("siphon_life"), 0)


func test_poison_mastery_maximizes_once_per_turn() -> void:
	var e := TestCombat.open_field(4)
	var c := _hero(e, "wizard", "boon_of_poison_mastery", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	_dull(foe)
	_knows(c, "poison_spray")
	assert_true(e.spells.cast(c, "poison_spray", 0, [foe]).ok)
	assert_eq(foe.creature.max_hp() - foe.creature.hp, 48, "Poison Spray's 4d12 at maximum")
	assert_false(e.faerun.maximized(c, "poison"), "only once a turn")


func test_furious_storm_immunity_while_bloodied_and_save_disadvantage() -> void:
	var ch := _with("wizard", "boon_of_the_furious_storm")
	ch.hp = ch.max_hp() / 2 - 1
	assert_ne(ch.immunity_source(&"lightning"), "", "immune while Bloodied")
	ch.hp = ch.max_hp()
	assert_eq(ch.immunity_source(&"lightning"), "", "only while Bloodied")
	var e := TestCombat.open_field(4)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	_knows(c, "lightning_bolt")
	assert_true(e.spells.cast(c, "lightning_bolt", 3, [foe], Vector2(6.5, 3.5), Vector2.RIGHT).ok)
	assert_true(e.log.dump().contains("Boon of the Furious Storm"), "the save had Disadvantage")
