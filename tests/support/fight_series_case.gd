class_name FightSeriesCase
extends TestCase
## Fights played to the end by the test autopilot with the four pregens, seed by seed, on their own maps
## (test_side_quest_bosses.gd, test_story_fights.gd): every fight finishes, and the party can win but pays for it (hard,
## per the owner's standing rule).

var root: Node
## Whether a fight a conversation starts has its speakers step aside first, as the conversation does (step_aside). Off,
## they stand on the board and block their squares, as the series were measured before 2026-10-13 (fight stalls lane):
## a lane re-measuring its fights turns it on.
var speakers_step_aside := false
## Fights at the location already won before this one starts (its loc state's encounters), for a fight the party can only
## reach through another (Lysaga's stump inside her scarecrow field): unset, every fight there is still to come.
var cleared_fights: Array[String] = []
## Run on the story once the party and flags are set, before the location loads (a Tarokka reading, a quest stage, a
## treasure in a hero's hands): unset, nothing more.
var prepare: Callable
## A fight that isn't in the place's data (Strahd's visits, data/strahd/visits.json): set, the series plays it on the
## location's map, its foes placed as the game places them (custom_start); `encounter` is then its id.
var custom_fight: Dictionary = {}
## A trigger to fire to start the fight (open:hag_oven, check:rahadin_footlocker:failure), for an encounter whose versions have
## different triggers: that trigger starts its own version (LocationFights._trigger_encounter).
var fire_trigger := ""

## The boss fights (owner, 2026-10-14: 3 wins in 8 for a party that uses its skills to the full): the autopilot plays
## them at full ability (PartyAutopilot.full); every other fight is still tuned against sharp play alone.
const BOSS_FIGHTS: Array[String] = [
	"bone_marshal", "tinkers_wagon", "the_hunt", "izek_duel", "festival_izek_rampage", "festival_loyalists",
	"izek_confrontation", "counts_likeness", "bakery_offalia", "coven_last_stand", "bella_betrayed", "bella_on_the_road",
	"offalia_on_the_road", "granny_ash", "grandsire", "abbot_wrath", "bride_defends", "vladimir_duel", "beacon_stand",
	"gilded_knight", "lantern_girl", "greytooth_hunt", "den_reckoning", "pack_challenge", "lysaga_and_hut",
	"lysaga_at_monument", "lysaga_scorned", "creeping_hut_masterless", "rag_queen", "lysaga_in_hut", "the_index",
	"khazan_named", "khazan_unmade", "roc_of_ghakis", "the_penitent", "forgotten_storm", "sarkhaza", "grandfather_stone",
	"exethanter_wrath", "vosk_unmasked", "the_eye_below", "amber_guide", "court_final_audience_hall", "court_final_study",
	"court_final_treasury", "crg_chapel_final_battle", "crg_dinner_affront", "crg_overlook_final_battle",
	"heart_of_sorrow_final", "heart_strahd_test", "cat_horseman_final", "cat_darklord_final", "cat_daylight_waking",
	"cat_royal_final", "cat_sergei_final", "larders_donjon", "court_rahadin_fight", "court_rahadin_chamber_fight",
	"court_brides_fight", "cat_oathbreakers", "corvina", "querreth", "summit_ritual", "ash_effigy", "vine_mother",
	"strahd_test_of_strength", "strahd_at_the_window", "sentinel_wakes", "sentinel_stops_you", "vault_guardian", "lorghoth_rises", "lorghoth_rises_late"]


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Boots `location` at `hour` with the four pregens at `level`, starts `encounter` and plays it with the autopilot.
## `flags`: story flags set first, each a name (set true) or "name=value".
## `at`: where the four stand when it starts (the saved positions a load uses); unset, the location's default spawn.
func _play(location: String, hour: int, level: int, encounter: String, seed_value: int, flags: Array[String] = [],
		guests: Array[String] = [], open_doors: Array[String] = [], at: Array[Vector2i] = []) -> Dictionary:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		# "name=value" sets a flag to a value (yester_druids_fate=fled); a bare name sets it true.
		var kv := f.split("=", true, 1)
		GameState.story.set_flag(kv[0], true if kv.size() == 1 else kv[1])
	for g in guests:
		GameState.story.add_guest(g)
	for d in open_doors:
		(GameState.story.loc_state(location)["doors"] as Dictionary)[d] = LocationView.DOOR_OPEN
	for c in cleared_fights:
		(GameState.story.loc_state(location)["encounters"] as Dictionary)[c] = true
	if prepare.is_valid():
		prepare.call(GameState.story)
	GameState.story.location = location
	if at.size() == GameState.story.party.size():
		GameState.story.positions = at.duplicate()
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(seed_value)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	# A party set down inside a fight's trigger area sets it off as it arrives; otherwise it starts here.
	var started := str((GameState.story.loc_state(location)["encounters"] as Dictionary).get(encounter, "")) == "started"
	if not started and not custom_fight.is_empty():
		started = custom_start(v, custom_fight)
	if not started and fire_trigger != "":
		started = LocationFights._trigger_encounter(v, fire_trigger)
	if not started and speakers_step_aside:
		step_aside(v, encounter)
	assert_true(started or v.start_encounter(encounter), "%s starts" % encounter)
	await _frames(2)
	var e := v.combat_view.e
	var was_full := PartyAutopilot.full
	PartyAutopilot.full = PartyAutopilot.full_by_default or encounter in BOSS_FIGHTS
	var res := PartyAutopilot.new(e).run(30)
	PartyAutopilot.full = was_full
	res["story_flags"] = e.legendary.story_flags.duplicate()   # what the fight hands back (a withdrawal's flag)
	res["departed"] = e.legendary.departed.values()
	for c in e.combatants:
		assert_true(c.creature.hp >= 0 and c.creature.hp <= c.creature.max_hp(), "%s HP in range" % c.name())
	root.queue_free()
	root = null
	await _frames(2)
	return res


## Starts `spec`, a fight from outside the place's data, the way the game starts one of Strahd's visits
## (GameRoot._strahd_step): its foes placed about four squares from the leader, clear of the party, guests, people,
## doors and exits (StrahdPresence.placed).
static func custom_start(v: LocationView, spec: Dictionary) -> bool:
	var taken: Array[Vector2i] = []
	for m: Combatant in v.members + v.guest_members:
		taken.append(m.cell)
	for t: Variant in (v.loc.get("doors", []) as Array) + (v.loc.get("exits", []) as Array):
		var c := (t as Dictionary)["cell"] as Array
		taken.append(Vector2i(int(c[0]), int(c[1])))
	for npc: String in v.npc_tokens:
		taken.append((v.npc_tokens[npc] as CombatToken).combatant.cell)
	return v.start_custom_encounter(StrahdPresence.placed(spec, v.loc["map"]["rows"] as Array, taken, v.leader().cell))


## The people whose conversation ends in `encounter` step aside before it starts, as they do when it ends in the fight
## (LocationNpcs.hide_npcs_of): left standing, their squares block the fight (the lead wolf's plugged the narrows on the
## Old Svalich Road, so the last wolf of the pack could neither reach the party nor be reached).
static func step_aside(v: LocationView, encounter: String) -> void:
	for n: Variant in v.loc.get("npcs", []):
		var ref := str((n as Dictionary).get("dialogue", ""))
		var file := DialogueFile.load_key(ref.substr(0, ref.rfind(":"))) if ref.contains(":") else null
		if file == null:
			continue
		for node: String in file.nodes:
			for st: Dictionary in file.nodes[node]:
				if str(st.get("t", "")) == "combat" and str(st.get("encounter", "")) == encounter:
					LocationNpcs.hide_npcs_of(v, ref)


## Plays `encounter` once per seed: every fight finishes and at least one is won. Returns the wins, for a test that
## wants more of them.
func _series(location: String, hour: int, level: int, encounter: String, seeds: Array, flags: Array[String] = [],
		guests: Array[String] = [], open_doors: Array[String] = [], at: Array[Vector2i] = []) -> int:
	var wins := 0
	var downs := 0
	var rounds := 0
	for s: int in seeds:
		var res := await _play(location, hour, level, encounter, s, flags, guests, open_doors, at)
		assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [encounter, s])
		if str(res["outcome"]) == "victory":
			wins += 1
		downs += int(res["downs"])
		rounds += int(res["rounds"])
	print("        %s at level %d: %d/%d won, %.1f rounds, %.1f party members dropped per fight" % [
		encounter, level, wins, seeds.size(), rounds / float(seeds.size()), downs / float(seeds.size())])
	assert_true(wins >= 1, "%s can be won at level %d (%d/%d)" % [encounter, level, wins, seeds.size()])
	return wins
