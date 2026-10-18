class_name ItemNotices
extends CanvasLayer
## Notices on the right of the screen for items the party comes by outside a loot window or a shop (owner, 2026-10-12: a
## skill check at the Wizard of Wines' well handed over a Rope of Climbing and nothing said so): a skill check's find, a
## gift in a conversation, a hidden find taken, a picked pocket. Each shows the item's icon, its name in its rarity's
## colour and who has it now; a magic item has a "Magic item found" banner across its top. StoryState.gain_item raises
## them (item_gained) and the game root shows them here. Three at most at once, the rest waiting their turn, so they stay
## clear of the narration box below; nothing on them takes the mouse or a controller's focus, and every line wraps inside
## a fixed width.

## Over the HUDs (10) and conversations (20), under the right-click menu (25), the big d20 (26) and the screens (30).
const LAYER := 24
const WIDTH := 360.0
const ICON := 40.0
const MAX_SHOWN := 3
## How long a notice stays, a magic item's a little longer, and its fade in and out (seconds).
const SECONDS := 4.5
const MAGIC_SECONDS := 6.5
const FADE := 0.4
## Below the minimap and the place's name (the HUD's top right).
const TOP := 304.0
const MARGIN := 16.0
## A magic item's name in its rarity's colour (art/palette); anything else in parchment. The inventory's rows and the
## shop's edge and tag magic items in the same colours (ItemTile.rarity_colour), so rare and artifact use the lighter
## blue and red: moon blue and crimson are too dark to read on the screens' crimson panels.
const RARITY_COLOURS := {"common": "vellum", "uncommon": "emerald_light", "rare": "moonlight", "very_rare": "orchid",
	"legendary": "flame", "artifact": "vampire_red"}

var _box: VBoxContainer
var _waiting: Array[Dictionary] = []


func _init() -> void:
	name = "ItemNotices"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS   # a cutscene that pauses the game doesn't freeze a notice on screen
	_box = VBoxContainer.new()
	_box.name = "Notices"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.offset_left = -WIDTH - MARGIN
	_box.offset_right = -MARGIN
	_box.offset_top = TOP
	add_child(_box)


## Shows a notice that `who` (a character's name, "" for the party's stash) now has `qty` of `item_id`, or queues it
## behind the ones up already.
func show_item(item_id: String, qty: int, who: String) -> void:
	var n := {"id": item_id, "qty": qty, "who": who}
	if shown().size() >= MAX_SHOWN:
		_waiting.append(n)
		return
	_add(n)


## The notices up now (not yet fading away).
func shown() -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	for c in _box.get_children():
		if c is PanelContainer and not c.is_queued_for_deletion():
			out.append(c as PanelContainer)
	return out


## What a notice says: {name, colour, magic, who}. `name` has the count when there's more than one.
static func words(item_id: String, qty: int, who: String) -> Dictionary:
	var comp := Compendium.shared()
	var item := comp.item_data(item_id)
	var magic := MagicItems.is_magic(item)
	var title := comp.display_name("items", item_id) + (" ×%d" % qty if qty > 1 else "")
	return {"name": title, "colour": str(RARITY_COLOURS.get(MagicItems.rarity(item), "parchment")) if magic else "parchment",
		"magic": magic, "who": ("%s has it" % who.get_slice(" ", 0)) if who != "" else "Into the party's stash"}


func _add(n: Dictionary) -> void:
	var w := words(str(n["id"]), int(n["qty"]), str(n["who"]))
	var magic := bool(w["magic"])
	var panel := PanelContainer.new()
	panel.name = "Notice"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UiKit.style("ui_black", "gilt" if magic else "gilt_dark", 2 if magic else 1, 0.93)
	s.set_content_margin_all(8)
	s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s)
	panel.custom_minimum_size.x = WIDTH
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := UiParts.icon_slot("item", str(n["id"]), ICON)
	if icon != null:
		row.add_child(icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var text_width := WIDTH - 16.0 - (ICON + 10.0 if icon != null else 0.0)
	if magic:
		var banner := UiKit.label("Magic item found", 12, "gilt_light", text_width)
		banner.name = "Banner"
		col.add_child(banner)
	var title := UiKit.label(str(w["name"]), 17, str(w["colour"]), text_width)
	title.name = "ItemName"
	col.add_child(title)
	var who := UiKit.label(str(w["who"]), 13, "bone", text_width)
	who.name = "Who"
	col.add_child(who)
	_box.add_child(panel)
	Audio.sfx("arcane_glint" if magic else "rummage")
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "modulate:a", 1.0, FADE)
	tw.tween_interval(MAGIC_SECONDS if magic else SECONDS)
	tw.tween_property(panel, "modulate:a", 0.0, FADE)
	tw.tween_callback(_gone.bind(panel))


func _gone(panel: PanelContainer) -> void:
	panel.queue_free()
	if not _waiting.is_empty():
		_add(_waiting.pop_front())
