extends TestCase
## World sounds in a real place (A3): a fire and a river are heard from where they are, through a listener that
## follows the leader.

const LOC := {
	"id": "test_riverbank", "name": "Test Riverbank", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##############",
		"#.......wwwww#",
		"#.......wwwww#",
		"#.......wwwww#",
		"#.......wwwww#",
		"##############"], "light": "dim", "theme": "riverside", "outdoors": true},
	"spawns": {"default": [2, 2]},
	"lights": [{"cell": [3, 3], "kind": "fire"}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_riverbank"] = LOC.duplicate(true)
	GameState.reset()
	var ch := Pregens.build("hedda_ironvow", 3)
	ch.finish_long_rest()
	GameState.story.party.append(ch)
	GameState.story.location = "test_riverbank"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await get_tree().process_frame
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_riverbank")


func test_fire_and_river_beds_play_where_they_are() -> void:
	var view := root.get("view") as LocationView
	var ws := view.get_node("WorldSounds") as WorldSounds
	assert_eq(ws.floor_sound, "grass", "a riverside walks on grass")
	var names: Array[String] = []
	for b in ws.beds:
		names.append(str(b.name))
		assert_true(b.stream != null, "%s has its recording" % b.name)
	assert_true(names.has("Bed_hearth_3_3"), "the fire is heard from its square: %s" % [names])
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("Bed_river_8_")), "the river from its bank: %s" % [names])
	await get_tree().process_frame
	var ear := ws.get_child(0) as AudioListener3D
	var lead := view.tokens[view.leader().id] as Node3D
	assert_true(ear.global_position.distance_to(lead.global_position) < 2.0, "the listener stands at the leader")


## The leader's footsteps play on its figure's footfalls (owner 2026-10-12: two a square had been about four times the
## pace of the legs): at the party's pace a stride is about two squares, so five squares are a few steps, not ten.
func test_footsteps_keep_the_pace_of_the_legs() -> void:
	var view := root.get("view") as LocationView
	var ws := view.get_node("WorldSounds") as WorldSounds
	var tok := view.tokens[view.leader().id] as CombatToken
	await get_tree().process_frame
	assert_true(tok.sprite.footfall.is_connected(ws._on_footfall), "the footsteps follow the leader's feet")
	var falls: Array[int] = [0]
	tok.sprite.footfall.connect(func() -> void: falls[0] += 1)
	assert_eq(view.leader().cell, Vector2i(2, 2), "starts at the spawn")
	assert_true(view.walk_to(Vector2i(7, 2)), "walks five squares along the bank")
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until and not (view._queue.is_empty() and view._glides.is_empty() and not tok.sprite.finish_stride):
		await get_tree().process_frame
	assert_eq(view.leader().cell, Vector2i(7, 2), "arrived")
	assert_between(falls[0], 2, 5, "a footfall about every two squares: %d" % falls[0])
