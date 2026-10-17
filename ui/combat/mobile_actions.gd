class_name MobileActions
extends CanvasLayer
## Mobile touch/controller action browser. Inspection never emits a game command; only the explicit review button does.

signal chosen(action: Dictionary, level: int)
signal closed
signal command_requested(command: String)

var catalog: ActionCatalog
var actor: Combatant
var page: MobilePage
var category := "All"
var query := ""
var selected: Dictionary = {}
var level := 0
var choice := -1
var metamagic := ""
var ready_trigger := ""
var _list: VBoxContainer
var _origin_turn: Combatant
var _committed := false


func open(catalog_: ActionCatalog, actor_: Combatant) -> void:
	catalog = catalog_
	actor = actor_
	_origin_turn = catalog.e.current()
	layer = 40
	set_meta(&"pad_scope", true)
	var body := MobilePage.build(self, "Actions · %s" % actor.name(), back)
	page = body.get_parent().get_parent().get_parent() as MobilePage
	page.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var close_button := MobileUi.button("Close", dismiss)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	page.heading.get_parent().add_child(close_button)
	browse()


func back() -> void:
	if not selected.is_empty():
		selected = {}
		browse()
	else:
		dismiss()


func dismiss() -> void:
	if is_queued_for_deletion():
		return
	hide()
	closed.emit()
	queue_free()


func browse() -> void:
	MobileUi.clear(page.toolbar)
	MobileUi.clear(page.body)
	var search := LineEdit.new()
	search.placeholder_text = "Search actions"
	search.text = query
	search.custom_minimum_size.y = 48
	search.add_theme_font_size_override("font_size", 18)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.clear_button_enabled = true
	search.text_changed.connect(func(value: String) -> void:
		query = value
		fill())
	var search_row := HBoxContainer.new()
	page.toolbar.add_child(search_row)
	search_row.add_child(search)
	var turn := MobileUi.button("Turn options", turn_options)
	turn.autowrap_mode = TextServer.AUTOWRAP_OFF
	turn.size_flags_horizontal = Control.SIZE_SHRINK_END
	search_row.add_child(turn)
	var tabs := HBoxContainer.new()
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.add_child(tabs)
	page.toolbar.add_child(strip)
	var categories: Array[String] = ["All", ActionCatalog.FAVOURITES, ActionCatalog.HIDDEN]
	categories.append_array(catalog.tabs_for(actor))
	for value in categories:
		var tab := MobileUi.button(value, func() -> void:
			category = value
			browse())
		if category == value:
			UiParts.light_up(tab)
		tab.autowrap_mode = TextServer.AUTOWRAP_OFF
		tabs.add_child(tab)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	page.body.add_child(_list)
	fill()


func pad_tab(step: int) -> void:
	if not selected.is_empty():
		return
	var categories: Array[String] = ["All", ActionCatalog.FAVOURITES, ActionCatalog.HIDDEN]
	categories.append_array(catalog.tabs_for(actor))
	category = categories[posmod(categories.find(category) + step, categories.size())]
	browse()


func turn_options() -> void:
	selected = {"turn_options": true}
	MobileUi.clear(page.toolbar)
	MobileUi.clear(page.body)
	for value: String in ["Cancel targeting", "Undo move", "End turn"]:
		page.body.add_child(MobileUi.button(value, func() -> void:
			hide()
			closed.emit()
			queue_free()
			command_requested.emit(value)))


func fill() -> void:
	MobileUi.clear(_list)
	var actions := catalog.actions_for(actor)
	if category != "All":
		actions = catalog.arranged(actor, category, actions)
	for action in actions:
		var words := "%s %s %s" % [action.get("label", ""), action.get("sub", ""), action.get("help", "")]
		if query.strip_edges() != "" and not words.to_lower().contains(query.strip_edges().to_lower()):
			continue
		var caption := "%s · %s" % [action.get("label", ""), str(action.get("cost", "free")).capitalize()]
		if str(action.get("sub", "")) != "":
			caption += "\n" + str(action["sub"])
		if not bool(action.get("legal", false)):
			caption += "\n" + str(action.get("reason", "Unavailable"))
		var card := MobileUi.button(caption, func() -> void: inspect(action))
		card.custom_minimum_size.y = 64
		card.set_meta(&"action_id", str(action["id"]))
		_list.add_child(card)
	if _list.get_child_count() == 0:
		_list.add_child(MobileUi.text("No matching actions. Try another category or search."))


func inspect(action: Dictionary) -> void:
	selected = action.duplicate(true)
	choice = -1
	metamagic = ""
	ready_trigger = ""
	var levels := catalog.level_choices(actor, selected)
	level = levels[0] if not levels.is_empty() else 0
	review()


func review() -> void:
	MobileUi.clear(page.toolbar)
	MobileUi.clear(page.body)
	page.scroll.scroll_vertical = 0
	var details := catalog.details(actor, selected)
	page.body.add_child(MobileUi.text(str(details.get("title", selected.get("label", ""))), "gilt_light"))
	for line: Variant in details.get("lines", []):
		page.body.add_child(MobileUi.text(str(line)))
	var choices := selected.get("choices", []) as Array
	for i in choices.size():
		var option := choices[i] as Dictionary
		var control := MobileUi.button(str(option["label"]), func() -> void:
			choice = i
			review())
		if choice == i:
			UiParts.light_up(control)
		page.body.add_child(control)
	var levels := catalog.level_choices(actor, selected)
	if levels.size() > 1:
		page.body.add_child(MobileUi.text("Casting level"))
		var row := HFlowContainer.new()
		page.body.add_child(row)
		for value in levels:
			var control := MobileUi.button("Level %d" % value, func() -> void:
				level = value
				review())
			if value == level:
				UiParts.light_up(control)
			control.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(control)
	var magic := selected.get("metamagic", []) as Array
	if not magic.is_empty():
		page.body.add_child(MobileUi.text("Spell shaping", "gilt_light"))
		page.body.add_child(MobileUi.button("Without Metamagic" + (" ✓" if metamagic == "" else ""), func() -> void:
			metamagic = ""
			review()))
		for option: Dictionary in magic:
			page.body.add_child(MobileUi.button(str(option["label"]) + (" ✓" if metamagic == str(option["id"]) else ""), func() -> void:
				metamagic = str(option["id"])
				ready_trigger = ""
				review()))
	if str(selected.get("kind", "")) == "spell" and str(selected.get("cost", "")) == "action" and str((selected.get("opts", {}) as Dictionary).get("resource_cast", "")) == "":
		page.body.add_child(MobileUi.text("Cast now or Ready", "gilt_light"))
		for trigger: String in ["", "approach", "attack", "spell"]:
			var labels := {"": "Cast now", "approach": "Ready: enemy enters range", "attack": "Ready: enemy attacks", "spell": "Ready: enemy casts a spell"}
			page.body.add_child(MobileUi.button(str(labels[trigger]) + (" ✓" if ready_trigger == trigger else ""), func() -> void:
				ready_trigger = trigger
				metamagic = ""
				review()))
	if actor.creature is Character:
		var id := str(selected["id"])
		page.body.add_child(MobileUi.button("Remove from Favourites" if catalog.is_favourite(actor, id) else "Add to Favourites", func() -> void:
			catalog.set_favourite(actor, id, not catalog.is_favourite(actor, id))
			review()))
		page.body.add_child(MobileUi.button("Show in category" if catalog.is_hidden(actor, id) else "Move to Hidden", func() -> void:
			catalog.set_hidden(actor, id, not catalog.is_hidden(actor, id))
			review()))
	var immediate := str(selected.get("targeting", "none")) == "none" or ready_trigger != ""
	var confirm := MobileUi.button(("Use " if immediate else "Aim ") + str(selected.get("label", "action")), commit)
	confirm.name = "MobileActionCommit"
	confirm.disabled = not bool(selected.get("legal", false)) or (not choices.is_empty() and choice < 0)
	page.toolbar.add_child(confirm)
	page.body.add_child(MobileUi.text("Confirming uses this action." if immediate else "Choose targets on the battlefield, then confirm. Aiming does not spend the action.", "parchment"))
	if not bool(selected.get("legal", false)):
		page.body.add_child(MobileUi.text(str(selected.get("reason", "Unavailable")), "flame"))


func commit() -> void:
	if _committed or is_queued_for_deletion():
		return
	# Resolve a fresh catalog entry at commitment; a stale card cannot authorize a spent resource or changed turn.
	if catalog.e.pending != null or catalog.e.current() != _origin_turn or actor != catalog.e.current() and not selected.has("policy"):
		page.body.add_child(MobileUi.text("The turn changed. Close Actions and select the acting character.", "flame"))
		return
	for fresh in catalog.actions_for(actor):
		if str(fresh["id"]) != str(selected.get("id", "")):
			continue
		if not bool(fresh.get("legal", false)):
			selected = fresh
			review()
			return
		var choices := fresh.get("choices", []) as Array
		if not choices.is_empty():
			if choice < 0 or choice >= choices.size():
				return
			var options := (fresh.get("opts", {}) as Dictionary).duplicate(true)
			options["choice"] = str((choices[choice] as Dictionary)["value"])
			fresh["opts"] = options
		var levels := catalog.level_choices(actor, fresh)
		if not levels.is_empty() and not level in levels:
			inspect(fresh)
			return
		if metamagic != "":
			var allowed := fresh.get("metamagic", []) as Array
			if not allowed.any(func(option: Dictionary) -> bool: return str(option["id"]) == metamagic):
				inspect(fresh)
				return
			var opts := (fresh.get("opts", {}) as Dictionary).duplicate(true)
			opts["metamagic"] = [metamagic]
			fresh["opts"] = opts
			if metamagic == "quickened":
				fresh["cost"] = "bonus"
		if ready_trigger != "":
			if str(fresh["kind"]) != "spell" or str(fresh["cost"]) != "action" or not ready_trigger in ["approach", "attack", "spell"]:
				return
			fresh["kind"] = "ready_spell"
			fresh["targeting"] = "none"
			var opts := (fresh.get("opts", {}) as Dictionary).duplicate(true)
			opts["trigger"] = ready_trigger
			fresh["opts"] = opts
		# Remove input ownership before emitting, so synchronous reaction prompts become the active modal.
		_committed = true
		hide()
		closed.emit()
		queue_free()
		chosen.emit(fresh, level)
		return
	page.body.add_child(MobileUi.text("This action is no longer available.", "flame"))
