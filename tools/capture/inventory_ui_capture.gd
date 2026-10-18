extends Node
## The inventory's categories, rarity borders and Attuned filter (inventory-ui lane): a pack with potions of every rarity,
## quest items, magic items of each rarity and some attuned, then the screens one shot each. LANE_ONLY=all,magic,potions,
## rarities,quest,attuned,shop,shop_potions limits the shots; the tabs this build doesn't have are skipped (so the same scene
## takes the "before" shots on an older build).
## make capture SCENE=res://tools/capture/inventory_ui_capture.tscn NAME=inventory-ui/after FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node
var _only: Array[String] = []


func _ready() -> void:
	for s in OS.get_environment("LANE_ONLY").split(",", false):
		_only.append(s.strip_edges())
	Compendium.shared().tables["locations"]["lane_inn"] = {"id": "lane_inn", "name": "The Blue Water Inn", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "lane_inn"
	GameState.story.gold = 210.0
	var g := GameState.story.party[0]
	for it: Array in [["potion_of_healing", 3], ["potion_of_resistance_fire", 1], ["potion_of_heroism", 2], ["potion_of_speed", 1],
			["potion_of_giant_strength_storm", 1], ["rope", 1], ["torch", 5], ["candle", 4], ["spell_component_ring", 1],
			["cloak_of_protection", 1], ["ring_of_warmth", 1], ["ring_of_protection", 1], ["ring_of_telekinesis", 1],
			["wand_of_secrets", 1], ["sunsword", 1], ["orb_of_damara", 1], ["st_andrals_bones", 1], ["holy_symbol_of_ravenkind", 1],
			["tome_of_strahd", 1]]:
		g.add_item(str(it[0]), int(it[1]))
	for e in g.inventory:
		e.erase("new")
	g.wear("cloak_of_protection")
	g.wear("ring_of_protection")
	g.attune("cloak_of_protection")
	g.attune("ring_of_protection")
	g.attune("ring_of_telekinesis")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _wants(what: String) -> bool:
	return _only.is_empty() or what in _only


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 8)
	tool.call("_shot", path)


func _inventory(setup: Callable) -> InventoryScreen:
	root.call("open_screen", "inventory", 0)
	var inv := root.get("screen") as InventoryScreen
	setup.call(inv)
	inv.call("_draw")
	return inv


func _has_tab(name_: String) -> bool:
	return name_ in InventoryScreen.FILTERS


func capture_shots(tool: Node, out: String) -> void:
	if _wants("all"):
		_inventory(func(inv: InventoryScreen) -> void: inv.selected = "ring_of_protection")
		await _shoot(tool, "%s_all.png" % out)
		root.call("close_screen")
	if _wants("magic"):
		_inventory(func(inv: InventoryScreen) -> void:
			inv.filter = "Magic"
			inv.selected = "sunsword")
		await _shoot(tool, "%s_magic.png" % out)
		root.call("close_screen")
	if _wants("rarities"):
		# Every rarity in one list, scrolled to the end where the legendary and artifact items sit.
		var inv_r := _inventory(func(inv: InventoryScreen) -> void:
			inv.filter = "Magic"
			inv.sort_by = "value"
			inv.selected = "orb_of_damara")
		await tool.call("wait_frames", 4)
		var list := inv_r.get("_grid") as Node
		var scroll := list.get_parent() as ScrollContainer
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _shoot(tool, "%s_rarities.png" % out)
		root.call("close_screen")
	if _wants("potions") and _has_tab("Potions"):
		_inventory(func(inv: InventoryScreen) -> void:
			inv.filter = "Potions"
			inv.selected = "potion_of_heroism")
		await _shoot(tool, "%s_potions.png" % out)
		root.call("close_screen")
	if _wants("quest") and _has_tab("Quest"):
		_inventory(func(inv: InventoryScreen) -> void:
			inv.filter = "Quest"
			inv.selected = "st_andrals_bones")
		await _shoot(tool, "%s_quest.png" % out)
		root.call("close_screen")
	if _wants("attuned") and _has_tab("Potions"):   # the Attuned filter came with the new tabs
		_inventory(func(inv: InventoryScreen) -> void:
			inv.marks = "attuned"
			inv.selected = "ring_of_telekinesis")
		await _shoot(tool, "%s_attuned.png" % out)
		root.call("close_screen")
	if _wants("shop"):
		root.call("open_shop", "gunther_arasek")
		var shop := root.find_child("ShopScreen", true, false) as ShopScreen
		if shop != null:
			shop.call("set_only_buys", false)
			await _shoot(tool, "%s_shop.png" % out)
			if _has_tab("Potions") and _wants("shop_potions"):
				shop.call("pick_filter", "Potions")
				await _shoot(tool, "%s_shop_potions.png" % out)
			shop.call("pick_filter", "All")
			shop.call("set_only_buys", true)
			shop.queue_free()
