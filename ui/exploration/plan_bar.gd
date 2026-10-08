class_name PlanBar
extends CanvasLayer
## Turn-based exploring's panel (F7, LocationPlan) at the top of the exploring screen: the round, each party member's
## movement left (the one moving is marked), whether the party is sneaking (and so would strike with Surprise), and
## buttons to end the round, attack the foes in sight and go back to real time. It shows only while the party explores
## turn-based, and watches the view rather than being told.

signal command(name: String)

var view: LocationView = null
## Whether the exploring HUD is up (conversations and screens hide it, and this with it).
var hud: CanvasLayer = null
var _panel: PanelContainer
var _title: Label
var _moves: HBoxContainer
var _hint: Label
var _strike: Button
var _shown := ""


func _init() -> void:
	name = "PlanBar"
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
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	_title = UiKit.label("", 19, "gilt_light")
	_title.add_theme_font_override("font", UiKit.display_font())
	top.add_child(_title)
	_moves = HBoxContainer.new()
	_moves.add_theme_constant_override("separation", 12)
	top.add_child(_moves)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(_button("End round  (%s)" % InputActions.key_text(&"plan_round"), "plan_round", "Everyone gets their movement again; six seconds pass."))
	_strike = _button("Attack", "strike", "")
	row.add_child(_strike)
	row.add_child(_button("Real time  (%s)" % InputActions.key_text(&"plan_mode"), "plan", "Back to walking freely (turn-based stays off until you switch it on again)."))
	_hint = UiKit.label("", 13, "parchment")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	add_child(_panel)
	_panel.visible = false


func _button(text: String, cmd: String, tip: String) -> Button:
	var b := UiKit.button(text, func() -> void: command.emit(cmd), 14)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 34)
	return b


func _process(_delta: float) -> void:
	var on := view != null and is_instance_valid(view) and view.planning and not view.in_combat and (hud == null or hud.visible)
	_panel.visible = on
	if not on:
		_shown = ""
		return
	var sig := _signature()
	if sig != _shown:
		_shown = sig
		_fill()


func _signature() -> String:
	var parts: Array = [view.plan_round, view.sneaking, LocationStealth.nearest_waiting(view)]
	for m: Combatant in view.members + view.guest_members:
		parts.append([m.id, LocationPlan.left_ft(view, m), m.creature.hp > 0])
	parts.append(view.leader().id if view.leader() != null else "")
	return str(parts)


## Fills the panel from the view: the round, each member's feet left, the strike button and the sneaking hint.
func _fill() -> void:
	_title.text = "Turn-based · Round %d" % view.plan_round
	for c in _moves.get_children():
		c.queue_free()
	for m: Combatant in view.members + view.guest_members:
		var lead := m == view.leader()
		var text := "%s%s %s" % ["★ " if lead else "", m.name().get_slice(" ", 0),
			"%d ft" % LocationPlan.left_ft(view, m) if m.creature.hp > 0 else "down"]
		var l := UiKit.label(text, 15, "gilt_light" if lead else ("vellum" if m.side == &"party" else "moonlight"))
		l.tooltip_text = "%s: movement left this round%s" % [m.name(), "" if m.side == &"party" else " (a guest: stays where they are)"]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_moves.add_child(l)
	var target := LocationStealth.nearest_waiting(view)
	_strike.disabled = target == ""
	var foe := ""
	for w in view.waiting:
		if str(w["encounter"]) == target and LocationStealth.is_shown(w):
			foe = (w["foe"] as Combatant).name()
			break
	_strike.text = "Attack %s" % foe if foe != "" else "Attack"
	_strike.tooltip_text = "No foes in sight." if target == "" else ("Start the fight from where everyone stands. Foes who haven't noticed the party are surprised." if view.sneaking
		else "Start the fight from where everyone stands. You aren't sneaking, so the foes hear you coming.")
	_hint.text = ("Sneaking: a foe who hasn't noticed you is surprised (Disadvantage on Initiative)." if view.sneaking
		else "Click to move whoever leads; 1-4 or Tab picks who moves. V to sneak and strike with Surprise.")
