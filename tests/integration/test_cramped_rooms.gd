extends TestCase
## Cramped rooms (owner, 2026-10-12): small decor on a '=' square (a music box, a doll) no longer fills it, out of fights
## and in them; furniture (the toy shelves) still does.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func test_small_decor_is_walked_over_and_furniture_is_not() -> void:
	var v := LocationView.create("vallaki_blinsky_toys", GameState.story, null, Dice.roller, "default")
	add_child(v)
	assert_false(v.grid.has_flag(Vector2i(3, 10), CombatGrid.LOW), "the music box's square is floor")
	assert_false(v.grid.has_flag(Vector2i(11, 10), CombatGrid.LOW), "the doll's square is floor")
	assert_true(v.grid.has_flag(Vector2i(1, 7), CombatGrid.LOW), "the toy shelves still fill theirs")
	v.queue_free()
