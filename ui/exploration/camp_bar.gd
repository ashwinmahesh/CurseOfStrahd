class_name CampBar
extends CanvasLayer
## The camp's panel at the top of the exploring screen (F16, LocationCamp): where the party is, what to do there (walk
## up to someone to talk, then sleep; change prepared spells, any time before the night or in the morning; break camp),
## and the buttons for it.
## It shows while the exploring HUD does, and watches the camp rather than being told. The rest screen offers the same
## (Sleep, Break camp) for the keyboard and the controller.

var camp: LocationCamp = null
var _panel: PanelContainer
var _title: Label
var _hint: Label
var _sleep: Button
var _prepare: Button
var _strike: Button
var _shown := ""


func _init() -> void:
	name = "CampBar"
	layer = 10


func _ready() -> void:
	_panel = PanelContainer.new()
	var s := UiKit.style("ui_black", "gilt_dark", 2, 0.9)
	s.set_content_margin_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.set_corner_radius_all(10)
	s.corner_detail = 1
	_panel.add_theme_stylebox_override("panel", s)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 8
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.trim(_panel, 30.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_panel.add_child(col)
	_title = UiKit.label("Camp", 19, "gilt_light")
	_title.add_theme_font_override("font", UiKit.display_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_sleep = _button("Sleep (8 hours)", func() -> void: camp.sleep(), "rest")
	row.add_child(_sleep)
	_prepare = _button("Change prepared spells", func() -> void: camp.prepare(), "spells")
	row.add_child(_prepare)
	_strike = _button("Break camp", func() -> void: camp.strike(), "")
	_strike.tooltip_text = "Pack up and walk on."
	row.add_child(_strike)
	_hint = UiKit.label("", 13, "parchment")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	add_child(_panel)
	_panel.visible = false


func _button(text: String, pressed: Callable, icon: String) -> Button:
	var b := UiKit.button(text, pressed, 14, icon)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	return b


func _process(_delta: float) -> void:
	var view := camp.view if camp != null and is_instance_valid(camp) else null
	var hud := camp.root.get("hud") as CanvasLayer if view != null and camp.root != null and "hud" in camp.root else null
	var on := view != null and is_instance_valid(view) and not view.in_combat and (hud == null or hud.visible)
	_panel.visible = on
	if not on:
		_shown = ""
		return
	var why := camp.sleep_refusal()
	var prep := camp.can_prepare()
	var sig := "%s|%s|%s|%d" % [camp.slept, why, prep, camp.talks.size()]
	if sig == _shown:
		return
	_shown = sig
	_title.text = "Camp · rested" if camp.slept else "Camp"
	_sleep.visible = not camp.slept
	_sleep.disabled = why != ""
	_sleep.tooltip_text = why if why != "" else "The Long Rest: everyone sleeps by the fire, and all Hit Points, spell slots and features come back."
	_prepare.visible = prep
	_prepare.text = camp.prepare_label()
	_prepare.tooltip_text = "Change what the night lets you change, counted from the list it ended with." if camp.slept \
		else "Change which spells each caster has ready. No rest needed outside a fight."
	if prep and camp.slept:
		UiParts.light_up(_prepare)   # the morning's chance, counted from the night's list
	var asking := camp.talks.size()
	if camp.slept:
		_hint.text = "Walk up to anyone to talk. Break camp when you're ready to go on." if asking == 0 \
			else "Someone wants a word. Walk up to them to talk, or break camp to go on."
		var change := PrepareScreen.available_line(camp.view.st, "long_rest") if prep and camp.view != null else ""
		if change != "":
			_hint.text = change.replace("the lit button below", "the lit button") + " " + _hint.text
	else:
		_hint.text = "Walk up to anyone by the fire to talk, then sleep." if asking == 0 \
			else "Someone wants a word: the mark over them. Walk up to them to talk, then sleep."
	_panel.reset_size()
