class_name TrapGlow
extends RefCounted
## What a found trap of the Amber Temple glows with (Amber Temple Look Plan step 13, shaders/world/trap_glow.gdshader): the
## line of warding glyphs in the vaults, the faceless god's gaze in the great hall and the frost vent breathing there.
## TrapSight.dress asks for it beside a trap's own piece and border; freeing what it returns takes it away with the
## trap. Only looks, only in the Modern finish.

const SHADER := preload("res://shaders/world/trap_glow.gdshader")
## By trap id: the kind the shader draws and its palette colour.
const GLOWS := {
	"warding_glyphs": {"kind": 0, "colour": "wick", "strength": 1.1},
	"faceless_gaze": {"kind": 1, "colour": "orchid", "strength": 1.2},
	"frost_vent": {"kind": 2, "colour": "frost", "strength": 1.0},
}


## A flat glow on each of `cells` for the trap `trap` if it has one, else nothing.
static func dress(view: LocationView, trap: Dictionary, cells: Array[Vector2i]) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var spec: Variant = GLOWS.get(str(trap.get("id", "")))
	if spec == null or not Look.modern():
		return out
	var s := spec as Dictionary
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = 1
	m.set_shader_parameter("kind", int(s["kind"]))
	m.set_shader_parameter("colour", Look.color(str(s["colour"])))
	m.set_shader_parameter("strength", float(s["strength"]))
	var root := Node3D.new()
	root.name = "TrapGlow"
	view.board.add_child(root)
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	for c in cells:
		var mi := MeshInstance3D.new()
		mi.name = "Glow"
		mi.mesh = quad
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(float(c.x) + 0.5, view.board.floor_y(c) + 0.045, float(c.y) + 0.5)
		root.add_child(mi)
	out.append(root)
	return out
