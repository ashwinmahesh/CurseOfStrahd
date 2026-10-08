class_name CombatArena
extends Node3D
## Phase 2 exit scene (plan §9): the arena fight of the four level 3 pregens against Barovian wolves and zombies,
## on the grid, with the combat HUD (docs/ui/combat_view.md). Builds the board, tokens and camera from
## data/encounters/arena_wolves_and_zombies.json and hands the fight to a CombatView. Built in code; the .tscn is a
## thin root.
## It also plays Skirmish fights (N1): with `skirmish` set, the fight is that setup's, on its map dressed as the place
## (SkirmishField), and it ends on the results (SkirmishResults: fight again, change the setup, or the title).

const ENCOUNTER_ID := "arena_wolves_and_zombies"
const SKIRMISH_SCENE := "res://scenes/skirmish.tscn"
const TITLE_SCENE := "res://scenes/main_menu.tscn"

## The Skirmish fight to play next, handed over by the Skirmish screen (the scene takes it and clears it); null plays
## the Phase 2 arena.
static var skirmish: SkirmishSetup = null

var e: Encounter
var board: ArenaBoard
var rig: CameraRig
var post: MeshInstance3D
var tokens: Dictionary = {}
var view: CombatView
## The pause menu while it's open (Escape): resume, load a save, or quit to the title. The fight waits meanwhile.
var screen: CanvasLayer = null   ## the pause menu, or a character sheet (view only)
## The Skirmish setup this fight is playing (null for the Phase 2 arena).
var played: SkirmishSetup = null
## A Skirmish fight on a location's map: the place's light and weather (null on the arena map).
var atmosphere: Atmosphere = null
## The end of a Skirmish fight, once it's showing.
var results: SkirmishResults = null


func _ready() -> void:
	var capture := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			capture = true
			Dice.reseed(2)   # run by the capture tool: repeatable dice
	InputActions.ensure()
	GameState.current_scene = scene_file_path
	ModeController.force(ModeController.Mode.COMBAT)
	var errors: Array[String] = []
	var surprised: Array[String] = []
	played = skirmish
	skirmish = null
	if played != null:
		e = played.build(Dice.roller, errors)
		if e == null:
			push_warning("Skirmish: %s" % ", ".join(errors))
			get_tree().change_scene_to_file.call_deferred(SKIRMISH_SCENE)
			return
		var entry := SkirmishSetup.map_entry(played.map_id)
		var place := str(entry["place"])
		board = ArenaBoard.build(e.grid, ArenaBoard.theme_for(entry["map"] as Dictionary), place)
		add_child(board)
		atmosphere = SkirmishField.dress(self, board, place, played.location(), played.time)
		if atmosphere == null:
			build_environment(self)
		surprised = played.surprised_ids(e)
	else:
		build_environment(self)
		e = EncounterSetup.load_id(ENCOUNTER_ID, Dice.roller, errors)
		assert(e != null, str(errors))
		board = ArenaBoard.build(e.grid)
		add_child(board)
		surprised = EncounterSetup.surprised_ids(Compendium.shared().get_entry("encounters", ENCOUNTER_ID), e)
	for c in e.combatants:
		var t := CombatToken.create(c)
		t.position = board.cell_center(c.cell, c.size_cells)
		t.face(Vector2(1, 0) if c.side == &"party" else Vector2(-1, 0), false)
		add_child(t)
		tokens[c.id] = t
	rig = CameraRig.new()
	add_child(rig)
	rig.zoom_max = 30.0
	rig.distance = 14.0
	rig.rotate_step(-1)   # look north-east: the party bottom-left, the enemies up the screen
	rig.camera.current = true
	post = Look.make_post_process()
	rig.camera.add_child(post)
	if atmosphere != null:
		atmosphere.attach(rig, post)
	_carry_lantern()
	view = CombatView.new()
	view.restart_allowed = played == null
	view.input_locked = capture
	add_child(view)
	if played != null:
		view.finished.connect(_skirmish_over)
	view.begin(e, board, rig, tokens, surprised)
	view.menu_requested.connect(toggle_menu)
	view.sheet_requested.connect(open_sheet)
	rig.snap_to_target()


## In the dark the first hero carries the party's lantern (its light is in the rules too: SkirmishSetup._light).
func _carry_lantern() -> void:
	if played == null or e.ambient_light == "bright":
		return
	for c in e.combatants:
		if c.side == &"party":
			var lantern := OmniLight3D.new()
			lantern.name = "Lantern"
			lantern.light_color = Look.color("candle")
			lantern.omni_range = 7.0
			lantern.light_energy = 2.4
			lantern.position = Vector3(0, 1.6, 0)
			(tokens[c.id] as Node3D).add_child(lantern)
			return


## The Skirmish fight is over and the player went on from the banner: the results, and where to next.
func _skirmish_over(_outcome: String) -> void:
	if results != null:
		return
	results = SkirmishResults.new()
	add_child(results)
	var earned: Array[String] = []
	for id in Achievements.grant(Achievements.for_skirmish(played, e, FightTally.tally(e))):
		earned.append(Achievements.name_of(id))
	results.show_for(e, played.title, earned)
	results.again.connect(func() -> void:
		skirmish = played
		Dice.reseed_random()
		get_tree().reload_current_scene())
	results.change_setup.connect(func() -> void: get_tree().change_scene_to_file(SKIRMISH_SCENE))
	results.to_title.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


## Escape (nothing selected) opens the pause menu, as in the story game; Escape again closes it.
func toggle_menu() -> void:
	if screen != null:
		close_screen()
		return
	var menu := PauseMenu.new()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu)
	menu.open(self, GameState.story, 0)
	screen = menu
	get_tree().paused = true


## A hero's character sheet, view only, while the fight waits (owner, 2026-10-08): the party's sheets, flipped through
## with the arrows as in the story game.
func open_sheet(who: Character) -> void:
	if screen != null:
		return
	var st := StoryState.new()
	for c in e.combatants:
		if c.side == &"party" and c.creature is Character and not EchoKnight.is_echo(c):
			st.party.append(c.creature as Character)
	if not st.party.has(who):
		return
	var sheet := CharacterSheetScreen.new()
	sheet.in_fight = true
	sheet.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sheet)
	sheet.open(self, st, st.party.find(who))
	screen = sheet
	get_tree().paused = true


## The pause menu or a sheet calls this to close itself (Resume, Escape).
func close_screen() -> void:
	get_tree().paused = false
	if screen != null:
		screen.queue_free()
		screen = null


func _unhandled_input(event: InputEvent) -> void:
	# Once the fight is over the view no longer takes Escape, so the menu opens from here.
	if screen == null and results == null and view != null and view.mode == CombatView.Mode.OVER and event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		toggle_menu()


## Night sky, fog and moonlight for a fight outdoors.
static func build_environment(root: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Look.color("night_deep")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("mist_blue")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Look.color("grave")
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Look.color("moonlight")
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 35, 0)
	root.add_child(moon)


## For the capture tool.
func capture_shots(tool: Node, out: String) -> void:
	await view.capture_shots(tool, out)


func debug_move_leader(point: Vector3) -> void:
	view.debug_move_leader(point)
