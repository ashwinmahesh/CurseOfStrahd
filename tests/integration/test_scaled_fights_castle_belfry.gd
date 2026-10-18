extends FightSeriesCase
## The giant spiders the belfry's bell calls (Dungeon Expansion Plan C3, castle_ravenloft_court_belfry): a new fight, tuned
## to the plan's band for the sharp test party (rule 4: 5 wins in 8 over seeds 1-8 on Balanced, the tests holding 4 to 6),
## played from where the party stands when it pulls the rope, its foes starting spread out (tests/unit/test_fight_spread.gd).
## Every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## court_way_spiders, castle_ravenloft_court_belfry at level 10, from the rope (a conversation's fight: its speakers step
## aside), the four standing at its foot.
func test_court_way_spiders_at_level_10() -> void:
	await _held("castle_ravenloft_court_belfry", 12, 10, "court_way_spiders",
		[Vector2i(42, 14), Vector2i(41, 14), Vector2i(43, 14), Vector2i(42, 15)], 4, 6, ["court_way_bell_rung"])
