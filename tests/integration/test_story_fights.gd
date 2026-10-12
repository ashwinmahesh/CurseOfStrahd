extends FightSeriesCase
## The story's own fights held to the side-quest bosses' bar where the owner found them too easy (2026-10-12: the Wizard
## of Wines at level 6 on Balanced, where the autopilot won all eight tries losing at most one hero): over seeds 1-8 the
## four pregens on autopilot win at least two and lose at least two, standing where walking in sets the fight off.
## Their level 7 versions carry the same additions.


## Where walking in sets each fight off.
const VINE_LANE: Array[Vector2i] = [Vector2i(22, 25), Vector2i(23, 25), Vector2i(22, 26), Vector2i(23, 26)]
const HALL_DOOR: Array[Vector2i] = [Vector2i(10, 9), Vector2i(9, 9), Vector2i(9, 10), Vector2i(10, 10)]
const DIG_DOOR: Array[Vector2i] = [Vector2i(17, 6), Vector2i(16, 6), Vector2i(15, 6), Vector2i(14, 6)]


func _held(location: String, encounter: String, at: Array[Vector2i]) -> void:
	var wins := await _series(location, 12, 6, encounter, [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], at)
	assert_true(wins >= 2, "%s is won at least twice in 8 (%d)" % [encounter, wins])
	assert_true(wins <= 6, "%s is lost at least twice in 8 (%d)" % [encounter, wins])


## Up the lane from the road: the vines stand up around them, and an old tree blight with them.
func test_the_vineyard_ambush_at_level_6() -> void:
	await _held("wizard_of_wines", "vineyard_ambush", VINE_LANE)


## Into the fermenting hall from the tasting room: two druids, their blights and a shambling mound.
func test_the_winery_hall_at_level_6() -> void:
	await _held("wizard_of_wines_winery", "winery_occupation", HALL_DOOR)


## Through the cask vaults to the dig: the overseer and two druids ahead, two more and their blights rising from among
## the casks behind.
func test_the_cellar_dig_at_level_6() -> void:
	await _held("wizard_of_wines_cellar", "cellar_dig", DIG_DOOR)


## Kostin at the press with the Mash, four druids and six vine blights; the party just inside the door.
func test_the_press_house_at_level_6() -> void:
	await _held("wizard_of_wines_press_house", "press_house_mash", [])
