class_name TouchGesture
extends RefCounted
## Contact ownership is fixed on press. A gesture that scrolled or joined a camera gesture can never tap
## when released. Coordinates and thresholds are logical points, not Retina pixels.

const SLOP := 12.0
const HOLD_MS := 500
## Ignore angular/zoom changes when fingers meet: the line between them has no stable direction.
const CAMERA_MIN_SPAN := 32.0

var contacts: Dictionary = {}


func press(index: int, at: Vector2, owner: String, now: int) -> void:
	contacts[index] = {"start": at, "at": at, "owner": owner, "time": now, "dragged": false, "multiple": false}
	if contacts.size() > 1:
		for id: int in contacts:
			(contacts[id] as Dictionary)["multiple"] = true


func move(index: int, at: Vector2) -> Dictionary:
	if not contacts.has(index):
		return {}
	var contact := contacts[index] as Dictionary
	var before := contact["at"] as Vector2
	var world := _world()
	var old_pair := _pair(world)
	contact["at"] = at
	if at.distance_to(contact["start"] as Vector2) > SLOP:
		contact["dragged"] = true
	if str(contact["owner"]) != "world":
		return {"kind": "scroll", "delta": at - before, "owner": contact["owner"]} if bool(contact["dragged"]) else {}
	if world.size() == 2 and contacts.size() == 2:
		var pair := _pair(world)
		var stable := old_pair.length() >= CAMERA_MIN_SPAN and pair.length() >= CAMERA_MIN_SPAN
		return {"kind": "camera", "scale": pair.length() / old_pair.length() if stable else 1.0,
			"rotation": old_pair.angle_to(pair) if stable else 0.0, "delta": (at - before) / 2.0}
	if world.size() == 1 and bool(contact["dragged"]) and not bool(contact["multiple"]):
		return {"kind": "pan", "delta": at - before}
	return {}


func release(index: int, at: Vector2, now: int, canceled: bool = false) -> Dictionary:
	if not contacts.has(index):
		return {}
	var contact := contacts[index] as Dictionary
	contacts.erase(index)
	if canceled or bool(contact["dragged"]) or bool(contact["multiple"]) or at.distance_to(contact["start"] as Vector2) > SLOP:
		return {}
	return {"kind": "context" if now - int(contact["time"]) >= HOLD_MS else "tap",
		"at": at, "owner": contact["owner"]}


func cancel() -> void:
	contacts.clear()


func _world() -> Array[int]:
	var out: Array[int] = []
	for id: int in contacts:
		if str((contacts[id] as Dictionary)["owner"]) == "world":
			out.append(id)
	return out


func _pair(ids: Array[int]) -> Vector2:
	if ids.size() != 2:
		return Vector2.ZERO
	return (contacts[ids[1]]["at"] as Vector2) - (contacts[ids[0]]["at"] as Vector2)
