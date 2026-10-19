extends TestCase
## The battle grid (Natural Maps plan N1, world/combat/battle_grid.gd): the Modern look draws its ground with no grid in
## it and lays thin lines over the land only while a fight (or the Battle grid setting) wants them: round the creature
## whose turn it is, whole in the tactical view, over walkable squares only, following the ground's slopes; Classic keeps
## its painted grid.

const ARENA := preload("res://scenes/combat/arena.tscn")


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameSettings.set_battle_grid("held")
	InputActions.ensure()


func after_each() -> void:
	Input.action_release(&"show_grid")
	Input.action_release(&"explore_grid")
	Look.set_style(Look.DEFAULT_STYLE, false)
	GameSettings.set_battle_grid("held")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	var waited := 0.0
	while waited < t:
		await get_tree().process_frame
		waited += get_process_delta_time()


## Waits out a fight's opening beat: the first turn, and the grid with it, wait for it.
func _opened(view: CombatView) -> void:
	var waited := 0.0
	while view._opening and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _frames(3)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


## The setting: a held key by default (Ashwin: the grid isn't needed in a fight, "maybe a button the player holds"), four
## choices, anything else is ignored.
func test_the_setting_defaults_to_a_held_key() -> void:
	GameSettings.set_value("battle_grid", null, false)
	assert_eq(GameSettings.battle_grid(), "held")
	GameSettings.set_battle_grid("never")
	assert_eq(GameSettings.battle_grid(), "never")
	GameSettings.set_battle_grid("sometimes")
	assert_eq(GameSettings.battle_grid(), "never", "a choice it doesn't have changes nothing")
	GameSettings.set_battle_grid("fights")
	assert_eq(GameSettings.battle_grid(), "fights")
	GameSettings.set_battle_grid("always")
	assert_eq(GameSettings.battle_grid(), "always")
	assert_true(InputMap.has_action(&"show_grid"), "the key to hold is an action")
	assert_true(InputActions.keys(&"show_grid")[0] != KEY_NONE, "with a key of its own")


## Modern: the ground's materials carry no grid, so exploring shows none on any map. Classic keeps the faint grid it
## paints (the look is frozen).
func test_modern_paints_no_grid_and_classic_keeps_its() -> void:
	Look.set_style("modern", false)
	var modern := Look.cel_textured("village/grass", 0.22)
	var painted: Variant = modern.get_shader_parameter("grid_strength")
	assert_true(painted == null or is_zero_approx(float(painted)), "no grid painted into Modern's grass")
	Look.set_style("classic", false)
	var classic := Look.cel_textured("village/grass", 0.22)
	assert_true(is_equal_approx(float(classic.get_shader_parameter("grid_strength")), 0.22), "Classic still paints its grid")
	GameSettings.set_battle_grid("always")
	Input.action_press(&"show_grid")
	assert_false(BattleGrid.auto_in_fights(), "and has no battle grid laid over it")
	assert_false(BattleGrid.auto_exploring())
	assert_false(BattleGrid.held(), "held or not")
	Input.action_release(&"show_grid")


## No board in the Modern look has a grid in any floor: a town, a wild map and a room carry no `grid_strength` (the old
## faint line round each square), where Classic's carry it.
func test_no_modern_ground_carries_a_painted_grid() -> void:
	Look.set_style("modern", false)
	for loc_id: String in ["village_of_barovia", "svalich_crossroads", "death_house_ground"]:
		var v := _view(loc_id)
		await _frames(2)
		var checked := 0
		for n in v.board.get_children():
			var m := (n as MeshInstance3D).material_override as ShaderMaterial if n is MeshInstance3D else null
			if m == null:
				continue
			var painted: Variant = m.get_shader_parameter("grid_strength")
			assert_true(painted == null or is_zero_approx(float(painted)), "%s: %s paints no grid" % [loc_id, n.name])
			checked += 1
		assert_true(checked > 10, "%s: floors to look at (%d)" % [loc_id, checked])
		v.queue_free()
		await _frames(1)


## Lines go over the squares a creature can stand beside: never a wall, a tree, water or the void, nor a hidden room.
func test_lines_skip_walls_water_and_hidden_squares() -> void:
	Look.set_style("modern", false)
	var v := _view("lake_zarovich")
	await _frames(2)
	var board := v.board
	var drawn := BattleGrid.cells(board)
	var seen := {}
	for c in drawn:
		seen[c] = true
	var saw_water := false
	var saw_wall := false
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			var blocked := v.grid.flags(c) & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)
			saw_water = saw_water or v.grid.has_flag(c, CombatGrid.WATER)
			saw_wall = saw_wall or v.grid.has_flag(c, CombatGrid.WALL)
			assert_eq(seen.has(c), blocked == 0, "%s: a line only where a creature can stand" % c)
	assert_true(saw_water and saw_wall, "the lake has water and walls to skip")
	var hide := Vector2i(drawn[0])
	assert_false(BattleGrid.cells(board, {hide: true}).has(hide), "a hidden room's square gets none")
	# The patches' corners never leave those squares.
	var mesh := BattleGrid.patches(board, drawn)
	var verts := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	assert_true(verts.size() >= drawn.size() * 4, "a patch for every square")
	for p in verts:
		var near := false
		for dz in range(-1, 1):
			for dx in range(-1, 1):
				near = near or seen.has(Vector2i(roundi(p.x) + dx, roundi(p.z) + dz))
		assert_true(near, "%s lies on a drawn square" % p)
	v.queue_free()


## On natural ground a patch lies along the ground as it is drawn: Yester Hill's slopes, corner by corner, a little above.
func test_lines_follow_the_slope_of_natural_ground() -> void:
	Look.set_style("modern", false)
	var v := _view("yester_hill")
	await _frames(2)
	var board := v.board
	assert_true(board.has_terrain(), "Yester Hill has natural ground")
	var sloped := Vector2i(-1, -1)
	for c in BattleGrid.cells(board):
		if v.grid.has_flag(c, CombatGrid.NATURAL):
			var hs: Array[float] = []
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				hs.append(board.corner_height(c, k))
			if maxf(maxf(hs[0], hs[1]), maxf(hs[2], hs[3])) - minf(minf(hs[0], hs[1]), minf(hs[2], hs[3])) > 0.2:
				sloped = c
				break
	assert_true(sloped.x >= 0, "a sloping square to look at")
	if sloped.x < 0:
		v.queue_free()
		return
	var mesh := BattleGrid.patches(board, [sloped] as Array[Vector2i])
	var verts := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	assert_eq(verts.size(), 5, "four corners and the middle")
	var lo := INF
	var hi := -INF
	for p in verts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		var under := board.ground_y(Vector2(clampf(p.x, sloped.x + 0.001, sloped.x + 0.999), clampf(p.z, sloped.y + 0.001, sloped.y + 0.999)))
		assert_between(p.y - under, BattleGrid.LIFT, 0.08, "%s lies just above the ground (%.3f)" % [p, p.y - under])
	assert_true(hi - lo > 0.15, "and slopes with it (%.2f)" % (hi - lo))
	v.queue_free()


## A fight shows no grid until the key is held; held, the lines gather round whoever's turn it is, and go when it is let
## go of or the fight is over. In fights, the setting shows them on its own.
func test_a_held_key_lays_the_grid_round_whose_turn_it_is() -> void:
	Look.set_style("modern", false)
	var arena := ARENA.instantiate() as Node3D
	add_child(arena)
	await _frames(5)
	var view := arena.get("view") as CombatView
	var lines := view.overlay.lines
	assert_false(lines.visible, "no grid in the opening beat")
	await _opened(view)
	assert_false(lines.is_wanted(), "no grid in a fight by default")
	assert_false(lines.visible, "none drawn")
	Input.action_press(&"show_grid")
	await _frames(3)
	assert_true(lines.is_wanted(), "the grid is wanted while the key is held")
	assert_true(lines.mesh != null and lines.visible, "and drawn")
	assert_true(lines.drawn_cells().size() > 20, "over the board's squares")
	await _seconds(0.5)
	assert_eq(lines.shown(), 1.0, "faded all the way in")
	var now := view.e.current()
	assert_true(lines.follow == view.tokens[now.id], "round the creature whose turn it is")
	var other: Combatant = null
	for c in view.e.combatants:
		if c != now and c.is_alive() and view.tokens.has(c.id) and (view.tokens[c.id] as CombatToken).visible:
			other = c
			break
	assert_true(other != null, "someone else to take the turn")
	if other != null:
		view.call("_gather_grid", other)
		assert_true(lines.follow == view.tokens[other.id], "and on to the next")
		var speedy := float(other.speed()) / float(CombatGrid.FEET) + 2.0
		assert_eq(lines.reach, clampf(speedy, BattleGrid.REACH_LEAST, BattleGrid.REACH_MOST), "as far as it can move")
	# The tactical view shows the whole map: the reach goes out as the camera does.
	var mat := lines.material_override as ShaderMaterial
	assert_true(float(mat.get_shader_parameter("reach_out")) < 20.0, "round the creature in play")
	view.rig.tactical = true
	view.rig.tactical_shown = 1.0
	await _frames(2)
	assert_true(float(mat.get_shader_parameter("reach_out")) > 100.0, "the whole map from the tactical view")
	view.rig.tactical = false
	view.rig.tactical_shown = 0.0
	# Let go, and it fades out.
	Input.action_release(&"show_grid")
	await _frames(3)
	assert_false(lines.is_wanted(), "gone when the key is let go")
	await _seconds(0.5)
	assert_false(lines.visible, "and not drawn")
	# In fights: on its own, and a fight that is over takes it away even with the key held.
	GameSettings.set_battle_grid("fights")
	view.call("_gather_grid", now)
	await _frames(3)
	assert_true(lines.is_wanted(), "In fights: the grid shows on its own")
	view.close_softly()
	await _frames(3)
	assert_false(lines.is_wanted(), "gone with the fight")
	Input.action_press(&"show_grid")
	await _frames(3)
	assert_false(lines.is_wanted(), "held or not")
	arena.queue_free()
	await _frames(1)


## Never: not even held. And the Classic look has none to lay.
func test_never_and_classic_show_no_grid_held() -> void:
	Look.set_style("modern", false)
	GameSettings.set_battle_grid("never")
	var arena := ARENA.instantiate() as Node3D
	add_child(arena)
	await _frames(5)
	var view := arena.get("view") as CombatView
	await _opened(view)
	Input.action_press(&"show_grid")
	await _frames(3)
	assert_false(view.overlay.lines.is_wanted(), "never means never")
	assert_false(view.overlay.lines.visible)
	arena.queue_free()
	await _frames(1)
	GameSettings.set_battle_grid("fights")
	Look.set_style("classic", false)
	arena = ARENA.instantiate() as Node3D
	add_child(arena)
	await _frames(5)
	view = arena.get("view") as CombatView
	await _opened(view)
	await _frames(3)
	assert_false(view.overlay.lines.is_wanted(), "Classic keeps the grid painted in its ground")
	arena.queue_free()
	await _frames(1)


## Exploring shows nothing by default; the held key lays the grid round the party's leader, "Always" keeps it there, and
## a fight has its own.
func test_exploring_shows_the_grid_only_when_asked() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	await _frames(3)
	var explore := v.get_node("ExploreGrid") as ExploreGrid
	assert_false(explore.lines.is_wanted(), "no grid on the open road")
	assert_false(explore.lines.visible)
	Input.action_press(&"show_grid")
	await _frames(3)
	assert_true(explore.lines.is_wanted(), "held: round the party")
	assert_true(explore.lines.follow == v.tokens[v.leader().id], "round its leader")
	assert_true(explore.lines.visible and explore.lines.mesh != null)
	Input.action_release(&"show_grid")
	await _frames(3)
	assert_false(explore.lines.is_wanted(), "let go")
	# The controller: the names trigger, held, shows it too (it moves with the names).
	assert_true(InputMap.has_action(&"explore_grid"), "the controller has an action for it")
	Input.action_press(&"explore_grid")
	await _frames(3)
	assert_true(explore.lines.is_wanted(), "the names trigger held: round the party")
	Input.action_release(&"explore_grid")
	await _frames(3)
	assert_false(explore.lines.is_wanted())
	GameSettings.set_battle_grid("always")
	await _frames(3)
	assert_true(explore.lines.is_wanted(), "Always: on its own")
	GameSettings.set_battle_grid("held")
	await _frames(3)
	assert_false(explore.lines.is_wanted(), "back to none")
	await _seconds(0.6)
	assert_false(explore.lines.visible, "and faded out")
	v.queue_free()
