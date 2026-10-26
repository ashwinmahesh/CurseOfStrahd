class_name CampaignLook
extends RefCounted
## The campaign's own scenery, as the engine's world code asks for it (docs/plans/engine_split.md): the engine builds boards,
## towns, rooms and props, and where a campaign has set pieces of its own (a castle's walls and towers, a temple's glowing
## amber, a statue on steps) it asks CampaignLook.current(). This base builds none: no square is claimed, nothing is added.
## data/campaign.json names the campaign's script under "look" (Curse of Strahd: world/look/strahd_look.gd).

const CONFIG := "res://data/campaign.json"

static var _current: CampaignLook


static func current() -> CampaignLook:
	if _current == null:
		_current = _load()
	return _current


## Puts `l` in place of the configured look; null goes back to the configured one.
static func use(l: CampaignLook) -> void:
	_current = l


static func _load() -> CampaignLook:
	if FileAccess.file_exists(CONFIG):
		var cfg := JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) as Dictionary
		var script := load(str(cfg.get("look", ""))) as GDScript
		if script != null:
			return script.new() as CampaignLook
	return CampaignLook.new()


# --- Big set pieces built into a board -----------------------------------------------------------------------------

## Works out the board's set pieces before the towns split their walls into houses.
func plan(_board: ArenaBoard) -> bool:
	return false


## Whether the set piece stands this square's floor in place of the ordinary floor.
func walk_at(_board: ArenaBoard, _c: Vector2i) -> bool:
	return false


## Whether the square belongs to a set piece (its roofs and walls), so the ordinary walls leave it alone.
func claims(_board: ArenaBoard, _c: Vector2i) -> bool:
	return false


## Whether a gate here stands in a passage the set piece frames with its own arch.
func frames(_board: ArenaBoard, _c: Vector2i) -> bool:
	return false


## Cuts a set-piece building away while the camera looks into it (`b` is the board's building record).
func cut(_b: Dictionary, _camera_pos: Vector3, _focus: Vector3, _delta: float) -> void:
	pass


# --- Statues, props and places of its own ---------------------------------------------------------------------------

## Steps for a statue on a plinth (a wall style with `plinth`), built once for its rect.
func plinth_steps(_board: ArenaBoard, _rect: Rect2i) -> void:
	pass


## Dresses a placed prop whose catalog look says `god`.
func dress_god(_board: ArenaBoard, _root: Node3D, _piece: Node3D, _cell: Vector2i) -> void:
	pass


## A catalog art the campaign builds in code. Returns {"handled": true, "node": Node3D} when it did, {"art": other} to carry
## on with another art name (the classic look), or {} to leave `art` alone.
func place_special(_art: String, _board: ArenaBoard, _root: Node3D, _cell: Vector2i, _spec: Dictionary, _look: Dictionary) -> Dictionary:
	return {}


## The panes of a door whose art is `amber_doors` (any campaign door with a light of its own).
func dress_door(_art: String, _leaf: Node3D, _width: float, _height: float) -> void:
	pass


## A place's own small things, once its props are up.
func dress_place(_view: LocationView) -> void:
	pass


## The place's lights and glows, every quarter second and whenever someone starts or stops speaking.
func refresh(_view: LocationView) -> void:
	pass
