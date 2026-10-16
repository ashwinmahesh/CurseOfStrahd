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
