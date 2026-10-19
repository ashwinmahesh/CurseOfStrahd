extends Node
## The single source of truth for a playthrough (plan §4.3). Everything that matters lives here and
## serializes to one save file; scenes only read and display it.

const SAVE_VERSION := 2

var party: Array[Dictionary] = []
var leader_index: int = 0
var flags: Dictionary = {}
var quests: Dictionary = {}
var tarokka: Dictionary = {}
var faction_attitudes: Dictionary = {}
## Barovian calendar: day 1 is the day the party arrives through the mists.
var day: int = 1
var minute_of_day: int = 8 * 60
var current_scene: String = ""
var party_positions: Array[Vector3] = []
## The playthrough: party characters, flags, quests, places (story/story_state.gd). Phase 3 onward.
var story := StoryState.new()
## Where the game should start when a save is loaded (a location id, or a combat-round snapshot).
var combat_snapshot: Dictionary = {}


func reset() -> void:
	party.clear()
	leader_index = 0
	flags.clear()
	quests.clear()
	tarokka.clear()
	faction_attitudes.clear()
	day = 1
	minute_of_day = 8 * 60
	current_scene = ""
	party_positions.clear()
	story = StoryState.new()
	combat_snapshot = {}


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	EventBus.flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func set_leader(index: int) -> void:
	if party.is_empty():
		return
	leader_index = posmod(index, party.size())
	EventBus.leader_changed.emit(leader_index)


func advance_minutes(minutes: int) -> void:
	minute_of_day += minutes
	while minute_of_day >= 24 * 60:
		minute_of_day -= 24 * 60
		day += 1


## The same night as StoryState.is_night(), the one the story reads (Wiki finding 72).
func is_night() -> bool:
	return minute_of_day < 6 * 60 or minute_of_day >= 19 * 60


func to_dict() -> Dictionary:
	var positions: Array = []
	for p in party_positions:
		positions.append([p.x, p.y, p.z])
	return {
		"version": SAVE_VERSION,
		"party": party.duplicate(true),
		"leader_index": leader_index,
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"tarokka": tarokka.duplicate(true),
		"faction_attitudes": faction_attitudes.duplicate(true),
		"day": day,
		"minute_of_day": minute_of_day,
		"current_scene": current_scene,
		"party_positions": positions,
		"dice": Dice.roller.get_state(),
		"story": story.to_dict(),
		"combat": combat_snapshot.duplicate(true),
		"saved_at": Time.get_datetime_string_from_system(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	for member: Variant in data.get("party", []):
		party.append((member as Dictionary).duplicate(true))
	leader_index = int(data.get("leader_index", 0))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	quests = (data.get("quests", {}) as Dictionary).duplicate(true)
	tarokka = (data.get("tarokka", {}) as Dictionary).duplicate(true)
	faction_attitudes = (data.get("faction_attitudes", {}) as Dictionary).duplicate(true)
	day = int(data.get("day", 1))
	minute_of_day = int(data.get("minute_of_day", 8 * 60))
	current_scene = str(data.get("current_scene", ""))
	for p: Variant in data.get("party_positions", []):
		var a := p as Array
		party_positions.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	# Fresh dice on every load (owner decision 2026-10-07): a reload never replays the rolls it was saved before.
	Dice.reseed_random()
	if data.has("story"):
		story = StoryState.from_dict(data["story"] as Dictionary)
	combat_snapshot = (data.get("combat", {}) as Dictionary).duplicate(true)
	# A save made outside a fight holds no fight's holds (owner report 2026-10-12: a save kept Restrained from a fight
	# that had ended): the same rule as a fight's end, EncounterSetup.clear_fight_effects.
	if combat_snapshot.is_empty() and story != null:
		for ch: Character in story.party + story.bench:
			EncounterSetup.clear_fight_effects(ch)
		for g: Creature in story.guests:
			EncounterSetup.clear_fight_effects(g)
		# A guest who fell in a fight before that was looked after mends here (StoryState.see_to_fallen_guests).
		story.see_to_fallen_guests()
	if story != null:
		_until_long_rest(story)


## The 8-hour house rule (Effect.until_long_rest) on a save from before it: spells still running on the party and
## exploring spells still active switch from the clock to the next Long Rest.
static func _until_long_rest(st: StoryState) -> void:
	for ch: Character in st.party + st.bench:
		for fx: Effect in ch.effects:
			if fx.ends == Effect.Ends.MINUTES and fx.source_kind == &"spell" \
					and Effect.until_long_rest(Compendium.shared().spell_data(fx.source_id).get("duration", {}) as Dictionary):
				fx.ends = Effect.Ends.LONG_REST
				fx.minutes_left = 0
	for id: String in st.active_spells.keys():
		if st.spell_active(id) and not bool((st.active_spells[id] as Dictionary).get("long_rest", false)) \
				and Effect.until_long_rest(Compendium.shared().spell_data(id).get("duration", {}) as Dictionary):
			RestRules.keep_until_long_rest(st, id)
