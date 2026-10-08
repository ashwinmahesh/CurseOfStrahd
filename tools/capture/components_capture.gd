extends Node
## Costly material components for sale (owner's pick, 2026-10-08): Father Lucian's Diamonds, Diamond Dust and Incense,
## and Bildrath's Incense, dusts, Pearl and Onyx, each with its icon.
## make capture SCENE=res://tools/capture/components_capture.tscn NAME=components FRAMES=10

var root: Node


func _ready() -> void:
	# Anything the game saves while the capture runs goes to a folder of its own, never over the owner's saves.
	SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
	Compendium.shared().tables["locations"]["components_town"] = {"id": "components_town", "name": "Vallaki", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["liriel_dawnsong", "ratatoille"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "components_town"
	GameState.story.gold = 900.0
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shop(tool: Node, npc: String, path: String) -> void:
	root.call("open_shop", npc)
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)
	for n in root.find_children("*", "ShopScreen", false, false):
		root.remove_child(n)
		n.queue_free()


func capture_shots(tool: Node, out: String) -> void:
	await _shop(tool, "father_lucian", out + "_1_father_lucian.png")
	await _shop(tool, "bildrath", out + "_2_bildrath.png")
