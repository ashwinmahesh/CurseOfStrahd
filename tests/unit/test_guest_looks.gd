extends TestCase
## Story allies in a fight (owner report, 2026-10-07: Ireena's combat portrait was a nobleman): a guest fights with a
## borrowed stat block (Ireena a noble, Ismark a veteran, the Martikovs wereravens), but wears their own sprite and
## portrait, the ones their NPC data names, on the field and in the combat HUD.


func test_every_guest_wears_their_own_look_in_a_fight() -> void:
	var checked := 0
	for npc: Variant in (Compendium.shared().tables["npcs"] as Dictionary).values():
		var d := npc as Dictionary
		if not bool(d.get("guest", false)) and not d.has("guest_build"):
			continue
		var cr := StoryState.make_guest(str(d["id"]))
		if cr == null:
			continue
		checked += 1
		var look := CombatToken.art_for(cr)
		assert_eq(look, str(d.get("sprite", d["id"])), "%s fights as %s" % [d["id"], look])
		assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % look), "%s has a portrait for the combat HUD" % d["id"])
	assert_true(checked >= 10, "the story's guests are checked (%d)" % checked)


func test_ireena_is_not_the_noble() -> void:
	var cr := StoryState.make_guest("ireena")
	assert_true(cr is Monster and str((cr as Monster).data.get("id", "")) == "noble", "she still fights as a noble")
	assert_eq(CombatToken.art_for(cr), "ireena")
	var c := Combatant.new(cr, &"guest", Vector2i.ZERO)
	assert_eq(CombatToken.art_id(c), "ireena", "the HUD's portrait and the token both read this")
