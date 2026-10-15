extends FightSeriesCase
## The Larders' two singles, Cyrus and Doru (not boss fights: neither is on the boss lane's list), scaled up for 2024
## heroes (owner, 2026-10-13: the book's fights were written for weaker characters).
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


## larders_cyrus_fight, castle_ravenloft_larders variant 0 at level 10.
func test_larders_cyrus_fight_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders", 12, 10, "larders_cyrus_fight", [Vector2i(25, 5), Vector2i(24, 5), Vector2i(25, 6), Vector2i(25, 4)], 4, 6, [])


## larders_doru_hunger, castle_ravenloft_larders_dungeon variant 0 at level 10.
func test_larders_doru_hunger_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_doru_hunger", [Vector2i(9, 10), Vector2i(9, 11), Vector2i(9, 12), Vector2i(10, 12)], 4, 6, [])
