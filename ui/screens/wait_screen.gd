class_name WaitScreen
extends CanvasLayer
## Wait (owner, 2026-10-08): pass 1 to 24 hours where the party stands, from the exploring bar's Wait button or H. The
## clock moves and everything that runs on it with it: the day's scheduled events and who stands where (LocationClock),
## the weather, the daylight, spells running out. Waiting isn't resting: no Hit Points, Hit Point Dice, spell slots or
## features come back. It can't be done in a fight, a conversation or a cutscene, or with foes in sight; then the screen
## says why and offers only Back. Left/Right (or the slider, or − and +) pick the hours, Enter waits, Esc goes back.

const MIN_HOURS := 1
const MAX_HOURS := 24
const START_HOURS := 1

var root: Node
var st: StoryState
var hours := START_HOURS
## Why waiting can't be done here, or "" when it can.
var blocked := ""
var _hours_label: Label
var _until: Label
var _slider: HSlider
var _go: Button
var _waited := false   ## a second Enter or click before the screen is gone does nothing


func _init() -> void:
	name = "WaitScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	build(root_, state, why_not(root_, state))


## The screen, with `reason` why waiting can't be done ("" when it can).
func build(root_: Node, state: StoryState, reason: String) -> void:
	root = root_
	st = state
	blocked = reason
	var box := UiKit.screen_frame(self, "Wait", Vector2(820, 360))
	box.add_theme_constant_override("separation", 14)
	var clear := Control.new()   # clear of the title's crest
	clear.custom_minimum_size = Vector2(0, 16)
	box.add_child(clear)
	box.add_child(UiKit.label("Pass the time where you stand. Waiting isn't resting: no Hit Points, Hit Point Dice, spell slots or features come back.",
		16, "parchment", 740))
	if blocked != "":
		box.add_child(UiKit.label(blocked, 18, "gilt_light", 740))
		box.add_child(_buttons(false))
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiKit.button("−", func() -> void: set_hours(hours - 1), 20))
	_slider = HSlider.new()
	_slider.min_value = MIN_HOURS
	_slider.max_value = MAX_HOURS
	_slider.step = 1
	_slider.value = hours
	_slider.custom_minimum_size = Vector2(380, 32)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(func(v: float) -> void: set_hours(int(v)))
	row.add_child(_slider)
	row.add_child(UiKit.button("+", func() -> void: set_hours(hours + 1), 20))
	box.add_child(row)
	_hours_label = UiKit.title("")
	_hours_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hours_label)
	_until = UiKit.label("", 16, "vellum", 740)
	_until.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_until)
	box.add_child(_buttons(true))
	set_hours(hours)


## Why the party can't wait now, or "": in a fight, a conversation or a cutscene, or with foes in sight.
static func why_not(root_: Node, state: StoryState) -> String:
	var view := root_.get("view") as LocationView if root_ != null else null
	if view != null and view.in_combat:
		return "Not in the middle of a fight."
	if root_ != null and root_.get("dialogue") != null:
		return "Not in the middle of a conversation."
	if root_ != null and root_.get("screen") is CutscenePlayer:
		return "Not while a scene is playing."
	if view != null and LocationStealth.nearest_waiting(view) != "":
		return "Not with foes in sight. Deal with them, or get out of their sight first."
	if state == null or state.party.is_empty():
		return "There is no one to wait."
	return ""


## The clock `h` hours from now, as the HUD shows it: "Day 3 · 22:00 (night)".
static func clock_after(state: StoryState, h: int) -> String:
	var m := state.total_minutes() + h * 60
	var of_day := m % (24 * 60)
	var night := of_day < 6 * 60 or of_day >= 19 * 60
	return "Day %d · %02d:%02d (%s)" % [floori(m / (24.0 * 60.0)) + 1, floori(of_day / 60.0), of_day % 60, "night" if night else "day"]


func set_hours(h: int) -> void:
	hours = clampi(h, MIN_HOURS, MAX_HOURS)
	if _slider != null and int(_slider.value) != hours:
		_slider.set_value_no_signal(hours)
	if _hours_label == null:
		return
	_hours_label.text = "1 hour" if hours == 1 else "%d hours" % hours
	_until.text = "Until %s" % clock_after(st, hours)
	_go.text = "Wait %s" % _hours_label.text


## Waits: the clock moves on by the hours picked (the screen fades to "N hours later" and the place catches up).
func wait() -> void:
	if blocked != "" or _waited:
		return
	_waited = true
	var minutes := hours * 60
	root.call("close_screen")
	st.advance_minutes(minutes)
	if root.has_method("_refresh"):
		root.call("_refresh")


func _buttons(can_wait: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	if can_wait:
		_go = UiKit.button("Wait", wait, 18, "wait")
		_go.name = "Wait"
		row.add_child(_go)
	var back := UiKit.button("Back", func() -> void: root.call("close_screen"), 18)
	back.name = "Back"
	row.add_child(back)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if blocked != "" or not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_LEFT:
			set_hours(hours - 1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			set_hours(hours + 1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			wait()
