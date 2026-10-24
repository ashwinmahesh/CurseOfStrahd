extends FightSeriesCase
## The phantom knights of Argynvostholt's cold hallway (dungeon expansion package A3, the book's Q25; docs/story/
## fight_tuning_holt_upper.md): they step out of the knights' quarters and up through the boards against a party that has
## neither the Order's oath, Godfrey's word nor Godfrey. Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening
## with Spirit Guardians, throwing Fireball, as he plays) win 5, give or take one, on Balanced (owner, 2026-10-13 18:05), each
## fight played from where the party stands as it steps up from the stair into the hallway, its foes starting spread out
## (tests/unit/test_fight_spread.gd). Every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
const THIRD := "argynvostholt_third"
## Where the four stand as the party steps up from the stair head into the hallway (the fight's area starts at row 20).
const AT_THE_HALLWAY: Array[Vector2i] = [Vector2i(18, 20), Vector2i(19, 20), Vector2i(20, 20), Vector2i(21, 20)]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(level: int, low: int, high: int) -> void:
	var wins := await _series(THIRD, 12, level, "trapped_hall", SEEDS, [], [], [], AT_THE_HALLWAY)
	assert_true(wins >= low, "trapped_hall at level %d is won at least %d times in 8 (%d)" % [level, low, wins])
	assert_true(wins <= high, "trapped_hall at level %d is lost at least %d times in 8 (%d)" % [level, 8 - high, wins])


## trapped_hall, argynvostholt_third variant 2 at level 6.
func test_trapped_hall_v2_at_level_6() -> void:
	await _held(6, 4, 6)


## trapped_hall variant 1 at level 7.
func test_trapped_hall_v1_at_level_7() -> void:
	await _held(7, 4, 6)


## trapped_hall variant 0 at level 8.
func test_trapped_hall_v0_at_level_8() -> void:
	await _held(8, 4, 6)
