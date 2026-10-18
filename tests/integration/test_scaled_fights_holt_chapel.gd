extends FightSeriesCase
## The three revenants that rise in Argynvostholt's chapel at night against a party with neither the Order's oath nor
## Godfrey's word (dungeon expansion package A2, the book's Q13). Over seeds 1-8 the four pregens on the sharp autopilot
## (smiting, opening with Spirit Guardians, throwing Fireball, as he plays) win 5, give or take one, on Balanced (owner,
## 2026-10-13 18:05), each fight played from where walking in sets it off, its foes waiting in plain view and starting
## spread out (tests/unit/test_fight_spread.gd). Every fight finishes. The ballroom's spiders are in
## test_scaled_fights_holt_ballroom.gd.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
## Where the four stand as the leader steps into the nave (the knights rise from the chapel's eighth row up) from the west
## gallery's door: the rest of the party is in the room, not strung out through the doorway.
const CHAPEL_DOOR: Array[Vector2i] = [Vector2i(4, 8), Vector2i(4, 9), Vector2i(4, 10), Vector2i(3, 10)]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## chapel_revenants, argynvostholt_hall variant 2 at level 6, after dark.
func test_chapel_revenants_v2_at_level_6() -> void:
	await _held("argynvostholt_hall", 23, 6, "chapel_revenants", CHAPEL_DOOR, 4, 6)


## chapel_revenants, argynvostholt_hall variant 1 at level 7, after dark.
func test_chapel_revenants_v1_at_level_7() -> void:
	await _held("argynvostholt_hall", 23, 7, "chapel_revenants", CHAPEL_DOOR, 4, 6)


## chapel_revenants, argynvostholt_hall variant 0 at level 8, after dark.
func test_chapel_revenants_v0_at_level_8() -> void:
	await _held("argynvostholt_hall", 23, 8, "chapel_revenants", CHAPEL_DOOR, 4, 6)
