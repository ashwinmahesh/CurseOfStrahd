class_name CombatView
extends Node3D
## Plays a fight on a board that's already built (plan §5.3, docs/ui/combat_view.md): the HUD, the player's clicks,
## keys and controller input turned into encounter commands, enemy turns through AiBrain, reaction prompts, and
## animation of the encounter's events. The arena scene and every explorable location use it; the Encounter runs
## the rules. Emits finished(outcome) when the player leaves the end-of-fight banner.

signal finished(outcome: String)
## A new round is about to begin (round 1 right after Initiative): the moment the game may save a fight.
signal round_started(round: int)
## Escape with nothing to cancel: the game opens its pause menu (the arena has none).
signal menu_requested
## The player asked for a party member's character sheet (their frame's portrait, or C for the one shown): the host
## opens it view only while the fight waits.
signal sheet_requested(who: Character)

## Seconds per square for a token moving on the board (owner 2026-10-06: half the old speed, it read unnaturally fast).
const STEP_TIME := 0.37   # seconds a square (owner 2026-10-07: about 30% slower than 0.26)
const AI_PAUSE := 0.35
## How long damage and healing numbers stay over a creature.
const FLOAT_TIME := 2.4
## The opening beat before the first turn (owner 2026-10-06: going into a fight felt abrupt): the camera takes in the
## field, the foes step into view, the HUD fades up and Initiative is rolled.
const INTRO_TIME := 1.5
## The part of the screen the combat HUD leaves clear, as the opening shot frames the fight: |x| up to .x, and y from
## .z (bottom) to .y (top), in -1..1 screen units.
const CLEAR_VIEW := Vector3(0.5, 0.55, -0.4)

enum Mode { BUSY, IDLE, TARGET, PROMPT, OVER }

var e: Encounter
var catalog: ActionCatalog
var board: ArenaBoard
var overlay: GridOverlay
var field: FieldView
## What lies on the ground (world/combat/ground_view.gd).
var ground_view: GroundView
## Spell and ability effects (world/combat/fx/spell_fx.gd).
var fx: SpellFx
## What enemies shout and creatures sound like (world/combat/combat_barks.gd).
var barks: CombatBarks
var rig: CameraRig
var hud: CombatHud
var tokens: Dictionary = {}
var mode: Mode = Mode.BUSY
## The arena offers R to fight again; in the story the end banner leads back to exploration.
var restart_allowed := false

var hover_cell := Vector2i(-1, -1)
var hover_world := Vector3.ZERO
var hover_token: CombatToken = null
var cursor_cell := Vector2i(4, 6)
var using_pad := false
var _pad_repeat := 0.0

var selected: Dictionary = {}
var picked: Array = []
var picked_points: Array[Vector2] = []
var slot_level := 0
var _reach: Dictionary = {}
var _target_cycle := 0
## Captures and scene tests turn off the mouse so a stray pointer can't act.
var input_locked := false
## The story's Narrator speaks rarely in combat (crits, falls, kills, victory; plan §5.7); none in the arena.
var narrator: Narrator = null
var story: StoryState = null
## The fight's opening beat is playing (begin): the first turn waits for it.
var _opening := false
## The camera's zoom before the opening shot pulled it out.
var _zoom_before := 13.0
## The view is fading out after the fight (close_softly): nothing more is played.
var _closed := false


## Starts showing `encounter` on `board_` with `rig_` and the creatures' `tokens_` (id -> CombatToken). Starts the
## encounter (rolling Initiative) unless it's already running.
func begin(encounter: Encounter, board_: ArenaBoard, rig_: CameraRig, tokens_: Dictionary, surprised: Array[String] = []) -> void:
	name = "CombatView"
	InputActions.ensure()   # the camera keys and the pad cursor, wherever the fight is shown from
	e = encounter
	board = board_
	rig = rig_
	tokens = tokens_
	catalog = ActionCatalog.new(e)
	overlay = GridOverlay.create(board)
	add_child(overlay)
	field = FieldView.create(board)
	add_child(field)
	ground_view = GroundView.create(board)
	add_child(ground_view)
	fx = SpellFx.new()
	add_child(fx)
	barks = CombatBarks.new()
	add_child(barks)
	hud = CombatHud.new()
	add_child(hud)
	hud.build(e, catalog)
	hud.action_chosen.connect(_choose)
	hud.end_turn_pressed.connect(_end_turn)
	hud.undo_move_pressed.connect(_undo_move)
	hud.reaction_answered.connect(_answer)
	hud.inspect_requested.connect(_inspect)
	hud.sheet_requested.connect(_sheet)
	hud.death_save_pressed.connect(_death_save)
	hud.slot_level_changed.connect(func(l: int) -> void:
		slot_level = l
		_update_hover())
	hud.radial_picked.connect(_radial)
	hud.cast_at_level.connect(func(action: Dictionary, level: int) -> void: _choose(action, level))
	hud.square_picked.connect(_square_picked)
	if e.state == Encounter.State.SETUP:
		if e.title != "":
			e.log.add("turn", e.title, "")
		if e.intro != "":
			e.log.add("narr", e.intro, "")
		e.start(surprised)
	# The opening beat: the camera takes in the field and the HUD fades up while Initiative is rolled; the first turn
	# waits for it. The rules are already running (round 1 saves itself as usual).
	var opened := Time.get_ticks_msec()
	_opening = true
	_frame_the_fight(rig.follow == null)
	LayerFade.fade(self, hud, true, 0.4, 0.2).finished.connect(func() -> void: hud.banner("Roll Initiative", INTRO_TIME))
	for c in e.combatants:
		if c.surprised:
			e.log.add("info", "%s is surprised: Disadvantage on Initiative" % c.name(), c.id)
	await _play_events()
	var left := INTRO_TIME - (Time.get_ticks_msec() - opened) / 1000.0
	if left > 0.0:
		await create_tween().tween_interval(left).finished
	if _closed:
		return
	_end_opening()
	_advance()


## The opening shot: the camera eases to the middle of everyone in the fight and pulls out until they all show in the
## part of the screen the HUD leaves clear, so the player sees what they're up against. `snap` puts it there at once
## (a scene that opens on the fight, like the arena). The first turn brings it back in (_end_opening).
func _frame_the_fight(snap: bool) -> void:
	_zoom_before = rig.distance
	var spots: Array[Vector3] = []
	for c in e.combatants:
		if c.is_alive() and tokens.has(c.id):
			spots.append(board.cell_center(c.cell, c.size_cells) + Vector3(0, 0.6, 0))
	if spots.is_empty():
		return
	if snap:
		rig.snap_to_target()   # settles the rig's heading first
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in spots:
		lo = lo.min(p)
		hi = hi.max(p)
	var mid := (lo + hi) / 2.0 - Vector3(0, 0.6, 0)
	var dist := rig.distance
	while dist < rig.zoom_max and not _all_in_view(spots, mid, dist):
		dist += 0.5
	dist = minf(dist, rig.zoom_max)
	rig.follow = null
	if snap:
		rig.global_position = mid
		rig.distance = dist
		return
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rig, "global_position", mid, 0.8)
	tw.tween_property(rig, "distance", dist, 0.8)


## Whether every point in `spots` would show in the screen's clear middle (inside the turn order, party list, log and
## hotbar) with the rig at `at`, `dist` away: the rig's camera worked out by hand, as it isn't there yet.
func _all_in_view(spots: Array[Vector3], at: Vector3, dist: float) -> bool:
	var pitch := deg_to_rad(CameraRig.PITCH_DEG)
	var turn := Basis(Vector3.UP, rig.rotation.y)
	var basis := turn * Basis(Vector3.RIGHT, pitch)
	var eye := at + turn * Vector3(0, -sin(pitch) * dist + 0.6, cos(pitch) * dist)
	var size := get_viewport().get_visible_rect().size
	var half_h := tan(deg_to_rad(rig.camera.fov) / 2.0)
	var half_w := half_h * size.x / maxf(1.0, size.y)
	for p in spots:
		var v := basis.inverse() * (p - eye)
		if v.z >= -0.1:
			return false
		var x := v.x / (-v.z * half_w)
		var y := v.y / (-v.z * half_h)
		if absf(x) > CLEAR_VIEW.x or y > CLEAR_VIEW.y or y < CLEAR_VIEW.z:
			return false
	return true


## The end of the opening beat: round 1 is announced and the camera eases back in to the zoom it had, on whoever acts
## first (_advance sets it following them).
func _end_opening() -> void:
	_opening = false
	if e.state == Encounter.State.ACTIVE:
		hud.banner("Round %d" % e.round_no, 1.0)
	create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).tween_property(rig, "distance", _zoom_before, 0.9)


## Removes the view's overlay and HUD (the board and tokens belong to the caller).
func close() -> void:
	queue_free()


## Ends the view without a snap (the story, after a fight): input stops at once, the floor marks go, the combat HUD
## fades out, then the view frees itself.
func close_softly() -> void:
	_closed = true
	input_locked = true
	mode = Mode.OVER
	overlay.clear_all()
	hud.hide_tooltip()
	LayerFade.fade(self, hud, false, 0.35).finished.connect(queue_free)


# --- Turn flow ------------------------------------------------------------------------------------

## Decides what happens next: a reaction prompt, an enemy turn, the player's turn, or the end.
func _advance() -> void:
	if _closed:
		return   # the story took the fight back (close_softly); a turn still in flight stops here
	_refresh_all()
	if e.state == Encounter.State.OVER:
		mode = Mode.OVER
		overlay.clear_all()
		hud.hide_tooltip()
		var tail := "R: fight again" if restart_allowed else "Space or A: continue"
		var head := e.legendary.end_title()
		if head == "":
			head = "Victory!" if e.outcome == "victory" else "The party has fallen"
		hud.banner(head + "\n" + tail, 600.0)
		return
	if e.pending != null:
		mode = Mode.PROMPT
		hud.show_prompt(e.pending)
		return
	var c := e.current()
	rig.follow = tokens[c.id] as Node3D
	if not c.is_player_controlled() or e.compelled(c):
		mode = Mode.BUSY
		overlay.clear_all()
		hud.hide_tooltip()
		await get_tree().create_timer(AI_PAUSE * GameSettings.combat_pace()).timeout
		if e.state != Encounter.State.ACTIVE or e.current() != c or e.pending != null:
			_advance()
			return
		var r := e.run_ai_turn()
		await _play_events()
		if r.is_paused():
			mode = Mode.PROMPT
			_refresh_all()
			hud.show_prompt(r.pending)
			return
		_advance()
		return
	mode = Mode.IDLE
	selected = {}
	picked = []
	picked_points = []
	hud.set_pips([], 0)
	_reach = catalog.move_reach(c) if c.can_act() else {}
	cursor_cell = c.cell
	_update_hover()


func _refresh_all() -> void:
	var cur := e.current()
	for id: String in tokens:
		var t := _tok(id)
		if t == null:
			continue
		t.mounted = e.mount_of(t.combatant) != null
		t.refresh()
		t.set_active(cur != null and t.combatant == cur and e.state == Encounter.State.ACTIVE)
	hud.refresh()
	_show_weapons()


## Spell objects and lingering areas on the field (Spiritual Weapon, Flaming Sphere, Spirit Guardians, Web...).
func _show_weapons() -> void:
	field.sync(e.spells.zones.objects)
	ground_view.sync(e.ground.items)


func _player() -> Combatant:
	var c := e.current()
	return c if c != null and c.is_player_controlled() and e.state == Encounter.State.ACTIVE else null


func _end_turn() -> void:
	var c := _player()
	if c == null or mode not in [Mode.IDLE, Mode.TARGET]:
		return
	if hud.confirm_open():
		hud.close_confirm()
	elif c.can_act() and c.action_available and not _confirmed_end:
		# Only an unused Action asks first; leftover movement never does (owner feedback 2026-10-06).
		_confirmed_end = true
		hud.confirm_end_turn("End turn with your Action unused?")
		return
	_confirmed_end = false
	mode = Mode.BUSY
	_cancel_targeting()
	var r := e.end_turn()
	if not r.ok:
		hud.banner(r.reason, 1.4)
	await _play_events()
	_advance()


var _confirmed_end := false


## Takes back the current creature's last move (the HUD's Undo move, or Ctrl+Z): it goes back with its movement.
func _undo_move() -> void:
	var c := _player()
	if c == null or mode not in [Mode.IDLE, Mode.TARGET]:
		return
	var r := e.undo_move(c)
	if not r.ok:
		hud.banner(r.reason, 1.6)
		return
	_cancel_targeting()
	mode = Mode.BUSY
	overlay.clear_all()
	await _play_events()
	_advance()


func _death_save() -> void:
	var c := _player()
	if c == null:
		return
	var r := e.death_save(c)
	await _play_events()
	_refresh_all()
	# Heroic Inspiration and the like can answer the roll (F6).
	if r.is_paused() or e.pending != null:
		mode = Mode.PROMPT
		hud.show_prompt(e.pending)


func _inspect(id: String) -> void:
	if id.begins_with("hover:"):
		var t := tokens.get(id.substr(6)) as CombatToken
		for k: String in tokens:
			(tokens[k] as CombatToken).set_highlight(tokens[k] == t)
		return
	var c := e.get_c(id)
	if c != null and c.is_player_controlled():
		hud.shown = c
		hud.refresh()


func _sheet(id: String) -> void:
	var c := e.get_c(id) if id != "" else hud.shown
	if c == null:
		for each in e.combatants:
			if each.side == &"party" and each.creature is Character:
				c = each
				break
	if c != null and c.creature is Character:
		sheet_requested.emit(c.creature as Character)


func _answer(use: bool, rule: String) -> void:
	if e.pending == null:
		return
	var req := e.pending
	var reactor := e.get_c(req.reactor_id)
	if reactor != null and rule != "ask":
		reactor.reaction_rules[req.kind] = rule
		e.log.add("info", "%s will %s %s from now on" % [reactor.name(), "always use" if rule == "auto" else "never use", req.title.trim_suffix("?").replace("Reaction: ", "")], reactor.id)
	mode = Mode.BUSY
	var r := e.answer_reaction(use)
	await _play_events()
	if r.is_paused():
		mode = Mode.PROMPT
		_refresh_all()
		hud.show_prompt(r.pending)
		return
	_advance()


# --- Choosing actions -----------------------------------------------------------------------------

## Starts an action from the hotbar; `level` picks the spell slot (0 = the lowest available).
func _choose(action: Dictionary, level: int = 0) -> void:
	var c := _player()
	if c == null or mode not in [Mode.IDLE, Mode.TARGET]:
		return
	if c != hud.shown:
		hud.shown = c
	if not bool(action["legal"]):
		hud.banner(str(action["reason"]), 1.4)
		return
	_cancel_targeting()
	slot_level = int(action.get("slot", 0))
	var levels: Array[int] = []
	if str(action["kind"]) in ["spell", "item_spell"]:
		levels = catalog.level_choices(c, action)
		if not levels.is_empty():
			slot_level = level if level in levels else levels[0]
	if str(action["targeting"]) == "none":
		_perform(action, [], Vector2.INF, Vector2.ZERO)
		return
	selected = action
	picked = []
	picked_points = []
	mode = Mode.TARGET
	if str(action["kind"]) in ["spell", "item_spell"]:
		hud.set_pips(levels, slot_level)
	_show_target_marks()
	_update_hover()


func _cancel_targeting() -> void:
	hud.hide_tooltip()
	selected = {}
	picked = []
	picked_points = []
	hud.set_pips([], 0)
	overlay.clear("target")
	overlay.clear("friendly")
	overlay.clear("area")
	if mode == Mode.TARGET:
		mode = Mode.IDLE


func _show_target_marks() -> void:
	var c := _player()
	var foes: Array = []
	var friends: Array = []
	if c == null or selected.is_empty() or str(selected["targeting"]) in ["point", "points", "direction"]:
		return
	if str(selected["targeting"]) == "dead":
		var dead: Array = []
		for o2 in e.combatants:
			if o2.creature.dead and catalog.target_why(c, selected, o2) == "":
				dead.append_array(o2.footprint())
		overlay.show_cells("friendly", dead)
		return
	for o in e.combatants:
		if not o.is_alive():
			continue
		if catalog.target_why(c, selected, o) == "":
			for cell in o.footprint():
				(foes if c.hostile_to(o) else friends).append(cell)
	overlay.show_cells("target", foes)
	overlay.show_cells("friendly", friends)


func _perform(action: Dictionary, targets: Array, point: Vector2, dir: Vector2) -> void:
	var c := _player()
	if c == null:
		return
	mode = Mode.BUSY
	overlay.clear_all()
	hud.hide_tooltip()
	var r := catalog.perform(c, action, targets, point, dir, slot_level)
	slot_level = 0
	selected = {}
	picked = []
	picked_points = []
	hud.set_pips([], 0)
	if not r.ok:
		hud.banner(r.reason, 1.6)
	await _play_events()
	if r.is_paused() or e.pending != null:
		mode = Mode.PROMPT
		_refresh_all()
		hud.show_prompt(e.pending)
		return
	_advance()


## A click (or A) on `cell` / the hovered token.
func _confirm_at() -> void:
	var c := _player()
	if c == null:
		return
	var t := _target_under()
	if mode == Mode.TARGET:
		_confirm_target(c, t)
		return
	if mode != Mode.IDLE:
		return
	if t != null and t.combatant != c:
		if c.hostile_to(t.combatant):
			var a := _default_attack(c, t.combatant)
			if a.is_empty():
				hud.banner("No attack can reach %s from here" % t.combatant.name(), 1.6)
				return
			_perform(a, [t.combatant], Vector2.INF, Vector2.ZERO)
		else:
			_inspect(t.combatant.id)
		return
	if hover_cell.x < 0 or hover_cell == c.cell:
		return
	var mp := catalog.move_preview(c, hover_cell, _reach)
	if not bool(mp["ok"]):
		hud.banner(str(mp["reason"]), 1.2)
		return
	mode = Mode.BUSY
	overlay.clear_all()
	hud.hide_tooltip()
	var r := e.move(c, hover_cell)
	if not r.ok:
		hud.banner(r.reason, 1.4)
	await _play_events()
	if r.is_paused() or e.pending != null:
		mode = Mode.PROMPT
		_refresh_all()
		hud.show_prompt(e.pending)
		return
	_advance()


## Right-click on a square on your turn: one menu with Move here and everything you could do to whoever is there.
var _menu_cell := Vector2i(-1, -1)
var _menu_items: Array[Dictionary] = []


func _open_square_menu(at: Vector2) -> bool:
	var c := _player()
	if c == null or e.current() != c:
		return false
	_pick_from_mouse(at)
	var t := _target_under()
	var cell := t.combatant.cell if t != null else hover_cell
	if cell.x < 0:
		return false
	_menu_cell = cell
	_menu_items = catalog.square_actions(c, cell, _reach)
	if _menu_items.is_empty():
		return false
	var o := e.occupant_at(cell)
	var shown: Array[Dictionary] = []
	for it in _menu_items:
		shown.append({"id": it["id"], "label": it["label"], "enabled": it.get("enabled", true), "why": it.get("why", "")})
	hud.hide_tooltip()
	hud.open_square_menu(o.name() if o != null else "This square", shown, at)
	return true


func _square_picked(id: String) -> void:
	var c := _player()
	if c == null or mode != Mode.IDLE:
		return
	var o := e.occupant_at(_menu_cell)
	if id == "move":
		hover_token = null
		hover_cell = _menu_cell
		_confirm_at()
		return
	if id == "info":
		if o != null and o.is_player_controlled():
			_inspect(o.id)
		elif o != null:
			hud.show_details(o.name(), ["HP %d/%d · AC %d" % [o.creature.hp, o.creature.max_hp(), o.creature.ac_value()], hud._chips(o)])
		return
	for it in _menu_items:
		# Picking something up needs no one standing there.
		if str(it["id"]) == id and it.has("action") and (o != null or str((it["action"] as Dictionary)["targeting"]) == "none"):
			_perform(it["action"] as Dictionary, [o] if o != null else [], Vector2.INF, Vector2.ZERO)
			return


func _confirm_target(c: Combatant, t: CombatToken) -> void:
	var kind := str(selected["targeting"])
	match kind:
		"points":
			if hover_cell.x < 0:
				return
			var point := Vector2(hover_cell) + Vector2(0.5, 0.5)
			if str(selected["kind"]) == "spell" and not point in picked_points:
				var check_opts := (selected.get("opts", {}) as Dictionary).duplicate()
				check_opts.erase("splintered")
				var check := e.spells._check_targets(c, Compendium.shared().spell_data(str(selected["spell_id"])), slot_level, [], point, check_opts)
				if str(check["why"]) != "":
					hud.banner(str(check["why"]), 1.4)
					return
			if point in picked_points:
				picked_points.erase(point)
			else:
				picked_points.append(point)
			var need := int(selected.get("count", 2))
			if picked_points.size() >= need:
				var placed := selected.duplicate(true)
				var options := (placed.get("opts", {}) as Dictionary).duplicate()
				options["points"] = picked_points.duplicate()
				placed["opts"] = options
				_perform(placed, [], picked_points[0], Vector2.ZERO)
			else:
				hud.banner("%d of %d spaces chosen" % [picked_points.size(), need], 1.2)
				_update_hover()
		"point":
			_perform(selected, [], _aim_point(), Vector2.ZERO)
		"place":
			# A square for the object (or teleport), or a creature to put it beside.
			if t != null and t.combatant != c and c.hostile_to(t.combatant):
				_perform(selected, [t.combatant], Vector2.INF, Vector2.ZERO)
			elif hover_cell.x >= 0:
				_perform(selected, [], Vector2(hover_cell.x + 0.5, hover_cell.y + 0.5), Vector2.ZERO)
		"direction":
			_perform(selected, [], Vector2.INF, _aim_dir(c))
		"multi":
			if t == null:
				return
			var why := catalog.target_why(c, selected, t.combatant)
			if why != "":
				hud.banner(why, 1.4)
				return
			if not bool(selected["repeat"]) and t.combatant in picked:
				picked.erase(t.combatant)
			else:
				picked.append(t.combatant)
			var need := e.spells.target_count(Compendium.shared().spell_data(str(selected["spell_id"])), slot_level + (1 if str((selected.get("opts", {}) as Dictionary).get("slot_boost", "")) != "" else 0)) if str(selected["kind"]) == "spell" else int(selected.get("count", 1))
			if picked.size() >= need:
				_perform(selected, picked.duplicate(), Vector2.INF, Vector2.ZERO)
			else:
				hud.banner("%d of %d chosen · Enter to cast now" % [picked.size(), need], 1.2)
				_update_hover()
		_:
			if t == null:
				return
			var why2 := catalog.target_why(c, selected, t.combatant)
			if why2 != "":
				hud.banner(why2, 1.4)
				return
			_perform(selected, [t.combatant], Vector2.INF, Vector2.ZERO)


## The attack a click on an enemy makes: the first usable weapon that can reach it, melee first.
func _default_attack(c: Combatant, t: Combatant) -> Dictionary:
	var best := {}
	for a in catalog.actions_for(c):
		if str(a["kind"]) != "attack" or not bool(a["legal"]):
			continue
		if catalog.target_why(c, a, t) != "":
			continue
		var o := e.option_by_id(c, str(a["option_id"]))
		if best.is_empty() or (bool(o["melee"]) and not bool(e.option_by_id(c, str(best["option_id"]))["melee"])):
			best = a
	return best


func _aim_point() -> Vector2:
	return Vector2(roundf(hover_world.x), roundf(hover_world.z))


func _aim_dir(c: Combatant) -> Vector2:
	var center := Vector2(c.cell.x + c.size_cells / 2.0, c.cell.y + c.size_cells / 2.0)
	var d := Vector2(hover_world.x, hover_world.z) - center
	if d.length() < 0.1:
		return Vector2(c.facing)
	var a := snappedf(d.angle(), PI / 4.0)
	return Vector2(cos(a), sin(a))


func _radial(choice: String) -> void:
	match choice:
		"Attacks", "Common":
			hud.set_tab(ActionCatalog.COMMON)
		"Spells":
			hud.set_tab(ActionCatalog.SPELLS)
		"Class":
			if _player() != null:
				hud.set_tab(catalog.class_tab(_player()))
		"Items":
			hud.set_tab(ActionCatalog.ITEMS)
		"Move":
			_cancel_targeting()
		"End Turn":
			_end_turn()
		"Inspect":
			_cycle_inspect()


func _cycle_inspect() -> void:
	var party: Array[Combatant] = []
	for c in e.combatants:
		if c.is_player_controlled():
			party.append(c)
	if party.is_empty():
		return
	var i := party.find(hud.shown)
	hud.shown = party[(i + 1) % party.size()]
	hud.refresh()


# --- Input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_F1 \
			or event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		hud.toggle_controls()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not using_pad:
			using_pad = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		using_pad = false
	if mode == Mode.OVER:
		if restart_allowed and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif not restart_allowed and (event.is_action_pressed(&"combat_end_turn") or event.is_action_pressed(&"combat_confirm")):
			hud.banner("", 0.0)
			finished.emit(e.outcome)
		return
	if hud.prompt_open():
		if event.is_action_pressed(&"combat_confirm"):
			hud.answer_prompt(true)
		elif event.is_action_pressed(&"combat_cancel"):
			hud.answer_prompt(false)
		get_viewport().set_input_as_handled()
		return
	if hud.confirm_open():
		if event.is_action_pressed(&"combat_end_turn") or event.is_action_pressed(&"combat_confirm"):
			hud.close_confirm()
			_end_turn()
		elif event.is_action_pressed(&"combat_cancel"):
			hud.close_confirm()
			_confirmed_end = false
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and hud.hide_details():
		return
	if event.is_action_pressed(&"combat_radial"):
		hud.radial.open()
		return
	if event.is_action_released(&"combat_radial"):
		hud.radial.confirm()
		return
	if event is InputEventMouseMotion:
		_pick_from_mouse((event as InputEventMouseMotion).position)
		_update_hover()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_pick_from_mouse(mb.position)
			_confirm_at()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mode == Mode.IDLE and _open_square_menu(mb.position):
				return
			_cancel_targeting()
			_update_hover()
	elif event.is_action_pressed(&"combat_confirm"):
		if mode == Mode.TARGET and str(selected.get("targeting", "")) == "multi" and not picked.is_empty() and not using_pad:
			_perform(selected, picked.duplicate(), Vector2.INF, Vector2.ZERO)
		else:
			_confirm_at()
	elif event.is_action_pressed(&"combat_cancel"):
		if hud.hide_details():
			return
		if mode == Mode.TARGET or not selected.is_empty():
			_cancel_targeting()
			_update_hover()
		else:
			menu_requested.emit()
	elif event.is_action_pressed(&"combat_end_turn"):
		_end_turn()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_C:
		_sheet("")   # the sheet of whoever the hotbar shows, view only
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_Z \
			and ((event as InputEventKey).ctrl_pressed or (event as InputEventKey).meta_pressed):
		_undo_move()   # Ctrl+Z (Cmd+Z on a Mac), ahead of plain Z, which changes the tab
	elif event.is_action_pressed(&"combat_tab_prev"):
		hud.cycle_tab(-1)
	elif event.is_action_pressed(&"combat_tab_next"):
		hud.cycle_tab(1)
	elif event.is_action_pressed(&"combat_slot_prev"):
		hud.move_focus(-1)
	elif event.is_action_pressed(&"combat_slot_next"):
		hud.move_focus(1)
	elif event.is_action_pressed(&"combat_use_slot"):
		var a := hud.slot_action(hud.focus_slot)
		if not a.is_empty():
			_choose(a)
	elif event.is_action_pressed(&"combat_next_target"):
		_next_target()
	elif event.is_action_pressed(&"combat_slot_level_down") or event.is_action_pressed(&"combat_slot_level_up"):
		_change_slot(-1 if event.is_action_pressed(&"combat_slot_level_down") else 1)
	elif event.is_action_pressed(&"cycle_leader"):
		_cycle_inspect()
	elif event.is_action_pressed(&"combat_toggle_log"):
		hud.toggle_log()
	else:
		for i in 10:
			if event.is_action_pressed(StringName("combat_slot_%d" % (i + 1))):
				var a2 := hud.slot_action(i)
				if not a2.is_empty():
					_choose(a2)
				return


func _change_slot(step: int) -> void:
	if hud.slot_levels.is_empty():
		return
	var i := clampi(hud.slot_levels.find(slot_level) + step, 0, hud.slot_levels.size() - 1)
	slot_level = hud.slot_levels[i]
	hud.set_pips(hud.slot_levels, slot_level)
	_update_hover()


## X / T: put the cursor on the next creature that the selected action (or an attack) could target.
func _next_target() -> void:
	var c := _player()
	if c == null:
		return
	var list: Array[Combatant] = []
	for o in e.living():
		if o == c or o.is_down() and str(selected.get("targeting", "")) != "dying":
			continue
		if mode == Mode.TARGET and catalog.target_why(c, selected, o) != "":
			continue
		if mode != Mode.TARGET and not c.hostile_to(o):
			continue
		list.append(o)
	if list.is_empty():
		return
	list.sort_custom(func(a: Combatant, b: Combatant) -> bool: return e.distance(c, a) < e.distance(c, b))
	_target_cycle = (_target_cycle + 1) % list.size()
	cursor_cell = list[_target_cycle].cell
	using_pad = true
	_pad_hover()


func _process(delta: float) -> void:
	if input_locked:
		return
	if hud.radial.visible:
		hud.radial.aim(Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)))
	# Controller cursor: the left stick steps it a square at a time.
	var stick := Input.get_vector(&"cursor_left", &"cursor_right", &"cursor_up", &"cursor_down")
	if stick.length() > 0.5:
		using_pad = true
		_pad_repeat -= delta
		if _pad_repeat <= 0.0:
			_pad_repeat = 0.16
			var basis := rig.ground_basis()
			var world := basis[0] * -stick.y + basis[1] * stick.x
			var step := Vector2i(roundi(world.x), roundi(world.z))
			cursor_cell = Vector2i(clampi(cursor_cell.x + step.x, 0, e.grid.width - 1), clampi(cursor_cell.y + step.y, 0, e.grid.depth - 1))
			_pad_hover()
	else:
		_pad_repeat = 0.0
	# Camera pan with WASD / arrows (the camera stops following until the next turn).
	var pan := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if pan.length() > 0.1:
		var b := rig.ground_basis()
		rig.follow = null
		rig.global_position += (b[0] * -pan.y + b[1] * pan.x) * delta * 9.0


func _pad_hover() -> void:
	hover_cell = cursor_cell
	hover_world = board.cell_center(cursor_cell) if e.grid.in_bounds(cursor_cell) else Vector3.ZERO
	hover_token = null
	var o := e.occupant_at(cursor_cell)
	if o != null:
		hover_token = tokens.get(o.id) as CombatToken
	rig.follow = null
	rig.global_position = rig.global_position.lerp(hover_world, 0.35)
	_update_hover()


# --- Picking and previews -------------------------------------------------------------------------

func _pick_from_mouse(screen: Vector2) -> void:
	var cam := rig.camera
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	hover_token = _token_on_ray(origin, dir)
	hover_cell = Vector2i(-1, -1)
	for h: int in [4, 3, 2, 1, 0]:
		if absf(dir.y) < 0.0001:
			break
		var t := (float(h) - origin.y) / dir.y
		if t < 0.0:
			continue
		var p := origin + dir * t
		var cell := Vector2i(floori(p.x), floori(p.z))
		if not e.grid.in_bounds(cell):
			continue
		if e.grid.height(cell) / CombatGrid.FEET == h or h == 0:
			hover_cell = cell
			hover_world = p
			break


func _token_on_ray(origin: Vector3, dir: Vector3) -> CombatToken:
	var best: CombatToken = null
	var best_t := INF
	for id: String in tokens:
		var tok := tokens[id] as CombatToken
		if not tok.combatant.is_alive():
			continue
		var base := tok.global_position
		var height := CombatToken.height_for(CombatToken.art_id(tok.combatant))
		var radius := 0.38 * tok.combatant.size_cells
		# Closest approach between the ray and the token's vertical axis.
		var steps := 12
		for i in steps + 1:
			var p := base + Vector3(0, height * i / float(steps), 0)
			var t := (p - origin).dot(dir)
			if t < 0.0:
				continue
			var q := origin + dir * t
			if q.distance_to(p) <= radius and t < best_t:
				best_t = t
				best = tok
	return best


func _target_under() -> CombatToken:
	if hover_token != null:
		return hover_token
	if hover_cell.x >= 0:
		var o := e.occupant_at(hover_cell)
		if o != null:
			return tokens.get(o.id) as CombatToken
	return null


func _update_hover() -> void:
	var c := _player()
	overlay.clear("path")
	overlay.clear("goal")
	overlay.clear("danger")
	if c == null or mode in [Mode.BUSY, Mode.PROMPT, Mode.OVER]:
		hud.hide_tooltip()
		overlay.clear("cursor")
		Cursors.show("pointer")
		return
	# The crossed swords over a foe (to attack or aim at), the pointer elsewhere.
	var under := _target_under()
	Cursors.show("attack" if under != null and c.hostile_to(under.combatant) else "pointer")
	overlay.show_cells("cursor", [hover_cell] if hover_cell.x >= 0 else [])
	var at := get_viewport().get_mouse_position() if not using_pad else rig.camera.unproject_position(hover_world + Vector3(0, 0.5, 0))
	var t := _target_under()
	if mode == Mode.TARGET:
		_target_hover(c, t, at)
		return
	# Idle: what a click would do. Nothing is lit until the pointer asks: the floor shows a walk only to where it points.
	if t != null and t.combatant != c:
		var o := t.combatant
		if c.hostile_to(o):
			var a := _default_attack(c, o)
			if a.is_empty():
				var first := {}
				for x in catalog.actions_for(c):
					if str(x["kind"]) == "attack":
						first = x
						break
				var pv0 := catalog.attack_preview(c, first, o) if not first.is_empty() else {"title": o.name(), "lines": []}
				hud.show_tooltip(str(pv0["title"]), pv0["lines"] as Array, ["Out of reach: move closer, or pick a ranged attack"], at)
			else:
				var pv := catalog.attack_preview(c, a, o)
				hud.show_tooltip(str(pv["title"]), pv["lines"] as Array, [], at)
		else:
			var about: Array = ["HP %d/%d · AC %d" % [o.creature.hp, o.creature.max_hp(), o.creature.ac_value()], hud._chips(o)]
			about.append_array(e.ground.describe_at(o.cell))
			hud.show_tooltip(o.name(), about, [], at)
		return
	# What lies on the square (GroundItems) is named under whatever else the tooltip says.
	var lying: Array = []
	if hover_cell.x >= 0:
		lying.append_array(e.ground.describe_at(hover_cell))
	if hover_cell.x < 0 or hover_cell == c.cell:
		if lying.is_empty():
			hud.hide_tooltip()
		else:
			hud.show_tooltip("Here", lying, [], at)
		return
	var mp := catalog.move_preview(c, hover_cell, _reach)
	if bool(mp["ok"]):
		# A dotted trail from the creature to a ring where it would stop; the ring is red if the walk provokes.
		overlay.show_trail("path", mp["path"] as Array)
		var provokes := false
		for w: String in mp["warnings"]:
			provokes = provokes or w.contains("Opportunity")
		overlay.clear("cursor")
		overlay.show_cells("danger" if provokes else "goal", [hover_cell])
		hud.show_tooltip("Move %d ft · %d ft left after" % [int(mp["cost"]), int(mp["left"])], lying, mp["warnings"] as Array, at)
	else:
		hud.show_tooltip(str(mp["reason"]), lying, [], at)


func _target_hover(c: Combatant, t: CombatToken, at: Vector2) -> void:
	var kind := str(selected["targeting"])
	if kind == "points" or (kind == "point" and str(selected["kind"]) == "feat"):
		var cells: Array = []
		for point in picked_points:
			cells.append(Vector2i(floori(point.x), floori(point.y)))
		if hover_cell.x >= 0:
			cells.append(hover_cell)
		overlay.show_cells("area", cells)
		hud.show_tooltip(str(selected["label"]), ["Choose a visible space within %d ft" % int(selected.get("range", 0)), "%d of %d spaces chosen" % [picked_points.size(), int(selected.get("count", 2))]] if kind == "points" else ["Choose an empty space or a willing ally to swap with"], [], at)
		return
	if kind in ["point", "direction"]:
		var pv := catalog.spell_preview(c, selected, _aim_point(), _aim_dir(c), slot_level)
		overlay.show_cells("area", pv["cells"] as Array)
		var lines: Array = []
		for w: Dictionary in pv["creatures"]:
			lines.append(str(w["line"]))
		if lines.is_empty():
			lines.append("No one in the area")
		hud.show_tooltip("%s · %s" % [selected["label"], "slot level %d" % int(pv["slot"]) if int(pv["slot"]) > 0 else "cantrip"], lines, pv["warnings"] as Array, at)
		return
	if kind == "place" and (t == null or not c.hostile_to(t.combatant)):
		var rng := int(selected.get("range", 0))
		# Measured from an Echo Knight's echo when the action moves it.
		var src := e.get_c(str(selected.get("from", "")))
		if src == null:
			src = c
		var ok := hover_cell.x >= 0 and e.grid.distance_ft(src.cell, src.size_cells, hover_cell, 1) <= rng
		overlay.show_cells("area", [hover_cell] if hover_cell.x >= 0 else [])
		hud.show_tooltip(str(selected["label"]), ["Click a square to place it (or an enemy to put it beside them)" if ok else "Out of range (%d ft)" % rng], [], at)
		return
	if t == null:
		var hint := "Choose a target"
		if kind == "multi":
			hint = "Choose targets (%d chosen) · Enter casts now" % picked.size()
		hud.show_tooltip(str(selected["label"]), [hint], [], at)
		return
	var o := t.combatant
	if str(selected["kind"]) in ["attack", "offhand"]:
		var pv2 := catalog.attack_preview(c, selected, o)
		hud.show_tooltip(str(pv2["title"]), pv2["lines"] as Array, [], at)
		return
	var why := catalog.target_why(c, selected, o)
	var lines2: Array = ["HP %d/%d · AC %d" % [o.creature.hp, o.creature.max_hp(), o.creature.ac_value()]]
	var tip_title := o.name()
	if str(selected["kind"]) in ["spell", "item_spell"]:
		var data := Compendium.shared().spell_data(str(selected["spell_id"]))
		var prev := catalog.cast_preview(c, selected, slot_level)
		if data.has("attack") and prev.has("attack"):
			var opt := {"melee": str(data["attack"]) == "melee", "profile": WeaponProfile.new()}
			var sit := e.attack_situation(c, o, opt)
			var ac := o.creature.ac_value() + int(sit["cover_bonus"])
			var to_hit := (prev["attack"] as Breakdown).total() + int(sit.get("height_bonus", 0))
			var needs := clampi(ac - to_hit, 2, 20)
			lines2.append("Spell attack %+d vs AC %d: needs %d+" % [to_hit, ac, needs])
			if int(sit.get("height_bonus", 0)) != 0:
				lines2.append(EncounterAttacks.height_line(int(sit.get("height_bonus", 0))))
			var sa := sit["advantage"] as Array
			var sd := sit["disadvantage"] as Array
			if not sa.is_empty() and sd.is_empty():
				tip_title = "%s · ADVANTAGE" % o.name()
			elif not sd.is_empty() and sa.is_empty():
				tip_title = "%s · DISADVANTAGE" % o.name()
			for s: Variant in sit["advantage"]:
				lines2.append("Advantage: %s" % s)
			for s: Variant in sit["disadvantage"]:
				lines2.append("Disadvantage: %s" % s)
		if data.has("save") and prev.has("save_dc"):
			var ab := StringName(str(data["save"]))
			var bonus := o.creature.save_bonus(ab).total()
			var dc := (prev["save_dc"] as Breakdown).total()
			lines2.append("%s save DC %d: fails %d%%" % [Creature.ABILITY_SHORT[ab], dc, roundi(clampf((dc - bonus - 1) / 20.0, 0.0, 1.0) * 100.0)])
		if prev.has("damage_dice"):
			lines2.append("Damage %s %s%s" % [prev["damage_dice"], str(prev.get("damage_type", "")).capitalize(), " " + (prev["damage_bonus"] as Breakdown).signed() if (prev["damage_bonus"] as Breakdown).total() != 0 else ""])
		if prev.has("heal_dice"):
			lines2.append("Heals %s %+d" % [prev["heal_dice"], (prev["heal_bonus"] as Breakdown).total()])
	if kind == "multi":
		lines2.append("Chosen: %d" % picked.count(o))
	hud.show_tooltip(tip_title, lines2, [why] if why != "" else [], at)


# --- Playing events -------------------------------------------------------------------------------

## The damage `id` takes from the event at `at` (an attack's blow), or -1 when none follows before the next action.
static func _damage_after(events: Array, at: int, id: String) -> int:
	for i in range(at + 1, events.size()):
		var ev := events[i] as Dictionary
		var kind := str(ev["type"])
		if kind == "damage" and str(ev["id"]) == id:
			return int(ev["amount"])
		if kind in ["attack", "spell", "ability", "move", "turn"]:
			break
	return -1


## Where a token stands: its square's centre, raised onto the mount's back for a rider.
func _token_spot(c: Combatant, cell: Vector2i) -> Vector3:
	var p := board.cell_center(cell, c.size_cells)
	var m := e.mount_of(c)
	if m != null:
		var h := CombatToken.height_for(CombatToken.art_id(m)) * (m.size_cells if m.size_cells > 1 else 1)
		p = board.cell_center(m.cell, m.size_cells) + Vector3(0, h * 0.8, 0)
	return p


func _play_events() -> void:
	var events := e.drain_events()
	var walking: Dictionary = {}
	# Who just played their attack as a spell gesture: the spell's own attack rolls that follow don't replay it.
	var cast_by := ""
	var ev_at := -1   # where `ev` is in `events`, for what follows it
	for ev in events:
		ev_at += 1
		if _closed:
			return   # the story took the fight back mid-way: its tokens may be gone
		var kind := str(ev["type"])
		match kind:
			"move":
				cast_by = ""
				fx.end_volley()
				var tok := _tok(str(ev["id"]))
				if tok == null:
					continue
				var from: Vector2i = ev["from"]
				var to: Vector2i = ev["to"]
				var step := STEP_TIME * GameSettings.combat_pace()   # the fast combat speed (Settings)
				# A move taken back (undo) glides home like a rewind: no walking, no turning round.
				var back := bool(ev.get("undo", false))
				tok.face(Vector2.ZERO if back else Vector2(to - from), not bool(ev.get("forced", false)) and not back, step)
				walking[tok] = true
				var tw := create_tween()
				tw.tween_property(tok, "position", _token_spot(tok.combatant, to), step)
				if bool(ev.get("mounted", false)) or bool(ev.get("dragged", false)):
					continue   # carried along: it moves with the step after it
				await tw.finished
			"attack":
				_stop_walking(walking)
				# An Echo Knight's blow struck from its echo plays on the echo.
				var a := _tok(str(ev.get("from", ev["attacker"])))
				if a == null:
					a = _tok(str(ev["attacker"]))
				var d := _tok(str(ev["target"]))
				if a != null and d != null:
					# Advantage or Disadvantage on the roll shows over the attacker, with its reason.
					var edge := ev.get("edge", {}) as Dictionary
					if not edge.is_empty():
						var adv := str(edge["kind"]) == "advantage"
						var why := ", ".join(edge.get("why", []) as Array)
						_float(a, ("ADVANTAGE" if adv else "DISADVANTAGE") + (("\n" + why) if why != "" else ""), "candle" if adv else "mist_blue", 34)
					var dir := (d.position - a.position)
					var home := a.position
					# A spell that rolls to hit (Fire Bolt, Eldritch Blast) sends its missile instead of a lunge.
					var flew: bool = await fx.volley(a, d, bool(ev["hit"]), str(ev.get("action", "")))
					# How the attack itself looks (art/vfx/effects.json): a monster's Fire Ray or an arrow flies, a claw
					# or a blade leaves a slash on the hit.
					var acue := SpellFx.attack_cue(a.combatant, str(ev.get("action", ""))) if SpellFx.enabled and not flew else {}
					var shoots := not acue.is_empty() and str(acue["family"]) in SpellFx.MISSILES and str(acue["family"]) != "touch"
					# The drawn attack winds up, then the token steps in on the blow; without one, just the step.
					var drawn := not flew and str(ev["attacker"]) != cast_by and a.start_attack(Vector2(dir.x, dir.z))
					if drawn:
						await a.wait_for_strike()
						if _cap_tool != null and not _cap_swing_done:
							# Capture: the first drawn attack at the moment its blow lands.
							_cap_swing_done = true
							_cap_tool.call("_shot", _cap_out + "_8_swing.png")
					elif not flew:
						a.face(Vector2(dir.x, dir.z), false)
					if shoots:
						await fx.missile(acue, a, d, bool(ev["hit"]))
					elif not flew:
						var tw2 := create_tween()
						tw2.tween_property(a, "position", home + dir.normalized() * (0.15 if drawn else 0.3), 0.1)
						tw2.tween_property(a, "position", home, 0.12)
						await tw2.finished
						if not acue.is_empty() and bool(ev["hit"]):
							fx.on_hit(acue, a, d, bool(ev.get("critical", false)))
					# A blow sounds by what struck and how hard it landed (CombatSfx); a spell's missile or a magic touch
					# already sounded as its effect landed.
					if not bool(ev["hit"]):
						Audio.sfx("swing")
					elif not flew and not str(ev.get("action", "")).begins_with("spell:") and (acue.is_empty() or str(acue["flavour"]) == "steel"):
						CombatSfx.hit(CombatSfx.hit_kind(a.combatant, str(ev.get("action", ""))), _damage_after(events, ev_at, d.combatant.id),
							d.combatant, bool(ev.get("critical", false)))
					if bool(ev["hit"]):
						barks.bark(a.combatant, "strike")
					if not bool(ev["hit"]):
						_float(d, "miss", "parchment")
					elif bool(ev.get("critical", false)):
						_narrate("combat:crit", a.combatant, d.combatant)
			"damage":
				var t := _tok(str(ev["id"]))
				if t != null:
					t.flash(Look.color("vampire_red"))
					t.hurt()
					_float(t, ("CRIT %d" if bool(ev.get("critical", false)) else "-%d") % int(ev["amount"]), "vampire_red", 64)
					t.refresh()
					if t.combatant.creature.hp > 0 and CombatSfx.heavy(int(ev["amount"]), t.combatant.creature.max_hp()):
						barks.bark(t.combatant, "hurt")
					await get_tree().create_timer(0.35 * GameSettings.combat_pace()).timeout
			"heal":
				var th := _tok(str(ev["id"]))
				if th != null:
					Audio.sfx("heal")
					_float(th, "+%d" % int(ev["amount"]), "bile")
					th.refresh()
			"condition", "down", "death", "death_save":
				var tc := _tok(str(ev["id"]))
				if tc != null:
					tc.refresh()
					if kind == "down" and tc.combatant.side in [&"party", &"guest"]:
						# A hero falls (owner ask 2026-10-07): the body drops, a thud and a bell, and their frame cries out.
						Audio.sfx("fall")
						Audio.sfx("toll", 0.0)
						tc.fall()
						hud.flash_down(tc.combatant.id)
						hud.banner("%s falls!" % tc.combatant.name())
						_narrate("combat:fall", tc.combatant, null)
					elif kind == "death":
						tc.fall_if_drawn()
					if kind == "death" and tc.combatant.side == &"enemy":
						Audio.sfx("enemy_death")
						Audio.sfx("thud")
						barks.bark(tc.combatant, "death")
						_narrate("combat:kill", null, tc.combatant)
					elif kind == "death" and tc.combatant.side == &"party":
						_narrate("death:" + tc.combatant.id, tc.combatant, null)
					if kind == "death_save":
						_float(tc, "✓" if bool(ev["success"]) else "✗", "bile" if bool(ev["success"]) else "vampire_red")
			"spell":
				_stop_walking(walking)
				var caster := _tok(str(ev["caster"]))
				cast_by = ""
				fx.end_volley()
				# How the spell looks (art/vfx/effects.json); {} plays only the flash and the floor marks. A cue's sounds
				# play with its effect (CombatSfx); without one, the plain spell sound.
				var cue := SpellFx.spell_cue(str(ev["spell"])) if SpellFx.enabled else {}
				if cue.is_empty() or caster == null:
					Audio.sfx("spell")
				if caster != null:
					caster.flash((cue["colours"] as Dictionary)["glow"] if not cue.is_empty() else Look.color("lilac"), 0.3)
					var aim := _spell_aim(ev, caster)
					# The drawn spell gesture when the sprite has one (aimed, or facing as it is for a spell on itself);
					# else casters whose attack is a spell gesture play that.
					if caster.start_cast(aim):
						cast_by = caster.combatant.id
						await caster.wait_for_strike()
					elif caster.casts_with_attack() and aim != Vector2.ZERO and caster.start_attack(aim):
						cast_by = caster.combatant.id
						await caster.wait_for_strike()
					if not cue.is_empty():
						var at: Array[CombatToken] = []
						for id: Variant in ev.get("targets", []) as Array:
							var tt0 := _tok(str(id))
							if tt0 != null:
								at.append(tt0)
						var rolls := str(Compendium.shared().spell_data(str(ev["spell"])).get("attack", "")) != ""
						await fx.cast(cue, caster, at, ev.get("cells", []) as Array, board, rolls)
				var cells := ev.get("cells", []) as Array
				if not cells.is_empty():
					overlay.show_cells("area", cells)
					await get_tree().create_timer(0.45 * GameSettings.combat_pace()).timeout
					overlay.clear("area")
			"ability":
				# A class feature or a monster's save action (Second Wind, a breath, a wail): its effect, if it has one.
				_stop_walking(walking)
				var ab := _tok(str(ev["by"]))
				var acu := SpellFx.ability_cue(str(ev.get("source", "")), str(ev["key"]), ab.combatant) if SpellFx.enabled and ab != null else {}
				if not acu.is_empty():
					ab.flash((acu["colours"] as Dictionary)["glow"], 0.3)
					var on: Array[CombatToken] = []
					for id: Variant in ev.get("targets", []) as Array:
						var ot := _tok(str(id))
						if ot != null:
							on.append(ot)
					if str(ev.get("source", "")) == "monster" and not on.is_empty() and on[0] != ab:
						var to := on[0].position - ab.position
						if ab.start_attack(Vector2(to.x, to.z)):
							await ab.wait_for_strike()
					await fx.cast(acu, ab, on, ev.get("cells", []) as Array, board, false)
			"smite":
				# A smite spell rides the hit that just landed (Divine Smite, Searing Smite...).
				var sk := _tok(str(ev["caster"]))
				var sv := _tok(str(ev["target"]))
				if SpellFx.enabled and sv != null:
					await fx.smite(str(ev["spell"]), sk, sv)
			"summon", "object", "object_gone":
				_show_weapons()
			"teleport":
				var tt := _tok(str(ev["id"]))
				if tt != null:
					# Back from Banishment: the token shows again.
					if not tt.visible:
						tt.show()
						tt.scale = Vector3.ONE * (float(tt.combatant.size_cells) if tt.combatant.size_cells > 1 else 1.0)
					tt.flash(Look.color("lilac"), 0.3)
					var was := tt.global_position
					tt.position = _token_spot(tt.combatant, ev["to"] as Vector2i)
					if SpellFx.enabled and was.distance_to(tt.global_position) > 0.5:
						fx.jumped(was, tt.global_position)
					await get_tree().create_timer(0.2 * GameSettings.combat_pace()).timeout
			"summon_creature":
				var sc := e.get_c(str(ev["id"]))
				if sc != null and not tokens.has(sc.id):
					var nt := CombatToken.create(sc)
					nt.position = board.cell_center(sc.cell, sc.size_cells)
					add_child(nt)
					tokens[sc.id] = nt
					nt.flash(Look.color("lilac"), 0.5)
					if SpellFx.enabled:
						fx.summoned(nt)
			"trait":
				# A monster trait that just saved it or changed the fight (Undead Fortitude): its name over the token.
				var trt := _tok(str(ev["id"]))
				if trt != null:
					trt.refresh()
					_float(trt, str(ev["name"]), "bone", 34)
					await get_tree().create_timer(0.35 * GameSettings.combat_pace()).timeout
			"legendary", "lair":
				# A boss acting between turns (ADR 0014): its name over the field, and a flash on the boss.
				_stop_walking(walking)
				var lt := _tok(str(ev["id"]))
				if lt != null:
					lt.flash(Look.color("vampire_red"), 0.3)
				hud.banner(("Lair action: %s" if kind == "lair" else "Legendary action: %s") % str(ev["name"]), 1.1)
				await get_tree().create_timer(0.35 * GameSettings.combat_pace()).timeout
				# The lair's own effect (its attacks and saves have no events of their own): "<master>.<action>".
				if kind == "lair" and lt != null and SpellFx.enabled:
					var lcue := SpellFx.ability_cue("monster", MonsterActions.action_key(lt.combatant, {"id": str(ev["action"])}), lt.combatant)
					if not lcue.is_empty():
						var lon: Array[CombatToken] = []
						for id: Variant in ev.get("targets", []) as Array:
							var lo := _tok(str(id))
							if lo != null:
								lon.append(lo)
						await fx.cast(lcue, lt, lon, [], board, false)
			"form":
				_swap_form_art(str(ev["id"]), str(ev.get("art", "")))
			"vanish":
				var vt := _tok(str(ev["id"]))
				if str(ev.get("narration", "")) != "" and vt != null:
					_narrate(str(ev["narration"]), null, vt.combatant)
				if vt != null and str(ev.get("left", "")) == "fell":
					# Over the edge: it drops out of sight.
					var drop := create_tween()
					drop.tween_property(vt, "position", vt.position + Vector3(0, -6, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					drop.tween_callback(vt.hide)
					await drop.finished
				elif vt != null:
					var tw3 := create_tween()
					tw3.tween_property(vt, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
					tw3.tween_callback(vt.hide)
			"fall":
				var ft := _tok(str(ev["id"]))
				if ft != null:
					_float(ft, "FALLS %d FT" % int(ev["feet"]), "bone", 34)
			"resize":
				var rt := _tok(str(ev["id"]))
				if rt != null:
					var k := float(rt.combatant.size_cells)
					var tw4 := create_tween()
					tw4.tween_property(rt, "scale", Vector3(k, k, k) if rt.combatant.size_cells > 1 else Vector3.ONE, 0.3)
					rt.position = board.cell_center(rt.combatant.cell, rt.combatant.size_cells)
			"turn":
				cast_by = ""
				fx.end_volley()
				_stop_walking(walking)
				_refresh_all()
				var tn := _tok(str(ev["id"]))
				if tn != null:
					barks.bark(tn.combatant, "battle")   # a kind of enemy cries out the first time one acts
			"round":
				if not _opening:   # the opening beat shows "Roll Initiative", then round 1
					hud.banner("Round %d" % int(ev["round"]), 1.0)
				round_started.emit(int(ev["round"]))
			"over":
				_refresh_all()
	_stop_walking(walking)
	_refresh_all()


## The token shown for a creature, or null (none, or freed once the story took the fight back).
func _tok(id: Variant) -> CombatToken:
	var v: Variant = tokens.get(str(id))
	return v as CombatToken if is_instance_valid(v) else null


## A Shapechanger took another shape (ADR 0014): its token wears the shape's sprite when it has one (`forms` art),
## and the stat block's own again in its true form.
func _swap_form_art(id: String, art: String) -> void:
	var old := _tok(id)
	if old == null:
		return
	var want := art if art != "" and DirectionalSprite.frames_for(art) != null else ""
	if want == old.art_override:
		old.flash(Look.color("lilac"), 0.3)
		return
	var nt := CombatToken.create(old.combatant, want)
	nt.position = old.position
	add_child(nt)
	tokens[id] = nt
	nt.flash(Look.color("lilac"), 0.4)
	old.queue_free()


## Where a spell goes, as a ground direction from its caster: its first other target, else the middle of its area.
## Zero for a spell on the caster alone.
func _spell_aim(ev: Dictionary, caster: CombatToken) -> Vector2:
	for id: Variant in ev.get("targets", []) as Array:
		var t := _tok(str(id))
		if t != null and t != caster:
			var d := t.position - caster.position
			return Vector2(d.x, d.z)
	var cells := ev.get("cells", []) as Array
	if cells.is_empty():
		return Vector2.ZERO
	var mid := Vector3.ZERO
	for cell: Variant in cells:
		mid += board.cell_center(cell as Vector2i)
	var d2 := mid / float(cells.size()) - caster.position
	return Vector2(d2.x, d2.z) if Vector2(d2.x, d2.z).length() > 0.1 else Vector2.ZERO


## A Narrator line in the combat log (and briefly as a banner), if the story has one for this moment.
func _narrate(key: String, actor: Combatant, target: Combatant) -> void:
	if narrator == null or story == null:
		return
	var who: Character = actor.creature as Character if actor != null and actor.creature is Character else null
	var text := narrator.line(key, story, who, {"round": e.round_no, "target": target.name() if target != null else ""})
	if text != "":
		e.log.add("narr", text, "")
		hud.refresh_log()
		# A story cutscene for this moment (story/cutscenes.gd): its picture over the fight, the line as its caption.
		var cut := Cutscenes.for_trigger(key, story)
		if cut != "":
			var player := CutscenePlayer.new()
			add_child(player)
			if player.play(cut, [text] as Array[String], story):
				Cutscenes.mark_played(cut, story)
				return
			player.queue_free()
		if VoiceOver.say(VoiceOver.NARRATOR, text) > 0.0:
			barks.hush()   # the Narrator speaks over no one


func _stop_walking(walking: Dictionary) -> void:
	for tok: Variant in walking.keys():
		(tok as CombatToken).face(Vector2.ZERO, false)
	walking.clear()


## A number or word rising over a creature: stays readable for about 2 seconds, then fades (damage a little bigger).
func _float(t: CombatToken, text: String, colour: String, size: int = 52) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Look.color(colour)
	l.outline_modulate = Look.color("void")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 11
	l.position = t.position + Vector3(0, CombatToken.height_for(CombatToken.art_id(t.combatant)) + 0.2, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector3(0, 0.6, 0), FLOAT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(FLOAT_TIME - 0.7)
	tw.tween_callback(l.queue_free)


# --- Test and capture hooks -----------------------------------------------------------------------

## For the capture tool: lock out the mouse, then show the active character's move preview toward the enemies.
func debug_move_leader(_point: Vector3) -> void:
	input_locked = true
	var c := _player()
	if c == null:
		return
	using_pad = true
	cursor_cell = c.cell + Vector2i(4, -1)
	_pad_hover()


## The capture tool's shot list (make capture SCENE=res://scenes/combat/arena.tscn): the opening move preview, an
## attack tooltip, a spell template, the first reaction prompt and the end of the fight. A fixed seed keeps the
## shots repeatable. The party is played by the test autopilot only to reach those moments; in the game the player
## controls every party member.
var _cap_tool: Node = null
var _cap_out := ""
var _cap_swing_done := false
var _cap_prompt_done := false


func capture_shots(tool: Node, out: String) -> void:
	input_locked = true
	_cap_tool = tool
	_cap_out = out
	await tool.call("wait_frames", 90)
	debug_move_leader(Vector3.ZERO)
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_1_move.png")
	var pilot := PartyAutopilot.new(e)
	# An attack tooltip once a party member has an enemy in reach.
	for guard in 60:
		if e.state != Encounter.State.ACTIVE:
			break
		var c := e.current()
		if c.is_player_controlled() and c.can_act():
			var near: Combatant = null
			for o in e.hostiles_of(c):
				if not o.is_down() and e.distance(c, o) <= 5:
					near = o
			if near != null:
				_advance()
				await tool.call("wait_frames", 30)
				# Capture only: the foe is knocked down so the tooltip shows its ADVANTAGE line.
				near.creature.add_condition(&"prone", "Capture")
				hover_token = tokens[near.id] as CombatToken
				hover_cell = near.cell
				using_pad = true
				_update_hover()
				await tool.call("wait_frames", 10)
				tool.call("_shot", out + "_2_attack.png")
				# The right-click menu on that square: Move here, every attack and spell on the foe, Info.
				var spot := get_viewport().get_visible_rect().size / 2.0
				_menu_cell = near.cell
				_menu_items = catalog.square_actions(c, near.cell, _reach)
				var shown: Array[Dictionary] = []
				for it in _menu_items:
					shown.append({"id": it["id"], "label": it["label"], "enabled": it.get("enabled", true), "why": it.get("why", "")})
				hud.hide_tooltip()
				hud.open_square_menu(near.name(), shown, spot)
				await tool.call("wait_frames", 10)
				tool.call("_shot", out + "_2b_square_menu.png")
				hud._menu.hide()
				near.creature.remove_condition(&"prone", "Capture")
				break
		await _autoplay_turn(pilot)
	# A spell template: Silvain's Burning Hands or Sleep aimed at the thickest knot of enemies.
	for guard in 40:
		if e.state != Encounter.State.ACTIVE:
			break
		var c2 := e.current()
		if c2.is_player_controlled() and (c2.creature as Character).class_level_of("wizard") > 0 and c2.can_act():
			_advance()
			await tool.call("wait_frames", 20)
			var a := catalog.find(c2, "spell:burning_hands")
			if a.is_empty() or not bool(a["legal"]):
				a = catalog.find(c2, "spell:thunderwave")
			if not a.is_empty() and bool(a["legal"]):
				_choose(a)
				var target := e.ai._nearest_enemy(c2)
				if target != null:
					hover_world = board.cell_center(target.cell)
					hover_cell = target.cell
				using_pad = true
				_update_hover()
				await tool.call("wait_frames", 10)
				tool.call("_shot", out + "_3_area.png")
				_cancel_targeting()
				await _capture_new_objects(tool, out, c2)
			break
		await _autoplay_turn(pilot)
	var weapon_shot := false
	for guard in 400:
		if e.state != Encounter.State.ACTIVE:
			break
		await _autoplay_turn(pilot)
		# Spiritual Weapon on the field (the spell audit's fix: a weapon you can see, not just a highlighted square).
		if not weapon_shot:
			for c3 in e.combatants:
				var w := e.spells.weapon_of(c3)
				if w != null:
					weapon_shot = true
					rig.follow = field.node_for(w.id)
					await tool.call("wait_frames", 45)
					tool.call("_shot", out + "_6_weapon.png")
					break
	_advance()
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_5_end.png")


## The Phase 4 spell objects and a mounted rider, staged beside the wizard for one shot: Mordenkainen's Faithful
## Hound, a Grasping Vine and the wizard riding an Otherworldly Steed (captures only).
func _capture_new_objects(tool: Node, out: String, c: Combatant) -> void:
	var cells: Array[Vector2i] = []
	for off: Vector2i in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(-3, 0), Vector2i(3, 0), Vector2i(-2, 1), Vector2i(2, 1)]:
		var cell := c.cell + off
		if e.grid.in_bounds(cell) and not e.grid.is_solid(cell) and e.occupant_at(cell) == null:
			cells.append(cell)
	if cells.size() < 2:
		return
	var hound := FieldObject.new(FieldObject.Kind.HOUND, "mordenkainens_faithful_hound", "Faithful Hound")
	hound.caster_id = c.id
	hound.cell = cells[0]
	hound.cells = [cells[0]]
	hound.rounds_left = 1000
	e.spells.zones.add(hound, CombatResult.new())
	var vine := FieldObject.new(FieldObject.Kind.VINE, "grasping_vine", "Grasping Vine")
	vine.caster_id = c.id
	vine.cell = cells[1]
	vine.cells = [cells[1]]
	vine.rounds_left = 1000
	e.spells.zones.add(vine, CombatResult.new())
	var steed_data := SummonBlocks.for_spell("find_steed", 2, "celestial", {})
	var m := Monster.from_data(steed_data)
	var spot := e.spells._free_cell_near(c.cell, 2)
	var sc := e.add(m, &"guest", spot)
	sc.controller = &"player"
	sc.set_meta("summoner", c.id)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": spot, "caster": c.id})
	c.movement_left = c.speed()
	var keep := e.order.duplicate()
	e.mount(c, sc)
	e.order = keep
	await _play_events()
	_show_weapons()
	rig.follow = tokens[c.id] as Node3D
	await tool.call("wait_frames", 45)
	tool.call("_shot", out + "_7_new_objects.png")
	e.dismount(c)
	sc.creature.dead = true
	e.events.append({"type": "vanish", "id": sc.id})
	hound.ended = true
	vine.ended = true
	e.spells.zones.prune()
	await _play_events()
	_show_weapons()


## One turn played without the player (captures only): the autopilot for the party, AiBrain for enemies. The
## first reaction prompt is photographed before it's answered.
func _autoplay_turn(pilot: PartyAutopilot) -> void:
	var c := e.current()
	if c.is_player_controlled():
		pilot.play(c)
	else:
		e.run_ai_turn()
	await _play_events()
	while e.pending != null:
		if not _cap_prompt_done and _cap_tool != null:
			_cap_prompt_done = true
			_refresh_all()
			hud.show_prompt(e.pending)
			await _cap_tool.call("wait_frames", 10)
			_cap_tool.call("_shot", _cap_out + "_4_reaction.png")
			hud.hide_prompt()
		e.answer_reaction(true)
		await _play_events()
	if e.state == Encounter.State.ACTIVE and e.current() == c and c.is_player_controlled():
		e.end_turn()
		await _play_events()
	_refresh_all()
