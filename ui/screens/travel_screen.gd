class_name TravelScreen
extends CanvasLayer
## The map of Barovia (plan §5.2, ADR 0010): an illustrated gothic map of the whole valley, painted as the land itself
## (art/ui/map/barovia.png, docs/ui/travel_map.md) with the places the party knows and the roads between them drawn on
## top, so names stay sharp at any zoom. Mist covers everything the party hasn't learned of: only the land around
## known places and along known roads is clear (Travel.known: been there, one road away, or heard of). Pick a place to
## see the way there (roads, hours, when you'd arrive, day or night) and set out. The wheel zooms and dragging pans.
## Opened from a way out of town (`setting_out`), or just to look (M).

signal travel_chosen(place_id: String)
signal closed

const MAP_ART := preload("res://art/ui/map/barovia.png")
## The map panel at zoom 1: the whole valley. The art is 3:2 and a place's `pos` is a fraction of it.
const MAP_SIZE := Vector2(1152, 768)
const ZOOM_MAX := 2.4
## The most the map zooms in on what the party knows when it opens.
const ZOOM_OPEN_MAX := 1.6
const FOG_SHADER := preload("res://shaders/ui/map_fog.gdshader")
## How much land is clear around a known place (a fraction of the art's width; a place's `reveal` overrides it) and
## along a known road.
const REVEAL := 0.065
const REVEAL_ROAD := 0.028
## Castle Ravenloft on its pillar of rock is seen from everywhere in the valley: [x, y, radius] as fractions.
const ALWAYS_SEEN: Array[Array] = [[0.695, 0.73, 0.085]]
## The fog mask over the whole art, in pixels (3:2 like the art).
const MASK := Vector2i(288, 192)

var st: StoryState
var here := ""
var setting_out := false
var zoom := 1.0
## Where the art's top-left corner sits in the panel (zero or less: the art always covers the panel).
var pan := Vector2.ZERO
var _map: Control
## Above the art and its fog: roads, marks and names.
var _ink: Control
var _fog: ColorRect
## The fog mask (1 = clear) as bytes, MASK.x by MASK.y.
var _reveal := PackedByteArray()
var _info: VBoxContainer
var _target := ""
var _hover := ""
var _drag_from := Vector2(-1, -1)
var _dragged := false
var _time := 0.0
## The place the party is at for the marks and routes: `here`, or the one place of the region it's indoors in.
var _at := ""


func _init() -> void:
	name = "TravelScreen"
	layer = 31


func open_map(state: StoryState, from_place: String, can_travel: bool) -> void:
	st = state
	here = from_place
	setting_out = can_travel
	_at = here if here != "" else _place_of_region(st.location)
	var frame := UiKit.screen_frame(self, "Barovia", Vector2(1540, 840))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	# The map sits in a gilt rule with the wrought-iron corners laid over it.
	var holder := PanelContainer.new()
	var hs := UiKit.style("ui_black", "gilt", 2, 1.0)
	hs.set_content_margin_all(2)
	holder.add_theme_stylebox_override("panel", hs)
	row.add_child(holder)
	_map = Control.new()
	_map.name = "Map"
	_map.custom_minimum_size = MAP_SIZE
	_map.clip_contents = true
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_map.draw.connect(_draw_art)
	_map.gui_input.connect(_on_map_input)
	_map.mouse_exited.connect(func() -> void:
		_hover = ""
		_redraw())
	holder.add_child(_map)
	_fog = ColorRect.new()
	_fog.name = "Fog"
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = FOG_SHADER
	fm.set_shader_parameter("panel_size", MAP_SIZE)
	fm.set_shader_parameter("mist", Color(Look.color("silver"), 0.98))
	fm.set_shader_parameter("mist_dark", Color(Look.color("slate"), 0.98))
	_fog.material = fm
	_map.add_child(_fog)
	_ink = Control.new()
	_ink.name = "Ink"
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_map)
	_map.add_child(_ink)
	var corners := Control.new()
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(corners)
	UiKit.trim(corners, 60.0)
	_info = VBoxContainer.new()
	_info.custom_minimum_size = Vector2(296, 0)
	_info.add_theme_constant_override("separation", 8)
	row.add_child(_info)
	_frame_known()
	_build_reveal()
	_show_info()
	_redraw()


## The only travel place in the region of `location_id` (inside a village's tavern: the village), or "".
func _place_of_region(location_id: String) -> String:
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", ""))
	var found := ""
	for p: Variant in Travel.map_data().get("places", []):
		if str((p as Dictionary).get("region", "")) == region and region != "":
			if found != "":
				return ""
			found = str((p as Dictionary)["id"])
	return found


# --- Where things are ------------------------------------------------------------------------------

## A point on the art (fractions of the whole map) in panel pixels at the current zoom and pan.
func to_panel(frac: Vector2) -> Vector2:
	return pan + frac * MAP_SIZE * zoom


func _pos(pl: Dictionary) -> Vector2:
	var p := pl["pos"] as Array
	return to_panel(Vector2(float(p[0]), float(p[1])))


## Opens zoomed in on the places the party knows (never closer than ZOOM_OPEN_MAX), centred on them.
func _frame_known() -> void:
	var lo := Vector2(1, 1)
	var hi := Vector2(0, 0)
	for k in Travel.known(st):
		var kp := k["pos"] as Array
		lo = lo.min(Vector2(float(kp[0]), float(kp[1])))
		hi = hi.max(Vector2(float(kp[0]), float(kp[1])))
	if lo.x > hi.x:
		zoom = 1.0
		pan = Vector2.ZERO
		return
	var pad := Vector2(180, 130)
	var need := (hi - lo) * MAP_SIZE + pad * 2.0
	zoom = clampf(minf(MAP_SIZE.x / need.x, MAP_SIZE.y / need.y), 1.0, ZOOM_OPEN_MAX)
	pan = MAP_SIZE / 2.0 - (lo + hi) / 2.0 * MAP_SIZE * zoom
	_clamp()


func _clamp() -> void:
	pan = pan.clamp(MAP_SIZE - MAP_SIZE * zoom, Vector2.ZERO)


## Zooms by `factor` keeping the point under the mouse where it is.
func zoom_at(at: Vector2, factor: float) -> void:
	var z := clampf(zoom * factor, 1.0, ZOOM_MAX)
	var frac := (at - pan) / (MAP_SIZE * zoom)
	zoom = z
	pan = at - frac * MAP_SIZE * zoom
	_clamp()
	_redraw()


func _place_at(at: Vector2) -> String:
	var best := ""
	var best_d := 26.0
	for p in Travel.known(st):
		var d := _pos(p).distance_to(at)
		if d < best_d:
			best_d = d
			best = str(p["id"])
	return best


## A road on the panel: a gently bowed line (the bow's side comes from the road's id, so it never changes), or a
## smooth curve through the road's `via` points (fractions of the art, to take it round a lake or a mountain).
func road_points(road: Dictionary, a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var via := road.get("via", []) as Array
	if via.is_empty():
		var bow := 0.07 if absi(str(road["id"]).hash()) % 2 == 0 else -0.07
		var ctrl := (a + b) / 2.0 + (b - a).orthogonal() * bow
		for i in 21:
			var t := i / 20.0
			pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
		return pts
	var knots: Array[Vector2] = [a]
	for v: Variant in via:
		knots.append(to_panel(Vector2(float((v as Array)[0]), float((v as Array)[1]))))
	knots.append(b)
	# Catmull-Rom through the knots, the ends doubled.
	for k in knots.size() - 1:
		var p0 := knots[maxi(k - 1, 0)]
		var p1 := knots[k]
		var p2 := knots[k + 1]
		var p3 := knots[mini(k + 2, knots.size() - 1)]
		for i in 16:
			var t := i / 16.0
			var t2 := t * t
			pts.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t))
	pts.append(b)
	return pts


# --- Drawing ---------------------------------------------------------------------------------------

func _draw_art() -> void:
	_map.draw_texture_rect(MAP_ART, Rect2(pan, MAP_SIZE * zoom), false)
	if st.is_night():
		_map.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(Look.color("night_deep"), 0.18))


func _redraw() -> void:
	if _map == null:
		return
	_map.queue_redraw()
	_ink.queue_redraw()
	var fm := _fog.material as ShaderMaterial
	fm.set_shader_parameter("pan", pan)
	fm.set_shader_parameter("art_size", MAP_SIZE * zoom)
	fm.set_shader_parameter("time_s", _time)


## The fog mask: clear around every known place (and Castle Ravenloft) and along every known road, soft at the edges.
func _build_reveal() -> void:
	_reveal = PackedByteArray()
	_reveal.resize(MASK.x * MASK.y)
	var spots: Array[Vector3] = []
	for a in ALWAYS_SEEN:
		spots.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	for p in Travel.known(st):
		var pos := p["pos"] as Array
		spots.append(Vector3(float(pos[0]), float(pos[1]), float(p.get("reveal", REVEAL))))
	var by_id := {}
	for p in Travel.known(st):
		by_id[str(p["id"])] = p
	for road in Travel.roads(st):
		var a := _pos(by_id[str(road["from"])] as Dictionary)
		var b := _pos(by_id[str(road["to"])] as Dictionary)
		var pts := road_points(road, a, b)
		for i in range(0, pts.size(), 2):
			var f := (pts[i] - pan) / (MAP_SIZE * zoom)
			spots.append(Vector3(f.x, f.y, REVEAL_ROAD))
	for s in spots:
		var c := Vector2(s.x * MASK.x, s.y * MASK.y)
		var r := s.z * MASK.x
		for y in range(maxi(0, floori(c.y - r)), mini(MASK.y, ceili(c.y + r) + 1)):
			for x in range(maxi(0, floori(c.x - r)), mini(MASK.x, ceili(c.x + r) + 1)):
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				if d >= r:
					continue
				var v := int(255.0 * (1.0 - smoothstep(r * 0.35, r, d)))
				if v > _reveal[y * MASK.x + x]:
					_reveal[y * MASK.x + x] = v
	var img := Image.create_from_data(MASK.x, MASK.y, false, Image.FORMAT_L8, _reveal)
	(_fog.material as ShaderMaterial).set_shader_parameter("reveal", ImageTexture.create_from_image(img))


## How clear the map is at a point (fractions of the art): 0 under fog, 1 in sight.
func clear_at(frac: Vector2) -> float:
	var x := clampi(int(frac.x * MASK.x), 0, MASK.x - 1)
	var y := clampi(int(frac.y * MASK.y), 0, MASK.y - 1)
	return _reveal[y * MASK.x + x] / 255.0


func _draw_map() -> void:
	var places := {}
	for p in Travel.known(st):
		places[str(p["id"])] = p
	var route_roads := {}
	if _target != "" and _target != _at and _at != "":
		for leg in Travel.route(_at, _target, st):
			route_roads[str((leg["road"] as Dictionary)["id"])] = true
	var font := UiKit.display_font()
	var tags: Array[Array] = []
	for road in Travel.roads(st):
		var id := str(road["id"])
		var pts := road_points(road, _pos(places[str(road["from"])] as Dictionary), _pos(places[str(road["to"])] as Dictionary))
		var on_route := route_roads.has(id)
		if on_route:
			_ink.draw_polyline(pts, Color(Look.color("void"), 0.8), 10.0, true)
			_ink.draw_polyline(pts, Look.color("vampire_red"), 4.5, true)
		else:
			_dashed(pts, Color(Look.color("void"), 0.55), 6.0, 11.0, 7.0)
			_dashed(pts, Look.color("bone"), 3.0, 11.0, 7.0)
		tags.append([pts[pts.size() / 2], "%s h" % _hours_text(float(road["hours"])), on_route])
	var tag_boxes: Array[Rect2] = []
	for t: Array in tags:
		tag_boxes.append(_tag(t[0] as Vector2, str(t[1]), bool(t[2])))
	# Marks first, then names placed clear of the marks and of each other; zoomed in, only the places in view.
	var view := Rect2(Vector2.ZERO, MAP_SIZE).grow(-4.0)
	var taken: Array[Rect2] = tag_boxes.duplicate()
	for id: String in places:
		var at := _pos(places[id] as Dictionary)
		if view.has_point(at):
			taken.append(Rect2(at - Vector2(12, 12), Vector2(24, 24)))
			_mark(at, id)
	for id: String in places:
		var at := _pos(places[id] as Dictionary)
		if view.has_point(at):
			_place_name(font, at, str((places[id] as Dictionary)["name"]), id, taken)


func _mark(at: Vector2, id: String) -> void:
	var grow := 2.0 if id == _hover else 0.0
	var ink := Look.color("void")
	if id == _at:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		_ink.draw_circle(at, 15.0 + 5.0 * pulse, Color(Look.color("vampire_red"), 0.45 * (1.0 - pulse)), false, 3.0, true)
		_ink.draw_circle(at, 11.0 + grow, ink, true, -1.0, true)
		_ink.draw_circle(at, 9.0 + grow, Look.color("crimson"), true, -1.0, true)
		_ink.draw_circle(at, 9.0 + grow, Look.color("gilt_light"), false, 2.0, true)
		_ink.draw_circle(at, 3.0, Look.color("gilt_light"), true, -1.0, true)
		return
	if id == _target:
		_ink.draw_circle(at, 15.0 + grow, Look.color("gilt_light"), false, 3.0, true)
	_ink.draw_circle(at, 9.0 + grow, ink, true, -1.0, true)
	_ink.draw_circle(at, 7.0 + grow, Look.color("ui_wine") if id == _target else Look.color("bone"), true, -1.0, true)
	_ink.draw_circle(at, 3.0 + grow * 0.5, ink, true, -1.0, true)


## A place's name in pale vellum with a dark outline, like the rest of the UI, put below, above, right or left of its
## mark, wherever it's clear. The chosen destination's name sits on a small crimson plaque.
func _place_name(font: Font, at: Vector2, text: String, id: String, taken: Array[Rect2]) -> void:
	var size := 21 if id == _at or id == _target else 19
	var inside := Rect2(Vector2(6, 6), MAP_SIZE - Vector2(12, 12))
	var box := Rect2()
	var least := INF
	# Where it's crowded (every place known, zoomed out) a name may come down a size to find a clear spot.
	for try_size: int in [size, size - 3]:
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, try_size)
		# Below, above, right, left, then the corners and a step further out.
		var spots: Array[Vector2] = [at + Vector2(-sz.x / 2.0, 16), at + Vector2(-sz.x / 2.0, -16 - sz.y),
			at + Vector2(18, -sz.y / 2.0), at + Vector2(-18 - sz.x, -sz.y / 2.0),
			at + Vector2(12, 12), at + Vector2(-12 - sz.x, 12), at + Vector2(12, -12 - sz.y), at + Vector2(-12 - sz.x, -12 - sz.y),
			at + Vector2(-sz.x / 2.0, 34), at + Vector2(-sz.x / 2.0, -34 - sz.y)]
		for s in spots:
			# Kept inside the panel; the first spot clear of other marks, tags and names wins, else the least crowded.
			var r := Rect2(s.clamp(inside.position, inside.end - sz), sz)
			var crowd := 0.0
			for t in taken:
				crowd += t.intersection(r.grow(3.0)).get_area()
			if crowd < least:
				least = crowd
				box = r
				size = try_size
			if crowd == 0.0:
				break
		if least == 0.0:
			break
	var asc := font.get_ascent(size)
	taken.append(box.grow(6.0))
	var base := box.position + Vector2(0, asc)
	if id == _target and id != _at:
		var plaque := box.grow_individual(10, 3, 10, 3)
		_ink.draw_rect(plaque, Color(Look.color("void"), 0.5), true)
		_ink.draw_rect(plaque.grow(-1.0), Look.color("ui_oxblood"), true)
		_ink.draw_rect(plaque.grow(-1.0), Look.color("gilt"), false, 1.5)
		_ink.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Look.color("gilt_light"))
		return
	var colour := Look.color("gilt_light") if id == _at else (Look.color("rose") if id == _hover else Look.color("vellum"))
	_ink.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(Look.color("void"), 0.9))
	_ink.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


## A road's hours on a small black tag with a gilt (or, on the route, crimson) edge. Returns where it went.
func _tag(at: Vector2, text: String, on_route: bool) -> Rect2:
	var font := ThemeDB.fallback_font
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var r := Rect2(at - sz / 2.0 - Vector2(6, 2), sz + Vector2(12, 4))
	_ink.draw_rect(r, Color(Look.color("ui_black"), 0.9), true)
	_ink.draw_rect(r, Look.color("vampire_red") if on_route else Look.color("gilt_dark"), false, 1.5 if on_route else 1.0)
	_ink.draw_string(font, r.position + Vector2(6, 2 + font.get_ascent(13)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Look.color("gilt_light") if on_route else Look.color("vellum"))
	return r


## An inked trail: dashes along a polyline.
func _dashed(pts: PackedVector2Array, colour: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var step := minf(left, seg - t)
			if on:
				_ink.draw_line(a.lerp(b, t / seg), a.lerp(b, (t + step) / seg), colour, width, true)
			t += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash if on else gap


# --- Input -----------------------------------------------------------------------------------------

func _on_map_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, 1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_drag_from = mb.position
				_dragged = false
			else:
				if not _dragged and mb.button_index == MOUSE_BUTTON_LEFT:
					var id := _place_at(mb.position)
					if id != "":
						select(id)
				_drag_from = Vector2(-1, -1)
		_map.accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag_from.x >= 0.0 and mm.button_mask != 0:
			if _dragged or mm.position.distance_to(_drag_from) > 5.0:
				_dragged = true
				pan += mm.relative
				_clamp()
		var h := _place_at(mm.position)
		if h != _hover:
			_hover = h
		_map.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else (Control.CURSOR_DRAG if _dragged else Control.CURSOR_ARROW)
		_redraw()


func select(place_id: String) -> void:
	_target = place_id
	# Bring a destination outside the view into it.
	var pl := Travel.place(place_id)
	if not pl.is_empty() and not Rect2(Vector2(60, 60), MAP_SIZE - Vector2(120, 120)).has_point(_pos(pl)):
		pan += MAP_SIZE / 2.0 - _pos(pl)
		_clamp()
	_redraw()
	_show_info()


func _process(delta: float) -> void:
	_time += delta
	_redraw()


# --- The side panel --------------------------------------------------------------------------------

func _show_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var cur := Travel.place(_at)
	_info.add_child(UiKit.label("You are at" if here != "" else ("You are in" if _at != "" else "You are"), 14, "parchment"))
	var where := UiKit.header(str(cur.get("name", "off the roads")))
	where.add_theme_font_size_override("font_size", 23)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.custom_minimum_size = Vector2(290, 0)
	_info.add_child(where)
	_info.add_child(UiKit.label("Day %d · %02d:%02d · %s" % [st.day, st.minute_of_day / 60, st.minute_of_day % 60,
		"night" if st.is_night() else "day"], 15, "vellum"))
	_info.add_child(UiKit.divider(280))
	if _target == "" or _target == _at:
		_info.add_child(UiKit.label("Choose a place on the map to see the way there.", 15, "vellum", 290))
	else:
		var to := Travel.place(_target)
		var t := UiKit.title(str(to["name"]))
		t.add_theme_font_size_override("font_size", 27)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(290, 0)
		_info.add_child(t)
		if str(to.get("summary", "")) != "":
			_info.add_child(UiKit.label(str(to["summary"]), 14, "vellum", 290))
		var legs: Array[Dictionary] = []
		if _at != "":
			legs = Travel.route(_at, _target, st)
		if legs.is_empty():
			_info.add_child(UiKit.label("No road you know leads there from here.", 15, "gilt", 290))
		else:
			var h := Travel.hours(legs)
			var arrive := (st.minute_of_day + roundi(h * 60.0)) % (24 * 60)
			var night := arrive < 6 * 60 or arrive >= 19 * 60
			var names: Array[String] = []
			for l in legs:
				var rn := str((l["road"] as Dictionary).get("name", "a road"))
				if names.is_empty() or names.back() != rn:
					names.append(rn)
			_info.add_child(UiKit.label("By %s" % ", then ".join(names), 14, "parchment", 290))
			_info.add_child(UiKit.label("%s hours on the road, arriving about %02d:%02d" % [_hours_text(h), arrive / 60, arrive % 60],
				16, "gilt_light", 290))
			if night:
				_info.add_child(UiKit.label("After dark: the roads are worse at night.", 14, "rose", 290))
			var go := UiKit.button("Set out", func() -> void:
				travel_chosen.emit(_target)
				queue_free(), 18, "map")
			go.name = "SetOut"
			go.disabled = not setting_out
			if not setting_out:
				go.tooltip_text = "Set out from a road out of town."
			_info.add_child(go)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(spacer)
	_info.add_child(_legend())
	_info.add_child(UiKit.label("Click a place to plan a journey. Wheel: zoom · Drag: pan", 13, "parchment", 290))
	_info.add_child(UiKit.button("Close", func() -> void:
		closed.emit()
		queue_free(), 15))


## What the marks mean, drawn with the map's own marks.
func _legend() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(290, 84)
	c.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		var ink := Look.color("ink")
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(Look.color("vellum"), 0.1), true)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Look.color("gilt_dark"), false, 1.0)
		c.draw_circle(Vector2(20, 16), 8.0, Look.color("crimson"), true, -1.0, true)
		c.draw_circle(Vector2(20, 16), 8.0, Look.color("gilt_light"), false, 2.0, true)
		c.draw_string(font, Vector2(40, 21), "Where the party is", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.color("vellum"))
		c.draw_circle(Vector2(20, 41), 8.0, ink, true, -1.0, true)
		c.draw_circle(Vector2(20, 41), 6.0, Look.color("bone"), true, -1.0, true)
		c.draw_string(font, Vector2(40, 46), "A place you know", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.color("vellum"))
		c.draw_line(Vector2(8, 66), Vector2(18, 66), Look.color("bone"), 3.0, true)
		c.draw_line(Vector2(24, 66), Vector2(32, 66), Look.color("bone"), 3.0, true)
		c.draw_string(font, Vector2(40, 71), "Road", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.color("vellum"))
		c.draw_line(Vector2(130, 66), Vector2(156, 66), Look.color("vampire_red"), 4.5, true)
		c.draw_string(font, Vector2(164, 71), "Your way there", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.color("vellum")))
	return c


static func _hours_text(h: float) -> String:
	return str(int(h)) if is_equal_approx(h, roundf(h)) else "%.1f" % h


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
