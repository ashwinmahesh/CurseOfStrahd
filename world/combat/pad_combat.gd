class_name PadCombat
extends RefCounted
## A fight on a pad (U6, docs/ui/controller.md), for world/combat/combat_view.gd, which still reads most of the pad
## itself (the cursor on the left stick, A, B, X, Y, the radial on LB, the hotbar on LT/RT/RB, the slot level on the
## D-pad, the tabs on its up and down). This adds what the pad had no button for, and the camera: Start opens the
## menu and View the controls card, L3 takes back the last move and R3 opens the square's menu at the cursor, Y while
## picking targets casts with those picked, A rolls a dying hero's death saving throw, and B with nothing to cancel
## does nothing (Start is the menu). The camera follows the cursor, the right stick turns and zooms it (but not while
## the radial aims with it), and the prompt bar says what the buttons do, over the hotbar's right end.

## How far above the bottom edge the prompt bar stands in a fight, clear of the hotbar.
const PROMPTS_RAISE := 256.0

var view: Node
## The camera glides to the cursor once the stick has moved it, until it's there.
var follow_cursor := false


func _init(view_: Node) -> void:
	view = view_


func _hud() -> CombatHud:
	return view.get("hud") as CombatHud


func _mode() -> int:
	return int(view.get("mode"))


## A pad button the fight's own input doesn't cover. True when it was used here.
func handle(event: InputEvent) -> bool:
	var jb := event as InputEventJoypadButton
	if jb == null or not jb.pressed:
		return false
	var hud := _hud()
	if event.is_action_pressed(&"pause_menu"):
		view.emit_signal(&"menu_requested")
	elif event.is_action_pressed(&"combat_controls"):
		hud.toggle_controls()
	elif event.is_action_pressed(&"combat_undo"):
		view.call("_undo_move")
	elif event.is_action_pressed(&"combat_square_menu"):
		if _mode() == CombatView.Mode.IDLE:
			var cam := (view.get("rig") as CameraRig).camera
			var board := view.get("board") as ArenaBoard
			view.call("_open_square_menu", cam.unproject_position(board.cell_center(view.get("cursor_cell") as Vector2i)))
	elif event.is_action_pressed(&"combat_end_turn") and _mode() == CombatView.Mode.TARGET:
		view.call("confirm_early")   # Y while picking: cast with the targets picked so far
	elif event.is_action_pressed(&"combat_confirm") and hud.death_save_shown():
		view.call("_death_save")
	elif event.is_action_pressed(&"combat_cancel") and _mode() == CombatView.Mode.IDLE \
			and (view.get("selected") as Dictionary).is_empty():
		hud.hide_details()   # nothing to cancel but a card: B never opens the menu (Start does)
	else:
		return false
	return true


## Each frame: the camera to the cursor, the right stick to the camera unless the radial aims with it, the prompts.
func tick(delta: float) -> void:
	var hud := _hud()
	var rig := view.get("rig") as CameraRig
	rig.pad_look = PadNav.active() and not hud.radial.visible
	if follow_cursor and bool(view.get("using_pad")):
		var to := (view.get("board") as ArenaBoard).cell_center(view.get("cursor_cell") as Vector2i)
		rig.follow = null
		rig.global_position = rig.global_position.lerp(to, clampf(delta * 5.0, 0.0, 1.0))
		if rig.global_position.distance_to(to) < 0.1:
			follow_cursor = false
	if not PadNav.active():
		PadPrompts.clear_world(self)
		return
	match _mode():
		CombatView.Mode.TARGET:
			PadPrompts.set_world(self, [["a", "Pick"], ["b", "Back"], [PadGlyphs.place_for(&"combat_next_target"), "Next target"],
				[PadGlyphs.place_for(&"combat_end_turn"), "Done picking"]], PROMPTS_RAISE)
		CombatView.Mode.IDLE:
			if hud.death_save_shown():
				PadPrompts.set_world(self, [["a", "Death saving throw"], ["start", "Menu"]], PROMPTS_RAISE)
			else:
				PadPrompts.set_world(self, [["a", "Move or attack"], [PadGlyphs.place_for(&"combat_next_target"), "Next target"],
					[PadGlyphs.place_for(&"combat_end_turn"), "End turn"], [PadGlyphs.place_for(&"combat_radial"), "Actions, Tactical (hold)"],
					[PadGlyphs.place_for(&"combat_square_menu"), "Options"], [PadGlyphs.place_for(&"combat_controls"), "Controls"]],
					PROMPTS_RAISE)
		_:
			PadPrompts.clear_world(self)
