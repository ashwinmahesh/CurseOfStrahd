extends TestCase
## Busts face each other (owner, 2026-10-08): the left bust faces right and the right bust faces left, each mirrored
## when it was drawn the other way (data/busts/facing.json), unless a line's `[away]` cue turns one away. A Narrator line's
## turn holds until that side speaks again; someone new on a side faces the other side.

const DIALOGUE := """
~ start
Ireena: Who's there?
Narrator [away]: She turns to the window.
Narrator: The rain goes on.
Ireena [sad, away]: I can't look at you and say it.
Ireena: There. I've said it.
Player: We heard.
Narrator [away:party]: You turn your back on her.
Ireena: Don't.
-> END
"""

var root: Node


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/facing"))


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await get_tree().process_frame
	GameState.reset()


func test_every_bust_says_which_way_it_was_drawn() -> void:
	var data := JSON.parse_string(FileAccess.get_file_as_string(DialogueBusts.FACING_FILE)) as Dictionary
	var facing := data["facing"] as Dictionary
	for f in DirAccess.get_files_at(DialogueBusts.DIR):
		if not f.ends_with(".webp"):
			continue
		var side := DialogueBusts.native_facing(f)
		assert_true(side in ["left", "right"], f)
		var stem := f.get_basename()
		var person := stem
		for mood in DialogueBusts.MOODS:
			if stem.ends_with("_" + mood) and facing.has(stem.trim_suffix("_" + mood)):
				person = stem.trim_suffix("_" + mood)
		assert_true(facing.has(stem) or facing.has(person), "%s has its facing in %s" % [f, DialogueBusts.FACING_FILE])
	for id: String in facing:
		assert_true(str(facing[id]) in ["left", "right"], "%s: left or right" % id)


func test_each_side_faces_the_other() -> void:
	# Ireena was drawn facing right, so on the right she is mirrored; Thistle was drawn facing left, so on the left she is
	# mirrored; Godrick faces right as drawn and Argynvost left, so neither is.
	assert_eq(DialogueBusts.native_facing("res://art/busts/ireena.webp"), "right")
	assert_eq(DialogueBusts.native_facing("res://art/busts/ireena_sad.webp"), "right", "a mood faces as its person")
	assert_true(DialogueBusts.mirrored("res://art/busts/ireena.webp", false, false))
	assert_true(DialogueBusts.mirrored("res://art/busts/thistle.webp", true, false))
	assert_false(DialogueBusts.mirrored("res://art/busts/godrick_pendlebrook.webp", true, false))
	assert_false(DialogueBusts.mirrored("res://art/busts/argynvost.webp", false, false))
	assert_false(DialogueBusts.mirrored("res://art/busts/ireena.webp", false, true), "turned away she faces right, as drawn")
	assert_false(DialogueBusts.mirrored("", true, false), "no bust, nothing to mirror")


func test_the_away_cue_reads_beside_a_mood() -> void:
	var f := DialogueFile.parse("~ a\nIreena [sad, away]: x\nNarrator [away:party]: y\nIreena [angry]: z\nNarrator: w\n", "test/cue")
	assert_true(f.errors.is_empty(), str(f.errors))
	var lines := f.nodes["a"] as Array
	assert_eq([str(lines[0]["mood"]), str(lines[0]["away"])], ["sad", "speaker"])
	assert_eq([str(lines[1]["mood"]), str(lines[1]["away"])], ["", "party"])
	assert_eq([str(lines[2]["mood"]), str(lines[2]["away"])], ["angry", ""])
	assert_eq(str(lines[3]["away"]), "")


func test_a_conversation_turns_and_turns_back() -> void:
	GameState.reset()
	var ch := Pregens.build("thistle", 3)
	ch.finish_long_rest()
	GameState.story.party.append(ch)
	root = Node.new()
	add_child(root)
	var d := DialogueUI.new()
	root.add_child(d)
	await get_tree().process_frame
	assert_true(d.play(DialogueRunner.new(GameState.story, DiceRoller.new(2)), "test/facing:start"))
	await get_tree().process_frame
	var b := d.busts
	assert_true(b.right.flip_h, "Ireena faces left, towards Thistle")
	assert_true(b.left.flip_h, "Thistle faces right, towards Ireena")
	d.call("_advance")
	assert_true(b.right_away and not b.right.flip_h, "the Narrator turns her to the window")
	d.call("_advance")
	assert_true(b.right_away, "and she stays turned through the Narrator's next line")
	d.call("_advance")
	assert_eq(b.right_id, "res://art/busts/ireena_sad.webp")
	assert_true(b.right_away and not b.right.flip_h, "her own line can keep her turned away")
	d.call("_advance")
	assert_false(b.right_away, "a line with no cue turns her back")
	assert_true(b.right.flip_h)
	d.call("_advance")
	assert_true(b.left.flip_h and not b.left_away, "the party answers, facing her")
	d.call("_advance")
	assert_true(b.left_away and not b.left.flip_h, "away:party turns the party's speaker")
	assert_true(b.right.flip_h, "she still faces them")
	d.call("_advance")
	assert_true(b.left_away, "the party's turn holds while she speaks")
