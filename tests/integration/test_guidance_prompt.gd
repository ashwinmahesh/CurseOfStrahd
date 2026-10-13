extends TestCase
## Guidance offered before a skill check outside a fight (ui/common/guidance_prompt.gd, story/guidance_offer.gd;
## Ashwin, 2026-10-13): a conversation's check option and its `check` lines stop on a `guidance` beat before the roll,
## the conversation screen puts the prompt over its box and rolls once it's answered; the prompt answers by mouse, keys
## and pad, says what a caster's other spell would end and sets the casters' rule for next time; a check on something in
## a place, forcing a lock and a search wait for it too while nothing else moves, and a caster on Automatic casts it
## without asking. With no screen to ask on, nothing is cast and the roll comes at once, as before.

const DIALOGUE := """
~ start
Ismark: Help my sister.
* [Persuasion DC 30] Talk him round. -> yes | no
* Leave. -> END

~ yes
Ismark: Yes.
-> END

~ no
Ismark: No.
check Perception DC 1 -> saw | missed

~ saw
Ismark: You see it.
-> END

~ missed
-> END
"""

const LOC := {
	"id": "test_guidance", "name": "Test Guidance", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#########",
		"#.......#",
		"#.......#",
		"####.####",
		"#.......#",
		"#########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"doors": [{"id": "stuck", "cell": [4, 3], "locked": true, "lock_dc": 1, "label": "the stuck door"}],
	"props": [
		{"id": "runes", "cell": [1, 1], "kind": "examine", "label": "Runes on the wall", "checks": [
			{"id": "read_runes", "skill": "arcana", "dc": 30, "label": "Read the runes", "success": {"text": "Never."}}]}],
}

var root: Node
var answers: Array = []


func before_each() -> void:
	InputActions.ensure()
	GuidanceOffer.headless_too = true
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/guidance"))
	GameState.reset()
	for id: String in ["ilse_varga", "hedda_ironvow", "liriel_dawnsong", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	answers.clear()


func after_each() -> void:
	GuidanceOffer.headless_too = false
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_guidance")
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _party(i: int) -> Character:
	return GameState.story.party[i]


## A conversation at its options, with no Persuasion spent yet.
func _runner() -> DialogueRunner:
	for k: Variant in GameState.story.flags.keys():
		if str(k).begins_with("_failed/"):
			GameState.story.flags.erase(k)
	var r := DialogueRunner.new(GameState.story, DiceRoller.new(5))
	r.offer_guidance = true
	assert_true(r.start("test/guidance:start"))
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	return r


func test_a_conversation_check_stops_for_guidance_before_the_roll() -> void:
	var r := _runner()
	var b := r.choose(0)
	assert_eq(str(b["kind"]), "guidance", "the offer comes before the roll")
	var offer := b["offer"] as Dictionary
	assert_eq(offer["skill"], &"persuasion")
	assert_eq(int(offer["dc"]), 30)
	assert_eq((offer["casters"] as Array).map(func(e: Dictionary) -> Creature: return e["caster"]), [_party(1), _party(2)])
	assert_false(GameState.story.flags.keys().any(func(k: Variant) -> bool: return str(k).begins_with("_failed/")),
		"nothing rolled yet, so nothing spent")
	var check := r.answer_guidance(0, "ask")
	assert_eq(str(check["kind"]), "check")
	assert_true("Guidance (Hedda)" in str(check["extra_label"]), "the d4 is on the roll: %s" % check["detail"])
	assert_false(bool(check["success"]), "DC 30")
	assert_true(GameState.story.flags.keys().any(func(k: Variant) -> bool: return str(k).begins_with("_failed/")),
		"a failed Persuasion stays spent")
	# The branch it took has a `check` line of its own, which asks too.
	var b2 := r.next()
	while str(b2["kind"]) == "line":
		b2 = r.next()
	assert_eq(str(b2["kind"]), "guidance", "a check line asks as well")
	var seen := r.answer_guidance(-1, "never")
	assert_eq(str(seen["kind"]), "check")
	assert_false("Guidance" in str(seen["extra_label"]), "rolled without it")
	assert_eq(GuidanceOffer.rule_of(_party(1)), "never", "Don't offer it: for every caster offered")
	assert_eq(str(r.next()["text"]), "You see it.", "then on down the branch the roll chose")


func test_without_a_screen_the_roll_comes_at_once() -> void:
	var r := _runner()
	r.offer_guidance = false
	var b := r.choose(0)
	assert_eq(str(b["kind"]), "check", "a bot's or a tool's conversation rolls straight away")
	assert_false("Guidance" in str(b["extra_label"]))
	GuidanceOffer.headless_too = false
	r = _runner()
	assert_eq(str(r.choose(0)["kind"]), "check", "headless, nobody's asked and nothing is cast")
	GuidanceOffer.set_rule(_party(2), "auto")
	r = _runner()
	var auto := r.choose(0)
	assert_eq(str(auto["kind"]), "check", "Automatic: no prompt")
	assert_true("Guidance (Liriel)" in str(auto["extra_label"]), "and cast all the same: %s" % auto["detail"])


func _offer(ends: String = "") -> Dictionary:
	var st := GameState.story
	var o := GuidanceOffer.offer(st, _party(0), &"athletics", 15)
	if ends != "":
		_party(2).concentration = Concentration.new(_party(2), "bless", ends)
		o = GuidanceOffer.offer(st, _party(0), &"athletics", 15)
	return o


func _ask(o: Dictionary) -> GuidancePrompt:
	root = Node.new()
	add_child(root)
	var p := GuidancePrompt.ask(root, o, func(i: int, rule: String) -> void: answers.append([i, rule]))
	await _frames(2)
	return p


func test_the_prompt_names_the_check_the_casters_and_what_a_spell_would_end() -> void:
	var p := await _ask(_offer("Bless"))
	assert_eq(p.layer, GuidancePrompt.LAYER)
	var words := " ".join(p.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text))
	assert_true("Ilse is about to try Athletics (DC 15)." in words, words)
	assert_eq(p.choices.size(), 2)
	assert_eq(p.choices[0].text, "1. Hedda casts Guidance: +1d4")
	assert_eq(p.choices[1].text, "2. Liriel casts Guidance (ends Bless)")
	assert_true(p.choices[0].has_meta(&"pad_first"), "the pad lands on the first caster")
	assert_true(p.rule_button.has_meta(&"pad_adjust"), "left and right turn the rule")
	assert_true("roll without it" in words, "the note under the frame says Escape rolls without it")
	p.choices[1].pressed.emit()
	assert_eq(answers, [[1, ""]], "the rule left alone stays as each caster has it")
	assert_false(p.open(), "answered once")
	p.choices[0].pressed.emit()
	assert_eq(answers.size(), 1, "and only once")


func test_keys_and_the_rule_answer_it() -> void:
	var p := await _ask(_offer())
	p.turn_rule(1)
	assert_eq(p.rule_button.text, "‹  Cast it without asking  ›")
	p.turn_rule(1)
	assert_eq(p.rule_button.text, "‹  Don't offer it  ›")
	p.turn_rule(-1)
	var esc := InputEventAction.new()
	esc.action = &"combat_cancel"
	esc.pressed = true
	p._unhandled_input(esc)
	assert_eq(answers, [[-1, "auto"]], "Esc rolls without it, keeping the rule picked")
	p = await _ask(_offer())
	var two := InputEventKey.new()
	two.physical_keycode = KEY_2
	two.pressed = true
	p._unhandled_input(two)
	assert_eq(answers.back(), [1, ""], "2 picks the second caster")


func test_the_conversation_screen_puts_it_over_the_box() -> void:
	root = Node.new()
	add_child(root)
	var d := DialogueUI.new()
	root.add_child(d)
	await _frames(1)
	var r := DialogueRunner.new(GameState.story, DiceRoller.new(5))
	r.offer_guidance = true
	assert_true(d.play(r, "test/guidance:start"))
	d.call("_advance")
	d.call("_choose", 0)
	await _frames(2)
	assert_true(d.guidance != null and d.guidance.open(), "the prompt is up")
	assert_true(d.d20 == null, "nothing rolled yet")
	d.guidance.choices[0].pressed.emit()
	await _frames(2)
	assert_eq(d.guidance, null)
	assert_true(d.d20 != null, "then the big d20 rolls")
	assert_true("Guidance (Hedda)" in (d.get("_text") as RichTextLabel).text, "and the result says who gave the d4")


func _place() -> LocationView:
	Compendium.shared().tables["locations"]["test_guidance"] = LOC.duplicate(true)
	GameState.story.location = "test_guidance"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


func test_a_check_in_a_place_waits_for_the_answer_and_nothing_moves_meanwhile() -> void:
	var v := await _place()
	var rolled: Array[String] = []
	v.check_rolled.connect(func(t: String) -> void: rolled.append(t))
	var line: Dictionary = {}
	for a: Variant in v.actions_at(Vector2i(1, 1))["actions"]:
		if str((a as Dictionary)["id"]) == "check:read_runes":
			line = a as Dictionary
	assert_true("can cast it first" in str(line.get("why", "")), "the menu says Guidance is asked for, not added: %s" % [line])
	LocationChecks.act(v, v.thing_at(Vector2i(1, 1)), "check:read_runes")
	await _frames(2)
	var p := root.get("guidance") as GuidancePrompt
	assert_true(p != null and p.open(), "the prompt is up over the place")
	assert_true(rolled.is_empty(), "nothing rolled yet")
	assert_true(WorldChecks.records(GameState.story, "test_guidance").is_empty(), "nobody's tried yet")
	var leader := v.leader().cell
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(5, 5)
	root.call("_unhandled_input", click)
	assert_eq(v.leader().cell, leader, "the world waits for it")
	p.choices[0].pressed.emit()
	await _frames(2)
	assert_eq(root.get("guidance"), null)
	assert_eq(rolled.size(), 1)
	assert_true("Guidance (Hedda)" in rolled[0], rolled[0])


func test_forcing_a_lock_and_a_search_ask_too_and_automatic_casts_unasked() -> void:
	var v := await _place()
	var rolled: Array[String] = []
	v.check_rolled.connect(func(t: String) -> void: rolled.append(t))
	LocationLocks._use_door(v, (LOC["doors"] as Array)[0] as Dictionary, "force")
	await _frames(2)
	var p := root.get("guidance") as GuidancePrompt
	assert_true(p != null, "forcing the door asks first")
	assert_eq(p.offer["skill"], &"athletics")
	p.decline_button.pressed.emit()
	await _frames(2)
	assert_eq(rolled.size(), 1, "then forces it")
	assert_false("Guidance" in rolled[0], rolled[0])
	assert_eq(str((GameState.story.loc_state("test_guidance")["doors"] as Dictionary).get("stuck", "")), LocationView.DOOR_OPEN,
		"DC 3: open")
	for ch in GameState.story.party:
		GuidanceOffer.set_rule(ch, "auto")
	rolled.clear()
	v.search()
	await _frames(2)
	assert_eq(root.get("guidance"), null, "Automatic: no prompt")
	assert_true(not rolled.is_empty() and "Guidance (Hedda)" in rolled[0], "the search's Perception has the d4: %s" % [rolled])
