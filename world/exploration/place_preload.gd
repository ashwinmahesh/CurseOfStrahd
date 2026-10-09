class_name PlacePreload
extends RefCounted
## The loading lane: the sprite sheets a place is about to show (the party's, its guests' and the people standing there
## now) read on worker threads while the loading cover is up, so building the place finds them in memory instead of
## reading each one on the main thread (headless, 2026-10-08: 0.66 s of a new game's first place went to the heroes'
## sheets, 0.26 s of Vallaki to its people's). game_root's `_covered` starts it, waits for it and lets it go once the
## place is built and holds the sheets itself.
## The foes still to be fought in a place are read the same way once the party is there (`keep_foes`), and held until
## it leaves, so a fight doesn't start by reading their sheets (Functional QA's hitch tour, 2026-10-09: 53 of 65 fights
## began with a frame over 100 ms, most of it the foes' sheets).

## Seconds to wait for the threads at most: anything not read by then is read during the build, as before.
const MAX_WAIT := 4.0
## Headless runs read nothing ahead: the stand-in renderer's texture store isn't made for textures made on several
## threads at once (a test run lost one). The perf probe turns this on to time the reading headless anyway.
static var headless_too := false
## Which of a place's fights still to come have their foes read ahead: "possible", every one whose condition could
## still come true while the party is here (a fight at night, or one a conversation's flag opens, starts as smoothly
## as the rest; entries for another party level, and a final battle the cards put elsewhere, are left out), "all" of
## them, "when" only those whose condition holds as the party arrives, or "off". The perf probe switches it to measure
## what holding them costs.
static var foes_mode := "possible"
## A party-level test in a condition ("level >= 7"): the level doesn't change while the party is in one place.
static var _level_test := RegEx.create_from_string("level\\s*(>=|<=|==|!=|>|<)\\s*\\d+")

## The sheets asked for (res:// paths), each a threaded load to collect.
var paths: Array[String] = []
var _held: Array[Resource] = []


## Starts reading the sheets for location entry `loc` with the party of `st`.
static func start(loc: Dictionary, st: StoryState) -> PlacePreload:
	return _reading(art_ids(loc, st), false)


## Starts reading the sheets and portraits of the foes still to be fought at location `loc_id` (entry `loc`).
static func foes(loc_id: String, loc: Dictionary, st: StoryState) -> PlacePreload:
	return _reading(foe_art_ids(loc_id, loc, st), true)


## Reads, on worker threads, each sprite's sheets (and its portrait, with `portraits`) that aren't in memory already.
static func _reading(arts: Array[String], portraits: bool) -> PlacePreload:
	var p := PlacePreload.new()
	if DisplayServer.get_name() == "headless" and not headless_too:
		return p
	for art in arts:
		var wanted: Array[String] = []
		for sheet: String in DirectionalSprite.SHEETS:
			wanted.append("res://art/sprites/%s/%s.tres" % [art, sheet])
		if portraits:
			wanted.append("res://art/portraits/%s.png" % art)
		for path in wanted:
			if ResourceLoader.has_cached(path) or not ResourceLoader.exists(path):
				continue
			if ResourceLoader.load_threaded_request(path) == OK:
				p.paths.append(path)
	return p


## The sprite ids of the foes a place's fights would bring on: the monsters of the encounter entries not started yet
## that foes_mode keeps.
static func foe_art_ids(loc_id: String, loc: Dictionary, st: StoryState) -> Array[String]:
	var out: Array[String] = []
	if foes_mode == "off":
		return out
	var begun := (st.location_states.get(loc_id, {}) as Dictionary).get("encounters", {}) as Dictionary
	for en: Variant in loc.get("encounters", []):
		var spec := en as Dictionary
		if begun.has(str(spec["id"])):
			continue
		if foes_mode == "when" and not StoryConditions.check(StoryConditions.encounter_when(spec), st):
			continue
		if foes_mode == "possible" and not could_happen(spec, st):
			continue
		for mo: Variant in spec.get("monsters", []):
			var art := CombatToken.monster_art(Compendium.shared().monster_data(str((mo as Dictionary)["monster"])))
			if art != "" and not art in out:
				out.append(art)
	return out


## The sprite ids a place will show: the party's and its guests' (custom heroes' paper dolls aside: HeroLook puts them
## together), and those of the people whose entries hold now (LocationNpcs._build_npcs picks them the same way).
static func art_ids(loc: Dictionary, st: StoryState) -> Array[String]:
	var out: Array[String] = []
	var who: Array[Creature] = []
	for ch: Character in st.party:
		if not HeroLook.is_custom(ch):
			who.append(ch)
	who.append_array(st.guests)
	for cr in who:
		var art := CombatToken.art_for(cr)
		if art != "" and not art in out:
			out.append(art)
	for n: Variant in loc.get("npcs", []):
		var spec := n as Dictionary
		if not StoryConditions.check(str(spec.get("when", "")), st) or not Schedule.in_hours(spec, st):
			continue
		var art := str(Compendium.shared().get_entry("npcs", str(spec["npc"])).get("sprite", spec["npc"]))
		if not art in out:
			out.append(art)
	return out


## Whether an encounter entry's condition could still come true during this visit: its party-level tests hold now, and
## a final battle is in the room the cards chose. Flags, the hour and guests can change while the party is here.
static func could_happen(spec: Dictionary, st: StoryState) -> bool:
	var room := str(spec.get("final_battle", ""))
	if room != "" and not StoryConditions.check("final_room:" + room, st):
		return false
	for m in _level_test.search_all(str(spec.get("when", ""))):
		if not StoryConditions.check(m.get_string(), st):
			return false
	return true


## Waits, a frame at a time on `node`'s tree, until every sheet is read or MAX_WAIT has passed, and holds what's in.
func wait(node: Node) -> void:
	var until := Time.get_ticks_msec() + int(MAX_WAIT * 1000.0)
	while _busy() and Time.get_ticks_msec() < until and node.is_inside_tree():
		await node.get_tree().process_frame
	collect()


## Holds every load that has finished.
func collect() -> void:
	for path in paths:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(path)
			if res != null:
				_held.append(res)


## Reads the foes of `view`'s place on worker threads and keeps them with the place (a Kept node on the view), so
## they're let go when the party leaves.
static func keep_foes(view: LocationView) -> void:
	var p := foes(view.loc_id, view.loc, view.st)
	if p.paths.is_empty():
		return
	var kept := Kept.new()
	kept.name = "FoeSheets"
	kept.process_mode = Node.PROCESS_MODE_ALWAYS   # collects under an arrival picture too, which pauses the game
	kept.pre = p
	view.add_child(kept)


## Holds a place's foes' sheets: collects them as their threads finish, and lets them go with the place.
class Kept extends Node:
	var pre: PlacePreload
	## Every sheet asked for has been read and is held.
	var done := false

	func _process(_delta: float) -> void:
		if not done and not pre._busy():
			pre.collect()
			done = true
			set_process(false)

	func _exit_tree() -> void:
		pre.release()


## Lets the sheets go (the place's figures hold the ones they show) and collects any load still out.
func release() -> void:
	for path in paths:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	paths.clear()
	_held.clear()


func _busy() -> bool:
	for path in paths:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return true
	return false
