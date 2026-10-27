extends TestCase
## Owner report (2026-10-13): "The lantern girl at the Lake (drowned one) doesn't have a sprite." Her NPC entry and her
## stat block both named the will-o'-wisp's art, so the girl of light on the end of the fishers' jetty was the wisp's
## skull orb, the same figure as the drowned lights round her. Everyone a place puts on its map has art of their own to
## look up, and she is a girl, with sheets of her own since 2026-10-14.


## Every person a location places has a walk and attack sheet under the sprite id the map draws them with, and a portrait
## for the dialogue (a missing file or a mistyped id would leave a capsule on the board and an empty frame).
func test_everyone_a_place_puts_on_the_map_has_a_sprite_and_a_portrait() -> void:
	var c := Compendium.shared()
	var checked := 0
	var gaps: Array[String] = []
	for lid: String in c.table("locations"):
		for n: Variant in c.get_entry("locations", lid).get("npcs", []):
			var id := str((n as Dictionary).get("npc", ""))
			var npc := c.get_entry("npcs", id)
			if npc.is_empty():
				gaps.append("%s: %s has no NPC entry" % [lid, id])
				continue
			checked += 1
			var sprite := str(npc.get("sprite", id))
			var portrait := str(npc.get("portrait", id))
			if not DirectionalSprite.has_attack(DirectionalSprite.frames_for(sprite)):
				gaps.append("%s: %s has no walk and attack sheet (sprite %s)" % [lid, id, sprite])
			if not ArtPaths.exists("art/portraits/%s.png" % portrait):
				gaps.append("%s: %s has no portrait (%s)" % [lid, id, portrait])
	assert_true(checked >= 100, "the places' people are checked (%d)" % checked)
	assert_eq(gaps, [] as Array[String], "people without art")


## The Lantern Girl is not drawn as a will-o'-wisp, nor on another character's sheets (for a while she wore Rose's): her
## own sprite and portrait ids, her own drawn sheets, at a child's height, lit from within.
func test_the_lantern_girl_is_a_girl_of_light_not_a_wisp() -> void:
	var c := Compendium.shared()
	var npc := c.get_entry("npcs", "lantern_girl")
	assert_eq(str(npc.get("sprite", "")), "lantern_girl", "she walks as herself")
	assert_eq(str(npc.get("portrait", "")), "lantern_girl", "and speaks as herself")
	var girl := Monster.from_data(c.monster_data("lantern_girl"))
	var wisp := Monster.from_data(c.monster_data("will_o_wisp"))
	assert_eq(CombatToken.art_for(girl), "lantern_girl", "her stat block is drawn as her")
	assert_ne(CombatToken.art_for(girl), CombatToken.art_for(wisp), "not as the drowned lights round her")
	assert_true(ArtPaths.exists("art/portraits/lantern_girl.png"), "the HUD has her face")
	assert_true(ArtPaths.exists("art/sprites/lantern_girl/walk.png"), "a walk sheet of her own")
	assert_true(ArtPaths.exists("art/sprites/lantern_girl/attack.png"), "and an attack sheet")
	var frames := DirectionalSprite.frames_for("lantern_girl")
	assert_true(DirectionalSprite.has_attack(frames), "a walk and an attack")
	var sheet := (frames.get_frame_texture(&"idle_s", 0) as AtlasTexture).atlas.resource_path
	assert_true(sheet.contains("lantern_girl"), "drawn on her own images, not another's (%s)" % sheet)
	var cb := Combatant.new(girl, &"neutral", Vector2i.ZERO)
	assert_between(CombatToken.height_of(cb), 0.8, 1.0, "the size of a child")
	var tok := CombatToken.create(cb, "lantern_girl")
	add_child(tok)
	var mat := tok.sprite.material_override as ShaderMaterial
	assert_true(float(mat.get_shader_parameter("glow")) > 0.0, "made of light, so lit from within")
	tok.queue_free()


## A figure's own light belongs to the art that asks for it (CombatToken.OWN_LIGHT): Rose, who the Lantern Girl once
## borrowed, stands as the scene lights her.
func test_own_light_stays_with_the_art_that_asks_for_it() -> void:
	assert_false(CombatToken.OWN_LIGHT.has("rose"), "Rose is not a light")
	var rose := Monster.from_data(Compendium.shared().monster_data("commoner"))
	var tok := CombatToken.create(Combatant.new(rose, &"neutral", Vector2i.ZERO), "rose")
	add_child(tok)
	var glow: Variant = (tok.sprite.material_override as ShaderMaterial).get_shader_parameter("glow")
	assert_true(glow == null or float(glow) == 0.0, "no glow of her own")
	tok.queue_free()
