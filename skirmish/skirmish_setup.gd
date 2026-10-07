class_name SkirmishSetup
extends RefCounted
## One Skirmish fight as the player set it up (N1, N9): the heroes (any level, any build, any items), the foes from the
## stat blocks, the map (the Phase 2 arena or any location's), the time of day, and where everyone stands. It builds
## the Encounter (pure rules, no nodes) and saves as JSON (SkirmishLibrary). Squares the encounter editor didn't set
## are filled in: the party round the map's way in, the foes a bow-shot off across open ground.

const ARENA_MAP := "encounter:arena_wolves_and_zombies"
const PARTY_CAP := StoryState.PARTY_CAP
const MAX_FOES := 20
## 2024 DMG, XP Budget per Character: level -> [Low, Moderate, High].
const XP_BUDGET := {1: [50, 75, 100], 2: [100, 150, 200], 3: [150, 225, 400], 4: [250, 375, 500],
	5: [500, 750, 1100], 6: [600, 1000, 1400], 7: [750, 1300, 1700], 8: [1000, 1700, 2100], 9: [1300, 2000, 2600],
	10: [1600, 2300, 3100], 11: [1900, 2900, 4100], 12: [2200, 3700, 4700], 13: [2600, 4200, 5400],
	14: [2900, 4900, 6200], 15: [3300, 5400, 7800], 16: [3800, 6100, 9800], 17: [4500, 7200, 11700],
	18: [5000, 8700, 14200], 19: [5500, 10700, 17200], 20: [6400, 13200, 22000]}
## How far off the foes stand when the editor didn't place them, in squares along open ground.
const FOE_DISTANCE := 10

var title := "Skirmish"
## "encounter:<id>" (data/encounters) or "location:<id>" (data/locations).
var map_id := ARENA_MAP
## Outdoors only: "day" (bright light) or "night" (darkness; the party carries a lantern).
var time := "day"
## "" (Initiative as usual), "party" or "enemies": who is surprised.
var surprise := ""
## Each hero as Character.to_dict(), plus "cell": [x, z] once the editor places them.
var party: Array[Dictionary] = []
## Each foe: {"monster": id, "cell": [x, z] (optional), "name": (optional)}.
var foes: Array[Dictionary] = []


# --- Saving ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"title": title, "map": map_id, "time": time, "surprise": surprise, "party": party.duplicate(true),
		"foes": foes.duplicate(true), "version": 1}


static func from_dict(d: Dictionary) -> SkirmishSetup:
	var s := SkirmishSetup.new()
	s.title = str(d.get("title", s.title))
	s.map_id = str(d.get("map", s.map_id))
	s.time = str(d.get("time", s.time))
	s.surprise = str(d.get("surprise", ""))
	for p: Variant in d.get("party", []):
		s.party.append((p as Dictionary).duplicate(true))
	for f: Variant in d.get("foes", []):
		s.foes.append((f as Dictionary).duplicate(true))
	return s


func duplicate_setup() -> SkirmishSetup:
	return SkirmishSetup.from_dict(to_dict())


## Takes another setup's fight (a saved one from the encounter editor): its map, hour, surprise, foes and their
## squares, and the heroes' starting squares by order, keeping this party.
func take_fight(other: SkirmishSetup) -> void:
	map_id = other.map_id
	time = other.time
	surprise = other.surprise
	foes.clear()
	for f in other.foes:
		foes.append(f.duplicate(true))
	for i in party.size():
		party[i].erase("cell")
		if i < other.party.size() and other.party[i].has("cell"):
			party[i]["cell"] = (other.party[i]["cell"] as Array).duplicate()


# --- The heroes -----------------------------------------------------------------------------------

## Adds a hero (its current state is stored; the fight starts it rested); `pregen` names the pregen it was built
## from, so the Lab can rebuild it at another level. False when the party is full.
func add_hero(ch: Character, pregen: String = "") -> bool:
	if party.size() >= PARTY_CAP:
		return false
	var d := ch.to_dict()
	if pregen != "":
		d["pregen"] = pregen
	party.append(d)
	return true


## Replaces hero `i` with `ch`, keeping where the editor placed them and which pregen they came from.
func set_hero(i: int, ch: Character) -> void:
	var d := ch.to_dict()
	for k: String in ["cell", "pregen"]:
		if party[i].has(k):
			d[k] = party[i][k]
	party[i] = d


## The pregen hero `i` was built from, or "".
func pregen_of(i: int) -> String:
	return str(party[i].get("pregen", ""))


## Hero `i` as a fresh Character, rested and ready.
func hero(i: int) -> Character:
	var ch := Character.from_dict(party[i])
	ch.finish_long_rest()
	return ch


func heroes() -> Array[Character]:
	var out: Array[Character] = []
	for i in party.size():
		out.append(hero(i))
	return out


func levels() -> Array[int]:
	var out: Array[int] = []
	for p in party:
		var total := 0
		for l: Variant in (p.get("build", {}) as Dictionary).get("levels", []):
			total += 1
		out.append(maxi(1, total))
	return out


# --- The foes -------------------------------------------------------------------------------------

func add_foe(monster_id: String) -> bool:
	if foes.size() >= MAX_FOES or Compendium.shared().monster_data(monster_id).is_empty():
		return false
	foes.append({"monster": monster_id})
	return true


## Takes away the last `monster_id` added.
func remove_foe(monster_id: String) -> void:
	for i in range(foes.size() - 1, -1, -1):
		if str(foes[i]["monster"]) == monster_id:
			foes.remove_at(i)
			return


func foe_count(monster_id: String) -> int:
	return foes.filter(func(f: Dictionary) -> bool: return str(f["monster"]) == monster_id).size()


## The 125 stat blocks, lowest Challenge Rating first, then by name.
static func monsters() -> Array[Dictionary]:
	var out := Compendium.shared().all("monsters")
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := float(a.get("cr", 0))
		var cb := float(b.get("cr", 0))
		return ca < cb if ca != cb else str(a.get("name", "")) < str(b.get("name", "")))
	return out


## "1/4", "1/2", "5".
static func cr_text(cr: Variant) -> String:
	var v := float(cr)
	match v:
		0.125:
			return "1/8"
		0.25:
			return "1/4"
		0.5:
			return "1/2"
	return str(int(v))


# --- Difficulty -----------------------------------------------------------------------------------

func xp_total() -> int:
	var xp := 0
	for f in foes:
		xp += int(Compendium.shared().monster_data(str(f["monster"])).get("xp", 0))
	return xp


## The party's XP budgets [Low, Moderate, High], summed over the heroes' levels (2024 DMG).
func budgets() -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	for lv in levels():
		var row := XP_BUDGET[clampi(lv, 1, 20)] as Array
		for k in 3:
			out[k] += int(row[k])
	return out


## "low", "moderate", "high" or "beyond high" by the 2024 DMG's budgets; "" with nobody on one side.
func difficulty() -> String:
	if party.is_empty() or foes.is_empty():
		return ""
	var b := budgets()
	var xp := xp_total()
	if xp > b[2]:
		return "beyond high"
	if xp >= b[1]:
		return "high" if xp >= b[2] else "moderate"
	return "low"


# --- Maps -----------------------------------------------------------------------------------------

## Every map a skirmish can be fought on: the Phase 2 arena first, then each location with a grid map, by region and
## name. Each: {id, name, region, map (the location's or encounter's map block), place (location id or "")}.
static func maps() -> Array[Dictionary]:
	var comp := Compendium.shared()
	var out: Array[Dictionary] = []
	for enc in comp.all("encounters"):
		out.append({"id": "encounter:" + str(enc["id"]), "name": str(enc.get("name", enc["id"])), "region": "Arena",
			"map": enc["map"], "place": ""})
	var locs: Array[Dictionary] = []
	for loc in comp.all("locations"):
		if not ((loc.get("map", {}) as Dictionary).get("rows", []) as Array).is_empty():
			locs.append({"id": "location:" + str(loc["id"]), "name": str(loc.get("name", loc["id"])),
				"region": region_name(str(loc.get("region", ""))), "map": loc["map"], "place": str(loc["id"])})
	locs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"]) if a["region"] == b["region"] else str(a["region"]) < str(b["region"]))
	out.append_array(locs)
	return out


static func region_name(id: String) -> String:
	return id.replace("_", " ").capitalize().replace(" Of ", " of ").replace(" The ", " the ")


## The map entry for `id` (see maps()), or {} when there's none.
static func map_entry(id: String) -> Dictionary:
	var kind := id.get_slice(":", 0)
	var key := id.get_slice(":", 1)
	var comp := Compendium.shared()
	if kind == "encounter":
		var enc := comp.get_entry("encounters", key)
		if not enc.is_empty():
			return {"id": id, "name": str(enc.get("name", key)), "region": "Arena", "map": enc["map"], "place": ""}
	elif kind == "location":
		var loc := comp.get_entry("locations", key)
		if not loc.is_empty() and loc.has("map"):
			return {"id": id, "name": str(loc.get("name", key)), "region": region_name(str(loc.get("region", ""))),
				"map": loc["map"], "place": key}
	return {}


## The location's own data for a location map ({} for the arena).
func location() -> Dictionary:
	var e := map_entry(map_id)
	return Compendium.shared().get_entry("locations", str(e["place"])) if not e.is_empty() and str(e["place"]) != "" else {}


func outdoors() -> bool:
	var e := map_entry(map_id)
	return not e.is_empty() and bool((e["map"] as Dictionary).get("outdoors", false))


## The fight's grid: the map's rows, with a location's doors standing open (the fight is the only thing there).
func grid() -> CombatGrid:
	var e := map_entry(map_id)
	if e.is_empty():
		return null
	return CombatGrid.from_rows((e["map"] as Dictionary)["rows"] as Array)


# --- Where everyone stands ------------------------------------------------------------------------

## Whether a creature `size_cells` across can stand with its corner at `cell`, clear of `taken` ({cell: true}).
static func fits(g: CombatGrid, cell: Vector2i, size_cells: int, taken: Dictionary = {}) -> bool:
	for c in CombatGrid.footprint(cell, size_cells):
		if not g.in_bounds(c) or g.is_solid(c) or g.has_flag(c, CombatGrid.WATER) or taken.has(c):
			return false
	# A big creature stands on one level.
	return size_cells == 1 or CombatGrid.footprint(cell, size_cells).all(func(c: Vector2i) -> bool: return g.height(c) == g.height(cell))


## Steps over open ground from `from` ({cell: squares}), 8 ways, never through walls or water.
static func walk(g: CombatGrid, from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in CombatGrid.DIRS:
			var n := c + d
			if dist.has(n) or not fits(g, n, 1):
				continue
			if d.x != 0 and d.y != 0 and (g.is_solid(Vector2i(c.x + d.x, c.y)) or g.is_solid(Vector2i(c.x, c.y + d.y))):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


## Where the party gathers when nobody placed them: the location's way in, else the open square nearest the map's
## top-left corner on its biggest stretch of open ground.
func party_anchor(g: CombatGrid) -> Vector2i:
	var loc := location()
	var spawn: Variant = (loc.get("spawns", {}) as Dictionary).get("default", null)
	if spawn is Array:
		var s := Vector2i(int((spawn as Array)[0]), int((spawn as Array)[1]))
		if fits(g, s, 1) and walk(g, s).size() > 12:
			return s
	var best := Vector2i(-1, -1)
	var best_size := 0
	var seen := {}
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if seen.has(c) or not fits(g, c, 1):
				continue
			var region := walk(g, c)
			for k: Vector2i in region:
				seen[k] = true
			if region.size() > best_size:
				best_size = region.size()
				best = c
	if best.x < 0:
		return best
	# The region's corner square nearest the top left.
	var region := walk(g, best)
	var corner := best
	for k: Vector2i in region:
		if k.x + k.y < corner.x + corner.y:
			corner = k
	return corner


## Every combatant's square: {"party": Array[Vector2i], "foes": Array[Vector2i]}, the editor's where they're still
## free, the rest filled in. A square that can't be found is (-1, -1); `errors` says who.
func placements(g: CombatGrid, errors: Array[String] = []) -> Dictionary:
	var taken := furniture()
	var party_cells: Array[Vector2i] = []
	var foe_cells: Array[Vector2i] = []
	party_cells.resize(party.size())
	foe_cells.resize(foes.size())
	party_cells.fill(Vector2i(-1, -1))
	foe_cells.fill(Vector2i(-1, -1))
	# 1. Whoever the editor placed, where that's still open ground.
	for i in party.size():
		var c := _cell_of(party[i])
		if c.x >= 0 and fits(g, c, 1, taken):
			party_cells[i] = c
			_take(taken, c, 1)
	for i in foes.size():
		var c := _cell_of(foes[i])
		var size := _foe_size(i)
		if c.x >= 0 and fits(g, c, size, taken):
			foe_cells[i] = c
			_take(taken, c, size)
	# 2. The rest of the party round the way in (or round whoever of them was placed).
	var anchor := party_anchor(g)
	for c in party_cells:
		if c.x >= 0:
			anchor = c
			break
	if anchor.x < 0:
		errors.append("The map has no open ground")
		return {"party": party_cells, "foes": foe_cells}
	var from_party := walk(g, anchor)
	var near := from_party.keys()
	near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(from_party[a]) < int(from_party[b]) if from_party[a] != from_party[b] else (a.y * 1000 + a.x) < (b.y * 1000 + b.x))
	for i in party.size():
		if party_cells[i].x >= 0:
			continue
		for c: Vector2i in near:
			if fits(g, c, 1, taken):
				party_cells[i] = c
				_take(taken, c, 1)
				break
		if party_cells[i].x < 0:
			errors.append("No room for %s" % str((party[i].get("build", {}) as Dictionary).get("name", "a hero")))
	# 3. The foes a bow-shot off: around the square FOE_DISTANCE steps away (or the farthest there is), keeping two
	# squares clear of the party.
	var far := 0
	for c: Vector2i in from_party:
		far = maxi(far, int(from_party[c]))
	var want := clampi(far * 3 / 4, mini(3, far), FOE_DISTANCE)
	var foe_anchor := anchor
	var placed_foe := foe_cells.filter(func(c: Vector2i) -> bool: return c.x >= 0)
	if not placed_foe.is_empty():
		foe_anchor = placed_foe[0]
	else:
		var best := -1.0
		for c: Vector2i in from_party:
			if int(from_party[c]) != want:
				continue
			var score := Vector2(c - anchor).length() + float(walk_room(from_party, c))
			if score > best:
				best = score
				foe_anchor = c
	var from_foes := walk(g, foe_anchor)
	var order := from_foes.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(from_foes[a]) < int(from_foes[b]) if from_foes[a] != from_foes[b] else (a.y * 1000 + a.x) < (b.y * 1000 + b.x))
	for i in foes.size():
		if foe_cells[i].x >= 0:
			continue
		var size := _foe_size(i)
		for c: Vector2i in order:
			if fits(g, c, size, taken) and _clear_of(c, size, party_cells, 2):
				foe_cells[i] = c
				_take(taken, c, size)
				break
		if foe_cells[i].x < 0:
			for c: Vector2i in order:
				if fits(g, c, size, taken):
					foe_cells[i] = c
					_take(taken, c, size)
					break
		if foe_cells[i].x < 0:
			errors.append("No room for %s" % str(Compendium.shared().monster_data(str(foes[i]["monster"])).get("name", "a foe")))
	return {"party": party_cells, "foes": foe_cells}


## The squares a location's furniture, chests, doorways and ways out stand on ({cell: true}): nobody starts there.
func furniture() -> Dictionary:
	var out := {}
	var loc := location()
	for key: String in ["props", "containers", "doors", "exits", "npcs"]:
		for t: Variant in loc.get(key, []):
			var c := _cell_of(t as Dictionary)
			if c.x >= 0:
				out[c] = true
	return out


## How many open squares lie within two steps of `c` (so the foes gather where there's room).
static func walk_room(dist: Dictionary, c: Vector2i) -> int:
	var n := 0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if dist.has(c + Vector2i(dx, dz)):
				n += 1
	return n


func _foe_size(i: int) -> int:
	return CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(str(foes[i]["monster"])).get("size", "medium"))))


static func _cell_of(d: Dictionary) -> Vector2i:
	var v: Variant = d.get("cell", null)
	if v is Array and (v as Array).size() == 2:
		return Vector2i(int((v as Array)[0]), int((v as Array)[1]))
	return Vector2i(-1, -1)


static func _take(taken: Dictionary, cell: Vector2i, size: int) -> void:
	for c in CombatGrid.footprint(cell, size):
		taken[c] = true


static func _clear_of(cell: Vector2i, size: int, others: Array[Vector2i], gap: int) -> bool:
	for o in others:
		if o.x < 0:
			continue
		for c in CombatGrid.footprint(cell, size):
			if maxi(absi(c.x - o.x), absi(c.y - o.y)) <= gap:
				return false
	return true


## Stores the squares in the setup (the editor's Save, and a fight remembers where it began).
func pin(cells: Dictionary) -> void:
	var pc := cells["party"] as Array[Vector2i]
	var fc := cells["foes"] as Array[Vector2i]
	for i in mini(pc.size(), party.size()):
		if pc[i].x >= 0:
			party[i]["cell"] = [pc[i].x, pc[i].y]
	for i in mini(fc.size(), foes.size()):
		if fc[i].x >= 0:
			foes[i]["cell"] = [fc[i].x, fc[i].y]


# --- The encounter editor (N9) --------------------------------------------------------------------

## The hero or foe whose footprint covers `cell` in `cells` (placements()): {kind: "hero" | "foe", index}, or {}.
func piece_at(cells: Dictionary, cell: Vector2i) -> Dictionary:
	var pc := cells["party"] as Array[Vector2i]
	for i in pc.size():
		if pc[i] == cell:
			return {"kind": "hero", "index": i}
	var fc := cells["foes"] as Array[Vector2i]
	for i in fc.size():
		if fc[i].x >= 0 and cell in CombatGrid.footprint(fc[i], _foe_size(i)):
			return {"kind": "foe", "index": i}
	return {}


func _entry(kind: String, index: int) -> Dictionary:
	return party[index] if kind == "hero" else foes[index]


## Whether the editor placed this hero or foe (else its square is filled in).
func pinned(kind: String, index: int) -> bool:
	return _cell_of(_entry(kind, index)).x >= 0


## Why a hero or foe (`monster` for one not added yet) can't stand at `cell`, or "" when it can: walls, water and the
## map's edge, the place's furniture, and anyone the editor has already placed (pieces filled in make room).
func place_problem(g: CombatGrid, kind: String, index: int, cell: Vector2i, monster: String = "") -> String:
	var size := 1
	if kind == "foe":
		var mid := monster if monster != "" else str(foes[index]["monster"])
		size = CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(mid).get("size", "medium"))))
	var taken := {}
	for i in party.size():
		if not (kind == "hero" and i == index):
			var c := _cell_of(party[i])
			if c.x >= 0:
				taken[c] = "someone"
	for i in foes.size():
		if not (kind == "foe" and i == index and monster == ""):
			var c := _cell_of(foes[i])
			if c.x >= 0:
				for f in CombatGrid.footprint(c, _foe_size(i)):
					taken[f] = "someone"
	var stuff := furniture()
	for c in CombatGrid.footprint(cell, size):
		if not g.in_bounds(c) or g.has_flag(c, CombatGrid.VOID):
			return "Off the map"
		if g.has_flag(c, CombatGrid.WATER):
			return "Deep water"
		if g.has_flag(c, CombatGrid.WALL):
			return "A wall"
		if g.has_flag(c, CombatGrid.LOW):
			return "Low cover: nobody stands on it"
		if stuff.has(c):
			return "Furniture, a chest or a doorway"
		if taken.has(c):
			return "Someone stands there"
	if not fits(g, cell, size):
		return "Not on one level"
	return ""


## Puts a hero or foe at `cell` (the editor's click). False with the reason in `why` when it can't stand there.
func place(g: CombatGrid, kind: String, index: int, cell: Vector2i, why: Array[String] = []) -> bool:
	var problem := place_problem(g, kind, index, cell)
	if problem != "":
		why.append(problem)
		return false
	_entry(kind, index)["cell"] = [cell.x, cell.y]
	return true


## Adds a foe standing at `cell`. False (with why) when there's no room, or twenty already.
func add_foe_at(g: CombatGrid, monster_id: String, cell: Vector2i, why: Array[String] = []) -> bool:
	var problem := place_problem(g, "foe", -1, cell, monster_id)
	if problem != "":
		why.append(problem)
		return false
	if not add_foe(monster_id):
		why.append("%d foes at most" % MAX_FOES)
		return false
	foes.back()["cell"] = [cell.x, cell.y]
	return true


## The hero or foe's square goes back to being filled in.
func unplace(kind: String, index: int) -> void:
	_entry(kind, index).erase("cell")


## Forgets every square, so all are filled in again (a new map).
func unpin() -> void:
	for p in party:
		p.erase("cell")
	for f in foes:
		f.erase("cell")


# --- The fight ------------------------------------------------------------------------------------

## What's missing before the fight can start ("" when it's ready).
func problem() -> String:
	if party.is_empty():
		return "Add a hero to the party."
	if foes.is_empty():
		return "Add a foe to fight."
	if map_entry(map_id).is_empty():
		return "Choose a map."
	return ""


## The Encounter, ready to start: the heroes rested, the foes numbered when there are several of a kind ("Wolf 2"),
## everyone on their square, and the light of the place and hour. Null when it can't be built (`errors` says why).
func build(dice: DiceRoller, errors: Array[String] = []) -> Encounter:
	if problem() != "":
		errors.append(problem())
		return null
	var g := grid()
	var cells := placements(g, errors)
	if not errors.is_empty():
		return null
	var e := Encounter.new(g, dice)
	e.title = title
	var map := map_entry(map_id)["map"] as Dictionary
	e.outdoors = bool(map.get("outdoors", false))
	e.sunlit = false
	e.ambient_light = str(map.get("light", "bright"))
	if e.outdoors:
		e.ambient_light = "bright" if time == "day" else "dark"
	var party_cbs: Array[Combatant] = []
	var pc := cells["party"] as Array[Vector2i]
	for i in party.size():
		party_cbs.append(e.add(hero(i), &"party", pc[i]))
	var counts := {}
	for f in foes:
		counts[str(f["monster"])] = int(counts.get(str(f["monster"]), 0)) + 1
	var numbered := {}
	var fc := cells["foes"] as Array[Vector2i]
	for i in foes.size():
		var mid := str(foes[i]["monster"])
		var mon := Monster.from_data(Compendium.shared().monster_data(mid))
		if foes[i].has("name"):
			mon.name = str(foes[i]["name"])
		elif int(counts[mid]) > 1:
			numbered[mid] = int(numbered.get(mid, 0)) + 1
			mon.name = "%s %d" % [mon.name, numbered[mid]]
		e.add(mon, &"enemy", fc[i])
	EncounterSetup.bring_familiars(e, party_cbs)
	_light(e, party_cbs)
	return e


## The place's lamps and fires as light, and the party's lantern after dark or in an unlit place (as in the story).
func _light(e: Encounter, party_cbs: Array[Combatant]) -> void:
	for l: Variant in location().get("lights", []):
		var li := l as Dictionary
		var o := FieldObject.new(FieldObject.Kind.ZONE, "", str(li.get("kind", "light")))
		o.cell = _cell_of(li)
		o.rules = {"light": {"bright": int(li.get("bright_ft", 10)), "dim": int(li.get("dim_ft", 10))}}
		e.spells.zones.objects.append(o)
	if e.ambient_light != "bright" and not party_cbs.is_empty():
		var lo := FieldObject.new(FieldObject.Kind.ZONE, "", "lantern")
		lo.caster_id = party_cbs[0].id
		lo.rules = {"light": {"bright": 30, "dim": 30}, "light_on": "caster"}
		e.spells.zones.objects.append(lo)


## Creature ids to surprise, from `surprise`.
func surprised_ids(e: Encounter) -> Array[String]:
	var out: Array[String] = []
	for c in e.combatants:
		if (surprise == "party" and c.side == &"party") or (surprise == "enemies" and c.side == &"enemy"):
			out.append(c.id)
	return out
