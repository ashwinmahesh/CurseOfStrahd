class_name AppearancePanel
extends HBoxContainer
## The custom hero's Appearance step (docs/ui/character_creation.md): the picks from art/creator/catalog.json in
## four tabs (Body: gender, build, height, skin; Head: head, hair, hair colour, beard; Outfit; Portrait and voice),
## beside the live sprite (HeroPreview). Heads, hairstyles and beards show as small pictures of this hero's own head
## with that pick; skin tones and hair colours as arched swatches of their shades. Every pick is sent back through
## `changed(appearance)`; the panel redraws itself.

signal changed(appearance: Dictionary)
signal tab_changed(tab: String)

const TABS: Array[String] = ["Body", "Head", "Outfit", "Portrait & voice"]
const OPTIONS_W := 520.0

var appearance: Dictionary = {}
var species := "human"
var class_id := ""
var tab := "Body"
## Portraits other custom characters in the company wear: portrait id -> their name. Shown, but not offered (each
## custom character's portrait is also the id its sprite is known by).
var taken: Dictionary = {}
var _left: VBoxContainer
var _preview: HeroPreview
var _side: VBoxContainer


static func create(app: Dictionary, species_id: String, cls: String, start_tab: String = "Body",
		taken_: Dictionary = {}) -> AppearancePanel:
	var p := AppearancePanel.new()
	p.appearance = app.duplicate()
	p.taken = taken_
	p.species = species_id
	p.class_id = cls
	p.tab = start_tab
	p.add_theme_constant_override("separation", 18)
	p._left = VBoxContainer.new()
	p._left.add_theme_constant_override("separation", 8)
	p._left.custom_minimum_size = Vector2(OPTIONS_W, 0)
	p.add_child(p._left)
	p._side = VBoxContainer.new()
	p._side.add_theme_constant_override("separation", 6)
	p.add_child(p._side)
	p._preview = HeroPreview.new()
	p._side.add_child(p._preview)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiParts.small_button("◀", func() -> void: p._preview.turn(-1)))
	row.add_child(UiParts.small_button("Stand", func() -> void: p._preview.set_mode("turn")))
	row.add_child(UiParts.small_button("Walk", func() -> void: p._preview.set_mode("walk")))
	row.add_child(UiParts.small_button("Attack", func() -> void: p._preview.set_mode("attack")))
	row.add_child(UiParts.small_button("▶", func() -> void: p._preview.turn(1)))
	p._side.add_child(row)
	p._redraw()
	p._preview.show_look(p.appearance, species_id)
	return p


func _pick(key: String, value: String) -> void:
	if str(appearance.get(key, "")) == value:
		return
	var old_gender := str(appearance.get("gender", "female"))
	appearance[key] = value
	if key == "gender":
		# A voice still on the old gender's default follows the new one.
		var defaults := HeroLook.catalog()["defaults"] as Dictionary
		if str(appearance.get("voice", "")) == str((defaults[old_gender] as Dictionary)["voice"]):
			appearance["voice"] = str((defaults[value] as Dictionary)["voice"])
	if key == "portrait":
		appearance["art"] = value
	# A pick can leave another without art (a build that has no such outfit yet): move it onto art that exists.
	appearance = HeroLook.settle(appearance)
	changed.emit(appearance.duplicate())
	_redraw()
	if key in HeroLook.LOOK_KEYS or key == "height":
		_preview.show_look(appearance, species)


func _redraw() -> void:
	for c in _left.get_children():
		c.queue_free()
	_left.add_child(UiParts.tab_strip(TABS, tab, func(t: String) -> void:
		tab = t
		tab_changed.emit(t)
		_redraw(), {}, 14))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	match tab:
		"Body":
			_choice_row(body, "Gender", "genders", "gender")
			_choice_row(body, "Build", "builds", "build")
			_choice_row(body, "Height", "heights", "height")
			_swatches(body, "Skin", "skins", "skin")
		"Head":
			_pictures(body, "Head", "heads", "head", 4)
			_pictures(body, "Hair", "hair", "hair", 5)
			_swatches(body, "Hair colour", "hair_colours", "hair_colour")
			_pictures(body, "Beard", "beards", "beard", 4)
		"Outfit":
			_outfits(body)
		"Portrait & voice":
			_portraits(body)
			_voices(body)
	_left.add_child(body)


## Plain choices as a row of buttons, the current one lit.
func _choice_row(box: VBoxContainer, title: String, category: String, key: String) -> void:
	box.add_child(UiParts.section(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for o: Variant in HeroLook.offered(appearance, category):
		var id := str((o as Dictionary)["id"])
		var b := UiKit.button(str((o as Dictionary)["label"]), func() -> void: _pick(key, id), 15)
		b.custom_minimum_size = Vector2(110, 36)
		if str(appearance.get(key, "")) == id:
			UiParts.light_up(b)
		row.add_child(b)
	box.add_child(row)


## Skin tones and hair colours: an arched swatch per option showing its shades, the current one ringed in gilt.
func _swatches(box: VBoxContainer, title: String, category: String, key: String) -> void:
	box.add_child(UiParts.section(title, UiKit.label(str(HeroLook.option(category, str(appearance.get(key, ""))).get("label", "")), 14, "gilt_light")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for o: Variant in HeroLook.offered(appearance, category):
		var id := str((o as Dictionary)["id"])
		var shades := HeroLook.ramp(category, id)
		var on := str(appearance.get(key, "")) == id
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(44, 56)
		b.tooltip_text = str((o as Dictionary)["label"])
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func() -> void:
			Audio.sfx("click")
			_pick(key, id))
		b.draw.connect(func() -> void:
			var r := Rect2(Vector2(3, 3), b.size - Vector2(6, 6))
			var pts := UiParts.arch_points(r, 14.0)
			# Light at the top down to the deep shade at the foot, as the shading falls on a figure.
			var cols := PackedColorArray()
			for p in pts:
				var t := clampf((p.y - r.position.y) / r.size.y, 0.0, 0.999)
				cols.append(shades[3 - int(t * 3.0)])
			b.draw_polygon(pts, cols)
			UiParts.closed_line(b, pts, Look.color("gilt_light" if on else "gilt_dark"), 2.5 if on else 1.2)
			if on:
				UiParts.diamond(b, Vector2(b.size.x / 2.0, b.size.y - 2.0), 4.0, Look.color("gilt_light"), true))
		row.add_child(b)
	box.add_child(row)


## Heads, hairstyles and beards: a picture of this hero's head (three-quarter view) with each option.
func _pictures(box: VBoxContainer, title: String, category: String, key: String, columns: int) -> void:
	box.add_child(UiParts.section(title))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for o: Variant in HeroLook.offered(appearance, category):
		var id := str((o as Dictionary)["id"])
		var trial := appearance.duplicate()
		trial[key] = id
		var b := UiKit.button(str((o as Dictionary)["label"]), func() -> void: _pick(key, id), 13)
		b.custom_minimum_size = Vector2(92, 92)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
		for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(k, Color.WHITE)
		if HeroLook.has_pieces(trial):
			b.icon = ImageTexture.create_from_image(HeroLook.head_picture(trial))
		if str(appearance.get(key, "")) == id:
			UiParts.light_up(b)
		grid.add_child(b)
	box.add_child(grid)


func _outfits(box: VBoxContainer) -> void:
	box.add_child(UiParts.section("Starting outfit"))
	box.add_child(UiKit.label("What your hero wears into the mists, and the weapon they swing in the art. Your gear on the sheet is set by your class and background.", 13, "parchment", OPTIONS_W))
	for o: Variant in HeroLook.offered(appearance, "outfits"):
		var od := o as Dictionary
		var id := str(od["id"])
		var on := str(appearance.get("outfit", "")) == id
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var n := UiKit.label(str(od["label"]), 17, "gilt_light" if on else "vellum")
		n.add_theme_font_override("font", UiKit.display_font())
		head.add_child(n)
		var suits: Array[String] = []
		for c: Variant in od.get("suits", []):
			suits.append(str(c).capitalize())
		if class_id in (od.get("suits", []) as Array):
			head.add_child(UiParts.pill("Suits your %s" % class_id.capitalize(), "bile"))
		row.add_child(head)
		row.add_child(UiKit.label("%s Suits %s." % [str(od["summary"]), ", ".join(suits)], 13, "parchment", OPTIONS_W - 40.0))
		box.add_child(UiParts.click_row(row, func() -> void: _pick("outfit", id), on))


func _portraits(box: VBoxContainer) -> void:
	box.add_child(UiParts.section("Portrait"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for o: Variant in HeroLook.offered(appearance, "portraits"):
		var id := str((o as Dictionary)["id"])
		var on := str(appearance.get("portrait", "")) == id
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(94, 94)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func() -> void:
			Audio.sfx("click")
			_pick("portrait", id))
		var pic := UiParts.framed_portrait(id, 90.0)
		pic.position = Vector2(2, 2)
		b.add_child(pic)
		if taken.has(id) and not on:
			b.disabled = true
			b.tooltip_text = "%s wears this portrait." % str(taken[id])
			pic.modulate = Color(1, 1, 1, 0.3)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var who := UiKit.label(str(taken[id]).get_slice(" ", 0), 12, "gilt_light")
			who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			who.clip_text = true
			who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			who.position = Vector2(6, 66)
			who.size = Vector2(82, 20)
			who.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(who)
		if on:
			b.draw.connect(func() -> void:
				b.draw_rect(Rect2(Vector2.ZERO, b.size).grow(-0.5), Look.color("gilt_light"), false, 3.0)
				UiParts.diamond(b, Vector2(b.size.x / 2.0, b.size.y), 5.0, Look.color("gilt_light"), true))
		grid.add_child(b)
	box.add_child(grid)


func _voices(box: VBoxContainer) -> void:
	box.add_child(UiParts.section("Voice"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for o: Variant in HeroLook.options("voices"):
		var od := o as Dictionary
		var id := str(od["id"])
		var b := UiKit.button(str(od["label"]), func() -> void:
			_pick("voice", id)
			_sample(id), 15)
		b.custom_minimum_size = Vector2(170, 38)
		if str(appearance.get("voice", "")) == id:
			UiParts.light_up(b)
		row.add_child(b)
	box.add_child(row)
	box.add_child(UiKit.label("Your hero speaks the party's lines in this voice. Choosing one plays a sample when it has been recorded.", 13, "parchment", OPTIONS_W))


func _sample(voice: String) -> void:
	var line := str(HeroLook.catalog().get("voice_sample", ""))
	if line != "":
		VoiceOver.say(voice, line)
