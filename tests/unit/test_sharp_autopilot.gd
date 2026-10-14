extends TestCase
## The test party's sharp play (owner, 2026-10-13): the paladin smites what's worth a slot, the cleric opens with Spirit
## Guardians once foes close in, and a caster who knows Fireball throws it at two foes. Plain (sharp off), it plays as
## it did before 2026-10-13.


func before_each() -> void:
	PartyAutopilot.sharp = false


func after_each() -> void:
	PartyAutopilot.sharp = PartyAutopilot.sharp_by_default


static func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 12:
		rows.append("....................")
	return TestCombat.encounter(rows)


static func _smite_prompt(paladin: Combatant, target: Combatant, crit: bool) -> ReactionRequest:
	var req := ReactionRequest.new(CombatFeatures.DIVINE_SMITE, paladin.id, target.id)
	req.callout = "Critical Hit: the smite's dice are doubled" if crit else ""
	return req


func test_the_paladin_smites_a_sturdy_foe_the_blade_wont_fell() -> void:
	var e := _field()
	var godrick := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(5, 5), 6)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(6, 5))
	var twig := TestCombat.foe(e, "twig_blight", Vector2i(6, 6))
	var pilot := PartyAutopilot.new(e)
	assert_false(pilot._answer(_smite_prompt(godrick, ogre, false)), "off, it never smites")
	PartyAutopilot.sharp = true
	assert_true(pilot._answer(_smite_prompt(godrick, ogre, false)), "an ogre is worth a slot")
	assert_false(pilot._answer(_smite_prompt(godrick, twig, false)), "a twig blight isn't")
	assert_true(pilot._answer(_smite_prompt(godrick, ogre, true)), "a Critical Hit on an ogre is")
	assert_false(pilot._answer(_smite_prompt(godrick, twig, true)), "but not when the blade alone fells it")
	ogre.creature.hp = 8
	assert_false(pilot._answer(_smite_prompt(godrick, ogre, false)), "nor a nearly dead ogre")


func test_the_cleric_opens_with_spirit_guardians_once_foes_close_in() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.sharp = on
		var e := _field()
		var liriel := TestCombat.hero(e, "liriel_dawnsong", Vector2i(5, 5), 6)
		TestCombat.foe(e, "ogre", Vector2i(8, 5))
		TestCombat.start_with(e, liriel)
		PartyAutopilot.new(e).play(liriel)
		var conc := liriel.creature.concentration
		var guarding := conc != null and conc.source_id == "spirit_guardians"
		assert_eq(guarding, on, "Spirit Guardians cast only in sharp play (sharp %s)" % on)


func test_the_wizard_throws_fireball_at_two_foes() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.sharp = on
		var e := _field()
		var rat := TestCombat.hero(e, "ratatoille", Vector2i(2, 5), 6)
		TestCombat.foe(e, "wolf", Vector2i(14, 5))
		TestCombat.foe(e, "wolf", Vector2i(14, 7))
		TestCombat.start_with(e, rat)
		var before := (rat.creature as Character).slots_left(3)
		PartyAutopilot.new(e).play(rat)
		var cast := (rat.creature as Character).slots_left(3) < before
		assert_eq(cast, on, "Fireball at two wolves only in sharp play (sharp %s)" % on)
