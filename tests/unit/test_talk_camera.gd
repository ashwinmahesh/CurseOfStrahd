extends TestCase
## The camera in a conversation (Visual Polish Plan 7, TalkCamera): it eases in toward the leader and the speaker and
## back out when the talk ends, snaps back when a fight starts from it, and leaves a fight's own shot alone.


func before_each() -> void:
	TalkCamera.headless_too = true
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	TalkCamera.headless_too = false


func _view() -> LocationView:
	var v := LocationView.create("village_of_barovia", GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


## Runs the rig's shot tween to its end.
func _settle(rig: CameraRig) -> void:
	var tw := rig.get_meta(TalkCamera.TWEEN) as Tween
	if tw != null and tw.is_valid():
		tw.custom_step(5.0)


func test_in_toward_the_speaker_and_back_out() -> void:
	var v := _view()
	var npc_id := ""
	for id: String in v.npc_tokens:
		npc_id = id
		break
	assert_true(npc_id != "", "the village has someone to talk to")
	var rig := v.rig
	var leader := rig.global_position
	TalkCamera.open(v, npc_id)
	_settle(rig)
	assert_true(is_equal_approx(rig.shot_zoom, TalkCamera.ZOOM), "in a step")
	assert_true(is_equal_approx(rig.shot_pitch, TalkCamera.PITCH), "a little lower")
	assert_true(is_equal_approx(rig.shot_weight, TalkCamera.LEAN), "leaning to frame them")
	var npc := (v.npc_tokens[npc_id] as Node3D).global_position
	var raised := (leader + npc) / 2.0 + rig.global_basis * Vector3(0, 0, TalkCamera.RAISE / TalkCamera.LEAN)
	assert_true(rig.shot_focus.is_equal_approx(raised), "between the leader and the speaker, framed above the box")
	TalkCamera.close(v)
	_settle(rig)
	assert_true(is_equal_approx(rig.shot_zoom, 1.0) and is_zero_approx(rig.shot_weight) and is_zero_approx(rig.shot_pitch),
		"back to the play view")
	v.queue_free()


func test_a_fight_from_the_talk_and_a_fights_own_shot() -> void:
	var v := _view()
	var rig := v.rig
	TalkCamera.open(v, "nobody_here")
	TalkCamera.close(v, true)
	assert_true(is_equal_approx(rig.shot_zoom, 1.0) and is_zero_approx(rig.shot_weight), "back at once for the fight")
	rig.shot_zoom = 0.5   # a fight's moment (CombatImpact) holds the shot
	TalkCamera.close(v)
	assert_true(is_equal_approx(rig.shot_zoom, 0.5), "a shot it didn't move isn't its to put back")
	rig.shot_zoom = 1.0
	TalkCamera.headless_too = false
	TalkCamera.open(v, "nobody_here")
	assert_true(is_equal_approx(rig.shot_zoom, 1.0), "never in headless runs")
	v.queue_free()
