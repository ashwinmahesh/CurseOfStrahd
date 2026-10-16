class_name MobileDevice
extends Node
## Platform availability, logical-point layout and input modality are separate. --mobile=iphone|ipad exercises
## the same UI on a desktop, without claiming to be an iOS simulator or changing persisted player settings.

signal modality_changed(mode: String)

static var current: MobileDevice
static var profile := _argument_profile()
static var test_size := Vector2.ZERO
static var test_safe := Rect2()
var modality := "touch"
var _configuring := false


static func _argument_profile() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg in ["--mobile=iphone", "--mobile=ipad"]:
			return arg.get_slice("=", 1)
	return ""


static func enabled() -> bool:
	return OS.has_feature("ios") or profile != "" or test_size != Vector2.ZERO


static func compact() -> bool:
	var area := safe_rect()
	return area.size.x < 900 or area.size.y < 600


static func logical_size() -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_visible_rect().size if tree != null else Vector2(1600, 900)


static func safe_rect() -> Rect2:
	var size := logical_size()
	if test_safe.has_area():
		var ratio := size / test_size if test_size != Vector2.ZERO else Vector2.ONE
		return Rect2(test_safe.position * ratio, test_safe.size * ratio).intersection(Rect2(Vector2.ZERO, size))
	if profile == "iphone":
		var ratio := size / Vector2(844, 390)
		return Rect2(Vector2(47, 8) * ratio, Vector2(750, 361) * ratio)
	if profile == "ipad":
		var ratio := size / Vector2(1194, 834)
		return Rect2(Vector2(8, 8) * ratio, Vector2(1178, 806) * ratio)
	if OS.has_feature("ios"):
		var native := Rect2(DisplayServer.get_display_safe_area())
		var pixels := Vector2(DisplayServer.window_get_size())
		if native.has_area() and pixels.x > 0 and pixels.y > 0:
			return Rect2(native.position * size / pixels, native.size * size / pixels).intersection(Rect2(Vector2.ZERO, size))
	return Rect2(Vector2.ZERO, size)


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if enabled():
		Input.emulate_mouse_from_touch = false
		Input.emulate_touch_from_mouse = false
		get_window().size_changed.connect(configure)
		configure()


func _exit_tree() -> void:
	if current == self:
		current = null


func configure() -> void:
	if not enabled() or _configuring:
		return
	_configuring = true
	var window := get_window()
	var points := Vector2(window.size) / maxf(DisplayServer.screen_get_scale(), 1.0)
	if profile != "":
		points = Vector2(844, 390) if profile == "iphone" else Vector2(1194, 834)
	if test_size != Vector2.ZERO:
		points = test_size
	window.content_scale_size = Vector2i(points)
	window.content_scale_factor = maxf(1.0, GameSettings.ui_scale())
	_configuring = false


func _input(event: InputEvent) -> void:
	if not enabled() or event.has_meta(&"touch_synthetic") or event.has_meta(&"pad_synthetic"):
		return
	var mode := modality
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		mode = "touch"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		mode = "controller"
	elif event is InputEventKey or event is InputEventMouseButton:
		mode = "pointer"
	if mode != modality:
		modality = mode
		modality_changed.emit(mode)
