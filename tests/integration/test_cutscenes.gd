extends TestCase
## Story cutscenes (Improvement Ideas G4; docs/ui/cutscenes.md, story/cutscenes.gd, ui/cutscene/): a picture takes the
## first of its takes whose condition holds or is skipped; in a conversation `cutscene <id>` puts it under the lines,
## which read as captions, the box comes back for options, Skip runs the captions on to the next choice, Esc pauses and
## `cutscene end` takes it away; looking at a place's trigger shows its picture with the narrator's words, closes on a
## click and keeps the world still meanwhile; a `once` one comes back no more. An ending's narration shows its picture
## behind the words. The rider on the ridge plays on the first journey out, with Ireena in it when she's along. A
## Tarokka treasure shows its picture once, in a conversation or before the loot window; a fight's narrator key can
## have one too (Strahd fleeing to his coffin as mist).

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

~ treasure
tarokka give argynvostholt_vladimir
Narrator: It is heavier than it looks.
-> END

~ ending
Narrator: The castle is quiet.
cutscene test_view
Narrator: The sun comes up.
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
	Cutscenes.register({"id": "test_once", "title": "Test once", "summary": "A fixture.",
		"images": [{"image": "strahd_watcher", "when": ""}], "trigger": "enter:test_ledge", "once": true})
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/cut"))
	Compendium.shared().tables["locations"]["test_crag"] = LOC.duplicate(true)


func after_each() -> void:
	get_tree().paused = false
	CutsceneView.headless_too = false   # even when a test stopped early
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
	assert_eq(Cutscenes.image("test_ridge", _story(true)), "res://art/cutscenes/strahd_watcher.jpg")
	assert_eq(Cutscenes.image("test_ridge", _story(false)), "", "the picture shows Ireena, so it waits for her")
	assert_eq(Cutscenes.image("no_such_cutscene", _story(true)), "")
	assert_eq(Cutscenes.focus("test_ridge"), Vector2(0.5, 0.3))
	assert_eq(Cutscenes.focus("test_view"), Vector2(0.5, 0.5), "the centre by default")
	assert_eq(Cutscenes.for_trigger("examine:test_lookout", _story(false)), "test_view")
	assert_eq(Cutscenes.for_trigger("examine:something_else", _story(false)), "")
	var st := _story(false)
	assert_eq(Cutscenes.for_trigger("enter:test_ledge", st), "test_once")
	Cutscenes.mark_played("test_once", st)
	assert_eq(Cutscenes.for_trigger("enter:test_ledge", st), "", "a `once` cutscene plays once")
	assert_eq(Cutscenes.for_trigger("examine:test_lookout", st), "test_view", "the others every time")


func test_the_runner_gives_the_picture_then_the_lines_and_takes_it_away() -> void:
	var r := DialogueRunner.new(_story(true), DiceRoller.new(3))
	assert_true(r.start("test/cut:start"))
	assert_eq(str(r.next()["text"]), "Before the picture.")
	var cut := r.next()
	assert_eq(str(cut["kind"]), "cutscene")
	assert_eq(str(cut["image"]), "res://art/cutscenes/strahd_watcher.jpg")
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


func test_the_rider_on_the_ridge_shows_on_the_first_journey_with_or_without_ireena() -> void:
	for with_ireena: bool in [true, false]:
		var r := DialogueRunner.new(_story(with_ireena), DiceRoller.new(3))
		assert_true(r.start("strahd/visits:watcher"))
		var kinds: Array[String] = []
		var shown := false
		for i in 6:
			var b := r.next()
			kinds.append(str(b["kind"]))
			if str(b["kind"]) == "cutscene":
				assert_eq(str(b["image"]), "res://art/cutscenes/%s.jpg" % ("strahd_watcher" if with_ireena else "strahd_watcher_alone"))
				assert_eq(str(r.next()["text"]).get_slice(".", 0), "The road bends under a bare ridge", "the narrator's line is its caption")
				shown = true
				break
		assert_true(shown, "a cutscene in the watcher: %s" % [kinds])


## Owner report (2026-10-08): the castle on its cliff played as soon as the party walked toward the village's west side.
## It belongs to the first try at leaving by the west road: the posts' conversation, once, and walking in shows none.
func test_the_road_west_castle_waits_for_the_first_try_at_leaving() -> void:
	Cutscenes.clear_cache()
	assert_eq(str(Cutscenes.get_cutscene("castle_road_west").get("trigger", "")), "", "no picture on walking into the west road")
	assert_eq(Cutscenes.for_trigger("enter:village_road_west", _story(false)), "", "nor any other picture")
	var st := _story(false)
	var seen: Array[String] = []
	for attempt in 2:
		var r := DialogueRunner.new(st, DiceRoller.new(3))
		assert_true(r.start("village_of_barovia/road_west:start"))
		for i in 4:
			var b := r.next()
			if str(b["kind"]) == "cutscene":
				seen.append("%d:%s" % [attempt, b["id"]])
			if str(b["kind"]) == "options":
				break
	assert_eq(seen, ["0:castle_road_west"] as Array[String], "the castle shows at the posts the first time only")


## Storyline QA (SL-10): talking to Doru again replayed the ceiling picture and the whole first meeting.
func test_doru_meets_you_once_then_picks_up_where_you_left_him() -> void:
	var st := _story(false)
	var first: Array[String] = []
	var again: Array[String] = []
	for pass_i in 2:
		var r := DialogueRunner.new(st, DiceRoller.new(3))
		assert_true(r.start("village_of_barovia/doru:start"))
		for i in 6:
			var b := r.next()
			var said := "%s:%s" % [b["kind"], b.get("id", str(b.get("text", "")).get_slice(".", 0))]
			(first if pass_i == 0 else again).append(said)
			if str(b["kind"]) == "options":
				break
	assert_true("cutscene:doru_ceiling" in first, "the first meeting has its picture: %s" % [first])
	assert_false(again.any(func(x: String) -> bool: return x.begins_with("cutscene")), "no picture the second time: %s" % [again])
	assert_false(again.any(func(x: String) -> bool: return x.contains("Something crosses the ceiling")), "nor the first meeting's words")
	assert_true(again.any(func(x: String) -> bool: return x.contains("Doru still clings")), "he's where you left him: %s" % [again])


## Storyline QA (SL-11): Ireena's window picture shows Ismark asleep by the door, so that take shows only where he is: the
## inn, with him guarding her. In Krezk, or at the inn without him, the room behind her is empty (Ashwin's yes,
## 2026-10-09: a take without him).
func test_ireenas_window_shows_ismark_only_when_he_is_there() -> void:
	var st := _story(false)
	assert_eq(Cutscenes.image("ireena_window", st), "res://art/cutscenes/ireena_window_alone.jpg", "at the inn without Ismark: an empty room")
	st.set_flag("ismark_guards_ireena", true)
	assert_eq(Cutscenes.image("ireena_window", st), "res://art/cutscenes/ireena_window.jpg", "with him guarding her")
	st.set_flag("ireena_in_krezk", true)
	assert_eq(Cutscenes.image("ireena_window", st), "res://art/cutscenes/ireena_window_alone.jpg", "in Krezk the room doesn't match his picture")


## UI QA (ART-07, SND-03): no still carries a black band along an edge (vosk_unmasked had one across its top), and the
## pause card holds the Narrator's voice with the picture.
func test_stills_have_no_black_bands_and_pausing_holds_the_voice() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/cutscenes/vosk_unmasked.jpg"))
	var top := 0.0
	for x in range(0, img.get_width(), 16):
		top = maxf(top, img.get_pixel(x, 2).get_luminance())
	assert_true(top > 0.05, "Vosk's still starts with the picture, not a black band")
	var view := CutsceneView.new()
	add_child(view)
	view.set_paused(true)
	assert_true(VoiceOver.is_paused(), "the pause card holds the voice")
	view.set_paused(false)
	assert_false(VoiceOver.is_paused(), "and Resume lets it go on")
	view.queue_free()


## Functional QA (FN-20): a still not in memory is read on a worker thread, so opening a cutscene never waits on the
## disk; the caption shows at once and the picture arrives a few frames later. (Headless runs read it on the main
## thread unless CutsceneView.headless_too: nothing else here makes a texture while it's read.)
func test_a_still_loads_off_the_main_thread() -> void:
	CutsceneView.headless_too = true
	var path := "res://art/cutscenes/castle_glimpse.jpg"
	var view := CutsceneView.new()
	add_child(view)
	view.show_image(path)
	if view.loading():   # (another test may have left it in memory; then it shows at once, which is fine too)
		assert_true(view.art.texture == null, "nothing waits for the disk on the opening frame")
		for i in 300:
			if not view.loading():
				break
			await get_tree().process_frame
	assert_false(view.loading(), "the still arrives")
	assert_true(view.art.texture != null, "and shows")
	assert_eq(view.image_path, path)
	var held := view.art.texture
	view.show_image("res://art/cutscenes/strahd_watcher.jpg")
	view.show_image(path)   # a still superseded mid-read never replaces the one asked for last
	for i in 300:
		if not view.loading():
			break
		await get_tree().process_frame
	assert_true(view.art.texture == held, "the last still asked for is the one shown")
	view.queue_free()
	CutsceneView.headless_too = false


## Headless (tests, the story bot, tools) a still is read on the main thread, never on a worker beside textures the
## main thread is making: the stand-in renderer's texture store lost one that way ('Parameter "t" is null' in
## texture_2d_initialize, test_npc_routes, 2026-10-09).
func test_headless_reads_a_still_on_the_main_thread() -> void:
	assert_false(CutsceneView.headless_too, "off unless a test asks")
	var path := ""
	for f in DirAccess.get_files_at("res://art/cutscenes"):
		var p := "res://art/cutscenes/" + f.trim_suffix(".import").trim_suffix(".remap")
		if p.ends_with(".jpg") and not ResourceLoader.has_cached(p):
			path = p
			break
	assert_ne(path, "", "a still nobody has read yet")
	var view := CutsceneView.new()
	add_child(view)
	view.show_image(path)
	assert_false(view.loading(), "nothing left reading on a worker")
	assert_true(view.art.texture != null, "the still shows at once")
	assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "never asked of a worker")
	view.queue_free()


func test_every_cutscene_statement_names_a_cutscene_with_a_picture() -> void:
	Cutscenes.clear_cache()
	var named := {}
	var dir := "res://narrative/"
	var stack: Array[String] = [dir]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".dialogue"):
				for line in FileAccess.get_file_as_string(d.path_join(f)).split("\n"):
					if line.strip_edges().begins_with("cutscene "):
						named[line.strip_edges().substr(9)] = d.path_join(f)
	assert_true(named.size() > 40, "the story's cutscenes are placed (%d)" % named.size())
	for id: String in named:
		if id != "end":
			assert_true(not Cutscenes.get_cutscene(id).is_empty(), "%s names cutscene %s" % [named[id], id])


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
	assert_true(view != null and view.image_path == "res://art/cutscenes/strahd_watcher.jpg", "the picture is up")
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
	assert_true(get_tree().paused, "the game waits under it")
	assert_eq(player.view.caption_text(), "The whole valley lies open below.")
	assert_eq(player.view.image_path, "res://art/cutscenes/strahd_watcher.jpg")
	player._unhandled_input(_esc())
	assert_true(player.view.paused, "Esc pauses")
	player.advance()
	assert_true(not player.done, "not while paused")
	player._unhandled_input(_esc())
	player.advance()
	assert_true(player.done, "a click after the last caption closes it")
	await _frames(2)
	assert_true(root.get("screen") == null, "and the world is back")
	assert_true(not get_tree().paused, "unpaused")


func test_an_ending_shows_its_picture_behind_the_narration() -> void:
	await _game(false)
	var screen := EndingScreen.new()
	screen.save_on_finish = false
	screen.to_title = false
	root.add_child(screen)
	screen.play(GameState.story, {"id": "test_end", "title": "Test", "summary": "A fixture.", "priority": 0, "when": "",
		"narration": "test/cut:ending", "epilogue": []})
	await _frames(1)
	var art := screen.get("_art") as TextureRect
	var castle := art.texture
	screen.advance()
	assert_eq(screen.lines_shown[-1], "The castle is quiet.")
	assert_true(art.texture == castle, "the castle until the statement")
	screen.advance()
	assert_eq(screen.lines_shown[-1], "The sun comes up.", "the statement doesn't end the narration")
	assert_eq(art.texture.resource_path, "res://art/cutscenes/strahd_watcher.jpg", "the picture behind the words")
	screen.queue_free()


func test_a_treasure_shows_its_picture_once_in_a_conversation() -> void:
	var st := _story(false)
	st.tarokka = {"tome": "swords_1"}   # the Tome waits with Vladimir (data/tarokka/outcomes.json)
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start("test/cut:treasure"))
	var cut := r.next()
	assert_eq(str(cut["kind"]), "cutscene", "the picture comes first")
	assert_eq(str(cut["id"]), "treasure_tome")
	assert_true(str(r.next()["text"]).contains("Tome of Strahd"), "then the notice, over it")
	assert_true(Cutscenes.played("treasure_tome", st), "and it won't show again")
	assert_eq(Cutscenes.for_trigger("find:tome_of_strahd", st), "")


func test_a_treasure_in_the_spoils_shows_its_picture_before_the_loot_window() -> void:
	await _game(false)
	root.call("_open_loot", "test_chest", [{"id": "sunsword", "qty": 1}], 0.0)
	await _frames(2)
	var player := root.get("screen") as CutscenePlayer
	assert_true(player != null and player.id == "treasure_sword", "the Sunsword's picture")
	assert_true(root.get("loot") == null, "the loot window waits for it")
	assert_true(player.view.caption_text().begins_with("The Sunsword"), player.view.caption_text())
	player.advance()
	await _frames(3)
	assert_true(root.get("loot") != null, "then the loot window opens")
	(root.get("loot") as Node).queue_free()
	root.set("loot", null)
	root.call("_open_loot", "test_chest", [{"id": "sunsword", "qty": 1}], 0.0)
	await _frames(2)
	assert_true(not root.get("screen") is CutscenePlayer, "only the first time")


func test_strahd_fleeing_as_mist_has_its_picture() -> void:
	var st := _story(false)
	assert_eq(Cutscenes.for_trigger("strahd:fled_to_coffin", st), "strahd_mist_flight")
	Cutscenes.clear_cache()
	assert_eq(Cutscenes.for_trigger("strahd:fled_to_coffin", st), "strahd_mist_flight", "from the data")


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
