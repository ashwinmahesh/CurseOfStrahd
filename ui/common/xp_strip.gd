class_name XpStrip
extends RefCounted
## The party's experience on the Party screen and the character sheet in XP levelling (story/xp.gd): "Level 6 · 15,240 /
## 23,000 XP" over a thin gilt bar, and, while the ceiling holds some back, "Held for the next milestone: 1,240 XP" with a
## tip that says why. XP is one pool for the whole party, so it is one strip, not one per hero. Milestone levelling has
## nothing to show: build() returns null.


## The strip `width` wide, or null when the game levels by milestones.
static func build(st: StoryState, width: float) -> Control:
	if not Xp.active(st):
		return null
	var box := VBoxContainer.new()
	box.name = "XpStrip"
	box.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var line := UiKit.label(Xp.line(st), 14, "gilt_light")
	line.name = "XpLine"
	line.tooltip_text = "The party's experience. Heroes take each level on the level-up screen, up to the party's level."
	head.add_child(line)
	box.add_child(head)
	var bar := UiParts.bar(Xp.progress(st.xp) * 1000.0, 1000.0, 0.0, "", "gilt", Callable(), width, 10.0)
	bar.name = "XpBar"
	box.add_child(bar)
	var held := Xp.reserve_line(st)
	if held != "":
		var note := UiKit.label(held, 13, "moonlight", width)
		note.name = "XpHeld"
		note.mouse_filter = Control.MOUSE_FILTER_PASS
		note.tooltip_text = Xp.reserve_tip()
		box.add_child(note)
	return box
