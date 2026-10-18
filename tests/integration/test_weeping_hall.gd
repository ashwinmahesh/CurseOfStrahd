extends TestCase
## Patrina's weeping in the Amber Temple's hall of echoes: a bed that follows her, rises as the party hears her, and
## goes quiet once she is laid to rest.

var root: Node


func before_each() -> void:
	GameState.reset()
	var ch := Pregens.build("hedda_ironvow", 3)
	ch.finish_long_rest()
	GameState.story.party.append(ch)
	GameState.story.location = "amber_temple_faceless_god"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await get_tree().process_frame


func test_the_weeping_follows_patrina_and_stills_when_she_rests() -> void:
	var view := root.get("view") as LocationView
	var ws := view.get_node("WorldSounds") as WorldSounds
	assert_true(ws.npc_beds.has("patrina_velikovna"), "the hall gives Patrina a bed")
	var bed := ws.npc_beds["patrina_velikovna"] as AudioStreamPlayer3D
	assert_true(bed.stream != null, "with its recording")
	assert_true(ws.beds.has(bed), "among the place's beds")
	ws._tend_npc_beds(WorldSounds.FADE_IN * 2.0)
	var tok := view.npc_tokens["patrina_velikovna"] as Node3D
	assert_true(bed.global_position.distance_to(tok.global_position) < 1.5, "the weeping comes from where she stands")
	assert_between(bed.volume_db, Audio.level_db("weeping") - 0.01, Audio.level_db("weeping") + 0.01, "fully risen, it is the quiet level")
	GameState.story.set_flag("patrina_fate", "rest")
	view.refresh_npcs()
	assert_false(view.npc_tokens.has("patrina_velikovna"), "laid to rest, she is gone from the hall")
	ws._tend_npc_beds(WorldSounds.FADE_OUT * 2.0)
	assert_eq(bed.volume_db, WorldSounds.SILENT_DB, "and her weeping with her")
	assert_false(bed.playing, "stopped")
