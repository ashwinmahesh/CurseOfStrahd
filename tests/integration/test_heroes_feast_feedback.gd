extends TestCase
## Heroes' Feast says that it took (owner's playtest, 2026-10-18: the spell worked, but nothing on screen or in the
## speakers told him so). Cast while exploring, the party's frames name the feast with the time it has left, the feast is
## written up in the Narrator's box and a toast, each fed hero gets the cast's light and the table's sound plays
## (story/field_casting.gd, world/exploration/location_magic.gd, world/combat/fx/fx_bodies.gd).

const LOC := {
	"id": "test_feast_hall", "name": "Test Feast Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
}

var root: Node
var said: Array[String] = []
var toasts: Array[String] = []


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_feast_hall"] = LOC.duplicate(true)
	GameState.reset()
	var cleric := TestChars.custom("cleric", "human", 11)
	var prepared := (cleric.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "heroes_feast" in prepared:
		prepared.append("heroes_feast")
	TestCombat.give_components(cleric, ["heroes_feast"])
	cleric.finish_long_rest()
	GameState.story.party.append(cleric)
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 9)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.gold = 1500.0
	GameState.story.location = "test_feast_hall"
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	said.clear()
	toasts.clear()
	_view().narration.connect(func(text: String) -> void: said.append(text))
	_view().toast.connect(func(text: String) -> void: toasts.append(text))


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("test_feast_hall")


func _view() -> LocationView:
	return root.get("view") as LocationView


## The cast as the character sheet does it: the engine takes the bowl and the hour, then the world shows it.
func _cast() -> Dictionary:
	var res := FieldCasting.cast_utility(GameState.story, GameState.story.party[0], "heroes_feast", false)
	assert_true(bool(res["ok"]), str(res["text"]))
	_view().apply_spell_effect(str(res["effect"]))
	return res


func _feast_of(ch: Character) -> Effect:
	for fx: Effect in ch.effects:
		if fx.source_id == "heroes_feast":
			return fx
	return null


func test_the_feast_still_does_its_work() -> void:
	var before: Array[int] = []
	for ch in GameState.story.party:
		before.append(ch.max_hp())
	_cast()
	for i in GameState.story.party.size():
		var ch := GameState.story.party[i]
		var gain := ch.max_hp() - before[i]
		assert_true(gain >= 2 and gain <= 20, "%s: 2d10 more Hit Points at most, got %d" % [ch.name, gain])
		assert_eq(ch.hp, ch.max_hp(), "%s gains as many Hit Points as the maximum rose" % ch.name)
		assert_true(ch.is_condition_immune(&"frightened") and ch.is_condition_immune(&"poisoned"), ch.name)
		assert_eq(_feast_of(ch).minutes_left, 24 * 60, "a day")


func test_a_toast_and_the_narrators_box_say_the_party_ate() -> void:
	_cast()
	assert_eq(toasts.size(), 1, "one toast: %s" % str(toasts))
	assert_eq(said.size(), 1, "one note in the Narrator's box: %s" % str(said))
	if toasts.is_empty() or said.is_empty():
		return
	assert_true("Heroes' Feast" in toasts[0] and "24 hours" in toasts[0], toasts[0])
	for ch in GameState.story.party:
		var gain := int(_feast_of(ch).modifiers[0].number("value"))
		assert_true(("%s +%d" % [ch.name.get_slice(" ", 0), gain]) in said[0], "%s's share of the Hit Points: %s" % [ch.name, said[0]])
	assert_true("poison" in said[0] and "fear" in said[0], "what it protects against: %s" % said[0])


func test_each_fed_hero_gets_the_cast_light() -> void:
	_cast()
	var fx: SpellFx = null
	for c in _view().get_children():
		if c is SpellFx:
			fx = c as SpellFx
	assert_true(fx != null, "the view plays the cast")
	if fx == null:
		return
	assert_eq(str(fx.last_cue.get("key", "")), "heroes_feast")
	assert_eq(str(fx.last_cue.get("family", "")), "feast", "its own look, not a plain heal")
	await get_tree().create_timer(0.6).timeout
	var emitters := fx.find_children("*", "GPUParticles3D", true, false)
	assert_true(emitters.size() >= GameState.story.party.size(), "motes on each of the %d heroes: %d" % [GameState.story.party.size(), emitters.size()])


func test_the_cast_sounds_the_table_and_the_chime() -> void:
	var cue := SpellFx.spell_cue("heroes_feast")
	var ids: Array[String] = []
	for entry in CombatSfx.ids_for(cue, "cast"):
		ids.append(entry.get_slice("@", 0))   # "<id>@<seconds>" comes in a moment after the others
	assert_true("feast_plates" in ids and "feast_clink" in ids, "plates and goblets: %s" % str(ids))
	assert_true("heal" in ids or "radiant_chime" in ids, "and a healing chime: %s" % str(ids))
	for id in ids:
		assert_false(Audio.files("sfx", id).is_empty(), "%s has a recording" % id)


func test_the_party_frames_name_the_feast_and_its_time_left() -> void:
	_cast()
	var ch := GameState.story.party[1]
	var entry := {}
	for e in EffectIcons.entries(ch):
		if str(e["key"]) == "spell:heroes_feast":
			entry = e
	assert_false(entry.is_empty(), "the feast is on the frame")
	assert_eq(str(entry["when"]), "24 hours left")
	assert_eq(entry["icon"], Icons.spell("heroes_feast"))
	GameState.story.advance_minutes(90)
	for e in EffectIcons.entries(ch):
		if str(e["key"]) == "spell:heroes_feast":
			assert_eq(str(e["when"]), "22 hours 30 minutes left")


func test_the_sheet_reads_the_time_left_in_hours() -> void:
	_cast()
	assert_eq(_feast_of(GameState.story.party[1]).describe_duration(), "24 h")
	GameState.story.advance_minutes(25)
	assert_eq(_feast_of(GameState.story.party[1]).describe_duration(), "23 h 35 min")
