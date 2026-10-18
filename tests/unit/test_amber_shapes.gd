extends TestCase
## What the Amber Temple's blocks of amber hold (Amber Temple Look Plan §3.2: art/amber_shapes.json, built by make
## vestige_shapes from the game-icons silhouettes): all sixteen vestiges have an entry, every picture it names is built
## and told apart from the others, every silhouette it uses exists and its artist is credited, and every colour and
## touch it names is a palette colour or one the shader draws.

const DATA := "res://art/amber_shapes.json"
const PACK := "res://art/sourced/game_icons/icons/ffffff/transparent/1x1/"
const SHAPES := "res://art/textures/amber/shapes/"
## The artist folders of the pack and the name the Credits screen gives each.
const ARTISTS := {"lorc": "Lorc", "delapouite": "Delapouite", "skoll": "Skoll", "carl-olsen": "Carl Olsen"}

const VESTIGES := ["zantras", "fekre", "taar_haak", "shami_amourae", "yog", "drizlash", "khirad", "norganas", "savnok",
	"seriach", "sykane", "tarakamedes", "tenebrous", "yrrga", "zhudun", "dahlver_nar"]


func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary


func test_every_vestige_holds_something() -> void:
	var shapes := _data()["shapes"] as Dictionary
	for id: String in VESTIGES:
		assert_true(shapes.has(id), "%s has an entry in art/amber_shapes.json" % id)
	assert_eq(shapes.size(), VESTIGES.size(), "and nothing else has")
	for id: String in VESTIGES:
		var e := shapes.get(id, {}) as Dictionary
		assert_true(not (e.get("layers", []) as Array).is_empty() or str(e.get("touch", "")) == "void",
			"%s holds a shape, or is the dark absence" % id)
		assert_eq(AmberGlow.vestige_of("sarc_" + id), id, "its prop id names it")


## Every picture is built (make vestige_shapes), imported, and none repeats another: the blocks can be told apart.
func test_every_picture_is_built_and_told_apart() -> void:
	var shapes := _data()["shapes"] as Dictionary
	var seen := {}
	for id: String in shapes:
		var e := shapes[id] as Dictionary
		if (e.get("layers", []) as Array).is_empty():
			continue
		var planes: Array[String] = [id + ".png"]
		for l: Variant in e["layers"]:
			if str((l as Dictionary).get("plane", "main")) == "orbit" and not (id + "_orbit.png") in planes:
				planes.append(id + "_orbit.png")
		for f in planes:
			assert_true(FileAccess.file_exists(SHAPES + f), "%s is built: run make vestige_shapes" % f)
			assert_true(ResourceLoader.exists(SHAPES + f), "%s is imported" % f)
			if FileAccess.file_exists(SHAPES + f):
				var sum := FileAccess.get_sha256(SHAPES + f)
				assert_false(seen.has(sum), "%s isn't the same picture as %s" % [f, seen.get(sum, "")])
				seen[sum] = f
				var img := Image.load_from_file(SHAPES + f)
				assert_true(img != null and img.get_width() == 256 and img.get_height() == 256, "%s is 256 by 256" % f)


## Every silhouette exists in the pack and its artist is on the Credits screen (the game-icons.net licence is CC BY 3.0).
func test_every_silhouette_exists_and_its_artist_is_credited() -> void:
	var credits := FileAccess.get_file_as_string("res://art/credits.json")
	var shapes := _data()["shapes"] as Dictionary
	for id: String in shapes:
		for l: Variant in (shapes[id] as Dictionary).get("layers", []):
			var icon := str((l as Dictionary)["icon"])
			assert_true(FileAccess.file_exists(PACK + icon + ".svg"), "%s: the silhouette %s exists" % [id, icon])
			var artist := icon.get_slice("/", 0)
			assert_true(ARTISTS.has(artist) and credits.contains(str(ARTISTS[artist])), "%s: %s is credited" % [id, artist])


## Every colour is a palette colour and every touch one the shader draws.
func test_colours_and_touches_are_known() -> void:
	var palette := {}
	palette.merge(JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/palette.json")) as Dictionary)
	var shapes := _data()["shapes"] as Dictionary
	for id: String in shapes:
		var e := shapes[id] as Dictionary
		for k: String in ["tint", "core", "edge", "light", "cloud_tint"]:
			if e.has(k):
				assert_true(palette.has(str(e[k])), "%s: %s %s is a palette colour" % [id, k, e[k]])
		if e.has("touch"):
			assert_true(AmberGlow.TOUCHES.has(str(e["touch"])), "%s: the touch %s is one the shader draws" % [id, e["touch"]])
	for touch: String in AmberGlow.TOUCHES:
		assert_true(AmberGlow.TOUCH_COLOURS.has(touch), "%s has a colour for what it draws" % touch)
