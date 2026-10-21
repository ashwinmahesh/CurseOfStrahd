extends TestCase
## Two cutscenes from the owner's todo list (2026-10-18; docs/ui/cutscenes.md): reading the Tome of Strahd plays six
## pictures of Strahd's story to the sorrow, and Escher's first meeting shows the tall mirror behind him with the same
## armchair empty, one picture by the owner's word. The Tome's reading is a conversation since 2026-10-20 (narrative/
## strahd/tome.dialogue): mostly Strahd's own words, the Narrator filling in what he left out, every time it is read.

const TOME_SCENES: Array[String] = ["tome_conqueror", "tome_brothers", "tome_refused", "tome_wedding", "tome_wall", "tome_again"]
## The lines of the first script (24 Narrator captions, all voiced) that stay in the conversation word for word.
const KEPT_NARRATOR_KEYS: Array[String] = ["read:tome_of_strahd", "scene:tome_conqueror_4", "scene:tome_brothers_3", "scene:tome_refused_3",
	"scene:tome_wedding_2", "scene:tome_wedding_4", "scene:tome_wall_2", "scene:tome_again", "scene:tome_again_3", "scene:tome_again_4"]
## A Strahd line is read in a click or two: long enough to say something, short enough to sit over the picture. The last
## line of the book is one steady sentence.
const MIN_WORDS := 25
const MAX_WORDS := 60
const LAST_LINE := "I chose every step of it, and I would choose it again."

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

## The conversation the Tome plays, to its end: its picture and line beats in order.
func _read_through(st: StoryState) -> Array[Dictionary]:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("strahd/tome:read"), "the Tome's conversation starts")
	var out: Array[Dictionary] = []
	for i in 100:
		var beat := r.next()
		if str(beat["kind"]) == "end":
			return out
		out.append(beat)
	assert_true(false, "the Tome's conversation ends")
	return out


func _lines(beats: Array[Dictionary], speaker: String) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b["kind"]) == "line" and str(b["speaker_id"]) == speaker:
			out.append(str(b["text"]))
	return out


func test_reading_the_tome_names_its_conversation() -> void:
	var st := _story()
	var ch := st.party[0]
	ch.add_item("tome_of_strahd")
	var res := FieldItems.use(st, ch, "tome_of_strahd", "read", ch, DiceRoller.new(1))
	assert_true(bool(res.get("ok", false)), str(res))
	assert_eq(str(res.get("dialogue", "")), "strahd/tome:read", "the inventory plays the book's conversation")
	assert_eq(str(res.get("cutscene", "")), "", "and no longer a place's first-reading cutscene")
	assert_eq(Cutscenes.for_trigger("read:tome_of_strahd", st), "", "nothing else answers a reading")
	var again := FieldItems.use(st, ch, "tome_of_strahd", "read", ch, DiceRoller.new(1))
	assert_eq(str(again.get("dialogue", "")), "strahd/tome:read", "a later reading plays it again")


## What the owner asked on 2026-10-20: mostly Strahd's own voice, the Narrator filling in what he didn't write.
func test_the_tome_is_told_mostly_by_strahd() -> void:
	var beats := _read_through(_story())
	var strahd := _lines(beats, "strahd")
	var narrator := _lines(beats, "narrator")
	assert_true(strahd.size() > narrator.size(), "mostly Strahd's: %d of his, %d of the Narrator's" % [strahd.size(), narrator.size()])
	assert_eq(narrator.size(), KEPT_NARRATOR_KEYS.size() + 1, "the kept Narrator lines and one new one")
	for line in strahd:
		var words := line.split(" ", false).size()
		assert_true(line == LAST_LINE or (words >= MIN_WORDS and words <= MAX_WORDS), "%d words in '%s'" % [words, line.left(40)])
		assert_true(" I " in " %s " % line or line.begins_with("My ") or " my " in line, "first person: '%s'" % line.left(40))
	assert_eq(strahd[strahd.size() - 1], LAST_LINE, "the book ends on his one steady sentence")
	assert_eq(str(beats[0]["kind"]), "cutscene", "the first picture is up before the first line")


func test_the_tome_keeps_its_voiced_narrator_lines_word_for_word() -> void:
	var narrator := _lines(_read_through(_story()), "narrator")
	var narr := Narrator.new(1)
	var st := _story()
	for key in KEPT_NARRATOR_KEYS:
		var text := narr.line(key, st, st.leader_character())
		assert_ne(text, "", "%s is still a Narrator line" % key)
		assert_true(text in narrator, "%s stays in the conversation as it was" % key)
		assert_true(VoiceOver.has_clip("narrator", text), "and it is already voiced")
	var fresh := narrator.filter(func(t: String) -> bool: return not VoiceOver.has_clip("narrator", t))
	assert_eq(fresh.size(), 0, "every line of the Tome is voiced, the new closing line too")


## Every scene has a picture of its own, each a different still, and they come in the order of the book.
func test_the_tome_shows_its_six_pictures_in_order() -> void:
	var st := _story()
	var pictures: Array[String] = []
	var closed := false
	for b in _read_through(st):
		if str(b["kind"]) == "cutscene":
			if str(b["id"]) == "":
				closed = true
			else:
				pictures.append(str(b["id"]))
	assert_eq(pictures, TOME_SCENES, "six pictures, in the book's order")
	assert_true(closed, "taken away at the end")
	var seen := {}
	for id in TOME_SCENES:
		var path := Cutscenes.image(id, st)
		assert_eq(path, "res://art/cutscenes/%s.jpg" % id, "%s has its own picture" % id)
		assert_false(seen.has(path), "%s: a picture used twice" % id)
		seen[path] = true
		assert_true(ResourceLoader.exists(path), path)
		assert_eq(str(Cutscenes.get_cutscene(id).get("trigger", "")), "", "%s is a conversation's picture now" % id)
		assert_eq(Audio.scene_mood(id), "sorrow", "%s plays to the sorrow" % id)


## What the owner asked the Tome to carry (2026-10-18): Strahd's motives, his love for Tatyana and her refusing the
## decorated war hero for his brother, and her rebirths, each time another try at making her love him; and (2026-10-20) that
## part of his jealousy of Sergei is that he is the elder, who had to work for everything, while the younger brother is given
## the love he always wanted. Nothing that belongs to someone else: the Amber Temple vault says "stop growing older than her"
## when the Tome and the copper ledger are read together (narrative/amber_temple/vault.dialogue ~ pact_tome), and Ireena is
## never named in a book written long before her.
func test_the_tome_carries_his_motives_her_refusal_her_rebirths_and_his_jealousy() -> void:
	var beats := _read_through(_story())
	var by_scene := {}
	var scene := ""
	var every := ""
	for b in beats:
		if str(b["kind"]) == "cutscene":
			scene = str(b["id"])
		elif str(b["kind"]) == "line":
			by_scene[scene] = "%s %s" % [by_scene.get(scene, ""), str(b["text"])]
			every += " " + str(b["text"])
	assert_true("loved for himself" in str(by_scene["tome_conqueror"]), "what he wanted, under the medals")
	assert_true("medals" in str(by_scene["tome_refused"]) and "pity" in str(by_scene["tome_refused"]),
		"the decorated war hero is refused, kindly, for his brother")
	assert_true("Sergei waited" in str(by_scene["tome_refused"]))
	assert_true("Generation after generation" in str(by_scene["tome_again"]) and "ledger" in str(by_scene["tome_again"]),
		"Tatyana is born again, and he tries each time")
	assert_true("I was gentle with her" in str(by_scene["tome_again"]), "each try begins kindly")
	var brothers := str(by_scene["tome_brothers"])
	assert_true("As the elder son I paid for my rank" in brothers and "in years and blood" in brothers, "he, the elder, worked for all of it")
	assert_true("Sergei never kept a winter watch" in brothers and "for nothing, the love I had wanted all my life" in brothers,
		"while the younger brother is given the love he always wanted")
	assert_false("growing older" in every, "the vault's revelation is left to the vault")
	assert_false("Ireena" in every, "the book names no one from the party's time")
	assert_false("Dark Powers" in every or " Death" in every, "the game never names what he bargained with")


## The real path, every time: Read it through on the Tome in the inventory. The screen gives way to the conversation, the
## codex fills and Strahd knows as before, and reading it again plays it again.
func test_reading_the_tome_in_the_inventory_plays_it_every_time() -> void:
	await _game()
	var ch := GameState.story.party[0]
	ch.add_item("tome_of_strahd")
	for reading in 2:
		root.call("open_screen", "inventory", 0)
		await _frames(2)
		var inv := root.get("screen") as InventoryScreen
		inv.selected = "tome_of_strahd"
		inv._use_power("read", {})
		await _frames(2)
		var d := root.get("dialogue") as DialogueUI
		assert_true(d != null, "reading %d: the inventory gives way to the conversation" % (reading + 1))
		assert_true(root.get("screen") == null, "reading %d: the screen is closed" % (reading + 1))
		assert_eq(str(root.get("_dialogue_ref")), "strahd/tome:read")
		assert_eq(root.get("_scene_mood"), "sorrow", "to the sorrow")
		var pictures := 0
		for i in 200:
			if root.get("dialogue") == null:
				break
			d = root.get("dialogue") as DialogueUI
			if d.cutscene != null and d.cutscene.image_path != "":
				pictures = maxi(pictures, 1)
			if bool(d.get("_waiting_continue")):
				d.call("_advance")
			await _frames(1)
		assert_true(root.get("dialogue") == null, "reading %d: it plays to its end" % (reading + 1))
		assert_true(pictures > 0, "over its pictures")
		assert_true("tome_of_strahd" in GameState.story.codex, "its story is in the codex")
		assert_true(bool(GameState.story.get_flag("strahd_knows_tome_read", false)), "and Strahd knows")
		await get_tree().create_timer(0.7).timeout
		assert_true("the Tome of Strahd" in (root.get("hud") as ExploreHud)._narr.text or "turns the pages again" in (root.get("hud") as ExploreHud)._narr.text,
			"what the reading said is narrated once it ends")


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
