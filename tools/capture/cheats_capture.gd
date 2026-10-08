extends Node
## The pause menu's Cheat codes page (ui/screens/cheat_codes_page.gd, lane 27) over a late party: the menu with its
## link, a code given twice, a +1 Weapon with its weapon picked, and a Spell Scroll's spell. The game is loaded in the
## capture's own save folder (tools/capture/capture.gd), so the owner's saves never show or change.
## make capture SCENE=res://tools/capture/cheats_capture.tscn NAME=cheats FRAMES=30

const LATE := "v2_amber_temple.json"

var root: Node


func _ready() -> void:
	var out := FileAccess.open(SaveSystem.slot_path("capture_game"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + LATE))
	out.close()
	SaveSystem.load_slot("capture_game")
	SaveSystem.delete_slot("capture_game")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	(root.get("hud") as ExploreHud).close_narration()
	root.call("open_screen", "menu", 0)
	await _shoot(tool, out + "_0_menu.png", 20)
	var menu := root.get("screen") as PauseMenu
	menu.call("_open_cheats")
	var page := menu.find_children("*", "CheatCodesPage", true, false)[0] as CheatCodesPage
	await _shoot(tool, out + "_1_empty.png")
	page.type_code(CheatCodes.code_of("arrow").to_lower())
	(page.find_child("Give", true, false) as Button).pressed.emit()
	(page.find_child("Give", true, false) as Button).pressed.emit()
	await _shoot(tool, out + "_2_arrows.png")
	page.type_code(CheatCodes.code_of("weapon_plus_1"))
	page.pick("weapon_plus_1__rapier")
	await _shoot(tool, out + "_3_weapon.png")
	page.type_code(CheatCodes.code_of("spell_scroll"))
	page.pick("spell_scroll__fireball")
	await _shoot(tool, out + "_4_scroll.png")
	page.type_code("ABCDEF")
	await _shoot(tool, out + "_5_unknown.png")
	root.call("close_screen")
