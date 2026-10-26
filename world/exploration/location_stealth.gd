class_name LocationStealth
extends RefCounted
## Sneaking in a location (LocationView), and who notices whom before a fight (F7, docs/rules/stealth.md).
##
## The party crouches while it sneaks, and each of them keeps the Stealth total they rolled (as the Hide action notes
## its total): one roll a visit, kept while the party stops and starts sneaking, until it leaves the place or an hour of
## the clock has passed (a Short or Long Rest takes one). A party that walks out through an exit sneaking arrives
## sneaking, with fresh rolls (GameRoot.enter_location). Foes waiting in plain view (an encounter marked `waiting`)
## stand where their fight puts them and show once the party can see them; a foe marked `unseen` waits out of view and
## appears with the fight. A waiting foe notices a party member it can see clearly within NOTICE_FT, if the member is
## inside its sight cone (CONE_DEG of the way it faces), or hears them within HEAR_FT whatever way it faces: at once if
## the party isn't sneaking, else when its passive Perception (5 lower when that member is in dim light to it, for
## sight) is at least the member's total. Being noticed starts the fight, and nobody is surprised. The cones hold only
## before a fight (owner, 2026-10-07, after Baldur's Gate 3); fights keep the 2024 rules, which have no facing.
##
## A sneaking party that steps into a waiting fight's area unnoticed starts nothing (step_in): the foes stand where they
## are and keep checking every step, and a foe that notices someone starts the fight, with nobody surprised. The party
## slips past the fight when every member has left the area again unnoticed (_check_slipped); stopping to sneak inside the
## area starts it (start_guarded_here), as stepping in without sneaking does. Taking from a container in the area asks
## the same notice rule (guard_take). docs/rules/stealth.md, "Slipping past".
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
## Before a fight a watcher sees only this wide an arc ahead of it (degrees), and hears the party all round within
## HEAR_FT (owner, 2026-10-07: Baldur's Gate 3's sight cones, outside fights only).
const CONE_DEG := 120.0
const HEAR_FT := 10
## How long a Stealth roll stands, in minutes of the clock (the visit's one roll; see set_sneaking).
const ROLL_MINUTES := 60
## Directions a location's data can give a figure's `facing` (grid x right, y down: north is up the map).
const DIRECTIONS := {"north": Vector2(0, -1), "south": Vector2(0, 1), "east": Vector2(1, 0), "west": Vector2(-1, 0),
	"northeast": Vector2(1, -1), "northwest": Vector2(-1, -1), "southeast": Vector2(1, 1), "southwest": Vector2(-1, 1)}


## The party crouches while sneaking (CombatToken.sneaking; sprites with the fuller animation set show it).
static func show_crouch(view: LocationView) -> void:
	if view.sneaking == view._shown_sneaking:
		return
	view._shown_sneaking = view.sneaking
	for m: Combatant in view.members + view.guest_members:
		if view.tokens.has(m.id):
			(view.tokens[m.id] as CombatToken).sneaking = view.sneaking
			(view.tokens[m.id] as CombatToken).refresh()


## Starts or stops sneaking. Starting rolls Stealth for each member without a total kept from earlier in this visit
## (ROLL_MINUTES), so stopping and starting again is no free reroll; foes check the totals as the party moves. Stopping
## inside a waiting fight's area starts that fight; in a waiting foe's sight it gets the party noticed at once.
static func set_sneaking(view: LocationView, on: bool) -> void:
	if view.in_combat or view.sneaking == on:
		return
	view.sneaking = on
	if on:
		_roll_totals(view)
		refresh_waiting(view)
	elif not start_guarded_here(view):
		after_step(view)


## Each member's Stealth total while sneaking (rolled now for anyone without a kept one, such as a guest who just
## joined, or whose roll is an hour old).
static func total_for(view: LocationView, cr: Creature) -> int:
	if not kept(view, cr):
		_roll_one(view, cr)
	return int(view.sneak_totals[cr])


## Whether `cr` has a Stealth total from this visit that still stands: rolled less than ROLL_MINUTES ago on the clock
## (a total set without a time, by a test or a capture, stands).
static func kept(view: LocationView, cr: Creature) -> bool:
	if not view.sneak_totals.has(cr):
		return false
	return not view.sneak_rolled.has(cr) or view.st.total_minutes() - int(view.sneak_rolled[cr]) < ROLL_MINUTES


static func _roll_totals(view: LocationView) -> void:
	for m: Combatant in view.members + view.guest_members:
		if m.creature.hp > 0 and not kept(view, m.creature):
			_roll_one(view, m.creature)


static func _roll_one(view: LocationView, cr: Creature) -> void:
	var t := cr.roll_check(view.dice, &"stealth", 0, CheckAids.before_check(cr, &"stealth"), [], "Stealth (%s)" % cr.name)
	view.sneak_totals[cr] = t.total
	view.sneak_rolled[cr] = view.st.total_minutes()
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
		if done.has(id) or not StoryConditions.check(StoryConditions.encounter_when(spec, str(view.loc.get("region", ""))), view.st):
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
		var monsters := LocationFights.monsters_for(view, ids[id] as Dictionary)
		var entries := (ids[id] as Dictionary)["monsters"] as Array
		for i in monsters.size():
			# An `unseen` foe isn't in plain view before its fight (among the casks): no figure, and it notices no one
			# until the fight puts it on its square.
			if bool((entries[i] as Dictionary).get("unseen", false)):
				continue
			var mo := monsters[i]
			var foe := Combatant.new(mo["creature"] as Monster, mo["side"] as StringName, mo["cell"] as Vector2i)
			foe.id = "waiting_%s_%d" % [id, i]
			view.waiting.append({"encounter": id, "foe": foe, "token": null, "low": [],
				"facing": waiting_facing(view, ids[id] as Dictionary, i, monsters)})
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
	tok.face(w["facing"] as Vector2, false)   # its sight cone points the way it looks
	if LyingFigures.of(foe.creature) != null:
		LyingFigures.lay(view, tok, LyingFigures.of(foe.creature), foe.cell)   # curled in the straw until the fight
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
	view._slipping.erase(encounter_id)
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

## Which way a waiting foe faces before its fight: its entry's `facing`, else toward the middle of its group (gathered
## round a fire, a cauldron, a dig), else toward the middle of its fight's area, else toward where the party arrives.
static func waiting_facing(view: LocationView, spec: Dictionary, i: int, monsters: Array[Dictionary]) -> Vector2:
	var given := str(((spec["monsters"] as Array)[i] as Dictionary).get("facing", ""))
	if DIRECTIONS.has(given):
		return (DIRECTIONS[given] as Vector2).normalized()
	var me := Vector2(monsters[i]["cell"] as Vector2i)
	# The middle of the group in view: `unseen` foes elsewhere (the cask vaults behind the dig) don't turn it round.
	var shown: Array[Vector2] = []
	for j in monsters.size():
		if not bool(((spec["monsters"] as Array)[j] as Dictionary).get("unseen", false)):
			shown.append(Vector2(monsters[j]["cell"] as Vector2i))
	if shown.size() >= 2:
		var mid := Vector2.ZERO
		for c in shown:
			mid += c
		mid /= shown.size()
		if me.distance_to(mid) > 0.5:
			return (mid - me).normalized()
	for a: Variant in view.loc.get("areas", []):
		var area := a as Dictionary
		if "enter_area:" + str(area["id"]) == str(spec["trigger"]):
			var lo := LocationView._cell((area["cells"] as Array)[0])
			var hi := LocationView._cell((area["cells"] as Array)[1])
			var centre := (Vector2(lo) + Vector2(hi)) / 2.0
			if me.distance_to(centre) > 0.5:
				return (centre - me).normalized()
	var spawn := Vector2(LocationView._cell((view.loc.get("spawns", {}) as Dictionary).get("default", [0, 0])))
	return (spawn - me).normalized() if spawn.distance_to(me) > 0.5 else Vector2(0, 1)


## Which way a figure faces on the grid (x right, y down), from its sprite; Vector2.ZERO without one.
static func token_facing(tok: CombatToken) -> Vector2:
	if tok == null or not is_instance_valid(tok) or tok.sprite == null:
		return Vector2.ZERO
	var f := tok.sprite.facing
	return Vector2(f.x, f.z).normalized()


## Gives `who` a sight cone pointing along `facing` for the notice rules (Vector2.ZERO: it sees all round).
static func set_cone(who: Combatant, facing: Vector2) -> void:
	if facing.length() < 0.01:
		if who.has_meta("watch_facing"):
			who.remove_meta("watch_facing")
	else:
		who.set_meta("watch_facing", facing.normalized())


## Whether the square `cell` (a creature `size` squares across there) is inside `watcher`'s sight cone; always, for a
## watcher without one.
static func in_cone(watcher: Combatant, cell: Vector2i, size: int = 1) -> bool:
	if not watcher.has_meta("watch_facing"):
		return true
	var to := (Vector2(cell) + Vector2.ONE * (size / 2.0)) - (Vector2(watcher.cell) + Vector2.ONE * (watcher.size_cells / 2.0))
	if to.length() < 0.01:
		return true
	return (watcher.get_meta("watch_facing") as Vector2).dot(to.normalized()) >= cos(deg_to_rad(CONE_DEG / 2.0)) - 0.0001


## The way a waiting foe looks now: its figure's (so a foe that turns, or walks a route, turns its cone), else the way
## it was set to face.
static func cone_of(w: Dictionary) -> Vector2:
	var tok := w["token"] as CombatToken
	var f := token_facing(tok)
	return f if f.length() > 0.01 else w.get("facing", Vector2.ZERO) as Vector2


## A fight-free Encounter that only answers who can see whom here now (the fight's own sight rules: walls and closed
## doors, the light of the hour, lamps and the lantern, Darkvision): the party (its own combatants, so nothing is
## rebound to it) and the waiting foes.
static func watch(view: LocationView) -> Encounter:
	var e := Encounter.new(LocationFights._combat_grid(view), view.dice)
	e.outdoors = bool(view.loc["map"].get("outdoors", false))
	for m: Combatant in view.members + view.guest_members:
		e.combatants.append(m)
	for w in view.waiting:
		set_cone(w["foe"] as Combatant, cone_of(w))
		e.combatants.append(w["foe"] as Combatant)
	LocationFights._light_the_fight(view, e)
	return e


## The waiting foes awake and in plain view of the party now, by name (Wait and a Short Rest need the party out of
## their sight; WaitScreen.why_not, RestRules.short_rest_refusals): any a party member or guest who is up can see, not
## hidden away (HiddenAreas), the nearest first. A foe waiting out of view (`unseen`) isn't among them, and neither is
## one the party saw once and has left behind. While the party sneaks, a foe that would notice none of them (the notice
## rule, with each member's kept total) doesn't count.
static func foes_in_sight(view: LocationView) -> Array[String]:
	var out: Array[String] = []
	if view == null or view.in_combat or view.waiting.is_empty() or view.members.is_empty():
		return out
	var e := watch(view)
	var seen: Array[Combatant] = []
	for w in view.waiting:
		var foe := w["foe"] as Combatant
		if not foe.can_act() or HiddenAreas.hides(view, foe.cell):
			continue
		for m: Combatant in _watchers(view):
			if sees(e, m, foe):
				if not view.sneaking or noticed_by(view, e, foe) != null:
					seen.append(foe)
				break
	var lead := view.leader().cell
	seen.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return view.grid.distance_ft(lead, 1, a.cell, a.size_cells) < view.grid.distance_ft(lead, 1, b.cell, b.size_cells))
	for foe in seen:
		var what := foe_label(foe)
		if not what in out:
			out.append(what)
	return out


## A foe by the name of its kind ("Wolf", not "Wolf 2").
static func foe_label(foe: Combatant) -> String:
	return str((foe.creature as Monster).data.get("name", foe.name())) if foe.creature is Monster else foe.name()


## Party members and guests who are up (only they can be seen moving, or look).
static func _watchers(view: LocationView) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for m: Combatant in view.members + view.guest_members:
		if m.creature.hp > 0:
			out.append(m)
	return out


## Whether `foe` notices `who` in encounter `e`: it's up and within NOTICE_FT. Within HEAR_FT it hears them whatever
## way it faces and whatever the light, unless a wall is between them. Farther off, `who` must be inside its sight cone
## (if it has one: before a fight), seen with less than Three-Quarters Cover. Either way, a sneaking party is noticed
## only when its passive Perception is at least `total` (5 lower, for sight, when `who` stands in dim light to it,
## which Lightly Obscures them).
static func notices(e: Encounter, foe: Combatant, who: Combatant, sneaking: bool, total: int) -> bool:
	if not foe.can_act() or who.creature.hp <= 0:
		return false
	var dist := e.distance(foe, who)
	if dist > NOTICE_FT:
		return false
	if dist <= HEAR_FT:
		if not e.grid.can_see(foe.cell, foe.size_cells, who.cell, who.size_cells):
			return false   # through a wall or a closed door
		return not sneaking or passive_score(foe) >= total
	# Cheapest first: the cone, then sight, then the Stealth contest, and cover (the costly trace) last. Creatures
	# give at most Half Cover, so only walls and the like are traced.
	if not in_cone(foe, who.cell, who.size_cells) or not sees(e, foe, who):
		return false
	if sneaking and passive_perception(e, foe, who) < total:
		return false
	return int(e.grid.cover_between(foe.cell, foe.size_cells, who.cell, who.size_cells)["cover"]) < CombatGrid.Cover.THREE_QUARTERS


## `foe`'s passive Perception, worked out once and kept on it.
static func passive_score(foe: Combatant) -> int:
	if not foe.has_meta("passive_perception"):
		foe.set_meta("passive_perception", foe.creature.passive_score(&"perception").total())
	return int(foe.get_meta("passive_perception"))


## `foe`'s passive Perception against `who`: 5 lower when `who` stands in dim light as `foe` sees it (Darkvision
## sees darkness as dim light, and dim light as bright).
static func passive_perception(e: Encounter, foe: Combatant, who: Combatant) -> int:
	var score := passive_score(foe)
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


## After the party moves (or starts or stops sneaking): the fights it has slipped past, figures for the foes it can now
## see, and a foe that notices anyone starts its fight. True if a fight started.
static func after_step(view: LocationView) -> bool:
	if view.in_combat:
		return false
	_check_slipped(view)
	refresh_waiting(view)
	if view.waiting.is_empty():
		return false
	var e := watch(view)
	for w in view.waiting:
		if is_asleep(view, w):
			continue   # asleep or otherwise unaware until the fight starts
		var who := noticed_by(view, e, w["foe"] as Combatant)
		if who == null:
			continue
		_alert(view, w, who)
		return true
	return false


## A foe noticed `who`: it starts its fight, and that fight surprises no one.
static func _alert(view: LocationView, w: Dictionary, who: Combatant) -> void:
	view._foes_alerted = true
	view.toast.emit("%s spots %s" % [(w["foe"] as Combatant).name() if is_shown(w) else "Something", who.name()])
	view.start_encounter(str(w["encounter"]))
	view._foes_alerted = false


## Whether a waiting foe is asleep (`surprise: enemies`): it notices nobody before its fight starts.
static func is_asleep(view: LocationView, w: Dictionary) -> bool:
	return str(LocationFights.spec_for(view, str(w["encounter"])).get("surprise", "")) == "enemies"


## Who can see you (U10): what a foe in plain view, or (while the party sneaks) anyone standing here, would make of
## the leader standing on `cell` now ("<who> would see <name> there"), or "". The lantern goes with them, and a foe
## asleep (`surprise: enemies`) sees nobody. A party that isn't sneaking is told instead when `cell` is inside the area
## of a waiting fight it can see (guarded_hint).
static func hover_warning(view: LocationView, cell: Vector2i) -> String:
	if view.in_combat or view.members.is_empty() or not view.grid.in_bounds(cell):
		return ""
	if view.waiting.is_empty() and not view.sneaking:
		return ""
	var guarded := guarded_hint(view, cell)   # not sneaking: a foe's area, where stepping in starts its fight
	if guarded != "":
		return guarded
	var who := view.leader()
	var was := who.cell
	who.cell = cell
	var e := watch(view)
	var total := total_for(view, who.creature) if view.sneaking else 0
	var watchers: Array[Combatant] = []
	for w in view.waiting:
		if is_shown(w) and str(LocationFights.spec_for(view, str(w["encounter"])).get("surprise", "")) != "enemies":
			watchers.append(w["foe"] as Combatant)
	if view.sneaking:
		# The people here would see a theft or a trespass (F8).
		for npc_id: String in LocationCrime.people(view):
			if not npc_id in view.st.guest_ids:
				watchers.append(LocationCrime.person(view, npc_id))
	var out := ""
	for watcher in watchers:
		if notices(e, watcher, who, view.sneaking, total):
			out = "%s would see %s there" % [watcher.name(), who.name().get_slice(" ", 0)]
			break
	who.cell = was
	return out


## What the foes in plain view make of party member `cr` sneaking at their kept Stealth total, for the badge on their
## portrait: {total, mood, foes}. `mood` is the sight overlay's for the worst foe (SightOverlay.eye_mood): "notices" (a
## foe would notice them even in dim light), "bright" (only in bright light) or "beaten" (none would), and `foes` are
## the kinds behind a "notices" or "bright". Only waiting foes shown and able to notice count, not ones asleep
## (`surprise: enemies`).
static func exposure(view: LocationView, cr: Creature) -> Dictionary:
	var total := total_for(view, cr)
	var named := {"notices": [] as Array[String], "bright": [] as Array[String]}
	for w in view.waiting:
		var foe := w["foe"] as Combatant
		if not is_shown(w) or not foe.can_act() or is_asleep(view, w):
			continue
		var mood := SightOverlay.eye_mood(foe, total, true)
		if mood != "beaten" and not foe_label(foe) in (named[mood] as Array[String]):
			(named[mood] as Array[String]).append(foe_label(foe))
	var worst := "notices" if not (named["notices"] as Array).is_empty() else ("bright" if not (named["bright"] as Array).is_empty() else "beaten")
	return {"total": total, "mood": worst, "foes": named.get(worst, [] as Array[String])}


## What an exposure says, as the badge's hint: "Stealth 7: the Wolf would notice them in any light".
static func exposure_text(ex: Dictionary) -> String:
	var who := _the_kinds(ex["foes"] as Array)
	match str(ex["mood"]):
		"notices":
			return "Stealth %d: %s would notice them in any light" % [int(ex["total"]), who]
		"bright":
			return "Stealth %d: %s would notice them in bright light" % [int(ex["total"]), who]
	return "Stealth %d: no foe in view would notice them" % int(ex["total"])


## Foe kinds as a phrase: "the Wolf", "the Wolf and the Zombie", "the Wolf, the Zombie and others".
static func _the_kinds(kinds: Array) -> String:
	if kinds.size() == 1:
		return "the %s" % kinds[0]
	if kinds.size() == 2:
		return "the %s and the %s" % [kinds[0], kinds[1]]
	if kinds.size() > 2:
		return "the %s, the %s and others" % [kinds[0], kinds[1]]
	return ""


# --- Slipping past ------------------------------------------------------------------------------------

## Whether `spec` is a fight whose foes guard their area: it waits in plain view, starts on stepping into an area, isn't an
## ambush on the party or a final battle, and has a foe that isn't `unseen` (a fight of unseen foes only still starts on
## the step). The fights LocationStealth.waiting_specs lists that have foes in view.
static func guards(spec: Dictionary) -> bool:
	if not bool(spec.get("waiting", false)) or not str(spec.get("trigger", "")).begins_with("enter_area:"):
		return false
	if str(spec.get("surprise", "")) == "party" or str(spec.get("final_battle", "")) != "":
		return false
	return (spec.get("monsters", []) as Array).any(func(m: Variant) -> bool: return not bool((m as Dictionary).get("unseen", false)))


## The waiting fights whose foes guard their area now (`guards`, not yet fought, their `when` true).
static func guarded_specs(view: LocationView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec in waiting_specs(view):
		if guards(spec):
			out.append(spec)
	return out


## The area (its data entry) whose entering starts `spec`, or {}.
static func area_of(view: LocationView, spec: Dictionary) -> Dictionary:
	for a: Variant in view.loc.get("areas", []):
		if "enter_area:" + str((a as Dictionary)["id"]) == str(spec.get("trigger", "")):
			return a as Dictionary
	return {}


## The kinds of the foes of fight `encounter_id` the party can see, as "the Wolf and the Zombie" ("" if none shown: a
## fight the party hasn't seen gives away nothing).
static func kinds_in_view(view: LocationView, encounter_id: String) -> String:
	var kinds: Array[String] = []
	for w in view.waiting:
		if str(w["encounter"]) == encounter_id and is_shown(w) and not foe_label(w["foe"] as Combatant) in kinds:
			kinds.append(foe_label(w["foe"] as Combatant))
	return _the_kinds(kinds)


## The leader stepped into the area of `spec`, a fight that waits in plain view (LocationFights._trigger_encounter).
## "" when the fight starts as it always did (the party isn't sneaking, or the fight has no foes in view to slip past);
## "spotted" when a foe of it notices someone, and starts it (nobody surprised); "slipped" when none does: nothing starts,
## and the party is slipping past it until every member has left the area again.
static func step_in(view: LocationView, spec: Dictionary) -> String:
	if not view.sneaking or not guards(spec):
		return ""
	refresh_waiting(view)
	var id := str(spec["id"])
	var foes: Array[Dictionary] = []
	for w in view.waiting:
		if str(w["encounter"]) == id:
			foes.append(w)
	if foes.is_empty():
		return ""
	var e := watch(view)
	for w in foes:
		if is_asleep(view, w):
			continue
		var who := noticed_by(view, e, w["foe"] as Combatant)
		if who != null:
			_alert(view, w, who)
			return "spotted"
	view._slipping[id] = true
	var kinds := kinds_in_view(view, id)
	if kinds != "":
		var shown := foes.filter(func(w: Dictionary) -> bool: return is_shown(w)).size()
		view.toast.emit("Unnoticed: %s %s seen you" % [kinds, "hasn't" if shown == 1 else "haven't"])
	return "slipped"


## After a step: each fight the party slipped into unnoticed that no one in the party (nor a guest) stands in the area of
## now is slipped past, if it hasn't started. A fight that has started, was won or stopped waiting (its night is over)
## is forgotten.
static func _check_slipped(view: LocationView) -> void:
	if view._slipping.is_empty():
		return
	var specs := guarded_specs(view)
	for id: String in view._slipping.keys():
		var spec := {}
		for s in specs:
			if str(s["id"]) == id:
				spec = s
		var area := area_of(view, spec) if not spec.is_empty() else {}
		if area.is_empty():
			view._slipping.erase(id)
			continue
		if _watchers(view).any(func(m: Combatant) -> bool: return LocationView._in_area(area, m.cell)):
			continue
		view._slipping.erase(id)
		_slipped_past(view, spec)


## The party slipped past waiting fight `spec`: said, and in XP mode paid as a fight talked away is (Xp.talked_away: what
## winning the version it would have met pays, once a fight, so fighting it later pays nothing more). The fight's flag
## isn't set, and it stays to be fought: entering again without sneaking starts it.
static func _slipped_past(view: LocationView, spec: Dictionary) -> void:
	var kinds := kinds_in_view(view, str(spec["id"]))
	if kinds != "":
		view.toast.emit("Slipped past %s" % kinds)
	var earned := Xp.talked_away(view.st, str(spec["id"]))
	if earned != "":
		view.toast.emit(earned)


## Stopping to sneak inside the area of a waiting fight starts it, as stepping in without sneaking would, whether or not
## a foe would have noticed. True if one started.
static func start_guarded_here(view: LocationView) -> bool:
	if view.in_combat or view.members.is_empty():
		return false
	for spec in guarded_specs(view):
		var area := area_of(view, spec)
		if not area.is_empty() and LocationView._in_area(area, view.leader().cell):
			return LocationFights.start_encounter(view, str(spec["id"]), spec)
	return false


## The waiting fight guarding the container `ct` (its square is inside the fight's area), or {}. Read off the foes waiting
## now (the hover hint asks often).
static func guarding_fight(view: LocationView, ct: Dictionary) -> Dictionary:
	var at := LocationView._cell(ct["cell"])
	var seen := {}
	for w in view.waiting:
		var id := str(w["encounter"])
		if seen.has(id):
			continue
		seen[id] = true
		var spec := LocationFights.spec_for(view, id)
		var area := area_of(view, spec) if not spec.is_empty() and guards(spec) else {}
		if not area.is_empty() and LocationView._in_area(area, at):
			return spec
	return {}


## The hover hint's note for a container guarded by a waiting fight, or "" (beside LocationCrime.owned_note).
static func guarded_note(view: LocationView, ct: Dictionary) -> String:
	return " (Guarded: taking from it where they'd see starts the fight)" if not guarding_fight(view, ct).is_empty() else ""


## The leader opens container `ct` to take from it. If it is guarded, the fight's foes ask the same notice rule as at every
## step of the leader (their sight cone, the 10 ft ring, light and cover; the leader's kept Stealth total while sneaking,
## none when not): one that would notice them starts its fight (nobody surprised) and nothing is taken. True if it did.
static func guard_take(view: LocationView, ct: Dictionary) -> bool:
	if view.members.is_empty():
		return false
	refresh_waiting(view)
	var spec := guarding_fight(view, ct)
	if spec.is_empty():
		return false
	var e := watch(view)
	var taker := view.leader()
	var total := total_for(view, taker.creature) if view.sneaking else 0
	for w in view.waiting:
		if str(w["encounter"]) == str(spec["id"]) and not is_asleep(view, w) \
				and notices(e, w["foe"] as Combatant, taker, view.sneaking, total):
			_alert(view, w, taker)
			return true
	return false


## What hovering `cell` says to a party that isn't sneaking: inside the area of a waiting fight whose foes it can see,
## stepping in starts the fight. "" elsewhere, and for a fight the party hasn't seen.
static func guarded_hint(view: LocationView, cell: Vector2i) -> String:
	if view.sneaking or view.in_combat or view.waiting.is_empty():
		return ""
	for w in view.waiting:
		if not is_shown(w):
			continue
		var spec := LocationFights.spec_for(view, str(w["encounter"]))
		var area := area_of(view, spec) if not spec.is_empty() and guards(spec) else {}
		if not area.is_empty() and LocationView._in_area(area, cell):
			return "Stepping in starts the fight; sneak to pass unseen"
	return ""


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
	_carry_cones(view, e)
	for c in e.combatants:
		if c.side == &"enemy" and noticed_by(view, e, c) == null:
			out.append(c.id)
	return out


## Party members who start the fight hidden: the party is sneaking and opened the fight, nobody noticed them, their
## Stealth total meets the Hide DC, and they have Three-Quarters Cover from every foe (the Hide action's needs).
static func hide_at_start(view: LocationView, e: Encounter) -> void:
	if not view.sneaking or view._foes_alerted:
		return
	_carry_cones(view, e)
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


## The fight is on: the party stops sneaking (V can't be used in a fight, and a party that stayed crouched would still be
## sneaking when it ends). The surprise and the hiding it earned were read just before; the player sneaks again when they
## choose to.
static func end_for_fight(view: LocationView) -> void:
	if not view.sneaking:
		return
	view.sneaking = false
	show_crouch(view)


## The moment a fight opens is still before it: each foe that was waiting in plain view keeps its sight cone for who
## it noticed (the fight's own rules, with no facing, take over from its first turn). A foe that wasn't in view sees
## all round.
static func _carry_cones(view: LocationView, e: Encounter) -> void:
	for c in e.combatants:
		if c.side != &"enemy" or c.has_meta("watch_facing"):
			continue
		for w in view.waiting:
			var foe := w["foe"] as Combatant
			if foe.cell == c.cell and foe.creature.name == c.creature.name:
				set_cone(c, cone_of(w))
				break


## The fight is over: nobody stays hidden out of it (the Invisible condition Hide gave ends).
static func after_fight(view: LocationView, e: Encounter) -> void:
	view._foes_alerted = false
	for c in e.combatants:
		if c.side in [&"party", &"guest"] and (c.hidden or c.creature.has_condition(&"invisible")):
			c.hidden = false
			c.creature.remove_condition(&"invisible", "Hidden")
