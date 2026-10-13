extends TestCase
## Creatures the party summons or conjures (a Figurine of Wondrous Power, Find Familiar, Find Steed, the Conjure and
## Summon spells, a Primal Companion, a dominated foe) fight on the party's side everywhere sides matter (owner's
## playtest, 2026-10-13: Spirit Guardians hurt the golden lions summoned after it was cast).


func _lions(e: Encounter, by: Combatant, point: Vector2) -> Array[Combatant]:
	by.creature.add_item("figurine_of_wondrous_power_golden_lions")
	by.action_available = true
	by.magic_action_used = false
	var before := e.combatants.size()
	var r := e.items.use(by, "figurine_of_wondrous_power_golden_lions", "animate", [], point)
	assert_true(r.ok, r.reason)
	var out: Array[Combatant] = []
	for i in range(before, e.combatants.size()):
		out.append(e.combatants[i])
	assert_eq(out.size(), 2, "two Lions")
	return out


## The owner's case: Spirit Guardians first, the lions after, inside the Emanation.
func test_spirit_guardians_spares_lions_summoned_after_it_was_cast() -> void:
	var e := TestCombat.open_field(4)
	var cleric := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5), 5)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	var guard := e.spells.zones.object_of(cleric.id, "spirit_guardians")
	e.end_turn()
	while e.current() != ilse:
		e.end_turn()
	var lions := _lions(e, ilse, Vector2(3.5, 4.5))
	for l in lions:
		assert_true(guard.covers(l), "%s stands inside the spirits" % l.name())
		assert_false(e.spells.zones.affects(guard, l), "the spirits leave %s alone" % l.name())
		assert_false(e.spells.zones.difficult_cells(l).has(Vector2i(3, 4)), "no difficult terrain for %s" % l.name())
	var hp := lions.map(func(l: Combatant) -> int: return l.creature.hp)
	var hp_foe := foe.creature.hp
	# A full round: each lion ends its turn inside, and the cleric moves the Emanation over them.
	while e.current() != cleric:
		e.end_turn()
	cleric.movement_left = 30
	e.move(cleric, Vector2i(4, 4))
	e.end_turn()
	while e.current() != cleric:
		e.end_turn()
	for i in lions.size():
		assert_eq(lions[i].creature.hp, int(hp[i]), "%s unhurt by the spirits" % lions[i].name())
	assert_true(foe.creature.hp < hp_foe, "the foe still takes the damage")


func test_lions_summoned_before_spirit_guardians_are_spared_too() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5), 5)
	var cleric := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, ilse)
	var lions := _lions(e, ilse, Vector2(3.5, 4.5))
	e.end_turn()
	while e.current() != cleric:
		e.end_turn()
	var hp := lions.map(func(l: Combatant) -> int: return l.creature.hp)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	var guard := e.spells.zones.object_of(cleric.id, "spirit_guardians")
	for i in lions.size():
		assert_false(e.spells.zones.affects(guard, lions[i]))
		assert_eq(lions[i].creature.hp, int(hp[i]), "%s unhurt as the spirits appear" % lions[i].name())


## Brings in a creature on the party's side from `source`, cast or used by a hero standing at (2, 5) on its own turn,
## after the cleric's Spirit Guardians went up: the creature, standing inside the spirits at (3, 4).
func _bring(e: Encounter, source: String, cleric: Combatant) -> Combatant:
	var who: Combatant
	match source:
		"figurine":
			who = TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 5), 5)
		"summon_beast", "find_steed", "find_familiar":
			who = TestCombat.caster_with(e, [source], Vector2i(2, 5))
		"dominate_beast":
			who = TestCombat.high_caster(e, ["dominate_beast"], Vector2i(2, 5))
	var beast := TestCombat.punching_bag(e, Vector2i(3, 4), 100, "beast") if source == "dominate_beast" else null
	if source == "find_familiar":
		# A ritual of an hour: called before the fight, and walks into the spirits after they went up.
		TestCombat.give_components(who.creature as Character, ["find_familiar"])
		assert_true(e.spells.precast(who, "find_familiar"))
		e.faerun.familiar_of(who).cell = Vector2i(11, 7)
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	e.end_turn()
	while e.current() != who:
		e.end_turn()
	var r := CombatResult.new()
	match source:
		"figurine":
			return _lions(e, who, Vector2(3.5, 4.5))[0]
		"find_familiar":
			var fam := e.faerun.familiar_of(who)
			fam.cell = Vector2i(3, 4)
			return fam
		"summon_beast":
			r = e.spells.cast(who, "summon_beast", 2, [], Vector2(3.5, 4.5), Vector2.ZERO, {"choice": "land"})
		"find_steed":
			r = e.spells.cast(who, "find_steed", 2, [], Vector2(3.5, 4.5), Vector2.ZERO, {"choice": "celestial"})
		"dominate_beast":
			r = e.spells.cast(who, "dominate_beast", 4, [beast])
			assert_true(r.ok, r.reason)
			return beast
	assert_true(r.ok, r.reason)
	var ids := e.spells.summoned.get(who.id, []) as Array
	return e.get_c(str(ids[-1])) if not ids.is_empty() else null


func test_every_summon_source_fights_on_the_partys_side() -> void:
	for source: String in ["figurine", "summon_beast", "find_steed", "find_familiar", "dominate_beast"]:
		var e := TestCombat.open_field(5)
		var cleric := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
		var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(7, 3), 5)
		var foe := TestCombat.foe(e, "zombie", Vector2i(8, 3))
		var s := _bring(e, source, cleric)
		assert_true(s != null, "%s: a creature joins" % source)
		if s == null:
			continue
		var tag := "%s (%s)" % [s.name(), source]
		assert_true(s.is_player_controlled(), "%s: the player commands it" % tag)
		assert_true(s.allied_with(cleric) and not s.hostile_to(ilse), "%s: on the party's side" % tag)
		assert_true(s.hostile_to(foe) and foe.hostile_to(s), "%s: and against its foes" % tag)
		# Spirit Guardians, cast before it came.
		var guard := e.spells.zones.object_of(cleric.id, "spirit_guardians")
		assert_true(guard.covers(s), "%s: inside the spirits" % tag)
		assert_false(e.spells.zones.affects(guard, s), "%s: spared by Spirit Guardians" % tag)
		# The foe's AI reckons it a target; the autopilot doesn't.
		assert_true(s in e.hostiles_of(foe), "%s: the foes' AI can target it" % tag)
		assert_false(s in PartyAutopilot.new(e)._enemies(ilse), "%s: the party's autopilot never targets it" % tag)
		assert_true(s in e.allies_of(ilse), "%s: one of Ilse's allies" % tag)
		# Flanking: across the zombie from Ilse.
		s.cell = Vector2i(9, 3)
		var adv := e.attacks.attack_situation(ilse, foe, e.option_by_id(ilse, "weapon:greatsword"))["advantage"] as Array
		assert_true("Flanking" in adv, "%s: flanks with Ilse" % tag)


## An Echo Knight's echo (1 Hit Point) isn't an ally for Pack Tactics or healing, but the party's own cleric doesn't
## destroy it: Spirit Guardians cast with the echo inside, and the Emanation moved onto it, leave it be.
func test_spirit_guardians_spares_an_echo_knights_echo() -> void:
	var e := TestCombat.open_field(4)
	var ch := TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["echo_knight"]})
	var knight := e.add(ch, &"party", Vector2i(2, 5))
	var cleric := TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 3), 5)
	var foe := TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, knight)
	var cat := ActionCatalog.new(e)
	assert_true(cat.perform(knight, cat.find(knight, "feat:ek:manifest_echo"), [], Vector2(4.5, 4.5)).ok)
	var echo := e.echo_knight.echoes(knight)[0]
	assert_false(echo in e.allies_of(knight), "still an image, not an ally")
	assert_true(echo in e.hostiles_of(foe), "the foes can strike it")
	e.end_turn()
	while e.current() != cleric:
		e.end_turn()
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	assert_false(e.spells.zones.affects(e.spells.zones.object_of(cleric.id, "spirit_guardians"), echo))
	cleric.movement_left = 30
	e.move(cleric, Vector2i(5, 4))
	assert_true(echo.is_alive() and echo.creature.hp == 1, "the echo stands")
