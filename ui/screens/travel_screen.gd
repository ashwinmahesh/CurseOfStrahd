class_name TravelScreen
extends CanvasLayer
## The map of Barovia (plan §5.2, ADR 0010): the places the party knows and the roads between them, drawn on a
## parchment panel. Pick a place to see the way there (roads, hours, when you'd arrive, day or night) and set out.
## Opened from a way out of town (`setting_out`), or just to look (M).

signal travel_chosen(place_id: String)
signal closed

const MAP_SIZE := Vector2(1100, 640)

var st: StoryState
var here := ""
var setting_out := false
var _map: Control
var _info: VBoxContainer
var _target := ""
var _bounds := Rect2()


func _init() -> void:
	name = "TravelScreen"
	layer = 31


func open_map(state: StoryState, from_place: String, can_travel: bool) -> void:
	st = state
	here = from_place
	setting_out = can_travel
	var frame := UiKit.screen_frame(self, "Barovia", Vector2(1500, 820))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	frame.add_child(row)
	_map = Control.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	row.add_child(_map)
	_info = VBoxContainer.new()
	_info.custom_minimum_size = Vector2(320, 0)
	row.add_child(_info)
	_show_info()


## Where a place sits on the panel: the known places are fitted to the panel with a margin, so a handful of nearby
## places spread out instead of bunching in a corner of the valley.
func _pos(pl: Dictionary) -> Vector2:
	var p := pl["pos"] as Array
	var at := Vector2(float(p[0]), float(p[1]))
	if _bounds.size == Vector2.ZERO:
		var lo := Vector2(1, 1)
		var hi := Vector2(0, 0)
		for k in Travel.known(st):
			var kp := k["pos"] as Array
			lo = lo.min(Vector2(float(kp[0]), float(kp[1])))
			hi = hi.max(Vector2(float(kp[0]), float(kp[1])))
		var span := (hi - lo).max(Vector2(0.25, 0.25))
		var center := (lo + hi) / 2.0
		_bounds = Rect2(center - span / 2.0, span)
	var margin := Vector2(140, 90)
	var rel := (at - _bounds.position) / _bounds.size
	return margin + rel * (MAP_SIZE - margin * 2.0)


func _draw_map() -> void:
	_map.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Look.color("bone_dark"))
	_map.draw_rect(Rect2(Vector2(8, 8), MAP_SIZE - Vector2(16, 16)), Look.color("parchment"))
	var places := {}
	for p in Travel.known(st):
		places[str(p["id"])] = p
	var route_roads := {}
	if _target != "" and _target != here:
		for leg in Travel.route(here, _target, st):
			route_roads[str((leg["road"] as Dictionary)["id"])] = true
	var font := ThemeDB.fallback_font
	for road in Travel.roads(st):
		var a := places[str(road["from"])] as Dictionary
		var b := places[str(road["to"])] as Dictionary
		var on_route := route_roads.has(str(road["id"]))
		_map.draw_line(_pos(a), _pos(b), Look.color("vampire_red") if on_route else Look.color("umber"), 5.0 if on_route else 3.0)
		var mid := (_pos(a) + _pos(b)) / 2.0
		_map.draw_string(font, mid + Vector2(6, -6), "%sh" % _hours_text(float(road["hours"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.color("peat"))
	var n := 0
	for id: String in places:
		var pl := places[id] as Dictionary
		var at := _pos(pl)
		var colour := Look.color("vampire_red") if id == here else (Look.color("ember") if id == _target else Look.color("ink"))
		_map.draw_circle(at, 11.0 if id == here else 8.0, colour)
		# Names alternate above and below their mark so neighbours don't print over each other.
		var name_s := str(pl["name"])
		var w := font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var off := Vector2(-w / 2.0, -16.0 if n % 2 == 0 else 30.0)
		_map.draw_string(font, at + off, name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Look.color("ink"))
		n += 1


func _on_map_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed):
		return
	var at := (ev as InputEventMouseButton).position
	var best := ""
	var best_d := 30.0
	for p in Travel.known(st):
		var d := _pos(p).distance_to(at)
		if d < best_d:
			best_d = d
			best = str(p["id"])
	if best != "":
		select(best)


func select(place_id: String) -> void:
	_target = place_id
	_map.queue_redraw()
	_show_info()


func _show_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var cur := Travel.place(here)
	_info.add_child(UiKit.header("You are at %s" % cur.get("name", "the edge of the map")))
	_info.add_child(UiKit.label("Day %d · %02d:%02d" % [st.day, st.minute_of_day / 60, st.minute_of_day % 60], 15, "parchment"))
	if _target == "" or _target == here:
		_info.add_child(UiKit.label("Choose a place on the map.", 15, "vellum", 300))
	else:
		var to := Travel.place(_target)
		_info.add_child(UiKit.title(str(to["name"])))
		if str(to.get("summary", "")) != "":
			_info.add_child(UiKit.label(str(to["summary"]), 14, "vellum", 300))
		var legs := Travel.route(here, _target, st)
		if legs.is_empty():
			_info.add_child(UiKit.label("No road you know leads there.", 15, "candle", 300))
		else:
			var h := Travel.hours(legs)
			var arrive := (st.minute_of_day + roundi(h * 60.0)) % (24 * 60)
			var night := arrive < 6 * 60 or arrive >= 19 * 60
			var names: Array[String] = []
			for l in legs:
				var rn := str((l["road"] as Dictionary).get("name", "a road"))
				if names.is_empty() or names.back() != rn:
					names.append(rn)
			_info.add_child(UiKit.label("By %s" % ", then ".join(names), 14, "vellum", 300))
			_info.add_child(UiKit.label("%s hours · arriving about %02d:%02d%s" % [_hours_text(h), arrive / 60, arrive % 60,
				" (after dark: the roads are worse at night)" if night else ""], 15, "candle" if night else "parchment", 300))
			var go := UiKit.button("Set out", func() -> void:
				travel_chosen.emit(_target)
				queue_free(), 18)
			go.disabled = not setting_out
			if not setting_out:
				go.tooltip_text = "Set out from a road out of town."
			_info.add_child(go)
	_info.add_child(UiKit.button("Close", func() -> void:
		closed.emit()
		queue_free(), 15))


static func _hours_text(h: float) -> String:
	return str(int(h)) if is_equal_approx(h, roundf(h)) else "%.1f" % h


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
