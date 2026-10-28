extends TestCase
## A light marked `visual` is only painted (the Amber Temple's great hall: violet fills, pillar glows, the god's frost lamp): it
## gives a fight no light zone, so the fights tuned on the hall's old lamps see what they did (the Patrina series is back at
## 5 in 8), while the lamps that were always there and the hall of echoes' four candles still light it.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func test_visual_lights_give_a_fight_no_light() -> void:
	var v := LocationView.create("amber_temple_faceless_god", GameState.story, null, Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	var lights := v.loc["lights"] as Array
	var visual := 0
	for l: Variant in lights:
		if bool((l as Dictionary).get("visual", false)):
			visual += 1
	assert_eq(visual, 18, "the great hall's added glows are painted only")
	var e := Encounter.new(LocationFights._combat_grid(v), Dice.roller)
	LocationFights._light_the_fight(v, e)
	var zones := 0
	for o in e.spells.zones.objects:
		if (o as FieldObject).rules.has("light") and str((o as FieldObject).rules.get("light_on", "")) != "caster":
			zones += 1
	assert_eq(zones, lights.size() - visual, "the fight is lit by the rest (the old lamps and the hall of echoes' candles)")
	assert_true(zones >= 5, "and by at least the five lamps the hall always had (%d)" % zones)
	v.queue_free()
