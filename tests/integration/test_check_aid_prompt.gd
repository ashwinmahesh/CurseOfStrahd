extends TestCase
## The question after a skill check failed outside a fight and a conversation (ui/common/check_aid_prompt.gd): what the roll came to,
## a line for each aid the roller could spend (CheckAids), and a way to let the failure stand. It answers by mouse, keys and pad,
## answers once, waits out the big d20 before it shows, and stops the keys reaching what is behind it.

var root: Node
var answers: Array[String] = []


func before_each() -> void:
	InputActions.ensure()   # Escape is the game's combat_cancel, as the game root sets it up
	GameState.reset()
	answers.clear()
	root = null


func after_each() -> void:
	if root != null:
		root.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _offer() -> Dictionary:
	var ch := Pregens.build("ilse_varga", 3)
	ch.heroic_inspiration = true
	var t := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 9, 2, 25)
	return {"who": ch, "skill": "Arcana", "dc": 25, "test": t, "options": CheckAids.options(ch, t)}


func _ask(o: Dictionary) -> CheckAidPrompt:
	if root != null:
		root.queue_free()
	root = Node.new()
	add_child(root)
	var p := CheckAidPrompt.ask(root, o, func(aid: String) -> void: answers.append(aid))
	await _frames(2)
	return p


func _key(p: CheckAidPrompt, code: Key) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	p._unhandled_input(k)


func test_the_prompt_says_what_the_roll_came_to_and_offers_the_aid() -> void:
	var p := await _ask(_offer())
	assert_eq(p.layer, CheckAidPrompt.LAYER)
	var words := " ".join(p.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text))
	assert_true("Ilse rolled 11 on Arcana against DC 25, and missed." in words, words)
	assert_true("Nothing has happened yet" in words, "it says the failure is waiting")
	assert_true("let it stand" in words, "the note under the frame says Escape lets it stand")
	assert_eq(p.choices.size(), 2, "Ilse is a fighter: Tactical Mind too")
	assert_eq(p.choices[0].text, "1. Heroic Inspiration: reroll the d20")
	assert_true(p.choices[1].text.begins_with("2. Tactical Mind: add 1d10"), p.choices[1].text)
	assert_eq(p.stand_button.text, "3. Let it stand")
	assert_true(p.choices[0].has_meta(&"pad_first"), "the pad lands on the first aid")
	p.choices[0].pressed.emit()
	assert_eq(answers, ["heroic_inspiration"])
	assert_false(p.open(), "answered once")
	p.stand_button.pressed.emit()
	assert_eq(answers.size(), 1, "and only once")


func test_letting_it_stand_answers_with_nothing() -> void:
	var p := await _ask(_offer())
	p.stand_button.pressed.emit()
	assert_eq(answers, [""])


func test_the_keys_pick_an_aid_or_let_it_stand() -> void:
	var p := await _ask(_offer())
	_key(p, KEY_3)
	assert_eq(answers, [""], "the number after the last aid is Let it stand")
	p = await _ask(_offer())
	_key(p, KEY_2)
	assert_eq(answers.back(), "tactical_mind", "2 picks the second aid")
	p = await _ask(_offer())
	_key(p, KEY_1)
	assert_eq(answers.back(), "heroic_inspiration")
	p = await _ask(_offer())
	_key(p, KEY_5)
	assert_eq(answers.size(), 3, "a number with nothing behind it does nothing")
	assert_true(p.open())
	var esc := InputEventAction.new()
	esc.action = &"combat_cancel"
	esc.pressed = true
	p._unhandled_input(esc)
	assert_eq(answers.back(), "", "Esc lets it stand")


func test_a_hidden_prompt_answers_nothing() -> void:
	var p := await _ask(_offer())
	# While the big d20 is still on its way down the prompt is hidden (CheckAidPrompt._process shows it once the die has gone).
	p.visible = false
	_key(p, KEY_1)
	assert_eq(answers, [], "a key does nothing while it is hidden")
	p.visible = true
	_key(p, KEY_1)
	assert_eq(answers, ["heroic_inspiration"])
