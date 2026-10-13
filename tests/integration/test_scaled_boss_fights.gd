extends FightSeriesCase
## The story's boss fights scaled up for 2024-rules heroes (owner, 2026-10-13: the book's fights were written for weaker
## characters). Over seeds 1-8 the four pregens on autopilot, standing where walking up to the one who starts the fight
## leaves them, win about 3 in 8 at levels 3-5 and 2 in 8 from level 6 (his targets). The side quests' bosses are held
## in test_side_quest_bosses.gd.


## Vallaki's square, beside Izek when he picks his fight; and on the festival ground.
const IZEK_SQUARE: Array[Vector2i] = [Vector2i(24, 13), Vector2i(25, 14), Vector2i(25, 15), Vector2i(25, 16)]
const FESTIVAL_GROUND: Array[Vector2i] = [Vector2i(24, 16), Vector2i(24, 17), Vector2i(24, 18), Vector2i(24, 19)]
## Old Bonegrinder's loft, at Morgantha's elbow.
const LOFT: Array[Vector2i] = [Vector2i(9, 6), Vector2i(8, 7), Vector2i(7, 8), Vector2i(6, 9)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = []) -> void:
	var wins := await _series(location, 12, level, encounter, SEEDS, flags, [], [], at)
	assert_true(wins >= low, "%s is won at least %d times in 8 (%d)" % [encounter, low, wins])
	assert_true(wins <= high, "%s is lost at least %d times in 8 (%d)" % [encounter, 8 - high, wins])


## Izek at his book 112 HP with four sergeants of the watch.
func test_izeks_duel_at_level_5() -> void:
	await _held("vallaki", 5, "izek_duel", IZEK_SQUARE, 1, 5)


## Izek runs wild at the festival: three sergeants, the captain and two guards try to hold him and turn on the party.
func test_izeks_festival_rampage_at_level_5() -> void:
	await _held("vallaki", 5, "festival_izek_rampage", IZEK_SQUARE, 1, 5)


## The Baron's loyalists at the festival: Izek, four sergeants, the captain and two guards.
func test_the_festival_loyalists_at_level_5() -> void:
	await _held("vallaki", 5, "festival_loyalists", FESTIVAL_GROUND, 1, 5)


## The coven's last stand: Morgantha and both daughters at their book 112 HP, and the rats from the grain bins.
func test_the_covens_last_stand_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 4, ["offalia_in_last_stand", "bella_in_last_stand"])
