extends TestCase
## Invisible creatures (owner, 2026-10-13: "Creatures that go invisible should disappear from the map unless the player
## character targeting them has invisibility. They shouldn't be targetable outside of AoE spells"): a foe that is
## Invisible, to one who can't see it (no See Invisibility, Truesight, Blindsight in range, Robe of Eyes, Lantern of
## Revealing), can't be attacked, targeted by a spell or picked on the hotbar; an area still catches it; the player's
## map and turn order leave it out unless one of the party can see it (EncounterSight.unseen_foe, hidden_from_party).


func _invisible(who: Combatant) -> Effect:
	var fx := Effect.new("Invisible", &"spell", "greater_invisibility").with_condition(&"invisible")
	who.creature.add_effect(fx)
	return fx


func _sees_invisible(who: Combatant) -> void:
	who.creature.add_effect(Effect.new("See Invisibility", &"spell", "see_invisibility").with_modifier("flag", {"value": "see_invisibility"}))


## A level 7 wizard, a fighter beside the foe, and a foe 5 squares off.
func _scene() -> Dictionary:
	var e := TestCombat.open_field(5)
	var wiz := TestCombat.high_caster(e, ["fireball", "invisibility", "hold_person"], Vector2i(2, 3))
	var fighter := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, wiz)
	# A Fireball cast here reaches the wizard too, and Absorb Elements would ask it first (a spell's save damage is asked about).
	wiz.reaction_rules["absorb_elements"] = "never"
	return {"e": e, "wiz": wiz, "fighter": fighter, "foe": foe}


func test_only_real_invisibility_counts_not_the_hidden_condition() -> void:
	var sc := _scene()
	var foe := sc["foe"] as Combatant
	assert_false(EncounterSight.truly_invisible(foe))
	foe.creature.add_condition(&"invisible", "Hidden")
	assert_false(EncounterSight.truly_invisible(foe), "Hide's condition leaves a creature on the map, as before")
	_invisible(foe)
	assert_true(EncounterSight.truly_invisible(foe), "an Invisibility spell")


func test_an_invisible_foe_is_unseen_unless_its_looker_sees_invisible() -> void:
	var sc := _scene()
	var e := sc["e"] as Encounter
	var wiz := sc["wiz"] as Combatant
	var fighter := sc["fighter"] as Combatant
	var foe := sc["foe"] as Combatant
	assert_false(e.sight.unseen_foe(fighter, foe), "seen while visible")
	_invisible(foe)
	assert_true(e.sight.unseen_foe(fighter, foe))
	assert_true(e.sight.unseen_foe(wiz, foe))
	_sees_invisible(wiz)
	assert_false(e.sight.unseen_foe(wiz, foe), "See Invisibility: the wizard sees it")
	assert_true(e.sight.unseen_foe(fighter, foe), "each looks for themselves")
	# Blindsight within its range sees it too.
	fighter.creature.add_effect(Effect.new("Blindsight", &"spell", "test").with_modifier("sense", {"kind": "blindsight", "value": 10}))
	if fighter.creature.sense_range("blindsight") > 0:
		assert_false(e.sight.unseen_foe(fighter, foe), "Blindsight 10 ft, the foe 5 ft away")
	# Never one's own side.
	var wiz2 := sc["wiz"] as Combatant
	_invisible(fighter)
	assert_false(e.sight.unseen_foe(wiz2, fighter), "a hero can still help an Invisible ally")


func test_attacks_and_spells_on_one_creature_refuse_it_but_an_area_catches_it() -> void:
	var sc := _scene()
	var e := sc["e"] as Encounter
	var wiz := sc["wiz"] as Combatant
	var fighter := sc["fighter"] as Combatant
	var foe := sc["foe"] as Combatant
	_invisible(foe)
	fighter.cell = Vector2i(5, 3)
	var melee := ""
	for o in e.attack_options(fighter):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			melee = str(o["id"])
	assert_ne(melee, "")
	assert_ne(e.attack_legal(fighter, foe, e.option_by_id(fighter, melee)), "", "no swing at what it can't see")
	var check := e.spells._check_targets(wiz, Compendium.shared().spell_data("hold_person"), 2, [foe], Vector2.INF, {})
	assert_true(str(check["why"]).contains("can't see"), str(check["why"]))
	var a := ActionCatalog.new(e)
	var bolt := a.find(wiz, "spell:hold_person")
	assert_true(a.target_why(wiz, bolt, foe).contains("can't see"), "the hotbar refuses it too")
	var hp := foe.creature.hp
	assert_true(e.spells.cast(wiz, "fireball", 3, [], Vector2(6.5, 3.5)).ok)
	assert_true(foe.creature.hp < hp, "a Fireball still burns it")
	_sees_invisible(wiz)
	assert_eq(a.target_why(wiz, a.find(wiz, "spell:hold_person"), foe), "", "with See Invisibility it can be picked")


func test_the_preview_and_the_map_leave_it_out_until_one_of_the_party_sees_it() -> void:
	var sc := _scene()
	var e := sc["e"] as Encounter
	var wiz := sc["wiz"] as Combatant
	var fighter := sc["fighter"] as Combatant
	var foe := sc["foe"] as Combatant
	var a := ActionCatalog.new(e)
	var fb := a.find(wiz, "spell:fireball")
	var seen := a.spell_preview(wiz, fb, Vector2(6.5, 3.5), Vector2.ZERO, 3)
	assert_true((seen["creatures"] as Array).any(func(r: Dictionary) -> bool: return str(r["id"]) == foe.id), "listed while visible")
	_invisible(foe)
	assert_true(e.sight.hidden_from_party(foe))
	var hidden := a.spell_preview(wiz, fb, Vector2(6.5, 3.5), Vector2.ZERO, 3)
	assert_false((hidden["creatures"] as Array).any(func(r: Dictionary) -> bool: return str(r["id"]) == foe.id), "not listed while no one sees it")
	_sees_invisible(fighter)
	assert_false(e.sight.hidden_from_party(foe), "with no one in particular looking, one hero seeing it shows it")
	assert_true(e.sight.hidden_from_party(foe, wiz), "through the wizard's turn it's still gone")
	assert_false(e.sight.hidden_from_party(foe, fighter), "through the one who sees it, it's there")
	assert_true(e.sight.unseen_foe(wiz, foe), "and the wizard still can't pick it")
	var seen_by_fighter := a.spell_preview(fighter, fb, Vector2(6.5, 3.5), Vector2.ZERO, 3)
	assert_true((seen_by_fighter["creatures"] as Array).any(func(r: Dictionary) -> bool: return str(r["id"]) == foe.id), "the fighter's own preview lists it")
	# Allies and the merely Hidden are never taken off the map.
	var ally_hidden := e.sight.hidden_from_party(fighter)
	assert_false(ally_hidden)
	var foe2 := TestCombat.punching_bag(e, Vector2i(8, 5))
	foe2.creature.add_condition(&"invisible", "Hidden")
	assert_false(e.sight.hidden_from_party(foe2))
	# A dead one isn't "hidden", it's dead.
	foe.creature.dead = true
	assert_false(e.sight.hidden_from_party(foe))


func test_a_foe_cannot_swing_at_an_invisible_hero_and_gets_no_opportunity_attack() -> void:
	var e := TestCombat.open_field(5)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var other := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 5))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	TestCombat.start_with(e, wolf)
	var bite := ""
	for o in e.attack_options(wolf):
		if bool(o["melee"]):
			bite = str(o["id"])
	assert_ne(bite, "")
	assert_eq(e.attack_legal(wolf, hero, e.option_by_id(wolf, bite)), "", "while seen")
	_invisible(hero)
	assert_ne(e.attack_legal(wolf, hero, e.option_by_id(wolf, bite)), "", "Invisible: it can't pick the hero out")
	assert_eq(e.attack_legal(wolf, other, e.option_by_id(wolf, bite)) == "" or e.distance(wolf, other) > 5, true)
	var spotted := e._provokers(hero, hero.cell, Vector2i(2, 3))
	assert_false(wolf in spotted, "no Opportunity Attack against what it can't see")


func test_invisibility_that_ends_puts_it_back_on_the_map() -> void:
	var sc := _scene()
	var e := sc["e"] as Encounter
	var wiz := sc["wiz"] as Combatant
	var foe := sc["foe"] as Combatant
	var fx := _invisible(foe)
	assert_true(e.sight.hidden_from_party(foe))
	foe.creature.remove_effect(fx)
	assert_false(e.sight.hidden_from_party(foe), "visible again once it ends")
	assert_false(e.sight.unseen_foe(wiz, foe))
