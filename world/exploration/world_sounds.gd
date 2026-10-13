class_name WorldSounds
extends Node3D
## The sounds of a place, heard from where they happen (A3, lane 11): the leader's footsteps, one each time its figure
## puts a foot down, on what the floor is made of, fires crackling and water running from where they are, louder as
## the party comes near, and the creak of a chest or the rustle of a sack as it's opened. art/audio.json says what
## plays: "steps" names each place's or map theme's floor, "loops" lists the fire and water beds, "containers" names
## each container model's sound. Doors, locks, levers and traps play their own one-shot effects where the game handles
## them.

## How much quieter footsteps are while the party sneaks.
const SNEAK_DB := -9.0
## A fire or water bed is heard from this far (world units, one a square) and at full volume within UNIT of it.
const HEARD_FROM := 14.0
const UNIT := 2.0
## Water squares nearer than this to a bed already placed share it, and a place has at most MAX_WATER beds, so a river
## is a few beds along its bank rather than one a square.
const WATER_SPACING := 6.0
const MAX_WATER := 8
## The light kinds that are open fires (torches are too many and too small to hear).
const FIRE_KINDS: Array[String] = ["fire", "bonfire", "brazier"]
## The listener stands at the leader, this high, so a bed's volume follows the party rather than the far-off camera.
const EAR_HEIGHT := 1.2

var view: LocationView
var floor_sound := ""
var beds: Array[AudioStreamPlayer3D] = []
var _ear: AudioListener3D
## The leader's figure, whose footfalls (DirectionalSprite.footfall) the footsteps play on.
var _feet: DirectionalSprite = null
var _rng := RandomNumberGenerator.new()   # cosmetic: where in its loop each bed starts


static func create(view_: LocationView) -> WorldSounds:
	var w := WorldSounds.new()
	w.name = "WorldSounds"
	w.view = view_
	return w


## The floor a place's footsteps sound on: its own entry in art/audio.json "steps", else its map theme's, else
## "stone".
static func floor_for(location_id: String, theme: String) -> String:
	var steps := Audio._data.get("steps", {}) as Dictionary
	var places := steps.get("places", {}) as Dictionary
	if places.has(location_id):
		return str(places[location_id])
	return str((steps.get("themes", {}) as Dictionary).get(theme, "stone"))


## The footstep effect for a square: brambles and bog sound as mud outdoors and as loose gravel indoors.
static func step_for(floor_: String, difficult: bool, outdoors: bool) -> String:
	if difficult:
		return "step_mud" if outdoors else "step_gravel"
	return "step_" + floor_


## Where the fire beds go: open fires among the place's lights, and props the story has set burning.
static func fire_cells(loc: Dictionary, burning: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = burning.duplicate()
	for l: Variant in loc.get("lights", []):
		var li := l as Dictionary
		if str(li.get("kind", "")) in FIRE_KINDS:
			out.append(LocationView._cell(li["cell"]))
	return out


## Where the water beds go: deep water squares on a bank (next to a square the party can stand on), at least
## WATER_SPACING apart, and no more than MAX_WATER of them.
static func water_cells(grid: CombatGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, z)
			if not grid.has_flag(c, CombatGrid.WATER) or not _on_bank(grid, c):
				continue
			if out.any(func(o: Vector2i) -> bool: return Vector2(o - c).length() < WATER_SPACING):
				continue
			out.append(c)
			if out.size() >= MAX_WATER:
				return out
	return out


static func _on_bank(grid: CombatGrid, c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not grid.has_flag(c + d, CombatGrid.WALL | CombatGrid.WATER | CombatGrid.VOID):   # off the map counts as VOID
			return true
	return false


## The sound a container makes as it's opened, by its model ("containers" in art/audio.json; "rummage" by default).
static func container_sound(model: String) -> String:
	return str((Audio._data.get("containers", {}) as Dictionary).get(model, "rummage"))


func _ready() -> void:
	var map := view.loc.get("map", {}) as Dictionary
	floor_sound = floor_for(view.loc_id, ArenaBoard.theme_for(map))
	_ear = AudioListener3D.new()
	add_child(_ear)
	_ear.make_current()
	var burning: Array[Vector2i] = []
	for p: Variant in view.loc.get("props", []):
		var prop := p as Dictionary
		if view.prop_nodes.has(str(prop.get("id", "")) + "#fire"):
			burning.append(LocationView._cell(prop["cell"]))
	for c in fire_cells(view.loc, burning):
		_add_bed("hearth", c)
	var water := str((Audio._data.get("water", {}) as Dictionary).get(view.loc_id, "river"))
	for c in water_cells(view.grid):
		_add_bed(water, c)
	view.loot_opened.connect(_on_loot_opened)


func _add_bed(id: String, cell: Vector2i) -> void:
	var stream := Audio.loop_stream(id)
	var p := AudioStreamPlayer3D.new()
	p.name = "Bed_%s_%d_%d" % [id, cell.x, cell.y]
	p.bus = &"SFX"
	p.unit_size = UNIT
	p.max_distance = HEARD_FROM
	p.volume_db = Audio.level_db(id)
	p.position = view.board.cell_center(cell) + Vector3(0, 0.4, 0)
	add_child(p)
	beds.append(p)
	if stream != null:
		p.stream = stream
		if Audio.audible():
			p.play(_rng.randf() * stream.get_length())


func _process(_delta: float) -> void:
	var lead := view.leader()
	if lead == null or not view.tokens.has(lead.id):
		return
	var token := view.tokens[lead.id] as Node3D
	var cam := view.rig.camera if view.rig != null else null
	_ear.global_transform = Transform3D(cam.global_basis if cam != null else Basis(), token.global_position + Vector3(0, EAR_HEIGHT, 0))
	_listen_to(token as CombatToken)


## Hears the footfalls of `token`'s figure (the leader's): a new leader's, or a figure drawn anew, replaces the last.
func _listen_to(token: CombatToken) -> void:
	var feet: DirectionalSprite = token.sprite if token != null else null
	if is_instance_valid(_feet) and feet == _feet:
		return
	if is_instance_valid(_feet):
		_feet.footfall.disconnect(_on_footfall)
	_feet = feet
	if feet != null:
		feet.footfall.connect(_on_footfall)


## A footfall of the leader's: its footstep, on what the square under it is made of. A fight's moves have their own
## sounds, and arriving somewhere isn't a step (the figure doesn't walk there).
func _on_footfall() -> void:
	if view.in_combat or not is_instance_valid(_feet):
		return
	var at := view.grid.cell_at((_feet.get_parent() as Node3D).position)
	var outdoors := bool((view.loc.get("map", {}) as Dictionary).get("outdoors", false))
	var id := step_for(floor_sound, view.grid.has_flag(at, CombatGrid.DIFFICULT), outdoors)
	Audio.sfx(id, 0.08, SNEAK_DB if view.sneaking else 0.0)


func _on_loot_opened(container_id: String, _items: Array, _gold: float) -> void:
	for c: Variant in view.loc.get("containers", []):
		var ct := c as Dictionary
		if str(ct.get("id", "")) == container_id:
			Audio.sfx(container_sound(str(ct.get("model", ""))))
			return
