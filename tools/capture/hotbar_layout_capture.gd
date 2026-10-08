extends Node
## make capture SCENE=res://tools/capture/hotbar_layout_capture.tscn NAME=hotbar_layout FRAMES=10
## U2: a hotbar the player arranged. A Favourites tab first (a starred attack and Dash), Dodge moved to the front of
## Common, Influence put away on the Hidden tab at the end, and a slot's right-click menu with its Hotbar choices.

func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var catalog := ActionCatalog.new(e)
	for a in catalog.actions_for(c):
		if str(a["kind"]) == "attack":
			catalog.set_favourite(c, str(a["id"]), true)
			break
	catalog.set_favourite(c, "dash", true)
	catalog.move_action(c, ActionCatalog.COMMON, "dodge", 0)
	catalog.set_hidden(c, "influence", true)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, catalog)
	hud.refresh()
	hud.set_tab(ActionCatalog.FAVOURITES)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_1_favourites.png")
	hud.set_tab(ActionCatalog.COMMON)
	await tool.call("wait_frames", 4)
	var first := hud._slot_buttons[0]
	hud.open_slot_menu(hud.slot_action(0), first.get_screen_position() + Vector2(40, -10))
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_2_common_menu.png")
	hud.queue_free()
