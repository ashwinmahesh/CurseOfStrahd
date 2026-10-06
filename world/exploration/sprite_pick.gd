class_name SpritePick
extends RefCounted
## Picking what's drawn rather than the floor (owner report 2026-10-06: the top of a tall prop lies over the square
## behind it, so hovering there missed the prop). A ray from the camera is tested against each sprite's quad as it is
## drawn (billboards turned to the camera, wall pieces flat on their wall), and for props against the texture's alpha,
## so only the painted part counts. Characters use a band down the middle of their frame.

## Decompressed alpha of each prop texture, by resource path (VRAM-compressed sheets are decoded once).
static var _alpha: Dictionary = {}


## Distance along the ray to the nearest opaque point of any sprite in `node` (itself and its children), or INF.
static func hit(node: Node3D, camera: Camera3D, origin: Vector3, dir: Vector3) -> float:
	var best := INF
	if node == null or not node.is_visible_in_tree():
		return best
	var sprites: Array[SpriteBase3D] = []
	if node is SpriteBase3D:
		sprites.append(node as SpriteBase3D)
	for c in node.get_children():
		if c is SpriteBase3D:
			sprites.append(c as SpriteBase3D)
		for g in c.get_children():
			if g is SpriteBase3D:
				sprites.append(g as SpriteBase3D)
	for s in sprites:
		if s.is_visible_in_tree():
			best = minf(best, sprite_hit(s, camera, origin, dir))
	return best


## The ray against one sprite: INF if it misses the sprite's painted pixels.
static func sprite_hit(s: SpriteBase3D, camera: Camera3D, origin: Vector3, dir: Vector3) -> float:
	if s.axis != Vector3.AXIS_Z:
		return INF   # pieces lying flat on the floor: the floor square under them is the same square
	var tex := _texture(s)
	if tex == null:
		return INF
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var gb := s.global_basis
	var sx := gb.x.length() * s.pixel_size
	var sy := gb.y.length() * s.pixel_size
	var right: Vector3
	var up: Vector3
	match s.billboard:
		BaseMaterial3D.BILLBOARD_FIXED_Y:
			right = camera.global_basis.x
			right.y = 0.0
			right = right.normalized()
			up = Vector3.UP
		BaseMaterial3D.BILLBOARD_ENABLED:
			right = camera.global_basis.x.normalized()
			up = camera.global_basis.y.normalized()
		_:
			right = gb.x.normalized()
			up = gb.y.normalized()
	var n := right.cross(up)
	var denom := dir.dot(n)
	if absf(denom) < 0.0001:
		return INF
	var pos := s.global_position
	var t := (pos - origin).dot(n) / denom
	if t <= 0.0:
		return INF
	var p := origin + dir * t - pos
	# Pixel coordinates in the texture (x from the left, y from the top), from the quad's offset and centring.
	var ux := p.dot(right) / sx - s.offset.x
	var uy := p.dot(up) / sy - s.offset.y
	var tx := ux + (w / 2.0 if s.centered else 0.0)
	var ty := (h / 2.0 if s.centered else h) - uy
	if tx < 0.0 or ty < 0.0 or tx >= w or ty >= h:
		return INF
	if s is Sprite3D and (s as Sprite3D).flip_h:
		tx = w - 1.0 - tx
	if s is AnimatedSprite3D:
		# A character: the figure fills a band down the middle of its frame.
		return t if absf(tx - w / 2.0) < w * 0.22 and ty > h * 0.08 else INF
	var img := _alpha_of(tex)
	if img == null:
		return t
	var ix := clampi(int(tx * img.get_width() / w), 0, img.get_width() - 1)
	var iy := clampi(int(ty * img.get_height() / h), 0, img.get_height() - 1)
	return t if img.get_pixel(ix, iy).a > 0.5 else INF


static func _texture(s: SpriteBase3D) -> Texture2D:
	if s is Sprite3D:
		return (s as Sprite3D).texture
	if s is AnimatedSprite3D:
		var a := s as AnimatedSprite3D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation):
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
	return null


static func _alpha_of(tex: Texture2D) -> Image:
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_rid())
	if _alpha.has(key):
		return _alpha[key] as Image
	var img := tex.get_image()
	if img != null and img.is_compressed():
		if img.decompress() != OK:
			img = null
	_alpha[key] = img
	return img
