extends TestCase
## Reactions to being hit when the hit is an Opportunity Attack on the hero's own move (owner report 2026-10-13:
## Ratatouille wasn't asked about Shield, after a level 3 spell earlier in his turn). Shield is asked about there as
## anywhere, and Reactions don't count towards the turn's one spell slot (owner's house rule, 2026-10-13): a slot spell
## before it doesn't stop it, and it doesn't stop one after it. A hit Shield can't turn aside says so in its details.
## The AI and the autopilot (Automatic rules) cast it too.


## A hero at (3, 3) beside a dire wolf at (4, 3), on the hero's turn.
func _beside_wolf(ch: Character) -> Dictionary:
	var e := TestCombat.open_field(3)
	ch.heroic_inspiration = false
	var h := e.add(ch, &"party", Vector2i(3, 3))
	h.reaction_rules["lucky"] = "never"
	var wolf := TestCombat.foe(e, "dire_wolf", Vector2i(4, 3))
	wolf.creature.hp = 200
	TestCombat.start_with(e, h)
	return {"e": e, "h": h, "wolf": wolf}


## The wolf's next attack roll comes out `over` above the hero's AC (0: it only just hits).
func _wolf_rolls(e: Encounter, h: Combatant, over: int = 0) -> void:
	TestCombat.next_d20(e, clampi(h.creature.ac_value() + over - 5, 2, 19))


func _decline_rest(e: Encounter) -> Array[String]:
	var kinds: Array[String] = []
	var guard := 0
	while e.pending != null and guard < 10:
		kinds.append(e.pending.kind)
		e.answer_reaction(false)
		guard += 1
	return kinds


func _logged(e: Encounter, part: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(part))


func test_shield_is_asked_about_when_an_opportunity_attack_hits_on_the_heros_own_move() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var slots := (h.creature as Character).slots_left(1)
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending != null and e.pending.kind == "shield", "asked: %s" % (e.pending.kind if e.pending != null else "nothing"))
	if e.pending == null:
		return
	assert_eq(e.pending.reactor_id, h.id)
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(_logged(e, "casts Shield"), "Shield cast")
	assert_true(_logged(e, "is turned aside"), "the Opportunity Attack misses")
	assert_false(h.creature.has_condition("prone"), "no Bite")
	assert_eq((h.creature as Character).slots_left(1), slots - 1, "a level 1 slot")
	assert_eq(h.cell, Vector2i(0, 3), "the move carries on")


func test_a_cantrip_first_still_leaves_shield() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	assert_true(e.spells.cast(h, "fire_bolt", 0, [f["wolf"]]).ok, "Fire Bolt")
	_decline_rest(e)
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending != null and e.pending.kind == "shield", "a cantrip spends no slot")
	_decline_rest(e)


## Ratatouille's fight: a slot spell first, then the move away.
func test_shield_is_asked_about_after_a_slot_spell_earlier_in_the_turn() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	assert_true(e.spells.cast(h, "magic_missile", 1, [wolf, wolf, wolf]).ok, "Magic Missile")
	_decline_rest(e)
	assert_true(h.cast_slot_spell_this_turn, "the turn's slot spell")
	var slots := (h.creature as Character).slots_left(1)
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending != null and e.pending.kind == "shield", "a Reaction isn't the turn's slot spell: %s" % (e.pending.kind if e.pending != null else "nothing"))
	if e.pending == null:
		return
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(_logged(e, "casts Shield"))
	assert_eq((h.creature as Character).slots_left(1), slots - 1)


## Shield on the way out first: the turn's slot spell is still there to cast.
func test_a_slot_spent_on_shield_leaves_the_turns_slot_spell() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending != null and e.pending.kind == "shield", "asked")
	if e.pending == null:
		return
	e.answer_reaction(true)
	_decline_rest(e)
	assert_false(h.cast_slot_spell_this_turn, "Shield's slot doesn't count")
	var r := e.spells.cast(h, "magic_missile", 1, [wolf, wolf, wolf])
	assert_true(r.ok, "Magic Missile after it: %s" % r.reason)
	_decline_rest(e)


func test_a_hit_shield_cant_turn_aside_says_so_in_its_details() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	_wolf_rolls(e, h, 6)
	e.move(h, Vector2i(0, 3))
	assert_false(_decline_rest(e).has("shield"), "+5 wouldn't make it miss")
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).begins_with("No Shield:"))), "the hit's details say why")


func test_shield_shares_one_prompt_with_the_heros_other_reactions() -> void:
	var ch := TestChars.custom("wizard", "human", 4, {"ability_score_improvement": ["defensive_duelist"]})
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "shield" in prepared:
		prepared.append("shield")
	ch.inventory.append({"id": "dagger", "qty": 1, "slot": ""})
	ch.equip("dagger", "main_hand")
	var f := _beside_wolf(ch)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	assert_true(e.features.holds_finesse(h), "a dagger in hand")
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending != null and e.pending.kind == Reactions.CHOICE, "one prompt: %s" % (e.pending.kind if e.pending != null else "nothing"))
	if e.pending == null:
		return
	var labels := e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["label"]))
	assert_true("Shield" in labels and labels.any(func(l: String) -> bool: return l.contains("Defensive Duelist")), str(labels))
	_decline_rest(e)


func test_hellish_rebuke_answers_an_opportunity_attack_on_the_warlocks_own_move() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	var guard := 0
	while e.pending != null and e.pending.kind != "hellish_rebuke" and guard < 10:
		e.answer_reaction(false)
		guard += 1
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked once the wolf's bite hurts")
	if e.pending == null:
		return
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(wolf.creature.hp < 200, "the wolf burns")
	assert_false(h.reaction_available)


## Hex with a pact slot on his turn, then Hellish Rebuke with the other one on the way out.
func test_hellish_rebuke_takes_a_pact_slot_after_hex_that_turn() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	var ch := h.creature as Character
	ch.spend_resource("spell:hellish_rebuke")   # the tiefling's free casting is gone
	var hex := e.spells.cast(h, "hex", int(ch.pact_magic()["level"]), [wolf])
	assert_true(hex.ok, "Hex with a pact slot: %s" % hex.reason)
	_decline_rest(e)
	var pact_left := int(ch.pact_magic()["left"])
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	var guard := 0
	while e.pending != null and e.pending.kind != "hellish_rebuke" and guard < 10:
		e.answer_reaction(false)
		guard += 1
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked after Hex")
	if e.pending == null:
		return
	e.answer_reaction(true)
	_decline_rest(e)
	assert_eq(int(ch.pact_magic()["left"]), pact_left - 1, "the other pact slot")
	assert_true(wolf.creature.hp < 200, "the wolf burns")


# --- Free castings (coordinator relay 2026-10-13: a Reaction spell never used one) ---------------------------------

## Kip's tiefling Hellish Rebuke (once a Long Rest, no slot): answered with it once his pact slots are spent.
func test_a_free_casting_answers_once_the_slots_are_gone() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	var ch := h.creature as Character
	ch.pact_slots_used = int(ch.pact_magic()["count"])
	assert_eq(ch.resource_left("spell:hellish_rebuke"), 1, "the Infernal legacy's free casting")
	assert_true(e.spells.can_cast_reaction(h, "hellish_rebuke"), "no slots, but the free casting")
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	var guard := 0
	while e.pending != null and e.pending.kind != "hellish_rebuke" and guard < 10:
		e.answer_reaction(false)
		guard += 1
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked")
	if e.pending == null:
		return
	assert_true(e.pending.cost.contains("free casting"), e.pending.cost)
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(_logged(e, "answers with Hellish Rebuke (free casting"), "cast for free")
	assert_eq(ch.resource_left("spell:hellish_rebuke"), 0, "the free casting spent")
	assert_true(wolf.creature.hp < 200, "the wolf burns")


## With both, a warlock's prompt lists the pact slot first and picks it: the free casting (level 1) waits for the pact
## slots, as it does on the hotbar. Picking the free casting spends it instead.
func test_a_warlocks_prompt_lists_the_pact_slot_then_the_free_casting() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var ch := h.creature as Character
	var pact_left := int(ch.pact_magic()["left"])
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	var guard := 0
	while e.pending != null and e.pending.kind != "hellish_rebuke" and guard < 10:
		e.answer_reaction(false)
		guard += 1
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked")
	if e.pending == null:
		return
	var ids := e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["id"]))
	assert_eq(ids, [str(ch.pact_magic()["level"]), "free"], "the pact slot, then the free casting")
	assert_eq(e.pending.selected_ids, [str(ch.pact_magic()["level"])] as Array[String])
	e.pending.selected_ids.assign(["free"])
	e.answer_reaction(true)
	_decline_rest(e)
	assert_eq(int(ch.pact_magic()["left"]), pact_left, "no pact slot spent")
	assert_eq(ch.resource_left("spell:hellish_rebuke"), 0, "the free casting picked")
	assert_true(_logged(e, "answers with Hellish Rebuke (free casting"))


## On Automatic with the pact slot the only way left (the free casting spent), the warlock casts without asking. With
## the free casting left too it is asked which (test_hellish_rebuke_upcast).
func test_on_automatic_a_warlock_with_one_way_to_cast_spends_the_pact_slot() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var ch := h.creature as Character
	ch.spend_resource("spell:hellish_rebuke")
	e.default_player_reaction = "auto"
	var pact_left := int(ch.pact_magic()["left"])
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_false(_decline_rest(e).has("hellish_rebuke"), "nothing asked")
	assert_eq(int(ch.pact_magic()["left"]), pact_left - 1, "a pact slot")


## Shield from a free casting (Magic Initiate's, say) with no slots left.
func test_shield_from_a_free_casting() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var ch := h.creature as Character
	for l in range(1, 10):
		while ch.slots_left(l) > 0:
			ch.expend_slot(l)
	ch.set_resource("spell:shield", "Shield", 1, "long", "A test's free casting")
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending != null and e.pending.kind == "shield", "asked with no slots left")
	if e.pending == null:
		return
	e.answer_reaction(true)
	_decline_rest(e)
	assert_true(_logged(e, "casts Shield (+5 AC until its next turn, free casting)"))
	assert_eq(ch.resource_left("spell:shield"), 0)


## The test autopilot plays with every rule on Automatic: Shield goes up by itself.
func test_on_automatic_shield_goes_up_against_the_opportunity_attack() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	e.default_player_reaction = "auto"
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_true(e.pending == null, "nothing asked")
	assert_true(_logged(e, "casts Shield"))
	assert_eq(h.cell, Vector2i(0, 3))


## An enemy wizard leaving a hero's reach on its own turn: the AI casts Shield against the Opportunity Attack.
func test_an_ai_wizard_shields_against_an_opportunity_attack() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.pregen("ratatoille", 9)
	ch.heroic_inspiration = false
	var foe := e.add(ch, &"enemy", Vector2i(3, 3))
	var wolf := e.add(TestCombat.monster("dire_wolf"), &"party", Vector2i(4, 3))
	wolf.reaction_rules["opportunity_attack"] = "auto"
	TestCombat.start_with(e, foe)
	assert_false(foe.is_player_controlled())
	_wolf_rolls(e, foe)
	e.move(foe, Vector2i(0, 3))
	_decline_rest(e)
	assert_true(_logged(e, "casts Shield"), "the AI took it")
	assert_true(_logged(e, "is turned aside"))
