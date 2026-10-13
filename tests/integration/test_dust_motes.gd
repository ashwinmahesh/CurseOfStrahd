extends TestCase
## Dust in the air indoors (Visual Polish Plan 9): in the Modern finish every room has motes that show only where a
## lamp or a window's shaft lights them (shaders/atmosphere/dust_mote.gdshader), more of them since most are dark; the
## Classic finish is frozen as it was, so its rooms get no new dust and the castle keeps its old motes.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _dust(loc_id: String) -> GPUParticles3D:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	var d := v.atmosphere.get_node_or_null("Dust") as GPUParticles3D
	v.queue_free()
	return d


func _shader(d: GPUParticles3D) -> Shader:
	return ((d.draw_pass_1 as QuadMesh).material as ShaderMaterial).shader


func test_every_room_has_dust_that_shows_only_in_the_light() -> void:
	Look.set_style("modern", false)
	var d := _dust("death_house_ground")
	assert_true(d != null, "Death House has dust in the air")
	if d == null:
		return
	assert_eq(_shader(d), AtmosphereWeather.DUST_SHADER, "lit only by lamps and shafts")
	assert_eq(d.amount, 160, "twice Death House's own 80 motes, since most are dark")
	var quad := d.draw_pass_1 as QuadMesh
	assert_true(quad.size.x <= 0.02, "specks, not dots (%.3f units across)" % quad.size.x)
	assert_true(_dust("village_of_barovia") == null, "none out of doors")


func test_classic_is_frozen() -> void:
	Look.set_style("classic", false)
	assert_true(_dust("death_house_ground") == null, "no new dust in Classic's rooms")
	var castle := _dust("castle_ravenloft_main_floor")
	assert_true(castle != null, "the castle's halls keep their dust")
	if castle != null:
		assert_eq(_shader(castle), AtmosphereWeather.MOTE_SHADER, "as it always was")
