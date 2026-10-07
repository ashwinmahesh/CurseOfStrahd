extends Node
## make capture SCENE=res://tools/capture/reaction_policy_capture.tscn NAME=reaction_policy FRAMES=10

func capture_shots(tool: Node, out: String) -> void:
	var books := BookContentFixture.new()
	tree_exiting.connect(books.restore, CONNECT_ONE_SHOT)
	InputActions.ensure()
	var ch := TestChars.custom("wizard", "human", 17)
	(ch.spellcasting[0]["prepared"] as Array).append_array(["moment_of_prescience", "reweave_fate"])
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.set_tab(ActionCatalog.new(e).class_tab(c))
	hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_choices.png")
	hud.queue_free()
