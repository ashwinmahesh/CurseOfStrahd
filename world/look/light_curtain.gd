class_name LightCurtain
extends RefCounted
## A curtain of cold light hung across a passage (Castle Ravenloft's guardians before the royal tomb, the book's K87:
## Dungeon Expansion Plan C11). There is no painted piece for it: an upright sheet of light, brightest at its hem and
## fading upward, that ripples slowly as if seen through water. Only a look: whether it lets anyone by is the door on
## its square (`leaf: "none"`). Its colour is moon blue, or the palette colour a prop's `flame` names.

const WIDTH := 1.0
const HEIGHT := 2.4
## How strongly it glows at its hem and at its top (alpha), and how fast it ripples.
const HEM := 0.55
const TOP := 0.08
const RIPPLE_SPEED := 0.35

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.7, 1.0, 1.0);
uniform float hem = 0.55;
uniform float top = 0.08;
uniform float speed = 0.35;
void fragment() {
	float up = 1.0 - UV.y;
	float body = mix(hem, top, smoothstep(0.0, 1.0, up));
	float ripple = 0.75 + 0.25 * sin(UV.x * 18.0 + TIME * speed * 6.2831 + up * 7.0)
		* sin(UV.x * 5.0 - TIME * speed * 3.1 + up * 3.0);
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	ALBEDO = tint.rgb;
	ALPHA = clamp(body * ripple * edge, 0.0, 1.0);
}
"""

static var _shader: Shader = null


## Builds the curtain on `cell` under `root` (SetDressing._place's node for the prop), facing across the passage: along
## x when walls stand either side of it east and west, else along z.
static func place(board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary) -> Node3D:
	var across_x := _wall(board, cell + Vector2i(-1, 0)) or _wall(board, cell + Vector2i(1, 0))
	var sheet := MeshInstance3D.new()
	sheet.name = "LightCurtain"
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	sheet.mesh = quad
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position = board.cell_center(cell) + Vector3(0, HEIGHT / 2.0, 0)
	sheet.rotation.y = 0.0 if across_x else PI / 2.0
	sheet.material_override = material(str(spec.get("flame", "moon_blue")))
	root.add_child(sheet)
	return root


## The curtain's material in palette colour `colour`.
static func material(colour: String) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var c := Look.color(colour)
	mat.set_shader_parameter("tint", Color(c.r, c.g, c.b, 1.0))
	mat.set_shader_parameter("hem", HEM)
	mat.set_shader_parameter("top", TOP)
	mat.set_shader_parameter("speed", RIPPLE_SPEED)
	return mat


static func _wall(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL)
