extends TestCase
## Dialogue busts (Improvement Ideas G1; docs/ui/busts.md, ui/dialogue/dialogue_busts.gd): every bust in the recipes is in
## the game (its neutral one and each mood), named after the portrait id the conversation uses; a mood without its own
## bust falls back to the neutral one; in a conversation the NPC talking stands lit on the right with the party's speaker
## dimmed on the left, a party line lights the left, and the Narrator dims both.

const DIALOGUE := """
~ start
Ireena: Who's there?
Ireena [angry]: Answer me.
Player: Friends.
Narrator: The fire cracks.
-> END
"""

var root: Node


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/busts"))


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await get_tree().process_frame
	GameState.reset()


func test_every_bust_in_the_recipes_is_in_the_game() -> void:
	var rec := JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/bust_recipes.json")) as Dictionary
	var people := rec["people"] as Dictionary
	assert_true(people.size() >= 50, "the ten heroes and forty NPCs")
	for id: String in people:
		var person := people[id] as Dictionary
		var own := "res://data/npcs/%s.json" % id
		if FileAccess.file_exists(own):
			assert_eq(str(Compendium.shared().get_entry("npcs", id).get("portrait", id)), id, "%s's bust is named after its portrait" % id)
		assert_eq(DialogueBusts.path_for(id), DialogueBusts.DIR + id + ".webp", "%s has a bust" % id)
		for mood: Variant in person["moods"]:
			assert_eq(DialogueBusts.path_for(id, str(mood)), "%s%s_%s.webp" % [DialogueBusts.DIR, id, mood], "%s looks %s" % [id, mood])


func test_a_mood_without_its_own_bust_uses_the_neutral_one() -> void:
	assert_eq(DialogueBusts.path_for("ireena", "angry"), "res://art/busts/ireena_angry.webp")
	assert_eq(DialogueBusts.path_for("ireena", "sly"), "res://art/busts/ireena.webp", "no sly Ireena: her neutral bust")
	assert_eq(DialogueBusts.path_for("nobody_at_all"), "", "no bust, nothing shown")


func test_the_speaker_is_lit_and_the_other_side_dims() -> void:
	GameState.reset()
	var ch := Pregens.build("godrick_pendlebrook", 3)
	ch.finish_long_rest()
	GameState.story.party.append(ch)
	root = Node.new()
	add_child(root)
	var d := DialogueUI.new()
	root.add_child(d)
	await get_tree().process_frame
	assert_true(d.play(DialogueRunner.new(GameState.story, DiceRoller.new(2)), "test/busts:start"))
	await get_tree().process_frame
	var b := d.busts
	assert_eq(b.right_id, "res://art/busts/ireena.webp", "Ireena on the right")
	assert_eq(b.left_id, "res://art/busts/godrick_pendlebrook.webp", "the party's speaker on the left")
	assert_eq(b.lit, "right", "she is talking")
	assert_true(b.right.self_modulate == Color.WHITE and b.left.self_modulate == DialogueBusts.DIM)
	d.call("_advance")
	assert_eq(b.right_id, "res://art/busts/ireena_angry.webp", "her angry bust for an angry line")
	d.call("_advance")
	assert_eq(b.lit, "left", "the party answers")
	d.call("_advance")
	assert_eq(b.lit, "", "the Narrator dims both")
