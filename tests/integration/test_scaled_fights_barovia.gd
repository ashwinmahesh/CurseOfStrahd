extends FightSeriesCase
## The Village of Barovia and the Old Svalich Road scaled up for 2024 heroes (owner, 2026-10-13: the book's fights were
## written for weaker characters). Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit
## Guardians, throwing Fireball, as he plays), standing where walking in or talking sets each fight off, win five in
## eight on Balanced, give or take one (his target, 2026-10-13 18:05). Whoever starts a fight by talking steps aside, as
## the conversation does in play. The side quests' own fights at levels 2 and 3 are held in test_side_quest_bosses.gd.


## The village: the square at night, the churchyard, the church's undercroft, the burgomaster's parlor.
const VILLAGE_SPAWN: Array[Vector2i] = [Vector2i(20, 12), Vector2i(21, 12), Vector2i(19, 12), Vector2i(20, 13)]
const BY_THE_GRAVE: Array[Vector2i] = [Vector2i(31, 6), Vector2i(32, 6), Vector2i(30, 6), Vector2i(31, 7)]
const UNDERCROFT: Array[Vector2i] = [Vector2i(17, 23), Vector2i(18, 23), Vector2i(16, 23), Vector2i(17, 24)]
const BY_IREENA: Array[Vector2i] = [Vector2i(4, 12), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]
## Ileana's door, where the coachman comes; the well; Grigore's woodpile.
const ILEANAS_DOOR: Array[Vector2i] = [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)]
const AT_THE_WELL: Array[Vector2i] = [Vector2i(22, 14), Vector2i(23, 14), Vector2i(22, 15), Vector2i(24, 14)]
const BY_THE_WOODPILE: Array[Vector2i] = [Vector2i(9, 12), Vector2i(10, 12), Vector2i(8, 12), Vector2i(9, 13)]
## The road: where the procession and the hunters meet the party, the ledge over the falls, the Vistani camp, the
## gallows and the patrol at the crossroads.
const PROCESSION: Array[Vector2i] = [Vector2i(15, 9), Vector2i(16, 9), Vector2i(14, 9), Vector2i(15, 10)]
const IN_THE_FOREST: Array[Vector2i] = [Vector2i(15, 10), Vector2i(14, 9), Vector2i(14, 11), Vector2i(16, 9)]
const FALLS_LEDGE: Array[Vector2i] = [Vector2i(11, 9), Vector2i(12, 10), Vector2i(13, 11), Vector2i(14, 12)]
const CAMP_EDGE: Array[Vector2i] = [Vector2i(21, 22), Vector2i(22, 22), Vector2i(21, 23), Vector2i(21, 21)]
const BY_THE_FIRE: Array[Vector2i] = [Vector2i(22, 16), Vector2i(23, 16), Vector2i(21, 16), Vector2i(22, 17)]
const GALLOWS: Array[Vector2i] = [Vector2i(19, 10), Vector2i(20, 10), Vector2i(18, 10), Vector2i(19, 11)]
const PATROL: Array[Vector2i] = [Vector2i(18, 21), Vector2i(19, 21), Vector2i(17, 21), Vector2i(18, 20)]
## The milestone where the black carriage comes for Steaua; the falls' offering stone, where the voices call.
const MILESTONE: Array[Vector2i] = [Vector2i(31, 11), Vector2i(32, 11), Vector2i(30, 11), Vector2i(31, 12)]
const OFFERING_STONE: Array[Vector2i] = [Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


func test_the_night_streets_at_level_3() -> void:
	await _held("village_of_barovia", 23, 3, "night_streets_dead", VILLAGE_SPAWN, 4, 6, ["ismark_met"])


func test_the_coachman_at_level_3() -> void:
	await _held("village_of_barovia", 22, 3, "teodor_errand", ILEANAS_DOOR, 4, 6, ["teodor_vigil", "teodor_met"], ["teodor"])


func test_the_coachman_at_level_4() -> void:
	await _held("village_of_barovia", 22, 4, "teodor_errand", ILEANAS_DOOR, 4, 6, ["teodor_vigil", "teodor_met"], ["teodor"])


func test_the_bride_in_the_well_at_level_3() -> void:
	await _held("village_of_barovia", 16, 3, "well_bride", AT_THE_WELL, 4, 6, ["bride_bones_raised"])


func test_the_bride_in_the_well_at_level_4() -> void:
	await _held("village_of_barovia", 16, 4, "well_bride", AT_THE_WELL, 4, 6, ["bride_bones_raised"])


## Five in eight with two more zombies (the burial in test_storyqa_continuity's playthrough still wins it: the owner's
## rule that playthroughs stay winnable).
func test_the_churchyard_dead_at_level_3() -> void:
	await _held("village_of_barovia", 12, 3, "churchyard_dead", BY_THE_GRAVE, 4, 6)


func test_doru_in_the_undercroft_at_level_3() -> void:
	await _held("village_church", 12, 3, "doru_undercroft", UNDERCROFT, 4, 6)


func test_the_siege_of_the_mansion_at_level_3() -> void:
	await _held("burgomaster_mansion", 12, 3, "mansion_siege", BY_IREENA, 4, 6)


func test_the_tenant_at_level_3() -> void:
	await _held("burgomaster_mansion", 22, 3, "hound_tenant", [], 4, 6, [], ["lupu"], ["study_door"])


func test_the_grey_goose_cellar_at_level_3() -> void:
	await _held("svalich_roadhouse", 23, 3, "roadhouse_cellar", [Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8),
		Vector2i(13, 8)], 4, 6, ["roadhouse_innkeeper_met"])


func test_the_dead_procession_at_level_4() -> void:
	await _held("road_ambush", 12, 4, "road_dead_procession", PROCESSION, 4, 6)


func test_the_road_hunters_at_level_4() -> void:
	await _held("road_forest", 12, 4, "road_hunters", IN_THE_FOREST, 4, 6)


func test_the_werewolf_at_the_falls_at_level_4() -> void:
	await _held("tser_falls", 23, 4, "falls_werewolf", FALLS_LEDGE, 4, 6)


func test_the_vistani_turn_on_the_party_at_level_4() -> void:
	await _held("tser_pool", 12, 4, "tser_pool_ambush", CAMP_EDGE, 4, 6, ["vistani_turned_hostile"])


func test_the_brawl_at_the_fire_at_level_4() -> void:
	await _held("tser_pool", 12, 4, "tser_pool_brawl", BY_THE_FIRE, 4, 6)


func test_the_hanged_dead_at_level_5() -> void:
	await _held("svalich_crossroads", 23, 5, "crossroads_hanged_dead", GALLOWS, 4, 6)


func test_the_kestrel_patrol_at_level_5() -> void:
	await _held("svalich_crossroads", 12, 5, "kestrel_patrol", PATROL, 4, 6)


func test_the_kestrel_patrol_caught_up_at_level_5() -> void:
	await _held("svalich_crossroads", 12, 5, "kestrel_patrol_reached", PATROL, 4, 6)


func test_the_woodpile_at_level_3() -> void:
	await _held("village_of_barovia", 19, 3, "woodpile_wakes", BY_THE_WOODPILE, 4, 6, ["seedwood_known"])


func test_the_woodpile_burning_at_level_4() -> void:
	await _held("village_of_barovia", 11, 4, "woodpile_burns", BY_THE_WOODPILE, 4, 6, ["seedwood_known", "bildrath_wood_taken"])


func test_the_carriage_escort_at_level_4() -> void:
	await _held("svalich_crossroads", 0, 4, "carriage_escort", MILESTONE, 4, 6, ["mare_saved", "carriage_came"])


func test_the_wisps_at_the_falls_at_level_4() -> void:
	await _held("tser_falls", 22, 4, "falls_wisps", OFFERING_STONE, 4, 6, ["wisps_lured"])


## The other ways into the same fight. A wisp that vanishes can only be hit by an area spell (2026-10-14), so how many
## lights come is tuned against the real fight: every one of these finishes on seeds 1-8.
func test_the_wisps_at_the_falls_at_level_4_unlured() -> void:
	await _held("tser_falls", 22, 4, "falls_wisps", OFFERING_STONE, 4, 6)


func test_the_wisps_at_the_falls_at_level_5() -> void:
	await _held("tser_falls", 22, 5, "falls_wisps", OFFERING_STONE, 4, 6, ["wisps_lured"])


func test_the_wisps_at_the_falls_at_level_5_unlured() -> void:
	await _held("tser_falls", 22, 5, "falls_wisps", OFFERING_STONE, 4, 6)


func test_the_wisps_at_the_falls_at_level_3() -> void:
	await _held("tser_falls", 22, 3, "falls_wisps", OFFERING_STONE, 4, 6, ["wisps_lured"])


func test_the_wisps_at_the_falls_at_level_3_unlured() -> void:
	await _held("tser_falls", 22, 3, "falls_wisps", OFFERING_STONE, 4, 6)
