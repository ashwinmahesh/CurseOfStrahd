class_name CombatImpact
extends Node
## Combat impact (G2, lane 21): the moments a blow or a spell should land with weight. A heavy hit freezes the fight
## for a beat and jolts the camera; a critical hit or a killing blow pushes the camera in on whoever took it; the blow
## that fells the last foe plays in slow motion; a spell of 3rd level or higher turns the camera to where it lands.
## CombatView calls these as it plays the encounter's events. The shot lives on the CameraRig (shot_zoom, shot_pitch,
## shot_focus, shot_weight, shake) and the slow motion on Engine.time_scale; both go back to how they were when a
## moment ends or the view closes. Nothing here touches the rules. Fast combat (Settings) halves every moment.

## Captures turn the moments off for their "before" shots. Headless runs (the tests, which time their fights and set
## their own time scale) never get them unless a test asks with `headless_too`.
static var enabled := true
static var headless_too := false

## A heavy hit (CombatSfx.heavy, the same blows that sound heavy): the fight holds at FREEZE_SCALE for FREEZE real
## seconds, and the camera jolts.
const FREEZE := 0.09
const FREEZE_SCALE := 0.03
const HEAVY_SHAKE := 0.55
## The push-in on a critical hit and on a killing blow: how close (shot_zoom), how far the view leans to the creature
## hit (shot_weight), and the seconds it takes to go in, to hold and to come back (in game time).
const CRIT := {"zoom": 0.82, "lean": 0.45, "in": 0.12, "hold": 0.3, "out": 0.5, "shake": 0.7}
const KILL := {"zoom": 0.76, "lean": 0.55, "in": 0.14, "hold": 0.45, "out": 0.6, "shake": 0.45}
## The last foe falling: time runs at SLOW_SCALE for SLOW real seconds and eases back over SLOW_EASE, while the camera
## pushes in close on it, a little lower.
const SLOW := 1.1
const SLOW_SCALE := 0.3
const SLOW_EASE := 0.5
const LAST := {"zoom": 0.62, "lean": 0.7, "pitch": 6.0, "in": 0.2, "hold": 0.55, "out": 0.7}
## A big spell: its lowest level, and how the camera turns to where it lands (lean toward the target, pulling back a
## little for a far one, up to SPELL_ZOOM_MOST).
const BIG_SPELL_LEVEL := 3
const SPELL_LEAN := 0.7
const SPELL_TURN := 0.35
const SPELL_BACK := 0.55
const SPELL_ZOOM_MOST := 1.2

var rig: CameraRig
## Engine.time_scale before the first slow or frozen moment (-1 while none is running).
var _base := -1.0
var _time_tw: Tween
var _shot_tw: Tween
## A big spell's turn is held until the spell has landed (spell_landed).
var _turned := false


func _init(rig_: CameraRig = null) -> void:
	name = "CombatImpact"
	rig = rig_


## Whether the moments play now.
static func on() -> bool:
	return enabled and (headless_too or DisplayServer.get_name() != "headless")


## A blow landed on `target` (an attack's hit, or the spell or effect that just hit it): `amount` damage of its
## `max_hp`, a critical hit or not, whether it fells it, and whether it fells the fight's last foe.
func hit(target: Node3D, amount: int, max_hp: int, critical: bool, fells: bool, last: bool) -> void:
	if not on() or rig == null or target == null:
		return
	if last:
		_slow_motion()
		_push(target.global_position, LAST)
		return
	if critical or fells:
		_push(target.global_position, KILL if fells else CRIT)
	var heavy := CombatSfx.heavy(amount, max_hp)
	if heavy:
		_freeze()
	if heavy or critical:
		var jolt := HEAVY_SHAKE
		if critical:
			jolt = float(CRIT["shake"])
		elif fells:
			jolt = float(KILL["shake"])
		rig.shake = maxf(rig.shake, jolt)


## A spell is about to be cast at `at` (where it lands) by a caster standing at `from`: a big one turns the camera
## there. spell_landed() turns it back.
func spell_cast(spell_id: String, from: Vector3, at: Vector3) -> void:
	if not on() or rig == null or not big_spell(spell_id):
		return
	_turned = true
	var far := Vector2(at.x - from.x, at.z - from.z).length()
	var tw := _shot()
	_aim(tw, at, SPELL_TURN)
	tw.tween_property(rig, "shot_weight", SPELL_LEAN, SPELL_TURN)
	tw.tween_property(rig, "shot_zoom", clampf(1.0 + (far - 6.0) * 0.03, 1.0, SPELL_ZOOM_MOST), SPELL_TURN)


## The spell has landed: the camera goes back to whoever acts.
func spell_landed() -> void:
	if not _turned:
		return
	_turned = false
	_rest(SPELL_BACK)


## Whether `spell_id` is big enough to turn the camera: a spell of BIG_SPELL_LEVEL or higher.
static func big_spell(spell_id: String) -> bool:
	return int(Compendium.shared().spell_data(spell_id).get("level", 0)) >= BIG_SPELL_LEVEL


# --- Reading the events -------------------------------------------------------------------------------------------

## Where the blow at `at` in `events` stops counting: the next event that starts a new blow, move or turn.
static func window_end(events: Array, at: int) -> int:
	for i in range(at + 1, events.size()):
		if str((events[i] as Dictionary)["type"]) in ["attack", "spell", "ability", "move", "turn", "legendary", "lair"]:
			return i
	return events.size()


## Whether `id` falls (dies or drops) after the event at `at`, before the next blow.
static func fells(events: Array, at: int, id: String) -> bool:
	for i in range(at + 1, window_end(events, at)):
		var ev := events[i] as Dictionary
		if str(ev["type"]) in ["death", "down"] and str(ev["id"]) == id:
			return true
	return false


## The event in `events` where the fight's last foe falls (its death or drop), or -1: only when the fight ended in
## victory with these events and no foe slipped away after it (Strahd's mist leaves rather than falls).
static func last_fall(e: Encounter, events: Array) -> int:
	if e.state != Encounter.State.OVER or e.outcome != "victory":
		return -1
	var at := -1
	for i in events.size():
		var ev := events[i] as Dictionary
		var kind := str(ev["type"])
		if kind in ["death", "down"]:
			var c := e.get_c(str(ev["id"]))
			if c != null and c.side == &"enemy":
				at = i
		elif kind == "vanish" and at >= 0:
			at = -1
	return at


# --- Time and the shot --------------------------------------------------------------------------------------------

func _freeze() -> void:
	if _time_tw != null and _time_tw.is_valid() and Engine.time_scale < _base:
		return   # already slowed (the last foe's fall): the freeze would cut it short
	var tw := _time()
	Engine.time_scale = _base * FREEZE_SCALE
	tw.tween_interval(FREEZE * GameSettings.combat_pace())
	tw.tween_callback(_time_back)


func _slow_motion() -> void:
	var tw := _time()
	Engine.time_scale = _base * SLOW_SCALE
	tw.tween_interval(SLOW * GameSettings.combat_pace())
	tw.tween_method(func(k: float) -> void: Engine.time_scale = lerpf(_base * SLOW_SCALE, _base, k), 0.0, 1.0,
		SLOW_EASE * GameSettings.combat_pace()).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_time_back)


## A new tween for the time scale, in real time, replacing one still running; notes the scale to come back to.
func _time() -> Tween:
	if _time_tw != null and _time_tw.is_valid():
		_time_tw.kill()
	if _base < 0.0:
		_base = Engine.time_scale
	_time_tw = create_tween()
	_time_tw.set_ignore_time_scale(true)
	return _time_tw


func _time_back() -> void:
	if _base >= 0.0:
		Engine.time_scale = _base
	_base = -1.0


## Pushes the camera in on `at`: in, hold, back out (`p` is CRIT, KILL or LAST).
func _push(at: Vector3, p: Dictionary) -> void:
	_turned = false
	var pace := GameSettings.combat_pace()
	var into := float(p["in"]) * pace
	var tw := _shot()
	_aim(tw, at, into)
	tw.tween_property(rig, "shot_zoom", float(p["zoom"]), into).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(rig, "shot_weight", float(p["lean"]), into).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(rig, "shot_pitch", float(p.get("pitch", 0.0)), into)
	tw.chain().tween_interval(float(p["hold"]) * pace)
	_back(tw.chain(), float(p["out"]) * pace)


## Eases the shot back to the play view over `seconds`.
func _rest(seconds: float) -> void:
	_back(_shot(), seconds)


func _back(tw: Tween, seconds: float) -> void:
	tw.tween_property(rig, "shot_zoom", 1.0, seconds)
	tw.tween_property(rig, "shot_weight", 0.0, seconds)
	tw.tween_property(rig, "shot_pitch", 0.0, seconds)


## Sets where the shot leans: at once while it isn't leaning anywhere, else gliding there with the rest of the step.
func _aim(tw: Tween, at: Vector3, seconds: float) -> void:
	if rig.shot_weight < 0.01:
		rig.shot_focus = at
	else:
		tw.tween_property(rig, "shot_focus", at, seconds)


## A new tween for the shot (game time, so slow motion slows it too), replacing one still running.
func _shot() -> Tween:
	if _shot_tw != null and _shot_tw.is_valid():
		_shot_tw.kill()
	_shot_tw = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return _shot_tw


## The view closed mid-moment: time and the camera go back at once.
func _exit_tree() -> void:
	_time_back()
	if is_instance_valid(rig):
		rig.shot_zoom = 1.0
		rig.shot_weight = 0.0
		rig.shot_pitch = 0.0
		rig.shake = 0.0
