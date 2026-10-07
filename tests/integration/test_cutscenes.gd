extends TestCase
## Story cutscenes (Improvement Ideas G4; docs/ui/cutscenes.md, story/cutscenes.gd, ui/cutscene/): a picture takes the
## first of its takes whose condition holds or is skipped; in a conversation `cutscene <id>` puts it under the lines,
## which read as captions, the box comes back for options, Skip runs the captions on to the next choice, Esc pauses and
## `cutscene end` takes it away; looking at a place's trigger shows its picture with the narrator's words, closes on a
## click and keeps the world still meanwhile. The rider on the ridge plays on the first journey out with Ireena.

const LOC := {
	"id": "test_crag", "name": "Test Crag", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#######",
		"#.....#",
		"#.....#",
		"#######"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"props": [{"id": "test_lookout", "cell": [1, 1], "kind": "examine", "label": "The view", "model": "rocks"}],
}

const DIALOGUE := """
~ start
Narrator: Before the picture.
cutscene test_ridge
Narrator: The rider waits on the ridge.
Ireena: Don't look at him.
Narrator: He doesn't move.
* Wave. -> wave
* Walk on. -> gone

~ wave
Narrator: He lifts a hand.
-> gone

~ gone
cutscene end
Narrator: The ridge is bare.
-> END
"""

## A picture the game already has, so the tests need no art of their own.
const TAKE := {"image": "strahd_watcher", "when": "guest:ireena"}

var root: Node


func before_each() -> void:
	Cutscenes.register({"id": "test_ridge", "title": "Test", "summary": "A fixture.", "images": [TAKE],
		"focus": [0.5, 0.3]})
	Cutscenes.register({"id": "test_view", "title": "Test view", "summary": "A fixture.",
		"images": [{"image": "strahd_watcher", "when": ""}], "trigger": "examine:test_lookout"})
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/cut"))
	Compendium.shared().tables["locations"]["test_crag"] = LOC.duplicate(true)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await _frames(1)
	Cutscenes.clear_cache()
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_crag")
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _story(with_ireena: bool) -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.pregen("ilse_varga", 3)
	ch.finish_long_rest()
	st.party.append(ch)
	if with_ireena:
		st.add_guest("ireena")
	return st


func _game(with_ireena: bool) -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	if with_ireena:
		GameState.story.add_guest("ireena")
	GameState.story.location = "test_crag"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func _esc() -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_ESCAPE
	k.keycode = KEY_ESCAPE
	k.pressed = true
	return k


# --- Data -----------------------------------------------------------------------------------------

func test_every_cutscene_has_a_picture_the_game_can_load() -> void:
	Cutscenes.clear_cache()
	var all := Cutscenes.all()
	assert_true(not all.is_empty(), "the data has cutscenes")
	for c in all:
		for take: Variant in c["images"]:
			var path := Cutscenes.ART % str((take as Dictionary)["image"])
			assert_true(ResourceLoader.exists(path) and load(path) is Texture2D, "%s: %s loads" % [c["id"], path])


func test_the_first_take_that_holds_is_shown_and_none_skips_it() -> void:
	assert_eq(Cutscenes.image("test_ridge", _story(true)), "res://art/cutscenes/strahd_watcher.png")
	assert_eq(Cutscenes.image("test_ridge", _story(false)), "", "the picture shows Ireena, so it waits for her")
	assert_eq(Cutscenes.image("no_such_cutscene", _story(true)), "")
	assert_eq(Cutscenes.focus("test_ridge"), Vector2(0.5, 0.3))
	assert_eq(Cutscenes.focus("test_view"), Vector2(0.5, 0.5), "the centre by default")
	assert_eq(Cutscenes.for_trigger("examine:test_lookout", _story(false)), "test_view")
	assert_eq(Cutscenes.for_trigger("examine:something_else", _story(false)), "")


func test_the_runner_gives_the_picture_then_the_lines_and_takes_it_away() -> void:
	var r := DialogueRunner.new(_story(true), DiceRoller.new(3))
	assert_true(r.start("test/cut:start"))
	assert_eq(str(r.next()["text"]), "Before the picture.")
	var cut := r.next()
	assert_eq(str(cut["kind"]), "cutscene")
	assert_eq(str(cut["image"]), "res://art/cutscenes/strahd_watcher.png")
	assert_eq(str(r.next()["text"]), "The rider waits on the ridge.")
	# Without Ireena the statement is passed over and the scene plays as before.
	var alone := DialogueRunner.new(_story(false), DiceRoller.new(3))
	alone.start("test/cut:start")
	alone.next()
	assert_eq(str(alone.next()["text"]), "The rider waits on the ridge.", "no picture beat")
	var gone := DialogueRunner.new(_story(true), DiceRoller.new(3))
	gone.start("test/cut:gone")
	var end := gone.next()
	assert_eq(str(end["kind"]), "cutscene")
	assert_eq(str(end["image"]), "", "`cutscene end` takes it away")


func test_the_rider_on_the_ridge_shows_on_the_first_journey_with_ireena() -> void:
	var st := _story(true)
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start("strahd/visits:watcher"))
	var kinds: Array[String] = []
	for i in 6:
		var b := r.next()
		kinds.append(str(b["kind"]))
		if str(b["kind"]) == "cutscene":
			assert_eq(str(b["image"]), "res://art/cutscenes/strahd_watcher.png")
			assert_eq(str(r.next()["text"]).get_slice(".", 0), "The road bends under a bare ridge", "the narrator's line is its caption")
			return
	fail("no cutscene in the watcher: %s" % [kinds])


# --- In a conversation ----------------------------------------------------------------------------

func test_a_conversation_reads_its_lines_over_the_picture_and_brings_the_box_back_for_options() -> void:
	await _game(true)
	root.call("start_dialogue", "test/cut:start", "")
	await _frames(2)
	var d := root.get("dialogue") as DialogueUI
	assert_true(d != null, "the conversation opens")
	assert_true(d.cutscene == null, "no picture before the statement")
	d.call("_advance")
	await _frames(1)
	var view := d.cutscene
	assert_true(view != null and view.image_path == "res://art/cutscenes/strahd_watcher.png", "the picture is up")
	assert_true(view.captioning, "a caption")
	assert_eq(view.caption_text(), "The rider waits on the ridge.")
	var panel := d.get("_panel") as Control
	assert_true(not panel.visible, "the box makes way for the caption")
	d.call("_advance")
	await _frames(1)
	assert_eq(view.caption_text(), "Don't look at him.", "a speaker's line")
	assert_true((view.get("_name") as Label).text.begins_with("Ireena"), "with their name above it")
	# Esc pauses: nothing moves on until Resume (or Esc again).
	d.call("_unhandled_input", _esc())
	assert_true(view.paused, "Esc pauses")
	view.clicked.emit()
	await _frames(1)
	assert_true(view.paused and view.caption_text() == "Don't look at him.", "a click while paused does nothing")
	d.call("_unhandled_input", _esc())
	assert_true(not view.paused, "Esc again resumes")
	# Skip: the rest of the captions go by up to the choice, which comes up in the box over the picture.
	view.skip_requested.emit()
	await _frames(1)
	assert_eq(d.options_shown.size(), 2, "at the choice")
	assert_true(panel.visible and not view.captioning, "the box is back over the picture")
	assert_true(d.cutscene == view, "the picture stays under the choice")
	var history := "\n".join(d.get("_history") as Array)
	assert_true(history.contains("He doesn't move."), "skipped lines stay in the History")
	d.call("_choose", 1)
	await _frames(2)
	assert_true(d.cutscene == null, "`cutscene end` takes the picture away")
	assert_true(panel.visible, "and the box carries on")


func test_without_its_condition_the_conversation_plays_as_before() -> void:
	await _game(false)
	root.call("start_dialogue", "test/cut:start", "")
	await _frames(2)
	var d := root.get("dialogue") as DialogueUI
	d.call("_advance")
	await _frames(1)
	assert_true(d.cutscene == null, "no picture without Ireena")
	assert_true((d.get("_panel") as Control).visible)


# --- Places ---------------------------------------------------------------------------------------

func test_looking_at_a_places_trigger_shows_its_picture_with_the_narrators_words() -> void:
	await _game(false)
	var narrator := root.get("narrator") as Narrator
	narrator.add_file(DialogueFile.parse("~ examine:test_lookout\n| The whole valley lies open below.", "test/narr"))
	var v := root.get("view") as LocationView
	v.interact(v.thing_at(Vector2i(1, 1)))
	await _frames(2)
	var player := root.get("screen") as CutscenePlayer
	assert_true(player != null, "the cutscene opens in place of a screen, so the world waits")
	assert_eq(player.view.caption_text(), "The whole valley lies open below.")
	assert_eq(player.view.image_path, "res://art/cutscenes/strahd_watcher.png")
	player._unhandled_input(_esc())
	assert_true(player.view.paused, "Esc pauses")
	player.advance()
	assert_true(not player.done, "not while paused")
	player._unhandled_input(_esc())
	player.advance()
	assert_true(player.done, "a click after the last caption closes it")
	await _frames(2)
	assert_true(root.get("screen") == null, "and the world is back")


func test_skip_closes_a_places_cutscene() -> void:
	await _game(false)
	var player := CutscenePlayer.new()
	root.add_child(player)
	assert_true(player.play("test_view", ["One.", "Two."] as Array[String], GameState.story))
	assert_eq(player.view.caption_text(), "One.")
	player.advance()
	assert_eq(player.view.caption_text(), "Two.")
	var closed := [false]
	player.finished.connect(func() -> void: closed[0] = true)
	player.view.skip_requested.emit()
	assert_true(closed[0] and player.done, "Skip closes it")
	var none := CutscenePlayer.new()
	root.add_child(none)
	assert_true(not none.play("test_ridge", ["x"] as Array[String], GameState.story), "no take holds: nothing to play")
	none.queue_free()
