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


## The exploring HUD while the party sneaks: a Stealth total on every portrait, a guest's too (the widest totals, a
## negative one), and the controls card that says what the colours mean.
func test_the_exploring_hud_while_sneaking() -> void:
	if not await _game(LATE):
		return
	assert_true(GameState.story.add_guest("ireena"))
	var view := root.get("view") as LocationView
	view.place_guests()
	view.set_sneaking(true)
	var widest := [28, -1, 100, 7]
	for m: Combatant in view.members + view.guest_members:
		view.sneak_totals[m.creature] = int(widest[(view.members + view.guest_members).find(m) % widest.size()])
	root.call("_refresh")
	await _frames(2)
	var badges := (root.get("hud") as ExploreHud).find_children("StealthBadge", "PanelContainer", true, false)
	assert_eq(badges.size(), GameState.story.party.size() + 1, "a total on each portrait and on the guest's")
	for b in badges:
		assert_true((b as Control).visible, "sneaking: shown")
	await _check("the exploring HUD, sneaking", func() -> Variant: return root.get("hud"))
	(root.get("hud") as ExploreHud).toggle_controls()
	await _check("the exploring controls", func() -> Variant: return (root.get("hud") as ExploreHud).get("_controls"))
	(root.get("hud") as ExploreHud).toggle_controls()
	GameState.story.remove_guest("ireena")


## Four item notices (ItemNotices) at once, with the longest item names in the game, magic and not.
func test_item_notices_with_the_longest_names() -> void:
	if not await _game(LATE):
		return
	var names: Array = []
	for item: Dictionary in Compendium.shared().all("items") + Compendium.shared().all("magic_items"):
		names.append([Compendium.shared().display_name("items", str(item["id"])).length(), str(item["id"])])
	names.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	await _check("item notices", func() -> Variant:
		var n := root.get("notices") as ItemNotices
		for i in ItemNotices.MAX_SHOWN:
			n.show_item(str((names[i] as Array)[1]), 12, "Godrick Pendlebrook")
		await _frames(2)
		return n.get_child(0),
		func() -> void:
			var n := root.get("notices") as ItemNotices
			for p in n.shown():
				p.free())


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


## The camp's panel (F16, CampBar) before the night and after it, and the rest screen while the party is camped.
func test_the_camp_panel() -> void:
	if not await _game(LATE):
		return
	root.call("enter_location", "mount_baratok", "default")
	await _frames(5)
	(GameState.story.flags as Dictionary).erase(RestRules.DONE_AT)
	var camp := LocationCamp.pitch(root.get("view") as LocationView, root, "safe")
	assert_true(camp != null, "camp is made on the mountainside")
	if camp == null:
		return
	await _check("the camp panel", func() -> Variant:
		await _frames(2)
		return camp.bar)
	await _check("the rest screen at camp", _screen("rest", 0), _close_screen)
	camp.sleep()
	await _check("the camp panel after the night", func() -> Variant:
		await _frames(2)
		return camp.bar)


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


## A Ring of Spell Storing's card (owner, 2026-10-19): the pickers for who casts which spell and the row of levels to store
## it at, with an empty ring so every level is offered.
func test_the_ring_of_spell_storing_card() -> void:
	if not await _game(LATE):
		return
	var ch := GameState.story.party[0]
	ch.add_item("ring_of_spell_storing")
	ch.entry_of("ring_of_spell_storing")["stored"] = []
	var open := func() -> Variant:
		root.call("open_screen", "inventory", 0)
		await _frames(2)
		var inv := root.get("screen") as InventoryScreen
		inv.selected = "ring_of_spell_storing"
		inv.call("_draw")
		await _frames(2)
		var levels := (inv.get("_card") as Node).find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
			return (b as Button).text.begins_with("Level "))
		assert_false(levels.is_empty(), "the ring's card offers levels to store at")
		return inv
	await _check("the Ring of Spell Storing's card", open, _close_screen)


## XP levelling's rows (story/xp.gd): the experience strip on the Party screen and the sheet at its longest (a level 10 pool a
## point short of 11 with a big reserve held), the level-up screen when there's no level to take, and Settings' Game page
## saying how heroes grow.
func test_the_xp_levelling_screens() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	st.options[Xp.OPTION] = Xp.EXPERIENCE
	var lowest := 20
	for ch in st.party:
		lowest = mini(lowest, ch.character_level())
	# The longest line: a pool a point short of the next level, with a big reserve held for the next milestone.
	st.xp = Xp.threshold(lowest + 1) - 1
	st.xp_reserve = 94000
	await _check("the party (XP levelling)", _screen("party", 0), _close_screen)
	await _check("%s's sheet (XP levelling)" % st.party[0].name, _screen("sheet", 0), _close_screen)
	# A pool that has taken every level the story gives: nobody can level up, and the line says what is still needed.
	st.xp = Xp.threshold(lowest)
	for i in st.party.size():
		if not st.can_level_up(st.party[i]):
			await _check("%s's level up (XP levelling, XP short)" % st.party[i].name, _screen("level_up", i), _close_screen)
	await _check("the settings (Game, XP levelling)", func() -> Variant:
		root.call("open_screen", "menu", 0)
		await _frames(1)
		root.get("screen").call("_show_settings", "Game")
		await _frames(2)
		return root.get("screen"), _close_screen)


## Prepare Spells (any time outside a fight, and the screen a finished rest offers) for a level 9 party whose casters
## have the longest lists, from the rest screen's way in and from one hero's sheet.
func test_the_prepare_spells_screen() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	assert_false(PrepareScreen.preparable(st, PrepareScreen.ANYTIME).is_empty(), "the party has casters to prepare")
	for kind: String in [PrepareScreen.ANYTIME, "long_rest"]:
		await _check("the Prepare Spells screen (%s)" % kind, func() -> Variant:
			var ps := PrepareScreen.new()
			ps.rest_kind = kind
			root.add_child(ps)
			ps.open(root, st, 0)
			await _frames(2)
			return ps, func() -> void:
				for n in root.find_children("*", "PrepareScreen", true, false):
					n.free())
	for i in st.party.size():
		if PrepareScreen.preparable(st, PrepareScreen.ANYTIME, st.party[i]).is_empty():
			continue
		await _check("%s's Prepare Spells (any time)" % st.party[i].name, func() -> Variant:
			root.call("open_screen", "sheet", i)
			await _frames(1)
			var sheet := root.get("screen") as CharacterSheetScreen
			sheet.show_tab("Spells")
			await _frames(1)
			sheet.call("_open_prepare", st.party[i])
			await _frames(2)
			return sheet, _close_screen)


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


## The journal's quests (Storyline QA, 2026-10-09): every quest in the game taken, under Main and under Other, each
## with the quest whose hint is longest picked, its hint showing and tracked (Other at the biggest interface and text
## too), and a search with nothing found. The list, the long names in it and the hints wrap or trim inside the frame.
func test_the_journal_quests() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	var longest := {"main": "", "other": ""}
	var size := {"main": 0, "other": 0}
	for q: Dictionary in Compendium.shared().all("quests"):
		var stage := ((q["stages"] as Array)[0] as Dictionary)
		st.set_quest_stage(str(q["id"]), str(stage["id"]))
		var kind := QuestLog.kind(str(q["id"]))
		if str(stage.get("hint", "")).length() > int(size[kind]):
			size[kind] = str(stage.get("hint", "")).length()
			longest[kind] = str(q["id"])
	for kind: String in ["main", "other", "other at the largest sizes"]:
		var largest := kind.ends_with("sizes")
		if largest:
			GameSettings.set_ui_scale(GameSettings.UI_SCALES.back())
			GameSettings.set_text_scale(GameSettings.TEXT_SCALES.back())
		var picked := str(longest[kind.get_slice(" ", 0)])
		QuestLog.track(st, picked)
		await _check("the journal's %s quests, a long hint showing" % kind, func() -> Variant:
			root.call("open_screen", "journal", 0)
			await _frames(1)
			var j := root.get("screen") as JournalScreen
			j.hints_shown[picked] = true
			j.call("_draw")
			await _frames(2)
			return j, _close_screen)
		if largest:
			GameSettings.set_ui_scale(1.0)
			GameSettings.set_text_scale(1.0)
	await _check("the journal's quests, searched for nothing", func() -> Variant:
		root.call("open_screen", "journal", 0)
		await _frames(1)
		var j := root.get("screen") as JournalScreen
		j.search = "nothing at all like this"
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
		var sneaking := root.get("view") as LocationView
		sneaking.set_sneaking(true)
		root.call("_refresh")
		await _check("the exploring HUD, sneaking, largest", func() -> Variant: return root.get("hud"))
		sneaking.set_sneaking(false)
		root.call("_refresh")
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


## The merchant with the most magic (Xaver, Khazan's stores) on each of his tabs, and the stockyard with a
## made-to-order ware's weapons open (Ashwin, 2026-10-14: every magic item the story doesn't need is for sale).
func test_a_magic_shop() -> void:
	if not await _game(LATE):
		return
	GameState.story.milestones = 20   # every rarity on the shelves
	var open := func(npc: String, bases: String) -> Variant:
		root.call("open_shop", npc)
		await _frames(2)
		var shops := root.find_children("*", "ShopScreen", false, false)
		if shops.is_empty():
			return null
		if bases != "":
			(shops.back() as ShopScreen).toggle_bases(bases)
			await _frames(1)
		return shops.back()
	var close := func() -> void:
		for s in root.find_children("*", "ShopScreen", false, false):
			s.queue_free()
	var tabs := ShopScreen.ware_tabs(GameState.story.shop_wares("library_xaver"))
	assert_true(tabs.size() >= 4, "his wares under several tabs: %s" % str(tabs))
	for tab in tabs:
		ShopScreen.ware_filter = tab
		await _check("Xaver's shop (%s)" % tab, open.bind("library_xaver", ""), close)
	ShopScreen.ware_filter = "Weapons"
	await _check("the stockyard with a +1 weapon's choices open", open.bind("gunther_arasek", "weapon_plus_1"), close)
	ShopScreen.ware_filter = "All"


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


## Guidance offered before a check (ui/common/guidance_prompt.gd) at its fullest: the whole party could cast it, each
## keeping the spell with the longest name it would end, before the skill with the longest name.
func test_the_guidance_prompt() -> void:
	if not await _game(LATE):
		return
	var casters: Array[Dictionary] = []
	for ch in GameState.story.party:
		casters.append({"caster": ch, "ends": "Protection from Evil and Good", "rule": "ask"})
	var offer := {"st": GameState.story, "who": GameState.story.party[0], "skill": &"sleight_of_hand", "dc": 25,
		"casters": casters, "auto": null}
	await _check("the Guidance prompt", func() -> Variant:
		var p := GuidancePrompt.ask(root, offer, func(_i: int, _rule: String) -> void: pass)
		await _frames(2)
		return p,
		func() -> void:
			for p in root.find_children("GuidancePrompt*", "", false, false):
				p.queue_free())


## Someone offering to lead the party to another place (ui/common/lead_prompt.gd), with the longest name and place
## the story has: Follow now or come back later.
func test_the_follow_prompt() -> void:
	if not await _game(LATE):
		return
	await _check("the Follow prompt", func() -> Variant:
		var p := LeadPrompt.ask(root, "Sir Godfrey Gwilym of Argynvostholt", "The Amber Temple: Hall of the Faceless God", func(_f: bool) -> void: pass)
		await _frames(2)
		return p,
		func() -> void:
			for p in root.find_children("LeadPrompt*", "", false, false):
				p.queue_free())


## What the party can hand a guest (ui/common/gift_picker.gd) at its fullest: a few gifts with long labels.
func test_the_give_picker() -> void:
	if not await _game(LATE):
		return
	var gifts: Array[Dictionary] = []
	for i in 4:
		gifts.append({"id": "g%d" % i, "label": "The brass wind-up key that the ravens of the high tower carried off under the roofs (%d)" % i,
			"item": "pidlwicks_key", "ref": "x:y", "note": "A long note that a tooltip carries."})
	await _check("the Give picker", func() -> Variant:
		var p := GiftPicker.ask(root, "Sir Godfrey Gwilym of Argynvostholt", gifts, func(_i: int) -> void: pass)
		await _frames(2)
		return p,
		func() -> void:
			for p in root.find_children("GiftPicker*", "", false, false):
				p.queue_free())


## The Party screen and the exploring HUD with the most guests the story has travelling at once: each card's Talk, Give...
## and Send home sit inside it.
func test_the_party_with_guests() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	st.set_flag("pidlwick_key_found")
	for id: String in ["pidlwick_ii", "sir_godfrey_gwilym", "ezmerelda", "adrian_martikov"]:
		st.add_guest(id)
	(root.get("view") as LocationView).place_guests()
	await _check("the party (with guests)", _screen("party", 0), _close_screen)
	await _check("the exploring HUD (with guests)", func() -> Variant:
		(root.get("hud") as ExploreHud).refresh()
		await _frames(2)
		return root.get("hud"))


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
	# A foe's Examine card (ActionCatalog.examine), studied so its defenses and abilities show too.
	var foe: Combatant = null
	for c1 in cv.e.combatants:
		if c1.side == &"enemy":
			foe = c1
			break
	if foe != null and foe.creature is Monster:
		cv.e.studied[str((foe.creature as Monster).data["id"])] = true
		await _check("a foe's Examine card", func() -> Variant:
			var who := cv.e.current() if cv.e.current().side == &"party" else null
			cv.hud.show_examine(cv.catalog.examine(who, foe), foe)
			await _frames(1)
			return cv.hud,
			func() -> void: cv.hud.hide_details())
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
	# A hero's Reactions on one prompt (owner report 2026-10-12): long names wrap, the picked one's words show.
	var many := ReactionRequest.new(Reactions.CHOICE, party.id, party.id)
	many.title = "%s the Very Long-Named Knight of the Silver Dragon has a Reaction" % party.name()
	many.text = "Pick one to use, or Skip to keep it."
	many.min_targets = 1
	many.max_targets = 1
	many.target_choices.assign([
		{"id": "now:0", "label": "Protection", "text": "The dire wolf of the Svalich Woods attacks Ireena Kolyana beside %s. Interpose the shield: Disadvantage on this attack and on others against Ireena until %s's next turn." % [party.name(), party.name()], "cost": "Reaction"},
		{"id": "now:1", "label": "Warding Flare", "text": "A flash of light gives the attack roll Disadvantage.", "cost": "Reaction and a use of Warding Flare"},
		{"id": "now:2:3", "label": "Hellish Rebuke · Level 3 slot (Pact Magic) · 4d10 Fire, a very long option name that has to wrap", "text": "Answer with fire.", "cost": "Reaction and the spell slot you choose"},
		{"id": "later:sentinel", "label": "Sentinel, if the attack hits", "text": "If the dire wolf hits Ireena, %s makes an Opportunity Attack against it right after (Sentinel). If it misses, the Reaction is kept." % party.name(), "cost": "Reaction, only if it hits"}])
	many.selected_ids.assign(["now:0"])
	await _check("a prompt listing a hero's Reactions", func() -> Variant:
		cv.hud.show_prompt(many)
		await _frames(1)
		assert_false((cv.hud.get("_prompt_rule_row") as Control).visible, "no one rule to set for a list")
		assert_true((cv.hud.get("_prompt_text") as Label).text.contains("Interpose the shield"), "the picked one's words")
		assert_false((cv.hud.get("_prompt_callout") as Label).visible, "no red line when there's nothing to call out")
		return cv.hud,
		func() -> void: cv.hud.hide_prompt())
	# Divine Smite on a Critical Hit (owner, 2026-10-13): the red line under its title, each slot's dice doubled.
	var smite := ReactionRequest.new(CombatFeatures.DIVINE_SMITE, party.id, party.id)
	smite.title = "Divine Smite?"
	smite.callout = "Critical Hit: the smite's dice are doubled"
	smite.text = "%s lands a Critical Hit on the dire wolf of the Svalich Woods. Smite for more Radiant damage: 2d8, and 1d8 more for each slot level above 1st, up to 5d8 (1d8 more against a Fiend), every die doubled?" % party.name()
	smite.cost = "The free use or the spell slot you choose"
	smite.spends_reaction = false
	smite.min_targets = 1
	smite.max_targets = 1
	smite.target_choices.assign([{"id": "free", "label": "Free use (Paladin's Smite) · 4d8 (2d8 doubled)"},
		{"id": "1", "label": "Level 1 slot · 4d8 (2d8 doubled)"}, {"id": "2", "label": "Level 2 slot · 6d8 (3d8 doubled)"},
		{"id": "3", "label": "Level 3 slot · 8d8 (4d8 doubled)"}, {"id": "4", "label": "Level 4 slot · 10d8 (5d8 doubled, the most)"},
		{"id": "5", "label": "Level 5 slot · 10d8 (5d8 doubled, the most)"}])
	smite.selected_ids.assign(["free"])
	await _check("Divine Smite's prompt on a Critical Hit", func() -> Variant:
		cv.hud.show_prompt(smite)
		await _frames(1)
		assert_true((cv.hud.get("_prompt_callout") as Label).visible, "the Critical Hit line shows")
		return cv.hud,
		func() -> void: cv.hud.hide_prompt())
	# Preserve Life (owner question 2026-10-14): a slider for each Bloodied creature in reach, long names wrapping, and the
	# count of what is left to share, with as many creatures as a party and its companions can bring.
	var share := ReactionRequest.new("preserve_life", party.id, party.id)
	share.title = "Preserve Life"
	share.text = "Share 45 Hit Points among the Bloodied creatures within 30 feet, yourself included. No one rises above half their Hit Point maximum, and the points you don't give out are lost."
	share.cost = "Magic action and a Channel Divinity use (2 left)"
	share.spends_reaction = false
	share.pool = 45
	for k in 6:
		var id := "creature%d" % k
		share.target_choices.append({"id": id, "name": "Knight %d" % k, "room": 18 + k,
			"label": "%s the Very Long-Named Knight of the Silver Dragon %d · %d of 60 Hit Points · up to %d" % [party.name(), k, 6 + k, 18 + k]})
		share.amounts[id] = 8 if k < 5 else 5
	await _check("Preserve Life's prompt", func() -> Variant:
		cv.hud.show_prompt(share)
		await _frames(1)
		assert_true((cv.hud.get("_prompt_pool") as Label).text.contains("Left to share: 0") or (cv.hud.get("_prompt_pool") as Label).text.contains("All 45"), (cv.hud.get("_prompt_pool") as Label).text)
		assert_false((cv.hud.get("_prompt_rule_row") as Control).visible, "no standing rule for a division")
		return cv.hud,
		func() -> void: cv.hud.hide_prompt())
	# Dropping Concentration (owner, 2026-10-17): its slot on the Common tab named for a long-named spell, and the check
	# that asks before letting go of it.
	var held := party.creature.begin_concentration("otilukes_resilient_sphere", "Otiluke's Resilient Sphere of the Very Long Name")
	cv.hud.shown = party
	cv.hud.set_tab(ActionCatalog.COMMON)
	await _check("the combat HUD with Drop Concentration on its hotbar", func() -> Variant:
		cv.hud.refresh()
		await _frames(1)
		return cv.hud)
	await _check("the check before dropping a spell", func() -> Variant:
		cv.hud.confirm_drop_concentration("Stop concentrating on %s?" % held.name)
		await _frames(1)
		return cv.hud,
		func() -> void: cv.hud.close_confirm())
	held.end("test")
	cv.hud.refresh()
	# The area panel at the top left (owner, 2026-10-12): more creatures than it lists, long names, warnings.
	var rows: Array = []
	for k in 12:
		var who := cv.e.combatants[k % cv.e.combatants.size()]
		rows.append({"id": who.id, "name": "%s the Very Long-Named %d" % [who.name(), k], "ally": k % 3 == 0, "safe": k == 3,
			"unaffected": false, "save_chance": 0.35, "damage": 21, "drops": "may drop" if k == 1 else ""})
	# At the top right (his correction, 04:35): beside the log, or under it in the corner when it's minimized.
	for minimized: bool in [false, true]:
		CombatHud.log_minimized = minimized
		cv.hud.call("_apply_log_state")
		await _check("the area saves panel" + (" with the log minimized" if minimized else ""), func() -> Variant:
			cv.hud.show_area_saves("Delayed Blast Fireball · slot level 9", "Dex save DC 19", rows,
				["Friendly fire: Godrick Pendlebrook is in the area", "Ends your Concentration on Hunger of Hadar"])
			await _frames(1)
			var area := (cv.hud.get("_area_panel") as Control).get_global_rect()
			var screen := get_tree().root.get_visible_rect()
			assert_true(area.position.x > screen.size.x * 0.5, "on the right half (%s)" % area)
			assert_false(area.intersects((cv.hud.get("_log_panel") as Control).get_global_rect()), "clear of the log")
			assert_false(area.intersects((cv.hud.get("_strip") as Control).get_global_rect()), "clear of the turn order")
			assert_false(area.intersects((cv.hud.get("_hot_panel") as Control).get_global_rect()), "clear of the hotbar")
			return cv.hud,
			func() -> void: cv.hud.hide_area_saves())
	CombatHud.log_minimized = false
	cv.hud.call("_apply_log_state")
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


## A fight of 24 (owner, 2026-10-14): the turn order scrolls inside its panel, with an arrow at the end that has more.
func test_the_combat_hud_with_a_long_turn_order() -> void:
	var e := TestCombat.open_field()
	for k in 4:
		TestCombat.hero(e, ["ilse_varga", "godrick_pendlebrook", "thistle", "silvain_aster"][k], Vector2i(0, k), 3)
	for k in 20:
		TestCombat.foe(e, "zombie", Vector2i(3 + k % 9, int(k / 9.0) * 2 + 1))
	TestCombat.start_with(e, e.combatants[0])
	var hud := CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.refresh()
	await _check("the combat HUD with a turn order of 24", func() -> Variant:
		hud.refresh()
		await _frames(2)
		var strip := hud.get("_strip_view") as TurnStrip
		strip.scroll_by(300.0, true)   # both arrows showing
		return hud)
	hud.queue_free()
	await _frames(2)


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


## The big d20 that show_roll puts up for a hero's save in a fight or an overworld check (DiceRoll), with Advantage,
## a long name and every part of the bonus, at rest.
func test_the_big_d20_for_a_save() -> void:
	if not await _game(LATE):
		return
	var roll := {"kind": "save", "natural": 14, "rolls": [14, 3], "total": 22, "target": 17, "success": true,
		"critical": false, "fumble": false, "who": "Godrick Pendlebrook", "label": "Constitution saving throw", "advantage": true,
		"parts": [{"label": "Con modifier", "value": 3}, {"label": "Proficiency", "value": 3}, {"label": "Aura of Protection", "value": 1},
			{"label": "Cloak of Protection", "value": 1}], "extra": 2, "extra_label": "Bless 2"}
	await _check("the big d20 for a save", func() -> Variant:
		var layer := CanvasLayer.new()
		layer.name = "BigRoll"
		layer.layer = DiceRoll.LAYER
		root.add_child(layer)
		var p := DiceRoll.new()
		layer.add_child(p)
		p.place_for_screen()
		p.roll(roll)
		await _frames(2)
		return layer,
		func() -> void:
			for l in root.find_children("BigRoll*", "CanvasLayer", false, false):
				l.queue_free())


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
	# A save with the longest note a player can type (Q9).
	var noted := FileAccess.get_file_as_string(SaveSystem.slot_path("v2_vallaki"))
	var data := JSON.parse_string(noted) as Dictionary
	data["note"] = "W".repeat(60)
	var f := FileAccess.open(SaveSystem.slot_path("v2_vallaki"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
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
	await _check("the game-over screen", _screen("game_over", 0), _close_screen)
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


## Report a bug (dev builds, BugReports): the screen with a long place, the late party and a long build line, and the
## screen once sent, naming a long folder.
func test_the_bug_report_screen() -> void:
	if not await _game(LATE):
		return
	for state: String in ["writing", "sent"]:
		await _check("the bug report screen (%s)" % state, func() -> Variant:
			var screen := BugReportScreen.new()
			get_tree().root.add_child(screen)
			var context := BugReports.current.gather("F12")
			context["place"] = "The Abbey of Saint Markovia, the Belfry and the Upper Hall (abbey_of_saint_markovia_belfry)"
			context["build"] = "a checkout on a-long-lane-branch-name at 0123456789 %s(/Volumes/StrahdLanes/CurseOfStrahdGame-bugreport)" \
				% "a long commit subject ".repeat(6)
			screen.open(BugReports.current, Image.create(1600, 900, false, Image.FORMAT_RGB8), context, {})
			if state == "sent":
				screen.sent_to = "/Users/someone/Documents/Obsidian Vault/CurseOfStrahd/Bug Reports/2026-10-11T23-59-59-%s" \
					% "a-long-title-".repeat(4)
				screen.call("_sent")
			return screen,
			func() -> void:
				for s in get_tree().root.find_children("*", "BugReportScreen", false, false):
					s.queue_free())


func test_the_title_screen() -> void:
	_golden_saves_on_disk(true)
	var menu: Node = null
	for step: String in ["_title", "_new_game", "_pick_difficulty", "_offer_tutorial", "_show_loads", "_open_hero"]:
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


## Coaching, its options and completion controls remain visible at all supported sizes.
func test_the_tutorial_coach() -> void:
	var previous_ui := GameSettings.ui_scale()
	var previous_text := GameSettings.text_scale()
	for largest: bool in [false, true]:
		GameSettings.set_ui_scale(GameSettings.UI_SCALES.back() if largest else 1.0)
		GameSettings.set_text_scale(GameSettings.TEXT_SCALES.back() if largest else 1.0)
		for state: String in ["practice", "details", "menu", "complete", "compact", "finished"]:
			await _check("the tutorial coach (%s, %s)" % [state, "largest" if largest else "normal"], func() -> Variant:
				var coach := TutorialCoach.new()
				root = coach
				add_child(coach)
				UiScale.playing(coach)
				coach.present({
					"title": "Spell slots, healing and your party",
					"body": "A spell slot is a limited resource spent on a powerful spell. A cantrip needs no slot. Spell level and character level are different: a higher-level hero can still cast a level 1 spell. Choose a wounded ally in range and inspect the result.",
					"objective": "Cast a healing spell on your wounded companion. The healing and spent spell slot will appear in the real combat log.",
					"details": "A creature may resist a spell by making a saving throw. This is a d20 roll plus its relevant bonus against the spell's Difficulty Class. A successful enemy save is a normal result, not a broken control. Concentration lets you maintain one ongoing spell at a time; damage can force a check to keep it.",
				}, 12, 18)
				coach.set_action("Open the character sheet", func() -> void: pass)
				coach.set_highlight(Rect2(Vector2(600, 100), Vector2(360, 52)))
				match state:
					"details": coach.toggle_details()
					"menu": coach.show_menu()
					"complete": coach.set_complete("Your ally regained hit points and you spent one level 1 spell slot. Continue when you have read the result.")
					"compact": coach.toggle_compact()
					"finished": coach.show_finished(true)
				await _frames(8)
				var panel := coach.get("_panel") as PanelContainer
				assert_true(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "the entire coach card stays inside the viewport")
				return coach,
				func() -> void:
					if root != null:
						root.queue_free()
						root = null)
	GameSettings.set_ui_scale(previous_ui)
	GameSettings.set_text_scale(previous_text)
