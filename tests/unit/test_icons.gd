extends TestCase
## Spell and item icons (art/icons.json -> make icons -> art/icons/): every spell and item in the data has one, every
## catalog key is built in a defined tint (menu glyphs as plain shapes in art/ui/icons), magic items fall back to their
## template's or base item's icon, and every artist is credited.

const CATALOG := "res://art/icons.json"
const FIX := "Add its key to art/icons.json (a game-icons.net silhouette) and run make icons."


func _catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) as Dictionary


func test_every_spell_has_an_icon() -> void:
	for s in Compendium.shared().all("spells"):
		var id := str(s["id"])
		assert_true(Icons.spell(id) != null, "spell %s has no icon (key %s). %s" % [id, Icons.spell_key(id), FIX])


func test_every_item_has_an_icon() -> void:
	for folder: String in ["items", "magic_items"]:
		for id: String in Compendium.shared().table(folder):
			assert_true(Icons.item(id) != null, "%s %s has no icon (key %s). %s" % [folder, id, Icons.item_key(id), FIX])


func test_every_catalog_key_is_built() -> void:
	var cat := _catalog()
	for kind: String in ["spells", "items", "features"]:
		for key: String in cat[kind] as Dictionary:
			assert_true(ResourceLoader.exists("res://art/icons/%s/%s.png" % [kind, key]), "%s/%s isn't built: run make icons" % [kind, key])
	for key: String in cat["ui"] as Dictionary:
		assert_true(UiKit.icon(key) != null, "menu glyph %s isn't built: run make icons" % key)


## Spells take a flavour's colours and items their material's ("<silhouette>@<tint>"): every tint used is defined, in
## palette colours only.
func test_every_tint_is_defined_in_palette_colours() -> void:
	var cat := _catalog()
	var tints := cat["tints"] as Dictionary
	var palette := {}
	for f: String in ["res://art/palette/palette.json", "res://art/palette/ui_palette.json"]:
		palette.merge(JSON.parse_string(FileAccess.get_file_as_string(f)) as Dictionary)
	for t: String in tints:
		var spec := tints[t] as Dictionary
		var names: Array = (spec["face"] as Array) + (spec.get("bg", []) as Array) + ([spec["glow"]] if spec.has("glow") else [])
		for n: Variant in names:
			assert_true(palette.has(str(n)), "tint %s uses %s, which isn't a palette colour" % [t, n])
	for kind: String in ["spells", "items", "features"]:
		for key: String in cat[kind] as Dictionary:
			var entry := str((cat[kind] as Dictionary)[key])
			if entry.contains("@"):
				assert_true(tints.has(entry.get_slice("@", 1)), "%s/%s: no tint %s" % [kind, key, entry.get_slice("@", 1)])


## The order agreed with the magic items data: the item's own icon, its template's, its base item's icon, the base id.
func test_magic_items_fall_back_to_their_template_or_base_item() -> void:
	var magic := Compendium.shared().table("magic_items")
	magic["test_plain_variant"] = {"id": "test_plain_variant", "base_item": "longsword", "template_id": "test_template"}
	magic["test_named_variant"] = {"id": "test_named_variant", "base_item": "longsword", "template_id": "test_named"}
	magic["test_named"] = {"id": "test_named", "icon": "sunsword"}
	magic["test_own"] = {"id": "test_own", "icon": "lamp", "base_item": "longsword"}
	assert_eq(Icons.item_key("test_plain_variant"), "longsword", "a +1 weapon looks like its base")
	assert_eq(Icons.item_key("test_named_variant"), "sunsword", "a named template keeps its own art")
	assert_eq(Icons.item_key("test_own"), "lamp", "an item's own icon wins")
	assert_eq(Icons.item_key("longsword"), "longsword", "a mundane item is keyed by its id")
	for id: String in ["test_plain_variant", "test_named_variant", "test_named", "test_own"]:
		magic.erase(id)


func test_hotbar_entries_find_their_icons() -> void:
	assert_true(Icons.for_action({"id": "spell:fireball", "spell_id": "fireball"}) == Icons.spell("fireball"), "a spell")
	assert_true(Icons.for_action({"id": "attack:weapon:longsword", "spell_id": ""}) == Icons.item("longsword"), "a weapon attack")
	assert_true(Icons.for_action({"id": "offhand:thrown:dagger", "spell_id": ""}) == Icons.item("dagger"), "a thrown off-hand dagger")
	assert_true(Icons.for_action({"id": "item:potion_of_healing", "spell_id": ""}) == Icons.item("potion_of_healing"), "a potion")
	assert_true(Icons.for_action({"id": "dash", "spell_id": ""}) == null, "plain actions keep their text")


## CC BY 3.0 asks for "Icons made by {author}": each artist whose silhouette is used is named on the Credits screen.
func test_every_icon_artist_is_credited() -> void:
	var credits := FileAccess.get_file_as_string("res://art/credits.json").to_lower()
	var cat := _catalog()
	for kind: String in ["spells", "items", "ui"]:
		for key: String in cat[kind] as Dictionary:
			var author := str((cat[kind] as Dictionary)[key]).get_slice("/", 0)
			assert_true(credits.contains(author.replace("-", " ")), "credit %s for %s/%s in art/credits.json" % [author, kind, key])
