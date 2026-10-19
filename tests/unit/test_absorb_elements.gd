extends TestCase
## Absorb Elements (Xanathar's p. 150, added by the owner 2026-10-18): the Reaction taken when acid, cold, fire,
## lightning or thunder damage lands. It asks like Hellish Rebuke (one pick per way to pay), gives Resistance to that type
## for the blow that triggered it and until the start of the caster's next turn, and stores 1d6 a slot level for the first
## melee hit on that next turn, which uses it up. Foes never cast it. Spell and hazard damage is answered only on Automatic.

const FIRE := [{"amount": 10, "type": "fire", "spell": true}]


## Silvain Aster (a wizard) who knows Absorb Elements beside a dummy that never acts. `foe_first`: it is the dummy's turn,
## the way a reaction to an enemy's blow comes; otherwise the caster's own.
func _scene(rule: String = "auto", level: int = 9, foe_first: bool = true) -> Dictionary:
	var e := TestCombat.open_field(7)
	var c := TestCombat.caster_with(e, ["absorb_elements"], Vector2i(2, 3), level)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	e.shared_turns = false
	TestCombat.start_with(e, foe if foe_first else c)
	if foe_first:
		c.initiative = 20
		e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	c.reaction_rules["absorb_elements"] = rule
	c.reaction_rules["shield"] = "never"
	return {"e": e, "c": c, "foe": foe}


## A dummy that burns what it hits: one melee attack, 4d6 Fire, that always connects.
func _burner(e: Encounter, cell: Vector2i) -> Combatant:
	var action := {"id": "scorch", "name": "Scorch", "kind": "melee", "attack": {"bonus": 30, "reach": 5},
		"damage": [{"average": 14, "dice": "4d6", "type": "fire"}]}
	return e.add(TestChars.dummy(500, false, {"ac": 1, "actions": [action]}), &"enemy", cell)


func _effects(c: Combatant, prefix: String = "Absorb Elements") -> Array[Effect]:
	var out: Array[Effect] = []
	for fx: Effect in c.creature.effects:
		if fx.name.begins_with(prefix):
			out.append(fx)
	return out


func _to_turn_of(e: Encounter, c: Combatant) -> void:
	var guard := 0
	while e.current() != c and guard < 12:
		e.end_turn()
		guard += 1


func _melee_option(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) in ["weapon", "unarmed"]:
			return str(o["id"])
	return ""


## How many times `text` is in the log, the rolls under each line too.
func _logged(e: Encounter, text: String) -> int:
	return e.log.dump().count(text)


func test_the_spell_is_a_level_one_abjuration_reaction_for_four_classes() -> void:
	var s := Compendium.shared().spell_data("absorb_elements")
	assert_eq(int(s["level"]), 1)
	assert_eq(str(s["school"]), "abjuration")
	assert_eq(str((s["casting_time"] as Dictionary)["unit"]), "reaction")
	assert_eq(s["classes"], ["druid", "ranger", "sorcerer", "wizard"])
	assert_eq(str((s["upcast"] as Dictionary)["damage"]), "1d6")
	assert_eq(str((s["source"] as Dictionary)["book"]), "XGtE")


func test_automatic_resists_the_blow_that_triggered_it() -> void:
	var sc := _scene("auto")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	var hp := c.creature.hp
	var slots := (c.creature as Character).slots_left(1)
	var dr := e.deal_damage(foe, c, FIRE, false, "Fire")
	assert_eq(dr.final, 5, "10 Fire halved by the Resistance the spell gives against the very blow that triggered it")
	assert_eq(c.creature.hp, hp - 5)
	assert_eq((c.creature as Character).slots_left(1), slots - 1, "a level 1 slot")
	assert_false(c.reaction_available, "it is a Reaction")
	assert_ne(c.creature.resistance_source(&"fire"), "", "Resistance to Fire")
	assert_eq(c.creature.resistance_source(&"cold"), "", "to that type only")
	var dr2 := e.deal_damage(foe, c, FIRE, false, "Fire")
	assert_eq(dr2.final, 5, "and it keeps resisting until the caster's next turn")
	assert_eq(_logged(e, "casts Absorb Elements"), 1, "cast once")


func test_off_and_ask_do_not_answer_damage_that_cannot_pause() -> void:
	for rule: String in ["ask", "never"]:
		var sc := _scene(rule)
		var e := sc["e"] as Encounter
		var c := sc["c"] as Combatant
		var dr := e.deal_damage(sc["foe"] as Combatant, c, FIRE, false, "Fire")
		assert_eq(dr.final, 10, "%s: a spell's damage can't wait for an answer" % rule)
		assert_true(c.reaction_available, rule)


func test_only_its_five_types_trigger_it() -> void:
	for ty: String in ["acid", "cold", "fire", "lightning", "thunder"]:
		var sc := _scene("auto")
		var c := sc["c"] as Combatant
		(sc["e"] as Encounter).deal_damage(sc["foe"] as Combatant, c, [{"amount": 10, "type": ty, "spell": true}], false, ty)
		assert_ne(c.creature.resistance_source(StringName(ty)), "", "%s is answered" % ty)
	for ty: String in ["force", "necrotic", "radiant", "poison", "psychic", "slashing"]:
		var sc2 := _scene("auto")
		var c2 := sc2["c"] as Combatant
		var dr := (sc2["e"] as Encounter).deal_damage(sc2["foe"] as Combatant, c2, [{"amount": 10, "type": ty, "spell": true}], false, ty)
		assert_true(c2.reaction_available, "%s is not" % ty)
		assert_eq(dr.final, 10)


func test_the_biggest_type_is_the_one_it_answers() -> void:
	var sc := _scene("auto")
	var c := sc["c"] as Combatant
	(sc["e"] as Encounter).deal_damage(sc["foe"] as Combatant, c, [{"amount": 4, "type": "fire", "spell": true}, {"amount": 9, "type": "cold", "spell": true}], false, "Flurry")
	assert_ne(c.creature.resistance_source(&"cold"), "")
	assert_eq(c.creature.resistance_source(&"fire"), "")
	assert_eq(_effects(c, "Absorb Elements (stored Cold)").size(), 1)


func test_nothing_is_wasted_on_a_type_already_resisted() -> void:
	var sc := _scene("auto")
	var c := sc["c"] as Combatant
	c.creature.add_effect(Effect.new("Warded", &"spell", "fire_ward").with_modifier("resistance", {"value": "fire"}))
	var dr := (sc["e"] as Encounter).deal_damage(sc["foe"] as Combatant, c, FIRE, false, "Fire")
	assert_eq(dr.final, 5)
	assert_true(c.reaction_available, "it keeps its Reaction and its slot")
	assert_true(_effects(c).is_empty())


func test_foes_never_cast_it() -> void:
	var e := TestCombat.open_field(7)
	var wizard := e.add(TestChars.pregen("silvain_aster", 9), &"enemy", Vector2i(5, 3))
	((wizard.creature as Character).spellcasting[0]["prepared"] as Array).append("absorb_elements")
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3))
	TestCombat.start_with(e, hero)
	assert_false(e.spells.reaction_spells.absorb_ready(wizard))
	wizard.reaction_rules["absorb_elements"] = "auto"
	var dr := e.deal_damage(hero, wizard, FIRE, false, "Fire")
	assert_true(wizard.reaction_available)
	assert_eq(dr.final, 10)


func test_an_attack_asks_and_names_the_dice_of_each_slot() -> void:
	var sc := _scene("ask")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var burner := _burner(e, Vector2i(3, 2))
	e.order.erase(burner)
	e.order.insert(0, burner)
	e.turn_index = 0
	e._begin_turn()
	TestCombat.next_d20(e, 19)
	var r := e.monster_attack(burner, c, "scorch")
	assert_true(r.ok, r.reason)
	assert_true(e.pending != null and e.pending.kind == "absorb_elements", "asked against an attack: %s" % e.log.dump())
	if e.pending == null:
		return
	assert_eq(e.pending.title, "Reaction: Absorb Elements?")
	var labels: Array = e.pending.target_choices.map(func(o: Dictionary) -> String: return str(o["label"]))
	assert_eq(labels.size(), 5, "a pick for each of the five slot levels Silvain has: %s" % str(labels))
	assert_true(str(labels[0]).contains("Level 1") and str(labels[0]).contains("1d6"), str(labels))
	assert_true(str(labels[2]).contains("Level 3") and str(labels[2]).contains("3d6"), str(labels))
	assert_eq(e.pending.selected_ids, ["1"] as Array[String], "it starts on the lowest slot")
	var l3 := (c.creature as Character).slots_left(3)
	e.pending.selected_ids.assign(["3"])
	assert_true(e.answer_reaction(true).ok)
	assert_eq((c.creature as Character).slots_left(3), l3 - 1, "the level 3 slot that was picked")
	var stored := _effects(c, "Absorb Elements (stored Fire)")
	assert_eq(stored.size(), 1)
	assert_eq(stored[0].modifiers[0].text("dice"), "3d6", "1d6 a slot level")
	assert_ne(c.creature.resistance_source(&"fire"), "")
	while e.pending != null:
		e.answer_reaction(false)


func test_declining_the_prompt_takes_the_whole_blow() -> void:
	var sc := _scene("ask")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var burner := _burner(e, Vector2i(3, 2))
	e.order.erase(burner)
	e.order.insert(0, burner)
	e.turn_index = 0
	e._begin_turn()
	TestCombat.next_d20(e, 19)
	e.monster_attack(burner, c, "scorch")
	assert_true(e.pending != null and e.pending.kind == "absorb_elements")
	e.answer_reaction(false)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(c.reaction_available)
	assert_true(_effects(c).is_empty())
	assert_eq(_logged(e, "casts Absorb Elements"), 0, "and the damage afterwards doesn't cast it behind the answer")


func test_automatic_still_asks_when_there_are_several_ways_to_cast_it() -> void:
	var sc := _scene("auto")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var burner := _burner(e, Vector2i(3, 2))
	e.order.erase(burner)
	e.order.insert(0, burner)
	e.turn_index = 0
	e._begin_turn()
	TestCombat.next_d20(e, 19)
	e.monster_attack(burner, c, "scorch")
	assert_true(e.pending != null and e.pending.kind == "absorb_elements", "Silvain has five slot levels to choose from")
	while e.pending != null:
		e.answer_reaction(false)


func test_automatic_casts_without_asking_when_there_is_one_way() -> void:
	var sc := _scene("auto", 1)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	assert_eq(e.spells.reaction_spells.payment_ways(c, "absorb_elements"), 1, "a level 1 wizard has level 1 slots only")
	var burner := _burner(e, Vector2i(3, 2))
	e.order.erase(burner)
	e.order.insert(0, burner)
	e.turn_index = 0
	e._begin_turn()
	TestCombat.next_d20(e, 19)
	e.monster_attack(burner, c, "scorch")
	while e.pending != null and e.pending.kind != "absorb_elements":
		e.answer_reaction(false)
	assert_true(e.pending == null or e.pending.kind != "absorb_elements", "no prompt for the one casting")
	assert_eq(_logged(e, "casts Absorb Elements"), 1)
	assert_false(c.reaction_available)


func test_the_stored_damage_is_added_once_to_the_first_melee_hit_of_the_next_turn() -> void:
	var sc := _scene("auto")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	e.deal_damage(foe, c, FIRE, false, "Fire")
	assert_eq(_effects(c, "Absorb Elements (stored").size(), 1)
	_to_turn_of(e, c)
	assert_eq(e.current(), c)
	assert_eq(c.creature.resistance_source(&"fire"), "", "the Resistance ended as the turn began")
	assert_eq(_effects(c, "Absorb Elements (stored").size(), 1, "the charge waits for the melee hit")
	var opt := _melee_option(e, c)
	assert_ne(opt, "", "Silvain has a melee attack")
	TestCombat.next_d20(e, 15)
	var hp := foe.creature.hp
	var r := e.attack(c, foe, opt)
	while e.pending != null:
		r = e.answer_reaction(true)
	assert_true(r.ok, r.reason)
	assert_eq(_logged(e, "Absorb Elements (stored Fire) 1d6"), 1, "the first hit carries the extra 1d6 Fire: %s" % e.log.dump())
	assert_true(_effects(c, "Absorb Elements").is_empty(), "and the spell ends")
	assert_true(foe.creature.hp < hp)
	TestCombat.next_d20(e, 15)
	e.attack(c, foe, opt)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(_logged(e, "Absorb Elements (stored Fire) 1d6"), 1, "never twice")


func test_a_miss_or_a_ranged_attack_keeps_the_charge() -> void:
	var sc := _scene("auto")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	e.deal_damage(foe, c, FIRE, false, "Fire")
	_to_turn_of(e, c)
	var data := Compendium.shared().spell_data("fire_bolt")
	var cast := e.spells.cast_with_numbers(c, "fire_bolt", 0, [foe], Vector2.INF,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, {})
	assert_true(cast.ok, "%s: %s" % [data["name"], cast.reason])
	assert_eq(_logged(e, "Absorb Elements (stored"), 0, "a ranged spell attack doesn't use it")
	assert_eq(_effects(c, "Absorb Elements (stored").size(), 1, "it is still waiting")


func test_a_melee_spell_attack_uses_it() -> void:
	var sc := _scene("auto")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	e.deal_damage(foe, c, FIRE, false, "Fire")
	_to_turn_of(e, c)
	TestCombat.next_d20(e, 15)
	var cast := e.spells.cast_with_numbers(c, "shocking_grasp", 0, [foe], Vector2.INF,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, {})
	assert_true(cast.ok, cast.reason)
	assert_eq(_logged(e, "Absorb Elements (stored Fire)"), 1, "Shocking Grasp is a melee attack: %s" % e.log.dump())
	assert_true(_effects(c).is_empty(), "the spell ends")


func test_it_expires_on_time() -> void:
	# Taken on another creature's turn: the Resistance ends as the caster's next turn starts, an unused charge as it ends.
	var sc := _scene("auto")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	e.deal_damage(foe, c, FIRE, false, "Fire")
	assert_eq(_effects(c).size(), 2, "the ward and the stored charge")
	_to_turn_of(e, c)
	assert_eq(_effects(c, "Absorb Elements (Fire)").size(), 0, "the ward is gone at the start of the turn")
	assert_eq(_effects(c, "Absorb Elements (stored").size(), 1)
	e.end_turn()
	assert_true(_effects(c).is_empty(), "the unused charge ends with the turn")
	assert_true(c.creature.modifiers_for(&"extra_damage").is_empty())


func test_cast_on_the_casters_own_turn_it_serves_the_next_one() -> void:
	var sc := _scene("auto", 9, false)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	e.deal_damage(foe, c, FIRE, false, "A trap on its own turn")
	assert_eq(_effects(c).size(), 2)
	var opt := _melee_option(e, c)
	TestCombat.next_d20(e, 15)
	e.attack(c, foe, opt)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(_logged(e, "Absorb Elements (stored"), 0, "the same turn's hit isn't the 'next turn'")
	e.end_turn()
	assert_eq(_effects(c, "Absorb Elements (stored").size(), 1, "its turn ending doesn't end the charge")
	assert_eq(_effects(c, "Absorb Elements (Fire)").size(), 1, "and the Resistance holds through the round")
	_to_turn_of(e, c)
	assert_eq(_effects(c, "Absorb Elements (Fire)").size(), 0)
	TestCombat.next_d20(e, 15)
	e.attack(c, foe, opt)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(_logged(e, "Absorb Elements (stored Fire) 1d6"), 1, "its next turn's first melee hit")


func test_it_is_listed_among_a_casters_reaction_rules() -> void:
	var sc := _scene("ask")
	var e := sc["e"] as Encounter
	var ids: Array = e.reactions.configurable_policies(sc["c"] as Combatant).map(func(p: Dictionary) -> String: return str(p["id"]))
	assert_true("absorb_elements" in ids, str(ids))
