class_name MobileControls
extends CanvasLayer
## Visible alternatives to gestures and right clicks; combat always separates preview from confirmation.

var bar: HBoxContainer
var confirm: Button
var drawer: CanvasLayer
var action_button: Button
var cancel_button: Button
var target_button: Button
var end_button: Button
var _finish_selection := false
var _refresh_elapsed := 0.0
var _action_context := {}
var _action_actor: Combatant


func _ready() -> void:
	layer = 18
	EventBus.scene_changed.connect(func(_path: String) -> void:
		_close()
		_action_actor = null
		_action_context.clear())
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	action_button = MobileUi.button("Actions", _actions)
	bar.add_child(action_button)
	target_button = MobileUi.button("Targets", func() -> void:
		var fight := UiFeel.touch.world_target() as CombatView
		if fight != null:
			_targets(fight))
	bar.add_child(target_button)
	confirm = MobileUi.button("", _confirm)
	bar.add_child(confirm)
	cancel_button = MobileUi.button("Cancel", func() -> void: _command("Cancel targeting"))
	bar.add_child(cancel_button)
	end_button = MobileUi.button("End Turn", func() -> void: _command("Finish selection" if _finish_selection else "End turn"))
	end_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(end_button)
	for button: Button in [action_button, target_button, confirm, cancel_button, end_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _command(command: String) -> void:
	var fight := UiFeel.touch.world_target() as CombatView
	if fight != null:
		fight.touch_command(command)


func _process(delta: float) -> void:
	var target := UiFeel.touch.world_target() if MobileDevice.enabled() else null
	visible = target is CombatView and drawer == null
	if not visible:
		return
	_refresh_elapsed -= delta
	if _refresh_elapsed > 0:
		return
	_refresh_elapsed = 0.1
	show_commands((target as CombatView).mobile_command_state())


func show_commands(state: Dictionary) -> void:
	confirm.text = str(state["label"])
	confirm.tooltip_text = confirm.text
	confirm.visible = confirm.text != ""
	confirm.disabled = not bool(state["enabled"])
	action_button.visible = bool(state["actions"])
	action_button.text = "Change action" if bool(state["targets"]) else "Actions"
	cancel_button.visible = bool(state["cancel"])
	target_button.visible = bool(state["targets"])
	_finish_selection = bool(state.get("finish", false))
	end_button.text = "Finish" if _finish_selection else "End Turn"
	end_button.visible = bool(state["end"]) or _finish_selection
	var safe := MobileDevice.safe_rect().grow(-4)
	end_button.size = Vector2(132, 48)
	end_button.position = Vector2(safe.position.x, safe.end.y - end_button.size.y)
	var count := 0
	for child: Control in bar.get_children():
		if child.visible:
			count += 1
	bar.size = Vector2(minf(safe.size.x - (144 if end_button.visible else 0), count * 150), 48)
	bar.position = Vector2(safe.end.x - bar.size.x, safe.end.y - maxf(48, bar.get_combined_minimum_size().y))


func _menu() -> void:
	var target := UiFeel.touch.world_target()
	if target is CombatView:
		(target as CombatView).menu_requested.emit()
	elif target != null:
		target.call("open_screen", "menu", 0)


func _confirm() -> void:
	var target := UiFeel.touch.world_target() as CombatView
	if target != null and target.touch_ready():
		target.touch_confirm()


func _page(title: String) -> VBoxContainer:
	_close()
	drawer = CanvasLayer.new()
	drawer.layer = 40
	drawer.set_meta(&"pad_scope", true)
	add_child(drawer)
	return MobilePage.build(drawer, title, _close)


func _close() -> void:
	if drawer != null:
		drawer.hide()
		drawer.queue_free()
		drawer = null
		UiFeel.touch.cancel()


func _input(event: InputEvent) -> void:
	if drawer != null and event.is_action_pressed(&"ui_cancel"):
		if PadNav.current != null and PadNav.current.scope_now() != drawer:
			return
		if drawer is MobileActions:
			(drawer as MobileActions).back()
		else:
			_close()
		get_viewport().set_input_as_handled()


func _actions(fight_target: CombatView = null) -> void:
	if drawer != null:
		return
	var target: Node = fight_target if fight_target != null else UiFeel.touch.world_target()
	if target == null:
		return
	if target is CombatView:
		var fight := target as CombatView
		if fight.hud.shown == null:
			return
		var actions := MobileActions.new()
		drawer = actions
		add_child(actions)
		actions.closed.connect(func() -> void:
			_action_actor = actions.actor
			_action_context = {"category": actions.category, "query": actions.query, "scroll": actions.page.scroll.scroll_vertical if actions.selected.is_empty() else actions.browse_scroll}
			drawer = null)
		actions.command_requested.connect(func(command: String) -> void:
			if is_instance_valid(fight):
				fight.touch_command(command))
		actions.chosen.connect(func(action: Dictionary, level: int) -> void:
			if is_instance_valid(fight) and fight.touch_ready():
				fight.hud.cast_at_level.emit(action, level))
		if _action_actor == fight.hud.shown:
			actions.category = str(_action_context.get("category", "All"))
			actions.query = str(_action_context.get("query", ""))
			actions.browse_scroll = int(_action_context.get("scroll", 0))
		actions.open(fight.catalog, fight.hud.shown)
	else:
		var body := _page("Actions")
		for spec: Array in ExploreHud.BUTTONS:
			var command := str(spec[2])
			body.add_child(MobileUi.button(str(spec[0]), func() -> void:
				_close()
				target.call("_command", command)))
		body.add_child(MobileUi.button("End exploration round", func() -> void:
			_close()
			target.call("_command", "plan_round")))


func _camera(target: Node = null) -> void:
	if target == null:
		target = UiFeel.touch.world_target()
	if target == null:
		return
	var rig := (target as CombatView).rig if target is CombatView else ((target as TutorialSession).location.rig if target is TutorialSession else (target.get("view") as LocationView).rig)
	var body := _page("Camera")
	for spec: Array in [["Turn left", -1], ["Turn right", 1]]:
		var step := int(spec[1])
		body.add_child(MobileUi.button(str(spec[0]), func() -> void: rig.rotate_step(step)))
	for spec: Array in [["Zoom in", 1.2], ["Zoom out", 0.8]]:
		var scale_ := float(spec[1])
		body.add_child(MobileUi.button(str(spec[0]), func() -> void: rig.touch_camera({"kind": "camera", "scale": scale_})))
	body.add_child(MobileUi.button("Tactical view", func() -> void: rig.tactical = not rig.tactical))
	body.add_child(MobileUi.button("Recenter", func() -> void: rig.touch_offset = Vector3.ZERO))


func _more(target: Node = null) -> void:
	if target == null:
		target = UiFeel.touch.world_target()
	if target == null:
		return
	var body := _page("More controls")
	body.add_child(MobileUi.button("Context · choose a square", func() -> void:
		_close()
		UiFeel.touch.context_next = true))
	body.add_child(MobileUi.button("Explain · choose a control", func() -> void:
		_close()
		UiFeel.touch.explain_next = true))
	body.add_child(MobileUi.button("Camera", func() -> void: _camera(target)))
	if target is CombatView:
		var fight := target as CombatView
		body.add_child(MobileUi.button("Choose a creature to target", func() -> void: _targets(fight)))
		for command: String in ["Cancel targeting", "Undo move", "End turn"]:
			body.add_child(MobileUi.button(command, func() -> void:
				_close()
				fight.touch_command(command)))
		body.add_child(MobileUi.button("Touch and controller controls", func() -> void:
			_close()
			fight.hud.toggle_controls()))


func _targets(fight: CombatView) -> void:
	var body := _page("Choose a creature · preview only")
	for creature in fight.e.combatants:
		if fight.viewer != null and not fight.e.can_see(fight.viewer, creature):
			continue
		body.add_child(MobileUi.button(creature.name(), func() -> void:
			_close()
			fight.touch_select(creature.id)))
