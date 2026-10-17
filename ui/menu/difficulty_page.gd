class_name DifficultyPage
extends RefCounted
## The New game page's last step (F1): how hard Barovia is, and how heroes grow. The four modes (combat/difficulty.gd)
## as rows to pick, each with a tip listing what it changes; then "How do heroes grow?", Milestones or Experience
## (story/xp.gd), chosen now and shown but not changed in Settings; then Back to the party and Begin.

## How heroes grow, as the page lists them: id (StoryState.options["levelling"]), name, what the row says, and the tip.
const GROWTH: Array[Dictionary] = [
	{"id": "milestone", "name": "Milestones", "tagline": "The story's turning points",
		"summary": "Levels come at the story's turning points, as the game has always had them.",
		"tip": "The party levels up when the story reaches a turning point: the end of Death House, the burial, each region's climax. Fights, quests and discoveries earn no XP."},
	{"id": "xp", "name": "Experience", "tagline": "Experience points",
		"summary": "Foes, quests, secrets and places earn XP. Story milestones still bring the level the story expects.",
		"tip": "Every foe beaten, quest finished, secret found and place discovered earns XP, and so do skill checks that matter and lore. Story milestones still guarantee the level the story expects, and the party never runs more than one level ahead of it: XP earned past that waits for the next milestone."},
]


## Fills `box` with the page, `picked` lit. `on_pick` gets the mode's id; `on_back` and `on_begin` take nothing.
## `levelling` is how heroes grow ("milestone" or "xp") and `on_levelling` gets the id picked.
static func build(box: VBoxContainer, picked: String, on_pick: Callable, on_back: Callable, on_begin: Callable,
		levelling: String = Xp.MILESTONE, on_levelling: Callable = Callable()) -> void:
	box.add_child(UiKit.title("How hard is Barovia?"))
	box.add_child(UiKit.label("Story, Balanced and Tactician can be changed later in Settings. Honour is chosen now or never.",
		15, "parchment", 560))
	for id in Difficulty.IDS:
		box.add_child(_mode_row(Difficulty.named(id), id == picked, on_pick))
	if on_levelling.is_valid():
		var head := UiKit.header("How do heroes grow?")
		head.name = "GrowthHeader"
		var above := Control.new()
		above.custom_minimum_size = Vector2(0, 4)
		box.add_child(above)
		box.add_child(head)
		for g in GROWTH:
			box.add_child(_growth_row(g, str(g["id"]) == levelling, on_levelling))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var back := UiParts.primary_button("Back", on_back)
	back.tooltip_text = "Back to choosing the party (Esc)"
	row.add_child(back)
	row.add_child(UiParts.gap())
	row.add_child(UiParts.primary_button("Begin on %s" % Difficulty.named(picked).name, on_begin))
	box.add_child(row)


static func _growth_row(g: Dictionary, lit: bool, on_pick: Callable) -> Control:
	if MobileDevice.enabled():
		return _mobile_choice(str(g["name"]), str(g["id"]), str(g["tip"]), lit, on_pick)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var n := UiKit.label(str(g["name"]), 19, "gilt_light")
	n.add_theme_font_override("font", UiKit.display_font())
	head.add_child(n)
	var tag := UiKit.label(str(g["tagline"]), 13, "parchment")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	col.add_child(head)
	col.add_child(UiKit.label(str(g["summary"]), 13, "vellum", 520))
	var row := UiParts.click_row(col, on_pick.bind(str(g["id"])), lit, func() -> Control:
		return UiParts.rules_tip(str(g["name"]), str(g["tagline"]), str(g["tip"]),
			[], "Chosen now. Settings shows it, but it can't be changed in a game that has begun."))
	row.name = "Growth_" + str(g["id"])
	return row


static func _mode_row(d: Difficulty, lit: bool, on_pick: Callable) -> Control:
	if MobileDevice.enabled():
		return _mobile_choice(d.name, d.id, d.summary + "\n" + "\n".join(d.describe()), lit, on_pick)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var n := UiKit.label(d.name, 19, "gilt_light")
	n.add_theme_font_override("font", UiKit.display_font())
	head.add_child(n)
	var tag := UiKit.label(d.tagline, 13, "parchment")
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	col.add_child(head)
	col.add_child(UiKit.label(d.summary, 13, "vellum", 520))
	var lines := d.describe()
	return UiParts.click_row(col, on_pick.bind(d.id), lit, func() -> Control:
		return UiParts.rules_tip(d.name, d.tagline, "\n".join(lines.map(func(l: String) -> String: return "• " + l))))


static func _mobile_choice(title: String, id: String, description: String, lit: bool, pick: Callable) -> Control:
	var column := VBoxContainer.new()
	var choose := MobileUi.button(title, pick.bind(id))
	choose.toggle_mode = true
	choose.button_pressed = lit
	if lit:
		UiParts.light_up(choose)
	column.add_child(choose)
	column.add_child(MobileUi.text(description))
	return column
