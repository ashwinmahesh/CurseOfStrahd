class_name HeatShimmer
extends CanvasLayer
## The air wavering above open fires and torches out of doors (Visual Polish Plan 8, shaders/post/heat_shimmer.gdshader):
## each fire's light (Atmosphere._dress_light hands over those of kind "fire" and "torch") gets a patch of the finished
## picture above it, nudged by rising waves. Indoors a hearth's heat goes up its chimney, and the patch would bend the
## wall above it, so rooms get none. One layer per place (a child of its Atmosphere), over the world and under
## the HUD and menus; only the nearest few fires in view shimmer, and with none in view it draws nothing. Only in the
## Modern finish. Cosmetic: it changes nothing the rules see.

const SHADER := preload("res://shaders/post/heat_shimmer.gdshader")
## Over the world, under the fight pulses (ScreenPulse.LAYER) and every menu and the HUD.
const LAYER := -6
## Each kind: the patch's width and height above the flame (world units), and how strongly it wavers.
const KINDS := {
	"fire": {"width": 1.0, "height": 1.6, "strength": 0.005},
	"torch": {"width": 0.45, "height": 0.8, "strength": 0.003},
}
## The most fires that shimmer at once (the nearest the camera's focus).
const MOST := 6

## Captures and the perf probe turn the shimmer off to compare (perf_run.py --effects HeatShimmer).
static var enabled := true

## The fires: [light, kind].
var fires: Array[Array] = []
var _patches: Array[ColorRect] = []


static func set_enabled(on: bool) -> void:
	enabled = on


## Adds fire `light` of `kind` to the place's shimmer (made under `atmo` on first use). Out of doors in the Modern
## finish only.
static func add(atmo: Atmosphere, light: Node3D, kind: String) -> HeatShimmer:
	if not Look.modern() or not KINDS.has(kind) or atmo == null or not atmo.outdoors:
		return null
	var h := atmo.get_node_or_null("HeatShimmer") as HeatShimmer
	if h == null:
		h = HeatShimmer.new()
		h.name = "HeatShimmer"
		h.layer = LAYER
		atmo.add_child(h)
	h.fires.append([light, kind])
	return h


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var shown := 0
	if enabled and cam != null:
		var size := get_viewport().get_visible_rect().size
		var focus := cam.global_position + -cam.global_basis.z * 10.0
		var near: Array[Array] = []
		for f in fires:
			var l: Variant = f[0]
			if not is_instance_valid(l) or not (l as Node3D).is_visible_in_tree():
				continue
			var at := (l as Node3D).global_position
			if cam.is_position_behind(at):
				continue
			near.append([at.distance_squared_to(focus), at, f[1]])
		near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for n in near:
			if shown >= MOST:
				break
			if _place(shown, cam, size, n[1] as Vector3, KINDS[n[2]] as Dictionary):
				shown += 1
	for i in range(shown, _patches.size()):
		_patches[i].visible = false
	visible = shown > 0


## Puts patch `i` over a fire at `at`; false when it falls off the screen.
func _place(i: int, cam: Camera3D, size: Vector2, at: Vector3, k: Dictionary) -> bool:
	var right := cam.global_basis.x.normalized()
	var foot := cam.unproject_position(at)
	var top := cam.unproject_position(at + Vector3.UP * float(k["height"]))
	var half := (cam.unproject_position(at + right * float(k["width"]) * 0.5) - foot).length()
	var rect := Rect2(Vector2(minf(foot.x, top.x) - half, top.y), Vector2(half * 2.0 + absf(top.x - foot.x), foot.y - top.y))
	if rect.size.y < 2.0 or not Rect2(Vector2.ZERO, size).intersects(rect):
		return false
	while _patches.size() <= i:
		var r := ColorRect.new()
		r.name = "Shimmer%d" % _patches.size()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("seed", float(_patches.size()) * 3.7)
		r.material = m
		add_child(r)
		_patches.append(r)
	var p := _patches[i]
	p.position = rect.position
	p.size = rect.size
	p.visible = true
	var mat := p.material as ShaderMaterial
	mat.set_shader_parameter("strength", float(k["strength"]))
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	return true
