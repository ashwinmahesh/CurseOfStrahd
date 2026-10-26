extends Node3D
## make capture SCENE=res://tools/capture/shapeshift_capture.tscn NAME=shapeshift/shot FRAMES=10
## A creature changing shape (owner ask, 2026-10-14: a visible effect on the sprite and a sound for every shapeshifter): a
## filmstrip of Emil becoming the werewolf (<out>_emil_<n>.png, one shot every FRAME_STEP frames from the moment he starts
## to change), Emil's wolf, Lysaga's swarm and Morgantha's disguise too, the same for Strahd's bat (<out>_bat_<n>.png), a Druid's Wild Shape (<out>_wild_<n>.png) and Strahd's mist
## (<out>_mist_<n>.png), and each changing back (<out>_<name>_back_<n>.png). tools/capture/apng.py joins a strip.

const FRAME_STEP := 4
const STRIP := 12

var e: Encounter
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var emil: Combatant
var strahd: Combatant
var hedda: Combatant
var lysaga: Combatant
var hag: Combatant
var pack_wolf: Combatant
var pack_raven: Combatant
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://addons/dnd_core/world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array = []
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	emil = e.add(StoryState.make_guest("emil_toranescu"), &"guest", Vector2i(4, 6))
	hedda = TestCombat.hero(e, "hedda_ironvow", Vector2i(8, 6))
	strahd = TestCombat.foe(e, "strahd_von_zarovich", Vector2i(12, 6))
	lysaga = TestCombat.foe(e, "baba_lysaga", Vector2i(12, 9))
	hag = TestCombat.foe(e, "night_hag", Vector2i(8, 9))
	hag.creature.name = "Morgantha"
	pack_wolf = TestCombat.foe(e, "werewolf", Vector2i(14, 3))
	pack_raven = TestCombat.foe(e, "wereraven", Vector2i(14, 9))
	TestCombat.start_with(e, emil)
	board = ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 6.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_focus = Node3D.new()
	add_child(_focus)


func _look(c: Combatant) -> void:
	_focus.position = board.cell_center(c.cell, c.size_cells)
	rig.follow = _focus
	rig.snap_to_target()


func _names(on: bool) -> void:
	for id: String in view.tokens:
		var tok := view.tokens[id] as CombatToken
		if is_instance_valid(tok):
			tok._label.visible = on


## The change plays (the events are drained and shown) while a shot is taken every FRAME_STEP frames.
func _strip(tool: Node, out: String, name: String, who: Combatant) -> void:
	_look(who)
	await tool.call("wait_frames", 12)
	view.call_deferred("_play_events")
	for i in STRIP:
		await tool.call("wait_frames", FRAME_STEP if i > 0 else 1)
		tool.call("_shot", "%s_%s_%02d.png" % [out, name, i])
	await tool.call("wait_frames", 30)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)   # the opening beat
	view.hud.hide_tooltip()
	_names(false)
	_look(emil)
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_0_before.png" % out)
	assert(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	await _strip(tool, out, "emil", emil)
	emil.bonus_available = true
	assert(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	await _strip(tool, out, "emil_back", emil)
	e.legendary._set_form(strahd, "bat")
	await _strip(tool, out, "bat", strahd)
	e.legendary._set_form(strahd, e.legendary.base_form(strahd))
	await _strip(tool, out, "bat_back", strahd)
	e.legendary._set_form(strahd, "mist")
	await _strip(tool, out, "mist", strahd)
	e.legendary._set_form(strahd, e.legendary.base_form(strahd))
	await _strip(tool, out, "mist_back", strahd)
	var wolf: Dictionary = ShapeChange.beast_forms(1.0).filter(func(d: Dictionary) -> bool: return str(d["id"]) == "wolf")[0]
	e.shapes.transform(hedda, wolf, {"temp_hp": 5, "label": "Wild Shape", "keep_mind": true})
	await _strip(tool, out, "wild", hedda)
	e.shapes.revert(hedda, "capture")
	await _strip(tool, out, "wild_back", hedda)
	# The forms of the forms branch: Emil's wolf, Lysaga's swarm and Morgantha's disguise, each and back.
	emil.bonus_available = true
	e.monster_actions.shift(emil, "wolf")
	await _strip(tool, out, "wolf", emil)
	e.monster_actions.shift(emil)
	await _strip(tool, out, "wolf_back", emil)
	e.legendary._set_form(lysaga, "swarm")
	await _strip(tool, out, "swarm", lysaga)
	e.legendary._set_form(lysaga, e.legendary.base_form(lysaga))
	await _strip(tool, out, "swarm_back", lysaga)
	e.legendary._set_form(hag, "disguise")
	await _strip(tool, out, "disguise", hag)
	# Foes that walk in as people (human_art) and change on their first turn.
	e.monster_actions.shift(pack_wolf)
	await _strip(tool, out, "packwolf", pack_wolf)
	e.monster_actions.shift(pack_raven)
	await _strip(tool, out, "packraven", pack_raven)
