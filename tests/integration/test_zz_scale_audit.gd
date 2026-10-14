extends FightSeriesCase
## Scratch audit harness (never committed): reads AUDIT_IN (a JSON list of fights), walks the party in to each fight
## the way play does, then plays it on seeds 1-8 from where the walk left the party. One JSON line per fight goes to
## AUDIT_OUT as soon as it's measured.

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func _setup(row: Dictionary, at: Array[Vector2i]) -> void:
	GameState.reset()
	var level := int(row["level"])
	for id: String in PARTY:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var flags := row.get("flags", {}) as Dictionary
	for f: String in flags:
		GameState.story.set_flag(f, flags[f])
	var quests := row.get("quests", {}) as Dictionary
	for q: String in quests:
		GameState.story.set_quest_stage(q, str(quests[q]))
	for g: Variant in row.get("guests", []):
		GameState.story.add_guest(str(g))
	var loc := str(row["loc"])
	for d: Variant in row.get("doors", []):
		(GameState.story.loc_state(loc)["doors"] as Dictionary)[str(d)] = LocationView.DOOR_OPEN
	var lf := row.get("loc_flags", {}) as Dictionary
	for c: Variant in row.get("cleared", []):
		(GameState.story.loc_state(loc)["encounters"] as Dictionary)[str(c)] = true
		if str(lf.get(str(c), "")) != "":
			GameState.story.set_flag(str(lf[str(c)]), true)
	GameState.story.location = loc
	if at.size() == GameState.story.party.size():
		GameState.story.positions = at.duplicate()
	GameState.story.minute_of_day = int(row.get("hour", 12)) * 60


func _boot() -> LocationView:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


func _close() -> void:
	if root != null:
		root.queue_free()
		root = null
	await _frames(2)


## The four open squares nearest `goal` by steps over open ground, missing the fight's own foes.
func _around(v: LocationView, goal: Vector2i, row: Dictionary) -> Array[Vector2i]:
	var foes := {}
	for c: Variant in row.get("foe_cells", []):
		foes[_v(c)] = true
	var out: Array[Vector2i] = []
	var seen := {goal: true}
	var queue: Array[Vector2i] = [goal]
	while not queue.is_empty() and out.size() < 4:
		var c: Vector2i = queue.pop_front()
		if not v.grid.is_solid(c) and not foes.has(c):
			out.append(c)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and v.grid.in_bounds(n) and not v.grid.is_solid(n):
				seen[n] = true
				queue.append(n)
	return out


func _started(loc: String) -> Array[String]:
	var out: Array[String] = []
	var encs := GameState.story.loc_state(loc)["encounters"] as Dictionary
	for k: String in encs:
		if str(encs[k]) == "started":
			out.append(k)
	return out


func _v(c: Variant) -> Vector2i:
	var a := c as Array
	return Vector2i(int(a[0]), int(a[1]))


## Walks the party in from the location's spawn: into the fight's area, or up beside whoever starts it. Returns where
## the four stood when it started (or when they stopped), and what happened.
func _probe(row: Dictionary) -> Dictionary:
	var loc := str(row["loc"])
	var enc := str(row["enc"])
	var given: Array[Vector2i] = []
	for c: Variant in row.get("at", []):
		given.append(_v(c))
	_setup(row, given)
	Dice.reseed(1)
	var v := await _boot()
	var note := ""
	if v == null:
		await _close()
		return {"at": [], "note": "no view"}
	if given.is_empty() and not v.in_combat and not bool(row.get("tested", false)):
		var goals: Array[Vector2i] = []
		if row.get("area") != null:
			var r := row["area"] as Array
			var a := _v(r[0])
			var b := _v(r[1])
			for x: int in range(a.x, b.x + 1):
				for y: int in range(a.y, b.y + 1):
					goals.append(Vector2i(x, y))
		else:
			for s: Variant in row.get("speakers", []):
				var sc := _v(s)
				for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1),
						Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					goals.append(sc + d)
		# The nearest goal by walking.
		var best := Vector2i(-1, -1)
		var best_len := 1 << 30
		for g: Vector2i in goals:
			if v.grid.is_solid(g):
				continue
			var p := v._path(v.leader().cell, g)
			if not p.is_empty() and p.size() < best_len:
				best_len = p.size()
				best = g
		if best.x < 0:
			# No way in from the spawn (a locked door, a fight that starts on a flag): set the four down by the goal.
			var near := Vector2i(-1, -1)
			for g: Vector2i in goals:
				if not v.grid.is_solid(g) and (near.x < 0 or g.distance_to(v.leader().cell) < near.distance_to(v.leader().cell)):
					near = g
			if near.x >= 0:
				var placed := _around(v, near, row)
				await _close()
				var out: Array = []
				for c in placed:
					out.append([c.x, c.y])
				return {"at": out, "note": "placed beside %s (no way in)" % near, "walked_in": false}
			note = "no way in"
		else:
			if v.walk_to(best):
				var last := v.leader().cell
				var still := 0
				for i: int in 1500:
					if v.in_combat or (not v.busy and v._queue.is_empty()):
						break
					await get_tree().process_frame
					still = still + 1 if v.leader().cell == last else 0
					last = v.leader().cell
					if still > 240:
						break
				await _frames(4)
			if not v.in_combat and v.leader().cell.distance_to(best) > 1.5:
				# The walk didn't get there (a locked door, a conversation on the way): set the four down beside the goal.
				var placed := _around(v, best, row)
				note = "placed beside %s (walk stopped at %s)" % [best, v.leader().cell]
				await _close()
				var out: Array = []
				for c in placed:
					out.append([c.x, c.y])
				return {"at": out, "note": note, "walked_in": false}
	var at: Array = []
	for m: Combatant in v.members:
		at.append([m.cell.x, m.cell.y])
	var started := _started(loc)
	if v.in_combat and not started.has(enc):
		note += " other fight started: %s" % ",".join(started)
	await _close()
	return {"at": at, "note": note.strip_edges(), "walked_in": started.has(enc)}


func _once(row: Dictionary, at: Array[Vector2i], seed_value: int) -> Dictionary:
	var loc := str(row["loc"])
	var enc := str(row["enc"])
	_setup(row, at)
	Dice.reseed(seed_value)
	var v := await _boot()
	var started := _started(loc).has(enc)
	if not started and not v.in_combat:
		if str(row.get("trigger", "")) == "dialogue":
			step_aside(v, enc)   # whoever started it by talking steps aside, as the conversation does in play
		started = v.start_encounter(enc)
	if not started:
		await _close()
		return {"outcome": "nostart", "rounds": 0, "downs": 0, "dead": 0, "foes": []}
	await _frames(2)
	var picked := LocationFights.spec_for(v, enc)
	var e := v.combat_view.e
	var foes: Array = []
	for c in e.combatants:
		if c.side == &"enemy":
			foes.append(c.creature.id)
	var cap := int(OS.get_environment("AUDIT_ROUNDS")) if OS.get_environment("AUDIT_ROUNDS") != "" else 30
	var res := PartyAutopilot.new(e).run(cap)
	var dead := 0
	for c in e.combatants:
		if c.side == &"party" and c.creature.dead and GameState.story.party.has(c.creature):
			dead += 1
	while e.pending != null:
		e.answer_reaction(false)
	if OS.get_environment("AUDIT_LOG") != "":
		var texts := e.log.texts()
		print("---- %s seed %d: %s weather=%s %s light=%s" % [enc, seed_value, res["outcome"], e.weather_id, e.weather, e.ambient_light])
		for t: String in texts.slice(maxi(0, texts.size() - int(OS.get_environment("AUDIT_LOG")))):
			if not t.ends_with("'s turn") and not t.begins_with("Round "):
				print("    ", t)
		for c in e.combatants:
			var conds: Array[String] = []
			for fx in c.creature.effects:
				conds.append(str(fx.name))
			print("    = %s %s hp %d/%d at %s%s hidden=%s alt=%s solid=%s conds=%s" % [c.side, c.name(), c.creature.hp,
				c.creature.max_hp(), c.cell, " DEAD" if c.creature.dead else "", c.hidden, c.altitude,
				e.grid.is_solid(c.cell), conds])
	res["dead"] = dead
	res["foes"] = foes
	var want: Array = row.get("monsters", [])
	if row.has("try"):
		want = []
		for mo: Variant in (row["try"] as Dictionary)["monsters"]:
			want.append(str((mo as Dictionary)["monster"]))
	var got: Array = []
	for mo: Variant in picked.get("monsters", []):
		got.append(str((mo as Dictionary)["monster"]))
	res["variant_ok"] = got == want
	await _close()
	return res


## A trial version of the fight, in memory only: row["try"] = {"monsters": [...], other spec keys...} replaces those
## keys of the row's variant (the n-th entry with the fight's id) until `_unpatch`.
var _saved := {}


func _patch(row: Dictionary) -> void:
	_saved = {}
	if not row.has("try"):
		return
	var loc := Compendium.shared().get_entry("locations", str(row["loc"]))
	var n := 0
	for en: Variant in loc.get("encounters", []):
		var d := en as Dictionary
		if str(d["id"]) != str(row["enc"]):
			continue
		if n == int(row.get("variant", 0)):
			_saved = {"spec": d, "old": d.duplicate(true)}
			var t := row["try"] as Dictionary
			for k: String in t:
				d[k] = (t[k] as Variant)
			return
		n += 1


func _unpatch() -> void:
	if _saved.is_empty():
		return
	var d := _saved["spec"] as Dictionary
	d.clear()
	d.merge(_saved["old"] as Dictionary)
	_saved = {}


func test_audit() -> void:
	var items := JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("AUDIT_IN"))) as Array
	var out_path := OS.get_environment("AUDIT_OUT")
	var seeds: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	if OS.get_environment("AUDIT_SEEDS") != "":
		seeds = []
		for s: String in OS.get_environment("AUDIT_SEEDS").split(","):
			seeds.append(int(s))
	for it: Variant in items:
		var row := it as Dictionary
		var t0 := Time.get_ticks_msec()
		_patch(row)
		var probe := await _probe(row)
		var cleared: Array = []
		for attempt: int in 3:
			var other := str(probe["note"])
			if not other.contains("other fight started: "):
				break
			for o: String in other.get_slice("other fight started: ", 1).split(","):
				cleared.append(o)
			row["cleared"] = cleared
			probe = await _probe(row)
		var at: Array[Vector2i] = []
		for c: Variant in probe["at"]:
			at.append(_v(c))
		var per: Array = []
		var wins := 0
		var win_downs := 0
		var foes: Array = []
		var variant_ok := false
		for s: int in seeds:
			var res := await _once(row, at, s)
			per.append([s, str(res["outcome"]), int(res["rounds"]), int(res["downs"]), int(res["dead"])])
			if str(res["outcome"]) == "victory":
				wins += 1
				win_downs += int(res["downs"])
			foes = res["foes"] as Array
			variant_ok = bool(res.get("variant_ok", false))
		_unpatch()
		var line := {"key": str(row["key"]) + str(row.get("label", "")), "level": row["level"], "wins": wins, "n": seeds.size(),
			"win_downs": (win_downs / float(wins)) if wins > 0 else -1.0, "per": per, "at": probe["at"],
			"note": probe["note"], "walked_in": probe.get("walked_in", false), "foes": foes, "variant_ok": variant_ok,
			"cleared": cleared,
			"secs": (Time.get_ticks_msec() - t0) / 1000.0}
		var f := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(line))
		f.close()
		print("AUDIT %s L%d: %d/%d won (%.1f down in wins) %s" % [row["key"], row["level"], wins, seeds.size(),
			line["win_downs"], probe["note"]])
	assert_true(true, "audit ran")
