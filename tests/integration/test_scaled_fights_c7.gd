extends FightSeriesCase
## The Dungeon Expansion's C7 fights (docs/story/fight_tuning_dungeon_c7.md): the entry's four stone dragons, scaled up for 2024
## heroes (owner, 2026-10-13: the book's fights were written for weaker characters), and the two dead of the king's balcony, an
## attrition fight kept at the book's size. Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit
## Guardians, throwing Fireball, as he plays) win the dragons 5, give or take one, on Balanced, each fight played from where the
## party stands when it starts, with its foes starting spread out (tests/unit/test_fight_spread.gd). Every fight finishes. Each
## level a fight changes at has its own version.

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
const MAIN := "castle_ravenloft_main_floor"
const BALCONY := "castle_ravenloft_chapel_balcony"
## Where the party stands when the plinths beside the great doors call the dragons awake: within two squares of one.
const AT_THE_DOORS: Array[Vector2i] = [Vector2i(25, 21), Vector2i(26, 21), Vector2i(25, 20), Vector2i(26, 20)]
## Where it stands as the stair brings it up onto the gallery: the leader steps off the stair's head into the king's balcony.
const AT_THE_STAIR_HEAD: Array[Vector2i] = [Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6), Vector2i(3, 7)]


func before_each() -> void:
	speakers_step_aside = true
	prepare = Callable()


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, [], [], at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## crg_entry_dragons, castle_ravenloft_main_floor variant 0 at level 11. The scene sets crg_entry_dragons_woken before the fight
## (its plinths are empty), so the series does too.
func test_crg_entry_dragons_v0_at_level_11() -> void:
	await _held(MAIN, 12, 11, "crg_entry_dragons", AT_THE_DOORS, 4, 6, ["crg_entry_dragons_woken"])


## crg_entry_dragons variant 1 at level 10.
func test_crg_entry_dragons_v1_at_level_10() -> void:
	await _held(MAIN, 12, 10, "crg_entry_dragons", AT_THE_DOORS, 4, 6, ["crg_entry_dragons_woken"])


## crg_entry_dragons variant 2 at level 9.
func test_crg_entry_dragons_v2_at_level_9() -> void:
	await _held(MAIN, 12, 9, "crg_entry_dragons", AT_THE_DOORS, 4, 6, ["crg_entry_dragons_woken"])


## crg_balcony_zombies, castle_ravenloft_chapel_balcony: the book's two Strahd zombies, one version for every level. An attrition
## fight (owner, 2026-10-18: "We can keep this at 8/8. Some combats are just meant to drain resources", unless they guard something
## or are a special encounter, and a plain ambush in a gallery is neither): the sharp party wins all eight or all but one, and no
## seed times out.
func test_crg_balcony_zombies_at_level_11() -> void:
	await _held(BALCONY, 12, 11, "crg_balcony_zombies", AT_THE_STAIR_HEAD, 7, 8)


func test_crg_balcony_zombies_at_level_10() -> void:
	await _held(BALCONY, 12, 10, "crg_balcony_zombies", AT_THE_STAIR_HEAD, 7, 8)


func test_crg_balcony_zombies_at_level_9() -> void:
	await _held(BALCONY, 12, 9, "crg_balcony_zombies", AT_THE_STAIR_HEAD, 7, 8)
