extends TestCase
## Owner's art todos (2026-10-17): "Cosmin is a young boy squire, but he has a female sprite and avatar" (he wore the old
## woman's commoner sprite and portrait), and "Guardian of Faith should have a sprite when summoned" (it put only a floor
## tint on the board). The Dinosaur and Plant Spirits stood as plain capsules the same way. Each has art of its own now.


## Cosmin is a boy of fourteen, not the shared commoner woman: sprite and portrait of his own, a head under a grown man.
func test_cosmin_is_a_boy_with_his_own_sprite_and_portrait() -> void:
	var npc := Compendium.shared().get_entry("npcs", "argynvostholt_cosmin")
	assert_eq(str(npc.get("sprite", "")), "cosmin", "he walks as himself")
	assert_eq(str(npc.get("portrait", "")), "cosmin", "and speaks as himself")
	assert_true(ResourceLoader.exists("res://art/portraits/cosmin.png"), "a portrait of him")
	var frames := DirectionalSprite.frames_for("cosmin")
	assert_true(DirectionalSprite.has_attack(frames), "a walk and an attack")
	var sheet := (frames.get_frame_texture(&"idle_s", 0) as AtlasTexture).atlas.resource_path
	assert_true(sheet.contains("cosmin"), "drawn on his own images, not the commoner's (%s)" % sheet)
	var boy := CombatToken.height_for("cosmin")
	assert_true(boy > CombatToken.height_for("ilya_krezkov") and boy < CombatToken.height_for("commoner"),
		"taller than Ilya (8), shorter than a grown commoner (%.2f)" % boy)
