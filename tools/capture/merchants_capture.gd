extends Node
## Lane 23 for captures (U11's trading half, F14): Bildrath's shop with its terms and a haggle won, St. Andral's
## services with a hero to raise, the Blue Water Inn's rooms, the Vistani trader and the book's other merchants. The
## party is four pregens at level 5 with gold to spend. LANE_ONLY=shop,haggle,services,rooms,trader,merchants limits it.
## make capture SCENE=res://tools/capture/merchants_capture.tscn NAME=lane23/after FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node
var _only: Array[String] = []


func _ready() -> void:
	for s in OS.get_environment("LANE_ONLY").split(",", false):
		_only.append(s.strip_edges())
	Compendium.shared().tables["locations"]["lane_town"] = {"id": "lane_town", "name": "Vallaki", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "lane_town"
	GameState.story.gold = 2840.0
	GameState.story.playthrough_seed = 23
	var godrick := GameState.story.party[0]
	for it: Array in [["longsword", 1], ["shield", 1], ["mirror", 1], ["candle", 4]]:
		godrick.add_item(str(it[0]), int(it[1]))
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _wants(what: String) -> bool:
	return _only.is_empty() or what in _only


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 8)
	tool.call("_shot", path)


func _close(kind: String) -> void:
	for n in root.find_children("*", kind, false, false):
		root.remove_child(n)
		n.queue_free()


func capture_shots(tool: Node, out: String) -> void:
	var st := GameState.story
	if _wants("shop"):
		root.call("open_shop", "bildrath")
		await _shoot(tool, "%s_shop_bildrath.png" % out)
		_close("ShopScreen")
	if _wants("haggle"):
		# A friendly merchant, haggled with: the terms row and the purse after a purchase.
		st.attitudes["gunther_arasek"] = "friendly"
		st.set_flag("_haggle_won/gunther_arasek", true)
		root.call("open_shop", "gunther_arasek")
		var shop := root.find_child("ShopScreen", true, false) as ShopScreen
		if shop != null:
			shop.call("_buy", "longsword")
		await _shoot(tool, "%s_shop_haggled.png" % out)
		_close("ShopScreen")
		root.call("open_shop", "blinsky")
		var toys := root.find_child("ShopScreen", true, false) as ShopScreen
		if toys != null:
			toys.index = 2
			toys.call("haggle")
		await _shoot(tool, "%s_shop_haggle_roll.png" % out)
		_close("ShopScreen")
		st.attitudes["bildrath"] = "hostile"
		root.call("open_shop", "bildrath")
		await _shoot(tool, "%s_shop_hostile.png" % out)
		_close("ShopScreen")
		st.attitudes.erase("bildrath")
