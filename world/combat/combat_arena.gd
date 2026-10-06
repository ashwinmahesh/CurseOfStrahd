extends Node3D
## Phase 2 exit scene (plan §9): the arena fight of the four level 3 pregens against Barovian wolves and zombies,
## on the grid, with the combat HUD (docs/ui/combat_view.md). Builds the board, tokens and camera from
## data/encounters/arena_wolves_and_zombies.json and hands the fight to a CombatView. Built in code; the .tscn is a
## thin root.

const ENCOUNTER_ID := "arena_wolves_and_zombies"

var e: Encounter
var board: ArenaBoard
var rig: CameraRig
var post: MeshInstance3D
var tokens: Dictionary = {}
var view: CombatView
## The pause menu while it's open (Escape): resume, load a save, or quit to the title. The fight waits meanwhile.
var screen: PauseMenu = null


func _ready() -> void:
	var capture := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			capture = true
			Dice.reseed(2)   # run by the capture tool: repeatable dice
	InputActions.ensure()
	GameState.current_scene = scene_file_path
	ModeController.force(ModeController.Mode.COMBAT)
	build_environment(self)
	var errors: Array[String] = []
	e = EncounterSetup.load_id(ENCOUNTER_ID, Dice.roller, errors)
	assert(e != null, str(errors))
	board = ArenaBoard.build(e.grid)
	add_child(board)
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
	view = CombatView.new()
	view.restart_allowed = true
	view.input_locked = capture
	add_child(view)
	var surprised := EncounterSetup.surprised_ids(Compendium.shared().get_entry("encounters", ENCOUNTER_ID), e)
	view.begin(e, board, rig, tokens, surprised)
	view.menu_requested.connect(toggle_menu)
	rig.snap_to_target()


## Escape (nothing selected) opens the pause menu, as in the story game; Escape again closes it.
func toggle_menu() -> void:
	if screen != null:
		close_screen()
		return
	screen = PauseMenu.new()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen)
	screen.open(self, GameState.story, 0)
	get_tree().paused = true


## The pause menu calls this to close itself (Resume, Escape).
func close_screen() -> void:
	get_tree().paused = false
	if screen != null:
		screen.queue_free()
		screen = null


func _unhandled_input(event: InputEvent) -> void:
	# Once the fight is over the view no longer takes Escape, so the menu opens from here.
	if screen == null and view != null and view.mode == CombatView.Mode.OVER and event.is_action_pressed(&"combat_cancel"):
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
