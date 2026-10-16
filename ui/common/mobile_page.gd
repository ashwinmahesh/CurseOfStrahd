class_name MobilePage
extends PanelContainer
## A safe-area page with a permanent Back control and a scrolling body. Existing wide details remain scrollable
## while individual screens reflow their primary columns; the title and Back never scroll out of reach.

var body: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var toolbar: VBoxContainer
var back_action: Callable


static func build(layer: CanvasLayer, title: String, close: Callable = cancel) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var page := MobilePage.new()
	page.back_action = close
	page.set_meta(&"pad_scope", true)
	page.add_theme_stylebox_override("panel", UiKit.style())
	layer.add_child(page)
	var column := VBoxContainer.new()
	page.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var back := UiKit.button("Back", func() -> void: page.back_action.call())
	back.name = "MobileBack"
	bar.add_child(back)
	page.heading = UiKit.title(title)
	page.heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.heading.clip_text = true
	page.heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(page.heading)
	page.toolbar = VBoxContainer.new()
	column.add_child(page.toolbar)
	page.scroll = ScrollContainer.new()
	page.scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(page.scroll)
	page.body = VBoxContainer.new()
	page.body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.body.add_theme_constant_override("separation", 10)
	page.scroll.add_child(page.body)
	page.reflow()
	return page.body


static func cancel() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		event.set_meta(&"touch_synthetic", true)
		tree.root.push_input(event)


func _ready() -> void:
	get_viewport().size_changed.connect(reflow)
	if UiFeel.touch != null:
		UiFeel.touch.cancel()


## A screen can install a real navigation callback; the compatibility fallback remains for older pages.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and back_action != cancel and is_visible_in_tree():
		back_action.call()
		get_viewport().set_input_as_handled()


func reflow() -> void:
	var rect := MobileDevice.safe_rect().grow(-4)
	position = rect.position
	size = rect.size
	custom_minimum_size = Vector2.ZERO
	if scroll != null:
		scroll.custom_minimum_size = Vector2.ZERO
