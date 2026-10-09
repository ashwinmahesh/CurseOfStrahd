extends TestCase
## Things the party only looks at are examined from where it stands when no square beside them can be reached
## (Storyline QA, 2026-10-08): Krezk's burgomaster's house front, the fire deep in Old Bonegrinder's oven, the horses
## in the Tser Pool pen, Madam Eva's great tent and Yester Hill's effigy all answered "Can't reach it", so their
## narration never played. Anything to take, read, pull or talk at still has to be reached.

const LOC := {
	"id": "test_paddock", "name": "Test Paddock", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#########",
		"#.......#",
		"#.=====.#",
		"#.=...=.#",
		"#.=====.#",
		"#.......#",
		"#########"], "light": "bright"},
	"spawns": {"default": [1, 1]},
	"props": [{"id": "penned_horses", "cell": [4, 3], "kind": "examine", "label": "Horses", "model": "satchel",
			"text": "Two horses doze behind the fence."},
		{"id": "penned_letter", "cell": [3, 3], "kind": "examine", "label": "A letter", "model": "satchel",
			"dialogue": "test/paddock:letter"}],
}

const DIALOGUE := """
~ letter
Narrator: A letter, folded small.
-> END
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_paddock"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/paddock"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_paddock"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	Compendium.shared().tables["locations"].erase("test_paddock")


func test_a_thing_only_looked_at_is_examined_from_afar() -> void:
	var v := root.get("view") as LocationView
	var said: Array[String] = []
	var toasts: Array[String] = []
	v.narration.connect(func(t: String) -> void: said.append(t))
	v.toast.connect(func(t: String) -> void: toasts.append(t))
	v.click(Vector2i(4, 3))
	await _frames(2)
	assert_true(said.has("Two horses doze behind the fence."), "a click examines the penned horses: %s" % [said])
	assert_false(toasts.has("Can't reach it"), str(toasts))
	said.clear()
	LocationInteraction.act(v, Vector2i(4, 3), "use")
	await _frames(2)
	assert_true(said.has("Two horses doze behind the fence."), "and so does the menu's choice: %s" % [said])


func test_something_to_read_still_has_to_be_reached() -> void:
	var v := root.get("view") as LocationView
	var toasts: Array[String] = []
	v.toast.connect(func(t: String) -> void: toasts.append(t))
	v.click(Vector2i(3, 3))
	await _frames(2)
	assert_true(toasts.has("Can't reach it"), str(toasts))
	assert_true(root.get("dialogue") == null, "no conversation from behind the fence")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
