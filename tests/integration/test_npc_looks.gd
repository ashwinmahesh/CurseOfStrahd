extends TestCase
## Rictavio unmasked (owner, 2026-10-08): once he admits he is Rudolph van Richten (flag rictavio_unmasked), his
## dialogue portrait, his bust and his combat HUD portrait become Van Richten's (data `looks`, story/npc_looks.gd). His
## name, his sprite on the map and the board, and his stat block stay Rictavio's.

const DIALOGUE := "~ a\nRictavio: A song, friends? No? A sausage, then.\n-> END\n"


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/looks"))


func _line(st: StoryState) -> Dictionary:
	var r := DialogueRunner.new(st, DiceRoller.new(2))
	r.start("test/looks:a")
	return r.next()


func test_the_showman_until_he_drops_the_act() -> void:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	var b := _line(st)
	assert_eq(str(b["portrait"]), "rictavio")
	assert_eq(str(b["name"]), "Rictavio")
	st.set_flag("rictavio_unmasked", true)
	b = _line(st)
	assert_eq(str(b["portrait"]), "van_richten", "the old hunter's face once unmasked")
	assert_eq(str(b["name"]), "Rictavio", "the name he goes by stays")
	assert_true(ResourceLoader.exists("res://art/portraits/van_richten.png"), "his portrait")
	assert_eq(DialogueBusts.path_for("van_richten"), "res://art/busts/van_richten.webp", "his bust")
	assert_eq(DialogueBusts.native_facing("res://art/busts/van_richten.webp"), str((JSON.parse_string(
		FileAccess.get_file_as_string(DialogueBusts.FACING_FILE)) as Dictionary)["facing"].get("van_richten", "")), "his facing is recorded")


func test_his_figure_stays_and_the_hud_shows_the_face() -> void:
	GameState.reset()
	var st := GameState.story
	var cr := StoryState.make_guest("rictavio")
	assert_true(cr != null, "Rictavio can fight beside the party")
	var c := Combatant.new(cr, &"guest", Vector2i.ZERO)
	assert_eq(CombatToken.art_id(c), "rictavio")
	assert_eq(CombatToken.portrait_id(c), "rictavio")
	st.set_flag("rictavio_unmasked", true)
	assert_eq(CombatToken.art_id(c), "rictavio", "his figure on the board stays the showman")
	assert_eq(CombatToken.portrait_id(c), "van_richten", "the HUD shows who he is")
	GameState.reset()


## Every creature has a portrait for the turn order and its frames (UI QA ART-06, 2026-10-08: the djinni's frame was
## empty), and the summonable ones too.
func test_every_monster_has_a_portrait() -> void:
	var c := Compendium.shared()
	for id: String in c.table("monsters"):
		var m := c.get_entry("monsters", id)
		var art := str(m.get("art", CombatToken.ART_ALIASES.get(id, id)))
		assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % art), "%s has a portrait (%s)" % [id, art])
