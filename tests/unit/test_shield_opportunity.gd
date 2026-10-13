extends TestCase
## Reactions to being hit when the hit is an Opportunity Attack on the hero's own move (owner report 2026-10-13:
## Ratatouille wasn't asked about Shield). Shield is asked about there as anywhere; after a spell slot was spent on the
## same turn the 2024 rule of one slot per turn rules it out, and the log says so. A hit Shield can't turn aside says
## so in its details. The AI and the autopilot (Automatic rules) cast it too.


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


func test_after_a_slot_spell_the_log_says_why_shield_isnt_asked_about() -> void:
	var f := _beside_wolf(TestChars.pregen("ratatoille", 9))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	assert_true(e.spells.cast(h, "magic_missile", 1, [wolf, wolf, wolf]).ok, "Magic Missile")
	_decline_rest(e)
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_false(_decline_rest(e).has("shield"), "one slot per turn: no Shield")
	assert_true(_logged(e, "Ratatouille can't cast Shield: a spell slot was already spent this turn"), "and the log says why")


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


func test_after_a_slot_spell_the_log_says_why_hellish_rebuke_isnt_asked_about() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	(h.creature as Character).spend_resource("spell:hellish_rebuke")   # the tiefling's free casting is gone
	var hex := e.spells.cast(h, "hex", int((h.creature as Character).pact_magic()["level"]), [wolf])
	assert_true(hex.ok, "Hex with a pact slot: %s" % hex.reason)
	_decline_rest(e)
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	assert_false(_decline_rest(e).has("hellish_rebuke"), "one slot per turn")
	assert_true(_logged(e, "Kip Smudgewick can't cast Hellish Rebuke: a spell slot was already spent this turn"))


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


## A free casting spends no slot, so the one-slot-per-turn rule leaves it: after Hex on his turn, it still answers.
func test_a_free_casting_isnt_held_back_by_the_one_slot_rule() -> void:
	var f := _beside_wolf(TestChars.pregen("kip_smudgewick", 5))
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var wolf := f["wolf"] as Combatant
	var ch := h.creature as Character
	assert_true(e.spells.cast(h, "hex", int(ch.pact_magic()["level"]), [wolf]).ok, "Hex with a pact slot")
	_decline_rest(e)
	var pact_left := int(ch.pact_magic()["left"])
	_wolf_rolls(e, h)
	e.move(h, Vector2i(0, 3))
	var guard := 0
	while e.pending != null and e.pending.kind != "hellish_rebuke" and guard < 10:
		e.answer_reaction(false)
		guard += 1
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked: the free casting is still there")
	if e.pending == null:
		return
	assert_true(e.pending.target_choices.is_empty(), "no slot to pick this turn")
	e.answer_reaction(true)
	_decline_rest(e)
	assert_eq(int(ch.pact_magic()["left"]), pact_left, "no pact slot spent")
	assert_eq(ch.resource_left("spell:hellish_rebuke"), 0)
	assert_false(_logged(e, "can't cast Hellish Rebuke"))


## With both a free casting and slots, the prompt lists the free casting first and picks it.
func test_the_prompt_lists_the_free_casting_before_the_slots() -> void:
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
	assert_eq(ids, ["0", str(ch.pact_magic()["level"])], "free casting, then the pact slot")
	assert_eq(e.pending.selected_ids, ["0"] as Array[String])
	e.answer_reaction(true)
	_decline_rest(e)
	assert_eq(int(ch.pact_magic()["left"]), pact_left, "the free casting went first")


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
