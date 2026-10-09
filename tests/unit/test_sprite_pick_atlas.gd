extends TestCase
## Picking against a frame cut from a VRAM-compressed sheet (owner report 2026-10-09: "Cannot blit_rect in compressed
## image formats" kept popping up in Vallaki: hovering over a reflection asked AtlasTexture.get_image(), which cuts the
## compressed sheet as it is). The frame's alpha comes from the decoded sheet, and reflections aren't picked at all.

class Catcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SHADER:
			errors.append(rationale if rationale != "" else code)

	func _log_message(_message: String, _error: bool) -> void:
		pass


## A reflection without its figure (the real one follows a DirectionalSprite's frames).
class LoneReflection extends SpriteReflection:
	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass


var catcher: Catcher


func before_each() -> void:
	catcher = Catcher.new()
	OS.add_logger(catcher)
	SpritePick._alpha.clear()


func after_each() -> void:
	OS.remove_logger(catcher)
	SpritePick._alpha.clear()


## A 64x64 sheet, opaque in its top-left quarter, VRAM-compressed as an imported sprite sheet is.
static func _sheet() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 32, 32), Color(1, 1, 1, 1))
	img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC)
	return ImageTexture.create_from_image(img)


func test_a_frame_of_a_compressed_sheet_reads_its_alpha_without_errors() -> void:
	var sheet := _sheet()
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(16, 16, 32, 32)
	var img := SpritePick._alpha_of(frame)
	assert_true(img != null, "the frame's alpha")
	if img == null:
		return
	assert_eq(img.get_size(), Vector2i(32, 32))
	assert_false(img.is_compressed())
	assert_true(img.get_pixel(4, 4).a > 0.5, "inside the opaque quarter")
	assert_true(img.get_pixel(28, 28).a < 0.5, "outside it")
	assert_eq(catcher.errors, [] as Array[String], "no engine errors")


func test_a_reflection_is_never_picked() -> void:
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	var r := LoneReflection.new()
	r.texture = _sheet()
	r.pixel_size = 0.05
	r.position = Vector3(0, 0, -5)
	root.add_child(r)
	var plain := Sprite3D.new()
	plain.texture = r.texture
	plain.pixel_size = 0.05
	plain.position = Vector3(0, 0, -5)
	var other := Node3D.new()   # beside the reflection's parent, not under it
	add_child(other)
	other.add_child(plain)
	var ray := Vector3(-0.4, 0.4, -5).normalized()   # at the opaque top-left quarter
	assert_true(SpritePick.hit(other, cam, Vector3.ZERO, ray) < INF, "a plain sprite there is hit")
	assert_eq(SpritePick.hit(root, cam, Vector3.ZERO, ray), INF, "its reflection isn't")
	root.queue_free()
	other.queue_free()
