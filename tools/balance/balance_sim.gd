extends SceneTree
## Plays a fight many times in each difficulty mode (F1's balance tool) with the pregens on autopilot
## (tests/support/party_autopilot.gd) and prints how it went: wins, rounds, heroes dropped and killed, foes that fled
## and potions drunk. The fight is a data/encounters entry, or a location's fight with a party of `level` placed on the
## way in from the location's spawn, about 35 ft from the nearest foe.
##
##   make balance ENC=<encounter id> | LOCATION=<location id> FIGHT=<fight id> [LEVEL=n] [PARTY="a b c d"]
##        [MODES="story balanced tactician honour"] [RUNS=n] [JSON=<file>] [NO_WARD=1]

const PARTY := ["ilse_varga", "hedda_ironvow", "silvain_aster", "tamsin_tealeaf"]
const ROUNDS := 30

var _args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var modes: Array[String] = []
	for m in str(_args.get("modes", " ".join(Difficulty.IDS))).split(" ", false):
		modes.append(m)
	var runs := int(_args.get("runs", "20"))
	var rows: Array[Dictionary] = []
	var label := ""
	for mode in modes:
		var row := {"mode": mode, "runs": runs, "wins": 0, "rounds": 0, "downs": 0, "deaths": 0, "fled": 0,
			"potions": 0, "timeouts": 0, "hp_lost": 0.0}
		for i in runs:
			var errors: Array[String] = []
			var e := _fight(1000 + i, errors)
			if e == null:
				printerr("Can't build the fight: %s" % ", ".join(errors))
				quit(1)
				return
			label = e.title
			Difficulty.named(mode).prepare(e)
			var res := PartyAutopilot.new(e).run(ROUNDS)
			_tally(row, e, res)
		rows.append(row)
	_print(label, rows)
	if _args.has("json"):
		var f := FileAccess.open(str(_args["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"fight": label, "args": _args, "rows": rows}, "  "))
		f.close()
	quit(0)


func _fight(seed_value: int, errors: Array[String]) -> Encounter:
	var dice := DiceRoller.new(seed_value)
	if _args.has("encounter"):
		return EncounterSetup.load_id(str(_args["encounter"]), dice, errors)
	return location_fight(str(_args.get("location", "")), str(_args.get("fight", "")), int(_args.get("level", "5")),
		_party_ids(), dice, errors, not _args.has("no_ward"))


func _party_ids() -> Array[String]:
	var out: Array[String] = []
	for id in str(_args.get("party", " ".join(PARTY))).split(" ", false):
		out.append(id)
	return out


## A location's fight `fight_id` as the story would start it, with the pregens `party` at `level` (rested) walking
## in from the location's spawn. The fight's version for that level is picked as the story picks it; doors are open.
static func location_fight(loc_id: String, fight_id: String, level: int, party: Array[String], dice: DiceRoller,
		errors: Array[String], with_ward: bool = true) -> Encounter:
	var loc := Compendium.shared().get_entry("locations", loc_id)
	if loc.is_empty():
		errors.append("No location '%s'" % loc_id)
		return null
	var st := StoryState.new()
	for id in party:
		var ch := Pregens.build(id, level, errors)
		if ch != null:
			ch.finish_long_rest()
			st.party.append(ch)
	var spec := {}
	for en: Variant in loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == fight_id and (spec.is_empty() or not StoryConditions.check(str(spec.get("when", "")), st)):
			spec = en as Dictionary
	if spec.is_empty():
		errors.append("No fight '%s' in %s" % [fight_id, loc_id])
		return null
	var map := loc["map"] as Dictionary
	var grid := CombatGrid.from_rows(map["rows"] as Array, map.get("elevation", []) as Array)
	var e := Encounter.new(grid, dice)
	e.title = "%s: %s" % [loc.get("name", loc_id), fight_id]
	e.location_id = loc_id
	for place: String in Tarokka.spots(loc):
		e.places.append(place)
	if str(spec.get("final_battle", "")) != "":
		e.places.append(str(spec["final_battle"]))
	e.lair = bool(spec.get("lair", false))
	e.outdoors = bool(map.get("outdoors", false))
	e.ambient_light = "bright" if e.outdoors else str(map.get("light", "dim"))
	e.allies_block = bool(spec.get("allies_block", loc.get("allies_block", false)))
	e.legendary.set_withdraw(spec.get("withdraw", {}))
	var foes: Array[Vector2i] = []
	for mo: Variant in spec["monsters"]:
		var md := mo as Dictionary
		var data := Compendium.shared().monster_data(str(md["monster"]))
		var mon := Monster.from_data(data)
		if md.has("hp"):
			mon.hp_max_base = int(md["hp"])
			mon.hp = mon.max_hp()
		# The Heart of Sorrow's ward, as LocationFights.ward_for gives it (that file needs the game's autoloads).
		var ward := data.get("ward", {}) as Dictionary
		if with_ward and not ward.is_empty() and str(ward.get("region", "")) in ["", str(loc.get("region", ""))] \
				and not StoryConditions.check(str(ward.get("unless", "false")), st):
			mon.ward_hp = int(ward["hp"])
		if md.has("name"):
			mon.name = str(md["name"])
		var cell := _cell(md["cell"])
		foes.append(cell)
		e.add(mon, StringName(str(md.get("side", "enemy"))), cell)
	var spawn := _cell((loc.get("spawns", {}) as Dictionary).get("default", [0, 0]))
	var taken := {}
	for c in e.combatants:
		for f in c.footprint():
			taken[f] = true
	var cells := _party_cells(grid, spawn, foes, taken, st.party.size())
	for i in mini(cells.size(), st.party.size()):
		e.add(st.party[i], &"party", cells[i])
	return e


## Where the party stands: on the shortest walk from the spawn to the nearest foe, at the first square within 35 ft
## of a foe, and the free squares closest around it.
static func _party_cells(grid: CombatGrid, spawn: Vector2i, foes: Array[Vector2i], taken: Dictionary, n: int) -> Array[Vector2i]:
	var walk := grid.reachable(spawn, 1, 100000, func(_x: Vector2i) -> bool: return false,
		func(_x: Vector2i) -> bool: return false, func(_x: Vector2i) -> bool: return false)
	var target := spawn
	var best := 1 << 30
	for f in foes:
		for cell: Vector2i in walk:
			if cell.distance_squared_to(f) <= 2 and int((walk[cell] as Dictionary)["cost"]) < best:
				best = int((walk[cell] as Dictionary)["cost"])
				target = cell
	var anchor := spawn
	for cell in CombatGrid.path_to(walk, target):
		anchor = cell
		var near := false
		for f in foes:
			if grid.distance_ft(cell, 1, f, 1) <= 35:
				near = true
		if near:
			break
	var around := grid.reachable(anchor, 1, 100000, func(_x: Vector2i) -> bool: return false,
		func(_x: Vector2i) -> bool: return false, func(_x: Vector2i) -> bool: return false)
	var free: Array[Vector2i] = []
	for cell: Vector2i in around:
		if not taken.has(cell):
			free.append(cell)
	free.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int((around[a] as Dictionary)["cost"]) < int((around[b] as Dictionary)["cost"]))
	return free.slice(0, n)


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


func _tally(row: Dictionary, e: Encounter, res: Dictionary) -> void:
	var outcome := str(res["outcome"])
	row["wins"] = int(row["wins"]) + (1 if outcome == "victory" else 0)
	row["timeouts"] = int(row["timeouts"]) + (1 if outcome == "timeout" else 0)
	row["rounds"] = int(row["rounds"]) + int(res["rounds"])
	row["downs"] = int(row["downs"]) + int(res["downs"])
	var lost := 0.0
	var party := 0
	for c in e.combatants:
		if c.side == &"party":
			party += 1
			if c.creature.dead:
				row["deaths"] = int(row["deaths"]) + 1
			lost += 1.0 - float(c.creature.hp) / maxf(1.0, float(c.creature.max_hp()))
		elif c.side == &"enemy" and str(e.legendary.departed.get(c.id, "")) == "fled":
			row["fled"] = int(row["fled"]) + 1
	row["hp_lost"] = float(row["hp_lost"]) + lost / maxf(1.0, float(party))
	for t in e.log.texts():
		if "drinks a Potion of Healing" in t:
			row["potions"] = int(row["potions"]) + 1


func _print(label: String, rows: Array[Dictionary]) -> void:
	print("\n%s" % label)
	print("%-10s %6s %7s %8s %8s %6s %8s %9s" % ["mode", "wins", "rounds", "dropped", "killed", "fled", "potions", "hp lost"])
	for r in rows:
		var n := maxf(1.0, float(r["runs"]))
		print("%-10s %3d/%-2d %7.1f %8.2f %8.2f %6.2f %8.2f %8d%%" % [r["mode"], r["wins"], r["runs"], float(r["rounds"]) / n,
			float(r["downs"]) / n, float(r["deaths"]) / n, float(r["fled"]) / n, float(r["potions"]) / n,
			roundi(100.0 * float(r["hp_lost"]) / n)])
