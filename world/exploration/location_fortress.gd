class_name LocationFortress
extends RefCounted
## Daern's Instant Fortress on a location's view (docs/story/fortress.md; the story's half is FortressSite): building the
## tower on the map, taking it off again, and finding room for it on the live map.


## Builds the tower on `view` (LocationView._ready, after the doors; LocationMagic when it has just been raised): its
## squares become walls to walking, sight and the fights on the map, the map's rows show them, and the tower is drawn
## over them, rising out of the ground when `rising`.
static func stand(view: LocationView, rising: bool = false) -> void:
	var fs := view.loc.get("fortress", {}) as Dictionary
	if fs.is_empty() or view.board == null:
		return
	var origin := FortressSite.cell_of(fs["cell"])
	var rows := (view.loc["map"] as Dictionary)["rows"] as Array
	var was: Array[String] = []
	for dy in FortressSite.SIDE:
		var row := str(rows[origin.y + dy])
		was.append(row.substr(origin.x, FortressSite.SIDE))
		rows[origin.y + dy] = row.substr(0, origin.x) + "#".repeat(FortressSite.SIDE) + row.substr(origin.x + FortressSite.SIDE)
	fs["was"] = was
	for c in FortressSite.footprint(origin):
		view.grid.set_flag(c, CombatGrid.WALL, true)
	# On a slope it stands level on the highest ground, its footing reaching down to the lowest.
	var hi := -1000.0
	var lo := 1000.0
	for c in FortressSite.footprint(origin):
		var y := view.board.cell_center(c).y
		hi = maxf(hi, y)
		lo = minf(lo, y)
	var at := view.board.cell_center(origin, FortressSite.SIDE)
	at.y = hi
	var tower := FortressTower.build(at, str(fs["looks"]), hi - lo)
	view.add_child(tower)
	view.exit_nodes[FortressSite.ENTRY] = tower
	SeeThrough.mark(tower.get_node("Structure"))   # the walls fade where they hide the party, as walls do
	if rising:
		FortressTower.rise(tower)


## Takes the tower off `view` again (it has been folded): the squares open as they were, the door goes, and the tower
## sinks into the ground.
static func unstand(view: LocationView) -> void:
	var fs := view.loc.get("fortress", {}) as Dictionary
	if fs.is_empty():
		return
	var origin := FortressSite.cell_of(fs["cell"])
	var rows := (view.loc["map"] as Dictionary)["rows"] as Array
	var was := fs.get("was", []) as Array
	for dy in FortressSite.SIDE:
		if dy < was.size():
			var row := str(rows[origin.y + dy])
			rows[origin.y + dy] = row.substr(0, origin.x) + str(was[dy]) + row.substr(origin.x + FortressSite.SIDE)
	for c in FortressSite.footprint(origin):
		view.grid.set_flag(c, CombatGrid.WALL, false)
	var exits := view.loc.get("exits", []) as Array
	for i in range(exits.size() - 1, -1, -1):
		if str((exits[i] as Dictionary).get("id", "")) == FortressSite.ENTRY:
			exits.remove_at(i)
	(view.loc.get("spawns", {}) as Dictionary).erase(FortressSite.FRONT)
	var tower := view.exit_nodes.get(FortressSite.ENTRY, null) as Node3D
	view.exit_nodes.erase(FortressSite.ENTRY)
	view.loc.erase("fortress")
	if tower != null and is_instance_valid(tower):
		FortressTower.sink(tower)


## A plot for the party on the live map `view` (the same as plot_for, with the map's people and any camp counted):
## {} when there is none.
static func plot_in(view: LocationView) -> Dictionary:
	var party: Array[Vector2i] = []
	for m in view.members + view.guest_members:
		party.append(m.cell)
	var people: Array[Vector2i] = []
	for shown in view._npc_shown:
		people.append(shown["cell"] as Vector2i)
	var camp := LocationCamp.of(view)
	if camp != null:
		people.append(camp.center)   # the fire, and everyone seated round it
		for id: String in camp.people:
			people.append((camp.people[id] as Dictionary)["cell"] as Vector2i)
	return FortressSite.plan(view.loc, view.grid, view.leader().cell, party, people)
