class_name TutorialCoach
extends CanvasLayer
## Coaching stays outside the practice world, with real controls visible behind it.

signal next_requested
signal retry_requested
signal skip_requested
signal exit_requested

const MARGIN := 14.0
const CARD_WIDTH := 468.0
const TOP := 232.0

var next_button: Button
var action_button: Button
var menu_button: Button
var retry_button: Button
var skip_button: Button
var exit_button: Button
var detail_button: Button
var compact_button: Button
var menu_open := false
var complete := false
var compact := false
var _panel: PanelContainer
var _paint: Control
var _shield: Control
var _body_box: VBoxContainer
var _body_scroll: ScrollContainer
var _progress: Label
var _title: Label
var _body: Label
var _objective: Label
var _feedback: Label
var _details: Label
var _hint: Label
var _buttons: VBoxContainer
var _menu_buttons: VBoxContainer
var _return_button: Button
var _footer: HBoxContainer
var _lesson: Dictionary = {}
var _target := Rect2()
var _targets: Array[Rect2] = []
var _read_targets: Array[Rect2] = []
var _read_blocks: Array[Control] = []
var _card_top_right := false
var _action_scope := false
var _dimmer: Control
var _dim_blocks: Array[ColorRect] = []
var _chrome_visible := true
var _free_practice := false
var _step_hint := ""
var event_filter: Callable
var _action := Callable()
var _finished := false
var _details_open := false
var _last_size := Vector2.ZERO
var _last_card_size := Vector2.ZERO
var _last_min_size := Vector2.ZERO
var _last_text_scale := 0.0


func _init() -> void:
	name = "TutorialCoach"
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("pad_scope", false)


func _ready() -> void:
	_build()
	_reflow()


func _build() -> void:
	if _panel != null:
		return
	_dimmer = Control.new()
	_dimmer.name = "WalkthroughDimmer"
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dimmer.set_meta("pad_skip", true)
	add_child(_dimmer)
	_paint = Control.new()
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.set_meta("pad_skip", true)
	_paint.draw.connect(_draw_target)
	add_child(_paint)
	_shield = Control.new()
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.set_meta("pad_skip", true)
	add_child(_shield)
	_panel = UiKit.panel("ui_black", "gilt")
	_panel.name = "CoachCard"
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)
	_progress = _reading_label("LEARN TO PLAY", 13, "parchment")
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_progress)
	compact_button = UiKit.button("Minimize", toggle_compact, 14)
	heading.add_child(compact_button)
	_title = _reading_label("", 21, "gilt_light")
	_title.name = "LessonTitle"
	column.add_child(_title)
	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 10)
	_body_scroll = UiParts.fill_scroll(_body_box)
	_body_scroll.size_flags_vertical = Control.SIZE_FILL
	_body_scroll.name = "LessonReading"
	column.add_child(_body_scroll)
	_body = _reading_label("", 16)
	_objective = _reading_label("", 16, "gilt_light")
	_feedback = _reading_label("", 16)
	_details = _reading_label("", 15, "parchment")
	for label: Label in [_body, _objective, _feedback, _details]:
		_body_box.add_child(label)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	column.add_child(_buttons)
	action_button = UiParts.primary_button("", _do_action)
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_child(action_button)
	next_button = UiParts.primary_button("Continue", _next)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.set_meta("pad_first", true)
	_buttons.add_child(next_button)
	_menu_buttons = VBoxContainer.new()
	_menu_buttons.add_theme_constant_override("separation", 6)
	column.add_child(_menu_buttons)
	_return_button = UiKit.button("Return to practice", close_menu, 16)
	retry_button = UiKit.button("Repeat this lesson", func() -> void: retry_requested.emit(), 16)
	skip_button = UiKit.button("Skip this lesson", func() -> void: skip_requested.emit(), 16)
	exit_button = UiKit.button("Leave tutorial", func() -> void: exit_requested.emit(), 16)
	for button: Button in [_return_button, retry_button, skip_button, exit_button]:
		_menu_buttons.add_child(button)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	column.add_child(_footer)
	detail_button = UiKit.button("More explanation", toggle_details, 14)
	detail_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(detail_button)
	menu_button = UiKit.button("Tutorial menu", show_menu, 14)
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(menu_button)
	_hint = _reading_label("", 12, "parchment")
	column.add_child(_hint)
	PadGlyphs.hint(_hint, "Esc: tutorial menu", "{start}: tutorial menu")
	_refresh_visibility()


static func _reading_label(text: String, size: int, colour: String = "vellum") -> Label:
	var label := UiKit.label(text, UiScale.text(size), colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func present(lesson: Dictionary, index: int, total: int) -> void:
	_build()
	_lesson = lesson.duplicate(true)
	complete = false
	_finished = false
	menu_open = false
	compact = false
	_details_open = false
	_action = Callable()
	action_button.text = ""
	_target = Rect2()
	_targets.clear()
	_read_targets.clear()
	_card_top_right = false
	_action_scope = false
	_chrome_visible = true
	_step_hint = ""
	_free_practice = bool(lesson.get("free_practice", false))
	_progress.text = "LESSON %d OF %d" % [index + 1, total]
	_title.text = str(lesson.get("title", "Learn to play"))
	_set_copy(_body, str(lesson.get("body", "")), str(lesson.get("body_pad", lesson.get("body", ""))))
	_set_copy(_objective, "Try it: " + str(lesson.get("objective", "")), "Try it: " + str(lesson.get("objective_pad", lesson.get("objective", ""))))
	_set_copy(_details, str(lesson.get("details", "")), str(lesson.get("details_pad", lesson.get("details", ""))))
	_feedback.text = ""
	_body_box.move_child(_feedback, 2)
	next_button.text = "Continue"
	_body_scroll.scroll_vertical = 0
	_refresh_visibility()
	_reflow()


func _set_copy(label: Label, keys: String, pad: String) -> void:
	PadGlyphs.hint(label, InputActions.fill(keys), InputActions.fill(pad))


func set_complete(feedback: String) -> void:
	_build()
	complete = true
	compact = false
	_feedback.text = feedback if bool(_lesson.get("read_only", false)) else "Done. " + feedback
	_body_box.move_child(_feedback, 0)
	_body_scroll.scroll_vertical = 0
	_refresh_visibility()
	_reflow()


func set_highlight(rect: Rect2) -> void:
	var rects: Array[Rect2] = []
	if rect.has_area():
		rects.append(rect)
	set_spotlights(rects)


func set_spotlights(rects: Array[Rect2]) -> void:
	if rects == _targets:
		return
	_targets = rects.duplicate()
	_target = _targets[0] if not _targets.is_empty() else Rect2()
	_reflow()
	_sync_masks()


func set_chrome_visible(on: bool) -> void:
	if _chrome_visible == on:
		return
	_chrome_visible = on
	_refresh_visibility()
	_reflow()


func set_step_hint(step: String, hint: String, pad_hint: String = "") -> void:
	if step == _step_hint:
		return
	_step_hint = step
	if not complete and not hint.is_empty():
		_set_copy(_objective, "Next: " + hint, "Next: " + (hint if pad_hint.is_empty() else pad_hint))


func allows_point(point: Vector2) -> bool:
	if _panel != null and _panel.is_visible_in_tree() and _panel.get_global_rect().has_point(point):
		return true
	if interaction_blocked():
		return false
	if _free_practice:
		return true
	for hole in _targets:
		if hole.has_point(point):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not visible or (_free_practice and not interaction_blocked()):
		return
	if event.is_action(&"ui_cancel") or event.is_action(&"pause_menu"):
		return
	if event is InputEventMouseButton:
		if not allows_point((event as InputEventMouseButton).position):
			get_viewport().set_input_as_handled()
		return
	if event_filter.is_valid() and not bool(event_filter.call(event)):
		get_viewport().set_input_as_handled()


func set_action(text: String, callback: Callable) -> void:
	_build()
	_action = callback
	action_button.text = text
	_refresh_visibility()
	_reflow()


func clear_action() -> void:
	_action = Callable()
	if action_button != null:
		action_button.text = ""
		_refresh_visibility()
		_reflow()


func show_menu() -> void:
	_build()
	menu_open = true
	compact = false
	_refresh_visibility()
	_reflow()


func close_menu() -> void:
	menu_open = false
	_refresh_visibility()
	_reflow()
	var focused := get_viewport().gui_get_focus_owner()
	if not complete and focused != null and _panel.is_ancestor_of(focused):
		focused.release_focus()


func toggle_details() -> void:
	_details_open = not _details_open
	compact = false
	_refresh_visibility()
	_reflow()


func toggle_compact() -> void:
	compact = not compact
	_refresh_visibility()
	_reflow()


func show_finished(pending_campaign: bool) -> void:
	present({
		"title": "Ready for your adventure",
		"body": "Choose a hero, check movement and resources, choose an action, read the result, then end the turn. You can replay Learn to play from the title screen whenever you want.",
		"objective": "Begin when you are ready.",
		"details": "Open a character sheet to inspect abilities. Inventory holds equipment and supplies; the journal tracks quests. Rest when it is safe to recover. Hover a rule or number for an explanation, and read the combat log when a result surprises you."
	}, 0, 1)
	_finished = true
	complete = true
	_progress.text = "TRAINING COMPLETE"
	var note := "Your practice party and supplies stay here. Your campaign begins fresh." if pending_campaign else "Your campaign and saves have not been changed."
	_set_copy(_objective, note, note)
	next_button.text = "Start campaign" if pending_campaign else "Return to title"
	_refresh_visibility()
	_reflow()


func interaction_blocked() -> bool:
	return menu_open or complete or _finished


func _refresh_visibility() -> void:
	if _panel == null:
		return
	_panel.visible = _chrome_visible or menu_open
	set_meta("pad_scope", interaction_blocked() or _action_scope)
	_shield.visible = interaction_blocked()
	_body_scroll.visible = not compact
	_body.visible = not _body.text.is_empty() and (not complete or _finished or bool(_lesson.get("read_only", false)))
	_objective.visible = (not str(_lesson.get("objective", "")).is_empty() or _finished) and (not complete or _finished)
	_feedback.visible = complete and not _feedback.text.is_empty()
	_details.visible = _details_open and not _details.text.is_empty()
	_buttons.visible = not compact
	action_button.visible = _action.is_valid() and not complete and not _finished
	next_button.visible = complete and not menu_open
	next_button.disabled = not complete
	_menu_buttons.visible = menu_open
	_return_button.visible = not _finished
	retry_button.visible = not _finished
	skip_button.visible = not _finished
	_footer.visible = not compact
	detail_button.visible = not _details.text.is_empty()
	detail_button.text = "Less explanation" if _details_open else "More explanation"
	menu_button.visible = not menu_open and not _finished
	compact_button.visible = not menu_open and not complete and not _finished
	compact_button.text = "Expand" if compact else "Minimize"
	_hint.visible = not _finished
	_return_button.text = "Return to lesson" if complete else "Return to practice"
	_focus_modal.call_deferred()
	_sync_masks()
	_paint.queue_redraw()


func _do_action() -> void:
	if _action.is_valid() and not complete:
		close_menu()
		_action.call()


func _next() -> void:
	if complete:
		next_requested.emit()


func pad_prompts() -> Array:
	return [["b", "Tutorial menu"], ["start", "Tutorial menu"]]


func _process(_delta: float) -> void:
	if _panel != null and (get_viewport().get_visible_rect().size != _last_size or not is_equal_approx(GameSettings.text_scale(), _last_text_scale) or _panel.size != _last_card_size or _panel.get_combined_minimum_size() != _last_min_size):
		_reflow()


func _reflow() -> void:
	if _panel == null or not is_inside_tree():
		return
	var viewport := get_viewport().get_visible_rect().size
	_last_size = viewport
	_last_text_scale = GameSettings.text_scale()
	for item: Array in [[_title, 21], [_body, 16], [_objective, 16], [_feedback, 16], [_details, 15], [_hint, 12]]:
		(item[0] as Label).add_theme_font_size_override("font_size", UiScale.text(int(item[1])))
	var width := minf(CARD_WIDTH, viewport.x - MARGIN * 2.0)
	_panel.custom_minimum_size.x = width
	var body_height := minf(210.0 if _details_open else 174.0, viewport.y * 0.24)
	if menu_open:
		body_height = minf(body_height, maxf(70.0, viewport.y - 475.0))
	_body_scroll.custom_minimum_size.y = body_height
	_panel.size = Vector2(width, 0)
	var height := _panel.get_combined_minimum_size().y
	var at := Vector2(MARGIN, TOP)
	if menu_open or _finished:
		at = (viewport - Vector2(width, height)) / 2.0
	elif _card_top_right:
		at = Vector2(viewport.x - width - MARGIN, MARGIN)
	elif bool(_lesson.get("read_only", false)):
		at = (viewport - Vector2(width, height)) / 2.0
	elif not _action_scope and _target.has_area() and Rect2(at, Vector2(width, height)).intersects(_target.grow(12.0)):
		at.x = MARGIN if _target.get_center().x >= viewport.x / 2.0 else viewport.x - width - MARGIN
	at.x = clampf(at.x, MARGIN, maxf(MARGIN, viewport.x - width - MARGIN))
	at.y = clampf(at.y, MARGIN, maxf(MARGIN, viewport.y - height - MARGIN))
	_panel.position = at
	_last_card_size = _panel.size
	_last_min_size = _panel.get_combined_minimum_size()
	_sync_masks()
	_paint.queue_redraw()


func _draw_target() -> void:
	if menu_open or _finished or (complete and not bool(_lesson.get("read_only", false))):
		return
	for target in _targets:
		var rect := target.grow(5.0).intersection(get_viewport().get_visible_rect().grow(-4.0))
		if not rect.has_area():
			continue
		_paint.draw_rect(rect.grow(2.0), Look.color("void"), false, 7.0)
		_paint.draw_rect(rect, Look.color("gilt_light"), false, 3.0)
		var point := Vector2(rect.get_center().x, rect.position.y - 7.0)
		if point.y >= 10.0:
			_paint.draw_colored_polygon(PackedVector2Array([point + Vector2(-7, -7), point + Vector2(7, -7), point]), Look.color("gilt_light"))


## Confine keyboard focus as well as pointer/gamepad input while the coach is modal.
func _focus_modal() -> void:
	if not is_inside_tree():
		return
	var buttons: Array[Button] = []
	for child in _panel.find_children("*", "Button", true, false):
		var button := child as Button
		button.focus_next = NodePath()
		button.focus_previous = NodePath()
		for side in 4:
			button.set_focus_neighbor(side, NodePath())
		if button.is_visible_in_tree() and not button.disabled:
			buttons.append(button)
	if not (interaction_blocked() or _action_scope) or buttons.is_empty() or not visible:
		return
	for i in buttons.size():
		var previous := buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		var following := buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_previous = previous
		buttons[i].focus_next = following
		buttons[i].focus_neighbor_top = previous
		buttons[i].focus_neighbor_left = previous
		buttons[i].focus_neighbor_bottom = following
		buttons[i].focus_neighbor_right = following
	var focused := get_viewport().gui_get_focus_owner()
	if focused not in buttons:
		(next_button if next_button.is_visible_in_tree() else buttons[0]).grab_focus()


## Exact subtraction means two separate targets never expose the strip between them.
static func dim_regions(bounds: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var regions: Array[Rect2] = [bounds]
	for raw in holes:
		var hole := raw.abs().intersection(bounds)
		if not hole.has_area():
			continue
		var next: Array[Rect2] = []
		for region in regions:
			var cut := region.intersection(hole)
			if not cut.has_area():
				next.append(region)
				continue
			var pieces: Array[Rect2] = [
				Rect2(region.position, Vector2(region.size.x, cut.position.y - region.position.y)),
				Rect2(Vector2(region.position.x, cut.end.y), Vector2(region.size.x, region.end.y - cut.end.y)),
				Rect2(Vector2(region.position.x, cut.position.y), Vector2(cut.position.x - region.position.x, cut.size.y)),
				Rect2(Vector2(cut.end.x, cut.position.y), Vector2(region.end.x - cut.end.x, cut.size.y)),
			]
			for piece in pieces:
				if piece.has_area():
					next.append(piece)
		regions = next
	return regions


func _sync_masks() -> void:
	if _dimmer == null or not is_inside_tree():
		return
	var viewport := get_viewport().get_visible_rect()
	var regions: Array[Rect2] = []
	var read_blocks: Array[Rect2] = []
	if menu_open or _finished or (complete and not bool(_lesson.get("read_only", false))):
		regions.append(viewport)
	elif not _free_practice:
		var visible_regions: Array[Rect2] = _targets.duplicate()
		visible_regions.append_array(_read_targets)
		regions = dim_regions(viewport, visible_regions)
		for region in _read_targets:
			var clipped := region.abs().intersection(viewport)
			if clipped.has_area():
				read_blocks.append_array(dim_regions(clipped, _targets))
	while _dim_blocks.size() < regions.size():
		var block := ColorRect.new()
		block.color = Color(Look.color("void"), 0.68)
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		block.set_meta("pad_skip", true)
		_dimmer.add_child(block)
		_dim_blocks.append(block)
	for i in _dim_blocks.size():
		var block := _dim_blocks[i]
		block.visible = i < regions.size()
		if block.visible:
			block.position = regions[i].position
			block.size = regions[i].size
	while _read_blocks.size() < read_blocks.size():
		var block := Control.new()
		block.name = "ReadOnlyAperture"
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		block.focus_mode = Control.FOCUS_NONE
		block.set_meta("pad_skip", true)
		_dimmer.add_child(block)
		_read_blocks.append(block)
	for i in _read_blocks.size():
		var block := _read_blocks[i]
		block.visible = i < read_blocks.size()
		if block.visible:
			block.position = read_blocks[i].position
			block.size = read_blocks[i].size
	_paint.queue_redraw()



## Readable apertures never grant input. Interactivity stays exclusively in _targets.
func set_read_regions(rects: Array[Rect2]) -> void:
	if rects == _read_targets:
		return
	_read_targets = rects.duplicate()
	_sync_masks()


func set_card_corner(top_right: bool) -> void:
	if _card_top_right == top_right:
		return
	_card_top_right = top_right
	_reflow()


func set_step_copy(title: String, body: String, details: String = "") -> void:
	_build()
	if _title.text == title and str(_lesson.get("body", "")) == body and str(_lesson.get("details", "")) == details:
		return
	_lesson["title"] = title
	_lesson["body"] = body
	_lesson["details"] = details
	_lesson.erase("body_pad")
	_lesson.erase("details_pad")
	_title.text = title
	_set_copy(_body, body, body)
	_set_copy(_details, details, details)
	_body_scroll.scroll_vertical = 0
	_refresh_visibility()
	_reflow()


func set_action_scope(on: bool) -> void:
	if _action_scope == on:
		return
	_action_scope = on
	set_meta("pad_scope", interaction_blocked() or _action_scope)
	_focus_modal.call_deferred()
