extends TestCase
## Two cutscenes from the owner's todo list (2026-10-18; docs/ui/cutscenes.md): reading the Tome of Strahd plays six
## scenes of Strahd's story (24 captions: his motives, his love for Tatyana and her refusing him for his brother, the
## bargain and the wedding, her fall, and her rebirths generation after generation), the first time only and to the
## sorrow; and Escher's first meeting shows the tall mirror behind him with the same armchair empty, one picture by the
## owner's word.

const TOME_SCENES: Array[String] = ["tome_conqueror", "tome_brothers", "tome_refused", "tome_wedding", "tome_wall", "tome_again"]
## How many captions each scene reads.
const TOME_CAPTIONS := {"tome_conqueror": 4, "tome_brothers": 4, "tome_refused": 4, "tome_wedding": 4, "tome_wall": 3, "tome_again": 5}
## A caption is read in a click or two: long enough to teach, short enough to sit over the picture.
const MIN_WORDS := 25
const MAX_WORDS := 60

var root: Node


func after_each() -> void:
	get_tree().paused = false
	CutsceneView.headless_too = false
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _story() -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.pregen("silvain_aster", 5)
	ch.finish_long_rest()
	st.party.append(ch)
	return st


func _game() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


# --- The Tome of Strahd ----------------------------------------------------------------------------

func test_reading_the_tome_names_its_cutscene() -> void:
	var st := _story()
	var ch := st.party[0]
	ch.add_item("tome_of_strahd")
	var res := FieldItems.use(st, ch, "tome_of_strahd", "read", ch, DiceRoller.new(1))
	assert_true(bool(res.get("ok", false)), str(res))
	assert_eq(str(res.get("cutscene", "")), "read:tome_of_strahd", "the inventory plays the pictures for a reading")
	assert_eq(Cutscenes.for_trigger("read:tome_of_strahd", st), "tome_conqueror")
	assert_eq(Cutscenes.for_trigger("read:no_such_book", st), "")


func test_the_tome_plays_six_scenes_and_twenty_four_captions() -> void:
	var st := _story()
	var narrator := Narrator.new(1)
	var actor := st.leader_character()
	var first := narrator.line("read:tome_of_strahd", st, actor)
	assert_ne(first, "", "the reading has its first caption")
	var steps := Cutscenes.scenes("tome_conqueror", first, st, narrator, actor)
	assert_eq(steps.size(), TOME_SCENES.size(), "six scenes")
	var total := 0
	for i in steps.size():
		var id := str(steps[i]["id"])
		assert_eq(id, TOME_SCENES[i])
		assert_true(ResourceLoader.exists(Cutscenes.image(id, st)), "%s has its picture" % id)
		var lines := steps[i]["lines"] as Array[String]
		assert_eq(lines.size(), int(TOME_CAPTIONS[id]), "%s reads %d captions" % [id, int(TOME_CAPTIONS[id])])
		total += lines.size()
		for line in lines:
			var words := line.split(" ", false).size()
			assert_true(words >= MIN_WORDS and words <= MAX_WORDS, "%s: %d words in '%s'" % [id, words, line.left(40)])
	assert_eq(total, 24)


## Every scene has a picture of its own, each a different still (a scene that names the picture already up would leave it as
## it is, which is how the two scenes that came last played until they had theirs).
func test_every_tome_scene_has_its_own_picture() -> void:
	var st := _story()
	var seen := {}
	for id in TOME_SCENES:
		var path := Cutscenes.image(id, st)
		assert_eq(path, "res://art/cutscenes/%s.jpg" % id, "%s has its own picture" % id)
		assert_false(seen.has(path), "%s: a picture used twice" % id)
		seen[path] = true
		assert_true(ResourceLoader.exists(path), path)


## What the owner asked the Tome to carry (2026-10-18): Strahd's motives, his love for Tatyana and her refusing the
## decorated war hero for his brother, and her rebirths, each time another try at making her love him; and nothing that
## belongs to someone else: the Amber Temple vault says "stop growing older than her" when the Tome and the copper ledger
## are read together (narrative/amber_temple/vault.dialogue ~ pact_tome), and Ireena is never named in a book written long
## before her.
func test_the_tome_carries_his_motives_her_refusal_and_her_rebirths() -> void:
	var st := _story()
	var narrator := Narrator.new(1)
	var by_scene := {}
	var every := ""
	for step in Cutscenes.scenes("tome_conqueror", narrator.line("read:tome_of_strahd", st), st, narrator):
		by_scene[str(step["id"])] = " ".join(step["lines"] as Array[String])
		every += " " + str(by_scene[str(step["id"])])
	assert_true("loved for himself" in str(by_scene["tome_conqueror"]), "what he wanted, under the medals")
	assert_true("medals" in str(by_scene["tome_refused"]) and "pity" in str(by_scene["tome_refused"]),
		"the decorated war hero is refused, kindly, for his brother")
	assert_true("Sergei waited" in str(by_scene["tome_refused"]))
	assert_true("Generation after generation" in str(by_scene["tome_again"]) and "ledger" in str(by_scene["tome_again"]),
		"Tatyana is born again, and he tries each time")
	assert_true("I was gentle with her" in str(by_scene["tome_again"]), "each try begins kindly")
	assert_false("growing older" in every, "the vault's revelation is left to the vault")
	assert_false("Ireena" in every, "the book names no one from the party's time")
	assert_false("Dark Powers" in every or " Death" in every, "the game never names what he bargained with")


func test_the_tome_plays_once_and_closes_back_to_the_world() -> void:
	await _game()
	var played: bool = root.call("play_item_cutscene", "read:tome_of_strahd", "Ilse reads the Tome of Strahd through.")
	assert_true(played, "the first reading plays")
	var player := root.get("screen") as CutscenePlayer
	assert_true(player != null, "the pictures stand in for the open screen")
	assert_true(get_tree().paused, "the world waits under them")
	assert_eq(root.get("_cutscene_mood"), "sorrow", "to the sorrow")
	for i in TOME_SCENES.size():
		assert_eq(player.scene_id, TOME_SCENES[i])
		assert_eq(player.view.image_path, Cutscenes.image(TOME_SCENES[i], GameState.story))
		for c in int(TOME_CAPTIONS[TOME_SCENES[i]]):
			assert_ne(player.view.caption_text(), "", "%s caption %d" % [TOME_SCENES[i], c + 1])
			player.advance()
	assert_true(player.done, "closed after the last caption of the last picture")
	await _frames(2)
	assert_true(root.get("screen") == null, "and the world is back")
	assert_true(not get_tree().paused, "unpaused")
	assert_eq(root.get("_cutscene_mood"), "", "the place's own music comes back")
	await get_tree().create_timer(0.7).timeout
	assert_true("reads the Tome of Strahd through" in (root.get("hud") as ExploreHud)._narr.text,
		"what the reading said is narrated once they close")
	var again: bool = root.call("play_item_cutscene", "read:tome_of_strahd", "Ilse turns the pages again.")
	assert_false(again, "a later reading shows nothing")
	assert_true(root.get("screen") == null)


## The real path: Read it through on the Tome in the inventory. The screen gives way to the pictures, the codex fills and
## Strahd knows as before, and reading it again shows no pictures.
func test_reading_the_tome_in_the_inventory_plays_the_pictures_once() -> void:
	await _game()
	var ch := GameState.story.party[0]
	ch.add_item("tome_of_strahd")
	root.call("open_screen", "inventory", 0)
	await _frames(2)
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "tome_of_strahd"
	inv._use_power("read", {})
	await _frames(2)
	var player := root.get("screen") as CutscenePlayer
	assert_true(player != null, "the inventory gives way to the pictures")
	assert_eq(player.scene_id, "tome_conqueror")
	assert_true("tome_of_strahd" in GameState.story.codex, "its story is in the codex")
	assert_true(bool(GameState.story.get_flag("strahd_knows_tome_read", false)), "and Strahd knows")
	player.close()
	await _frames(3)
	root.call("open_screen", "inventory", 0)
	await _frames(2)
	inv = root.get("screen") as InventoryScreen
	inv.selected = "tome_of_strahd"
	inv._use_power("read", {})
	await _frames(2)
	assert_true(root.get("screen") is InventoryScreen, "a second reading stays in the inventory, no pictures")


func test_skip_leaves_every_scene() -> void:
	await _game()
	assert_true(bool(root.call("play_item_cutscene", "read:tome_of_strahd", "")))
	var player := root.get("screen") as CutscenePlayer
	player.advance()
	player.close()
	assert_true(player.done)
	await _frames(2)
	assert_true(not get_tree().paused)
	assert_false(bool(root.call("play_item_cutscene", "read:tome_of_strahd", "")), "and it counts as seen")


# --- Escher's mirror -------------------------------------------------------------------------------

func test_escher_meets_you_with_the_mirror_that_shows_an_empty_chair() -> void:
	var st := _story()
	assert_true(not st.get_flag("escher_met", false))
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start("castle_ravenloft/spires_escher:start"))
	var pictures: Array[String] = []
	var ended_picture := false
	var told_mirror := false
	for i in 12:
		var beat := r.next()
		var kind := str(beat["kind"])
		if kind == "cutscene":
			if str(beat["image"]) == "":
				ended_picture = true
			else:
				pictures.append(str(beat["id"]))
		if kind == "line" and "mirror behind him shows an empty chair" in str(beat.get("text", "")):
			told_mirror = true
			assert_eq(pictures, ["escher_mirror"], "the picture is up before the line that describes it")
		if ended_picture:
			break
	assert_true(told_mirror, "the existing line stays under the picture")
	assert_eq(pictures, ["escher_mirror"], "one picture")
	assert_true(ended_picture, "and it goes before the menu comes back")
	assert_true(bool(st.get_flag("escher_met", false)))
	assert_true(ResourceLoader.exists(Cutscenes.image("escher_mirror", st)), "its picture is in the game")
	assert_eq(str(Cutscenes.get_cutscene("escher_mirror").get("trigger", "")), "", "a conversation's picture, not a place's")


func test_the_mirror_does_not_come_back_on_a_second_visit() -> void:
	var st := _story()
	st.set_flag("escher_met", true)
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start("castle_ravenloft/spires_escher:start"))
	for i in 6:
		var beat := r.next()
		assert_ne(str(beat["kind"]), "cutscene", "no picture on a second visit")
		if str(beat["kind"]) == "end":
			break
