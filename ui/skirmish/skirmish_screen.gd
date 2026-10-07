class_name SkirmishScreen
extends Control
## Skirmish and the Character Lab (N1), from the title screen: build a party of up to four at any level from 1 to 20
## (the pregens, a quick hero of any class, or one made in the hero creator; levelled with sensible picks or by hand
## on the level-up screen; given any item), choose foes from the stat blocks and a map (the arena or any location),
## save the setup, and fight it in the combat arena (CombatArena.skirmish). The setup outlives the fight, so Change
## the setup comes back here. Drawn in the Crimson scheme (UiKit, UiParts).

const TITLE_SCENE := "res://scenes/main_menu.tscn"
const ARENA_SCENE := "res://scenes/combat/arena.tscn"
const TABS: Array[String] = ["Party", "Foes", "Field", "Saved"]
const FRAME := Vector2(1540, 830)
const SIDE_W := 300.0
const LIST_CAP := 80
const QUICK_LEVELS: Array[int] = [1, 3, 5, 8, 11, 15, 20]
const DIFFICULTY_COLOURS := {"low": "moss", "moderate": "candle", "high": "ember", "beyond high": "vampire_red"}

## The setup being made; it outlives a fight, so Change the setup comes back to it.
static var current: SkirmishSetup = null
## The tab and the level new heroes come in at, kept between visits.
static var kept_tab := "Party"
static var add_level := 5

var setup: SkirmishSetup
var tab := "Party"
## The hero the Lab shows, or -1 for the page that adds one.
var hero_index := -1
## The hero the Lab is changing (written back to the setup after every change).
var lab_hero: Character = null
## A party screen the Lab opened (level up, sheet, inventory), and the state it sees.
var screen: Node = null
var lab_state := SkirmishState.new()
## Levels the Lab took, per hero index: the hero as they were before each (so a level can be taken back).
var undo: Dictionary = {}
var creation: CreationScreen = null
var sketch: MapSketch = null

var layer: CanvasLayer
var _frame: VBoxContainer
var _tabs_row: Control
var _body: Control
var _side: VBoxContainer
var _note: Label
var _list: VBoxContainer = null
var _filter := ""


func _ready() -> void:
	get_tree().paused = false
	ModeController.force(ModeController.Mode.EXPLORATION)
	InputActions.ensure()
	Cursors.install()
	Cursors.show("pointer")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if current == null:
		current = SkirmishSetup.new()
	setup = current
	tab = kept_tab
	hero_index = 0 if not setup.party.is_empty() else -1
	_backdrop()
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_frame = UiKit.screen_frame(layer, "Skirmish", FRAME)
	var under_crest := Control.new()
	under_crest.custom_minimum_size = Vector2(0, 14)
	_frame.add_child(under_crest)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(row)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 0)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(main)
	_tabs_row = HBoxContainer.new()
	main.add_child(_tabs_row)
	var pane := UiParts.pane(12)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(pane)
	_body = MarginContainer.new()
	pane.add_child(_body)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(SIDE_W, 0)
	_side.add_theme_constant_override("separation", 8)
	row.add_child(_side)
	_note = UiKit.label("", 14, "gilt_light", FRAME.x - 120.0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame.add_child(_note)
	_select_hero(hero_index)
	_redraw()


func _exit_tree() -> void:
	Cursors.uninstall()


## The title's key art, darkened, behind the frame.
func _backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Look.color("void")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := TextureRect.new()
	art.texture = load("res://art/ui/title_backdrop.png") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(1, 1, 1, 0.35)
	add_child(art)


func say(text: String) -> void:
	if _note != null:
		_note.text = text


# --- Drawing --------------------------------------------------------------------------------------

func _redraw() -> void:
	kept_tab = tab
	for c in _tabs_row.get_children():
		c.queue_free()
	var strip := UiParts.tab_strip(TABS, tab, func(t: String) -> void:
		tab = t
		_filter = ""
		_redraw(), {}, 16)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_row.add_child(strip)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_list = null
	sketch = null
	match tab:
		"Party":
			_party_tab()
		"Foes":
			_foes_tab()
		"Field":
			_field_tab()
		"Saved":
			_saved_tab()
	_draw_side()


## The fight at a glance, always beside the tabs: the map, the heroes, the foes and how hard it is, and Fight.
func _draw_side() -> void:
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	_side.add_child(UiParts.section("This fight"))
	var entry := SkirmishSetup.map_entry(setup.map_id)
	var where := str(entry.get("name", "No map")) if not entry.is_empty() else "No map"
	if setup.outdoors():
		where += " · " + ("day" if setup.time == "day" else "night")
	_side.add_child(UiKit.label(where, 16, "gilt_light", SIDE_W))
	_side.add_child(UiKit.label(str(entry.get("region", "")), 13, "parchment", SIDE_W))
	_side.add_child(UiParts.section("Heroes"))
	if setup.party.is_empty():
		_side.add_child(UiKit.label("None yet", 14, "bone"))
	for i in setup.party.size():
		var b := setup.party[i].get("build", {}) as Dictionary
		_side.add_child(UiKit.label("%s · level %d" % [str(b.get("name", "Hero")), setup.levels()[i]], 14, "vellum", SIDE_W))
	_side.add_child(UiParts.section("Foes"))
	if setup.foes.is_empty():
		_side.add_child(UiKit.label("None yet", 14, "bone"))
	for line in _foe_lines():
		_side.add_child(UiKit.label(line, 14, "vellum", SIDE_W))
	var diff := setup.difficulty()
	if diff != "":
		var b := setup.budgets()
		var pill_row := HBoxContainer.new()
		pill_row.add_child(UiParts.pill(diff.capitalize(), str(DIFFICULTY_COLOURS.get(diff, "gilt")), 13))
		pill_row.tooltip_text = "%d XP of foes. The 2024 DMG's budgets for this party: Low %d, Moderate %d, High %d." % [setup.xp_total(), b[0], b[1], b[2]]
		pill_row.add_child(UiParts.gap())
		pill_row.add_child(UiKit.label("%d XP" % setup.xp_total(), 13, "parchment"))
		_side.add_child(pill_row)
	_side.add_child(UiParts.gap())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(spacer)
	var fight := UiParts.primary_button("Fight", _fight)
	fight.name = "Fight"
	fight.disabled = setup.problem() != ""
	fight.tooltip_text = setup.problem()
	fight.size_flags_horizontal = Control.SIZE_FILL
	_side.add_child(fight)
	var back := UiKit.button("Back to the title", _to_title, 15)
	back.tooltip_text = "Esc. The setup stays as it is for next time."
	_side.add_child(back)


func _foe_lines() -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for f in setup.foes:
		var mid := str(f["monster"])
		if seen.has(mid):
			continue
		seen[mid] = true
		var n := setup.foe_count(mid)
		var nm := str(Compendium.shared().monster_data(mid).get("name", mid))
		out.append(("%d × %s" % [n, nm]) if n > 1 else nm)
	return out


static func _scroll_list() -> Array:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	return [UiParts.fill_scroll(list), list]


func _search(placeholder: String, on_change: Callable) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = _filter
	field.clear_button_enabled = true
	field.add_theme_font_size_override("font_size", 15)
	field.text_changed.connect(func(t: String) -> void:
		_filter = t
		on_change.call())
	return field


# --- Party and the Character Lab ------------------------------------------------------------------

func _party_tab() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(UiParts.section("The party (%d of %d)" % [setup.party.size(), SkirmishSetup.PARTY_CAP]))
	for i in setup.party.size():
		left.add_child(_hero_card(i))
	var add := UiKit.button("Add a hero", func() -> void:
		_select_hero(-1)
		_redraw(), 16)
	add.disabled = setup.party.size() >= SkirmishSetup.PARTY_CAP
	add.tooltip_text = "" if not add.disabled else "Four heroes at most, as in the story."
	if hero_index == -1:
		UiParts.light_up(add)
	left.add_child(add)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	if hero_index < 0 or lab_hero == null:
		_add_page(right)
	else:
		_lab_page(right)


func _hero_card(i: int) -> Control:
	var ch := setup.hero(i) if i != hero_index or lab_hero == null else lab_hero
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 58.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var n := UiKit.label(ch.name, 16, "gilt_light", 230)
	n.add_theme_font_override("font", UiKit.display_font())
	col.add_child(n)
	col.add_child(UiKit.label("Level %d · %s" % [ch.character_level(), ch.class_summary()], 12, "parchment", 230))
	col.add_child(UiKit.label("%d HP · AC %d" % [ch.max_hp(), ch.ac_value()], 12, "bone"))
	line.add_child(col)
	return UiParts.click_row(line, func() -> void:
		_select_hero(i)
		_redraw(), i == hero_index)


func _select_hero(i: int) -> void:
	hero_index = i if i >= 0 and i < setup.party.size() else -1
	lab_hero = setup.hero(hero_index) if hero_index >= 0 else null


## Writes the Lab's hero back into the setup.
func _store() -> void:
	if hero_index >= 0 and lab_hero != null:
		setup.set_hero(hero_index, lab_hero)


func _level_picker(level: int, on_set: Callable, lowest: int = 1, highest: int = HeroLab.MAX_LEVEL) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var down := UiParts.small_button("−", func() -> void: on_set.call(level - 1))
	down.disabled = level <= lowest
	row.add_child(down)
	var l := UiParts.figure("Level %d" % level, 20, "gilt_light")
	l.custom_minimum_size = Vector2(96, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(l)
	var up := UiParts.small_button("+", func() -> void: on_set.call(level + 1))
	up.disabled = level >= highest
	row.add_child(up)
	row.add_child(UiKit.label("  to", 13, "parchment"))
	for q in QUICK_LEVELS:
		var b := UiParts.small_button(str(q), func() -> void: on_set.call(q))
		if q == level:
			UiParts.light_up(b)
		b.disabled = q < lowest or q > highest
		row.add_child(b)
	return row


## The page that adds a hero: a pregen, a quick hero of any class, or one made in the hero creator, at the level set.
func _add_page(box: VBoxContainer) -> void:
	box.add_child(UiParts.section("Add a hero"))
	box.add_child(_level_picker(add_level, func(l: int) -> void:
		add_level = clampi(l, 1, HeroLab.MAX_LEVEL)
		_redraw()))
	box.add_child(UiKit.label("The pregens follow their own level plans to 11 and the Lab's picks after that. A quick hero takes its class's recommended scores and the first sensible picks; open the Lab to change any of it.", 13, "parchment", 820))
	box.add_child(UiParts.section("The company"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var pregens := Compendium.shared().all("pregens")
	pregens.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return bool(a.get("roster", false)) and not bool(b.get("roster", false)) if bool(a.get("roster", false)) != bool(b.get("roster", false)) else str(a["name"]) < str(b["name"]))
	for d in pregens:
		grid.add_child(_pregen_card(d))
	box.add_child(grid)
	box.add_child(UiParts.section("A quick hero of any class"))
	var classes := HFlowContainer.new()
	classes.add_theme_constant_override("h_separation", 6)
	classes.add_theme_constant_override("v_separation", 6)
	for c in Compendium.shared().all_playable("classes"):
		var cid := str(c["id"])
		var b := UiParts.small_button(str(c["name"]), func() -> void: _add_quick(cid))
		b.tooltip_text = str(c.get("summary", ""))
		b.disabled = setup.party.size() >= SkirmishSetup.PARTY_CAP
		classes.add_child(b)
	box.add_child(classes)
	box.add_child(UiParts.section("Your own"))
	var own := UiKit.button("Make a hero in the creator", _open_creator, 15, "create")
	own.disabled = setup.party.size() >= SkirmishSetup.PARTY_CAP
	own.tooltip_text = "Looks, voice, class and the rest, as for the story. They join at level 1; the Lab levels them up."
	own.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(own)


func _pregen_card(d: Dictionary) -> Control:
	var id := str(d["id"])
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiParts.framed_portrait(id, 84.0))
	var n := UiKit.label(str(d.get("name", id)).get_slice(" ", 0), 14, "gilt_light", 110)
	n.add_theme_font_override("font", UiKit.display_font())
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var summary := str(d.get("summary", ""))
	var card := UiParts.click_row(col, func() -> void: _add_pregen(id), false,
		func() -> Control: return UiParts.rules_tip(str(d.get("name", id)), "Add at level %d" % add_level, summary))
	card.custom_minimum_size = Vector2(118, 0)
	return card


func _add_pregen(id: String) -> void:
	var errors: Array[String] = []
	var ch := HeroLab.pregen(id, add_level, errors)
	if ch == null:
		say("Couldn't build %s: %s" % [id, ", ".join(errors)])
		return
	_add(ch, id, errors)


func _add_quick(class_id: String) -> void:
	var ch := HeroLab.quick_hero(class_id, add_level, "human", _quick_name(class_id))
	if ch == null:
		say("Couldn't build a quick %s" % class_id)
		return
	_add(ch, "", [])


## "Lab Fighter", or "Lab Fighter 2" when there's one already.
func _quick_name(class_id: String) -> String:
	var base := "Lab %s" % Compendium.shared().display_name("classes", class_id)
	var taken := {}
	for p in setup.party:
		taken[str((p.get("build", {}) as Dictionary).get("name", ""))] = true
	var n := 1
	var out := base
	while taken.has(out):
		n += 1
		out = "%s %d" % [base, n]
	return out


func _add(ch: Character, pregen: String, errors: Array[String]) -> void:
	if not setup.add_hero(ch, pregen):
		say("The party is full.")
		return
	_select_hero(setup.party.size() - 1)
	say("%s joins at level %d.%s" % [ch.name, ch.character_level(), (" " + ", ".join(errors)) if not errors.is_empty() else ""])
	_redraw()


func _open_creator() -> void:
	creation = CreationScreen.new()
	layer.visible = false
	add_child(creation)
	creation.finished.connect(func(made: Array[Character]) -> void:
		_close_creator()
		var ch := made[0]
		ch.finish_long_rest()
		_add(ch, "", []))
	creation.cancelled.connect(func() -> void:
		_close_creator()
		_redraw())
	var others: Array[String] = []
	for i in setup.party.size():
		if setup.pregen_of(i) != "":
			others.append(setup.pregen_of(i))
	creation.open_hero(others)


func _close_creator() -> void:
	if creation != null:
		creation.queue_free()
		creation = null
	layer.visible = true


## The Character Lab for one hero: their level (one at a time with the Lab's picks, by hand on the level-up screen,
## or straight to a level), the sheet and inventory screens, and any item to give them.
func _lab_page(box: VBoxContainer) -> void:
	var ch := lab_hero
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 92.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UiKit.label(ch.name, 26, "gilt_light")
	n.add_theme_font_override("font", UiKit.display_font())
	col.add_child(n)
	col.add_child(UiKit.label(ch.class_summary(), 15, "parchment", 600))
	col.add_child(UiKit.label("%d Hit Points · AC %d · Speed %d ft · Proficiency %s" % [ch.max_hp(), ch.ac_value(),
		ch.speed().total(), UiKit.signed(ch.proficiency_bonus())], 14, "vellum"))
	col.add_child(UiKit.label(_gear_line(ch), 13, "bone", 600))
	head.add_child(col)
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	tools.add_child(UiParts.small_button("Sheet", func() -> void: open_screen("sheet", 0), "sheet"))
	tools.add_child(UiParts.small_button("Inventory", func() -> void: open_screen("inventory", 0), "inventory"))
	tools.add_child(UiParts.small_button("Remove", _remove_hero))
	head.add_child(tools)
	box.add_child(head)
	box.add_child(UiParts.section("Level"))
	var lowest := ch.character_level() - (undo.get(hero_index, []) as Array).size()
	if setup.pregen_of(hero_index) != "":
		lowest = 1
	box.add_child(_level_picker(ch.character_level(), _set_level, maxi(1, lowest)))
	var by_hand := UiKit.button("Take the next level by hand", _level_by_hand, 14, "level_up")
	by_hand.disabled = ch.character_level() >= HeroLab.MAX_LEVEL
	by_hand.tooltip_text = "The level-up screen, as in the story: choose the class (multiclassing too), Hit Points, and every pick."
	by_hand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(by_hand)
	box.add_child(UiParts.section("Give an item"))
	box.add_child(_search("Search every item: a +1 weapon, a Flame Tongue, a Cloak of Protection, potions...", _fill_items))
	var pair := _scroll_list()
	box.add_child(pair[0])
	_list = pair[1]
	_fill_items()


## What the hero holds and wears, and how many attunement places are taken.
static func _gear_line(ch: Character) -> String:
	var parts: Array[String] = []
	for slot: String in ["main_hand", "off_hand", "armor"]:
		var it := ch.equipped(slot)
		if not it.is_empty():
			parts.append(str(it.get("name", it.get("id", ""))))
	for slot: String in MagicItems.WORN_SLOTS:
		for it in ch.equipped_all(slot):
			parts.append(str(it.get("name", it.get("id", ""))))
	var line := ", ".join(parts) if not parts.is_empty() else "Nothing in hand or worn"
	return "%s · attuned to %d of %d" % [line, ch.attuned.size(), Character.MAX_ATTUNED]


func _fill_items() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var words := _filter.strip_edges().to_lower()
	var shown := 0
	for d in HeroLab.all_items():
		var nm := str(d.get("name", d["id"]))
		if words != "" and not nm.to_lower().contains(words) and not str(d.get("category", "")).contains(words):
			continue
		if words == "" and not MagicItems.is_magic(d):
			continue   # magic items first; a search finds the rest
		shown += 1
		if shown > LIST_CAP:
			_list.add_child(UiKit.label("More... type to narrow the list.", 13, "parchment"))
			break
		var id := str(d["id"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		UiParts.add_icon(line, "item", id, 26.0)
		line.add_child(UiKit.label(nm, 15, "vellum"))
		line.add_child(UiParts.gap())
		var tags: Array[String] = []
		if MagicItems.is_magic(d):
			tags.append(MagicItems.rarity(d).replace("_", " "))
		tags.append(str(d.get("category", "")))
		if MagicItems.needs_attunement(d):
			tags.append("attunement")
		line.add_child(UiKit.label(" · ".join(tags), 12, "parchment"))
		_list.add_child(UiParts.click_row(line, func() -> void: _give(id), false,
			func() -> Control: return UiParts.rules_tip(nm, " · ".join(tags), str(d.get("summary", d.get("text", ""))))))


func _give(item_id: String) -> void:
	say(HeroLab.give(lab_hero, item_id))
	_store()
	_redraw()


func _remove_hero() -> void:
	if hero_index < 0:
		return
	setup.party.remove_at(hero_index)
	undo.clear()
	_select_hero(mini(hero_index, setup.party.size() - 1))
	_redraw()


## Takes the hero to `level`: up with the Lab's picks (each level can be taken back), down by taking levels back,
## or for a pregen by rebuilding it at that level.
func _set_level(level: int) -> void:
	level = clampi(level, 1, HeroLab.MAX_LEVEL)
	var ch := lab_hero
	var steps := undo.get(hero_index, []) as Array
	var errors: Array[String] = []
	if level > ch.character_level():
		var cls := ch.class_order[0] if not ch.class_order.is_empty() else ""
		while ch.character_level() < level:
			steps.append(ch.to_dict())
			if not HeroLab.level_once(ch, cls, errors):
				steps.pop_back()
				break
	elif level < ch.character_level():
		while ch.character_level() > level and not steps.is_empty():
			ch = Character.from_dict(steps.pop_back() as Dictionary)
		if ch.character_level() > level and setup.pregen_of(hero_index) != "":
			ch = HeroLab.pregen(setup.pregen_of(hero_index), level, errors)
			steps.clear()
	undo[hero_index] = steps
	if ch != null:
		ch.finish_long_rest()
		lab_hero = ch
		_store()
	say("%s is level %d.%s" % [lab_hero.name, lab_hero.character_level(), (" " + ", ".join(errors)) if not errors.is_empty() else ""])
	_redraw()


## The game's level-up screen for the next level; Escape there leaves the hero as they were.
func _level_by_hand() -> void:
	var steps := undo.get(hero_index, []) as Array
	steps.append(lab_hero.to_dict())
	undo[hero_index] = steps
	open_screen("level_up", 0)


# --- The game's own party screens, for the Lab's hero ---------------------------------------------

## The level-up, sheet and inventory screens call these on their root, as they do in the story.
func open_screen(kind: String, _index: int) -> void:
	close_screen(false)
	if lab_hero == null:
		return
	lab_state.party.clear()
	lab_state.party.append(lab_hero)
	lab_state.lab_target = lab_hero.character_level() + 1 if kind == "level_up" else lab_hero.character_level()
	match kind:
		"level_up":
			screen = LevelUpScreen.new()
		"sheet":
			screen = CharacterSheetScreen.new()
		"inventory":
			screen = InventoryScreen.new()
		_:
			return
	Audio.sfx("page")
	layer.visible = false
	add_child(screen)
	screen.call("open", self, lab_state, 0)


func close_screen(redraw: bool = true) -> void:
	if screen == null:
		return
	screen.queue_free()
	screen = null
	layer.visible = true
	# A level-up left without confirming takes nothing.
	var steps := undo.get(hero_index, []) as Array
	if not steps.is_empty() and int((((steps.back() as Dictionary).get("build", {}) as Dictionary).get("levels", []) as Array).size()) == lab_hero.character_level():
		steps.pop_back()
	_store()
	if redraw:
		_redraw()


## The inventory screen asks its root to refresh after a change.
func _refresh() -> void:
	_store()


# --- Foes -----------------------------------------------------------------------------------------

func _foes_tab() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(UiParts.section("The stat blocks (%d)" % SkirmishSetup.monsters().size()))
	left.add_child(_search("Search by name or kind: wolf, undead, dragon, Strahd...", _fill_foes))
	var pair := _scroll_list()
	left.add_child(pair[0])
	_list = pair[1]
	_fill_foes()
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	right.add_child(UiParts.section("Chosen (%d of %d)" % [setup.foes.size(), SkirmishSetup.MAX_FOES],
		UiParts.small_button("Clear", func() -> void:
			setup.foes.clear()
			_redraw())))
	var seen := {}
	for f in setup.foes:
		var mid := str(f["monster"])
		if seen.has(mid):
			continue
		seen[mid] = true
		right.add_child(_chosen_row(mid))
	if setup.foes.is_empty():
		right.add_child(UiKit.label("Click a stat block to add one. Add it again for more.", 14, "bone", 360))


func _fill_foes() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var words := _filter.strip_edges().to_lower()
	for d in SkirmishSetup.monsters():
		var nm := str(d.get("name", d["id"]))
		var kind := str(d.get("type", ""))
		if words != "" and not nm.to_lower().contains(words) and not kind.to_lower().contains(words):
			continue
		var mid := str(d["id"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var cr := UiParts.figure("CR " + SkirmishSetup.cr_text(d.get("cr", 0)), 15, "gilt")
		cr.custom_minimum_size = Vector2(64, 0)
		line.add_child(cr)
		line.add_child(UiKit.label(nm, 16, "vellum"))
		var n := setup.foe_count(mid)
		if n > 0:
			line.add_child(UiParts.pill("× %d" % n, "gilt_light", 12))
		line.add_child(UiParts.gap())
		line.add_child(UiKit.label("%s %s · %d HP · AC %d · %d XP" % [str(d.get("size", "")).capitalize(), kind,
			int((d.get("hp", {}) as Dictionary).get("average", 0)), _ac_of(d), int(d.get("xp", 0))], 13, "parchment"))
		var summary := str(d.get("summary", ""))
		_list.add_child(UiParts.click_row(line, func() -> void: _add_foe(mid), n > 0,
			func() -> Control: return UiParts.rules_tip(nm, "CR %s %s" % [SkirmishSetup.cr_text(d.get("cr", 0)), kind], summary)))


static func _ac_of(d: Dictionary) -> int:
	var ac: Variant = d.get("ac", 10)
	if ac is Dictionary:
		return int((ac as Dictionary).get("value", 10))
	if ac is Array and not (ac as Array).is_empty():
		var first: Variant = (ac as Array)[0]
		return int((first as Dictionary).get("value", 10)) if first is Dictionary else int(first)
	return int(ac)


func _add_foe(mid: String) -> void:
	if not setup.add_foe(mid):
		say("%d foes at most." % SkirmishSetup.MAX_FOES)
		return
	say("Added %s." % str(Compendium.shared().monster_data(mid).get("name", mid)))
	_redraw()


func _chosen_row(mid: String) -> Control:
	var d := Compendium.shared().monster_data(mid)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.add_child(UiKit.label(str(d.get("name", mid)), 15, "vellum"))
	line.add_child(UiParts.gap())
	line.add_child(UiParts.small_button("−", func() -> void:
		setup.remove_foe(mid)
		_redraw()))
	line.add_child(UiParts.figure(str(setup.foe_count(mid)), 16, "gilt_light"))
	var plus := UiParts.small_button("+", func() -> void: _add_foe(mid))
	plus.disabled = setup.foes.size() >= SkirmishSetup.MAX_FOES
	line.add_child(plus)
	return UiParts.row(line)


# --- Field ----------------------------------------------------------------------------------------

func _field_tab() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(UiParts.section("Maps"))
	left.add_child(_search("Search: Vallaki, castle, road...", _fill_maps))
	var pair := _scroll_list()
	left.add_child(pair[0])
	_list = pair[1]
	_fill_maps()
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	var entry := SkirmishSetup.map_entry(setup.map_id)
	right.add_child(UiParts.section(str(entry.get("name", "No map"))))
	sketch = MapSketch.new()
	sketch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sketch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sketch.custom_minimum_size = Vector2(600, 420)
	right.add_child(sketch)
	_show_sketch()
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	if setup.outdoors():
		options.add_child(UiKit.label("Time", 14, "parchment"))
		for t: Array in [["day", "Day"], ["night", "Night"]]:
			var key := str(t[0])
			var b := UiParts.small_button(str(t[1]), func() -> void:
				setup.time = key
				_redraw())
			if setup.time == key:
				UiParts.light_up(b)
			options.add_child(b)
	else:
		options.add_child(UiKit.label("Indoors: the place's own light (%s)" % str((entry.get("map", {}) as Dictionary).get("light", "dim")), 14, "parchment"))
	options.add_child(UiParts.gap())
	options.add_child(UiKit.label("Surprise", 14, "parchment"))
	for s: Array in [["", "None"], ["enemies", "The foes"], ["party", "The party"]]:
		var key := str(s[0])
		var b := UiParts.small_button(str(s[1]), func() -> void:
			setup.surprise = key
			_redraw())
		if setup.surprise == key:
			UiParts.light_up(b)
		options.add_child(b)
	right.add_child(options)


## Draws the chosen map with everyone where they'd start.
func _show_sketch() -> void:
	if sketch == null:
		return
	var g := setup.grid()
	if g == null:
		return
	var cells := setup.placements(g)
	sketch.show_map(g, setup.furniture(), marks_for(setup, cells))


## The sketch's marks for `cells` (SkirmishSetup.placements): heroes by initial, foes numbered.
static func marks_for(s: SkirmishSetup, cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pc := cells["party"] as Array[Vector2i]
	for i in pc.size():
		var nm := str((s.party[i].get("build", {}) as Dictionary).get("name", "?"))
		out.append({"cell": pc[i], "size": 1, "side": "party", "label": nm.left(1)})
	var fc := cells["foes"] as Array[Vector2i]
	for i in fc.size():
		var data := Compendium.shared().monster_data(str(s.foes[i]["monster"]))
		out.append({"cell": fc[i], "size": CombatGrid.size_cells_for(StringName(str(data.get("size", "medium")))),
			"side": "enemy", "label": str(i + 1)})
	return out


func _fill_maps() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var words := _filter.strip_edges().to_lower()
	var region := ""
	for m in SkirmishSetup.maps():
		var nm := str(m["name"])
		if words != "" and not nm.to_lower().contains(words) and not str(m["region"]).to_lower().contains(words):
			continue
		if str(m["region"]) != region:
			region = str(m["region"])
			_list.add_child(UiKit.label(region, 13, "gilt"))
		var id := str(m["id"])
		var rows := (m["map"] as Dictionary)["rows"] as Array
		var line := HBoxContainer.new()
		line.add_child(UiKit.label(nm, 15, "vellum"))
		line.add_child(UiParts.gap())
		line.add_child(UiKit.label("%d × %d" % [str(rows[0]).length(), rows.size()], 12, "parchment"))
		_list.add_child(UiParts.click_row(line, func() -> void:
			if setup.map_id != id:
				setup.map_id = id
				setup.unpin()
			_redraw(), id == setup.map_id))


# --- Saved setups ---------------------------------------------------------------------------------

func _saved_tab() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_body.add_child(box)
	box.add_child(UiParts.section("Save this setup"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var field := LineEdit.new()
	field.text = setup.title
	field.placeholder_text = "A name for it"
	field.custom_minimum_size = Vector2(420, 0)
	field.add_theme_font_size_override("font_size", 15)
	field.text_changed.connect(func(t: String) -> void: setup.title = t.strip_edges() if t.strip_edges() != "" else "Skirmish")
	row.add_child(field)
	row.add_child(UiKit.button("Save", _save, 15, "save"))
	box.add_child(row)
	box.add_child(UiKit.label("Saving under a name that's taken replaces that setup. Heroes are saved as they are, items and all.", 13, "parchment"))
	box.add_child(UiParts.section("Saved setups"))
	var pair := _scroll_list()
	box.add_child(pair[0])
	var list := pair[1] as VBoxContainer
	var saved := SkirmishLibrary.list()
	if saved.is_empty():
		list.add_child(UiKit.label("Nothing saved yet.", 14, "bone"))
	for s in saved:
		var file := str(s["file"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.add_child(UiKit.label(str(s["title"]), 16, "gilt_light"))
		var entry := SkirmishSetup.map_entry(str(s["map"]))
		line.add_child(UiKit.label("%s · %d heroes · %d foes · %s" % [str(entry.get("name", "?")), int(s["heroes"]), int(s["foes"]),
			str(s["saved_at"]).replace("T", " ").left(16)], 13, "parchment"))
		line.add_child(UiParts.gap())
		line.add_child(UiParts.small_button("Load", func() -> void: _load(file)))
		line.add_child(UiParts.small_button("Delete", func() -> void:
			SkirmishLibrary.delete(file)
			say("Deleted.")
			_redraw()))
		list.add_child(UiParts.row(line))


func _save() -> void:
	var file := SkirmishLibrary.save(setup)
	say("Saved as “%s”." % setup.title if file != "" else "Couldn't save.")
	_redraw()


func _load(file: String) -> void:
	var s := SkirmishLibrary.load_setup(file)
	if s == null:
		say("Couldn't read that setup.")
		return
	setup = s
	current = s
	undo.clear()
	_select_hero(0)
	say("Loaded “%s”." % s.title)
	_redraw()


# --- Leaving --------------------------------------------------------------------------------------

func _fight() -> void:
	if setup.problem() != "":
		say(setup.problem())
		return
	var errors: Array[String] = []
	var g := setup.grid()
	setup.placements(g, errors)
	if not errors.is_empty():
		say(", ".join(errors))
		return
	current = setup
	CombatArena.skirmish = setup.duplicate_setup()
	Dice.reseed_random()   # every fight rolls its own dice
	get_tree().change_scene_to_file(ARENA_SCENE)


func _to_title() -> void:
	current = setup
	get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if creation != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if screen != null:
			close_screen()
		else:
			_to_title()
