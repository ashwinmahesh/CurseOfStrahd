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
var plan_bar: PlanBar                ## turn-based exploring's panel (F7)
var screen: Node = null              ## the open full-screen panel (sheet, inventory ...), if any
var dialogue: DialogueUI = null
var loot: LootWindow = null
var guidance: GuidancePrompt = null  ## Guidance offered before a check while exploring (ask_guidance), if it's up
var _prompting: Node = null          ## a small prompt of ours is up (LeadPrompt: follow now or later; GiftPicker: what to hand a guest)
var _hover := Vector2i(-1, -1)
var _move_repeat := 0.0
var _dialogue_ref := ""
## The music a conversation turned the place's to (_talk_music), "" while the place's own plays.
var _talk_mood := ""
## The music a cutscene in the conversation brought (_scene_music); it holds over whoever speaks until the end.
var _scene_mood := ""
## The music a place cutscene's picture brought (_cutscene_music); the place's own comes back when it closes.
var _cutscene_mood := ""
## Banter that came while the Narrator was speaking; it plays a moment after the box clears (_process).
var _banter_waiting: Array = []
var _banter_quiet_since := -1   ## msec ticks since the box cleared, while banter waits
const BANTER_PAUSE_MS := 1200
## A road meeting's reward (RoadSpoils), given when its conversation ends, or after the fight it started:
## {ref, key, loot, after_fight}.
var _road_event := {}
## Loot windows waiting their turn: a fight's spoils and a road meeting's reward can both come at once.
var _loot_queue: Array[Array] = []
var menu: ContextMenu                ## the right-click menu on things in the world
var _menu_cell := Vector2i(-1, -1)
var ending: EndingScreen = null      ## the campaign's last screen, once the game has ended (ADR 0014)
var glow := HoverGlow.new()          ## the rim on whatever the mouse is over
var pad := PadExplore.new(self)      ## exploring on a controller (U6): the marked thing and the pad's buttons
var notices := ItemNotices.new()     ## items the party comes by outside loot and shops, on the side


func _ready() -> void:
	InputActions.ensure()
	UiScale.playing(self)   # the interface takes the player's size (Settings, Interface) while a game is on screen
	Cursors.install()
	GameState.current_scene = "res://scenes/game.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--load="):
			SaveSystem.load_slot(a.get_slice("=", 1))   # captures: start from a save
	st = GameState.story
	st.time_passed.connect(_on_time_passed)
	add_child(notices)
	st.item_gained.connect(notices.show_item)   # an item come by outside loot and shops, on the side
	narrator = Narrator.new()
	banter = Banter.new()
	if st.party.is_empty():
		_new_pregen_party()
	hud = ExploreHud.new()
	add_child(hud)
	hud.build(st)
	st.xp_gained.connect(hud.toast)   # XP levelling: a quest finished, a place found, a milestone (story/xp.gd)
	D20Die.warm.call_deferred(hud)   # the big d20's shader and numerals, ready before its first roll
	hud.leader_picked.connect(func(i: int) -> void:
		if view != null:
			view.set_leader(i)
		_refresh())
	hud.sheet_requested.connect(func(i: int) -> void: open_screen("sheet", i))
	hud.guest_clicked.connect(guest_menu)   # a story ally's card: Talk, Give... and Send home
	hud.command.connect(_command)
	plan_bar = PlanBar.new()
	plan_bar.hud = hud
	plan_bar.command.connect(_command)
	add_child(plan_bar)
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
	# The first place (a new game, Continue or a load) behind the loading card.
	_covered(where, func() -> void:
		enter_location(where, spawn)
		# A round-start save puts the party back into its fight.
		var snap := GameState.combat_snapshot
		if not snap.is_empty() and str(snap.get("location", "")) == where:
			view.resume_encounter.call_deferred(snap)
		elif LongRest.broken(st):
			_night_after_load.call_deferred()   # saved with the night's rest broken and no fight under way
		# A finished game's save plays its ending again.
		if Endings.reached(st) != "":
			show_ending.call_deferred())


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


## Shows `location_id` with the party at `spawn`. `sneaking`: the party walked out of the last place through an exit while
## sneaking, so it arrives sneaking too, with fresh Stealth rolls (LocationStealth), sneaking when the place first looks at
## its areas (a fight waiting there may be slipped into, or be set off by a foe that notices them); any other way in (the
## travel map, a cutscene, a load) starts it walking normally.
func enter_location(location_id: String, spawn: String, sneaking: bool = false) -> void:
	# A journey that is waiting to go on is only ever on its road: entering any other place ends it (a conversation's
	# `move`, or a record a save carried over), so a fight won there can't carry the party off to the journey's end.
	if not st.travel_resume.is_empty() and not Travel.is_road_scene(location_id):
		st.travel_resume = {}
	_fade_from_black()
	glow.clear()
	if view != null:
		view.queue_free()
		view = null
	ModeController.force(ModeController.Mode.EXPLORATION)
	view = LocationView.create(location_id, st, narrator, Dice.roller, spawn)
	# Arriving in a new region: its loading card (G5, ui/screens/loading_card.gd) while the place settles in behind (a
	# change made behind a cover put the card up already).
	if not moving and str(view.loc.get("region", "")) != _card_region:
		_card_region = str(view.loc.get("region", ""))
		LoadingCard.show_for(self, view.loc)
	# The place's name as it fades in (Visual Polish Plan 6), unless a loading card is up and names it already.
	_title = PlaceTitle.show_for(self, view.loc)
	Audio.play_music(_place_mood())
	view.banter_player = banter
	_banter_waiting = []
	_banter_quiet_since = -1
	view.banter.connect(func(lines: Array) -> void:
		# Banter never talks over the Narrator: it waits for the place's own words to finish (_process).
		if hud.narration_showing():
			_banter_waiting = lines
		else:
			_show_banter(lines))
	var leaving := view
	view.exit_requested.connect(func(to: String, sp: String) -> void:
		_covered.call_deferred(to, enter_location.bind(to, sp, leaving.sneaking)))
	view.travel_requested.connect(func() -> void: open_travel.call_deferred(true))
	view.dialogue_requested.connect(start_dialogue)
	view.gift_requested.connect(give_to_guest)
	view.narration.connect(func(t: String) -> void: hud.narrate(t))
	view.cutscene_requested.connect(play_cutscene)
	view.toast.connect(func(t: String) -> void: hud.toast(t))
	view.check_rolled.connect(func(t: String) -> void:
		hud.roll(t)
		# A trap's or a pit's roll may have dropped the last one standing (QA FN-17). Not a refresh: that stands the
		# conscious back up, and a pit leaves its victim Prone.
		if not view.in_combat:
			_check_fallen())
	view.big_roll.connect(func(t: D20Test, who: String, label: String) -> void: DiceRoll.show_roll(self, DiceRoll.from_test(t, who, label)))
	view.party_tended.connect(_refresh)
	view.guidance_asked.connect(_ask_guidance)
	view.loot_opened.connect(_open_loot)
	view.combat_started.connect(func(cv: CombatView) -> void:
		Cursors.show("pointer")
		glow.clear()
		LayerFade.fade(self, hud, false, 0.25)   # the combat HUD fades up in its place
		Audio.play_music("combat")
		_boss_music.call_deferred(cv)   # the fight is set up just after this signal
		Audio.follow_fight.call_deferred(cv)   # the music swells while a boss stands or someone is Bloodied (A2)
		Achievements.watch(cv, st, hud.toast)   # the run's record for the ending, and achievements (N8)
		cv.menu_requested.connect(func() -> void:
			if screen is PauseMenu:
				close_screen()
			else:
				open_screen("menu", 0))
		cv.sheet_requested.connect(func(who: Character) -> void:
			if st.party.has(who):
				open_screen("sheet", st.party.find(who))))
	view.combat_ended.connect(_after_combat)
	view.arrive_sneaking = sneaking
	add_child(view)
	PlacePreload.keep_foes(view)   # the foes of its fights read on worker threads while the party is here
	plan_bar.view = view
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
	hud.refresh(str(view.loc.get("name", "")), view.sneaking, view.solo and not view.planning, view.planning)
	if not view.in_combat:
		_check_fallen()


## Everyone down outside a fight (the last one standing caught by a trap while the rest lie where a fight left them):
## nobody can walk, stabilize or act, and no Death Saving Throws run outside fights, so it ends as a lost fight does,
## with "The party has fallen" (QA FN-17: nothing came up, and nothing could change).
func _check_fallen() -> void:
	if _fallen or screen != null or dialogue != null or ending != null or moving or not _party_down():
		return
	_fallen = true
	_fall.call_deferred()   # not from inside close_screen's own refresh, and after whatever ended a fight has its say


## The game over, if the party is still all down once the moment has passed. A fight's own end goes first: its own
## game over, or the final battle's wipe that is an ending (test_ending_screen). So does the big d20 for the save that
## dropped them: the player sees it fail before the party falls.
func _fall() -> void:
	if DiceRoll.showing() != null:
		# Asked again shortly (a bound method, so it goes with this root), never awaiting the panel: a panel freed
		# with its scene never says it finished.
		get_tree().create_timer(0.1, true).timeout.connect(_fall)
		return
	if screen != null or dialogue != null or ending != null or moving or view == null or view.in_combat or not _party_down():
		_fallen = false
		return
	open_screen("game_over", 0)


func _party_down() -> bool:
	if st.party.is_empty():
		return false
	for ch in st.party:
		if not ch.dead and ch.hp > 0:
			return false
	return true


var _fallen := false


# --- Input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if moving or view == null or view.in_combat or dialogue != null or ending != null or guidance != null or _prompting != null:
		return
	if screen != null:
		if event.is_action_pressed(&"combat_cancel"):
			close_screen()
			get_viewport().set_input_as_handled()
		return
	if loot != null:
		return
	if pad.handle(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var pick := view.pick_cell(view.rig.camera, (event as InputEventMouseMotion).position)
		_hover = pick
		var thing := view.thing_at(pick) if pick.x >= 0 else {}
		# Turn-based: the floor's hint is the walk's cost against this round's movement, its trail drawn on the ground.
		var label := str(thing.get("label", ""))
		if thing.is_empty() and view.planning:
			label = LocationPlan.hover_text(view, pick)
		elif thing.is_empty() and pick.x >= 0:
			label = LocationStealth.hover_warning(view, pick) if view.sneaking else LocationStealth.guarded_hint(view, pick)   # who can see you (U10)
		LocationPlan.preview(view, pick if thing.is_empty() else Vector2i(-1, -1))
		hud.hint(label, (event as InputEventMouseMotion).position)
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
		# The keys are matched as their defaults, so the player's own keys (Settings, Keys) land on the same commands.
		match InputActions.as_default(event as InputEventKey):
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
			KEY_H:
				open_screen("wait", 0)
			KEY_F:
				view.search()
			KEY_V:
				_command("sneak")
			KEY_T:
				_command("plan")
			KEY_SPACE:
				if view.planning:
					_command("plan_round")
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
	if event.is_action_pressed(&"cycle_leader"):
		view.set_leader(view.next_leader_index(1))   # the next hero, passing over the dead
		_refresh()
	for i in 4:
		if event.is_action_pressed(StringName("select_member_%d" % (i + 1))):
			view.set_leader(i)
			_refresh()


func _process(delta: float) -> void:
	var exploring := not moving and view != null and not view.in_combat and dialogue == null and screen == null \
		and loot == null and ending == null and guidance == null and _prompting == null
	if view != null and not view.in_combat:
		view.rig.pad_look = exploring   # the right stick turns and zooms the camera (a fight sets its own)
	if exploring and PadNav.active():
		pad.tick(delta)
	elif pad.marked.x >= 0 or PadPrompts.owns(pad):
		pad.clear()
		glow.clear()
	if not exploring:
		return
	if not _banter_waiting.is_empty():
		if hud.narration_showing():
			_banter_quiet_since = -1
		elif _banter_quiet_since < 0:
			_banter_quiet_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _banter_quiet_since >= BANTER_PAUSE_MS:
			_show_banter(_banter_waiting)
			_banter_waiting = []
			_banter_quiet_since = -1
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
		"trade", "services":
			var thing := view.thing_at(cell)
			if not thing.is_empty():
				var npc := str((thing["spec"] as Dictionary)["npc"])
				if parts[0] == "trade":
					open_shop(npc)
				else:
					open_services(npc)
		_:
			view.act(cell, id)


func _command(name_: String) -> void:
	if moving:
		return   # the HUD's shortcuts while a change of place is under its cover
	match name_:
		"sneak":
			view.set_sneaking(not view.sneaking)
			if not view.in_combat:
				hud.toast("Sneaking" if view.sneaking else "Walking normally")
		"plan":
			view.toggle_plan()
		"plan_round":
			view.next_round()
		"strike":
			if not view.strike():
				hud.toast("No foes in sight")
		"split":
			if view.planning:
				hud.toast("Turn-based already moves one of you at a time")
			else:
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


## Someone's services (a temple's spells, an inn's rooms; F14); `from_dialogue` resumes the conversation when it closes.
func open_services(npc_id: String, from_dialogue: bool = false) -> void:
	var sv := ServicesScreen.new()
	sv.rest_after = not from_dialogue
	add_child(sv)
	sv.open_for(self, st, npc_id)
	sv.closed.connect(func() -> void:
		_refresh()
		if from_dialogue and dialogue != null:
			dialogue.resume())


## Madam Eva's respec (plan §5.6): party member `index` is built again from level 1 in the creator (name, look and
## personality kept), keeps their belongings, and levels back up with the party's milestones.
func respec(index: int) -> void:
	var old := st.party[index]
	var starting: Array[Dictionary] = [CreationScreen.rebuild_start(old)]
	var cs := CreationScreen.new()
	add_child(cs)
	cs.open_with(starting, 1)
	cs.finished.connect(func(made: Array[Character]) -> void:
		st.last_check = true   # the conversation goes on knowing someone was rebuilt (`check.last`)
		st.respec_member(old, made[0])
		cs.queue_free()
		view.rebuild_party()
		_refresh()
		if dialogue != null:
			dialogue.resume())
	cs.cancelled.connect(func() -> void:
		st.last_check = false   # backed out: nobody was rebuilt
		cs.queue_free()
		if dialogue != null:
			dialogue.resume())


# --- Conversations: someone leads the party (`lead`), and the story allies who travel with it ---------------------

## A `lead <npc> to <where>` line (docs/contracts/dialogue.md): the party follows `npc_id` to `to`. Somewhere on this map
## they walk after the figure (LocationLead); to another place a prompt asks first (LeadPrompt), then they follow to the
## way out and the place changes. The conversation carries on where the party stands afterwards, and `check.last` says
## whether they went.
func _lead(npc_id: String, to: String) -> void:
	if view == null or dialogue == null:
		return
	var plan := LocationLead.plan(view, to)
	TalkCamera.close(view, false)
	if str(plan["kind"]) == "none":
		push_warning("Dialogue: `lead %s to %s` names no place here" % [npc_id, to])
		_lead_done(npc_id, true)
		return
	if str(plan["kind"]) == "there":
		_prompting = LeadPrompt.ask(self, GuestTalk.name_of(npc_id), str(plan["name"]), func(follow: bool) -> void:
			_prompting = null
			if follow:
				_lead_walk(npc_id, plan)
			else:
				_lead_done(npc_id, false))
		return
	_lead_walk(npc_id, plan)


## The walk: on this map, to the spot; to another place, to the way out, then the change of place.
func _lead_walk(npc_id: String, plan: Dictionary) -> void:
	var here := str(plan["kind"]) == "here"
	var spot := Vector2i(-1, -1)
	if here:
		spot = plan["cell"] as Vector2i
	elif not (plan["exit"] as Dictionary).is_empty():
		spot = LocationView._cell((plan["exit"] as Dictionary)["cell"])
	var walk: LocationLead = null
	if spot.x >= 0:
		var fig := LocationLead.figure(view, npc_id)
		if not fig.is_empty():
			var stand := LocationLead.stand_for(view, fig["cell"] as Vector2i, spot, bool(plan.get("exact", false)))
			walk = LocationLead.begin(view, npc_id, stand)
	if walk == null:
		if here:
			_lead_done(npc_id, true)   # nowhere to walk to: they are simply there
		else:
			await _lead_there(npc_id, plan)   # no way out on foot from here: the party is simply there
		return
	var followed: bool = await walk.finished
	if not is_inside_tree() or dialogue == null:
		return
	if not followed:
		if view.in_combat:
			_leave_dialogue_for_fight()   # a fight began on the way: it has the screen
		else:
			_lead_done(npc_id, false)
	elif here:
		_lead_done(npc_id, true)
	else:
		await _lead_there(npc_id, plan)


## The change of place: the party and the one leading arrive together, and the conversation carries on there.
func _lead_there(npc_id: String, plan: Dictionary) -> void:
	var to := str(plan["where"])
	var spawn := str(plan["spawn"])
	st.advance_minutes(5)   # walking between places takes a few minutes
	await _covered(to, enter_location.bind(to, spawn))
	if not is_inside_tree() or dialogue == null:
		return
	if view.in_combat:
		_leave_dialogue_for_fight()   # the place set a fight off as the party arrived
		return
	ModeController.force(ModeController.Mode.DIALOGUE)
	hud.visible = false
	view.stage_npc(npc_id, "")   # beside the party for the rest of the talk
	_lead_done(npc_id, true)


## A fight began while the conversation was stepped back for a lead: the talk is over and the fight has the screen.
func _leave_dialogue_for_fight() -> void:
	if dialogue != null:
		dialogue.queue_free()
		dialogue = null
	hud.visible = true


## Back to the conversation: the camera comes in again and the box with it.
func _lead_done(npc_id: String, followed: bool) -> void:
	if dialogue == null or view == null:
		return
	st.last_check = followed
	TalkCamera.open(view, npc_id)
	dialogue.resume()


## Talk to a story ally who travels with the party (a click on them, the HUD's card, the Party screen's Talk).
func talk_to_guest(npc_id: String) -> void:
	if view == null or view.in_combat or dialogue != null or _prompting != null or moving:
		return
	if screen != null:
		close_screen()
	LocationGuests.talk(view, npc_id)


## Hand a story ally something (the right-click menu's Give..., the HUD's and the Party screen's): the picker lists what
## the party carries that is for them (GuestTalk.gifts); picking one starts the conversation that hands it over.
func give_to_guest(npc_id: String) -> void:
	if view == null or view.in_combat or dialogue != null or _prompting != null or moving:
		return
	if screen != null:
		close_screen()
	var gifts := GuestTalk.gifts(st, npc_id)
	if gifts.is_empty():
		hud.toast("Nothing the party carries is for %s right now" % GuestTalk.name_of(npc_id).get_slice(" ", 0))
		return
	_prompting = GiftPicker.ask(self, GuestTalk.name_of(npc_id), gifts, func(i: int) -> void:
		_prompting = null
		if i >= 0 and str(gifts[i]["ref"]) != "":
			start_dialogue(str(gifts[i]["ref"]), npc_id))


## A guest's card on the HUD was clicked: the same choices as their right-click menu, beside the card.
func guest_menu(npc_id: String, at: Vector2) -> void:
	if view == null or view.busy or view.in_combat or dialogue != null or _prompting != null or moving:
		return
	_menu_cell = Vector2i(-1, -1)
	menu.show_actions(GuestTalk.name_of(npc_id), GuestTalk.actions(st, npc_id), at)


## Party banter or a guest's line (story/banter.gd) in the Narrator's box, each line in its speaker's voice.
func _show_banter(lines: Array) -> void:
	var text: Array[String] = []
	var faces := {}
	for l: Variant in lines:
		var d := l as Dictionary
		var who := str(d["name"])
		for title: String in ["Sir ", "Lady ", "Madam ", "Father ", "Mother ", "Brother "]:
			who = who.trim_prefix(title)   # "Godfrey: ...", not "Sir: ..."
		text.append(str(d["text"]) if bool(d["narrator"]) else "%s: %s" % [who.get_slice(" ", 0), d["text"]])
		faces[str(d.get("portrait", ""))] = true
	# One voice shows its face (the Narrator's included); a back-and-forth shows none.
	hud.narrate("\n".join(text), str(faces.keys()[0]) if faces.size() == 1 else "")
	# Each line in its speaker's voice, one after another (ADR 0013); the box stays up until they're done.
	hud.hold_narration(VoiceOver.say_all(lines))


func start_dialogue(ref: String, _npc_id: String) -> void:
	if ref == "" or dialogue != null:
		return
	ModeController.force(ModeController.Mode.DIALOGUE)
	Cursors.show("pointer")
	glow.clear()
	_dialogue_ref = ref
	_talk_mood = ""
	_scene_mood = ""
	hud.visible = false
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.ended.connect(_dialogue_ended)
	dialogue.shop_requested.connect(func(npc: String) -> void: open_shop(npc, true))
	dialogue.services_requested.connect(func(npc: String) -> void: open_services(npc, true))
	dialogue.stage_requested.connect(func(what: String, npc: String, at: String) -> void:
		if view == null:
			return
		if what == "appear":
			view.stage_npc(npc, at)
		else:
			view.unstage_npc(npc))
	dialogue.respec_requested.connect(respec)
	dialogue.lead_requested.connect(_lead)
	dialogue.spoke.connect(_talk_music)
	dialogue.spoke.connect(func(speaker_id: String) -> void:
		if view != null:
			view.set_speaking(speaker_id))   # a vestige's amber flares while its line shows (AmberGlow)
	dialogue.scene_shown.connect(_scene_music)
	var runner := DialogueRunner.new(st, Dice.roller, narrator)
	runner.npc_id = _npc_id
	runner.offer_guidance = true   # Guidance before a check, from whoever can cast it (GuidanceOffer)
	runner.offer_leads = true      # the party follows whoever leads it (`lead`), and is asked first when it is another place
	if not dialogue.play(runner, ref):
		dialogue.queue_free()
		dialogue = null
		hud.visible = true
		ModeController.force(ModeController.Mode.EXPLORATION)
	else:
		TalkCamera.open(view, _npc_id, view.dialogue_prop if view != null else "")   # the camera eases in on the leader and the speaker, or the prop that speaks (Visual Polish Plan 7)
		if dialogue != null:
			_talk_music(_npc_id)   # the one who was clicked, before they have spoken


## A conversation with someone the place's music turns for (art/audio.json "talk_moods": Strahd, Rahadin and the others
## the castle itself fears) plays that music until it ends; _dialogue_ended brings the place's own back. `speaker_id`
## is whoever was spoken to, or whose line is showing.
func _talk_music(speaker_id: String) -> void:
	if _scene_mood != "":
		return   # the scene's own music holds
	var m := Audio.talk_mood(_place_mood(), speaker_id)
	if m != "":
		_talk_mood = m
		Audio.play_music(m)


## A cutscene whose scene has its own music (art/audio.json "scenes": Strahd at the window of a lively inn, a burial in
## the vineyard) plays it from its picture to the conversation's end, over any speaker's; _dialogue_ended brings the
## place's own back.
func _scene_music(cutscene_id: String) -> void:
	var m := Audio.scene_mood(cutscene_id)
	if m == "camp":
		m = _place_mood()   # "back to the camp" is the camp's own music, which turns warm once the festival is over
	if m != "":
		_scene_mood = m
		_talk_mood = m
		Audio.play_music(m)


## Guidance before a check while exploring (LocationView.ask_guidance): the prompt over the place, which waits for it.
func _ask_guidance(offer: Dictionary, answered: Callable) -> void:
	guidance = GuidancePrompt.ask(self, offer, func(index: int, rule: String) -> void:
		guidance = null
		answered.call(index, rule))


func _dialogue_ended(combat: String) -> void:
	# `move <location>[:<spawn>]` ended the conversation: where the party goes once it has closed (story/dialogue_runner.gd).
	var moved: Dictionary = dialogue.runner.move_to if dialogue != null and dialogue.runner != null else {}
	dialogue = null
	_scene_mood = ""
	if view != null:
		view.clear_staged()   # whoever stepped into the scene leaves with it
		view.dialogue_prop = ""
		view.set_speaking("")
		TalkCamera.close(view, combat != "" or not moved.is_empty())
	# `end_game`, or the parley's yield or ireena, ends the campaign (ADR 0014).
	if Endings.reached(st) != "" or (Endings.parley_ends(st) and Endings.request(st) != ""):
		show_ending()
		return
	hud.visible = true
	if _talk_mood != "":
		_talk_mood = ""
		if combat == "":
			Audio.play_music(_place_mood())   # a fight brings its own music
	if view.guest_members.filter(func(g: Combatant) -> bool: return not LocationParty.is_follower(g)).size() != st.guests.size():
		view.place_guests()
	ModeController.force(ModeController.Mode.EXPLORATION)
	view.refresh_npcs()
	_refresh()
	var strahd_next := StrahdPresence.after_dialogue(st, _dialogue_ref)
	if not strahd_next.is_empty():
		_strahd_step(strahd_next)
		return
	if combat == "" and _night_visit_over():
		_sleep_again()   # his visit broke the night's rest, and he's gone: the party sleeps on
	if not _road_event.is_empty() and str(_road_event["ref"]) == _dialogue_ref:
		if combat == "":
			_give_road_event()
		else:
			_road_event["after_fight"] = true   # the meeting turned into a fight: its reward comes after
	if combat != "":
		view.hide_npcs_of(_dialogue_ref)
		view.start_encounter(combat)
	elif not moved.is_empty():
		_move_party(str(moved["location"]), str(moved["spawn"]))
	elif not view.check_flag_encounters() and _journey_pending():
		_continue_journey.call_deferred()


## A conversation's `move <location>[:<spawn>]`: the party goes there as through an exit, behind the same cover, to
## another map or to another square of this one (a trap's drop from cell to cell). The place then does what it does for any
## arrival: its Narrator line, the autosave, a fight whose area they land in.
func _move_party(location_id: String, spawn: String) -> void:
	if not Compendium.shared().has("locations", location_id):
		push_warning("Dialogue: move to unknown location '%s'" % location_id)
		return
	_covered.call_deferred(location_id, enter_location.bind(location_id, spawn))


## A road meeting's reward, in the loot window.
func _give_road_event() -> void:
	var loot_spec := _road_event["loot"] as Dictionary
	var key := str(_road_event["key"])
	_road_event = {}
	if view != null:
		view.loot_opened.emit.call_deferred("road:" + key, (loot_spec["items"] as Array).duplicate(true), float(loot_spec["gold"]))


func _open_loot(container_id: String, items: Array, gold: float) -> void:
	if loot != null:
		_loot_queue.append([container_id, items, gold])   # after the one that's open
		return
	# A Tarokka treasure among the spoils shows its picture first (story/cutscenes.gd `find:<item>`), once.
	for it: Variant in items:
		var item_id := str((it as Dictionary).get("id", "")) if it is Dictionary else str(it)
		var cut := Cutscenes.for_trigger("find:" + item_id, st)
		if cut != "":
			var player := play_cutscene(cut, Cutscenes.found_line(item_id))
			if player != null:
				player.finished.connect(func() -> void: _open_loot.call_deferred(container_id, items, gold), CONNECT_ONE_SHOT)
				return
	# Taking from something someone owns is stealing, if anybody sees (F8, LocationCrime).
	var worth := Crime.value_of(items, gold)
	if view != null:
		LocationCrime.opened(view, container_id)
	loot = LootWindow.new()
	add_child(loot)
	loot.closed.connect(func() -> void:
		var taken := worth - Crime.value_of(loot.items, loot.gold)
		loot = null
		_refresh()
		if view != null:
			LocationCrime.after_loot(view, container_id, taken)
		if not _loot_queue.is_empty():
			var next := _loot_queue.pop_front() as Array
			_open_loot.call_deferred(str(next[0]), next[1] as Array, float(next[2])))
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
	if outcome == "victory":
		LongRest.fought(st)   # a fight that broke the night's rest: an hour more to finish it (2024 PHB)
	view.refresh_npcs()
	_refresh()
	if not _road_event.is_empty() and bool(_road_event["after_fight"]):
		if outcome == "victory":
			_give_road_event()   # after the fight's own spoils (the loot queue)
		else:
			_road_event = {}
	var strahd_after := StrahdPresence.after_encounter(st, outcome)
	if not strahd_after.is_empty():
		_strahd_step(strahd_after)   # his parting words; the journey (or the night's rest) goes on when they're done
		return
	if LongRest.broken(st):
		_sleep_again()   # the night's fight is won: the party sleeps on, and the Long Rest's benefits come at last
	if _journey_pending():
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


## Whether a journey is waiting to go on from here: one is only ever waiting on a road's map, so a record anywhere
## else is left over (from a save, or a path that left the road) and is dropped.
func _journey_pending() -> bool:
	if st.travel_resume.is_empty():
		return false
	if Travel.is_road_scene(st.location):
		return true
	st.travel_resume = {}
	return false


## Sets out from place `from` for place `to`, road by road. Something on the road stops the journey on that road's
## map; when it's dealt with, the journey goes on (StoryState.travel_resume).
func travel(from: String, to: String) -> void:
	# The hours of the legs pass before the party stands on the road (the change of place waits behind its cover), and
	# time passing makes an autosave: not of this half-way state, which would load back at the start with the journey
	# armed (_on_time_passed).
	_journeying = true
	_travel_legs(from, to)
	_journeying = false


func _travel_legs(from: String, to: String) -> void:
	st.travel_resume = {}
	for leg in Travel.route(from, to, st):
		st.advance_minutes(roundi(float(leg["hours"]) * 60.0))
		st.miles_since_long_rest += float(leg["hours"]) * 3.0
		if _strahd_on_road(leg, to):
			return
		var ev := Travel.roll(leg["road"] as Dictionary, st, Dice.roller, to)
		RoadFamiliarity.note(st, leg["road"] as Dictionary)   # walked now: the next time along it is familiar ground
		if ev.is_empty():
			continue
		st.travel_resume = {"to": to, "at": str(leg["to"])}
		var table := ev["table"] as Dictionary
		var entry := ev["entry"] as Dictionary
		# Every random encounter pays (Ashwin, 2026-10-09): a fight's reward goes in with its spoils, a meeting's when its
		# conversation ends (RoadSpoils).
		var key := "%s:%s:%d" % [table["id"], entry.get("id", ""), st.total_minutes()]
		# A fight plays out on one of the road's battle grounds, a meeting on the table's own map (RoadGrounds).
		var ground := RoadGrounds.choose(table, leg["road"] as Dictionary, st) if entry.has("monsters") else str(table["map"])
		_covered(ground, func() -> void:
			enter_location(ground, "default")
			if entry.has("monsters"):
				if str(entry.get("text", "")) != "":
					hud.narrate(str(entry["text"]))
				var foes := RoadGrounds.placed(entry["monsters"] as Array, str(table["map"]), ground)
				view.start_custom_encounter({"id": "random_%s_%d" % [table["id"], st.total_minutes()], "monsters": foes,
					"surprise": str(entry.get("surprise", "")), "loot": RoadSpoils.for_fight(st, entry["monsters"] as Array, key)})
			else:
				_road_event = {"ref": str(entry["dialogue"]), "key": key, "loot": RoadSpoils.for_event(st, key), "after_fight": false}
				start_dialogue(str(entry["dialogue"]), ""))
		return
	_covered(str(Travel.place(to).get("location", "")).get_slice(":", 0), _arrive.bind(to))


func _continue_journey() -> void:
	# Spoils open a frame after a fight or a road meeting ends: the road waits until they're taken.
	await get_tree().process_frame
	while loot != null or not _loot_queue.is_empty():
		if loot != null:
			await loot.closed
		await get_tree().process_frame
	var r := st.travel_resume
	st.travel_resume = {}
	if r.is_empty() or view.in_combat or not Travel.is_road_scene(st.location):
		return
	travel(str(r["at"]), str(r["to"]))


func _arrive(place_id: String) -> void:
	var pl := Travel.place(place_id)
	var loc_ref := str(pl.get("location", ""))
	enter_location(loc_ref.get_slice(":", 0), str(pl.get("spawn", "default")))
	var hour := "%02d:%02d" % [st.minute_of_day / 60, st.minute_of_day % 60]
	if is_instance_valid(_title):
		_title.set_subtitle(hour)   # the place's title names it; the hour goes beneath
	else:
		hud.toast("%s · %s" % [pl.get("name", place_id), hour])


## A fight with a foe that has legendary actions (Strahd, ADR 0014) plays the boss music.
func _boss_music(cv: CombatView) -> void:
	if not is_instance_valid(cv) or cv.e == null:
		return
	for c in cv.e.combatants:
		if c.creature is Monster and not ((c.creature as Monster).data.get("legendary_actions", {}) as Dictionary).is_empty():
			Audio.play_music("boss")
			return


# --- Strahd's presence (ADR 0014, story/strahd_presence.gd) -----------------------------------------

## A visit from Strahd at `on` (arrive, rest) if one is due here and now and nothing else is going on. What holds it
## (_strahd_holds) makes it wait until it's done with: it plays then, never dropped.
func _strahd(on: String, ctx: Dictionary = {}) -> bool:
	if view == null or view.in_combat or (dialogue != null and on != "rest"):
		return false
	if _strahd_holds(on):
		_strahd_after_loot.call_deferred(on, ctx)
		return false
	var visit := StrahdPresence.due(st, on, ctx)
	if visit.is_empty():
		if on == "rest" and LongRest.waits_on_strahd(st):
			_sleep_again()   # the visit that broke the rest isn't due after all: the party sleeps on
		return false
	close_screen()
	_strahd_step(StrahdPresence.begin(st, visit))
	return true


## Whether a visit at `on` waits: spoils still open (they come a frame after a fight), and for the night's visit after
## a Long Rest, a screen still open (the rest screen with the night's lines, the companions' words and the change of
## prepared spells; the inventory a magic item's rest was taken from) or a talk started from it (lane 24, gap 2: the
## visit used to close the rest screen and take its morning with it).
func _strahd_holds(on: String) -> bool:
	return loot != null or not _loot_queue.is_empty() or (on == "rest" and (screen != null or dialogue != null))


func _strahd_after_loot(on: String, ctx: Dictionary) -> void:
	while _strahd_holds(on):
		if loot != null:
			await loot.closed
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_strahd(on, ctx)


## A leg of a journey is over: a visit on the road stops it on the road's map, like a road event; the journey goes
## on when the visit is done (StoryState.travel_resume).
func _strahd_on_road(leg: Dictionary, to: String) -> bool:
	var visit := StrahdPresence.due(st, "travel", {"location": "", "outdoors": true})
	if visit.is_empty():
		return false
	st.travel_resume = {"to": to, "at": str(leg["to"])}
	var road := StrahdPresence.road_map(visit, leg["road"] as Dictionary)
	_covered(road, func() -> void:
		enter_location(road, "default")
		_strahd_step(StrahdPresence.begin(st, visit)))
	return true


## A Long Rest is over (the rest screen, a camp's night, a magic item's rest; `minutes` since it began): he may have
## come in the night, and comes once the screen it was taken from, and any talk started there, are done
## (_strahd_holds). A visit that may come to blows broke the rest before its benefits (LongRest: the rest asked for it
## by the night it ran through, kept with it); when it's over the party sleeps on (_sleep_again).
func strahd_after_rest(minutes: int) -> void:
	var b := LongRest.broken_rest(st)
	var night := bool(b["night"]) if LongRest.waits_on_strahd(st) and b.has("night") \
		else StrahdPresence.night_between(st.total_minutes() - minutes, st.total_minutes())
	_strahd("rest", {"night": night})


## Whether Strahd's visit that broke a Long Rest is over: it came (his memory's last visit is no earlier than the
## break) and nothing of it is still to play.
func _night_visit_over() -> bool:
	if not LongRest.waits_on_strahd(st):
		return false
	var mem := StrahdPresence.memory(st)
	return int(mem["last"]) >= int(LongRest.broken_rest(st).get("at", 0)) and (mem["pending"] as Dictionary).is_empty()


## What broke the night's rest is over (its fight won, Strahd's visit done): the party lies down again and finishes
## the Long Rest by itself (LongRest.resume; the owner, 2026-10-13), unless foes still wait here. At camp the camp's
## own morning follows (LocationCamp.night); elsewhere the night's lines and the morning's word come over the place,
## as after a magic item's rest, and Strahd may still come.
func _sleep_again() -> void:
	if view == null or not LongRest.broken(st):
		return
	var res := LongRest.resume(st, Dice.roller)
	var camp := LocationCamp.of(view)
	if camp != null:
		camp.night(res)
		return
	var said: Array[String] = [str(res["text"])]
	if str(res["how"]) == LongRest.SLEPT:
		st.morning["prepared"] = PrepareScreen.snapshot(st)
		for line: String in res["lines"]:
			said.append(line)
		said.append_array([RestScreen.night_words(self, st), RestScreen.talk_hint(st)])
	hud.narrate(" ".join(said.filter(func(t: String) -> bool: return t != "")))
	_refresh()
	if str(res["how"]) in [LongRest.SLEPT, LongRest.STRAHD]:
		strahd_after_rest.call_deferred(int(res["minutes"]))


## A save made while the night's rest was broken and no fight was under way: Strahd's visit that broke it comes now,
## or the party sleeps on.
func _night_after_load() -> void:
	if LongRest.waits_on_strahd(st) and not _night_visit_over():
		strahd_after_rest(0)
	else:
		_sleep_again()


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
## The place's name shown on arriving (PlaceTitle), while it's up.
var _title: PlaceTitle = null
var _card_region := ""   ## the region whose loading card was shown last


## A new place comes up out of black instead of cutting to it (docs/plans/ui_polish.md): the screen goes dark at once
## and the place fades in. The change itself isn't delayed, so nothing that waits on it notices. Behind a cover
## (`_covered`) the black stays until the cover lifts it.
func _fade_from_black() -> void:
	if not is_inside_tree():
		return
	_black_now()
	if not moving:
		_fade_in_place(0.12)


## The screen black at once (layer 39: over the HUDs, under the time-passing fade, the loading card and the menus).
func _black_now() -> void:
	if _place_fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 39
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


## The place fades in from black after `delay` seconds, paused game or not: a place's arrival picture pauses the game
## as it opens, and a fade that waited for it left the screen black over the picture until a click closed it (Ashwin,
## first walk into the Village of Barovia, 2026-10-08).
func _fade_in_place(delay: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	tw.tween_property(_place_fade, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_place_fade.set_meta(&"tween", tw)
	PlaceDissolve.play(self, delay)   # and the world sharpens out of a soft blur as the black lifts (Visual Polish Plan 10)


# --- Changing place behind a cover (the loading lane) ----------------------------------------------

## A change of place expected to take longer than this (ms: the build and its first two frames) shows the loading
## card; a quicker one shows a moment of black and fades in, so no card flashes up and away.
const CARD_MS := 500.0
## The guess for a place not timed yet this session (headless, 2026-10-08: interiors took 0.1 to 0.45 s to build,
## towns and the open country 0.5 to 1.65 s, before the GPU's share).
const GUESS_OUTDOORS_MS := 900.0
const GUESS_INDOORS_MS := 350.0
## Seconds a card put up only for the wait (not for a new region) stays at least, so it never flashes.
const CARD_MIN_HOLD := 1.0
## Changes of place timed this session: location id -> ms (the build and its first two frames).
static var took_ms: Dictionary = {}
## A change of place is under way behind its cover: the game takes no input and the old place stands still.
var moving := false
## A journey's legs are being worked out (travel): time passing in them makes no autosave.
var _journeying := false
## The sprite sheets being read for the change under way (collected if the game goes before it's done).
var _preload: PlacePreload = null


## How long a change of place to location `to` is expected to take (ms): as long as it took last time this session,
## else a guess by whether it's out of doors.
static func expected_ms(to: String) -> float:
	if took_ms.has(to):
		return float(took_ms[to])
	var map: Dictionary = Compendium.shared().get_entry("locations", to).get("map", {}) if Compendium.shared().has("locations", to) else {}
	return GUESS_OUTDOORS_MS if bool(map.get("outdoors", false)) else GUESS_INDOORS_MS


## Makes a change of place (`change`, which ends at location `to`) behind a cover, so the player never sees the old
## place frozen while the new one is built: the screen goes black at once and, when the change is slow or reaches a
## new region, the loading card comes up. The sprite sheets the place will show load on worker threads meanwhile
## (PlacePreload), and only once the cover has been drawn does `change` run (one long frame). The cover stays over the
## new place's first two frames, while its shaders and textures reach the GPU; then the black fades and the card goes
## after its hold. Inside a change already covered, and with motion off (tests, captures), it just makes the change.
func _covered(to: String, change: Callable) -> void:
	if moving or not UiMotion.on() or not is_inside_tree():
		change.call()
		return
	moving = true
	glow.clear()
	var old := view
	if old != null:
		old.process_mode = Node.PROCESS_MODE_DISABLED   # the old place stands still under the cover
	var loc: Dictionary = Compendium.shared().get_entry("locations", to) if Compendium.shared().has("locations", to) else {}
	var region := str(loc.get("region", ""))
	var new_region := region != _card_region
	var card: LoadingCard = null
	_black_now()
	_place_fade.mouse_filter = Control.MOUSE_FILTER_STOP   # clicks don't reach the HUD under the black
	if new_region or expected_ms(to) >= CARD_MS:
		_card_region = region
		card = LoadingCard.cover(self, loc, LoadingCard.HOLD_SECONDS if new_region else CARD_MIN_HOLD)
		await get_tree().create_timer(LoadingCard.FADE_IN).timeout
	_preload = PlacePreload.start(loc, st)
	await _preload.wait(self)
	if is_inside_tree():
		await get_tree().process_frame   # the frame before this one, with the cover up, has been drawn
	if not is_inside_tree():
		return
	var t := Time.get_ticks_usec()
	change.call()
	if is_instance_valid(old) and old == view:
		old.process_mode = Node.PROCESS_MODE_INHERIT   # the change didn't go anywhere after all
	for i in 2:
		if is_inside_tree():
			await get_tree().process_frame
	took_ms[to] = (Time.get_ticks_usec() - t) / 1000.0
	if _preload != null:
		_preload.release()
		_preload = null
	moving = false
	if not is_inside_tree():
		return
	_place_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_in_place(0.0)
	if is_instance_valid(card):
		if screen != null or dialogue != null:
			card.hold = 0.0   # an arrival picture or conversation opened: the card makes way for it at once
		card.lift()


## A fade to black and back when time passes (rests, journeys, waiting for noon), with how long it was.
func _on_time_passed(minutes: int) -> void:
	if not is_inside_tree():
		return
	if not _journeying:
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
	if _preload != null:   # left in the middle of a change of place: its threaded loads are collected all the same
		_preload.release()
		_preload = null
	if st != null and st.time_passed.is_connected(_on_time_passed):
		st.time_passed.disconnect(_on_time_passed)
	if st != null and st.item_gained.is_connected(notices.show_item):
		st.item_gained.disconnect(notices.show_item)
	if st != null and is_instance_valid(hud) and st.xp_gained.is_connected(hud.toast):
		st.xp_gained.disconnect(hud.toast)


# --- Screens --------------------------------------------------------------------------------------

## The music for where the party is (art/audio.json: the place's own mood, else its region's as the story stands, else
## its map's theme).
func _place_mood() -> String:
	var loc := Compendium.shared().get_entry("locations", st.location)
	return Audio.mood_for(st.location, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary), st)


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
		"wait":
			screen = WaitScreen.new()
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
	# A screen that frees itself (not through close_screen) isn't left behind as the open one: Esc in a later fight
	# or a bug report would read a freed screen (owner's reports 2026-10-12 20:06 and 20:08).
	var opened := screen
	opened.tree_exited.connect(func() -> void:
		if screen == opened:
			screen = null
			if is_inside_tree():
				get_tree().paused = false)
	var fighting := view != null and view.in_combat
	if screen is CharacterSheetScreen:
		(screen as CharacterSheetScreen).in_fight = fighting   # view only in a fight (owner, 2026-10-08)
	screen.call("open", self, st, index)
	if kind in ["menu", "sheet"] and fighting:
		# The fight waits while the menu or a character sheet is open.
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


## A place's cutscene (story/cutscenes.gd): its picture over everything with the narrator's line as the caption, and
## the scene after it, if it has one (data `then`). It stands in for a full-screen panel and pauses the game until it
## closes, so nothing moves under it (a fight that an area starts waits for it too).
func play_cutscene(id: String, caption: String) -> CutscenePlayer:
	close_screen()
	var player := CutscenePlayer.new()
	add_child(player)
	player.scene_shown.connect(_cutscene_music)   # before play_scenes: the first picture's music too
	if not player.play_scenes(Cutscenes.scenes(id, caption, st, narrator, st.leader_character()), st):
		player.queue_free()
		hud.narrate(caption)
		return null
	Cutscenes.mark_played(id, st)
	screen = player
	get_tree().paused = true
	player.finished.connect(func() -> void:
		if screen == player:
			screen = null
			get_tree().paused = false
		if _cutscene_mood != "":
			_cutscene_mood = ""
			Audio.play_music(_place_mood())
		_refresh())
	return player


## A cutscene an item's power plays (story/cutscenes.gd `read:<item>`: reading the Tome of Strahd): the Narrator's line for
## `key` reads over its first picture, and `after` is what the HUD says when it closes. False, and nothing shown, when no
## cutscene fits now (it plays once).
func play_item_cutscene(key: String, after: String = "") -> bool:
	var cut := Cutscenes.for_trigger(key, st)
	if cut == "":
		return false
	var player := play_cutscene(cut, narrator.line(key, st, st.leader_character()))
	if player == null:
		return false
	if after != "":
		# A beat after the world wakes: its clock may narrate the weather the hours brought, and the reading's own
		# words (Strahd knows) should be the ones left up.
		player.finished.connect(func() -> void:
			await get_tree().create_timer(0.4, true, false, true).timeout
			if is_instance_valid(hud):
				hud.narrate(after))
	return true


## A place cutscene's picture with its own music (art/audio.json "place_scenes", as a conversation's "scenes": _scene_music)
## plays until the cutscene closes; play_cutscene brings the place's own back.
func _cutscene_music(cutscene_id: String) -> void:
	var m := Audio.place_scene_mood(cutscene_id)
	if m != "":
		_cutscene_mood = m
		Audio.play_music(m)


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
	# Never a journey that hasn't reached its road: it would load back at the start with the journey armed.
	if not st.travel_resume.is_empty() and not Travel.is_road_scene(st.location):
		return
	if SaveSystem.autosave() == OK:
		hud.saved_note()


func _quick_save() -> void:
	var err := SaveSystem.quick_save()
	hud.toast("Saved." if err == OK else "Can't save now.")


## F9: back to the game's own slot as last saved.
func _quick_load() -> void:
	# A live Honour run can't go back (Ashwin, 2026-10-09, QA D-3): its one save only moves forward.
	if SaveSystem.honour():
		hud.toast("An Honour run can't go back: the game saves as you go.")
		return
	if SaveSystem.current_slot != "" and SaveSystem.load_slot(SaveSystem.current_slot) == OK:
		get_tree().reload_current_scene()
	else:
		hud.toast("No quick save yet.")


## Closing the window in a live Honour run keeps where the party is (in a fight, the round's own save already does), so
## coming back doesn't rewind it to the last autosave (QA D-3).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and SaveSystem.honour() and view != null and not moving:
		SaveSystem.autosave()


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
