class_name LocationClock
extends Node
## The clock in a location (F2): when time passes while the party is here (a rest, a wait, a conversation that takes
## an hour), the day's scheduled events catch up (Schedule: their flags, and a Narrator line or a conversation if they
## happen here), and when the hour turns or an event changed the story, the people re-check who stands where (each NPC
## entry's `hours` and `when`): the market empties at dusk, the lamplighter comes out. Out in the open it also says when
## the weather turns (Weather). One per LocationView, made by LocationNpcs; it looks only outside fights and
## conversations, and only when the clock has moved.

var view: LocationView
var _minute := -1
var _weather := ""
## The people need re-checking: done on a frame they weren't already rebuilt in (two rebuilds in one frame free the
## lights the first one's props just lit, before Atmosphere has dressed them).
var _recheck := false


static func of(v: LocationView) -> LocationClock:
	for c in v.get_children():
		if c is LocationClock:
			return c as LocationClock
	var clock := LocationClock.new()
	clock.name = "LocationClock"
	clock.view = v
	v.add_child(clock)
	return clock


func _process(_delta: float) -> void:
	if view == null or view.is_queued_for_deletion() or view.in_combat or view.members.is_empty() \
			or ModeController.mode != ModeController.Mode.EXPLORATION:
		return   # (a place being left builds nothing more: its new pieces would be freed before they're lit)
	if _recheck and int(view.get_meta(&"npcs_built", -1)) != Engine.get_process_frames():
		_recheck = false
		view.refresh_npcs()
	var now := view.st.total_minutes()
	if now == _minute:
		return
	var turned := _minute >= 0 and floori(now / 60.0) != floori(_minute / 60.0)
	_minute = now
	var before := str(Schedule.memory(view.st)["fired"])
	var plays := Schedule.catch_up(view.st, view.loc_id)
	if turned or str(Schedule.memory(view.st)["fired"]) != before:
		_recheck = true
		if int(view.get_meta(&"npcs_built", -1)) != Engine.get_process_frames():
			_recheck = false
			view.refresh_npcs()
	# The weather turns (Weather, F12): out in the open the party sees it come.
	var weather := Weather.now(view.st, view.loc_id)
	if _weather != "" and weather != _weather and bool((view.loc.get("map", {}) as Dictionary).get("outdoors", false)):
		view.narration.emit(str(Weather.kind(weather).get("line", "")))
	_weather = weather
	var talked := false
	for p in plays:
		var e := p["event"] as Dictionary
		if e.has("dialogue") and not talked:
			talked = true
			view.dialogue_requested.emit(str(e["dialogue"]), "")
		elif e.has("narration"):
			view.narration.emit(str(e["narration"]))
