class_name LocationView
extends Node3D
## One explorable location from data/locations (plan §5.2, ADR 0009): the board built from its grid map, doors,
## props, containers, lights, NPCs and the party, with free roam on the grid. The player moves the leader (click or
## WASD) and the others follow in marching order, or moves one character alone. Interactables: doors and locks,
## containers and loot, examine and search, books for the codex, levers, NPCs (dialogue), exits. Traps are noticed
## by passive Perception, searched for, disarmed or sprung. Areas trigger narration and fights; a fight happens in
## place on the same grid (CombatView). It shows and records state in GameState.story; it never decides for a party
## member.
##
## The view holds the location's state. Its jobs live in helpers that take it as their first argument, a file each:
## LocationBuilder (the board's pieces and the time of day), LocationParty (the party's figures), LocationWalk
## (walking and what a step sets off), LocationNpcs (the people here), LocationStealth (sneaking, foes waiting in
## plain view and who notices whom), LocationPlan (turn-based exploring), LocationInteraction (clicks, the
## right-click menu, containers and props), LocationLocks (doors and locks), LocationTraps (traps and
## searching), LocationCare (a party member down outside a fight), LocationMagic (exploring spells and items) and
## LocationFights (fights on this grid). The forwarding functions below are the view's interface for the game root,
## the HUD and the tests.

signal exit_requested(location_id: String, spawn: String)
signal dialogue_requested(ref: String, npc_id: String)
signal narration(text: String)
## A place's cutscene (story/cutscenes.gd `trigger`): its picture, with the narrator's line as the caption.
signal cutscene_requested(id: String, caption: String)
signal toast(text: String)
signal loot_opened(container_id: String, items: Array, gold: float)
signal combat_started(view: CombatView)
signal combat_ended(outcome: String)
signal check_rolled(text: String)
## A check or save the player made on purpose or can't miss (a lock picked or forced, a pocket, a trap disarmed or
## sprung on them, a climb out of a pit, tending the dying): the big d20 rolls it (DiceRoll). `label` is what was
## rolled ("Athletics", "Dexterity saving throw").
signal big_roll(test: D20Test, who: String, label: String)
signal hover_changed(text: String)
signal banter(lines: Array)
## The party reached a road out of here (an exit to "travel"): the game opens the map.
signal travel_requested
## A party member down outside a fight was stabilized or healed from the right-click menu.
signal party_tended

## Seconds a square takes walking (owner 2026-10-07: tokens moved too fast between squares; about 30% slower than
## the earlier 0.18 and 0.32).
const STEP_TIME := 0.26
const SNEAK_STEP_TIME := 0.46
const DOOR_OPEN := "open"

var loc: Dictionary = {}
var loc_id := ""
var grid: CombatGrid
var board: ArenaBoard
var rig: CameraRig
var post: MeshInstance3D
var st: StoryState
var narrator: Narrator
var dice: DiceRoller
var banter_player: Banter = null
var _last_banter := -1000

## Party members on the map (marching order = st.party order) and their tokens.
var members: Array[Combatant] = []
var tokens: Dictionary = {}          ## combatant id -> CombatToken
var npc_tokens: Dictionary = {}      ## npc id -> CombatToken
var _env: Environment
var _sun: DirectionalLight3D
var atmosphere: Atmosphere
var guest_members: Array[Combatant] = []   ## story allies following the party (StoryState.guests)
var _npc_shown: Array[Dictionary] = []   ## [{spec, token, cell, low_before}] for the NPC entries standing here now
var door_nodes: Dictionary = {}      ## door id -> Node3D
var container_nodes: Dictionary = {}
var prop_nodes: Dictionary = {}
var exit_nodes: Dictionary = {}       ## exit id -> its door or stairs piece (SetDressing.exit_piece)
var trap_marks: Dictionary = {}
var lantern: OmniLight3D

var sneaking := false
## Sneaking and foes in plain view (LocationStealth, F7): each member's Stealth total while sneaking, and the foes of
## `waiting` fights standing where their fight puts them [{encounter, foe: Combatant, token, low}].
var sneak_totals: Dictionary = {}    ## Creature -> int
var waiting: Array[Dictionary] = []
var _waiting_key := ""                ## what the party could see from when the waiting foes were last looked for
## A foe noticed the party: the fight it starts surprises no one (LocationStealth).
var _foes_alerted := false
## Turn-based exploring (LocationPlan, F7): rounds of six seconds, each member moving up to their Speed.
var planning := false
var plan_round := 0
var plan_left: Dictionary = {}       ## combatant id -> feet of movement left this round
var _plan_seconds := 0
var _solo_before := false
var solo := false                    ## move only the leader (split the party)
var busy := false                    ## walking, talking or fighting
var in_combat := false
var combat_view: CombatView = null
## The encounter spec of the fight that ended last (the game reads its `final_battle` when combat_ended fires).
var last_encounter: Dictionary = {}
## A final battle waiting for Strahd's parley to end (ADR 0014): its encounter id, or "".
var _pending_final := ""
## Strahd names his price before a final battle (the presence package writes it).
const PARLEY := "strahd/final:parley"
var hover_cell := Vector2i(-1, -1)
var input_locked := false

var _queue: Array[Vector2i] = []     ## the leader's remaining path
var _on_arrive: Callable = Callable()
var _step_t := 0.0
## Party tokens gliding between squares (PartyGlide), by token id.
var _glides: Dictionary = {}
var _areas_in: Dictionary = {}
var _exit_check := 0.0
## The party crouches while sneaking (CombatToken.sneaking; sprites with the fuller animation set show it).
var _shown_sneaking := false
var _spawn_name := ""
## Figures a conversation brought on: npc id -> token. Gone when the conversation ends (or at `vanish`).
var _staged: Dictionary = {}


static func create(location_id: String, state: StoryState, narrator_: Narrator, dice_: DiceRoller, spawn: String = "") -> LocationView:
	var v := LocationView.new()
	v.name = "Location_" + location_id
	v.loc_id = location_id
	# A copy: random encounters on the road add fights to it for the length of a visit.
	v.loc = Compendium.shared().get_entry("locations", location_id).duplicate(true)
	v.st = state
	v.narrator = narrator_
	v.dice = dice_
	v._spawn_name = spawn
	return v


func _ready() -> void:
	assert(not loc.is_empty(), "No location %s" % loc_id)
	grid = grid_for(loc)
	board = ArenaBoard.build(grid, ArenaBoard.theme_for(loc["map"] as Dictionary), loc_id)
	add_child(board)
	LocationBuilder._build_environment(self)
	LocationBuilder._build_doors(self)
	LocationBuilder._build_props(self)
	LocationBuilder._build_lights(self)
	LocationNpcs._build_npcs(self)
	LocationParty._place_party(self)
	LocationTraps._mark_found_traps(self)
	rig = CameraRig.new()
	add_child(rig)
	rig.zoom_max = 30.0
	rig.distance = 13.0
	rig.rotate_step(-1)
	rig.camera.current = true
	post = Look.make_post_process()
	rig.camera.add_child(post)
	atmosphere.attach(rig, post)
	rig.follow = tokens[members[0].id] as Node3D if not members.is_empty() else null
	rig.snap_to_target()
	st.location = loc_id
	var first := not st.visited.has(loc_id)
	st.visited[loc_id] = true
	_say(str((loc.get("narration", {}) as Dictionary).get("enter", "enter:" + loc_id)))
	if first and str(loc.get("text", "")) != "":
		narration.emit(str(loc["text"]))
	add_child(HiddenAreas.create(self))   # rooms behind undiscovered secret doors stay out of sight
	add_child(SightOverlay.create(self))   # who can see the party while it sneaks or plans (U10)
	add_child(WorldSounds.create(self))   # footsteps, fires and running water heard from where they are (A3)
	LocationWalk._check_areas(self)
	if LocationPlan.wanted() and not in_combat:
		LocationPlan.start(self)
	LocationStealth.refresh_waiting(self)


func _process(delta: float) -> void:
	LocationStealth.show_crouch(self)
	_exit_check -= delta
	if _exit_check <= 0.0:
		_exit_check = 0.25
		refresh_exits()
		LocationStealth.refresh_waiting(self)   # a door opened, a lamp lit: foes come into view
	if board != null and rig != null and rig.camera != null and not members.is_empty() and (not board.occluders.is_empty() or not board.mesh_occluders.is_empty() or not board.buildings.is_empty()):
		var focus := (tokens[leader().id] as Node3D).global_position if tokens.has(leader().id) else Vector3.ZERO
		if is_instance_valid(rig.cutaway_focus):
			focus = rig.cutaway_focus.global_position   # a boss's entrance (G3): the walls clear the view to the boss
		board.fade_occluders(rig.camera.global_position, focus, delta)
		board.cut_buildings(rig.camera.global_position, focus, delta)
	LocationWalk._update_glides(self, delta)
	LocationWalk.tick(self, delta)


func leader() -> Combatant:
	return members[0] if not members.is_empty() else null


## Plays a Narrator trigger; falls back to `fallback` text. Returns true if anything was said.
func _say(key: String, actor: Character = null, fallback: String = "") -> bool:
	var text := narrator.line(key, st, actor if actor != null else (leader().creature as Character if leader() != null else null)) if narrator != null else ""
	if text == "":
		text = fallback
	if text != "":
		var cut := Cutscenes.for_trigger(key, st) if not cutscene_requested.get_connections().is_empty() else ""
		if cut != "":
			cutscene_requested.emit(cut, text)
		else:
			narration.emit(text)
		return true
	return false


## A location's grid as authored: its map rows, its natural ground (`elevation`) and the props stood on above the
## ground (a prop's `stand_ft`: a podium, a platform, a tree climbed into; CombatGrid.raise).
static func grid_for(loc: Dictionary) -> CombatGrid:
	var map := loc["map"] as Dictionary
	var g := CombatGrid.from_rows(map["rows"] as Array, map.get("elevation", []) as Array)
	for p: Variant in loc.get("props", []):
		var prop := p as Dictionary
		if int(prop.get("stand_ft", 0)) > 0:
			for c in BattleScenery.span_cells(prop):
				g.raise(c, int(prop["stand_ft"]))
	return g


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


# --- The board's pieces (LocationBuilder) ----------------------------------------------------------

func update_daylight() -> void:
	LocationBuilder.update_daylight(self)


func time_phase() -> String:
	return LocationBuilder.time_phase(self)


func refresh_exits() -> void:
	LocationBuilder.refresh_exits(self)


# --- The people here (LocationNpcs) -----------------------------------------------------------------

func refresh_npcs() -> void:
	LocationNpcs.refresh_npcs(self)


func stage_npc(npc_id: String, at: String = "") -> void:
	LocationNpcs.stage_npc(self, npc_id, at)


func unstage_npc(npc_id: String) -> void:
	LocationNpcs.unstage_npc(self, npc_id)


func clear_staged() -> void:
	LocationNpcs.clear_staged(self)


func hide_npcs_of(dialogue_ref: String) -> void:
	LocationNpcs.hide_npcs_of(self, dialogue_ref)


# --- The party (LocationParty) and walking (LocationWalk) --------------------------------------------

func rebuild_party() -> void:
	LocationParty.rebuild_party(self)


func place_guests() -> void:
	LocationParty.place_guests(self)


func set_leader(index: int) -> void:
	LocationParty.set_leader(self, index)


func _save_positions() -> void:
	LocationParty._save_positions(self)


func walk_to(cell: Vector2i, then: Callable = Callable()) -> bool:
	return LocationWalk.walk_to(self, cell, then)


func _path(from: Vector2i, to: Vector2i, around_traps: bool = true) -> Array[Vector2i]:
	return LocationWalk._path(self, from, to, around_traps)


func step(dir: Vector2i) -> void:
	LocationWalk.step(self, dir)


static func _in_area(area: Dictionary, c: Vector2i) -> bool:
	return LocationWalk._in_area(area, c)


# --- Sneaking (LocationStealth) and turn-based exploring (LocationPlan) -------------------------------

func set_sneaking(on: bool) -> void:
	LocationStealth.set_sneaking(self, on)


func toggle_plan() -> void:
	LocationPlan.toggle(self)


func next_round() -> void:
	LocationPlan.next_round(self)


## Opens the fight with foes the party can see (the nearest, or `encounter_id`). True if it started.
func strike(encounter_id: String = "") -> bool:
	var id := encounter_id if encounter_id != "" else LocationStealth.nearest_waiting(self)
	return id != "" and LocationStealth.strike(self, id)


# --- Using things (LocationInteraction), doors and locks (LocationLocks) -----------------------------

func actions_at(cell: Vector2i) -> Dictionary:
	return LocationInteraction.actions_at(self, cell)


func act(cell: Vector2i, action_id: String) -> void:
	LocationInteraction.act(self, cell, action_id)


func pick_cell(camera: Camera3D, screen: Vector2) -> Vector2i:
	return LocationInteraction.pick_cell(self, camera, screen)


func _pickables() -> Array:
	return LocationInteraction._pickables(self)


func thing_at(cell: Vector2i) -> Dictionary:
	return LocationInteraction.thing_at(self, cell)


func click(cell: Vector2i) -> void:
	LocationInteraction.click(self, cell)


func interact(thing: Dictionary) -> void:
	LocationInteraction.interact(self, thing)


func _use_container(ct: Dictionary, method: String = "auto") -> void:
	LocationInteraction._use_container(self, ct, method)


func mark_looted(container_id: String) -> void:
	LocationInteraction.mark_looted(self, container_id)


func _locked(spec: Dictionary) -> bool:
	return LocationLocks._locked(self, spec)


static func _pick_bonus(picker: Character, adv: Array[String]) -> Breakdown:
	return LocationLocks._pick_bonus(picker, adv)


# --- Traps and searching (LocationTraps), the party's care (LocationCare), field magic (LocationMagic) ----------

func search() -> void:
	LocationTraps.search(self)


func _show_trap(trap: Dictionary) -> void:
	LocationTraps._show_trap(self, trap)


func refresh_party() -> void:
	LocationCare.refresh_party(self)


func apply_spell_effect(spell_id: String) -> void:
	LocationMagic.apply_spell_effect(self, spell_id)


# --- Fights (LocationFights) -------------------------------------------------------------------------

func start_encounter(encounter_id: String) -> bool:
	return LocationFights.start_encounter(self, encounter_id)


func start_custom_encounter(spec: Dictionary) -> bool:
	return LocationFights.start_custom_encounter(self, spec)


func resume_encounter(snapshot: Dictionary) -> bool:
	return LocationFights.resume_encounter(self, snapshot)


func check_flag_encounters() -> bool:
	return LocationFights.check_flag_encounters(self)


func _trigger_encounter(trigger: String) -> bool:
	return LocationFights._trigger_encounter(self, trigger)


func _spoils(encounter_id: String, spec: Dictionary, with_loot: bool = true) -> void:
	LocationFights._spoils(self, encounter_id, spec, with_loot)


static func ward_for(data: Dictionary, location: Dictionary, state: StoryState) -> int:
	return LocationFights.ward_for(data, location, state)
