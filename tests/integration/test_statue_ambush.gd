extends TestCase
## The ambush under the faceless god (Dungeon Expansion Plan T1; the book's X4, X5a and X17): an arrow-slit gallery cut into
## the wall west of the south gallery, reached from the hall of echoes, its two slits low walls a flameskull looks over; the
## wardens' rack (the book's X17 Staff of Frost went to the Tsolenka Pass, so it holds a Cone of Cold scroll and a potion against
## the flameskulls' fire); the fight on stepping into the great hall, the party surprised, the shape
## in the dark leaving with Vosk's voice; and Vosk's later word in the library.

const HALL := "amber_temple_faceless_god"


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", HALL) as Dictionary


## The gallery is cut into wall that was solid, with nothing that stood before moved: the passage from the hall of echoes,
## the gallery itself and its two slits.
func test_the_gallery_is_cut_into_the_wall() -> void:
	var rows := (_loc()["map"] as Dictionary)["rows"] as Array
	assert_eq(str(rows[22])[5], ".", "the passage down from the hall of echoes")
	assert_eq(str(rows[23])[5], ".", "and on into the gallery")
	for y: int in [24, 25, 26]:
		assert_eq(str(rows[y]).substr(2, 11), "...........", "gallery row %d is open" % y)
	assert_eq(str(rows[24])[13], "=", "the north slit is a low wall")
	assert_eq(str(rows[26])[13], "=", "the south slit is a low wall")
	assert_eq(str(rows[25])[13], "#", "solid wall between the slits")
	assert_true(_walkable_between(rows, Vector2i(5, 21), Vector2i(8, 25)), "the gallery is reached from the hall of echoes")


## A walk over open floor ('.') from `a` to `b`, four ways round.
func _walkable_between(rows: Array, a: Vector2i, b: Vector2i) -> bool:
	var seen := {a: true}
	var todo: Array[Vector2i] = [a]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c == b:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
				continue
			if str(rows[n.y])[n.x] == ".":
				seen[n] = true
				todo.append(n)
	return false


## The rack at the gallery's back holds the wardens' scroll of Cone of Cold and their potion against fire.
func test_the_rack_holds_the_wardens_cold_and_their_ward_against_fire() -> void:
	var rack := (_loc()["containers"] as Array).filter(func(c: Variant) -> bool: return str((c as Dictionary)["id"]) == "wardens_stave_rack")
	assert_eq(rack.size(), 1, "the wardens' rack")
	var items := ((rack[0] as Dictionary)["items"] as Array).map(func(i: Variant) -> String: return str((i as Dictionary)["id"]))
	assert_true("spell_scroll__cone_of_cold" in items, "with a scroll of Cone of Cold in it")
	assert_true("potion_of_resistance_fire" in items, "and a potion against the flameskulls' fire")


## Both versions start on stepping into the great hall, with the party surprised, three flameskulls and the shape that leaves
## in Vosk's voice; neither once Vosk has been met or dealt with.
func test_the_ambush_starts_in_the_great_hall() -> void:
	var versions := (_loc()["encounters"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == "statue_ambush")
	assert_eq(versions.size(), 2, "a version for level 10 and one below")
	for v: Variant in versions:
		var e := v as Dictionary
		assert_eq(str(e["trigger"]), "enter_area:amber_great_hall", "it starts in the great hall")
		assert_eq(str(e["surprise"]), "party", "the party is surprised")
		for gate: String in ["flag.statue_ambush_fought", "flag.vosk_met", "flag.vosk_fate", "flag.vosk_destroyed"]:
			assert_true(gate in str(e["when"]), "not once %s" % gate)
		var kinds := (e["monsters"] as Array).map(func(m: Variant) -> String: return str((m as Dictionary)["monster"]))
		assert_eq(kinds.count("flameskull"), 3, "three flameskulls")
		assert_eq(kinds.count("arcanaloth"), 1, "and the shape in the dark")
		var w := e["withdraw"] as Dictionary
		assert_eq(str(w["who"]), "arcanaloth", "the shape withdraws")
		assert_eq(str(w["speaker"]), "vosk", "in Vosk's voice")
		assert_eq(str(w["flag"]), "statue_shape_withdrew", "and says so")


## In the library Vosk mentions the hall's welcome, once the shape in the dark has left the fight, and not before.
func test_vosk_knows_about_the_hall() -> void:
	GameState.reset()
	var line := "the wardens' little reception"
	assert_false(_vosk_says(line), "no word of it before the ambush")
	GameState.reset()
	GameState.story.set_flag("statue_shape_withdrew", true)
	assert_true(_vosk_says(line), "he mentions the welcome after it")


func _vosk_says(words: String) -> bool:
	var r := DialogueRunner.new(GameState.story, DiceRoller.new(3))
	assert_true(r.start("amber_temple/vosk:start"), "Vosk's start")
	var b := r.next()
	for i in 12:
		if str(b["kind"]) == "line" and str(b.get("text", "")).contains(words):
			return true
		if str(b["kind"]) in ["end", "options"]:
			return false
		b = r.next()
	return false
