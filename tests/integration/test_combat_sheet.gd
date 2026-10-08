extends TestCase
## Character sheets in a fight (owner, 2026-10-08): a party frame's portrait, or C, opens the sheet view only. The fight
## waits under it, nothing on it can be changed or spent, any party member's sheet can be read, and closing it (Back to
## the fight, Esc or C) returns to the same turn with nothing used.

const WARD := {
	"id": "test_sheet_ward", "name": "Test Ward", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 3]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_sheet_ward"] = WARD.duplicate(true)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_sheet_ward"
	GameState.story.milestones = 5   # a level up is waiting, so the sheet would offer it outside a fight
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)


func after_each() -> void:
	get_tree().paused = false
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_sheet_ward")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fight() -> CombatView:
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("rat"), "the fight starts")
	await _frames(3)
	var cv := view.combat_view
	for i in 10:
		if cv.e.current().side == &"party":
			break
		cv.e.end_turn()
		await _frames(1)
	cv.hud.refresh()
	await _frames(1)
	return cv


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = true
	return k


func _texts(n: Node) -> Array[String]:
	var out: Array[String] = []
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).visible:
			out.append((b as Button).text)
	return out


## What a turn has to spend, to compare before and after.
func _turn(cv: CombatView) -> String:
	var c := cv.e.current()
	var slots: Array = []
	for ch in GameState.story.party:
		slots.append(ch.spell_slots())
	return "%s %d move %d action %s bonus %s reaction %s hp %d slots %s" % [c.id, cv.e.round_no, c.movement_left,
		c.action_available, c.bonus_available, c.reaction_available, c.creature.hp, str(slots)]


func test_a_portrait_opens_the_sheet_view_only_and_the_fight_waits() -> void:
	var cv := await _fight()
	var before := _turn(cv)
	var portrait: Button = null
	for b in cv.hud.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text.contains("Liriel Dawnsong's character sheet"):
			portrait = b as Button
	assert_true(portrait != null, "Liriel's frame has a portrait to click")
	portrait.pressed.emit()
	await _frames(2)
	var sheet := root.get("screen") as CharacterSheetScreen
	assert_true(sheet != null, "the sheet opens")
	assert_true(sheet.in_fight, "view only")
	assert_eq(sheet.index, 1, "Liriel's")
	assert_true(get_tree().paused, "the fight waits")
	var shown := _texts(sheet)
	assert_true("Back to the fight" in shown, "a way back: %s" % str(shown))
	assert_false("Level up" in shown, "no levelling in a fight")
	for tab: String in CharacterSheetScreen.TABS:
		sheet.show_tab(tab)
		await _frames(1)
		var on_tab := _texts(sheet)
		assert_false("Cast" in on_tab or "Ritual" in on_tab, "%s: nothing to cast from the sheet in a fight" % tab)
		assert_false("Open inventory" in on_tab, "%s: gear waits for the fight's end" % tab)
		for t in sheet.find_children("*", "TextEdit", true, false):
			assert_false((t as TextEdit).editable, "notes are read only")
	# Every party member's sheet reads, with the arrows as ever.
	for i in GameState.story.party.size():
		sheet._unhandled_input(_key(KEY_RIGHT))
	assert_eq(sheet.index, 1, "round the whole party and back")
	(sheet.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return (b as Button).text == "Back to the fight")[0] as Button).pressed.emit()
	await _frames(2)
	assert_false(get_tree().paused, "the fight goes on")
	assert_true(root.get("screen") == null)
	assert_eq(_turn(cv), before, "nothing spent, the same turn")
	cv.finished.emit("victory")
	await _frames(3)


func test_c_opens_the_shown_hero_and_esc_or_c_closes_it() -> void:
	var cv := await _fight()
	var before := _turn(cv)
	cv._unhandled_input(_key(KEY_C))
	await _frames(2)
	var sheet := root.get("screen") as CharacterSheetScreen
	assert_true(sheet != null and sheet.in_fight, "C opens a view-only sheet")
	assert_true(GameState.story.party[sheet.index] == cv.hud.shown.creature, "of the hero the hotbar shows")
	sheet._unhandled_input(_key(KEY_C))
	await _frames(2)
	assert_true(root.get("screen") == null, "C closes it")
	assert_false(get_tree().paused)
	cv._unhandled_input(_key(KEY_C))
	await _frames(2)
	sheet = root.get("screen") as CharacterSheetScreen
	var esc := InputEventAction.new()
	esc.action = &"combat_cancel"
	esc.pressed = true
	sheet._unhandled_input(esc)
	await _frames(2)
	assert_true(root.get("screen") == null, "Esc closes it")
	assert_eq(_turn(cv), before)
	cv.finished.emit("victory")
	await _frames(3)


func test_outside_a_fight_the_sheet_is_as_before() -> void:
	root.call("open_screen", "sheet", 0)
	await _frames(2)
	var sheet := root.get("screen") as CharacterSheetScreen
	assert_false(sheet.in_fight)
	assert_false(get_tree().paused)
	assert_true("Level up" in _texts(sheet), "levelling is offered outside a fight")
	root.call("close_screen")
