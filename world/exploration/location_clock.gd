class_name LocationClock
extends Node
## The clock in a location (F2): when time passes while the party is here (a rest, a wait, a conversation that takes
## an hour), the day's scheduled events catch up (Schedule: their flags, and a Narrator line or a conversation if they
## happen here), and when the hour turns or an event changed the story, the people re-check who stands where (each NPC
## entry's `hours` and `when`): the market empties at dusk, the lamplighter comes out. One per LocationView, made by
## LocationNpcs; it looks only outside fights and conversations, and only when the clock has moved.

var view: LocationView
var _minute := -1


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
	if view == null or view.in_combat or view.members.is_empty() or ModeController.mode != ModeController.Mode.EXPLORATION:
		return
	var now := view.st.total_minutes()
	if now == _minute:
		return
	var turned := _minute >= 0 and floori(now / 60.0) != floori(_minute / 60.0)
	_minute = now
	var before := str(Schedule.memory(view.st)["fired"])
	var plays := Schedule.catch_up(view.st, view.loc_id)
	if turned or str(Schedule.memory(view.st)["fired"]) != before:
		view.refresh_npcs()
	var talked := false
	for p in plays:
		var e := p["event"] as Dictionary
		if e.has("dialogue") and not talked:
			talked = true
			view.dialogue_requested.emit(str(e["dialogue"]), "")
		elif e.has("narration"):
			view.narration.emit(str(e["narration"]))
