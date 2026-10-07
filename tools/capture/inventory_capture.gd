extends Node
## Inventory and level up for captures (lane 14: U3 search and junk, Q7 the stash from anywhere, Q10 recommended picks,
## U11 the paper doll, grid, weapon sets and quick slots): the party at level 5 with finds in the pack, some marked as
## junk, then the screens one shot each. LANE_ONLY=inventory,search,junk,road,shop,loot,level_up limits the shots.
## make capture SCENE=res://tools/capture/inventory_capture.tscn NAME=lane14/after FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node
var _only: Array[String] = []


func _ready() -> void:
	for s in OS.get_environment("LANE_ONLY").split(",", false):
		_only.append(s.strip_edges())
	for id: String in ["lane_inn", "lane_road"]:
		Compendium.shared().tables["locations"][id] = {"id": id, "name": "The Blue Water Inn" if id == "lane_inn" else "Svalich Road",
			"region": "test", "summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
			"rest": "safe" if id == "lane_inn" else "wild"}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "lane_inn"
	GameState.story.gold = 64.0
	var godrick := GameState.story.party[0]
	for it: Array in [["potion_of_healing", 3], ["wand_of_secrets", 1], ["rope", 1], ["flail", 1], ["handaxe", 2], ["mirror", 1],
			["ring_of_protection", 1], ["candle", 4], ["st_andrals_bones", 1]]:
		godrick.add_item(str(it[0]), int(it[1]))
	# Some finds were already looked at; the rest stay new.
	for id: String in ["rope", "flail", "handaxe", "mirror", "candle"]:
		godrick.entry_of(id).erase("new")
	for id: String in ["flail", "handaxe", "mirror"]:
		godrick.entry_of(id)["junk"] = true
	GameState.story.party[1].add_item("dagger", 2)
	GameState.story.party[1].entry_of("dagger")["junk"] = true
	GameState.story.stash.append({"id": "hooded_lantern", "qty": 1})
	GameState.story.stash.append({"id": "javelin", "qty": 4})
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


func capture_shots(tool: Node, out: String) -> void:
	if _wants("inventory"):
		_inventory(func(inv: InventoryScreen) -> void:
			inv.selected = "flail"
			inv.sort_by = "newest")
		await _shoot(tool, "%s_inventory.png" % out)
		root.call("close_screen")
		# Closing cleared the New marks; put them back for the next shots.
		for id: String in ["potion_of_healing", "wand_of_secrets", "ring_of_protection"]:
			GameState.story.party[0].entry_of(id)["new"] = true
	if _wants("search"):
		_inventory(func(inv: InventoryScreen) -> void:
			inv.search = "potion"
			inv.selected = "potion_of_healing")
		await _shoot(tool, "%s_search.png" % out)
		root.call("close_screen")
		for id: String in ["potion_of_healing", "wand_of_secrets", "ring_of_protection"]:
			GameState.story.party[0].entry_of(id)["new"] = true
	if _wants("junk"):
		_inventory(func(inv: InventoryScreen) -> void:
			inv.marks = "junk"
			inv.selected = "mirror")
		await _shoot(tool, "%s_junk.png" % out)
		root.call("close_screen")
	if _wants("road"):
		GameState.story.location = "lane_road"
		_inventory(func(inv: InventoryScreen) -> void:
			inv.selected = "wand_of_secrets")
		await _shoot(tool, "%s_road_stash.png" % out)
		root.call("close_screen")
		GameState.story.location = "lane_inn"
	if _wants("shop"):
		root.call("open_shop", "gunther_arasek")
		await _shoot(tool, "%s_shop.png" % out)
		var shop := root.find_child("ShopScreen", true, false) as ShopScreen
		if shop != null and shop.has_method("sell_all_junk"):
			shop.call("sell_all_junk")
			await _shoot(tool, "%s_shop_sold.png" % out)
		if shop != null:
			shop.queue_free()
	if _wants("loot"):
		var lw := LootWindow.new()
		add_child(lw)
		lw.show_loot(GameState.story, "chest", [{"id": "potion_of_healing", "qty": 2}, {"id": "wand_of_magic_missiles", "qty": 1},
			{"id": "rope", "qty": 1}, {"id": "torch", "qty": 5}], 25.0, null)
		await _shoot(tool, "%s_loot.png" % out)
		lw.queue_free()
	if _wants("level_up"):
		# Q10: a companion at an Ability Score Improvement (filled from their own level plan), and a new hero choosing a
		# subclass (filled with the class's recommended picks). Each shot scrolls to the picks.
		GameState.story.milestones = 10
		var party := GameState.story.party
		party[0] = Pregens.build("godrick_pendlebrook", 3)
		var hero := TestChars.custom("cleric", "human", 2)
		hero.name = "Mirela Vasquez"
		hero.build["name"] = hero.name
		party[3] = hero
		for i: int in [0, 3]:
			root.call("open_screen", "level_up", i)
			await tool.call("wait_frames", 4)
			var screen := root.get("screen") as Node
			for l in screen.find_children("*", "Label", true, false):
				if (l as Label).text.begins_with("4 · Choices"):
					var up := (l as Node).get_parent()
					while up != null and not up is ScrollContainer:
						up = up.get_parent()
					if up != null:
						(up as ScrollContainer).scroll_vertical = int((l as Label).global_position.y - (up as ScrollContainer).global_position.y) - 20
			await _shoot(tool, "%s_level_up_%s.png" % [out, party[i].name.get_slice(" ", 0).to_lower()])
			root.call("close_screen")
