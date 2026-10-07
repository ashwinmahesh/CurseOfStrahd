extends TestCase
## The hotbar for creatures the player runs that aren't a character sheet (combat/action_catalog.gd
## _feature_entries): a druid in Wild Shape can leave it from the hotbar, and a summoned steed shows its own actions
## (Healing Touch). Before, the catalog skipped feature actions for anything but a Character, so neither showed.


func _ids(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for a in ActionCatalog.new(e).actions_for(c):
		out.append(str(a["id"]))
	return out


func test_a_druid_in_wild_shape_can_leave_it_from_the_hotbar() -> void:
	var e := TestCombat.open_field(3)
	var d := e.add(TestChars.custom("druid", "human", 2), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, d)
	var form := str(e.class_features.wild_forms(d)[0]["id"])
	assert_true(e.feature_actions.perform(d, "cf:wild_shape:" + form, null, Vector2.INF).ok)
	assert_true(e.shapes.is_shaped(d))
	var ids := _ids(e, d)
	assert_true(ids.any(func(id: String) -> bool: return id.ends_with("revert_shape")), "Leave Wild Shape is on the bar: %s" % [ids])
	var tab := ActionCatalog.new(e).class_tab(d)
	assert_eq(tab, "Abilities", "a beast shape's actions sit on the Abilities tab")


func test_a_summoned_steed_shows_its_healing_touch() -> void:
	var e := TestCombat.open_field(10)
	var c := TestCombat.caster_with(e, ["find_steed"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 9), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "find_steed", 2, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "celestial"}).ok)
	var steed: Combatant = null
	for id: Variant in e.spells.summoned.get(c.id, []):
		steed = e.get_c(str(id))
	assert_true(steed != null, "the steed is here")
	var ids := _ids(e, steed)
	assert_true(ids.any(func(id: String) -> bool: return id.contains("creature:")), "its own actions are on the bar: %s" % [ids])
