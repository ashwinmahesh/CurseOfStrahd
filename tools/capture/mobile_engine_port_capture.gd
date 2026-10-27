extends Node
## Prepared offscreen phone/tablet inventory evidence for the engine migration; never native or physical evidence.

func close_screen() -> void:
	pass


func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var state := StoryState.new()
	var ch := Pregens.build("godrick_pendlebrook", 3)
	state.party.append(ch)
	state.gold = 125
	ch.add_item("ring_of_protection")
	ch.add_item("potion_of_healing", 3)
	ch.wear("ring_of_protection")
	ch.attune("ring_of_protection")
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	inventory.marks = InventoryScreen.MARK_ATTUNED
	inventory.mobile.draw()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_attuned.png")
	inventory.mobile.filters_open = true
	inventory.mobile.draw()
	await tool.call("wait_frames", 12)
	for option: CheckButton in inventory.find_children("*", "CheckButton", true, false):
		if not option.is_queued_for_deletion() and option.text == "Legendary":
			inventory.mobile.page.scroll.ensure_control_visible(option)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_rarity_filters.png")
	inventory.marks = ""
	inventory.rarities = ["legendary"]
	inventory.mobile.filters_open = false
	inventory.mobile.draw()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_rarity_empty.png")
	inventory.mobile.reset_filters()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_bag_recovered.png")
	inventory.queue_free()
	await tool.call("wait_frames", 3)
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_for(self, state, "father_lucian")
	shop.pick_ware_filter("Potions")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_shop_potions.png")
	shop.mobile_side = "Sell"
	shop.set_only_buys(false)
	shop.pick_filter("Magic")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_shop_rarity.png")
	shop.queue_free()
