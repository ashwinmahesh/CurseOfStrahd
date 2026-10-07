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
## The party reached a road out of here (an exit to "travel"): the game opens the map.
signal travel_requested
## A party member down outside a fight was stabilized or healed from the right-click menu.
signal party_tended

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
## Counts down to the party standing still: the walk cycle plays until the last step's glide has finished.
var _walk_stop_t := -1.0
var _areas_in: Dictionary = {}


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


var _spawn_name := ""


func _ready() -> void:
	assert(not loc.is_empty(), "No location %s" % loc_id)
	grid = CombatGrid.from_rows(loc["map"]["rows"] as Array)
	board = ArenaBoard.build(grid, ArenaBoard.theme_for(loc["map"] as Dictionary), loc_id)
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
	_check_areas()


# --- Building -------------------------------------------------------------------------------------

func _build_environment() -> void:
	# Light, sky, fog, mist, weather and the land around the map: the place's mood (Atmosphere, docs/art/atmosphere.md).
	atmosphere = Atmosphere.create(loc_id, loc, board)
	add_child(atmosphere)
	_env = atmosphere.env
	_sun = atmosphere.sun
	# The party's lantern (or a Light cantrip): it goes where the leader goes, lit when it's dark.
	lantern = OmniLight3D.new()
	lantern.light_color = Look.color("candle")
	lantern.omni_range = 7.0
	lantern.light_energy = 2.4
	lantern.position = Vector3(0, 1.6, 0)
	update_daylight()


## The time of day outdoors (plan §5.2 day and night): an overcast Barovian day, a red dusk and dawn, and a blue
## night when the lantern comes out. Indoors only the map's light level counts.
func update_daylight() -> void:
	if atmosphere == null:
		return
	var light := str(loc["map"].get("light", "dim"))
	var outdoors := bool(loc["map"].get("outdoors", false))
	var phase := time_phase()
	if not outdoors:
		atmosphere.set_phase("any")
		lantern.visible = light != "bright" or st.spell_active("light")
		return
	atmosphere.set_phase(phase)
	lantern.visible = phase == "night" or light == "dark" or st.spell_active("light")


## "day" (7:00-17:59), "dusk" (18:00-18:59), "night" (19:00-5:59) or "dawn" (6:00-6:59).
func time_phase() -> String:
	var h := st.minute_of_day / 60
	if h >= 7 and h < 18:
		return "day"
	if h == 18:
		return "dusk"
	if h == 6:
		return "dawn"
	return "night"


func _door_state(id: String) -> String:
	return str((st.loc_state(loc_id)["doors"] as Dictionary).get(id, ""))


func _build_doors() -> void:
	for ex: Variant in loc.get("exits", []):
		var piece := SetDressing.exit_piece(board, ex as Dictionary)
		if piece != null:
			exit_nodes[str((ex as Dictionary)["id"])] = piece
	refresh_exits()
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		var cell := _cell(door["cell"])
		var id := str(door["id"])
		var secret := int(door.get("secret_dc", 0)) > 0 and not bool((st.loc_state(loc_id)["found"] as Dictionary).get(id, false))
		var open := _door_state(id) == DOOR_OPEN
		grid.set_flag(cell, CombatGrid.WALL, not open)
		var node: Node3D = SetDressing.door(board, door, secret)
		if node == null:
			node = _box(Vector3(0.9, 1.7, 0.9), board.cell_center(cell) + Vector3(0, 0.85, 0), "walnut" if not secret else "slate")
		node.visible = not open
		door_nodes[id] = node


## Stairs (and other pieces that are the way itself) show only while their exit's `when` holds, so a secret stair
## isn't drawn before anyone finds it. Checked a few times a second, since many things can open a way.
func refresh_exits() -> void:
	for ex: Variant in loc.get("exits", []):
		var e := ex as Dictionary
		var node := exit_nodes.get(str(e["id"]), null) as Node3D
		if node != null and is_instance_valid(node) and bool(node.get_meta("only_when_open", false)):
			node.visible = StoryConditions.check(str(e.get("when", "")), st)


func _build_props() -> void:
	for p: Variant in loc.get("props", []):
		var prop := p as Dictionary
		if not StoryConditions.check(str(prop.get("when", "")), st):
			continue
		var id := str(prop["id"])
		var kind := str(prop["kind"])
		if kind == "search" and not bool((st.loc_state(loc_id)["found"] as Dictionary).get(id, false)):
			continue
		if str(prop.get("burning", "")) != "" and StoryConditions.check(str(prop["burning"]), st):
			prop_nodes[id + "#fire"] = _flame(_cell(prop["cell"]), 1.6)
		prop_nodes[id] = _prop_node(prop)
	for c: Variant in loc.get("containers", []):
		var ct := c as Dictionary
		if not StoryConditions.check(str(ct.get("when", "")), st):
			continue
		var looted := bool((st.loc_state(loc_id)["looted"] as Dictionary).get(str(ct["id"]), false))
		var node: Node3D = SetDressing.place(board, ct, true)
		if node == null:
			node = _box(Vector3(0.8, 0.55, 0.55), board.cell_center(_cell(ct["cell"])) + Vector3(0, 0.28, 0), "umber")
		if looted:
			SetDressing.mark_looted(node)
		container_nodes[str(ct["id"])] = node


## A prop's piece (SetDressing, art/sprites/props/catalog.json), else a billboard by name, else a plain marker.
func _prop_node(prop: Dictionary) -> Node3D:
	var node: Node3D = SetDressing.place(board, prop)
	if node != null:
		return node
	var sprite := _prop_art(prop)
	if sprite != "":
		node = board.prop_sprite(sprite, board.cell_center(_cell(prop["cell"])), 0.8)
	if node == null:
		var colour := {"examine": "parchment", "book": "ember", "search": "bone", "lever": "pewter", "decor": "stone"}.get(str(prop["kind"]), "bone") as String
		node = _box(Vector3(0.45, 0.35, 0.45), board.cell_center(_cell(prop["cell"])) + Vector3(0, 0.2, 0), colour)
	return node


## Which billboard prop art (art/sprites/props) a prop looks like, from its model or id, or "" for a plain marker.
static func _prop_art(prop: Dictionary) -> String:
	var key := ("%s %s" % [prop.get("model", ""), prop.get("id", "")]).to_lower()
	for pair: Array in [["well", "well"], ["grave", "gravestone"], ["crypt", "gravestone"], ["lantern", "lantern_post"],
			["lamp", "lantern_post"], ["shelf", "bookshelf"], ["bookcase", "bookshelf"], ["bed", "bed"], ["table", "table"],
			["barrel", "barrel"], ["crate", "crate"], ["stall", "market_stall"], ["cart", "wagon"], ["wagon", "wagon"],
			["tree", "dead_tree"]]:
		if key.contains(str(pair[0])):
			return str(pair[1])
	return ""


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
		if str(li.get("kind", "")) == "torch" and ModelPiece.for_art(board, "torch") != "":
			ModelPiece.stand(board, board, ModelPiece.for_art(board, "torch"), "torch", _cell(li["cell"]))   # 3D (docs/art/models.md)
			omni.position.y = 1.9
		elif str(li.get("kind", "")) == "torch" and SetDressing.has_art("torch"):
			board.prop_sprite("torch", board.cell_center(_cell(li["cell"])))
			omni.position.y = 1.9
		elif str(li.get("kind", "")) in ["fire", "bonfire", "brazier", "torch"]:
			_flame(_cell(li["cell"]), 0.6 if str(li["kind"]) != "torch" else 0.35)


## A flame with a flicker of its own (watch fires, braziers, the burning wicker sun): the flame billboard where the
## art exists (SetDressing.flame), else a small emissive cone.
func _flame(cell: Vector2i, size: float) -> Node3D:
	var root := Node3D.new()
	root.position = board.cell_center(cell)
	add_child(root)
	var art := SetDressing.flame(size)
	if art != null:
		root.add_child(art)
	for i in (0 if art != null else 3):
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = size * (0.45 - i * 0.12)
		cm.height = size * (1.2 - i * 0.25)
		mi.mesh = cm
		mi.position = Vector3(0, cm.height / 2.0, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Look.color(["ember", "flame", "wick"][i])
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mi.material_override = mat
		root.add_child(mi)
	var light := CandleFlicker.new()
	light.light_color = Look.color("flame")
	light.omni_range = 4.0 + size * 4.0
	light.base_energy = 1.8 + size
	light.position = Vector3(0, size, 0)
	root.add_child(light)
	return root


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
	# Rebuilt pieces in rooms nobody has found yet stay hidden (HiddenAreas only looks again when a secret door is found).
	var hidden_areas := HiddenAreas.of(self)
	if hidden_areas != null:
		hidden_areas.call("_hide_nodes")


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
	place_guests()
	if lantern != null and not members.is_empty():
		(tokens[members[0].id] as Node3D).add_child(lantern)


## Swaps in party members whose character changed (Madam Eva's respec, a swap on the roster screen) where the old ones
## stood; someone sent to camp leaves, and someone brought along steps in beside the party.
func rebuild_party() -> void:
	_fit_party_size()
	for i in mini(members.size(), st.party.size()):
		if members[i].creature == st.party[i]:
			continue
		var old := members[i]
		var tok := tokens[old.id] as CombatToken
		if lantern != null and lantern.get_parent() == tok:
			tok.remove_child(lantern)
		tok.queue_free()
		tokens.erase(old.id)
		var cb := Combatant.new(st.party[i], &"party", old.cell)
		members[i] = cb
		var fresh := CombatToken.create(cb)
		fresh.position = board.cell_center(cb.cell)
		add_child(fresh)
		tokens[cb.id] = fresh
		if i == 0:
			rig.follow = fresh
			if lantern != null and lantern.get_parent() == null:
				fresh.add_child(lantern)


## Matches the figures to the party's size (the roster screen): figures for members who left go, and members who
## joined stand on free squares near the leader. rebuild_party then swaps any changed faces in place.
func _fit_party_size() -> void:
	var left: Array[Combatant] = []
	for cb in members:
		if not cb.creature in st.party:
			left.append(cb)
	for cb in left:
		if members.size() <= st.party.size():
			break
		members.erase(cb)
		if tokens.has(cb.id):
			var tok := tokens[cb.id] as CombatToken
			if lantern != null and lantern.get_parent() == tok:
				tok.remove_child(lantern)
			tok.queue_free()
			tokens.erase(cb.id)
	if members.size() < st.party.size() and not members.is_empty():
		var taken: Array[Vector2i] = []
		for cb in members:
			taken.append(cb.cell)
		var cells := _cells_around(members[0].cell, st.party.size() + members.size())
		for i in range(members.size(), st.party.size()):
			var cell := members[0].cell
			for c in cells:
				if not c in taken:
					cell = c
					break
			taken.append(cell)
			var cb := Combatant.new(st.party[i], &"party", cell)
			members.append(cb)
			var tok := CombatToken.create(cb)
			tok.position = board.cell_center(cell)
			add_child(tok)
			tokens[cb.id] = tok
	# Members keep the party's order (a swap puts the newcomer in the leaver's place).
	var ordered: Array[Combatant] = []
	for ch in st.party:
		for cb in members:
			if cb.creature == ch:
				ordered.append(cb)
	if ordered.size() == members.size():
		members = ordered
	if lantern != null and not members.is_empty() and lantern.get_parent() == null:
		(tokens[members[0].id] as Node3D).add_child(lantern)
	if not members.is_empty():
		rig.follow = tokens[members[0].id] as Node3D
	_save_positions()
	place_guests()


## Puts the party's guests behind the last member (called again when someone joins or leaves).
func place_guests() -> void:
	for g in guest_members:
		if tokens.has(g.id):
			(tokens[g.id] as Node).queue_free()
			tokens.erase(g.id)
	guest_members.clear()
	if st.guests.is_empty() or members.is_empty():
		return
	var tail := members[members.size() - 1].cell
	var taken := {}
	for m in members:
		taken[m.cell] = true
	var spots := _cells_around(tail, members.size() + st.guests.size() + 4)
	var k := 0
	for i in st.guests.size():
		while k < spots.size() and taken.has(spots[k]):
			k += 1
		var cell := spots[k] if k < spots.size() else tail
		taken[cell] = true
		var cb := Combatant.new(st.guests[i], &"guest", cell)
		guest_members.append(cb)
		var npc := Compendium.shared().get_entry("npcs", st.guest_ids[i])
		var tok := CombatToken.create(cb, str(npc.get("sprite", st.guest_ids[i])))
		tok.position = board.cell_center(cell)
		add_child(tok)
		tokens[cb.id] = tok


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
	trap_marks[str(trap["id"])] = TrapSight.dress(self, trap)   # its own piece and a red border that doesn't cover it


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
	if PitFall.holds(self, leader()) and not PitFall.climb_out(self, leader().cell):
		return false   # the leader is at the bottom of a pit: the climb comes first
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


func _path(from: Vector2i, to: Vector2i, around_traps: bool = true) -> Array[Vector2i]:
	var avoid := {}
	if around_traps:
		for t: Variant in loc.get("traps", []):
			var trap := t as Dictionary
			var tstate := str((st.loc_state(loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
			if tstate == "found" or PitFall.open_hole(trap, tstate):
				for c: Variant in trap["cells"]:
					avoid[_cell(c)] = true
	avoid.erase(to)
	# Closed doors that would open at a touch are part of the way: the party opens them as it reaches them.
	var doors := _openable_doors()
	# An exit set into a wall or a tent (a house's front door, Madam Eva's tent flap) is walked into like a door.
	var low_exit := grid.has_flag(to, CombatGrid.LOW) and _exit_at(to)
	if grid.has_flag(to, CombatGrid.WALL) and _exit_at(to):
		doors[to] = {}
	for c: Vector2i in doors:
		grid.set_flag(c, CombatGrid.WALL, false)
	if low_exit:
		grid.set_flag(to, CombatGrid.LOW, false)
	var reach := grid.reachable(from, 1, 2000, func(c: Vector2i) -> bool: return avoid.has(c),
		func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
	for c: Vector2i in doors:
		grid.set_flag(c, CombatGrid.WALL, true)
	if low_exit:
		grid.set_flag(to, CombatGrid.LOW, true)
	var way := CombatGrid.path_to(reach, to)
	# A found trap that fills the only way (a corridor) is crossed rather than leaving the party stuck; stepping
	# on it springs it as usual unless it's disarmed first.
	if way.is_empty() and around_traps and not avoid.is_empty():
		return _path(from, to, false)
	return way


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


var _exit_check := 0.0


func _process(delta: float) -> void:
	_exit_check -= delta
	if _exit_check <= 0.0:
		_exit_check = 0.25
		refresh_exits()
	if board != null and rig != null and rig.camera != null and not members.is_empty() and (not board.occluders.is_empty() or not board.mesh_occluders.is_empty() or not board.buildings.is_empty()):
		var focus := (tokens[leader().id] as Node3D).global_position if tokens.has(leader().id) else Vector3.ZERO
		board.fade_occluders(rig.camera.global_position, focus, delta)
		board.cut_buildings(rig.camera.global_position, focus, delta)
	if _walk_stop_t >= 0.0 and not in_combat:
		_walk_stop_t -= delta
		if _walk_stop_t < 0.0 and _queue.is_empty():
			_stand_still()
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
	# Walking until this step's glide ends (a step right after it keeps the cycle going; a walk cut short stops too).
	_walk_stop_t = _step_t
	if _check_cell_events():
		_queue.clear()
		_on_arrive = Callable()
		return
	if _queue.is_empty():
		_save_positions()
		if _on_arrive.is_valid():
			var cb := _on_arrive
			_on_arrive = Callable()
			cb.call()


## The party (and guests) stop walking in place once they've arrived.
func _stand_still() -> void:
	for m: Combatant in members + guest_members:
		if tokens.has(m.id):
			(tokens[m.id] as CombatToken).face(Vector2.ZERO, false)


## The leader steps to `next`; each follower steps into the square the one ahead of it just left.
func _advance_party(next: Vector2i) -> void:
	var old: Array[Vector2i] = []
	for m in members:
		old.append(m.cell)
	_move_member(0, next)
	if solo:
		return
	for i in range(1, members.size()):
		if members[i].creature.hp <= 0 or PitFall.holds(self, members[i]):
			continue
		if old[i - 1] != members[i].cell:
			_move_member(i, old[i - 1])
	# Guests walk at the back of the line.
	var ahead := old[old.size() - 1] if not old.is_empty() else next
	for g in guest_members:
		if g.creature.hp <= 0 or g.cell == ahead:
			continue
		var was := g.cell
		g.cell = ahead
		var gt := tokens[g.id] as CombatToken
		gt.face(Vector2(ahead - was), true, SNEAK_STEP_TIME if sneaking else STEP_TIME)
		create_tween().tween_property(gt, "position", board.cell_center(ahead), (SNEAK_STEP_TIME if sneaking else STEP_TIME) * 0.95)
		ahead = was


func _move_member(i: int, to: Vector2i) -> void:
	var m := members[i]
	var from := m.cell
	m.cell = to
	var tok := tokens[m.id] as CombatToken
	tok.face(Vector2(to - from), true, SNEAK_STEP_TIME if sneaking else STEP_TIME)
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
			if str(exit["to"]) == "travel":
				travel_requested.emit()
				return true
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


## Passive Perception notices traps in sight (TrapSight); a member stepping on an unnoticed trap springs it.
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
		if state == "" and TrapSight.notice(self, trap):
			return true
		if str(states.get(id, "")) == "":
			for m in members:
				if m.cell in cells:
					_spring_trap(trap, m)
					return true
	return false


func _spring_trap(trap: Dictionary, victim: Combatant) -> void:
	if PitFall.is_pit(trap):
		PitFall.spring(self, trap, victim)   # a real drop: catch the edge or fall in (and climb out later)
		return
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
			if ch.hp <= 0 and not ch.dead:
				out.append_array(_tend_actions(ch))
			out.append_array(PitFall.actions_for(self, members[i]))
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
				var ways := actions_to_unlock(spec)
				out.append_array(ways)
				if ways.is_empty():
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
	if action_id in ["stabilize", "kit"] or action_id.begins_with("potion:"):
		_tend(cell, action_id)
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
		"climb":
			PitFall.climb_out(self, cell)
			return
	if thing.is_empty():
		return
	var spec := thing["spec"] as Dictionary
	var then := Callable()
	match action_id:
		"talk", "use", "open":
			then = func() -> void: interact(thing)
		"key", "pick", "force", "knock", "chime", "mystery_key":
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



# --- A party member down outside a fight (owner ask, 2026-10-07) --------------------------------------------

## What the others can do for `ch` at 0 Hit Points (2024 rules, as in a fight): a DC 10 Wisdom (Medicine) check by
## the best of them, a Healer's Kit (no check), or a healing potion given to them.
func _tend_actions(ch: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var medic := _best(&"medicine")
	if ch.stable:
		out.append({"id": "stabilize", "label": "Stabilize", "enabled": false, "why": "Already stable"})
	elif medic == null:
		out.append({"id": "stabilize", "label": "Stabilize", "enabled": false, "why": "Nobody is on their feet"})
	else:
		out.append({"id": "stabilize", "label": "Stabilize: %s, Medicine %+d vs DC 10" % [medic.name.get_slice(" ", 0),
			medic.skill_bonus(&"medicine").total()]})
		var kit := _holder_of("healers_kit")
		if kit != null:
			out.append({"id": "kit", "label": "Stabilize with %s's Healer's Kit" % kit.name.get_slice(" ", 0)})
	var seen := {}
	for m in st.party:
		if m.hp <= 0:
			continue
		for e: Dictionary in m.inventory:
			var id := str(e["id"])
			if seen.has(id) or int(e["qty"]) <= 0 or _potion_heal(id).is_empty():
				continue
			seen[id] = true
			out.append({"id": "potion:" + id, "label": "Give %s (%s's)" % [Compendium.shared().item_data(id).get("name", id),
				m.name.get_slice(" ", 0)]})
	return out



## Outside a fight, a party member with Hit Points again gets up (Prone ends: there's no turn to spend standing) and
## every party token shows its current state (owner report 2026-10-07: healed outside combat but still "Prone · Dying").
func refresh_party() -> void:
	if in_combat:
		return
	for m in members + guest_members:
		var cr := m.creature
		if cr.hp > 0 and not cr.dead and cr.has_condition(&"prone"):
			cr.remove_condition(&"prone")
		if tokens.has(m.id):
			(tokens[m.id] as CombatToken).refresh()

## A conscious party member carrying `item_id`, or null.
func _holder_of(item_id: String) -> Character:
	for m in st.party:
		if m.hp > 0 and m.inventory.any(func(e: Dictionary) -> bool: return str(e["id"]) == item_id and int(e["qty"]) > 0):
			return m
	return null


## A potion's healing ({dice, flat}), or {} if it isn't a healing potion.
static func _potion_heal(item_id: String) -> Dictionary:
	var data := Compendium.shared().item_data(item_id)
	if str(data.get("category", "")) != "potion":
		return {}
	for fx: Variant in data.get("effects", []):
		if str((fx as Dictionary).get("effect", "")) == "heal":
			return (fx as Dictionary).get("params", {}) as Dictionary
	return {}


## Stabilizes or heals the party member at `cell` (the menu's stabilize, kit and potion:<id>).
func _tend(cell: Vector2i, action_id: String) -> void:
	var target: Character = null
	for m in members:
		if m.cell == cell:
			target = m.creature as Character
	if target == null or target.dead or target.hp > 0:
		return
	var who := target.name.get_slice(" ", 0)
	if action_id == "stabilize":
		var medic := _best(&"medicine")
		if medic == null or target.stable:
			return
		var t := medic.roll_check(dice, &"medicine", 10)
		check_rolled.emit(t.describe())
		if t.success:
			target.stabilize()
			toast.emit("%s stops %s's bleeding: Stable" % [medic.name.get_slice(" ", 0), who])
		else:
			toast.emit("%s can't stop %s's bleeding (try again)" % [medic.name.get_slice(" ", 0), who])
	elif action_id == "kit":
		var holder := _holder_of("healers_kit")
		if holder == null or target.stable:
			return
		target.stabilize()
		toast.emit("%s binds %s's wounds with a Healer's Kit: Stable" % [holder.name.get_slice(" ", 0), who])
	else:
		var item_id := action_id.get_slice(":", 1)
		var holder := _holder_of(item_id)
		var heal := _potion_heal(item_id)
		if holder == null or heal.is_empty():
			return
		var name := str(Compendium.shared().item_data(item_id).get("name", item_id))
		var amount := int(heal.get("flat", 0))
		if heal.has("dice"):
			amount += int(dice.roll_expr(str(heal["dice"]), "%s gives %s %s" % [holder.name, target.name, name])["total"])
		var healed := target.heal(amount, name)
		holder.remove_one(item_id)
		toast.emit("%s gives %s a %s: rolled %d, %d Hit Points" % [holder.name.get_slice(" ", 0), who, name, amount, healed])
	refresh_party()
	party_tended.emit()

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


## The square the mouse points at (owner report 2026-10-06): a person, prop, chest, door or way out drawn there
## first, nearest the camera, since the top of a tall piece lies over the squares behind it; else the floor.
func pick_cell(camera: Camera3D, screen: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best := INF
	var cell := Vector2i(-1, -1)
	for entry: Array in _pickables():
		var t := SpritePick.hit(entry[0] as Node3D, camera, origin, dir)
		if t < best:
			best = t
			cell = entry[1] as Vector2i
	return cell if cell.x >= 0 else GridPick.cell_under(camera, grid, screen)


## [node, cell] for everything drawn that the mouse can point at.
func _pickables() -> Array:
	var out: Array = []
	for m: Combatant in members + guest_members:
		if tokens.has(m.id):
			out.append([tokens[m.id], m.cell])
	# Nothing in an area the party hasn't found yet can be hovered or clicked (HiddenAreas).
	for shown in _npc_shown:
		if not HiddenAreas.hides(self, shown["cell"] as Vector2i):
			out.append([shown["token"], shown["cell"]])
	for key: String in ["props", "containers", "doors", "exits"]:
		var nodes := {"props": prop_nodes, "containers": container_nodes, "doors": door_nodes, "exits": exit_nodes}[key] as Dictionary
		for t: Variant in loc.get(key, []):
			var spec := t as Dictionary
			var node := nodes.get(str(spec.get("id", "")), null) as Node3D
			if node != null and is_instance_valid(node) and not HiddenAreas.hides(self, _cell(spec["cell"])):
				out.append([node, _cell(spec["cell"])])
	return out


## What's at a square for the hover hint and clicks: {kind, id, label} or {}.
func thing_at(cell: Vector2i) -> Dictionary:
	if HiddenAreas.hides(self, cell):
		return {}
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
		Audio.sfx("locked")
		narration.emit("It won't budge.")
		return
	if _locked(door):
		if not _unlock(door, method):
			return
	(st.loc_state(loc_id)["doors"] as Dictionary)[id] = DOOR_OPEN
	Audio.sfx("door")
	grid.set_flag(_cell(door["cell"]), CombatGrid.WALL, false)
	(door_nodes[id] as Node3D).visible = false
	if door.has("flag"):
		st.set_flag(str(door["flag"]))
	_say("open:" + id)
	_trigger_encounter("open:" + id)


## Tries a key, thieves' tools (2024: Dexterity check, + Proficiency Bonus with the tools, Advantage with Sleight of
## Hand too), force (Strength (Athletics)) or the Knock spell, with the best party member for the job. Returns true
## if it opens. `method`: "auto" (a left click: the key if the party carries it, else the lock rattles and says so;
## nothing is tried), or "key", "pick", "force" or "knock" (the right-click menu).
func _unlock(spec: Dictionary, method: String = "auto") -> bool:
	var id := str(spec["id"])
	var key := str(spec.get("key", ""))
	if key != "" and st.party_has_item(key) and method in ["auto", "key"]:
		(st.loc_state(loc_id)["doors"] as Dictionary)[id] = "unlocked"
		Audio.sfx("unlock")
		toast.emit("Unlocked with the %s" % Compendium.shared().display_name("items", key))
		return true
	if method == "auto":
		Audio.sfx("locked")
		var can_try := actions_to_unlock(spec).any(func(a: Dictionary) -> bool: return bool(a.get("enabled", true)))
		toast.emit("Locked. Right-click it to try the lock." if can_try else "Locked. It needs its key.")
		return false
	if method == "key":
		narration.emit("None of you has the key.")
		return false
	if method == "knock":
		return _knock(spec)
	if method == "chime":
		return _chime(spec)
	if method == "mystery_key":
		return _mystery_key(spec)
	var dc := int(spec.get("lock_dc", 15))
	if dc <= 0:
		narration.emit("Locked, and no lock to pick: you'll need the key.")
		return false
	var picker := _lock_picker() if method == "pick" else null
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
		Audio.sfx("unlock")
		_say("check:unlock:success", who)
		return true
	_say("check:unlock:failure", who, "It holds.")
	st.advance_minutes(1)
	return false


## Knock (2024): the lock opens, with a knock heard 300 feet away. Spends the caster's lowest slot that works.
func _knock(spec: Dictionary) -> bool:
	var caster := _knock_caster()
	if caster == null:
		narration.emit("Nobody can cast Knock.")
		return false
	var res := FieldCasting.cast_utility(st, caster, "knock", false)
	if not bool(res["ok"]):
		toast.emit(str(res["text"]))
		return false
	(st.loc_state(loc_id)["doors"] as Dictionary)[str(spec["id"])] = "unlocked"
	Audio.sfx("unlock")
	toast.emit("%s casts Knock. A loud knock, and the lock gives." % caster.name.get_slice(" ", 0))
	return true


## Chime of Opening (2024 DMG): struck as a Magic action, its clear note opens one lock or latch. Ten uses, then it
## cracks and is useless.
func _chime(spec: Dictionary) -> bool:
	var ch := _item_holder("chime_of_opening")
	if ch == null or ch.charges_left("chime_of_opening") <= 0:
		narration.emit("Nobody has a Chime of Opening that still rings.")
		return false
	ch.spend_charges("chime_of_opening", 1)
	(st.loc_state(loc_id)["doors"] as Dictionary)[str(spec["id"])] = "unlocked"
	Audio.sfx("unlock")
	var text := "%s strikes the chime. A clear note rings out, and the lock springs open." % ch.name.get_slice(" ", 0)
	if ch.charges_left("chime_of_opening") <= 0:
		ch.remove_one("chime_of_opening")
		text += " The chime cracks; it won't ring again."
	toast.emit(text)
	return true


## Mystery Key (2024 DMG): a 5 percent chance to open any lock it's tried in, and once it does, the key is gone. Each
## lock gets one try (docs/rules/deviations.md).
func _mystery_key(spec: Dictionary) -> bool:
	var ch := _item_holder("mystery_key")
	if ch == null:
		narration.emit("Nobody carries the Mystery Key.")
		return false
	var ls := st.loc_state(loc_id)
	if not ls.has("mystery_key_tried"):
		ls["mystery_key_tried"] = {}
	(ls["mystery_key_tried"] as Dictionary)[str(spec["id"])] = true
	var roll := dice.roll_one(100, "Mystery Key")
	if roll > 5:
		toast.emit("%s tries the Mystery Key, but it won't turn (d100 %d; it needs 5 or less)." % [ch.name.get_slice(" ", 0), roll])
		return false
	(ls["doors"] as Dictionary)[str(spec["id"])] = "unlocked"
	ch.remove_one("mystery_key")
	Audio.sfx("unlock")
	toast.emit("%s tries the Mystery Key and it turns (d100 %d)! The lock opens, and the key vanishes." % [ch.name.get_slice(" ", 0), roll])
	return true


## The living party member carrying `item_id` (not packed in a bag), or null.
func _item_holder(item_id: String) -> Character:
	for ch in st.party:
		if ch.hp > 0 and not ch.dead and not ch.entry_of(item_id).is_empty():
			return ch
	return null


## The living party member who has Knock ready and a 2nd-level or higher slot to cast it with, or null.
func _knock_caster() -> Character:
	for ch in st.party:
		if ch.hp <= 0 or ch.dead or not ch.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == "knock"):
			continue
		for l in range(2, 10):
			if ch.slots_left(l) > 0:
				return ch
	return null


## The right-click menu's ways to open a lock: the key, Pick the lock, Force it, Cast Knock (each greyed out with the
## reason when it can't be tried). [] when none apply, so it needs its key and nobody has it.
func actions_to_unlock(spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key := str(spec.get("key", ""))
	if key != "":
		var has := st.party_has_item(key)
		out.append({"id": "key", "label": "Unlock with the %s" % Compendium.shared().display_name("items", key),
			"enabled": has, "why": "" if has else "Nobody carries the key"})
	if int(spec.get("lock_dc", 15)) > 0:
		var picker := _lock_picker()
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
	var caster := _knock_caster()
	if caster != null:
		out.append({"id": "knock", "label": "Cast Knock (%s)" % caster.name.get_slice(" ", 0)})
	# Magic items that open locks (ADR 0012): a Chime of Opening's note, a Mystery Key's long odds.
	var chime := _item_holder("chime_of_opening")
	if chime != null:
		var left := chime.charges_left("chime_of_opening")
		out.append({"id": "chime", "label": "Strike the Chime of Opening (%s, %d %s left)" % [chime.name.get_slice(" ", 0), left,
			"use" if left == 1 else "uses"], "enabled": left > 0, "why": "" if left > 0 else "The chime is spent"})
	var mkey := _item_holder("mystery_key")
	if mkey != null:
		var tried := bool((st.loc_state(loc_id).get("mystery_key_tried", {}) as Dictionary).get(str(spec["id"]), false))
		out.append({"id": "mystery_key", "label": "Try the Mystery Key (%s, 1 in 20)" % mkey.name.get_slice(" ", 0),
			"enabled": not tried, "why": "" if not tried else "It wouldn't turn in this lock"})
	return out


## The living party member best at picking locks (thieves' tools in hand, the best bonus), or null.
func _lock_picker() -> Character:
	var picker: Character = null
	var best := -99
	for ch in st.party:
		if ch.hp > 0 and st.member_matches(ch, "item:thieves_tools"):
			var adv: Array[String] = []
			var total := _pick_bonus(ch, adv).total()
			if picker == null or total > best:
				picker = ch
				best = total
	return picker


## 2024 Thieves' Tools: Dexterity check + Proficiency Bonus with the tools, Advantage with Sleight of Hand too.
static func _pick_bonus(picker: Character, adv: Array[String]) -> Breakdown:
	var bonus := picker.ability_check_bonus(&"dex")
	if picker.has_proficiency("tools", "thieves_tools"):
		bonus.add("Thieves' Tools proficiency", picker.proficiency_bonus())
		if picker.skill_rank(&"sleight_of_hand") > 0:
			adv.append("Sleight of Hand proficiency")
	# Gloves of Thievery: +5 to Dexterity checks to pick locks.
	if picker.has_flag("lockpick_plus_5"):
		bonus.add("Gloves of Thievery", 5)
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
	var items := (left["items"] as Array).duplicate(true) if not left.is_empty() else (ct.get("items", []) as Array).duplicate(true)
	if left.is_empty():
		# Scrolls name their spell, and this playthrough's random magic items are in here too (story/treasure.gd).
		items = Treasure.specify_scrolls(items, st, "%s:%s" % [loc_id, id])
		items.append_array(((Treasure.placed(st, loc_id).get(id, []) as Array)).duplicate(true))
	# A Tarokka treasure spot (ADR 0011): whatever the reading hid here is in the chest too.
	for treasure in Tarokka.take_from(Tarokka.place_for(loc, "container", id), st):
		items.append({"id": treasure, "qty": 1})
	loot_opened.emit(id, items, float(left["gold"]) if not left.is_empty() else float(ct.get("gold", 0)))


## Called by the loot window when everything's been taken.
func mark_looted(container_id: String) -> void:
	(st.loc_state(loc_id)["looted"] as Dictionary)[container_id] = true
	if container_nodes.has(container_id):
		SetDressing.mark_looted(container_nodes[container_id] as Node3D)


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
	# Sharp Eye (Ravenloft: The Horrors Within): Advantage on a Search, Proficiency Bonus times per Long Rest.
	var adv: Array[String] = []
	if who.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "sharp_eye") and who.resource_left("sharp_eye") > 0:
		who.spend_resource("sharp_eye")
		adv.append("Sharp Eye")
	var t := who.roll_check(dice, &"perception", 0, adv, [], "%s searches" % who.name, ["search"])
	var sharp_eye := not adv.is_empty()
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
			prop_nodes[str(prop["id"])] = _prop_node(prop)
			found.append(str(prop.get("label", "something")))
			found_ids.append(str(prop["id"]))
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) <= 0 or bool((states["found"] as Dictionary).get(str(door["id"]), false)):
			continue
		if grid.distance_ft(c, 1, _cell(door["cell"]), 1) <= 15 and t.total >= int(door["secret_dc"]):
			(states["found"] as Dictionary)[str(door["id"])] = true
			SetDressing.reveal_door(door_nodes[str(door["id"])] as Node3D)
			found.append(str(door.get("label", "a hidden door")))
	st.last_check = not found.is_empty()
	if found.is_empty() and sharp_eye:
		who.restore_resource("sharp_eye")
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
		# A final battle's `when` also needs Strahd waiting in its room (StoryConditions.encounter_when, ADR 0014).
		if not StoryConditions.check(StoryConditions.encounter_when(spec), st):
			continue
		if str(spec.get("final_battle", "")) != "":
			return _begin_final_battle(str(spec["id"]))
		start_encounter(str(spec["id"]))
		return true
	return false


## Before a final battle Strahd parleys (strahd/final:parley, when it's written and hasn't been answered): the fight
## starts once it ends, if `strahd_parley` is `fight` or unset; `yield` and `ireena` leave it to the ending. True if
## the parley or the fight began.
func _begin_final_battle(encounter_id: String) -> bool:
	var answer := str(st.get_flag("strahd_parley", ""))
	var file := DialogueFile.load_key(PARLEY.get_slice(":", 0))
	if answer == "" and file != null and file.nodes.has(PARLEY.get_slice(":", 1)) and _pending_final == "":
		_pending_final = encounter_id
		dialogue_requested.emit(PARLEY, "strahd")
		return true
	if answer in ["", "fight"]:
		return start_encounter(encounter_id)
	return false


## Fights triggered by a flag (set by dialogue or a lever): checked after conversations and interactions.
func check_flag_encounters() -> bool:
	# The parley before a final battle has ended: the fight, unless Strahd's price was paid.
	if _pending_final != "":
		var waiting := _pending_final
		_pending_final = ""
		if str(st.get_flag("strahd_parley", "")) in ["", "fight"]:
			return start_encounter(waiting)
		return false
	for en: Variant in loc.get("encounters", []):
		var spec := en as Dictionary
		var trig := str(spec["trigger"])
		if trig.begins_with("flag:") and _truthy(st.get_flag(trig.substr(5))):
			if _trigger_encounter(trig):
				return true
	return false


static func _truthy(v: Variant) -> bool:
	return StoryConditions._truthy(v)


## What an exploring spell does here and now (FieldCasting.cast_utility): Light lights the lantern, Detect Magic
## names the magic within 30 ft, Find Traps reveals the traps in sight within 120 ft, Knock opens the nearest lock
## within 60 ft.
func apply_spell_effect(spell_id: String) -> void:
	match spell_id:
		"light":
			update_daylight()
		"knock":
			var nearest := {}
			var nearest_ft := 61
			for list: String in ["doors", "containers"]:
				for d: Variant in loc.get(list, []):
					var spec := d as Dictionary
					var c := _cell(spec["cell"])
					var ft := grid.distance_ft(leader().cell, 1, c, 1)
					if ft < nearest_ft and _locked(spec) and not thing_at(c).is_empty():
						nearest = spec
						nearest_ft = ft
			if nearest.is_empty():
				narration.emit("A loud knock echoes, but there's no lock within 60 feet.")
				return
			(st.loc_state(loc_id)["doors"] as Dictionary)[str(nearest["id"])] = "unlocked"
			Audio.sfx("unlock")
			toast.emit("A loud knock. Unlocked: %s." % str(nearest.get("label", "the lock")))
		"detect_magic":
			var found: Array[String] = []
			var placed := Treasure.placed(st, loc_id)
			for c: Variant in loc.get("containers", []):
				var ct := c as Dictionary
				if not container_nodes.has(str(ct["id"])) or grid.distance_ft(leader().cell, 1, _cell(ct["cell"]), 1) > 30:
					continue
				if bool((st.loc_state(loc_id)["looted"] as Dictionary).get(str(ct["id"]), false)):
					continue
				# The chest's own items and the random treasure rolled into it (story/treasure.gd).
				for it: Variant in (ct.get("items", []) as Array) + (placed.get(str(ct["id"]), []) as Array):
					if MagicItems.is_magic(Compendium.shared().item_data(str((it as Dictionary)["id"]))):
						found.append(str(ct.get("label", "a chest")))
						break
			for p: Variant in loc.get("props", []):
				var pr := p as Dictionary
				if bool(pr.get("magic", false)) and prop_nodes.has(str(pr["id"])) and grid.distance_ft(leader().cell, 1, _cell(pr["cell"]), 1) <= 30:
					found.append(str(pr.get("label", "something")))
			if not _say("detect_magic:%s" % loc_id, leader().creature as Character):
				narration.emit("Magic within 30 ft: %s." % (", ".join(found) if not found.is_empty() else "nothing you can sense"))
		"secrets":
			_wand_of_secrets()
		"find_traps":
			var n := 0
			for t: Variant in loc.get("traps", []):
				var trap := t as Dictionary
				if not StoryConditions.check(str(trap.get("when", "")), st):
					continue
				var state := str((st.loc_state(loc_id)["traps"] as Dictionary).get(str(trap["id"]), ""))
				if state != "":
					continue
				for tc: Variant in trap["cells"]:
					if grid.distance_ft(leader().cell, 1, _cell(tc), 1) <= 120 and grid.can_see(leader().cell, 1, _cell(tc), 1):
						(st.loc_state(loc_id)["traps"] as Dictionary)[str(trap["id"])] = "found"
						_show_trap(trap)
						n += 1
						break
			narration.emit("You sense %s." % ("no traps in sight" if n == 0 else "%d trap%s" % [n, "" if n == 1 else "s"]))


## Wand of Secrets (2024 DMG): it pulses and points at the nearest secret door or trap within 30 ft, which the party
## then knows about (HiddenAreas brings a room behind a found door into view).
func _wand_of_secrets() -> void:
	var c := leader().cell
	var states := st.loc_state(loc_id)
	var best := {}
	var best_kind := ""
	var best_ft := 31
	for d: Variant in loc.get("doors", []):
		var door := d as Dictionary
		if int(door.get("secret_dc", 0)) <= 0 or bool((states["found"] as Dictionary).get(str(door["id"]), false)):
			continue
		var ft := grid.distance_ft(c, 1, _cell(door["cell"]), 1)
		if ft < best_ft:
			best = door
			best_kind = "door"
			best_ft = ft
	for t: Variant in loc.get("traps", []):
		var trap := t as Dictionary
		if str((states["traps"] as Dictionary).get(str(trap["id"]), "")) != "" or not StoryConditions.check(str(trap.get("when", "")), st):
			continue
		for tc: Variant in trap["cells"]:
			var ft2 := grid.distance_ft(c, 1, _cell(tc), 1)
			if ft2 < best_ft:
				best = trap
				best_kind = "trap"
				best_ft = ft2
	if best.is_empty():
		narration.emit("The wand stays still: no secret door or trap within 30 feet.")
		return
	if best_kind == "door":
		(states["found"] as Dictionary)[str(best["id"])] = true
		if door_nodes.has(str(best["id"])):
			SetDressing.reveal_door(door_nodes[str(best["id"])] as Node3D)
	else:
		(states["traps"] as Dictionary)[str(best["id"])] = "found"
		_show_trap(best)
		if best.has("flag"):
			st.set_flag(str(best["flag"]))
	var label := str(best.get("label", "a hidden door" if best_kind == "door" else "a trap"))
	narration.emit("The wand pulses and points %d feet away: %s." % [best_ft, label])
	toast.emit("Found: " + label)


## A fight that isn't in the location's data (a random encounter on the road): added for this visit, then started.
func start_custom_encounter(spec: Dictionary) -> bool:
	var s := spec.duplicate(true)
	s["trigger"] = "dialogue"
	if not loc.has("encounters"):
		loc["encounters"] = []
	(loc["encounters"] as Array).append(s)
	return start_encounter(str(s["id"]))


## A monster's ward in a fight at `location` (ADR 0014): its `ward.hp` taken before its Hit Points (the Heart of
## Sorrow shielding Strahd), in its `region` if it names one, unless the story condition `unless` holds. 0 for none.
static func ward_for(data: Dictionary, location: Dictionary, state: StoryState) -> int:
	var ward := data.get("ward", {}) as Dictionary
	if ward.is_empty() or (str(ward.get("region", "")) != "" and str(ward["region"]) != str(location.get("region", ""))):
		return 0
	return 0 if StoryConditions.check(str(ward.get("unless", "false")), state) else int(ward["hp"])


## The fight happens here, on the same grid: the party where it stands, the monsters where the data puts them.
## Surprise: a sneaking party whose every Stealth check beats a monster's passive Perception surprises it.
func start_encounter(encounter_id: String) -> bool:
	# Several entries may share an id with different `when` conditions (e.g. a lighter version for a lower-level
	# party): the first whose condition holds is the fight.
	var spec := {}
	for en: Variant in loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id and (spec.is_empty() or not StoryConditions.check(StoryConditions.encounter_when(spec), st)):
			spec = en as Dictionary
	if spec.is_empty() or in_combat:
		return false
	if _pending_final == encounter_id:
		_pending_final = ""
	_queue.clear()
	_on_arrive = Callable()
	in_combat = true
	ModeController.force(ModeController.Mode.COMBAT)
	var e := Encounter.new(_combat_grid(), dice)
	e.title = str(spec.get("text", ""))
	# Bosses (ADR 0014): the place (a Misty Escape's resting place), the lair's actions, a foe that withdraws.
	e.location_id = loc_id
	for place: String in Tarokka.spots(loc):
		e.places.append(place)
	if str(spec.get("final_battle", "")) != "":
		e.places.append(str(spec["final_battle"]))
	e.lair = bool(spec.get("lair", false))
	e.outdoors = bool(loc["map"].get("outdoors", false))
	e.legendary.set_withdraw(spec.get("withdraw", {}))
	if str(spec.get("final_battle", "")) != "" and st.quest_stage_index("strahds_lair", st.quest_stage("strahds_lair")) < st.quest_stage_index("strahds_lair", "confronted"):
		st.set_quest_stage("strahds_lair", "confronted")
	var party_cbs: Array[Combatant] = []
	for m in members:
		if m.creature.dead:
			continue
		party_cbs.append(e.add(m.creature, &"party", m.cell))
	for g in guest_members:
		if not g.creature.dead:
			e.add(g.creature, &"guest", g.cell).controller = &"player"
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
		mon.ward_hp = ward_for(data, loc, st)
		if md.has("name"):
			mon.name = str(md["name"])
		elif int(counts[str(md["monster"])]) > 1:
			numbered[str(md["monster"])] = int(numbered.get(str(md["monster"]), 0)) + 1
			mon.name = "%s %d" % [mon.name, numbered[str(md["monster"])]]
		e.add(mon, StringName(str(md.get("side", "enemy"))), _cell(md["cell"]))
	_light_the_fight(e)
	var surprised: Array[String] = []
	var who := str(spec.get("surprise", ""))
	for c in e.combatants:
		if (who == "party" and c.side == &"party") or (who == "enemies" and c.side == &"enemy"):
			surprised.append(c.id)
	if sneaking and who == "":
		surprised.append_array(_stealth_surprise(e))
	(st.loc_state(loc_id)["encounters"] as Dictionary)[encounter_id] = "started"
	var ctokens := _fight_tokens(e)
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
	var ctokens := _fight_tokens(e)
	combat_view = CombatView.new()
	combat_view.input_locked = input_locked
	combat_view.narrator = narrator
	combat_view.story = st
	add_child(combat_view)
	var none: Array[String] = []
	_run_combat(encounter_id, spec, e, ctokens, none)
	return true


## The fight's tokens (combatant id -> CombatToken), made so the switch into combat doesn't jump (owner 2026-10-06):
## the party and guests keep the figures they walked in with, mid-step, facing and lantern and all, and turn to the
## nearest foe as their step lands; the foes fade in where they stand, facing the party.
func _fight_tokens(e: Encounter) -> Dictionary:
	var ctokens := {}
	var ours: Array[CombatToken] = []
	var party_mid := Vector3.ZERO
	for c in e.combatants:
		for m: Combatant in members + guest_members:
			var tok := tokens[m.id] as CombatToken
			if m.creature == c.creature and not ours.has(tok):
				tok.combatant = c
				tok.refresh()
				var spot := board.cell_center(c.cell, c.size_cells)
				if tok.position.distance_to(spot) > 1.0:
					tok.position = spot   # a fight resumed from a save: they stand where the round began
				ctokens[c.id] = tok
				ours.append(tok)
				party_mid += spot
	for m: Combatant in members + guest_members:
		if not ours.has(tokens[m.id] as CombatToken):
			(tokens[m.id] as Node3D).visible = false
	party_mid /= maxf(1.0, float(ours.size()))
	var foes: Array[CombatToken] = []
	for c in e.combatants:
		if ctokens.has(c.id):
			continue
		var t := _combat_token(c)
		t.position = board.cell_center(c.cell, c.size_cells)
		var look := party_mid - t.position
		t.face(Vector2(look.x, look.z), false)
		add_child(t)
		ctokens[c.id] = t
		foes.append(t)
	foes.sort_custom(func(a: CombatToken, b: CombatToken) -> bool: return a.position.distance_to(party_mid) < b.position.distance_to(party_mid))
	for i in foes.size():
		foes[i].emerge(0.1 + 0.5 * i / maxf(1.0, foes.size() - 1.0), 0.6)
	var turn := create_tween()
	turn.tween_interval(STEP_TIME + 0.05)
	turn.tween_callback(func() -> void: _face_nearest_foe(ours, foes))
	return ctokens


## Each of `ours` stops walking and turns to the nearest of `foes`.
func _face_nearest_foe(ours: Array[CombatToken], foes: Array[CombatToken]) -> void:
	for tok in ours:
		if not is_instance_valid(tok):
			continue
		var best := Vector3.ZERO
		var best_d := INF
		for f in foes:
			if is_instance_valid(f) and f.combatant.is_alive() and tok.combatant.hostile_to(f.combatant):
				var d := tok.position.distance_to(f.position)
				if d < best_d:
					best_d = d
					best = f.position - tok.position
		tok.face(Vector2(best.x, best.z), false)


## A fight's token: guests wear their NPC sprite rather than their stat block's.
func _combat_token(c: Combatant) -> CombatToken:
	if c.side == &"guest":
		var npc := Compendium.shared().get_entry("npcs", c.id.trim_prefix("guest_"))
		if not npc.is_empty():
			return CombatToken.create(c, str(npc.get("sprite", npc["id"])))
	return CombatToken.create(c)


## The fight sees what the party sees (vision rules live in the encounter): outdoors the hour sets the light (an
## overcast Barovian day is bright but not true sunlight; night is dark), indoors the map's light does; the
## location's lamps and candles, and the party's lantern when it's lit, are light sources on the grid.
func _light_the_fight(e: Encounter) -> void:
	if bool(loc["map"].get("outdoors", false)):
		e.ambient_light = {"day": "bright", "dusk": "dim", "dawn": "dim"}.get(time_phase(), "dark") as String
	else:
		e.ambient_light = str(loc["map"].get("light", "dim"))
	e.sunlit = false
	for l: Variant in loc.get("lights", []):
		var li := l as Dictionary
		var o := FieldObject.new(FieldObject.Kind.ZONE, "", str(li.get("kind", "light")))
		o.cell = _cell(li["cell"])
		o.rules = {"light": {"bright": int(li.get("bright_ft", 10)), "dim": int(li.get("dim_ft", 10))}}
		e.spells.zones.objects.append(o)
	if lantern != null and lantern.visible and not members.is_empty():
		var lo := FieldObject.new(FieldObject.Kind.ZONE, "", "lantern")
		lo.caster_id = leader().id
		lo.rules = {"light": {"bright": 30, "dim": 30}, "light_on": "caster"}
		e.spells.zones.objects.append(lo)


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
	last_encounter = spec
	for c in e.combatants:
		if c.side in [&"party", &"guest"]:
			for m: Combatant in members + guest_members:
				if m.creature == c.creature:
					m.cell = c.cell
		elif c.creature.dead and not e.legendary.departed.has(c.id):
			var stain := _box(Vector3(0.6, 0.02, 0.4), board.cell_center(c.cell, c.size_cells) + Vector3(0, 0.015, 0), "blood_deep")
			stain.name = "Remains"
	# The party's own figures go back to exploring where they stand; whoever else is still up fades away.
	var ours := {}
	for m: Combatant in members + guest_members:
		ours[tokens[m.id]] = true
	for id: String in ctokens:
		var tok := ctokens[id] as CombatToken
		if ours.has(tok):
			continue
		if tok.visible and tok.combatant.is_alive():
			tok.fade_away(0.5)
		else:
			tok.queue_free()
	if combat_view != null:
		combat_view.close_softly()
		combat_view = null
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
	for m: Combatant in members + guest_members:
		var tok := tokens[m.id] as CombatToken
		tok.combatant = m
		tok.set_active(false)
		tok.set_highlight(false)
		tok.scale = Vector3.ONE
		tok.visible = true
		tok.refresh()
		create_tween().tween_property(tok, "position", board.cell_center(m.cell), 0.25)
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
	# What the fight hands back to the story, whatever the outcome (ADR 0014): Misty Escape's flag, a withdrawal's
	# flag, Strahd destroyed and his quest's stage.
	for f: String in e.legendary.story_flags:
		st.set_flag(f, e.legendary.story_flags[f])
	for qid: String in e.legendary.story_quests:
		st.set_quest_stage(qid, str(e.legendary.story_quests[qid]))
	_save_positions()
	combat_ended.emit(outcome)
	# A foe that withdrew or fled as mist leaves nothing behind (a Tarokka treasure here is still found).
	if outcome == "victory":
		_spoils(encounter_id, spec, not e.legendary.no_loot())


## What a won fight leaves (the encounter's `loot`, and a Tarokka treasure if this fight is a treasure spot), in the
## loot window like a chest. Leftovers stay as "fight:<id>".
func _spoils(encounter_id: String, spec: Dictionary, with_loot: bool = true) -> void:
	var loot := spec.get("loot", {}) as Dictionary if with_loot else {}
	var items := (loot.get("items", []) as Array).duplicate(true)
	for treasure in Tarokka.take_from(Tarokka.place_for(loc, "encounter", encounter_id), st):
		items.append({"id": treasure, "qty": 1})
	var gold := float(loot.get("gold", 0))
	if not items.is_empty() or gold > 0.0:
		loot_opened.emit.call_deferred("fight:" + encounter_id, items, gold)
