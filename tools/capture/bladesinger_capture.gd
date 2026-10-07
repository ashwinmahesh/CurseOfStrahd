extends Node
## make capture SCENE=res://tools/capture/bladesinger_capture.tscn NAME=bladesinger FRAMES=10
## Song of Defense: its Ask/Off/Auto settings in the class tab, and the slot choice when a hit lands during Bladesong.

func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var ch := TestChars.custom("wizard", "human", 10, {"wizard_subclass": ["bladesinger"]})
	ch.name = "Bladesinger"
	var e := TestCombat.open_field()
	e.default_player_reaction = "never"
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var foe_ch := TestChars.custom("fighter", "human", 5, {"fighter_subclass": ["champion"]})
	foe_ch.inventory.append({"id": "greatsword", "qty": 1, "slot": ""})
	foe_ch.equip("greatsword", "main_hand")
	var foe := e.add(foe_ch, &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	e.feature_recipes.perform(c, "bladesong", [])
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.set_tab(ActionCatalog.new(e).class_tab(c))
	hud.refresh()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_policies.png")
	c.reaction_rules["song_of_defense"] = "ask"
	e.end_turn()
	TestCombat.next_d20(e, 20)
	e.attack(foe, c, "weapon:greatsword")
	if e.pending != null:
		hud.show_prompt(e.pending)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_slot_choice.png")
	if e.pending != null:
		e.answer_reaction(false)
	hud.queue_free()
