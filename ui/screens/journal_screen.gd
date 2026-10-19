class_name JournalScreen
extends CanvasLayer
## The quest journal, the codex and the bestiary (plan §5.5, §5.6). Quests: Main (the story's spine) and Other (side
## and companion quests) as tabs, a search box over both, the tab's quests as a list (open ones newest first, then the
## finished ones; the Other tab under a heading for each region, in the campaign's order, Ashwin 2026-10-18), and beside
## it the one picked: the journal text of every stage reached, its current objectives, a
## Hint button for what to do next and Track, which makes it the quest the HUD follows (Ashwin, 2026-10-09). Then the
## books, letters and notes the party has read, and what it has learned of the creatures it fought (BestiaryPage, U8).
## The reading text follows the player's text size (UiScale.text). On a pad LB/RB change the page, LT/RT Main and
## Other, Y goes to the search box and A there opens the pad's keyboard.
##
## The search (Ashwin, 2026-10-19) finds quests by what the journal shows of them: the name, who gave the quest, the place
## (its region), the entries of the stages reached and the current objectives, never the summary or the hint. Chips beside
## it keep All, Open, Done or Failed quests, Ctrl+F or / (Y on a pad) goes to the box, Esc or B clears it and leaves it, and
## a list with nothing to show says why and offers to clear the search.

const TABS: Array[String] = ["Quests", "Codex", "Bestiary"]
const QUEST_TABS: Array[String] = ["Main", "Other"]
const LIST_W := 340.0
## How wide the picked quest's text wraps, beside the list.
const DETAIL_W := 680.0
## The status chips: {status: label}, in order.
const STATUS_CHIPS := {"all": "All", "active": "Open", "success": "Done", "failure": "Failed"}

var root: Node
var st: StoryState
var tab := "Quests"
## Main or Other ("" until the journal opens: the tracked quest's tab, else Main while it has an open quest).
var quest_tab := ""
## What the search box holds: every word must appear in a quest's name, giver, place, journal text or objectives.
var search := ""
## Which quests the chips keep: "all", or the status "active" (Open), "success" (Done) or "failure" (Failed).
var status_filter := "all"
## The quest shown beside the list ("" for the tracked one, else the first in the list).
var picked := ""
## The creature the Bestiary shows ("" for the first).
var beast := ""
## Quests whose hint the player asked for while the journal is open: {quest id: true}. Hints stay hidden until asked
## for, so the journal never spoils on its own.
var hints_shown := {}
var _frame: VBoxContainer
## The quest page's parts that redraw as the search changes, so the search box keeps its focus and caret.
var _quest_tabs: HBoxContainer
var _quest_body: HBoxContainer
var _search_box: LineEdit
var _chip_row: HFlowContainer


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
	_frame.add_child(UiParts.tab_strip(TABS, tab, func(t: String) -> void: _turn_to(t),
		{"Quests": "journal", "Codex": "search", "Bestiary": "attack"}))
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(pane)
	if tab == "Bestiary":
		pane.add_child(BestiaryPage.build(st, beast, func(id: String) -> void:
			beast = id
			_draw()))
		return
	if tab == "Quests":
		pane.add_child(_quest_page())
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pane.add_child(UiParts.fill_scroll(box))
	_codex(box)


func _turn_to(t: String) -> void:
	var forward := TABS.find(t) > TABS.find(tab)
	tab = t
	_draw()
	UiMotion.turn_page(_frame.get_child(1) as Control, forward)


## LB/RB: the journal's pages (its own, so the Main and Other tabs under them don't take the shoulders).
func pad_tab(step: int) -> void:
	_turn_to(TABS[posmod(TABS.find(tab) + step, TABS.size())])


## LT/RT: Main and Other, on the Quests page.
func pad_trigger(step: int) -> void:
	if tab == "Quests":
		_pick_quest_tab(QUEST_TABS[posmod(QUEST_TABS.find(quest_tab) + step, QUEST_TABS.size())])


func pad_prompts() -> Array:
	return [["lb+rb", "Pages"], ["lt+rt", "Main / Other"], ["y", "Search"]] if tab == "Quests" else [["lb+rb", "Pages"]]


## Y: to the search box (A there opens the keyboard).
func pad_button(button: int) -> bool:
	if button == JOY_BUTTON_Y and tab == "Quests" and _search_box != null and is_instance_valid(_search_box):
		_search_box.grab_focus()
		return true
	return false


## Ctrl+F or / goes to the search box on the Quests page.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or tab != "Quests" or _search_box == null or not is_instance_valid(_search_box):
		return
	if key.keycode == KEY_SLASH or (key.keycode == KEY_F and (key.ctrl_pressed or key.meta_pressed)):
		get_viewport().set_input_as_handled()
		_search_box.grab_focus()


# --- Quests ---------------------------------------------------------------------------------------------------------

## Main and Other with their counts, the search box, and below them the list and the picked quest.
func _quest_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if quest_tab == "":
		quest_tab = _opening_tab()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_quest_tabs = HBoxContainer.new()
	_quest_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_quest_tabs)
	top.add_child(_search_row())
	page.add_child(top)
	_chip_row = HFlowContainer.new()
	_chip_row.name = "StatusChips"
	_chip_row.add_theme_constant_override("h_separation", 8)
	_chip_row.add_theme_constant_override("v_separation", 4)
	page.add_child(_chip_row)
	_quest_body = HBoxContainer.new()
	_quest_body.add_theme_constant_override("separation", 14)
	_quest_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_quest_body)
	_fill_quests()
	return page


## The tab the journal opens on: the tracked quest's, else Main while it has an open quest, else Other if it has any.
func _opening_tab() -> String:
	var all := QuestLog.journal(st)
	for q in all:
		if bool(q["tracked"]):
			return "Main" if str(q["kind"]) == "main" else "Other"
	for q in all:
		if str(q["kind"]) == "main" and str(q["status"]) == "active":
			return "Main"
	for q in all:
		if str(q["kind"]) == "other":
			return "Other"
	return "Main"


func _pick_quest_tab(t: String) -> void:
	if t == quest_tab:
		return
	quest_tab = t
	picked = ""
	_fill_quests()


## The search box (a gilt glass before it). Only the tabs, list and quest redraw as the text changes.
func _search_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiParts.drawn(Vector2(24, 30), func(c: Control) -> void:
		var at := Vector2(10, c.size.y / 2.0 - 2.0)
		c.draw_arc(at, 7.0, 0.0, TAU, 24, Look.color("gilt"), 2.0, true)
		c.draw_line(at + Vector2(5, 5), at + Vector2(12, 12), Look.color("gilt"), 3.0, true)
		UiParts.diamond(c, at, 2.5, Look.color("gilt_light"), true)))
	var box := LineEdit.new()
	box.name = "QuestSearch"
	box.placeholder_text = "Search quests"
	box.tooltip_text = "Finds quests by name, who gave them, where they are and what you have learned of them."
	box.text = search
	box.clear_button_enabled = true
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_font_size_override("font_size", 15)
	box.add_theme_color_override("clear_button_color", Look.color("gilt"))
	box.add_theme_color_override("clear_button_color_pressed", Look.color("gilt_light"))
	box.text_changed.connect(func(t: String) -> void:
		search = t
		_fill_quests())
	box.gui_input.connect(_search_keys)
	_search_box = box
	row.add_child(box)
	return row


## Esc or B in the search box: what was typed is cleared and the box is left, so the next Esc or B closes the journal (the
## box would otherwise keep that first press to itself, leaving editing with nothing to see). A pad with no focus spends its
## next press getting some back, so it is given the picked quest's row to stand on.
func _search_keys(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _search_box != null:
		_search_box.accept_event()
		if search != "":
			_search_box.text = ""
			search = ""
			_fill_quests()
		_search_box.release_focus()
		var row := find_child("Quest_" + picked, true, false)
		if PadNav.active() and row != null and row.get_child_count() > 0:
			UiFeel.pad.focus_on(row.get_child(row.get_child_count() - 1) as Control)


## Whether every word of `text` is in what the journal shows of the quest: its name, who gave it, its place, the journal
## text of the stages reached and its objectives. Never its summary or its hint: the card doesn't show them, and a summary
## can tell more than the party has found out.
static func matches(text: String, q: Dictionary) -> bool:
	if text.strip_edges() == "":
		return true
	var hay := " ".join([str(q["name"]), str(q.get("giver_name", "")), QuestRegions.title(str(q.get("region", ""))),
		" ".join(q["entries"] as Array), " ".join(q["objectives"] as Array)]).to_lower()
	for word in text.to_lower().split(" ", false):
		if not hay.contains(word):
			return false
	return true


## The quests under `t` that the search keeps: open ones newest first, then the finished ones, newest first; Other's
## grouped by region (by_region).
func _shown(all: Array[Dictionary], t: String) -> Array[Dictionary]:
	var open: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	for q in all:
		if (str(q["kind"]) == "main") != (t == "Main") or not matches(search, q) \
				or (status_filter != "all" and str(q["status"]) != status_filter):
			continue
		if str(q["status"]) == "active":
			open.push_front(q)
		else:
			done.push_front(q)
	open.append_array(done)
	return open if t == "Main" else by_region(open)


## Quests grouped by their region (QuestRegions order), each region keeping the order they came in.
static func by_region(quests: Array[Dictionary]) -> Array[Dictionary]:
	var groups := {}
	for q in quests:
		var region := str(q.get("region", QuestRegions.NONE))
		if not groups.has(region):
			groups[region] = [] as Array[Dictionary]
		(groups[region] as Array[Dictionary]).append(q)
	var regions: Array = groups.keys()
	regions.sort_custom(func(a: String, b: String) -> bool: return QuestRegions.before(a, b))
	var out: Array[Dictionary] = []
	for region: String in regions:
		out.append_array(groups[region] as Array[Dictionary])
	return out


func _fill_quests() -> void:
	for holder: Control in [_quest_tabs, _chip_row, _quest_body]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	var all := QuestLog.journal(st)
	var shown := _shown(all, quest_tab)
	# A search that finds nothing here but something under the other tab turns to it.
	var other := QUEST_TABS[1 - QUEST_TABS.find(quest_tab)]
	if shown.is_empty() and search.strip_edges() != "" and not _shown(all, other).is_empty():
		quest_tab = other
		shown = _shown(all, quest_tab)
	_fill_chips(all)
	var labels: Array[String] = []
	for t in QUEST_TABS:
		labels.append("%s  %d" % [t, _shown(all, t).size()])
	var strip := UiParts.tab_strip(labels, labels[QUEST_TABS.find(quest_tab)], func(label: String) -> void:
		_pick_quest_tab(QUEST_TABS[labels.find(label)]), {}, 14)
	strip.remove_meta(&"pad_tabs")   # LT/RT step these (pad_trigger); LB/RB stay the journal's pages
	strip.custom_minimum_size = Vector2(LIST_W, 0)   # over the list they choose
	_quest_tabs.add_child(strip)
	var ids := shown.map(func(q: Dictionary) -> String: return str(q["id"]))
	if not picked in ids:
		picked = ""
		for q in shown:
			if bool(q["tracked"]):
				picked = str(q["id"])
		# Else the first open quest in the list (Other's regions may put a finished one first), else the first.
		for q in shown:
			if picked == "" and str(q["status"]) == "active":
				picked = str(q["id"])
		if picked == "" and not shown.is_empty():
			picked = str(shown[0]["id"])
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var left := UiParts.fill_scroll(list)
	left.name = "QuestList"
	left.size_flags_horizontal = Control.SIZE_FILL
	left.custom_minimum_size = Vector2(LIST_W, 0)
	_quest_body.add_child(left)
	if shown.is_empty():
		var kept := str(STATUS_CHIPS[status_filter]).to_lower() + " " if status_filter != "all" else ""
		var why := ""
		if search.strip_edges() != "":
			why = "No %squest matches \"%s\"." % [kept, search.strip_edges()]
		elif status_filter != "all":
			why = "No %squests under %s." % [kept, quest_tab]
		else:
			why = "No main quests yet." if quest_tab == "Main" else "No other quests yet. Ask around: people's rumours start them."
		list.add_child(UiKit.label(why, UiScale.text(15), "bone", LIST_W - 20.0))
		if search.strip_edges() != "" or status_filter != "all":
			var clear := UiParts.small_button("Clear search" if search.strip_edges() != "" else "Show all", _clear_search)
			clear.name = "ClearSearch"
			var holder := HBoxContainer.new()
			holder.add_child(clear)
			list.add_child(holder)
		return
	var finished_shown := false
	var region := ""
	var counts := {}
	for q in shown:
		counts[str(q["region"])] = int(counts.get(str(q["region"]), 0)) + 1
	for q in shown:
		if quest_tab == "Other":
			if str(q["region"]) != region:
				list.add_child(_region_heading(str(q["region"]), int(counts[str(q["region"])]), region == ""))
				region = str(q["region"])
		elif str(q["status"]) != "active" and not finished_shown:
			finished_shown = true
			list.add_child(UiKit.label("Finished", UiScale.text(13), "bone"))
		list.add_child(_quest_row(q))
	for q in shown:
		if str(q["id"]) == picked:
			var right := UiParts.fill_scroll(_quest_card(q))
			right.name = "QuestEntry"
			_quest_body.add_child(right)


## The chips under the search: All, Open, Done and Failed with how many quests each keeps under the tab and the words
## searched for, the one in force lit, and a reminder of how to get to the box (Ctrl+F or / on a keyboard, Y on a pad).
func _fill_chips(all: Array[Dictionary]) -> void:
	var counts := {"all": 0, "active": 0, "success": 0, "failure": 0}
	for q in all:
		if (str(q["kind"]) == "main") == (quest_tab == "Main") and matches(search, q):
			counts["all"] = int(counts["all"]) + 1
			counts[str(q["status"])] = int(counts[str(q["status"])]) + 1
	_chip_row.add_child(UiKit.label("Show", UiScale.text(13), "parchment"))
	for status: String in STATUS_CHIPS:
		var chip := UiParts.small_button("%s  %d" % [STATUS_CHIPS[status], int(counts[status])], func() -> void:
			status_filter = status
			_fill_quests())
		chip.name = "Chip_" + status
		if status == status_filter:
			UiParts.light_up(chip)
		_chip_row.add_child(chip)
	var hint := UiKit.label("", 13, "parchment")
	PadGlyphs.hint(hint, "Ctrl+F or /  to search", "{y}  to search")
	_chip_row.add_child(hint)


## Empties the search box and puts the chips back to All.
func _clear_search() -> void:
	search = ""
	status_filter = "all"
	if _search_box != null and is_instance_valid(_search_box):
		_search_box.text = ""
	_fill_quests()


## A region's heading over its side quests: its name (wrapping rather than spilling) and how many, a gilt rule under it.
func _region_heading(region_id: String, count: int, first: bool) -> Control:
	var gap := MarginContainer.new()
	gap.name = "Region_" + region_id
	gap.add_theme_constant_override("margin_top", 0 if first else 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	gap.add_child(box)
	var t := UiKit.label("%s  %d" % [QuestRegions.title(region_id), count], UiScale.text(15), "gilt")
	t.add_theme_font_override("font", UiKit.display_font())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(1, 0)
	box.add_child(t)
	var rule := UiParts.drawn(Vector2(10, 6), func(c: Control) -> void:
		var y := c.size.y / 2.0
		UiParts.diamond(c, Vector2(4, y), 3.0, Look.color("gilt"), true)
		c.draw_line(Vector2(10, y), Vector2(c.size.x, y), Color(Look.color("gilt_dark"), 0.9), 1.0))
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(rule)
	return gap


## A quest in the list: its name, a gilt diamond while open (lit when tracked), its ending once over.
func _quest_row(q: Dictionary) -> Control:
	var status := str(q["status"])
	var lit := str(q["id"]) == picked
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var tracked := bool(q["tracked"])
	line.add_child(UiParts.drawn(Vector2(14, 24), func(c: Control) -> void:
		if status == "active":
			UiParts.diamond(c, c.size / 2.0, 5.0 if tracked else 3.5, Look.color("gilt_light" if tracked else "gilt"), tracked)))
	var name_ := UiKit.label(str(q["name"]), UiScale.text(15), ("gilt_light" if lit else "vellum") if status == "active" else "bone")
	name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_.clip_text = true
	name_.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_.custom_minimum_size = Vector2(1, 0)
	name_.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_)
	if tracked:
		line.add_child(UiParts.pill("Tracked", "moonlight", 12))
	elif status == "success":
		line.add_child(UiKit.label("Done", 12, "bile"))
	elif status != "active":
		line.add_child(UiKit.label("Failed", 12, "rose"))
	var qid := str(q["id"])
	var r := UiParts.click_row(line, func() -> void:
		picked = qid
		_fill_quests(), lit)
	r.name = "Quest_" + qid
	if lit:
		r.get_child(r.get_child_count() - 1).set_meta(&"pad_first", true)   # the pad starts on the picked quest's button
	return r


## The picked quest: its name and state, Track, the journal text of every stage reached, its objectives and its hint.
func _quest_card(q: Dictionary) -> Control:
	var status := str(q["status"])
	var qid := str(q["id"])
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var t := UiKit.header(str(q["name"]))
	t.add_theme_color_override("font_color", Look.color("gilt_light" if status == "active" else "bone"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(1, 0)
	head.add_child(t)
	match status:
		"active":
			head.add_child(UiParts.pill("Open", "moonlight", 13))
		"success":
			head.add_child(UiParts.pill("Completed", "bile", 13))
		_:
			head.add_child(UiParts.pill("Failed", "rose", 13))
	col.add_child(head)
	if str(q.get("giver_name", "")) != "":
		col.add_child(UiKit.label("Given by %s" % q["giver_name"], UiScale.text(14), "parchment", DETAIL_W))
	if status == "active":
		var tracked := bool(q["tracked"])
		var b := UiParts.small_button("Stop tracking" if tracked else "Track", func() -> void:
			QuestLog.track(st, "" if tracked else qid)
			_fill_quests())
		b.name = "Track_" + qid
		b.tooltip_text = "The quest the HUD follows: its objective shows under the clock." if not tracked \
			else "Stop following it: the HUD shows the newest quest's objective again."
		if tracked:
			UiParts.light_up(b)
		var row := HBoxContainer.new()
		row.add_child(b)
		col.add_child(row)
	for text: String in q["entries"]:
		col.add_child(UiKit.label(text, UiScale.text(15), "vellum" if status == "active" else "parchment", DETAIL_W))
	for o: String in q["objectives"]:
		var orow := HBoxContainer.new()
		orow.add_theme_constant_override("separation", 8)
		orow.add_child(UiParts.mark(1))
		orow.add_child(UiKit.label(o, UiScale.text(15), "gilt_light", DETAIL_W - 30.0))
		col.add_child(orow)
	if status == "active" and str(q.get("warn", "")) != "":
		var warn := UiKit.label(str(q["warn"]), UiScale.text(15), "flame", DETAIL_W)   # time is running (the quest's `closes`)
		warn.name = "Warning"
		col.add_child(warn)
	if status == "active":
		var who := _talk_to(qid)
		if who != null:
			col.add_child(who)
	if status == "active" and str(q.get("hint", "")) != "":
		col.add_child(_hint(qid, str(q["hint"])))
	return UiParts.row(col, Callable(), false, 12)


## Who to talk to next for an open quest (owner ask 2026-10-12): the portrait, name and place of each person whose
## conversation moves it on now (QuestGuide), at most three; null when it doesn't need anyone talked to.
func _talk_to(quest_id: String) -> Control:
	var targets := QuestGuide.targets_for(st, quest_id)
	if targets.is_empty():
		return null
	var box := VBoxContainer.new()
	box.name = "TalkTo"
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiKit.label("Talk to", UiScale.text(14), "parchment"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var c := Compendium.shared()
	for t: Dictionary in targets.slice(0, 3):
		var npc := c.get_entry("npcs", str(t["npc"]))
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 10)
		card.add_child(UiParts.framed_portrait(str(npc.get("portrait", t["npc"])), 64.0))
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(UiKit.label(str(npc.get("name", t["npc"])), UiScale.text(16), "bile"))
		words.add_child(UiKit.label(str(c.get_entry("locations", str(t["location"])).get("name", "")), UiScale.text(13), "parchment"))
		card.add_child(words)
		row.add_child(card)
	return box


## What to do next for an open quest (its stage's `hint`): a Hint button that shows the hint beside it, and hides it
## again. The button stays put, so a pad keeps its focus.
func _hint(quest_id: String, hint: String) -> Control:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 10)
	var text := UiKit.label(hint, UiScale.text(14), "parchment", DETAIL_W - 110.0)
	text.name = "HintText"
	text.visible = hints_shown.has(quest_id)
	var b := UiParts.small_button("Hide hint" if text.visible else "Hint", func() -> void:
		text.visible = not text.visible
		if text.visible:
			hints_shown[quest_id] = true
		else:
			hints_shown.erase(quest_id)
		(holder.get_child(0) as Button).text = "Hide hint" if text.visible else "Hint")
	b.name = "Hint_" + quest_id
	b.tooltip_text = "What to do next: where to go and who to see, never the twist."
	holder.add_child(b)
	holder.add_child(text)
	return holder


func _codex(box: VBoxContainer) -> void:
	if st.codex.is_empty():
		box.add_child(UiKit.label("Nothing read yet. Books, letters and notes you read appear here.", 16, "bone"))
	for id in st.codex:
		var entry := _codex_entry(id)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.add_child(UiKit.header(str(entry["title"])))
		col.add_child(UiKit.label(str(entry["text"]), UiScale.text(15), "vellum", 1060))
		box.add_child(UiParts.row(col, Callable(), false, 12))


## A codex entry's title and text: from the book prop that grants it, the skill check that learned it (WorldChecks), or
## its Narrator examine line.
static func _codex_entry(id: String) -> Dictionary:
	for loc in Compendium.shared().all("locations"):
		for p: Variant in loc.get("props", []):
			var prop := p as Dictionary
			if str(prop.get("codex", prop["id"])) == id and str(prop["kind"]) == "book":
				var text := str(prop.get("text", ""))
				return {"title": str(prop.get("label", id)), "text": text if text != "" else "(Read in %s.)" % loc.get("name", "")}
		for c in WorldChecks.all_in(loc):
			var codex := ((c["check"] as Dictionary).get("success", {}) as Dictionary).get("codex", {}) as Dictionary
			if str(codex.get("id", "")) == id:
				return {"title": str(codex.get("title", id)), "text": str(codex.get("text", ""))}
	# A book carried and read (the Tome of Strahd): the item's own codex entry.
	var item := Compendium.shared().item_data(id)
	if item.has("codex"):
		return (item["codex"] as Dictionary).duplicate()
	return {"title": id.replace("_", " ").capitalize(), "text": ""}
