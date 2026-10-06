class_name CreationScreen
extends CanvasLayer
## Character creation (docs/ui/character_creation.md, approved 2026-10-06): a party strip with four slots, a steps
## rail (✓ done, ! blocking, · not started), the step panel, and the live sheet. Steps: Class, Origin, Ability
## Scores, Class Choices, Equipment, Appearance, Identity, Review. Every list, number, reason and warning comes
## from CharacterBuilder; this screen only lays them out and sends picks back. Emits finished(party) when all four
## are confirmed.

signal finished(party: Array[Character])
signal cancelled

const TAGS: Array[String] = ["blunt", "loyal", "veteran", "pious", "curious", "sly", "kind", "haunted", "brave",
	"cautious", "scholarly", "cynical", "cheerful", "proud", "greedy", "gentle"]
const LOOKS: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]

var builders: Array[CharacterBuilder] = []
var confirmed: Array[bool] = []
var slot := 0
var step := 0
var _strip: HBoxContainer
var _rail: VBoxContainer
var _body: VBoxContainer
var _sheet: VBoxContainer
var _rolled_text := ""


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
	var frame := UiKit.screen_frame(self, "Create your party", Vector2(1580, 880))
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 8)
	frame.add_child(_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)
	_rail = VBoxContainer.new()
	_rail.custom_minimum_size = Vector2(200, 0)
	row.add_child(_rail)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.scroll(_body, Vector2(930, 740)))
	_sheet = VBoxContainer.new()
	row.add_child(UiKit.scroll(_sheet, Vector2(360, 740)))
	_draw()


func b() -> CharacterBuilder:
	return builders[slot]


func _draw() -> void:
	for c in _strip.get_children():
		c.queue_free()
	for i in builders.size():
		var name_text := str(builders[i].build.get("name", ""))
		var mark := "✓ " if confirmed[i] else ("▸ " if i == slot else "")
		_strip.add_child(UiKit.button("%s%s" % [mark, name_text if name_text != "" else "Character %d" % (i + 1)], func() -> void:
			slot = i
			_draw(), 15))
	var all_done := not confirmed.has(false)
	var go := UiKit.button("Begin the adventure" if builders.size() > 1 else "Done", _finish, 16)
	go.disabled = not all_done
	go.tooltip_text = "" if all_done else "Confirm every character on their Review step first."
	_strip.add_child(go)
	_strip.add_child(UiKit.button("Back to title", func() -> void: cancelled.emit(), 14))
	for c in _rail.get_children():
		c.queue_free()
	for i in CharacterBuilder.STEP_NAMES.size():
		var status := b().step_status(i as CharacterBuilder.Step)
		var mark := "✓" if bool(status["complete"]) else "!"
		if i == CharacterBuilder.Step.APPEARANCE:
			mark = "✓"
		var btn := UiKit.button("%s %s%s" % [mark, CharacterBuilder.STEP_NAMES[i], " ◂" if i == step else ""], func() -> void:
			step = i
			_draw(), 15)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = "\n".join(status["errors"] as Array)
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
	var back := UiKit.button("Back", func() -> void:
		step = maxi(0, step - 1)
		_draw())
	back.disabled = step == 0
	nav.add_child(back)
	if step < CharacterBuilder.Step.REVIEW:
		nav.add_child(UiKit.button("Next", func() -> void:
			step += 1
			_draw()))
	_body.add_child(nav)


func _changed() -> void:
	confirmed[slot] = false
	_draw()


func _class_step() -> void:
	_body.add_child(UiKit.header("Class"))
	var row := HBoxContainer.new()
	for o in b().available_classes():
		var btn := UiKit.button(("▸ " if o.id == b().class_id() else "") + o.label, func() -> void:
			b().set_class(o.id)
			_changed(), 16)
		btn.tooltip_text = o.summary
		row.add_child(btn)
	_body.add_child(row)
	var cid := b().class_id()
	if cid == "":
		_body.add_child(UiKit.label("Pick a class. Phase 3 has the Fighter, Rogue, Cleric and Wizard with all their subclasses.", 15, "parchment", 880))
		return
	var p := b().class_preview(cid)
	_body.add_child(UiKit.label(str(p["summary"]), 15, "vellum", 880))
	_body.add_child(UiKit.label("Hit Die d%d · Primary %s · Saves %s · Complexity %s" % [int(p["hit_die"]), ", ".join(p["primary"] as Array),
		", ".join(p["saves"] as Array), p["complexity"]], 14, "parchment", 880))
	_body.add_child(UiKit.header("Levels 1-5"))
	for f: Dictionary in p["features_1_to_5"]:
		_body.add_child(UiKit.label("%d · %s: %s" % [int(f["level"]), f["name"], f["summary"]], 14, "vellum", 880))
	_body.add_child(UiKit.header("Subclasses (chosen at level %d)" % int(p["subclass_level"])))
	for s: Dictionary in p["subclasses"]:
		_body.add_child(UiKit.label("%s: %s" % [s["name"], s["summary"]], 14, "vellum", 880))


func _origin_step() -> void:
	_body.add_child(UiKit.header("Background"))
	var grid := GridContainer.new()
	grid.columns = 4
	for o in b().available_backgrounds():
		var btn := UiKit.button(("▸ " if o.id == str(b().build.get("background", "")) else "") + o.label, func() -> void:
			b().set_background(o.id)
			_changed(), 14)
		btn.tooltip_text = "%s\nAbilities: %s · Feat: %s · Skills: %s" % [o.summary, ", ".join(o.data["abilities"] as Array), o.data["feat"], ", ".join(o.data["skills"] as Array)]
		grid.add_child(btn)
	_body.add_child(grid)
	_body.add_child(UiKit.header("Species"))
	var grid2 := GridContainer.new()
	grid2.columns = 5
	for o in b().available_species():
		var btn := UiKit.button(("▸ " if o.id == str(b().build.get("species", "")) else "") + o.label, func() -> void:
			b().set_species(o.id)
			_changed(), 14)
		btn.tooltip_text = "%s\nSpeed %s · Darkvision %s" % [o.summary, str(o.data["speed"]), str(o.data["darkvision"])]
		grid2.add_child(btn)
	_body.add_child(grid2)
	_choices_step(CharacterBuilder.Step.ORIGIN)


func _ability_step() -> void:
	_body.add_child(UiKit.header("Ability scores"))
	var method := str(b().build.get("ability_method", "standard_array"))
	var row := HBoxContainer.new()
	for m: Array in [["standard_array", "Standard Array"], ["point_buy", "Point Cost (27)"], ["roll", "Random (4d6 drop lowest)"]]:
		row.add_child(UiKit.button(("▸ " if method == str(m[0]) else "") + str(m[1]), func() -> void:
			if str(m[0]) == "roll":
				var rolled := b().roll_scores(Dice.roller)
				var parts: Array[String] = []
				for r in rolled:
					parts.append("%d %s (dropped %d)" % [int(r["total"]), str(r["rolls"]), int(r["dropped"])])
				_rolled_text = "Rolled: " + " · ".join(parts)
			else:
				b().set_ability_method(str(m[0]))
			_changed(), 14))
	row.add_child(UiKit.button("Recommended", func() -> void:
		b().apply_recommended_scores()
		_changed(), 14))
	_body.add_child(row)
	if method == "roll" and _rolled_text != "":
		_body.add_child(UiKit.label(_rolled_text, 13, "parchment", 880))
	var scores := b().build.get("base_scores", {}) as Dictionary
	var pool: Array[int] = []
	if method == "standard_array":
		pool = AbilityScores.STANDARD_ARRAY.duplicate()
	elif method == "roll":
		for v: Variant in b().build.get("rolled_scores", []):
			pool.append(int(v))
	var ch := b().preview()
	for ab: StringName in Abilities.ALL:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var base := int(scores.get(str(ab), 8))
		r.add_child(UiKit.label(str(Creature.ABILITY_NAMES[ab]), 16, "vellum"))
		if method == "point_buy":
			r.add_child(UiKit.button("−", func() -> void:
				b().set_score(ab, maxi(8, base - 1))
				_changed(), 14))
			r.add_child(UiKit.label(str(base), 16, "gilt_light"))
			r.add_child(UiKit.button("+", func() -> void:
				b().set_score(ab, mini(15, base + 1))
				_changed(), 14))
		else:
			var pick := OptionButton.new()
			for v in pool:
				pick.add_item(str(v), v)
			pick.select(maxi(0, pool.find(base)))
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
		var bd := ch.ability_breakdown(ab)
		var total := UiKit.label("→ %d (%s)" % [bd.total(), UiKit.signed(ch.ability_mod(ab))], 16, "gilt_light")
		total.tooltip_text = bd.describe()
		total.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_child(total)
		_body.add_child(r)
	if method == "point_buy":
		_body.add_child(UiKit.label("Points left: %d of 27" % b().point_buy_remaining(), 15, "gilt_light"))
	for p in b().ability_problems():
		_body.add_child(UiKit.label("! " + p, 14, "vampire_red", 880))


func _choices_step(which: int) -> void:
	var list := b().choices_for_step(which as CharacterBuilder.Step)
	if which == CharacterBuilder.Step.CHOICES:
		_body.add_child(UiKit.header("Class choices"))
	if list.is_empty() and which == CharacterBuilder.Step.CHOICES:
		_body.add_child(UiKit.label("Nothing to choose yet: pick a class first.", 15, "parchment"))
	for c in list:
		var w := ChoiceWidget.create(c)
		w.picks_changed.connect(func(key: String, picks: Array) -> void:
			b().choose(key, picks)
			_changed())
		_body.add_child(w)


func _equipment_step() -> void:
	_body.add_child(UiKit.header("Starting equipment"))
	var opts := b().equipment_options()
	var chosen := b().build.get("equipment", {}) as Dictionary
	for source: String in ["class", "background"]:
		_body.add_child(UiKit.label(source.capitalize(), 16, "gilt"))
		var row := HBoxContainer.new()
		for o: Variant in opts[source]:
			var opt := o as Dictionary
			var names: Array[String] = []
			for it: Variant in opt.get("items", []):
				var itd := it as Dictionary
				names.append("%s%s" % [Compendium.shared().display_name("items", str(itd["id"])), " ×%d" % int(itd.get("qty", 1)) if int(itd.get("qty", 1)) > 1 else ""])
			if opt.has("gold"):
				names.append("%s gp" % str(opt["gold"]))
			var oid := str(opt.get("id", ""))
			var btn := UiKit.button(("▸ " if str(chosen.get(source, "")) == oid else "") + "Option %s" % oid.to_upper(), func() -> void:
				b().set_equipment(source, oid)
				_changed(), 14)
			btn.tooltip_text = ", ".join(names)
			row.add_child(btn)
			row.add_child(UiKit.label(", ".join(names), 13, "vellum", 380))
		_body.add_child(row)
	_body.add_child(UiKit.header("What it does for this character"))
	for a in b().preview().attacks():
		_body.add_child(UiKit.label(a.describe(), 14, "vellum", 880))
	_body.add_child(UiKit.label("AC with this gear: %d" % b().preview().ac_value(), 15, "gilt_light"))


func _appearance_step() -> void:
	_body.add_child(UiKit.header("Appearance"))
	_body.add_child(UiKit.label("Pick a look from the generated sprite library (more looks and palette swaps arrive with the art pass).", 14, "parchment", 880))
	var app := b().build.get("appearance", {}) as Dictionary
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for look in LOOKS:
		var col := VBoxContainer.new()
		col.add_child(UiKit.portrait(look, 140))
		col.add_child(UiKit.button(("▸ " if str(app.get("art", "")) == look else "") + look.replace("_", " ").capitalize(), func() -> void:
			var a := (b().build.get("appearance", {}) as Dictionary).duplicate()
			a["art"] = look
			b().set_appearance(a)
			_changed(), 13))
		row.add_child(col)
	_body.add_child(row)


func _identity_step() -> void:
	_body.add_child(UiKit.header("Identity"))
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
	_body.add_child(UiKit.label("Personality tags (two or three): the story reads these for party interjections.", 14, "parchment", 880))
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
	_body.add_child(UiKit.header("Review"))
	var errs := b().errors()
	if errs.is_empty():
		_body.add_child(UiKit.label("✓ Nothing blocks this character.", 15, "bile"))
	else:
		_body.add_child(UiKit.label("Blocking", 16, "vampire_red"))
		for e in errs:
			_body.add_child(UiKit.label("! " + e, 14, "vampire_red", 880))
	var warns := b().warnings()
	if not warns.is_empty():
		_body.add_child(UiKit.label("Warnings (never blocking)", 16, "gilt"))
		for w in warns:
			_body.add_child(UiKit.label("~ " + w, 14, "gilt", 880))
	var confirm := UiKit.button("Confirm %s" % str(b().build.get("name", "this character")), func() -> void:
		confirmed[slot] = true
		var next := confirmed.find(false)
		if next >= 0:
			slot = next
			step = 0
		_draw(), 16)
	confirm.disabled = not errs.is_empty()
	_body.add_child(confirm)
	var built: Array[Character] = []
	for i in builders.size():
		if builders[i].errors().is_empty():
			built.append(builders[i].preview())
	if built.size() >= 2:
		var cov := PartyCoverage.analyze(built)
		_body.add_child(UiKit.header("Party composition"))
		var roles := cov["roles"] as Dictionary
		for r: String in roles:
			var who := roles[r] as Array
			_body.add_child(UiKit.label("%s: %s" % [r.replace("_", " ").capitalize(), ", ".join(who) if not who.is_empty() else "nobody"], 14, "vellum", 880))
		for g: String in cov["gaps"]:
			_body.add_child(UiKit.label("· " + g, 13, "gilt", 880))


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
