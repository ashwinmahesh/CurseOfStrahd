class_name CreationScreen
extends CanvasLayer
## Character creation (docs/ui/character_creation.md, approved 2026-10-06): a party strip with four slots, a steps
## rail (✓ done, ! blocking, · not started), the step panel, and the live sheet. Steps: Class, Origin, Ability
## Scores, Class Choices, Equipment, Appearance, Identity, Review. Every list, number, reason and warning comes
## from CharacterBuilder; this screen only lays them out and sends picks back. Emits finished(party) when all four
## are confirmed.
##
## Hero mode (open_hero): one custom character who takes a pregenerated companion's place. Its Appearance step is the
## paper doll (AppearancePanel: body, head, hair, beard, skin, outfit, portrait and voice), and Review weighs the party
## it will travel with.

signal finished(party: Array[Character])
signal cancelled

const TAGS: Array[String] = ["blunt", "loyal", "veteran", "pious", "curious", "sly", "kind", "haunted", "brave",
	"cautious", "scholarly", "cynical", "cheerful", "proud", "greedy", "gentle"]
const LOOKS: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]
## Text width inside the step panel.
const BODY_W := 820.0

var builders: Array[CharacterBuilder] = []
var confirmed: Array[bool] = []
var slot := 0
var step := 0
var _strip: HBoxContainer
var _rail: VBoxContainer
var _body: VBoxContainer
var _sheet: VBoxContainer
var _rolled_text := ""
## Hero mode: the pregen the hero replaces and the three who travel with them.
var hero_mode := false
var replacing := ""
var companions: Array[String] = []
var _appearance_tab := "Body"
## The player picked an outfit themselves, so a class change no longer picks one for them.
var _outfit_chosen := false


func _init() -> void:
	name = "CreationScreen"
	layer = 30


## `starting` builds (from pregens being edited) or empty builds for the four slots. `count` 1 rebuilds a single
## character (Madam Eva's respec).
func open_with(starting: Array[Dictionary], count: int = 4) -> void:
	for i in count:
		var b := CharacterBuilder.new(null, starting[i] if i < starting.size() else {})
		builders.append(b)
		confirmed.append(false)
	_build_frame("Create your party" if count > 1 else "Rebuild a character")


## One custom hero in place of the pregen `replacing_id`; `others` are the three pregens who come along.
func open_hero(replacing_id: String, others: Array[String]) -> void:
	hero_mode = true
	replacing = replacing_id
	companions = others
	var app := HeroLook.default_appearance("female")
	builders.append(CharacterBuilder.new(null, {"appearance": app, "identity": {"pronouns": "she/her", "tags": []}}))
	confirmed.append(false)
	_build_frame("Create your hero")


func _build_frame(title: String) -> void:
	var frame := UiKit.screen_frame(self, title, Vector2(1540, 830))
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 8)
	frame.add_child(_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(row)
	_rail = VBoxContainer.new()
	_rail.custom_minimum_size = Vector2(200, 0)
	_rail.add_theme_constant_override("separation", 5)
	row.add_child(_rail)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	var pane := UiParts.pane(14)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(_body))
	row.add_child(pane)
	_sheet = VBoxContainer.new()
	var side := UiParts.fill_scroll(_sheet)
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(side)
	_draw()


func b() -> CharacterBuilder:
	return builders[slot]


func _draw() -> void:
	_draw_strip()
	_draw_rest()


func _draw_strip() -> void:
	for c in _strip.get_children():
		c.queue_free()
	for i in builders.size():
		var name_text := str(builders[i].build.get("name", ""))
		var chip := UiKit.button("%s%s" % ["✓ " if confirmed[i] else "", name_text if name_text != "" else "Character %d" % (i + 1)], func() -> void:
			slot = i
			_draw(), 16)
		var art := str((builders[i].build.get("appearance", {}) as Dictionary).get("art", ""))
		var path := "res://art/portraits/%s.png" % art
		if art != "" and ResourceLoader.exists(path):
			chip.icon = load(path) as Texture2D
			chip.expand_icon = true
			chip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				chip.add_theme_color_override(k, Color.WHITE)
		chip.custom_minimum_size = Vector2(150, 46)
		if confirmed[i]:
			chip.add_theme_color_override("font_color", Look.color("bile"))
		if i == slot:
			UiParts.light_up(chip)
		_strip.add_child(chip)
	if hero_mode:
		var with := HBoxContainer.new()
		with.add_theme_constant_override("separation", 4)
		var names: Array[String] = []
		for id in companions:
			with.add_child(UiParts.framed_portrait(id, 42.0))
			names.append(str(Compendium.shared().get_entry("pregens", id).get("name", id)).get_slice(" ", 0))
		var cap := UiKit.label("Travelling with %s" % _and_list(names), 14, "parchment")
		cap.tooltip_text = "Your hero takes %s's place." % str(Compendium.shared().get_entry("pregens", replacing).get("name", replacing))
		cap.mouse_filter = Control.MOUSE_FILTER_PASS
		with.add_child(cap)
		_strip.add_child(with)
	_strip.add_child(UiParts.gap())
	_strip.add_child(UiParts.small_button("Back to title", func() -> void: cancelled.emit()))
	var all_done := not confirmed.has(false)
	var go := UiParts.primary_button("Begin the adventure" if builders.size() > 1 or hero_mode else "Done", _finish)
	go.disabled = not all_done
	go.tooltip_text = "" if all_done else "Confirm every character on their Review step first."
	_strip.add_child(go)


func _draw_rest() -> void:
	for c in _rail.get_children():
		c.queue_free()
	_rail.add_child(UiParts.caption("Steps", 12))
	for i in CharacterBuilder.STEP_NAMES.size():
		var status := b().step_status(i as CharacterBuilder.Step)
		var done := bool(status["complete"]) or i == CharacterBuilder.Step.APPEARANCE
		var errors := "\n".join(status["errors"] as Array)
		var step_name := str(CharacterBuilder.STEP_NAMES[i])
		var btn := UiParts.tip_button("%s  %s" % ["✓" if done else "!", step_name], func() -> void:
			step = i
			_draw(), func() -> Control:
				return UiParts.rules_tip(step_name, "Done" if done else "Needs attention", errors), i == step, 16)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i != step:
			btn.add_theme_color_override("font_color", Look.color("vellum" if done else "flame"))
		if errors == "":
			btn.tip = Callable()
			btn.tooltip_text = ""
		_rail.add_child(btn)
	for c in _body.get_children():
		c.queue_free()
	for c in _sheet.get_children():
		c.queue_free()
	_sheet.add_child(LiveSheet.build(b().preview()))
	match step:
		CharacterBuilder.Step.CLASS:
			_class_step()
		CharacterBuilder.Step.ORIGIN:
			_origin_step()
		CharacterBuilder.Step.ABILITIES:
			_ability_step()
		CharacterBuilder.Step.CHOICES:
			_choices_step(CharacterBuilder.Step.CHOICES)
		CharacterBuilder.Step.EQUIPMENT:
			_equipment_step()
		CharacterBuilder.Step.APPEARANCE:
			_appearance_step()
		CharacterBuilder.Step.IDENTITY:
			_identity_step()
		CharacterBuilder.Step.REVIEW:
			_review_step()
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	nav.add_child(UiParts.gap())
	var back := UiKit.button("Back", func() -> void:
		step = maxi(0, step - 1)
		_draw())
	back.disabled = step == 0
	nav.add_child(back)
	if step < CharacterBuilder.Step.REVIEW:
		var next := UiKit.button("Next", func() -> void:
			step += 1
			_draw())
		UiParts.light_up(next)
		nav.add_child(next)
	_body.add_child(nav)


func _changed() -> void:
	confirmed[slot] = false
	_draw()


func _class_step() -> void:
	_body.add_child(UiParts.section("Class"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for o in b().available_classes():
		var label := o.label
		var summary := o.summary
		var btn := UiParts.tip_button(o.label, func() -> void:
			b().set_class(o.id)
			_suit_outfit()
			_changed(), func() -> Control: return UiParts.rules_tip(label, "", summary), o.id == b().class_id(), 16)
		btn.custom_minimum_size = Vector2(130, 40)
		grid.add_child(btn)
	_body.add_child(grid)
	var cid := b().class_id()
	if cid == "":
		_body.add_child(UiKit.label("Pick a class to see what it does at levels 1 to 5 and the subclasses it can take.", 15, "parchment", BODY_W))
		return
	var p := b().class_preview(cid)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := UiKit.title(str(p["name"]))
	t.add_theme_font_size_override("font_size", 26)
	head.add_child(t)
	head.add_child(UiKit.label(str(p["summary"]), 15, "vellum", BODY_W))
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 8)
	for f: Array in [["Hit Die", "d%d" % int(p["hit_die"])], ["Primary", ", ".join(p["primary"] as Array).capitalize()],
			["Saves", ", ".join(p["saves"] as Array).to_upper()], ["Complexity", str(p["complexity"]).capitalize()]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.add_child(UiParts.caption(str(f[0]), 10))
		box.add_child(UiParts.figure(str(f[1]), 18))
		var tile := UiParts.card("ui_black", "gilt_dark", 0.8, 6)
		tile.custom_minimum_size = Vector2(150, 0)
		tile.add_child(box)
		facts.add_child(tile)
	head.add_child(facts)
	_body.add_child(UiParts.row(head, Callable(), false, 12))
	_body.add_child(UiParts.section("Levels 1 to 5"))
	for f: Dictionary in p["features_1_to_5"]:
		_body.add_child(UiParts.feature_row(f, "Level %d" % int(f["level"]), BODY_W))
	_body.add_child(UiParts.section("Subclasses (chosen at level %d)" % int(p["subclass_level"])))
	for sub: Dictionary in p["subclasses"]:
		_body.add_child(UiParts.feature_row(sub, "", BODY_W))


func _origin_step() -> void:
	_body.add_child(UiParts.section("Background"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for o in b().available_backgrounds():
		var label := o.label
		var summary := o.summary
		var facts := [["Abilities", ", ".join(o.data["abilities"] as Array).to_upper()], ["Feat", str(o.data["feat"])],
			["Skills", ", ".join(o.data["skills"] as Array).replace("_", " ").capitalize()]]
		var btn := UiParts.tip_button(o.label, func() -> void:
			b().set_background(o.id)
			_changed(), func() -> Control: return UiParts.rules_tip(label, "Background", summary, facts),
			o.id == str(b().build.get("background", "")), 15)
		btn.custom_minimum_size = Vector2(196, 36)
		grid.add_child(btn)
	_body.add_child(grid)
	_body.add_child(UiParts.section("Species"))
	var grid2 := GridContainer.new()
	grid2.columns = 5
	grid2.add_theme_constant_override("h_separation", 6)
	grid2.add_theme_constant_override("v_separation", 6)
	for o in b().available_species():
		var label := o.label
		var summary := o.summary
		var facts := [["Speed", "%s ft" % str(o.data["speed"])], ["Darkvision", "%s ft" % str(o.data["darkvision"]) if int(o.data["darkvision"]) > 0 else "none"]]
		var btn := UiParts.tip_button(o.label, func() -> void:
			b().set_species(o.id)
			_changed(), func() -> Control: return UiParts.rules_tip(label, "Species", summary, facts),
			o.id == str(b().build.get("species", "")), 15)
		btn.custom_minimum_size = Vector2(156, 36)
		grid2.add_child(btn)
	_body.add_child(grid2)
	_choices_step(CharacterBuilder.Step.ORIGIN)


func _ability_step() -> void:
	_body.add_child(UiParts.section("Ability scores"))
	var method := str(b().build.get("ability_method", "standard_array"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for m: Array in [["standard_array", "Standard Array"], ["point_buy", "Point Cost (27)"], ["roll", "Random (4d6 drop lowest)"]]:
		var mb := UiKit.button(str(m[1]), func() -> void:
			if str(m[0]) == "roll":
				var rolled := b().roll_scores(Dice.roller)
				var parts: Array[String] = []
				for r in rolled:
					parts.append("%d %s (dropped %d)" % [int(r["total"]), str(r["rolls"]), int(r["dropped"])])
				_rolled_text = "Rolled: " + " · ".join(parts)
			else:
				b().set_ability_method(str(m[0]))
			_changed(), 15)
		if method == str(m[0]):
			UiParts.light_up(mb)
		row.add_child(mb)
	row.add_child(UiParts.gap())
	row.add_child(UiKit.button("Recommended", func() -> void:
		b().apply_recommended_scores()
		_changed(), 15))
	_body.add_child(row)
	if method == "roll" and _rolled_text != "":
		_body.add_child(UiKit.label(_rolled_text, 13, "parchment", BODY_W))
	var scores := b().build.get("base_scores", {}) as Dictionary
	var pool: Array[int] = []
	if method == "standard_array":
		pool = AbilityScores.STANDARD_ARRAY.duplicate()
	elif method == "roll":
		for v: Variant in b().build.get("rolled_scores", []):
			pool.append(int(v))
	var ch := b().preview()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	for ab: StringName in Abilities.ALL:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var base := int(scores.get(str(ab), 8))
		var full := str(Creature.ABILITY_NAMES[ab])
		col.add_child(UiParts.medallion(full, ch.ability_mod(ab), ch.ability_score(ab), func() -> Control:
			return UiParts.breakdown_tip(ch.ability_breakdown(ab), full, "%d (%s)" % [ch.ability_score(ab), UiKit.signed(ch.ability_mod(ab))])))
		var cap := UiParts.caption("Base score", 10)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		if method == "point_buy":
			r.add_child(UiParts.small_button("−", func() -> void:
				b().set_score(ab, maxi(8, base - 1))
				_changed()))
			r.add_child(UiParts.figure(str(base), 18, "gilt_light"))
			r.add_child(UiParts.small_button("+", func() -> void:
				b().set_score(ab, mini(15, base + 1))
				_changed()))
		else:
			var pick := OptionButton.new()
			for v in pool:
				pick.add_item(str(v), v)
			pick.select(maxi(0, pool.find(base)))
			pick.custom_minimum_size = Vector2(80, 0)
			pick.item_selected.connect(func(idx: int) -> void:
				var v2 := pool[idx]
				# Swap with the ability that had this value, so the array stays a permutation.
				var s2 := (b().build.get("base_scores", {}) as Dictionary).duplicate()
				for other: StringName in Abilities.ALL:
					if other != ab and int(s2.get(str(other), 0)) == v2:
						s2[str(other)] = base
						break
				s2[str(ab)] = v2
				b().set_base_scores(s2)
				_changed())
			r.add_child(pick)
		col.add_child(r)
		var bonus := ch.ability_score(ab) - base
		if bonus != 0:
			var from := UiKit.label("%s from bonuses" % UiKit.signed(bonus), 12, "bile")
			from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(from)
		cols.add_child(col)
	_body.add_child(UiParts.row(cols, Callable(), false, 12))
	if method == "point_buy":
		_body.add_child(UiKit.label("Points left: %d of 27" % b().point_buy_remaining(), 15, "gilt_light"))
	for p in b().ability_problems():
		_body.add_child(UiKit.label("! " + p, 14, "vampire_red", BODY_W))


func _choices_step(which: int) -> void:
	var list := b().choices_for_step(which as CharacterBuilder.Step)
	if which == CharacterBuilder.Step.CHOICES:
		_body.add_child(UiParts.section("Class choices"))
	if list.is_empty() and which == CharacterBuilder.Step.CHOICES:
		_body.add_child(UiKit.label("Nothing to choose yet: pick a class first.", 15, "parchment"))
	for c in list:
		var w := ChoiceWidget.create(c)
		w.picks_changed.connect(func(key: String, picks: Array) -> void:
			b().choose(key, picks)
			_changed())
		_body.add_child(w)


func _equipment_step() -> void:
	var opts := b().equipment_options()
	var chosen := b().build.get("equipment", {}) as Dictionary
	for source: String in ["class", "background"]:
		_body.add_child(UiParts.section("%s equipment" % source.capitalize()))
		for o: Variant in opts[source]:
			var opt := o as Dictionary
			var names: Array[String] = []
			for it: Variant in opt.get("items", []):
				var itd := it as Dictionary
				names.append("%s%s" % [Compendium.shared().display_name("items", str(itd["id"])), " ×%d" % int(itd.get("qty", 1)) if int(itd.get("qty", 1)) > 1 else ""])
			if opt.has("gold"):
				names.append("%s gp" % str(opt["gold"]))
			var oid := str(opt.get("id", ""))
			var picked := str(chosen.get(source, "")) == oid
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var btn := UiKit.button("Option %s" % oid.to_upper(), func() -> void:
				b().set_equipment(source, oid)
				_changed(), 15)
			btn.custom_minimum_size = Vector2(120, 0)
			if picked:
				UiParts.light_up(btn)
			row.add_child(btn)
			row.add_child(UiKit.label(", ".join(names), 14, "vellum" if picked else "parchment", 660))
			_body.add_child(UiParts.row(row, Callable(), picked))
	_body.add_child(UiParts.section("What it does for this character"))
	var pv := b().preview()
	for a in pv.attacks():
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		var n := UiKit.label(a.name, 16, "vellum")
		n.custom_minimum_size = Vector2(220, 0)
		row2.add_child(n)
		row2.add_child(UiParts.figure(a.attack.signed(), 18, "gilt_light"))
		row2.add_child(UiKit.label("to hit", 12, "parchment"))
		var bonus := a.damage_bonus.total()
		row2.add_child(UiParts.figure(str(int(a.damage_dice) + bonus) if a.damage_dice.is_valid_int() else a.damage_dice + ("%+d" % bonus if bonus != 0 else ""), 18))
		row2.add_child(UiKit.label(str(a.damage_type).capitalize(), 13, "parchment"))
		if a.mastery != "":
			row2.add_child(UiParts.pill(a.mastery.capitalize(), "moonlight"))
		_body.add_child(UiParts.row(row2, func() -> Control: return UiParts.breakdown_tip(a.attack, a.name, "%s to hit" % a.attack.signed())))
	var ac_row := HBoxContainer.new()
	ac_row.add_theme_constant_override("separation", 10)
	ac_row.add_child(UiKit.label("Armor Class with this gear", 15, "parchment"))
	ac_row.add_child(UiParts.figure(str(pv.ac_value()), 20, "gilt_light"))
	_body.add_child(UiParts.row(ac_row, func() -> Control: return UiParts.breakdown_tip(pv.armor_class(), "Armor Class")))


func _appearance_step() -> void:
	var app := b().build.get("appearance", {}) as Dictionary
	if bool(app.get("custom", false)):
		_body.add_child(UiParts.section("Appearance"))
		var panel := AppearancePanel.create(app, str(b().build.get("species", "human")), b().class_id(), _appearance_tab)
		panel.tab_changed.connect(func(t: String) -> void: _appearance_tab = t)
		panel.changed.connect(func(a: Dictionary) -> void:
			var before := b().build.get("appearance", {}) as Dictionary
			if str(a.get("outfit", "")) != str(before.get("outfit", "")):
				_outfit_chosen = true
			var portrait_changed := str(a.get("portrait", "")) != str(before.get("portrait", ""))
			_follow_gender(before, a)
			b().set_appearance(a)
			if portrait_changed:
				_draw_strip())
		_body.add_child(panel)
		return
	_body.add_child(UiParts.section("Appearance"))
	_body.add_child(UiKit.label("Pick a look from the generated sprite library (more looks and palette swaps arrive with the art pass).", 14, "parchment", BODY_W))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for look in LOOKS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.add_child(UiParts.framed_portrait(look, 170.0))
		var btn := UiKit.button(look.replace("_", " ").capitalize(), func() -> void:
			var a := (b().build.get("appearance", {}) as Dictionary).duplicate()
			a["art"] = look
			b().set_appearance(a)
			_changed(), 14)
		if str(app.get("art", "")) == look:
			UiParts.light_up(btn)
		col.add_child(btn)
		row.add_child(col)
	_body.add_child(row)


## A hero whose pronouns are still the old gender's usual ones gets the new gender's.
func _follow_gender(before: Dictionary, after: Dictionary) -> void:
	var g0 := str(before.get("gender", ""))
	var g1 := str(after.get("gender", ""))
	if g0 == g1:
		return
	var usual := {"female": "she/her", "male": "he/him"}
	var idn := (b().build.get("identity", {}) as Dictionary).duplicate(true)
	if str(idn.get("pronouns", "")) in ["", str(usual.get(g0, ""))]:
		idn["pronouns"] = str(usual.get(g1, ""))
		b().set_identity(idn)


## In hero mode, until the player picks an outfit themselves, the class picks the one that suits it.
func _suit_outfit() -> void:
	var app := (b().build.get("appearance", {}) as Dictionary)
	if not bool(app.get("custom", false)) or _outfit_chosen:
		return
	var fresh := HeroLook.default_appearance(str(app.get("gender", "female")), b().class_id())
	var a := app.duplicate()
	a["outfit"] = fresh["outfit"]
	b().set_appearance(a)


static func _and_list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names.back()]


func _identity_step() -> void:
	_body.add_child(UiParts.section("Identity"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Name"
	name_edit.text = str(b().build.get("name", ""))
	name_edit.custom_minimum_size = Vector2(400, 0)
	name_edit.text_submitted.connect(func(t: String) -> void:
		b().set_name(t)
		_changed())
	name_edit.focus_exited.connect(func() -> void:
		if name_edit.text != str(b().build.get("name", "")):
			b().set_name(name_edit.text)
			_changed.call_deferred())
	_body.add_child(name_edit)
	var identity := (b().build.get("identity", {}) as Dictionary).duplicate(true)
	var pron := LineEdit.new()
	pron.placeholder_text = "Pronouns (e.g. she/her, he/him, they/them)"
	pron.text = str(identity.get("pronouns", ""))
	pron.custom_minimum_size = Vector2(400, 0)
	pron.text_changed.connect(func(t: String) -> void:
		var idn := (b().build.get("identity", {}) as Dictionary).duplicate(true)
		idn["pronouns"] = t
		b().set_identity(idn))
	_body.add_child(pron)
	_body.add_child(UiKit.label("Personality tags (two or three): the story reads these for party interjections.", 14, "parchment", BODY_W))
	var tags := identity.get("tags", []) as Array
	var grid := GridContainer.new()
	grid.columns = 6
	for t in TAGS:
		var cb := CheckBox.new()
		cb.text = t
		cb.button_pressed = t in tags
		cb.toggled.connect(func(on: bool) -> void:
			var idn := (b().build.get("identity", {}) as Dictionary).duplicate(true)
			var tg: Array = (idn.get("tags", []) as Array).duplicate()
			if on and not t in tg:
				tg.append(t)
			elif not on:
				tg.erase(t)
			idn["tags"] = tg
			b().set_identity(idn))
		grid.add_child(cb)
	_body.add_child(grid)


func _review_step() -> void:
	_body.add_child(UiParts.section("Review"))
	var errs := b().errors()
	if errs.is_empty():
		_body.add_child(UiParts.row(UiKit.label("✓ Nothing blocks this character.", 16, "bile")))
	else:
		for e in errs:
			_body.add_child(UiParts.row(UiKit.label("! " + e, 15, "vampire_red", BODY_W)))
	var warns := b().warnings()
	if not warns.is_empty():
		_body.add_child(UiParts.caption("Warnings (never blocking)", 12, "gilt"))
		for w in warns:
			_body.add_child(UiParts.row(UiKit.label("~ " + w, 14, "gilt", BODY_W)))
	var confirm := UiParts.primary_button("Confirm %s" % str(b().build.get("name", "this character")), func() -> void:
		confirmed[slot] = true
		var next := confirmed.find(false)
		if next >= 0:
			slot = next
			step = 0
		_draw())
	confirm.disabled = not errs.is_empty()
	_body.add_child(confirm)
	var built: Array[Character] = []
	for i in builders.size():
		if builders[i].errors().is_empty():
			built.append(builders[i].preview())
	for id in companions:
		var mate := Pregens.build(id, 1)
		if mate != null:
			built.append(mate)
	if built.size() >= 2:
		var cov := PartyCoverage.analyze(built)
		_body.add_child(UiParts.section("Party composition"))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		var roles := cov["roles"] as Dictionary
		for r: String in roles:
			var who := roles[r] as Array
			grid.add_child(UiParts.caption(r.replace("_", " "), 11))
			grid.add_child(UiKit.label(", ".join(who) if not who.is_empty() else "nobody", 14, "vellum" if not who.is_empty() else "rose"))
		_body.add_child(UiParts.row(grid))
		for g: String in cov["gaps"]:
			_body.add_child(UiKit.label("◇ " + g, 13, "gilt", BODY_W))


func _finish() -> void:
	var party: Array[Character] = []
	for bb in builders:
		var ch := bb.build_character()
		if ch == null:
			return
		if str((ch.build.get("appearance", {}) as Dictionary).get("art", "")) == "":
			var app := (ch.build.get("appearance", {}) as Dictionary).duplicate()
			app["art"] = CombatToken.default_look(ch)
			ch.build["appearance"] = app
		ch.finish_long_rest()
		party.append(ch)
	finished.emit(party)
