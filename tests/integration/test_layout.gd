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

## Spills found when these checks arrived, each waiting on the lane that owns the screen: [what was opened (its start),
## words in the problem, why]. They print as known instead of failing, and an entry fails once its spill is gone, so
## the list only shrinks.
const KNOWN := [
	["a conversation", "past the window's edge", "the longest options widen the conversation past the right edge instead of wrapping (ui/dialogue/dialogue_ui.gd, lane 20)"],
	["the title screen (show_loads)", "reaches past the window's edge", "the Load list doesn't scroll: with many saves it runs off the bottom (ui/menu/main_menu.gd, lane 16's Q9)"],
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


## The inventory in `view` ("doll" or "list"; it opens in the view last chosen).
func _inventory(index: int, view: String) -> Callable:
	return func() -> Variant:
		root.call("open_screen", "inventory", index)
		await _frames(1)
		(root.get("screen") as InventoryScreen).set_view(view)
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
	box.queue_free()


func test_the_exploring_hud() -> void:
	if not await _game(LATE):
		return
	await _check("the exploring HUD", func() -> Variant: return root.get("hud"))


func test_the_party_screens() -> void:
	if not await _game(LATE):
		return
	var st := GameState.story
	for i in st.party.size():
		await _check("%s's sheet" % st.party[i].name, _screen("sheet", i), _close_screen)
		await _check("%s's inventory" % st.party[i].name, _inventory(i, "doll"), _close_screen)
		# The inventory's list view too (owner, 2026-10-07: a switch between it and the paper doll).
		await _check("%s's inventory (list)" % st.party[i].name, _inventory(i, "list"), _close_screen)
	GameSettings.set_value("inventory_view", "doll")
	for kind: String in ["journal", "party", "roster", "rest", "menu"]:
		await _check("the %s" % kind, _screen(kind, 0), _close_screen)


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


func test_the_ending() -> void:
	if not await _game(FINISHED):
		return
	await _frames(10)
	var ending := root.get("ending") as Node
	assert_true(ending != null, "the finished game shows its ending")
	if ending != null:
		ending.set("to_title", false)
		await _check("the ending", func() -> Variant: return root.get("ending"))


func test_the_title_screen() -> void:
	# The Load list as full as a player's: every golden save in this run's save folder.
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	for f in DirAccess.get_files_at(GoldenSaves.DIR):
		if not f.ends_with(".json"):
			continue
		var out := FileAccess.open(SaveSystem.slot_path(f.get_basename()), FileAccess.WRITE)
		out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + f))
		out.close()
	var menu: Node = null
	for step: String in ["_title", "_new_game", "_show_loads", "_open_hero"]:
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
	for f in DirAccess.get_files_at(GoldenSaves.DIR):
		if f.ends_with(".json"):
			SaveSystem.delete_slot(f.get_basename())
