class_name NpcWalker
extends Node3D
## A neutral NPC that walks a fixed loop of waypoints (a scripted route, not a decision).
## Used in the gray-box room to show the generated 8-direction walk.

const SPEED := 1.12   # squares a second (owner 2026-10-07: about 30% slower)

var waypoints: Array[Vector3] = []
var sprite: DirectionalSprite
var _next := 0


static func create(frames: SpriteFrames, route: Array[Vector3]) -> NpcWalker:
	var n := NpcWalker.new()
	n.name = "Villager"
	n.waypoints = route
	n.sprite = DirectionalSprite.create(frames, 1.55)
	n.sprite.set_step_time(1.0 / SPEED)
	# The generated art is dark; lift it a little so it reads against the night floor.
	n.sprite.modulate = Color(1.3, 1.3, 1.3)
	n.add_child(n.sprite)
	n.position = route[0]
	return n


func _physics_process(delta: float) -> void:
	if waypoints.size() < 2:
		sprite.moving = false
		return
	var goal := waypoints[_next]
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 0.05:
		_next = (_next + 1) % waypoints.size()
		return
	var step := minf(SPEED * delta, to.length())
	global_position += to.normalized() * step
	sprite.facing = to.normalized()
	sprite.moving = true
