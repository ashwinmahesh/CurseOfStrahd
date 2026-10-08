extends TestCase
## The weather on the exploring HUD's time line (F12, owner wish to see overworld effects): "Day 1 · 18:00 · Fog ·
## 0 gp" out in the open, nothing about it indoors, where it doesn't reach.

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func test_the_time_line_names_the_weather_outdoors_only() -> void:
	GameState.reset()
	GameState.story.location = "village_of_barovia"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 5:
		await get_tree().process_frame
	var st := GameState.story
	var hud := root.get("hud") as ExploreHud
	var line := (hud.get("_mode") as Label).text
	assert_true(line.contains(" · %s" % Weather.label(st)), "outdoors: %s" % line)
	root.call("enter_location", "blood_of_the_vine", "default")
	for i in 3:
		await get_tree().process_frame
	line = (hud.get("_mode") as Label).text
	assert_false(line.contains(Weather.label(st)), "indoors: %s" % line)
