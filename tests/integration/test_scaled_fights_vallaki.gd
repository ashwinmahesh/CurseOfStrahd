extends FightSeriesCase
## Vallaki's fights scaled up for 2024 heroes (owner, 2026-10-13: the book's fights were written for weaker characters).
## Over seeds 1-8 the four pregens at level 5 on the sharp autopilot (smiting, opening with Spirit Guardians, throwing
## Fireball, as he plays), standing where walking in or talking sets each fight off, win five in eight on Balanced, give
## or take one (his target, 2026-10-13 18:05). Whoever starts a fight by talking steps aside, as the conversation does in
## play. The named fights (Izek, the Count's likeness) are held in test_scaled_boss_fights.gd.


## The festival on the square; the gate and the street for the Ribbons; the graveyard and the lane for the Roses.
const FESTIVAL: Array[Vector2i] = [Vector2i(20, 14), Vector2i(21, 15), Vector2i(22, 16), Vector2i(23, 17)]
const FESTIVAL_BROKEN: Array[Vector2i] = [Vector2i(31, 15), Vector2i(30, 16), Vector2i(29, 16), Vector2i(28, 17)]
const RIBBONS_GATE: Array[Vector2i] = [Vector2i(22, 20), Vector2i(23, 21), Vector2i(24, 21), Vector2i(23, 20)]
const RIBBONS_STREET: Array[Vector2i] = [Vector2i(23, 21), Vector2i(24, 21), Vector2i(23, 20), Vector2i(23, 22)]
const ROSES_GRAVES: Array[Vector2i] = [Vector2i(45, 8), Vector2i(45, 9), Vector2i(44, 9), Vector2i(43, 9)]
const ROSES_STREET: Array[Vector2i] = [Vector2i(12, 28), Vector2i(13, 27), Vector2i(14, 26), Vector2i(15, 25)]
## The coffin maker's storeroom door; St. Andral's altar by Father Lucian; Stella's room; the Wachters' cellar stair.
const STOREROOM: Array[Vector2i] = [Vector2i(13, 10), Vector2i(12, 10), Vector2i(11, 10), Vector2i(10, 10)]
const BY_LUCIAN: Array[Vector2i] = [Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 6), Vector2i(11, 7)]
const STELLAS_ROOM: Array[Vector2i] = [Vector2i(19, 11), Vector2i(20, 11), Vector2i(18, 11), Vector2i(19, 12)]
const CELLAR_STAIR: Array[Vector2i] = [Vector2i(7, 15), Vector2i(8, 15), Vector2i(7, 16), Vector2i(9, 15)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 at level 5 between 4 and 6 (target 5).
func _held(location: String, hour: int, encounter: String, at: Array[Vector2i], flags: Array[String] = []) -> void:
	var wins := await _series(location, hour, 5, encounter, SEEDS, flags, [], [], at)
	assert_true(wins >= 4, "%s is won at least four times in 8 (%d)" % [encounter, wins])
	assert_true(wins <= 6, "%s is lost at least twice in 8 (%d)" % [encounter, wins])


func test_the_festival_coup() -> void:
	await _held("vallaki", 12, "festival_coup", FESTIVAL)


func test_the_festival_coup_with_the_cult_broken() -> void:
	await _held("vallaki", 12, "festival_coup", FESTIVAL_BROKEN, ["wachter_cult_broken"])


func test_the_ribbons_at_the_gate() -> void:
	await _held("vallaki", 21, "ribbons_gate", RIBBONS_GATE, ["ribbons_list_known"])


func test_the_ribbons_in_the_street() -> void:
	await _held("vallaki", 21, "ribbons_street", RIBBONS_STREET, ["ribbons_list_known"])


func test_the_roses_at_the_graves() -> void:
	await _held("vallaki", 11, "roses_graves", ROSES_GRAVES, ["ana_grave_known"])


func test_the_roses_in_the_street() -> void:
	await _held("vallaki", 22, "roses_street", ROSES_STREET, ["roses_vigil", "ana_met"])


func test_the_coffin_makers_storeroom() -> void:
	await _held("vallaki_coffin_maker", 12, "storeroom_spawn", STOREROOM)


func test_the_siege_of_st_andrals() -> void:
	await _held("vallaki_st_andrals", 23, "church_siege", BY_LUCIAN)


## One Master's Gaze at level 5 (the owner's call, 2026-10-12: two killed heroes outright too often), with twelve
## shadows and a ghast.
func test_stellas_shadow() -> void:
	await _held("vallaki_wachter_house", 14, "stella_shadow", STELLAS_ROOM, ["stella_bound_known", "stella_met"])


## A level later the Master looks out of two of them, with ten shadows.
func test_stellas_shadow_at_level_6() -> void:
	var wins := await _series("vallaki_wachter_house", 14, 6, "stella_shadow", SEEDS, ["stella_bound_known", "stella_met"],
		[], [], STELLAS_ROOM)
	assert_true(wins >= 4 and wins <= 6, "stella_shadow at level 6 is won 4 to 6 times in 8 (%d)" % wins)


func test_the_cult_in_the_wachters_cellar() -> void:
	await _held("vallaki_wachter_house", 23, "wachter_cellar_cult", CELLAR_STAIR)
