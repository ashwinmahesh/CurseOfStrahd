class_name CombatHud
extends CanvasLayer
## The combat screen (docs/ui/combat_view.md, wireframes cb_01-03, approved 2026-10-06): initiative strip on top,
## party frames on the left, the combat log on the right, the hotbar with the action economy and End Turn at the
## bottom, plus the target tooltip, reaction prompts, roll details, banners and the controller's radial menu.
## It reads the Encounter and the ActionCatalog and never computes rules itself. Drawn on a CanvasLayer so the
## palette pass never touches it (plan §5.6).

signal action_chosen(action: Dictionary)
signal end_turn_pressed
## Undo move (or Ctrl+Z): take back the current creature's last move (Encounter.undo_move).
signal undo_move_pressed
signal reaction_answered(use: bool, rule: String)
signal inspect_requested(combatant_id: String)
## A click on a party frame's portrait: that hero's character sheet, view only (CombatView.sheet_requested).
signal sheet_requested(combatant_id: String)
signal death_save_pressed
signal slot_level_changed(level: int)
signal radial_picked(choice: String)
## Right-click → "Cast at level N" on a spell slot.
signal cast_at_level(action: Dictionary, level: int)
## A choice from the right-click menu on a square of the board.
signal square_picked(id: String)

const COST_COLOURS := {"action": "moss", "attack": "moss", "bonus": "gilt", "reaction": "mist_blue", "free": "slate",
	"movement": "moon_blue"}
const SLOT_SIZE := Vector2(132, 50)
## The target box's outline when an attack would roll with Advantage or Disadvantage.
const EDGE_COLOURS := {"advantage": "bile", "disadvantage": "vampire_red"}
## {action} reads as the player's key for it (InputActions.fill, Settings, Keys).
const CONTROLS: Array[String] = [
	"Mouse: hover the floor to see your path and its cost; click to move. Hover an enemy for the odds; click to attack with the best weapon that reaches. Right-click on the field cancels; right-click a hotbar slot for Info, Use and the spell's casting level.",
	"Keyboard: {combat_toggle_log} minimizes or restores the combat log · {combat_slot_1}-{combat_slot_10} use hotbar slots · {combat_tab_prev} / {combat_tab_next} change tab · {combat_confirm} confirms (casts early with fewer targets) · Esc cancels · {combat_end_turn} ends the turn · Ctrl+Z takes back the last move · {combat_slot_level_down} and {combat_slot_level_up} change the spell slot · {combat_next_target} jumps to the next target · {cycle_leader} inspects the next party member · C opens the character sheet of the one shown (view only; or click a party portrait) · {quick_save} quicksaves and {quick_load} loads the quicksave (outside a fight; in one, the game saves at each round's start).",
	"Camera: {walk} pan · {camera_rotate_left} / {camera_rotate_right} rotate · mouse wheel zooms.",
	"Controller: left stick moves the cursor (the camera follows) · right stick turns and zooms the camera · {a} confirms · {b} cancels · {@combat_next_target} next target · {@combat_end_turn} ends the turn (while picking targets, casts with those picked) · hold {@combat_radial} for the radial menu (right stick picks, release to choose) · {@combat_slot_prev} / {@combat_slot_next} pick a hotbar slot · {@combat_use_slot} uses it · {@combat_tab_prev} / {@combat_tab_next} change tab · {@combat_slot_level_down} / {@combat_slot_level_up} change the spell slot · {@combat_undo} takes back the last move · {@combat_square_menu} the square's menu at the cursor · {@combat_controls} these controls · {start} menu. Settings, Keys, Controller moves them.",
	"Reactions always ask unless you set a rule: in the prompt (Next time: Ask me / Always use it / Never), or on the Reactions tab, where a click on a rule steps it through Ask, Automatic and Off on any turn. A slot with a gilt corner holds choices: click it to pick one.",
]

var e: Encounter
var catalog: ActionCatalog
## The party member whose hotbar is shown (the active one on their turn, or whoever the player inspects).
var shown: Combatant = null
var tab: String = ActionCatalog.COMMON
## Index into the visible slots the controller has highlighted (-1 none).
var focus_slot := -1
## The upcast pips for the spell being aimed.
var slot_levels: Array[int] = []
var slot_level := 0

var _strip: HBoxContainer
var _round_label: Label
var _party_box: VBoxContainer
var _log: RichTextLabel
var _log_count := 0
var _portrait: TextureRect
var _hot_name: Label
var _hot_stats: Label
var _economy: EconomyShapes
var _move_bar: ProgressBar
var _move_label: Label
var _tabs: HBoxContainer
## The slot rows: one grid, or on the Spells tab a row of grids by spell level (SpellGroups) with the level beside each.
var _slots: VBoxContainer
var _slot_buttons: Array[Button] = []
var _slot_actions: Array[Dictionary] = []
var _end_turn: Button
var _undo_move: Button
var _turn_note: Label
var _tooltip: PanelContainer
## The odds over a pointed-at target's head (show_odds).
var _odds: PanelContainer
var _odds_chance: Label
var _odds_damage: Label
var _tooltip_box: VBoxContainer
var _prompt: PanelContainer
var _prompt_title: Label
var _prompt_text: Label
var _prompt_cost: Label
var _prompt_rule: OptionButton
var _prompt_targets: VBoxContainer
var _prompt_use: Button
var _details: PanelContainer
var _details_box: VBoxContainer
var _banner: Label
var _banner_time := 0.0
var _confirm: PanelContainer
var _confirm_text: Label
var _pips: HBoxContainer
## Above the hotbar (Baldur's Gate 3's resource row): spell slots and the class's own resources as pips.
var _slot_box: PanelContainer
## The weapon sets on the portrait: the main hand of the set in hand, then the other set's.
var _weapons: VBoxContainer
var _slot_row: HBoxContainer
var _menu: ContextMenu
var _menu_action: Dictionary = {}
var _death_button: Button
var _slot_scroll: ScrollContainer
var radial: RadialMenu
var _portraits: Dictionary = {}
## The log panel can be minimized to its title bar; the choice lasts for the session.
static var log_minimized := false
## It opens compact, over the top right only, and grows to its full height on a click (also for the session).
static var log_tall := false
const LOG_BOTTOM := 600.0
## The reaction prompt: its width, and its bottom edge (above the hotbar, whose top is 244 px up).
const PROMPT_WIDTH := 440.0
const PROMPT_BOTTOM := -254.0
const LOG_COMPACT_BOTTOM := 372.0
var _log_panel: PanelContainer
var _log_title: Label
var _log_toggle: Button
var _log_grow: Button
var _controls: PanelContainer


## Party member id -> when their fall alarm ends (msec).
var _down_alarm := {}


func _init() -> void:
	name = "CombatHud"
	layer = 10


func build(encounter: Encounter, catalog_: ActionCatalog) -> void:
	e = encounter
	catalog = catalog_
	_build_strip()
	_build_party()
	_build_log()
	_build_hotbar()
	_build_tooltip()
	_build_prompt()
	_build_details()
	_build_confirm()
	_build_banner()
	radial = RadialMenu.new()
	radial.anchor_left = 0.5
	radial.anchor_top = 0.5
	radial.anchor_right = 0.5
	radial.anchor_bottom = 0.5
	radial.offset_left = -radial.custom_minimum_size.x / 2.0
	radial.offset_top = -radial.custom_minimum_size.y / 2.0
	radial.picked.connect(func(choice: String) -> void: radial_picked.emit(choice))
	add_child(radial)
	_menu = ContextMenu.new()
	_menu.picked.connect(_on_menu)
	add_child(_menu)
	_controls = _panel("parchment")
	_controls.anchor_left = 0.5
	_controls.anchor_right = 0.5
	_controls.offset_left = -420
	_controls.offset_right = 420
	_controls.offset_top = 150
	_controls.visible = false
	var cbox := VBoxContainer.new()
	_controls.add_child(cbox)
	var head := _label("", 20, "gilt_light")
	PadGlyphs.hint(head, "Controls (F1 to close)", "Controls ({@combat_controls} to close)")
	cbox.add_child(head)
	for line: String in CONTROLS:
		var l := _label(PadGlyphs.names(InputActions.fill(line)), 15, "vellum")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(800, 0)
		cbox.add_child(l)
	add_child(_controls)


func toggle_controls() -> void:
	_controls.visible = not _controls.visible


## Whether the hero whose turn it is has only a Death Saving Throw to roll (the pad's A rolls it).
func death_save_shown() -> bool:
	return _death_button.visible


# --- Building -------------------------------------------------------------------------------------

func _build_strip() -> void:
	var panel := _panel()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = 10
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var head := VBoxContainer.new()
	_round_label = _label("Round 1", 24, "gilt_light")
	head.add_child(_round_label)
	head.add_child(_label("turn order", 14, "parchment"))
	# The controls card's key sits here, out of the way of the party frames (a guest's frame used to cover it).
	var f1 := _label("F1: controls", 12, "gilt_dark")
	PadGlyphs.hint(f1, "F1: controls", "{@combat_controls}: controls")
	head.add_child(f1)
	row.add_child(head)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 6)
	row.add_child(_strip)


func _build_party() -> void:
	_party_box = VBoxContainer.new()
	_party_box.position = Vector2(12, 140)
	_party_box.add_theme_constant_override("separation", 8)
	add_child(_party_box)


func _build_log() -> void:
	_log_panel = _panel()
	_log_panel.anchor_left = 1.0
	_log_panel.anchor_right = 1.0
	_log_panel.offset_left = -420
	_log_panel.offset_right = -12
	_log_panel.offset_top = 140
	_log_panel.offset_bottom = LOG_BOTTOM
	add_child(_log_panel)
	var box := VBoxContainer.new()
	_log_panel.add_child(box)
	var head := HBoxContainer.new()
	_log_title = _label("COMBAT LOG · click a line for the math", 14, "parchment")
	_log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_title.clip_text = true
	head.add_child(_log_title)
	_log_grow = Button.new()
	_log_grow.custom_minimum_size = Vector2(30, 26)
	_log_grow.tooltip_text = "Show more or less of the combat log"
	_log_grow.pressed.connect(grow_log)
	head.add_child(_log_grow)
	_log_toggle = Button.new()
	_log_toggle.custom_minimum_size = Vector2(30, 26)
	_log_toggle.tooltip_text = "Minimize or restore the combat log (L)"
	_log_toggle.pressed.connect(toggle_log)
	head.add_child(_log_toggle)
	box.add_child(head)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(390, 120)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("italics_font_size", 14)
	_log.add_theme_color_override("default_color", Look.color("vellum"))
	_log.meta_clicked.connect(_on_log_meta)
	box.add_child(_log)
	_apply_log_state()


## Minimizes the log to its title bar (showing the latest line) or restores it. Remembered for the session.
func toggle_log() -> void:
	log_minimized = not log_minimized
	_apply_log_state()


## Between the compact log (the latest lines, over the top right only) and the full-height one.
func grow_log() -> void:
	log_tall = not log_tall
	log_minimized = false
	_apply_log_state()


func _apply_log_state() -> void:
	_log.visible = not log_minimized
	_log_toggle.text = "+" if log_minimized else "–"
	_log_grow.text = "▴" if log_tall else "▾"
	_log_grow.visible = not log_minimized
	_log_panel.offset_bottom = _log_panel.offset_top + 46 if log_minimized else (LOG_BOTTOM if log_tall else LOG_COMPACT_BOTTOM)
	_update_log_title()


func _update_log_title() -> void:
	if not log_minimized or e == null or e.log.entries.is_empty():
		_log_title.text = "COMBAT LOG · click a line for the math"
		return
	_log_title.text = "LOG · " + str(e.log.entries.back()["text"])


func _build_hotbar() -> void:
	var panel := _panel()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -640
	panel.offset_right = 520
	panel.offset_top = -244
	panel.offset_bottom = -48
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(150, 0)
	_hot_name = _label("", 19, "gilt_light")
	_hot_name.add_theme_font_override("font", UiKit.display_font())
	card.add_child(_hot_name)
	# The character in the sheet's gilt frame.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(124, 124)
	var under := ColorRect.new()
	under.color = Look.color("ui_black")
	under.position = Vector2(5, 5)
	under.size = Vector2(114, 114)
	holder.add_child(under)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(5, 5)
	_portrait.size = Vector2(114, 114)
	_portrait.custom_minimum_size = Vector2(114, 114)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	holder.add_child(_portrait)
	holder.add_child(UiParts.drawn(Vector2(124, 124), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r.grow(-1), Look.color("gilt"), false, 2.0)
		c.draw_rect(r.grow(-5), Color(Look.color("gilt_dark"), 0.9), false, 1.0)
		for p: Vector2 in [Vector2(1, 1), Vector2(c.size.x - 1, 1), Vector2(1, c.size.y - 1), c.size - Vector2(1, 1)]:
			UiParts.diamond(c, p, 7.0, Look.color("void"), true)
			UiParts.diamond(c, p, 5.0, Look.color("gilt_light"), true)))
	# The weapon sets on the portrait's right edge (Baldur's Gate 3's set switch): what's in hand, and the other set
	# below it, dimmer; a click on either swaps them (free).
	_weapons = VBoxContainer.new()
	_weapons.add_theme_constant_override("separation", 2)
	_weapons.position = Vector2(84, 50)
	holder.add_child(_weapons)
	card.add_child(holder)
	_hot_stats = _label("", 15, "vellum")
	card.add_child(_hot_stats)
	row.add_child(card)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	row.add_child(mid)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	mid.add_child(top)
	_economy = EconomyShapes.new()
	top.add_child(_economy)
	var mv := VBoxContainer.new()
	mv.add_child(UiParts.caption("Movement", 11))
	_move_bar = ProgressBar.new()
	_move_bar.custom_minimum_size = Vector2(220, 14)
	_move_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Look.color("moon_blue")
	var back := StyleBoxFlat.new()
	back.bg_color = Look.color("void")
	back.border_color = Look.color("gilt_dark")
	back.set_border_width_all(1)
	_move_bar.add_theme_stylebox_override("fill", fill)
	_move_bar.add_theme_stylebox_override("background", back)
	mv.add_child(_move_bar)
	_move_label = _label("", 15, "vellum")
	mv.add_child(_move_label)
	top.add_child(mv)
	# The resource row sits on the bar's top edge, left, so the shapes' row keeps its room.
	_slot_box = PanelContainer.new()
	var strip := _style("ui_black", "gilt_dark", 1)
	strip.set_content_margin_all(4)
	strip.content_margin_left = 10
	strip.content_margin_right = 10
	_slot_box.add_theme_stylebox_override("panel", strip)
	_slot_box.anchor_left = 0.5
	_slot_box.anchor_right = 0.5
	_slot_box.anchor_top = 1.0
	_slot_box.anchor_bottom = 1.0
	# Sized by what it holds: it grows right from the bar's left end and up from the bar's top edge.
	_slot_box.offset_left = -620
	_slot_box.offset_right = -620
	_slot_box.offset_top = -243
	_slot_box.offset_bottom = -243
	_slot_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 16)
	_slot_box.add_child(_slot_row)
	add_child(_slot_box)
	_pips = HBoxContainer.new()
	top.add_child(_pips)
	_turn_note = _label("", 16, "gilt_light")
	top.add_child(_turn_note)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	mid.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 112)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_slot_scroll = scroll
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 6)
	scroll.add_child(_slots)
	_end_turn = Button.new()
	_end_turn.text = "End\nTurn"
	_end_turn.custom_minimum_size = Vector2(108, 108)
	_end_turn.add_theme_font_size_override("font_size", 20)
	_end_turn.add_theme_stylebox_override("normal", _round_style("blood"))
	_end_turn.add_theme_stylebox_override("hover", _round_style("crimson", "gilt_light"))
	_end_turn.add_theme_stylebox_override("pressed", _round_style("blood_deep", "gilt_light"))
	_end_turn.add_theme_stylebox_override("disabled", _round_style("ui_oxblood", "gilt_dark"))
	_end_turn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_end_turn.add_theme_font_override("font", UiKit.display_font())
	_end_turn.add_theme_color_override("font_color", Look.color("gilt_light"))
	_end_turn.add_theme_color_override("font_hover_color", Look.color("ivory"))
	_end_turn.add_theme_color_override("font_disabled_color", Look.color("gilt_dark"))
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_end_turn.anchor_left = 0.5
	_end_turn.anchor_right = 0.5
	_end_turn.anchor_top = 1.0
	_end_turn.anchor_bottom = 1.0
	_end_turn.offset_left = 536
	_end_turn.offset_right = 644
	_end_turn.offset_top = -196
	_end_turn.offset_bottom = -88
	add_child(_end_turn)
	# Under End Turn, lit while the last move can still be taken back. It never takes focus, so Space and Enter
	# still end the turn and confirm.
	_undo_move = Button.new()
	_undo_move.text = "Undo move"
	_undo_move.tooltip_text = "Take back the last move (Ctrl+Z) while nothing has come of it"
	UiKit.button_look(_undo_move)
	UiParts.compact(_undo_move)
	_undo_move.add_theme_font_size_override("font_size", 15)
	_undo_move.focus_mode = Control.FOCUS_NONE
	_undo_move.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_undo_move.offset_left = 526
	_undo_move.offset_right = 654
	_undo_move.offset_top = -80
	_undo_move.offset_bottom = -48
	_undo_move.pressed.connect(func() -> void: undo_move_pressed.emit())
	add_child(_undo_move)
	_death_button = Button.new()
	_death_button.text = "Roll Death Saving Throw"
	_death_button.visible = false
	_death_button.custom_minimum_size = Vector2(260, 48)
	_death_button.pressed.connect(func() -> void: death_save_pressed.emit())
	mid.add_child(_death_button)


func _build_tooltip() -> void:
	_odds = _panel("gilt_dark", "ui_black", false)
	_odds.visible = false
	_odds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ob := VBoxContainer.new()
	ob.add_theme_constant_override("separation", -4)
	ob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_odds.add_child(ob)
	_odds_chance = _label("", 30, "gilt_light")
	_odds_chance.add_theme_font_override("font", UiKit.display_font())
	_odds_chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_child(_odds_chance)
	_odds_damage = _label("", 14, "vellum")
	_odds_damage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_child(_odds_damage)
	add_child(_odds)
	_tooltip = _panel("gilt", "ui_black", false)
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_box = VBoxContainer.new()
	_tooltip.add_child(_tooltip_box)
	add_child(_tooltip)


func _build_prompt() -> void:
	_prompt = _panel("gilt_light")
	_prompt.set_meta(&"pad_modal", true)   # while it's up the pad moves over it alone (PadNav)
	# Bottom right, just above the hotbar, growing upward over the log: out of the way of who's hitting whom (UI QA,
	# 2026-10-09; Baldur's Gate 3 keeps its reaction prompt off the action too).
	_prompt.anchor_left = 1.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -PROMPT_WIDTH - 12
	_prompt.offset_right = -12
	_prompt.offset_top = PROMPT_BOTTOM
	_prompt.offset_bottom = PROMPT_BOTTOM
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.visible = false
	add_child(_prompt)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_prompt.add_child(box)
	_prompt_title = _label("", 22, "gilt_light")
	box.add_child(_prompt_title)
	_prompt_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_title.custom_minimum_size = Vector2(PROMPT_WIDTH - 28, 0)
	_prompt_text = _label("", 16, "vellum")
	_prompt_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_text.custom_minimum_size = Vector2(PROMPT_WIDTH - 28, 0)
	box.add_child(_prompt_text)
	_prompt_cost = _label("", 15, "parchment")
	box.add_child(_prompt_cost)
	var target_scroll := ScrollContainer.new()
	target_scroll.custom_minimum_size.y = 120
	target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(target_scroll)
	_prompt_targets = VBoxContainer.new()
	_prompt_targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_scroll.add_child(_prompt_targets)
	var rule_row := HBoxContainer.new()
	rule_row.add_child(_label("Next time: ", 15, "parchment"))
	_prompt_rule = OptionButton.new()
	_prompt_rule.add_item("Ask me")
	_prompt_rule.add_item("Always use it")
	_prompt_rule.add_item("Never")
	rule_row.add_child(_prompt_rule)
	box.add_child(rule_row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var use := Button.new()
	_prompt_use = use
	PadGlyphs.hint(use, "Use Reaction (Enter)", "Use Reaction ({a})")
	use.set_meta(&"pad_first", true)
	use.pressed.connect(func() -> void: answer_prompt(true))
	var skip := Button.new()
	PadGlyphs.hint(skip, "Skip (Esc)", "Skip ({b})")
	skip.pressed.connect(func() -> void: answer_prompt(false))
	buttons.add_child(use)
	buttons.add_child(skip)
	box.add_child(buttons)


func _build_details() -> void:
	_details = _panel("parchment")
	_details.anchor_left = 0.5
	_details.anchor_right = 0.5
	_details.offset_left = -330
	_details.offset_right = 330
	_details.offset_top = 150
	_details.visible = false
	add_child(_details)
	_details_box = VBoxContainer.new()
	_details.add_child(_details_box)


func _build_confirm() -> void:
	_confirm = _panel("gilt_light")
	_confirm.set_meta(&"pad_modal", true)
	_confirm.anchor_left = 0.5
	_confirm.anchor_right = 0.5
	_confirm.anchor_top = 0.5
	_confirm.anchor_bottom = 0.5
	_confirm.offset_left = -240
	_confirm.offset_right = 240
	_confirm.offset_top = -60
	_confirm.visible = false
	add_child(_confirm)
	var box := VBoxContainer.new()
	_confirm.add_child(box)
	_confirm_text = _label("", 18, "vellum")
	box.add_child(_confirm_text)
	var row := HBoxContainer.new()
	var yes := Button.new()
	PadGlyphs.hint(yes, "End turn (%s)" % InputActions.key_text(&"combat_end_turn"), "End turn ({a})")
	yes.set_meta(&"pad_first", true)
	yes.pressed.connect(func() -> void:
		_confirm.visible = false
		end_turn_pressed.emit())
	var no := Button.new()
	PadGlyphs.hint(no, "Keep going (Esc)", "Keep going ({b})")
	no.pressed.connect(func() -> void: _confirm.visible = false)
	row.add_child(yes)
	row.add_child(no)
	box.add_child(row)


func _build_banner() -> void:
	_banner = _label("", 40, "gilt_light")
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 150
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	add_child(_banner)


# --- Refreshing -----------------------------------------------------------------------------------

func refresh() -> void:
	if e == null:
		return
	var cur := e.current()
	if cur != null and cur.is_player_controlled():
		shown = cur
	elif shown == null:
		for c in e.combatants:
			if c.is_player_controlled():
				shown = c
				break
	_round_label.text = "Round %d" % maxi(1, e.round_no)
	# Every card, bar and button reads the same unchanged creatures: one read (Creature.begin_read).
	Creature.begin_read()
	_refresh_strip()
	_refresh_party()
	_refresh_hotbar()
	Creature.end_read()
	refresh_log()


func _refresh_strip() -> void:
	for ch in _strip.get_children():
		ch.queue_free()
	var cur := e.current()
	# The lair's turn sits at initiative count 20 (ADR 0014); legendary creatures show the actions they have left.
	var lair_at := e.legendary.lair_slot()
	for i in e.order.size():
		var c := e.order[i]
		if i == lair_at:
			_strip.add_child(_lair_card())
		if c.creature.dead and c.side == &"enemy":
			continue
		var active := c == cur
		var card := PanelContainer.new()
		var frame := "gilt_light" if c.side == &"party" else ("moonlight" if c.side == &"guest" else "crimson")
		card.add_theme_stylebox_override("panel", _style("ui_oxblood" if not active else "ui_wine", "gilt_light" if active else frame, 4 if active else 2))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		v.add_child(UiParts.framed_portrait(CombatToken.portrait_id(c), 72.0 if active else 54.0, c.is_down(), c.creature.dead))
		var short := c.name().get_slice(" ", 0) if c.side != &"enemy" else c.name().replace("Dire Wolf", "Dire")
		var sl := _label(short, 13 if not active else 15, "gilt_light" if active else "vellum")
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
		v.add_child(_hp_bar(c, 60 if not active else 76))
		var pips := e.legendary.pips(c)
		if pips != "":
			var lg := _label(pips, 13, "crimson")
			lg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lg.tooltip_text = "Legendary actions left this round"
			v.add_child(lg)
		card.mouse_entered.connect(func() -> void: inspect_requested.emit("hover:" + c.id))
		_strip.add_child(card)
	if lair_at == e.order.size():
		_strip.add_child(_lair_card())


## The lair's turn in the order (initiative count 20): ticked once the lair has acted this round.
func _lair_card() -> PanelContainer:
	var card := PanelContainer.new()
	var done := e.legendary.lair_round >= e.round_no
	card.add_theme_stylebox_override("panel", _style("ui_black", "crimson", 2))
	var l := _label("Lair\n20" + (" ✓" if done else ""), 13, "parchment" if done else "vellum")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.tooltip_text = "The lair acts on initiative count 20, losing ties"
	card.add_child(l)
	return card


func _refresh_party() -> void:
	for ch in _party_box.get_children():
		ch.queue_free()
	for c in e.combatants:
		# An Echo Knight's echo is an image on the board, not a member of the party.
		if c.side not in [&"party", &"guest"] or EchoKnight.is_echo(c):
			continue
		var on := c == shown
		var alarm := int(_down_alarm.get(c.id, 0)) > Time.get_ticks_msec()
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style("ui_oxblood" if alarm else "ui_black",
			"vampire_red" if alarm or c.is_down() else ("gilt_light" if on else "gilt_dark"), 4 if alarm else (3 if on else 2)))
		card.custom_minimum_size = Vector2(270, 0)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var btn := Button.new()
		card.add_child(btn)   # under the content, so the effect icons on top can name themselves on hover
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(UiParts.framed_portrait(CombatToken.portrait_id(c), 64.0, c.is_down(), c.creature.dead))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 3)
		v.custom_minimum_size = Vector2(180, 0)
		# The name, then what they are in small pills (a guest, DOWN), so a long name or a fall never widens the frame.
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_constant_override("separation", 5)
		var nm := _label(c.name(), 17, "vampire_red" if c.is_down() else ("gilt_light" if on else "vellum"))
		nm.add_theme_font_override("font", UiKit.display_font())
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.add_child(nm)
		if c.side == &"guest":
			head.add_child(UiParts.pill("Guest", "moonlight", 11))
		if c.is_down() and not c.creature.dead:
			head.add_child(UiParts.pill("DOWN", "vampire_red", 11))
		v.add_child(head)
		v.add_child(_hp_bar(c, 170, 10.0))
		var cr := c.creature
		var status := "%d/%d" % [cr.hp, cr.max_hp()]
		if cr.temp_hp > 0:
			status += " +%d temp" % cr.temp_hp
		var chips := _chips(c)
		if chips != "":
			status += " · " + chips
		# One line, cut with an ellipsis; the whole list is in the frame's tooltip.
		var sl := _label(status, 13, "parchment")
		sl.custom_minimum_size = Vector2(180, 0)
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(sl)
		# What's working on them (Rage, Bladesong, the spell they concentrate on...), an icon each.
		var working := EffectIcons.row(cr, 20.0)
		if working != null:
			v.add_child(working)
		row.add_child(v)
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		for st_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
		btn.pressed.connect(func() -> void: inspect_requested.emit(c.id))
		btn.tooltip_text = "%s · %s\nClick to see their actions" % [c.name(), status]
		if c.creature is Character:
			card.add_child(_sheet_button(c))
		_party_box.add_child(card)


## Over a hero's portrait in their frame: opens their character sheet, view only, while the fight waits.
func _sheet_button(c: Combatant) -> Control:
	var over := Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size = Vector2(64, 64)
	for st_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: sheet_requested.emit(c.id))
	b.tooltip_text = "%s's character sheet (C), view only" % c.name()
	over.add_child(b)
	return over


## A party member just fell: their frame flashes red for a moment (and stays marked DOWN while they're down).
func flash_down(id: String) -> void:
	_down_alarm[id] = Time.get_ticks_msec() + 2500
	_refresh_party()
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if is_inside_tree():
			_refresh_party())


func _chips(c: Combatant) -> String:
	var cr := c.creature
	var parts: Array[String] = []
	if cr.hp <= 0 and not cr.dead:
		parts.append("Stable" if cr.stable else "Dying %d✓ %d✗" % [cr.death_successes, cr.death_failures])
	for cond in cr.active_conditions():
		if cr.hp <= 0 and cond in [&"unconscious", &"incapacitated", &"prone"]:
			continue
		parts.append(str(cond).capitalize())
	if cr.concentration != null:
		parts.append("◎ " + cr.concentration.name)
	var marked := {}
	for fx0 in cr.effects:
		if fx0.data.has("mark_by"):
			marked[str(fx0.data.get("mark_of", ""))] = true
	for fx in cr.effects:
		# A marked creature shows "Hexed by ..." once, not the spell's own effect beside it.
		if marked.has(fx.source_id):
			continue
		if fx.data.has("mark_by"):
			parts.append(fx.name)
			continue
		if fx.conditions.is_empty() and fx.source_kind == &"spell" and (cr.concentration == null or fx.source_id != cr.concentration.source_id):
			parts.append(fx.name)
	if c.hidden:
		parts.append("Hidden")
	if c.altitude > 0:
		parts.append("%d ft up" % c.altitude)
	if cr is Character and (cr as Character).heroic_inspiration:
		parts.append("Heroic Inspiration")
	return ", ".join(parts)


func _refresh_hotbar() -> void:
	var c := shown
	if c == null:
		return
	var cur := e.current()
	var mine := cur == c and e.state == Encounter.State.ACTIVE
	_hot_name.text = c.name()
	_portrait.texture = _portrait_for(c)
	_hot_stats.text = "HP %d/%d · AC %d" % [c.creature.hp, c.creature.max_hp(), c.creature.ac_value()]
	# Extra Attack's attacks as pips beside the Action: all of them until the Attack action starts, then what's left.
	_economy.preview("")   # the slots are rebuilt: whatever was pointed at is gone
	var per := e.attacks_per_action(c)
	var attacks_left := c.attacks_left if mine and c.took_attack_action else (per if c.action_available else 0)
	_economy.set_state(c.action_available, c.bonus_available, c.reaction_available, per, attacks_left)
	var spd := maxi(1, c.speed())
	_move_bar.max_value = maxf(spd, c.movement_left)
	_move_bar.value = c.movement_left if mine else spd
	_move_label.text = "%d / %d ft" % [c.movement_left if mine else spd, spd]
	if e.state == Encounter.State.OVER:
		_turn_note.text = "Victory!" if e.outcome == "victory" else "The party has fallen"
	elif cur != null and not cur.is_player_controlled():
		_turn_note.text = "%s's turn" % cur.name()
	elif not mine:
		_turn_note.text = "Inspecting %s (not their turn)" % c.name()
	else:
		_turn_note.text = ""   # the attacks left show as pips beside the Action
	_refresh_slot_pips(c)
	_refresh_weapons(c, mine)
	_end_turn.disabled = not mine or e.pending != null
	_undo_move.disabled = not mine or not e.can_undo_move(c)
	# A dying hero has nothing else to do: the Death Saving Throw takes the action slots' place inside the bar (owner
	# report 2026-10-07: added under them, it pushed the bar past the bottom of the screen).
	var dying := mine and e.needs_death_save(c)
	_death_button.visible = dying
	_tabs.visible = not dying
	_slot_scroll.visible = not dying
	# Tabs.
	for ch in _tabs.get_children():
		ch.queue_free()
	var tabs := catalog.tabs_for(c)
	if not tab in tabs:
		tab = tabs[0]
	for t in tabs:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.button_pressed = t == tab
		UiKit.button_look(b)
		UiParts.compact(b)
		b.add_theme_font_size_override("font_size", 15)
		var on := UiKit.button_style("hover")
		on.border_color = Look.color("gilt_light")
		on.set_border_width_all(2)
		on.content_margin_top = 3
		on.content_margin_bottom = 3
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_pressed_color", Look.color("gilt_light"))
		b.pressed.connect(func() -> void:
			tab = t
			focus_slot = -1
			_refresh_hotbar())
		_tabs.add_child(b)
	# Slots.
	for ch in _slots.get_children():
		ch.queue_free()
	_slot_buttons.clear()
	_slot_actions.clear()
	# The player's arrangement (U2): their order, their favourites, the actions they hid (ActionCatalog.arranged), with
	# one slot per idea: a rule's modes as one toggle, an action's variants as one container (ActionCatalog.slots).
	var acts: Array = catalog.slots(c, tab)
	var groups: Array[Dictionary] = [{"heading": "", "items": acts}]
	if tab == ActionCatalog.SPELLS:
		# By spell level, alphabetical within, like every other spell list (SpellGroups), unless the player arranged the
		# tab: then each level keeps their order.
		groups = SpellGroups.groups(acts, func(a: Dictionary) -> String: return str(a.get("spell_id", "")),
			func(a: Dictionary) -> int: return int(a.get("slot", 0)))
		if ((ActionCatalog.layout(c).get("order", {}) as Dictionary)).has(tab):
			for g in groups:
				(g["items"] as Array).sort_custom(func(x: Variant, y: Variant) -> bool: return acts.find(x) < acts.find(y))
	var i := 0
	var grid: GridContainer = null
	for g in groups:
		grid = GridContainer.new()
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		if str(g["heading"]) == "":
			grid.columns = 7
			_slots.add_child(grid)
		else:
			grid.columns = 6
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var cap := _label(str(g["heading"]), 13, "gilt")
			cap.custom_minimum_size = Vector2(70, SLOT_SIZE.y)
			cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # beside the level's first row
			cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(cap)
			row.add_child(grid)
			_slots.add_child(row)
		for av: Variant in g["items"]:
			i = _add_slot(grid, av as Dictionary, i, c, mine)


## One hotbar slot for action `a` in `grid`, numbered `i`; returns the next number.
func _add_slot(grid: GridContainer, a: Dictionary, i: int, c: Combatant, mine: bool) -> int:
	# A standing rule (a toggle) changes on any turn; everything else waits for this character's turn.
	var anytime := bool(a.get("toggle", false)) or bool(a.get("anytime", false))
	var usable := bool(a["legal"]) and (mine or anytime)
	var b := Button.new()
	b.custom_minimum_size = SLOT_SIZE
	# A dark face like every other button, its cost told by the colour of its top edge (and the word in the tooltip).
	var colour := str(COST_COLOURS.get(str(a["cost"]), "slate"))
	var focused := i == focus_slot
	# An armed rider or smite glows: a bright edge on a warmer face until the hit spends it.
	if bool(a.get("armed", false)):
		focused = true
	b.add_theme_stylebox_override("normal", _slot_style("ui_wine" if bool(a.get("armed", false)) else "ui_oxblood", "gilt_light" if focused else "gilt_dark", focused))
	b.add_theme_stylebox_override("hover", _slot_style("ui_wine", "gilt_light", true))
	b.add_theme_stylebox_override("pressed", _slot_style("blood", "gilt_light", true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _slot_style("ui_black", "gilt_light" if focused else "ui_oxblood", focused))
	var stripe := ColorRect.new()
	stripe.color = Look.color(colour) if usable else Color(Look.color(colour), 0.35)
	stripe.anchor_right = 1.0
	stripe.offset_left = 17
	stripe.offset_right = -17
	stripe.offset_top = 2
	stripe.offset_bottom = 5
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(stripe)
	# The cost as the economy's own shape in the top right corner (Baldur's Gate 3's slots): ● Action, ▲ Bonus Action,
	# ◆ Reaction, a dash for movement, a ring for free.
	var cost := str(a["cost"])
	var mark := UiParts.drawn(SLOT_SIZE, func(cv: Control) -> void:
		_cost_mark(cv, Vector2(cv.size.x - 16.0, 11.0), cost, Look.color(colour) if usable else Color(Look.color(colour), 0.4)))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mark)
	_slot_face(b, a, i, usable)
	# Pointing at a slot lights what it would spend on the economy shapes (Baldur's Gate 3 does the same).
	if usable:
		b.mouse_entered.connect(func() -> void: _economy.preview(cost, c.attacks_left > 0))
		b.mouse_exited.connect(func() -> void: _economy.preview(""))
	b.disabled = not usable
	var reason := str(a["reason"]) if not bool(a["legal"]) else ""
	if not mine and not anytime and reason == "":
		reason = "Not %s's turn" % c.name()
	var more := "Right-click for more"
	if bool(a.get("toggle", false)):
		more = "Click to change it, right-click to pick"
	elif bool(a.get("group", false)):
		more = "Click to choose"
	b.tooltip_text = "%s (%s)%s%s\n%s%s" % [a["label"], _cost_word(str(a["cost"])), ("\n" + str(a["help"])) if str(a["help"]) != "" else "", ("\nCan't: " + reason) if reason != "" else "", more, (" (choose the %s)" % str(a.get("choice_label", "")).to_lower()) if a.has("choices") else ""]
	var act := a
	b.pressed.connect(func() -> void: use_action(act, b))
	# Drag a slot onto another on the same tab to put it there (U2); a group moves by its first action.
	var here_tab := tab
	b.set_drag_forwarding(func(_at: Vector2) -> Variant:
			if not c.creature is Character:
				return null
			var ghost := _label(str(act["label"]), 13, "gilt_light")
			b.set_drag_preview(ghost)
			return {"hotbar_action": _arrange_id(act), "tab": here_tab},
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and (data as Dictionary).has("hotbar_action") and str((data as Dictionary)["tab"]) == here_tab,
		func(_at: Vector2, data: Variant) -> void:
			var to := catalog.arranged(c, here_tab).map(func(x: Dictionary) -> String: return str(x["id"])).find(_arrange_id(act))
			catalog.move_action(c, here_tab, str((data as Dictionary)["hotbar_action"]), to)
			_refresh_hotbar())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			var at := b.get_screen_position() + (ev as InputEventMouseButton).position
			if bool(act.get("group", false)):
				open_group(act, at)
			else:
				open_slot_menu(act, at))
	grid.add_child(b)
	_slot_buttons.append(b)
	_slot_actions.append(a)
	return i + 1


## A hotbar slot's face: the icon at the left with its hotkey on its corner, then the name and the line under it,
## each shrunk to fit the space left and only then cut with an ellipsis (names like "Spear (thrown)" used to be cut
## off mid-word at the slot's edge).
func _slot_face(b: Button, a: Dictionary, i: int, usable: bool) -> void:
	var tex := UiParts.action_icon(a)
	var left := 14.0
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.position = Vector2(12, (SLOT_SIZE.y - 30.0) / 2.0 + 1.0)
		ic.size = Vector2(30, 30)
		ic.modulate = Color.WHITE if usable else Color(Color.WHITE, 0.4)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		left = 47.0
	var width := SLOT_SIZE.x - left - 12.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.position = Vector2(left, 6)
	col.size = Vector2(width, SLOT_SIZE.y - 8.0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var name_ := _fitted(str(a["label"]), width - 7.0, 13, 10, "ivory" if usable else "bone")   # clear of the cost mark
	col.add_child(name_)
	if bool(a.get("toggle", false)):
		# A rule: the mode in force in its own colour, and a pip per mode along the bottom with that one lit.
		var items := a["items"] as Array
		var current := int(a["current"])
		col.add_child(_fitted(str(a["sub"]), width, 12, 9, _mode_colour(str((items[current] as Dictionary)["mode"])) if usable else "bone"))
		var n := items.size()
		var pips := UiParts.drawn(SLOT_SIZE, func(cv: Control) -> void:
			var w := 10.0
			var gap := 4.0
			var x0 := cv.size.x - 16.0 - n * w - (n - 1) * gap
			for k in n:
				var r := Rect2(x0 + k * (w + gap), cv.size.y - 9.0, w, 3.0)
				var colour := Look.color(_mode_colour(str((items[k] as Dictionary)["mode"]))) if k == current else Color(Look.color("gilt_dark"), 0.6)
				cv.draw_rect(r, colour if usable else Color(colour, 0.4)))
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pips)
	elif str(a["sub"]) != "":
		col.add_child(_fitted(str(a["sub"]), width, 12, 9, ("gilt_light" if bool(a.get("armed", false)) else "parchment") if usable else "bone"))
	if bool(a.get("group", false)) and not bool(a.get("toggle", false)):
		# A container: a small gilt corner says a click opens its choices (Baldur's Gate 3's fly-out mark).
		var corner := UiParts.drawn(SLOT_SIZE, func(cv: Control) -> void:
			var tip := Vector2(cv.size.x - 13.0, cv.size.y - 7.0)
			cv.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-8, 0), tip + Vector2(0, -8)]),
				Look.color("gilt_light") if usable else Color(Look.color("gilt_dark"), 0.6)))
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(corner)
	if usable:
		b.mouse_entered.connect(func() -> void: name_.add_theme_color_override("font_color", Look.color("gilt_light")))
		b.mouse_exited.connect(func() -> void: name_.add_theme_color_override("font_color", Look.color("ivory")))
	if i < 10:
		var key := _label(InputActions.key_text(StringName("combat_slot_%d" % (i + 1))), 11, "gilt_light" if usable else "gilt_dark")
		key.position = Vector2(36, 28) if tex != null else Vector2(5, 15)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)


## One line of a slot's text at the largest size from `big` down to `small` that fits `width`, cut with an ellipsis if
## even `small` doesn't.
func _fitted(text: String, width: float, big: int, small: int, colour: String) -> Label:
	var font := ThemeDB.fallback_font
	var size := big
	while size > small and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	var l := _label(text, size, colour)
	l.add_theme_constant_override("outline_size", 3)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The resource row: spell slots left by level ("1st ●●●○"), then the creature's own resources (Second Wind, Channel
## Divinity, Focus Points, Rage...) as pips, or "left / most" past ten. What doesn't fit the bar's width folds into a
## last "+N" chip that names the rest.
func _refresh_slot_pips(c: Combatant) -> void:
	for ch in _slot_row.get_children():
		_slot_row.remove_child(ch)
		ch.queue_free()
	var chips: Array[Control] = []
	for p in catalog.slot_pips(c):
		chips.append(_pip_chip(ActionCatalog._ordinal(int(p["level"])), int(p["total"]), int(p["left"]), "moonlight",
			"Level %d spell slots: %d of %d left" % [int(p["level"]), int(p["left"]), int(p["total"])]))
	var res := c.creature.resources
	for rid: Variant in res:
		var r := res[rid] as Dictionary
		var most := int(r.get("max", 0))
		if most <= 0:
			continue
		var left := c.creature.resource_left(str(rid))
		chips.append(_pip_chip(str(r.get("name", rid)), most, left, "gilt_light",
			"%s: %d of %d left (back after a %s rest)" % [r.get("name", rid), left, most, "Short or Long" if str(r.get("recharge", "")) == "short" else "Long"]))
	_slot_box.visible = not chips.is_empty()
	var room := 1120.0
	var used := 0.0
	var rest: Array[String] = []
	for chip in chips:
		var w := chip.get_combined_minimum_size().x + 16.0
		if used + w > room - 60.0 and chip != chips.back() or used + w > room:
			rest.append(chip.tooltip_text)
			chip.queue_free()
			continue
		used += w
		_slot_row.add_child(chip)
	if not rest.is_empty():
		var more := UiParts.caption("+%d" % rest.size(), 11, "gilt_light")
		more.tooltip_text = "\n".join(rest)
		more.mouse_filter = Control.MOUSE_FILTER_PASS
		_slot_row.add_child(more)


## The weapon sets on the portrait: the main hand in hand (or the off hand, or a fist), and the other set's below it.
func _refresh_weapons(c: Combatant, mine: bool) -> void:
	for ch in _weapons.get_children():
		_weapons.remove_child(ch)
		ch.queue_free()
	if not c.creature is Character:
		return
	var ch := c.creature as Character
	var held := ch.held_id("main_hand") if ch.held_id("main_hand") != "" else ch.held_id("off_hand")
	var other := str(ch.weapon_set_2.get("main_hand", ch.weapon_set_2.get("off_hand", "")))
	if not ch.has_weapon_set_2():
		other = ""
	if held == "" and other == "":
		return
	var names := func(hands: Array) -> String:
		var out: Array[String] = []
		for id: Variant in hands:
			if str(id) != "" and not ch.entry_of(str(id)).is_empty():
				out.append(str(Compendium.shared().item_data(str(id)).get("name", id)))
		return " and ".join(out) if not out.is_empty() else "nothing"
	var tip := "In hand: %s\nOther set: %s\nClick to swap (free; attacking with the other set swaps too)" % [
		names.call([ch.held_id("main_hand"), ch.held_id("off_hand")]), names.call([ch.weapon_set_2.get("main_hand", ""), ch.weapon_set_2.get("off_hand", "")])]
	for k in 2:
		var id := held if k == 0 else other
		if k == 1 and id == "":
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 34) if k == 0 else Vector2(28, 28)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _style("ui_black", "gilt_light" if k == 0 else "gilt_dark", 1))
		b.add_theme_stylebox_override("hover", _style("ui_wine", "gilt_light", 2))
		b.add_theme_stylebox_override("pressed", _style("blood", "gilt_light", 2))
		b.add_theme_stylebox_override("disabled", _style("ui_black", "gilt_light" if k == 0 else "gilt_dark", 1))
		if id != "":
			UiParts.texture_on_button(b, UiParts.icon_texture("item", id), 24 if k == 0 else 18)
		if k == 1:
			b.modulate = Color(1, 1, 1, 0.7)
		b.tooltip_text = tip
		b.disabled = not mine or other == ""
		b.pressed.connect(func() -> void:
			var swap := catalog.find(c, "swap_weapons")
			if not swap.is_empty():
				action_chosen.emit(swap))
		_weapons.add_child(b)


## One resource on the row: its name in small capitals, then its pips.
func _pip_chip(name_: String, total: int, left: int, colour: String, tip: String) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.add_child(UiParts.caption(name_, 11))
	chip.add_child(UiParts.pips(total, left, colour))
	chip.tooltip_text = tip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	return chip


## A slot used (a click, its hotkey, the pad's RB): a toggle steps to its next mode, a container opens its choices at the
## slot, anything else goes to the fight.
func use_action(a: Dictionary, from: Control = null) -> void:
	if bool(a.get("toggle", false)):
		var items := a["items"] as Array
		action_chosen.emit(items[(int(a["current"]) + 1) % items.size()] as Dictionary)
	elif bool(a.get("group", false)):
		var at := from.get_screen_position() + Vector2(0, -8) if from != null else get_viewport().get_visible_rect().size / 2.0
		open_group(a, at, false)
	else:
		action_chosen.emit(a)


## The visible slot at `index` used, as its hotkey does (the view's number keys and RB).
func use_slot(index: int) -> void:
	var a := slot_action(index)
	if not a.is_empty():
		use_action(a, _slot_buttons[index] if index < _slot_buttons.size() else null)


## A container's or a rule's choices at its slot: each action (or mode), greyed with why when it can't be used now, and
## with `arrange` (a right-click) the Hotbar choices for the whole slot.
func open_group(a: Dictionary, at: Vector2, arrange: bool = true) -> void:
	_menu_action = a
	var mine := shown != null and e.current() == shown and e.state == Encounter.State.ACTIVE
	var toggle := bool(a.get("toggle", false))
	var key := str(a["id"]).substr(6)
	var members := a["items"] as Array
	var items: Array[Dictionary] = []
	for k in members.size():
		var m := members[k] as Dictionary
		var now := mine or bool(m.get("anytime", false))
		var ok := bool(m["legal"]) and now
		var why := "" if ok else (str(m.get("reason", "")) if now else "Not this character's turn")
		var label := str(m["mode_label"]) if toggle else catalog.variant_name(m, key)
		if toggle and k == int(a["current"]):
			label = "✓ " + label
		if bool(m.get("armed", false)):
			label += " (armed)"
		items.append({"id": "pick:%d" % k, "label": label, "enabled": ok, "why": why})
	if arrange and shown != null and shown.creature is Character:
		var first := str((members[0] as Dictionary)["id"])
		items.append({"separator": "Hotbar"})
		items.append({"id": "bar:fav" if not catalog.is_favourite(shown, first) else "bar:unfav",
			"label": "Add to Favourites" if not catalog.is_favourite(shown, first) else "Remove from Favourites"})
		items.append({"id": "bar:hide" if not catalog.is_hidden(shown, first) else "bar:show",
			"label": "Hide it (on the Hidden tab)" if not catalog.is_hidden(shown, first) else "Show it on its tab again"})
		items.append({"id": "bar:earlier", "label": "Move earlier"})
		items.append({"id": "bar:later", "label": "Move later"})
	_menu.show_actions(str(a["label"]), items, at)


## The action id a slot is arranged by (U2): its own, or a group's first action's.
static func _arrange_id(a: Dictionary) -> String:
	if bool(a.get("group", false)):
		return str(((a["items"] as Array)[0] as Dictionary)["id"])
	return str(a["id"])


## A slot's cost mark at `at`: the economy's shape for what it spends.
static func _cost_mark(cv: Control, at: Vector2, cost: String, col: Color) -> void:
	var edge := Color(Look.color("void"), 0.8)
	match cost:
		"action", "attack":
			cv.draw_circle(at, 5.0, col)
			cv.draw_arc(at, 5.0, 0.0, TAU, 16, edge, 1.0)
		"bonus":
			var tri := PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 5), at + Vector2(-6, 5)])
			cv.draw_colored_polygon(tri, col)
			cv.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), edge, 1.0)
		"reaction":
			var dia := PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)])
			cv.draw_colored_polygon(dia, col)
			cv.draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), edge, 1.0)
		"movement":
			cv.draw_rect(Rect2(at + Vector2(-6, -2), Vector2(12, 4)), col)
		_:
			cv.draw_arc(at, 4.5, 0.0, TAU, 16, col, 1.5)


## A rule's mode in its colour: Ask gilt, Automatic green, Off grey.
static func _mode_colour(mode: String) -> String:
	if mode == "ask":
		return "gilt_light"
	if mode.begins_with("auto"):
		return "bile"
	return "bone"


## The right-click menu on a hotbar slot: Info, Use, and for spells each slot level it can be cast with.
func open_slot_menu(action: Dictionary, at: Vector2) -> void:
	_menu_action = action
	var mine := shown != null and e.current() == shown and e.state == Encounter.State.ACTIVE
	var usable := bool(action["legal"]) and mine
	var why := "" if usable else (str(action.get("reason", "")) if mine else "Not this character's turn")
	var items: Array[Dictionary] = [{"id": "info", "label": "Info"}, {"id": "use", "label": "Use", "enabled": usable, "why": why}]
	var choices := action.get("choices", []) as Array
	if not choices.is_empty():
		items.append({"separator": str(action.get("choice_label", "Choose"))})
		for i in choices.size():
			var ch0 := choices[i] as Dictionary
			items.append({"id": "choice:%d" % i, "label": "%s: %s" % [action["label"], ch0["label"]], "enabled": usable, "why": why})
	var mms := action.get("metamagic", []) as Array
	if not mms.is_empty():
		items.append({"separator": "Metamagic"})
		for mm: Variant in mms:
			items.append({"id": "meta:%s" % (mm as Dictionary)["id"], "label": str((mm as Dictionary)["label"]), "enabled": usable, "why": why})
	if str(action["kind"]) == "spell" and str(action["cost"]) == "action" and shown != null and str((action.get("opts", {}) as Dictionary).get("resource_cast", "")) == "":
		items.append({"separator": "Ready"})
		for trig: String in ["approach", "attack", "spell"]:
			var when := {"approach": "an enemy comes within range", "attack": "an enemy within range attacks", "spell": "an enemy within range casts a spell"}[trig] as String
			items.append({"id": "ready:%s" % trig, "label": "Ready %s: release it when %s" % [action["label"], when], "enabled": usable, "why": why})
	if shown != null and shown.creature is Character and not bool(action.get("square", false)):
		# Arranging the hotbar (U2): any time, nothing spent.
		var aid := str(action.get("id", ""))
		items.append({"separator": "Hotbar"})
		items.append({"id": "bar:fav" if not catalog.is_favourite(shown, aid) else "bar:unfav",
			"label": "Add to Favourites" if not catalog.is_favourite(shown, aid) else "Remove from Favourites"})
		items.append({"id": "bar:hide" if not catalog.is_hidden(shown, aid) else "bar:show",
			"label": "Hide it (on the Hidden tab)" if not catalog.is_hidden(shown, aid) else "Show it on its tab again"})
		items.append({"id": "bar:earlier", "label": "Move earlier"})
		items.append({"id": "bar:later", "label": "Move later"})
	if str(action["kind"]) == "item_spell" and shown != null:
		var ilevels := catalog.level_choices(shown, action)
		if not ilevels.is_empty():
			items.append({"separator": "Casting level (more charges)"})
			for l in ilevels:
				items.append({"id": "cast:%d" % l, "label": "Use at level %d" % l, "enabled": usable, "why": why})
	if str(action["kind"]) == "spell" and shown != null and str((action.get("opts", {}) as Dictionary).get("resource_cast", "")) == "":
		var levels := catalog.level_choices(shown, action)
		if not levels.is_empty():
			items.append({"separator": "Casting level"})
			var ch := shown.creature as Character
			for l in levels:
				items.append({"id": "cast:%d" % l, "label": "Cast at level %d (%d slot%s left)" % [l, ch.slots_left(l), "" if ch.slots_left(l) == 1 else "s"],
					"enabled": usable, "why": why})
	_menu.show_actions(str(action.get("label", "")), items, at)


## The right-click menu on a square of the board (combat_view builds the items from ActionCatalog.square_actions).
func open_square_menu(title: String, items: Array[Dictionary], at: Vector2) -> void:
	_menu_action = {"square": true}
	_menu.show_actions(title, items, at)


func _on_menu(id: String) -> void:
	var action := _menu_action
	if bool(action.get("square", false)):
		square_picked.emit(id)
		return
	if action.is_empty() or shown == null:
		return
	if id.begins_with("pick:") and action.has("items"):
		action_chosen.emit((action["items"] as Array)[int(id.substr(5))] as Dictionary)
		return
	if id == "info":
		var d := catalog.details(shown, action)
		show_details(str(d["title"]), d["lines"] as Array)
	elif id == "use":
		action_chosen.emit(action)
	elif id.begins_with("meta:"):
		var shaped := action.duplicate(true)
		var o2 := (shaped.get("opts", {}) as Dictionary).duplicate()
		o2["metamagic"] = [id.substr(5)]
		shaped["opts"] = o2
		shaped["sub"] = str(action["sub"]) + " · " + id.substr(5).capitalize()
		if id.substr(5) == "quickened":
			shaped["cost"] = "bonus"
		action_chosen.emit(shaped)
	elif id.begins_with("ready"):
		var ready := action.duplicate(true)
		ready["kind"] = "ready_spell"
		ready["targeting"] = "none"
		var ro := (ready.get("opts", {}) as Dictionary).duplicate()
		ro["trigger"] = id.get_slice(":", 1) if id.contains(":") else "approach"
		ready["opts"] = ro
		action_chosen.emit(ready)
	elif id.begins_with("choice:"):
		var picked := action.duplicate(true)
		var ch0 := (action["choices"] as Array)[int(id.get_slice(":", 1))] as Dictionary
		var opts := (picked.get("opts", {}) as Dictionary).duplicate()
		opts["choice"] = str(ch0["value"])
		picked["opts"] = opts
		picked["sub"] = str(action["sub"]).get_slice(" · ", 0) + " · " + str(ch0["label"])
		action_chosen.emit(picked)
	elif id.begins_with("cast:"):
		cast_at_level.emit(action, int(id.get_slice(":", 1)))
	elif id.begins_with("bar:"):
		_arrange(action, id.substr(4))


## A hotbar slot's "Hotbar" menu choices (U2): star it, hide it, or move it one place.
func _arrange(action: Dictionary, what: String) -> void:
	var aid := _arrange_id(action)
	# A group is starred or hidden as a whole.
	var ids: Array[String] = [aid]
	if bool(action.get("group", false)):
		ids.assign((action["items"] as Array).map(func(m: Dictionary) -> String: return str(m["id"])))
	match what:
		"fav", "unfav":
			for one in ids:
				catalog.set_favourite(shown, one, what == "fav")
		"hide", "show":
			for one in ids:
				catalog.set_hidden(shown, one, what == "hide")
		"earlier", "later":
			var at := catalog.arranged(shown, tab).map(func(x: Dictionary) -> String: return str(x["id"])).find(aid)
			if at >= 0:
				catalog.move_action(shown, tab, aid, at + (-1 if what == "earlier" else 1))
	_refresh_hotbar()


func menu_open() -> bool:
	return _menu.visible


static func _cost_word(cost: String) -> String:
	match cost:
		"action":
			return "Action"
		"attack":
			return "one attack of your Attack action"
		"bonus":
			return "Bonus Action"
		"reaction":
			return "Reaction"
		"movement":
			return "movement"
	return "free"


## The visible slot at `index` (0-based, as numbered on the hotbar), or {}.
func slot_action(index: int) -> Dictionary:
	return _slot_actions[index] if index >= 0 and index < _slot_actions.size() else {}


func slot_count() -> int:
	return _slot_actions.size()


func cycle_tab(step: int) -> void:
	if shown == null:
		return
	var tabs := catalog.tabs_for(shown)
	tab = tabs[posmod(tabs.find(tab) + step, tabs.size())]
	focus_slot = -1
	_refresh_hotbar()


func set_tab(name_: String) -> void:
	tab = name_
	focus_slot = 0
	_refresh_hotbar()


func move_focus(step: int) -> void:
	if _slot_actions.is_empty():
		return
	focus_slot = posmod(focus_slot + step, _slot_actions.size())
	_refresh_hotbar()


func refresh_log() -> void:
	var entries := e.log.entries
	for i in range(_log_count, entries.size()):
		var en := entries[i]
		var text := str(en["text"])
		var kind := str(en["kind"])
		var colour := "vellum"
		match kind:
			"hit":
				colour = "rose"
			"miss":
				colour = "parchment"
			"heal":
				colour = "bile"
			"death":
				colour = "vampire_red"
			"turn":
				colour = "gilt_light"
			"spell":
				colour = "moonlight"
			"reaction":
				colour = "mist_blue"
			"warn":
				colour = "gilt"
			"condition":
				colour = "moonlight"
		var line := "[color=#%s]%s[/color]" % [Look.color(colour).to_html(false), _escape(text)]
		if kind == "narr":
			line = "[i]%s[/i]" % line
		if kind == "turn":
			line = "[b]%s[/b]" % line
		if not (en["details"] as Array).is_empty():
			line = "[url=%d]%s[/url]" % [i, line]
		_log.append_text(line + "\n")
	_log_count = entries.size()
	_update_log_title()


static func _escape(t: String) -> String:
	return t.replace("[", "[lb]")


func _on_log_meta(meta: Variant) -> void:
	var i := int(str(meta))
	if i < 0 or i >= e.log.entries.size():
		return
	var en := e.log.entries[i]
	show_details(str(en["text"]), en["details"] as Array)


func show_details(title: String, lines: Array) -> void:
	for ch in _details_box.get_children():
		ch.queue_free()
	_details_box.add_child(_label(title, 18, "gilt_light"))
	for l: Variant in lines:
		var lab := _label(str(l), 14, "vellum")
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(620, 0)
		_details_box.add_child(lab)
	_details_box.add_child(_label("(click anywhere or press Esc to close)", 12, "parchment"))
	_details.reset_size()
	_details.visible = true


func hide_details() -> bool:
	if _details.visible:
		_details.visible = false
		return true
	return false


# --- Tooltip, prompt, banner ----------------------------------------------------------------------

## The box beside the pointer. `edge` outlines it for an attack with "advantage" (green) or "disadvantage" (red), as
## the roll would be made (both at once cancel and leave the gilt edge).
func show_tooltip(title: String, lines: Array, warnings: Array, at: Vector2, edge: String = "") -> void:
	_odds.visible = false   # show_odds after this puts them back for an attack
	var box := _tooltip.get_theme_stylebox("panel") as StyleBoxFlat
	box.border_color = Look.color(EDGE_COLOURS.get(edge, "gilt") as String)
	box.set_border_width_all(3 if EDGE_COLOURS.has(edge) else 2)
	for ch in _tooltip_box.get_children():
		ch.free()
	_tooltip_box.add_child(_label(title, 18, "gilt_light"))
	for l: Variant in lines:
		_tooltip_box.add_child(_label(str(l), 15, "vellum"))
	for w: Variant in warnings:
		_tooltip_box.add_child(_label("⚠ " + str(w), 15, "gilt"))
	_tooltip.visible = true
	_tooltip.reset_size()
	var vp := _tooltip.get_viewport_rect().size
	var pos := at + Vector2(24, 18)
	pos.x = clampf(pos.x, 290.0, maxf(290.0, vp.x - _tooltip.size.x - 430.0))
	pos.y = clampf(pos.y, 150.0, maxf(150.0, vp.y - _tooltip.size.y - 260.0))
	_tooltip.position = pos


func hide_tooltip() -> void:
	_tooltip.visible = false
	_odds.visible = false


## The odds over a target's head while an attack on it is pointed at (Baldur's Gate 3's hit chance): the chance to hit
## in large figures, edged green or red for Advantage or Disadvantage, and the damage a hit does under it. `at` is the
## head's place on screen. Any other tooltip, or none, takes it away.
func show_odds(chance: float, damage: String, edge: String, at: Vector2) -> void:
	_odds_chance.text = "%d%%" % roundi(chance * 100.0)
	_odds_chance.add_theme_color_override("font_color", Look.color("bile" if chance >= 0.65 else ("gilt_light" if chance >= 0.35 else "rose")))
	_odds_damage.text = damage + " dmg" if damage != "" else ""
	var box := _odds.get_theme_stylebox("panel") as StyleBoxFlat
	box.border_color = Look.color(EDGE_COLOURS.get(edge, "gilt_dark") as String)
	box.set_border_width_all(3 if EDGE_COLOURS.has(edge) else 1)
	_odds.visible = true
	_odds.reset_size()
	var vp := _odds.get_viewport_rect().size
	var pos := at - Vector2(_odds.size.x / 2.0, _odds.size.y + 6.0)
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - _odds.size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, vp.y - _odds.size.y - 4.0))
	_odds.position = pos


func show_prompt(req: ReactionRequest) -> void:
	hide_tooltip()
	var reactor := e.get_c(req.reactor_id)
	if reactor != null and reactor.is_player_controlled():
		shown = reactor
		_refresh_hotbar()
		_refresh_party()
	_prompt_title.text = req.title
	_prompt_text.text = req.text
	_prompt_cost.text = "Costs: " + req.cost
	_prompt_use.text = "Use Reaction (A / Enter)" if req.spends_reaction else "Confirm (A / Enter)"
	for child: Node in _prompt_targets.get_children():
		_prompt_targets.remove_child(child)
		child.queue_free()
	_prompt_targets.get_parent().visible = not req.target_choices.is_empty()
	var group := ButtonGroup.new() if req.max_targets == 1 else null
	_prompt_use.disabled = req.selection_error() != ""
	for choice in req.target_choices:
		var target_id := str(choice["id"])
		var check := CheckButton.new()
		check.text = str(choice["label"])
		check.button_group = group
		check.button_pressed = target_id in req.selected_ids
		check.toggled.connect(func(on: bool) -> void:
			if on and not target_id in req.selected_ids:
				req.selected_ids.append(target_id)
			elif not on:
				req.selected_ids.erase(target_id)
			_prompt_use.disabled = req.selection_error() != "")
		_prompt_targets.add_child(check)
	_prompt_rule.select(0)
	# Its height follows what it holds this time, grown up from just above the hotbar (grow_vertical).
	_prompt.offset_top = PROMPT_BOTTOM
	_prompt.offset_bottom = PROMPT_BOTTOM
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


func prompt_open() -> bool:
	return _prompt.visible


func answer_prompt(use: bool) -> void:
	if not _prompt.visible or (use and _prompt_use.disabled):
		return
	_prompt.visible = false
	var rule := ["ask", "auto", "never"][_prompt_rule.selected] as String
	reaction_answered.emit(use, rule)


func confirm_end_turn(text: String) -> void:
	_confirm_text.text = text
	_confirm.visible = true


func confirm_open() -> bool:
	return _confirm.visible


func close_confirm() -> void:
	_confirm.visible = false


func banner(text: String, seconds: float = 1.6) -> void:
	_banner.text = text
	_banner_time = seconds
	_banner.modulate.a = 1.0


func set_pips(levels: Array[int], current: int) -> void:
	slot_levels = levels
	slot_level = current
	for ch in _pips.get_children():
		ch.queue_free()
	if levels.is_empty():
		return
	_pips.add_child(_label("Slot:", 14, "parchment"))
	for l in levels:
		var b := Button.new()
		b.text = str(l)
		b.toggle_mode = true
		b.button_pressed = l == current
		b.custom_minimum_size = Vector2(30, 30)
		b.pressed.connect(func() -> void:
			slot_level = l
			set_pips(slot_levels, l)
			slot_level_changed.emit(l))
		_pips.add_child(b)
	_pips.add_child(_label("[ ] to change", 12, "parchment"))


func _process(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)


# --- Helpers --------------------------------------------------------------------------------------

func _portrait_for(c: Combatant) -> Texture2D:
	var aid := CombatToken.portrait_id(c)
	if _portraits.has(aid):
		return _portraits[aid] as Texture2D
	var path := "res://art/portraits/%s.png" % aid
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_portraits[aid] = tex
	return tex


## Hit Points as the sheet's bar: crimson, brighter when Bloodied. Enemies show only whether they're Bloodied (the
## party can't see their exact Hit Points).
func _hp_bar(c: Combatant, width: int, height: float = 8.0) -> Control:
	var cr := c.creature
	if c.side != &"enemy":
		var bar := UiParts.hp_bar(cr, float(width), height, false)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return bar
	var frac := 0.0 if cr.dead else (0.5 if cr.is_bloodied() else 1.0)
	var enemy := UiParts.bar(frac, 1.0, 0.0, "", "vampire_red" if cr.is_bloodied() else "crimson", Callable(), float(width), height)
	enemy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return enemy


func _label(text: String, size: int, colour: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Look.color(colour))
	l.add_theme_color_override("font_outline_color", Look.color("void"))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _style(bg: String, border: String, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), 0.94)
	s.border_color = Look.color(border)
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.corner_detail = 1
	s.set_content_margin_all(6)
	return s


## End Turn is a crimson seal ringed in gilt.
## A hotbar slot: a dark face with a fine gilt edge, bright when focused.
func _slot_style(bg: String, edge: String, bright: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), 0.95)
	s.border_color = Look.color(edge)
	s.set_border_width_all(2 if bright else 1)
	# Long hexagons like every other button (the owner's Crimson concept).
	s.set_corner_radius_all(14)
	s.corner_detail = 1
	s.set_content_margin_all(5)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9
	return s


func _round_style(bg: String, ring: String = "gilt") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Look.color(bg)
	s.border_color = Look.color(ring)
	s.set_border_width_all(4)
	s.set_corner_radius_all(54)
	s.shadow_color = Color(Look.color("void"), 0.7)
	s.shadow_size = 6
	return s


func _panel(border: String = "gilt_dark", bg: String = "ui_black", ornate: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), 0.9)
	s.border_color = Look.color(border)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.corner_detail = 1
	s.set_content_margin_all(14 if ornate else 10)
	p.add_theme_stylebox_override("panel", s)
	if ornate:
		UiKit.trim(p, 40.0)
	return p
