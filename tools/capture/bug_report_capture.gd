extends Node
## Report a bug (core/bug_reports.gd, dev builds) in a game at Vallaki: the pause menu with its Report a bug link, the
## report screen it opens (the picture is the game under the menu), the screen with words and a kind, sent, and F12's
## screen from exploring. Reports go to the capture's own folder, never the vault; the game is loaded in the capture's
## own save folder (tools/capture/capture.gd), so the owner's saves never show or change.
## make capture SCENE=res://tools/capture/bug_report_capture.tscn NAME=bug_report FRAMES=40

const GAME := "v2_vallaki.json"

var root: Node


func _ready() -> void:
	BugReports.current.dir = SaveSystem.save_dir.path_join("bug_reports")
	var out := FileAccess.open(SaveSystem.slot_path("capture_game"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + GAME))
	out.close()
	SaveSystem.load_slot("capture_game")
	SaveSystem.delete_slot("capture_game")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var reports := BugReports.current
	(root.get("hud") as ExploreHud).close_narration()
	root.call("open_screen", "menu", 0)
	await _shoot(tool, out + "_0_menu.png", 20)
	var menu := root.get("screen") as PauseMenu
	(menu.find_child("ReportBug", true, false) as Button).pressed.emit()
	await tool.call("wait_frames", 6)
	var screen := reports.screen
	await _shoot(tool, out + "_1_report.png", 20)
	screen.words.text = "The well in the square has no rope, but the quest says to climb down it.\nI walked all round it and found nothing to click."
	(screen.find_child("KindPlayswrong", true, false) as Button).button_pressed = true
	await _shoot(tool, out + "_2_written.png")
	screen.send()
	print("capture: report in ", screen.sent_to)
	DirAccess.copy_absolute(screen.sent_to.path_join("report.md"), out + "_report.md")   # the capture's folder goes when it ends
	await _shoot(tool, out + "_3_sent.png")
	screen.close()
	await _shoot(tool, out + "_4_menu_back.png", 20)
	root.call("close_screen")
	await tool.call("wait_frames", 20)
	reports.open()
	await _shoot(tool, out + "_5_f12.png", 20)
	reports.screen.close()
	await tool.call("wait_frames", 10)
