class_name BestiaryPage
extends RefCounted
## The journal's Bestiary (Improvement Ideas U8): every creature the party has fought, in the order it met them, and
## beside the list what it has learned about the one picked (story/bestiary.gd). Meeting one shows its look, its kind
## and a line about it; felling one adds how tough it is and its attacks; a Study adds its defenses and traits, with
## rules words gilded (U1) and conditions as tags that open their cards. What's still unknown says how to learn it.

const LIST_W := 300.0
## Where the list was scrolled to when a creature was picked, so the page comes back the same.
static var _scroll := 0


## The page for `st`, showing `picked` (or the first creature); `on_pick` gets a monster id from a click in the list.
static func build(st: StoryState, picked: String, on_pick: Callable) -> Control:
	var ids := Bestiary.met(st)
	if ids.is_empty():
		return UiKit.label("No creatures yet. Whatever the party fights is written here: what it is, how tough it was, and what a Study taught you.", UiScale.text(16), "bone", 1060)
	if not picked in ids:
		picked = ids[0]
		_scroll = 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var left := UiParts.fill_scroll(list)
	left.name = "List"
	left.size_flags_horizontal = Control.SIZE_FILL
	left.custom_minimum_size = Vector2(LIST_W, 0)
	var keep := func(id: String) -> void:
		_scroll = left.scroll_vertical
		on_pick.call(id)
	for id in ids:
		list.add_child(_list_row(st, id, id == picked, keep))
	left.get_v_scroll_bar().changed.connect(func() -> void: left.scroll_vertical = _scroll, CONNECT_ONE_SHOT)
	row.add_child(left)
	var right := UiParts.fill_scroll(entry(st, picked))
	right.name = "Entry"
	row.add_child(right)
	return row


static func _list_row(st: StoryState, id: String, lit: bool, on_pick: Callable) -> Control:
	var d := Compendium.shared().monster_data(id)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(UiParts.framed_portrait(art(id), 40.0))
	var name_ := UiKit.label(str(d.get("name", id)), 15, "gilt_light" if lit else "vellum")
	name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_.clip_text = true
	name_.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_.custom_minimum_size = Vector2(1, 0)
	name_.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_.size_flags_vertical = Control.SIZE_FILL
	line.add_child(name_)
	var felled := int((st.bestiary[id] as Dictionary).get("defeated", 0))
	if felled > 0:
		var count := UiParts.figure("×%d" % felled, 14, "parchment")
		count.tooltip_text = "Felled by the party"
		line.add_child(count)
	var r := UiParts.click_row(line, func() -> void: on_pick.call(id), lit)
	r.name = id
	return r


## What the party knows of creature `id`.
static func entry(st: StoryState, id: String) -> Control:
	var d := Compendium.shared().monster_data(id)
	var known := Bestiary.level(st, id)
	var e := st.bestiary.get(id, {}) as Dictionary
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UiParts.framed_portrait(art(id), 132.0))
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 4)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UiKit.title(str(d.get("name", id))))
	who.add_child(UiParts.caption("%s %s" % [str(d.get("size", "")).capitalize(), str(d.get("type", "")).capitalize()], 12))
	if str(d.get("summary", "")) != "":
		who.add_child(TermText.make(str(d["summary"]), UiScale.text(15), "vellum", 630))
	var place := str(Compendium.shared().get_entry("locations", str(e.get("where", ""))).get("name", ""))
	var met := "First fought on day %d" % int(e.get("met", 1)) + (" in %s" % place if place != "" else "")
	var felled := int(e.get("defeated", 0))
	met += " · felled: %d" % felled if felled > 0 else " · none felled yet"
	who.add_child(UiKit.label(met + ".", UiScale.text(13), "parchment", 630))
	head.add_child(who)
	col.add_child(head)
	col.add_child(UiParts.section("From fighting it"))
	if known >= 2:
		col.add_child(UiKit.label(_toughness(d), UiScale.text(15), "vellum", 760))
		for a: Variant in d.get("actions", []):
			var act := a as Dictionary
			if str(act.get("summary", "")) == "":
				continue
			col.add_child(_named_line(str(act.get("name", "")), str(act["summary"])))
	else:
		col.add_child(UiKit.label("Fell one to learn how tough it is and how it fights.", UiScale.text(14), "bone", 760))
	col.add_child(UiParts.section("What a Study taught you"))
	if known >= 3:
		col.add_child(UiKit.label("Challenge %s" % _cr(d.get("cr", 0)), UiScale.text(15), "vellum"))
		for k: Array in [["resistances", "Resists"], ["vulnerabilities", "Vulnerable to"], ["immunities", "Immune to"]]:
			var v := d.get(str(k[0]), []) as Array
			if not v.is_empty():
				col.add_child(_named_line(str(k[1]), ", ".join(v.map(func(x: Variant) -> String: return str(x).capitalize()))))
		var conds := d.get("condition_immunities", []) as Array
		if not conds.is_empty():
			var tags := HFlowContainer.new()
			tags.add_theme_constant_override("h_separation", 4)
			tags.add_theme_constant_override("v_separation", 4)
			tags.add_child(UiKit.label("Can't be", UiScale.text(14), "gilt"))
			for c: Variant in conds:
				tags.add_child(UiParts.pill(str(c).capitalize(), "rose", UiScale.text(12)))
			col.add_child(tags)
		var senses := d.get("senses", {}) as Dictionary
		if not senses.is_empty():
			var parts: Array[String] = []
			for s: String in senses:
				parts.append("%s %d ft." % [s.capitalize(), int(senses[s])])
			col.add_child(_named_line("Senses", ", ".join(parts)))
		for t: Variant in d.get("traits", []):
			var tr := t as Dictionary
			if str(tr.get("summary", "")) != "":
				col.add_child(_named_line(str(tr.get("name", "")), str(tr["summary"])))
		if (d.get("resistances", []) as Array).is_empty() and (d.get("immunities", []) as Array).is_empty() \
				and (d.get("vulnerabilities", []) as Array).is_empty():
			col.add_child(UiKit.label("No resistances, immunities or weaknesses to damage.", UiScale.text(14), "parchment"))
	else:
		col.add_child(UiKit.label("Study one in a fight (an Intelligence check) to learn its defenses and traits.",
			UiScale.text(14), "bone", 760))
	return col


## "Armor Class 15 · about 90 Hit Points · Speed 10 ft., fly 90 ft."
static func _toughness(d: Dictionary) -> String:
	var hp := d.get("hp", {}) as Dictionary
	var speeds: Array[String] = []
	var sp := d.get("speed", {}) as Dictionary
	for kind: String in sp:
		speeds.append(("%d ft." if kind == "walk" else kind + " %d ft.") % int(sp[kind]))
	return "Armor Class %d · about %d Hit Points · Speed %s" % [int(d.get("ac", 10)), int(hp.get("average", 0)), ", ".join(speeds)]


static func _cr(cr: Variant) -> String:
	var f := float(cr)
	if is_equal_approx(f, 0.125):
		return "1/8"
	if is_equal_approx(f, 0.25):
		return "1/4"
	if is_equal_approx(f, 0.5):
		return "1/2"
	return str(int(f))


## A name in gilt over its words, gilded where they name rules terms.
static func _named_line(name_text: String, text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(UiKit.label(name_text, UiScale.text(15), "gilt_light"))
	box.add_child(TermText.make(text, UiScale.text(15), "vellum", 760))
	return box


## The creature's picture: its token art, as the fights show it.
static func art(id: String) -> String:
	return CombatToken.art_for(Monster.from_data(Compendium.shared().monster_data(id)))
