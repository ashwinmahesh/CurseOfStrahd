extends Node
## make capture SCENE=res://tools/capture/mind_magic_capture.tscn NAME=mind_magic FRAMES=10

func capture_shots(tool: Node, out: String) -> void:
	var book_content := BookContentFixture.new()
	tree_exiting.connect(book_content.restore, CONNECT_ONE_SHOT)
	InputActions.ensure()
	var ch := TestChars.custom("cleric", "human", 3, {"cleric_subclass": ["knowledge_domain"]})
	ch.name = "Knowledge Cleric"
	var state := StoryState.new()
	state.party.assign([ch])
	var sheet := CharacterSheetScreen.new()
	add_child(sheet)
	sheet.open(self, state, 0)
	sheet.show_tab("Spells")
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_exploration.png")
	sheet.queue_free()
	await tool.call("wait_frames", 2)
	# Focus the combat capture on the two payment options for the same spell.
	ch.spellcasting[0]["cantrips"] = []
	ch.spellcasting[0]["fixed_cantrips"] = []
	ch.spellcasting[0]["prepared"] = []
	ch.spellcasting[0]["always"] = [{"id": "mind_spike", "source": "Knowledge Domain"}]
	for level in range(1, 10):
		while ch.slots_left(level) > 0:
			ch.expend_slot(level)
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.set_tab(ActionCatalog.SPELLS)
	hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_combat.png")
	hud.queue_free()
