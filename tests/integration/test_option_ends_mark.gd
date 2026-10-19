extends TestCase
## An option that closes a quest wears a broken seal and says which (Side Quest Failure Plan F4, docs/contracts/dialogue.md):
## the seal at its edge, "Ends <quest>" in its tooltip and, while it has the focus, in a line under the menu. Ordinary
## options carry none of it, and the line goes with the menu.

const DIALOGUE := """
~ start
Ranka: The basket is yours, if you want it.
* [ends:the_fourth_sister] (Take the basket and let her go.) -> END
* Ask about the wood. -> END
"""

var root: Node


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/ends_mark"))
	GameState.reset()
	GameState.story.party.append(Pregens.build("godrick_pendlebrook", 3))
	root = Node.new()
	add_child(root)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await get_tree().process_frame
	GameState.reset()


func _talk() -> DialogueUI:
	var d := DialogueUI.new()
	root.add_child(d)
	await get_tree().process_frame
	assert_true(d.play(DialogueRunner.new(GameState.story, DiceRoller.new(7)), "test/ends_mark:start"))
	d.call("_advance")   # past Ranka's line to the options
	await get_tree().process_frame
	return d


func _buttons(d: DialogueUI) -> Array[Button]:
	var out: Array[Button] = []
	for c in (d.get("_options") as VBoxContainer).get_children():
		out.append(c as Button)
	return out


func test_the_closing_option_wears_the_seal() -> void:
	var d := await _talk()
	var buttons := _buttons(d)
	assert_eq(buttons.size(), 2)
	assert_true(buttons[0].find_child("EndsMark", false, false) != null, "the seal sits on the option that closes the quest")
	assert_eq(buttons[0].tooltip_text, "Ends The Fourth Sister")
	assert_true(buttons[1].find_child("EndsMark", false, false) == null, "the other option has none")
	assert_eq(buttons[1].tooltip_text, "")


func test_the_line_under_the_menu_follows_the_focus() -> void:
	var d := await _talk()
	var note := d.find_child("EndsNote", true, false) as Label
	assert_true(note != null)
	var buttons := _buttons(d)
	buttons[0].grab_focus()
	await get_tree().process_frame
	assert_true(note.visible, "the focused option closes a quest")
	assert_eq(note.text, "Ends The Fourth Sister")
	buttons[1].grab_focus()
	await get_tree().process_frame
	assert_false(note.visible, "the focus moved to an ordinary one")
	buttons[0].grab_focus()
	await get_tree().process_frame
	assert_true(note.visible)
	d.call("_clear_options")
	assert_false(note.visible, "it goes with the menu")


func test_a_finished_quest_leaves_the_option_unmarked() -> void:
	GameState.story.set_quest_stage("the_fourth_sister", "given")
	var d := await _talk()
	assert_true(_buttons(d)[0].find_child("EndsMark", false, false) == null, "nothing left to close")
