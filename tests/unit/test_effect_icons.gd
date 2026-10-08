extends TestCase
## What's working on a hero, as icons on the party frames (owner request, 2026-10-08; ui/common/effect_icons.gd): an
## ability switched on in its own icon, a spell on them in the spell's, the spell they concentrate on once and ringed,
## nothing for the difficulty's bonus or an effect that only gives a condition (that has its tag), and each one named
## on hover.


func _hero() -> Character:
	var ch := Pregens.build("hedda_ironvow", 5)
	ch.effects.clear()
	return ch


func _names(ch: Character) -> Array[String]:
	var out: Array[String] = []
	for e in EffectIcons.entries(ch):
		out.append(str(e["name"]))
	return out


func test_abilities_and_spells_show_in_their_own_icons() -> void:
	var ch := _hero()
	ch.add_effect(Effect.new("Rage", &"feature", "rage"))
	ch.add_effect(Effect.new("Bless", &"spell", "bless"))
	ch.add_effect(Effect.new("Some Rare Gift", &"feature", "no_icon_of_its_own"))
	var list := EffectIcons.entries(ch)
	assert_eq(_names(ch), ["Rage", "Bless", "Some Rare Gift"] as Array[String])
	assert_eq(list[0]["icon"], Icons.feature("rage"), "Rage has its own icon")
	assert_ne(Icons.feature("rage"), Icons.feature("_any"))
	assert_eq(list[1]["icon"], Icons.spell("bless"), "a spell shows the spell's icon")
	assert_eq(list[2]["icon"], Icons.feature("_any"), "an ability without its own takes the rune")
	for e in list:
		assert_true(e["icon"] != null, "%s has an icon" % e["name"])


func test_concentration_once_and_first() -> void:
	var ch := _hero()
	var conc := Concentration.new(ch, "hunters_mark", "Hunter's Mark")
	ch.concentration = conc
	ch.add_effect(Effect.new("Hunter's Mark", &"spell", "hunters_mark"))
	ch.add_effect(Effect.new("Vow of Enmity", &"feature", "vow_of_enmity"))
	var list := EffectIcons.entries(ch)
	assert_eq(list.size(), 2, "the concentrated spell once")
	assert_true(bool(list[0]["concentration"]) and str(list[0]["when"]).begins_with("Concentration"))
	assert_eq(str(list[1]["name"]), "Vow of Enmity")


func test_what_isnt_shown() -> void:
	var ch := _hero()
	var story := Effect.new("Story", &"feature", "difficulty")
	story.ends = Effect.Ends.NEVER
	ch.add_effect(story)
	ch.add_effect(Effect.new("Held", &"spell", "hold_person").with_condition(&"paralyzed"))
	assert_eq(_names(ch), [] as Array[String], "the difficulty's bonus and a condition-only effect stay off")
	assert_true(EffectIcons.row(ch) == null, "no row when nothing's working")


func test_each_icon_is_named_on_hover() -> void:
	var ch := _hero()
	var fx := Effect.new("Bladesong", &"feature", "bladesong")
	fx.lasting({"kind": "minutes", "amount": 1})
	ch.add_effect(fx)
	var row := EffectIcons.row(ch, 20.0)
	add_child(row)
	var icons := row.get_children()
	assert_eq(icons.size(), 1)
	assert_eq(str((icons[0] as Control).get_meta(&"plain_tip", "")), "Bladesong", "named on hover")
	assert_eq((icons[0] as Control).mouse_filter, Control.MOUSE_FILTER_PASS, "takes the pointer")
	row.queue_free()
