extends FightSeriesCase
## The two fights of the Rooms of Weeping's west wing (Dungeon Expansion Plan C6, docs/story/fight_tuning_dungeon_c6.md):
## the guardians' passage's rat swarms (K35) and the parapets' animated armour (K46). Over seeds 1-8 the four pregens on the
## sharp autopilot win five in eight on Balanced, give or take one (owner, 2026-10-13), the vermin guarding a door, played from
## where the party stands as it steps in, their foes starting spread out (tests/unit/test_fight_spread.gd). The armour on the
## parapets is attrition, which may stay at 8 in 8 (owner, 2026-10-18: "unless they're guarding something or it's a special
## encounter"), so it is held to 7 or 8. Every fight finishes.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
const WING := "castle_ravenloft_court_west_wing"
const PARAPETS := "castle_ravenloft_parapets"
## The party steps into the passage's door area from the east, a column of four along the middle row (the passage is three
## squares wide, its east end the way in from the hall of weeping).
const AT_THE_STEEL_DOOR: Array[Vector2i] = [Vector2i(27, 11), Vector2i(28, 11), Vector2i(29, 11), Vector2i(30, 11)]
## The armour faces west along the walk and notices a party within 30 ft: the party has come in from the hall of heroes.
const ON_THE_PARAPETS: Array[Vector2i] = [Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3), Vector2i(3, 3)]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, level: int, encounter: String, at: Array[Vector2i], low: int, high: int) -> void:
	var wins := await _series(location, 12, level, encounter, SEEDS, [], [], [], at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## court_vermin, castle_ravenloft_court_west_wing variant 0 at level 10.
func test_court_vermin_v0_at_level_10() -> void:
	await _held(WING, 10, "court_vermin", AT_THE_STEEL_DOOR, 4, 6)


## court_parapet_watch, castle_ravenloft_parapets variant 0 at level 10 (attrition).
func test_court_parapet_watch_v0_at_level_10() -> void:
	await _held(PARAPETS, 10, "court_parapet_watch", ON_THE_PARAPETS, 7, 8)
