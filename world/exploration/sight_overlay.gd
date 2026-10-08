class_name SightOverlay
extends Node3D
## Who can see you (U10, lane 25; docs/rules/stealth.md), after Baldur's Gate 3's sight cones: while the party sneaks or
## explores turn-based, or while the player holds L (show_sight), each foe waiting in plain view shows the squares it
## can see, and wears an eye that says how likely it is to notice the party there. While the party sneaks or L is
## held, so do the people standing here, who would see a theft or a trespass (F8, LocationCrime).
##
## The eye and its squares are red when the watcher would notice one of the party who stepped into its sight even in
## dim light (always, when the party isn't sneaking), amber when only bright light would give them away (dim light
## lowers its passive Perception by 5), and gold when the party's Stealth beats it either way. Its squares are its sight
## cone (LocationStealth.CONE_DEG the way its figure faces, out to NOTICE_FT, in its line of sight and with less than
## Three-Quarters Cover) and the ring it hears all round (HEAR_FT, not through walls).

const EYE_HEIGHT := 1.8
const EYE_PIXEL := 0.0058

## The tint of the squares a foe watches, by its eye's mood (a square several foes watch takes the worst).
const MOODS := {"notices": ["crimson", 0.09], "bright": ["candle", 0.08], "beaten": ["gilt", 0.05]}

var view: LocationView
var _eyes: Dictionary = {}       ## foe id -> Sprite3D
var _reach: Dictionary = {}      ## mood -> MultiMeshInstance3D
var _reach_cells: Dictionary = {}   ## foe id -> [sight key, Array[Vector2i]]
var _shown_key := ""


static func create(view_: LocationView) -> SightOverlay:
	var o := SightOverlay.new()
	o.name = "SightOverlay"
	o.view = view_
	return o


func _ready() -> void:
	for mood: String in MOODS:
		var layer := MultiMeshInstance3D.new()
		layer.name = "Reach_" + mood
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.96, 0.96)
		mm.mesh = pm
		layer.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(Look.color(str(MOODS[mood][0])), float(MOODS[mood][1]))
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Drawn after the palette pass, like the fight's floor marks (GridOverlay).
		mat.render_priority = 4
		layer.material_override = mat
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(layer)
		_reach[mood] = layer


## Whether the player is holding the key that shows what foes can see.
static func held() -> bool:
	return InputMap.has_action(&"show_sight") and Input.is_action_pressed(&"show_sight")


func _process(_delta: float) -> void:
	if view == null or not is_instance_valid(view):
		return
	var on := (view.sneaking or view.planning or held()) and not view.in_combat
	var key := _state_key(on)
	if key == _shown_key:
		return
	_shown_key = key
	refresh(on)


## Whether the people here show what they can see too: only while the party sneaks or L is held, when a theft or a
## trespass is on the player's mind (in turn-based mode alone they'd crowd a town with red).
func people_shown() -> bool:
	return (view.sneaking or held()) and not view.in_combat


## What the marks depend on: whether they show, the foes in sight, the people here, the party's Stealth, and what the
## watchers can see.
func _state_key(on: bool) -> String:
	if not on:
		return "off"
	var shown: Array = []
	for w in view.waiting:
		if LocationStealth.is_shown(w):
			shown.append([str((w["foe"] as Combatant).id), LocationStealth.cone_of(w).snapped(Vector2(0.05, 0.05))])
	var people: Array = []
	if people_shown():
		for npc_id: String in LocationCrime.people(view):
			var tok := LocationCrime.token(view, npc_id)
			people.append([npc_id, tok.combatant.cell, LocationStealth.token_facing(tok).snapped(Vector2(0.05, 0.05))])
	return str([shown, people, view.sneaking, view.sneak_totals.values(), view._waiting_key, view.st.loc_state(view.loc_id)["doors"]])


## Redraws the eyes and the squares each watcher can see.
func refresh(on: bool = true) -> void:
	var worst := {}   ## cell -> mood, the most dangerous watcher seeing it
	var keep := {}
	if on:
		var e := LocationStealth.watch(view)
		var lowest := _lowest_total()
		var watchers: Array = []   ## [Combatant, its figure]
		for w in view.waiting:
			if LocationStealth.is_shown(w):
				watchers.append([w["foe"], w["token"]])
		if people_shown():
			for npc_id: String in LocationCrime.people(view):
				if not npc_id in view.st.guest_ids:
					watchers.append([LocationCrime.person(view, npc_id), LocationCrime.token(view, npc_id)])
		for pair: Array in watchers:
			var who := pair[0] as Combatant
			keep[who.id] = true
			var mood := eye_mood(who, lowest, view.sneaking)
			_eye(who, pair[1] as Node3D, mood)
			for c in reach_of(e, who):
				if not worst.has(c) or MOODS.keys().find(mood) < MOODS.keys().find(str(worst[c])):
					worst[c] = mood
	for id: String in _eyes.keys():
		if not keep.has(id):
			(_eyes[id] as Node).queue_free()
			_eyes.erase(id)
	for mood: String in MOODS:
		var cells: Array[Vector2i] = []
		for c: Vector2i in worst:
			if worst[c] == mood:
				cells.append(c)
		var mm := (_reach[mood] as MultiMeshInstance3D).multimesh
		mm.instance_count = cells.size()
		for i in cells.size():
			mm.set_instance_transform(i, Transform3D(Basis(), view.board.cell_center(cells[i]) + Vector3(0, 0.015, 0)))


## The lowest Stealth total among the party who are up (0 when not sneaking).
func _lowest_total() -> int:
	if not view.sneaking:
		return 0
	var lowest := 1 << 20
	for m: Combatant in view.members + view.guest_members:
		if m.creature.hp > 0:
			lowest = mini(lowest, LocationStealth.total_for(view, m.creature))
	return lowest


## How a foe would take the party stepping into its sight: "notices" (red: even in dim light), "bright" (amber: only
## in bright light, since dim light takes 5 off its passive Perception) or "beaten" (the party's Stealth beats it).
static func eye_mood(foe: Combatant, lowest: int, sneaking: bool) -> String:
	if not sneaking:
		return "notices"
	if not foe.has_meta("passive_perception"):
		foe.set_meta("passive_perception", foe.creature.passive_score(&"perception").total())
	var score := int(foe.get_meta("passive_perception"))
	if score - 5 >= lowest:
		return "notices"
	return "bright" if score >= lowest else "beaten"


## The squares `foe` watches: those it hears all round (within HEAR_FT, not through walls) and its sight cone out to
## NOTICE_FT (in its line of sight, with less than Three-Quarters Cover). Cached until it moves or turns, or a door or
## a secret room changes what it can see.
func reach_of(e: Encounter, foe: Combatant) -> Array[Vector2i]:
	var facing := foe.get_meta("watch_facing", Vector2.ZERO) as Vector2
	var key := str([foe.cell, facing.snapped(Vector2(0.05, 0.05)), view.st.loc_state(view.loc_id)["doors"], HiddenAreas.signature(view)])
	var cached := _reach_cells.get(foe.id, []) as Array
	if not cached.is_empty() and str(cached[0]) == key:
		return cached[1] as Array[Vector2i]
	var out: Array[Vector2i] = []
	var r := LocationStealth.NOTICE_FT / CombatGrid.FEET
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := foe.cell + Vector2i(dx, dy)
			if not e.grid.in_bounds(c) or e.grid.is_solid(c) or c in foe.footprint() or HiddenAreas.hides(view, c):
				continue
			var d := e.grid.distance_ft(foe.cell, foe.size_cells, c, 1)
			if d > LocationStealth.NOTICE_FT or (d > LocationStealth.HEAR_FT and not LocationStealth.in_cone(foe, c)):
				continue
			if not e.grid.can_see(foe.cell, foe.size_cells, c, 1):
				continue
			if d > LocationStealth.HEAR_FT and int(e.grid.cover_between(foe.cell, foe.size_cells, c, 1)["cover"]) >= CombatGrid.Cover.THREE_QUARTERS:
				continue
			out.append(c)
	_reach_cells[foe.id] = [key, out]
	return out


func _eye(foe: Combatant, token: Node3D, mood: String) -> void:
	var eye := _eyes.get(foe.id, null) as Sprite3D
	if eye == null:
		eye = Sprite3D.new()
		eye.name = "Eye_" + foe.id
		eye.texture = UiKit.icon("search")
		eye.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		eye.no_depth_test = true
		eye.render_priority = 6
		eye.pixel_size = EYE_PIXEL
		eye.shaded = false
		add_child(eye)
		_eyes[foe.id] = eye
	eye.position = (token.position if token != null else view.board.cell_center(foe.cell, foe.size_cells)) + Vector3(0, EYE_HEIGHT * foe.size_cells, 0)
	eye.modulate = Look.color({"notices": "crimson", "bright": "candle", "beaten": "gilt"}[mood] as String)
	eye.set_meta("mood", mood)


## The mood shown over this foe (tests), or "".
func mood_of(foe_id: String) -> String:
	var eye := _eyes.get(foe_id, null) as Sprite3D
	return str(eye.get_meta("mood", "")) if eye != null else ""


## How many squares are tinted (tests): all of them, or those of one mood.
func reach_size(mood: String = "") -> int:
	var n := 0
	for m: String in MOODS:
		if mood == "" or m == mood:
			n += (_reach[m] as MultiMeshInstance3D).multimesh.instance_count
	return n
