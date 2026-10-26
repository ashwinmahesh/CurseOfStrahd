class_name LocationFights
extends RefCounted
## Fights in a location (LocationView): which encounter a trigger starts, Strahd's parley before a final battle,
## fights started by a flag or a random encounter, the fight itself on the same grid (CombatView), a save as each round
## begins and resuming from it, the switch into combat without a jump, and what a won fight leaves.


## Starts any encounter of this location whose trigger matches and whose condition holds. True if one started. (Not a
## fight waiting in plain view that a sneaking party steps into unnoticed: LocationStealth.step_in.)
static func _trigger_encounter(view: LocationView, trigger: String) -> bool:
	for en: Variant in view.loc.get("encounters", []):
		var spec := en as Dictionary
		if str(spec["trigger"]) != trigger:
			continue
		if (view.st.loc_state(view.loc_id)["encounters"] as Dictionary).get(str(spec["id"]), false) is bool \
				and bool((view.st.loc_state(view.loc_id)["encounters"] as Dictionary).get(str(spec["id"]), false)):
			continue
		# A final battle's `when` also needs Strahd waiting in its room (StoryConditions.encounter_when, ADR 0014), and a
		# fight set off by walking in waits out the region's truce (Strahd's dinner guests).
		if not StoryConditions.check(StoryConditions.encounter_when(spec, str(view.loc.get("region", ""))), view.st):
			continue
		if str(spec.get("final_battle", "")) != "":
			return _begin_final_battle(view, str(spec["id"]))
		# A sneaking party that steps into the area of a fight waiting in plain view slips in unless a foe notices it
		# (LocationStealth.step_in); any other step in starts the fight.
		if trigger.begins_with("enter_area:"):
			match LocationStealth.step_in(view, spec):
				"spotted":
					return true
				"slipped":
					return false
		start_encounter(view, str(spec["id"]), spec)
		return true
	return false


## Before a final battle the campaign may parley (CampaignModule.parley_ref, when it's written and hasn't been answered):
## the fight starts once it ends, unless the answer leaves it to the ending. True if the parley or the fight began.
static func _begin_final_battle(view: LocationView, encounter_id: String) -> bool:
	var campaign := Campaign.module()
	var ref := campaign.parley_ref()
	if ref != "":
		var file := DialogueFile.load_key(ref.get_slice(":", 0))
		if campaign.parley_answer(view.st) == "" and file != null and file.nodes.has(ref.get_slice(":", 1)) and view._pending_final == "":
			view._pending_final = encounter_id
			view.dialogue_requested.emit(ref, campaign.parley_speaker())
			return true
	if campaign.parley_allows_fight(view.st):
		return start_encounter(view, encounter_id)
	return false


## Fights triggered by a flag (set by dialogue or a lever): checked after conversations and interactions.
static func check_flag_encounters(view: LocationView) -> bool:
	_after_captives(view)
	# The parley before a final battle has ended: the fight, unless the campaign's price was paid.
	if view._pending_final != "":
		var waiting := view._pending_final
		view._pending_final = ""
		if Campaign.module().parley_allows_fight(view.st):
			return start_encounter(view, waiting)
		return false
	for en: Variant in view.loc.get("encounters", []):
		var spec := en as Dictionary
		var trig := str(spec["trigger"])
		if trig.begins_with("flag:") and _truthy(view.st.get_flag(trig.substr(5))):
			if _trigger_encounter(view, trig):
				return true
	return false


static func _truthy(v: Variant) -> bool:
	return StoryConditions._truthy(v)


## A fight that isn't in the location's data (a random encounter on the road): added for this visit, then started.
static func start_custom_encounter(view: LocationView, spec: Dictionary) -> bool:
	var s := spec.duplicate(true)
	s["trigger"] = "dialogue"
	s["custom"] = true   # not the place's own fight: it brings its own spoils, or none (_spoils)
	if not view.loc.has("encounters"):
		view.loc["encounters"] = []
	(view.loc["encounters"] as Array).append(s)
	remember_custom(view, s)
	return start_encounter(view, str(s["id"]))


## A fight that isn't in the place's data (a road encounter, Strahd's visit, the watch's arrest) is kept in the place's
## saved state until it ends, so its round-start save can pick it up again after a load (QA FN-13: it vanished).
static func remember_custom(view: LocationView, spec: Dictionary) -> void:
	(view.st.loc_state(view.loc_id).get_or_add("custom_fights", {}) as Dictionary)[str(spec["id"])] = spec.duplicate(true)


## A monster's ward in a fight at `location` (ADR 0014): its `ward.hp` taken before its Hit Points (the Heart of
## Sorrow shielding Strahd), in its `region` if it names one, unless the story condition `unless` holds. 0 for none.
static func ward_for(data: Dictionary, location: Dictionary, state: StoryState) -> int:
	var ward := data.get("ward", {}) as Dictionary
	if ward.is_empty() or (str(ward.get("region", "")) != "" and str(ward["region"]) != str(location.get("region", ""))):
		return 0
	return 0 if StoryConditions.check(str(ward.get("unless", "false")), state) else int(ward["hp"])


## The fight happens here, on the same grid: the party where it stands, the monsters where the data puts them.
## Surprise (2024, LocationStealth): a sneaking party surprises each foe that hasn't noticed any of them.
static func start_encounter(view: LocationView, encounter_id: String, chosen: Dictionary = {}) -> bool:
	# Several entries may share an id with different `when` conditions (e.g. a lighter version for a lower-level
	# party): the first whose condition holds is the fight. A trigger that starts its own entry (`chosen`: the oven
	# Offalia's open:hag_oven, Rahadin's failed footlocker) starts that version, not another of the same id.
	var spec := chosen if not chosen.is_empty() else spec_for(view, encounter_id)
	if spec.is_empty() or view.in_combat:
		return false
	if view._pending_final == encounter_id:
		view._pending_final = ""
	view._queue.clear()
	view._on_arrive = Callable()
	LocationCare.stand_up(view, true)   # nobody starts a fight lying where a trap threw them: outside one, standing is free
	view.in_combat = true
	view.fight_id = encounter_id   # (the sanctum's braziers flare for Vosk's: AmberGlow)
	ModeController.force(ModeController.Mode.COMBAT)
	LocationNpcs.clear_for_fight(view)   # the house's people keep out of it (`steps_aside`)
	var grid := _combat_grid(view)
	var sitting := keep_back(view, grid, _starting_squares(view, spec))   # before the encounter, so her square blocks
	var e := Encounter.new(grid, view.dice)
	e.title = str(spec.get("text", ""))
	# Bosses (ADR 0014): the place (a Misty Escape's resting place), the lair's actions, a foe that withdraws.
	e.location_id = view.loc_id
	for place in Campaign.module().treasure_spots(view.loc):
		e.places.append(place)
	if str(spec.get("final_battle", "")) != "":
		e.places.append(str(spec["final_battle"]))
	e.lair = bool(spec.get("lair", false))
	# Party members pass through each other's spaces unless the place or the fight says otherwise.
	e.allies_block = bool(spec.get("allies_block", view.loc.get("allies_block", false)))
	e.outdoors = bool(view.loc["map"].get("outdoors", false))
	# The weather over a fight in the open (F12): fog and storms obscure the field, storms put out flames and feed
	# Call Lightning.
	if e.outdoors:
		e.weather_id = Weather.now(view.st, view.loc_id)
		e.weather = Weather.kind(e.weather_id)
	e.legendary.set_withdraw(spec.get("withdraw", {}))
	if str(spec.get("final_battle", "")) != "":
		Campaign.module().final_battle_begun(view.st)
	var party_cbs: Array[Combatant] = []
	for m in view.members:
		if m.creature.dead:
			continue
		party_cbs.append(e.add(m.creature, &"party", m.cell))
	for g in view.guest_members:
		# A familiar following the party joins as its caster's summon (EncounterSetup.bring_familiars below), and a guest
		# who keeps out of fights isn't in the encounter at all (sits_out, keep_back).
		if not g.creature.dead and not LocationParty.is_follower(g) and not sits_out(view, g):
			e.add(g.creature, &"guest", g.cell).controller = &"player"
	for mo: Dictionary in monsters_for(view, spec):
		e.add(mo["creature"] as Monster, mo["side"] as StringName, mo["cell"] as Vector2i)
	# The playthrough's difficulty: enemy Hit Points, what foes carry, how they fight (combat/difficulty.gd).
	Difficulty.of_options(view.st.options).prepare(e)
	EncounterSetup.bring_familiars(e, party_cbs)
	EncounterSetup.bring_steeds(e, party_cbs)
	Wards.bring_circle(e, view.st, view.loc_id)   # a Magic Circle cast here within the hour
	FieldCasting.bring_risen(e, view.st)   # Animate Dead's and Create Undead's dead, for their day
	_light_the_fight(view, e)
	_ward_the_fight(view, e)
	BattleScenery.for_location(view, e)   # doors, furniture and chandeliers that can be broken (F5)
	LocationTraps.into_fight(view, e)   # traps that haven't gone off go off under whoever steps on them
	var surprised: Array[String] = []
	var who := str(spec.get("surprise", ""))
	for c in e.combatants:
		if (who == "party" and c.side == &"party") or (who == "enemies" and c.side == &"enemy"):
			surprised.append(c.id)
	# Who the party's sneaking catches unawares, and who starts the fight hidden (LocationStealth, F7).
	if who == "":
		surprised.append_array(LocationStealth.surprised_at_start(view, e))
	LocationStealth.hide_at_start(view, e)
	LocationStealth.end_for_fight(view)   # the fight ends the sneaking, now that its surprise and hiding are read
	LocationPlan.stop(view)
	(view.st.loc_state(view.loc_id)["encounters"] as Dictionary)[encounter_id] = "started"
	var ctokens := _fight_tokens(view, e)
	LocationStealth.clear_waiting(view, encounter_id)
	view.combat_view = CombatView.new()
	view.combat_view.input_locked = view.input_locked
	view.combat_view.narrator = view.narrator
	view.combat_view.story = view.st
	view.add_child(view.combat_view)
	var opened := view._say("combat:start")
	for key in Campaign.module().fight_start_keys():
		opened = view._say(key) or opened   # the campaign's own (the Sunsword, while carried)
	_say_keeps_back(view, sitting, opened)   # last: it waits a beat after whatever was just said, so neither is replaced
	# The picture streaks toward the party and drains for a beat as the fight breaks out (Visual Polish Plan 3).
	if ScreenPulse.on():
		ScreenPulse.play(view, "engage", view.rig.global_position)
	_run_combat(view, encounter_id, spec, e, ctokens, surprised)
	return true


# --- Guests who keep out of fights (docs/contracts/campaign.md) ---------------------------------------------------------

## How far (in feet, walking) a guest who keeps out of a fight steps to get off a square the fight needs.
const ASIDE_FT := 15
## How long (seconds) the Narrator waits to speak of her after the fight's own opening line, which the box would replace.
static var keeps_back_delay := 7.0


## Whether guest `g` keeps out of fights (her NPC's `guest_fights: false`: Ireena, StoryState.guest_fights). She isn't in
## the encounter: no turn, nobody can target her and no area spell of either side catches her. Her figure stays on the
## board as a bystander (keep_back). A familiar or steed following the party is never one.
static func sits_out(view: LocationView, g: Combatant) -> bool:
	if LocationParty.is_follower(g):
		return false
	var i := view.st.guests.find(g.creature)
	return i >= 0 and not StoryState.guest_fights(view.st.guest_ids[i])


## The guests who sit this fight out, alive (the fallen are carried home and the dead are gone): with `e`, a fight already
## going, not one that has a combatant in it (a round-start save made before she kept out has her in it, and she fights
## that one).
static func sitting_out(view: LocationView, e: Encounter = null) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for g in view.guest_members:
		if not g.creature.dead and sits_out(view, g) and (e == null or e.get_c(g.id) == null):
			out.append(g)
	return out


## Where someone stands as fight `spec` begins: {taken: squares with someone on them, foes: where the foes start}. The
## living party's squares (they share squares outside a fight), the foes' and their footprints, the bystanders' (the
## house's people who stay on the board).
static func _starting_squares(view: LocationView, spec: Dictionary) -> Dictionary:
	var taken := _bystander_squares(view)
	for m in view.members:
		if not m.creature.dead:
			taken[m.cell] = true
	var foes: Array[Vector2i] = []
	for mo: Variant in spec.get("monsters", []):
		var md := mo as Dictionary
		var at := LocationView._cell(md["cell"])
		var size := CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(str(md["monster"])).get("size", "medium"))))
		foes.append(at)
		for f in CombatGrid.footprint(at, size):
			taken[f] = true
	return {"taken": taken, "foes": foes}


## The same for an encounter that is already going (a fight picked up from a save): every combatant's footprint.
static func _squares_in(view: LocationView, e: Encounter) -> Dictionary:
	var taken := _bystander_squares(view)
	var foes: Array[Vector2i] = []
	for c in e.combatants:
		for f in CombatGrid.footprint(c.cell, c.size_cells):
			taken[f] = true
		if c.side == &"enemy" and c.is_alive():
			foes.append(c.cell)
	return {"taken": taken, "foes": foes}


static func _bystander_squares(view: LocationView) -> Dictionary:
	var taken := {}
	for npc: String in view.npc_tokens:
		var tok := view.npc_tokens[npc] as CombatToken
		if tok.visible:
			taken[tok.combatant.cell] = true
	return taken


## The guests who keep out of this fight stay on the board as bystanders: each steps off a square the fight puts someone
## on (`squares`, from _starting_squares or _squares_in) to the nearest open one, farther from the foes where there is a
## choice, and her square blocks on `grid` as any bystander's does (LOW), movement and shots both. With nowhere to step
## she stays, and her square blocks only if nobody stands on it. Returns who sits out, for the Narrator. `e` is the fight
## when it is already going (resume_encounter).
static func keep_back(view: LocationView, grid: CombatGrid, squares: Dictionary, e: Encounter = null) -> Array[Combatant]:
	var sitting := sitting_out(view, e)
	var taken := squares["taken"] as Dictionary
	for g in sitting:
		var at := g.cell
		if taken.has(at) or grid.is_solid(at):
			at = _aside(grid, at, taken, squares["foes"] as Array[Vector2i])
		if at != g.cell:
			g.cell = at
			var tok := view.tokens.get(g.id, null) as CombatToken
			if tok != null:
				view.create_tween().tween_property(tok, "position", view.board.cell_center(at), 0.25)
		if not taken.has(at):
			grid.set_flag(at, CombatGrid.LOW, true)
			taken[at] = true
	return sitting


## The open square within ASIDE_FT of `from` (walking) that nobody stands on and is farthest from the foes (capped at six
## squares), the nearer to `from` on a tie; `from` if there is none.
static func _aside(grid: CombatGrid, from: Vector2i, taken: Dictionary, foes: Array[Vector2i]) -> Vector2i:
	var reach := grid.reachable(from, 1, ASIDE_FT, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false)
	var best := from
	var best_score := -INF
	for c: Vector2i in reach:
		if taken.has(c) or not grid.in_bounds(c) or grid.is_solid(c):
			continue
		var clear := 6
		for f in foes:
			clear = mini(clear, maxi(absi(c.x - f.x), absi(c.y - f.y)))
		var score := float(clear) * 10.0 - float((reach[c] as Dictionary)["cost"]) / float(CombatGrid.FEET)
		if score > best_score:
			best_score = score
			best = c
	return best


## Whether `m`, one of the view's figures, stays on the board through fight `e`: a guest who keeps out of fights and has no
## combatant in it (sitting_out).
static func _stays_on_board(view: LocationView, e: Encounter, m: Combatant) -> bool:
	return e.get_c(m.id) == null and sits_out(view, m)


## The Narrator's word on a guest keeping out of the fight that is beginning: her first one, once
## (combat:keeps_back:<npc>:first), then now and then (combat:keeps_back:<npc>, which holds off between fights). When the
## fight's own opening line was just said (`after_a_line`) it follows a beat later, since the box shows one line at a time.
static func _say_keeps_back(view: LocationView, sitting: Array[Combatant], after_a_line: bool) -> void:
	if view.narrator == null:
		return
	var lead := view.leader()
	var actor := lead.creature as Character if lead != null else null
	for g in sitting:
		var npc := view.st.guest_ids[view.st.guests.find(g.creature)]
		for key: String in ["combat:keeps_back:%s:first" % npc, "combat:keeps_back:%s" % npc]:
			var text := view.narrator.line(key, view.st, actor)
			if text == "":
				continue
			if after_a_line and keeps_back_delay > 0.0:
				var wait := view.create_tween()
				wait.tween_interval(keeps_back_delay)
				wait.tween_callback(func() -> void:
					if view.in_combat:
						view.narration.emit(text))
			else:
				view.narration.emit(text)
			return


## The encounter's monsters as the fight places them: [{creature: Monster, side, cell}], with this fight's tuned
## Hit Points, a boss's ward, and numbers on repeated names ("Wolf 2"). Foes waiting in plain view before the fight
## (LocationStealth) are built the same way.
static func monsters_for(view: LocationView, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts := {}
	for mo: Variant in spec["monsters"]:
		var mid := str((mo as Dictionary)["monster"])
		counts[mid] = int(counts.get(mid, 0)) + 1
	var numbered := {}
	for mo: Variant in spec["monsters"]:
		var md := mo as Dictionary
		var data := Compendium.shared().monster_data(str(md["monster"]))
		if md.has("art"):
			data = data.duplicate()
			data["art"] = str(md["art"])   # a named foe drawn as themselves (Vasilka, not any flesh golem)
		if md.has("states"):
			data = with_states(data, md["states"] as Array)
		var mon := Monster.from_data(data)
		if md.has("lying"):
			mon.set_meta(&"lying", md["lying"])   # lies there until its fight opens (LyingFigures)
		if md.has("steps_down"):
			mon.set_meta(&"steps_down", md["steps_down"])   # a person of the place stepping down into this foe (StepDown)
		if md.has("hp"):
			# A tuned stat block for this fight (docs/contracts/locations.md).
			mon.hp_max_base = int(md["hp"])
			mon.hp = mon.max_hp()
		mon.ward_hp = ward_for(data, view.loc, view.st)
		if md.has("name"):
			mon.name = str(md["name"])
		elif int(counts[str(md["monster"])]) > 1:
			numbered[str(md["monster"])] = int(numbered.get(str(md["monster"]), 0)) + 1
			mon.name = "%s %d" % [mon.name, numbered[str(md["monster"])]]
		out.append({"creature": mon, "side": StringName(str(md.get("side", "enemy"))), "cell": LocationView._cell(md["cell"])})
	return out


## Stat block `data` in the `states` this fight puts it in: each one of the block's own `states` (by id) joins its
## traits for the fight (Sarkhaza chained or grave-salted; docs/contracts/locations.md), and may hold its Multiattack to
## `multiattack` attacks and its legendary actions to `legendary_uses` a round.
static func with_states(data: Dictionary, states: Array) -> Dictionary:
	var out := data.duplicate()
	var traits := (data.get("traits", []) as Array).duplicate()
	var defs := data.get("states", {}) as Dictionary
	for id: Variant in states:
		if not defs.has(str(id)):
			push_error("%s has no state %s" % [data.get("id", "?"), id])
			continue
		var st := defs[str(id)] as Dictionary
		traits.append(st)
		if st.has("multiattack"):
			out["actions"] = _fewer_attacks(out.get("actions", []) as Array, int(st["multiattack"]))
		if st.has("legendary_uses") and out.has("legendary_actions"):
			var la := (out["legendary_actions"] as Dictionary).duplicate()
			for k: String in ["per_round", "in_lair"]:
				if la.has(k):
					la[k] = mini(int(la[k]), int(st["legendary_uses"]))
			out["legendary_actions"] = la
	out["traits"] = traits
	return out


## `actions` with the Multiattack cut to its first `n` attacks.
static func _fewer_attacks(actions: Array, n: int) -> Array:
	var out: Array = []
	for a: Variant in actions:
		var act := a as Dictionary
		if str(act.get("kind", "")) != "multiattack":
			out.append(act)
			continue
		var left := n
		var kept: Array = []
		for entry: Variant in act.get("multiattack", []):
			if left <= 0:
				break
			var d := (entry as Dictionary).duplicate()
			d["count"] = mini(int(d["count"]), left)
			left -= int(d["count"])
			kept.append(d)
		var cut := act.duplicate()
		cut["multiattack"] = kept
		out.append(cut)
	return out


## The encounter entry a fight with `encounter_id` uses now: of the entries sharing the id, the first whose `when`
## holds (else the last). {} if there's none.
static func spec_for(view: LocationView, encounter_id: String) -> Dictionary:
	var spec := {}
	for en: Variant in view.loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id and (spec.is_empty() or not StoryConditions.check(StoryConditions.encounter_when(spec), view.st)):
			spec = en as Dictionary
	return spec


static func _run_combat(view: LocationView, encounter_id: String, spec: Dictionary, e: Encounter, ctokens: Dictionary, surprised: Array[String]) -> void:
	e.keep_round_snapshots = true   # the round-start save, taken as each round begins (_save_round)
	Bestiary.before_fight(view.st, e)   # creatures met, and those already studied show their defenses (U8)
	view.combat_view.finished.connect(func(outcome: String) -> void: _end_encounter(view, encounter_id, spec, e, ctokens, outcome))
	view.combat_view.round_started.connect(func(_r: int) -> void: _save_round(view, encounter_id, e))
	view.combat_started.emit(view.combat_view)
	view.combat_view.begin(e, view.board, view.rig, ctokens, surprised)


## Saves the fight as the round begins: the party (in the story), the location, and the encounter's state.
static func _save_round(view: LocationView, encounter_id: String, e: Encounter) -> void:
	if e.state != Encounter.State.ACTIVE:
		return
	view._save_positions()
	# The fight as its round began, before the lair or the first turn acted (the view hears of the round after).
	var data := e.round_snapshot if int(e.round_snapshot.get("round", -1)) == e.round_no else EncounterSnapshot.capture(e)
	data = _without_bystander_guests(view, e, data)
	GameState.combat_snapshot = {"location": view.loc_id, "encounter": encounter_id, "data": data}
	SaveSystem.save_round()


## `data`, a fight's saved state, without the squares of the guests who keep out of it (keep_back makes them LOW): the
## save holds the ground as it was, and the fight picked up again steps her aside afresh (resume_encounter), since a guest
## is put behind the leader at a load and not where she stood. The same `data` if none of them is on the board.
static func _without_bystander_guests(view: LocationView, e: Encounter, data: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	for g in view.guest_members:
		if _stays_on_board(view, e, g):
			cells.append(g.cell)
	if cells.is_empty():
		return data
	var out := data.duplicate(true)
	var rows := out["rows"] as Array
	for c in cells:
		var row := str(rows[c.y])
		if c.x < row.length() and row[c.x] == "=":
			rows[c.y] = row.substr(0, c.x) + "." + row.substr(c.x + 1)
	return out


## Picks a saved fight up again at the start of its round (after loading a round-start save).
static func resume_encounter(view: LocationView, snapshot: Dictionary) -> bool:
	var encounter_id := str(snapshot.get("encounter", ""))
	var spec := {}
	for en: Variant in view.loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id:
			spec = en as Dictionary
	# A fight the place's data doesn't have comes back from the place's saved state (remember_custom).
	var kept := view.st.loc_state(view.loc_id).get("custom_fights", {}) as Dictionary
	if spec.is_empty() and kept.has(encounter_id):
		spec = (kept[encounter_id] as Dictionary).duplicate(true)
		(view.loc.get_or_add("encounters", []) as Array).append(spec)
	if spec.is_empty() or view.in_combat:
		return false
	if not LocationParty.snapshot_fits(view, snapshot):
		# The place was edited since the save (the load guard, Dungeon Expansion Plan E1): the party stood on squares that
		# are closed now, so the fight begins again from its own squares instead of resuming on the old layout.
		GameState.combat_snapshot = {}
		return start_encounter(view, encounter_id)
	view.in_combat = true
	view.fight_id = encounter_id   # (the sanctum's braziers flare for Vosk's: AmberGlow)
	ModeController.force(ModeController.Mode.COMBAT)
	var e := EncounterSnapshot.restore(snapshot["data"] as Dictionary, view.dice, view.st.party)
	keep_back(view, e.grid, _squares_in(view, e), e)
	# The people who stepped down into this fight (StepDown) are named by its entry; a saved fight remembers only the foes.
	for md: Variant in spec.get("monsters", []):
		if (md as Dictionary).has("steps_down"):
			for c in e.combatants:
				if c.side == &"enemy" and c.name() == str((md as Dictionary).get("name", "")):
					c.creature.set_meta(&"steps_down", (md as Dictionary)["steps_down"])
	var ctokens := _fight_tokens(view, e, false)
	view.combat_view = CombatView.new()
	view.combat_view.input_locked = view.input_locked
	view.combat_view.narrator = view.narrator
	view.combat_view.story = view.st
	view.add_child(view.combat_view)
	var none: Array[String] = []
	_run_combat(view, encounter_id, spec, e, ctokens, none)
	return true


## The fight's tokens (combatant id -> CombatToken), made so the switch into combat doesn't jump (owner 2026-10-06):
## the party and guests keep the figures they walked in with, mid-step, facing and lantern and all, and turn to the
## nearest foe as their step lands; the foes fade in where they stand, facing the party.
static func _fight_tokens(view: LocationView, e: Encounter, fresh: bool = true) -> Dictionary:
	var ctokens := {}
	var ours: Array[CombatToken] = []
	var party_mid := Vector3.ZERO
	for c in e.combatants:
		for m: Combatant in view.members + view.guest_members:
			var tok := view.tokens[m.id] as CombatToken
			if m.creature == c.creature and not ours.has(tok):
				tok.combatant = c
				tok.refresh()
				var spot := view.board.cell_center(c.cell, c.size_cells)
				if tok.position.distance_to(spot) > 1.0:
					tok.position = spot   # a fight resumed from a save: they stand where the round began
				ctokens[c.id] = tok
				ours.append(tok)
				party_mid += spot
	var aside: Array[CombatToken] = []   # guests who keep out of the fight: still on the board, watching it
	for m: Combatant in view.members + view.guest_members:
		if not ours.has(view.tokens[m.id] as CombatToken):
			if _stays_on_board(view, e, m):
				aside.append(view.tokens[m.id] as CombatToken)
			else:
				(view.tokens[m.id] as Node3D).visible = false
	party_mid /= maxf(1.0, float(ours.size()))
	var foes: Array[CombatToken] = []
	var standing: Array[CombatToken] = []
	var striding: Array[CombatToken] = []
	for c in e.combatants:
		if ctokens.has(c.id):
			continue
		# A foe the party could already see waiting there keeps its figure (LocationStealth).
		var t := LocationStealth.claim_token(view, c)
		if t != null:
			ctokens[c.id] = t
			standing.append(t)
			t.get_up(0.3)   # one lying in plain view (curled in the straw) gets up
			continue
		t = _combat_token(c)
		t.position = view.board.cell_center(c.cell, c.size_cells)
		var look := party_mid - t.position
		t.face(Vector2(look.x, look.z), false)
		view.add_child(t)
		if LyingFigures.of(c.creature) != null:
			LyingFigures.lay(view, t, LyingFigures.of(c.creature), c.cell)
		ctokens[c.id] = t
		# A person of the place who is this foe steps down off where they stood (StepDown).
		if _step_down(view, t, c, fresh):
			striding.append(t)
			continue
		# A person the conversation showed who turns out to be this (Offalia a hag, Vosk unmasked) changes where it stands.
		var reveal := _reveal_of(view, c)
		if not reveal.is_empty() and SpellFx.enabled:
			_reveal(view, t, reveal)
			standing.append(t)
			continue
		foes.append(t)
	foes.sort_custom(func(a: CombatToken, b: CombatToken) -> bool: return a.position.distance_to(party_mid) < b.position.distance_to(party_mid))
	for i in foes.size():
		var delay := 0.1 + 0.5 * i / maxf(1.0, foes.size() - 1.0)
		foes[i].emerge(delay, 0.6)
		foes[i].get_up(delay + 0.5)   # one lying there gets up as it comes into view (the dead on their pallets)
	var turn := view.create_tween()
	turn.tween_interval(LocationView.STEP_TIME + 0.05)
	var every_foe: Array[CombatToken] = foes.duplicate()
	every_foe.append_array(standing)
	every_foe.append_array(striding)
	turn.tween_callback(func() -> void:
		_face_nearest_foe(ours, every_foe)
		_face_nearest_foe(aside, every_foe)
		_face_nearest_foe(standing, ours))
	return ctokens


## A foe whose entry says `steps_down: {npc}` is a person of the place (the Amber Sentinel on its dais): they leave the board as
## the fight begins, and the foe's figure takes their place and strides to its start square (StepDown; `fresh`: not a fight
## picked up from a save, where it is simply there). False for any other foe.
static func _step_down(view: LocationView, t: CombatToken, c: Combatant, fresh: bool) -> bool:
	if not c.creature.has_meta(&"steps_down"):
		return false
	var npc := str((c.creature.get_meta(&"steps_down") as Dictionary).get("npc", ""))
	var person := view.npc_tokens.get(npc) as CombatToken
	LocationNpcs.hide_npc(view, npc)   # (whichever way the fight began: a conversation, or a walk onto the ledge)
	if person == null or not fresh:
		return false
	StepDown.take_place(t, person.position, func() -> void: view.stepping_down.emit(npc, t))
	return true


## Each of `ours` stops walking and turns to the nearest of `foes`.
static func _face_nearest_foe(ours: Array[CombatToken], foes: Array[CombatToken]) -> void:
	for tok in ours:
		if not is_instance_valid(tok):
			continue
		var best := Vector3.ZERO
		var best_d := INF
		for f in foes:
			if is_instance_valid(f) and f.combatant.is_alive() and tok.combatant.hostile_to(f.combatant):
				var d := tok.position.distance_to(f.position)
				if d < best_d:
					best_d = d
					best = f.position - tok.position
		tok.face(Vector2(best.x, best.z), false)


## The look of a person who has just turned out to be foe `c` (a stat block's `reveal`): {art: the figure they had, kind:
## how the change looks (FxShapeshift)}, or {} when `c` isn't someone who stepped aside from the conversation that led
## here, in a different figure. Each person changes once.
static func _reveal_of(view: LocationView, c: Combatant) -> Dictionary:
	var kind := str((c.creature as Monster).data.get("reveal", "")) if c.creature is Monster else ""
	if kind == "":
		return {}
	for aside: Dictionary in view._stepped_aside:
		var art := str(aside["art"])
		if _same_person(str(aside["name"]), c.name()) and art != CombatToken.art_id(c) and DirectionalSprite.frames_for(art) != null:
			view._stepped_aside.erase(aside)
			return {"art": art, "kind": kind}
	return {}


## Whether a foe's name is an NPC's ("Vosk, unmasked" is Vosk, "The Abbot" is the Abbot).
static func _same_person(npc_name: String, foe_name: String) -> bool:
	return Legendary.same_person(npc_name, foe_name)


## `t`, a foe that was a person a moment ago, stands there in `reveal`'s figure and changes into itself: the same effect
## and sound as any change of shape (FxShapeshift), played on a stand-in wearing the person's figure, then `t` comes
## into view in a flash. Doesn't wait: the fight's opening plays meanwhile.
static func _reveal(view: LocationView, t: CombatToken, reveal: Dictionary) -> void:
	var kind := str(reveal["kind"])
	var ghost := CombatToken.create(t.combatant, str(reveal["art"]))
	ghost.position = t.position
	if ghost.sprite != null and t.sprite != null:
		ghost.sprite.facing = t.sprite.facing
	view.add_child(ghost)
	t.visible = false
	var fx := SpellFx.new()
	view.add_child(fx)
	fx.shape_gather(ghost, kind)
	# On a tween of the effect's own, so a scene that goes away mid-change takes it along (a timer's lambda that captured
	# the freed nodes would be called all the same, with an error).
	var tw := fx.create_tween()
	tw.tween_interval(FxShapeshift.GATHER * GameSettings.combat_pace())
	tw.tween_callback(func() -> void:
		ghost.queue_free()
		t.visible = true
		fx.shape_settle(t, kind))
	tw.tween_interval(3.0)
	tw.tween_callback(fx.queue_free)


## A fight's token: guests wear their NPC sprite rather than their stat block's.
static func _combat_token(c: Combatant) -> CombatToken:
	if c.side == &"guest":
		var npc := Compendium.shared().get_entry("npcs", c.id.trim_prefix("guest_"))
		if not npc.is_empty():
			return CombatToken.create(c, str(npc.get("sprite", npc["id"])))
	return CombatToken.create(c)


## The fight sees what the party sees (vision rules live in the encounter): outdoors the hour sets the light (an
## overcast Barovian day is bright but not true sunlight; night is dark), indoors the map's light does; the
## location's lamps and candles, and the party's lantern when it's lit, are light sources on the grid.
static func _light_the_fight(view: LocationView, e: Encounter) -> void:
	if bool(view.loc["map"].get("outdoors", false)):
		e.ambient_light = {"day": "bright", "dusk": "dim", "dawn": "dim"}.get(view.time_phase(), "dark") as String
	else:
		e.ambient_light = str(view.loc["map"].get("light", "dim"))
	e.sunlit = false
	for l: Variant in view.loc.get("lights", []):
		var li := l as Dictionary
		if bool(li.get("visual", false)):
			continue   # only painted: a mood or a glow, no light to see by
		var o := FieldObject.new(FieldObject.Kind.ZONE, "", str(li.get("kind", "light")))
		o.cell = LocationView._cell(li["cell"])
		o.rules = {"light": {"bright": int(li.get("bright_ft", 10)), "dim": int(li.get("dim_ft", 10)),
			"sunlight": bool(li.get("sunlight", false))}}
		e.spells.zones.objects.append(o)
	if view.lantern != null and view.lantern.visible and not view.members.is_empty():
		var lo := FieldObject.new(FieldObject.Kind.ZONE, "", "lantern")
		lo.caster_id = view.leader().id
		lo.rules = {"light": {"bright": 30, "dim": 30}, "light_on": "caster"}
		e.spells.zones.objects.append(lo)


## A place's antimagic areas (`antimagic` on an area, docs/contracts/locations.md) are Antimagic Field zones for the length of a
## fight there: over the area's open squares, the spell's own rules (no spell is cast on them, magic items go quiet), with no
## caster and no end. Van Richten's Tower's ring, five feet round its walls (Dungeon Expansion Plan V1).
static func _ward_the_fight(view: LocationView, e: Encounter) -> void:
	for area in Wards.antimagic_areas(view.loc):
		var c0 := LocationView._cell((area["cells"] as Array)[0])
		var c1 := LocationView._cell((area["cells"] as Array)[1])
		var o := FieldObject.new(FieldObject.Kind.ZONE, "antimagic_field", str(area.get("name", "")))
		for x in range(mini(c0.x, c1.x), maxi(c0.x, c1.x) + 1):
			for y in range(mini(c0.y, c1.y), maxi(c0.y, c1.y) + 1):
				var cell := Vector2i(x, y)
				if e.grid.in_bounds(cell) and not e.grid.has_flag(cell, CombatGrid.WALL) and not e.grid.has_flag(cell, CombatGrid.VOID):
					o.cells.append(cell)
		if o.cells.is_empty():
			continue
		o.cell = o.cells[0]
		e.spells.zones.objects.append(o)


## The location's grid as it stands now (closed doors are walls; NPC squares are blocked).
static func _combat_grid(view: LocationView) -> CombatGrid:
	var g := LocationView.grid_for(view.loc)
	g.drop_ft = int(view.loc["map"].get("drop_ft", 0))
	g.ceiling_ft = int(view.loc["map"].get("ceiling_ft", 0 if bool(view.loc["map"].get("outdoors", false)) else 20))
	var party_at := {}
	for m in view.members + view.guest_members:
		party_at[m.cell] = true
	# A shut door is a wall, unless one of the party stands in its doorway (holding it open: BattleScenery.for_location).
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		var cell := LocationView._cell(door["cell"])
		g.set_flag(cell, CombatGrid.WALL, LocationLocks._door_state(view, str(door["id"])) != LocationView.DOOR_OPEN and not party_at.has(cell))
	# A bystander's square blocks in the fight, unless one of the party stands in it (nobody blocks outside fights).
	for npc: String in view.npc_tokens:
		var at := (view.npc_tokens[npc] as CombatToken).combatant.cell
		if (view.npc_tokens[npc] as CombatToken).visible and not party_at.has(at):
			g.set_flag(at, CombatGrid.LOW, true)
	return g


## A foe's token when the fight is over: one still up fades away and frees itself at the end of its half second, which is
## after the fight's view (`playing`) has freed itself (a third of a second after it closes); a fallen one is hidden at
## once and freed when the view has gone. That view can still be mid-beat on any of them: the story takes a fight back, and a
## story bot plays the whole fight on the encounter and ends it, while the view plays; an attack's lunge resumes with
## the blow's two tokens, and a fallen one freed under it was a script error (batch 291's logcheck, test_phase4_exit's
## Vallaki fight). The beat stops with its view.
static func _drop_token(tok: CombatToken, playing: CombatView) -> void:
	if tok.visible and tok.combatant.is_alive():
		tok.fade_away(0.5)
		return
	tok.hide()
	if playing != null and is_instance_valid(playing) and playing.is_inside_tree():
		playing.tree_exited.connect(tok.queue_free, CONNECT_ONE_SHOT)
	else:
		tok.queue_free()


static func _end_encounter(view: LocationView, encounter_id: String, spec: Dictionary, e: Encounter, ctokens: Dictionary, outcome: String) -> void:
	view.last_encounter = spec
	Bestiary.after_fight(view.st, e)   # who fell and what was studied, for the journal's Bestiary (U8)
	for c in e.combatants:
		if c.side in [&"party", &"guest"]:
			for m: Combatant in view.members + view.guest_members:
				# One that fell out of the fight (a chasm) climbs back to where it stood before it.
				if m.creature == c.creature and not c.has_meta("left_fight"):
					m.cell = c.cell
		elif c.creature.dead and not e.legendary.departed.has(c.id):
			var stain := LocationBuilder._box(view, Vector3(0.6, 0.02, 0.4), view.board.cell_center(c.cell, c.size_cells) + Vector3(0, 0.015, 0), "blood_deep")
			stain.name = "Remains"
	# The party's own figures go back to exploring where they stand; whoever else is still up fades away.
	var ours := {}
	for m: Combatant in view.members + view.guest_members:
		ours[view.tokens[m.id]] = true
	for id: String in ctokens:
		var tok := ctokens[id] as CombatToken
		if ours.has(tok):
			continue
		_drop_token(tok, view.combat_view)
	if view.combat_view != null:
		view.combat_view.close_softly()
		view.combat_view = null
	view.in_combat = false
	view.fight_id = ""
	GameState.combat_snapshot = {}
	(view.st.loc_state(view.loc_id).get("custom_fights", {}) as Dictionary).erase(encounter_id)
	ModeController.force(ModeController.Mode.EXPLORATION)
	view.rig.follow = view.tokens[view.leader().id] as Node3D
	view.st.advance_minutes(1)
	# With the fight over, nobody is still held by a dead grappler, and the fallen-over get up; nobody stays held by a
	# web, a net or a grapple, and what lasted only rounds is gone (EncounterSetup.clear_fight_effects).
	for m in view.members + view.guest_members:
		EncounterSetup.clear_fight_effects(m.creature)
	LocationStealth.after_fight(view, e)
	BattleScenery.after_fight(view, e)   # broken doors stay open; what else broke stays broken this visit
	LocationTraps.after_fight(view, e)   # traps sprung in the fight are spent
	LocationPlan.resume(view)
	for m: Combatant in view.members + view.guest_members:
		var tok := view.tokens[m.id] as CombatToken
		tok.combatant = m
		tok.set_active(false)
		tok.set_highlight(false)
		tok.scale = Vector3.ONE
		tok.visible = true
		tok.refresh()
		view.create_tween().tween_property(tok, "position", view.board.cell_center(m.cell), 0.25)
	# A familiar lost in the fight (or sent away) leaves the line; one still with its caster walks on.
	LocationParty.refresh_familiars(view)
	if outcome == "victory":
		(view.st.loc_state(view.loc_id)["encounters"] as Dictionary)[encounter_id] = true
		# XP levelling: the foes overcome are worth XP, a road meeting, a night at camp or Strahd's visit (custom) every time
		# but lost over the ceiling (story/xp.gd).
		var earned := Xp.fight(view.st, e, encounter_id, bool(spec.get("custom", false)))
		if earned != "":
			view.toast.emit(earned)
		if spec.has("flag"):
			view.st.set_flag(str(spec["flag"]))
		if spec.has("quest"):
			var q := spec["quest"] as Dictionary
			if view.st.set_quest_stage(str(q["id"]), str(q["stage"])):
				view.toast.emit(view.st.quest_notice())   # "Quest failed: X", "Quest complete: X", else "Journal updated: X"
		# Out of combat, the fallen are stabilized by their friends (a minute later) at 0 HP; nobody stays dying.
		for m in view.members:
			var cr := m.creature
			if cr.hp <= 0 and not cr.dead and not cr.stable:
				cr.stabilize()
		view._say("combat:victory")
		for key in Campaign.module().fight_victory_keys():
			view._say(key)
		view._fight_bark_due = true   # a guest may have a word as the party walks on (LocationWalk._guest_chatter)
	# A guest who fell isn't left for dead: carried home to heal, or patched up if they can't leave, and the player is
	# told (StoryState.see_to_fallen_guests; Ashwin, 2026-10-12: Adrian's figure walked on after he fell).
	var carried := view.st.see_to_fallen_guests()
	if not carried.is_empty():
		view.place_guests()
		for who in carried:
			view.toast.emit("%s is badly hurt and goes home to heal. You can ask them along again where you met." % who)
	# A guest who came for one fight only has had it (StoryState.release_one_fight_guests: Sir Klutz's ghost).
	var released := view.st.release_one_fight_guests()
	if not released.is_empty():
		view.place_guests()
		for who in released:
			view.toast.emit("%s fades from the party: the one battle they stayed for is over." % who)
	# What the fight hands back to the story, whatever the outcome (ADR 0014): Misty Escape's flag, a withdrawal's
	# flag, Strahd destroyed and his quest's stage.
	for f: String in e.legendary.story_flags:
		view.st.set_flag(f, e.legendary.story_flags[f])
	for qid: String in e.legendary.story_quests:
		view.st.set_quest_stage(qid, str(e.legendary.story_quests[qid]))
	# F13: cutting down a foe that surrendered costs the companions' regard (story/captives.gd).
	if Captives.slain_after_surrender(e) > 0:
		var said := Approval.react(view.st, Captives.CRUELTY, Captives.CRUELTY_WHY)
		if said != "":
			view.toast.emit(said)
	# Captives are dealt with in a conversation first; the spoils (and a journey that was under way) wait for it.
	var captives := Captives.taken(e)
	var talk := Captives.conversation(captives, encounter_id)
	if talk != "":
		_after_talk = {"view": view.get_instance_id(), "id": encounter_id, "spec": spec, "loot": not e.legendary.no_loot(),
			"carried": _left_behind(e), "journey": view.st.travel_resume}
		view.st.travel_resume = {}
	view._save_positions()
	view.combat_ended.emit(outcome)
	# A foe that withdrew or fled as mist leaves nothing behind (a Tarokka treasure here is still found).
	if talk != "":
		Captives.forget_spent(view.st)
		view.dialogue_requested.emit(talk, "")
	elif outcome == "victory":
		_spoils(view, encounter_id, spec, not e.legendary.no_loot(), _left_behind(e))


## What the fallen foes still carried, and their weapons left lying on the ground (GroundItems).
static func _left_behind(e: Encounter) -> Array[Dictionary]:
	var left := AiTactics.leftovers(e)
	left.append_array(e.ground.spoils)
	return left


## A won fight's spoils and journey, held while its captives are dealt with (F13): {view (instance id), id, spec,
## loot, carried, journey}. check_flag_encounters, which runs as a conversation ends, hands them on.
static var _after_talk: Dictionary = {}


## After the captives' conversation: the fight's spoils, and the journey picks up again.
static func _after_captives(view: LocationView) -> void:
	if _after_talk.is_empty() or int(_after_talk["view"]) != view.get_instance_id():
		return
	var t := _after_talk
	_after_talk = {}
	if not (t["journey"] as Dictionary).is_empty():
		view.st.travel_resume = t["journey"] as Dictionary
	var carried: Array[Dictionary] = []
	carried.assign(t["carried"] as Array)
	_spoils(view, str(t["id"]), t["spec"] as Dictionary, bool(t["loot"]), carried)


## What a won fight leaves (the encounter's `loot`, what the fallen foes still carried, and a Tarokka treasure if this
## fight is a treasure spot), in the loot window like a chest. Leftovers stay as "fight:<id>".
static func _spoils(view: LocationView, encounter_id: String, spec: Dictionary, with_loot: bool = true, carried: Array[Dictionary] = []) -> void:
	var loot := spec.get("loot", {}) as Dictionary if with_loot else {}
	var items := (loot.get("items", []) as Array).duplicate(true)
	for it in carried:
		items.append(it.duplicate())
	for treasure in Campaign.module().take_treasure(view.loc, "encounter", encounter_id, view.st):
		items.append({"id": treasure, "qty": 1})
	var gold := float(loot.get("gold", 0))
	# Every won fight from the place's own data also leaves its foes' coins and a find, as a road fight does
	# (RoadSpoils.for_story_fight). A fight that isn't the place's (a road encounter with its own spoils, Strahd's
	# visit, the watch's arrest) leaves only what it brings.
	if with_loot and not bool(spec.get("custom", false)):
		var extra := RoadSpoils.for_story_fight(view.st, spec.get("monsters", []) as Array, "%s:%s" % [view.loc_id, encounter_id])
		gold += float(extra["gold"])
		items.append_array(extra["items"] as Array)
	if not items.is_empty() or gold > 0.0:
		view.loot_opened.emit.call_deferred("fight:" + encounter_id, items, gold)
