extends FightSeriesCase
## Castle Ravenloft's fights beyond its bosses, scaled up for 2024 heroes (owner, 2026-10-13: the book's fights were
## written for weaker characters). Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit
## Guardians, throwing Fireball, as he plays), standing where walking in or touching something sets each fight off, win
## five in eight on Balanced, give or take one (his target, 2026-10-13 18:05). The bosses are held in
## test_scaled_boss_fights.gd.


## The Hall of Faces, round the ever-burning hearth the party has just put out, the others trailing back toward the
## great entry.
const AT_THE_HEARTH: Array[Vector2i] = [Vector2i(46, 6), Vector2i(45, 7), Vector2i(44, 8), Vector2i(43, 8)]
## The portrait gallery's east door, the leader a step inside, the others behind in the doorway and the hall of weeping
## (the way up from the stairs).
const GALLERY_DOOR: Array[Vector2i] = [Vector2i(35, 7), Vector2i(35, 8), Vector2i(35, 9), Vector2i(36, 10)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, hour: int, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = [], doors: Array[String] = []) -> void:
	var wins := await _series(location, hour, level, encounter, SEEDS, flags, guests, doors, at)
	assert_true(wins >= low, "%s at level %d is won at least %d times in 8 (%d)" % [encounter, level, low, wins])
	assert_true(wins <= high, "%s at level %d is lost at least %d times in 8 (%d)" % [encounter, level, 8 - high, wins])


## The faces wake when the ever-burning hearth goes out: two guardian portraits (each able to Counterspell), three
## helmed horrors and three of the count's animated armours at 125 HP from level 10.
func test_the_faces_wake_at_level_10() -> void:
	await _held("castle_ravenloft_main_floor", 12, 10, "crg_faces_wake", AT_THE_HEARTH, 4, 6, ["crg_ever_hearth_out"])


## Below level 10, two portraits, two helmed horrors and three animated armours at 95 HP.
func test_the_faces_wake_at_level_9() -> void:
	await _held("castle_ravenloft_main_floor", 12, 9, "crg_faces_wake", AT_THE_HEARTH, 4, 6, ["crg_ever_hearth_out"])


## The count's portrait (able to Counterspell) watches the gallery with four suits of his armour.
func test_the_portrait_gallery_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 12, 10, "court_portrait_watch", GALLERY_DOOR, 4, 6, [], [], ["court_gallery_door_e"])
