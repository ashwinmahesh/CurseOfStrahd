class_name LocationParty
extends RefCounted
## The party's figures in a location (LocationView): where they stand on arriving or after loading, the roster
## changing under them (a respec, a swap, someone joining or leaving), guests at the back of the line, who leads, and
## who is best at a skill.


## Places the party at the spawn (or the saved positions when loading into this location).
static func _place_party(view: LocationView) -> void:
	var spawns := view.loc.get("spawns", {}) as Dictionary
	var start := LocationView._cell(spawns.get(view._spawn_name, spawns.get("default", [1, 1])))
	var use_saved := view._spawn_name == "" and view.st.location == view.loc_id and view.st.positions.size() == view.st.party.size()
	var cells: Array[Vector2i] = []
	if use_saved:
		cells = view.st.positions.duplicate()
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
## Find Familiar familiar that's with its caster (not in its pocket dimension): it follows at the back of the line and
## is marked `familiar_of` its caster, whose fights summon it themselves (EncounterSetup.bring_familiars).
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
		else:
			var keeper := keepers[i - view.st.guests.size()]
			var fam := Monster.from_data(EncounterSetup.familiar_data(keeper))
			fam.id = "familiar_%s" % keeper.id
			cb = Combatant.new(fam, &"guest", cell)
			cb.id = fam.id
			cb.set_meta("familiar_of", keeper.id)
		view.guest_members.append(cb)
		var tok := CombatToken.create(cb, art)
		tok.position = view.board.cell_center(cell)
		view.add_child(tok)
		view.tokens[cb.id] = tok


## Brings the familiars at the back of the line up to date with their casters: one cast just now, lost in a fight,
## dismissed or sent to its pocket dimension. Re-places the guests only when something changed.
static func refresh_familiars(view: LocationView) -> void:
	var want := {}
	for m in view.members:
		if m.creature is Character and (m.creature as Character).familiar == "here" and not m.creature.dead:
			want[m.id] = true
	var have := {}
	for g in view.guest_members:
		if g.has_meta("familiar_of"):
			have[str(g.get_meta("familiar_of"))] = true
	if want != have:
		place_guests(view)


static func _cells_around(view: LocationView, start: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var reach := view.grid.reachable(start, 1, 60, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false)
	var cells: Array = reach.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(reach[a]["cost"]) < int(reach[b]["cost"]))
	for c: Vector2i in cells:
		if out.size() >= n:
			break
		if not c in out:
			out.append(c)
	while out.size() < n:
		out.append(start)
	return out


static func _save_positions(view: LocationView) -> void:
	view.st.positions.clear()
	for m in view.members:
		view.st.positions.append(m.cell)


## Sets who leads (and speaks): moves them to the front of the marching order.
static func set_leader(view: LocationView, index: int) -> void:
	if index <= 0 or index >= view.members.size() or view.in_combat:
		return
	var m := view.members[index]
	view.members.remove_at(index)
	view.members.insert(0, m)
	var ch := view.st.party[index]
	view.st.party.remove_at(index)
	view.st.party.insert(0, ch)
	view.st.leader = 0
	view.rig.follow = view.tokens[m.id] as Node3D
	if view.lantern != null:
		view.lantern.reparent(view.tokens[m.id] as Node3D, false)
	view.toast.emit("%s leads" % ch.name)


static func _best(view: LocationView, skill: StringName) -> Character:
	var best: Character = null
	for ch in view.st.party:
		if ch.hp > 0 and (best == null or ch.skill_bonus(skill).total() > best.skill_bonus(skill).total()):
			best = ch
	return best
