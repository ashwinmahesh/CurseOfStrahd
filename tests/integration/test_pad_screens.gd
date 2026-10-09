extends TestCase
## Every screen on a pad (U6, docs/ui/controller.md), over a late party: one press puts focus on the screen, the
## D-pad reaches every choice on it from there, and B goes back. Driven by synthetic pad events (PadNav); the
## reachability walk uses PadNav's own neighbour rule, so a choice it can't reach is one a player couldn't either.

const LATE := "v2_amber_temple.json"

var root: Node
var nav: PadNav
func before_each() -> void:
	InputActions.ensure()
	nav = PadNav.current
	nav.reset()


func after_each() -> void:
	nav.reset()
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game, loaded from golden save `f`.
func _game(f: String) -> bool:
	var path := GoldenSaves.DIR + f
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("pad"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(path))
	out.close()
	assert_eq(SaveSystem.load_slot("pad"), OK, "%s loads" % f)
	SaveSystem.delete_slot("pad")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	(root.get("hud") as ExploreHud).close_narration()
	await _frames(1)
	return true


## A press through the engine's Input, as a real pad sends it (pop-up menus read Input's state for the D-pad).
func _press_real(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
	await _frames(2)


func _press(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		get_viewport().push_input(ev)
	await _frames(2)


static func _describe(c: Control) -> String:
	var t := ""
	if c is Button:
		t = (c as Button).text
	elif c is Label:
		t = (c as Label).text
	return "%s%s (%s)" % [c.name, (" \"%s\"" % t.left(24)) if t != "" else "", c.get_class()]


## Checks the screen in front: focus lands on it with one press, and every choice is reachable from there. A screen
## with nothing to choose (`nothing`, a rest where there's no resting) only needs B.
func _reach(what: String, nothing: bool = false) -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_UP)
	var scope := nav.scope_now()
	if scope == null:
		if not nothing:
			fail("%s: no screen in front for the pad" % what)
		return
	var start := nav.focus_in(scope)
	if start == null:
		fail("%s: a press put focus nowhere on it" % what)
		return
	var list := PadNav.choices(scope)
	var seen := {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var c: Control = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if d.y == 0 and (c is Range or c.has_method(&"pad_adjust") or c.has_meta(&"pad_adjust")):
				continue
			var n := PadNav.neighbour(c, d, list)
			if n != null and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var missed: Array[String] = []
	for c in list:
		if not seen.has(c):
			missed.append(_describe(c))
	if not missed.is_empty():
		fail("%s: %d of %d choices out of the D-pad's reach: %s" % [what, missed.size(), list.size(), ", ".join(missed.slice(0, 12))])
	print("  %s: %d choices, first %s" % [what, list.size(), _describe(start)])


## B leaves: the screen `kind` is gone from game_root (or `gone` says it went).
func _back(what: String, gone: Callable) -> void:
	await _press(JOY_BUTTON_B)
	await _frames(2)
	if not bool(gone.call()):
		fail("%s: B didn't go back" % what)


func _screen_gone() -> bool:
	return root.get("screen") == null


func test_the_party_screens() -> void:
	if not await _game(LATE):
		return
	for kind: String in ["sheet", "inventory", "journal", "party", "roster", "rest", "wait", "menu"]:
		root.call("open_screen", kind, 0)
		await _frames(3)
		await _reach("the %s" % kind, kind == "rest")   # the Amber Temple is no place to rest
		await _back("the %s" % kind, _screen_gone)
		root.call("close_screen")
		await _frames(2)


func test_the_sheet_tabs() -> void:
	if not await _game(LATE):
		return
	root.call("open_screen", "sheet", 0)
	await _frames(2)
	var sheet := root.get("screen") as CharacterSheetScreen
	for t: String in CharacterSheetScreen.TABS:
		sheet.show_tab(t)
		await _frames(2)
		await _reach("the sheet's %s tab" % t)


func test_the_settings_pages() -> void:
	if not await _game(LATE):
		return
	for page: String in PauseMenu.SETTINGS_PAGES:
		root.call("open_screen", "menu", 0)
		await _frames(2)
		root.get("screen").call("_show_settings", page)
		await _frames(2)
		await _reach("the settings (%s)" % page)
		await _back("the settings (%s)" % page, func() -> bool: return root.get("screen") != null and not bool(root.get("screen").get("_on_settings")))
		root.call("close_screen")
		await _frames(2)


func test_the_travel_map_shop_temple_and_loot() -> void:
	if not await _game(LATE):
		return
	root.call("open_travel", false)
	await _frames(3)
	await _reach("the travel map")
	await _back("the travel map", _screen_gone)
	root.call("close_screen")
	await _frames(2)
	root.call("open_shop", "blinsky")
	await _frames(3)
	await _reach("a shop")
	await _back("a shop", func() -> bool: return root.find_children("*", "ShopScreen", false, false).filter(
		func(s: Node) -> bool: return not s.is_queued_for_deletion() and s.process_mode != Node.PROCESS_MODE_DISABLED).is_empty())
	root.call("open_services", "father_lucian")
	await _frames(3)
	await _reach("St. Andral's services")
	await _back("St. Andral's services", func() -> bool: return root.find_children("*", "ServicesScreen", false, false).filter(
		func(s: Node) -> bool: return not s.is_queued_for_deletion() and s.process_mode != Node.PROCESS_MODE_DISABLED).is_empty())
	var items: Array = []
	for id: String in ["potion_of_healing", "longsword", "rope_hempen", "torch"]:
		items.append({"id": id, "qty": 2})
	root.call("_open_loot", "pad_chest", items, 25.0)
	await _frames(3)
	await _reach("a loot window")
	await _back("a loot window", func() -> bool: return root.get("loot") == null)


func test_a_conversation() -> void:
	if not await _game(LATE):
		return
	var d := DialogueUI.new()
	root.add_child(d)
	await _frames(1)
	var options: Array = []
	for t: String in ["Who are you?", "Where is the castle?", "Farewell."]:
		options.append({"text": t, "label": "", "enabled": true, "check": {}})
	d.call("_show", {"kind": "options", "options": options})
	await _frames(2)
	await _reach("a conversation")
	d.queue_free()


func test_the_creator() -> void:
	if not await _game(LATE):
		return
	root.call("open_screen", "create", 0)
	await _frames(3)
	var cs := root.get("screen") as CreationScreen
	for step: int in range(CharacterBuilder.STEP_NAMES.size()):
		cs.step = step
		cs.call("_draw")
		await _frames(2)
		await _reach("the creator's %s step" % CharacterBuilder.STEP_NAMES[step])


## The title screen is a scene of its own (a Control at the top of the tree), as the game runs it.
func test_the_title_screen() -> void:
	var runner := get_tree().current_scene
	var menu: Node = null
	for step: String in ["_title", "_new_game", "_pick_difficulty", "_credits"]:
		if menu != null:
			menu.queue_free()
		await _frames(1)
		menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(menu)
		get_tree().current_scene = menu
		await _frames(2)
		if step != "_title":
			menu.call(step)
		await _frames(2)
		await _reach("the title screen (%s)" % step.trim_prefix("_"))
	get_tree().current_scene = runner
	menu.queue_free()
	await _frames(1)


func _trigger(axis: JoyAxis) -> void:
	for v: float in [1.0, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = v
		get_viewport().push_input(ev)
	await _frames(2)


func test_shoulders_and_triggers_step_tabs_and_characters() -> void:
	if not await _game(LATE):
		return
	root.call("open_screen", "sheet", 0)
	await _frames(2)
	await _press(JOY_BUTTON_DPAD_DOWN)
	var sheet := root.get("screen") as CharacterSheetScreen
	var tab := sheet.tab
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_ne(sheet.tab, tab, "RB: the sheet's next tab")
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(sheet.tab, tab, "LB: back")
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_eq(sheet.index, 1, "RT: the next of the party")
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	assert_eq(sheet.index, 0, "LT: back")
	root.call("close_screen")
	await _frames(2)
	GameState.story.set_quest_stage("escort_ireena", "asked")   # this save's journal is empty
	GameState.story.set_quest_stage("the_oat_thief", "rumored")
	root.call("open_screen", "journal", 0)
	await _frames(2)
	var journal := root.get("screen") as JournalScreen
	var landed := nav.focus_in(nav.scope_now())
	assert_true(landed != null and landed.has_meta(&"pad_first"), "the pad starts on the picked quest")
	var quest_tab := journal.quest_tab
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_ne(journal.quest_tab, quest_tab, "RT: the journal's other quests (Main / Other)")
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	assert_eq(journal.quest_tab, quest_tab, "LT: back")
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(journal.tab, JournalScreen.TABS[1], "RB: the journal's Codex")
	root.call("close_screen")
	await _frames(2)
	root.call("open_screen", "inventory", 0)
	await _frames(2)
	await _press(JOY_BUTTON_DPAD_DOWN)
	var inv := root.get("screen") as InventoryScreen
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(inv.filter, InventoryScreen.FILTERS[1], "RB: the pack's next filter")
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_eq(inv.index, 1, "RT: the inventory's next of the party")
	root.call("close_screen")


func test_items_on_a_pad() -> void:
	if not await _game(LATE):
		return
	root.call("open_screen", "inventory", 0)
	await _frames(2)
	await _press(JOY_BUTTON_DPAD_DOWN)
	var inv := root.get("screen") as InventoryScreen
	var tile: Control = null
	for t: Node in inv.find_children("*", "", true, false):
		if (t is ItemTile or t is ItemTile.Row) and not ((t as Control).get("payload") as Dictionary).is_empty() \
				and (t as Control).is_visible_in_tree():
			tile = t as Control
			break
	assert_true(tile != null, "the pack shows an item")
	if tile == null:
		return
	nav.focus_on(tile)
	await _frames(2)
	assert_eq(inv.selected, str(((tile.get("payload") as Dictionary)["entry"] as Dictionary)["id"]), "focus picks it: its card shows")
	var shown := PadPrompts.prompts_for(nav.scope, tile)
	assert_true(shown.any(func(p: Array) -> bool: return str(p[0]) == "x" and str(p[1]) == "Item menu"), "X is its menu")
	await _press(JOY_BUTTON_X)
	await _frames(1)
	var menus := inv.find_children("*", "PopupMenu", true, false)
	assert_eq(menus.size(), 1, "X opens its menu")
	if menus.size() == 1:
		var m := menus[0] as PopupMenu
		assert_true(m.visible and m.item_count > 0, "with what can be done")
		assert_eq(m.get_focused_item(), 0, "it opens on its first line")
		await _press_real(JOY_BUTTON_DPAD_DOWN)
		var lines: Array[String] = []
		for i in m.item_count:
			lines.append("%s%s" % [m.get_item_text(i), " (off)" if m.is_item_disabled(i) else ""])
		var want := 0
		for i in range(1, m.item_count):
			if not m.is_item_disabled(i) and not m.is_item_separator(i):
				want = i
				break
		assert_eq(m.get_focused_item(), want, "the D-pad lights the next line that can be chosen: %s" % ", ".join(lines))
		await _press(JOY_BUTTON_B)
		await _frames(2)
		assert_false(is_instance_valid(m) and m.visible, "B closes the menu")
	assert_true(root.get("screen") == inv, "and only the menu")
	await _press(JOY_BUTTON_X)
	await _frames(1)
	menus = inv.find_children("*", "PopupMenu", true, false).filter(func(n: Node) -> bool: return (n as PopupMenu).visible)
	if menus.size() == 1:
		var m2 := menus[0] as PopupMenu
		var first := m2.get_item_text(0)
		await _press_real(JOY_BUTTON_A)
		await _frames(2)
		assert_false(is_instance_valid(m2) and m2.visible, "A on a line does it (%s) and closes the menu" % first)
	root.call("close_screen")


func test_the_creator_on_a_pad() -> void:
	if not await _game(LATE):
		return
	root.call("open_screen", "create", 0)
	await _frames(3)
	var cs := root.get("screen") as CreationScreen
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(cs.step, 1, "RB: the next step")
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(cs.step, 0, "LB: back")
	await _press(JOY_BUTTON_START)
	assert_eq(cs.step, 1, "Start: Next")
	await _press(JOY_BUTTON_B)
	assert_eq(cs.step, 0, "B: a step back")
	var shown := PadPrompts.prompts_for(cs, get_viewport().gui_get_focus_owner())
	assert_true(shown.any(func(p: Array) -> bool: return str(p[0]) == "lb+rb" and str(p[1]) == "Steps"), "the bar says LB/RB step")
	assert_false(shown.any(func(p: Array) -> bool: return str(p[1]) == "Tabs"), "instead of Tabs")
	root.call("close_screen")


func test_more_screens() -> void:
	if not await _game(LATE):
		return
	GameState.story.milestones += 1
	if GameState.story.can_level_up(GameState.story.party[0]):
		root.call("open_screen", "level_up", 0)
		await _frames(3)
		await _reach("the level up")
		await _back("the level up", _screen_gone)
		root.call("close_screen")
		await _frames(2)
	for mode: int in [SavesScreen.Mode.SAVE, SavesScreen.Mode.LOAD]:
		root.call("open_screen", "menu", 0)
		await _frames(2)
		(root.get("screen") as PauseMenu).call("_open_saves", mode)
		await _frames(2)
		await _reach("the saves page (%s)" % ("save" if mode == SavesScreen.Mode.SAVE else "load"))
		root.call("close_screen")
		await _frames(2)
	root.call("open_screen", "menu", 0)
	await _frames(2)
	(root.get("screen") as PauseMenu).call("_open_cheats")
	await _frames(2)
	await _reach("the cheat codes page")
	root.call("close_screen")
	await _frames(2)
	var w := WaitScreen.new()
	root.add_child(w)
	w.build(root, GameState.story, "Not with foes in sight.")
	await _frames(2)
	await _reach("the wait screen, blocked")
	w.queue_free()
	await _frames(1)
	var beat := {"kind": "check", "who": "Godrick Pendlebrook", "portrait": "godrick_pendlebrook", "skill": "Persuasion",
		"dc": 18, "total": 13, "success": false, "said": "We mean no harm.",
		"detail": "Persuasion: d20 (6) + 7 = 13 vs DC 18, failure", "rolls": [6], "kept": 6,
		"modifier": 7, "extra": 0, "extra_label": "", "advantage": false, "disadvantage": false, "auto_failed": false,
		"parts": [{"label": "Charisma", "value": 3}], "aids": [{"id": "heroic_inspiration", "label": "Heroic Inspiration: reroll the d20"}]}
	var d := DialogueUI.new()
	root.add_child(d)
	await _frames(1)
	d.call("_show", beat)
	await _frames(2)
	await _reach("a conversation check")
	d.queue_free()
	await _frames(1)


func test_the_ending_on_a_pad() -> void:
	if not await _game("v2_the_end.json"):
		return
	await _frames(10)
	var ending := root.get("ending") as Node
	if ending == null:
		fail("the finished game shows its ending")
		return
	ending.set("to_title", false)
	await _reach("the ending")


func test_the_travel_map_on_a_pad() -> void:
	if not await _game(LATE):
		return
	root.call("open_travel", false)
	await _frames(3)
	var map := root.get("screen") as TravelScreen
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(str(get_viewport().gui_get_focus_owner().name), "Map", "it opens on the map")
	var moved := false
	for b: JoyButton in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var before := str(map.get("_hover"))
		await _press(b)
		if str(map.get("_hover")) != before and str(map.get("_hover")) != "":
			moved = true
			break
	assert_true(moved, "the D-pad goes from place to place")
	var lit := str(map.get("_hover"))
	await _press(JOY_BUTTON_A)
	assert_eq(str(map.get("_target")), lit, "A plans the way there")
	var z := map.zoom
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_true(map.zoom > z, "RT zooms in")
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	assert_true(is_equal_approx(map.zoom, z) or map.zoom < z + 0.01, "LT zooms out")
	await _back("the travel map", _screen_gone)


## Skirmish and the Character Lab, a scene of its own like the title screen, on each of its tabs.
func test_skirmish_on_a_pad() -> void:
	Achievements.path = "user://test_achievements_pad_%d.json" % OS.get_process_id()
	SkirmishLibrary.dir = "user://test_skirmish_pad_%d/" % OS.get_process_id()
	SkirmishScreen.current = null
	SkirmishScreen.kept_tab = "Party"
	var runner := get_tree().current_scene
	await _frames(1)
	var screen := (load("res://scenes/skirmish.tscn") as PackedScene).instantiate() as SkirmishScreen
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	await _frames(3)
	for t: String in SkirmishScreen.TABS:
		screen.tab = t
		screen.call("_redraw")
		await _frames(2)
		await _reach("skirmish (%s)" % t)
	get_tree().current_scene = runner
	screen.queue_free()
	await _frames(1)
	SkirmishScreen.current = null
	DirAccess.remove_absolute(Achievements.path)
	Achievements.path = ""
	SkirmishLibrary.dir = "user://skirmish/"


func test_typing_a_cheat_code_on_a_pad() -> void:
	if not await _game(LATE):
		return
	root.call("open_screen", "menu", 0)
	await _frames(2)
	(root.get("screen") as PauseMenu).call("_open_cheats")
	await _frames(2)
	var f := get_viewport().gui_get_focus_owner()
	assert_true(f is LineEdit, "the page opens on the code's field (%s)" % (_describe(f) if f != null else "nothing"))
	await _press(JOY_BUTTON_A)
	var boards := get_tree().root.find_children("*", "PadKeyboard", false, false)
	assert_eq(boards.size(), 1, "A opens the keyboard")
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _press(JOY_BUTTON_A)   # E: a code is hex digits only
	await _press(JOY_BUTTON_START)
	await _frames(1)
	assert_true(root.get("screen") != null, "the menu is still open")
	var page := (root.get("screen") as Node).find_children("*", "CheatCodesPage", true, false)
	assert_eq(page.size(), 1, "and its cheat codes page")
	if is_instance_valid(f) and f is LineEdit:
		assert_eq((f as LineEdit).text, "E", "with what was typed")
	root.call("close_screen")


## A cutscene on a pad: A goes on (never Skip), B pauses it and the pause card takes the pad, A on Resume goes back.
func test_a_cutscene_on_a_pad() -> void:
	if not await _game(LATE):
		return
	Cutscenes.register({"id": "test_pad_cut", "title": "Test", "summary": "A fixture.",
		"images": [{"image": "strahd_watcher", "when": ""}]})
	var p := CutscenePlayer.new()
	root.add_child(p)
	p.play("test_pad_cut", ["The first line.", "The second line."] as Array[String], GameState.story)
	await _frames(3)
	await _press(JOY_BUTTON_A)
	assert_false(p.done, "A doesn't skip it")
	assert_eq(p.index, 1, "A goes on to the next line")
	await _press(JOY_BUTTON_B)
	assert_true(p.view.paused, "B pauses it")
	var f := get_viewport().gui_get_focus_owner()
	assert_eq(str(f.name) if f != null else "", "Resume", "the pause card opens on Resume")
	await _press(JOY_BUTTON_A)
	assert_false(p.view.paused, "A on it goes back to the scene")
	p.queue_free()
	Cutscenes.clear_cache()
	await _frames(1)
