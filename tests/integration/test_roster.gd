extends TestCase
## The roster (owner, 2026-10-06): up to four travel, the rest wait at camp, and the player swaps them outside fights
## and conversations; those at camp are saved, level with the party, and the world swaps the figures.

const LOC := {
	"id": "test_camp", "name": "Test Camp", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]}
}

var root: Node


func _story(travelling: Array[String], camp: Array[String], level: int = 1) -> StoryState:
	var st := StoryState.new()
	for id in travelling:
		st.party.append(Pregens.build(id, level))
	for id in camp:
		st.bench.append(Pregens.build(id, level))
	return st


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func test_a_swap_puts_the_newcomer_in_the_leavers_place() -> void:
	var st := _story(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow"], ["silvain_aster"])
	var tamsin := st.party[1]
	var silvain := st.bench[0]
	assert_true(st.swap_members(tamsin, silvain))
	assert_eq(st.party[1], silvain, "Silvain walks where Tamsin walked")
	assert_true(tamsin in st.bench, "Tamsin waits at camp")
	assert_eq(st.roster().size(), 4, "nobody is lost")


func test_four_travel_at_most_and_one_at_least() -> void:
	var st := _story(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"], [])
	var hero_b := CharacterBuilder.new(null, {"appearance": HeroLook.default_appearance("female", "fighter")})
	hero_b.set_class("fighter")
	hero_b.set_background("soldier")
	hero_b.set_species("human")
	hero_b.set_name("Vasha Dunmere")
	var hero := hero_b.preview()
	st.bench.append(hero)
	assert_false(st.bring_along(hero), "a full party has no room")
	assert_true(st.send_to_camp(st.party[3]))
	assert_true(st.bring_along(hero), "now there's room")
	assert_eq(st.party.size(), StoryState.PARTY_CAP)
	while st.party.size() > 1:
		assert_true(st.send_to_camp(st.party[0]))
	assert_false(st.send_to_camp(st.party[0]), "somebody stays on the road")
	assert_eq(st.leader, 0, "the leader is still someone in the party")


func test_camp_is_saved_and_loaded() -> void:
	var st := _story(["ilse_varga", "tamsin_tealeaf"], ["hedda_ironvow", "silvain_aster"])
	var back := StoryState.from_dict(st.to_dict())
	assert_eq(back.party.size(), 2)
	assert_eq(back.bench.size(), 2, "those at camp come back with the save")
	assert_eq(back.bench[1].name, "Silvain Aster")
	var old := st.to_dict()
	old.erase("bench")
	assert_eq(StoryState.from_dict(old).bench.size(), 0, "a save from before the roster has nobody at camp")


func test_someone_at_camp_catches_up_on_rejoining() -> void:
	var st := _story(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow"], ["silvain_aster"])
	st.milestones = 3
	var silvain := st.bench[0]
	assert_eq(silvain.character_level(), 1)
	assert_true(st.swap_members(st.party[2], silvain))
	assert_eq(silvain.character_level(), st.target_level(), "levelled to the party's milestone by their plan")


func test_the_roster_screen_and_the_world_follow_the_party() -> void:
	Compendium.shared().tables["locations"]["test_camp"] = LOC.duplicate(true)
	GameState.reset()
	var st := GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	var silvain := Pregens.build("silvain_aster", 1)
	st.bench.append(silvain)
	st.location = "test_camp"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var view := root.get("view") as LocationView
	assert_eq(view.members.size(), 3)
	root.call("open_screen", "roster", 0)
	var screen := root.get("screen") as RosterScreen
	assert_true(screen != null, "the roster screen opens")
	assert_true(st.bring_along(silvain))
	screen.call("_changed")
	assert_eq(view.members.size(), 4, "Silvain steps in beside the party")
	assert_true(view.tokens.has(view.members[3].id), "with a figure of his own")
	var tamsin := st.party[1]
	assert_true(st.send_to_camp(tamsin))
	screen.call("_changed")
	assert_eq(view.members.size(), 3, "Tamsin's figure leaves")
	for cb in view.members:
		assert_ne(cb.creature, tamsin)
	root.call("close_screen")
