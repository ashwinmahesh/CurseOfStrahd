extends Node
## make capture SCENE=res://tools/capture/skirmish_capture.tscn NAME=skirmish FRAMES=10
## Skirmish and the Character Lab (N1): the Add a hero page, the Lab with a level 14 hero and the item list, the foes,
## the field's map, the saved setups, then the fight on Vallaki's square at night and its results.

var screen: SkirmishScreen
var arena: CombatArena


func _ready() -> void:
	SkirmishLibrary.dir = "user://capture_skirmish/"
	SkirmishScreen.current = null
	SkirmishScreen.kept_tab = "Party"


func capture_shots(tool: Node, out: String) -> void:
	Dice.reseed(5)
	screen = (load("res://scenes/skirmish.tscn") as PackedScene).instantiate() as SkirmishScreen
	add_child(screen)
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_1_add.png")
	SkirmishScreen.add_level = 14
	screen.call("_add_pregen", "godrick_pendlebrook")
	screen.call("_add_pregen", "liriel_dawnsong")
	screen.call("_add_quick", "wizard")
	screen.call("_add_pregen", "wren_featherfoot")
	screen.call("_select_hero", 0)
	screen.call("_give", "flame_tongue")
	screen.call("_redraw")
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_2_lab.png")
	screen.tab = "Foes"
	screen.call("_redraw")
	for m: String in ["vampire", "vampire_spawn", "vampire_spawn", "werewolf", "werewolf", "wolf", "wolf"]:
		screen.call("_add_foe", m)
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_3_foes.png")
	screen.tab = "Field"
	screen.setup.map_id = "location:vallaki"
	screen.setup.time = "night"
	screen.call("_redraw")
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_4_field.png")
	screen.setup.title = "Night in Vallaki"
	SkirmishLibrary.save(screen.setup)
	screen.tab = "Saved"
	screen.call("_redraw")
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_5_saved.png")
	CombatArena.skirmish = screen.setup.duplicate_setup()
	screen.queue_free()
	await tool.call("wait_frames", 2)
	arena = (load("res://scenes/combat/arena.tscn") as PackedScene).instantiate() as CombatArena
	add_child(arena)
	await tool.call("wait_frames", 150)
	tool.call("_shot", out + "_6_fight.png")
	for c in arena.e.combatants:
		if c.side == &"enemy":
			arena.e.deal_damage(arena.e.combatants[0], c, [{"amount": 500, "type": "radiant"}], false, "capture")
	arena.e.call("_check_over")
	await tool.call("wait_frames", 30)
	arena.view.finished.emit(arena.e.outcome)
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_7_results.png")
	for f in SkirmishLibrary.list():
		SkirmishLibrary.delete(str(f["file"]))
