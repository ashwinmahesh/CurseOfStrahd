extends TestCase
## The big d20 (G11) and choosing who speaks (Q13), in a conversation (docs/ui/d20_roll.md): a check rolls a large d20
## that lands on the kept die, with the DC, each part of the bonus, both dice under Advantage, the total and the result,
## and goes away with the next beat; the player can hand the party's voice to another living member, whose bonus and
## chance the options then show, whose checks they roll, and whose bust stands on the left.

const DIALOGUE := """
~ start
Ireena: Will you help?
* [Persuasion DC 1] Of course we will. -> yes | yes
* Leave. -> END

~ yes
Ireena: Thank you.
-> END
"""

var root: Node


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/d20"))
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "kip_smudgewick"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
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
	assert_true(d.play(DialogueRunner.new(GameState.story, DiceRoller.new(7)), "test/d20:start"))
	d.call("_advance")   # past Ireena's line to the options
	return d


func test_the_roll_in_words() -> void:
	var text := D20Roll.parts_text({"rolls": [14, 7], "kept": 14, "advantage": true,
		"parts": [{"label": "Charisma", "value": 3}, {"label": "Proficiency", "value": 2}], "extra": 0})
	assert_eq(text, "d20 Advantage: 14 and 7, the higher kept · Charisma +3 · Proficiency +2")
	assert_eq(D20Roll.parts_text({"rolls": [9], "kept": 9, "modifier": -1, "parts": []}), "d20: 9 · Bonus -1")
	assert_eq(D20Roll.parts_text({"auto_failed": true}), "An automatic failure")


func test_a_check_rolls_the_big_d20_and_it_goes_with_the_next_beat() -> void:
	var d := await _talk()
	assert_eq(d.options_shown.size(), 2)
	d.call("_choose", 0)
	assert_true(d.d20 != null, "the big d20 is up")
	var beat := d.d20.beat
	assert_eq(d.d20.die.number, int(beat["kept"]), "it lands on the die that counts")
	assert_eq(str(beat["skill"]), "Persuasion")
	assert_true((beat["parts"] as Array).size() > 0, "every part of the bonus")
	assert_eq(int(beat["total"]), int(beat["kept"]) + int(beat["modifier"]) + int(beat["extra"]))
	d.call("_advance")
	await get_tree().process_frame
	assert_true(d.d20 == null, "gone with the next beat")


func test_the_player_picks_who_speaks_and_their_chances_show() -> void:
	var d := await _talk()
	var party := GameState.story.party
	var speaker_button := d.find_child("Speaker", true, false) as Button
	assert_true(speaker_button != null and speaker_button.visible, "the choice is offered while there are options")
	var first := d.runner.speaker
	assert_eq(str((d.options_shown[0]["check"] as Dictionary)["who"]), first.name)
	d.cycle_speaker()
	var other: Character = party[1] if first == party[0] else party[0]
	assert_true(d.runner.speaker == other, "the next party member speaks")
	assert_eq(str((d.options_shown[0]["check"] as Dictionary)["who"]), other.name, "the options show their check")
	assert_true(speaker_button.text.begins_with("Speaks: %s" % other.name.get_slice(" ", 0)))
	assert_eq(d.busts.left_id, DialogueBusts.path_for(DialogueRunner.portrait_of(other)), "their bust on the left")
	d.call("_choose", 0)
	assert_eq(str(d.d20.beat["who"]), other.name, "and they roll it")
