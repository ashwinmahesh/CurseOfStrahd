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
