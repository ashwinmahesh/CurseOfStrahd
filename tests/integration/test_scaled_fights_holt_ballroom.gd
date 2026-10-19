extends FightSeriesCase
## The giant spiders' colony in the west wing's ballroom at Argynvostholt (dungeon expansion package A1, the book's Q4).
## Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit Guardians, throwing Fireball, as
## he plays) win 5, give or take one, on Balanced (owner, 2026-10-13 18:05), each fight played from where walking in
## sets it off, its foes waiting in plain view and starting spread out (tests/unit/test_fight_spread.gd). Every fight
## finishes. The chapel's revenants are in test_scaled_fights_holt_chapel.gd.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
## Where the four stand as the leader steps onto the dance floor (the colony stirs from the ballroom's seventh row on) from
## the doors (three leaves side by side, opened): the rest of the party is in the room, not strung out through the doors.
const BALLROOM_DOOR: Array[Vector2i] = [Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(7, 9)]
const BALLROOM_DOORS: Array[String] = ["holt_ballroom_door", "holt_ballroom_door_w", "holt_ballroom_door_e"]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## ballroom_colony, argynvostholt_west_wing variant 2 at level 6.
func test_ballroom_colony_v2_at_level_6() -> void:
	await _held("argynvostholt_west_wing", 12, 6, "ballroom_colony", BALLROOM_DOOR, 4, 7, [], [], BALLROOM_DOORS)


## ballroom_colony, argynvostholt_west_wing variant 1 at level 7.
func test_ballroom_colony_v1_at_level_7() -> void:
	await _held("argynvostholt_west_wing", 12, 7, "ballroom_colony", BALLROOM_DOOR, 4, 6, [], [], BALLROOM_DOORS)


## ballroom_colony, argynvostholt_west_wing variant 0 at level 8.
func test_ballroom_colony_v0_at_level_8() -> void:
	await _held("argynvostholt_west_wing", 12, 8, "ballroom_colony", BALLROOM_DOOR, 4, 7, [], [], BALLROOM_DOORS)
