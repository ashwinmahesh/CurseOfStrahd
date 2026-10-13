extends FightSeriesCase
## The story's boss fights scaled up for 2024-rules heroes (owner, 2026-10-13: the book's fights were written for weaker
## characters). Over seeds 1-8 the four pregens on autopilot, standing where walking up to the one who starts the fight
## leaves them, win about 3 in 8 at levels 3-5 and 2 in 8 from level 6 (his targets). The side quests' bosses are held
## in test_side_quest_bosses.gd.


## Vallaki's square, beside Izek when he picks his fight; and on the festival ground.
const IZEK_SQUARE: Array[Vector2i] = [Vector2i(24, 13), Vector2i(25, 14), Vector2i(25, 15), Vector2i(25, 16)]
const FESTIVAL_GROUND: Array[Vector2i] = [Vector2i(24, 16), Vector2i(24, 17), Vector2i(24, 18), Vector2i(24, 19)]
## Izek's room in the Burgomaster's mansion, the four in the passage at its door.
const IZEKS_DOOR: Array[Vector2i] = [Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]
## Old Bonegrinder's loft, at Morgantha's elbow.
const LOFT: Array[Vector2i] = [Vector2i(9, 6), Vector2i(8, 7), Vector2i(7, 8), Vector2i(6, 9)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = []) -> void:
	speakers_step_aside = true
	var wins := await _series(location, 12, level, encounter, SEEDS, flags, [], [], at)
	assert_true(wins >= low, "%s is won at least %d times in 8 (%d)" % [encounter, low, wins])
	assert_true(wins <= high, "%s is lost at least %d times in 8 (%d)" % [encounter, 8 - high, wins])


## Izek at his book 112 HP with four sergeants of the watch.
func test_izeks_duel_at_level_5() -> void:
	await _held("vallaki", 5, "izek_duel", IZEK_SQUARE, 2, 4)


## Izek runs wild at the festival: two sergeants, the captain and two guards try to hold him and turn on the party.
func test_izeks_festival_rampage_at_level_5() -> void:
	await _held("vallaki", 5, "festival_izek_rampage", IZEK_SQUARE, 2, 4)


## The Baron's loyalists at the festival: Izek, three sergeants, the captain and two guards (3 in 8 with four sergeants
## too, but then the phase 4 playthrough's Wachter path could lose it).
func test_the_festival_loyalists_at_level_5() -> void:
	await _held("vallaki", 5, "festival_loyalists", FESTIVAL_GROUND, 2, 4)


## Izek in his room with his dolls, three sergeants of the watch and a guard coming in behind the party: 2 of 8, the
## harder side of the owner's 3 (without the guard, 4).
func test_izek_in_his_room_at_level_5() -> void:
	await _held("vallaki_burgomaster_mansion", 5, "izek_confrontation", IZEKS_DOOR, 2, 4)


## The coven's last stand: Morgantha and both daughters at their book 112 HP, and three swarms of rats from the grain
## bins: 1 of 8, the harder side of the owner's 2 (with two swarms, 4).
func test_the_covens_last_stand_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 3, ["offalia_in_last_stand", "bella_in_last_stand"])


## Morgantha and one daughter, the other split off from the coven: the mill's dogs (four, and a swarm of rats, with
## Offalia; five with Bella) come up with them.
func test_morgantha_and_offalia_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 3, ["offalia_in_last_stand"])


func test_morgantha_and_bella_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 3, ["bella_in_last_stand"])
