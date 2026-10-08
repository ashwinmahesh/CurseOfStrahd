extends Node
## Lane 23 for captures (U11's trading half, F14): Bildrath's shop with its terms and a haggle won, St. Andral's
## services with a hero to raise, the Blue Water Inn's rooms, the Vistani trader and the book's other merchants. The
## party is four pregens at level 5 with gold to spend. LANE_ONLY=shop,haggle,services,rooms,trader,merchants,unlocked limits it.
## make capture SCENE=res://tools/capture/merchants_capture.tscn NAME=lane23/after FRAMES=10

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var root: Node
var _only: Array[String] = []


func _ready() -> void:
	# Anything the game saves while the capture runs goes to a folder of its own, never over the owner's saves.
	SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
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


func _shoot(tool: Node, path: String, frames: int = 8) -> void:
	await tool.call("wait_frames", frames)
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
	if _wants("services"):
		# St. Andral's: Ratatoille fell two days ago, Godrick is hurt and poisoned.
		var fallen := st.party[3]
		fallen.hp = 0
		fallen.dead = true
		Services.note_deaths(st, st.total_minutes())
		st.day += 2   # without the clock's fade, which would cover the shot
		st.party[0].hp = 9
		st.party[0].add_effect(Effect.new("Poisoned", &"monster", "capture_poison").with_condition(&"poisoned"))
		root.call("open_services", "father_lucian")
		await _shoot(tool, "%s_services_temple.png" % out)
		var sv := root.find_children("*", "ServicesScreen", false, false).back() as ServicesScreen
		sv.call("buy", "raise_dead")
		await _shoot(tool, "%s_services_raised.png" % out, 150)   # after "An hour later" fades
		_close("ServicesScreen")
	if _wants("rooms"):
		root.call("open_services", "urwin_martikov")
		await _shoot(tool, "%s_services_rooms.png" % out)
		_close("ServicesScreen")
	if _wants("trader"):
		root.call("open_shop", "vadoma")
		await _shoot(tool, "%s_trader_vadoma.png" % out)
		_close("ShopScreen")
	if _wants("merchants"):
		st.set_flag("coffin_spawn_destroyed")
		st.set_flag("winery_wine_flows")
		for npc: String in ["henrik", "arik", "davian_martikov"]:
			root.call("open_shop", npc)
			await _shoot(tool, "%s_merchant_%s.png" % [out, npc])
			_close("ShopScreen")
	if _wants("unlocked"):
		st.set_flag("keepers_allied")
		st.set_flag("rictavio_unmasked")
		st.set_flag("godfrey_remembers")
		for npc: String in ["urwin_martikov", "rictavio", "sir_godfrey_gwilym"]:
			root.call("open_shop", npc)
			await _shoot(tool, "%s_unlocked_%s.png" % [out, npc])
			_close("ShopScreen")
