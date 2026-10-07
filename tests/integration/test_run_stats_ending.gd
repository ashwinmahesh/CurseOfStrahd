extends TestCase
## Run stats at the ending (N8) in the real game scene: a story fight is added to the run when it ends (kills and
## all, an achievement toasted), the record saves with the game, and The End lists what the run earned and opens the
## company's tally with each hero's row. Achievements go beside this test run's saves, never the player's.

const HALL := "run_stats_test_hall"

var root: Node


func before_each() -> void:
	Engine.time_scale = 4.0
	Achievements.path = ""   # beside the test run's own saves (SaveSystem.save_dir)


func after_each() -> void:
	Engine.time_scale = 1.0
	if root != null:
		root.queue_free()
		root = null
	DirAccess.remove_absolute(Achievements.file())
	SaveSystem.current_slot = ""
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _start() -> void:
	Compendium.shared().tables["locations"][HALL] = {"id": HALL, "name": "Run Stats Test Hall", "region": "test",
		"summary": "", "map": {"rows": ["############", "#..........#", "#..........#", "#..........#", "#..........#", "############"]},
		"spawns": {"default": [2, 2]}}
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = HALL
	st.gold = 10.0
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await frames(3)


func test_a_story_fight_counts_and_the_ending_shows_the_tally() -> void:
	assert_true(Achievements.file().begins_with(SaveSystem.save_dir), "beside the test run's saves")
	await _start()
	var st := GameState.story
	var view := root.get("view") as LocationView
	assert_true(view.start_custom_encounter({"id": "two_wolves", "monsters": [{"monster": "wolf", "cell": [8, 2]},
		{"monster": "wolf", "cell": [8, 3]}]}), "the fight starts")
	await frames(4)
	var cv := view.combat_view
	assert_true(cv != null)
	if cv == null:
		return
	var godrick := cv.e.combatants.filter(func(c: Combatant) -> bool: return c.name() == "Godrick Pendlebrook")[0] as Combatant
	for c in cv.e.combatants:
		if c.side == &"enemy":
			cv.e.deal_damage(godrick, c, [{"amount": 60, "type": "slashing"}], false, "test")
	cv.e.call("_check_over")
	st.gold = 60.0   # the wolves' den had a purse
	cv.finished.emit("victory")
	await frames(4)
	var rs := st.run_stats
	assert_eq(int(rs.get("fights", 0)), 1, "the fight was added to the run")
	var h := (rs["heroes"] as Dictionary)[RunStats.hero_key(st.party[0])] as Dictionary
	assert_eq(int(h["kills"]), 2, "both wolves are Godrick's")
	assert_eq(int(h["best_hit"]), 60)
	assert_eq(int((rs["kills_by_kind"] as Dictionary)["wolf"]), 2)
	assert_eq(float(rs["gold_found"]), 50.0)
	assert_true("first_victory" in (rs["earned"] as Array) and "big_hit" in (rs["earned"] as Array), str(rs.get("earned")))
	assert_true(Achievements.has("first_victory"), "kept beside the saves")
	# The record saves with the game.
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(int(back.run_stats["fights"]), 1)
	# The End lists the run's achievements and opens the tally.
	st.set_flag(Endings.FLAG, "strahd_destroyed")
	st.set_flag("strahd_destroyed", true)
	root.call("show_ending")
	await frames(3)
	var screen := root.get("ending") as EndingScreen
	assert_true(screen != null, "the ending")
	if screen == null:
		return
	screen.save_on_finish = false
	screen.to_title = false
	for i in 200:
		if screen.phase == EndingScreen.Phase.END:
			break
		screen.skip()
		await frames(1)
	assert_eq(screen.phase, EndingScreen.Phase.END)
	var tally_button := screen.find_child("Tally", true, false) as Button
	assert_true(tally_button != null, "the tally's button on The End")
	tally_button.pressed.emit()
	await frames(2)
	assert_true(screen.tally != null, "the company's tally")
	var text := ""
	for l in screen.tally.find_children("*", "Label", true, false):
		text += (l as Label).text + "\n"
	assert_true(text.contains("Godrick Pendlebrook") and text.contains("Liriel Dawnsong"), "a row per hero")
	assert_true(text.contains("2 Wolf"), "the foes defeated most")
	assert_true(text.contains("First Blood"), "the achievements")
	screen.close_tally()
	assert_true(screen.tally == null)
