extends TestCase
## The exploring HUD's see-through panels never sit on each other (UI QA, 2026-10-08): the last roll ran under the
## Narrator's box (a trap's save and the Narrator's line in the Death House attic), and an exit plaque read through the
## box when a save loaded beside a way out (the recap at the Amber Temple's doors).

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	get_tree().paused = false
	GameState.reset()


func _hud() -> ExploreHud:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		GameState.story.party.append(Pregens.build(id, 3))
	GameState.story.location = "village_of_barovia"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 5:
		await get_tree().process_frame
	# The village's arrival picture pauses the game: put it away, as a click would.
	var shown := root.get("screen") as CutscenePlayer
	if shown != null:
		shown.close()
	for i in 3:
		await get_tree().process_frame
	assert_false(get_tree().paused, "playing, nothing over the world")
	return root.get("hud") as ExploreHud


static func _has(rects: Array[Rect2], r: Rect2) -> bool:
	return rects.any(func(x: Rect2) -> bool: return x.is_equal_approx(r))


func test_the_last_roll_waits_above_the_narrators_box() -> void:
	var hud: ExploreHud = await _hud()
	var roll := hud.get("_roll_panel") as PanelContainer
	var narr := hud.get_node("NarratorBox") as PanelContainer
	hud.close_narration()   # whatever the arrival said
	hud.roll("Dexterity save (Godrick Pendlebrook): d20 11 + 0 = 11 vs DC 11, success · Godrick Pendlebrook takes 1 Bludgeoning damage")
	for i in 2:
		await get_tree().process_frame
	var alone := roll.get_rect()
	hud.narrate("Dust lies thick on everything up here, and the air is colder than it should be. Somewhere below, a door closes softly.")
	for i in 3:
		await get_tree().process_frame
	assert_true(narr.visible and roll.visible, "both showing")
	assert_false(roll.get_rect().intersects(narr.get_rect()), "the roll %s is clear of the Narrator's box %s" % [roll.get_rect(), narr.get_rect()])
	assert_true(roll.get_rect().end.y <= narr.get_rect().position.y, "above it")
	hud.close_narration()
	for i in 2:
		await get_tree().process_frame
	assert_eq(roll.get_rect().position, alone.position, "back at the bottom left once the box goes")


func test_the_hud_tells_the_exit_signs_what_to_keep_clear() -> void:
	var hud: ExploreHud = await _hud()
	hud.narrate("The mists part again, and the story picks up where you set it down.")
	for i in 2:
		await get_tree().process_frame
	var narr := (hud.get_node("NarratorBox") as PanelContainer).get_rect()
	assert_true(_has(hud.exit_signs.keep_clear, narr), "the Narrator's box is kept clear")
	for r in hud.exit_signs.plaque_rects:
		assert_false(r.intersects(narr), "a plaque %s sits on the Narrator's box %s" % [r, narr])
	hud.close_narration()
	await get_tree().process_frame
	assert_false(_has(hud.exit_signs.keep_clear, narr), "not kept clear once it goes")


func test_a_plaque_on_a_panel_is_lifted_above_it() -> void:
	var signs := ExitSigns.new()
	var box := Rect2(380, 640, 840, 176)
	var roll := Rect2(380, 590, 520, 42)
	signs.keep_clear = [box]
	var lifted: Rect2 = signs.call("_clear_of_panels", Rect2(600, 700, 220, 44))
	assert_false(lifted.intersects(box), "clear of the box: %s" % lifted)
	assert_eq(lifted.size, Vector2(220, 44), "same size")
	# Lifted off the box onto the roll above it, it moves again.
	signs.keep_clear = [box, roll]
	lifted = signs.call("_clear_of_panels", Rect2(600, 700, 220, 44))
	assert_false(lifted.intersects(box) or lifted.intersects(roll), "clear of both: %s" % lifted)
	# Never off the top of the screen.
	signs.keep_clear = [Rect2(0, 0, 1600, 30)]
	assert_true((signs.call("_clear_of_panels", Rect2(100, 10, 200, 40)) as Rect2).position.y >= 12.0, "stays on screen")
	signs.free()


## The pad's prompt bar over the world is kept clear too (UI QA UI-12): a plaque at the edge sat half under it.
func test_the_pad_bar_is_kept_clear() -> void:
	var hud: ExploreHud = await _hud()
	var was := PadPrompts.world_rect
	# Set and read in one go: with no pad in use the bar's own _process clears it again next frame.
	PadPrompts.world_rect = Rect2(1200, 740, 380, 40)
	hud.call("_keep_panels_apart")
	assert_true(_has(hud.exit_signs.keep_clear, Rect2(1200, 740, 380, 40)), "the bar's rect is kept clear")
	PadPrompts.world_rect = Rect2()
	hud.call("_keep_panels_apart")
	assert_false(_has(hud.exit_signs.keep_clear, Rect2(1200, 740, 380, 40)), "not once it goes")
	PadPrompts.world_rect = was
