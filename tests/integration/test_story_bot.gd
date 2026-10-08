extends TestCase
## The scripted player behind the playthrough tests (tests/support/story_bot.gd): it sets out on the travel map by a
## road that's open (the crossroads' castle road is shut until the castle calls; Storyline QA, 2026-10-08), and it
## doesn't touch a place that was freed under it when the journey changes the scene.

var root: Node


func after_each() -> void:
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null


func _start(location: String) -> StoryBot:
	GameState.reset()
	var st := GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.minute_of_day = 10 * 60
	st.location = location
	st.playthrough_seed = 7
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	return StoryBot.new(self, root)


func test_the_road_out_of_the_crossroads_is_an_open_one() -> void:
	var bot := await _start("svalich_crossroads")
	var road := bot.road_out("svalich_crossroads")
	assert_false(road.is_empty(), "the crossroads has roads out")
	var exit := road["exit"] as Dictionary
	assert_ne(str(exit["id"]), "castle_road", "not the castle road, which is shut")
	assert_true(StoryConditions.check(str(exit.get("when", "")), GameState.story), "an exit that's open now")


func test_from_the_crossroads_to_tser_pool_by_the_map() -> void:
	var bot := await _start("svalich_crossroads")
	var there := await bot.go_to("tser_pool")
	assert_true(there, "reached Tser Pool (%s)" % " / ".join(bot.trace.slice(maxi(0, bot.trace.size() - 6))))
	assert_true(bot.view() != null and bot.view().loc_id == "tser_pool", "and the bot stands there")
