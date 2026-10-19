extends FightSeriesCase
## The wardens' camp on Yester Hill (the optional fight on the way up, not Wintersplinter's), scaled up for 2024 heroes
## (owner, 2026-10-13: the book's fights were written for weaker characters). The summit itself is held in test_yester_summit.gd.
## Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit Guardians, throwing Fireball, as he
## plays) win 5, give or take one, on Balanced (owner, 2026-10-13 18:05), each fight played from where walking in or
## talking sets it off, with its foes starting spread out (tests/unit/test_fight_spread.gd). Every fight finishes.

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


## wardens_camp_fight, yester_hill variant 2 at level 5.
func test_wardens_camp_fight_v2_at_level_5() -> void:
	await _held("yester_hill", 12, 5, "wardens_camp_fight", [Vector2i(14, 21), Vector2i(15, 22), Vector2i(16, 23), Vector2i(17, 24)], 2, 6, [])


## wardens_camp_fight, yester_hill variant 1 at level 6.
func test_wardens_camp_fight_v1_at_level_6() -> void:
	await _held("yester_hill", 12, 6, "wardens_camp_fight", [Vector2i(14, 21), Vector2i(15, 22), Vector2i(16, 23), Vector2i(17, 24)], 4, 6, [])


## wardens_camp_fight, yester_hill variant 0 at level 7.
func test_wardens_camp_fight_v0_at_level_7() -> void:
	await _held("yester_hill", 12, 7, "wardens_camp_fight", [Vector2i(14, 21), Vector2i(15, 22), Vector2i(16, 23), Vector2i(17, 24)], 0, 6, [])
