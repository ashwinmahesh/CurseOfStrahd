extends TestCase
## Aiming an area spell on the board draws the area's edge and paints no squares (owner, 2026-10-12: "for AoE spells,
## don't make the floor orange. Instead show a circular border which shows the area that would be affected").

const SCENE := preload("res://scenes/combat/arena.tscn")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_aiming_burning_hands_draws_its_edge_not_orange_squares() -> void:
	var arena := SCENE.instantiate() as Node3D
	add_child(arena)
	await _frames(5)
	var view := arena.get("view") as CombatView
	var e := view.e
	var wizard: Combatant = null
	for o in e.combatants:
		if o.side == &"party" and o.creature is Character and (o.creature as Character).class_level_of("wizard") > 0:
			wizard = o
	assert_true(wizard != null, "the arena's party has its wizard")
	if wizard == null:
		arena.queue_free()
		return
	for i in 40:
		if e.current() == wizard:
			break
		e.end_turn()
		await _frames(1)
	assert_eq(e.current(), wizard)
	var hands := view.catalog.find(wizard, "spell:burning_hands")
	assert_true(not hands.is_empty() and bool(hands["legal"]), "Burning Hands to aim")
	if hands.is_empty() or not bool(hands["legal"]):
		arena.queue_free()
		return
	view.set("mode", CombatView.Mode.IDLE)
	view.call("_choose", hands)
	view.set("using_pad", true)
	var aim := wizard.cell + Vector2i(3, 0)
	view.set("hover_world", view.board.cell_center(aim))
	view.set("hover_cell", aim)
	view.call("_update_hover")
	var area := view.overlay.get_node("Layer_area") as MultiMeshInstance3D
	assert_true(view.overlay.is_showing_outline(), "the cone's edge on the floor")
	assert_eq(area.multimesh.instance_count, 0, "and no squares painted under it")
	var line := view.overlay.get_node("AreaOutline") as MeshInstance3D
	assert_true(line.mesh != null and line.mesh.get_faces().size() > 0)
	view.call("_cancel_targeting")
	assert_false(view.overlay.is_showing_outline(), "gone when the aim is called off")
	view.set("mode", CombatView.Mode.IDLE)
	arena.queue_free()
	await _frames(1)
