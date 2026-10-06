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

const COST_COLOURS := {"action": "moss", "attack": "moss", "bonus": "ember", "reaction": "plum", "free": "slate",
	"movement": "moon_blue"}
const SLOT_SIZE := Vector2(132, 50)
const CONTROLS: Array[String] = [
	"Mouse: hover the floor to see your path and its cost; click to move. Hover an enemy for the odds; click to attack with the best weapon that reaches. Right-click cancels.",
	"Keyboard: 1-0 use hotbar slots · Z / X change tab · Enter confirms (casts early with fewer targets) · Esc cancels · Space ends the turn · [ and ] change the spell slot · T jumps to the next target · Tab inspects the next party member.",
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
var _death_button: Button
var radial: RadialMenu
var _portraits: Dictionary = {}
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
	_controls = _panel("parchment")
	_controls.anchor_left = 0.5
	_controls.anchor_right = 0.5
	_controls.offset_left = -420
	_controls.offset_right = 420
	_controls.offset_top = 150
	_controls.visible = false
	var cbox := VBoxContainer.new()
	_controls.add_child(cbox)
	cbox.add_child(_label("Controls (F1 or Start to close)", 20, "flame"))
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
	_round_label = _label("Round 1", 24, "flame")
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
	var panel := _panel()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -420
	panel.offset_right = -12
	panel.offset_top = 140
	panel.offset_bottom = 600
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label("COMBAT LOG · click a line for the math", 14, "parchment"))
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
	_hot_name = _label("", 18, "vellum")
	card.add_child(_hot_name)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(120, 120)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(_portrait)
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
	mv.add_child(_label("Movement", 14, "parchment"))
	_move_bar = ProgressBar.new()
	_move_bar.custom_minimum_size = Vector2(220, 14)
	_move_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Look.color("sickly")
	var back := StyleBoxFlat.new()
	back.bg_color = Look.color("grave")
	_move_bar.add_theme_stylebox_override("fill", fill)
	_move_bar.add_theme_stylebox_override("background", back)
	mv.add_child(_move_bar)
	_move_label = _label("", 15, "vellum")
	mv.add_child(_move_label)
	top.add_child(mv)
	_pips = HBoxContainer.new()
	top.add_child(_pips)
	_turn_note = _label("", 16, "flame")
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
	_end_turn.add_theme_stylebox_override("normal", _round_style("candle"))
	_end_turn.add_theme_stylebox_override("hover", _round_style("flame"))
	_end_turn.add_theme_stylebox_override("pressed", _round_style("ember"))
	_end_turn.add_theme_stylebox_override("disabled", _round_style("ash_violet"))
	_end_turn.add_theme_color_override("font_color", Look.color("void"))
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
	_tooltip = _panel("vellum", "ink")
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_box = VBoxContainer.new()
	_tooltip.add_child(_tooltip_box)
	add_child(_tooltip)


func _build_prompt() -> void:
	_prompt = _panel("flame")
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
	_prompt_title = _label("", 22, "flame")
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
	_confirm = _panel("flame")
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
	_banner = _label("", 40, "flame")
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
	for c in e.order:
		if c.creature.dead and c.side == &"enemy":
			continue
		var active := c == cur
		var card := PanelContainer.new()
		var frame := "flame" if c.side == &"party" else ("moonlight" if c.side == &"guest" else "crimson")
		card.add_theme_stylebox_override("panel", _style("grave" if not active else "ash_violet", "wick" if active else frame, 4 if active else 2))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var tex := TextureRect.new()
		tex.texture = _portrait_for(c)
		tex.custom_minimum_size = Vector2(70, 70) if active else Vector2(52, 52)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if c.is_down():
			tex.modulate = Color(0.5, 0.5, 0.5)
		v.add_child(tex)
		var short := c.name().get_slice(" ", 0) if c.side != &"enemy" else c.name().replace("Dire Wolf", "Dire")
		v.add_child(_label(short, 13 if not active else 15, "vellum"))
		v.add_child(_hp_bar(c, 60 if not active else 76))
		card.mouse_entered.connect(func() -> void: inspect_requested.emit("hover:" + c.id))
		_strip.add_child(card)


func _refresh_party() -> void:
	for ch in _party_box.get_children():
		ch.queue_free()
	for c in e.combatants:
		if c.side not in [&"party", &"guest"]:
			continue
		var on := c == shown
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style("ink", "wick" if on else "bone_dark", 3 if on else 2))
		card.custom_minimum_size = Vector2(270, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var tex := TextureRect.new()
		tex.texture = _portrait_for(c)
		tex.custom_minimum_size = Vector2(64, 64)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if c.is_down():
			tex.modulate = Color(0.45, 0.45, 0.45)
		row.add_child(tex)
		var v := VBoxContainer.new()
		v.add_child(_label(c.name() + (" (guest)" if c.side == &"guest" else ""), 17, "vellum"))
		v.add_child(_hp_bar(c, 170))
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
		b.add_theme_stylebox_override("normal", _style("ink", "bone_dark", 2))
		b.add_theme_stylebox_override("pressed", _style("plum", "flame", 2))
		b.add_theme_stylebox_override("hover", _style("grave", "flame", 2))
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
		var colour := str(COST_COLOURS.get(str(a["cost"]), "slate"))
		var border := "wick" if i == focus_slot else "void"
		b.add_theme_stylebox_override("normal", _style(colour if usable else "grave", border, 2 if i != focus_slot else 3))
		b.add_theme_stylebox_override("hover", _style(colour if usable else "grave", "flame", 2))
		b.add_theme_stylebox_override("pressed", _style("plum", "flame", 2))
		b.add_theme_stylebox_override("disabled", _style("grave", border, 2))
		b.add_theme_color_override("font_color", Look.color("ivory"))
		b.add_theme_color_override("font_disabled_color", Look.color("bone"))
		b.disabled = not usable
		var reason := str(a["reason"]) if not bool(a["legal"]) else ""
		if not mine and reason == "":
			reason = "Not %s's turn" % c.name()
		b.tooltip_text = "%s (%s)%s%s" % [a["label"], _cost_word(str(a["cost"])), ("\n" + str(a["help"])) if str(a["help"]) != "" else "", ("\nCan't: " + reason) if reason != "" else ""]
		var act := a
		b.pressed.connect(func() -> void: action_chosen.emit(act))
		_slots.add_child(b)
		_slot_buttons.append(b)
		_slot_actions.append(a)
		i += 1


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
				colour = "flame"
			"spell":
				colour = "lilac"
			"reaction":
				colour = "orchid"
			"warn":
				colour = "candle"
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
	_details_box.add_child(_label(title, 18, "flame"))
	for l: Variant in lines:
		var lab := _label(str(l), 14, "vellum")
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(620, 0)
		_details_box.add_child(lab)
	_details_box.add_child(_label("(click anywhere or press Esc to close)", 12, "parchment"))
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
	_tooltip_box.add_child(_label(title, 18, "flame"))
	for l: Variant in lines:
		_tooltip_box.add_child(_label(str(l), 15, "vellum"))
	for w: Variant in warnings:
		_tooltip_box.add_child(_label("⚠ " + str(w), 15, "candle"))
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


func _hp_bar(c: Combatant, width: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 8)
	bar.show_percentage = false
	var cr := c.creature
	var frac := clampf(float(cr.hp) / maxf(1.0, float(cr.max_hp())), 0.0, 1.0)
	var colour := "sickly"
	if c.side == &"enemy":
		frac = 0.0 if cr.dead else (0.5 if cr.is_bloodied() else 1.0)
		colour = "crimson" if cr.is_bloodied() else "sickly"
	elif frac <= 0.5:
		colour = "candle" if frac > 0.25 else "crimson"
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = frac
	var fill := StyleBoxFlat.new()
	fill.bg_color = Look.color(colour)
	var back := StyleBoxFlat.new()
	back.bg_color = Look.color("void")
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


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
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	return s


func _round_style(bg: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Look.color(bg)
	s.border_color = Look.color("void")
	s.set_border_width_all(3)
	s.set_corner_radius_all(54)
	return s


func _panel(border: String = "bone_dark", bg: String = "ink") -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), 0.9)
	s.border_color = Look.color(border)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	return p
