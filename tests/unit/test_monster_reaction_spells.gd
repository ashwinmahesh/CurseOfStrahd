extends TestCase
## Foes casting Shield and Counterspell from their stat blocks (coordinator relay 2026-10-13: no foe ever did; the
## owner's rule is that foes use their spells when best): the mage's Protective Magic (3/day, Counterspell or Shield),
## Kasimir's and the apprentice wizard's Spellcasting. Counterspell answers a levelled spell a hero casts within 60 ft:
## a Constitution save, and on a failure the spell dissipates with the action spent and the slot kept.


## A dire wolf on the party's side (Bite +5) beside `foe_id`, on the wolf's turn.
func _wolf_and(foe_id: String) -> Dictionary:
	var e := TestCombat.open_field(3)
	var wolf := e.add(TestCombat.monster("dire_wolf"), &"party", Vector2i(3, 3))
	var foe := TestCombat.foe(e, foe_id, Vector2i(4, 3))
	foe.creature.hp = 200
	TestCombat.start_with(e, wolf)
	return {"e": e, "wolf": wolf, "foe": foe}


## The wolf bites, its roll landing exactly on the foe's AC.
func _bite(f: Dictionary) -> CombatResult:
	var e := f["e"] as Encounter
	var foe := f["foe"] as Combatant
	TestCombat.next_d20(e, clampi(foe.creature.ac_value() - 5, 2, 19))
	return e.attack(f["wolf"] as Combatant, foe, "monster:bite")


## Ratatouille 30 ft from `foe_id`, on his turn.
func _wizard_and(foe_id: String) -> Dictionary:
	var e := TestCombat.open_field(3)
	var ch := TestChars.pregen("ratatoille", 5)
	ch.heroic_inspiration = false
	var w := e.add(ch, &"party", Vector2i(2, 3))
	var foe := TestCombat.foe(e, foe_id, Vector2i(8, 3))
	foe.creature.hp = 200
	TestCombat.start_with(e, w)
	return {"e": e, "w": w, "foe": foe}


func _logged(e: Encounter, part: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(part))


func _settle(e: Encounter) -> void:
	var guard := 0
	while e.pending != null and guard < 10:
		e.answer_reaction(false)
		guard += 1


# --- Shield ---------------------------------------------------------------------------------------------------

func test_a_mage_shields_with_protective_magic() -> void:
	var f := _wolf_and("mage")
	var e := f["e"] as Encounter
	var foe := f["foe"] as Combatant
	_bite(f)
	_settle(e)
	assert_true(_logged(e, "Mage casts Shield"), "Protective Magic")
	assert_true(_logged(e, "is turned aside"), "the bite misses")
	assert_eq(foe.creature.hp, 200)
	assert_false(foe.reaction_available)
	assert_eq(int(foe.get_meta("react_protective_magic", 0)), 1, "one of its three uses")


func test_protective_magic_runs_out_after_three() -> void:
	var f := _wolf_and("mage")
	var e := f["e"] as Encounter
	var foe := f["foe"] as Combatant
	foe.set_meta("react_protective_magic", 3)
	assert_false(e.spells.can_cast_reaction(foe, "shield"), "no uses left")
	_bite(f)
	_settle(e)
	assert_false(_logged(e, "casts Shield"))
	assert_true(foe.creature.hp < 200, "the bite lands")


func test_kasimir_shields_with_his_spellcasting() -> void:
	var f := _wolf_and("kasimir_velikov")
	var e := f["e"] as Encounter
	var foe := f["foe"] as Combatant
	_bite(f)
	_settle(e)
	assert_true(_logged(e, "casts Shield"))
	assert_eq(int(foe.get_meta("cast_shield", 0)), 1, "a use of its Shield a day")


func test_no_shield_without_its_reaction() -> void:
	var f := _wolf_and("mage")
	var e := f["e"] as Encounter
	var foe := f["foe"] as Combatant
	foe.reaction_available = false
	_bite(f)
	_settle(e)
	assert_false(_logged(e, "casts Shield"))


## Magic Missile at an apprentice wizard: Shield stops the darts (the spell's own rule).
func test_an_apprentice_shields_against_magic_missile() -> void:
	var f := _wizard_and("apprentice_wizard")
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var foe := f["foe"] as Combatant
	var r := e.spells.cast(w, "magic_missile", 1, [foe, foe, foe])
	_settle(e)
	assert_true(r.ok, r.reason)
	assert_true(_logged(e, "casts Shield"), "Shield against the darts")
	assert_eq(foe.creature.hp, 200, "the darts are stopped")


# --- Counterspell ---------------------------------------------------------------------------------------------

func test_a_mage_counterspells_a_levelled_spell_and_the_slot_is_kept() -> void:
	var f := _wizard_and("mage")
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var foe := f["foe"] as Combatant
	var ch := w.creature as Character
	var slots := ch.slots_left(1)
	TestCombat.next_d20(e, 2)   # the Constitution save fails
	e.spells.cast(w, "magic_missile", 1, [foe, foe, foe])
	_settle(e)
	assert_true(_logged(e, "Mage casts Counterspell at Ratatouille"), "Protective Magic: Counterspell")
	assert_true(_logged(e, "Magic Missile dissipates (Counterspell)"))
	assert_eq(foe.creature.hp, 200, "no darts")
	assert_eq(ch.slots_left(1), slots, "the slot is kept")
	assert_false(w.action_available, "the action is spent")
	assert_false(foe.reaction_available)
	assert_eq(int(foe.get_meta("react_protective_magic", 0)), 1)


func test_a_made_save_gets_the_spell_through() -> void:
	var f := _wizard_and("mage")
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var foe := f["foe"] as Combatant
	var slots := (w.creature as Character).slots_left(1)
	TestCombat.next_d20(e, 19)
	e.spells.cast(w, "magic_missile", 1, [foe, foe, foe])
	_settle(e)
	assert_true(_logged(e, "gets through the Counterspell"))
	assert_true(foe.creature.hp < 200, "the darts hit (its Reaction went on Counterspell, so no Shield)")
	assert_eq((w.creature as Character).slots_left(1), slots - 1)


func test_a_cantrip_isnt_worth_a_counterspell() -> void:
	var f := _wizard_and("mage")
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var foe := f["foe"] as Combatant
	e.spells.cast(w, "fire_bolt", 0, [foe])
	_settle(e)
	assert_false(_logged(e, "Counterspell"))
	assert_true(foe.reaction_available)


func test_no_counterspell_without_its_reaction() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.pregen("ratatoille", 5)
	ch.heroic_inspiration = false
	var w := e.add(ch, &"party", Vector2i(0, 0))
	var far := TestCombat.foe(e, "mage", Vector2i(11, 7))
	var near := TestCombat.punching_bag(e, Vector2i(2, 0))
	TestCombat.start_with(e, w)
	assert_true(e.distance(far, w) <= 60, "the open field is small: the mage is in range")
	far.reaction_available = false   # a Reaction already spent
	e.spells.cast(w, "magic_missile", 1, [near, near, near])
	_settle(e)
	assert_false(_logged(e, "Counterspell"), "no Reaction, no Counterspell")


## A hero's guest the player runs (Kasimir at the party's side) doesn't counter: asking would pause the cast.
func test_a_foes_spell_isnt_countered_by_the_players_guest() -> void:
	var e := TestCombat.open_field(3)
	var kas := e.add(TestCombat.monster("kasimir_velikov"), &"guest", Vector2i(2, 3))
	var mage := TestCombat.foe(e, "mage", Vector2i(8, 3))
	TestCombat.start_with(e, mage)
	assert_true(kas.is_player_controlled())
	e.monster_actions.cast(mage, "fireball", [], e.center_of(kas), 3)
	_settle(e)
	assert_true(_logged(e, "Mage casts Fireball"), "the Fireball goes off")
	assert_false(_logged(e, "Counterspell"))
