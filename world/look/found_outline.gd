class_name FoundOutline
extends RefCounted
## How something a Search or a check just found looks (FoundGlow decides what glows and when): an orange line round
## its shape, a dark hairline beyond it (so it reads on pale ground too) and a soft orange glow beyond that; and where a
## wall or a pillar stands well in front of it, a fainter orange shape seen through, so a find behind a cut-away wall
## still shows where it is (not a door's: its leaf always sits partly in its wall). A 2D piece (a Sprite3D) gets
## shaders/world/found_outline_sprite.gdshader as its overlay, which finds the picture's edge in its texture, then
## found_outline_sprite_xray.gdshader. A 3D piece (a satchel, a
## bookcase door: most things are modelled) gets a chain of passes as its overlay: a faint rim that also marks the
## piece in the stencil buffer (found_rim.gdshader), the piece drawn again shifted a few pixels eight ways for each
## ring, only where the stencil isn't marked (found_outline_mesh.gdshader), so the line follows its shape however its
## faces are cut, and the shape seen through (found_xray_mesh.gdshader). Orange, so it reads as none of the gilt hover
## glow, a spell area's pale gold edge or a fight's rings; drawn after the screen pass like the characters, so the
## classic look's palette snap and ink leave it as it is.

const SPRITE_SHADER := preload("res://shaders/world/found_outline_sprite.gdshader")
const SPRITE_XRAY_SHADER := preload("res://shaders/world/found_outline_sprite_xray.gdshader")
const RIM_SHADER := preload("res://shaders/world/found_rim.gdshader")
const MESH_SHADER := preload("res://shaders/world/found_outline_mesh.gdshader")
const MESH_XRAY_SHADER := preload("res://shaders/world/found_xray_mesh.gdshader")
## How far past a picture's edges its outline is drawn (world units): room for the glow when the camera is far out.
const MARGIN := 0.3
## The line's orange: the palette's candle, warmed toward flame in the classic look; its glow is candle.
const LINE_WARMTH := 0.4
## The modern finish tone-maps with AgX at exposure 1.35 (Atmosphere), which washes a full-strength orange toward pale
## gold: there the outline is drawn this much dimmer and more saturated, so it stays orange.
const MODERN_BRIGHT := 0.85
const MODERN_SATURATE := 1.6
## A 3D piece's rings (screen pixels out from its edge): the line, the dark hairline and the glow, each drawn eight
## ways round [radius, colour, alpha]; and the rim's render priority, the rings' one each after it in that order (each
## ring fills only what the ones before it left), all after the screen pass and under the characters.
const RINGS: Array[Array] = [[2.5, "line", 1.0], [3.75, "void", 0.7], [8.0, "candle", 0.3]]
const RIM_PRIORITY := DirectionalSprite.RENDER_PRIORITY - 4


## Outlines everything drawn under `root`: its sprites and meshes, but not a fire's flame. `see_through`: its shape also
## shows through a wall in front (not for a door, whose leaf always sits in its wall). Returns what it lit, for glow(),
## refit() and remove(): [{geo, mat, tex, px}].
static func apply(root: Node3D, see_through: bool = true) -> Array[Dictionary]:
	var lit: Array[Dictionary] = []
	if root == null or not is_instance_valid(root):
		return lit
	var mesh_mat: ShaderMaterial = null
	for n: Node in [root] + root.find_children("*", "GeometryInstance3D", true, false):
		var geo := n as GeometryInstance3D
		if geo == null or geo is SpriteReflection or geo.is_queued_for_deletion() or _in_flame(geo, root):
			continue
		if geo.material_overlay != null and geo.material_overlay != HoverGlow._rim:
			continue   # someone else's overlay (the hover glow's rim gives way: this one says more)
		if geo is SpriteBase3D:
			var mat := _sprite_material(see_through)
			var entry := {"geo": geo, "mat": mat, "tex": null, "px": 0.0}
			_fit(entry)
			geo.material_overlay = mat
			lit.append(entry)
		elif geo is MeshInstance3D and (geo as MeshInstance3D).mesh != null:
			if mesh_mat == null:
				mesh_mat = _mesh_material(see_through)
			geo.material_overlay = mesh_mat
			lit.append({"geo": geo, "mat": mesh_mat})
	return lit


## Sets how strongly `lit` glows: 1 the steady outline, more while it pulses, 0 gone.
static func glow(lit: Array[Dictionary], k: float) -> void:
	var done := {}
	for entry in lit:
		if not done.has(entry["mat"]):
			done[entry["mat"]] = true
			_set_all(entry["mat"] as ShaderMaterial, "glow", k)


## Keeps each sprite's outline on its picture when the picture changes (a PropView turns to show its back).
static func refit(lit: Array[Dictionary]) -> void:
	for entry in lit:
		if not is_instance_valid(entry["geo"]) or not entry["geo"] is SpriteBase3D:
			continue
		var sp := entry["geo"] as SpriteBase3D
		_motion(sp, entry["mat"] as ShaderMaterial)
		if _texture(sp) != entry["tex"] or sp.pixel_size != float(entry["px"]) \
			or sp.flip_h != bool(entry.get("flip_h", false)) or sp.flip_v != bool(entry.get("flip_v", false)):
			_fit(entry)


## Takes the outline off whatever of `lit` is still there.
static func remove(lit: Array[Dictionary]) -> void:
	for entry in lit:
		if is_instance_valid(entry["geo"]) and (entry["geo"] as GeometryInstance3D).material_overlay == entry["mat"]:
			(entry["geo"] as GeometryInstance3D).material_overlay = null


## Whether all of `lit` is still in the world (a rebuild of the place's pieces frees them).
static func alive(lit: Array[Dictionary]) -> bool:
	for entry in lit:
		if not is_instance_valid(entry["geo"]) or (entry["geo"] as Node).is_queued_for_deletion():
			return false
	return true


## The line's colour in the current look.
static func line_colour() -> Color:
	return Look.color("candle") if Look.modern() else Look.color("candle").lerp(Look.color("flame"), LINE_WARMTH)


static func _sprite_material(see_through: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	# After the screen pass, with the hover glow (just under the characters, so one standing in front stays in front).
	mat.render_priority = DirectionalSprite.RENDER_PRIORITY - 1
	if see_through:
		var xray := ShaderMaterial.new()
		xray.shader = SPRITE_XRAY_SHADER
		xray.render_priority = mat.render_priority
		mat.next_pass = xray
	_set_all(mat, "line_color", line_colour())
	_set_all(mat, "halo_color", Look.color("candle"))
	_set_all(mat, "edge_color", Look.color("void"))
	_tone(mat)
	return mat


static func _mesh_material(see_through: bool) -> ShaderMaterial:
	var rim := ShaderMaterial.new()
	rim.shader = RIM_SHADER
	rim.render_priority = RIM_PRIORITY
	rim.set_shader_parameter("tint", Look.color("candle"))
	var last := rim
	for i in RINGS.size():
		var ring := RINGS[i]
		var colour := line_colour() if str(ring[1]) == "line" else Look.color(str(ring[1]))
		for k in 8:
			var pass_mat := ShaderMaterial.new()
			pass_mat.shader = MESH_SHADER
			pass_mat.render_priority = RIM_PRIORITY + 1 + i
			pass_mat.set_shader_parameter("color", Color(colour, float(ring[2])))
			pass_mat.set_shader_parameter("shift", Vector2.from_angle(k * PI / 4.0) * float(ring[0]))
			last.next_pass = pass_mat
			last = pass_mat
	if see_through:
		var xray := ShaderMaterial.new()
		xray.shader = MESH_XRAY_SHADER
		xray.render_priority = RIM_PRIORITY + RINGS.size()
		xray.set_shader_parameter("color", Look.color("candle"))
		last.next_pass = xray
	_tone(rim)
	return rim


## The look's brightness and saturation on every pass of `mat` (MODERN_BRIGHT, MODERN_SATURATE).
static func _tone(mat: ShaderMaterial) -> void:
	_set_all(mat, "bright", MODERN_BRIGHT if Look.modern() else 1.0)
	_set_all(mat, "saturate", MODERN_SATURATE if Look.modern() else 1.0)


## Sets shader parameter `param` on `mat` and every pass after it.
static func _set_all(mat: ShaderMaterial, param: String, value: Variant) -> void:
	var m: Material = mat
	while m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(param, value)
		m = m.next_pass


## The sprite outline's quad and picture for the sprite as it is now (Sprite3D draws its quad from get_item_rect, in
## the plane its axis gives: x, y for z; x, -y on x and z for y; -x, y on z and y for x).
static func _texture(sp: SpriteBase3D) -> Texture2D:
	if sp is Sprite3D:
		return (sp as Sprite3D).texture
	var animated := sp as AnimatedSprite3D
	if animated != null and animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation) \
			and animated.sprite_frames.get_frame_count(animated.animation) > 0:
		return animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	return null


static func _fit(entry: Dictionary) -> void:
	var sp := entry["geo"] as SpriteBase3D
	var mat := entry["mat"] as ShaderMaterial
	var texture := _texture(sp)
	entry["tex"] = texture
	entry["px"] = sp.pixel_size
	entry["flip_h"] = sp.flip_h
	entry["flip_v"] = sp.flip_v
	if texture == null:
		return
	var src := Rect2(Vector2.ZERO, texture.get_size())
	if sp is Sprite3D:
		var still := sp as Sprite3D
		var frame := texture.get_size() / Vector2(still.hframes, still.vframes)
		src = still.region_rect if still.region_enabled else Rect2(Vector2(still.frame_coords) * frame, frame)
	var rect := sp.get_item_rect()
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		# Packed animation frames trim transparent margins. The drawn quad/UVs cover only the region.
		src = atlas.region
		var margin := atlas.margin
		var offset := Vector2(margin.position.x, margin.size.y - margin.position.y)
		if sp.flip_h:
			offset.x = margin.size.x - margin.position.x
		if sp.flip_v:
			offset.y = margin.position.y
		rect.position += offset
		rect.size = atlas.region.size
		texture = atlas.atlas
	var tex_size := texture.get_size()
	_set_all(mat, "sprite_tex", texture)
	_set_all(mat, "uv_rect", Vector4(src.position.x / tex_size.x, src.position.y / tex_size.y, src.size.x / tex_size.x,
		src.size.y / tex_size.y))
	var size := rect.size * sp.pixel_size
	var c := (rect.position + rect.size / 2.0) * sp.pixel_size
	var plane := 0 if sp.axis == Vector3.AXIS_Z else (1 if sp.axis == Vector3.AXIS_Y else 2)
	_set_all(mat, "plane", plane)
	_set_all(mat, "quad_center", [Vector3(c.x, c.y, 0.0), Vector3(c.x, 0.0, -c.y), Vector3(0.0, c.y, -c.x)][plane])
	_set_all(mat, "grow", Vector2(1.0 + 2.0 * MARGIN / maxf(size.x, 0.01), 1.0 + 2.0 * MARGIN / maxf(size.y, 0.01)))
	var billboard := 0
	match sp.billboard:
		BaseMaterial3D.BILLBOARD_ENABLED, BaseMaterial3D.BILLBOARD_PARTICLES:
			billboard = 1
		BaseMaterial3D.BILLBOARD_FIXED_Y:
			billboard = 2
	_set_all(mat, "billboard", billboard)
	_set_all(mat, "alpha_cut", sp.alpha_scissor_threshold)
	_motion(sp, mat)


## A fire's flame (SetDressing.flame, its pieces named Flame) isn't the thing found.
static func _in_flame(geo: Node, root: Node) -> bool:
	var n := geo
	while n != null and n != root.get_parent():
		if str(n.name).begins_with("Flame"):
			return true
		n = n.get_parent()
	return false


## Follow the same billboard and pose deformation as character art; static props keep identity defaults.
static func _motion(sp: SpriteBase3D, mat: ShaderMaterial) -> void:
	if not sp is DirectionalSprite:
		return
	var source := sp.material_override as ShaderMaterial
	if source == null:
		return
	for key: String in ["face", "depth_nudge"]:
		_set_all(mat, "figure_" + key, source.get_shader_parameter(key))
	if source.shader == DirectionalSprite.CRISP:
		for key: String in ["squash", "lean", "lift", "push"]:
			_set_all(mat, "figure_" + key, source.get_shader_parameter(key))
