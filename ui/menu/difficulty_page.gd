class_name DifficultyPage
extends RefCounted
## The New game page's last step (F1): how hard Barovia is. The four modes (combat/difficulty.gd) as rows to pick,
## each with a tip listing what it changes, then Back to the party and Begin.


## Fills `box` with the page, `picked` lit. `on_pick` gets the mode's id; `on_back` and `on_begin` take nothing.
static func build(box: VBoxContainer, picked: String, on_pick: Callable, on_back: Callable, on_begin: Callable) -> void:
	box.add_child(UiKit.title("How hard is Barovia?"))
	box.add_child(UiKit.label("Story, Balanced and Tactician can be changed later in Settings. Honour is chosen now or never.",
		15, "parchment", 560))
	for id in Difficulty.IDS:
		box.add_child(_mode_row(Difficulty.named(id), id == picked, on_pick))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var back := UiParts.primary_button("Back", on_back)
	back.tooltip_text = "Back to choosing the party (Esc)"
	row.add_child(back)
	row.add_child(UiParts.gap())
	row.add_child(UiParts.primary_button("Begin on %s" % Difficulty.named(picked).name, on_begin))
	box.add_child(row)


static func _mode_row(d: Difficulty, lit: bool, on_pick: Callable) -> Control:
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
