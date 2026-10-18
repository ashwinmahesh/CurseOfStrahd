extends TestCase
## The castle's music turns to dread while the party talks to Strahd, Rahadin or another of the few who frighten it
## (art/audio.json talk_moods, GameRoot._talk_music), and the castle's own comes back when the conversation ends. A
## servant leaves it alone, and a line by one of the few turns it even when the conversation began with someone else.
## A cutscene whose scene has its own music (art/audio.json "scenes", the owner's music audit of 2026-10-17) turns it
## from its picture to the end, anywhere, and holds over whoever speaks after.

const LOC := {
	"id": "test_dread", "name": "Test Dread", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#######",
		"#.....#",
		"#.....#",
		"#######"], "light": "dim"},
	"spawns": {"default": [2, 2]},
}

const DIALOGUE := """
~ rahadin
Rahadin: You are still here. Good.
Narrator: He folds his hands.
-> END

~ helga
Helga Ruvak: Will you be staying the night?
-> END

~ meeting
Narrator: A small man in black waits in the hall.
Rahadin: You are the master's guests.
-> END

~ scene
Narrator: The candles gutter.
cutscene test_scene_music
Narrator: Something changes.
Rahadin: The master will hear of this.
-> END

~ opens
cutscene test_scene_music
Rahadin: You are still here.
-> END
"""

var root: Node
var _places: Dictionary
var _scenes: Dictionary


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_dread"] = LOC.duplicate(true)
	_places = (Audio._data["places"] as Dictionary).duplicate()
	(Audio._data["places"] as Dictionary)["test_dread"] = "castle"
	_scenes = (Audio._data.get("scenes", {}) as Dictionary).duplicate()
	var scenes := _scenes.duplicate()
	scenes["test_scene_music"] = "sorrow"
	Audio._data["scenes"] = scenes
	Cutscenes.register({"id": "test_scene_music", "title": "Test", "images": [{"image": "chapel_dawn", "when": ""}]})
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/dread"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_dread"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	Audio._data["places"] = _places
	Audio._data["scenes"] = _scenes
	Cutscenes.clear_cache()
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_dread")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Reads the conversation to its end.
func _finish() -> void:
	for i in 12:
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			return
		d.call("_advance")
		await _frames(2)


func test_the_place_plays_the_castles_music() -> void:
	assert_eq(Audio.mood, "castle")
	assert_true(Audio.playing_track in Audio.files("music", "castle"), Audio.playing_track)


func test_talking_to_rahadin_plays_dread_and_the_castle_returns() -> void:
	root.call("start_dialogue", "test/dread:rahadin", "rahadin")
	await _frames(2)
	assert_eq(Audio.mood, "dread", "the music turns as the conversation opens")
	assert_true(Audio.playing_track in Audio.files("music", "dread"), Audio.playing_track)
	await _finish()
	assert_true(root.get("dialogue") == null, "the conversation is over")
	assert_eq(Audio.mood, "castle", "the castle's own music is back")
	assert_true(Audio.playing_track in Audio.files("music", "castle"), Audio.playing_track)


func test_a_servant_leaves_the_castles_music_alone() -> void:
	var before := Audio.playing_track
	root.call("start_dialogue", "test/dread:helga", "helga_ruvak")
	await _frames(2)
	assert_eq(Audio.mood, "castle")
	assert_eq(Audio.playing_track, before, "the same recording goes on")
	await _finish()
	assert_eq(Audio.mood, "castle")
	assert_eq(Audio.playing_track, before)


func test_his_line_turns_it_even_when_nobody_was_clicked() -> void:
	root.call("start_dialogue", "test/dread:meeting", "")
	await _frames(2)
	assert_eq(Audio.mood, "castle", "the Narrator speaks first")
	(root.get("dialogue") as DialogueUI).call("_advance")
	await _frames(2)
	assert_eq(Audio.mood, "dread", "and then Rahadin does")
	await _finish()
	assert_eq(Audio.mood, "castle")


func test_only_the_castle_turns() -> void:
	(Audio._data["places"] as Dictionary)["test_dread"] = "town"
	Audio.play_music("town")
	root.call("start_dialogue", "test/dread:rahadin", "rahadin")
	await _frames(2)
	assert_eq(Audio.mood, "town", "Rahadin in a town leaves its music alone")
	await _finish()
	assert_eq(Audio.mood, "town")


func test_a_scene_turns_the_music_and_holds_over_the_dread() -> void:
	root.call("start_dialogue", "test/dread:scene", "")
	await _frames(2)
	assert_eq(Audio.mood, "castle", "the Narrator speaks first")
	(root.get("dialogue") as DialogueUI).call("_advance")
	await _frames(2)
	assert_eq(Audio.mood, "sorrow", "the picture comes up with its scene's music")
	assert_true(Audio.playing_track in Audio.files("music", "sorrow"), Audio.playing_track)
	(root.get("dialogue") as DialogueUI).call("_advance")
	await _frames(2)
	assert_eq(Audio.mood, "sorrow", "Rahadin speaking doesn't turn it to the dread")
	await _finish()
	assert_true(root.get("dialogue") == null, "the conversation is over")
	assert_eq(Audio.mood, "castle", "the castle's own music is back")


func test_a_scene_that_opens_the_talk_wins_over_who_was_clicked() -> void:
	root.call("start_dialogue", "test/dread:opens", "rahadin")
	await _frames(2)
	assert_eq(Audio.mood, "sorrow", "the scene's music, not Rahadin's dread")
	await _finish()
	assert_eq(Audio.mood, "castle")


func test_a_scene_turns_a_town_too() -> void:
	(Audio._data["places"] as Dictionary)["test_dread"] = "town"
	Audio.play_music("town")
	root.call("start_dialogue", "test/dread:scene", "")
	await _frames(2)
	assert_eq(Audio.mood, "town")
	(root.get("dialogue") as DialogueUI).call("_advance")
	await _frames(2)
	assert_eq(Audio.mood, "sorrow", "a scene's music plays wherever the conversation is")
	await _finish()
	assert_eq(Audio.mood, "town", "and the town's own comes back")
