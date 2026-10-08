class_name LocationFights
extends RefCounted
## Fights in a location (LocationView): which encounter a trigger starts, Strahd's parley before a final battle,
## fights started by a flag or a random encounter, the fight itself on the same grid (CombatView), a save as each round
## begins and resuming from it, the switch into combat without a jump, and what a won fight leaves.


## Starts any encounter of this location whose trigger matches and whose condition holds. True if one started.
static func _trigger_encounter(view: LocationView, trigger: String) -> bool:
	for en: Variant in view.loc.get("encounters", []):
		var spec := en as Dictionary
		if str(spec["trigger"]) != trigger:
			continue
		if (view.st.loc_state(view.loc_id)["encounters"] as Dictionary).get(str(spec["id"]), false) is bool \
				and bool((view.st.loc_state(view.loc_id)["encounters"] as Dictionary).get(str(spec["id"]), false)):
			continue
		# A final battle's `when` also needs Strahd waiting in its room (StoryConditions.encounter_when, ADR 0014).
		if not StoryConditions.check(StoryConditions.encounter_when(spec), view.st):
			continue
		if str(spec.get("final_battle", "")) != "":
			return _begin_final_battle(view, str(spec["id"]))
		start_encounter(view, str(spec["id"]))
		return true
	return false


## Before a final battle Strahd parleys (strahd/final:parley, when it's written and hasn't been answered): the fight
## starts once it ends, if `strahd_parley` is `fight` or unset; `yield` and `ireena` leave it to the ending. True if
## the parley or the fight began.
static func _begin_final_battle(view: LocationView, encounter_id: String) -> bool:
	var answer := str(view.st.get_flag("strahd_parley", ""))
	var file := DialogueFile.load_key(LocationView.PARLEY.get_slice(":", 0))
	if answer == "" and file != null and file.nodes.has(LocationView.PARLEY.get_slice(":", 1)) and view._pending_final == "":
		view._pending_final = encounter_id
		view.dialogue_requested.emit(LocationView.PARLEY, "strahd")
		return true
	if answer in ["", "fight"]:
		return start_encounter(view, encounter_id)
	return false


## Fights triggered by a flag (set by dialogue or a lever): checked after conversations and interactions.
static func check_flag_encounters(view: LocationView) -> bool:
	_after_captives(view)
	# The parley before a final battle has ended: the fight, unless Strahd's price was paid.
	if view._pending_final != "":
		var waiting := view._pending_final
		view._pending_final = ""
		if str(view.st.get_flag("strahd_parley", "")) in ["", "fight"]:
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
	if not view.loc.has("encounters"):
		view.loc["encounters"] = []
	(view.loc["encounters"] as Array).append(s)
	return start_encounter(view, str(s["id"]))


## A monster's ward in a fight at `location` (ADR 0014): its `ward.hp` taken before its Hit Points (the Heart of
## Sorrow shielding Strahd), in its `region` if it names one, unless the story condition `unless` holds. 0 for none.
static func ward_for(data: Dictionary, location: Dictionary, state: StoryState) -> int:
	var ward := data.get("ward", {}) as Dictionary
	if ward.is_empty() or (str(ward.get("region", "")) != "" and str(ward["region"]) != str(location.get("region", ""))):
		return 0
	return 0 if StoryConditions.check(str(ward.get("unless", "false")), state) else int(ward["hp"])


## The fight happens here, on the same grid: the party where it stands, the monsters where the data puts them.
## Surprise (2024, LocationStealth): a sneaking party surprises each foe that hasn't noticed any of them.
static func start_encounter(view: LocationView, encounter_id: String) -> bool:
	# Several entries may share an id with different `when` conditions (e.g. a lighter version for a lower-level
	# party): the first whose condition holds is the fight.
	var spec := spec_for(view, encounter_id)
	if spec.is_empty() or view.in_combat:
		return false
	if view._pending_final == encounter_id:
		view._pending_final = ""
	view._queue.clear()
	view._on_arrive = Callable()
	view.in_combat = true
	ModeController.force(ModeController.Mode.COMBAT)
	var e := Encounter.new(_combat_grid(view), view.dice)
	e.title = str(spec.get("text", ""))
	# Bosses (ADR 0014): the place (a Misty Escape's resting place), the lair's actions, a foe that withdraws.
	e.location_id = view.loc_id
	for place: String in Tarokka.spots(view.loc):
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
	if str(spec.get("final_battle", "")) != "" and view.st.quest_stage_index("strahds_lair", view.st.quest_stage("strahds_lair")) < view.st.quest_stage_index("strahds_lair", "confronted"):
		view.st.set_quest_stage("strahds_lair", "confronted")
	var party_cbs: Array[Combatant] = []
	for m in view.members:
		if m.creature.dead:
			continue
		party_cbs.append(e.add(m.creature, &"party", m.cell))
	for g in view.guest_members:
		# A familiar following the party joins as its caster's summon (EncounterSetup.bring_familiars below).
		if not g.creature.dead and not g.has_meta("familiar_of"):
			e.add(g.creature, &"guest", g.cell).controller = &"player"
	for mo: Dictionary in monsters_for(view, spec):
		e.add(mo["creature"] as Monster, mo["side"] as StringName, mo["cell"] as Vector2i)
	# The playthrough's difficulty: enemy Hit Points, what foes carry, how they fight (combat/difficulty.gd).
	Difficulty.of_options(view.st.options).prepare(e)
	EncounterSetup.bring_familiars(e, party_cbs)
	_light_the_fight(view, e)
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
	LocationPlan.stop(view)
	(view.st.loc_state(view.loc_id)["encounters"] as Dictionary)[encounter_id] = "started"
	var ctokens := _fight_tokens(view, e)
	LocationStealth.clear_waiting(view, encounter_id)
	view.combat_view = CombatView.new()
	view.combat_view.input_locked = view.input_locked
	view.combat_view.narrator = view.narrator
	view.combat_view.story = view.st
	view.add_child(view.combat_view)
	view._say("combat:start")
	_run_combat(view, encounter_id, spec, e, ctokens, surprised)
	return true


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
		var mon := Monster.from_data(data)
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


## The encounter entry a fight with `encounter_id` uses now: of the entries sharing the id, the first whose `when`
## holds (else the last). {} if there's none.
static func spec_for(view: LocationView, encounter_id: String) -> Dictionary:
	var spec := {}
	for en: Variant in view.loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id and (spec.is_empty() or not StoryConditions.check(StoryConditions.encounter_when(spec), view.st)):
			spec = en as Dictionary
	return spec


static func _run_combat(view: LocationView, encounter_id: String, spec: Dictionary, e: Encounter, ctokens: Dictionary, surprised: Array[String]) -> void:
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
	GameState.combat_snapshot = {"location": view.loc_id, "encounter": encounter_id, "data": EncounterSnapshot.capture(e)}
	SaveSystem.save_round()


## Picks a saved fight up again at the start of its round (after loading a round-start save).
static func resume_encounter(view: LocationView, snapshot: Dictionary) -> bool:
	var encounter_id := str(snapshot.get("encounter", ""))
	var spec := {}
	for en: Variant in view.loc.get("encounters", []):
		if str((en as Dictionary)["id"]) == encounter_id:
			spec = en as Dictionary
	if spec.is_empty() or view.in_combat:
		return false
	view.in_combat = true
	ModeController.force(ModeController.Mode.COMBAT)
	var e := EncounterSnapshot.restore(snapshot["data"] as Dictionary, view.dice, view.st.party)
	var ctokens := _fight_tokens(view, e)
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
static func _fight_tokens(view: LocationView, e: Encounter) -> Dictionary:
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
	for m: Combatant in view.members + view.guest_members:
		if not ours.has(view.tokens[m.id] as CombatToken):
			(view.tokens[m.id] as Node3D).visible = false
	party_mid /= maxf(1.0, float(ours.size()))
	var foes: Array[CombatToken] = []
	var standing: Array[CombatToken] = []
	for c in e.combatants:
		if ctokens.has(c.id):
			continue
		# A foe the party could already see waiting there keeps its figure (LocationStealth).
		var t := LocationStealth.claim_token(view, c)
		if t != null:
			ctokens[c.id] = t
			standing.append(t)
			continue
		t = _combat_token(c)
		t.position = view.board.cell_center(c.cell, c.size_cells)
		var look := party_mid - t.position
		t.face(Vector2(look.x, look.z), false)
		view.add_child(t)
		ctokens[c.id] = t
		foes.append(t)
	foes.sort_custom(func(a: CombatToken, b: CombatToken) -> bool: return a.position.distance_to(party_mid) < b.position.distance_to(party_mid))
	for i in foes.size():
		foes[i].emerge(0.1 + 0.5 * i / maxf(1.0, foes.size() - 1.0), 0.6)
	var turn := view.create_tween()
	turn.tween_interval(LocationView.STEP_TIME + 0.05)
	var every_foe: Array[CombatToken] = foes.duplicate()
	every_foe.append_array(standing)
	turn.tween_callback(func() -> void:
		_face_nearest_foe(ours, every_foe)
		_face_nearest_foe(standing, ours))
	return ctokens


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
		var o := FieldObject.new(FieldObject.Kind.ZONE, "", str(li.get("kind", "light")))
		o.cell = LocationView._cell(li["cell"])
		o.rules = {"light": {"bright": int(li.get("bright_ft", 10)), "dim": int(li.get("dim_ft", 10))}}
		e.spells.zones.objects.append(o)
	if view.lantern != null and view.lantern.visible and not view.members.is_empty():
		var lo := FieldObject.new(FieldObject.Kind.ZONE, "", "lantern")
		lo.caster_id = view.leader().id
		lo.rules = {"light": {"bright": 30, "dim": 30}, "light_on": "caster"}
		e.spells.zones.objects.append(lo)


## The location's grid as it stands now (closed doors are walls; NPC squares are blocked).
static func _combat_grid(view: LocationView) -> CombatGrid:
	var g := CombatGrid.from_rows(view.loc["map"]["rows"] as Array)
	g.drop_ft = int(view.loc["map"].get("drop_ft", 0))
	g.ceiling_ft = int(view.loc["map"].get("ceiling_ft", 0 if bool(view.loc["map"].get("outdoors", false)) else 20))
	for d: Variant in view.loc.get("doors", []):
		var door := d as Dictionary
		g.set_flag(LocationView._cell(door["cell"]), CombatGrid.WALL, LocationLocks._door_state(view, str(door["id"])) != LocationView.DOOR_OPEN)
	for npc: String in view.npc_tokens:
		if (view.npc_tokens[npc] as CombatToken).visible:
			g.set_flag((view.npc_tokens[npc] as CombatToken).combatant.cell, CombatGrid.LOW, true)
	return g


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
		if tok.visible and tok.combatant.is_alive():
			tok.fade_away(0.5)
		else:
			tok.queue_free()
	if view.combat_view != null:
		view.combat_view.close_softly()
		view.combat_view = null
	view.in_combat = false
	GameState.combat_snapshot = {}
	ModeController.force(ModeController.Mode.EXPLORATION)
	view.rig.follow = view.tokens[view.leader().id] as Node3D
	view.st.advance_minutes(1)
	# With the fight over, nobody is still held by a dead grappler, and the fallen-over get up.
	for m in view.members:
		if m.creature.hp > 0:
			m.creature.remove_condition(&"grappled")
			m.creature.remove_condition(&"prone")
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
		if spec.has("flag"):
			view.st.set_flag(str(spec["flag"]))
		if spec.has("quest"):
			var q := spec["quest"] as Dictionary
			view.st.set_quest_stage(str(q["id"]), str(q["stage"]))
			view.toast.emit("Journal updated: %s" % str(Compendium.shared().get_entry("quests", str(q["id"])).get("name", q["id"])))
		# Out of combat, the fallen are stabilized by their friends (a minute later) at 0 HP; nobody stays dying.
		for m in view.members:
			var cr := m.creature
			if cr.hp <= 0 and not cr.dead and not cr.stable:
				cr.stabilize()
		view._say("combat:victory")
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
	for treasure in Tarokka.take_from(Tarokka.place_for(view.loc, "encounter", encounter_id), view.st):
		items.append({"id": treasure, "qty": 1})
	var gold := float(loot.get("gold", 0))
	if not items.is_empty() or gold > 0.0:
		view.loot_opened.emit.call_deferred("fight:" + encounter_id, items, gold)
