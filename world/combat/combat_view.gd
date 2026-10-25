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
## An observed copy after normal presentation, for guided practice.
signal events_presented(events: Array[Dictionary])
## A beat of an action reached the screen: "damage" (the blow's number floated), "save" (a hero's big d20 for a saving
## throw, shown after the blow and damage that called for it) or "concentration" (the sound of a spell breaking).
## `id` is the creature it happened to.
signal moment_shown(kind: String, id: String)

## Seconds per square for a token moving on the board (owner 2026-10-06: half the old speed, it read unnaturally fast).
const STEP_TIME := 0.37   # seconds a square (owner 2026-10-07: about 30% slower than 0.26)
const AI_PAUSE := 0.35
## How long damage and healing numbers stay over a creature.
const FLOAT_TIME := FloatText.TIME
## The opening beat before the first turn (owner 2026-10-06: going into a fight felt abrupt): the camera takes in the
## field, the foes step into view, the HUD fades up and Initiative is rolled.
const INTRO_TIME := 1.5
## The part of the screen the combat HUD leaves clear, as the opening shot frames the fight: |x| up to .x, and y from
## .z (bottom) to .y (top), in -1..1 screen units.
const CLEAR_VIEW := Vector3(0.5, 0.55, -0.4)
## The clear part's bottom with boss plates over the hotbar (G3).
const BOSS_CLEAR_BOTTOM := -0.25

enum Mode { BUSY, IDLE, TARGET, PROMPT, OVER }

var e: Encounter
var catalog: ActionCatalog
var board: ArenaBoard
var overlay: GridOverlay
var field: FieldView
## What lies on the ground (world/combat/ground_view.gd).
var ground_view: GroundView
## The breakable things, fire and oil (world/combat/object_view.gd).
var objects_view: ObjectView
## Spell and ability effects (world/combat/fx/spell_fx.gd).
var fx: SpellFx
## What enemies shout and creatures sound like (world/combat/combat_barks.gd).
var barks: CombatBarks
## Who is concentrating on what (combatant id -> spell id), for the sound when a blow breaks it.
var _concentrating: Dictionary = {}
## True while _play_events plays an action: the combat log doesn't flush early on a narration, or it would give away
## a save, a failed Concentration or a fall the screen hasn't shown yet.
var _log_held := false
## Heavy hits, crits, killing blows, the last foe and big spells landing with weight (G2, world/combat/combat_impact.gd).
var impact: CombatImpact
## Strahd's and the other bosses' name plates and health bars, and their entrance (G3, ui/combat/boss_bar.gd); null
## in a fight without one.
var boss_bar: BossBar
var rig: CameraRig
var hud: CombatHud
var tokens: Dictionary = {}
## The party's and guests' own figures as the fight was handed them (id -> CombatToken): exploring goes on with these
## after the fight, so a change of shape hides one instead of freeing it (_swap_form_art).
var _own_tokens: Dictionary = {}
## A foe drawn in someone else's look (a named NPC on a generic stat block) while it wears a Beast's shape: id -> that
## look, to wear again when the shape ends (_swap_shape_art).
var _shape_looks: Dictionary = {}
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
## Picks after the first: a wall's squares and burning side, Commander's Strike's foe, Crown of Madness's victim,
## Maneuvering Attack's ally and square (world/combat/target_picker.gd).
var picker: TargetPicker
var slot_level := 0
var _reach: Dictionary = {}
var _target_cycle := 0
## Captures and scene tests turn off the mouse so a stray pointer can't act.
var input_locked := false
## Optional practice opponent; ordinary encounters keep the default AI path.
var opponent_turn: Callable
## Optional guided-scenario restriction, absent in ordinary encounters.
var command_filter: Callable
## The pad's own part of a fight (U6): the menu, controls, undo, the square's menu, death saves, the camera and prompts.
var pad := PadCombat.new(self)
## The story's Narrator speaks rarely in combat (crits, falls, kills, victory; plan §5.7); none in the arena.
var narrator: Narrator = null
var story: StoryState = null
## The fight's opening beat is playing (begin): the first turn waits for it.
var _opening := false
## The camera's zoom before the opening shot pulled it out.
var _zoom_before := 13.0
## The view is fading out after the fight (close_softly): nothing more is played.
var _closed := false
## A boss's entrance is showing (a click, Space or Escape cuts it short).
var _entrance_tw: Tween
## Enemy plans are made on a worker thread so the screen keeps moving while a foe in a big fight thinks (FN-14);
## headless runs (tests, the balance sims) plan in line as before.
var think_aside := DisplayServer.get_name() != "headless"
var _thinker: Thread = null


## Starts showing `encounter` on `board_` with `rig_` and the creatures' `tokens_` (id -> CombatToken). Starts the
## encounter (rolling Initiative) unless it's already running.
func begin(encounter: Encounter, board_: ArenaBoard, rig_: CameraRig, tokens_: Dictionary, surprised: Array[String] = []) -> void:
	name = "CombatView"
	InputActions.ensure()   # the camera keys and the pad cursor, wherever the fight is shown from
	e = encounter
	board = board_
	rig = rig_
	tokens = tokens_
	for id: Variant in tokens:
		var own := tokens[id] as CombatToken
		if own != null and own.combatant != null and own.combatant.side in [&"party", &"guest"]:
			_own_tokens[id] = own
	e.shared_turns = GameSettings.shared_turns()
	_hero_saves()   # what was rolled before the fight showed isn't news
	catalog = ActionCatalog.new(e)
	picker = TargetPicker.new(e)
	overlay = GridOverlay.create(board)
	overlay.lines.rig = rig   # (the whole map's grid as the camera goes tactical)
	add_child(overlay)
	field = FieldView.create(board)
	add_child(field)
	ground_view = GroundView.create(board)
	add_child(ground_view)
	objects_view = ObjectView.create(board)
	add_child(objects_view)
	# The breakable things on the board's '=' squares (a location fight placed its own already).
	if e.state == Encounter.State.SETUP:
		BattleScenery.from_board(e, board)
	fx = SpellFx.new()
	add_child(fx)
	barks = CombatBarks.new()
	add_child(barks)
	impact = CombatImpact.new(rig)
	add_child(impact)
	hud = CombatHud.new()
	add_child(hud)
	hud.build(e, catalog)
	hud.action_chosen.connect(_choose)
	hud.end_turn_pressed.connect(_end_turn)
	hud.drop_concentration_confirmed.connect(_drop_concentration)
	hud.undo_move_pressed.connect(_undo_move)
	hud.reaction_answered.connect(_answer)
	hud.inspect_requested.connect(_inspect)
	hud.focus_requested.connect(_focus_on)
	hud.sheet_requested.connect(_sheet)
	hud.death_save_pressed.connect(_death_save)
	hud.slot_level_changed.connect(func(l: int) -> void:
		slot_level = l
		_update_hover())
	hud.radial_picked.connect(_radial)
	hud.radial.picked_item.connect(_wheel_picked)
	hud.cast_at_level.connect(func(action: Dictionary, level: int) -> void: _choose(action, level))
	hud.square_picked.connect(_square_picked)
	_restore_forms()   # a fight picked up from a save, with someone mid-shape
	var fresh := e.state == Encounter.State.SETUP
	if fresh:
		if e.title != "":
			e.log.add("turn", e.title, "")
		if e.intro != "":
			e.log.add("narr", e.intro, "")
		e.start(surprised)
	# A colossus stepping down off where it stood (StepDown, the Amber Sentinel) wakes and strides to its square first.
	var striders := StepDown.pending(tokens)
	if fresh and not striders.is_empty():
		hud.visible = false   # (the opening beat fades it up after)
		for strider in striders:
			await StepDown.play(self, strider)
			if _closed:
				return
	# Bosses (G3): a name plate and health bar for each above the hotbar, and for a fight that's just starting, an
	# entrance on the greatest of them before the opening beat.
	var bosses := BossBar.bosses_in(e)
	var entered := false
	if not bosses.is_empty():
		boss_bar = BossBar.new()
		add_child(boss_bar)
		boss_bar.build(e, bosses)
		if fresh and BossBar.entrance_on():
			entered = await _boss_entrance(bosses[0])
			if _closed:
				return
	# The opening beat: the camera takes in the field and the HUD fades up while Initiative is rolled; the first turn
	# waits for it. The rules are already running (round 1 saves itself as usual).
	var opened := Time.get_ticks_msec()
	_opening = true
	_frame_the_fight(rig.follow == null)
	LayerFade.fade(self, hud, true, 0.4, 0.2).finished.connect(func() -> void: hud.banner("Roll Initiative", INTRO_TIME))
	if boss_bar != null and not entered:
		LayerFade.fade(self, boss_bar, true, 0.4, 0.2)
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
		if absf(x) > CLEAR_VIEW.x or y > CLEAR_VIEW.y or y < (CLEAR_VIEW.z if boss_bar == null else BOSS_CLEAR_BOTTOM):
			return false
	return true


## The end of the opening beat: round 1 is announced and the camera eases back in to the zoom it had, on whoever acts
## first (_advance sets it following them).
func _end_opening() -> void:
	_opening = false
	if e.state == Encounter.State.ACTIVE:
		hud.banner("Round %d" % e.round_no, 1.0)
	create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).tween_property(rig, "distance", _zoom_before, 0.9)


## A boss's entrance (G3): letterbox bars, the camera close and low on `boss`, its name and title, a sting; then the
## usual opening shot takes in the whole fight. False (and nothing shown) when the boss can't be seen.
func _boss_entrance(boss: Combatant) -> bool:
	var tok := _tok(boss.id)
	if tok == null or not tok.visible:
		return false
	hud.visible = false   # the opening beat fades it up after
	var was_following := rig.follow != null
	rig.follow = tok
	rig.cutaway_focus = tok   # walls between the camera and the boss go down for the shot
	if not was_following:
		rig.snap_to_target()   # a scene that opens on the fight (the arena) starts on the boss
	impact.boss_shot()
	boss_bar.show_entrance(boss)
	_entrance_tw = create_tween()
	_entrance_tw.tween_interval(BossBar.ENTRANCE)
	await _entrance_tw.finished
	_entrance_tw = null
	rig.cutaway_focus = null
	boss_bar.hide_entrance()
	impact.boss_shot_done()
	return true


## Removes the view's overlay and HUD (the board and tokens belong to the caller).
func close() -> void:
	_closed = true
	input_locked = true
	queue_free()


## Ends the view without a snap (the story, after a fight): input stops at once, the floor marks go, the combat HUD
## fades out, then the view frees itself.
func close_softly() -> void:
	_closed = true
	input_locked = true
	mode = Mode.OVER
	overlay.clear_all()
	overlay.lines.set_active(false)
	overlay.lines.latched = false
	hud.hide_tooltip()
	if boss_bar != null:
		LayerFade.fade(self, boss_bar, false, 0.35)
	LayerFade.fade(self, hud, false, 0.35).finished.connect(queue_free)


# --- Turn flow ------------------------------------------------------------------------------------

## Decides what happens next: a reaction prompt, an enemy turn, the player's turn, or the end.
func _advance() -> void:
	if _closed:
		return   # the story took the fight back (close_softly); a turn still in flight stops here
	e.shared_turns = GameSettings.shared_turns()   # the Settings choice, read again in case it changed mid-fight
	e.flanking = GameSettings.flanking()
	_refresh_all()
	if e.state == Encounter.State.OVER:
		mode = Mode.OVER
		overlay.clear_all()
		overlay.lines.set_active(false)
		overlay.lines.latched = false
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
	# The camera stays where it is for an Invisible foe's turn: going to it would show where it is.
	if not (_tok(c.id) != null and _tok(c.id).unseen):
		rig.follow = tokens[c.id] as Node3D
	_gather_grid(c)
	_looked_at = ""
	if not c.is_player_controlled() or e.compelled(c):
		mode = Mode.BUSY
		overlay.clear_all()
		hud.hide_tooltip()
		await get_tree().create_timer(AI_PAUSE * GameSettings.combat_pace()).timeout
		if _closed or not is_inside_tree():
			return
		while opponent_turn.is_valid() and not can_process():
			await get_tree().process_frame
			if _closed or not is_inside_tree():
				return
		if e.state != Encounter.State.ACTIVE or e.current() != c or e.pending != null:
			_advance()
			return
		var r: CombatResult = opponent_turn.call(c) as CombatResult if opponent_turn.is_valid() else e.begin_ai_turn()
		if r == null:
			var thought: Dictionary = await _think(c)
			if thought.is_empty():
				return
			if _closed or e.state != Encounter.State.ACTIVE or e.current() != c or e.pending != null:
				_advance()
				return
			r = e.finish_ai_turn(thought)
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
	# Maneuvering Attack just hit: the ally that moves, then its square (TargetPicker).
	if picker.begin_move(c):
		selected = picker.action
		mode = Mode.TARGET
	# A walk up to a foe just ended: the blow it was for.
	if mode == Mode.IDLE and _strike_after(c):
		return
	_update_hover()


## `c`'s plan (AiBrain.think) made on a worker thread while the frames go on (FN-14: a foe in a big fight took half a
## second to plan, and the screen froze). Nothing changes the fight meanwhile: it's an enemy's turn, the plan only
## reads it, and so does the screen (a Creature read belongs to the thread that opened it).
func _think(c: Combatant) -> Dictionary:
	if not think_aside:
		return e.ai.think(c)
	# What a creature's conditions and gear grant is worked out on first use and kept: settle it for everyone first,
	# so the two threads never fill it at once.
	for x in e.combatants:
		if x.creature != null:
			x.creature.all_modifiers()
	var th := Thread.new()
	_thinker = th
	th.start(e.ai.think.bind(c))
	while _thinker == th and th.is_alive():
		await get_tree().process_frame
	if _thinker != th:
		return {}   # the view went away meanwhile (_exit_tree waited for the plan)
	_thinker = null
	var thought: Variant = th.wait_to_finish()
	return thought as Dictionary if thought is Dictionary else e.ai.think(c)


func _exit_tree() -> void:
	_closed = true
	if _thinker != null:
		_thinker.wait_to_finish()   # a plan still being made as the view goes (a load from the menu)
		_thinker = null


## The hero the player looks through (owner, 2026-10-13: an Invisible foe is on the map only "if the player character
## targeting them has invisibility"): whoever's turn it is, and through a foe's turn the hero who had the last one.
## An inspected hero (a click on a portrait) doesn't change it.
var viewer: Combatant = null


func _look_through(cur: Combatant) -> void:
	if cur != null and cur.is_player_controlled() and cur.side in [&"party", &"guest"] and cur.is_alive():
		viewer = cur
	if viewer != null and not viewer.is_alive():
		viewer = null
	hud.viewer = viewer


func _refresh_all() -> void:
	var cur := e.current()
	_look_through(cur)
	for id: String in tokens:
		var t := _tok(id)
		if t == null:
			continue
		t.mounted = e.mount_of(t.combatant) != null
		t.refresh()
		t.set_active(cur != null and t.combatant == cur and e.state == Encounter.State.ACTIVE)
		t.set_unseen(e.sight.hidden_from_party(t.combatant, viewer))
	hud.refresh()
	if boss_bar != null:
		boss_bar.refresh()
	_show_weapons()
	_show_heights()


## A dark disc on the floor under each creature in the air (flying, levitating, carried), so its square reads at a
## glance, and nothing under the rest.
var _air_marks: Dictionary = {}


func _show_heights() -> void:
	for id: String in _air_marks.keys():
		var c := e.get_c(id)
		if c == null or c.altitude <= 0 or not c.is_alive() or c.has_meta("left_fight"):
			(_air_marks[id] as Node3D).queue_free()
			_air_marks.erase(id)
	for c in e.living():
		if c.altitude <= 0 or c.has_meta("left_fight"):
			continue
		var mark := _air_marks.get(c.id) as MeshInstance3D
		if mark == null:
			mark = MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.height = 0.02
			disc.top_radius = 0.38 * c.size_cells
			disc.bottom_radius = 0.38 * c.size_cells
			mark.mesh = disc
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(Look.color("ink"), 0.45)
			mark.material_override = m
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			board.add_child(mark)
			_air_marks[c.id] = mark
		mark.position = board.cell_center(c.cell, c.size_cells) + Vector3(0, 0.03, 0)


## Spell objects and lingering areas on the field (Spiritual Weapon, Flaming Sphere, Spirit Guardians, Web...).
func _show_weapons() -> void:
	field.sync(e.spells.zones.objects)
	ground_view.sync(e.ground.items)
	objects_view.sync(e.objects)


func _player() -> Combatant:
	var c := e.current()
	return c if c != null and c.is_player_controlled() and e.state == Encounter.State.ACTIVE else null


func _end_turn() -> void:
	if not _command_allowed("end_turn", {}):
		return
	var c := _player()
	if c == null or mode not in [Mode.IDLE, Mode.TARGET]:
		return
	if hud.confirm_open() and hud.confirm_kind() == "drop_concentration":
		hud.close_confirm()   # ending the turn gives the check about a spell no answer: it is closed, the spell kept
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


## The player said yes to "Stop concentrating on ...?": the spell ends at no cost, and its cue (the sound of a spell
## breaking after a blow) doesn't sound for it later.
func _drop_concentration() -> void:
	var c := _player()
	if c == null or mode not in [Mode.IDLE, Mode.TARGET]:
		return
	var held := c.creature.concentration
	var action := catalog.find(c, "drop_concentration")
	if action.is_empty() or not bool(action["legal"]):
		hud.banner(str(action.get("reason", "Not concentrating")), 1.4)
		return
	_cancel_targeting()
	_concentrating.erase(c.id)
	if held != null:
		hud.banner("Stopped concentrating on %s" % held.name, 1.4)
	_perform(action, [], Vector2.INF, Vector2.ZERO)


## Takes back the current creature's last move (the HUD's Undo move, or Ctrl+Z): it goes back with its movement.
func _undo_move() -> void:
	if not _command_allowed("undo", {}):
		return
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
	if not _command_allowed("inspect", {}):
		return
	if id.begins_with("hover:"):
		var t := tokens.get(id.substr(6)) as CombatToken
		for k: String in tokens:
			(tokens[k] as CombatToken).set_highlight(tokens[k] == t)
		return
	var c := e.get_c(id)
	# A hero sharing the turn: a click takes control of them (shared party turns).
	if c != null and c in e.shared_heroes() and c != e.current() and mode in [Mode.IDLE, Mode.TARGET]:
		_switch(c)
		return
	if c != null and c.is_player_controlled():
		hud.shown = c
		hud.refresh()


## A click on a portrait in the turn order (owner, 2026-10-12: "it should pan the camera over to where that enemy or
## player character is"): the camera glides over to them (the rig eases after what it follows) and their figure lights
## up; on a pad the cursor goes too. The next turn, the camera keys or the cursor take the camera on. A creature
## nobody can see stays unseen.
func _focus_on(id: String) -> void:
	if not _command_allowed("focus", {}):
		return
	var tok := _tok(id)
	if tok == null or not tok.visible or tok.combatant == null or not tok.combatant.is_alive():
		return
	_looked_at = id
	if using_pad:
		cursor_cell = tok.combatant.cell
		_pad_hover()
		hud.look_at(id)   # the order scrolls to them and rings them
	rig.follow = tok
	for k: String in tokens:
		(tokens[k] as CombatToken).set_highlight(tokens[k] == tok)


## The battle grid (BattleGrid; the Modern look's, laid over natural ground): its lines gather round the creature whose
## turn it is, as far as it can move, shown while the Show the grid key is held (or on their own, by the setting). An
## Invisible foe's turn leaves them where they were, as it leaves the camera, and so does one nobody can see; with none
## yet, they gather round the hero looked through.
func _gather_grid(c: Combatant) -> void:
	overlay.lines.set_auto(BattleGrid.auto_in_fights())
	var tok := _tok(c.id)
	if tok == null or tok.unseen or not tok.visible:
		if overlay.lines.follow != null:
			return
		tok = _tok(viewer.id) if viewer != null else null
		if tok == null:
			for own: Variant in _own_tokens.values():
				tok = own as CombatToken
				break
	if tok != null:
		overlay.lines.gather(tok, c.speed() if tok.combatant == c else 0)


## The last creature looked at from the turn order (_focus_on), where the pad's next look starts from.
var _looked_at := ""


## On a pad (holding the radial, the Next target button; the right bumper goes back): the camera to the next creature in
## the turn order after the one last looked at, or after whoever's turn it is. The order on the HUD scrolls along.
func _look_along_order(step: int = 1) -> void:
	var order: Array[Combatant] = []
	for c in e.order:
		var tok := _tok(c.id)
		if c.is_alive() and tok != null and tok.visible:
			order.append(c)
	if order.is_empty():
		return
	var from := e.get_c(_looked_at) if _looked_at != "" else e.current()
	var i := order.find(from)
	if i < 0:
		_focus_on(order[0 if step > 0 else order.size() - 1].id)   # whoever it was is gone: from the top, or the end
		return
	_focus_on(order[posmod(i + step, order.size())].id)


## Takes control of another hero sharing the turn (EncounterTurns.switch_to): a click on their frame or portrait, Tab,
## or the radial's Inspect. The camera goes to them; the one left keeps what it hasn't used.
func _switch(c: Combatant) -> void:
	if not _command_allowed("switch", {"target": c}):
		return
	_cancel_targeting()
	var r := e.switch_to(c)
	if not r.ok:
		hud.banner(r.reason, 1.4)
		return
	hud.shown = c
	mode = Mode.BUSY
	await _play_events()
	if r.is_paused() or e.pending != null:
		mode = Mode.PROMPT
		_refresh_all()
		hud.show_prompt(e.pending)
		return
	_advance()


func _sheet(id: String) -> void:
	if not _command_allowed("sheet", {}):
		return
	var c := e.get_c(id) if id != "" else hud.shown
	if c == null:
		for each in e.combatants:
			if each.side == &"party" and each.creature is Character:
				c = each
				break
	if c != null and c.creature is Character:
		sheet_requested.emit(c.creature as Character)


func _answer(use: bool, rule: String) -> void:
	if not _command_allowed("reaction", {"use": use}):
		return
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
	if not _command_allowed("choose", {"action": action, "level": level}):
		return
	# A standing rule (Ask / Automatic / Off) changes on any turn for whoever the hotbar shows: nothing is spent.
	if action.has("policy"):
		if hud.shown != null:
			var rr := catalog.set_rule(hud.shown, action)
			if not rr.ok:
				hud.banner(rr.reason, 1.4)
			hud.refresh()
		return
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
	# Letting go of a spell can't be taken back: it asks first (_drop_concentration answers).
	if str(action["kind"]) == "drop_concentration":
		hud.confirm_drop_concentration("Stop concentrating on %s?" % (c.creature.concentration.name if c.creature.concentration != null else "it"))
		return
	if str(action["targeting"]) == "none" and not picker.takes(c, action):
		_perform(action, [], Vector2.INF, Vector2.ZERO)
		return
	# A wall starts its drawing, Crown of Madness's keep-control its victim (TargetPicker).
	selected = picker.begin(c, action, slot_level)
	picked = []
	picked_points = []
	mode = Mode.TARGET
	if str(action["kind"]) in ["spell", "item_spell"]:
		hud.set_pips(levels, slot_level)
	_show_target_marks()
	_update_hover()


func _cancel_targeting() -> void:
	picker.cancel()
	hud.hide_tooltip()
	selected = {}
	picked = []
	picked_points = []
	hud.set_pips([], 0)
	overlay.clear("target")
	overlay.clear("friendly")
	overlay.clear("area")
	overlay.clear_outline()
	overlay.clear("arc")   # a leap's or a throw's flight
	overlay.clear("arc_bad")
	if mode == Mode.TARGET:
		mode = Mode.IDLE


func _show_target_marks() -> void:
	var c := _player()
	var foes: Array = []
	var friends: Array = []
	if c == null or selected.is_empty() or picker.active() or str(selected["targeting"]) in ["point", "points", "direction"]:
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
	if not _command_allowed("perform", {"action": action, "targets": targets}):
		return
	var c := _player()
	if c == null:
		return
	mode = Mode.BUSY
	overlay.clear_all()
	hud.hide_tooltip()
	var r := catalog.perform(c, action, targets, point, dir, slot_level)
	slot_level = 0
	selected = {}
	picker.reset()
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


## Does what a pick after the first asked for (TargetPicker): the action with its picks, Maneuvering Attack's move,
## or a refusal to show; otherwise the picking goes on.
func _run_pick(cmd: Dictionary) -> void:
	match str(cmd.get("do", "")):
		"perform":
			_perform(cmd["action"] as Dictionary, cmd["targets"] as Array, cmd["point"] as Vector2, cmd["dir"] as Vector2)
			return
		"move":
			_reaction_move(cmd["ally"] as Combatant, cmd["cell"] as Vector2i)
			return
		"refuse":
			hud.banner(str(cmd["why"]), 1.4)
	_update_hover()


## Backspace or right-click while picking: takes back a wall's last square, or a second pick (TargetPicker). False
## when there was nothing to take back.
func _undo_pick() -> bool:
	if not _command_allowed("undo", {}):
		return false
	if mode != Mode.TARGET or not picker.undo():
		return false
	if not picker.active():
		overlay.clear("area")
		_show_target_marks()
	_update_hover()
	return true


## The floor marks and the tooltip a pick after the first asks for (TargetPicker.show).
func _show_pick(view: Dictionary, at: Vector2) -> void:
	for key: String in ["area", "target", "friendly", "goal", "danger"]:
		overlay.show_cells(key, view[key] as Array)
	# A spell's area already placed (Sculpt Spells, Slow's picks): its edge, as while it was aimed.
	if view.has("outline"):
		overlay.show_outline(view["outline"] as Dictionary, view.get("outline_cells", []) as Array)
	overlay.show_trail("path", view["trail"] as Array)
	hud.show_tooltip(str(view["title"]), view["lines"] as Array, view["warnings"] as Array, at)


## Maneuvering Attack's move: the ally picked walks to the square picked with its Reaction.
func _reaction_move(ally: Combatant, cell: Vector2i) -> void:
	mode = Mode.BUSY
	overlay.clear_all()
	hud.hide_tooltip()
	selected = {}
	picker.reset()
	var r := e.reaction_move(ally, cell)
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
	if not _command_allowed("board", {"cell": hover_cell, "target": t.combatant if t != null else null}):
		return
	if mode == Mode.TARGET:
		_confirm_target(c, t)
		return
	if mode != Mode.IDLE:
		return
	if t != null and t.combatant != c:
		if c.hostile_to(t.combatant):
			# A melee weapon in hand: walk up and swing when the movement left gets there (owner, 2026-10-12).
			var ma := catalog.melee_approach(c, t.combatant, _reach)
			if bool(ma["ok"]) and bool(ma["walk"]):
				_walk_and_strike(c, ma, t.combatant)
				return
			var a := ma["action"] as Dictionary if bool(ma["ok"]) else _default_attack(c, t.combatant)
			if a.is_empty():
				# Out of attacks says so, not that the foe is out of reach (owner, 2026-10-13).
				var why := catalog.attack_blocker(c, t.combatant)
				hud.banner(why if why != "" and not why.begins_with("Out of reach") else "No attack can reach %s from here" % t.combatant.name(), 1.6)
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
	var r := e.move(c, mp["dest"] as Vector2i)   # a square too far: as far toward it as the movement goes
	if not r.ok:
		hud.banner(r.reason, 1.4)
	await _play_events()
	if r.is_paused() or e.pending != null:
		mode = Mode.PROMPT
		_refresh_all()
		hud.show_prompt(e.pending)
		return
	_advance()


## A melee blow waiting on the walk up to its target (_walk_and_strike): {id, target, dest, action}, struck when the
## walk is over and the hero is in control again (_advance), a reaction prompt on the way included.
var _strike_after_walk := {}


## A click on a foe that a melee weapon in hand can't reach from here but the movement left can (owner, 2026-10-12):
## the hero walks up (the way that provokes the fewest Opportunity Attacks for the same feet), then swings.
func _walk_and_strike(c: Combatant, plan: Dictionary, t: Combatant) -> void:
	if not _command_allowed("perform", {"action": plan["action"], "targets": [t]}):
		return
	mode = Mode.BUSY
	overlay.clear_all()
	hud.hide_tooltip()
	var r := e.move(c, plan["dest"] as Vector2i)
	if r.ok:
		_strike_after_walk = {"id": c.id, "target": t.id, "dest": plan["dest"], "action": str((plan["action"] as Dictionary)["id"])}
	else:
		hud.banner(r.reason, 1.4)
	await _play_events()
	if r.is_paused() or e.pending != null:
		mode = Mode.PROMPT
		_refresh_all()
		hud.show_prompt(e.pending)
		return
	_advance()


## The blow a walk up was for (_walk_and_strike), if `c` stands where it meant to and can still make it; true when it
## goes ahead. Otherwise (stopped short, the foe down or out of reach) the turn is the player's again.
func _strike_after(c: Combatant) -> bool:
	var plan := _strike_after_walk
	_strike_after_walk = {}
	if plan.is_empty() or str(plan["id"]) != c.id or c.cell != (plan["dest"] as Vector2i):
		return false
	var t := e.get_c(str(plan["target"]))
	if t == null or not t.is_alive():
		return false
	for a in catalog.actions_for(c):
		if str(a["id"]) == str(plan["action"]) and bool(a["legal"]) and catalog.target_why(c, a, t) == "":
			_perform(a, [t], Vector2.INF, Vector2.ZERO)
			return true
	return false


## Right-click on a square on your turn: one menu with Move here and everything you could do to whoever is there.
var _menu_cell := Vector2i(-1, -1)
## The creature the square menu was opened on, when several share the square.
var _menu_who: Combatant = null
var _menu_items: Array[Dictionary] = []


func _open_square_menu(at: Vector2) -> bool:
	if not _command_allowed("square_menu", {}):
		return false
	var c := _player()
	if c == null or e.current() != c:
		return false
	_pick_from_mouse(at)
	var t := _target_under()
	var cell := t.combatant.cell if t != null else hover_cell
	if cell.x < 0:
		return false
	_menu_cell = cell
	_menu_who = t.combatant if t != null else null
	_menu_items = catalog.square_actions(c, cell, _reach, _menu_who)
	if _menu_items.is_empty():
		return false
	var o := _menu_who if _menu_who != null else e.occupant_at(cell)
	var shown: Array[Dictionary] = []
	for it in _menu_items:
		shown.append({"id": it["id"], "label": it["label"], "enabled": it.get("enabled", true), "why": it.get("why", "")})
	hud.hide_tooltip()
	var thing := e.objects.blocking_at(cell)
	hud.open_square_menu(o.name() if o != null else (thing.title() if thing != null else "This square"), shown, at)
	return true


## A right-click on a creature when there's no menu to open (another creature's turn): its Examine card.
func _examine_at(at: Vector2) -> bool:
	_pick_from_mouse(at)
	var t := _target_under()
	if t == null:
		return false
	hud.hide_tooltip()
	hud.show_examine(catalog.examine(_player() if _player() != null else hud.shown, t.combatant), t.combatant)
	return true


func _square_picked(id: String) -> void:
	var c := _player()
	if c == null or mode != Mode.IDLE:
		return
	var o := _menu_who if _menu_who != null and _menu_who.is_alive() and _menu_cell in _menu_who.footprint() else e.occupant_at(_menu_cell)
	if id == "move":
		hover_token = null
		hover_cell = _menu_cell
		_confirm_at()
		return
	if id == "info":
		if o != null:
			hud.show_examine(catalog.examine(c, o), o)
		return
	for it in _menu_items:
		# Picking something up needs no one standing there.
		if str(it["id"]) == id and it.has("action") and (o != null or str((it["action"] as Dictionary)["targeting"]) == "none"):
			# Commander's Strike and Crown of Madness go on to their second pick (TargetPicker).
			if o != null and picker.second(c, it["action"] as Dictionary, o, 0):
				selected = it["action"] as Dictionary
				mode = Mode.TARGET
				_update_hover()
				return
			_perform(it["action"] as Dictionary, [o] if o != null else [], Vector2.INF, Vector2.ZERO)
			return


func _confirm_target(c: Combatant, t: CombatToken) -> void:
	if not _command_allowed("target", {"target": t.combatant if t != null else null}):
		return
	if picker.active():
		_run_pick(picker.pick(hover_cell, t.combatant if t != null else null))
		return
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
			# A leap lands on the square pointed at (its arc showed it), not the nearest grid corner.
			if str(selected["kind"]) in ["long_jump", "jump"]:
				if hover_cell.x >= 0:
					_perform(selected, [], Vector2(hover_cell.x + 0.5, hover_cell.y + 0.5), Vector2.ZERO)
				return
			# Slow's creatures in the cube, or who an Evoker's Evocation spell with its own side in it shields, are picked
			# next (TargetPicker).
			var aim := _aim()
			if picker.sculpt(c, selected, aim["point"] as Vector2, aim["dir"] as Vector2, slot_level):
				_update_hover()
				return
			_perform(selected, [], aim["point"] as Vector2, aim["dir"] as Vector2)
		"place":
			# A square for the object (or teleport), or a creature to put it beside.
			var beside := t != null and t.combatant != c and c.hostile_to(t.combatant)
			# A teleport that can take a willing creature along (Thunder Step) asks who, once the square is picked.
			if str(selected.get("kind", "")) == "spell" and (beside or hover_cell.x >= 0):
				var landing := e.spells._beside(c, t.combatant) if beside else hover_cell
				if picker.bring_along(c, selected, Vector2(landing.x + 0.5, landing.y + 0.5), slot_level):
					_update_hover()
					return
			if beside:
				_perform(selected, [t.combatant], Vector2.INF, Vector2.ZERO)
			elif hover_cell.x >= 0:
				_perform(selected, [], Vector2(hover_cell.x + 0.5, hover_cell.y + 0.5), Vector2.ZERO)
		"direction":
			if picker.sculpt(c, selected, Vector2.INF, _aim_dir(c), slot_level):
				_update_hover()
				return
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
			need = maxi(need, int(selected.get("count", 1)))   # Eldritch Blast: one pick per beam
			if picked.size() >= need:
				_perform(selected, picked.duplicate(), Vector2.INF, Vector2.ZERO)
			else:
				hud.banner("%d of %d chosen · Enter to cast now" % [picked.size(), need], 1.2)
				_update_hover()
		_:
			if t == null:
				# An object's square (a crate, a door, a chandelier's chain, oil on the floor): aim at it instead.
				var aimed := e.objects.redirect(c, selected, hover_cell) if hover_cell.x >= 0 else {}
				if not aimed.is_empty():
					if not bool(aimed["legal"]):
						hud.banner(str(aimed["reason"]), 1.4)
						return
					_perform(aimed, [], Vector2.INF, Vector2.ZERO)
				return
			var why2 := catalog.target_why(c, selected, t.combatant)
			if why2 != "":
				hud.banner(why2, 1.4)
				return
			# Commander's Strike's ally and Crown of Madness's target take a second pick (TargetPicker).
			if picker.second(c, selected, t.combatant, slot_level):
				_update_hover()
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
	return _aim()["point"] as Vector2


## Where an area placed at a point goes (TargetPicker.aim): {point, dir}, its middle at the floor under the pointer, or
## at the middle of the figure the pointer is on (the floor behind a tall figure lies farther back).
func _aim() -> Dictionary:
	var at := Vector2(hover_world.x, hover_world.z)
	if hover_token != null and hover_token.combatant.is_alive():
		at = e.center_of(hover_token.combatant)
	return TargetPicker.aim(e, _player(), selected, at, slot_level)


## The way an area aimed from the caster points, toward the pointer: a Line, a Cone or Thunderwave's Cube at any angle
## (owner, 2026-10-12 for Lines, 2026-10-18 for the rest: "we should be able to aim them freely (not have it locked to
## certain boxes)"), settling on a row, column or diagonal within a hair of one (CombatGrid.line_aim).
func _aim_dir(c: Combatant) -> Vector2:
	var center := Vector2(c.cell.x + c.size_cells / 2.0, c.cell.y + c.size_cells / 2.0)
	var d := Vector2(hover_world.x, hover_world.z) - center
	if d.length() < 0.1:
		return Vector2(c.facing)
	return CombatGrid.line_aim(d)


## The step (degrees) a stick turns an area aimed from the caster in, so a steady thumb holds a steady aim.
const AIM_STEP_DEG := 1.0


## An area aimed from the caster on a pad (owner, 2026-10-12 for Lines, 2026-10-18 for cones and cubes): the left stick
## points it at any angle, in AIM_STEP_DEG steps, and the cursor goes to its far end (short of the board's edge), where
## its count and saves show and A casts it. The camera stays put.
func _pad_aim(c: Combatant, stick: Vector2, length_ft: int) -> void:
	var basis := rig.ground_basis()
	var world := basis[0] * -stick.y + basis[1] * stick.x
	var d := Vector2(world.x, world.z)
	if d.length() < 0.01:
		return
	d = Vector2.from_angle(snappedf(d.angle(), deg_to_rad(AIM_STEP_DEG)))
	var center := e.center_of(c)
	var reach := c.size_cells / 2.0 + length_ft / float(CombatGrid.FEET) - 0.5
	var p := center + d * reach
	while reach > 0.5 and not e.grid.in_bounds(Vector2i(floori(p.x), floori(p.y))):
		reach -= 0.25
		p = center + d * reach
	cursor_cell = Vector2i(clampi(floori(p.x), 0, e.grid.width - 1), clampi(floori(p.y), 0, e.grid.depth - 1))
	hover_cell = cursor_cell
	hover_world = Vector3(p.x, board.cell_center(cursor_cell).y, p.y)
	_hover_on_stack(cursor_cell)
	_update_hover()


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
		"Tactical":
			rig.tactical = not rig.tactical
		"Grid":
			_latch_grid()
		"End Turn":
			_end_turn()
		"Inspect":
			_cycle_inspect()


# --- The controller's wheels (owner pick 2026-10-09, after Baldur's Gate 3 on console) ------------------------------

## The page of the hotbar filter a wheel of actions shows.
var _wheel_page := 0


## Fills the wheel (LB held, Controller fights: Wheels) with the hotbar filter's slots, a page at a time, the last wedges
## always the tactical view and the battle grid.
func _open_wheel() -> void:
	var per := RadialMenu.PAGE - RadialMenu.TAIL
	var first := _wheel_page * per
	var items: Array[Dictionary] = []
	for i in range(first, mini(first + per, hud.slot_count())):
		var a := hud.slot_action(i)
		var usable := bool(a.get("legal", false)) and (e.current() == hud.shown or bool(a.get("toggle", false)))
		items.append({"label": str(a["label"]), "icon": UiParts.action_icon(a), "enabled": usable})
	items.append({"label": "Tactical view", "icon": Icons.feature("the_third_eye"), "enabled": true, "tactical": true})
	items.append({"label": "Battle grid", "icon": null, "enabled": GameSettings.battle_grid() != "never", "grid": true})
	var pages := maxi(1, ceili(hud.slot_count() / float(per)))
	hud.radial.open_items(items, "%s %d/%d" % [hud.tab, _wheel_page + 1, pages] if pages > 1 else hud.tab)


## A wedge of the wheel chosen: the tactical view, the battle grid, or the slot it holds used as its hotkey would.
func _wheel_picked(index: int) -> void:
	var item := hud.radial.items[index] if index < hud.radial.items.size() else {}
	if bool(item.get("tactical", false)):
		rig.tactical = not rig.tactical
		return
	if bool(item.get("grid", false)):
		_latch_grid()
		return
	hud.use_slot(_wheel_page * (RadialMenu.PAGE - RadialMenu.TAIL) + index)


## The controller's way to the battle grid, which the keyboard holds a key for: it stays on, round whoever's turn it is,
## until it is picked again or the fight ends (BattleGrid.latched).
func _latch_grid() -> void:
	if GameSettings.battle_grid() == "never" or not Look.modern():
		hud.banner("No battle grid in this look" if not Look.modern() else "The battle grid is off in Settings", 1.4)
		return
	overlay.lines.latched = not overlay.lines.latched
	hud.banner("Battle grid on" if overlay.lines.latched else "Battle grid off", 1.0)


func _cycle_inspect() -> void:
	# A shared turn: the next hero who can still take theirs.
	var sharing := e.shared_heroes()
	if sharing.size() > 1 and mode in [Mode.IDLE, Mode.TARGET]:
		_switch(sharing[1])
		return
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
	if not _command_allowed("input", {"event": event}):
		get_viewport().set_input_as_handled()
		return
	if _entrance_tw != null and _entrance_tw.is_valid() and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel")
			or event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		_entrance_tw.custom_step(BossBar.ENTRANCE)   # cuts the boss's entrance short
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_F1:
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
		# On a pad, A on one of the prompt's options picks that option (the engine presses it): it isn't Use Reaction.
		if event.is_action_pressed(&"combat_confirm") and not (event is InputEventJoypadButton and hud.prompt_option_focused()):
			hud.answer_prompt(true)
		elif event.is_action_pressed(&"combat_cancel"):
			hud.answer_prompt(false)
		get_viewport().set_input_as_handled()
		return
	if hud.confirm_open():
		if hud.confirm_kind() == "drop_concentration":
			# Enter lets go; Space (End Turn) is not a yes to this one; Esc keeps the spell.
			if event.is_action_pressed(&"combat_confirm"):
				hud.close_confirm()
				_drop_concentration()
			elif event.is_action_pressed(&"combat_cancel"):
				hud.close_confirm()
		elif event.is_action_pressed(&"combat_end_turn") or event.is_action_pressed(&"combat_confirm"):
			hud.close_confirm()
			_end_turn()
		elif event.is_action_pressed(&"combat_cancel"):
			hud.close_confirm()
			_confirmed_end = false
		return
	# Holding the radial, Y hides or shows the action bar (the H key on a pad; Y alone still ends the turn).
	if hud.radial.visible and event is InputEventJoypadButton and event.is_action_pressed(&"combat_end_turn"):
		hud.toggle_actions()
		get_viewport().set_input_as_handled()
		return
	if pad.handle(event):   # the pad's menu, controls, undo, square menu and death saves (U6)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and hud.hide_details():
		return
	if event.is_action_pressed(&"combat_radial"):
		if GameSettings.pad_wheels():
			_wheel_page = 0
			_open_wheel()
		else:
			hud.radial.open()
		return
	# While the radial is held, Next target looks along the turn order instead (the portraits' click on a pad).
	if hud.radial.visible and event.is_action_pressed(&"combat_next_target"):
		_look_along_order()
		get_viewport().set_input_as_handled()
		return
	# The right bumper, still holding the radial, looks back along it (it uses a hotbar slot otherwise).
	if hud.radial.visible and event is InputEventJoypadButton and event.is_action_pressed(&"combat_use_slot"):
		_look_along_order(-1)
		get_viewport().set_input_as_handled()
		return
	# While a wheel of actions is open the D-pad changes its filter (up and down) and its page (left and right).
	if hud.radial.visible and not hud.radial.items.is_empty() and event is InputEventJoypadButton and event.is_pressed():
		var jb := event as InputEventJoypadButton
		if jb.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			hud.cycle_tab(-1 if jb.button_index == JOY_BUTTON_DPAD_UP else 1)
			_wheel_page = 0
			_open_wheel()
			get_viewport().set_input_as_handled()
			return
		if jb.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			var pages := maxi(1, ceili(hud.slot_count() / float(RadialMenu.PAGE - RadialMenu.TAIL)))
			_wheel_page = posmod(_wheel_page + (-1 if jb.button_index == JOY_BUTTON_DPAD_LEFT else 1), pages)
			_open_wheel()
			get_viewport().set_input_as_handled()
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
			if mode != Mode.TARGET and _examine_at(mb.position):
				return
			if not _undo_pick():
				_cancel_targeting()
				_update_hover()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_BACKSPACE:
		_undo_pick()
	elif event.is_action_pressed(&"combat_confirm"):
		if using_pad or not confirm_early():
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
		hud.use_slot(hud.focus_slot)   # a container opens its choices, a toggle steps on
	elif event.is_action_pressed(&"combat_next_target"):
		_next_target()
	elif event.is_action_pressed(&"combat_slot_level_down") or event.is_action_pressed(&"combat_slot_level_up"):
		_change_slot(-1 if event.is_action_pressed(&"combat_slot_level_down") else 1)
	elif event.is_action_pressed(&"cycle_leader"):
		_cycle_inspect()
	elif event.is_action_pressed(&"combat_toggle_log"):
		hud.toggle_log()
	elif event.is_action_pressed(&"combat_toggle_hud"):
		hud.toggle_actions()
	else:
		for i in 10:
			if event.is_action_pressed(StringName("combat_slot_%d" % (i + 1))):
				hud.use_slot(i)
				return


## Casts what's being aimed with the targets picked so far (Enter; Y on a pad). False when nothing is being picked.
func confirm_early() -> bool:
	if not _command_allowed("confirm_spell", {}):
		return false
	if mode == Mode.TARGET and str(selected.get("targeting", "")) == "multi" and not picked.is_empty():
		_perform(selected, picked.duplicate(), Vector2.INF, Vector2.ZERO)
	elif mode == Mode.TARGET and picker.active():
		_run_pick(picker.confirm())
	else:
		return false
	return true


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
		# The caster itself only when a pick takes it (Sculpt Spells shielding the Evoker).
		if o == c and not (mode == Mode.TARGET and picker.active() and picker.candidate(o)) or o.is_down() and str(selected.get("targeting", "")) != "dying":
			continue
		if mode == Mode.TARGET and picker.active():
			if not picker.candidate(o):
				continue
		elif mode == Mode.TARGET and catalog.target_why(c, selected, o) != "":
			continue
		if mode != Mode.TARGET and not c.hostile_to(o):
			continue
		if e.sight.hidden_from_party(o, viewer):
			continue
		list.append(o)
	if list.is_empty():
		return
	# Those sharing a square are the same distance: the fight's order breaks the tie, so the next press is always the next one.
	list.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		var da := e.distance(c, a)
		var db := e.distance(c, b)
		return da < db or (da == db and e.combatants.find(a) < e.combatants.find(b)))
	_target_cycle = (_target_cycle + 1) % list.size()
	cursor_cell = list[_target_cycle].cell
	using_pad = true
	pad.follow_cursor = true
	_pad_hover(list[_target_cycle])


func _process(delta: float) -> void:
	if input_locked:
		return
	if hud.radial.visible:
		hud.radial.aim(Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)))
	# Controller cursor: the left stick steps it a square at a time, or points an area aimed from the caster.
	var stick := Input.get_vector(&"cursor_left", &"cursor_right", &"cursor_up", &"cursor_down")
	var reach := 0
	if stick.length() > 0.5 and mode == Mode.TARGET and _player() != null and not picker.active() \
			and str(selected.get("targeting", "")) == "direction":
		reach = catalog.aim_ft(_player(), selected)
	if reach > 0:
		using_pad = true
		_pad_repeat = 0.0
		_pad_aim(_player(), stick, reach)
	elif stick.length() > 0.5:
		using_pad = true
		_pad_repeat -= delta
		if _pad_repeat <= 0.0:
			_pad_repeat = 0.16
			var basis := rig.ground_basis()
			var world := basis[0] * -stick.y + basis[1] * stick.x
			var step := Vector2i(roundi(world.x), roundi(world.z))
			cursor_cell = Vector2i(clampi(cursor_cell.x + step.x, 0, e.grid.width - 1), clampi(cursor_cell.y + step.y, 0, e.grid.depth - 1))
			pad.follow_cursor = true
			_pad_hover()
	else:
		_pad_repeat = 0.0
	pad.tick(delta)
	# Camera pan with WASD / arrows (the camera stops following until the next turn); on a pad it follows the cursor.
	var pan := Vector2.ZERO if using_pad else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if pan.length() > 0.1:
		var b := rig.ground_basis()
		rig.follow = null
		rig.global_position += (b[0] * -pan.y + b[1] * pan.x) * delta * 9.0


func _pad_hover(prefer: Combatant = null) -> void:
	hover_cell = cursor_cell
	hover_world = board.cell_center(cursor_cell) if e.grid.in_bounds(cursor_cell) else Vector3.ZERO
	_hover_on_stack(cursor_cell, prefer)
	rig.follow = null
	rig.global_position = rig.global_position.lerp(hover_world, 0.35)
	_update_hover()


# --- Picking and previews -------------------------------------------------------------------------

## The creatures the party can see standing in `cell`, in the fight's order: several where creatures share a square
## (heroes, and foes since 2026-10-19). One the party can't see (Invisible) isn't one of them, so it neither shows in the
## square nor shifts the figures that do.
func _stack_at(cell: Vector2i) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in e.movement.occupants_at(cell):
		if not e.sight.hidden_from_party(o, viewer):
			out.append(o)
	return out


## The pad cursor's token on `cell`: `prefer` if it stands there, else the one it was on if it still does (so the cursor
## doesn't hop about a stack), else the first. None for an empty square.
func _hover_on_stack(cell: Vector2i, prefer: Combatant = null) -> void:
	var here := _stack_at(cell)
	var was: Combatant = hover_token.combatant if hover_token != null and hover_token.combatant != null else null
	hover_token = null
	var pick: Combatant = null
	if prefer != null and prefer in here:
		pick = prefer
	elif was != null and was in here:
		pick = was
	elif not here.is_empty():
		pick = here[0]
	if pick != null:
		hover_token = tokens.get(pick.id) as CombatToken


## What a tooltip says of the creature under the pointer when others share its square, to add to its lines: who, and the
## button that moves the cursor on to the next of them.
func _stack_note(o: Combatant) -> Array:
	var others: Array[String] = []
	for x in _stack_at(o.cell):
		if x != o:
			others.append(x.name())
	if others.is_empty():
		return []
	var button := PadGlyphs.words(InputActions.fill("{combat_next_target}"), "{@combat_next_target}")
	return ["Shares the square with %s · %s for the next" % [" and ".join(others), button]]

func _pick_from_mouse(screen: Vector2) -> void:
	var cam := rig.camera
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	hover_token = _token_on_ray(origin, dir)
	hover_cell = Vector2i(-1, -1)
	if board.shaped():
		# Natural ground's slopes, raised props' tops (GridPick.ground_hit).
		var hit: Variant = GridPick.ground_hit(board, origin, dir)
		if hit != null:
			hover_world = hit as Vector3
			hover_cell = Vector2i(floori(hover_world.x), floori(hover_world.z))
		return
	for h: float in GridPick.planes():
		if absf(dir.y) < 0.0001:
			break
		var t := (h - origin.y) / dir.y
		if t < 0.0:
			continue
		var p := origin + dir * t
		var cell := Vector2i(floori(p.x), floori(p.z))
		if not e.grid.in_bounds(cell):
			continue
		if GridPick.on_plane(e.grid, cell, h):
			hover_cell = cell
			hover_world = p
			break


func _token_on_ray(origin: Vector3, dir: Vector3) -> CombatToken:
	var best: CombatToken = null
	var best_t := INF
	for id: String in tokens:
		var tok := tokens[id] as CombatToken
		if not tok.combatant.is_alive() or tok.unseen:
			continue
		var base := tok.global_position
		var height := CombatToken.height_of(tok.combatant)
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
		var here := _stack_at(hover_cell)
		if not here.is_empty():
			return tokens.get(here[0].id) as CombatToken
	return null


func _update_hover() -> void:
	var c := _player()
	if not _aiming_area():
		hud.hide_area_saves()   # the area panel lives only while an area spell is aimed
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
	# Aiming an area placed at a point, its outline is the cursor: its middle is under the pointer.
	var placing := _aiming_area() and str(selected.get("targeting", "")) == "point"
	overlay.show_cells("cursor", [hover_cell] if hover_cell.x >= 0 and not placing else [])
	var at := get_viewport().get_mouse_position() if not using_pad else rig.camera.unproject_position(hover_world + Vector3(0, 0.5, 0))
	var t := _target_under()
	if mode == Mode.TARGET:
		_target_hover(c, t, at)
		return
	# Idle: what a click would do. Nothing is lit until the pointer asks: the floor shows a walk only to where it points.
	if t != null and t.combatant != c:
		var o := t.combatant
		if c.hostile_to(o):
			# A melee weapon in hand and the foe within the movement left: the walk up drawn like a move, then the blow's
			# odds as seen from where it ends (owner, 2026-10-12).
			var ma := catalog.melee_approach(c, o, _reach)
			if bool(ma["ok"]) and bool(ma["walk"]):
				var warns := ma["warnings"] as Array
				var provokes := false
				for w: String in warns:
					provokes = provokes or w.contains("Opportunity")
				overlay.show_trail("path", ma["path"] as Array)
				overlay.show_cells("danger" if provokes else "goal", [ma["dest"]])
				var wpv := ma["preview"] as Dictionary
				var wlines: Array = ["Walk %d ft up, then attack · %d ft left after" % [int(ma["cost"]), int(ma["left"])]]
				wlines.append_array(wpv["lines"] as Array)
				wlines.append_array(_stack_note(o))
				hud.show_tooltip(str(wpv["title"]), wlines, warns, at, str(wpv.get("edge", "")))
				_show_odds(wpv, o)
				return
			var a := ma["action"] as Dictionary if bool(ma["ok"]) else _default_attack(c, o)
			if a.is_empty():
				var first := {}
				for x in catalog.actions_for(c):
					if str(x["kind"]) == "attack":
						first = x
						break
				var pv0 := catalog.attack_preview(c, first, o) if not first.is_empty() else {"title": o.name(), "lines": []}
				var why0 := catalog.attack_blocker(c, o)
				hud.show_tooltip(str(pv0["title"]), (pv0["lines"] as Array) + _stack_note(o), [why0 if why0 != "" else "Out of reach: move closer, or pick a ranged attack"], at)
			else:
				var pv := catalog.attack_preview(c, a, o)
				hud.show_tooltip(str(pv["title"]), (pv["lines"] as Array) + _stack_note(o), [], at, str(pv.get("edge", "")))
				_show_odds(pv, o)
		else:
			var about: Array = ["HP %d/%d · AC %d" % [o.creature.hp, o.creature.max_hp(), o.creature.ac_value()], hud._chips(o)]
			about.append_array(e.ground.describe_at(o.cell))
			about.append_array(_stack_note(o))
			hud.show_tooltip(o.name(), about, [], at)
		return
	# What lies on the square (GroundItems), and what hangs or burns there (EncounterObjects), is named under whatever
	# else the tooltip says; a door or a crate filling it has a card of its own.
	var lying: Array = []
	if hover_cell.x >= 0:
		lying.append_array(e.ground.describe_at(hover_cell))
		lying.append_array(e.objects.describe_at(hover_cell))
		var card := e.objects.tooltip(hover_cell)
		if not card.is_empty():
			hud.show_tooltip(str(card["title"]), card["lines"] as Array, [], at)
			return
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
		overlay.show_cells("danger" if provokes else "goal", [mp["dest"]])
		var head := ("Move %d ft toward there · %d ft left after" if bool(mp["partial"]) else "Move %d ft · %d ft left after") % [int(mp["cost"]), int(mp["left"])]
		hud.show_tooltip(head, lying, mp["warnings"] as Array, at)
	else:
		hud.show_tooltip(str(mp["reason"]), lying, [], at)


## A leap being aimed: the arc from `c` to the square pointed at, a ring where it lands (red when it can't), and the
## tooltip with the feet it costs and what's left.
func _jump_hover(c: Combatant, at: Vector2) -> void:
	if hover_cell.x < 0:
		overlay.clear("goal")
		hud.show_tooltip(str(selected["label"]), ["Choose where to land (%d ft at most)" % int(selected.get("range", 0))], [], at)
		return
	var feet := e.grid.distance_ft(c.cell, c.size_cells, hover_cell, c.size_cells)
	var why := e.movement.leap_why(c, hover_cell)
	if why == "" and feet > int(selected.get("range", 0)):
		why = "Too far: %d ft at most" % int(selected.get("range", 0))
	var to := board.cell_center(hover_cell, c.size_cells) + Vector3(0, 0.05, 0)
	overlay.show_arc("arc" if why == "" else "arc_bad", board.cell_center(c.cell, c.size_cells) + Vector3(0, 0.05, 0), to)
	overlay.show_cells("goal" if why == "" else "danger", [hover_cell])
	var cost := feet if str(selected["kind"]) == "long_jump" else 10
	var lines: Array = ["Leap %d ft over whatever is between" % feet, "Costs %d ft · %d ft left after" % [cost, maxi(0, c.movement_left - cost)]] if why == "" else [why]
	hud.show_tooltip(str(selected["label"]), lines, [], at)


## About chest height on a creature's figure, where a throw leaves or lands.
func _chest(c: Combatant) -> Vector3:
	var tok := tokens.get(c.id) as CombatToken
	var base := tok.global_position if tok != null else board.cell_center(c.cell, c.size_cells)
	return base + Vector3(0, CombatToken.height_of(c) * 0.6, 0)


## The odds of an attack over its target's head (CombatHud.show_odds), when the attack can be made.
func _show_odds(pv: Dictionary, o: Combatant) -> void:
	var tok := tokens.get(o.id) as CombatToken
	if tok == null or not bool(pv.get("legal", false)):
		return
	var head := tok.global_position + Vector3(0, CombatToken.height_of(o) + 0.45, 0)
	hud.show_odds(float(pv.get("chance", 0.0)), str(pv.get("damage", "")), str(pv.get("edge", "")), rig.camera.unproject_position(head))


## Whether the pointer is aiming an area spell at a point or in a direction (the area panel shows its saves).
func _aiming_area() -> bool:
	if mode != Mode.TARGET or picker.active() or str(selected.get("kind", "")) in ["long_jump", "jump"]:
		return false
	var kind := str(selected.get("targeting", ""))
	return kind == "direction" or (kind == "point" and str(selected.get("kind", "")) != "feat") or _boom_round_leaving()


## Whether the teleport being aimed leaves an area behind it (Thunder Step's boom round the space it leaves): the area
## panel then shows who the boom would catch.
func _boom_round_leaving() -> bool:
	if str(selected.get("targeting", "")) != "place" or str(selected.get("kind", "")) != "spell":
		return false
	var data := Compendium.shared().spell_data(str(selected.get("spell_id", "")))
	return data.has("area") and SpellTargeting.area_from_caster(data)


func _target_hover(c: Combatant, t: CombatToken, at: Vector2) -> void:
	if picker.active():
		overlay.clear_outline()   # a wall drawn square by square shows its squares
		_show_pick(picker.show(hover_cell, t.combatant if t != null else null), at)
		return
	var kind := str(selected["targeting"])
	overlay.clear("arc")
	overlay.clear("arc_bad")
	# A leap (Long Jump, the Jump spell): its arc to the square pointed at, the landing ringed, the feet it costs.
	if str(selected["kind"]) in ["long_jump", "jump"]:
		_jump_hover(c, at)
		return
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
		# Placed at a point, its middle under the pointer, as it's cast (TargetPicker.aim: a Cube's face and direction,
		# a Tsunami's run across the line from the caster).
		var aim := _aim() if kind == "point" else {"point": _aim_point(), "dir": _aim_dir(c)}
		var pv := catalog.spell_preview(c, selected, aim["point"] as Vector2, aim["dir"] as Vector2, slot_level)
		# The area's edge, round for a radius, and no orange squares (owner, 2026-10-12: "for AoE spells, don't make the
		# floor orange. Instead show a circular border which shows the area that would be affected").
		overlay.show_outline(pv["outline"] as Dictionary, pv["cells"] as Array)
		# Who it catches and their saves go in the panel at the top left (owner, 2026-10-12); by the pointer, a count.
		var caught := pv["creatures"] as Array
		var friends := caught.filter(func(w: Dictionary) -> bool: return bool(w["ally"]) and not bool(w["safe"])).size()
		var count := ("%d in the area%s" % [caught.size(), (" (%d %s)" % [friends, "friend" if friends == 1 else "friends"]) if friends > 0 else ""]) \
			if not caught.is_empty() else "No one in the area"
		var title := "%s · %s" % [selected["label"], "slot level %d" % int(pv["slot"]) if int(pv["slot"]) > 0 else "cantrip"]
		hud.show_tooltip(title, [count], [], at)
		hud.show_area_saves(title, ("%s save DC %d" % [pv["save"], int(pv["dc"])]) if str(pv["save"]) != "" else "", caught, pv["warnings"] as Array)
		return
	if kind == "place" and (t == null or not c.hostile_to(t.combatant)):
		var rng := int(selected.get("range", 0))
		# Measured from an Echo Knight's echo when the action moves it.
		var src := e.get_c(str(selected.get("from", "")))
		if src == null:
			src = c
		var ok := hover_cell.x >= 0 and e.grid.distance_ft(src.cell, src.size_cells, hover_cell, 1) <= rng
		overlay.show_cells("area", [hover_cell] if hover_cell.x >= 0 else [])
		var place_lines: Array = ["Click a square to place it (or an enemy to put it beside them)" if ok else "Out of range (%d ft)" % rng]
		# The boom round the space it leaves (Thunder Step): its edge, and who it catches in the area panel.
		if _boom_round_leaving():
			var boom := catalog.spell_preview(c, selected, Vector2.INF, Vector2.ZERO, slot_level)
			overlay.show_outline(boom["outline"] as Dictionary, boom["cells"] as Array)
			var caught_by := boom["creatures"] as Array
			var boom_title := "%s · slot level %d" % [selected["label"], int(boom["slot"])]
			place_lines.append(("%d caught in the boom" % caught_by.size()) if not caught_by.is_empty() else "No one near enough to hear it")
			hud.show_area_saves(boom_title, ("%s save DC %d" % [boom["save"], int(boom["dc"])]) if str(boom["save"]) != "" else "", caught_by, boom["warnings"] as Array)
		hud.show_tooltip(str(selected["label"]), place_lines, [], at)
		return
	if t == null:
		# An object's square: the chosen attack or spell aimed at it (EncounterObjects.redirect).
		var aimed := e.objects.redirect(c, selected, hover_cell) if hover_cell.x >= 0 else {}
		if not aimed.is_empty():
			var thing_lines: Array = []
			for ob in e.objects.objects_at(hover_cell):
				thing_lines.append_array(ob.describe())
			hud.show_tooltip(str(aimed["label"]), thing_lines, [str(aimed["reason"])] if not bool(aimed["legal"]) else [], at)
			return
		var hint := "Choose a target"
		if kind == "multi":
			hint = "Choose targets (%d chosen) · Enter casts now" % picked.size()
		hud.show_tooltip(str(selected["label"]), [hint], [], at)
		return
	var o := t.combatant
	if str(selected["kind"]) in ["attack", "offhand"]:
		var pv2 := catalog.attack_preview(c, selected, o)
		hud.show_tooltip(str(pv2["title"]), (pv2["lines"] as Array) + _stack_note(o), [], at, str(pv2.get("edge", "")))
		_show_odds(pv2, o)
		# A throw: its arc to the target, red when it can't be made.
		if selected.has("group") and str(selected["group"]) == "Throw":
			overlay.show_arc("arc" if bool(pv2.get("legal", false)) else "arc_bad", _chest(c), _chest(o))
		return
	var why := catalog.target_why(c, selected, o)
	var lines2: Array = ["HP %d/%d · AC %d" % [o.creature.hp, o.creature.max_hp(), o.creature.ac_value()]]
	var tip_title := o.name()
	var edge := ""   # a spell attack's Advantage or Disadvantage, for the box's outline
	if str(selected["kind"]) in ["spell", "item_spell"]:
		var data := Compendium.shared().spell_data(str(selected["spell_id"]))
		var prev := catalog.cast_preview(c, selected, slot_level)
		if data.has("attack") and prev.has("attack"):
			# The odds from the situation the roll uses (Spell Sniper, cover a spell ignores), the caster's own edge too.
			var spv := catalog.spell_attack_preview(c, str(selected["spell_id"]), o, prev["attack"] as Breakdown)
			lines2.append_array(spv["lines"] as Array)
			edge = str(spv["edge"])
			if edge != "":
				tip_title = "%s · %s" % [o.name(), edge.to_upper()]
		if data.has("save") and prev.has("save_dc"):
			var ab := StringName(str(data["save"]))
			var bonus := o.creature.save_bonus(ab).total()
			var dc := (prev["save_dc"] as Breakdown).total()
			lines2.append("%s save DC %d: fails %d%%" % [Creature.ABILITY_SHORT[ab], dc, roundi(clampf((dc - bonus - 1) / 20.0, 0.0, 1.0) * 100.0)])
			var immune_note := catalog.condition_immunity_note(str(selected["spell_id"]), o)
			if immune_note != "":
				lines2.append(immune_note)
		if prev.has("damage_dice"):
			lines2.append("Damage %s %s%s" % [prev["damage_dice"], str(prev.get("damage_type", "")).capitalize(), " " + (prev["damage_bonus"] as Breakdown).signed() if (prev["damage_bonus"] as Breakdown).total() != 0 else ""])
		if prev.has("heal_dice"):
			lines2.append("Heals %s %+d" % [prev["heal_dice"], (prev["heal_bonus"] as Breakdown).total()])
	if kind == "multi":
		lines2.append("Chosen: %d" % picked.count(o))
	lines2.append_array(_stack_note(o))
	hud.show_tooltip(tip_title, lines2, [why] if why != "" else [], at, edge)


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


## A spell `caster` just cast that it now concentrates on: a soft cue after the spell's own sound.
func _concentration_begins(caster: CombatToken, spell_id: String) -> void:
	if caster == null:
		return
	var conc := caster.combatant.creature.concentration
	if conc == null or conc.ended or conc.source_id != spell_id:
		return
	_concentrating[caster.combatant.id] = spell_id
	get_tree().create_timer(0.4 * GameSettings.combat_pace()).timeout.connect(func() -> void: CombatSfx.concentration(true))


## `c` was hit or fell: if that ended the spell it was concentrating on, the sound of it breaking.
func _concentration_kept(c: Combatant) -> void:
	if not _concentrating.has(c.id):
		return
	var conc := c.creature.concentration
	if conc != null and not conc.ended and conc.source_id == str(_concentrating[c.id]):
		return
	_concentrating.erase(c.id)
	CombatSfx.concentration(false)
	moment_shown.emit("concentration", c.id)


## Where a token stands: its square's centre (a little to one side when heroes share it), raised onto the mount's back
## for a rider, and as high off the floor as it flies (1 unit = 5 ft).
func _token_spot(c: Combatant, cell: Vector2i) -> Vector3:
	var p := board.cell_center(cell, c.size_cells) + _share_offset(c, cell)
	var m := e.mount_of(c)
	if m != null:
		# The mount's figure as drawn: its height is already its size's (a Large horse 1.7), grown or shrunk by a spell.
		var mt := tokens.get(m.id) as CombatToken
		var h := CombatToken.height_of(m) * (mt.size_scale().y if mt != null else 1.0)
		p = board.cell_center(m.cell, m.size_cells) + Vector3(0, h * 0.8, 0)
	return p + Vector3(0, c.altitude / float(CombatGrid.FEET), 0)


## Creatures sharing a square (owner, 2026-10-12: heroes may end a move in an ally's space) stand side by side on it as
## the camera looks, in the fight's order, so each figure shows and can be pointed at. Zero for a creature alone there.
func _share_offset(c: Combatant, cell: Vector2i) -> Vector3:
	if e.mount_of(c) != null:
		return Vector3.ZERO
	var here: Array[Combatant] = []
	for o in e.combatants:
		if o == c or (o.is_alive() and o.cell == cell and o.size_cells == c.size_cells and e.mount_of(o) == null and e.rider_of(c) != o \
				and not e.sight.hidden_from_party(o, viewer)):
			here.append(o)
	if here.size() < 2:
		return Vector3.ZERO
	var right := rig.ground_basis()[1] if rig != null else Vector3(1, 0, 0)
	return right * (here.find(c) - (here.size() - 1) / 2.0) * 0.38 * c.size_cells


## After the events: tokens whose square is now shared, or no longer is, step to their place on it.
func _settle_shared() -> void:
	for id: String in tokens:
		var tok := _tok(id)
		if tok == null or not tok.visible or tok.combatant == null or not tok.combatant.is_alive():
			continue
		var to := _token_spot(tok.combatant, tok.combatant.cell)
		var off := Vector2(to.x - tok.position.x, to.z - tok.position.z).length()
		if off > 0.02 and off < 0.75 and absf(to.y - tok.position.y) < 0.05:
			create_tween().tween_property(tok, "position", to, STEP_TIME * GameSettings.combat_pace())


func _play_events() -> void:
	var events := e.drain_events()
	await _dice_moments(events)
	if _closed or not is_inside_tree():
		return
	_log_held = true
	var walking: Dictionary = {}
	# Who just played their attack as a spell gesture: the spell's own attack rolls that follow don't replay it.
	var cast_by := ""
	var ev_at := -1   # where `ev` is in `events`, for what follows it
	# Where the fight's last foe falls in these events (slow motion on the blow that does it), and whether it played.
	var final_fall := CombatImpact.last_fall(e, events)
	var final_played := false
	# A big spell's camera turn holds until its damage has shown (the next blow, move or turn).
	var turned_until := -1
	for ev in events:
		ev_at += 1
		if turned_until >= 0 and ev_at >= turned_until:
			turned_until = -1
			impact.spell_landed()
		if _closed:
			return   # the story took the fight back mid-way: its tokens may be gone
		var kind := str(ev["type"])
		match kind:
			"move":
				# A push or a pull the spell itself makes between its beams (Repelling Blast, Grasp of Hadar) doesn't end the
				# volley: the beams after it still fly (Ashwin, 2026-10-23: they showed no animation).
				if not bool(ev.get("forced", false)):
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
			"object_attack", "object_throw", "object_damage", "object_broken", "object_fall", "object_door", "object_move", "object_topple", "object_burst":
				_stop_walking(walking)
				await objects_view.play(ev, e.objects, tokens, fx)
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
					if bool(ev["hit"]):
						var struck: Array[CombatToken] = [d]
						final_played = _impact_on(struck, events, ev_at, final_fall, bool(ev.get("critical", false))) or final_played
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
					moment_shown.emit("damage", t.combatant.id)
					# A hero's Concentration save shows after the damage (the "save" event next), and settles then;
					# a foe's, which has no roll to show, is told by the sound once the number has been seen.
					if not _save_follows(events, ev_at, t.combatant.id):
						_concentration_kept(t.combatant)
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
					tc.set_unseen(e.sight.hidden_from_party(tc.combatant, viewer))   # an Invisibility cast or broken
					if kind in ["down", "death"]:
						_concentration_kept(tc.combatant)
					if ev_at == final_fall and not final_played:
						# The last foe fell to something that wasn't a blow played above (an aura, a turn's damage).
						final_played = true
						impact.hit(tc, 0, 1, false, true, true)
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
					impact.spell_cast(str(ev["spell"]), caster.global_position, _spell_spot(ev, caster))
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
				_concentration_begins(caster, str(ev["spell"]))
				var landed_on: Array[CombatToken] = []
				final_played = _impact_on(landed_on, events, ev_at, final_fall, false) or final_played
				var cells := ev.get("cells", []) as Array
				if not cells.is_empty():
					overlay.show_outline(ev.get("outline", {}) as Dictionary, cells)
					await get_tree().create_timer(0.45 * GameSettings.combat_pace()).timeout
					overlay.clear_outline()
				turned_until = CombatImpact.window_end(events, ev_at)
			"ability":
				# A class feature or a monster's save action (Second Wind, a breath, a wail): its effect, if it has one.
				_stop_walking(walking)
				var ab := _tok(str(ev["by"]))
				var acu := SpellFx.ability_cue(str(ev.get("source", "")), str(ev["key"]), ab.combatant) if SpellFx.enabled and ab != null else {}
				if acu.is_empty() and str(ev.get("source", "")) == "feature":
					CombatSfx.feature(str(ev["key"]))   # Bladesong, Vow of Enmity: a sound as it switches on
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
				var touched: Array[CombatToken] = []
				final_played = _impact_on(touched, events, ev_at, final_fall, false) or final_played
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
						tt.scale = tt.size_scale()
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
					if str(ev.get("becomes", "")) != "" and SpellFx.enabled:
						fx.shape_settle(nt, str(ev["becomes"]))   # a cursed creature's change, begun at its vanishing
					else:
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
				_stop_walking(walking)   # its figure is about to be swapped, and a freed token can't be told to stand
				await _swap_form_art(str(ev["id"]), str(ev.get("art", "")), str(ev.get("kind", "")))
			"shape":
				_stop_walking(walking)
				await _swap_shape_art(str(ev["id"]), str(ev.get("art", "")), str(ev.get("kind", "")))
			"vanish":
				var vt := _tok(str(ev["id"]))
				if str(ev.get("narration", "")) != "" and vt != null:
					_narrate(str(ev["narration"]), null, vt.combatant)
				if str(ev.get("say", "")) != "":
					# Its parting line (Strahd leaving a visit, owner 2026-10-13): spoken as it goes, and the fight waits for
					# it, so it doesn't end on a cut.
					hud.refresh_log()
					var secs := VoiceOver.say(str(ev.get("speaker", "")), str(ev["say"]))
					if secs > 0.0:
						barks.hush()
					await get_tree().create_timer(maxf(secs, 2.0) + 0.3).timeout
					if _closed or not is_inside_tree():
						return
				if vt != null and str(ev.get("becomes", "")) != "" and SpellFx.enabled and vt.visible:
					# It turns into something else (the lycanthropy curse): it changes where it stands, and the new
					# creature arrives in its place (summon_creature).
					_stop_walking(walking)
					await fx.shape_gather(vt, str(ev["becomes"]))
					if _closed or not is_inside_tree():
						return
					vt.hide()
				elif vt != null and str(ev.get("left", "")) == "fell":
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
			"altitude":
				# Rising or sinking where it stands (F4): the token glides to the height the event names.
				var at := _tok(str(ev["id"]))
				if at != null:
					var spot := _token_spot(at.combatant, at.combatant.cell)
					spot.y += (int(ev["to"]) - at.combatant.altitude) / float(CombatGrid.FEET)
					var up := create_tween()
					up.tween_property(at, "position", spot, STEP_TIME * GameSettings.combat_pace())
					await up.finished
				_show_heights()
			"resize":
				var rt := _tok(str(ev["id"]))
				if rt != null:
					var tw4 := create_tween()
					tw4.tween_property(rt, "scale", rt.size_scale(), 0.3)
					rt.position = board.cell_center(rt.combatant.cell, rt.combatant.size_cells)
			"turn":
				cast_by = ""
				fx.end_volley()
				_stop_walking(walking)
				_refresh_all()
				var tn := _tok(str(ev["id"]))
				if tn != null:
					barks.bark(tn.combatant, "battle")   # a kind of enemy cries out the first time one acts
				for cid: Variant in _concentrating.keys():
					var cc := e.get_c(str(cid))
					if cc == null or cc.creature.concentration == null or cc.creature.concentration.ended:
						_concentrating.erase(cid)   # it ran out or was let go: nothing breaks
			"switch":
				_stop_walking(walking)
				_refresh_all()   # control passed to another hero of a shared turn
			"round":
				if not _opening:   # the opening beat shows "Roll Initiative", then round 1
					hud.banner("Round %d" % int(ev["round"]), 1.0)
				round_started.emit(int(ev["round"]))
			"over":
				_refresh_all()
			"save":
				# A hero's saving throw, where it came in the action: after the blow and damage before it.
				_stop_walking(walking)
				await _show_save(ev)
				if _closed or not is_inside_tree():
					return
	impact.spell_landed()
	_stop_walking(walking)
	_settle_shared()
	_log_held = false
	_refresh_all()
	if not _closed and is_inside_tree() and events_presented.has_connections():
		events_presented.emit(events.duplicate(true))


# --- Dice moments (owner 2026-10-09: the big d20 only for the heroes' saving throws) -----------------------------

## The saving throws the party's heroes rolled since the last look (their creatures' d20 events, Creature.roll_d20),
## each marked so it shows once: [{who: Combatant, test: D20Test}].
func _hero_saves(in_events: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in e.combatants:
		if not c.is_player_controlled() or not c.side in [&"party", &"guest"]:
			continue
		for ev in c.creature.events:
			if str(ev.get("type", "")) != "d20" or bool(ev.get("shown", false)) or in_events.has(ev.get("test")):
				continue
			ev["shown"] = true
			if int(ev.get("kind", -1)) == D20Test.Kind.SAVING_THROW and ev.get("test") is D20Test:
				out.append({"who": c, "test": ev["test"]})
	return out


## Before an action's events play: the dice lane's big emerald d20 (DiceRoll) for each saving throw a hero just made that
## has no "save" event among `events` to show it in its place, a death save included, one after another; it returns once
## the roll has gone (any press skips it; fast combat plays it quicker; headless runs and captures go straight on).
## The saves with a "save" event wait for it (_show_save): the d20 of a Concentration save or a hit's rider shows after
## the blow and its damage have, and the prompt that may follow it comes after that.
func _dice_moments(events: Array = []) -> void:
	var marked := {}
	for ev: Variant in events:
		if str((ev as Dictionary)["type"]) == "save":
			marked[(ev as Dictionary)["test"]] = true
	for s in _hero_saves(marked):
		await _show_roll(s["who"] as Combatant, s["test"] as D20Test)


func _show_roll(who: Combatant, t: D20Test) -> void:
	var kind := "death_save" if t.label.begins_with("Death save") else "save"
	await DiceRoll.show_roll(self, DiceRoll.from_test(t, who.name(), t.label, kind))
	moment_shown.emit("save", who.id)


## A "save" event (EncounterDamage / D20Responses.mark_save): the hero's roll, once, then whether it broke the
## Concentration it was for. A roll the creature's events show as seen already (it came before the fight showed) isn't
## replayed.
func _show_save(ev: Dictionary) -> void:
	var who := e.get_c(str(ev["id"]))
	var t := ev["test"] as D20Test
	if who == null or t == null:
		return
	for own in who.creature.events:
		if own.get("test") == t:
			if bool(own.get("shown", false)):
				return
			own["shown"] = true
	await _show_roll(who, t)
	if _closed or not is_inside_tree():
		return
	_concentration_kept(who)


## Whether a "save" event for `id` follows the event at `at` in the same blow, spell or move.
static func _save_follows(events: Array, at: int, id: String) -> bool:
	for i in range(at + 1, CombatImpact.window_end(events, at)):
		var ev := events[i] as Dictionary
		if str(ev["type"]) == "save" and str(ev["id"]) == id:
			return true
	return false


## The token shown for a creature, or null (none, or freed once the story took the fight back).
func _tok(id: Variant) -> CombatToken:
	var v: Variant = tokens.get(str(id))
	return v as CombatToken if is_instance_valid(v) else null


## A Shapechanger took another shape (ADR 0014): its token wears the shape's sprite when it has one (`forms` art),
## and the stat block's own again in its true form. A party member's or guest's own figure (a wereraven ally's) is only
## hidden while it wears another and comes back for its true form, since exploring goes on with it after the fight
## (owner's report 2026-10-12: Adrian's hybrid left the Vine Mother's fight unable to end). The change is seen and heard
## (owner ask, 2026-10-14, for every shapeshifter): the old figure gathers and flares, then the new one arrives in a
## flash (FxShapeshift; `kind` is how it looks and sounds). A figure nobody can see (an Invisible foe's) changes without
## showing where it stands, and so does a fight with its effects off.
func _swap_form_art(id: String, art: String, kind: String = "", quiet: bool = false) -> void:
	var old := _tok(id)
	if old == null:
		return
	var want := art if art != "" and DirectionalSprite.frames_for(art) != null else ""
	var own: CombatToken = null
	if is_instance_valid(_own_tokens.get(id)):
		own = _own_tokens[id] as CombatToken
	if want == old.art_override or (want == "" and old == own):
		old.flash(Look.color("lilac"), 0.3)
		return
	var shown := SpellFx.enabled and old.visible and not quiet
	if shown:
		await fx.shape_gather(old, kind)
		old = _tok(id)
		if _closed or not is_inside_tree() or old == null:
			return
	var nt: CombatToken
	if want == "" and own != null and own != old:
		nt = own
		nt.combatant = old.combatant
		nt.position = old.position
		nt.visible = true
		nt.refresh()
	else:
		# Its own figure again is its true one, even when what it is now says otherwise (a Werewolf's person).
		nt = CombatToken.create(old.combatant, want if want != "" else CombatToken.true_figure(old.combatant))
		nt.position = old.position
		add_child(nt)
	tokens[id] = nt
	nt.set_unseen(e.sight.hidden_from_party(nt.combatant, viewer))   # an Invisible foe's new figure stays off the map too
	if old == own:
		old.visible = false
	else:
		old.queue_free()
	if shown and nt.visible:
		fx.shape_settle(nt, kind)
	elif not quiet:
		nt.flash(Look.color("lilac"), 0.4)


## A fight picked up from a save (a round-start save) with someone mid-shape: the party and guests come in the figures
## they walked in with, a foe's is built from its creature (LocationFights._fight_tokens), so a hero or guest wears their
## own figure under a beast's stat block and a Shapechanger or hybrid wears its true one. Each puts on what it changed
## into, and the party's own figure waits, hidden, for the shape to end, as _swap_form_art leaves it.
func _restore_forms() -> void:
	for c in e.combatants:
		var tok := _tok(c.id)
		if tok == null or not c.creature is Monster:
			continue
		var art := ""
		if e.shapes.is_shaped(c):
			art = CombatToken.monster_art((c.creature as Monster).data)
			_shape_looks[c.id] = ""
		else:
			art = e.legendary.form_art(c) if e.legendary.form_art(c) != "" else e.monster_actions.form_art(c)
		# Its figure is a swap away from its own, so it can swap back (a foe's drawn from its creature wears the beast
		# with no `art_override` to go back from).
		if art != "" and DirectionalSprite.frames_for(art) != null and tok.art_override != art:
			_swap_form_art(c.id, art, "", true)


## Polymorph, Wild Shape and the other changes of shape (ShapeChange, owner 2026-10-13: "their sprite should reflect
## their transformed shape"): the token wears the Beast's sprite while the shape lasts, facing the way it faced, and its
## own figure again after (a hero's or guest's own token, a foe's look, _swap_form_art). A shape with no sprite of its
## own leaves the figure as it is.
func _swap_shape_art(id: String, art: String, kind: String = "") -> void:
	var old := _tok(id)
	if old == null:
		return
	if art != "":
		if DirectionalSprite.frames_for(art) == null:
			# A shape with no figure to swap to still shows as a change, on the figure it has.
			if SpellFx.enabled and old.visible:
				await fx.shape_gather(old, kind)
				if not _closed and is_instance_valid(old) and old.is_inside_tree():
					fx.shape_settle(old, kind)
			else:
				old.flash(Look.color("lilac"), 0.3)
			return
		if not _shape_looks.has(id):
			_shape_looks[id] = old.art_override
		await _swap_form_art(id, art, kind)
	elif _shape_looks.has(id):
		await _swap_form_art(id, "" if _own_tokens.has(id) else str(_shape_looks[id]), kind)
		_shape_looks.erase(id)
	var nt := _tok(id)
	if nt == null or nt == old:
		return
	nt.scale = Vector3.ONE   # built (or, a hero's own figure, first built) at the size it is now
	if nt.sprite != null and old.sprite != null:
		nt.sprite.facing = old.sprite.facing


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


## Where a spell lands, on the ground: the middle of its other targets, else of its area; the caster's own spot for a
## spell on itself.
func _spell_spot(ev: Dictionary, caster: CombatToken) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for id: Variant in ev.get("targets", []) as Array:
		var t := _tok(str(id))
		if t != null and t != caster:
			sum += t.global_position
			n += 1
	if n == 0:
		for cell: Variant in ev.get("cells", []) as Array:
			sum += board.cell_center(cell as Vector2i)
			n += 1
	return sum / float(n) if n > 0 else caster.global_position


## G2: the blow, spell or effect at `at` in `events` has landed on `struck` (for a spell or an effect, empty: its
## victims are whoever its damage that follows hits). CombatImpact gives the moment its weight: the last foe's fall
## in slow motion, else the hardest-hit creature's (a kill first, then the most damage) push-in or freeze. A kill
## pushes in only on a single victim. True if it played the last foe's fall.
func _impact_on(struck: Array[CombatToken], events: Array, at: int, final_fall: int, critical: bool) -> bool:
	if not CombatImpact.on():
		return false
	var end := CombatImpact.window_end(events, at)
	if final_fall > at and final_fall < end:
		var last := _tok(str((events[final_fall] as Dictionary)["id"]))
		if last != null:
			impact.hit(last, 0, 1, critical, true, true)
			return true
	if struck.is_empty():
		for i in range(at + 1, end):
			var dv := events[i] as Dictionary
			var dt := _tok(str(dv.get("id", ""))) if str(dv["type"]) == "damage" else null
			if dt != null and not struck.has(dt):
				struck.append(dt)
	var best: CombatToken = null
	var most := -1
	for t in struck:
		var score := _damage_after(events, at, t.combatant.id) + (100000 if CombatImpact.fells(events, at, t.combatant.id) else 0)
		if score > most:
			best = t
			most = score
	if best != null:
		var id := best.combatant.id
		impact.hit(best, _damage_after(events, at, id), best.combatant.creature.max_hp(), critical,
			struck.size() == 1 and CombatImpact.fells(events, at, id), false)
	return false


## A Narrator line in the combat log (and briefly as a banner), if the story has one for this moment.
func _narrate(key: String, actor: Combatant, target: Combatant) -> void:
	if narrator == null or story == null:
		return
	var who: Character = actor.creature as Character if actor != null and actor.creature is Character else null
	var text := narrator.line(key, story, who, {"round": e.round_no, "fight": str(e.get_instance_id()),
		"target": target.name() if target != null else ""})
	if text != "":
		e.log.add("narr", text, "")
		if not _log_held:
			hud.refresh_log()
		# A story cutscene for this moment (story/cutscenes.gd): its picture over the fight, the line as its caption.
		var cut := Cutscenes.for_trigger(key, story)
		if cut != "":
			var player := CutscenePlayer.new()
			add_child(player)
			if player.play_scenes(Cutscenes.scenes(cut, text, story, narrator, who), story):
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
	FloatText.rise(self, t, text, colour, size)   # the same mark a trap's damage gets outside a fight (LocationHurt)


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


func _command_allowed(command: String, data: Dictionary = {}) -> bool:
	return not command_filter.is_valid() or bool(command_filter.call(command, data))
