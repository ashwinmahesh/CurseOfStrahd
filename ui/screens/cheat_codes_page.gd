class_name CheatCodesPage
extends CanvasLayer
## Cheat codes, a page over the pause menu (owner, 2026-10-08). Type an item's six-character code (Cheat Codes.md in
## the vault lists them, CheatCodes makes them) and Give puts the item in the pack of the hero picked at the top, the
## one selected in the world unless the player picks another. A code works as often as the player likes. An item
## built on a base (a +1 Weapon, a Spell Scroll) asks which weapon, armor or spell. Back or Escape returns to the menu.

## Closed by Back or Escape.
signal closed

## The frame, short enough for the shortest window the game draws (1600 x 900).
const SIZE := Vector2(900, 600)
const ICON := 64.0

var st: StoryState
var _hidden: CanvasItem            ## the arch, hidden while the page is up
var _closing := false
var _who := 0                      ## the hero the item goes to (index in st.party)
var _chips: Control
var _code: LineEdit
var _icon_box: Control
var _name: Label
var _kind: Label
var _summary: Label
var _pick_row: HBoxContainer
var _pick_word: Label
var _pick: OptionButton
var _give: Button
var _status: Label
var _item := ""                    ## the item the code names ("" while it names none)
var _choices: Array[String] = []   ## the finished items it can be, when it's built on a base


func _init() -> void:
	name = "CheatCodesPage"
	layer = 31


## Whether there's a party to give to (the menu offers the page only then).
static func can_open(state: StoryState) -> bool:
	return state != null and not state.party.is_empty()


## Opens the page over `parent` (the pause menu) and returns it. `hide` (the arch) is hidden while the page is up.
static func open_on(parent: Node, state: StoryState, hide: CanvasItem = null) -> CheatCodesPage:
	var page := CheatCodesPage.new()
	page.st = state
	page._who = clampi(state.leader, 0, state.party.size() - 1)
	page._hidden = hide
	if hide != null:
		hide.visible = false
	parent.add_child(page)
	page._build()
	return page


func _build() -> void:
	var box := UiKit.screen_frame(self, "Cheat Codes", SIZE)
	# Clear of the title's arch, whose point hangs into the frame.
	var clear := Control.new()
	clear.custom_minimum_size = Vector2(0, 14)
	box.add_child(clear)
	var hint := UiKit.label("Type a code from Cheat Codes.md in your vault. The item goes to the hero you pick, and a code works as often as you like.", 15, "parchment")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(1, 0)
	box.add_child(hint)
	box.add_child(UiParts.caption("GIVE TO"))
	_chips = HBoxContainer.new()
	_chips.custom_minimum_size = Vector2(0, 46)
	box.add_child(_chips)
	_draw_chips()
	box.add_child(UiParts.caption("CODE"))
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 16)
	_code = LineEdit.new()
	_code.name = "Code"
	_code.placeholder_text = "e.g. 359A02"
	_code.max_length = 12
	_code.custom_minimum_size = Vector2(240, 0)
	_code.add_theme_font_override("font", UiParts.figure_font())
	_code.add_theme_font_size_override("font_size", 26)
	_code.tooltip_text = "Six letters and numbers (0-9 and A-F). Spaces and lower case don't matter."
	_code.text_changed.connect(_typed)
	_code.text_submitted.connect(func(_t: String) -> void: _give_now())
	code_row.add_child(_code)
	_give = UiParts.primary_button("Give", _give_now)
	_give.name = "Give"
	_give.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	code_row.add_child(_give)
	box.add_child(code_row)
	# What the code names: its icon, name, kind and summary, and the base to build it on when it has one.
	var pane := UiParts.pane(12)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_icon_box = Control.new()
	_icon_box.custom_minimum_size = Vector2(ICON, ICON)
	_icon_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_icon_box)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	_name = UiKit.header("")
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size = Vector2(1, 0)
	words.add_child(_name)
	_kind = UiKit.label("", 14, "parchment")
	_kind.clip_text = true
	_kind.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_kind.custom_minimum_size = Vector2(1, 0)
	words.add_child(_kind)
	head.add_child(words)
	inside.add_child(head)
	_summary = UiKit.label("", 15, "vellum")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(1, 0)
	_summary.max_lines_visible = 4
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inside.add_child(_summary)
	_pick_row = HBoxContainer.new()
	_pick_row.add_theme_constant_override("separation", 12)
	_pick_word = UiKit.label("", 15, "gilt")
	_pick_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pick_row.add_child(_pick_word)
	_pick = OptionButton.new()
	_pick.name = "Base"
	UiKit.button_look(_pick)
	_pick.add_theme_font_size_override("font_size", 15)
	_pick.custom_minimum_size = Vector2(360, 0)
	_pick.clip_text = true
	_pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pick.fit_to_longest_item = false
	_pick.item_selected.connect(func(_i: int) -> void: _show_item())
	_pick_row.add_child(_pick)
	inside.add_child(_pick_row)
	pane.add_child(inside)
	box.add_child(pane)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	var back := UiKit.button("Back", close, 18)
	back.name = "Back"
	back.tooltip_text = "Back (Esc)"
	foot.add_child(back)
	_status = UiKit.label("", 15, "gilt_light")
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(1, 0)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_status)
	box.add_child(foot)
	_typed("")
	_code.grab_focus.call_deferred()


func _draw_chips() -> void:
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	_chips.add_child(UiParts.party_chips(st.party, _who, func(i: int) -> void:
		_who = i
		_status.text = ""
		# Deferred, so the chip isn't taken away while it's still being pressed.
		_draw_chips.call_deferred()))


## The hero the item goes to.
func recipient() -> Character:
	return st.party[clampi(_who, 0, st.party.size() - 1)]


## The code as typed, kept to hex digits in upper case, and the item it names shown.
func _typed(text: String) -> void:
	var clean := CheatCodes.normalise(text).left(CheatCodes.LENGTH)
	if clean != text:
		_code.text = clean
		_code.caret_column = clean.length()
	_status.text = ""
	_item = CheatCodes.item_for(clean) if clean.length() == CheatCodes.LENGTH else ""
	_choices.clear()
	if _item != "":
		_choices = CheatCodes.choices(_item)
	_pick.clear()
	for v in _choices:
		_pick.add_item(CheatCodes.choice_name(v))
	if not _choices.is_empty():
		_pick.select(_choices.find(CheatCodes.default_choice(_item)))
	_pick_word.text = CheatCodes.base_word(_item) if _item != "" else ""
	_pick_row.visible = _choices.size() > 1
	_show_item()


## Types `text` into the code box, as the player would.
func type_code(text: String) -> void:
	_code.text = text
	_code.caret_column = text.length()
	_typed(text)


## Picks `variant_id` in the base picker (a +1 Longsword, a scroll of Fireball), if it's on offer.
func pick(variant_id: String) -> void:
	var i := _choices.find(variant_id)
	if i >= 0:
		_pick.select(i)
		_show_item()


## The finished item the page would give ("" while the code names none).
func chosen() -> String:
	if _item == "":
		return ""
	if _choices.is_empty():
		return _item
	return _choices[clampi(_pick.selected, 0, _choices.size() - 1)]


func _show_item() -> void:
	for c in _icon_box.get_children():
		_icon_box.remove_child(c)
		c.queue_free()
	var id := chosen()
	_give.disabled = id == ""
	_icon_box.visible = id != ""
	if id == "":
		var typed := CheatCodes.normalise(_code.text).length()
		_name.text = "No item has that code." if typed == CheatCodes.LENGTH else ""
		_kind.text = "" if typed == CheatCodes.LENGTH else "Type all six characters."
		_summary.text = ""
		return
	var d := Compendium.shared().item_data(id)
	var slot := UiParts.icon_slot("item", id, ICON)
	if slot != null:
		_icon_box.add_child(slot)
	var qty := CheatCodes.quantity(id)
	_name.text = "%s%s" % [d.get("name", id), " ×%d" % qty if qty > 1 else ""]
	_kind.text = kind_text(d)
	_summary.text = str(d.get("summary", ""))


## "Rare magic weapon · needs attunement", "Gear": what kind of item it is.
static func kind_text(d: Dictionary) -> String:
	var category := str(d.get("category", "item")).replace("_", " ")
	if not MagicItems.is_magic(d):
		return category.capitalize()
	var out := "%s magic %s" % [MagicItems.rarity(d).replace("_", " ").capitalize(), category]
	if MagicItems.needs_attunement(d):
		out += " · needs attunement"
	return out


## Gives the shown item to the picked hero; the code stays, to give another.
func _give_now() -> void:
	var id := chosen()
	if id == "":
		return
	var ch := recipient()
	var qty := CheatCodes.give(ch, id)
	if qty <= 0:
		return
	Audio.sfx("coins")
	var carried := 0
	for e in ch.inventory:
		if str(e["id"]) == id:
			carried += int(e.get("qty", 1))
	# A generic scroll becomes a particular one as it's given, so there's no count of it to show.
	_status.text = "Gave %s%s to %s%s." % [Compendium.shared().item_data(id).get("name", id), " ×%d" % qty if qty > 1 else "",
		ch.name.get_slice(" ", 0), ", who now carries %d" % carried if carried > 0 else ""]


func close() -> void:
	if _closing or is_queued_for_deletion():
		return
	_closing = true
	if _hidden != null and is_instance_valid(_hidden):
		_hidden.visible = true
	closed.emit()
	UiMotion.dismiss(self)


## Escape (the pause menu's action) returns to the menu.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
