extends TestCase
## Owner decision (2026-10-07): "Everytime I reload and re-roll, its the same number." Every load seeds the dice
## fresh, so two loads of one save roll differently; the world the save holds (the Tarokka reading, its seed) stays.


func _rolls(n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(Dice.roller.d20("test"))
	return out


func test_two_loads_of_one_save_roll_differently() -> void:
	# Saving is refused in a fight; an earlier file in the same run may have left the arena's fight mode on.
	ModeController.force(ModeController.Mode.EXPLORATION)
	GameState.reset()
	GameState.story.party.append(TestChars.pregen("silvain_aster", 3))
	GameState.story.playthrough_seed = 1234
	Dice.reseed(99)
	assert_eq(SaveSystem.save("fresh_dice"), OK)
	assert_eq(SaveSystem.load_slot("fresh_dice"), OK)
	var first := _rolls(12)
	assert_eq(SaveSystem.load_slot("fresh_dice"), OK)
	var second := _rolls(12)
	assert_ne(first, second, "a reload doesn't replay the same rolls")
	assert_eq(GameState.story.playthrough_seed, 1234, "the save's world seed is kept")
	SaveSystem.delete_slot("fresh_dice")


func test_a_new_game_gets_its_own_dice() -> void:
	Dice.reseed(7)
	var fixed := _rolls(12)
	Dice.reseed_random()
	var a := _rolls(12)
	Dice.reseed_random()
	var b := _rolls(12)
	assert_ne(a, b, "two fresh seeds roll differently")
	assert_ne(a, fixed)
