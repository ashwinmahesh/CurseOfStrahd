extends TestCase
## Knocking Out a Creature (2024 PHB "Damage and Healing"; F13): a melee attack that would drop a creature to 0 Hit
## Points leaves it at 1 and Unconscious instead when the attacker's rule says so, until it finishes a Short Rest,
## regains Hit Points or gets first aid; a fight whose foes are all down or knocked out is won.


## Ilse (her Knock Out rule: `rule`) beside a bandit at 1 Hit Point, with a second foe far off so the fight goes on
## unless `alone`.
func _fight(rule: String, alone: bool = false) -> Dictionary:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	(ilse.creature as Character).heroic_inspiration = false
	if rule != "":
		ilse.reaction_rules["knock_out"] = rule
	var bandit := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	if not alone:
		TestCombat.punching_bag(e, Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	bandit.creature.hp = 1
	return {"e": e, "ilse": ilse, "bandit": bandit}


func _hit(e: Encounter, c: Combatant, t: Combatant) -> CombatResult:
	TestCombat.next_d20(e, 19)
	var r := e.attack(c, t, str(e.best_melee_option(c, t)["id"]))
	while e.pending != null:   # nothing here should ask; declined if it does
		e.answer_reaction(false)
	return r


func test_a_melee_blow_knocks_the_foe_out_when_the_rule_is_on() -> void:
	var f := _fight("auto", true)
	var e := f["e"] as Encounter
	var bandit := f["bandit"] as Combatant
	_hit(e, f["ilse"] as Combatant, bandit)
	assert_true(bandit.is_alive(), "not killed")
	assert_eq(bandit.creature.hp, 1)
	assert_true(bandit.creature.has_flag("knocked_out"), "the flag the captives read")
	assert_true(bandit.creature.has_condition(&"unconscious"))
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("knocks Bandit out")))
	assert_eq(e.state, Encounter.State.OVER, "its only foe knocked out, the fight is won")
	assert_eq(e.outcome, "victory")


func test_blows_kill_as_usual_by_default_and_only_melee_attacks_knock_out() -> void:
	var f := _fight("")
	var e := f["e"] as Encounter
	var bandit := f["bandit"] as Combatant
	_hit(e, f["ilse"] as Combatant, bandit)
	assert_false(bandit.is_alive(), "the rule starts Off")
	var g := _fight("auto")
	var e2 := g["e"] as Encounter
	var bandit2 := g["bandit"] as Combatant
	e2.deal_damage(g["ilse"] as Combatant, bandit2, [{"amount": 5, "type": "fire"}], false, "a spell")
	assert_false(bandit2.is_alive(), "damage that isn't a melee attack kills")


func test_healing_or_first_aid_brings_a_knocked_out_creature_round() -> void:
	var f := _fight("auto")
	var e := f["e"] as Encounter
	var ilse := f["ilse"] as Combatant
	var bandit := f["bandit"] as Combatant
	_hit(e, ilse, bandit)
	assert_true(bandit.creature.has_flag("knocked_out"))
	assert_eq(e.state, Encounter.State.ACTIVE, "another foe is still up")
	bandit.creature.heal(2, "test")
	assert_false(bandit.creature.has_flag("knocked_out"), "regaining Hit Points ends it")
	assert_false(bandit.creature.has_condition(&"unconscious"))
	assert_true(bandit.creature.has_condition(&"prone"), "it comes round on the ground")
	bandit.creature.hp = 1
	ilse.action_available = true
	_hit(e, ilse, bandit)
	assert_true(bandit.creature.has_flag("knocked_out"), "knocked out again")
	ilse.action_available = true
	assert_false(e.stabilize(ilse, bandit, true).ok, "a Healer's Kit only stabilizes the dying")
	TestCombat.next_d20(e, 19)
	var r := e.stabilize(ilse, bandit, false)
	assert_true(r.ok, r.reason)
	assert_false(bandit.creature.has_flag("knocked_out"), "first aid (DC 10 Medicine) brings it round")
	assert_eq(bandit.creature.hp, 1)


func test_a_short_rest_ends_it_and_the_class_tab_offers_the_rule() -> void:
	var f := _fight("auto")
	var e := f["e"] as Encounter
	var ilse := f["ilse"] as Combatant
	var bandit := f["bandit"] as Combatant
	_hit(e, ilse, bandit)
	bandit.creature.finish_short_rest()
	assert_false(bandit.creature.has_flag("knocked_out"))
	var rule: Dictionary = {}
	for p in e.reactions.configurable_policies(ilse):
		if str(p["id"]) == "knock_out":
			rule = p
	assert_eq(str(rule.get("default", "")), "never")
	assert_eq(rule.get("modes", []), ["auto", "never"])
