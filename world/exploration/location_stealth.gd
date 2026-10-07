class_name LocationStealth
extends RefCounted
## Sneaking in a location (LocationView), and who notices whom before a fight (F7, docs/rules/stealth.md).
##
## The party crouches while it sneaks, and each of them keeps the Stealth total they rolled on starting (as the Hide
## action notes its total). Foes waiting in plain view (an encounter marked `waiting`) stand where their fight puts
## them and show once the party can see them. A waiting foe notices a party member it can see clearly within
## NOTICE_FT: at once if the party isn't sneaking, else when its passive Perception (5 lower when that member is in
## dim light to it) is at least the member's total. Being noticed starts the fight, and nobody is surprised.
##
## When the party opens a fight (striking a waiting foe, or stepping into a fight's area) while sneaking, every foe
## that notices none of them is surprised (2024: Disadvantage on Initiative), and a member nobody noticed, with a
## total of 15 or more and Three-Quarters Cover from every foe, starts the fight hidden (the Invisible condition, as
## if they had just taken the Hide action). A party that isn't sneaking is heard coming and surprises no one.

## How far a waiting foe notices the party (a DM's call: the rules set no distance). The maps are compact, and at 60 ft
## foes noticed a party walking past their room or camp, which made optional fights hard to avoid.
const NOTICE_FT := 30
## The Hide action's DC (2024): a sneaking member's total must reach it to start a fight hidden.
const HIDE_DC := 15


## The party crouches while sneaking (CombatToken.sneaking; sprites with the fuller animation set show it).
static func show_crouch(view: LocationView) -> void:
	if view.sneaking == view._shown_sneaking:
		return
	view._shown_sneaking = view.sneaking
	for m: Combatant in view.members + view.guest_members:
		if view.tokens.has(m.id):
			(view.tokens[m.id] as CombatToken).sneaking = view.sneaking
			(view.tokens[m.id] as CombatToken).refresh()


## Starts or stops sneaking. Starting rolls each member's Stealth (foes check it as the party moves); stopping in a
## waiting foe's sight gets the party noticed at once.
static func set_sneaking(view: LocationView, on: bool) -> void:
	if view.in_combat or view.sneaking == on:
		return
	view.sneaking = on
	view.sneak_totals.clear()
	if on:
		_roll_totals(view)
		refresh_waiting(view)
	else:
		after_step(view)


## Each member's Stealth total while sneaking (rolled now for anyone without one, such as a guest who just joined).
static func total_for(view: LocationView, cr: Creature) -> int:
	if not view.sneak_totals.has(cr):
		_roll_one(view, cr)
	return int(view.sneak_totals[cr])


static func _roll_totals(view: LocationView) -> void:
	for m: Combatant in view.members + view.guest_members:
		if m.creature.hp > 0:
			_roll_one(view, m.creature)


static func _roll_one(view: LocationView, cr: Creature) -> void:
	var t := cr.roll_check(view.dice, &"stealth", 0, CheckAids.before_check(cr, &"stealth"), [], "Stealth (%s)" % cr.name)
	view.sneak_totals[cr] = t.total
	view.check_rolled.emit(t.describe())


# --- Foes waiting in plain view ----------------------------------------------------------------------

## The encounter entries whose foes stand in plain view before their fight: `waiting`, started by stepping into an
## area, not yet fought, their `when` true, not an ambush on the party and not a final battle (Strahd parleys first).
static func waiting_specs(view: LocationView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var done := view.st.loc_state(view.loc_id)["encounters"] as Dictionary
	for en: Variant in view.loc.get("encounters", []):
		var id := str((en as Dictionary)["id"])
		if seen.has(id):
			continue
		seen[id] = true
		var spec := LocationFights.spec_for(view, id)
		if not bool(spec.get("waiting", false)) or not str(spec["trigger"]).begins_with("enter_area:"):
			continue
		if str(spec.get("surprise", "")) == "party" or str(spec.get("final_battle", "")) != "":
			continue
		if done.has(id) or not StoryConditions.check(StoryConditions.encounter_when(spec), view.st):
			continue
		out.append(spec)
	return out


## Brings the waiting foes up to date: entries for fights that can happen now, gone for those that can't, and a
## figure for each foe the party can see (it stays once seen).
static func refresh_waiting(view: LocationView) -> void:
	if view.in_combat:
		return
	var specs := waiting_specs(view)
	var ids := {}
	for spec in specs:
		ids[str(spec["id"])] = spec
	for w: Dictionary in view.waiting.duplicate():
		if not ids.has(str(w["encounter"])):
			_drop(view, w)
	var have := {}
	for w in view.waiting:
		have[str(w["encounter"])] = true
	for id: String in ids:
		if have.has(id):
			continue
		var i := 0
		for mo: Dictionary in LocationFights.monsters_for(view, ids[id] as Dictionary):
			var foe := Combatant.new(mo["creature"] as Monster, mo["side"] as StringName, mo["cell"] as Vector2i)
			foe.id = "waiting_%s_%d" % [id, i]
			i += 1
			view.waiting.append({"encounter": id, "foe": foe, "token": null, "low": []})
	if view.waiting.is_empty() or view.members.is_empty() or view.waiting.all(func(w: Dictionary) -> bool: return w["token"] != null):
		return
	# Sight is costly to work out for a character, so only when something that changes it has: where the party
	# stands, the doors, the hour, the lantern, a secret door found.
	var key := _sight_key(view)
	if key == view._waiting_key:
		return
	view._waiting_key = key
	var e := watch(view)
	for w in view.waiting:
		if w["token"] != null:
			continue
		var foe := w["foe"] as Combatant
		if HiddenAreas.hides(view, foe.cell):
			continue
		for m: Combatant in _watchers(view):
			if sees(e, m, foe):
				_show(view, w)
				break


## Whether `a` sees `b` in `e`: the fight's sight rules, after the cheap line-of-sight test that rules most pairs out.
static func sees(e: Encounter, a: Combatant, b: Combatant) -> bool:
	return e.grid.can_see(a.cell, a.size_cells, b.cell, b.size_cells) and e.sight.can_see(a, b)


static func _sight_key(view: LocationView) -> String:
	var cells: Array = []
	for m: Combatant in view.members + view.guest_members:
		cells.append(m.cell)
	return str([cells, view.st.loc_state(view.loc_id)["doors"], view.time_phase(), view.lantern != null and view.lantern.visible,
		HiddenAreas.signature(view), view.waiting.size()])


## Whether the party can see this waiting foe now (it has a figure).
static func is_shown(w: Dictionary) -> bool:
	return w["token"] != null


## The waiting foe standing on `cell` that the party can see: its entry, or {}.
static func foe_at(view: LocationView, cell: Vector2i) -> Dictionary:
	for w in view.waiting:
		if is_shown(w) and cell in (w["foe"] as Combatant).footprint():
			return w
	return {}


static func _show(view: LocationView, w: Dictionary) -> void:
	var foe := w["foe"] as Combatant
	var tok := LocationFights._combat_token(foe)
	tok.position = view.board.cell_center(foe.cell, foe.size_cells)
	view.add_child(tok)
	tok.emerge(0.0, 0.5)
	w["token"] = tok
	# Nobody walks through them; the squares go back to how they were with the fight or when they leave.
	var low: Array[Vector2i] = []
	for c in foe.footprint():
		if not view.grid.has_flag(c, CombatGrid.LOW):
			view.grid.set_flag(c, CombatGrid.LOW, true)
			low.append(c)
	w["low"] = low


static func _drop(view: LocationView, w: Dictionary) -> void:
	for c: Vector2i in w["low"]:
		view.grid.set_flag(c, CombatGrid.LOW, false)
	w["low"] = []
	var tok := w["token"] as CombatToken
	if tok != null and is_instance_valid(tok):
		tok.queue_free()
	w["token"] = null
	view.waiting.erase(w)


## The fight with `encounter_id` started: its waiting foes go (their figures were handed to the fight).
static func clear_waiting(view: LocationView, encounter_id: String) -> void:
	for w: Dictionary in view.waiting.duplicate():
		if str(w["encounter"]) == encounter_id:
			_drop(view, w)


## The waiting figure for the fight's combatant `c` (the same square), handed over so the foe doesn't fade in again;
## null if there's none.
static func claim_token(view: LocationView, c: Combatant) -> CombatToken:
	for w in view.waiting:
		var tok := w["token"] as CombatToken
		if tok != null and is_instance_valid(tok) and (w["foe"] as Combatant).cell == c.cell and (w["foe"] as Combatant).creature.name == c.creature.name:
			w["token"] = null
			tok.combatant = c
			tok.refresh()
			return tok
	return null


# --- Who notices whom --------------------------------------------------------------------------------

## A fight-free Encounter that only answers who can see whom here now (the fight's own sight rules: walls and closed
## doors, the light of the hour, lamps and the lantern, Darkvision): the party (its own combatants, so nothing is
## rebound to it) and the waiting foes.
static func watch(view: LocationView) -> Encounter:
	var e := Encounter.new(LocationFights._combat_grid(view), view.dice)
	e.outdoors = bool(view.loc["map"].get("outdoors", false))
	for m: Combatant in view.members + view.guest_members:
		e.combatants.append(m)
	for w in view.waiting:
		e.combatants.append(w["foe"] as Combatant)
	LocationFights._light_the_fight(view, e)
	return e


## Party members and guests who are up (only they can be seen moving, or look).
static func _watchers(view: LocationView) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for m: Combatant in view.members + view.guest_members:
		if m.creature.hp > 0:
			out.append(m)
	return out


## Whether `foe` notices `who` in encounter `e`: it's up, within NOTICE_FT, sees them with less than Three-Quarters
## Cover, and either the party isn't sneaking or its passive Perception (5 lower when `who` stands in dim light to it,
## which Lightly Obscures them) is at least `total`.
static func notices(e: Encounter, foe: Combatant, who: Combatant, sneaking: bool, total: int) -> bool:
	if not foe.can_act() or who.creature.hp <= 0:
		return false
	# Cheapest first: distance, then sight, then the Stealth contest, and cover (the costly trace) last. Creatures
	# give at most Half Cover, so only walls and the like are traced.
	if e.distance(foe, who) > NOTICE_FT or not sees(e, foe, who):
		return false
	if sneaking and passive_perception(e, foe, who) < total:
		return false
	return int(e.grid.cover_between(foe.cell, foe.size_cells, who.cell, who.size_cells)["cover"]) < CombatGrid.Cover.THREE_QUARTERS


## `foe`'s passive Perception against `who`: 5 lower when `who` stands in dim light as `foe` sees it (Darkvision
## sees darkness as dim light, and dim light as bright).
static func passive_perception(e: Encounter, foe: Combatant, who: Combatant) -> int:
	if not foe.has_meta("passive_perception"):
		foe.set_meta("passive_perception", foe.creature.passive_score(&"perception").total())
	var score := int(foe.get_meta("passive_perception"))
	var light := e.sight.light_at(who.cell)
	var dv := foe.creature.darkvision()
	if dv > 0 and dv >= e.distance(foe, who):
		light = {"dark": "dim", "dim": "bright"}.get(light, light) as String
	return score - 5 if light == "dim" else score


## The first party member `foe` notices in `e` (the party's combatants there), or null.
static func noticed_by(view: LocationView, e: Encounter, foe: Combatant) -> Combatant:
	for c in e.combatants:
		if c.side in [&"party", &"guest"] and notices(e, foe, c, view.sneaking, total_for(view, c.creature) if view.sneaking else 0):
			return c
	return null


## After the party moves (or starts or stops sneaking): figures for the foes it can now see, and a foe that notices
## anyone starts its fight. True if a fight started.
static func after_step(view: LocationView) -> bool:
	if view.in_combat:
		return false
	refresh_waiting(view)
	if view.waiting.is_empty():
		return false
	var e := watch(view)
	for w in view.waiting:
		var spec := LocationFights.spec_for(view, str(w["encounter"]))
		if str(spec.get("surprise", "")) == "enemies":
			continue   # asleep or otherwise unaware until the fight starts
		var foe := w["foe"] as Combatant
		var who := noticed_by(view, e, foe)
		if who == null:
			continue
		view._foes_alerted = true
		view.toast.emit("%s spots %s" % [foe.name() if is_shown(w) else "Something", who.name()])
		view.start_encounter(str(w["encounter"]))
		view._foes_alerted = false
		return true
	return false


## Who can see you (U10): what a foe in plain view would make of the leader standing on `cell` now ("<foe> would
## see <name> there"), or "". The lantern goes with them, and a foe asleep (`surprise: enemies`) sees nobody.
static func hover_warning(view: LocationView, cell: Vector2i) -> String:
	if view.in_combat or view.members.is_empty() or view.waiting.is_empty() or not view.grid.in_bounds(cell):
		return ""
	var who := view.leader()
	var was := who.cell
	who.cell = cell
	var e := watch(view)
	var out := ""
	for w in view.waiting:
		if not is_shown(w) or str(LocationFights.spec_for(view, str(w["encounter"])).get("surprise", "")) == "enemies":
			continue
		var foe := w["foe"] as Combatant
		if notices(e, foe, who, view.sneaking, total_for(view, who.creature) if view.sneaking else 0):
			out = "%s would see %s there" % [foe.name(), who.name().get_slice(" ", 0)]
			break
	who.cell = was
	return out


## The party opens the fight with this waiting foe (a strike from plan mode or the right-click menu).
static func strike(view: LocationView, encounter_id: String) -> bool:
	if view.in_combat:
		return false
	return view.start_encounter(encounter_id)


## The nearest fight with a foe the party can see, or "".
static func nearest_waiting(view: LocationView) -> String:
	var best := ""
	var best_d := 1 << 30
	if view.members.is_empty():
		return best
	for w in view.waiting:
		if not is_shown(w):
			continue
		var d := view.grid.distance_ft(view.leader().cell, 1, (w["foe"] as Combatant).cell, (w["foe"] as Combatant).size_cells)
		if d < best_d:
			best_d = d
			best = str(w["encounter"])
	return best


# --- The fight opening -------------------------------------------------------------------------------

## Who a fight surprises (2024: Disadvantage on Initiative): with the party sneaking, each foe in `e` that notices
## none of the party as it opens. A party that isn't sneaking is heard coming, and a fight the foes start (one of
## them noticed someone) surprises no one.
static func surprised_at_start(view: LocationView, e: Encounter) -> Array[String]:
	var out: Array[String] = []
	if not view.sneaking or view._foes_alerted:
		return out
	for c in e.combatants:
		if c.side == &"enemy" and noticed_by(view, e, c) == null:
			out.append(c.id)
	return out


## Party members who start the fight hidden: the party is sneaking and opened the fight, nobody noticed them, their
## Stealth total meets the Hide DC, and they have Three-Quarters Cover from every foe (the Hide action's needs).
static func hide_at_start(view: LocationView, e: Encounter) -> void:
	if not view.sneaking or view._foes_alerted:
		return
	var seen := {}
	for foe in e.combatants:
		if foe.side == &"enemy":
			for c in e.combatants:
				if c.side in [&"party", &"guest"] and notices(e, foe, c, true, total_for(view, c.creature)):
					seen[c] = true
	for c in e.combatants:
		if not c.side in [&"party", &"guest"] or seen.has(c) or c.creature.hp <= 0:
			continue
		var total := total_for(view, c.creature)
		if total < HIDE_DC or e.hide_blocker(c) != "":
			continue
		c.hidden = true
		c.stealth_total = total
		c.creature.add_condition(&"invisible", "Hidden")
		e.log.add("info", "%s starts the fight hidden (Stealth %d)" % [c.name(), total], c.id)


## The fight is over: nobody stays hidden out of it (the Invisible condition Hide gave ends).
static func after_fight(view: LocationView, e: Encounter) -> void:
	view._foes_alerted = false
	for c in e.combatants:
		if c.side in [&"party", &"guest"] and (c.hidden or c.creature.has_condition(&"invisible")):
			c.hidden = false
			c.creature.remove_condition(&"invisible", "Hidden")
