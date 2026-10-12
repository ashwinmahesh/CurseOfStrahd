extends TestCase
## Items the party comes by outside loot and shops are announced on the side (ui/exploration/item_notices.gd; owner,
## 2026-10-12: the well at the Wizard of Wines handed over a Rope of Climbing and nothing said so): the item's name in
## its rarity's colour, who has it, a "Magic item found" banner on a magic item; three at a time, the rest waiting; a
## conversation's gift, a hidden find and a skill check's find all raise one, a loot window doesn't.

const LOC := {
	"id": "test_notices", "name": "Test Notices", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#######",
		"#.....#",
		"#.....#",
		"#######"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"props": [{"id": "nook", "cell": [1, 1], "kind": "search", "search_dc": 1, "label": "A nook", "item": "rope_of_climbing"}],
}

const DIALOGUE := """
~ gift
Narrator: A stranger presses something into your hands.
give potion_of_healing_greater 2
-> END
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_notices"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/notices"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_notices"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_notices")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _notices() -> ItemNotices:
	return root.get("notices") as ItemNotices


func _texts() -> Array[String]:
	var out: Array[String] = []
	for p in _notices().shown():
		var t: Array[String] = []
		for l in p.find_children("*", "Label", true, false):
			t.append((l as Label).text)
		out.append(" | ".join(t))
	return out


func test_what_a_notice_says() -> void:
	var rope := ItemNotices.words("rope_of_climbing", 1, "Tamsin Tealeaf")
	assert_true(bool(rope["magic"]))
	assert_eq(str(rope["name"]), "Rope of Climbing")
	assert_eq(str(rope["colour"]), "emerald_light", "an uncommon item in its rarity's colour")
	assert_eq(str(rope["who"]), "Tamsin has it")
	var bolts := ItemNotices.words("antitoxin", 3, "")
	assert_false(bool(bolts["magic"]))
	assert_eq(str(bolts["name"]), "Antitoxin ×3")
	assert_eq(str(bolts["colour"]), "parchment")
	assert_eq(str(bolts["who"]), "Into the party's stash")


func test_a_magic_item_has_its_banner() -> void:
	_notices().show_item("rope_of_climbing", 1, "Ilse Varga")
	assert_eq(_notices().shown().size(), 1)
	assert_true(_texts()[0].begins_with("Magic item found | Rope of Climbing | Ilse has it"), _texts()[0])
	_notices().show_item("antitoxin", 1, "Ilse Varga")
	assert_false(_texts()[1].contains("Magic item found"), "a mundane find has none")


func test_three_at_a_time_and_the_rest_wait() -> void:
	for i in 6:
		_notices().show_item("antitoxin", i + 1, "Ilse Varga")
	assert_eq(_notices().shown().size(), ItemNotices.MAX_SHOWN)
	_notices().call("_gone", _notices().shown()[0])
	await _frames(1)
	assert_eq(_notices().shown().size(), ItemNotices.MAX_SHOWN, "the next one takes its place")
	assert_true(_texts()[-1].contains("Antitoxin ×%d" % (ItemNotices.MAX_SHOWN + 1)), str(_texts()))


func test_nothing_on_them_takes_the_mouse_or_focus() -> void:
	_notices().show_item("rope_of_climbing", 1, "Ilse Varga")
	for c in _notices().find_children("*", "Control", true, false):
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, c.name)
		assert_eq((c as Control).focus_mode, Control.FOCUS_NONE, c.name)


func test_a_conversations_gift_is_announced() -> void:
	root.call("start_dialogue", "test/notices:gift", "")
	var d := root.get("dialogue") as DialogueUI
	for i in 8:
		if not _texts().is_empty():
			break
		d.call("_advance")
		await _frames(2)
	assert_eq(_texts().size(), 1, "the gift is on the side")
	assert_true(_texts()[0].contains("Potion of Healing (Greater) ×2"), str(_texts()))


func test_a_hidden_find_is_announced() -> void:
	var v := root.get("view") as LocationView
	v.search()
	v.interact(v.thing_at(Vector2i(1, 1)))
	assert_true(_texts().any(func(t: String) -> bool: return t.contains("Rope of Climbing")), str(_texts()))


func test_a_loot_window_raises_none() -> void:
	root.call("_open_loot", "test_chest", [{"id": "antitoxin", "qty": 1}], 0.0)
	await _frames(2)
	var loot := root.get("loot") as Node
	assert_true(loot != null, "the loot window opened")
	if loot != null:
		loot.call("_take_all")
	await _frames(1)
	assert_true(_notices().shown().is_empty(), "loot speaks for itself")
