extends Node
## The story game (scenes/game.tscn, plan §10 Phase 3): the current location, the exploration HUD, conversations,
## loot, the party screens (sheet, inventory, journal, rest, party, level up), saving and loading, and the way from
## one location to the next. GameState.story holds everything; this node only shows it and routes input.

const FIRST_LOCATION := "into_the_mists_road"

var st: StoryState
var narrator: Narrator
var banter: Banter
var view: LocationView
var hud: ExploreHud
var screen: Node = null              ## the open full-screen panel (sheet, inventory ...), if any
var dialogue: DialogueUI = null
var loot: LootWindow = null
var _hover := Vector2i(-1, -1)
var _move_repeat := 0.0
var _dialogue_ref := ""
var menu: ContextMenu                ## the right-click menu on things in the world
var _menu_cell := Vector2i(-1, -1)
var ending: EndingScreen = null      ## the campaign's last screen, once the game has ended (ADR 0014)
var glow := HoverGlow.new()          ## the rim on whatever the mouse is over


func _ready() -> void:
	InputActions.ensure()
	Cursors.install()
	GameState.current_scene = "res://scenes/game.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--load="):
			SaveSystem.load_slot(a.get_slice("=", 1))   # captures: start from a save
	st = GameState.story
	st.time_passed.connect(_on_time_passed)
	narrator = Narrator.new()
	banter = Banter.new()
	if st.party.is_empty():
		_new_pregen_party()
	hud = ExploreHud.new()
	add_child(hud)
	hud.build(st)
	hud.leader_picked.connect(func(i: int) -> void:
		if view != null:
			view.set_leader(i)
		_refresh())
	hud.sheet_requested.connect(func(i: int) -> void: open_screen("sheet", i))
	hud.command.connect(_command)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 25
	add_child(menu_layer)
	menu = ContextMenu.new()
	menu.picked.connect(func(id: String) -> void: world_action(_menu_cell, id))
	menu_layer.add_child(menu)
	var where := st.location if st.location != "" else FIRST_LOCATION
	var spawn := "" if st.location == where else "default"
	# Captures (tools/capture) may start anywhere: --location=<id> [--spawn=<name>].
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):
			where = a.get_slice("=", 1)
			spawn = "default"
		elif a.begins_with("--spawn="):
			spawn = a.get_slice("=", 1)
	enter_location(where, spawn)
	# A round-start save puts the party back into its fight.
	var snap := GameState.combat_snapshot
	if not snap.is_empty() and str(snap.get("location", "")) == where:
		view.resume_encounter.call_deferred(snap)
	# A finished game's save plays its ending again.
	if Endings.reached(st) != "":
		show_ending.call_deferred()


## A quick start: four of the six at level 1 travelling, the other two at camp (plan §5.6 Start step). The menu's
## roster pick replaces this.
func _new_pregen_party() -> void:
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot", "kip_smudgewick"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		if st.party.size() < StoryState.PARTY_CAP:
			st.party.append(ch)
		else:
			st.bench.append(ch)
	st.gold = 10.0


func enter_location(location_id: String, spawn: String) -> void:
	_fade_from_black()
	glow.clear()
	if view != null:
		view.queue_free()
		view = null
	ModeController.force(ModeController.Mode.EXPLORATION)
	view = LocationView.create(location_id, st, narrator, Dice.roller, spawn)
	Audio.play_music(_place_mood())
	view.banter_player = banter
	view.banter.connect(func(lines: Array) -> void:
		var text: Array[String] = []
		var faces := {}
		for l: Variant in lines:
			var d := l as Dictionary
			text.append(str(d["text"]) if bool(d["narrator"]) else "%s: %s" % [str(d["name"]).get_slice(" ", 0), d["text"]])
			faces[str(d.get("portrait", ""))] = true
		# One voice shows its face (the Narrator's included); a back-and-forth shows none.
		hud.narrate("\n".join(text), str(faces.keys()[0]) if faces.size() == 1 else "")
		# Each line in its speaker's voice, one after another (ADR 0013); the box stays up until they're done.
		hud.hold_narration(VoiceOver.say_all(lines)))
	view.exit_requested.connect(func(to: String, sp: String) -> void: enter_location.call_deferred(to, sp))
	view.travel_requested.connect(func() -> void: open_travel.call_deferred(true))
	view.dialogue_requested.connect(start_dialogue)
	view.narration.connect(func(t: String) -> void: hud.narrate(t))
	view.toast.connect(func(t: String) -> void: hud.toast(t))
	view.check_rolled.connect(func(t: String) -> void: hud.roll(t))
	view.party_tended.connect(_refresh)
	view.loot_opened.connect(_open_loot)
	view.combat_started.connect(func(cv: CombatView) -> void:
		Cursors.show("pointer")
		glow.clear()
		LayerFade.fade(self, hud, false, 0.25)   # the combat HUD fades up in its place
		Audio.play_music("combat")
		_boss_music.call_deferred(cv)   # the fight is set up just after this signal
		cv.menu_requested.connect(func() -> void:
			if screen is PauseMenu:
				close_screen()
			else:
				open_screen("menu", 0)))
	view.combat_ended.connect(_after_combat)
	add_child(view)
	hud.show_location(view)
	_refresh()
	if spawn != "":
		_autosave.call_deferred()   # arriving somewhere new (before any visit that greets the party)
		_strahd.call_deferred("arrive")   # Strahd's presence (ADR 0014): a visit on arriving somewhere


func _refresh() -> void:
	if view == null:
		return
	view.update_daylight()
	if not view.in_combat:
		view.refresh_party()   # healed outside a fight: back on their feet, chips up to date
	hud.refresh(str(view.loc.get("name", "")), view.sneaking, view.solo)


# --- Input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if view == null or view.in_combat or dialogue != null or ending != null:
		return
	if screen != null:
		if event.is_action_pressed(&"combat_cancel"):
			close_screen()
			get_viewport().set_input_as_handled()
		return
	if loot != null:
		return
	if event is InputEventMouseMotion:
		var pick := view.pick_cell(view.rig.camera, (event as InputEventMouseMotion).position)
		_hover = pick
		var thing := view.thing_at(pick) if pick.x >= 0 else {}
		hud.hint(str(thing.get("label", "")), (event as InputEventMouseMotion).position)
		Cursors.show(Cursors.for_thing(thing))
		glow.show(view, pick, thing)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var cell := view.pick_cell(view.rig.camera, (event as InputEventMouseButton).position)
		if cell.x >= 0:
			view.click(cell)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var at := (event as InputEventMouseButton).position
		open_world_menu(view.pick_cell(view.rig.camera, at), at)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).physical_keycode:
			KEY_C:
				open_screen("sheet", 0)
			KEY_I:
				open_screen("inventory", 0)
			KEY_J:
				open_screen("journal", 0)
			KEY_P:
				open_screen("party", 0)
			KEY_R:
				open_screen("rest", 0)
			KEY_F:
				view.search()
			KEY_V:
				_command("sneak")
			KEY_G:
				_command("split")
			KEY_ESCAPE:
				if hud.controls_showing():
					hud.toggle_controls()
				elif hud.narration_showing():
					hud.close_narration()
				else:
					open_screen("menu", 0)
			KEY_F1:
				hud.toggle_controls()
			KEY_M:
				open_travel(false)
			KEY_F5:
				_quick_save()
			KEY_F9:
				_quick_load()
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_interact_nearby()
			JOY_BUTTON_X:
				view.search()
			JOY_BUTTON_Y:
				open_screen("journal", 0)
			JOY_BUTTON_START:
				open_screen("menu", 0)
			JOY_BUTTON_BACK:
				_menu_nearby()
			JOY_BUTTON_LEFT_SHOULDER:
				open_screen("sheet", 0)
			JOY_BUTTON_RIGHT_SHOULDER:
				open_screen("inventory", 0)
	if event.is_action_pressed(&"cycle_leader"):
		view.set_leader(1)
		_refresh()
	for i in 4:
		if event.is_action_pressed(StringName("select_member_%d" % (i + 1))):
			view.set_leader(i)
			_refresh()


func _process(delta: float) -> void:
	if view == null or view.in_combat or dialogue != null or screen != null or loot != null or ending != null:
		return
	var v := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if v.length() < 0.3:
		_move_repeat = 0.0
		return
	_move_repeat -= delta
	if _move_repeat > 0.0:
		return
	_move_repeat = 0.16
	var b := view.rig.ground_basis()
	var w := b[0] * -v.y + b[1] * v.x
	view.step(Vector2i(roundi(w.x), roundi(w.z)))


## Controller A: use the nearest interactable within a square of the leader.
func _interact_nearby() -> void:
	var c := view.leader().cell
	for d: Vector2i in [Vector2i.ZERO] + CombatGrid.DIRS:
		var thing := view.thing_at(c + d)
		if not thing.is_empty() and str(thing["kind"]) != "exit":
			view.interact(thing)
			return
	hud.toast("Nothing to use here")


## The right-click menu for a square: what can be done with the person, thing, party member or floor there.
func open_world_menu(cell: Vector2i, at: Vector2) -> void:
	if cell.x < 0 or view.busy:
		return
	var m := view.actions_at(cell)
	if (m["actions"] as Array).is_empty():
		return
	_menu_cell = cell
	var items: Array[Dictionary] = []
	items.assign(m["actions"] as Array)
	menu.show_actions(str(m["title"]), items, at)


## Controller Back: the menu for the nearest thing beside the leader, at the middle of the screen.
func _menu_nearby() -> void:
	var c := view.leader().cell
	for d: Vector2i in [Vector2i.ZERO] + CombatGrid.DIRS:
		if not view.thing_at(c + d).is_empty():
			open_world_menu(c + d, get_viewport().get_visible_rect().size / 2.0)
			return
	hud.toast("Nothing to use here")


func world_action(cell: Vector2i, id: String) -> void:
	var parts := id.split(":")
	match parts[0]:
		"lead":
			view.set_leader(int(parts[1]))
			_refresh()
		"sheet":
			open_screen("sheet", int(parts[1]))
		"inventory":
			open_screen("inventory", int(parts[1]))
		"spells":
			open_screen("sheet", int(parts[1]))
			(screen as CharacterSheetScreen).show_tab("Spells")
		"trade":
			var thing := view.thing_at(cell)
			if not thing.is_empty():
				open_shop(str((thing["spec"] as Dictionary)["npc"]))
		_:
			view.act(cell, id)


func _command(name_: String) -> void:
	match name_:
		"sneak":
			view.sneaking = not view.sneaking
			hud.toast("Sneaking" if view.sneaking else "Walking normally")
		"split":
			view.solo = not view.solo
			hud.toast("Only %s moves" % st.party[0].name if view.solo else "The party moves together")
		"search":
			view.search()
		"map":
			open_travel(false)
		_:
			open_screen(name_, 0)
	_refresh()


# --- Conversations, loot, fights ------------------------------------------------------------------

## A merchant's shop; `from_dialogue` resumes the conversation when it closes.
func open_shop(npc_id: String, from_dialogue: bool = false) -> void:
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_for(self, st, npc_id)
	shop.closed.connect(func() -> void:
		_refresh()
		if from_dialogue and dialogue != null:
			dialogue.resume())


## Madam Eva's respec (plan §5.6): party member `index` is built again from level 1 in the creator (name, look and
## personality kept), keeps their belongings, and levels back up with the party's milestones.
func respec(index: int) -> void:
	var old := st.party[index]
	var start := {"name": old.name, "identity": (old.build.get("identity", {}) as Dictionary).duplicate(true),
		"appearance": (old.build.get("appearance", {}) as Dictionary).duplicate(true)}
	var starting: Array[Dictionary] = [start]
	var cs := CreationScreen.new()
	add_child(cs)
	cs.open_with(starting, 1)
	cs.finished.connect(func(made: Array[Character]) -> void:
		st.respec_member(old, made[0])
		cs.queue_free()
		view.rebuild_party()
		_refresh()
		if dialogue != null:
			dialogue.resume())
	cs.cancelled.connect(func() -> void:
		cs.queue_free()
		if dialogue != null:
			dialogue.resume())


func start_dialogue(ref: String, _npc_id: String) -> void:
	if ref == "" or dialogue != null:
		return
	ModeController.force(ModeController.Mode.DIALOGUE)
	Cursors.show("pointer")
	glow.clear()
	_dialogue_ref = ref
	hud.visible = false
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.ended.connect(_dialogue_ended)
	dialogue.shop_requested.connect(func(npc: String) -> void: open_shop(npc, true))
	dialogue.stage_requested.connect(func(what: String, npc: String, at: String) -> void:
		if view == null:
			return
		if what == "appear":
			view.stage_npc(npc, at)
		else:
			view.unstage_npc(npc))
	dialogue.respec_requested.connect(respec)
	var runner := DialogueRunner.new(st, Dice.roller, narrator)
	runner.npc_id = _npc_id
	if not dialogue.play(runner, ref):
		dialogue.queue_free()
		dialogue = null
		hud.visible = true
		ModeController.force(ModeController.Mode.EXPLORATION)


func _dialogue_ended(combat: String) -> void:
	dialogue = null
	if view != null:
		view.clear_staged()   # whoever stepped into the scene leaves with it
	# `end_game`, or the parley's yield or ireena, ends the campaign (ADR 0014).
	if Endings.reached(st) != "" or (Endings.parley_ends(st) and Endings.request(st) != ""):
		show_ending()
		return
	hud.visible = true
	if view.guest_members.size() != st.guests.size():
		view.place_guests()
	ModeController.force(ModeController.Mode.EXPLORATION)
	view.refresh_npcs()
	_refresh()
	var strahd_next := StrahdPresence.after_dialogue(st, _dialogue_ref)
	if not strahd_next.is_empty():
		_strahd_step(strahd_next)
		return
	if combat != "":
		view.hide_npcs_of(_dialogue_ref)
		view.start_encounter(combat)
	elif not view.check_flag_encounters() and not st.travel_resume.is_empty():
		_continue_journey.call_deferred()


func _open_loot(container_id: String, items: Array, gold: float) -> void:
	loot = LootWindow.new()
	add_child(loot)
	loot.closed.connect(func() -> void:
		loot = null
		_refresh())
	loot.show_loot(st, container_id, items, gold, view)


func _after_combat(outcome: String) -> void:
	LayerFade.fade(self, hud, true, 0.45, 0.2)   # as the combat HUD fades out
	Audio.sting("defeat" if outcome == "defeat" else "victory")
	Audio.play_music(_place_mood())
	# A wipe in a final battle is no load screen, and a fight that destroys Strahd is the last (ADR 0014).
	if Endings.after_fight(st, view.last_encounter, outcome) != "":
		show_ending()
		return
	if outcome == "defeat":
		open_screen("game_over", 0)
		return
	view.refresh_npcs()
	_refresh()
	var strahd_after := StrahdPresence.after_encounter(st, outcome)
	if not strahd_after.is_empty():
		_strahd_step(strahd_after)   # his parting words; the journey goes on when they're done
		return
	if not st.travel_resume.is_empty():
		hud.toast("The road is clear. You go on.")
		_continue_journey.call_deferred()
	else:
		_autosave.call_deferred()   # a won fight is a checkpoint


## The campaign's end (ADR 0014): the ending reached plays on the ending screen, which marks the save finished and
## goes back to the title.
func show_ending() -> void:
	var id := Endings.request(st)
	if id == "" or ending != null:
		return
	close_screen()
	hud.visible = false
	ModeController.force(ModeController.Mode.CUTSCENE)
	ending = EndingScreen.new()
	ending.closed.connect(func() -> void: ending = null)
	add_child(ending)
	ending.play(st, Endings.get_ending(id))


# --- Travel (ADR 0010) ----------------------------------------------------------------------------

## The map of Barovia: from a road out of town the party can set out; elsewhere (M) it's only for looking.
func open_travel(setting_out: bool) -> void:
	if screen != null or dialogue != null or view.in_combat:
		return
	var here := Travel.place_for_location(st.location)
	if here == "" and setting_out:
		hud.toast("No road leads on from here yet.")
		return
	var t := TravelScreen.new()
	screen = t
	add_child(t)
	t.open_map(st, here, setting_out)
	t.travel_chosen.connect(func(to: String) -> void:
		screen = null
		travel(here, to))
	t.closed.connect(func() -> void: screen = null)


## Sets out from place `from` for place `to`, road by road. Something on the road stops the journey on that road's
## map; when it's dealt with, the journey goes on (StoryState.travel_resume).
func travel(from: String, to: String) -> void:
	st.travel_resume = {}
	for leg in Travel.route(from, to, st):
		st.advance_minutes(roundi(float(leg["hours"]) * 60.0))
		st.miles_since_long_rest += float(leg["hours"]) * 3.0
		if _strahd_on_road(leg, to):
			return
		var ev := Travel.roll(leg["road"] as Dictionary, st, Dice.roller)
		if ev.is_empty():
			continue
		st.travel_resume = {"to": to, "at": str(leg["to"])}
		var table := ev["table"] as Dictionary
		var entry := ev["entry"] as Dictionary
		enter_location(str(table["map"]), "default")
		if entry.has("monsters"):
			if str(entry.get("text", "")) != "":
				hud.narrate(str(entry["text"]))
			view.start_custom_encounter({"id": "random_%s_%d" % [table["id"], st.total_minutes()], "monsters": entry["monsters"],
				"surprise": str(entry.get("surprise", ""))})
		else:
			start_dialogue(str(entry["dialogue"]), "")
		return
	_arrive(to)


func _continue_journey() -> void:
	var r := st.travel_resume
	st.travel_resume = {}
	if r.is_empty() or view.in_combat:
		return
	travel(str(r["at"]), str(r["to"]))


func _arrive(place_id: String) -> void:
	var pl := Travel.place(place_id)
	var loc_ref := str(pl.get("location", ""))
	enter_location(loc_ref.get_slice(":", 0), str(pl.get("spawn", "default")))
	hud.toast("%s · %02d:%02d" % [pl.get("name", place_id), st.minute_of_day / 60, st.minute_of_day % 60])


## A fight with a foe that has legendary actions (Strahd, ADR 0014) plays the boss music.
func _boss_music(cv: CombatView) -> void:
	if not is_instance_valid(cv) or cv.e == null:
		return
	for c in cv.e.combatants:
		if c.creature is Monster and not ((c.creature as Monster).data.get("legendary_actions", {}) as Dictionary).is_empty():
			Audio.play_music("boss")
			return


# --- Strahd's presence (ADR 0014, story/strahd_presence.gd) -----------------------------------------

## A visit from Strahd at `on` (arrive, rest) if one is due here and now and nothing else is going on.
func _strahd(on: String, ctx: Dictionary = {}) -> bool:
	if view == null or view.in_combat or dialogue != null or loot != null:
		return false
	var visit := StrahdPresence.due(st, on, ctx)
	if visit.is_empty():
		return false
	close_screen()
	_strahd_step(StrahdPresence.begin(st, visit))
	return true


## A leg of a journey is over: a visit on the road stops it on the road's map, like a road event; the journey goes
## on when the visit is done (StoryState.travel_resume).
func _strahd_on_road(leg: Dictionary, to: String) -> bool:
	var visit := StrahdPresence.due(st, "travel", {"location": "", "outdoors": true})
	if visit.is_empty():
		return false
	st.travel_resume = {"to": to, "at": str(leg["to"])}
	enter_location(StrahdPresence.road_map(visit, leg["road"] as Dictionary), "default")
	_strahd_step(StrahdPresence.begin(st, visit))
	return true


## The rest screen's Long Rest is over (ui/screens/rest_screen.gd): he may have come in the night.
func strahd_after_rest(minutes: int) -> void:
	_strahd("rest", {"night": StrahdPresence.night_between(st.total_minutes() - minutes, st.total_minutes())})


## Plays a visit's step: the carriage ride (go), a Narrator line, then a conversation or a fight he leaves.
func _strahd_step(step: Dictionary) -> void:
	var go := str(step.get("go", ""))
	if go != "":
		enter_location(go.get_slice(":", 0), go.get_slice(":", 1) if go.contains(":") else "default")
	if str(step.get("narration", "")) != "":
		hud.narrate(str(step["narration"]))
	if step.has("encounter"):
		var taken: Array[Vector2i] = []
		for m: Combatant in view.members + view.guest_members:
			taken.append(m.cell)
		for t: Variant in (view.loc.get("doors", []) as Array) + (view.loc.get("exits", []) as Array):
			var c := (t as Dictionary)["cell"] as Array
			taken.append(Vector2i(int(c[0]), int(c[1])))
		for npc: String in view.npc_tokens:
			taken.append((view.npc_tokens[npc] as CombatToken).combatant.cell)
		view.start_custom_encounter(StrahdPresence.placed(step["encounter"] as Dictionary, view.loc["map"]["rows"] as Array,
			taken, view.leader().cell))
	elif str(step.get("dialogue", "")) != "":
		start_dialogue(str(step["dialogue"]), "strahd")


# --- Time passing ---------------------------------------------------------------------------------

var _fade: ColorRect = null
var _fade_label: Label = null
var _place_fade: ColorRect = null


## A new place comes up out of black instead of cutting to it (docs/plans/ui_polish.md): the screen goes dark at once
## and the place fades in. The change itself isn't delayed, so nothing that waits on it notices.
func _fade_from_black() -> void:
	if not is_inside_tree():
		return
	if _place_fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 39   # over the HUDs, under the time-passing fade and the menus
		add_child(layer)
		_place_fade = ColorRect.new()
		_place_fade.color = Color(Look.color("void"), 0.0)
		_place_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_place_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_place_fade)
	if _place_fade.has_meta(&"tween"):
		var old := _place_fade.get_meta(&"tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	_place_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(_place_fade, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_place_fade.set_meta(&"tween", tw)


## A fade to black and back when time passes (rests, journeys, waiting for noon), with how long it was.
func _on_time_passed(minutes: int) -> void:
	if not is_inside_tree():
		return
	_autosave.call_deferred()   # after a rest or a wait, once it's done
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 40
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(Look.color("void"), 0.0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
		_fade_label = UiKit.label("", 30, "parchment")
		_fade_label.set_anchors_preset(Control.PRESET_CENTER)
		_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fade_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_fade_label.modulate.a = 0.0
		layer.add_child(_fade_label)
	var hours := float(minutes) / 60.0
	_fade_label.text = ("%d hours later" % roundi(hours)) if hours >= 1.5 else ("An hour later" if hours >= 0.75 else "Half an hour later")
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.parallel().tween_property(_fade_label, "modulate:a", 1.0, 0.45)
	tw.tween_interval(0.9)
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(_fade_label, "modulate:a", 0.0, 0.6)


func _exit_tree() -> void:
	Cursors.uninstall()
	if st != null and st.time_passed.is_connected(_on_time_passed):
		st.time_passed.disconnect(_on_time_passed)


# --- Screens --------------------------------------------------------------------------------------

## The music for where the party is (art/audio.json: the place's own mood, else its map's theme).
func _place_mood() -> String:
	var loc := Compendium.shared().get_entry("locations", st.location)
	return Audio.mood_for(st.location, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary))


func open_screen(kind: String, index: int) -> void:
	close_screen()
	Cursors.show("pointer")
	glow.clear()
	if kind in ["sheet", "inventory", "journal", "party", "level_up", "create"]:
		Audio.sfx("page")
	match kind:
		"sheet":
			screen = CharacterSheetScreen.new()
		"inventory":
			screen = InventoryScreen.new()
		"journal":
			screen = JournalScreen.new()
		"party":
			screen = PartyScreen.new()
		"roster":
			screen = RosterScreen.new()
		"create":
			screen = CreationScreen.new()
		"rest":
			screen = RestScreen.new()
		"menu":
			screen = PauseMenu.new()
		"game_over":
			screen = PauseMenu.new()
			(screen as PauseMenu).game_over = true
		"level_up":
			screen = LevelUpScreen.new()
		_:
			return
	add_child(screen)
	screen.call("open", self, st, index)
	if kind == "menu" and view != null and view.in_combat:
		# The fight waits while the menu is open.
		screen.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true


func close_screen() -> void:
	get_tree().paused = false
	if screen != null:
		# A framed screen sinks away (G9); anything else is freed at once.
		if screen is CanvasLayer:
			UiMotion.dismiss(screen as CanvasLayer)
		else:
			screen.queue_free()
		screen = null
	_refresh()


## Plays a Narrator trigger here (rests, dreams). Returns the line, or "".
func narrate_key(key: String) -> String:
	if view == null:
		return ""
	var text := narrator.line(key, st, st.leader_character())
	if text != "":
		hud.narrate(text)
	return text


## Rebuilds the current location (after a rest or level up changes what's shown).
func rebuild() -> void:
	enter_location(st.location, "")


## The autosave (docs/plans/ui_polish.md): only while simply exploring, never in a fight, a conversation or the
## ending, and only when this is the game itself; a capture or test that puts it inside another scene leaves it off
## unless it turns `autosaves` on.
var autosaves := false


func _autosave() -> void:
	if not (autosaves or get_tree().current_scene == self) or view == null or view.in_combat or dialogue != null \
			or ending != null or ModeController.mode != ModeController.Mode.EXPLORATION or Endings.reached(st) != "":
		return
	if SaveSystem.autosave() == OK:
		hud.saved_note()


func _quick_save() -> void:
	var err := SaveSystem.quick_save()
	hud.toast("Saved." if err == OK else "Can't save now.")


## F9: back to the game's own slot as last saved.
func _quick_load() -> void:
	if SaveSystem.current_slot != "" and SaveSystem.load_slot(SaveSystem.current_slot) == OK:
		get_tree().reload_current_scene()
	else:
		hud.toast("No quick save yet.")


# --- Captures -------------------------------------------------------------------------------------

## The capture tool's sequence (make capture SCENE=res://scenes/game.tscn): exploring, a conversation at its first
## choice, then each party screen.
func capture_shots(tool: Node, out: String) -> void:
	# --ending=<id>: the ending screen, card by card (ui/screens/ending_screen.gd).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ending="):
			await EndingScreen.capture(self, tool, out, a.get_slice("=", 1))
			return
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_1_explore.png")
	# The right-click menu on the nearest door, person or thing.
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for x in view.grid.width:
		for y in view.grid.depth:
			var cell := Vector2i(x, y)
			var k := str(view.thing_at(cell).get("kind", ""))
			if k in ["door", "npc", "container"]:
				var d := view.grid.distance_ft(view.leader().cell, 1, cell, 1)
				if d < best_d:
					best_d = d
					best = cell
	if best.x >= 0:
		var at := view.rig.camera.unproject_position(view.board.cell_center(best) + Vector3(0, 0.6, 0))
		open_world_menu(best, at)
		await tool.call("wait_frames", 8)
		tool.call("_shot", out + "_1b_menu.png")
		menu.hide()
	var shown := view.get("_npc_shown") as Array
	if not shown.is_empty():
		var spec := (shown[0] as Dictionary)["spec"] as Dictionary
		start_dialogue(str(spec.get("dialogue", "")), str(spec["npc"]))
		for i in 30:
			if dialogue == null or not dialogue.options_shown.is_empty():
				break
			dialogue.call("_advance")
			await tool.call("wait_frames", 2)
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_2_dialogue.png")
		if dialogue != null:
			dialogue.queue_free()
			dialogue = null
		hud.visible = true
		ModeController.force(ModeController.Mode.EXPLORATION)
	# --dialogue=<file:node> [--beats=N]: a conversation N beats in (the Tarokka spread, a big scene).
	var dref := ""
	var beats := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dialogue="):
			dref = a.get_slice("=", 1)
		elif a.begins_with("--beats="):
			beats = int(a.get_slice("=", 1))
	if dref != "":
		start_dialogue(dref, "madam_eva" if dref.contains("madam_eva") else "")
		for i in beats:
			if dialogue == null:
				break
			if not dialogue.options_shown.is_empty():
				dialogue.call("_choose", 0)
			else:
				dialogue.call("_advance")
			await tool.call("wait_frames", 2)
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_dialogue.png")
		return
	# --map: the travel map.
	if "--map" in OS.get_cmdline_user_args():
		open_travel(true)
		if screen is TravelScreen:
			var known := Travel.known(st)
			if known.size() > 1:
				(screen as TravelScreen).select(str(known[known.size() - 1]["id"]))
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_map.png")
		return
	# --shop=<npc>: a merchant's shop.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shop="):
			open_shop(a.get_slice("=", 1))
			await tool.call("wait_frames", 10)
			tool.call("_shot", out + "_shop.png")
			return
	# --encounter=<id>: the fight in place, a few turns in.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--encounter=") and view.start_encounter(a.get_slice("=", 1)):
			await tool.call("wait_frames", 240)
			tool.call("_shot", out + "_2b_fight.png")
			return
	var n := 3
	for kind: String in ["sheet", "inventory", "journal", "party", "rest"]:
		open_screen(kind, 2 if kind == "sheet" else 0)
		if kind == "sheet":
			(screen as CharacterSheetScreen).show_tab("Spells")
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_%d_%s.png" % [n, kind])
		n += 1
	close_screen()
