extends TestCase
## A full list of spells greys the rest and takes no new pick until one is unpicked (Ashwin, 2026-10-28: "changing spells
## at the limit must not randomly replace one; block new selection until one is unselected").

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["silvain_aster"]:
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


func _buttons(w: ChoiceWidget) -> Array[Button]:
	var out: Array[Button] = []
	for b in w.find_children("*", "Button", true, false):
		if (b as Button).toggle_mode:
			out.append(b as Button)
	return out


func test_the_unpicked_spells_are_greyed_while_the_list_is_full() -> void:
	var ch := GameState.story.party[0]
	var c := ch.choice("wizard.cantrips")
	ChoiceOptions.populate(c, ch)
	assert_true(ChoiceOptions.full(c), "a Wizard's cantrips are full: %d of %d" % [c.picks.size(), c.count])
	var w := ChoiceWidget.create(c)
	root.add_child(w)
	await get_tree().process_frame
	var picked := 0
	var greyed := 0
	for b in _buttons(w):
		if b.button_pressed:
			picked += 1
			assert_false(b.disabled, "a picked cantrip can be unpicked")
		elif b.disabled:
			greyed += 1
	assert_eq(picked, c.count, "the picks are lit")
	assert_true(greyed > 3, "the rest are greyed: %d" % greyed)
	# One unpicked: a place is free, and nothing waits any more.
	var fewer := ChoiceOptions.toggled(c, c.picks[0], false)
	(ch.build["choices"] as Dictionary)["wizard.cantrips"] = fewer.duplicate()
	ch.refresh()
	var room := ch.choice("wizard.cantrips")
	ChoiceOptions.populate(room, ch)
	assert_false(ChoiceOptions.full(room))
	var w2 := ChoiceWidget.create(room)
	root.add_child(w2)
	await get_tree().process_frame
	var open := 0
	for b in _buttons(w2):
		if not b.button_pressed and not b.disabled:
			open += 1
	assert_true(open > 3, "with a place free the others can be picked: %d" % open)
