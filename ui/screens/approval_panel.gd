class_name ApprovalPanel
extends RefCounted
## How the six companions feel about the party (F3, story/approval.gd), for the party screen: a card per companion in
## the company (travelling first, then those at camp) with their tier, a bar from Estranged to Devoted, and the last
## moments they remember, liked or not. A companion's party card wears the same tier as a pill.

const CARD_WIDTH := 455.0
const BAR_WIDTH := 300.0
## Moments shown on a card; the rest are in its tooltip.
const SHOWN := 3


## The whole section, or null when nobody in the company is one of the six (a party of custom characters).
static func build(st: StoryState) -> Control:
	var who: Array[Character] = []
	for ch in st.roster():
		if Approval.is_companion(ch.id) and StoryState.member_matches(ch, "name:" + ch.id):
			who.append(ch)
	if who.is_empty():
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiParts.section("How the company feels about you"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for ch in who:
		grid.add_child(_card(st, ch, ch in st.party))
	box.add_child(grid)
	box.add_child(UiKit.label("Companions travelling with you see what you choose and remember it. Those at camp only hear about it later, if at all.", 13, "parchment", 1400))
	return box


## A companion's tier as a small pill (on their party card), with what it means on hover. Null for anyone else.
static func tier_pill(st: StoryState, ch: Character) -> Control:
	if not Approval.is_companion(ch.id) or not StoryState.member_matches(ch, "name:" + ch.id):
		return null
	var t := Approval.tier(st, ch.id)
	var p := UiParts.pill(str(t["name"]), str(t["colour"]))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return UiParts.tipped(p, func() -> Control: return _tip(st, ch))


static func _card(st: StoryState, ch: Character, travelling: bool) -> Control:
	var t := Approval.tier(st, ch.id)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 54.0, false, ch.dead))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UiKit.label(ch.name, 17, "vellum"))
	names.add_child(UiParts.caption("Travelling with you" if travelling else "At camp", 10, "parchment" if travelling else "bone"))
	head.add_child(names)
	head.add_child(UiParts.pill(str(t["name"]), str(t["colour"]), 13))
	col.add_child(head)
	col.add_child(meter(Approval.score(st, ch.id), BAR_WIDTH + 100.0, 16.0))
	col.add_child(UiKit.label(str(t["says"]), 13, "parchment", CARD_WIDTH - 30.0))
	var heart := Approval.romance_line(st, ch.id)
	if heart != "":
		col.add_child(UiKit.label("♥ " + heart, 14, "rose", CARD_WIDTH - 30.0))
	var mem := Approval.memories(st, ch.id)
	if mem.is_empty():
		col.add_child(UiKit.label("Nothing you've done has stayed with them yet.", 13, "bone", CARD_WIDTH - 30.0))
	for m: Dictionary in mem.slice(0, SHOWN):
		col.add_child(_memory(m))
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.5, 10)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_child(col)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return UiParts.tipped(card, func() -> Control: return _tip(st, ch))


## "▲ You brought St. Andral's bones home" (liked) or "▼ ..." (not); doubled for a big change.
static func _memory(m: Dictionary) -> Label:
	var d := int(m["delta"])
	var mark := ("▲" if d > 0 else "▼").repeat(2 if absi(d) >= Approval.GREAT else 1)
	return UiKit.label("%s %s" % [mark, str(m["why"])], 13, "bile" if d > 0 else "rose", CARD_WIDTH - 30.0)


## The bar: Estranged on the left, Devoted on the right, a tick where each tier starts, and the score as a filled run
## from the middle (Neutral) toward it in the tier's colour.
static func meter(value: int, width: float = BAR_WIDTH, height: float = 14.0) -> Control:
	var colour := str(Approval.tier_for(value)["colour"])
	return UiParts.drawn(Vector2(width, height), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size).grow(-1.0)
		c.draw_rect(r, Look.color("void"))
		var span := float(Approval.HIGHEST - Approval.LOWEST)
		var x_of := func(v: float) -> float: return r.position.x + r.size.x * (v - Approval.LOWEST) / span
		var mid := x_of.call(0.0) as float
		var at := x_of.call(float(value)) as float
		var run := Rect2(Vector2(minf(mid, at), r.position.y + 2), Vector2(absf(at - mid), r.size.y - 4))
		c.draw_rect(run, Color(Look.color(colour), 0.85))
		for tier_info in Approval.TIERS:
			var m := int(tier_info["min"])
			if m <= Approval.LOWEST:
				continue
			# The tick sits where the tier begins: above zero at its min, below zero where the tier above ends.
			var edge := x_of.call(float(m) if m > 0 else float(m) - 0.5) as float
			c.draw_line(Vector2(edge, r.position.y), Vector2(edge, r.end.y), Color(Look.color("gilt_dark"), 0.9), 1.0)
		c.draw_line(Vector2(mid, r.position.y - 1), Vector2(mid, r.end.y + 1), Look.color("gilt"), 1.5)
		UiParts.diamond(c, Vector2(at, r.get_center().y), r.size.y * 0.42, Look.color("ivory"), true)
		c.draw_rect(r, Look.color("gilt_dark"), false, 1.0))


static func _tip(st: StoryState, ch: Character) -> Control:
	var t := Approval.tier(st, ch.id)
	var facts: Array = []
	for tier_info in Approval.TIERS:
		var here := str(tier_info["id"]) == str(t["id"])
		facts.append([("▸ " if here else "") + str(tier_info["name"]), str(tier_info["says"])])
	var lines: Array[String] = []
	for m in Approval.memories(st, ch.id):
		lines.append("%s %s (day %d)" % ["▲" if int(m["delta"]) > 0 else "▼", str(m["why"]), int(m["day"])])
	var body := "\n".join(lines) if not lines.is_empty() else "Nothing you've done has stayed with them yet."
	var heart := Approval.romance_line(st, ch.id)
	if heart != "":
		body = "♥ %s\n%s" % [heart, body]
	return UiParts.rules_tip("%s: %s" % [ch.name.get_slice(" ", 0), str(t["name"])],
		"Approval %+d, from -100 to +100" % Approval.score(st, ch.id), body, facts,
		"Choices made while they travel with you move it. Warm and better opens their confidences at camp, and romances; Close or better adds to the end of their own story; Strained or worse holds that ending back until it's mended.")
