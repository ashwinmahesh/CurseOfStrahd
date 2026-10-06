class_name JournalScreen
extends CanvasLayer
## The quest journal and the codex (plan §5.5, §5.6): each quest with the journal text of every stage reached and
## its current objectives (finished ones below), and the books, letters and notes the party has read.

var root: Node
var st: StoryState


func _init() -> void:
	name = "JournalScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "Journal", Vector2(1200, 760))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(1160, 660)
	frame.add_child(tabs)
	var quests := VBoxContainer.new()
	quests.name = "Quests"
	quests.add_theme_constant_override("separation", 12)
	var entries := QuestLog.journal(st)
	if entries.is_empty():
		quests.add_child(UiKit.label("No quests yet.", 16, "parchment"))
	for q in entries:
		var status := str(q["status"])
		quests.add_child(UiKit.header("%s%s" % [q["name"], "" if status == "active" else (" · completed" if status == "success" else " · failed")]))
		for text: String in q["entries"]:
			quests.add_child(UiKit.label(text, 15, "vellum", 1080))
		for o: String in q["objectives"]:
			quests.add_child(UiKit.label("◇ " + o, 15, "wick", 1080))
	tabs.add_child(UiKit.scroll(quests, Vector2(1140, 600)))
	(tabs.get_child(0) as Control).name = "Quests"
	var codex := VBoxContainer.new()
	codex.add_theme_constant_override("separation", 12)
	if st.codex.is_empty():
		codex.add_child(UiKit.label("Nothing read yet. Books, letters and notes you read appear here.", 16, "parchment"))
	for id in st.codex:
		var entry := _codex_entry(id)
		codex.add_child(UiKit.header(str(entry["title"])))
		codex.add_child(UiKit.label(str(entry["text"]), 15, "vellum", 1080))
	tabs.add_child(UiKit.scroll(codex, Vector2(1140, 600)))
	(tabs.get_child(1) as Control).name = "Codex"


## A codex entry's title and text: from the book prop that grants it, or its Narrator examine line.
static func _codex_entry(id: String) -> Dictionary:
	for loc in Compendium.shared().all("locations"):
		for p: Variant in loc.get("props", []):
			var prop := p as Dictionary
			if str(prop.get("codex", prop["id"])) == id and str(prop["kind"]) == "book":
				var text := str(prop.get("text", ""))
				return {"title": str(prop.get("label", id)), "text": text if text != "" else "(Read in %s.)" % loc.get("name", "")}
	return {"title": id.replace("_", " ").capitalize(), "text": ""}
