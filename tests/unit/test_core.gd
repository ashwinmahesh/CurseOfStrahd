extends TestCase
## Autoloads: GameState, SaveSystem, ModeController.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)


func test_mode_transitions() -> void:
	assert_true(ModeController.enter(ModeController.Mode.COMBAT))
	assert_false(ModeController.can_enter(ModeController.Mode.REST), "no resting mid-combat")
	assert_true(ModeController.enter(ModeController.Mode.EXPLORATION))
	ModeController.force(ModeController.Mode.EXPLORATION)


func test_flags_and_clock() -> void:
	GameState.set_flag("doru_freed")
	assert_eq(GameState.get_flag("doru_freed"), true)
	assert_eq(GameState.get_flag("unknown"), false)
	GameState.minute_of_day = 23 * 60
	GameState.advance_minutes(120)
	assert_eq(GameState.day, 2)
	assert_eq(GameState.minute_of_day, 60)
	assert_true(GameState.is_night())


func test_save_and_load_round_trip() -> void:
	GameState.party.append({"name": "Ilse", "class": "fighter", "level": 1})
	GameState.party.append({"name": "Doru", "class": "cleric", "level": 1})
	GameState.set_leader(1)
	GameState.set_flag("ireena_escorted", true)
	GameState.party_positions.append(Vector3(1.5, 0, -2))
	Dice.reseed(77)
	Dice.roller.d20()
	assert_eq(SaveSystem.save("unit_test"), OK)
	var would_follow: Array[int] = []
	for i in 8:
		would_follow.append(Dice.roller.d20())
	GameState.reset()
	Dice.reseed(1)
	assert_eq(SaveSystem.load_slot("unit_test"), OK)
	assert_eq(GameState.party.size(), 2)
	assert_eq(GameState.leader_index, 1)
	assert_eq(GameState.get_flag("ireena_escorted"), true)
	assert_eq(GameState.party_positions[0], Vector3(1.5, 0, -2))
	# Owner decision 2026-10-07 (ADR 0002): a load rolls fresh dice instead of replaying the saved sequence.
	var after_load: Array[int] = []
	for i in 8:
		after_load.append(Dice.roller.d20())
	assert_ne(after_load, would_follow, "a load doesn't replay the rolls that followed the save")
	DirAccess.remove_absolute(SaveSystem.slot_path("unit_test"))


func test_no_saving_in_combat() -> void:
	ModeController.enter(ModeController.Mode.COMBAT)
	assert_eq(SaveSystem.save("unit_test_combat"), ERR_UNAVAILABLE)
	ModeController.force(ModeController.Mode.EXPLORATION)
