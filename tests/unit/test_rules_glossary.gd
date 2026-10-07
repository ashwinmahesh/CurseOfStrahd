extends TestCase
## U1, rules words you can hover and pin: one glossary in our own words behind every gilded word, text that gilds the
## right words (and not the names that merely contain them), and cards that nest, pin and stay on screen.


func before_each() -> void:
	# The headless pointer rests nowhere, so cards here open and close only when the test asks.
	if TipCards.current != null:
		TipCards.current.hold = true


func after_each() -> void:
	if TipCards.current != null:
		TipCards.current.clear()
		TipCards.current.hold = false


func _terms_file() -> Array:
	return (JSON.parse_string(FileAccess.get_file_as_string(Glossary.PATH)) as Dictionary)["terms"] as Array


func test_every_term_is_complete_and_unique() -> void:
	var ids := {}
	var phrases := {}
	for v: Variant in _terms_file():
		var raw := v as Dictionary
		var id := str(raw["id"])
		assert_false(ids.has(id), "%s listed once" % id)
		ids[id] = true
		var e := Glossary.entry(id)
		assert_true(str(e.get("name", "")) != "", "%s has a name" % id)
		assert_true(str(e.get("kind", "")) != "", "%s has a kind" % id)
		assert_true(str(e.get("text", "")).length() > 20, "%s has its text (borrowed from %s)" % [id, raw.get("from", "itself")])
		assert_false(str(e["text"]).contains("["), "%s: plain text, no markup" % id)
		for p: Variant in raw.get("match", [e["name"]]):
			assert_false(phrases.has(str(p)), "'%s' opens only one term (%s, %s)" % [p, phrases.get(str(p), ""), id])
			phrases[str(p)] = id
	for id: String in Glossary.ids():
		for s: Variant in Glossary.entry(id).get("see", []):
			assert_true(Glossary.has(str(s)), "%s: See also %s is a term" % [id, s])
			assert_ne(str(s), id, "%s doesn't send you to itself" % id)


func test_conditions_actions_and_weapon_rules_all_have_terms() -> void:
	for c: Dictionary in Compendium.shared().all("conditions"):
		assert_true(Glossary.has(str(c["id"])), "condition %s" % c["id"])
		assert_eq(Glossary.entry(str(c["id"]))["text"], c["text"], "%s's text comes from its data" % c["id"])
	for key: String in ActionCatalog.PROPERTY_TEXT:
		assert_true(Glossary.has("property_" + key), "weapon property %s" % key)
	for key: String in ActionCatalog.MASTERY_TEXT:
		assert_true(Glossary.has("mastery_" + key), "mastery %s" % key)
	for word: String in ["Prone", "Concentration", "Bloodied", "Graze", "Heroic Inspiration", "Advantage", "Bonus Action"]:
		assert_true(Glossary.id_for(word) != "", "%s is a term" % word)


func test_gilds_the_first_mention_of_each_term() -> void:
	var found := Glossary.found("You have Advantage on attack rolls while Prone, and Advantage again on your next attack roll.")
	assert_eq(found, ["advantage", "attack_roll", "prone"] as Array[String])
	var bb := Glossary.bbcode("You have Advantage on attack rolls while Prone, and Advantage again.")
	assert_eq(bb.count("[url=term:advantage]"), 1, "first mention only: " + bb)
	assert_true(bb.contains("[url=term:prone]Prone[/url]"), bb)
	assert_false(Glossary.bbcode("Prone and Advantage", ["prone"]).contains("term:prone"), "a card's own term stays plain")
	assert_true(Glossary.bbcode("a [bracket]").contains("[lb]bracket]"), "brackets in the text are escaped")


func test_longest_term_wins() -> void:
	assert_eq(Glossary.found("You gain 5 Temporary Hit Points."), ["temporary_hit_points"] as Array[String])
	assert_eq(Glossary.found("Make a ranged spell attack roll."), ["spell_attack"] as Array[String])
	assert_eq(Glossary.found("Spend Hit Point Dice to heal."), ["hit_point_dice"] as Array[String])
	assert_eq(Glossary.found("Your spell save DC is 14."), ["spell_save_dc"] as Array[String])


func test_names_that_contain_a_term_stay_plain() -> void:
	for text: String in ["You cast Cone of Cold.", "It casts Flaming Sphere.", "You wear Heavy Armor.",
			"Choose Protector (Martial weapons, Heavy armor) or Thaumaturge.", "Proficient with Light armor and Shields.",
			"Cast the Slow spell.", "A Light Crossbow.", "Magic Missile strikes."]:
		assert_eq(Glossary.found(text), [] as Array[String], text)
	assert_eq(Glossary.found("Martial melee weapon: 1d8 Bludgeoning; mastery Slow."), ["mastery_slow"] as Array[String])
	assert_eq(Glossary.found("1d4 Piercing, Finesse, Light, Thrown"), ["property_finesse", "property_light", "property_thrown"] as Array[String])
	assert_eq(Glossary.found("Take the Magic action."), ["action_magic"] as Array[String])
	assert_eq(Glossary.found("When Concentration ends, Your Speed returns."), ["concentration", "speed"] as Array[String])
	assert_eq(Glossary.found("A 20-foot Cone of fire."), ["cone"] as Array[String])


func test_rules_tips_gild_their_words() -> void:
	var tip := UiParts.rules_tip("Prone", "Condition", "You're Prone: Disadvantage on attack rolls.", [["Duration", "Concentration, up to 1 minute"]])
	var texts := tip.find_children("*", "TermText", true, false)
	assert_true(texts.size() >= 2, "the facts and the body are gilded text")
	var all := ""
	for t in texts:
		all += (t as TermText).text
	assert_true(all.contains("term:concentration") and all.contains("term:disadvantage"), all)
	assert_false(all.contains("term:prone"), "the tip's own condition stays plain")
	tip.free()


func test_rich_tips_open_as_cards_not_engine_tooltips() -> void:
	var d := UiParts.drawn(Vector2(10, 10), func(_c: Control) -> void: pass, func() -> Control: return Label.new(), "10 / 20")
	assert_eq(d.tooltip_text, "", "no engine tooltip under the card")
	assert_eq(str(d.get_meta(&"plain_tip", "")), "10 / 20")
	assert_true(TipCards.tip_of(d).is_valid())
	var b := UiParts.tip_button("Go", func() -> void: pass, func() -> Control: return Label.new())
	assert_eq(b.tooltip_text, "")
	var tag := UiParts.pill("Bloodied", "rose")
	assert_true(TipCards.tip_of(tag).is_valid(), "a rules term's tag opens its card")
	var plain := UiParts.pill("Open", "moonlight")
	assert_false(TipCards.tip_of(plain).is_valid(), "other tags don't")
	for n: Node in [d, b, tag, plain]:
		n.free()


func test_cards_nest_pin_and_close() -> void:
	var layer := TipCards.current
	assert_true(layer != null, "UiFeel made the card layer")
	var host := TermText.make("Prone", 14)
	add_child(host)
	var outer := layer.open_card({"key": "term:prone", "control": host, "term": "prone"}, Vector2(200, 200))
	assert_true(outer != null and outer.parent_card == null)
	# A gilded word inside the Prone card opens a card beside it, chained to it.
	var inner_text := outer.find_children("*", "TermText", true, false)[0] as TermText
	assert_true(inner_text.text.contains("term:attack_roll"), inner_text.text)
	var inner := layer.open_card({"key": "term:attack_roll", "control": inner_text, "term": "attack_roll"}, Vector2(260, 240))
	assert_eq(inner.parent_card, outer, "the nested card knows its parent")
	await get_tree().process_frame
	assert_true(inner.position.x >= outer.get_global_rect().end.x or inner.get_global_rect().end.x <= outer.position.x,
		"the nested card sits beside its parent, not over it")
	assert_false(outer.settled, "a fresh card lets the pointer pass through, like a tooltip")
	assert_eq(outer.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)
	outer.settling(TipCards.SETTLE, TipCards.SETTLE)
	assert_true(outer.settled and outer.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED, "settled, it takes the pointer")
	layer.toggle_pin(inner)
	assert_true(inner.pinned and inner.parent_card == null, "a pinned card stands on its own")
	assert_true(inner.settled, "and takes the pointer at once")
	# Another control's card replaces the unpinned chain; the pinned card stays.
	var other := layer.open_card({"key": "term:advantage", "control": host, "term": "advantage"}, Vector2(600, 300))
	assert_false(outer in layer.cards, "the old chain closed")
	assert_true(inner in layer.cards and other in layer.cards)
	layer.pin_term("advantage", host)
	assert_true(other.pinned, "clicking the gilded word pins the card already showing for it")
	assert_eq(layer.pinned_count(), 2)
	for i in TipCards.MAX_PINS + 2:
		layer.pin_term("speed", host)
	assert_true(layer.pinned_count() <= TipCards.MAX_PINS, "at most %d pinned" % TipCards.MAX_PINS)
	layer.clear()
	assert_eq(layer.cards.size(), 0)
	host.queue_free()


func test_every_card_fits_on_screen() -> void:
	var layer := TipCards.current
	var host := TermText.make("x", 14)
	add_child(host)
	var screen := layer.get_viewport().get_visible_rect().size
	for id: String in Glossary.ids():
		var c := layer.open_card({"key": "term:" + id, "control": host, "term": id}, screen - Vector2(5, 5))
		await get_tree().process_frame
		var r := c.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, screen).encloses(r), "%s's card stays on screen (%s)" % [id, r])
		assert_true(r.size.x <= TipCard.TERM_WIDTH + 60.0, "%s's card keeps its width (%s)" % [id, r.size])
		layer.clear()
	# A long spell's card scrolls inside the screen rather than running off it.
	var spell := Compendium.shared().spell_data("wish")
	var long := layer.open_card({"key": "tip:1", "control": host, "tip": func() -> Control:
		return UiParts.rules_tip("Wish", "Level 9 Conjuration", str(spell.get("text", "")) + "\n\n" + str(spell.get("text", "")))},
		Vector2(40, 40))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(Rect2(Vector2.ZERO, screen).encloses(long.get_global_rect()), "the long card fits (%s)" % long.get_global_rect())
	layer.clear()
	host.queue_free()
