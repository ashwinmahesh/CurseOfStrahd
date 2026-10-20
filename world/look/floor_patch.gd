class_name FloorPatch
extends RefCounted
## Rubble, water and webs that blend into the floor (owner 2026-10-19: "Basically we want the world to look more natural";
## the vault's Natural Maps Plan, I4, after N2's blended ground). On a board whose floors are boxes (every interior and
## dungeon, an outdoor dungeon map, a board with no place) each '~' square carried a material of its own, so a run of
## rubble, a flooded passage or a hall of webs was a rectangle of square tiles laid in the room's floor. Here the run's
## squares and the squares round it are covered by one thin patch drawn with N2's blend (Look.blend_ground,
## lit_world_blend.gdshader): the difficult surface and the room's own floor (up to three of them: the squares round the
## run may be different rooms') melt into each other at the run's edge, which the shader breaks up with noise and lets
## spill up to half a square into the floor beside it; a difficult square's middle 60% is always its own surface. The
## room's floor tiles beyond the patch are the boxes' own, untouched, and a patch's outer squares are that same floor.
## The patch is one flat quad over each square, a child of the square's floor box, so whatever hides or opens a floor
## (a stairwell, a secret room) hides its patch with it. Modern only; cosmetic, the rules grid never sees any of it.
## Where the floors are the shaped ground's (every outdoor map but the built-floor ones) N2 draws all this itself.

## Off in tests and timing runs that compare with the squares as they were (Modern only either way).
static var enabled := true
## How far above the floor's top the patch lies, so it never fights the box under it.
const LIFT := 0.004
## The surface a place's rubble is when neither its look nor its theme names one (an interior's, a dungeon's own is mud).
const DEFAULT_SURFACE := "dungeon/packed_earth"
## How far noise moves the patch's edge, and how far the rubble creeps out over the floor beside it (N2's blend uniforms).
const EDGE_NOISE := 1.0
const SPILL := 4.5


## Lays the patches of the board's difficult floor (ArenaBoard._build asks once its floors are built). The number of
## squares covered, 0 where none are.
static func lay(board: ArenaBoard) -> int:
	if not enabled or not Look.modern():
		return 0
	var loc := Compendium.shared().get_entry("locations", board.place) if board.place != "" \
		and Compendium.shared().has("locations", board.place) else {}
	if GroundRelief.eligible(board, loc):
		return 0   # the shaped ground blends this map's difficult ground itself
	var grid := board.grid
	var diff: Dictionary = {}
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			if board.grid.has_flag(c, CombatGrid.DIFFICULT) and _floor_of(board, c) and not _blocked(board, c):
				diff[c] = true
	if diff.is_empty():
		return 0
	var rubble := Look.cel_textured(surface_for(board))
	if rubble == null:
		return 0
	# The floors round the run: each square within one of a difficult square that is walkable and has a textured floor
	# box. The most used three are the patch's room floors; squares with any other are left out.
	var ring: Dictionary = {}
	var uses: Dictionary = {}
	for c: Vector2i in diff:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dz)
				if diff.has(n) or ring.has(n) or not grid.in_bounds(n) or not _floor_of(board, n) or _blocked(board, n):
					continue
				var m := _material_of(board, n)
				if m == null:
					continue
				ring[n] = m
				uses[m] = int(uses.get(m, 0)) + 1
	var order: Array = uses.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return int(uses[a]) > int(uses[b]))
	var slots: Array[ShaderMaterial] = [rubble]
	for m: Variant in order:
		if slots.size() < Look.BLEND_SLOTS:
			slots.append(m as ShaderMaterial)
	if slots.size() < 2:
		return 0
	var img := Image.create(grid.width, grid.depth, false, Image.FORMAT_RGBA8)
	var covered: Array[Vector2i] = []
	for c: Vector2i in diff:
		img.set_pixel(c.x, c.y, Color(1.0, 0.0, 0.0, 0.0))
		covered.append(c)
	for n: Vector2i in ring:
		var slot := slots.find(ring[n])
		if slot < 1:
			continue
		img.set_pixel(n.x, n.y, Color(1.0 if slot == 0 else 0.0, 1.0 if slot == 1 else 0.0, 1.0 if slot == 2 else 0.0, 1.0 if slot == 3 else 0.0))
		covered.append(n)
	var blend := Look.blend_ground(slots, ImageTexture.create_from_image(img), Vector2(grid.width, grid.depth), Vector4(1, 0, 0, 0))
	blend.set_shader_parameter("edge_noise", EDGE_NOISE)   # a patch's edge wanders more than the open ground's
	blend.set_shader_parameter("spill", SPILL)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	for c: Vector2i in covered:
		var box := board.floor_box(c)
		var mi := MeshInstance3D.new()
		mi.name = "FloorPatch"
		mi.mesh = plane
		mi.material_override = blend
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, (box.mesh as BoxMesh).size.y / 2.0 + LIFT, 0.0)
		mi.set_meta("floor_patch", c)
		box.add_child(mi)
	return covered.size()


## The surface a board's difficult floor is: its place look's `difficult`, else its theme's (a dungeon's mud), else
## packed earth (an interior's debris, a yard's mud).
static func surface_for(board: ArenaBoard) -> String:
	var s := str(board._look.get("difficult", ""))
	if s == "":
		s = Look.theme_surface(board._surface_theme(), "difficult")
	if s == "":
		s = "village/mud_road" if board.theme == "shrine_yard" else DEFAULT_SURFACE
	return s


## Whether square `c` has a floor box the patch can lie on: flat, walked, at its own height.
static func _floor_of(board: ArenaBoard, c: Vector2i) -> bool:
	return board.floor_box(c) != null and board.floor_box(c).mesh is BoxMesh and not board.grid.has_flag(c, CombatGrid.NATURAL)


## Whether square `c` is no floor to walk on: a wall, deep water or the void.
static func _blocked(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.has_flag(c, CombatGrid.WALL | CombatGrid.WATER | CombatGrid.VOID)


## The textured material of square `c`'s floor box, or null where it is a plain colour (the blend needs a texture).
static func _material_of(board: ArenaBoard, c: Vector2i) -> ShaderMaterial:
	var m := board.floor_box(c).material_override as ShaderMaterial
	return m if m != null and str(m.get_meta("surface", "")) != "" else null
