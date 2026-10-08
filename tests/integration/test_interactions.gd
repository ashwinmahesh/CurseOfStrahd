extends TestCase
## Using things in the world (owner feedback, 2026-10-06): a click on a locked door or chest only rattles it and says
## it's locked, and the ways to open it (the key, Pick the lock, Force it, Cast Knock) are on the right-click menu; a
## description or event closes with Continue, a click anywhere or Esc; the Narrator speaks with a portrait, and
## whoever makes a check shows theirs; the loot window takes the gold on its own.

const LOC := {
	"id": "test_vault", "name": "Test Vault", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"####.###.####",
		"#...#...#...#",
		"#############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"doors": [{"id": "barred", "cell": [4, 4], "locked": true, "lock_dc": 5, "label": "the barred door"},
		{"id": "keyed", "cell": [8, 4], "locked": true, "lock_dc": 0, "key": "antitoxin", "label": "the keyed door"}],
	"props": [{"id": "grim_portrait", "cell": [1, 1], "kind": "examine", "label": "Grim portrait",
		"dialogue": "test/vault:portrait"}],
	"containers": [{"id": "coffer", "cell": [1, 3], "label": "Coffer", "items": [{"id": "dagger", "qty": 1}], "gold": 7},
		{"id": "strongbox", "cell": [11, 1], "label": "Strongbox", "locked": true, "lock_dc": 5, "gold": 3}],
}

const DIALOGUE := """
~ portrait
Narrator: A stern face in oils. Its eyes follow you.
-> END

~ look_closer
check Perception DC 1 -> spotted | spotted

~ spotted
Narrator: Behind the frame, a draught.
-> END
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_vault"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/vault"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_vault"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	# The fixture isn't real content (test_set_dressing checks every location's props for art).
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_vault")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _walk_until_idle() -> void:
	for i in 400:
		if (_view().get("_queue") as Array).is_empty():
			return
		await get_tree().process_frame


func _door_state(id: String) -> String:
	return str((GameState.story.loc_state("test_vault")["doors"] as Dictionary).get(id, ""))


## A left click at `at` in the game's 1600x900 coordinates (the headless window is tiny, so they're passed as the
## viewport's own), hovering there first like a mouse would.
func _click(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv, true)
	for down: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
	await _frames(2)


func _key(k: Key) -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = down
		get_viewport().push_input(ev)
	await _frames(2)


func _ids(actions: Array) -> Array[String]:
	var out: Array[String] = []
	for a: Variant in actions:
		out.append(str((a as Dictionary)["id"]))
	return out


# --- Locks ----------------------------------------------------------------------------------------

func test_a_click_on_a_locked_door_says_locked_and_tries_nothing() -> void:
	var v := _view()
	var toasts: Array[String] = []
	v.toast.connect(func(t: String) -> void: toasts.append(t))
	var rolls: Array[String] = []
	v.check_rolled.connect(func(t: String) -> void: rolls.append(t))
	v.click(Vector2i(4, 4))
	await _walk_until_idle()
	await _frames(2)
	assert_eq(_door_state("barred"), "", "still locked")
	assert_true(v.grid.has_flag(Vector2i(4, 4), CombatGrid.WALL), "still shut")
	assert_true(rolls.is_empty(), "no lockpicking roll: %s" % [rolls])
	assert_true(toasts.any(func(t: String) -> bool: return t.begins_with("Locked")), str(toasts))
	assert_false(Audio.files("sfx", "locked").is_empty(), "the locked rattle exists")


func test_the_right_click_menu_holds_the_ways_in() -> void:
	var v := _view()
	var ids := _ids(v.actions_at(Vector2i(4, 4))["actions"] as Array)
	assert_true("pick" in ids and "force" in ids, str(ids))
	assert_false("knock" in ids, "nobody has Knock ready yet")
	# Picking it from the menu walks over and rolls until it gives.
	for i in 10:
		if not v.grid.has_flag(Vector2i(4, 4), CombatGrid.WALL):
			break
		v.act(Vector2i(4, 4), "pick")
		await _walk_until_idle()
		await _frames(1)
	assert_false(v.grid.has_flag(Vector2i(4, 4), CombatGrid.WALL), "picked and opened")
	assert_eq(_door_state("barred"), LocationView.DOOR_OPEN)


func test_a_carried_key_opens_its_door_with_a_click() -> void:
	var v := _view()
	var menu := v.actions_at(Vector2i(8, 4))["actions"] as Array
	assert_eq(_ids(menu), ["key", "look"] as Array[String], "no lock to pick: only its key")
	assert_false(bool((menu[0] as Dictionary)["enabled"]), "greyed out while nobody carries it")
	v.click(Vector2i(8, 4))
	await _walk_until_idle()
	await _frames(1)
	assert_eq(_door_state("keyed"), "", "no key, no entry")
	GameState.story.give_item("antitoxin", 1, GameState.story.party[0])
	v.click(Vector2i(8, 4))
	await _walk_until_idle()
	await _frames(1)
	assert_eq(_door_state("keyed"), LocationView.DOOR_OPEN, "the key opens it at a click")


func test_knock_opens_a_lock_and_spends_a_slot() -> void:
	var silvain := GameState.story.party[3]
	(silvain.spellcasting[0]["prepared"] as Array).append("knock")
	var before := silvain.slots_left(2)
	assert_true(before > 0, "a 3rd-level wizard has 2nd-level slots")
	var v := _view()
	var ids := _ids(v.actions_at(Vector2i(4, 4))["actions"] as Array)
	assert_true("knock" in ids, str(ids))
	v.act(Vector2i(4, 4), "knock")
	await _walk_until_idle()
	await _frames(1)
	assert_eq(_door_state("barred"), LocationView.DOOR_OPEN)
	assert_eq(silvain.slots_left(2), before - 1)


func test_a_locked_chest_says_locked_too() -> void:
	var v := _view()
	v.click(Vector2i(11, 1))
	await _walk_until_idle()
	await _frames(2)
	assert_true(root.get("loot") == null, "no loot window for a locked chest")
	var ids := _ids(v.actions_at(Vector2i(11, 1))["actions"] as Array)
	assert_true("pick" in ids, str(ids))


## The church's undercroft door (owner report 2026-10-08): barred, with no key. Until Father Donavich lifts the bar it
## can be picked or forced like any lock; once he has, it opens at a click (it used to say it wouldn't budge, with no
## way in at all).
func test_the_church_undercroft_door_opens_once_the_bar_is_lifted() -> void:
	root.queue_free()
	await _frames(1)
	GameState.story.location = "village_church"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	for i in 20:   # past the church's opening narration
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			break
		d.call("_advance")
		await _frames(1)
	var v := _view()
	var cell := Vector2i(18, 4)
	var ids := _ids(v.actions_at(cell)["actions"] as Array)
	assert_true("pick" in ids and "force" in ids, "barred, it can be picked or forced: %s" % [ids])
	GameState.story.set_flag("undercroft_unbarred")
	var menu := v.actions_at(cell)["actions"] as Array
	assert_eq(_ids(menu), ["open", "look"] as Array[String], "with the bar lifted it's a door")
	assert_true(bool((menu[0] as Dictionary).get("enabled", true)), "that opens")
	# What a click does on reaching it (the walk across the nave is left out).
	v.interact(v.thing_at(cell))
	await _frames(1)
	assert_eq(str((GameState.story.loc_state("village_church")["doors"] as Dictionary).get("undercroft_door", "")),
		LocationView.DOOR_OPEN, "using it opens it")
	assert_false(v.grid.has_flag(cell, CombatGrid.WALL), "and the way down is clear")


# --- Popups ---------------------------------------------------------------------------------------

func _open_portrait() -> DialogueUI:
	var v := _view()
	v.interact(v.thing_at(Vector2i(1, 1)))
	await _frames(2)
	return root.get("dialogue") as DialogueUI


func test_a_description_closes_with_a_click_on_its_text() -> void:
	var d := await _open_portrait()
	assert_true(d != null, "the description is open")
	var text := d.get("_text") as RichTextLabel
	await _click(text.get_global_rect().get_center())
	assert_true(root.get("dialogue") == null, "a click on the words closes it")


func test_a_description_closes_with_a_click_beside_it_esc_or_continue() -> void:
	var d := await _open_portrait()
	await _click(Vector2(20, 20))
	assert_true(root.get("dialogue") == null, "a click anywhere closes it")
	d = await _open_portrait()
	await _key(KEY_ESCAPE)
	assert_true(root.get("dialogue") == null, "Esc closes it")
	assert_true(root.get("screen") == null, "and doesn't open the menu")
	d = await _open_portrait()
	var go := d.find_child("Continue", true, false) as Button
	assert_true(go != null and go.is_visible_in_tree(), "a Continue button shows")
	go.pressed.emit()
	await _frames(2)
	assert_true(root.get("dialogue") == null, "Continue closes it")


func test_the_narrator_and_whoever_rolls_show_their_portraits() -> void:
	var d := await _open_portrait()
	var face := d.get("_portrait") as TextureRect
	assert_true(face.texture != null, "the Narrator has a portrait")
	assert_eq((d.get("_name") as Label).text, "Narrator")
	await _key(KEY_ESCAPE)
	root.call("start_dialogue", "test/vault:look_closer", "")
	await _frames(2)
	d = root.get("dialogue") as DialogueUI
	assert_true(d != null)
	face = d.get("_portrait") as TextureRect
	var roller := (d.get("_name") as Label).text
	assert_ne(roller, "Narrator", "the check beat names who rolled")
	assert_true(face.texture != null, "%s's portrait shows with the roll" % roller)
	var who := _member(roller)
	assert_true(who != null, roller)
	if who != null:
		assert_true(face.texture.resource_path.ends_with("/%s.png" % DialogueRunner.portrait_of(who)), face.texture.resource_path)


func _member(name_: String) -> Character:
	for ch in GameState.story.party:
		if ch.name == name_:
			return ch
	return null


func test_the_narrator_box_shows_the_narrator_and_closes_on_click_or_esc() -> void:
	var hud := root.get("hud") as ExploreHud
	hud.narrate("The mists part.")
	await _frames(2)
	assert_true(hud.narration_showing())
	var box := hud.get_node("NarratorBox") as PanelContainer
	assert_true(box.find_children("*", "TextureRect", true, false).any(
		func(t: Node) -> bool: return (t as TextureRect).texture != null), "the Narrator's portrait is in the box")
	await _key(KEY_ESCAPE)
	assert_false(hud.narration_showing(), "Esc puts it away")
	assert_true(root.get("screen") == null, "the first Esc doesn't open the menu")
	hud.narrate("The mists part again.")
	await _frames(2)
	await _click(box.get_global_rect().get_center())
	assert_false(hud.narration_showing(), "a click on it puts it away")


# --- Loot -----------------------------------------------------------------------------------------

func test_the_loot_window_takes_the_gold_alone() -> void:
	var v := _view()
	v.interact(v.thing_at(Vector2i(1, 3)))
	await _frames(2)
	var loot := root.get("loot") as LootWindow
	assert_true(loot != null)
	var take := loot.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).text == "Take gold")
	assert_eq(take.size(), 1, "a Take gold button")
	(take[0] as Button).pressed.emit()
	await _frames(1)
	assert_eq(GameState.story.gold, 7.0, "the coins are in the purse")
	# (Random treasure, ADR 0012, may add more to the chest; the dagger is what this test put there.)
	assert_true(loot.items.any(func(it: Variant) -> bool: return str((it as Dictionary).get("id", "")) == "dagger"), "the dagger is still there")
	assert_true(root.get("loot") != null, "the window stays open for the rest")

