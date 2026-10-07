class_name JournalScreen
extends CanvasLayer
## The quest journal and the codex (plan §5.5, §5.6): each quest as a card with the journal text of every stage
## reached and its current objectives (open quests first, finished ones tagged and greyed below), and the books,
## letters and notes the party has read.

var root: Node
var st: StoryState
var tab := "Quests"
var _frame: VBoxContainer


func _init() -> void:
	name = "JournalScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	_frame = UiKit.screen_frame(self, "Journal", Vector2(1200, 780))
	_draw()


func _draw() -> void:
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	_frame.add_child(UiParts.tab_strip(["Quests", "Codex"], tab, func(t: String) -> void:
		var forward := t == "Codex"
		tab = t
		_draw()
		UiMotion.turn_page(_frame.get_child(1) as Control, forward), {"Quests": "journal", "Codex": "search"}))
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(pane)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pane.add_child(UiParts.fill_scroll(box))
	if tab == "Codex":
		_codex(box)
	else:
		_quests(box)


func _quests(box: VBoxContainer) -> void:
	var entries := QuestLog.journal(st)
	if entries.is_empty():
		box.add_child(UiKit.label("No quests yet.", 16, "bone"))
	# Open quests first, then the finished ones.
	var order: Array[Dictionary] = []
	for q in entries:
		if str(q["status"]) == "active":
			order.append(q)
	for q in entries:
		if str(q["status"]) != "active":
			order.append(q)
	for q in order:
		var status := str(q["status"])
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var t := UiKit.header(str(q["name"]))
		t.add_theme_color_override("font_color", Look.color("gilt_light" if status == "active" else "bone"))
		head.add_child(t)
		head.add_child(UiParts.gap())
		match status:
			"active":
				head.add_child(UiParts.pill("Open", "moonlight", 13))
			"success":
				head.add_child(UiParts.pill("Completed", "bile", 13))
			_:
				head.add_child(UiParts.pill("Failed", "rose", 13))
		col.add_child(head)
		for text: String in q["entries"]:
			col.add_child(UiKit.label(text, 15, "vellum" if status == "active" else "parchment", 1060))
		for o: String in q["objectives"]:
			var orow := HBoxContainer.new()
			orow.add_theme_constant_override("separation", 8)
			orow.add_child(UiParts.mark(1))
			orow.add_child(UiKit.label(o, 15, "gilt_light", 1020))
			col.add_child(orow)
		box.add_child(UiParts.row(col, Callable(), false, 12))


func _codex(box: VBoxContainer) -> void:
	if st.codex.is_empty():
		box.add_child(UiKit.label("Nothing read yet. Books, letters and notes you read appear here.", 16, "bone"))
	for id in st.codex:
		var entry := _codex_entry(id)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.add_child(UiKit.header(str(entry["title"])))
		col.add_child(UiKit.label(str(entry["text"]), 15, "vellum", 1060))
		box.add_child(UiParts.row(col, Callable(), false, 12))


## A codex entry's title and text: from the book prop that grants it, or its Narrator examine line.
static func _codex_entry(id: String) -> Dictionary:
	for loc in Compendium.shared().all("locations"):
		for p: Variant in loc.get("props", []):
			var prop := p as Dictionary
			if str(prop.get("codex", prop["id"])) == id and str(prop["kind"]) == "book":
				var text := str(prop.get("text", ""))
				return {"title": str(prop.get("label", id)), "text": text if text != "" else "(Read in %s.)" % loc.get("name", "")}
	# A book carried and read (the Tome of Strahd): the item's own codex entry.
	var item := Compendium.shared().item_data(id)
	if item.has("codex"):
		return (item["codex"] as Dictionary).duplicate()
	return {"title": id.replace("_", " ").capitalize(), "text": ""}
