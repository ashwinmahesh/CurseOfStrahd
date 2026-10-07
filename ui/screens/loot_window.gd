class_name LootWindow
extends CanvasLayer
## The loot window (docs/ui/inventory.md, inv_02): what a container holds, with Take all, Take one, Take gold, or Send
## to whoever can carry it (overloaded characters are skipped, and it says so). Coins go to the party purse. Anything
## can go straight to the party stash instead (Q7, owner 2026-10-07): it's taken out again at a safe place.

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
	# As tall as what's inside (owner, docs/plans/ui_polish.md: a purse of coins sat in a frame built for twenty
	# items), from a small box for a few things up to the old size for a full chest.
	var lines := its.size() + (1 if g > 0.0 else 0)
	var box := UiKit.screen_frame(self, "Loot", Vector2(860, clampf(250.0 + 58.0 * maxf(1.0, lines), 330.0, 560.0)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiParts.caption("Give to", 12))
	_to = OptionButton.new()
	for ch in st.party:
		_to.add_item(ch.name)
	_to.custom_minimum_size = Vector2(220, 0)
	row.add_child(_to)
	box.add_child(row)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(_list))
	box.add_child(pane)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(UiKit.button("Send to who can carry", _send_all, 15))
	var to_stash := UiKit.button("All to the stash", stash_all, 15)
	to_stash.tooltip_text = "Everything here into the party stash, and the coins to the purse. Take things out at an inn or a home."
	buttons.add_child(to_stash)
	buttons.add_child(UiKit.button("Close", _close, 15))
	buttons.add_child(UiParts.gap())
	var all := UiParts.primary_button("Take all (Space)", _take_all, "inventory")
	all.tooltip_text = "Everything here to the character chosen above, and the coins to the purse."
	buttons.add_child(all)
	box.add_child(buttons)
	_redraw()


func _redraw() -> void:
	for c in _list.get_children():
		c.queue_free()
	if gold > 0.0:
		var coins := HBoxContainer.new()
		coins.add_theme_constant_override("separation", 10)
		coins.add_child(UiParts.figure("%d" % int(gold), 20, "gilt_light"))
		var what := UiKit.label("gold pieces, for the party purse", 15, "parchment")
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coins.add_child(what)
		coins.add_child(UiParts.small_button("Take gold", take_coins))
		_list.add_child(UiParts.row(coins))
	if items.is_empty() and gold <= 0.0:
		_list.add_child(UiKit.label("Empty.", 15, "bone"))
	for i in items.size():
		var it := items[i] as Dictionary
		# A disguised item (a Potion of Poison) shows only what it passes for.
		var data := MagicItems.shown_data(Compendium.shared().item_data(str(it["id"])), it)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		UiParts.add_icon(row, "item", str(data.get("id", it["id"])))
		var qty := int(it.get("qty", 1))
		var n := UiKit.label("%s%s" % [data.get("name", it["id"]), " ×%d" % qty if qty > 1 else ""], 16, "vellum")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UiKit.label("%s lb" % str(data.get("weight_lb", 0)), 13, "parchment"))
		var idx := i
		row.add_child(UiParts.small_button("Take one", func() -> void: _take(idx, 1)))
		var stash := UiParts.small_button("Stash", func() -> void: _stash(idx))
		stash.tooltip_text = "Into the party stash; take it out at an inn or a home"
		stash.disabled = InventoryScreen.is_quest(data)
		row.add_child(stash)
		_list.add_child(UiParts.row(row, _item_tip(data)))


static func _item_tip(data: Dictionary) -> Callable:
	return func() -> Control:
		var body := str(data.get("text", "")) if str(data.get("text", "")) != "" else str(data.get("summary", ""))
		return UiParts.rules_tip(str(data.get("name", "")), str(data.get("category", "")).capitalize(), body,
			[["Weight", "%s lb" % str(data.get("weight_lb", 0))], ["Value", "%s gp" % str(data.get("cost_gp", 0))]])


func _target() -> Character:
	return st.party[clampi(_to.selected, 0, st.party.size() - 1)]


func _take(i: int, n: int) -> void:
	var it := items[i] as Dictionary
	var qty := int(it.get("qty", 1))
	_target().add_item(str(it["id"]), mini(n, qty), it)
	if qty - n <= 0:
		items.remove_at(i)
	else:
		it["qty"] = qty - n
	_redraw()
	_maybe_done()


func _take_all() -> void:
	for it: Variant in items:
		var d := it as Dictionary
		_target().add_item(str(d["id"]), int(d.get("qty", 1)), d)
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
				ch.add_item(str(d["id"]), int(d.get("qty", 1)), d)
				placed = true
				break
		if not placed:
			_target().add_item(str(d["id"]), int(d.get("qty", 1)), d)
			notes.append("%s is overloaded with %s" % [_target().name, MagicItems.display_name(data, d)])
	items.clear()
	_take_gold()
	if not notes.is_empty() and view != null:
		view.toast.emit("; ".join(notes))
	_close()


## One find (all of it) into the party stash, with its own state.
func _stash(i: int) -> void:
	var it := items[i] as Dictionary
	st.stash_add(str(it["id"]), int(it.get("qty", 1)), it)
	items.remove_at(i)
	_redraw()
	_maybe_done()


## Everything into the party stash (quest items to the chosen character, since they can't be stashed), the coins to
## the purse.
func stash_all() -> void:
	for it: Variant in items:
		var d := it as Dictionary
		if InventoryScreen.is_quest(Compendium.shared().item_data(str(d["id"]))):
			_target().add_item(str(d["id"]), int(d.get("qty", 1)), d)
		else:
			st.stash_add(str(d["id"]), int(d.get("qty", 1)), d)
	items.clear()
	_take_gold()
	_close()


## The coins alone into the party purse; the items stay to be taken or left.
func take_coins() -> void:
	if gold <= 0.0:
		return
	Audio.sfx("coins")
	_take_gold()
	_redraw()


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
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_take_all()
