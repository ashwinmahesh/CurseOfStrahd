class_name StoryBot
extends RefCounted
## A scripted player for the Phase 3 exit run (tests/integration/test_phase3_exit.gd): it travels by the locations'
## exits, walks through doors, talks to people and answers by a list of preferred option texts, wins fights with
## PartyAutopilot, takes loot, rests and heals between fights, and levels the party up at milestones. Everything goes
## through the real game scene (scenes/game.tscn), the same calls the mouse and keyboard make. Test-only.

var test: Node
var root: Node
## Option text fragments to pick, in order of preference; the first that matches a shown option wins.
var prefer: Array[String] = []
## Option text fragments never to pick unless nothing else is left.
var avoid: Array[String] = []
var trace: Array[String] = []
var fights: Array[Dictionary] = []
var conversations: Array[String] = []
var _chosen := {}
var defeated := false
## How many times a lost fight is played in all (TRIES); a test that expects the party to lose sets 1.
var fight_tries := TRIES


func _init(test_: Node, root_: Node) -> void:
	test = test_
	root = root_


func view() -> LocationView:
	return root.get("view") as LocationView


func st() -> StoryState:
	return GameState.story


func frames(n: int) -> void:
	for i in n:
		await test.get_tree().process_frame


## Set STORYBOT_ECHO=1 to watch the run live.
var echo := OS.get_environment("STORYBOT_ECHO") == "1"


func note(text: String) -> void:
	trace.append("[%s] %s" % [view().loc_id if view() != null else "?", text])
	if echo:
		print("    bot: ", trace.back())


# --- Waiting --------------------------------------------------------------------------------------

## Lets the game run until the party is standing still, handling fights, conversations and loot on the way.
## False if the party was defeated.
func settle(max_frames: int = 4000) -> bool:
	var idle := 0
	for i in max_frames:
		if defeated:
			return false
		var v := view()
		if v == null:
			await frames(1)
			continue
		if v.in_combat:
			if not await fight():
				return false
			idle = 0
			continue
		if root.get("dialogue") != null:
			await converse()
			idle = 0
			continue
		if root.get("loot") != null:
			var lw := root.get("loot") as LootWindow
			lw.call("_take_gold")
			if root.get("loot") != null:
				lw.call("_take_all")
			if root.get("loot") != null:
				lw.call("_close")
			await frames(1)
			continue
		if root.get("screen") != null:
			root.call("close_screen")
		if (v.get("_queue") as Array).is_empty() and not v.busy:
			idle += 1
			if idle >= 3:
				return true
		else:
			idle = 0
		await frames(1)
	note("still busy after %d frames" % max_frames)
	return true


## Plays the current fight to its end with the autopilot. True on victory. A fight the party loses is played again from
## the start of its first round with other dice, as a player would reload, up to TRIES times in all (lane 22,
## 2026-10-08, folding in lane 15's Yester Hill retry): any change to how many dice a run draws can flip a close fight.
## Only a loss acts, so a run that wins never moves.
func fight() -> bool:
	await frames(2)
	var kept := _keep_fight_start()
	for attempt in fight_tries:
		var last := attempt == fight_tries - 1 or not kept
		var outcome := await _play_fight(last)
		if outcome == "victory":
			_drop_fight_start()
			await recover()
			return true
		if last:
			_drop_fight_start()
			return false
		note("lost; the fight again from its first round with other dice (try %d of %d)" % [attempt + 2, fight_tries])
		if not await _reload_fight(attempt + 1):
			note("couldn't pick the fight up again from its save")
			defeated = true
			return false
	return false


## How many times a lost fight is played in all.
const TRIES := 5
## Where the round-start save of the fight's first round is kept for a retry.
const FIGHT_SAVE := "storybot_fight_start"


## The autopilot plays the fight once: "victory", or anything else for a loss. Only the last try ends the fight in the
## game (a loss shows its log in the trace); an earlier loss is left for the reload.
func _play_fight(last: bool) -> String:
	var v := view()
	var cv := v.combat_view
	if cv == null:
		return "victory"
	var e := cv.e
	var foes: Array[String] = []
	for c in e.combatants:
		if c.side == &"enemy":
			foes.append(c.name())
	var res := PartyAutopilot.new(e).run(40)
	fights.append({"where": v.loc_id, "foes": foes, "outcome": str(res["outcome"]), "rounds": int(res["rounds"]),
		"downs": int(res["downs"])})
	note("fight vs %s: %s in %d rounds, %d down" % [", ".join(foes), res["outcome"], int(res["rounds"]), int(res["downs"])])
	if str(res["outcome"]) != "victory" and not last:
		return str(res["outcome"])
	await frames(2)
	if v.in_combat and v.combat_view != null:
		v.combat_view.finished.emit(e.outcome if e.state == Encounter.State.OVER else "defeat")
	await frames(3)
	if str(res["outcome"]) != "victory":
		var lines := e.log.dump().split("\n")
		for l in lines.slice(0, 80):
			trace.append("      | " + l)
		if lines.size() > 80:
			trace.append("      | ...")
			for l in lines.slice(maxi(80, lines.size() - 60)):
				trace.append("      | " + l)
		for c in e.combatants:
			trace.append("      @ %s at %s, %d HP%s" % [c.name(), c.cell, c.creature.hp, " (dead)" if c.creature.dead else ""])
		defeated = true
	return str(res["outcome"])


## Keeps the round-start save the game wrote as this fight's first round began. False if there's none to keep (then a
## loss is final).
func _keep_fight_start() -> bool:
	var data := GameState.combat_snapshot.get("data", {}) as Dictionary
	var src := SaveSystem.slot_path(SaveSystem.ROUND_START)
	if int(data.get("round", 0)) != 1 or not FileAccess.file_exists(src):
		return false
	var out := FileAccess.open(SaveSystem.slot_path(FIGHT_SAVE), FileAccess.WRITE)
	if out == null:
		return false
	out.store_string(FileAccess.get_file_as_string(src))
	out.close()
	return true


func _drop_fight_start() -> void:
	if FileAccess.file_exists(SaveSystem.slot_path(FIGHT_SAVE)):
		DirAccess.remove_absolute(SaveSystem.slot_path(FIGHT_SAVE))


## Loads the fight's first-round save into a fresh game scene with seeded dice (1000 + `n`), the way a player reloads.
## The story object the test holds stays the same one, and the test's `root` follows the new scene. True once the
## party is back in the fight.
func _reload_fight(n: int) -> bool:
	var story := st()
	# A fight that isn't in the location's data (a random encounter on the road) is added again after the load.
	var spec := LocationFights.spec_for(view(), str(GameState.combat_snapshot.get("encounter", "")))
	root.queue_free()
	await frames(1)
	if SaveSystem.load_slot(FIGHT_SAVE) != OK:
		return false
	Dice.reseed(1000 + n)
	_adopt(story)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	test.add_child(root)
	if "root" in test:
		test.set("root", root)
	for i in 40:
		await frames(1)
		if view() != null and view().in_combat and view().combat_view != null:
			await frames(2)
			return true
		if i == 10 and view() != null and not view().in_combat and not spec.is_empty() \
				and LocationFights.spec_for(view(), str(spec["id"])).is_empty():
			(view().loc.get_or_add("encounters", []) as Array).append(spec.duplicate(true))
			view().resume_encounter(GameState.combat_snapshot)
	return false


## The loaded story's state, moved into the story object the test already holds (GameState.story points at it again).
static func _adopt(story: StoryState) -> void:
	var loaded := GameState.story
	for p: Dictionary in loaded.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			story.set(str(p["name"]), loaded.get(str(p["name"])))
	GameState.story = story


## Answers the open conversation: preferred options first, then options not taken yet, then the last one.
func converse() -> void:
	var d := root.get("dialogue") as DialogueUI
	conversations.append("%s:%s" % [d.runner.file.key if d.runner.file != null else "", d.runner.node])
	for i in 400:
		if root.get("dialogue") == null:
			return
		# A merchant's shop or someone's services opened from the talk: look, buy nothing, close it (the talk resumes).
		for n in root.get_children():
			if n is ShopScreen:
				(n as ShopScreen).call("_close")
				await frames(1)
			elif n is ServicesScreen:
				(n as ServicesScreen).call("_close")
				await frames(1)
		if bool(d.get("_waiting_continue")):
			d.call("_advance")
			await frames(1)
			continue
		var opts := d.options_shown
		if opts.is_empty():
			await frames(1)
			continue
		var pick := _pick(opts)
		# Captives after a fight (F13, story/captives.gd): let them go, which rolls nothing, so the run's later dice
		# don't move with whether a foe gave up.
		if d.runner.file != null and d.runner.file.key.begins_with("captives/"):
			for j in opts.size():
				if str((opts[j] as Dictionary)["text"]) == "Let them go.":
					pick = j
		var text := str((opts[pick] as Dictionary)["text"])
		_chosen[text] = int(_chosen.get(text, 0)) + 1
		note("says: %s" % text)
		d.call("_choose", pick)
		await frames(1)
	note("conversation didn't end")


func _pick(opts: Array) -> int:
	var enabled: Array[int] = []
	for i in opts.size():
		if bool((opts[i] as Dictionary).get("enabled", true)):
			enabled.append(i)
	for p in prefer:
		for i in enabled:
			var t := str((opts[i] as Dictionary)["text"])
			if t.containsn(p) and int(_chosen.get(t, 0)) < 2:
				return i
	for i in enabled:
		var t := str((opts[i] as Dictionary)["text"])
		if int(_chosen.get(t, 0)) == 0 and not _avoided(t):
			return i
	for i in enabled:
		var t := str((opts[i] as Dictionary)["text"])
		if t.containsn("goodbye") or t.containsn("leave") or t.containsn("that's all"):
			return i
	return int(enabled.back()) if not enabled.is_empty() else 0


func _avoided(t: String) -> bool:
	for a in avoid:
		if t.containsn(a):
			return true
	return false


# --- Moving ---------------------------------------------------------------------------------------

## Travels to `location_id` through the exits whose conditions hold now, using the travel map between places
## (ADR 0010) when no walking route leads there. True when there.
func go_to(location_id: String) -> bool:
	for hop in 30:
		var v := view()
		if v.loc_id == location_id:
			return true
		var route := _route(v.loc_id, location_id)
		if route.is_empty():
			if await _go_by_map(location_id):
				continue
			note("no way from %s to %s" % [v.loc_id, location_id])
			return false
		var exit := route[0]
		note("heading for %s via %s" % [location_id, exit["id"]])
		if not await walk_to(_cell(exit["cell"])):
			return false
		await frames(4)
		if view() == v:
			note("didn't leave by %s" % exit["id"])
			return false
		# Like a careful player: patch up on arriving somewhere you can rest.
		await recover()
	return view().loc_id == location_id


## Walks the leader to `cell`, opening doors on the way. True if the leader got there (or left the location).
func walk_to(cell: Vector2i) -> bool:
	for attempt in 8:
		var v := view()
		if v.leader().cell == cell and attempt > 0:
			return true
		if not v.walk_to(cell):
			# A locked door in the way: unlock the nearest one on a straight path, then try again.
			if not await _open_blocking_door(cell):
				note("can't reach %s" % cell)
				return false
			continue
		if not await settle():
			return false
		await frames(2)
		if view() != v:
			return true
	return view().leader().cell == cell


func _open_blocking_door(goal: Vector2i) -> bool:
	var v := view()
	for d: Variant in v.loc.get("doors", []):
		var door := d as Dictionary
		var dc := _cell(door["cell"])
		if v.thing_at(dc).is_empty() or str(v.thing_at(dc)["kind"]) != "door":
			continue
		if not v.grid.has_flag(dc, CombatGrid.WALL):
			continue
		for tries in 6:
			# A click on a locked door only rattles it: like a player, try the lock from its right-click menu.
			var way := _way_through(v, dc)
			if way != "":
				v.act(dc, way)
			else:
				v.click(dc)
			if not await settle():
				return false
			if not v.grid.has_flag(dc, CombatGrid.WALL):
				break
		if not v.grid.has_flag(dc, CombatGrid.WALL) and v.walk_to(goal):
			v.set("_queue", [])
			return true
	return false


## The right-click menu's way to open a locked door (the key, then the picks, then force, Knock last), or "".
static func _way_through(v: LocationView, cell: Vector2i) -> String:
	var ids: Array[String] = []
	for a: Variant in v.actions_at(cell)["actions"] as Array:
		if bool((a as Dictionary).get("enabled", true)):
			ids.append(str((a as Dictionary)["id"]))
	for way: String in ["key", "pick", "force", "knock"]:
		if way in ids:
			return way
	return ""


## Searches from where the leader stands (a minute each) until something shows at `cell`, the way a player keeps
## looking where they know a secret is. Thirty tries, so even a leader with no Perception bonus finds a DC 14 seam
## whatever the dice (each try fails 65% of the time; twelve tries failed on one seed). True once it's there.
func search_for(cell: Vector2i, tries: int = 30) -> bool:
	for i in tries:
		if not view().thing_at(cell).is_empty():
			return true
		view().search()
		await frames(2)
	if view().thing_at(cell).is_empty():
		note("searched %d times and found nothing at %s" % [tries, cell])
		return false
	return true


## Walks next to a person, prop or container and uses it (talks, examines, opens, searches for it first). A walk cut
## short (a trap spotted on the way) is walked again.
func use(cell: Vector2i) -> bool:
	var v := view()
	if v.thing_at(cell).is_empty():
		v.search()
		await frames(2)
	if v.thing_at(cell).is_empty():
		note("nothing at %s" % cell)
		return false
	for attempt in 5:
		var talks := conversations.size()
		var way := _way_through(v, cell)
		if way != "":
			v.act(cell, way)
		else:
			v.click(cell)
		if not await settle():
			return false
		if view() != v or conversations.size() > talks or v.grid.distance_ft(v.leader().cell, 1, cell, 1) <= 5:
			note("used %s" % cell)
			return true
	note("couldn't get next to %s" % cell)
	return false


## Talks to `npc_id`. Someone else's conversation on the way (another NPC speaking as the party walks past) doesn't
## count: the bot goes again until this NPC's own conversation has played.
func talk(npc_id: String) -> bool:
	for attempt in 4:
		var v := view()
		var target: Dictionary = {}
		for shown: Dictionary in v.get("_npc_shown"):
			if str((shown["spec"] as Dictionary)["npc"]) == npc_id:
				target = shown
		if target.is_empty():
			note("%s isn't here" % npc_id)
			return false
		var ref := str((target["spec"] as Dictionary).get("dialogue", ""))
		var before := conversations.size()
		if not await use(target["cell"] as Vector2i):
			return false
		if ref == "" or conversations.slice(before).has(ref):
			return true
	note("never got to talk to %s" % npc_id)
	return false


## Travels by map toward `location_id`. The map shows only places the party has been to, one road from there, or
## heard of (Travel.known), so a far place is reached the way a player does it: set out for the known place nearest
## it by road, look again from there, and go on.
func _go_by_map(location_id: String) -> bool:
	for hop in 8:
		if _known_place_toward(location_id, false) != "":
			return await _go_by_map_once(location_id)
		var step := _known_place_toward(location_id, true)
		if step == "" or not await _go_by_map_once(str(Travel.place(step)["location"]).get_slice(":", 0)):
			note("no way on toward %s" % location_id)
			return false
	return false


## The known place to set out for: one whose location is `location_id` or walks to it, or (`nearest`) the known
## place fewest road hours from such a place, counting every open road, known or not; "" if there's none.
func _known_place_toward(location_id: String, nearest: bool) -> String:
	var ends: Array[String] = []
	for p: Variant in Travel.map_data().get("places", []):
		var pl := p as Dictionary
		var loc := str(pl["location"]).get_slice(":", 0)
		if loc == location_id or not _route(loc, location_id).is_empty():
			ends.append(str(pl["id"]))
	var known := {}
	for k in Travel.known(st()):
		known[str(k["id"])] = true
	if not nearest:
		for e in ends:
			if known.has(e):
				return e
		return ""
	var dist := {}
	var open: Array[String] = []
	for e in ends:
		dist[e] = 0.0
		open.append(e)
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool: return float(dist[a]) < float(dist[b]))
		var here := open.pop_front() as String
		for r: Variant in Travel.map_data().get("roads", []):
			var road := r as Dictionary
			if not StoryConditions.check(str(road.get("when", "")), st()):
				continue
			var there := str(road["to"]) if str(road["from"]) == here else (str(road["from"]) if str(road["to"]) == here else "")
			if there == "":
				continue
			var d := float(dist[here]) + float(road["hours"])
			if not dist.has(there) or d < float(dist[there]):
				dist[there] = d
				open.append(there)
	var best := ""
	for id: String in known:
		var at := str(Travel.place(id)["location"]).get_slice(":", 0)
		if dist.has(id) and at != view().loc_id and (best == "" or float(dist[id]) < float(dist[best])):
			best = id
	return best


## Walks to the nearest road out (an exit to "travel"), opens the map and sets out for the place nearest
## `location_id` (by walking from that place's location). Fights and events on the road are handled by settle().
func _go_by_map_once(location_id: String) -> bool:
	var target := ""
	for p: Variant in Travel.map_data().get("places", []):
		var pl := p as Dictionary
		var loc := str(pl["location"]).get_slice(":", 0)
		if loc == location_id or not _route(loc, location_id).is_empty():
			if Travel.known(st()).has(pl):
				target = str(pl["id"])
				if loc == location_id:
					break
	if target == "":
		return false
	# Find a way to a location with a road out, then the road out itself.
	var out_exit := {}
	var out_loc := ""
	for lid: String in Compendium.shared().table("locations"):
		var loc := Compendium.shared().get_entry("locations", lid)
		for ex: Variant in loc.get("exits", []):
			if str((ex as Dictionary)["to"]) == "travel" and (lid == view().loc_id or not _route(view().loc_id, lid).is_empty()):
				if out_loc == "" or lid == view().loc_id:
					out_loc = lid
					out_exit = ex as Dictionary
	if out_loc == "":
		return false
	if view().loc_id != out_loc and not await go_to(out_loc):
		return false
	# Rested before the road, where the place allows it: a journey can meet a fight with no rest before it.
	await rest_if_needed()
	note("setting out for %s" % target)
	if not await walk_to(_cell(out_exit["cell"])):
		return false
	# Someone may have called out as the party reached the road (a conversation swallows the map); stepping on the
	# way out again sets out, as a player would click it again.
	for attempt in 3:
		for i in 60:
			if root.get("screen") is TravelScreen:
				break
			await frames(1)
		if root.get("screen") is TravelScreen:
			break
		await settle()
		view().click(_cell(out_exit["cell"]))
	var map := root.get("screen") as TravelScreen
	if map == null:
		note("the map didn't open")
		return false
	map.select(target)
	map.travel_chosen.emit(target)
	map.queue_free()
	await frames(4)
	return await settle()


func _route(from: String, to: String) -> Array[Dictionary]:
	var prev := {from: {}}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var here := queue.pop_front() as String
		if here == to:
			break
		var loc := Compendium.shared().get_entry("locations", here)
		for ex: Variant in loc.get("exits", []):
			var exit := ex as Dictionary
			var there := str(exit["to"])
			if there == "travel" or prev.has(there) or not StoryConditions.check(str(exit.get("when", "")), st()):
				continue
			prev[there] = {"from": here, "exit": exit}
			queue.append(there)
	var out: Array[Dictionary] = []
	if not prev.has(to):
		return out
	var at := to
	while at != from:
		var p := prev[at] as Dictionary
		out.push_front(p["exit"] as Dictionary)
		at = str(p["from"])
	return out


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


# --- Looking after the party ----------------------------------------------------------------------

## After a fight: heal the fallen with spells, short rest if hurt, long rest if worn down and the place allows it,
## and level up when a milestone allows.
func recover() -> void:
	var party := st().party
	for ch in party:
		if ch.dead or ch.hp > 0:
			continue
		_heal_with_spells(ch)
	await rest_if_needed()
	await level_up()


## A short rest if anyone is below half their Hit Points, then a long rest when anyone is still below 60%, the healers
## are out of 1st-level slots, or a caster has spent half its spell slots or more (lane 22, 2026-10-08: a party that
## left a fight above 60% but spent walked worn into the next one where it couldn't rest, Yester Hill's road home).
func rest_if_needed() -> void:
	var party := st().party
	var hurt := party.filter(func(c: Character) -> bool: return not c.dead and c.hp < c.max_hp() / 2)
	if not hurt.is_empty():
		await rest(false)
	var worn := party.filter(func(c: Character) -> bool: return not c.dead and c.hp * 10 < c.max_hp() * 6)
	var dry := party.filter(func(c: Character) -> bool:
		return not c.dead and (c.class_level_of("cleric") > 0 or c.class_level_of("wizard") > 0) and c.slots_left(1) == 0)
	var spent := party.filter(func(c: Character) -> bool: return not c.dead and _half_spent(c))
	if not worn.is_empty() or not dry.is_empty() or not spent.is_empty():
		await rest(true)


## Whether a caster has spent half its spell slots or more.
static func _half_spent(c: Character) -> bool:
	var total := 0
	var left := 0
	var slots := c.spell_slots()
	for level in range(1, slots.size() + 1):
		total += slots[level - 1]
		left += c.slots_left(level)
	return total > 0 and left * 2 <= total


func _heal_with_spells(target: Character) -> void:
	for healer in st().party:
		if healer.dead or healer.hp <= 0:
			continue
		for o in FieldCasting.options(st().party, healer, Dice.roller):
			if bool(o["legal"]) and str(o["id"]) in ["healing_word", "cure_wounds", "prayer_of_healing"]:
				var t: Array[Character] = [target]
				var r := FieldCasting.cast(st().party, healer, str(o["id"]), 0, t, Dice.roller)
				if bool(r["ok"]):
					note("%s heals %s: %s" % [healer.name, target.name, r["text"]])
					return


func rest(long: bool) -> void:
	root.call("open_screen", "rest", 0)
	await frames(1)
	var rs := root.get("screen") as RestScreen
	if rs == null:
		return
	var rule := str(view().loc.get("rest", "risky"))
	if rule == "no":
		root.call("close_screen")
		return
	if long:
		rs.call("_long_rest", rule)
		note("long rest")
	else:
		for ch in st().party:
			for i in 6:
				if ch.dead or ch.hp >= ch.max_hp() * 3 / 4:
					break
				var hd := ch.hit_dice()
				var spent := false
				for die: String in hd:
					var e := hd[die] as Dictionary
					if int(e["spent"]) < int(e["total"]):
						rs.call("_spend", ch, int(die))
						spent = true
						break
				if not spent:
					break
		rs.call("_finish_short")
		note("short rest")
	root.call("close_screen")
	await frames(1)


func level_up() -> void:
	for i in st().party.size():
		var ch := st().party[i]
		var guard := 0
		while st().can_level_up(ch) and guard < 4:
			guard += 1
			root.call("open_screen", "level_up", i)
			await frames(1)
			var lu := root.get("screen") as LevelUpScreen
			if lu == null or lu.ctl == null:
				break
			var ctl := lu.ctl
			var missing := TestChars.auto_pick(func() -> Array[Choice]: return ctl.pending_choices(),
				func(key: String, picks: Array) -> void: ctl.choose(key, picks))
			if not missing.is_empty():
				note("%s: level up stuck on %s" % [ch.name, missing])
			lu.call("_confirm")
			note("%s reaches level %d" % [ch.name, ch.character_level()])
			root.call("close_screen")
			await frames(1)
