extends Node
## Lane 13's shots (Settings and HUD): Settings' Game, Display and Keys pages (a key just moved), the exploring HUD's
## party frames with their resources and conditions at three interface sizes (U4, U9), a conversation at the normal
## and the largest text size (U4), and the journal's Bestiary (U8). The party is the level 9 one from the Amber Temple
## golden save, read straight from tests/saves (nothing is written to the player's saves), and the settings this run
## changes go to a file of its own, removed at the end. Last, the party in a fight: what's working on each of them as
## icons on the combat HUD's frames too.
## make capture SCENE=res://tools/capture/settings_capture.tscn NAME=settings/shot FRAMES=10

const SAVE := "res://tests/saves/v2_amber_temple.json"
const SETTINGS := "user://capture_settings.cfg"

var root: Node

## A room for the fight shot (not saved anywhere: the Compendium only holds it for this run).
const WARD := {
	"id": "capture_ward", "name": "Capture Ward", "region": "test", "summary": "A capture fixture.",
	"map": {"rows": ["############", "#..........#", "#..........#", "#..........#", "#..........#", "############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rats", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [9, 3]}, {"monster": "rat", "cell": [9, 4]}]}],
}


func _ready() -> void:
	GameSettings.path = SETTINGS   # never the player's own settings
	GameState.reset()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	GameState.from_dict(SaveSystem.upgrade(data as Dictionary))
	var st := GameState.story
	# Something on each of them, for the party frames (U9).
	st.party[0].add_condition(&"poisoned")
	st.party[1].slots_used[0] = 2
	st.party[1].slots_used[2] = 1
	for res_id: String in st.party[2].resources:
		st.party[2].spend_resource(res_id)
		break
	st.party[3].concentration = Concentration.new(st.party[3], "bless", "Bless")
	st.party[3].hp = int(st.party[3].max_hp() * 0.4)
	# Abilities switched on and spells on them, for the effect icons.
	st.party[0].add_effect(Effect.new("Rage", &"feature", "rage").lasting_rounds(9))
	st.party[0].add_effect(Effect.new("Bless", &"spell", "bless").lasting_rounds(7))
	st.party[2].add_effect(Effect.new("Vow of Enmity", &"feature", "vow_of_enmity").lasting_rounds(10))
	st.party[2].add_effect(Effect.new("Sacred Weapon", &"feature", "sacred_weapon").lasting_rounds(10))
	st.party[3].add_effect(Effect.new("Bladesong", &"feature", "bladesong").lasting_rounds(10))
	st.party[3].add_effect(Effect.new("Mage Armor", &"spell", "mage_armor"))
	# A bestiary as a party at the Amber Temple might have it (U8).
	var n := 0
	for m: Array in [["wolf", 1, 3, true], ["zombie", 1, 5, false], ["strahd_zombie", 2, 2, false],
			["vampire_spawn", 4, 2, true], ["werewolf", 6, 0, false], ["strahd_von_zarovich", 3, 0, false]]:
		if not Compendium.shared().monster_data(str(m[0])).is_empty():
			st.bestiary[str(m[0])] = {"n": n, "met": int(m[1]), "where": "village_of_barovia", "defeated": int(m[2]),
				"studied": bool(m[3])}
			n += 1
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	await tool.call("wait_frames", 30)
	hud.close_narration()
	# Settings' three pages; on Keys, the journal moved onto C (the character sheet takes J in exchange).
	for page: String in PauseMenu.SETTINGS_PAGES:
		root.call("open_screen", "menu", 0)
		await tool.call("wait_frames", 2)
		var menu := root.get("screen") as PauseMenu
		menu.call("_show_settings", page)
		if page == "Keys":
			await tool.call("wait_frames", 2)
			var keys := menu.find_children("*", "KeysPage", true, false)[0] as KeysPage
			keys.call("_wait", &"open_journal", 0)
			keys.press(KEY_C)
		await _shoot(tool, "%s_settings_%s.png" % [out, page.to_lower()])
		root.call("close_screen")
	await _shoot(tool, "%s_hud_keys_moved.png" % out)
	InputActions.reset()
	# The party frames at three interface sizes.
	for size: float in [1.0, 0.85, 1.2]:
		GameSettings.set_ui_scale(size)
		UiScale.apply()
		root.call("_refresh")
		await _shoot(tool, "%s_hud_%d.png" % [out, roundi(size * 100.0)], 20)
	GameSettings.set_ui_scale(1.0)
	UiScale.apply()
	# A conversation at the normal and the largest text size.
	for text: float in [1.0, GameSettings.TEXT_SCALES.back()]:
		GameSettings.set_text_scale(text)
		root.call("start_dialogue", "village_of_barovia/ismark:start", "ismark")
		await _shoot(tool, "%s_talk_text_%d.png" % [out, roundi(text * 100.0)], 30)
		var d := root.get("dialogue") as Node
		if d != null:
			d.queue_free()
			root.call("_dialogue_ended", "")
		await tool.call("wait_frames", 5)
	GameSettings.set_text_scale(1.0)
	# The bestiary, on a creature the party has studied.
	root.call("open_screen", "journal", 0)
	await tool.call("wait_frames", 2)
	var j := root.get("screen") as JournalScreen
	j.tab = "Bestiary"
	j.beast = "vampire_spawn"
	j.call("_draw")
	await _shoot(tool, "%s_bestiary_studied.png" % out)
	j.beast = "zombie"
	j.call("_draw")
	await _shoot(tool, "%s_bestiary_felled.png" % out)
	root.call("close_screen")
	# The same party in a fight: the effect icons on the combat HUD's frames.
	Compendium.shared().tables["locations"]["capture_ward"] = WARD.duplicate(true)
	root.call("enter_location", "capture_ward", "default")
	await tool.call("wait_frames", 20)
	(root.get("view") as LocationView).start_encounter("rats")
	await _shoot(tool, "%s_combat_effects.png" % out, 90)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
