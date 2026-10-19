extends Node3D
## make capture SCENE=res://tools/capture/hud_size_capture.tscn NAME=hud_size/shot FRAMES=10 [ARGS="--size=1280x720"]
## The combat HUD's party frames, turn order and combat log in a fight of four heroes and eight zombies (owner,
## 2026-10-19: smaller portraits and turn order, the saves list of an area spell under the combat log): the fight at its
## first turn (<out>_1_idle.png), the wizard's Fireball aimed with the log compact (<out>_2_fireball.png) and with it
## grown tall (<out>_3_fireball_tall_log.png), then the log minimized (<out>_4_fireball_log_minimized.png) and the order
## on a foe's turn (<out>_5_foe_turn.png) and with long foe names (<out>_6_long_name.png), so the sizes can be shown before and after.

const POINTER := Vector2(10.5, 5.5)

var e: Encounter
var view: CombatView
var rig: CameraRig
var wizard: Combatant
var heroes: Array[Combatant] = []
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array = []
	for z in 12:
		rows.append("..................")
	e = TestCombat.encounter(rows)
	var ch := TestChars.custom("wizard", "human", 7)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["fireball"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	wizard = e.add(ch, &"party", Vector2i(2, 5))
	heroes.append(wizard)
	heroes.append(TestCombat.hero(e, "ilse_varga", Vector2i(3, 3), 6))
	heroes.append(TestCombat.hero(e, "godrick_pendlebrook", Vector2i(3, 7), 6))
	heroes.append(TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4), 6))
	for cell: Vector2i in [Vector2i(8, 3), Vector2i(11, 4), Vector2i(12, 7), Vector2i(10, 8), Vector2i(13, 5), Vector2i(9, 6), Vector2i(11, 6), Vector2i(12, 2)]:
		TestCombat.foe(e, "zombie", cell)
	TestCombat.start_with(e, wizard)
	# What the frames and the order show: a hurt hero, a condition, an effect icon and a few log lines.
	heroes[1].creature.take_damage(14, &"slashing")
	heroes[2].creature.add_condition(&"poisoned", "capture")
	heroes[1].creature.add_effect(Effect.new("Ray of Frost", &"spell", "ray_of_frost").with_modifier("speed", {"value": -10}))
	e.log.add("turn", "Round 1: %s" % wizard.name(), wizard.id)
	e.log.add("hit", "Ilse Varga hits the zombie with her Greatsword for 11 damage.", heroes[1].id)
	e.log.add("miss", "The zombie misses Godrick Pendlebrook.", "")
	e.log.add("spell", "Tamsin Tealeaf casts Cure Wounds on Ilse Varga.", heroes[3].id)
	e.log.add("heal", "Ilse Varga regains 9 Hit Points.", heroes[1].id)
	e.log.add("warn", "The zombie is still on its feet.", "")
	e.log.add("turn", "%s's turn" % wizard.name(), wizard.id)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 18.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_focus = Node3D.new()
	add_child(_focus)
	_focus.position = Vector3(POINTER.x - 3.0, 0, POINTER.y + 2.5)
	rig.follow = _focus
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	view.hud.shown = wizard
	view.hud.refresh()
	view.hud.refresh_log()
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_1_idle.png" % out)
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	view.mode = CombatView.Mode.IDLE
	var a := view.catalog.find(wizard, "spell:fireball")
	if a.is_empty() or not bool(a["legal"]):
		push_warning("hud_size_capture: Fireball can't be cast (%s)" % str(a.get("reason", "not known")))
		return
	view._choose(a)
	view.using_pad = true
	view.hover_token = null
	view.hover_world = Vector3(POINTER.x, 0.0, POINTER.y)
	view.hover_cell = Vector2i(floori(POINTER.x), floori(POINTER.y))
	view._update_hover()
	view.overlay.show_cells("goal", [view.hover_cell])
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_2_fireball.png" % out)
	view.hud.grow_log()
	view._update_hover()
	await tool.call("wait_frames", 10)
	tool.call("_shot", "%s_3_fireball_tall_log.png" % out)
	view.hud.grow_log()
	view.hud.toggle_log()
	view._update_hover()
	await tool.call("wait_frames", 10)
	tool.call("_shot", "%s_4_fireball_log_minimized.png" % out)
	view.hud.toggle_log()
	view._cancel_targeting()
	view.overlay.clear_all()
	view.hud.hide_area_saves()
	view.hud.hide_tooltip()
	# A foe's turn: the order's highlighted card is a zombie's.
	for i in e.order.size():
		if e.order[i].side == &"enemy":
			e.turn_index = i
			break
	e._begin_turn()
	view.hud.refresh()
	await tool.call("wait_frames", 40)
	tool.call("_shot", "%s_5_foe_turn.png" % out)
	# A foe with a long name: its card is cut with an ellipsis (<out>_6_long_name.png).
	var foes: Array = e.order.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	(foes[0] as Combatant).creature.name = "Strahd von Zarovich"
	(foes[2] as Combatant).creature.name = "The Very Long-Named Zombie Lord"
	view.hud.refresh()
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_6_long_name.png" % out)
