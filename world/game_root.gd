extends Node
## The story game (scenes/game.tscn, plan §10 Phase 3): the current location, the exploration HUD, conversations,
## loot, the party screens (sheet, inventory, journal, rest, party, level up), saving and loading, and the way from
## one location to the next. GameState.story holds everything; this node only shows it and routes input.

const FIRST_LOCATION := "into_the_mists_road"

var st: StoryState
var narrator: Narrator
var banter: Banter
var view: LocationView
var hud: ExploreHud
var screen: Node = null              ## the open full-screen panel (sheet, inventory ...), if any
var dialogue: DialogueUI = null
var loot: LootWindow = null
var _hover := Vector2i(-1, -1)
var _move_repeat := 0.0


func _ready() -> void:
	InputActions.ensure()
	GameState.current_scene = "res://scenes/game.tscn"
	st = GameState.story
	narrator = Narrator.new()
	banter = Banter.new()
	if st.party.is_empty():
		_new_pregen_party()
	hud = ExploreHud.new()
	add_child(hud)
	hud.build(st)
	hud.leader_picked.connect(func(i: int) -> void:
		if view != null:
			view.set_leader(i)
		_refresh())
	hud.sheet_requested.connect(func(i: int) -> void: open_screen("sheet", i))
	hud.command.connect(_command)
	var where := st.location if st.location != "" else FIRST_LOCATION
	enter_location(where, "" if st.location == where else "default")
	# A round-start save puts the party back into its fight.
	var snap := GameState.combat_snapshot
	if not snap.is_empty() and str(snap.get("location", "")) == where:
		view.resume_encounter.call_deferred(snap)


## A quick start: the four pregens at level 1 (plan §5.6 Start step). The full creator replaces this in the menu.
func _new_pregen_party() -> void:
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	st.gold = 10.0


func enter_location(location_id: String, spawn: String) -> void:
	if view != null:
		view.queue_free()
		view = null
	ModeController.force(ModeController.Mode.EXPLORATION)
	view = LocationView.create(location_id, st, narrator, Dice.roller, spawn)
	view.banter_player = banter
	view.banter.connect(func(lines: Array) -> void:
		var text: Array[String] = []
		for l: Variant in lines:
			var d := l as Dictionary
			text.append(str(d["text"]) if bool(d["narrator"]) else "%s: %s" % [str(d["name"]).get_slice(" ", 0), d["text"]])
		hud.narrate("\n".join(text)))
	view.exit_requested.connect(func(to: String, sp: String) -> void: enter_location.call_deferred(to, sp))
	view.dialogue_requested.connect(start_dialogue)
	view.narration.connect(func(t: String) -> void: hud.narrate(t))
	view.toast.connect(func(t: String) -> void: hud.toast(t))
	view.check_rolled.connect(func(t: String) -> void: hud.roll(t))
	view.loot_opened.connect(_open_loot)
	view.combat_started.connect(func(_v: CombatView) -> void: hud.visible = false)
	view.combat_ended.connect(_after_combat)
	add_child(view)
	_refresh()


func _refresh() -> void:
	if view == null:
		return
	hud.refresh(str(view.loc.get("name", "")), view.sneaking, view.solo)


# --- Input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if view == null or view.in_combat or dialogue != null:
		return
	if screen != null:
		if event.is_action_pressed(&"combat_cancel"):
			close_screen()
			get_viewport().set_input_as_handled()
		return
	if loot != null:
		return
	if event is InputEventMouseMotion:
		var pick := GridPick.cell_under(view.rig.camera, view.grid, (event as InputEventMouseMotion).position)
		_hover = pick
		var thing := view.thing_at(pick) if pick.x >= 0 else {}
		hud.hint(str(thing.get("label", "")), (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var cell := GridPick.cell_under(view.rig.camera, view.grid, (event as InputEventMouseButton).position)
		if cell.x >= 0:
			view.click(cell)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).physical_keycode:
			KEY_C:
				open_screen("sheet", 0)
			KEY_I:
				open_screen("inventory", 0)
			KEY_J:
				open_screen("journal", 0)
			KEY_P:
				open_screen("party", 0)
			KEY_R:
				open_screen("rest", 0)
			KEY_F:
				view.search()
			KEY_V:
				_command("sneak")
			KEY_G:
				_command("split")
			KEY_ESCAPE:
				open_screen("menu", 0)
			KEY_F5:
				_quick_save()
			KEY_F9:
				_quick_load()
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_interact_nearby()
			JOY_BUTTON_X:
				view.search()
			JOY_BUTTON_Y:
				open_screen("journal", 0)
			JOY_BUTTON_START:
				open_screen("menu", 0)
			JOY_BUTTON_LEFT_SHOULDER:
				open_screen("sheet", 0)
			JOY_BUTTON_RIGHT_SHOULDER:
				open_screen("inventory", 0)
	if event.is_action_pressed(&"cycle_leader"):
		view.set_leader(1)
		_refresh()
	for i in 4:
		if event.is_action_pressed(StringName("select_member_%d" % (i + 1))):
			view.set_leader(i)
			_refresh()


func _process(delta: float) -> void:
	if view == null or view.in_combat or dialogue != null or screen != null or loot != null:
		return
	var v := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if v.length() < 0.3:
		_move_repeat = 0.0
		return
	_move_repeat -= delta
	if _move_repeat > 0.0:
		return
	_move_repeat = 0.16
	var b := view.rig.ground_basis()
	var w := b[0] * -v.y + b[1] * v.x
	view.step(Vector2i(roundi(w.x), roundi(w.z)))


## Controller A: use the nearest interactable within a square of the leader.
func _interact_nearby() -> void:
	var c := view.leader().cell
	for d: Vector2i in [Vector2i.ZERO] + CombatGrid.DIRS:
		var thing := view.thing_at(c + d)
		if not thing.is_empty() and str(thing["kind"]) != "exit":
			view.interact(thing)
			return
	hud.toast("Nothing to use here")


func _command(name_: String) -> void:
	match name_:
		"sneak":
			view.sneaking = not view.sneaking
			hud.toast("Sneaking" if view.sneaking else "Walking normally")
		"split":
			view.solo = not view.solo
			hud.toast("Only %s moves" % st.party[0].name if view.solo else "The party moves together")
		"search":
			view.search()
		_:
			open_screen(name_, 0)
	_refresh()


# --- Conversations, loot, fights ------------------------------------------------------------------

func start_dialogue(ref: String, _npc_id: String) -> void:
	if ref == "" or dialogue != null:
		return
	ModeController.force(ModeController.Mode.DIALOGUE)
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.ended.connect(_dialogue_ended)
	if not dialogue.play(DialogueRunner.new(st, Dice.roller, narrator), ref):
		dialogue.queue_free()
		dialogue = null
		ModeController.force(ModeController.Mode.EXPLORATION)


func _dialogue_ended(combat: String) -> void:
	dialogue = null
	ModeController.force(ModeController.Mode.EXPLORATION)
	view.refresh_npcs()
	_refresh()
	if combat != "":
		view.start_encounter(combat)
	else:
		view.check_flag_encounters()


func _open_loot(container_id: String, items: Array, gold: float) -> void:
	loot = LootWindow.new()
	add_child(loot)
	loot.closed.connect(func() -> void:
		loot = null
		_refresh())
	loot.show_loot(st, container_id, items, gold, view)


func _after_combat(outcome: String) -> void:
	hud.visible = true
	if outcome == "defeat":
		open_screen("game_over", 0)
		return
	view.refresh_npcs()
	_refresh()


# --- Screens --------------------------------------------------------------------------------------

func open_screen(kind: String, index: int) -> void:
	close_screen()
	match kind:
		"sheet":
			screen = CharacterSheetScreen.new()
		"inventory":
			screen = InventoryScreen.new()
		"journal":
			screen = JournalScreen.new()
		"party":
			screen = PartyScreen.new()
		"rest":
			screen = RestScreen.new()
		"menu":
			screen = PauseMenu.new()
		"game_over":
			screen = PauseMenu.new()
			(screen as PauseMenu).game_over = true
		"level_up":
			screen = LevelUpScreen.new()
		_:
			return
	add_child(screen)
	screen.call("open", self, st, index)


func close_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	_refresh()


## Rebuilds the current location (after a rest or level up changes what's shown).
func rebuild() -> void:
	enter_location(st.location, "")


func _quick_save() -> void:
	var err := SaveSystem.save("quick")
	hud.toast("Saved." if err == OK else "Can't save now.")


func _quick_load() -> void:
	if SaveSystem.load_slot("quick") == OK:
		get_tree().reload_current_scene()
	else:
		hud.toast("No quick save yet.")
