class_name ThingLabels
extends Control
## Hold Alt (the "show_names" key, Settings, Keys) while exploring to see what can be used (docs/plans/ui_polish.md, like BG3's highlight key): every person,
## door, container, thing to examine and way out in view gets its name on a small dark plate above it, in screen
## space so it stays sharp. A locked door or chest says so, an emptied one reads "empty", and a sleeper "asleep, prone".
## Nothing in an area the party hasn't found, no unfound secret door and no unsearched hiding place is shown (they go
## through LocationView.thing_at, which already hides them).

var view: LocationView
## Ways out that already carry a sign of their own (ExitSigns), so they get no second plate.
var signed := {}
## On while the names key is held (or `pinned` for captures and tests).
var showing := false
var pinned := false
const FONT_SIZE := 14
const PAD := Vector2(8, 3)
## Only things this near the leader (squares), like a torch's reach and a bit: the far dark stays unknown.
const REACH := 12
## Height of each kind's plate above its floor (world units).
const LIFT := {"npc": 1.75, "door": 1.7, "exit": 1.7, "container": 1.0, "prop": 1.2}


func _init() -> void:
	name = "ThingLabels"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_location(v: LocationView, signs: Array[Dictionary] = []) -> void:
	view = v
	signed = {}
	for e in signs:
		signed[e["cell"] as Vector2i] = true
	queue_redraw()


func _process(_delta: float) -> void:
	var on := pinned or (Input.is_action_pressed(&"show_names") and is_visible_in_tree())
	if on != showing or on:
		showing = on
		queue_redraw()


## What the plates say now: [{text, kind, at (screen), dim}], nearest the camera last so it's drawn on top.
func plates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if view == null or not is_instance_valid(view) or view.rig == null or view.in_combat or view.members.is_empty():
		return out
	var cam := view.rig.camera
	var seen := {}
	var ours := {}
	for m: Combatant in view.members + view.guest_members:
		ours[m.cell] = true
	var lead := view.leader().cell
	for entry: Array in view.call("_pickables"):
		var cell := entry[1] as Vector2i
		if seen.has(cell) or ours.has(cell) or signed.has(cell) or maxi(absi(cell.x - lead.x), absi(cell.y - lead.y)) > REACH:
			continue
		seen[cell] = true
		var thing := view.thing_at(cell)
		if thing.is_empty():
			continue
		var kind := str(thing["kind"])
		var w := Vector3(cell.x + 0.5, view.board.floor_y(cell) + float(LIFT.get(kind, 1.4)), cell.y + 0.5)
		if cam.is_position_behind(w):
			continue
		var at := cam.unproject_position(w)
		if not get_viewport_rect().grow(-8).has_point(at):
			continue
		var name_and_dim := _name(thing)
		out.append({"text": name_and_dim[0], "kind": kind, "at": at, "dim": name_and_dim[1],
			"depth": cam.global_position.distance_to(w)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["depth"]) > float(b["depth"]))
	return out


## The plate's words and whether it's drawn dim (an emptied chest, a way that's shut for now).
func _name(thing: Dictionary) -> Array:
	var spec := thing.get("spec", {}) as Dictionary
	match str(thing["kind"]):
		"npc":
			var state := LocationNpcs.state_words(view, str(thing["id"]))
			return [str(Compendium.shared().get_entry("npcs", str(thing["id"])).get("name", thing["id"])) + (" · " + state if state != "" else ""), false]
		"door":
			var door := _first_up(str(spec.get("label", "door")).trim_prefix("the "))
			return [door + (" · locked" if bool(view.call("_locked", spec)) else ""), false]
		"container":
			var looted := bool((view.st.loc_state(view.loc_id)["looted"] as Dictionary).get(str(thing["id"]), false))
			var box := _first_up(str(spec.get("label", "chest")).trim_prefix("the "))
			if looted:
				return [box + " · empty", true]
			return [box + (" · locked" if bool(view.call("_locked", spec)) else ""), false]
		"exit":
			var open := StoryConditions.check(str(spec.get("when", "")), view.st)
			return [_first_up(str(spec.get("label", "Leave"))), not open]
		"trap":
			return [str(spec.get("label", "Trap")), false]
	if str(thing["kind"]) == "prop":
		return [_first_up(LocationInteraction.prop_name(spec).trim_prefix("the ")), false]
	return [_first_up(str(spec.get("label", thing.get("label", ""))).trim_prefix("the ")), false]


## "a straw pallet" -> "Straw pallet": no article, a capital first.
static func _first_up(t: String) -> String:
	for art: String in ["the ", "a ", "an "]:
		if t.to_lower().begins_with(art):
			t = t.substr(art.length())
	return t if t == "" else t[0].to_upper() + t.substr(1)


func _draw() -> void:
	if not showing:
		return
	var font := ThemeDB.fallback_font
	var placed: Array[Rect2] = []
	for p in plates():
		var text := str(p["text"])
		if text == "":
			continue
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE) + PAD * 2.0
		var at := p["at"] as Vector2
		var r := Rect2(at - Vector2(size.x / 2.0, size.y), size)
		# Plates that would overlap step up out of each other's way.
		for i in 6:
			var hit := false
			for q in placed:
				if q.grow(2).intersects(r):
					r.position.y = q.position.y - r.size.y - 3.0
					hit = true
			if not hit:
				break
		# Kept on the screen.
		r.position = r.position.clamp(Vector2(4, 4), get_viewport_rect().size - r.size - Vector2(4, 4))
		placed.append(r)
		var dim := bool(p["dim"])
		var edge := Look.color("pewter") if dim else _edge(str(p["kind"]))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Look.color("ui_black"), 0.86)
		sb.border_color = Color(edge, 0.9)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.corner_detail = 1
		draw_style_box(sb, r)
		# A short stem down to the thing it names.
		draw_line(Vector2(r.get_center().x, r.end.y), Vector2(r.get_center().x, minf(at.y + 6.0, r.end.y + 14.0)), Color(edge, 0.6), 1.0)
		var colour := Look.color("bone") if dim else Look.color("vellum")
		var base := Vector2(r.position.x + PAD.x, r.position.y + PAD.y + font.get_ascent(FONT_SIZE))
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Look.color("void"))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


## The plate's edge says what it is at a glance: people in moonlight, ways out in bright gold, the rest in gilt.
static func _edge(kind: String) -> Color:
	match kind:
		"npc":
			return Look.color("moonlight")
		"exit":
			return Look.color("gilt_light")
		"trap":
			return Look.color("vampire_red")
	return Look.color("gilt")
