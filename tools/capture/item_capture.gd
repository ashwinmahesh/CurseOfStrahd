extends Node
## Magic items in use, for captures (ADR 0012): a locked chest's right-click menu with a Chime of Opening and a Mystery
## Key, the Ring of Spell Storing's spell picker, a disguised Potion of Poison with Identify on its card, the Rest
## screen's study row, and the loot window showing only what a disguised item passes for.
## make capture SCENE=res://tools/capture/item_capture.tscn NAME=items FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node


func _ready() -> void:
	Compendium.shared().tables["locations"]["item_hall"] = {"id": "item_hall", "name": "Item Hall", "region": "test",
		"summary": "", "map": {"rows": ["#######", "#.....#", "#.....#", "#######"]}, "spawns": {"default": [1, 1]},
		"rest": "safe", "containers": [{"id": "strongbox", "cell": [4, 1], "label": "Strongbox", "locked": true, "lock_dc": 20,
			"model": "chest"}]}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "item_hall"
	var ilse := GameState.story.party[0]
	ilse.add_item("chime_of_opening")
	ilse.add_item("mystery_key")
	ilse.add_item("ring_of_spell_storing")
	ilse.entry_of("ring_of_spell_storing")["stored"] = []
	ilse.add_item("potion_of_poison")
	GameState.story.party[1].add_item("gloves_of_thievery")
	GameState.story.party[1].wear("gloves_of_thievery")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 8)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	root.call("open_world_menu", Vector2i(4, 1), Vector2(800, 420))
	await _shoot(tool, "%s_lock_menu.png" % out)
	(root.get("menu") as Node).call("hide")
	for pick: String in ["ring_of_spell_storing", "potion_of_poison"]:
		root.call("open_screen", "inventory", 0)
		(root.get("screen") as InventoryScreen).selected = pick
		root.get("screen").call("_draw")
		await _shoot(tool, "%s_inventory_%s.png" % [out, pick])
		root.call("close_screen")
	root.call("open_screen", "rest", 0)
	await _shoot(tool, "%s_rest.png" % out)
	root.call("close_screen")
	var lw := LootWindow.new()
	add_child(lw)
	lw.show_loot(GameState.story, "chest", [{"id": "potion_of_poison", "qty": 1}, {"id": "armor_of_vulnerability_slashing__plate_armor", "qty": 1},
		{"id": "wand_of_secrets", "qty": 1}], 12.0, null)
	await _shoot(tool, "%s_loot.png" % out)
	lw.queue_free()
