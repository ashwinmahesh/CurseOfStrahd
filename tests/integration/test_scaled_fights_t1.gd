extends FightSeriesCase
## The ambush under the faceless god (Dungeon Expansion Plan T1, docs/story/fight_tuning_dungeon_t1.md): the shape in the dark
## at the statue's head (Vosk, unseen, the book's arcanaloth at X5a) and three flameskulls behind the west wall's arrow slits
## (X17). A special encounter on the temple's way in, so held to the owner's 5 wins in 8 for the sharp test party, give or
## take one (rule 4), played from where the party stands as it steps into the great hall, surprised, with its foes
## starting spread out (tests/unit/test_fight_spread.gd). The shape leaves after its first round. Every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
const HALL := "amber_temple_faceless_god"
## Where the party stands as it steps up out of the south gallery into the great hall (its trigger area).
const AT_THE_HALL: Array[Vector2i] = [Vector2i(19, 21), Vector2i(20, 21), Vector2i(18, 21), Vector2i(21, 21)]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(level: int, low: int, high: int) -> void:
	var wins := await _series(HALL, 12, level, "statue_ambush", SEEDS, [], [], [], AT_THE_HALL)
	assert_true(wins >= low, "statue_ambush at level %d is won at least %d times in 8 (%d)" % [level, low, wins])
	assert_true(wins <= high, "statue_ambush at level %d is lost at least %d times in 8 (%d)" % [level, 8 - high, wins])


## statue_ambush variant 0, at level 10.
func test_statue_ambush_v0_at_level_10() -> void:
	await _held(10, 4, 6)


## statue_ambush variant 1, at level 9 (the temple's arrival level).
func test_statue_ambush_v1_at_level_9() -> void:
	await _held(9, 4, 6)
