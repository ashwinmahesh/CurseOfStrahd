class_name CombatHud
extends CanvasLayer
## The combat screen (docs/ui/combat_view.md, wireframes cb_01-03, approved 2026-10-06): initiative strip on top,
## party frames on the left, the combat log on the right, the hotbar with the action economy and End Turn at the
## bottom, plus the target tooltip, reaction prompts, roll details, banners and the controller's radial menu.
## It reads the Encounter and the ActionCatalog and never computes rules itself. Drawn on a CanvasLayer so the
## palette pass never touches it (plan §5.6).

signal action_chosen(action: Dictionary)
signal end_turn_pressed
signal reaction_answered(use: bool, rule: String)
signal inspect_requested(combatant_id: String)
signal death_save_pressed
signal slot_level_changed(level: int)
signal radial_picked(choice: String)
## Right-click → "Cast at level N" on a spell slot.
signal cast_at_level(action: Dictionary, level: int)

const COST_COLOURS := {"action": "moss", "attack": "moss", "bonus": "gilt", "reaction": "mist_blue", "free": "slate",
	"movement": "moon_blue"}
const SLOT_SIZE := Vector2(132, 50)
const CONTROLS: Array[String] = [
	"Mouse: hover the floor to see your path and its cost; click to move. Hover an enemy for the odds; click to attack with the best weapon that reaches. Right-click on the field cancels; right-click a hotbar slot for Info, Use and the spell's casting level.",
	"Keyboard: L minimizes or restores the combat log · 1-0 use hotbar slots · Z / X change tab · Enter confirms (casts early with fewer targets) · Esc cancels · Space ends the turn · [ and ] change the spell slot · T jumps to the next target · Tab inspects the next party member · F5 quicksaves and F9 loads the quicksave (outside a fight; in one, the game saves at each round's start).",
	"Camera: WASD or arrows pan · Q / E rotate · mouse wheel zooms.",
	"Controller: left stick moves the cursor · A confirms · B cancels · X next target · Y ends the turn · hold LB for the radial menu (right stick picks, release to choose) · LT / RT pick a hotbar slot · RB uses it · d-pad left/right changes the spell slot · View inspects the next party member.",
	"Reactions always ask unless you set a rule in the prompt (Next time: Ask me / Always use it / Never).",
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
var _slots: GridContainer
var _slot_buttons: Array[Button] = []
var _slot_actions: Array[Dictionary] = []
var _end_turn: Button
var _turn_note: Label
var _tooltip: PanelContainer
var _tooltip_box: VBoxContainer
var _prompt: PanelContainer
var _prompt_title: Label
var _prompt_text: Label
var _prompt_cost: Label
var _prompt_rule: OptionButton
var _details: PanelContainer
var _details_box: VBoxContainer
var _banner: Label
var _banner_time := 0.0
var _confirm: PanelContainer
var _confirm_text: Label
var _pips: HBoxContainer
var _slot_box: VBoxContainer
var _slot_row: HBoxContainer
var _menu: ContextMenu
var _menu_action: Dictionary = {}
var _death_button: Button
var radial: RadialMenu
var _portraits: Dictionary = {}
## The log panel can be minimized to its title bar; the choice lasts for the session.
static var log_minimized := false
const LOG_BOTTOM := 600.0
var _log_panel: PanelContainer
var _log_title: Label
var _log_toggle: Button
var _controls: PanelContainer


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
	cbox.add_child(_label("Controls (F1 or Start to close)", 20, "gilt_light"))
	for line: String in CONTROLS:
		var l := _label(line, 15, "vellum")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(800, 0)
		cbox.add_child(l)
	add_child(_controls)
	var hint := _label("F1: controls", 14, "parchment")
	hint.position = Vector2(14, 520)
	add_child(hint)


func toggle_controls() -> void:
	_controls.visible = not _controls.visible


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
	_log_toggle = Button.new()
	_log_toggle.custom_minimum_size = Vector2(30, 26)
	_log_toggle.tooltip_text = "Minimize or restore the combat log (L)"
	_log_toggle.pressed.connect(toggle_log)
	head.add_child(_log_toggle)
	box.add_child(head)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(390, 420)
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


func _apply_log_state() -> void:
	_log.visible = not log_minimized
	_log_toggle.text = "+" if log_minimized else "–"
	_log_panel.offset_bottom = _log_panel.offset_top + 46 if log_minimized else LOG_BOTTOM
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
	_slot_box = VBoxContainer.new()
	_slot_box.add_child(UiParts.caption("Spell slots", 11))
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 10)
	_slot_box.add_child(_slot_row)
	top.add_child(_slot_box)
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
	_slots = GridContainer.new()
	_slots.columns = 7
	_slots.add_theme_constant_override("h_separation", 6)
	_slots.add_theme_constant_override("v_separation", 6)
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
	_death_button = Button.new()
	_death_button.text = "Roll Death Saving Throw"
	_death_button.visible = false
	_death_button.custom_minimum_size = Vector2(260, 48)
	_death_button.pressed.connect(func() -> void: death_save_pressed.emit())
	mid.add_child(_death_button)


func _build_tooltip() -> void:
	_tooltip = _panel("gilt", "ui_black", false)
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_box = VBoxContainer.new()
	_tooltip.add_child(_tooltip_box)
	add_child(_tooltip)


func _build_prompt() -> void:
	_prompt = _panel("gilt_light")
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -150
	_prompt.visible = false
	add_child(_prompt)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_prompt.add_child(box)
	_prompt_title = _label("", 22, "gilt_light")
	box.add_child(_prompt_title)
	_prompt_text = _label("", 16, "vellum")
	_prompt_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_text.custom_minimum_size = Vector2(560, 0)
	box.add_child(_prompt_text)
	_prompt_cost = _label("", 15, "parchment")
	box.add_child(_prompt_cost)
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
	use.text = "Use Reaction (A / Enter)"
	use.pressed.connect(func() -> void: answer_prompt(true))
	var skip := Button.new()
	skip.text = "Skip (B / Esc)"
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
	yes.text = "End turn (Space / A)"
	yes.pressed.connect(func() -> void:
		_confirm.visible = false
		end_turn_pressed.emit())
	var no := Button.new()
	no.text = "Keep going (Esc / B)"
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
	_refresh_strip()
	_refresh_party()
	_refresh_hotbar()
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
		v.add_child(UiParts.framed_portrait(CombatToken.art_id(c), 72.0 if active else 54.0, c.is_down(), c.creature.dead))
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
		if c.side not in [&"party", &"guest"]:
			continue
		var on := c == shown
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style("ui_black", "gilt_light" if on else "gilt_dark", 3 if on else 2))
		card.custom_minimum_size = Vector2(270, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(UiParts.framed_portrait(CombatToken.art_id(c), 64.0, c.is_down(), c.creature.dead))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		var nm := _label(c.name() + (" (guest)" if c.side == &"guest" else ""), 17, "gilt_light" if on else "vellum")
		nm.add_theme_font_override("font", UiKit.display_font())
		v.add_child(nm)
		v.add_child(_hp_bar(c, 170, 10.0))
		var cr := c.creature
		var status := "%d/%d" % [cr.hp, cr.max_hp()]
		if cr.temp_hp > 0:
			status += " +%d temp" % cr.temp_hp
		var chips := _chips(c)
		if chips != "":
			status += " · " + chips
		var sl := _label(status, 13, "parchment")
		sl.custom_minimum_size = Vector2(180, 0)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
		row.add_child(v)
		var btn := Button.new()
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		for st_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
		btn.pressed.connect(func() -> void: inspect_requested.emit(c.id))
		card.add_child(btn)
		_party_box.add_child(card)


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
	for fx in cr.effects:
		if fx.conditions.is_empty() and fx.source_kind == &"spell" and (cr.concentration == null or fx.source_id != cr.concentration.source_id):
			parts.append(fx.name)
	if c.hidden:
		parts.append("Hidden")
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
	_economy.set_state(c.action_available, c.bonus_available, c.reaction_available)
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
		var per := e.attacks_per_action(c)
		_turn_note.text = ("%d attacks per Attack action" % per) if per > 1 else ""
		if c.attacks_left > 0:
			_turn_note.text = "%d attack%s left in this Attack action" % [c.attacks_left, "" if c.attacks_left == 1 else "s"]
	_refresh_slot_pips(c)
	_end_turn.disabled = not mine or e.pending != null
	_death_button.visible = mine and e.needs_death_save(c)
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
	var i := 0
	for a in catalog.actions_for(c):
		if str(a["tab"]) != tab:
			continue
		var usable := bool(a["legal"]) and mine
		var b := Button.new()
		b.custom_minimum_size = SLOT_SIZE
		b.clip_text = true
		var key := "%d " % ((i + 1) % 10) if i < 10 else ""
		b.text = "%s%s\n%s" % [key, a["label"], a["sub"]]
		b.add_theme_font_size_override("font_size", 13)
		# A dark face like every other button, its cost told by the colour of its top edge (and the word in the tooltip).
		var colour := str(COST_COLOURS.get(str(a["cost"]), "slate"))
		var focused := i == focus_slot
		b.add_theme_stylebox_override("normal", _slot_style("ui_oxblood", "gilt_light" if focused else "gilt_dark", focused))
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
		b.add_theme_color_override("font_color", Look.color("ivory"))
		b.add_theme_color_override("font_hover_color", Look.color("gilt_light"))
		b.add_theme_color_override("font_disabled_color", Look.color("bone"))
		UiParts.texture_on_button(b, UiParts.action_icon(a), 32)
		b.disabled = not usable
		var reason := str(a["reason"]) if not bool(a["legal"]) else ""
		if not mine and reason == "":
			reason = "Not %s's turn" % c.name()
		b.tooltip_text = "%s (%s)%s%s\nRight-click for more%s" % [a["label"], _cost_word(str(a["cost"])), ("\n" + str(a["help"])) if str(a["help"]) != "" else "", ("\nCan't: " + reason) if reason != "" else "", (" (choose the %s)" % str(a.get("choice_label", "")).to_lower()) if a.has("choices") else ""]
		var act := a
		b.pressed.connect(func() -> void: action_chosen.emit(act))
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				open_slot_menu(act, b.get_screen_position() + (ev as InputEventMouseButton).position))
		_slots.add_child(b)
		_slot_buttons.append(b)
		_slot_actions.append(a)
		i += 1


## Spell slots left by level, as filled and empty pips ("1st ●●●○").
func _refresh_slot_pips(c: Combatant) -> void:
	for ch in _slot_row.get_children():
		ch.queue_free()
	var pips := catalog.slot_pips(c)
	_slot_box.visible = not pips.is_empty()
	for p in pips:
		var left := int(p["left"])
		var total := int(p["total"])
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(UiParts.caption(ActionCatalog._ordinal(int(p["level"])), 11))
		chip.add_child(UiParts.pips(total, left, "moonlight"))
		chip.tooltip_text = "Level %d spell slots: %d of %d left" % [int(p["level"]), left, total]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		_slot_row.add_child(chip)


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
	if str(action["kind"]) == "spell" and str(action["cost"]) == "action" and shown != null:
		items.append({"separator": "Ready"})
		items.append({"id": "ready", "label": "Ready %s: release it when an enemy comes in range" % action["label"], "enabled": usable, "why": why})
	if str(action["kind"]) == "item_spell" and shown != null:
		var ilevels := catalog.level_choices(shown, action)
		if not ilevels.is_empty():
			items.append({"separator": "Casting level (more charges)"})
			for l in ilevels:
				items.append({"id": "cast:%d" % l, "label": "Use at level %d" % l, "enabled": usable, "why": why})
	if str(action["kind"]) == "spell" and shown != null:
		var levels := catalog.slot_choices(shown, str(action["spell_id"]))
		if not levels.is_empty():
			items.append({"separator": "Casting level"})
			var ch := shown.creature as Character
			for l in levels:
				items.append({"id": "cast:%d" % l, "label": "Cast at level %d (%d slot%s left)" % [l, ch.slots_left(l), "" if ch.slots_left(l) == 1 else "s"],
					"enabled": usable, "why": why})
	_menu.show_actions(str(action.get("label", "")), items, at)


func _on_menu(id: String) -> void:
	var action := _menu_action
	if action.is_empty() or shown == null:
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
	elif id == "ready":
		var ready := action.duplicate(true)
		ready["kind"] = "ready_spell"
		ready["targeting"] = "none"
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

func show_tooltip(title: String, lines: Array, warnings: Array, at: Vector2) -> void:
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
	_prompt_rule.select(0)
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


func prompt_open() -> bool:
	return _prompt.visible


func answer_prompt(use: bool) -> void:
	if not _prompt.visible:
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
	var aid := CombatToken.art_id(c)
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
