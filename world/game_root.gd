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
var _dialogue_ref := ""
var menu: ContextMenu                ## the right-click menu on things in the world
var _menu_cell := Vector2i(-1, -1)


func _ready() -> void:
	InputActions.ensure()
	GameState.current_scene = "res://scenes/game.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--load="):
			SaveSystem.load_slot(a.get_slice("=", 1))   # captures: start from a save
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
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 25
	add_child(menu_layer)
	menu = ContextMenu.new()
	menu.picked.connect(func(id: String) -> void: world_action(_menu_cell, id))
	menu_layer.add_child(menu)
	var where := st.location if st.location != "" else FIRST_LOCATION
	var spawn := "" if st.location == where else "default"
	# Captures (tools/capture) may start anywhere: --location=<id> [--spawn=<name>].
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):
			where = a.get_slice("=", 1)
			spawn = "default"
		elif a.begins_with("--spawn="):
			spawn = a.get_slice("=", 1)
	enter_location(where, spawn)
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
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var at := (event as InputEventMouseButton).position
		open_world_menu(GridPick.cell_under(view.rig.camera, view.grid, at), at)
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
			JOY_BUTTON_BACK:
				_menu_nearby()
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


## The right-click menu for a square: what can be done with the person, thing, party member or floor there.
func open_world_menu(cell: Vector2i, at: Vector2) -> void:
	if cell.x < 0 or view.busy:
		return
	var m := view.actions_at(cell)
	if (m["actions"] as Array).is_empty():
		return
	_menu_cell = cell
	var items: Array[Dictionary] = []
	items.assign(m["actions"] as Array)
	menu.show_actions(str(m["title"]), items, at)


## Controller Back: the menu for the nearest thing beside the leader, at the middle of the screen.
func _menu_nearby() -> void:
	var c := view.leader().cell
	for d: Vector2i in [Vector2i.ZERO] + CombatGrid.DIRS:
		if not view.thing_at(c + d).is_empty():
			open_world_menu(c + d, get_viewport().get_visible_rect().size / 2.0)
			return
	hud.toast("Nothing to use here")


func world_action(cell: Vector2i, id: String) -> void:
	var parts := id.split(":")
	match parts[0]:
		"lead":
			view.set_leader(int(parts[1]))
			_refresh()
		"sheet":
			open_screen("sheet", int(parts[1]))
		"inventory":
			open_screen("inventory", int(parts[1]))
		"spells":
			open_screen("sheet", int(parts[1]))
			(screen as CharacterSheetScreen).show_tab("Spells")
		"trade":
			var thing := view.thing_at(cell)
			if not thing.is_empty():
				open_shop(str((thing["spec"] as Dictionary)["npc"]))
		_:
			view.act(cell, id)


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

## A merchant's shop; `from_dialogue` resumes the conversation when it closes.
func open_shop(npc_id: String, from_dialogue: bool = false) -> void:
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_for(self, st, npc_id)
	shop.closed.connect(func() -> void:
		_refresh()
		if from_dialogue and dialogue != null:
			dialogue.resume())


func start_dialogue(ref: String, _npc_id: String) -> void:
	if ref == "" or dialogue != null:
		return
	ModeController.force(ModeController.Mode.DIALOGUE)
	_dialogue_ref = ref
	hud.visible = false
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.ended.connect(_dialogue_ended)
	dialogue.shop_requested.connect(func(npc: String) -> void: open_shop(npc, true))
	var runner := DialogueRunner.new(st, Dice.roller, narrator)
	runner.npc_id = _npc_id
	if not dialogue.play(runner, ref):
		dialogue.queue_free()
		dialogue = null
		hud.visible = true
		ModeController.force(ModeController.Mode.EXPLORATION)


func _dialogue_ended(combat: String) -> void:
	dialogue = null
	hud.visible = true
	if view.guest_members.size() != st.guests.size():
		view.place_guests()
	ModeController.force(ModeController.Mode.EXPLORATION)
	view.refresh_npcs()
	_refresh()
	if combat != "":
		view.hide_npcs_of(_dialogue_ref)
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


## Plays a Narrator trigger here (rests, dreams). Returns the line, or "".
func narrate_key(key: String) -> String:
	if view == null:
		return ""
	var text := narrator.line(key, st, st.leader_character())
	if text != "":
		hud.narrate(text)
	return text


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


# --- Captures -------------------------------------------------------------------------------------

## The capture tool's sequence (make capture SCENE=res://scenes/game.tscn): exploring, a conversation at its first
## choice, then each party screen.
func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_1_explore.png")
	# The right-click menu on the nearest door, person or thing.
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for x in view.grid.width:
		for y in view.grid.depth:
			var cell := Vector2i(x, y)
			var k := str(view.thing_at(cell).get("kind", ""))
			if k in ["door", "npc", "container"]:
				var d := view.grid.distance_ft(view.leader().cell, 1, cell, 1)
				if d < best_d:
					best_d = d
					best = cell
	if best.x >= 0:
		var at := view.rig.camera.unproject_position(view.board.cell_center(best) + Vector3(0, 0.6, 0))
		open_world_menu(best, at)
		await tool.call("wait_frames", 8)
		tool.call("_shot", out + "_1b_menu.png")
		menu.hide()
	var shown := view.get("_npc_shown") as Array
	if not shown.is_empty():
		var spec := (shown[0] as Dictionary)["spec"] as Dictionary
		start_dialogue(str(spec.get("dialogue", "")), str(spec["npc"]))
		for i in 30:
			if dialogue == null or not dialogue.options_shown.is_empty():
				break
			dialogue.call("_advance")
			await tool.call("wait_frames", 2)
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_2_dialogue.png")
		if dialogue != null:
			dialogue.queue_free()
			dialogue = null
		hud.visible = true
		ModeController.force(ModeController.Mode.EXPLORATION)
	# --encounter=<id>: the fight in place, a few turns in.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--encounter=") and view.start_encounter(a.get_slice("=", 1)):
			await tool.call("wait_frames", 240)
			tool.call("_shot", out + "_2b_fight.png")
			return
	var n := 3
	for kind: String in ["sheet", "inventory", "journal", "party", "rest"]:
		open_screen(kind, 2 if kind == "sheet" else 0)
		if kind == "sheet":
			(screen as CharacterSheetScreen).show_tab("Spells")
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_%d_%s.png" % [n, kind])
		n += 1
	close_screen()
