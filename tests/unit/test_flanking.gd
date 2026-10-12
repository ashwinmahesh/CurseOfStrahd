extends TestCase
## Flanking (2024 DMG optional rule; owner, 2026-10-12): Advantage on melee attacks against a foe with an ally on its
## opposite side, both next to it, for heroes and foes alike, with a switch in Settings.


func _adv(e: Encounter, c: Combatant, t: Combatant, option_id: String) -> Array:
	return (e.attacks.attack_situation(c, t, e.option_by_id(c, option_id))["advantage"] as Array)


func test_an_ally_across_the_foe_gives_advantage() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(6, 3), 5)
	TestCombat.start_with(e, ilse)
	assert_true("Flanking" in _adv(e, ilse, z, "weapon:greatsword"), "east and west of it")
	var lines := ActionCatalog.new(e).attack_preview(ilse, ActionCatalog.new(e).find(ilse, "attack:weapon:greatsword"), z)["lines"] as Array
	assert_true(lines.has("Advantage: Flanking"), "the odds on hover name it: %s" % [lines])
	god.cell = Vector2i(6, 4)
	assert_false("Flanking" in _adv(e, ilse, z, "weapon:greatsword"), "a corner beside, not across")
	god.cell = Vector2i(6, 2)
	ilse.cell = Vector2i(4, 4)
	assert_true("Flanking" in _adv(e, ilse, z, "weapon:greatsword"), "opposite corners")


func test_only_melee_and_only_an_ally_who_can_act() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(6, 3), 5)
	TestCombat.start_with(e, ilse)
	assert_false("Flanking" in _adv(e, ilse, z, "weapon:shortbow"), "a bow shot doesn't flank")
	god.creature.hp = 0
	assert_false("Flanking" in _adv(e, ilse, z, "weapon:greatsword"), "a fallen ally flanks nobody")
	god.creature.hp = god.creature.max_hp()
	e.flanking = false
	assert_false("Flanking" in _adv(e, ilse, z, "weapon:greatsword"), "Settings turned it off")


func test_foes_flank_too_and_big_foes_by_their_sides() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3), 5)
	var z1 := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.foe(e, "zombie", Vector2i(6, 3))
	var ogre := TestCombat.foe(e, "ogre", Vector2i(9, 6))
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(11, 7), 5)
	TestCombat.start_with(e, ilse)
	assert_true("Flanking" in _adv(e, z1, ilse, "monster:slam"), "two zombies either side of her")
	ilse.cell = Vector2i(8, 6)
	assert_true("Flanking" in _adv(e, ilse, ogre, "weapon:greatsword"), "west and east of the Large ogre")
	god.cell = Vector2i(10, 8)
	assert_false("Flanking" in _adv(e, ilse, ogre, "weapon:greatsword"), "west and south aren't across from each other")
