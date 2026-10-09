extends TestCase
## Take gold in the loot window (Ashwin, 2026-10-09: it did nothing once every item had been taken). Taking the last
## item used to put the coins in the purse without a word while their row and its button stayed on show, so the
## button had nothing left to take. The coins now wait for Take gold (or Take all, Send, All to the stash).

var lw: LootWindow


func before_each() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong"]:
		GameState.story.party.append(Pregens.build(id, 3))
	GameState.story.gold = 10.0


func after_each() -> void:
	if lw != null and is_instance_valid(lw):
		lw.queue_free()
	lw = null
	GameState.reset()


func _open() -> void:
	lw = LootWindow.new()
	add_child(lw)
	lw.show_loot(GameState.story, "chest", [{"id": "dagger", "qty": 1}, {"id": "torch", "qty": 2}], 25.0, null)
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The window's live buttons with this text.
func _buttons(text: String) -> Array[Button]:
	var out: Array[Button] = []
	for n in lw.find_children("*", "Button", true, false):
		var b := n as Button
		if b.text == text and not b.is_queued_for_deletion() and b.is_visible_in_tree():
			out.append(b)
	return out


func _press(text: String) -> void:
	var list := _buttons(text)
	assert_false(list.is_empty(), "a %s button shows" % text)
	if not list.is_empty():
		list[0].pressed.emit()
	await _frames(1)


func test_take_gold_works_after_every_item_is_taken_one_by_one() -> void:
	await _open()
	await _press("Take one")
	await _press("Take one")
	await _press("Take one")   # the second torch
	assert_true(lw.items.is_empty(), "every item taken")
	assert_eq(GameState.story.gold, 10.0, "the coins are still in the chest, not slipped into the purse")
	assert_eq(lw.gold, 25.0)
	var take_gold := _buttons("Take gold")
	assert_eq(take_gold.size(), 1, "Take gold still shows")
	assert_true(not take_gold.is_empty() and take_gold[0].focus_mode != Control.FOCUS_NONE, "and a pad or the keyboard can reach it")
	assert_true(not take_gold.is_empty() and take_gold[0] in PadNav.choices(lw), "the pad lands on it")
	await _press("Take gold")
	assert_eq(GameState.story.gold, 35.0, "Take gold puts the coins in the purse")
	assert_eq(lw.gold, 0.0)
	assert_true(_buttons("Take gold").is_empty(), "and its row goes")


func test_take_gold_works_after_every_item_is_stashed() -> void:
	await _open()
	await _press("Stash")
	await _press("Stash")
	assert_true(lw.items.is_empty(), "every item in the stash")
	assert_eq(GameState.story.gold, 10.0, "the coins wait")
	await _press("Take gold")
	assert_eq(GameState.story.gold, 35.0, "Take gold takes them")


func test_take_all_still_takes_the_coins_with_everything() -> void:
	await _open()
	await _press("Take one")
	lw.call("_take_all")
	assert_eq(GameState.story.gold, 35.0, "the coins with the rest")
