extends FightSeriesCase
## Death House scaled up for 2024 heroes (owner, 2026-10-13: the book's fights were written for weaker characters). Over
## seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit Guardians, as he plays), standing where
## walking in or talking sets each fight off, win five in eight on Balanced, give or take one (his target, 2026-10-13
## 18:05). Whoever starts a fight by talking steps aside, as the conversation does in play. The wolves in the narrows on the road there are held here too. The Dursts' robed ones (level 3) are held in
## test_side_quest_bosses.gd.


## The narrows on the Old Svalich Road, the party just short of the lead wolf.
const NARROWS: Array[Vector2i] = [Vector2i(22, 15), Vector2i(23, 16), Vector2i(24, 17), Vector2i(25, 17)]
## Death House, third floor: up the stair onto the balcony; the nursery door; the storage room door.
const BALCONY: Array[Vector2i] = [Vector2i(11, 6), Vector2i(12, 7), Vector2i(13, 8), Vector2i(14, 9)]
const NURSERY_DOOR: Array[Vector2i] = [Vector2i(22, 8), Vector2i(22, 7), Vector2i(22, 6), Vector2i(22, 5)]
const STORAGE_DOOR: Array[Vector2i] = [Vector2i(12, 12), Vector2i(12, 11), Vector2i(12, 10), Vector2i(13, 10)]
## The dungeon: Elisabeth's crypt; the ghoul passage from the well chamber; the shrine's statue; the Dursts' door; their
## table, the party coming in at the door; the ritual chamber's altar.
const CRYPTS: Array[Vector2i] = [Vector2i(11, 2), Vector2i(10, 3), Vector2i(9, 3), Vector2i(8, 3)]
const GHOUL_PASSAGE: Array[Vector2i] = [Vector2i(11, 14), Vector2i(11, 13), Vector2i(11, 12), Vector2i(12, 11)]
const SHRINE: Array[Vector2i] = [Vector2i(4, 19), Vector2i(3, 18), Vector2i(3, 17), Vector2i(3, 16)]
const DURST_DOOR: Array[Vector2i] = [Vector2i(7, 18), Vector2i(6, 17), Vector2i(5, 16), Vector2i(4, 16)]
const AT_SUPPER: Array[Vector2i] = [Vector2i(9, 18), Vector2i(8, 18), Vector2i(7, 18), Vector2i(6, 17)]
const ALTAR: Array[Vector2i] = [Vector2i(25, 14), Vector2i(26, 13), Vector2i(26, 12), Vector2i(26, 11)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]
const DUNGEON_CLEARED: Array[String] = ["death_house_ghouls_destroyed", "death_house_mimic_slain"]


func before_each() -> void:
	speakers_step_aside = true


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = []) -> void:
	var wins := await _series(location, 12, level, encounter, SEEDS, flags, [], [], at)
	assert_true(wins >= low, "%s is won at least %d times in 8 (%d)" % [encounter, low, wins])
	assert_true(wins <= high, "%s is lost at least %d times in 8 (%d)" % [encounter, 8 - high, wins])


func test_the_wolves_in_the_narrows_at_level_1() -> void:
	await _held("into_the_mists_road", 1, "mists_wolves", NARROWS, 4, 6)


func test_the_black_armor_on_the_balcony_at_level_1() -> void:
	await _held("death_house_third", 1, "armor_guardian", BALCONY, 4, 6)


func test_the_nursemaid_at_level_1() -> void:
	await _held("death_house_third", 1, "nursery_specter", NURSERY_DOOR, 4, 6, ["death_house_armor_destroyed"])


func test_the_storage_room_at_level_1() -> void:
	await _held("death_house_third", 1, "storage_broom", STORAGE_DOOR, 4, 6)


func test_elisabeths_crypt_at_level_2() -> void:
	await _held("death_house_dungeon_1", 2, "crypt_insects", CRYPTS, 4, 6)


func test_the_ghoul_passage_at_level_2() -> void:
	await _held("death_house_dungeon_1", 2, "passage_ghouls", GHOUL_PASSAGE, 4, 6)


func test_the_shrines_shadows_at_level_2() -> void:
	await _held("death_house_dungeon_1", 2, "shrine_shadows", SHRINE, 4, 6, ["death_house_ghouls_destroyed"])


func test_the_door_with_teeth_at_level_2() -> void:
	await _held("death_house_dungeon_1", 2, "den_mimic", DURST_DOOR, 4, 6, ["death_house_ghouls_destroyed"])


func test_supper_with_the_dursts_at_level_2() -> void:
	await _held("death_house_dungeon_1", 2, "durst_reunion", AT_SUPPER, 4, 6, DUNGEON_CLEARED)


func test_supper_with_the_dursts_shaken_at_level_2() -> void:
	await _held("death_house_dungeon_1", 2, "durst_reunion_shaken", AT_SUPPER, 4, 6, DUNGEON_CLEARED)


func test_the_shades_at_the_altar_at_level_2() -> void:
	await _held("death_house_dungeon_2", 2, "shades_harry", ALTAR, 4, 6, ["death_house_portcullis_raised"])
