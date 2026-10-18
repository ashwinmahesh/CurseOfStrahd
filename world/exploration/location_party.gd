class_name LocationParty
extends RefCounted
## The party's figures in a location (LocationView): where they stand on arriving or after loading, the roster
## changing under them (a respec, a swap, someone joining or leaving), guests at the back of the line, who leads, and
## who is best at a skill.


## How far (squares) a saved square that is no longer open looks for the nearest one that is, before the party goes to the
## default spawn instead (the load guard, Dungeon Expansion Plan E1).
const NEAREST_OPEN_REACH := 8


## Places the party at the spawn (or the saved positions when loading into this location, any of them that a map edited
## since the save has closed swapped for open squares).
static func _place_party(view: LocationView) -> void:
	var spawns := view.loc.get("spawns", {}) as Dictionary
	var start := LocationView._cell(spawns.get(view._spawn_name, spawns.get("default", [1, 1])))
	var use_saved := view._spawn_name == "" and view.st.location == view.loc_id and view.st.positions.size() == view.st.party.size()
	var cells: Array[Vector2i] = []
	if use_saved:
		cells = open_squares(view, view.st.positions, start)
	else:
		cells = _cells_around(view, start, view.st.party.size())
	view.members.clear()
	for i in view.st.party.size():
		var ch := view.st.party[i]
		var cb := Combatant.new(ch, &"party", cells[i])
		view.members.append(cb)
		var tok := CombatToken.create(cb)
		tok.position = view.board.cell_center(cb.cell)
		view.add_child(tok)
		view.tokens[cb.id] = tok
	_save_positions(view)
	place_guests(view)
	if view.lantern != null and not view.members.is_empty():
		(view.tokens[view.members[0].id] as Node3D).add_child(view.lantern)


## Whether a creature can stand on `c` in the map as it is now. A shut door's square is a wall in the grid, but a hero can
## stand in its doorway (holding it open: LocationFights._combat_grid), so a door's square is open when the door is one the
## party can see; a secret door not yet found is still wall.
static func is_open(view: LocationView, c: Vector2i) -> bool:
	if not view.grid.in_bounds(c):
		return false
	if not view.grid.is_solid(c):
		return true
	return (view.grid.flags(c) & (CombatGrid.LOW | CombatGrid.VOID)) == 0 and _doorway(view, c)


## Whether `c` is the square of a door the party can see (not a secret door nobody has found yet).
static func _doorway(view: LocationView, c: Vector2i) -> bool:
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		if LocationView._cell(door["cell"]) != c:
			continue
		var found := bool((view.st.loc_state(view.loc_id)["found"] as Dictionary).get(str(door["id"]), false))
		return int(door.get("secret_dc", 0)) <= 0 or found
	return false


## The load guard: `saved` as squares the party can stand on in the map as it is now. A square a later edit made a wall, a
## prop or water, or that lies outside a smaller map, becomes the nearest open square nobody else stands on (equally near
## ones: the topmost, then the leftmost), or one beside the default spawn `start` when none is within NEAREST_OPEN_REACH.
## Open squares are kept as saved.
static func open_squares(view: LocationView, saved: Array[Vector2i], start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var taken := {}
	for c in saved:
		if is_open(view, c):
			taken[c] = true
	var around: Array[Vector2i] = []
	for c in saved:
		if is_open(view, c):
			out.append(c)
			continue
		var best := Vector2i(-1, -1)
		var best_d := INF
		for r in range(1, NEAREST_OPEN_REACH + 1):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var n := c + Vector2i(dx, dy)
					var d := float(dx * dx + dy * dy)
					if d < best_d and is_open(view, n) and not taken.has(n):
						best = n
						best_d = d
			if best_d < INF and best_d <= float((r + 1) * (r + 1)):
				break   # nothing on a wider ring is nearer than this
		if best_d == INF:   # nothing open in reach: beside the default spawn
			if around.is_empty():
				around = _cells_around(view, start, saved.size())
			best = start
			for n in around:
				if not taken.has(n):
					best = n
					break
		taken[best] = true
		out.append(best)
	return out


## Whether a fight saved at the start of a round (a round-start save) still fits the map as it is now: nobody on the
## party's side stands on a square that has since closed (a flyer over a chasm or water, or one who left the fight, is
## where it should be). A fight that doesn't fit begins again from its own squares (LocationFights.resume_encounter).
static func snapshot_fits(view: LocationView, snapshot: Dictionary) -> bool:
	for cdv: Variant in (snapshot.get("data", {}) as Dictionary).get("combatants", []):
		var cd := cdv as Dictionary
		if str(cd.get("side", "")) not in ["party", "guest"] or int(cd.get("altitude", 0)) > 0 \
				or bool((cd.get("meta", {}) as Dictionary).get("left_fight", false)):
			continue
		var a := cd["cell"] as Array
		if not is_open(view, Vector2i(int(a[0]), int(a[1]))):
			return false
	return true


## Swaps in party members whose character changed (Madam Eva's respec, a swap on the roster screen) where the old ones
## stood; someone sent to camp leaves, and someone brought along steps in beside the party.
static func rebuild_party(view: LocationView) -> void:
	_fit_party_size(view)
	for i in mini(view.members.size(), view.st.party.size()):
		if view.members[i].creature == view.st.party[i]:
			continue
		var old := view.members[i]
		var tok := view.tokens[old.id] as CombatToken
		if view.lantern != null and view.lantern.get_parent() == tok:
			tok.remove_child(view.lantern)
		tok.queue_free()
		view.tokens.erase(old.id)
		var cb := Combatant.new(view.st.party[i], &"party", old.cell)
		view.members[i] = cb
		var fresh := CombatToken.create(cb)
		fresh.position = view.board.cell_center(cb.cell)
		view.add_child(fresh)
		view.tokens[cb.id] = fresh
		if i == 0:
			view.rig.follow = fresh
			if view.lantern != null and view.lantern.get_parent() == null:
				fresh.add_child(view.lantern)


## Matches the figures to the party's size (the roster screen): figures for members who left go, and members who
## joined stand on free squares near the leader. rebuild_party then swaps any changed faces in place.
static func _fit_party_size(view: LocationView) -> void:
	var left: Array[Combatant] = []
	for cb in view.members:
		if not cb.creature in view.st.party:
			left.append(cb)
	for cb in left:
		if view.members.size() <= view.st.party.size():
			break
		view.members.erase(cb)
		if view.tokens.has(cb.id):
			var tok := view.tokens[cb.id] as CombatToken
			if view.lantern != null and view.lantern.get_parent() == tok:
				tok.remove_child(view.lantern)
			tok.queue_free()
			view.tokens.erase(cb.id)
	if view.members.size() < view.st.party.size() and not view.members.is_empty():
		var taken: Array[Vector2i] = []
		for cb in view.members:
			taken.append(cb.cell)
		var cells := _cells_around(view, view.members[0].cell, view.st.party.size() + view.members.size())
		for i in range(view.members.size(), view.st.party.size()):
			var cell := view.members[0].cell
			for c in cells:
				if not c in taken:
					cell = c
					break
			taken.append(cell)
			var cb := Combatant.new(view.st.party[i], &"party", cell)
			view.members.append(cb)
			var tok := CombatToken.create(cb)
			tok.position = view.board.cell_center(cell)
			view.add_child(tok)
			view.tokens[cb.id] = tok
	# Members keep the party's order (a swap puts the newcomer in the leaver's place).
	var ordered: Array[Combatant] = []
	for ch in view.st.party:
		for cb in view.members:
			if cb.creature == ch:
				ordered.append(cb)
	if ordered.size() == view.members.size():
		view.members = ordered
	if view.lantern != null and not view.members.is_empty() and view.lantern.get_parent() == null:
		(view.tokens[view.members[0].id] as Node3D).add_child(view.lantern)
	if not view.members.is_empty():
		view.rig.follow = view.tokens[view.members[0].id] as Node3D
	_save_positions(view)
	place_guests(view)


## Puts the party's guests behind the last member (called again when someone joins or leaves), and after them each
## Find Familiar familiar that's with its caster (not in its pocket dimension) and each Find Steed steed: they follow
## at the back of the line, marked `familiar_of` or `steed_of` their caster, whose fights summon them themselves
## (EncounterSetup.bring_familiars, bring_steeds).
static func place_guests(view: LocationView) -> void:
	for g in view.guest_members:
		if view.tokens.has(g.id):
			(view.tokens[g.id] as Node).queue_free()
			view.tokens.erase(g.id)
	view.guest_members.clear()
	var keepers: Array[Combatant] = []
	for m in view.members:
		if m.creature is Character and (m.creature as Character).familiar == "here" and not m.creature.dead:
			keepers.append(m)
	# A steed called while exploring (owner report 2026-10-12: Godrick's never showed up) walks with its paladin too.
	var riders: Array[Combatant] = []
	for m in view.members:
		if m.creature is Character and not (m.creature as Character).steed.is_empty() and not m.creature.dead:
			riders.append(m)
	keepers.append_array(riders)
	if (view.st.guests.is_empty() and keepers.is_empty()) or view.members.is_empty():
		return
	var tail := view.members[view.members.size() - 1].cell
	var taken := {}
	for m in view.members:
		taken[m.cell] = true
	var spots := _cells_around(view, tail, view.members.size() + view.st.guests.size() + keepers.size() + 4)
	var k := 0
	for i in view.st.guests.size() + keepers.size():
		while k < spots.size() and taken.has(spots[k]):
			k += 1
		var cell := spots[k] if k < spots.size() else tail
		taken[cell] = true
		var cb: Combatant
		var art := ""
		if i < view.st.guests.size():
			cb = Combatant.new(view.st.guests[i], &"guest", cell)
			art = str(Compendium.shared().get_entry("npcs", view.st.guest_ids[i]).get("sprite", view.st.guest_ids[i]))
		elif i - view.st.guests.size() < keepers.size() - riders.size():
			var keeper := keepers[i - view.st.guests.size()]
			var fam := Monster.from_data(EncounterSetup.familiar_data(keeper))
			fam.id = "familiar_%s" % keeper.id
			cb = Combatant.new(fam, &"guest", cell)
			cb.id = fam.id
			cb.set_meta("familiar_of", keeper.id)
		else:
			var rider := keepers[i - view.st.guests.size()]
			var steed := (rider.creature as Character).steed
			var horse := Monster.from_data(SummonBlocks.for_spell("find_steed", int(steed.get("level", 2)), str(steed.get("type", "celestial")), {}))
			horse.id = "steed_%s" % rider.id
			cb = Combatant.new(horse, &"guest", cell)
			cb.id = horse.id
			cb.set_meta("steed_of", rider.id)
			cb.set_meta("steed", steed.duplicate())   # its type and level, so a new casting swaps it
		view.guest_members.append(cb)
		var tok := CombatToken.create(cb, art)
		tok.position = view.board.cell_center(cell)
		view.add_child(tok)
		view.tokens[cb.id] = tok


## Brings the familiars and steeds at the back of the line up to date with their casters: one cast just now, lost in a
## fight, dismissed or sent to its pocket dimension. Re-places the guests only when something changed.
static func refresh_familiars(view: LocationView) -> void:
	var want := {}
	for m in view.members:
		if m.creature is Character and (m.creature as Character).familiar == "here" and not m.creature.dead:
			want["familiar:" + m.id] = true
		if m.creature is Character and not (m.creature as Character).steed.is_empty() and not m.creature.dead:
			want["steed:%s:%s" % [m.id, (m.creature as Character).steed]] = true
	var have := {}
	for g in view.guest_members:
		if g.has_meta("familiar_of"):
			have["familiar:" + str(g.get_meta("familiar_of"))] = true
		if g.has_meta("steed_of"):
			have["steed:%s:%s" % [g.get_meta("steed_of"), g.get_meta("steed", {})]] = true
	if want != have:
		place_guests(view)


## A familiar or steed walking with its caster: not one of the story's guests, and its caster's fights bring it.
static func is_follower(g: Combatant) -> bool:
	return g.has_meta("familiar_of") or g.has_meta("steed_of")


static func _cells_around(view: LocationView, start: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var reach := view.grid.reachable(start, 1, 60, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false)
	var cells: Array = reach.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(reach[a]["cost"]) < int(reach[b]["cost"]))
	# People don't block the way any more (owner, 2026-10-12), but the party doesn't arrive standing on them.
	var people := {}
	for shown in view._npc_shown:
		people[shown["cell"] as Vector2i] = true
	for c: Vector2i in cells:
		if out.size() >= n:
			break
		if not c in out and not people.has(c):
			out.append(c)
	while out.size() < n:
		out.append(start)
	return out


static func _save_positions(view: LocationView) -> void:
	view.st.positions.clear()
	for m in view.members:
		view.st.positions.append(m.cell)


## Whether `cr` can lead the party and be walked about: not the dead (they stay on the roster and can be revived) and not
## anyone down at 0 Hit Points, who lies where they fell until tended (owner, 2026-10-14: a dead hero was still playable).
static func can_lead(cr: Creature) -> bool:
	return not cr.dead and cr.hp > 0


## The marching-order index of whoever leads next, going `step` (1 forward, -1 back) round the line from the leader and
## passing over the dead and the downed; -1 when nobody else can lead.
static func next_leader(view: LocationView, step: int) -> int:
	var n := view.members.size()
	for k in range(1, n):
		var i := k if step > 0 else n - k
		if can_lead(view.members[i].creature):
			return i
	return -1


## Sets who leads (and speaks): moves them to the front of the marching order. A dead or downed hero can't be picked.
static func set_leader(view: LocationView, index: int) -> void:
	if index <= 0 or index >= view.members.size() or view.in_combat:
		return
	var m := view.members[index]
	var ch := view.st.party[index]
	if not can_lead(ch):
		view.toast.emit("%s is %s and can't lead" % [ch.name, "dead" if ch.dead else "down"])
		return
	view.members.remove_at(index)
	view.members.insert(0, m)
	view.st.party.remove_at(index)
	view.st.party.insert(0, ch)
	view.st.leader = 0
	view.rig.follow = view.tokens[m.id] as Node3D
	if view.lantern != null:
		view.lantern.reparent(view.tokens[m.id] as Node3D, false)
	view.toast.emit("%s leads" % ch.name)


## Hands the lead on to the next hero who can act when the leader is dead or down (fallen in a fight or to a trap, or a
## save that put them first). Nothing changes when nobody can: that is the game over's business. True if it moved.
static func ensure_living_leader(view: LocationView) -> bool:
	if view.in_combat or view.members.is_empty() or can_lead(view.members[0].creature):
		return false
	var next := next_leader(view, 1)
	if next < 0:
		return false
	set_leader(view, next)
	return true


static func _best(view: LocationView, skill: StringName) -> Character:
	var best: Character = null
	for ch in view.st.party:
		if ch.hp > 0 and (best == null or ch.skill_bonus(skill).total() > best.skill_bonus(skill).total()):
			best = ch
	return best
