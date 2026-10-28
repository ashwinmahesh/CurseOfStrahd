extends TestCase
## The big d20 shows a d20 rolled again and what was added after the roll (Ashwin, 2026-10-26: "display the same green dice
## roll when rerolling for inspiration" and "same thing with other abilities which add to rolls (ex dark ones own luck, say
## the number rolled from that and whether it resulted in a success or not)"): the die is thrown as it first landed, set
## aside, and thrown again for each reroll; the words give each throw, then each addition with its number and whether the
## roll then succeeded. In a conversation an aid spent on the check goes on from the die shown.

const OWN := "dark_ones_own_luck"
const DIALOGUE := """
~ start
Ireena: Will you help?
* [Intimidation DC 14] Of course we will. -> yes | no
* Leave. -> END

~ yes
Ireena: Thank you.
-> END

~ no
Ireena: You are wasting my time.
-> END
"""

var root: Node
var _motion := true


func before_each() -> void:
	UiMotion.on()   # its first call decides (off in a headless run); only then can a test turn motion on
	_motion = UiMotion.reduced
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/reroll_display"))
	GameState.reset()
	root = Node.new()
	add_child(root)


func after_each() -> void:
	UiMotion.reduced = _motion
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await get_tree().process_frame
	GameState.reset()


func _seed(low_first: bool) -> int:
	for s in range(1, 3000):
		var d := DiceRoller.new(s)
		var a := d.d20()
		var b := d.d20()
		if low_first and a <= 4 and b >= 19:
			return s
		if not low_first and a >= 5 and a <= 9:
			return s
	return 0


func _roll_with_reroll() -> Dictionary:
	return {"kind": "check", "natural": 17, "rolls": [17], "total": 21, "target": 14, "success": true, "who": "Ilse", "label": "Intimidation",
		"modifier": 4, "parts": [{"label": "Str modifier", "value": 2}, {"label": "Proficiency", "value": 2}], "extra": 0, "extra_label": "",
		"rerolls": [{"source": "Heroic Inspiration", "before": [4], "before_kept": 4, "after": [17], "after_kept": 17}], "added": []}


func test_the_throws_of_a_roll_that_was_rolled_again() -> void:
	var plain := DiceRoll.throws_of({"natural": 12, "rolls": [12]})
	assert_eq(plain.size(), 1)
	assert_eq(int(plain[0]["kept"]), 12)
	var throws := DiceRoll.throws_of(_roll_with_reroll())
	assert_eq(throws.size(), 2, "the first throw, then the reroll")
	assert_eq(int(throws[0]["kept"]), 4, "the die as it first landed")
	assert_eq(str(throws[0]["source"]), "")
	assert_eq(int(throws[1]["kept"]), 17)
	assert_eq(str(throws[1]["source"]), "Heroic Inspiration")
	# Under Advantage the other die goes along: one die rolled again, the other as it was.
	var adv := {"natural": 15, "rolls": [3, 15], "advantage": true, "rerolls": [{"source": "Heroic Inspiration", "before": [3, 9],
		"before_kept": 9, "after": [15, 9], "after_kept": 15}]}
	var t2 := DiceRoll.throws_of(adv)
	assert_eq(int(t2[0]["kept"]), 9)
	assert_eq(int(t2[0]["other"]), 3)
	assert_eq(int(t2[1]["kept"]), 15)
	assert_eq(int(t2[1]["other"]), 9)


func test_the_roll_in_words_gives_each_throw() -> void:
	assert_eq(DiceRoll.parts_text(_roll_with_reroll()), "d20: 4 · Heroic Inspiration rerolled: 17 · Str modifier +2 · Proficiency +2")
	var adv := {"natural": 15, "rolls": [15, 9], "advantage": true, "parts": [], "modifier": 0, "rerolls": [{"source": "Heroic Inspiration",
		"before": [3, 9], "before_kept": 9, "after": [15, 9], "after_kept": 15}]}
	assert_eq(DiceRoll.parts_text(adv), "d20 Advantage: 3 and 9, the higher kept · Heroic Inspiration rerolled Advantage: 15 and 9, the higher kept")


func test_each_addition_says_what_it_rolled_and_whether_it_helped() -> void:
	var r := {"kind": "check", "added": [{"source": "Bardic Inspiration", "amount": 4, "total": 12, "success": false},
		{"source": "Dark One's Own Luck", "amount": 7, "total": 19, "success": true}]}
	var lines := DiceRoll.added_lines(r)
	assert_eq(lines.size(), 2)
	assert_eq(lines[0], "Bardic Inspiration +4: the total is now 12, still a failure")
	assert_eq(lines[1], "Dark One's Own Luck +7: the total is now 19, a success")
	r["kind"] = "save"
	assert_true(DiceRoll.added_lines(r)[1].ends_with("it saves"), DiceRoll.added_lines(r)[1])
	r["kind"] = "attack"
	assert_true(DiceRoll.added_lines(r)[0].ends_with("it still misses"))
	# The first addition names the number too (it used to be run into its label: "Dark One's Own Luck 7 +7").
	var t := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 5, 2, 20)
	t.add_bonus(7, "Dark One's Own Luck")
	var words := DiceRoll.parts_text(DiceRoll.from_test(t, "Kip", "Persuasion"))
	assert_true(words.contains("Dark One's Own Luck +7"), words)
	assert_false(words.contains("Luck 7 +7"), words)


func test_the_panel_sets_the_first_throw_aside_and_throws_again() -> void:
	UiMotion.reduced = false
	var panel := DiceRoll.new()
	root.add_child(panel)
	panel.roll(_roll_with_reroll())
	assert_eq(panel._stages.size(), 2, "two throws")
	assert_eq(panel.die.number, 4, "the first lands as it did")
	assert_eq(panel._stage, 0)
	panel._landed()   # the first throw lands
	assert_true(panel.die.dim, "and is set aside")
	assert_true(panel._parts.text.contains("Heroic Inspiration: the d20 is thrown again"), panel._parts.text)
	panel._next_throw(panel._turn)
	assert_eq(panel._stage, 1)
	assert_eq(panel.die.number, 17, "the new throw")
	assert_false(panel.die.dim)
	assert_true(panel._parts.text.begins_with("d20: 4"), "the words, once it lands: %s" % panel._parts.text)
	# A click lands every throw at once, with the words.
	var again := DiceRoll.new()
	root.add_child(again)
	again.roll(_roll_with_reroll())
	again.skip()
	assert_eq(again._stage, 1)
	assert_eq(again.die.number, 17)
	assert_eq(again._parts.modulate.a, 1.0, "the words are there")
	panel.queue_free()
	again.queue_free()


func _talk(hero: Character, seed_found: int) -> DialogueUI:
	GameState.story.party.append(hero)
	var d := DialogueUI.new()
	root.add_child(d)
	await get_tree().process_frame
	assert_true(d.play(DialogueRunner.new(GameState.story, DiceRoller.new(seed_found)), "test/reroll_display:start"))
	d.call("_advance")
	return d


func _aid_button(d: DialogueUI, starts: String) -> Button:
	for b in d.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(starts) and not b.is_queued_for_deletion():
			return b as Button
	return null


func test_heroic_inspiration_in_a_conversation_throws_the_die_again_and_takes_the_success_branch() -> void:
	UiMotion.reduced = false
	var ilse := TestChars.pregen("ilse_varga", 3)
	ilse.finish_long_rest()
	ilse.heroic_inspiration = true
	var d := await _talk(ilse, _seed(true))
	d.call("_choose", 0)
	assert_false(bool(d.d20.result["success"]), "the first throw fails")
	assert_eq(d.d20._stages.size(), 1, "one throw")
	var aid := _aid_button(d, "Heroic Inspiration")
	assert_true(aid != null, "offered on the failure")
	if aid == null:
		return
	aid.pressed.emit()
	assert_true(bool(d.d20.result["success"]), "the reroll turns it round")
	assert_eq((d.d20.result["rerolls"] as Array).size(), 1, "the die knows it was thrown again")
	assert_eq(d.d20._stages.size(), 1, "and goes on from the roll shown: only the new throw is made")
	assert_eq(d.d20._throws_shown, 2)
	d.call("_advance")
	await get_tree().process_frame
	assert_true(str(d.get("_text").text).contains("Thank you"), "the branch is the success one: %s" % d.get("_text").text)


func test_dark_ones_own_luck_in_a_conversation_changes_the_words_and_leaves_the_die() -> void:
	UiMotion.reduced = false
	var kip := TestChars.pregen("kip_smudgewick", 6)
	kip.finish_long_rest()
	kip.heroic_inspiration = false
	var d := await _talk(kip, _seed(false))
	d.call("_choose", 0)
	if bool(d.d20.result["success"]):
		return   # rolled well without it: nothing to add to
	var number := d.d20.die.number
	var aid := _aid_button(d, "Dark One's Own Luck")
	assert_true(aid != null, "offered on the failure")
	if aid == null:
		return
	aid.pressed.emit()
	assert_eq((d.d20.result["added"] as Array).size(), 1)
	assert_eq(d.d20._stages.size(), 0, "no new d20: the die stays")
	assert_eq(d.d20.die.number, number)
	var line := str(d.d20._added.text)
	assert_true(line.begins_with("Dark One's Own Luck +"), line)
	assert_true(line.contains("the total is now %d" % int(d.d20.result["total"])), line)
	assert_true(line.ends_with("a success") or line.ends_with("still a failure"), line)
