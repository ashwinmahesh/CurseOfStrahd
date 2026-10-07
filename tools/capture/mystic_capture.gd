extends Node
## make capture SCENE=res://tools/capture/mystic_capture.tscn NAME=mystic FRAMES=10

func capture_shots(tool: Node, out: String) -> void:
	var book_content := BookContentFixture.new()
	tree_exiting.connect(book_content.restore, CONNECT_ONE_SHOT)
	InputActions.ensure()
	var ch := TestChars.custom("monk", "human", 17, {"monk_subclass": ["warrior_of_the_mystic_arts"]})
	ch.name = "Mystic"
	ch.expend_slot(1)
	ch.expend_slot(2)
	ch.finish_short_rest()
	ch.spend_resource("focus_points", 5)
	var state := StoryState.new()
	state.party.assign([ch])
	var rest := RestScreen.new()
	add_child(rest)
	rest.open(self, state, 0)
	rest._short_done = true
	rest._draw()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_rest.png")
	rest.queue_free()
	await tool.call("wait_frames", 2)
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["mystic_focus"] = "ask"
	TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.refresh()
	hud.show_prompt(e.pending)
	await tool.call("wait_frames", 90)
	tool.call("_shot", out + "_recovery.png")
	while e.pending != null:
		e.answer_reaction(false)
	hud.hide_prompt()
	hud.queue_free()
