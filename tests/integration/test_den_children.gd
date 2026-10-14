extends TestCase
## Owner report (2026-10-14): the text in Kiril's den says five children are held in the pen, but only Mirela showed.
## The pen holds all five (Mirela, Codruta, Little Petru and the twins Zamfir and Ioana) while they are held, and the
## aftermath square outside the pen shows them with her when the pack is gone.

const CHILDREN: Array[String] = ["mirela", "codruta", "krezk_petru", "zamfir", "ioana"]
const PEN_X := [2, 8]
const PEN_Y := [2, 6]

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "werewolf_den_caves"
	Dice.reseed(4)
	await _start_game()


func after_each() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()


func _start_game() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	for i in 30:
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			break
		d.call("_advance")
		await _frames(1)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func test_all_five_children_stand_in_the_pen() -> void:
	var cells := {}
	for id in CHILDREN:
		var tok := _view().npc_tokens.get(id, null) as CombatToken
		assert_true(tok != null, "%s has a figure in the pen" % id)
		if tok == null:
			continue
		var cell: Vector2i = _view().grid.cell_at(tok.position)
		assert_true(cell.x >= PEN_X[0] and cell.x <= PEN_X[1] and cell.y >= PEN_Y[0] and cell.y <= PEN_Y[1], "%s is inside the pen, at %s" % [id, cell])
		assert_false(cells.has(cell), "%s doesn't share a square with %s" % [id, cells.get(cell, "")])
		cells[cell] = id
	assert_eq(cells.size(), 5, "five different squares for five children")


func test_every_child_speaks_the_pen_conversation() -> void:
	var specs := 0
	for id in CHILDREN:
		for e: Dictionary in (Compendium.shared().get_entry("locations", "werewolf_den_caves")["npcs"] as Array):
			if str(e["npc"]) == id and str(e.get("dialogue", "")) == "werewolf_den/children:start":
				specs += 1
				break
	assert_eq(specs, 5, "each child's pen entry opens the children's conversation")


func test_the_children_leave_the_pen_when_freed() -> void:
	GameState.story.set_flag("den_children_freed", true)
	_view().refresh_npcs()
	await _frames(2)
	var in_pen := 0
	for id in CHILDREN:
		var tok := _view().npc_tokens.get(id, null) as CombatToken
		if tok != null and tok.visible:
			var cell: Vector2i = _view().grid.cell_at(tok.position)
			if cell.x >= PEN_X[0] and cell.x <= PEN_X[1] and cell.y >= PEN_Y[0] and cell.y <= PEN_Y[1]:
				in_pen += 1
	assert_eq(in_pen, 0, "freed children aren't left in the pen")
