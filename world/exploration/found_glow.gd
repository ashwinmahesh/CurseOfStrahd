class_name FoundGlow
extends Node
## What the party has just found glows (owner ask 2026-10-13: "When we find something via a perception check, give
## that thing a glowing orange outline so we know what was discovered"). A hidden find, a secret door or a trap that
## comes to light here gets an orange outline (FoundOutline): it pulses as it's found, then stays steady until the
## party uses the thing or leaves the place. Things found on an earlier visit, or before the party got here (a place
## hint), don't glow. In a fight it's put away (the fight's own rings and outlines are the ones to read there) and
## comes back after it.
##
## It watches the location's states rather than each way of finding things, so a Search, a check's reveal, a
## conversation and a spell all count: whatever turns up in the place's `found` states, or as a found trap, glows.
## Using the thing (LocationInteraction) ends its glow, and so does opening the door, taking the find or the trap
## going off or being disarmed, however that happens.

## Seconds it pulses as it's found, one pulse every PULSE_EVERY; then the steady outline.
const PULSE := 2.4
const PULSE_EVERY := 0.8
## Seconds it takes to come up when found, and to go once used.
const RISE := 0.15
const FADE := 0.35
## How often the place's states are looked at (seconds).
const CHECK_EVERY := 0.1

var view: LocationView
## What's lit: "kind:id" -> {kind, id, at (when found, on this node's clock), was (its state then, _state_of), lit
## (FoundOutline's), ending (-1, or when it began to go)}.
var lit: Dictionary = {}
## Everything already found here, lit or not ("kind:id" -> true).
var _known: Dictionary = {}
## The props and secret doors here that can be found: id -> "prop" or "door".
var _kinds: Dictionary = {}
var _sig := ""
var _wait := 0.0
var _clock := 0.0
var _in_fight := false


static func create(v: LocationView) -> FoundGlow:
	var g := FoundGlow.new()
	g.name = "FoundGlow"
	g.view = v
	return g


## The location's FoundGlow, or null.
static func of(v: LocationView) -> FoundGlow:
	return v.get_node_or_null("FoundGlow") as FoundGlow if v != null and is_instance_valid(v) else null


## The party used thing `kind` `id` here (opened it, took it, tried its lock, disarmed it ...): its glow goes.
static func used(v: LocationView, kind: String, id: String) -> void:
	var g := of(v)
	if g != null:
		g.end(kind + ":" + id)


func _ready() -> void:
	for p: Variant in view.loc.get("props", []):
		_kinds[str((p as Dictionary)["id"])] = "prop"
	for d: Variant in view.loc.get("doors", []):
		if int((d as Dictionary).get("secret_dc", 0)) > 0:
			_kinds[str((d as Dictionary)["id"])] = "door"
	for key in _found_now():
		_known[key] = true
	_sig = _signature()


func _process(delta: float) -> void:
	_clock += delta
	_wait -= delta
	if _wait <= 0.0:
		_wait = CHECK_EVERY
		_look()
	_animate()


## Whether `kind:id` is glowing now.
func is_lit(key: String) -> bool:
	return lit.has(key) and float((lit[key] as Dictionary)["ending"]) < 0.0


## Starts `key`'s glow going.
func end(key: String) -> void:
	if lit.has(key) and float((lit[key] as Dictionary)["ending"]) < 0.0:
		(lit[key] as Dictionary)["ending"] = _clock


## Everything found here now: "prop:<id>", "door:<id>" and "trap:<id>" keys.
func _found_now() -> Array[String]:
	var out: Array[String] = []
	var states := view.st.loc_state(view.loc_id)
	for id: String in states["found"]:
		if _kinds.has(id) and bool((states["found"] as Dictionary)[id]):
			out.append("%s:%s" % [_kinds[id], id])
	for id: String in states["traps"]:
		if str((states["traps"] as Dictionary)[id]) == "found":
			out.append("trap:" + id)
	return out


func _signature() -> String:
	var states := view.st.loc_state(view.loc_id)
	return "%d|%d" % [(states["found"] as Dictionary).size(), (states["traps"] as Dictionary).size()]


func _look() -> void:
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		for key in _found_now():
			if not _known.has(key):
				_known[key] = true
				var none: Array[Dictionary] = []
				var kind := key.get_slice(":", 0)
				var id := key.get_slice(":", 1)
				lit[key] = {"kind": kind, "id": id, "at": _clock, "was": _state_of(kind, id), "lit": none, "ending": -1.0}
	if view.in_combat != _in_fight:
		_in_fight = view.in_combat
		for key: String in lit:
			var entry := lit[key] as Dictionary
			FoundOutline.remove(entry["lit"] as Array[Dictionary])
			(entry["lit"] as Array[Dictionary]).clear()
	for key: String in lit.keys():
		var entry := lit[key] as Dictionary
		if float(entry["ending"]) < 0.0 and _state_of(str(entry["kind"]), str(entry["id"])) != str(entry["was"]):
			end(key)
		if _in_fight or float(entry["ending"]) >= 0.0:
			continue
		var pieces := entry["lit"] as Array[Dictionary]
		if pieces.is_empty() or not FoundOutline.alive(pieces):
			# Not on yet (just found, or back from a fight), or its pieces were rebuilt (after a conversation).
			FoundOutline.remove(pieces)
			entry["lit"] = _light(str(entry["kind"]), str(entry["id"]))
			entry["k"] = -1.0   # new materials: set their strength
		else:
			FoundOutline.refit(pieces)


## Where thing `kind` `id` stands: a find used or not, a door's state, a trap's. When it changes from what it was as the
## thing was found, the party has dealt with it some way (taken it, opened or unlocked the door, sprung or disarmed
## the trap) and the glow goes. A find a check hands straight over is already used as it's found, so it still glows.
func _state_of(kind: String, id: String) -> String:
	var states := view.st.loc_state(view.loc_id)
	match kind:
		"prop":
			return str(bool((states["props"] as Dictionary).get(id, false)))
		"door":
			return str((states["doors"] as Dictionary).get(id, ""))
		"trap":
			return str((states["traps"] as Dictionary).get(id, ""))
	return ""


## Outlines what thing `kind` `id` shows: a find's piece, a door's leaf, a trap's own pieces (its border alone when it
## has none).
func _light(kind: String, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match kind:
		"prop":
			out = FoundOutline.apply(view.prop_nodes.get(id, null) as Node3D)
		"door":
			out = FoundOutline.apply(view.door_nodes.get(id, null) as Node3D, false)   # its leaf sits in its wall
		"trap":
			var all: Array[Node3D] = []
			var pieces: Array[Node3D] = []
			for n: Variant in view.trap_marks.get(id, []):
				if is_instance_valid(n):
					all.append(n as Node3D)
					if (n as Node3D).name != &"TrapBorder":
						pieces.append(n as Node3D)
			for n in (pieces if not pieces.is_empty() else all):
				out.append_array(FoundOutline.apply(n))
	return out


## How strongly each lit thing glows now: rising as it's found, pulsing for PULSE seconds, then steady; fading once
## used, and gone after FADE.
func _animate() -> void:
	for key: String in lit.keys():
		var entry := lit[key] as Dictionary
		var t := _clock - float(entry["at"])
		var k := minf(t / RISE, 1.0)
		if t < PULSE:
			k += 0.9 * pow(sin(PI * t / PULSE_EVERY), 2.0) * (1.0 - t / PULSE)
		if float(entry["ending"]) >= 0.0:
			k *= 1.0 - (_clock - float(entry["ending"])) / FADE
			if k <= 0.0:
				FoundOutline.remove(entry["lit"] as Array[Dictionary])
				lit.erase(key)
				continue
		if k != float(entry.get("k", -1.0)):   # steady: nothing to set each frame
			entry["k"] = k
			FoundOutline.glow(entry["lit"] as Array[Dictionary], k)
