extends TestCase
## The campaign's end in the real game scene (ADR 0014): a conversation that reaches `end_game`, a parley that ends
## without one (the party yields), and a wipe in a final battle each open the ending screen, never the world or the
## game-over menu. The screen plays the ending's narration and slides, marks the save finished, and closes (in a game
## it goes back to the title; tests stay in the scene). Uses an in-memory hall so no castle content is needed.

const HALL := "ending_test_hall"
const ROOM := "castle_ravenloft_study"   ## the seer card's enemy room (data/tarokka/outcomes.json)

var root: Node


func before_each() -> void:
	Engine.time_scale = 4.0


func after_each() -> void:
	Engine.time_scale = 1.0
	if root != null:
		root.queue_free()
		root = null
	SaveSystem.delete_slot("test_ending")
	SaveSystem.current_slot = ""
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The party at level 10 in a bare hall whose one fight is a final battle, the reading pointing at it.
func _start() -> void:
	Compendium.shared().tables["locations"][HALL] = {"id": HALL, "name": "Ending Test Hall", "region": "test",
		"summary": "", "map": {"rows": ["##########", "#........#", "#........#", "#........#", "#........#", "##########"]},
		"spawns": {"default": [2, 2]},
		"encounters": [{"id": "strahd_waits", "trigger": "dialogue", "final_battle": ROOM, "lair": true,
			"monsters": [{"monster": "wolf", "cell": [7, 3]}]}]}
	GameState.reset()
	var st := GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = HALL
	st.minute_of_day = 22 * 60
	st.playthrough_seed = 7
	st.tarokka = {"tome": "swords_1", "symbol": "swords_2", "sword": "swords_3", "ally": "artifact", "enemy": "seer"}
	st.set_quest_stage("strahds_lair", "foretold")
	SaveSystem.current_slot = "test_ending"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await frames(3)


func _ending() -> EndingScreen:
	return root.get("ending") as EndingScreen


## Plays a conversation through the real dialogue box, Continue after Continue.
func _talk(ref: String, text: String) -> void:
	var f := DialogueFile.parse(text, ref.get_slice(":", 0))
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	root.call("start_dialogue", ref, "strahd")
	for i in 20:
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			break
		d.call("_advance")
		await frames(1)
	assert_true(root.get("dialogue") == null, "the conversation closed")


## Clicks through the whole ending screen; returns how many slides it showed.
func _play_through(screen: EndingScreen) -> int:
	screen.to_title = false
	var shown := 0
	for i in 200:
		if screen.phase == EndingScreen.Phase.END:
			break
		if screen.phase == EndingScreen.Phase.SLIDES:
			shown += 1
		screen.advance()
		await frames(1)
	assert_eq(screen.phase, EndingScreen.Phase.END, "The End is reached")
	return shown


func test_end_game_in_a_conversation_opens_the_ending_and_finishes_the_save() -> void:
	await _start()
	var st := GameState.story
	st.add_guest("ireena")
	st.set_flag("vallaki_backed", "wachter")
	st.set_flag("order_fate", "grudge")
	await _talk("test/ending_parley:start", "~ start\nStrahd: Give her to me.\nset strahd_parley = \"ireena\"\nend_game\n")
	var screen := _ending()
	assert_true(screen != null, "the ending screen is up")
	if screen == null:
		return
	assert_eq(str(screen.ending["id"]), "ireena_given_up")
	assert_false((root.get("hud") as CanvasLayer).visible, "the world's HUD is hidden")
	assert_eq(ModeController.mode, ModeController.Mode.CUTSCENE)
	assert_true(screen.slides.size() >= 5, "slides for the bride, Ismark, Vallaki, the Order ...")
	assert_eq(screen.phase, EndingScreen.Phase.TITLE, "the title card first")
	# A key goes on (Space), the world beneath gets nothing.
	var space := InputEventAction.new()
	space.action = &"combat_end_turn"
	space.pressed = true
	root.get_viewport().push_input(space)
	await frames(2)
	assert_eq(screen.phase, EndingScreen.Phase.NARRATION, "Space goes on to the narration")
	assert_true(str(screen.beat.get("text", "")).begins_with("You step aside"), "Ireena is there to hand over")
	var slides := await _play_through(screen)
	assert_eq(slides, screen.slides.size(), "every slide shown in turn")
	assert_true(screen.lines_shown.size() >= 5, "the narration played: %s" % [screen.lines_shown])
	assert_true(screen.saved, "the save is marked finished")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.slot_path("test_ending")))
	assert_eq(str(((data as Dictionary).get("finished", {}) as Dictionary).get("ending", "")), "ireena_given_up")
	var home := screen.find_child("ReturnToTitle", true, false) as Button
	assert_true(home != null, "Return to the title")
	if home != null:
		home.pressed.emit()
	await frames(2)
	assert_true(_ending() == null, "the screen closed")


func test_yielding_at_the_parley_ends_the_game_without_end_game() -> void:
	await _start()
	await _talk("test/ending_yield:start", "~ start\nStrahd: Kneel, or fight.\nset strahd_parley = \"yield\"\n-> END\n")
	var screen := _ending()
	assert_true(screen != null, "yield ends the game")
	if screen == null:
		return
	assert_eq(str(screen.ending["id"]), "strahd_triumphant")
	screen.save_on_finish = false
	screen.advance()
	assert_true(str(screen.beat.get("text", "")).begins_with("You lower your weapons"), "the yielded branch")
	screen.skip()
	assert_eq(screen.phase, EndingScreen.Phase.SLIDES, "Esc skips the narration")
	assert_true(str(screen.slides[1]["text"]).contains("count's guests"), "the yielded party's slide")
	screen.skip()
	assert_eq(screen.phase, EndingScreen.Phase.END)
	assert_false(screen.saved)


func test_a_wipe_in_the_final_battle_is_an_ending_not_a_game_over() -> void:
	await _start()
	var st := GameState.story
	st.set_flag("strahd_parley", "fight")
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("strahd_waits"), "the final battle starts")
	await frames(4)
	assert_true(view.in_combat and view.combat_view != null)
	if view.combat_view == null:
		return
	for ch in st.party:
		ch.hp = 0
	view.combat_view.finished.emit("defeat")
	await frames(4)
	assert_true(root.get("screen") == null, "no game-over menu")
	var screen := _ending()
	assert_true(screen != null, "the ending screen instead")
	if screen == null:
		return
	assert_eq(Endings.reached(st), "strahd_triumphant")
	screen.save_on_finish = false
	screen.advance()
	assert_true(str(screen.beat.get("text", "")).begins_with("The last of you falls"), "the fallen branch")
	assert_true(str(screen.slides[1]["text"]).contains("walk its halls"), "the fallen party's slide")


func test_an_ordinary_wipe_is_still_a_game_over() -> void:
	await _start()
	var view := root.get("view") as LocationView
	view.start_custom_encounter({"id": "plain_wolves", "monsters": [{"monster": "wolf", "cell": [7, 3]}]})
	await frames(4)
	if view.combat_view == null:
		fail("the fight didn't start")
		return
	view.combat_view.finished.emit("defeat")
	await frames(4)
	assert_true(_ending() == null, "no ending for a wipe outside a final battle")
	assert_true(root.get("screen") is PauseMenu, "the game-over menu")
	assert_eq(Endings.reached(GameState.story), "")
