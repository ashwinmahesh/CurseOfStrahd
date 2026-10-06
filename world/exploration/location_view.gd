class_name LocationView
extends Node3D
## One explorable location from data/locations (plan §5.2, ADR 0009): the board built from its grid map, doors,
## props, containers, lights, NPCs and the party, with free roam on the grid. The player moves the leader (click or
## WASD) and the others follow in marching order, or moves one character alone. Interactables: doors and locks,
## containers and loot, examine and search, books for the codex, levers, NPCs (dialogue), exits. Traps are noticed
## by passive Perception, searched for, disarmed or sprung. Areas trigger narration and fights; a fight happens in
## place on the same grid (CombatView). It shows and records state in GameState.story; it never decides for a party
## member.

signal exit_requested(location_id: String, spawn: String)
signal dialogue_requested(ref: String, npc_id: String)
signal narration(text: String)
signal toast(text: String)
signal loot_opened(container_id: String, items: Array, gold: float)
signal combat_started(view: CombatView)
signal combat_ended(outcome: String)
signal check_rolled(text: String)
signal hover_changed(text: String)
signal banter(lines: Array)

const STEP_TIME := 0.18
const SNEAK_STEP_TIME := 0.32
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
var _npc_shown: Array[Dictionary] = []   ## [{spec, token, cell, low_before}] for the NPC entries standing here now
var door_nodes: Dictionary = {}      ## door id -> Node3D
var container_nodes: Dictionary = {}
var prop_nodes: Dictionary = {}
var trap_marks: Dictionary = {}
var lantern: OmniLight3D

var sneaking := false
var solo := false                    ## move only the leader (split the party)
var busy := false                    ## walking, talking or fighting
var in_combat := false
var combat_view: CombatView = null
var hover_cell := Vector2i(-1, -1)
var input_locked := false

var _queue: Array[Vector2i] = []     ## the leader's remaining path
var _on_arrive: Callable = Callable()
var _step_t := 0.0
var _areas_in: Dictionary = {}


static func create(location_id: String, state: StoryState, narrator_: Narrator, dice_: DiceRoller, spawn: String = "") -> LocationView:
	var v := LocationView.new()
	v.name = "Location_" + location_id
	v.loc_id = location_id
	v.loc = Compendium.shared().get_entry("locations", location_id)
	v.st = state
	v.narrator = narrator_
	v.dice = dice_
	v._spawn_name = spawn
	return v


var _spawn_name := ""


func _ready() -> void:
	assert(not loc.is_empty(), "No location %s" % loc_id)
	grid = CombatGrid.from_rows(loc["map"]["rows"] as Array)
	board = ArenaBoard.build(grid, str(loc["map"].get("theme", "manor")))
	add_child(board)
	_build_environment()
	_build_doors()
	_build_props()
	_build_lights()
	_build_npcs()
	_place_party()
	_mark_found_traps()
	rig = CameraRig.new()
	add_child(rig)
	rig.zoom_max = 30.0
	rig.distance = 13.0
	rig.rotate_step(-1)
	rig.camera.current = true
	post = Look.make_post_process()
	rig.camera.add_child(post)
	rig.follow = tokens[members[0].id] as Node3D if not members.is_empty() else null
	rig.snap_to_target()
	st.location = loc_id
	var first := not st.visited.has(loc_id)
	st.visited[loc_id] = true
	_say(str((loc.get("narration", {}) as Dictionary).get("enter", "enter:" + loc_id)))
	if first and str(loc.get("text", "")) != "":
		narration.emit(str(loc["text"]))
	_check_areas()


# --- Building -------------------------------------------------------------------------------------

func _build_environment() -> void:
	var light := str(loc["map"].get("light", "dim"))
	var outdoors := bool(loc["map"].get("outdoors", false))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Look.color("night_deep") if outdoors else Look.color("void")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("mist_blue") if outdoors else Look.color("bruise")
	env.ambient_light_energy = {"bright": 1.2, "dim": 0.75, "dark": 0.35}.get(light, 0.75) as float
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Look.color("grave")
	env.fog_density = 0.02 if outdoors else 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Look.color("moonlight")
	moon.light_energy = 0.8 if outdoors else (0.25 if light != "dark" else 0.08)
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 35, 0)
	add_child(moon)
	if light == "dark" or not outdoors:
		# The party's lantern (or a Light cantrip): it goes where the leader goes.
		lantern = OmniLight3D.new()
		lantern.light_color = Look.color("candle")
		lantern.omni_range = 7.0
		lantern.light_energy = 1.6
		lantern.position = Vector3(0, 1.6, 0)


func _door_state(id: String) -> String:
	return str((st.loc_state(loc_id)["doors"] as Dictionary).get(id, ""))


func _build_doors() -> void:
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		var cell := _cell(door["cell"])
		var id := str(door["id"])
		var secret := int(door.get("secret_dc", 0)) > 0 and not bool((st.loc_state(loc_id)["found"] as Dictionary).get(id, false))
		var open := _door_state(id) == DOOR_OPEN
		grid.set_flag(cell, CombatGrid.WALL, not open)
		var node := _box(Vector3(0.9, 1.7, 0.9), board.cell_center(cell) + Vector3(0, 0.85, 0), "walnut" if not secret else "slate")
		node.visible = not open
		door_nodes[id] = node


func _build_props() -> void:
	for p: Variant in loc.get("props", []):
		var prop := p as Dictionary
		if not StoryConditions.check(str(prop.get("when", "")), st):
			continue
		var id := str(prop["id"])
		var kind := str(prop["kind"])
		if kind == "search" and not bool((st.loc_state(loc_id)["found"] as Dictionary).get(id, false)):
			continue
		var colour := {"examine": "parchment", "book": "ember", "search": "bone", "lever": "pewter", "decor": "stone"}.get(kind, "bone") as String
		prop_nodes[id] = _box(Vector3(0.45, 0.35, 0.45), board.cell_center(_cell(prop["cell"])) + Vector3(0, 0.2, 0), colour)
	for c: Variant in loc.get("containers", []):
		var ct := c as Dictionary
		if not StoryConditions.check(str(ct.get("when", "")), st):
			continue
		var looted := bool((st.loc_state(loc_id)["looted"] as Dictionary).get(str(ct["id"]), false))
		container_nodes[str(ct["id"])] = _box(Vector3(0.8, 0.55, 0.55), board.cell_center(_cell(ct["cell"])) + Vector3(0, 0.28, 0),
			"umber" if not looted else "peat")


func _build_lights() -> void:
	for l: Variant in loc.get("lights", []):
		var li := l as Dictionary
		var omni := CandleFlicker.new()
		omni.light_color = Look.color("candle")
		var dim := float(li.get("dim_ft", 20)) / 5.0
		omni.omni_range = maxf(2.0, dim)
		omni.base_energy = 1.4 if str(li["kind"]) in ["candle", "lamp"] else 2.2
		omni.position = board.cell_center(_cell(li["cell"])) + Vector3(0, 1.2, 0)
		add_child(omni)


## Re-reads which NPCs, props and containers are here (their `when` conditions) after a conversation or a fight
## changes the story.
func refresh_npcs() -> void:
	for id: String in prop_nodes:
		(prop_nodes[id] as Node).queue_free()
	prop_nodes.clear()
	for id: String in container_nodes:
		(container_nodes[id] as Node).queue_free()
	container_nodes.clear()
	_build_props()
	for shown in _npc_shown:
		(shown["token"] as Node).queue_free()
		if not bool(shown["low_before"]):
			grid.set_flag(shown["cell"] as Vector2i, CombatGrid.LOW, false)
	_npc_shown.clear()
	npc_tokens.clear()
	_build_npcs()


func _build_npcs() -> void:
	for n: Variant in loc.get("npcs", []):
		var spec := n as Dictionary
		if not StoryConditions.check(str(spec.get("when", "")), st):
			continue
		if npc_tokens.has(str(spec["npc"])):
			continue   # one entry per NPC at a time: the first whose condition holds
		var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
		var mon_id := str(npc.get("monster", "commoner"))
		var data := Compendium.shared().monster_data(mon_id)
		if data.is_empty():
			data = Compendium.shared().monster_data("commoner")
		var m := Monster.from_data(data)
		m.name = str(npc.get("name", spec["npc"]))
		var cb := Combatant.new(m, &"neutral", _cell(spec["cell"]))
		cb.id = "npc_" + str(spec["npc"])
		var tok := _npc_token(cb, str(npc.get("sprite", spec["npc"])))
		tok.position = board.cell_center(cb.cell)
		add_child(tok)
		npc_tokens[str(spec["npc"])] = tok
		_npc_shown.append({"spec": spec, "token": tok, "cell": cb.cell, "low_before": grid.has_flag(cb.cell, CombatGrid.LOW)})
		grid.set_flag(cb.cell, CombatGrid.LOW, true)   # an NPC blocks the square while standing there


func _npc_token(cb: Combatant, art: String) -> CombatToken:
	return CombatToken.create(cb, art)


## Places the party at the spawn (or the saved positions when loading into this location).
func _place_party() -> void:
	var spawns := loc.get("spawns", {}) as Dictionary
	var start := _cell(spawns.get(_spawn_name, spawns.get("default", [1, 1])))
	var use_saved := _spawn_name == "" and st.location == loc_id and st.positions.size() == st.party.size()
	var cells: Array[Vector2i] = []
	if use_saved:
		cells = st.positions.duplicate()
	else:
		cells = _cells_around(start, st.party.size())
	members.clear()
	for i in st.party.size():
		var ch := st.party[i]
		var cb := Combatant.new(ch, &"party", cells[i])
		members.append(cb)
		var tok := CombatToken.create(cb)
		tok.position = board.cell_center(cb.cell)
		add_child(tok)
		tokens[cb.id] = tok
	_save_positions()
	if lantern != null and not members.is_empty():
		(tokens[members[0].id] as Node3D).add_child(lantern)


func _cells_around(start: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var reach := grid.reachable(start, 1, 60, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false)
	var cells: Array = reach.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(reach[a]["cost"]) < int(reach[b]["cost"]))
	for c: Vector2i in cells:
		if out.size() >= n:
			break
		if not c in out:
			out.append(c)
	while out.size() < n:
		out.append(start)
	return out


func _mark_found_traps() -> void:
	for t: Variant in loc.get("traps", []):
		var trap := t as Dictionary
		var state := str((st.loc_state(loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
		if state == "found":
			_show_trap(trap)


func _show_trap(trap: Dictionary) -> void:
	if trap_marks.has(str(trap["id"])):
		return
	var nodes: Array[Node3D] = []
	for c: Variant in trap["cells"]:
		var mark := _box(Vector3(0.8, 0.02, 0.8), board.cell_center(_cell(c)) + Vector3(0, 0.02, 0), "vampire_red")
		nodes.append(mark)
	trap_marks[str(trap["id"])] = nodes


func _box(size: Vector3, pos: Vector3, colour: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Look.cel(colour)
	add_child(mi)
	return mi


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


# --- Party movement -------------------------------------------------------------------------------

func leader() -> Combatant:
	return members[0] if not members.is_empty() else null


## Walks the leader to `cell` (followers trail behind unless solo), then calls `then` on arrival.
func walk_to(cell: Vector2i, then: Callable = Callable()) -> bool:
	if busy or in_combat or members.is_empty():
		return false
	var path := _path(leader().cell, cell)
	if path.is_empty():
		toast.emit("Can't get there")
		return false
	_queue = path.slice(1)
	_on_arrive = then
	if _queue.is_empty():
		if then.is_valid():
			then.call()
		elif _exit_at(cell):
			_check_cell_events()   # standing on a way out and clicking it again: go
	return true


func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var avoid := {}
	for t: Variant in loc.get("traps", []):
		var trap := t as Dictionary
		if str((st.loc_state(loc_id)["traps"] as Dictionary).get(str(trap["id"]), "")) == "found":
			for c: Variant in trap["cells"]:
				avoid[_cell(c)] = true
	avoid.erase(to)
	# Closed doors that would open at a touch are part of the way: the party opens them as it reaches them.
	var doors := _openable_doors()
	# An exit set into a wall (a house's front door on the village map) is walked into like a door.
	if grid.has_flag(to, CombatGrid.WALL) and _exit_at(to):
		doors[to] = {}
	for c: Vector2i in doors:
		grid.set_flag(c, CombatGrid.WALL, false)
	var reach := grid.reachable(from, 1, 2000, func(c: Vector2i) -> bool: return avoid.has(c),
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	for c: Vector2i in doors:
		grid.set_flag(c, CombatGrid.WALL, true)
	return CombatGrid.path_to(reach, to)


func _exit_at(cell: Vector2i) -> bool:
	for ex: Variant in loc.get("exits", []):
		if _cell((ex as Dictionary)["cell"]) == cell:
			return true
	return false


## Closed, unlocked, known doors whose conditions hold: {cell: door spec}.
func _openable_doors() -> Dictionary:
	var out := {}
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		var id := str(door["id"])
		if _door_state(id) == DOOR_OPEN or _locked(door):
			continue
		if int(door.get("secret_dc", 0)) > 0 and not bool((st.loc_state(loc_id)["found"] as Dictionary).get(id, false)):
			continue
		if not StoryConditions.check(str(door.get("when", "")), st):
			continue
		out[_cell(door["cell"])] = door
	return out


## One square in a direction (WASD).
func step(dir: Vector2i) -> void:
	if busy or in_combat or members.is_empty() or not _queue.is_empty():
		return
	var to := leader().cell + dir
	if grid.step_cost(leader().cell, to, 1, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false) < 0:
		return
	_queue = [to]


func _process(delta: float) -> void:
	if in_combat or _queue.is_empty():
		return
	_step_t -= delta
	if _step_t > 0.0:
		return
	_step_t = SNEAK_STEP_TIME if sneaking else STEP_TIME
	var next: Vector2i = _queue.pop_front()
	if grid.has_flag(next, CombatGrid.WALL) and not _exit_at(next):
		var door := _openable_doors().get(next, {}) as Dictionary
		if not door.is_empty():
			_use_door(door)
		if grid.has_flag(next, CombatGrid.WALL) or in_combat:
			_queue.clear()
			_on_arrive = Callable()
			return
	_advance_party(next)
	if _check_cell_events():
		_queue.clear()
		_on_arrive = Callable()
		return
	if _queue.is_empty():
		for m in members:
			(tokens[m.id] as CombatToken).face(Vector2.ZERO, false)
		_save_positions()
		if _on_arrive.is_valid():
			var cb := _on_arrive
			_on_arrive = Callable()
			cb.call()


## The leader steps to `next`; each follower steps into the square the one ahead of it just left.
func _advance_party(next: Vector2i) -> void:
	var old: Array[Vector2i] = []
	for m in members:
		old.append(m.cell)
	_move_member(0, next)
	if solo:
		return
	for i in range(1, members.size()):
		if members[i].creature.hp <= 0:
			continue
		if old[i - 1] != members[i].cell:
			_move_member(i, old[i - 1])


func _move_member(i: int, to: Vector2i) -> void:
	var m := members[i]
	var from := m.cell
	m.cell = to
	var tok := tokens[m.id] as CombatToken
	tok.face(Vector2(to - from), true)
	var tw := create_tween()
	tw.tween_property(tok, "position", board.cell_center(to), (SNEAK_STEP_TIME if sneaking else STEP_TIME) * 0.95)


func _save_positions() -> void:
	st.positions.clear()
	for m in members:
		st.positions.append(m.cell)


## Sets who leads (and speaks): moves them to the front of the marching order.
func set_leader(index: int) -> void:
	if index <= 0 or index >= members.size() or in_combat:
		return
	var m := members[index]
	members.remove_at(index)
	members.insert(0, m)
	var ch := st.party[index]
	st.party.remove_at(index)
	st.party.insert(0, ch)
	st.leader = 0
	rig.follow = tokens[m.id] as Node3D
	if lantern != null:
		lantern.reparent(tokens[m.id] as Node3D, false)
	toast.emit("%s leads" % ch.name)


# --- Events while walking -------------------------------------------------------------------------

## Areas, traps and exits after a step. True if something stopped the walk.
func _check_cell_events() -> bool:
	if _check_traps():
		return true
	if _check_areas():
		return true
	if _check_approach():
		return true
	for ex: Variant in loc.get("exits", []):
		var exit := ex as Dictionary
		if _cell(exit["cell"]) == leader().cell:
			if not StoryConditions.check(str(exit.get("when", "")), st):
				# A barred way only stops a walk that ends on it (passing over it, or standing there to use
				# something next to it, carries on).
				if _queue.is_empty() and not _on_arrive.is_valid():
					narration.emit(str(exit.get("locked_text", "The way is barred.")))
				return false
			_save_positions()
			st.advance_minutes(5)   # walking between places takes a few minutes; rests take the hours
			exit_requested.emit(str(exit["to"]), str(exit.get("spawn", "default")))
			return true
	return false


func _check_areas() -> bool:
	if members.is_empty():
		return false
	var c := leader().cell
	for a: Variant in loc.get("areas", []):
		var area := a as Dictionary
		var id := str(area["id"])
		var inside := _in_area(area, c)
		if inside and not _areas_in.has(id):
			_areas_in[id] = true
			st.visited[id] = true
			_say("enter:" + id)
			if _trigger_encounter("enter_area:" + id):
				return true
			_maybe_banter()
		elif not inside:
			_areas_in.erase(id)
	return false


## When a conversation ends in a fight, the people in it step aside: the encounter places its own monsters (a
## talking wolf pack, the Dursts as ghouls). Their entries' `when` decides whether they come back afterwards.
func hide_npcs_of(dialogue_ref: String) -> void:
	var file_key := dialogue_ref.substr(0, dialogue_ref.rfind(":"))
	for shown in _npc_shown:
		var ref := str((shown["spec"] as Dictionary).get("dialogue", ""))
		if ref.substr(0, ref.rfind(":")) != file_key:
			continue
		(shown["token"] as Node3D).visible = false
		if not bool(shown["low_before"]):
			grid.set_flag(shown["cell"] as Vector2i, CombatGrid.LOW, false)


## An NPC entry with `approach: n` speaks first, once, when the leader comes within n squares and can see them.
func _check_approach() -> bool:
	for shown in _npc_shown:
		var spec := shown["spec"] as Dictionary
		var reach := int(spec.get("approach", 0))
		if reach <= 0 or str(spec.get("dialogue", "")) == "":
			continue
		var key := "approach:%s:%s" % [spec["npc"], spec["dialogue"]]
		var props := st.loc_state(loc_id)["props"] as Dictionary
		if bool(props.get(key, false)):
			continue
		var at := shown["cell"] as Vector2i
		if grid.distance_ft(leader().cell, 1, at, 1) > reach * 5 or not grid.can_see(leader().cell, 1, at, 1):
			continue
		props[key] = true
		_queue.clear()
		dialogue_requested.emit(str(spec["dialogue"]), str(spec["npc"]))
		return true
	return false


static func _in_area(area: Dictionary, c: Vector2i) -> bool:
	var a := _cell((area["cells"] as Array)[0])
	var b := _cell((area["cells"] as Array)[1])
	return c.x >= mini(a.x, b.x) and c.x <= maxi(a.x, b.x) and c.y >= mini(a.y, b.y) and c.y <= maxi(a.y, b.y)


## Now and then (entering an area, at most every 10 game minutes) the party talks among themselves.
func _maybe_banter() -> void:
	if banter_player == null or st.total_minutes() - _last_banter < 10:
		return
	var lines := banter_player.next(st, str(loc.get("region", "")))
	if not lines.is_empty():
		_last_banter = st.total_minutes()
		banter.emit(lines)


## Passive Perception notices traps within 10 ft; a member stepping on an unnoticed trap springs it.
func _check_traps() -> bool:
	var states := st.loc_state(loc_id)["traps"] as Dictionary
	for t: Variant in loc.get("traps", []):
		var trap := t as Dictionary
		var id := str(trap["id"])
		if not StoryConditions.check(str(trap.get("when", "")), st):
			continue
		var state := str(states.get(id, ""))
		if state in ["disarmed", "triggered"]:
			continue
		var cells: Array[Vector2i] = []
		for c: Variant in trap["cells"]:
			cells.append(_cell(c))
		if state == "":
			for m in members:
				if m.creature.hp <= 0:
					continue
				var near := false
				for c in cells:
					if grid.distance_ft(m.cell, 1, c, 1) <= 10:
						near = true
				var passive := m.creature.passive_score(&"perception").total()
				if near and passive >= int(trap["detect_dc"]):
					states[id] = "found"
					_show_trap(trap)
					if trap.has("flag"):
						st.set_flag(str(trap["flag"]))
					_say("trap:%s:found" % id, m.creature as Character, "%s spots something: %s (passive Perception %d)." % [m.name().get_slice(" ", 0), str(trap.get("label", "a trap")), passive])
					return true
		if str(states.get(id, "")) == "":
			for m in members:
				if m.cell in cells:
					_spring_trap(trap, m)
					return true
	return false


func _spring_trap(trap: Dictionary, victim: Combatant) -> void:
	var id := str(trap["id"])
	(st.loc_state(loc_id)["traps"] as Dictionary)[id] = "triggered"
	var lines: Array[String] = []
	var save := trap.get("save", {}) as Dictionary
	var success := false
	if not save.is_empty():
		var t := victim.creature.roll_save(dice, StringName(str(save["ability"])), int(save["dc"]))
		success = t.success
		lines.append(t.describe())
	if str(trap.get("damage", "")) != "":
		var rolled := dice.roll_expr(str(trap["damage"]), "Trap: %s" % trap.get("label", id))
		var amount := int(rolled["total"])
		if success:
			amount /= 2
		var dr := victim.creature.take_damage(amount, StringName(str(trap.get("damage_type", "bludgeoning"))), false, dice, str(trap.get("label", "a trap")))
		lines.append(dr.describe(victim.name()))
		(tokens[victim.id] as CombatToken).flash(Look.color("vampire_red"))
	if str(trap.get("condition", "")) != "" and not success:
		victim.creature.add_condition(StringName(str(trap["condition"])), str(trap.get("label", "a trap")))
	(tokens[victim.id] as CombatToken).refresh()
	if trap.has("flag"):
		st.set_flag(str(trap["flag"]))
	check_rolled.emit(" · ".join(lines))
	_say("trap:%s:triggered" % id, victim.creature as Character, str(trap.get("text", "A trap springs!")))


# --- Interactions ---------------------------------------------------------------------------------

## The right-click menu for a square (plan §5.6): {title, actions: [{id, label, enabled, why}]}. Party members get
## Lead / Character / Inventory (the game root opens those screens); things get their verbs (Talk, Open, Pick the
## lock, Force it, Use the key, Disarm, Read, Pull, Go ...) plus Look; bare floor gets Walk here and Search here.
func actions_at(cell: Vector2i) -> Dictionary:
	var out: Array[Dictionary] = []
	for i in members.size():
		if members[i].cell == cell:
			var ch := members[i].creature as Character
			out.append({"id": "lead:%d" % i, "label": "Lead the party", "enabled": i != 0 and ch.hp > 0,
				"why": "Already leading" if i == 0 else ("Can't lead while down" if ch.hp <= 0 else "")})
			out.append({"id": "sheet:%d" % i, "label": "Character sheet"})
			out.append({"id": "inventory:%d" % i, "label": "Inventory"})
			out.append({"id": "spells:%d" % i, "label": "Cast a spell...", "enabled": not ch.known_spells().is_empty(),
				"why": "" if not ch.known_spells().is_empty() else "No spells"})
			return {"title": ch.name, "actions": out}
	var thing := thing_at(cell)
	if thing.is_empty():
		if grid.in_bounds(cell) and not grid.is_solid(cell):
			out.append({"id": "walk", "label": "Walk here"})
			out.append({"id": "search_here", "label": "Search here (Perception)"})
		return {"title": "", "actions": out}
	var spec := thing["spec"] as Dictionary
	var title := str(thing["label"]).get_slice(" ", 0)
	match str(thing["kind"]):
		"npc":
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			title = str(npc.get("name", spec["npc"]))
			out.append({"id": "talk", "label": "Talk", "enabled": str(spec.get("dialogue", "")) != "",
				"why": "" if str(spec.get("dialogue", "")) != "" else "Nothing to say"})
			if npc.has("shop"):
				var closed := str((npc["shop"] as Dictionary).get("closed", ""))
				var open := closed == "" or not StoryConditions.check(closed, st)
				out.append({"id": "trade", "label": "Trade", "enabled": open, "why": "" if open else "Closed for now"})
		"door", "container":
			title = str(spec.get("label", "the door" if str(thing["kind"]) == "door" else "the chest")).capitalize()
			var verb := "Open" if str(thing["kind"]) == "door" else "Open and look inside"
			if str(thing["kind"]) == "door" and not StoryConditions.check(str(spec.get("when", "")), st):
				out.append({"id": "open", "label": verb, "enabled": false, "why": "It won't budge"})
			elif _locked(spec):
				var key := str(spec.get("key", ""))
				if key != "":
					var has := st.party_has_item(key)
					out.append({"id": "key", "label": "Unlock with the %s" % Compendium.shared().display_name("items", key),
						"enabled": has, "why": "" if has else "Nobody carries the key"})
				var dc := int(spec.get("lock_dc", 15))
				var picker := _lock_picker()
				if dc > 0:
					if picker != null:
						var adv: Array[String] = []
						var b := _pick_bonus(picker, adv)
						out.append({"id": "pick", "label": "Pick the lock (%s, %s%s)" % [picker.name.get_slice(" ", 0), b.signed(),
							", Advantage" if not adv.is_empty() else ""]})
					else:
						out.append({"id": "pick", "label": "Pick the lock", "enabled": false, "why": "Nobody has thieves' tools"})
					var strong := _best(&"athletics")
					out.append({"id": "force", "label": "Force it (%s, Athletics %s, harder than picking)" % [strong.name.get_slice(" ", 0),
						strong.skill_bonus(&"athletics").signed()]})
				elif key == "":
					out.append({"id": "open", "label": verb, "enabled": false, "why": "Locked; it needs its key"})
			else:
				out.append({"id": "open", "label": verb})
		"prop":
			title = str(spec.get("label", "it")).capitalize()
			out.append({"id": "use", "label": str(thing["label"]).get_slice(" ", 0)})
		"trap":
			title = str(spec.get("label", "a trap")).capitalize()
			var who := _lock_picker()
			if who != null:
				var adv2: Array[String] = []
				out.append({"id": "disarm", "label": "Disarm (%s, %s)" % [who.name.get_slice(" ", 0), _pick_bonus(who, adv2).signed()]})
			else:
				out.append({"id": "disarm", "label": "Disarm", "enabled": false, "why": "Nobody has thieves' tools"})
			out.append({"id": "avoid", "label": "Walk around it (the party already does)", "enabled": false})
		"exit":
			title = str(spec.get("label", "The way on"))
			var open := StoryConditions.check(str(spec.get("when", "")), st)
			out.append({"id": "go", "label": "Go: %s" % Compendium.shared().get_entry("locations", str(spec["to"])).get("name", spec["to"]),
				"enabled": open, "why": "" if open else str(spec.get("locked_text", "The way is barred."))})
	out.append({"id": "look", "label": "Look"})
	return {"title": title, "actions": out}


## Does a right-click menu choice for `cell` (party-member ids are the game root's). Walks next to things first.
func act(cell: Vector2i, action_id: String) -> void:
	if busy or in_combat or members.is_empty():
		return
	var thing := thing_at(cell)
	match action_id:
		"walk":
			walk_to(cell)
			return
		"search_here":
			walk_to(cell, search)
			return
		"look":
			_look(cell, thing)
			return
		"go":
			walk_to(cell)
			return
	if thing.is_empty():
		return
	var spec := thing["spec"] as Dictionary
	var then := Callable()
	match action_id:
		"talk", "use", "open":
			then = func() -> void: interact(thing)
		"key", "pick", "force":
			if str(thing["kind"]) == "door":
				then = func() -> void: _use_door(spec, action_id)
			else:
				then = func() -> void: _use_container(spec, action_id)
		"disarm":
			then = func() -> void: _disarm(spec)
	if not then.is_valid():
		return
	var stand := _adjacent_free(cell)
	if stand == Vector2i(-1, -1):
		toast.emit("Can't reach it")
	elif stand == leader().cell:
		then.call()
	else:
		walk_to(stand, then)


## "Look": what the party can tell at a glance, without walking over.
func _look(cell: Vector2i, thing: Dictionary) -> void:
	if thing.is_empty():
		narration.emit("Nothing there but %s." % ("floor" if not grid.is_solid(cell) else "wall"))
		return
	var spec := thing["spec"] as Dictionary
	match str(thing["kind"]):
		"npc":
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			var att := st.attitude(str(spec["npc"]))
			narration.emit("%s%s. %s%s" % [npc.get("name", spec["npc"]), (", " + str(npc["title"])) if str(npc.get("title", "")) != "" else "",
				str(npc.get("summary", "")), (" (%s)" % att) if att != "" else ""])
		"door", "container":
			var state := "locked" if _locked(spec) else "unlocked"
			if str(thing["kind"]) == "container" and bool((st.loc_state(loc_id)["looted"] as Dictionary).get(str(spec["id"]), false)):
				state = "empty"
			narration.emit("%s: %s." % [str(spec.get("label", "It")).capitalize(), state])
		"trap":
			var save := spec.get("save", {}) as Dictionary
			narration.emit("%s. Springing it means a %s saving throw%s." % [str(spec.get("label", "A trap")).capitalize(),
				Creature.ABILITY_NAMES.get(StringName(str(save.get("ability", "dex"))), "Dexterity"),
				(" and %s damage" % spec["damage"]) if spec.has("damage") else ""])
		"exit":
			narration.emit("%s, to %s." % [spec.get("label", "A way on"), Compendium.shared().get_entry("locations", str(spec["to"])).get("name", spec["to"])])
		_:
			if not _say("look:" + str(spec.get("id", "")), leader().creature as Character):
				narration.emit(str(spec.get("label", "Something")).capitalize() + ".")


## What's at a square for the hover hint and clicks: {kind, id, label} or {}.
func thing_at(cell: Vector2i) -> Dictionary:
	for shown in _npc_shown:
		var spec := shown["spec"] as Dictionary
		if shown["cell"] == cell:
			var npc := Compendium.shared().get_entry("npcs", str(spec["npc"]))
			return {"kind": "npc", "id": str(spec["npc"]), "label": "Talk to %s" % npc.get("name", spec["npc"]), "spec": spec}
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		if _cell(door["cell"]) == cell and (door_nodes[str(door["id"])] as Node3D).visible:
			var secret := int(door.get("secret_dc", 0)) > 0 and not bool((st.loc_state(loc_id)["found"] as Dictionary).get(str(door["id"]), false))
			if secret:
				return {}
			return {"kind": "door", "id": str(door["id"]), "label": "Open %s%s" % [door.get("label", "the door"), " (locked)" if _locked(door) else ""], "spec": door}
	for c: Variant in loc.get("containers", []):
		var ct := c as Dictionary
		if _cell(ct["cell"]) == cell and container_nodes.has(str(ct["id"])):
			return {"kind": "container", "id": str(ct["id"]), "label": "Open %s%s" % [ct.get("label", "the chest"), " (locked)" if _locked(ct) else ""], "spec": ct}
	for p: Variant in loc.get("props", []):
		var prop := p as Dictionary
		if _cell(prop["cell"]) == cell and prop_nodes.has(str(prop["id"])):
			var verb := {"examine": "Examine", "book": "Read", "search": "Search", "lever": "Pull", "decor": "Look at"}.get(str(prop["kind"]), "Examine") as String
			return {"kind": "prop", "id": str(prop["id"]), "label": "%s %s" % [verb, prop.get("label", "it")], "spec": prop}
	for t: Variant in loc.get("traps", []):
		var trap := t as Dictionary
		if str((st.loc_state(loc_id)["traps"] as Dictionary).get(str(trap["id"]), "")) == "found":
			for tc: Variant in trap["cells"]:
				if _cell(tc) == cell:
					return {"kind": "trap", "id": str(trap["id"]), "label": "Disarm %s" % trap.get("label", "the trap"), "spec": trap}
	for ex: Variant in loc.get("exits", []):
		var exit := ex as Dictionary
		if _cell(exit["cell"]) == cell:
			return {"kind": "exit", "id": str(exit["id"]), "label": str(exit.get("label", "Leave")), "spec": exit}
	return {}


## Clicking a square: walk there, or walk next to the thing there and use it.
func click(cell: Vector2i) -> void:
	if busy or in_combat or members.is_empty():
		return
	var thing := thing_at(cell)
	if thing.is_empty() or str(thing["kind"]) == "exit":
		walk_to(cell)
		return
	var stand := _adjacent_free(cell)
	if stand == Vector2i(-1, -1):
		toast.emit("Can't reach it")
		return
	if stand == leader().cell:
		interact(thing)
	else:
		walk_to(stand, func() -> void: interact(thing))


func _adjacent_free(cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_len := 1 << 30
	for d in CombatGrid.DIRS:
		var c := cell + d
		if not grid.in_bounds(c) or grid.is_solid(c):
			continue
		if c == leader().cell:
			return c
		var p := _path(leader().cell, c)
		if not p.is_empty() and p.size() < best_len:
			best_len = p.size()
			best = c
	return best


func interact(thing: Dictionary) -> void:
	var spec := thing["spec"] as Dictionary
	var who := leader()
	(tokens[who.id] as CombatToken).face(Vector2(_cell(spec.get("cell", [who.cell.x, who.cell.y])) - who.cell), false)
	match str(thing["kind"]):
		"npc":
			dialogue_requested.emit(str(spec.get("dialogue", "")), str(spec["npc"]))
		"door":
			_use_door(spec)
		"container":
			_use_container(spec)
		"prop":
			_use_prop(spec)
		"trap":
			_disarm(spec)


func _locked(spec: Dictionary) -> bool:
	if not bool(spec.get("locked", false)) and int(spec.get("lock_dc", 0)) <= 0:
		return false
	var state := str((st.loc_state(loc_id)["doors"] as Dictionary).get(str(spec["id"]), ""))
	return state != "unlocked" and state != DOOR_OPEN


func _use_door(door: Dictionary, method: String = "auto") -> void:
	var id := str(door["id"])
	if not StoryConditions.check(str(door.get("when", "")), st):
		narration.emit("It won't budge.")
		return
	if _locked(door):
		if not _unlock(door, method):
			return
	(st.loc_state(loc_id)["doors"] as Dictionary)[id] = DOOR_OPEN
	grid.set_flag(_cell(door["cell"]), CombatGrid.WALL, false)
	(door_nodes[id] as Node3D).visible = false
	if door.has("flag"):
		st.set_flag(str(door["flag"]))
	_say("open:" + id)
	_trigger_encounter("open:" + id)


## Tries a key, thieves' tools (2024: Dexterity check, + Proficiency Bonus with the tools, Advantage with Sleight of
## Hand too) or force (Strength (Athletics)), with the best party member for the job. Returns true if it opens.
## `method`: "auto" (a key, else thieves' tools, else force), "key", "pick" or "force" (the right-click menu).
func _unlock(spec: Dictionary, method: String = "auto") -> bool:
	var id := str(spec["id"])
	var key := str(spec.get("key", ""))
	if key != "" and st.party_has_item(key) and method in ["auto", "key"]:
		(st.loc_state(loc_id)["doors"] as Dictionary)[id] = "unlocked"
		toast.emit("Unlocked with the %s" % Compendium.shared().display_name("items", key))
		return true
	if method == "key":
		narration.emit("None of you has the key.")
		return false
	var dc := int(spec.get("lock_dc", 15))
	if dc <= 0:
		narration.emit("Locked, and no lock to pick: you'll need the key.")
		return false
	var picker := _lock_picker() if method in ["auto", "pick"] else null
	if method == "pick" and picker == null:
		narration.emit("Nobody has thieves' tools.")
		return false
	var t: D20Test
	var who: Character
	if picker != null:
		who = picker
		var adv: Array[String] = []
		var bonus := _pick_bonus(picker, adv)
		t = picker.roll_d20(dice, D20Test.Kind.ABILITY_CHECK, bonus, dc, picker.check_keys(&"dex"), adv, [], "%s picks the lock" % picker.name)
	else:
		who = _best(&"athletics")
		t = who.roll_check(dice, &"athletics", dc + 2, [], [], "%s forces it" % who.name)
	check_rolled.emit(t.describe())
	st.last_check = t.success
	if t.success:
		(st.loc_state(loc_id)["doors"] as Dictionary)[id] = "unlocked"
		_say("check:unlock:success", who)
		return true
	_say("check:unlock:failure", who, "It holds.")
	st.advance_minutes(1)
	return false


## The living party member best at picking locks (thieves' tools in hand, highest Dexterity), or null.
func _lock_picker() -> Character:
	var picker: Character = null
	for ch in st.party:
		if ch.hp > 0 and st.member_matches(ch, "item:thieves_tools") and (picker == null or ch.ability_mod(&"dex") > picker.ability_mod(&"dex")):
			picker = ch
	return picker


## 2024 Thieves' Tools: Dexterity check + Proficiency Bonus with the tools, Advantage with Sleight of Hand too.
static func _pick_bonus(picker: Character, adv: Array[String]) -> Breakdown:
	var bonus := picker.ability_check_bonus(&"dex")
	if picker.has_proficiency("tools", "thieves_tools"):
		bonus.add("Thieves' Tools proficiency", picker.proficiency_bonus())
		if picker.skill_rank(&"sleight_of_hand") > 0:
			adv.append("Sleight of Hand proficiency")
	return bonus


func _best(skill: StringName) -> Character:
	var best: Character = null
	for ch in st.party:
		if ch.hp > 0 and (best == null or ch.skill_bonus(skill).total() > best.skill_bonus(skill).total()):
			best = ch
	return best


func _use_container(ct: Dictionary, method: String = "auto") -> void:
	var id := str(ct["id"])
	if _locked(ct) and not _unlock(ct, method):
		return
	_say("open:" + id)
	if _trigger_encounter("open:" + id):
		return
	var looted := st.loc_state(loc_id)["looted"] as Dictionary
	if bool(looted.get(id, false)):
		toast.emit("Empty")
		return
	if ct.has("flag"):
		st.set_flag(str(ct["flag"]))
	var left := (st.loc_state(loc_id).get("contents", {}) as Dictionary).get(id, {}) as Dictionary
	if not left.is_empty():
		loot_opened.emit(id, (left["items"] as Array).duplicate(true), float(left["gold"]))
	else:
		loot_opened.emit(id, (ct.get("items", []) as Array).duplicate(true), float(ct.get("gold", 0)))


## Called by the loot window when everything's been taken.
func mark_looted(container_id: String) -> void:
	(st.loc_state(loc_id)["looted"] as Dictionary)[container_id] = true
	if container_nodes.has(container_id):
		(container_nodes[container_id] as MeshInstance3D).material_override = Look.cel("peat")


func _use_prop(prop: Dictionary) -> void:
	var id := str(prop["id"])
	var kind := str(prop["kind"])
	var used := st.loc_state(loc_id)["props"] as Dictionary
	match kind:
		"book":
			var codex := str(prop.get("codex", id))
			if not codex in st.codex:
				st.codex.append(codex)
				toast.emit("Added to the codex: %s" % prop.get("label", id))
		"lever":
			if prop.has("flag"):
				st.set_flag(str(prop["flag"]), not bool(st.get_flag(str(prop["flag"]))))
		_:
			pass
	if prop.has("flag") and kind != "lever":
		st.set_flag(str(prop["flag"]))
	if prop.has("item") and not bool(used.get(id, false)):
		st.give_item(str(prop["item"]), 1, leader().creature as Character)
		toast.emit("%s takes %s" % [leader().name(), Compendium.shared().display_name("items", str(prop["item"]))])
	used[id] = true
	if str(prop.get("dialogue", "")) != "":
		dialogue_requested.emit(str(prop["dialogue"]), "")
		return
	var said := _say("%s:%s" % ["search" if kind == "search" else "examine", id], leader().creature as Character)
	if not said and str(prop.get("text", "")) != "":
		narration.emit(str(prop["text"]))
	_trigger_encounter("examine:" + id)


## Searching (out of combat): a Wisdom (Perception) check by the leader finds traps and hidden things within 15 ft
## (search props, secret doors) whose DC it meets. Takes a minute.
func search() -> void:
	if busy or in_combat:
		return
	var who := leader().creature as Character
	var t := who.roll_check(dice, &"perception", 0, [], [], "%s searches" % who.name)
	check_rolled.emit(t.describe())
	st.advance_minutes(1)
	var found: Array[String] = []
	var found_ids: Array[String] = []
	var c := leader().cell
	var states := st.loc_state(loc_id)
	for tr: Variant in loc.get("traps", []):
		var trap := tr as Dictionary
		if str((states["traps"] as Dictionary).get(str(trap["id"]), "")) != "":
			continue
		for tc: Variant in trap["cells"]:
			if grid.distance_ft(c, 1, _cell(tc), 1) <= 15 and t.total >= int(trap["detect_dc"]):
				(states["traps"] as Dictionary)[str(trap["id"])] = "found"
				_show_trap(trap)
				found.append(str(trap.get("label", "a trap")))
				break
	for p: Variant in loc.get("props", []):
		var prop := p as Dictionary
		if str(prop["kind"]) != "search" or bool((states["found"] as Dictionary).get(str(prop["id"]), false)):
			continue
		if grid.distance_ft(c, 1, _cell(prop["cell"]), 1) <= 15 and t.total >= int(prop.get("search_dc", 10)):
			(states["found"] as Dictionary)[str(prop["id"])] = true
			prop_nodes[str(prop["id"])] = _box(Vector3(0.45, 0.35, 0.45), board.cell_center(_cell(prop["cell"])) + Vector3(0, 0.2, 0), "bone")
			found.append(str(prop.get("label", "something")))
			found_ids.append(str(prop["id"]))
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) <= 0 or bool((states["found"] as Dictionary).get(str(door["id"]), false)):
			continue
		if grid.distance_ft(c, 1, _cell(door["cell"]), 1) <= 15 and t.total >= int(door["secret_dc"]):
			(states["found"] as Dictionary)[str(door["id"])] = true
			(door_nodes[str(door["id"])] as MeshInstance3D).material_override = Look.cel("walnut")
			found.append(str(door.get("label", "a hidden door")))
	st.last_check = not found.is_empty()
	if found.is_empty():
		_say("check:perception:failure", who, "Nothing you can find.")
	else:
		# A found thing's own line (search:<prop> or check:perception:<prop>:success) before the generic one.
		var said := false
		for id in found_ids:
			if not said:
				said = _say("search:" + id, who) or _say("check:perception:%s:success" % id, who)
		if not said:
			_say("check:perception:success", who, "")
		toast.emit("Found: " + ", ".join(found))


func _disarm(trap: Dictionary) -> void:
	var who := _lock_picker()
	if who == null:
		narration.emit("Without thieves' tools you can only walk around it.")
		return
	var bonus := who.ability_check_bonus(&"dex")
	if who.has_proficiency("tools", "thieves_tools"):
		bonus.add("Thieves' Tools proficiency", who.proficiency_bonus())
	var t := who.roll_d20(dice, D20Test.Kind.ABILITY_CHECK, bonus, int(trap.get("disarm_dc", 15)), who.check_keys(&"dex"), [], [], "%s disarms %s" % [who.name, trap.get("label", "the trap")])
	check_rolled.emit(t.describe())
	if t.success:
		(st.loc_state(loc_id)["traps"] as Dictionary)[str(trap["id"])] = "disarmed"
		for n: Node3D in trap_marks.get(str(trap["id"]), []):
			n.queue_free()
		trap_marks.erase(str(trap["id"]))
		_say("trap:%s:disarmed" % trap["id"], who, "Disarmed.")
	elif t.total <= int(trap.get("disarm_dc", 15)) - 5:
		var m: Combatant = null
		for mm in members:
			if mm.creature == who:
				m = mm
		_spring_trap(trap, m if m != null else leader())
	else:
		_say("trap:%s:failed" % trap["id"], who, "Not yet. Careful.")


## Plays a Narrator trigger; falls back to `fallback` text. Returns true if anything was said.
func _say(key: String, actor: Character = null, fallback: String = "") -> bool:
	var text := narrator.line(key, st, actor if actor != null else (leader().creature as Character if leader() != null else null)) if narrator != null else ""
	if text == "":
		text = fallback
	if text != "":
		narration.emit(text)
		return true
	return false


# --- Fights ---------------------------------------------------------------------------------------

## Starts any encounter of this location whose trigger matches and whose condition holds. True if one started.
func _trigger_encounter(trigger: String) -> bool:
	for en: Variant in loc.get("encounters", []):
		var spec := en as Dictionary
		if str(spec["trigger"]) != trigger:
			continue
		if (st.loc_state(loc_id)["encounters"] as Dictionary).get(str(spec["id"]), false) is bool \
				and bool((st.loc_state(loc_id)["encounters"] as Dictionary).get(str(spec["id"]), false)):
			continue
		if not StoryConditions.check(str(spec.get("when", "")), st):
			continue
		start_encounter(str(spec["id"]))
		return true
	return false


## Fights triggered by a flag (set by dialogue or a lever): checked after conversations and interactions.
func check_flag_encounters() -> bool:
	for en: Variant in loc.get("encounters", []):
		var spec := en as Dictionary
		var trig := str(spec["trigger"])
		if trig.begins_with("flag:") and _truthy(st.get_flag(trig.substr(5))):
			if _trigger_encounter(trig):
				return true
	return false


static func _truthy(v: Variant) -> bool:
	return StoryConditions._truthy(v)


## The fight happens here, on the same grid: the party where it stands, the monsters where the data puts them.
## Surprise: a sneaking party whose every Stealth check beats a monster's passive Perception surprises it.
func start_encounter(encounter_id: String) -> bool:
	# Several entries may share an id with different `when` conditions (e.g. a lighter version for a lower-level
	# party): the first whose condition holds is the fight.
	var spec := {}
	for en: Variant in loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id and (spec.is_empty() or not StoryConditions.check(str(spec.get("when", "")), st)):
			spec = en as Dictionary
	if spec.is_empty() or in_combat:
		return false
	_queue.clear()
	_on_arrive = Callable()
	in_combat = true
	ModeController.force(ModeController.Mode.COMBAT)
	var e := Encounter.new(_combat_grid(), dice)
	e.title = str(spec.get("text", ""))
	var party_cbs: Array[Combatant] = []
	for m in members:
		if m.creature.dead:
			continue
		party_cbs.append(e.add(m.creature, &"party", m.cell))
	var counts := {}
	for mo: Variant in spec["monsters"]:
		var mid := str((mo as Dictionary)["monster"])
		counts[mid] = int(counts.get(mid, 0)) + 1
	var numbered := {}
	for mo: Variant in spec["monsters"]:
		var md := mo as Dictionary
		var data := Compendium.shared().monster_data(str(md["monster"]))
		var mon := Monster.from_data(data)
		if md.has("hp"):
			# A tuned stat block for this fight (docs/contracts/locations.md).
			mon.hp_max_base = int(md["hp"])
			mon.hp = mon.max_hp()
		if md.has("name"):
			mon.name = str(md["name"])
		elif int(counts[str(md["monster"])]) > 1:
			numbered[str(md["monster"])] = int(numbered.get(str(md["monster"]), 0)) + 1
			mon.name = "%s %d" % [mon.name, numbered[str(md["monster"])]]
		e.add(mon, StringName(str(md.get("side", "enemy"))), _cell(md["cell"]))
	var surprised: Array[String] = []
	var who := str(spec.get("surprise", ""))
	for c in e.combatants:
		if (who == "party" and c.side == &"party") or (who == "enemies" and c.side == &"enemy"):
			surprised.append(c.id)
	if sneaking and who == "":
		surprised.append_array(_stealth_surprise(e))
	(st.loc_state(loc_id)["encounters"] as Dictionary)[encounter_id] = "started"
	for m in members:
		(tokens[m.id] as Node3D).visible = false
	var ctokens := {}
	for c in e.combatants:
		var t := CombatToken.create(c)
		t.position = board.cell_center(c.cell, c.size_cells)
		add_child(t)
		ctokens[c.id] = t
	combat_view = CombatView.new()
	combat_view.input_locked = input_locked
	combat_view.narrator = narrator
	combat_view.story = st
	add_child(combat_view)
	_say("combat:start")
	_run_combat(encounter_id, spec, e, ctokens, surprised)
	return true


func _run_combat(encounter_id: String, spec: Dictionary, e: Encounter, ctokens: Dictionary, surprised: Array[String]) -> void:
	combat_view.finished.connect(func(outcome: String) -> void: _end_encounter(encounter_id, spec, e, ctokens, outcome))
	combat_view.round_started.connect(func(_r: int) -> void: _save_round(encounter_id, e))
	combat_started.emit(combat_view)
	combat_view.begin(e, board, rig, ctokens, surprised)


## Saves the fight as the round begins: the party (in the story), the location, and the encounter's state.
func _save_round(encounter_id: String, e: Encounter) -> void:
	if e.state != Encounter.State.ACTIVE:
		return
	_save_positions()
	GameState.combat_snapshot = {"location": loc_id, "encounter": encounter_id, "data": EncounterSnapshot.capture(e)}
	SaveSystem.save_round()


## Picks a saved fight up again at the start of its round (after loading a round-start save).
func resume_encounter(snapshot: Dictionary) -> bool:
	var encounter_id := str(snapshot.get("encounter", ""))
	var spec := {}
	for en: Variant in loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id:
			spec = en as Dictionary
	if spec.is_empty() or in_combat:
		return false
	in_combat = true
	ModeController.force(ModeController.Mode.COMBAT)
	var e := EncounterSnapshot.restore(snapshot["data"] as Dictionary, dice, st.party)
	for m in members:
		(tokens[m.id] as Node3D).visible = false
	var ctokens := {}
	for c in e.combatants:
		var t := CombatToken.create(c)
		t.position = board.cell_center(c.cell, c.size_cells)
		add_child(t)
		ctokens[c.id] = t
	combat_view = CombatView.new()
	combat_view.input_locked = input_locked
	combat_view.narrator = narrator
	combat_view.story = st
	add_child(combat_view)
	var none: Array[String] = []
	_run_combat(encounter_id, spec, e, ctokens, none)
	return true


func _stealth_surprise(e: Encounter) -> Array[String]:
	var lowest := 1000
	for m in members:
		if m.creature.hp > 0:
			var t := m.creature.roll_check(dice, &"stealth", 0)
			lowest = mini(lowest, t.total)
			check_rolled.emit(t.describe())
	var out: Array[String] = []
	for c in e.combatants:
		if c.side == &"enemy" and c.creature.passive_score(&"perception").total() < lowest:
			out.append(c.id)
	return out


## The location's grid as it stands now (closed doors are walls; NPC squares are blocked).
func _combat_grid() -> CombatGrid:
	var g := CombatGrid.from_rows(loc["map"]["rows"] as Array)
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		g.set_flag(_cell(door["cell"]), CombatGrid.WALL, _door_state(str(door["id"])) != DOOR_OPEN)
	for npc: String in npc_tokens:
		if (npc_tokens[npc] as CombatToken).visible:
			g.set_flag((npc_tokens[npc] as CombatToken).combatant.cell, CombatGrid.LOW, true)
	return g


func _end_encounter(encounter_id: String, spec: Dictionary, e: Encounter, ctokens: Dictionary, outcome: String) -> void:
	for c in e.combatants:
		if c.side == &"party":
			for m in members:
				if m.creature == c.creature:
					m.cell = c.cell
		elif c.creature.dead:
			var stain := _box(Vector3(0.6, 0.02, 0.4), board.cell_center(c.cell, c.size_cells) + Vector3(0, 0.015, 0), "blood_deep")
			stain.name = "Remains"
	for id: String in ctokens:
		(ctokens[id] as Node).queue_free()
	if combat_view != null:
		combat_view.queue_free()
		combat_view = null
	for m in members:
		var tok := tokens[m.id] as CombatToken
		tok.position = board.cell_center(m.cell)
		tok.visible = true
		tok.refresh()
	in_combat = false
	GameState.combat_snapshot = {}
	ModeController.force(ModeController.Mode.EXPLORATION)
	rig.follow = tokens[leader().id] as Node3D
	st.advance_minutes(1)
	# With the fight over, nobody is still held by a dead grappler, and the fallen-over get up.
	for m in members:
		if m.creature.hp > 0:
			m.creature.remove_condition(&"grappled")
			m.creature.remove_condition(&"prone")
	if outcome == "victory":
		(st.loc_state(loc_id)["encounters"] as Dictionary)[encounter_id] = true
		if spec.has("flag"):
			st.set_flag(str(spec["flag"]))
		if spec.has("quest"):
			var q := spec["quest"] as Dictionary
			st.set_quest_stage(str(q["id"]), str(q["stage"]))
			toast.emit("Journal updated: %s" % str(Compendium.shared().get_entry("quests", str(q["id"])).get("name", q["id"])))
		# Out of combat, the fallen are stabilized by their friends (a minute later) at 0 HP; nobody stays dying.
		for m in members:
			var cr := m.creature
			if cr.hp <= 0 and not cr.dead and not cr.stable:
				cr.stabilize()
		_say("combat:victory")
	_save_positions()
	combat_ended.emit(outcome)
