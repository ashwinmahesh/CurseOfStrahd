extends TestCase
## The emerald d20 (docs/ui/d20_roll.md): a real d20's numbering, a throw that always comes to rest square to the camera
## on the true number (whatever way it tumbles, the other die too under Advantage), show_roll's panel for a fight or the
## overworld (it reads the roll, never hangs an await, and lines up rolls asked for at once), and the overworld's
## checks that roll it: forcing a lock among them.

const LOC := {
	"id": "test_dice_vault", "name": "Test Dice Vault", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#########",
		"#.......#",
		"#.......#",
		"####.####",
		"#.......#",
		"#########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"doors": [{"id": "grate", "cell": [4, 3], "locked": true, "lock_dc": 5, "label": "the grate"}],
}

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	await get_tree().process_frame
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_dice_vault")
	GameState.reset()


## The number on the face that points most toward the camera (+Z) on die `i`.
func _facing(d: D20Die, i: int = 0) -> int:
	var b := (d.get("_dice") as Array)[i].transform.basis as Basis
	var best := 0
	var most := -2.0
	for f in D20Mesh.faces():
		var toward := (b * (f["normal"] as Vector3)).normalized().z
		if toward > most:
			most = toward
			best = int(f["number"])
	return best


func test_numbered_like_a_real_d20() -> void:
	var faces := D20Mesh.faces()
	assert_eq(faces.size(), 20)
	var seen := {}
	for f in faces:
		seen[int(f["number"])] = true
		var opposite := faces.filter(func(g: Dictionary) -> bool: return (g["normal"] as Vector3).dot(f["normal"] as Vector3) < -0.99)
		assert_eq(opposite.size(), 1, "one face opposite each")
		assert_eq(int(f["number"]) + int((opposite[0] as Dictionary)["number"]), 21, "opposite faces add up to 21")
	assert_eq(seen.size(), 20, "1 to 20, once each")
	for n in range(1, 21):
		var b := D20Mesh.rest_basis(n)
		var f := D20Mesh.face_of(n)
		assert_true((b * (f["normal"] as Vector3)).is_equal_approx(Vector3(0, 0, 1)), "%d faces the camera" % n)
		assert_true((b * (f["up"] as Vector3)).is_equal_approx(Vector3(0, 1, 0)), "%d reads upright" % n)
	assert_true(D20Mesh.mesh().get_surface_count() == 1)


func test_every_throw_comes_to_rest_on_the_true_number() -> void:
	root = Control.new()
	add_child(root)
	var d := D20Die.new()
	d.size = Vector2(160, 160)
	d.manual = true
	root.add_child(d)
	var landed := [0]
	d.landed.connect(func() -> void: landed[0] += 1)
	for n in range(1, 21):
		d.roll(n)
		d.seek(0.3)
		assert_true(d.rolling(), "still tumbling")
		d.seek(D20Die.ROLL_SECONDS)
		assert_eq(_facing(d), n, "it rests on %d" % n)
		assert_false(d.rolling())
	assert_eq(landed[0], 20, "landed fires once a throw")
	# Under Advantage both dice tumble; each rests on its own number.
	d.roll(15, 6)
	d.seek(D20Die.ROLL_SECONDS + D20Die.SHINE_SECONDS)
	assert_eq(_facing(d, 0), 15)
	assert_eq(_facing(d, 1), 6)
	d.show_landed(9)
	assert_eq(_facing(d), 9, "shown at rest at once")


func test_a_roll_reads_a_d20_test() -> void:
	var dice := DiceRoller.new(TestChars.seed_for_d20(20))
	var t := D20Test.roll(dice, D20Test.Kind.SAVING_THROW, 3, 15, 1, 0, "Dexterity save")
	var r := DiceRoll.from_test(t, "Liriel Dawnsong", "Dexterity saving throw")
	assert_eq(str(r["kind"]), "save")
	assert_eq((r["rolls"] as Array).size(), 2, "both dice under Advantage")
	assert_eq(int(r["natural"]), t.kept)
	assert_eq(int(r["total"]), t.total)
	assert_eq(bool(r["success"]), t.success)
	assert_true(bool(r["advantage"]))
	assert_eq(DiceRoll.title_text(r), "Liriel Dawnsong: Dexterity saving throw, DC 15")
	assert_eq(DiceRoll.verdict_text(r), "Saved" if t.success else "Failed")
	assert_eq(DiceRoll.title_text({"kind": "death_save", "who": "Godrick", "label": "Death saving throw", "target": 10}),
		"Godrick: Death saving throw", "a death save's DC goes without saying")
	assert_eq(DiceRoll.verdict_text({"kind": "attack", "success": true, "critical": true}), "Critical Hit")
	assert_eq(DiceRoll.verdict_text({"kind": "check", "success": false, "verdict": "It holds"}), "It holds")


func test_show_roll_comes_and_goes_and_never_hangs_an_await() -> void:
	root = Node.new()
	add_child(root)
	var roll := {"kind": "save", "natural": 12, "rolls": [12], "total": 15, "target": 15, "success": true,
		"critical": false, "fumble": false, "who": "Liriel Dawnsong", "label": "Dexterity saving throw"}
	var done := DiceRoll.show_roll(root, roll)
	var panel := root.find_child("DiceRoll", true, false) as DiceRoll
	assert_true(panel != null, "the panel is up")
	assert_eq(panel.die.number, 12, "on the kept die")
	assert_eq(panel._verdict.text, "Saved")
	await done
	await get_tree().process_frame
	assert_true(root.find_child("BigRoll", true, false) == null, "and gone once it's done")


func test_forcing_a_lock_rolls_the_big_d20() -> void:
	Compendium.shared().tables["locations"]["test_dice_vault"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["tamsin_tealeaf", "hedda_ironvow"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_dice_vault"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var v := root.get("view") as LocationView
	var rolled: Array[Array] = []
	v.big_roll.connect(func(t: D20Test, who: String, label: String) -> void: rolled.append([t, who, label]))
	v.act(Vector2i(4, 3), "force")
	for i in 400:
		if not rolled.is_empty() or (v.get("_queue") as Array).is_empty() and i > 5:
			break
		await get_tree().process_frame
	assert_eq(rolled.size(), 1, "forcing it rolls the big d20")
	assert_eq(str(rolled[0][2]), "Athletics")
	assert_true((rolled[0][0] as D20Test).target > 0, "against the lock's DC")
