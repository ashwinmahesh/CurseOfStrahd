class_name HoverGlow
extends RefCounted
## Whatever the mouse is over while exploring glows (docs/plans/ui_polish.md, BG3's way of saying "this can be
## used"): a door, chest, thing or way out gets a gilt rim over its meshes (shaders/world/hover_rim.gdshader), a
## billboard brightens. People and the party already answer with the talk cursor and their rings, so they don't.

const RIM := preload("res://shaders/world/hover_rim.gdshader")
const BRIGHT := Color(1.35, 1.25, 1.05)

static var _rim: ShaderMaterial
var _lit: Array[GeometryInstance3D] = []
var _cell := Vector2i(-1, -1)


## Lights what's at `cell` in `view` (if it's a thing to use), and puts out what was lit before.
func show(view: LocationView, cell: Vector2i, thing: Dictionary) -> void:
	if cell == _cell:
		return
	clear()
	_cell = cell
	if view == null or thing.is_empty() or str(thing["kind"]) in ["npc"]:
		return
	if _rim == null:
		_rim = ShaderMaterial.new()
		_rim.shader = RIM
		_rim.set_shader_parameter("tint", Look.color("gilt_light"))
		# After the screen pass (which repaints the screen from what was drawn before it), like the characters.
		_rim.render_priority = DirectionalSprite.RENDER_PRIORITY - 1
	for entry: Array in view.call("_pickables"):
		if entry[1] as Vector2i != cell or not is_instance_valid(entry[0] as Node3D):
			continue
		var node := entry[0] as Node3D
		if node is CombatToken:
			continue
		for g: Node in [node] + node.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if gi == null or not gi.visible:
				continue
			if gi is SpriteBase3D:
				(gi as SpriteBase3D).modulate = BRIGHT
			elif gi.material_overlay == null:
				gi.material_overlay = _rim
			else:
				continue
			_lit.append(gi)


func clear() -> void:
	for gi in _lit:
		if not is_instance_valid(gi):
			continue
		if gi is SpriteBase3D:
			(gi as SpriteBase3D).modulate = Color.WHITE
		elif gi.material_overlay == _rim:
			gi.material_overlay = null
	_lit.clear()
	_cell = Vector2i(-1, -1)
