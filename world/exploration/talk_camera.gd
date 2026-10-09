class_name TalkCamera
extends RefCounted
## The camera in a conversation (Visual Polish Plan 7, after Octopath Traveler 2's scenes): as a conversation opens
## while exploring, the play camera eases in a step, a little lower, and leans to frame the party's leader and whoever
## they're talking to above the conversation box; when it ends it eases back to the play view. GameRoot.start_dialogue and _dialogue_ended call
## it. It moves only the CameraRig's shot (shot_zoom, shot_pitch, shot_focus, shot_weight, as CombatImpact does in a
## fight), never the rig itself, and never during a fight. Like the rest of the interface's motion it's off in
## headless runs and still captures (UiMotion).

## How close (shot_zoom), how much lower (degrees off the play pitch: flatter, more of the faces), how far the view
## leans toward the pair (shot_weight), and the seconds it takes to come in and to go back.
const ZOOM := 0.8
const PITCH := 5.0
const LEAN := 0.7
## How far the camera also comes forward (world units, toward the player): the conversation box covers the lower part
## of the screen, so the pair is framed above it rather than behind it.
const RAISE := 1.6
const IN := 0.8
const OUT := 0.7
## The tween on a rig, kept so the way back cuts the way in short, and the mark that it moved the shot.
const TWEEN := &"talk_camera"
const OPEN := &"talk_camera_open"

## Tests ask for it in headless runs.
static var headless_too := false


static func on() -> bool:
	return UiMotion.on() or headless_too


## The conversation with `npc_id` opened in `view`: the camera eases in toward the leader and the speaker (the leader
## alone when the speaker isn't on the map).
static func open(view: LocationView, npc_id: String) -> void:
	if not on() or view == null or view.rig == null or view.in_combat or not view.is_inside_tree():
		return
	var rig := view.rig
	var focus := rig.global_position
	var tok: Variant = view.npc_tokens.get(npc_id)
	if is_instance_valid(tok) and (tok as Node3D).is_inside_tree():
		focus = (focus + (tok as Node3D).global_position) / 2.0
	# The rig leans toward shot_focus by shot_weight: a point toward the player, so the pair sits above the box.
	focus += rig.global_basis * Vector3(0.0, 0.0, RAISE / LEAN)
	var tw := _tween(rig)
	rig.set_meta(OPEN, true)
	if rig.shot_weight < 0.01:
		rig.shot_focus = focus
	else:
		tw.tween_property(rig, "shot_focus", focus, IN)
	tw.tween_property(rig, "shot_zoom", ZOOM, IN)
	tw.tween_property(rig, "shot_pitch", PITCH, IN)
	tw.tween_property(rig, "shot_weight", LEAN, IN)


## The conversation ended: the camera eases back to the play view, or is back at once (`at_once`) when a fight
## starts from it, so the fight's own camera has the shot to itself.
static func close(view: LocationView, at_once: bool = false) -> void:
	if view == null or view.rig == null or not view.is_inside_tree():
		return
	var rig := view.rig
	if not rig.has_meta(OPEN):
		return   # it never moved for this conversation (a fight's, say): the shot isn't its to put back
	rig.remove_meta(OPEN)
	var tw := _tween(rig)
	if at_once or view.in_combat:
		tw.kill()
		rig.shot_zoom = 1.0
		rig.shot_pitch = 0.0
		rig.shot_weight = 0.0
		return
	tw.tween_property(rig, "shot_zoom", 1.0, OUT)
	tw.tween_property(rig, "shot_pitch", 0.0, OUT)
	tw.tween_property(rig, "shot_weight", 0.0, OUT)


## A new tween for the rig's shot, replacing the one still running; it runs while the game is paused (a conversation
## may pause it) and eases in and out.
static func _tween(rig: CameraRig) -> Tween:
	var old: Variant = rig.get_meta(TWEEN) if rig.has_meta(TWEEN) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := UiMotion.tween_for(rig).set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	rig.set_meta(TWEEN, tw)
	return tw
