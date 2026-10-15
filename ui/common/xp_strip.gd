class_name XpStrip
extends RefCounted
## The party's experience on the Party screen and the character sheet in XP levelling (story/xp.gd): "Level 6 · 15,240 /
## 23,000 XP" over a thin gilt bar, and, while the ceiling holds some back, "Held for the next milestone: 1,240 XP" with a
## tip that says why. XP is one pool for the whole party, so it is one strip, not one per hero. Milestone levelling has
## nothing to show: build() returns null.


## The strip `width` wide, or null when the game levels by milestones. `compact` (the sheet, whose column has no height to
## spare) keeps what is held for the next milestone on the one line, "· 1,240 held", with the sentence in its tip.
static func build(st: StoryState, width: float, compact: bool = false) -> Control:
	if not Xp.active(st):
		return null
	var box := VBoxContainer.new()
	box.name = "XpStrip"
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var held := Xp.reserve_line(st)
	var line := UiKit.label(Xp.line(st) + (" · %s held" % Xp.fmt(st.xp_reserve) if compact and held != "" else ""), 13 if compact else 14, "gilt_light")
	line.name = "XpLine"
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = "The party's experience. Heroes take each level on the level-up screen, up to the party's level."
	if compact and held != "":
		line.tooltip_text += "\n%s. %s" % [held, Xp.reserve_tip()]
	head.add_child(line)
	box.add_child(head)
	var bar := UiParts.bar(Xp.progress(st.xp) * 1000.0, 1000.0, 0.0, "", "gilt", Callable(), width, 10.0)
	bar.name = "XpBar"
	box.add_child(bar)
	if held != "" and not compact:
		var note := UiKit.label(held, 13, "moonlight", width)
		note.name = "XpHeld"
		note.mouse_filter = Control.MOUSE_FILTER_PASS
		note.tooltip_text = Xp.reserve_tip()
		box.add_child(note)
	return box
