extends FightSeriesCase
## The last non-boss fights that had no series test: the Larders' Cyrus, Doru and false brother, and the Amber Temple's
## library wardens, scaled up for 2024 heroes (owner, 2026-10-13: the book's fights were written for weaker characters).
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


## library_wardens, amber_temple_library variant 0 at level 10.
func test_library_wardens_v0_at_level_10() -> void:
	await _held("amber_temple_library", 12, 10, "library_wardens", [Vector2i(13, 3), Vector2i(14, 4), Vector2i(14, 5), Vector2i(15, 6)], 4, 8, [], [], ["restricted_grille"])


## larders_cyrus_fight, castle_ravenloft_larders variant 0 at level 10.
func test_larders_cyrus_fight_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders", 12, 10, "larders_cyrus_fight", [Vector2i(25, 5), Vector2i(24, 5), Vector2i(25, 6), Vector2i(25, 4)], 4, 8, [])


## larders_doru_hunger, castle_ravenloft_larders_dungeon variant 0 at level 10.
func test_larders_doru_hunger_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_doru_hunger", [Vector2i(9, 10), Vector2i(9, 11), Vector2i(9, 12), Vector2i(10, 12)], 4, 6, [])


## larders_false_brother, castle_ravenloft_larders_dungeon variant 0 at level 10. Brother Anatol is a Vampire, a boss
## (owner, 2026-10-24), with his two spawn, all at book Hit Points: a boss fight (FightSeriesCase.BOSS_FIGHTS). His
## hunger (+1 to hit and DCs, 1d6 more Necrotic a hit; the owner's yes to hitting harder) puts it at 1 in 8.
func test_larders_false_brother_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_false_brother", [Vector2i(5, 15), Vector2i(6, 15), Vector2i(4, 15), Vector2i(6, 16)], 1, 3, [])


## larders_false_brother_unmasked, castle_ravenloft_larders_dungeon variant 0 at level 10: the same three, 2 in 8.
func test_larders_false_brother_unmasked_v0_at_level_10() -> void:
	await _held("castle_ravenloft_larders_dungeon", 12, 10, "larders_false_brother_unmasked", [Vector2i(5, 15), Vector2i(6, 15), Vector2i(4, 15), Vector2i(6, 16)], 1, 3, [])
