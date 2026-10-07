class_name PartyGlide
extends RefCounted
## How a party token walks between squares outside a fight (owner 2026-10-07: "the characters move and stop kind of
## unnaturally"). LocationView still moves the party square by square; this draws it as one continuous walk: the token
## eases in when it sets off and eases out to a stop, keeps a steady pace through the squares (diagonals included),
## rounds corners instead of snapping, turns through the in-between directions, matches its walk cycle to its speed,
## and finishes its stride before standing still. Followers set off a beat after the one ahead.

## Seconds to reach full pace from a standstill, and to come to a stop from it.
const EASE := 0.16
## How far ahead along the path (in squares) the token steers: corners are rounded about this much.
const LOOKAHEAD := 0.35
## How fast the heading turns (radians a second): a reversal passes through the directions between.
const TURN_RATE := 12.0
## A follower waits this long per place in the line before setting off from a standstill.
const FOLLOW_DELAY := 0.04

var token: CombatToken
## Square centres still to reach, in order.
var points: Array[Vector3] = []
## Seconds a square takes at full pace.
var step_time := 0.18
## Seconds to hold still before setting off.
var wait := 0.0
var speed := 0.0
var heading := Vector3.ZERO
## A follower: more than a square behind, it walks up to this much faster to close the gap (the line stays about a
## square apart).
var catch_up := 1.0


func _init(tok: CombatToken) -> void:
	token = tok


## Moves the token on by `delta` seconds. True once it has arrived and stopped.
func update(delta: float) -> bool:
	if wait > 0.0:
		wait -= delta
		return false
	if points.is_empty():
		_stop()
		return true
	var pos := token.position
	var full := 1.0 / maxf(step_time, 0.01)
	var accel := full / EASE
	var left := _length_left(pos)
	var want := _carrot(pos, LOOKAHEAD) - pos
	want.y = 0.0
	if want.length_squared() > 1e-8:
		want = want.normalized()
		heading = want if heading == Vector3.ZERO else _turn(heading, want, TURN_RATE * delta)
	# Slow for a sharp turn (a reversal nearly stops), and never faster than the speed that stops on the last square.
	var bend := clampf(heading.dot(want) * 0.5 + 0.5, 0.25, 1.0) if want != Vector3.ZERO else 1.0
	var pace := full * clampf(left, 1.0, catch_up)
	speed = minf(move_toward(speed, pace * bend, accel * delta), sqrt(2.0 * accel * left) + 0.05)
	var go := speed * delta
	if go >= left or left < 0.01:
		token.position = points[points.size() - 1]
		points.clear()
		_stop()
		return true
	# Steer: along the heading, toward the point a little ahead on the path.
	var step := (heading if heading != Vector3.ZERO else want) * go
	var rise := clampf(go / maxf(_flat(points[0] - pos), 0.001), 0.0, 1.0)
	token.position = Vector3(pos.x + step.x, lerpf(pos.y, points[0].y, rise), pos.z + step.z)
	while points.size() > 1 and _flat(token.position - points[0]) <= LOOKAHEAD:
		points.pop_front()
	token.face(Vector2(heading.x, heading.z), true, 1.0 / maxf(speed, full * 0.35))
	return false


## The walk ends: stand still (the sprite finishes its stride first).
func _stop() -> void:
	speed = 0.0
	if is_instance_valid(token):
		if token.sprite != null:
			token.sprite.finish_stride = true
		token.face(Vector2.ZERO, false)


## Distance left along the path from `pos` (ground plane).
func _length_left(pos: Vector3) -> float:
	var total := 0.0
	var at := pos
	for p in points:
		total += _flat(p - at)
		at = p
	return total


## The point `ahead` squares along the path from `pos`.
func _carrot(pos: Vector3, ahead: float) -> Vector3:
	var at := pos
	var left := ahead
	for p in points:
		var d := _flat(p - at)
		if d >= left:
			return at.lerp(p, left / d)
		left -= d
		at = p
	return points[points.size() - 1]


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Turns unit vector `from` toward `to` by at most `max_angle` radians round the vertical.
static func _turn(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var a := atan2(from.x, from.z)
	var b := atan2(to.x, to.z)
	var diff := wrapf(b - a, -PI, PI)
	var turned := a + clampf(diff, -max_angle, max_angle)
	return Vector3(sin(turned), 0.0, cos(turned))
