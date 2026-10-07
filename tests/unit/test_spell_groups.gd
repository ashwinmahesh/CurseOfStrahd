extends TestCase
## Every spell list's order (SpellGroups, owner 2026-10-07): by spell level, cantrips first, alphabetical within.


func test_spells_group_by_level_then_name() -> void:
	var ids: Array = ["guiding_bolt", "fire_bolt", "aid", "bless", "light", "cure_wounds"]
	var groups := SpellGroups.groups(ids)
	var levels: Array[int] = []
	for g in groups:
		levels.append(int(g["level"]))
	assert_eq(levels, [0, 1, 2] as Array[int], "cantrips, then level 1, then level 2")
	assert_eq(str(groups[0]["heading"]), "Cantrips")
	assert_eq(str(groups[1]["heading"]), "Level 1")
	assert_eq(groups[0]["items"], ["fire_bolt", "light"])
	assert_eq(groups[1]["items"], ["bless", "cure_wounds", "guiding_bolt"])
	assert_eq(SpellGroups.sorted(ids), ["fire_bolt", "light", "bless", "cure_wounds", "guiding_bolt", "aid"])
