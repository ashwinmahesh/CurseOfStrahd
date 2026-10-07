extends TestCase
## Picking which of the 8 rendered directions to show, relative to the camera.


func test_directions_relative_to_an_unrotated_camera() -> void:
	var cam := Basis() # looks down -Z, screen-right is +X
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, 1), cam), "s", "facing the camera")
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, -1), cam), "n", "facing away")
	assert_eq(DirectionalSprite.direction_for(Vector3(1, 0, 0), cam), "e", "facing screen-right")
	assert_eq(DirectionalSprite.direction_for(Vector3(-1, 0, 0), cam), "w")
	assert_eq(DirectionalSprite.direction_for(Vector3(1, 0, 1).normalized(), cam), "se")
	assert_eq(DirectionalSprite.direction_for(Vector3(-1, 0, -1).normalized(), cam), "nw")


func test_directions_follow_camera_rotation() -> void:
	# Camera turned 90 degrees to the right (yaw -90): world +X is now "away from the camera".
	var cam := Basis(Vector3.UP, -PI / 2.0)
	assert_eq(DirectionalSprite.direction_for(Vector3(1, 0, 0), cam), "n")
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, 1), cam), "e")


func test_pitched_camera_still_works() -> void:
	var cam := Basis(Vector3.RIGHT, deg_to_rad(-40.0))
	assert_eq(DirectionalSprite.direction_for(Vector3(0, 0, 1), cam), "s")


func test_villager_sprite_frames_have_every_direction() -> void:
	var frames := load("res://art/sprites/villager/walk.tres") as SpriteFrames
	assert_true(frames != null, "walk.tres loads")
	if frames == null:
		return
	for d in DirectionalSprite.DIRECTIONS:
		assert_eq(frames.get_frame_count(StringName("walk_" + d)), 8, "walk_" + d)
		assert_eq(frames.get_frame_count(StringName("idle_" + d)), 1, "idle_" + d)


## Every character sprite sheet (art/sprites/<id>/walk.tres) and the animations the game plays from it.
func _sprite_ids() -> Array[String]:
	var ids: Array[String] = []
	for d in DirAccess.get_directories_at("res://art/sprites"):
		if d != "villager_standin" and ResourceLoader.exists("res://art/sprites/%s/walk.tres" % d):
			ids.append(d)
	return ids


func test_every_sprite_walks_in_every_direction() -> void:
	var ids := _sprite_ids()
	assert_true(ids.size() >= 40, "found the character sprites")
	for id in ids:
		var frames := DirectionalSprite.frames_for(id)
		for d in DirectionalSprite.DIRECTIONS:
			assert_true(frames.get_frame_count(StringName("walk_" + d)) >= 4, "%s walk_%s has a cycle" % [id, d])
			assert_true(frames.get_animation_loop(StringName("walk_" + d)), "%s walk_%s loops" % [id, d])


func test_every_sprite_attacks_in_every_direction() -> void:
	for id in _sprite_ids():
		assert_true(ResourceLoader.exists("res://art/sprites/%s/attack.tres" % id), id + " has an attack sheet")
		var frames := DirectionalSprite.frames_for(id)
		assert_true(DirectionalSprite.has_attack(frames), id + " attack merged into its frames")
		if not DirectionalSprite.has_attack(frames):
			continue
		var hit := int(frames.get_meta("hit_frame", -1))
		for d in DirectionalSprite.DIRECTIONS:
			var anim := StringName("attack_" + d)
			var n := frames.get_frame_count(anim)
			assert_true(n >= 4, "%s %s has frames" % [id, anim])
			assert_false(frames.get_animation_loop(anim), "%s %s plays once" % [id, anim])
			assert_between(hit, 1, n - 2, "%s hit frame inside the swing" % id)
			# Attack cells grow evenly round the walk cell's centre at its scale (render_attack.py), so the figure
			# keeps its size and ground line: at least as big, and bigger by an even number of pixels.
			var grow := frames.get_frame_texture(anim, 0).get_height() - frames.get_frame_texture(&"idle_s", 0).get_height()
			assert_true(grow >= 0 and grow % 2 == 0, "%s %s cell grows evenly (%d)" % [id, anim, grow])
		assert_eq(DirectionalSprite.cell_size(frames), frames.get_frame_texture(&"idle_s", 0).get_height(),
			id + " sized by its walk cell")


func test_attack_plays_once_and_strikes_on_the_hit_frame() -> void:
	var frames := DirectionalSprite.frames_for("ilse_varga")
	var s := DirectionalSprite.create(frames, 1.3)
	var hits: Array[int] = [0, 0]
	s.struck.connect(func() -> void: hits[0] += 1)
	s.attack_finished.connect(func() -> void: hits[1] += 1)
	assert_true(s.attack(), "starts")
	assert_true(s.is_attacking(), "attacking")
	assert_eq(str(s.animation), "attack_s", "no camera: faces the viewer")
	assert_false(s.has_struck(), "not yet")
	s.frame = int(frames.get_meta("hit_frame"))
	assert_true(s.has_struck(), "the blow lands on the hit frame")
	assert_eq(hits[0], 1, "struck once")
	s.animation_finished.emit()
	assert_false(s.is_attacking(), "done")
	assert_eq(hits, [1, 1] as Array[int], "finished once, no second strike")
	s.free()


func test_attack_without_an_attack_sheet_does_nothing() -> void:
	var frames := load("res://art/sprites/villager_standin/walk.tres") as SpriteFrames
	var s := DirectionalSprite.create(frames, 1.2)
	assert_false(s.attack(), "nothing to play")
	assert_false(s.is_attacking())
	assert_true(s.has_struck(), "callers waiting on the blow don't wait")
	s.free()


func test_walk_cycle_paced_to_the_step_time() -> void:
	var s := DirectionalSprite.create(DirectionalSprite.frames_for("ilse_varga"), 1.3)
	s.set_step_time(0.18)
	var fast := s.walk_speed
	s.set_step_time(0.32)
	assert_true(s.walk_speed < fast, "sneaking walks slower")
	assert_between(fast, 0.5, 2.5)
	s.free()


## Every creature that can turn up in a fight has a sprite with a walk and an attack: each stat block in data/monsters,
## every creature the combat code makes on the spot (summons, familiars, severed limbs), each under the art id the
## combat token looks up (CombatToken.ART_ALIASES). A block that is also a person in data/npcs (Rahadin) wears that
## person's sprite, which the people's art pass draws and tools/art/check_npc_art.py tracks, so it isn't counted here.
func test_every_fighting_creature_has_a_sprite() -> void:
	var people := {}
	for f in DirAccess.get_files_at("res://data/npcs"):
		if f.ends_with(".json"):
			var n: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/" + f))
			if n is Dictionary:
				people[str((n as Dictionary).get("sprite", (n as Dictionary).get("id", "")))] = true
	var ids: Array[String] = []
	for f in DirAccess.get_files_at("res://data/monsters"):
		if f.ends_with(".json"):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/" + f))
			if d is Dictionary:
				var id := str((d as Dictionary).get("art", (d as Dictionary).get("id", "")))
				if not people.has(id):
					ids.append(id)
	ids.append_array(["severed_arm", "severed_head", "illusion", "bigbys_hand", "animated_object", "giant_insect",
		"aberrant_spirit", "bestial_spirit", "celestial_spirit", "construct_spirit", "draconic_spirit", "elemental_spirit",
		"fey_spirit", "fiendish_spirit", "undead_spirit", "otherworldly_steed", "primal_beast", "imp_familiar",
		"pseudodragon_familiar", "quasit_familiar", "slaad_tadpole_familiar", "sphinx_familiar", "sprite_familiar",
		"venomous_snake_familiar", "owl_familiar", "skeleton_familiar"])
	var missing: Array[String] = []
	for id in ids:
		var aid := str(CombatToken.ART_ALIASES.get(id, id))
		if not DirectionalSprite.has_attack(DirectionalSprite.frames_for(aid)):
			missing.append(id)
	assert_eq(missing, [] as Array[String], "creatures without a walk and attack sheet")


## Animation set v2 (render_keys.py): the hero's merged frames have every pose, and the poses and one-shots play.
func test_full_animation_set_poses_and_one_shots() -> void:
	var frames := DirectionalSprite.frames_for("godrick_pendlebrook")
	for base: String in ["walk", "idle", "attack", "hurt", "die", "down", "ride_idle", "ride_attack", "sneak_idle", "sneak_walk",
			"cast"]:
		for d in DirectionalSprite.DIRECTIONS:
			assert_true(frames.get_frame_count(StringName(base + "_" + d)) >= 1, "godrick %s_%s" % [base, d])
	assert_true(frames.get_frame_count(&"idle_s") >= 2, "idle breathes")
	assert_false(frames.get_animation_loop(&"die_s"), "the fall plays once")
	assert_true(frames.get_animation_loop(&"down_s"), "lying holds")
	var s := DirectionalSprite.create(frames, 1.5)
	assert_eq(s._loop_for(), "idle")
	s.moving = true
	assert_eq(s._loop_for(), "walk")
	s.pose = "sneak"
	assert_eq(s._loop_for(), "sneak_walk", "sneaking while moving")
	s.moving = false
	assert_eq(s._loop_for(), "sneak_idle")
	s.pose = "ride"
	assert_eq(s._loop_for(), "ride_idle")
	assert_true(s.attack(), "attacks from the saddle")
	assert_eq(str(s.animation), "ride_attack_s")
	s.animation_finished.emit()
	s.pose = ""
	assert_true(s.hurt(), "flinches")
	assert_true(s.has_struck(), "a flinch lands no blow")
	s.animation_finished.emit()
	assert_true(s.cast(), "casts")
	assert_eq(str(s.animation), "cast_s")
	s.frame = int((frames.get_meta("hit_frames") as Dictionary)["cast"])
	assert_true(s.has_struck(), "the spell lands on its frame")
	s.animation_finished.emit()
	assert_true(s.die(), "falls")
	assert_eq(s.pose, "down")
	assert_false(s.hurt(), "no flinch while falling or lying")
	s.animation_finished.emit()
	assert_eq(s._loop_for(), "down", "lies there")
	s.free()


func test_sprites_without_the_full_set_keep_the_old_behaviour() -> void:
	var s := DirectionalSprite.create(DirectionalSprite.frames_for("wolf"), 0.8)
	assert_false(s.hurt(), "no flinch")
	assert_false(s.die(), "no drawn fall")
	assert_false(s.cast(), "no spell gesture")
	s.pose = "sneak"
	assert_eq(s._loop_for(), "idle", "a pose the sheet lacks falls back to standing")
	s.free()


## The crisp sprite shader billboards the walking figures round the Y axis, but a sprite laid flat (CombatToken's
## lying view, for sheets without a drawn "down" pose) keeps its own rotation, so a downed figure lies on the ground.
func test_the_crisp_shader_billboards_only_billboarded_sprites() -> void:
	var frames := DirectionalSprite.frames_for("thistle")
	var s := DirectionalSprite.create(frames, 1.3)
	assert_true(bool((s.material_override as ShaderMaterial).get_shader_parameter("billboard")), "standing figures turn to the camera")
	var lying := Sprite3D.new()
	lying.texture = frames.get_frame_texture(&"idle_s", 0)
	DirectionalSprite.setup_material(lying)
	assert_false(bool((lying.material_override as ShaderMaterial).get_shader_parameter("billboard")), "the lying view stays flat")
	s.free()
	lying.free()
