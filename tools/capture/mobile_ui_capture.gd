extends Node
## Isolated mobile pages, with the real inventory and combat catalog. No player saves or settings are modified.

var inventory: InventoryScreen


func close_screen() -> void:
	if is_instance_valid(inventory):
		inventory.queue_free()


func capture_shots(tool: Node, out: String) -> void:
	var state := StoryState.new()
	for id: String in ["godrick_pendlebrook", "thistle", "liriel_dawnsong", "ratatoille"]:
		state.party.append(Pregens.build(id, 5))
	state.party[0].add_item("potion_of_healing", 4)
	state.gold = 42
	inventory = InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	for section: String in ["Bag", "Equipment", "Details"]:
		inventory.mobile.section = section if section != "Details" else "Bag"
		inventory.mobile.detail = section == "Details"
		inventory.selected = "potion_of_healing" if section == "Details" else ""
		inventory._draw()
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_" + section.to_lower() + ".png")
	close_screen()
	await tool.call("wait_frames", 2)
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(encounter, "zombie", Vector2i(6, 2))
	TestCombat.start_with(encounter, actor)
	var catalog := ActionCatalog.new(encounter)
	var actions := MobileActions.new()
	add_child(actions)
	actions.open(catalog, actor)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_actions.png")
	for action in catalog.actions_for(actor):
		if str(action["id"]) == "dodge":
			actions.inspect(action)
			break
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_review.png")

	actions.queue_free()
	await tool.call("wait_frames", 2)
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(encounter, catalog)
	hud.refresh()
	hud.show_tooltip("Zombie · preview", ["Attack with your longsword", "Use Confirm to commit"], [], Vector2.ZERO)
	hud.show_odds(0.65, "8–15", "", Vector2.ZERO)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_battle_hud.png")
	var req := ReactionRequest.new("shield", actor.id, "foe")
	req.title = "Reaction: protect your companion?"
	req.text = "A zombie attacks your companion. Choose who receives your protection before confirming."
	req.cost = "Reaction"
	req.min_targets = 1
	req.max_targets = 1
	for n in 5:
		req.target_choices.append({"id": str(n), "label": "Companion %d · within reach" % n})
	hud.show_prompt(req)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_reaction.png")
	hud.queue_free()
	await tool.call("wait_frames", 2)
	var pause := PauseMenu.new()
	add_child(pause)
	pause.open(self, state, 0)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_menu.png")
	pause._show_settings("Game")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_settings.png")
	pause.queue_free()
	await tool.call("wait_frames", 2)
	var exploration := ExploreHud.new()
	add_child(exploration)
	exploration.build(state)
	exploration.refresh("Village of Barovia", true, false, false)
	exploration.narrate("Mist curls around the village houses. A light burns in the tavern window, and the sound of quiet conversation reaches the road.")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_exploration.png")
	exploration.queue_free()
	await tool.call("wait_frames", 2)
	var conversation := DialogueUI.new()
	add_child(conversation)
	conversation._text.text = "The innkeeper watches you for a moment, then nods toward the fire. Outside, the mist presses against the windows."
	conversation._show({"kind": "options", "options": [
		{"text": "Ask about the strange mist around the village.", "label": "", "check": {}},
		{"text": "Offer to help the villagers.", "label": "Persuasion", "check": {"who": "Godrick", "bonus": 5, "chance": 0.65}},
		{"text": "Leave the inn and explore the village.", "label": "", "check": {}}]})
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_conversation.png")
	conversation.queue_free()
	await tool.call("wait_frames", 2)
	var sheet := CharacterSheetScreen.new()
	add_child(sheet)
	sheet.open(self, state, 0)
	sheet.mobile_section = "Abilities"
	sheet._draw()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_character.png")
	sheet.queue_free()
	await tool.call("wait_frames", 2)
	var creator := CreationScreen.new()
	add_child(creator)
	creator.open_with([])
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_creator.png")

	creator.queue_free()
	await tool.call("wait_frames", 2)
	var prior_dir := SaveSystem.save_dir
	SaveSystem.save_dir = "user://mobile_capture_saves/"
	var saves := SavesScreen.open_on(self, SavesScreen.Mode.LOAD, Callable())
	saves._tab = "Chapters"
	saves._fill()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_saves.png")
	saves._question({"location": "Village of Barovia", "day": 12, "party": "Godrick, Thistle and Liriel"}, "Import save?", "An adventure shared from a computer.", "Import creates a new local save.", "Import", func() -> void: pass)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_import.png")
	saves.queue_free()
	SaveSystem.save_dir = prior_dir
	await tool.call("wait_frames", 2)
	var lifecycle := MobileLifecycle.new()
	add_child(lifecycle)
	lifecycle.suspend()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_resume.png")
	lifecycle.resume_play()
