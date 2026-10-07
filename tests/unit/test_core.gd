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


## The autosave (docs/plans/ui_polish.md) is never the game's own slot: it remembers the slot it was written for and
## loading it goes back there, so F5 keeps saving where it did. It lists as an autosave, and never saves in a fight.
func test_autosave_keeps_the_games_slot() -> void:
	GameState.party.append({"name": "Ilse", "class": "fighter", "level": 1})
	assert_eq(SaveSystem.save("unit_test_home"), OK)
	assert_eq(SaveSystem.current_slot, "unit_test_home")
	assert_eq(SaveSystem.autosave(), OK)
	assert_eq(SaveSystem.current_slot, "unit_test_home", "autosaving doesn't move the game's slot")
	var kinds := {}
	for s in SaveSystem.list_slots():
		kinds[str(s["slot"])] = str(s["kind"])
	assert_eq(kinds.get(SaveSystem.AUTOSAVE, "?"), "autosave")
	assert_eq(kinds.get("unit_test_home", "?"), "")
	SaveSystem.current_slot = ""
	assert_eq(SaveSystem.load_slot(SaveSystem.AUTOSAVE), OK)
	assert_eq(SaveSystem.current_slot, "unit_test_home", "loading the autosave goes back to its game's slot")
	ModeController.enter(ModeController.Mode.COMBAT)
	assert_eq(SaveSystem.autosave(), ERR_UNAVAILABLE, "no autosave mid-fight")
	ModeController.force(ModeController.Mode.EXPLORATION)
	SaveSystem.delete_slot("unit_test_home")
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
	SaveSystem.current_slot = ""
