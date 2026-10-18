extends FightSeriesCase
## The Wizard of Wines' fights for a party that comes early or late (the owner's target over seeds 1-8: the sharp test
## party wins about 5 times in 8 on Balanced, one either way; the Vine Mother and the Ash Effigy, bosses, are played by
## the party at full ability and won about 3 times in 8, 2026-10-14): the four story fights at
## levels 5 and 7, the Vine Mother at 5, 7 and 8 with Adrian along and without, and the Ash Effigy at level 8 with a
## druid beside it. Level 6 is held by test_story_fights.gd, test_side_quest_bosses.gd and test_yester_summit.gd.

const VINE_LANE: Array[Vector2i] = [Vector2i(22, 25), Vector2i(23, 25), Vector2i(22, 26), Vector2i(23, 26)]
const HALL_DOOR: Array[Vector2i] = [Vector2i(10, 9), Vector2i(9, 9), Vector2i(9, 10), Vector2i(10, 10)]
const DIG_DOOR: Array[Vector2i] = [Vector2i(17, 6), Vector2i(16, 6), Vector2i(15, 6), Vector2i(14, 6)]
const SEVENTH_ROW: Array[Vector2i] = [Vector2i(29, 24), Vector2i(28, 24), Vector2i(27, 24), Vector2i(26, 24)]
const YESTER_CROWN: Array[Vector2i] = [Vector2i(15, 18), Vector2i(16, 18), Vector2i(17, 18), Vector2i(18, 18)]


func _held(location: String, hour: int, level: int, encounter: String, flags: Array[String], at: Array[Vector2i],
		guests: Array[String] = [], low: int = 4, high: int = 6) -> void:
	speakers_step_aside = true   # Kostin at the press, Zorica or Ruxandra at the effigy
	var wins := await _series(location, hour, level, encounter, [1, 2, 3, 4, 5, 6, 7, 8], flags, guests, [], at)
	assert_true(wins >= low, "%s can be won at level %d %s (%d/8)" % [encounter, level, guests, wins])
	assert_true(wins <= high, "%s stays hard at level %d %s (%d/8)" % [encounter, level, guests, wins])


func test_the_story_fights_at_level_5() -> void:
	await _held("wizard_of_wines", 12, 5, "vineyard_ambush", [], VINE_LANE)
	await _held("wizard_of_wines_winery", 12, 5, "winery_occupation", [], HALL_DOOR)
	await _held("wizard_of_wines_cellar", 12, 5, "cellar_dig", [], DIG_DOOR)
	await _held("wizard_of_wines_press_house", 12, 5, "press_house_mash", [], [])


func test_the_story_fights_at_level_7() -> void:
	await _held("wizard_of_wines", 12, 7, "vineyard_ambush", [], VINE_LANE)
	await _held("wizard_of_wines_winery", 12, 7, "winery_occupation", [], HALL_DOOR)
	await _held("wizard_of_wines_cellar", 12, 7, "cellar_dig", [], DIG_DOOR)
	await _held("wizard_of_wines_press_house", 12, 7, "press_house_mash", [], [])


## Each level's bands without Adrian and with him. Since foes' cones aim freely (owner, 2026-10-18: accept the new
## results, no retune) the party wins 8 in 8 with Adrian at level 5, 1 without him at level 7 and 1 with him at level 8.
const VINE_MOTHER_BANDS := {5: [[2, 4], [7, 8]], 7: [[0, 2], [2, 5]], 8: [[2, 4], [0, 2]]}


func test_the_vine_mother_at_levels_5_7_and_8() -> void:
	for level: int in [5, 7, 8]:
		var bands := VINE_MOTHER_BANDS[level] as Array
		await _held("wizard_of_wines", 1, level, "vine_mother", ["winery_reclaimed"], SEVENTH_ROW, [],
			int((bands[0] as Array)[0]), int((bands[0] as Array)[1]))
		await _held("wizard_of_wines", 1, level, "vine_mother", ["winery_reclaimed"], SEVENTH_ROW, ["adrian_martikov"],
			int((bands[1] as Array)[0]), int((bands[1] as Array)[1]))


## The Ash Effigy with a druid at level 8: The Ash Effigy (480 HP), Druid, 4 Twig Blights; 3 in 8.
func test_the_ash_effigy_with_a_druid_at_level_8() -> void:
	await _held("yester_hill_gulthias_tree", 22, 8, "ash_effigy", ["yester_hill_resolved", "gulthias_tree_burned"], YESTER_CROWN, [], 2, 4)
