extends TestCase


func _record(journal: CombatJournal, e: Encounter, kind: String, args: Dictionary = {}) -> CombatResult:
	journal.append(e, kind, args)
	var result := CombatJournal.apply(e, kind, args)
	e.drain_events()
	return result


func _restore(journal: CombatJournal, party: Array[Character] = []) -> Encounter:
	var copy := CombatJournal.new()
	copy.data = JSON.parse_string(JSON.stringify(journal.data)) as Dictionary
	return copy.restore(DiceRoller.new(99), party)


func _same(a: Encounter, b: Encounter) -> void:
	assert_eq(b.dice.get_state(), a.dice.get_state(), "64-bit dice state survives JSON exactly")
	assert_eq(b.state, a.state)
	assert_eq(b.round_no, a.round_no)
	assert_eq(b.turn_index, a.turn_index)
	assert_eq(b.shared, a.shared)
	assert_eq(b.shared_started, a.shared_started)
	assert_eq(b.shared_ended, a.shared_ended)
	assert_eq(b.combatants.size(), a.combatants.size())
	for c in a.combatants:
		var other := b.get_c(c.id)
		assert_eq(other.cell, c.cell)
		assert_eq(other.action_available, c.action_available)
		assert_eq(other.bonus_available, c.bonus_available)
		assert_eq(other.movement_left, c.movement_left)
		assert_eq(JSON.parse_string(JSON.stringify(other.creature.state_to_dict())), JSON.parse_string(JSON.stringify(c.creature.state_to_dict())))
		if c.creature is Character:
			assert_eq(JSON.parse_string(JSON.stringify((other.creature as Character).to_dict())), JSON.parse_string(JSON.stringify((c.creature as Character).to_dict())))
	assert_eq(b.pending.kind if b.pending != null else "", a.pending.kind if a.pending != null else "")
	if b.pending != null:
		b.pending.continuation = Callable()
		b.pending = null


func test_commands_recover_shared_turns_movement_undo_and_enemy_turns() -> void:
	var e := TestCombat.open_field(712983123342341234)
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.hero(e, "silvain_aster", Vector2i(2, 3), 5)
	TestCombat.foe(e, "zombie", Vector2i(6, 2))
	e.default_player_reaction = "never"
	var journal := CombatJournal.begin(e)
	_record(journal, e, "start", {"surprised": []})
	for turn in 8:
		if e.state == Encounter.State.OVER:
			break
		if e.pending != null:
			_record(journal, e, "answer", {"use": false, "rule": "ask", "selected": [], "amounts": {}})
		elif e.current().is_player_controlled():
			var hero := e.current()
			if hero.cell.x > 0:
				_record(journal, e, "move", {"actor": hero.id, "cell": hero.cell + Vector2i.LEFT})
				_record(journal, e, "undo", {"actor": hero.id})
			_same(e, _restore(journal))
			_record(journal, e, "end")
		else:
			_record(journal, e, "ai")
		_same(e, _restore(journal))


func test_recovery_resets_full_party_inventory_before_replay_and_does_not_repeat_costs() -> void:
	var e := TestCombat.open_field(42)
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	var ch := hero.creature as Character
	ch.add_item("potion_of_healing", 3)
	ch.hp = 1
	e.default_player_reaction = "never"
	var journal := CombatJournal.begin(e)
	_record(journal, e, "start", {"surprised": []})
	while e.current() != hero:
		_record(journal, e, "ai")
	var action := {}
	for choice in ActionCatalog.new(e).actions_for(hero):
		if str(choice.get("id", "")).contains("potion_of_healing") and bool(choice.get("legal", false)):
			action = choice
			break
	assert_false(action.is_empty())
	var result := _record(journal, e, "perform", {"actor": hero.id, "action": action, "targets": [hero],
		"point": Vector2.INF, "direction": Vector2.ZERO, "slot": 0})
	assert_true(result.ok, result.reason)
	var current := Character.from_dict(ch.to_dict())
	var restored := _restore(journal, [current])
	assert_true(restored.get_c(hero.id).creature == current, "world tokens keep their character reference")
	_same(e, restored)
	_same(e, _restore(journal, [current]))


func test_replay_reconstructs_pending_reactions_and_their_continuations() -> void:
	var e := TestCombat.open_field(60)
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	var journal := CombatJournal.begin(e)
	_record(journal, e, "start", {"surprised": []})
	# A monster moving out of the hero's reach offers a real Opportunity Attack with its continuation.
	if e.current() == hero:
		_record(journal, e, "end")
	assert_true(e.current() == foe)
	var moved := _record(journal, e, "move", {"actor": foe.id, "cell": Vector2i(6, 2)})
	assert_true(moved.is_paused())
	_same(e, _restore(journal))
	_record(journal, e, "answer", {"use": true, "rule": "ask", "selected": [], "amounts": {}})
	_same(e, _restore(journal))
	while e.pending != null:
		_record(journal, e, "answer", {"use": false, "rule": "ask", "selected": [], "amounts": {}})
		_same(e, _restore(journal))


func test_round_start_can_become_a_recovery_base_without_double_start_effects() -> void:
	var e := TestCombat.open_field(72)
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(7, 2))
	e.keep_round_snapshots = true
	e.default_player_reaction = "never"
	e.start()
	var base := e.round_snapshot.duplicate(true)
	var before := EncounterSnapshot.restore(base, DiceRoller.new(91), [], false)
	before.default_player_reaction = "never"
	var journal := CombatJournal.begin(before, base)
	var resumed := journal.restore(DiceRoller.new(99))
	_record(journal, resumed, "end")
	_same(resumed, _restore(journal))


func _until_player(journal: CombatJournal, e: Encounter, hero: Combatant) -> void:
	for turn in 30:
		if e.current() == hero and e.pending == null:
			return
		if e.pending != null:
			_record(journal, e, "answer", {"use": false, "rule": "ask", "selected": [], "amounts": {}})
		elif e.current().is_player_controlled():
			_record(journal, e, "end")
		else:
			_record(journal, e, "ai")
	fail("Hero never reached their turn")


func _action(e: Encounter, hero: Combatant, id: String) -> Dictionary:
	for action in ActionCatalog.new(e).actions_for(hero):
		if str(action["id"]) == id:
			return action
	fail("Missing action: " + id)
	return {}


func test_reaction_point_allocation_and_spell_slots_are_recovered_once() -> void:
	var e := TestCombat.open_field(18)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 5)
	var ally := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(3, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	ally.creature.hp = 1
	var journal := CombatJournal.begin(e)
	_record(journal, e, "start", {"surprised": []})
	_until_player(journal, e, hero)
	var result := _record(journal, e, "perform", {"actor": hero.id, "action": _action(e, hero, "preserve_life"), "targets": [],
		"point": Vector2.INF, "direction": Vector2.ZERO, "slot": 0})
	assert_true(result.is_paused())
	_same(e, _restore(journal))
	_record(journal, e, "answer", {"use": true, "rule": "ask", "selected": [], "amounts": {ally.id: 9}})
	assert_eq(ally.creature.hp, 10)
	_same(e, _restore(journal))
	_record(journal, e, "end")
	_until_player(journal, e, hero)
	var spell := _action(e, hero, "spell:bless")
	result = _record(journal, e, "perform", {"actor": hero.id, "action": spell, "targets": [hero, ally],
		"point": Vector2.INF, "direction": Vector2.ZERO, "slot": 1})
	assert_true(result.ok, result.reason)
	_same(e, _restore(journal))


func test_incompatible_or_malformed_journals_are_rejected() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(7, 2))
	var journal := CombatJournal.begin(e)
	journal.append(e, "start", {"surprised": []})
	assert_true(CombatJournal.valid(journal.data))
	for key: String in ["version", "dice", "base", "options", "commands", "effects", "counters"]:
		var data := journal.data.duplicate(true)
		data[key] = "corrupt"
		assert_false(CombatJournal.valid(data), key)
	var unknown := journal.data.duplicate(true)
	unknown["commands"][0]["kind"] = "execute_script"
	assert_false(CombatJournal.valid(unknown))
