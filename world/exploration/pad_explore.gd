class_name PadExplore
extends RefCounted
## Exploring on a pad (U6, docs/ui/controller.md), for world/game_root.gd. The left stick walks (game_root reads it)
## and the right stick turns and zooms the camera (CameraRig.pad_look). The nearest thing the party can use is marked,
## as the mouse's hover marks it (its glow and hint): D-pad left and right mark the next thing round the leader, A uses
## it (walking there first, as a click does), Y opens everything that can be done with it, X searches. LB/RB change
## who leads, L3 sneaks, R3 explores turn-based and RT ends its round, LT held shows names and what foes see, D-pad up
## steps into the HUD's bar for the rest, D-pad down shows the controls, B closes them and the Narrator, Back opens the
## map and Start the menu.

## How far a thing may be from the leader to be marked, in squares.
const REACH := 8
## Seconds between looks round for the nearest thing while walking.
const REFRESH := 0.2

var root: Node
## The square marked (-1, -1 for none), and whether the player chose it (then it stays until out of reach).
var marked := Vector2i(-1, -1)
var chosen := false
var _t := 0.0
var _rt_down := false


func _init(root_: Node) -> void:
	root = root_


func _view() -> LocationView:
	return root.get("view") as LocationView


func _hud() -> ExploreHud:
	return root.get("hud") as ExploreHud


## A pad event while exploring. True when it's the pad's (every pad event is, so the keyboard's code never reads one).
func handle(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	var view := _view()
	var hud := _hud()
	if event is InputEventJoypadMotion:
		var rt := event.is_action(&"plan_round") and event.get_action_strength(&"plan_round") >= 0.5
		if rt and not _rt_down and view.planning:
			root.call("_command", "plan_round")
		if event.is_action(&"plan_round"):
			_rt_down = rt
		return true
	if not (event as InputEventJoypadButton).pressed:
		return true
	if event.is_action_pressed(&"ui_cancel"):
		if hud.controls_showing():
			hud.toggle_controls()
		elif hud.narration_showing():
			hud.close_narration()
	elif event.is_action_pressed(&"use_marked"):
		use()
	elif event.is_action_pressed(&"marked_menu"):
		menu()
	elif event.is_action_pressed(&"mark_prev") or event.is_action_pressed(&"mark_next"):
		cycle(-1 if event.is_action_pressed(&"mark_prev") else 1)
	elif event.is_action_pressed(&"search"):
		root.call("_command", "search")
	elif event.is_action_pressed(&"leader_prev") or event.is_action_pressed(&"leader_next"):
		rotate_leader(-1 if event.is_action_pressed(&"leader_prev") else 1)
	elif event.is_action_pressed(&"sneak"):
		root.call("_command", "sneak")
	elif event.is_action_pressed(&"plan_mode"):
		root.call("_command", "plan")
	elif event.is_action_pressed(&"open_map"):
		root.call("open_travel", false)
	elif event.is_action_pressed(&"pause_menu"):
		root.call("open_screen", "menu", 0)
	elif event.is_action_pressed(&"hud_bar"):
		hud.pad_bar(true)
	elif event.is_action_pressed(&"show_controls"):
		hud.toggle_controls()
	return true


## LB/RB: who leads goes round the party in its order, RB the next and LB the one before (Tab's swap only trades the
## first two).
func rotate_leader(step: int) -> void:
	var view := _view()
	var n := view.members.size()
	if n < 2 or view.in_combat:
		return
	if step < 0:
		view.set_leader(n - 1)   # the last leads, the rest keep their order behind
	else:
		view.set_leader(1)
		# The one who led goes to the back, so the order goes round.
		view.members.append(view.members.pop_at(1))
		view.st.party.append(view.st.party.pop_at(1))
	root.call("_refresh")


## Keeps the mark on the nearest thing as the party walks (a thing the player chose stays while it's in reach).
func tick(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH
	var view := _view()
	if view == null or view.members.is_empty() or view.busy:
		return
	var list := things()
	if marked.x >= 0 and not marked in list:
		marked = Vector2i(-1, -1)
		chosen = false
	if not chosen:
		var best := Vector2i(-1, -1)
		var d := INF
		var at := view.leader().cell
		for c: Vector2i in list:
			var dc := Vector2(c - at).length()
			if dc < d:
				d = dc
				best = c
		marked = best
	show_mark()


## The squares within REACH of the leader with something on them the party can use (people, doors, chests, things,
## ways out, foes in sight), not the party itself.
func things() -> Array[Vector2i]:
	var view := _view()
	var out: Array[Vector2i] = []
	var at := view.leader().cell
	var party := {}
	for m: Combatant in view.members + view.guest_members:
		party[m.cell] = true
	for entry: Array in view._pickables():
		var c := entry[1] as Vector2i
		if party.has(c) or c in out or Vector2(c - at).length() > REACH:
			continue
		if not view.thing_at(c).is_empty():
			out.append(c)
	return out


## D-pad left/right: the next thing round the leader, counter-clockwise or clockwise as the screen shows them.
func cycle(step: int) -> void:
	var view := _view()
	var list := things()
	if list.is_empty():
		_hud().toast("Nothing to use nearby")
		return
	var cam := view.rig.camera
	var centre := cam.unproject_position(view.board.cell_center(view.leader().cell))
	var angle := func(c: Vector2i) -> float:
		var p := cam.unproject_position(view.board.cell_center(c)) - centre
		return fposmod(atan2(p.y, p.x), TAU)
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(angle.call(a)) < float(angle.call(b)))
	var i := list.find(marked)
	marked = list[posmod(i + step, list.size()) if i >= 0 else (0 if step > 0 else list.size() - 1)]
	chosen = true
	Audio.sfx("hover", 0.08)
	show_mark()


## The mark's glow, and its hint beside it (what A will do).
func show_mark() -> void:
	var view := _view()
	var glow := root.get("glow") as HoverGlow
	if marked.x < 0:
		glow.clear()
		_hud().hint("", Vector2.ZERO)
		PadPrompts.world = [["dpad_horizontal", "Mark"], ["x", "Search"], ["dpad_up", "Menu bar"]]
		return
	var thing := view.thing_at(marked)
	glow.show(view, marked, thing)
	var at := view.rig.camera.unproject_position(view.board.cell_center(marked) + Vector3(0, 0.6, 0))
	_hud().hint(str(thing.get("label", "")), at)
	PadPrompts.world = [["a", "Use"], ["y", "Options"], ["dpad_horizontal", "Mark"], ["x", "Search"],
		["dpad_up", "Menu bar"]]


## A: use the marked thing, walking there first as a click does.
func use() -> void:
	if marked.x < 0:
		_hud().toast("Nothing to use here")
		return
	_view().click(marked)


## Y: everything that can be done with the marked thing, beside it.
func menu() -> void:
	if marked.x < 0:
		_hud().toast("Nothing to use here")
		return
	var at := _view().rig.camera.unproject_position(_view().board.cell_center(marked) + Vector3(0, 0.6, 0))
	root.call("open_world_menu", marked, at)


## The mark goes (the pad put down, a screen opened, a fight began).
func clear() -> void:
	marked = Vector2i(-1, -1)
	chosen = false
	PadPrompts.world = []
