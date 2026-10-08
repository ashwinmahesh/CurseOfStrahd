class_name GroundView
extends Node3D
## Draws what lies on the battlefield (combat/ground_items.gd): each pile as its item's icon lying flat on the floor,
## tucked into a corner of its square so a creature standing there doesn't hide it, with a soft ring to find it by;
## a monster's weapon that isn't an item is a plain blade. It only shows state: `sync()` matches the nodes to the
## encounter's piles (CombatView calls it beside FieldView's).

## The icon's width in world units (a square is 1).
const SIDE := 0.4
## Where on its square each pile lies, by its place among the piles there.
const CORNERS: Array[Vector2] = [Vector2(0.24, 0.24), Vector2(-0.24, 0.24), Vector2(0.24, -0.24), Vector2(-0.24, -0.24)]

var board: ArenaBoard
var _nodes: Dictionary = {}   ## pile id -> Node3D


static func create(board_: ArenaBoard) -> GroundView:
	var v := GroundView.new()
	v.name = "GroundView"
	v.board = board_
	return v


## Matches what's drawn to `piles` (GroundItems.items).
func sync(piles: Array) -> void:
	var live := {}
	var taken := {}   ## cell -> piles placed there so far
	for p: Variant in piles:
		var g := p as Dictionary
		var gid := str(g["gid"])
		var cell := g["cell"] as Vector2i
		live[gid] = true
		var n := _nodes.get(gid) as Node3D
		if n == null:
			n = _make(g)
			add_child(n)
			_nodes[gid] = n
		var k := int(taken.get(cell, 0))
		taken[cell] = k + 1
		n.position = _spot(cell, k)
	for gid: String in _nodes.keys():
		if not live.has(gid):
			(_nodes[gid] as Node3D).queue_free()
			_nodes.erase(gid)


func node_for(gid: String) -> Node3D:
	return _nodes.get(gid) as Node3D


func _spot(cell: Vector2i, k: int) -> Vector3:
	var off := CORNERS[k % CORNERS.size()]
	var y := board.ground_y(Vector2(cell.x + 0.5 + off.x, cell.y + 0.5 + off.y)) + 0.02   # (natural ground's slope)
	if board.grid.has_flag(cell, CombatGrid.LOW):
		y += ArenaBoard.LOW_H
	return Vector3(cell.x + 0.5 + off.x, y, cell.y + 0.5 + off.y)


func _make(g: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Ground_%s" % (str(g["item_id"]) if str(g["item_id"]) != "" else "weapon")
	# A faint ring under it, so the pile reads on any floor.
	var ring := TorusMesh.new()
	ring.inner_radius = SIDE * 0.5
	ring.outer_radius = SIDE * 0.58
	_part(root, ring, Vector3.ZERO, _glow("candle", 0.45))
	var tex: Texture2D = null
	if str(g["item_id"]) != "":
		tex = Icons.item(str(g["item_id"]))
	if tex != null:
		var sp := Sprite3D.new()
		sp.texture = tex
		sp.pixel_size = SIDE / maxf(1.0, float(tex.get_width()))
		sp.rotation_degrees = Vector3(-90, 0, 0)   # flat on the floor, facing up
		sp.position.y = 0.01
		sp.shaded = false
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sp)
		return root
	# No icon: a plain blade lying aslant on the square.
	var lie := Node3D.new()
	lie.rotation_degrees.y = 35.0
	root.add_child(lie)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.06, 0.02, 0.42)
	_part(lie, blade, Vector3(0, 0.02, 0.04), Look.cel("pewter"))
	var guard := BoxMesh.new()
	guard.size = Vector3(0.18, 0.03, 0.04)
	_part(lie, guard, Vector3(0, 0.025, -0.17), Look.cel("umber"))
	return root


func _glow(colour: String, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(Look.color(colour), alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
