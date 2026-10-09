extends TestCase
## Layout checks (P5): every screen, opened at 1080p, 1440p, a small window, 16:10 and 4:3, fails when text or buttons
## spill out of their boxes (tests/support/layout_check.gd says what counts). The party comes from a late golden save
## (tests/saves), so sheets, packs, spell lists and the journal are as full as a player's. Owner reports behind it
## (2026-10-07): dialogue options cut off at the right, the Death Saving Throw button below the window.
## The game draws at 1600x900 and stretches, so the three 16:9 sizes lay out alike and are checked once.

## A level 9 party with a long journal and full packs, and a finished game for the ending.
const LATE := "v2_amber_temple.json"
const FINISHED := "v2_the_end.json"

## A fight to check the combat HUD in: one rat, started by hand.
const ARENA := {
	"id": "test_layout_ward", "name": "Test Ward", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 3]}]}],
}

## Full-screen sizes beyond LayoutCheck.SIZES, for the cutscene stills: Mac laptops are taller than 16:9, an ultrawide
## much wider.
const FULL_SCREENS := {"a MacBook Pro full screen": Vector2i(3024, 1964), "a MacBook Air full screen": Vector2i(2560, 1664),
	"a 4K full screen": Vector2i(3840, 2160), "an ultrawide full screen": Vector2i(3440, 1440)}

## Spills found when these checks arrived, each waiting on the lane that owns the screen: [what was opened (its start),
## words in the problem, why]. They print as known instead of failing, and an entry fails once its spill is gone, so
## the list only shrinks.
const KNOWN := [
]

var root: Node
var _window := Vector2i.ZERO
var _known_seen := {}   ## KNOWN index -> true, this test
var _opened: Array[String] = []   ## what this test checked


func before_each() -> void:
	_window = get_tree().root.size


func after_each() -> void:
	(Compendium.shared().tables["locations"] as Dictionary).erase(str(ARENA["id"]))
	for i in KNOWN.size():
		var k := KNOWN[i] as Array
		if not _known_seen.has(i) and _opened.any(func(w: String) -> bool: return w.begins_with(str(k[0]))):
			fail("%s no longer has its known spill (%s): take it out of KNOWN" % [k[0], k[1]])
	get_tree().root.size = _window
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The window sizes that lay out differently, each with the names of the sizes that give it.
func _layouts() -> Dictionary:
	var out := {}
	for size_name: String in LayoutCheck.SIZES:
		get_tree().root.size = LayoutCheck.SIZES[size_name]
		var logical := get_tree().root.get_visible_rect().size
		var key := "%dx%d" % [logical.x, logical.y]
		if not out.has(key):
			out[key] = {"size": LayoutCheck.SIZES[size_name], "names": []}
		(out[key]["names"] as Array).append(size_name)
	return out


## Opens something with `open` (which returns the node to check, or null) at each window size and fails on whatever
## spills out of its box. `close` puts things back between sizes.
func _check(what: String, open: Callable, close: Callable = Callable()) -> void:
	var layouts := _layouts()
	for key: String in layouts:
		var l := layouts[key] as Dictionary
		get_tree().root.size = l["size"] as Vector2i
		await _frames(2)
		var node: Variant = await open.call()
		if not node is Node:
			fail("%s didn't open at %s" % [what, key])
			continue
		await _frames(3)
		if not what in _opened:
			_opened.append(what)
		for p in LayoutCheck.problems(node as Node, get_tree().root.get_visible_rect()):
			var known := _known(what, p)
			if known >= 0:
				if not _known_seen.has(known):
					print("  known: %s: %s" % [what, (KNOWN[known] as Array)[2]])
				_known_seen[known] = true
				continue
			fail("%s at %s (%s): %s" % [what, ", ".join(l["names"] as Array), key, p])
		if close.is_valid():
			await close.call()
			await _frames(1)


## The KNOWN entry a problem is, or -1.
static func _known(what: String, problem: String) -> int:
	for i in KNOWN.size():
		var k := KNOWN[i] as Array
		if what.begins_with(str(k[0])) and problem.contains(str(k[1])):
			return i
	return -1


## The game, loaded from golden save `f`.
func _game(f: String) -> bool:
	if root != null:
		root.queue_free()
		root = null
		await _frames(1)
	var path := GoldenSaves.DIR + f
	if not FileAccess.file_exists(path):
		fail("no golden save %s" % f)
		return false
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("layout"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(path))
	out.close()
	assert_eq(SaveSystem.load_slot("layout"), OK, "%s loads" % f)
	SaveSystem.delete_slot("layout")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	return true


func _screen(kind: String, index: int) -> Callable:
	return func() -> Variant:
		root.call("open_screen", kind, index)
		await _frames(2)
		return root.get("screen")


## A hero's sheet open at `tab`.
func _sheet_tab(index: int, tab: String) -> Callable:
	return func() -> Variant:
		root.call("open_screen", "sheet", index)
		await _frames(1)
		(root.get("screen") as CharacterSheetScreen).show_tab(tab)
		await _frames(2)
		return root.get("screen")


func _close_screen() -> void:
	root.call("close_screen")


## The checker on a made-up screen: what it calls a spill and what it lets be.
func test_what_counts_as_spilling() -> void:
	var box := Control.new()
	add_child(box)
	box.size = Vector2(1600, 900)
	var cut := Button.new()
	cut.text = "A very long button label that cannot possibly fit in eighty pixels"
	cut.clip_text = true
	cut.position = Vector2(10, 10)
	box.add_child(cut)
	var said := Button.new()
	said.text = cut.text
	said.clip_text = true
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	said.position = Vector2(10, 60)
	box.add_child(said)
	var off := Label.new()
	off.text = "Below the window"
	off.position = Vector2(10, 890)
	box.add_child(off)
	var crest := TextureRect.new()
	crest.position = Vector2(500, -40)
	crest.custom_minimum_size = Vector2(300, 100)
	box.add_child(crest)
	var list := ScrollContainer.new()
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.position = Vector2(10, 200)
	list.size = Vector2(300, 100)
	box.add_child(list)
	var rows := VBoxContainer.new()
	list.add_child(rows)
	for i in 8:
		var row := Label.new()
		row.text = "Row %d" % i
		rows.add_child(row)
	# A screen frame whose content is wider than it was designed for (it grows over its own corners).
	var frame := PanelContainer.new()
	frame.set_meta(&"design_size", Vector2(400, 200))
	frame.position = Vector2(600, 300)
	frame.size = Vector2(400, 200)
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(520, 100)
	frame.add_child(wide)
	box.add_child(frame)
	await _frames(2)
	cut.size = Vector2(80, cut.size.y)
	said.size = Vector2(80, said.size.y)
	var found := LayoutCheck.problems(box, Rect2(0, 0, 1600, 900))
	var text := "\n".join(found)
	assert_true(text.contains("cuts its text short") and text.contains("A very long"), "a cut with no ellipsis: %s" % text)
	assert_eq(found.filter(func(p: String) -> bool: return p.contains("cuts its text short")).size(), 1, "an ellipsis says so")
	assert_true(text.contains("Below the window"), "a label past the bottom")
	assert_false(text.contains("TextureRect"), "an ornament may hang over the edge")
	assert_false(text.contains("Row"), "rows scrolled out of a list's view are fine")
	assert_true(text.contains("grew past its design size") and text.contains("not 400x200"), "a frame its content widened: %s" % text)
	box.queue_free()


func test_the_exploring_hud() -> void:
	if not await _game(LATE):
		return
	await _check("the exploring HUD", func() -> Variant: return root.get("hud"))


func test_the_turn_based_panel() -> void:
	if not await _game(LATE):
		return
	var view := root.get("view") as LocationView
	view.toggle_plan()
	view.set_sneaking(true)
	await _check("the turn-based panel", func() -> Variant:
		await _frames(2)
		return root.get("plan_bar"))
	GameSettings.set_turn_based(false)


func test_the_party_screens() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	for i in st.party.size():
		await _check("%s's sheet" % st.party[i].name, _screen("sheet", i), _close_screen)
		# Spells too: a spell with many tags beside its slot picker widened the tab past the frame (UI QA UI-02).
		await _check("%s's sheet (Spells)" % st.party[i].name, _sheet_tab(i, "Spells"), _close_screen)
		await _check("%s's inventory" % st.party[i].name, _screen("inventory", i), _close_screen)
	for kind: String in ["journal", "party", "roster", "rest", "menu"]:
		await _check("the %s" % kind, _screen(kind, 0), _close_screen)


## Settings' three pages in the pause menu's arch (lane 13: Game, Display and the Keys list).
func test_the_settings_pages() -> void:
	if not await _game(LATE):
		return
	for page: String in PauseMenu.SETTINGS_PAGES:
		await _check("the settings (%s)" % page, func() -> Variant:
			root.call("open_screen", "menu", 0)
			await _frames(1)
			root.get("screen").call("_show_settings", page)
			await _frames(2)
			return root.get("screen"), _close_screen)
	# Display with the Depth blur row at its longest choice (owner 2026-10-08: Off, Corners, Edges, Wide).
	var longest := ""
	for id: String in Atmosphere.EDGE_BLURS:
		if longest == "" or str(Atmosphere.EDGE_BLURS[id]["name"]).length() > str(Atmosphere.EDGE_BLURS[longest]["name"]).length():
			longest = id
	GameSettings.set_blur_reach(longest)
	await _check("the settings (Display, depth blur %s)" % Atmosphere.EDGE_BLURS[longest]["name"], func() -> Variant:
		root.call("open_screen", "menu", 0)
		await _frames(1)
		root.get("screen").call("_show_settings", "Display")
		await _frames(2)
		return root.get("screen"), _close_screen)
	GameSettings.set_blur_reach("")


## The journal with every open quest's hint showing (Storyline QA, 2026-10-09): the hints wrap inside their cards.
func test_the_journal_hints() -> void:
	if not await _game(LATE):
		return
	await _check("the journal with its hints showing", func() -> Variant:
		root.call("open_screen", "journal", 0)
		await _frames(1)
		var j := root.get("screen") as JournalScreen
		for q in QuestLog.journal(GameState.story):
			j.hints_shown[str(q["id"])] = true
		j.call("_draw")
		await _frames(2)
		return j, _close_screen)


## The journal's Bestiary (U8) with every creature in the game met, a third of them felled and a third studied.
func test_the_bestiary() -> void:
	if not await _game(LATE):
		return
	var i := 0
	for m: Dictionary in Compendium.shared().all("monsters"):
		GameState.story.bestiary[str(m["id"])] = {"n": i, "met": 1, "where": "amber_temple_entrance",
			"defeated": 3 if i % 3 > 0 else 0, "studied": i % 3 == 2}
		i += 1
	await _check("the bestiary", func() -> Variant:
		root.call("open_screen", "journal", 0)
		await _frames(1)
		var j := root.get("screen") as JournalScreen
		j.tab = "Bestiary"
		j.beast = "strahd_von_zarovich"
		j.call("_draw")
		await _frames(2)
		return j, _close_screen)


## The play screen at the biggest interface and text the Settings offer (U4): the exploring HUD with a level 9
## party's resources, a conversation with the longest options, and the combat HUD.
func test_the_play_screen_at_the_largest_sizes() -> void:
	GameSettings.set_ui_scale(GameSettings.UI_SCALES.back())
	GameSettings.set_text_scale(GameSettings.TEXT_SCALES.back())
	Compendium.shared().tables["locations"]["test_layout_ward"] = ARENA.duplicate(true)
	if await _game(LATE):
		assert_true(is_equal_approx(get_tree().root.content_scale_factor, GameSettings.ui_scale()), "the game takes the size")
		await _check("the exploring HUD, largest", func() -> Variant: return root.get("hud"))
		var options := longest_options(6)
		await _check("a conversation, largest", func() -> Variant:
			var d := DialogueUI.new()
			root.add_child(d)
			await _frames(1)
			d.call("_show", {"kind": "options", "options": options})
			await _frames(2)
			return d,
			func() -> void:
				for d in root.find_children("*", "DialogueUI", false, false):
					d.queue_free())
		root.call("enter_location", "test_layout_ward", "default")
		await _frames(3)
		var view := root.get("view") as LocationView
		assert_true(view.start_encounter("rat"), "the fight starts")
		await _frames(3)
		var cv := view.combat_view
		await _check("the combat HUD, largest", func() -> Variant: return cv.hud)
		cv.finished.emit("victory")
		await _frames(3)
	GameSettings.set_ui_scale(1.0)
	GameSettings.set_text_scale(1.0)


func test_the_level_up_screen() -> void:
	if not await _game(LATE):
		return
	GameState.story.milestones += 1
	for i in GameState.story.party.size():
		if GameState.story.can_level_up(GameState.story.party[i]):
			await _check("%s's level up" % GameState.story.party[i].name, _screen("level_up", i), _close_screen)


func test_the_creator() -> void:
	if not await _game(LATE):
		return
	await _check("the character creator", _screen("create", 0), _close_screen)


## Madam Eva's rebuild (owner, 2026-10-08): the creator for one hero, on its Equipment step (every option, with its
## gold) and its Appearance step (a prebuilt hero keeps their look); and the hero picker with its way back.
func test_madam_evas_rebuild() -> void:
	if not await _game(LATE):
		return
	var hero := GameState.story.party[0]
	for step: int in [CharacterBuilder.Step.EQUIPMENT, CharacterBuilder.Step.APPEARANCE]:
		await _check("the rebuild's %s step" % CharacterBuilder.STEP_NAMES[step], func() -> Variant:
			var cs := CreationScreen.new()
			root.add_child(cs)
			var start: Array[Dictionary] = [CreationScreen.rebuild_start(hero)]
			cs.open_with(start, 1)
			cs.b().set_class("wizard")
			cs.b().set_background("acolyte")
			cs.step = step
			cs.call("_draw")
			await _frames(2)
			return cs,
			func() -> void:
				for cs in root.find_children("*", "CreationScreen", false, false):
					cs.queue_free())
	var names: Array[String] = []
	for ch in GameState.story.party:
		names.append(ch.name)
	names.append(str(DialogueRunner.BACK_OUT["respec"]))
	await _check("the rebuild's hero picker", func() -> Variant:
		var d := DialogueUI.new()
		root.add_child(d)
		await _frames(1)
		d.call("_show", {"kind": "pick_member", "purpose": "respec", "members": names,
			"text": "Whose fate will the cards read anew? (They return to level 1 and are built again; they keep their belongings.)"})
		await _frames(2)
		return d,
		func() -> void:
			for d in root.find_children("*", "DialogueUI", false, false):
				d.queue_free())


## Wait (owner, 2026-10-08): the hours picker, and the screen when foes in sight stop it.
func test_the_wait_screen() -> void:
	if not await _game(LATE):
		return
	await _check("the wait screen", func() -> Variant:
		root.call("open_screen", "wait", 0)
		await _frames(2)
		(root.get("screen") as WaitScreen).set_hours(24)
		return root.get("screen"), _close_screen)
	await _check("the wait screen, blocked", func() -> Variant:
		var w := WaitScreen.new()
		root.add_child(w)
		w.build(root, GameState.story, "Not with foes in sight. Deal with them, or get out of their sight first.")
		return w,
		func() -> void:
			for w in root.find_children("*", "WaitScreen", false, false):
				w.queue_free())


func test_the_travel_map() -> void:
	if not await _game(LATE):
		return
	await _check("the travel map", func() -> Variant:
		root.call("open_travel", false)
		await _frames(2)
		return root.get("screen"), _close_screen)


func test_a_shop() -> void:
	if not await _game(LATE):
		return
	await _check("a shop", func() -> Variant:
		root.call("open_shop", "blinsky")
		await _frames(2)
		var shops := root.find_children("*", "ShopScreen", false, false)
		return shops.back() if not shops.is_empty() else null,
		func() -> void:
			for s in root.find_children("*", "ShopScreen", false, false):
				s.queue_free())


func test_a_temple_with_a_hero_to_raise() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	st.party[st.party.size() - 1].hp = 0
	st.party[st.party.size() - 1].dead = true
	st.party[0].hp = 1
	await _check("St. Andral's services", func() -> Variant:
		root.call("open_services", "father_lucian")
		await _frames(2)
		var found := root.find_children("*", "ServicesScreen", false, false)
		return found.back() if not found.is_empty() else null,
		func() -> void:
			for s in root.find_children("*", "ServicesScreen", false, false):
				s.queue_free())
	await _check("the inn's rooms", func() -> Variant:
		root.call("open_services", "urwin_martikov")
		await _frames(2)
		var found := root.find_children("*", "ServicesScreen", false, false)
		return found.back() if not found.is_empty() else null,
		func() -> void:
			for s in root.find_children("*", "ServicesScreen", false, false):
				s.queue_free())


func test_a_loot_window() -> void:
	if not await _game(LATE):
		return
	var items: Array = []
	for id: String in ["potion_of_healing", "longsword", "spellbook", "rope_hempen", "torch", "rations"]:
		if not Compendium.shared().item_data(id).is_empty():
			items.append({"id": id, "qty": 2})
	await _check("a loot window", func() -> Variant:
		root.call("_open_loot", "layout_chest", items.duplicate(true), 125.0)
		await _frames(2)
		return root.get("loot"),
		func() -> void:
			var w := root.get("loot") as Node
			if w != null:
				w.queue_free()
			root.set("loot", null))


## The longest options the game's conversations offer, each with a check's chance after it, the way the cut-off ones
## looked (owner report).
static func longest_options(n: int) -> Array:
	var texts: Array[String] = []
	for dir: String in DirAccess.get_directories_at("res://narrative"):
		for f: String in DirAccess.get_files_at("res://narrative/" + dir):
			if not f.ends_with(".dialogue"):
				continue
			for line: String in FileAccess.get_file_as_string("res://narrative/%s/%s" % [dir, f]).split("\n"):
				var t := line.strip_edges()
				if not t.begins_with("* "):
					continue
				t = t.substr(2).get_slice("->", 0).strip_edges()
				var re := RegEx.create_from_string("\\[if [^\\]]*\\]\\s*")
				t = re.sub(t, "", true).strip_edges()
				texts.append(t)
	texts.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out: Array = []
	for t: String in texts.slice(0, n):
		var label := ""
		var text := t
		if t.begins_with("["):
			label = t.substr(0, t.find("]") + 1)
			text = t.substr(t.find("]") + 1).strip_edges()
		out.append({"text": text, "label": label, "enabled": true,
			"check": {"who": "Godrick Pendlebrook", "bonus": 7, "chance": 0.65} if label != "" else {}})
	return out


func test_a_conversation_with_the_longest_options() -> void:
	if not await _game(LATE):
		return
	var options := longest_options(6)
	await _check("a conversation", func() -> Variant:
		var d := DialogueUI.new()
		root.add_child(d)
		await _frames(1)
		d.call("_show", {"kind": "options", "options": options})
		await _frames(2)
		return d,
		func() -> void:
			for d in root.find_children("*", "DialogueUI", false, false):
				d.queue_free())


func test_the_combat_hud_with_a_hero_dying() -> void:
	Compendium.shared().tables["locations"]["test_layout_ward"] = ARENA.duplicate(true)
	if not await _game(LATE):
		return
	root.call("enter_location", "test_layout_ward", "default")
	await _frames(3)
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("rat"), "the fight starts")
	await _frames(3)
	var cv := view.combat_view
	await _check("the combat HUD", func() -> Variant: return cv.hud)
	# One slot per idea (Combat HUD plan): the Reactions tab's toggles, and a container's pick list open at its slot.
	await _check("the combat HUD's Reactions tab", func() -> Variant:
		cv.hud.set_tab(ActionCatalog.REACTIONS)
		await _frames(1)
		return cv.hud)
	cv.hud.set_tab(ActionCatalog.COMMON)
	for i in cv.hud.slot_count():
		if bool(cv.hud.slot_action(i).get("group", false)):
			await _check("a container's pick list", func() -> Variant:
				cv.hud.use_slot(i)
				await _frames(1)
				return cv.hud,
				func() -> void: cv.hud._menu.hide())
			break
	# A reaction prompt (bottom right, above the hotbar) with the odds over a foe at the window's edge.
	var party: Combatant = null
	for c0 in cv.e.combatants:
		if c0.side == &"party":
			party = c0
			break
	var req := ReactionRequest.new("opportunity_attack", party.id, party.id)
	req.title = "Reaction: Opportunity Attack?"
	req.text = "A long trigger: the dire wolf of the Svalich Woods leaves %s's reach while the fight goes on around them. Strike it as it goes?" % party.name()
	await _check("a reaction prompt and the odds over a foe", func() -> Variant:
		cv.hud.show_prompt(req)
		cv.hud.show_odds(0.55, "3–18", "advantage", Vector2(5000, -200))
		await _frames(1)
		return cv.hud,
		func() -> void:
			cv.hud.hide_prompt()
			cv.hud.hide_tooltip())
	for i in 10:
		if cv.e.current().side == &"party":
			break
		cv.e.end_turn()
		await _frames(1)
	var c := cv.e.current()
	c.creature.take_damage(c.creature.hp, &"slashing")
	cv.hud.refresh()
	await _check("the combat HUD with a hero dying", func() -> Variant:
		cv.hud.refresh()
		await _frames(1)
		return cv.hud)
	cv.finished.emit("victory")
	await _frames(3)


func test_the_boss_plates() -> void:
	# Three bosses side by side (G3, ui/combat/boss_bar.gd): the longest title and Strahd's Legendary Resistance.
	var ward := ARENA.duplicate(true)
	(ward["encounters"] as Array).append({"id": "bosses", "trigger": "manual", "monsters": [
		{"monster": "strahd_von_zarovich", "cell": [6, 1]},
		{"monster": "vladimir_horngaard", "cell": [7, 2], "name": "Vladimir Horngaard"},
		{"monster": "night_hag", "cell": [8, 3], "name": "Offalia Wormwiggle"}]})
	Compendium.shared().tables["locations"]["test_layout_ward"] = ward
	if not await _game(LATE):
		return
	root.call("enter_location", "test_layout_ward", "default")
	await _frames(3)
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("bosses"), "the fight starts")
	await _frames(3)
	var cv := view.combat_view
	assert_true(cv.boss_bar != null and cv.boss_bar.bosses.size() == 3, "a plate for each boss")
	await _check("the boss plates", func() -> Variant: return cv.boss_bar)
	cv.finished.emit("victory")
	await _frames(3)


## A hero's character sheet opened from their portrait in a fight: view only, with Back to the fight (owner, 2026-10-08).
func test_the_character_sheet_in_a_fight() -> void:
	Compendium.shared().tables["locations"]["test_layout_ward"] = ARENA.duplicate(true)
	if not await _game(LATE):
		return
	root.call("enter_location", "test_layout_ward", "default")
	await _frames(3)
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("rat"), "the fight starts")
	await _frames(3)
	var cv := view.combat_view
	for tab: String in ["Actions", "Spells", "Equipment"]:
		await _check("the character sheet in a fight (%s)" % tab, func() -> Variant:
			cv.hud.sheet_requested.emit(cv.e.combatants.filter(func(c: Combatant) -> bool: return c.creature is Character)[0].id)
			await _frames(2)
			var sheet := root.get("screen") as CharacterSheetScreen
			if sheet != null:
				sheet.show_tab(tab)
				await _frames(1)
			return sheet, _close_screen)
	cv.finished.emit("victory")
	await _frames(3)


func test_the_ending() -> void:
	if not await _game(FINISHED):
		return
	await _frames(10)
	var ending := root.get("ending") as Node
	assert_true(ending != null, "the finished game shows its ending")
	if ending != null:
		ending.set("to_title", false)
		await _check("the ending", func() -> Variant: return root.get("ending"))


## A loading card (G5) with the longest place name and the longest tip.
func test_a_loading_card() -> void:
	if not await _game(LATE):
		return
	var longest_name := ""
	for loc: Variant in (Compendium.shared().tables["locations"] as Dictionary).values():
		var n := str((loc as Dictionary).get("name", ""))
		if n.length() > longest_name.length():
			longest_name = n
	var longest_tip := ""
	for t: Variant in LoadingCard.tips():
		if str(t).length() > longest_tip.length():
			longest_tip = str(t)
	await _check("a loading card", func() -> Variant:
		var card := LoadingCard.new()
		card.location = {"name": longest_name, "region": "castle_ravenloft"}
		card.tip = longest_tip
		root.add_child(card)
		await _frames(2)
		return card,
		func() -> void:
			for c in root.find_children("*", "LoadingCard", false, false):
				c.queue_free())


## The big d20 over a conversation (G11): a failed check with Advantage, every bonus part and two aids on offer.
## Busts either side of the box, facing each other, then the one on the right turned away (owner, 2026-10-08).
func test_a_conversation_with_busts_facing_each_other() -> void:
	if not await _game(LATE):
		return
	DialogueFile.register(DialogueFile.parse("~ a\nIreena [sad]: My father is three days dead.\nNarrator [away]: She turns to the window.\n-> END\n",
		"test_layout/busts"))
	for turned: bool in [false, true]:
		await _check("a conversation with busts%s" % (" turned away" if turned else ""), func() -> Variant:
			var d := DialogueUI.new()
			root.add_child(d)
			await _frames(1)
			d.play(DialogueRunner.new(GameState.story, DiceRoller.new(2)), "test_layout/busts:a")
			if turned:
				d.call("_advance")
			await _frames(2)
			assert_true(d.busts.right.visible, "Ireena's bust shows")
			assert_eq(d.busts.right_away, turned)
			return d,
			func() -> void:
				for d in root.find_children("*", "DialogueUI", false, false):
					d.queue_free())


func test_a_conversation_check_with_the_big_d20() -> void:
	if not await _game(LATE):
		return
	var beat := {"kind": "check", "who": "Godrick Pendlebrook", "portrait": "godrick_pendlebrook", "skill": "Persuasion",
		"dc": 18, "total": 13, "success": false, "said": "We mean no harm, and we will pay for the trouble.",
		"detail": "Persuasion (Godrick Pendlebrook): d20 adv (6, 4) + 7 = 13 vs DC 18, failure", "rolls": [6, 4], "kept": 6,
		"modifier": 7, "extra": 0, "extra_label": "", "advantage": true, "disadvantage": false, "auto_failed": false,
		"parts": [{"label": "Charisma", "value": 3}, {"label": "Proficiency", "value": 3}, {"label": "Ring of Persuasive Courtesy", "value": 1}],
		"aids": [{"id": "heroic_inspiration", "label": "Heroic Inspiration: reroll the d20"},
			{"id": "tactical_mind", "label": "Tactical Mind: add 1d10 (a Second Wind use, kept if it still fails)"}]}
	await _check("a conversation check", func() -> Variant:
		var d := DialogueUI.new()
		root.add_child(d)
		await _frames(1)
		d.call("_show", beat)
		await _frames(2)
		return d,
		func() -> void:
			for d in root.find_children("*", "DialogueUI", false, false):
				d.queue_free())


## A story cutscene (docs/ui/cutscenes.md) with the longest caption a line may have (60 words), and its pause card.
func test_a_cutscene_with_the_longest_caption() -> void:
	if not await _game(LATE):
		return
	Cutscenes.register({"id": "test_layout_cut", "title": "Test", "summary": "A fixture.",
		"images": [{"image": "strahd_watcher", "when": ""}]})
	var words: Array[String] = []
	for i in 60:
		words.append(["ridge", "lantern", "Barovia", "unhurried", "watching"][i % 5])
	var caption := " ".join(words) + "."
	for paused: bool in [false, true]:
		await _check("a cutscene%s" % (" paused" if paused else ""), func() -> Variant:
			var p := CutscenePlayer.new()
			root.add_child(p)
			p.play("test_layout_cut", [caption] as Array[String], GameState.story)
			p.view.set_paused(paused)
			await _frames(2)
			return p,
			func() -> void:
				for p in root.find_children("*", "CutscenePlayer", false, false):
					p.queue_free())
	Cutscenes.clear_cache()


## Cutscene stills in a window and full screen (owner, 2026-10-08: full screen cut off the top of the picture): at every
## size the whole picture shows, as large as fits, with black around it, and the caption (the longest a line may be)
## sits on the picture or its bar, never clipped.
func test_a_cutscene_picture_is_whole_in_a_window_and_full_screen() -> void:
	if not await _game(LATE):
		return
	Cutscenes.register({"id": "test_layout_cut", "title": "Test", "summary": "A fixture.", "focus": [0.5, 0.9],
		"images": [{"image": "strahd_watcher", "when": ""}]})
	var words: Array[String] = []
	for i in 60:
		words.append(["ridge", "lantern", "Barovia", "unhurried", "watching"][i % 5])
	var caption := " ".join(words) + "."
	var sizes := LayoutCheck.SIZES.duplicate()
	sizes.merge(FULL_SCREENS)
	for size_name: String in sizes:
		get_tree().root.size = sizes[size_name] as Vector2i
		await _frames(2)
		var p := CutscenePlayer.new()
		root.add_child(p)
		p.play("test_layout_cut", [caption] as Array[String], GameState.story)
		await _frames(3)
		for i in 120:   # the still comes off a worker thread (FN-20)
			if not p.view.loading():
				break
			await _frames(1)
		var screen := get_tree().root.get_visible_rect()
		var pic := p.view.picture_rect()
		assert_true(pic.size.x > 0.0, "%s: the picture shows" % size_name)
		assert_true(screen.grow(LayoutCheck.SLACK).encloses(pic), "%s: the picture %s spills out of the screen %s" % [size_name, pic, screen])
		assert_true(absf(pic.size.x - screen.size.x) <= LayoutCheck.SLACK or absf(pic.size.y - screen.size.y) <= LayoutCheck.SLACK,
			"%s: the picture %s is as large as fits in %s" % [size_name, pic, screen])
		for problem in LayoutCheck.problems(p, screen):
			fail("a cutscene at %s: %s" % [size_name, problem])
		p.queue_free()
		await _frames(1)
	Cutscenes.clear_cache()


## The saves lists as full as a player's: every golden save in this run's save folder.
static func _golden_saves_on_disk(on: bool) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	for f in DirAccess.get_files_at(GoldenSaves.DIR):
		if not f.ends_with(".json"):
			continue
		if not on:
			SaveSystem.delete_slot(f.get_basename())
			continue
		var out := FileAccess.open(SaveSystem.slot_path(f.get_basename()), FileAccess.WRITE)
		out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + f))
		out.close()


## The saves' own page (ui/screens/saves_screen.gd) over the pause menu, to save and to load, the question before a
## save is written over another, and the game-over screen that leads to it.
func test_the_saves_pages() -> void:
	if not await _game(LATE):
		return
	_golden_saves_on_disk(true)
	# A save with the longest note a player can type (Q9), and a backup of them all.
	var noted := FileAccess.get_file_as_string(SaveSystem.slot_path("v2_vallaki"))
	var data := JSON.parse_string(noted) as Dictionary
	data["note"] = "W".repeat(60)
	var f := FileAccess.open(SaveSystem.slot_path("v2_vallaki"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	SaveSystem.back_up_for_build("layout_build")
	for mode: int in [SavesScreen.Mode.SAVE, SavesScreen.Mode.LOAD]:
		await _check("the saves page (%s)" % ("save" if mode == SavesScreen.Mode.SAVE else "load"), func() -> Variant:
			root.call("open_screen", "menu", 0)
			await _frames(1)
			(root.get("screen") as PauseMenu).call("_open_saves", mode)
			await _frames(2)
			return root.get("screen"), _close_screen)
	await _check("the saves page (overwrite?)", func() -> Variant:
		root.call("open_screen", "menu", 0)
		await _frames(1)
		var menu := root.get("screen") as PauseMenu
		menu.call("_open_saves", SavesScreen.Mode.SAVE)
		await _frames(1)
		var page := menu.find_children("*", "SavesScreen", true, false)[0] as SavesScreen
		page.call("_confirm", page.slots()[0])
		await _frames(2)
		return root.get("screen"), _close_screen)
	await _check("the saves page (delete?)", func() -> Variant:
		root.call("open_screen", "menu", 0)
		await _frames(1)
		var menu := root.get("screen") as PauseMenu
		menu.call("_open_saves", SavesScreen.Mode.LOAD)
		await _frames(1)
		var page := menu.find_children("*", "SavesScreen", true, false)[0] as SavesScreen
		page.call("_confirm_delete", page.slots()[0])
		await _frames(2)
		return menu, _close_screen)
	await _check("the saves page (chapters)", func() -> Variant:
		root.call("open_screen", "menu", 0)
		await _frames(1)
		var menu := root.get("screen") as PauseMenu
		menu.call("_open_saves", SavesScreen.Mode.LOAD)
		await _frames(1)
		(menu.find_child("Chapters", true, false) as Button).pressed.emit()
		await _frames(2)
		return menu, _close_screen)
	await _check("the saves page (backups)", func() -> Variant:
		root.call("open_screen", "menu", 0)
		await _frames(1)
		var menu := root.get("screen") as PauseMenu
		menu.call("_open_saves", SavesScreen.Mode.LOAD)
		await _frames(1)
		(menu.find_child("Backups", true, false) as Button).pressed.emit()
		await _frames(2)
		return menu, _close_screen)
	await _check("the game-over screen", _screen("game_over", 0), _close_screen)
	for b in SaveSystem.backups():
		SaveSystem._remove_dir(SaveSystem.backups_dir().path_join(b))
	SaveSystem._remove_dir(SaveSystem.backups_dir())
	_golden_saves_on_disk(false)


## The cheat codes' page over the menu: empty, with the item whose name is longest, and with the Spell Scroll's picker
## on the spell whose scroll name is longest.
func test_the_cheat_codes_page() -> void:
	if not await _game(LATE):
		return
	var longest := {}
	for e in CheatCodes.entries():
		if longest.is_empty() or str(e["name"]).length() > str(longest["name"]).length():
			longest = e
	var scrolls := CheatCodes.choices("spell_scroll")
	var widest := scrolls[0]
	for v in scrolls:
		if CheatCodes.choice_name(v).length() > CheatCodes.choice_name(widest).length():
			widest = v
	for typed: Array in [["empty", "", ""], [str(longest["name"]), str(longest["code"]), ""],
			["a scroll", CheatCodes.code_of("spell_scroll"), widest]]:
		await _check("the cheat codes page (%s)" % typed[0], func() -> Variant:
			root.call("open_screen", "menu", 0)
			await _frames(1)
			var menu := root.get("screen") as PauseMenu
			menu.call("_open_cheats")
			await _frames(1)
			var page := menu.find_children("*", "CheatCodesPage", true, false)[0] as CheatCodesPage
			page.type_code(str(typed[1]))
			if str(typed[2]) != "":
				page.pick(str(typed[2]))
			await _frames(2)
			return menu, _close_screen)


func test_the_title_screen() -> void:
	_golden_saves_on_disk(true)
	var menu: Node = null
	for step: String in ["_title", "_new_game", "_pick_difficulty", "_show_loads", "_open_hero"]:
		await _check("the title screen (%s)" % step.trim_prefix("_"), func() -> Variant:
			if menu != null:
				menu.queue_free()
				await _frames(1)
			menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
			add_child(menu)
			await _frames(2)
			if step != "_title":
				menu.call(step)
			await _frames(2)
			return menu)
	if menu != null:
		menu.queue_free()
	_golden_saves_on_disk(false)
