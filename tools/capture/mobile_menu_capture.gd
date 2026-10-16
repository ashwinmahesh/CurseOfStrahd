extends Node


func capture_shots(tool: Node, out: String) -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for method: String in ["_title", "_new_game", "_pick_difficulty", "_offer_tutorial"]:
		menu.call(method)
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + method + ".png")
	menu.call("_credits")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_credits.png")
	menu.queue_free()
	await tool.call("wait_frames", 2)
	var state := StoryState.new()
	var hero := Pregens.build("godrick_pendlebrook", 5)
	hero.inventory.clear()
	for item in Compendium.shared().all("items"):
		if hero.inventory.size() >= 350:
			break
		hero.inventory.append({"id": str(item["id"]), "qty": 1, "slot": ""})
	state.party.append(hero)
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	inventory.mobile.turn_page(1)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_inventory_page2.png")
	for scroll: ScrollContainer in inventory.find_children("*", "ScrollContainer", true, false):
		if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll.scroll_vertical = 99999
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_inventory_paging.png")
	inventory.queue_free()
	await tool.call("wait_frames", 2)
	var cheats := CheatCodesPage.open_on(self, state)
	cheats.type_code("359A02")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_cheat_code.png")
	cheats.queue_free()
	await tool.call("wait_frames", 2)
	var layer := CanvasLayer.new()
	add_child(layer)
	var dice := DiceRoll.new()
	layer.add_child(dice)
	dice.place_for_screen()
	dice.roll({"who": "Godrick Pendlebrook", "label": "Wisdom saving throw", "kind": "save", "natural": 20,
		"rolls": [20, 8], "advantage": true, "total": 24, "target": 18, "success": true, "critical": true})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_dice.png")

	layer.queue_free()
	ErrorWatch.show_notice({"text": "The saved game could not be opened. Your previous save is still available.", "where": "save_loader"})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_error.png")
	ErrorWatch.dismiss()
