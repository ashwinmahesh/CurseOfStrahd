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



## A guest in a fight, with a foe in view; the events the board would play are cleared.
func _guest(e: Encounter, npc_id: String) -> Combatant:
	var c := e.add(StoryState.make_guest(npc_id), &"guest", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(5, 2))
	TestCombat.start_with(e, c)
	e.events.clear()
	return c


func _forms(e: Encounter, c: Combatant) -> Array:
	return e.events.filter(func(ev: Dictionary) -> bool: return str(ev.get("type", "")) == "form" and str(ev.get("id", "")) == c.id)


func test_a_martikov_who_changes_in_a_fight_wears_the_wereraven_hybrid() -> void:
	# Owner ask, 2026-10-12: the wereravens' change should show. They fight in their own clothes until they shift.
	assert_true(DirectionalSprite.frames_for("wereraven") != null, "the hybrid has a figure to swap to")
	assert_true(ResourceLoader.exists("res://art/portraits/wereraven.png"), "and a portrait")
	for id: String in ["adrian_martikov", "davian_martikov", "ilinca_vrana"]:
		var e := TestCombat.open_field()
		var c := _guest(e, id)
		var ids := e.feature_actions.list(c).map(func(x: Dictionary) -> String: return str(x["id"]))
		assert_true("feat:creature:shape_shift" in ids, "%s can Shape-Shift" % id)
		var r := e.feature_actions.perform(c, "creature:shape_shift", null, Vector2.INF)
		assert_true(r.ok, "%s shifts (%s)" % [id, r.reason])
		assert_eq(str(c.get_meta("form", "")), "hybrid")
		assert_false(c.bonus_available, "a Bonus Action")
		var forms := _forms(e, c)
		assert_eq(forms.size(), 1, "%s's token changes" % id)
		if forms.size() == 1:
			assert_eq(str((forms[0] as Dictionary).get("art", "")), "wereraven", "%s becomes the hybrid" % id)
		var beak := (c.creature as Monster).action("beak")
		assert_eq(e.monster_actions.why_not(c, beak), "", "and fights with the beak")
		# And back, on a later turn.
		c.bonus_available = true
		e.events.clear()
		assert_true(e.feature_actions.perform(c, "creature:shape_shift", null, Vector2.INF).ok)
		assert_eq(str(c.get_meta("form", "")), "humanoid", "%s is a man or woman again" % id)
		forms = _forms(e, c)
		assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "x")) == "", "their own figure again")


## Owner ask, 2026-10-14: when Emil turns into a werewolf his sprite does too. His stat block is his own, but it names the
## figure he takes (`hybrid_art`), and he is a man again when he changes back.
func test_emil_becomes_the_werewolf_when_he_changes_and_a_man_again_after() -> void:
	assert_true(DirectionalSprite.frames_for("werewolf") != null, "the werewolf has a figure to swap to")
	var e := TestCombat.open_field()
	var c := _guest(e, "emil_toranescu")
	assert_true(e.feature_actions.perform(c, "creature:shape_shift", null, Vector2.INF).ok)
	assert_eq(str(c.get_meta("form", "")), "hybrid", "he changes")
	var forms := _forms(e, c)
	assert_eq(forms.size(), 1, "his token changes")
	if forms.size() == 1:
		assert_eq(str((forms[0] as Dictionary).get("art", "")), "werewolf", "into the werewolf")
		assert_eq(str((forms[0] as Dictionary).get("kind", "")), "werewolf", "which shows as a werewolf's change")
	c.bonus_available = true
	e.events.clear()
	assert_true(e.feature_actions.perform(c, "creature:shape_shift", null, Vector2.INF).ok)
	assert_eq(str(c.get_meta("form", "")), "humanoid", "a man again")
	forms = _forms(e, c)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "x")) == "", "his own figure again")


func test_kiril_takes_the_werewolf_figure_too_as_a_foe() -> void:
	var e := TestCombat.open_field()
	var k := TestCombat.foe(e, "kiril_stoyanovich", Vector2i(3, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.start_with(e, k)
	k.bonus_available = true
	e.events.clear()
	e.monster_actions.bonus_action(k, "shift")
	assert_eq(str(k.get_meta("form", "")), "hybrid")
	var forms := _forms(e, k)
	assert_eq(forms.size(), 1, "his token changes")
	if forms.size() == 1:
		assert_eq(str((forms[0] as Dictionary).get("art", "")), "werewolf")


func test_something_that_forces_a_lycanthrope_back_shows_it_too() -> void:
	# Moonbeam: a creature in another form reverts to its true one, and its figure with it.
	var e := TestCombat.open_field(3)
	var caster := TestCombat.caster_with(e, ["moonbeam"], Vector2i(2, 3), 5)
	var emil := TestCombat.foe(e, "emil_toranescu", Vector2i(7, 3))
	TestCombat.start_with(e, emil)
	emil.bonus_available = true
	e.monster_actions.bonus_action(emil, "shift")
	assert_eq(str(emil.get_meta("form", "")), "hybrid")
	e.end_turn()
	e.events.clear()
	TestCombat.next_d20(e, 1)
	caster.action_available = true
	assert_true(e.spells.cast(caster, "moonbeam", 2, [], Vector2(7.5, 3.5)).ok)
	assert_eq(str(emil.get_meta("form", "")), "humanoid", "forced back")
	var forms := _forms(e, emil)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "x")) == "", "and drawn as a man again")


func test_an_enemy_lycanthrope_still_changes_on_its_own() -> void:
	var e := TestCombat.open_field()
	var w := TestCombat.foe(e, "werewolf", Vector2i(3, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.start_with(e, w)
	w.bonus_available = true
	e.events.clear()
	e.monster_actions.bonus_action(w, "shift")
	assert_eq(str(w.get_meta("form", "")), "hybrid")
	assert_true(_forms(e, w).is_empty(), "it already looks the part")
