class_name LootWindow
extends CanvasLayer
## The loot window (docs/ui/inventory.md, inv_02): what a container holds, with Take all, Take one, or Send to whoever
## can carry it (overloaded characters are skipped, and it says so). Coins go to the party purse.

signal closed

var st: StoryState
var view: LocationView
var container_id := ""
var items: Array = []
var gold := 0.0
var _list: VBoxContainer
var _to: OptionButton


func _init() -> void:
	name = "LootWindow"
	layer = 30


func show_loot(state: StoryState, cid: String, its: Array, g: float, v: LocationView) -> void:
	st = state
	container_id = cid
	items = its
	gold = g
	view = v
	var box := UiKit.screen_frame(self, "Loot", Vector2(720, 520))
	var row := HBoxContainer.new()
	row.add_child(UiKit.label("Give to:", 15, "parchment"))
	_to = OptionButton.new()
	for ch in st.party:
		_to.add_item(ch.name)
	row.add_child(_to)
	box.add_child(row)
	_list = VBoxContainer.new()
	box.add_child(UiKit.scroll(_list, Vector2(680, 300)))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(UiKit.button("Take all", _take_all))
	buttons.add_child(UiKit.button("Send to who can carry", _send_all))
	buttons.add_child(UiKit.button("Close", _close))
	box.add_child(buttons)
	_redraw()


func _redraw() -> void:
	for c in _list.get_children():
		c.queue_free()
	if gold > 0.0:
		_list.add_child(UiKit.label("%d gp" % int(gold), 16, "gilt_light"))
	if items.is_empty() and gold <= 0.0:
		_list.add_child(UiKit.label("Empty.", 15, "parchment"))
	for i in items.size():
		var it := items[i] as Dictionary
		var data := Compendium.shared().item_data(str(it["id"]))
		var row := HBoxContainer.new()
		var qty := int(it.get("qty", 1))
		var l := UiKit.label("%s%s · %s lb" % [data.get("name", it["id"]), " ×%d" % qty if qty > 1 else "", str(data.get("weight_lb", 0))], 16)
		l.custom_minimum_size = Vector2(420, 0)
		l.tooltip_text = str(data.get("summary", ""))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var idx := i
		row.add_child(UiKit.button("Take one", func() -> void: _take(idx, 1), 14))
		_list.add_child(row)


func _target() -> Character:
	return st.party[clampi(_to.selected, 0, st.party.size() - 1)]


func _take(i: int, n: int) -> void:
	var it := items[i] as Dictionary
	var qty := int(it.get("qty", 1))
	_target().add_item(str(it["id"]), mini(n, qty))
	if qty - n <= 0:
		items.remove_at(i)
	else:
		it["qty"] = qty - n
	_redraw()
	_maybe_done()


func _take_all() -> void:
	for it: Variant in items:
		var d := it as Dictionary
		_target().add_item(str(d["id"]), int(d.get("qty", 1)))
	items.clear()
	_take_gold()
	_close()


## Each item goes to the first party member it doesn't overload (marching order); if everyone would be overloaded
## it goes to the chosen character anyway and says so.
func _send_all() -> void:
	var notes: Array[String] = []
	for it: Variant in items:
		var d := it as Dictionary
		var data := Compendium.shared().item_data(str(d["id"]))
		var weight := float(data.get("weight_lb", 0)) * int(d.get("qty", 1))
		var placed := false
		for ch in st.party:
			if ch.carried_weight() + weight <= ch.carrying_capacity().total():
				ch.add_item(str(d["id"]), int(d.get("qty", 1)))
				placed = true
				break
		if not placed:
			_target().add_item(str(d["id"]), int(d.get("qty", 1)))
			notes.append("%s is overloaded with %s" % [_target().name, data.get("name", d["id"])])
	items.clear()
	_take_gold()
	if not notes.is_empty() and view != null:
		view.toast.emit("; ".join(notes))
	_close()


func _take_gold() -> void:
	st.gold += gold
	gold = 0.0


func _maybe_done() -> void:
	if items.is_empty():
		_take_gold()


func _close() -> void:
	if items.is_empty() and gold <= 0.0 and view != null:
		view.mark_looted(container_id)
	else:
		# Whatever's left stays in the container.
		_write_back()
	closed.emit()
	queue_free()


func _write_back() -> void:
	if view == null:
		return
	var state := st.loc_state(view.loc_id)
	if not state.has("contents"):
		state["contents"] = {}
	(state["contents"] as Dictionary)[container_id] = {"items": items.duplicate(true), "gold": gold}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_close()
