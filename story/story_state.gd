class_name StoryState
extends RefCounted
## Everything about a playthrough's story and party that outlives a scene (plan §4.3 "single game state"): the
## party's characters, money and stash, story flags, quest stages, NPC attitudes, places visited, the codex, the
## Narrator's memory, milestone level-ups, game time, and each location's state (doors, loot, traps, fights).
## Pure data with to_dict()/from_dict(); GameState (core/) holds one and saves it.

var party: Array[Character] = []
## Roster members at camp: the rest of the company, out of the party for now (owner, 2026-10-06: the player swaps
## who travels, up to PARTY_CAP at once, outside fights and conversations). They don't speak in the story, except by
## the fire when the party makes camp (camp_company), and they don't level while they're away (owner, 2026-10-07):
## they keep their level, and when they rejoin, the player takes each level they missed in turn on the level-up screen
## (levels_waiting).
var bench: Array[Character] = []
## The roster members by the fire while the party has made camp in the wild (LocationCamp, F16): there the story finds
## them as it finds the party (find_member, so their camp talks come up) and they see what's chosen (Approval). Not
## saved: a camp is pitched again each time.
var camp_company: Array[Character] = []
## The morning after the last Long Rest (LongRest.morning_open): {at: the game minute it ended, prepared: the party's
## prepared spells then (PrepareScreen.snapshot), what a change of them counts from}. Not saved.
var morning: Dictionary = {}
## Index into party of the character leading in exploration and speaking in dialogue.
var leader: int = 0
var gold: float = 0.0
var stash: Array[Dictionary] = []          ## [{id, qty}] at safe places
var flags: Dictionary = {}
var quests: Dictionary = {}                ## quest id -> {stage, history: [stage ids], at: game minute it last moved}
var attitudes: Dictionary = {}             ## npc id -> hostile | indifferent | friendly
var visited: Dictionary = {}               ## location or area id -> true
var codex: Array[String] = []              ## lore read (book props, letters)
var narrator: Dictionary = {}              ## trigger key -> {played: [variant indexes], last_minute, done}
var milestones: int = 0                    ## story milestones reached (milestone levelling; XP levelling counts them too, for its floor)
## The party's experience points (Xp, XP levelling): one pool, each hero's share. Not counted in milestone mode.
var xp: int = 0
## XP earned past the ceiling, waiting for the next milestone to pay it out (Xp.gain).
var xp_reserve: int = 0
var start_level: int = 1
var day: int = 1
var minute_of_day: int = 18 * 60           ## the party arrives at dusk
var location: String = ""
var positions: Array[Vector2i] = []        ## grid cells of party members in the current location
var location_states: Dictionary = {}      ## location id -> {doors: {id: "open"|"unlocked"}, looted: {}, traps: {id: state}, encounters: {}, props: {}}
## The result of the last check a dialogue or the world made (for `check.last`).
var last_check: bool = false
## Party members lost for good: [{name, id, how, day}] (the roll of honour in the party screen).
var fallen: Array[Dictionary] = []
## The playthrough's seed: it decides the Tarokka reading (and nothing that a die roll decides).
var playthrough_seed: int = 0
## Madam Eva's reading once drawn: {tome, symbol, sword, ally, enemy} -> card id (story/tarokka.gd).
var tarokka: Dictionary = {}
## Story allies travelling with the party (ADR 0010): the npc ids, and their creatures in the same order.
var guest_ids: Array[String] = []
var guests: Array[Creature] = []
## Merchants' stock as it stands: npc id -> {item id: quantity left} (only items with limited stock).
var shops: Dictionary = {}
## A journey interrupted by something on the road: {to: place id, at: place id the party had reached}.
var travel_resume: Dictionary = {}
## Miles travelled since the party's last Long Rest (Mist Walker, a Ravenloft Dark Gift).
var miles_since_long_rest: float = 0.0
## Playthrough options the owner can switch (plan §5.6): respec at Madam Eva. `levelling` is how heroes grow, picked at a
## new game and never changed: "milestone" (every save before XP levelling) or "xp" (story/xp.gd).
var options: Dictionary = {"respec": true, "levelling": "milestone"}
## Exploring spells still running: spell id -> {until: total minute, caster} (Light, Detect Magic, Speak with Dead).
var active_spells: Dictionary = {}
## How each of the six companions feels about the party's choices (story/approval.gd): id -> {score, memories}.
var approval: Dictionary = {}
## The run's record for the ending (RunStats): each hero's kills, crits, natural 20s and 1s and more, and the gold.
var run_stats: Dictionary = {}
## What the party has learned about the creatures it has fought (story/bestiary.gd): monster id -> {n, met, where,
## defeated, studied}.
var bestiary: Dictionary = {}


# --- Flags, quests, attitudes ---------------------------------------------------------------------

## Adds `entry` to the codex (lore read: a book, a letter, a lore check, the Tome of Strahd). Returns -1 if the party
## already had it, else the XP the lore earned (Experience mode; 0 in milestone mode), for the caller to add to its
## notice (Xp.tag).
func add_codex(entry: String) -> int:
	if entry in codex:
		return -1
	codex.append(entry)
	return Xp.award(self, "lore", entry)


func get_flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)


func set_flag(id: String, value: Variant = true) -> void:
	flags[id] = value


func quest_stage(quest_id: String) -> String:
	return str((quests.get(quest_id, {}) as Dictionary).get("stage", ""))


## A quest has just moved into a stage that ends it ("success" or "failure"). The world marks a failure with a sting
## (GameRoot); the notice itself is quest_notice.
signal quest_finished(quest_id: String, ending: String)

## What the player should be told about the last set_quest_stage that took (quest_notice). Not saved.
var _quest_says := ""


## Moves a quest to `stage` (data/quests). Returns false if the quest or stage doesn't exist, or if `stage` is an
## earlier one that's still open and the quest has ended or `stage` is its first: a line that starts or moves a quest
## without asking where it is can't reopen a finished quest or start a begun one over (Storyline QA, 2026-10-12:
## Blinsky's doll talk put Izek's back to "Learn what Izek wants with her"; Davian's pledge put The Third Stone back to
## "told" after the stone was found, Wiki finding 40). Also false when the quest stands at a failure ending that doesn't
## list `stage` in its `then`: a failure is final, so a later success line can't paper over it (side quest failure
## plan, F1); a comeback is a stage the failure names. The stage's `at` (when the quest last moved, which the clocks
## count from) changes only when the stage does.
func set_quest_stage(quest_id: String, stage: String) -> bool:
	var q := Compendium.shared().get_entry("quests", quest_id)
	if q.is_empty():
		return false
	var at := quest_stage_index(quest_id, stage)
	if at < 0:
		return false
	var ends := str(((q["stages"] as Array)[at] as Dictionary).get("ends", ""))
	var was := quest_stage(quest_id)
	var was_ending := quest_ending(quest_id)
	if ends == "" and at < quest_stage_index(quest_id, was) and (at == 0 or quest_ended(quest_id)):
		return false
	if was != stage and _failure_is_final(q, was, stage):
		return false
	var entry := quests.get(quest_id, {"stage": "", "history": []}) as Dictionary
	entry["stage"] = stage
	var hist := entry.get("history", []) as Array
	if not stage in hist:
		hist.append(stage)
	entry["history"] = hist
	var moved := was != stage
	if moved or not entry.has("at"):
		entry["at"] = total_minutes()   # when it last moved: the recap's road ahead names the newest first (Q3, lane 16)
	quests[quest_id] = entry
	var xp_said := ""
	if ends == "success":
		xp_said = Xp.quest_done(self, quest_id)   # XP levelling: a quest finished is worth XP (nothing in milestone mode)
	var quest_name := Compendium.shared().display_name("quests", quest_id)
	_quest_says = "Journal updated: %s" % quest_name
	if moved and ends != was_ending:   # (not again for one ending that gives way to another of its kind)
		if ends == "failure":
			_quest_says = "Quest failed: %s" % quest_name
		elif ends == "success":
			_quest_says = xp_said if xp_said != "" else "Quest complete: %s" % quest_name
	if moved and ends != "":
		quest_finished.emit(quest_id, ends)
	if quest_id == "find_the_ally":
		_settle_ally()
	return true


## Whether the quest stands at the failure ending `from_stage` and `to_stage` isn't one of the stages that ending's
## `then` allows.
func _failure_is_final(q: Dictionary, from_stage: String, to_stage: String) -> bool:
	for s: Variant in q.get("stages", []):
		var d := s as Dictionary
		if str(d["id"]) == from_stage:
			return str(d.get("ends", "")) == "failure" and not to_stage in (d.get("then", []) as Array)
	return false


## What the player is told about the quest the last set_quest_stage moved: "Quest failed: X" when it moved into a
## stage that ends in failure, "Quest complete: X" into one that ends in success (in Experience mode the line that also
## says the XP it paid, so the two never double), and "Journal updated: X" for anything else. The dialogue's `quest`
## line and a won fight's `quest` both say it; read it straight after the call that returned true.
func quest_notice() -> String:
	return _quest_says


## The Tarokka ally's quest follows the party (Wiki finding 66): it's found the moment the one the cards named travels
## with the party, however they came to join (Ismark's, Kolyan's and Parriwimple's scenes never said so), and the
## Darklord card, which names no one, closes it at once.
func _settle_ally() -> void:
	if quest_stage("find_the_ally") != "foretold":
		return
	if str(tarokka.get("ally", "")) == "darklord":
		set_quest_stage("find_the_ally", "alone")
	elif Campaign.module().field(self, "ally.npc") in guest_ids:
		set_quest_stage("find_the_ally", "found")
	elif Campaign.module().field(self, "ally.lost") != "":
		set_quest_stage("find_the_ally", "lost")   # gone before the cards named them (Wiki findings 101, 113)


## Whether the quest stands at a stage that ends it (success or failure).
func quest_ended(quest_id: String) -> bool:
	return quest_ending(quest_id) != ""


## How the quest's stage ends it: "success", "failure", or "" while the quest is open or hasn't begun.
func quest_ending(quest_id: String) -> String:
	var i := quest_stage_index(quest_id, quest_stage(quest_id))
	if i < 0:
		return ""
	var stages := Compendium.shared().get_entry("quests", quest_id).get("stages", []) as Array
	return str((stages[i] as Dictionary).get("ends", ""))


## Whole days since the quest last moved (its `at`), for `quest_days.<id> >= 3`; -1 while it hasn't begun.
func quest_days(quest_id: String) -> int:
	var entry := quests.get(quest_id, {}) as Dictionary
	if not entry.has("at"):
		return -1
	return maxi(0, total_minutes() - int(entry["at"])) / DAY_MINUTES


## Whole days since a flag was stamped (`set <flag> = now`, dialogue contract), for `days_since.<flag> >= 2`; -1 while
## it hasn't been stamped.
func days_since(flag_id: String) -> int:
	var stamp: Variant = flags.get(flag_id)
	if not (stamp is int or stamp is float):
		return -1
	return maxi(0, total_minutes() - int(stamp)) / DAY_MINUTES


## The order of a quest's stages, for >= comparisons in conditions (-1 if not reached / unknown).
func quest_stage_index(quest_id: String, stage: String) -> int:
	var q := Compendium.shared().get_entry("quests", quest_id)
	var i := 0
	for s: Variant in q.get("stages", []):
		if str((s as Dictionary)["id"]) == stage:
			return i
		i += 1
	return -1


func attitude(npc_id: String) -> String:
	if attitudes.has(npc_id):
		return str(attitudes[npc_id])
	return str(Compendium.shared().get_entry("npcs", npc_id).get("attitude", "indifferent"))


# --- Party ----------------------------------------------------------------------------------------

func leader_character() -> Character:
	if party.is_empty():
		return null
	return party[clampi(leader, 0, party.size() - 1)]


## The first party member (in marching order) that matches a selector: class:x, species:x, background:x,
## tag:x, name:x, item:x. While the party has made camp, the companions by the fire count too (camp_company).
func find_member(selector: String) -> Character:
	for ch in party:
		if member_matches(ch, selector):
			return ch
	for ch in camp_company:
		if member_matches(ch, selector):
			return ch
	return null


static func member_matches(ch: Character, selector: String) -> bool:
	var kind := selector.get_slice(":", 0)
	var value := selector.get_slice(":", 1)
	match kind:
		"class":
			return ch.class_level_of(value) > 0
		"species":
			return str(ch.build.get("species", "")) == value or ch.lineage == value
		"background":
			return str(ch.build.get("background", "")) == value
		"tag":
			var identity := ch.build.get("identity", {}) as Dictionary
			return value in (identity.get("tags", []) as Array)
		"name":
			# A custom hero never answers for a pregenerated companion it replaced or shares a name with.
			if bool((ch.build.get("appearance", {}) as Dictionary).get("custom", false)):
				return false
			return ch.id == value or ch.name.to_snake_case() == value
		"item":
			if ch.carries(value):
				return true
			for e: Dictionary in ch.inventory:
				if is_scroll_of(str(e["id"]), value) and int(e["qty"]) > 0:
					return true
		"knows":
			# A spell the character can cast now (prepared, always prepared, or granted, by a feature or by a potion still
			# working): a story beat that needs one.
			return ch.knows_spell(value) or ch.granted_spell(value)
	return false


func party_has_item(item_id: String) -> bool:
	if find_member("item:" + item_id) != null:
		return true
	for e in stash:
		if (str(e["id"]) == item_id or is_scroll_of(str(e["id"]), item_id)) and int(e["qty"]) > 0:
			return true
	return false


## Whether `item_id` is a Spell Scroll of the level the generic scroll `generic_id` names ("item:spell_scroll_level_1" in
## a condition, or `take spell_scroll_level_1`, asks for any such scroll). A scroll is always carried as a particular
## spell ("spell_scroll__shield"), never as the generic id a reward names (MagicItems.GENERIC_SCROLLS).
static func is_scroll_of(item_id: String, generic_id: String) -> bool:
	if not MagicItems.GENERIC_SCROLLS.has(generic_id) or item_id == generic_id:
		return false
	var spell := Character.scroll_spell_of(Compendium.shared().item_data(item_id))
	return spell != "" and int(Compendium.shared().spell_data(spell).get("level", -1)) == int(MagicItems.GENERIC_SCROLLS[generic_id])


## The party came by an item outside a loot window or a shop (gain_item): `who` is the character who has it, "" for the
## party's stash. The game shows it on the side (ItemNotices).
signal item_gained(item_id: String, qty: int, who: String)


## Gives `ch` (or the stash) an item the party has just come by, a skill check's find, a gift, a hidden find, a picked
## pocket, and says so (item_gained). Loot windows, shops and moves to and from the stash use give_item quietly.
func gain_item(item_id: String, qty: int, ch: Character = null) -> void:
	give_item(item_id, qty, ch)
	item_gained.emit(item_id, qty, ch.name if ch != null else "")


## Gives an item to `ch` (or the stash if nobody's given).
func give_item(item_id: String, qty: int, ch: Character = null) -> void:
	if ch != null:
		ch.add_item(item_id, qty)
		return
	if MagicItems.GENERIC_SCROLLS.has(item_id):
		for i in qty:
			give_item(MagicItems.specific_scroll(item_id, "%d:stash:%d:%d" % [playthrough_seed, stash.size(), i], Compendium.shared()), 1)
		return
	for e in stash:
		if str(e["id"]) == item_id:
			e["qty"] = int(e["qty"]) + qty
			return
	stash.append({"id": item_id, "qty": qty})


## Moves one `item_id` from `ch`'s pack to the party stash (from anywhere; things come out again at safe places, which
## the inventory screen checks). A magic item keeps its own state there (charges, identified, a lifted curse), and an
## attunement to it ends; a cursed item its bearer is attuned to stays with them (Character.part_blocker).
func stash_put(item_id: String, ch: Character, entry: Dictionary = {}) -> bool:
	if not ch.inventory.any(func(e: Dictionary) -> bool: return str(e["id"]) == item_id and int(e["qty"]) > 0 \
			and (entry.is_empty() or is_same(e, entry))) or ch.part_blocker(item_id) != "":
		return false
	stash_add(item_id, 1, ch.remove_one(item_id, entry))
	return true


## Puts `qty` of an item in the party stash; `state` is its own state (an inventory entry or a loot window's find), kept
## for an item that has any (charges, identified, a junk mark).
func stash_add(item_id: String, qty: int, state: Dictionary = {}) -> void:
	var keep := Character.entry_state(state)
	keep.erase("new")
	if keep.is_empty() or bool(Compendium.shared().item_data(item_id).get("stackable", false)) or MagicItems.GENERIC_SCROLLS.has(item_id):
		give_item(item_id, qty)
		return
	for i in qty:
		var e := keep.duplicate(true)
		e["id"] = item_id
		e["qty"] = 1
		stash.append(e)


## Moves one `item_id` from the stash to `ch` (from stash entry `entry` when given), with the state it was stashed with.
func stash_take(item_id: String, ch: Character, entry: Dictionary = {}) -> bool:
	for e in stash:
		if str(e["id"]) == item_id and int(e["qty"]) > 0 and (entry.is_empty() or is_same(e, entry)):
			e["qty"] = int(e["qty"]) - 1
			if int(e["qty"]) <= 0:
				stash.erase(e)
			ch.add_item(item_id, 1, Character.entry_state(e))
			return true
	return false


## Takes up to `qty` of an item from the party (stash last). Returns how many were taken.
func take_item(item_id: String, qty: int) -> int:
	var left := qty
	for ch in party:
		for e: Dictionary in ch.inventory.duplicate():
			if left <= 0:
				break
			if (str(e["id"]) == item_id or is_scroll_of(str(e["id"]), item_id)) and int(e["qty"]) > 0:
				var n := mini(left, int(e["qty"]))
				e["qty"] = int(e["qty"]) - n
				left -= n
				if int(e["qty"]) <= 0 and str(e.get("slot", "")) == "":
					ch.inventory.erase(e)
	for e: Dictionary in stash.duplicate():
		if left <= 0:
			break
		if str(e["id"]) == item_id or is_scroll_of(str(e["id"]), item_id):
			var n2 := mini(left, int(e["qty"]))
			e["qty"] = int(e["qty"]) - n2
			left -= n2
			if int(e["qty"]) <= 0:
				stash.erase(e)
	return qty - left


## The highest level the campaign takes the party to (plan §10, Phase 5: 10 or 11 by the Amber Temple).
const LEVEL_CAP := 11


## The level the story gives the party now: where it starts plus the milestones it has reached (plan §5.6).
func story_level() -> int:
	return mini(LEVEL_CAP, start_level + milestones)


## The level the party may reach now. Milestone levelling: the story's. XP levelling (story/xp.gd): the XP pool's, which
## the floor and the ceiling keep within a level of the story's.
func target_level() -> int:
	if Xp.active(self):
		return mini(LEVEL_CAP, maxi(start_level, Xp.level_for(xp)))
	return story_level()


## Experience (Xp.gain, quests, places, finds, milestones) said something the player should see: "Quest complete: The
## Grey Mare, +125 XP". The game shows it as a notice.
signal xp_gained(text: String)


func can_level_up(ch: Character) -> bool:
	return ch.character_level() < target_level()


## How many levels `ch` has to take to reach the party's milestone: one level-up screen each, in order.
func levels_waiting(ch: Character) -> int:
	return maxi(0, target_level() - ch.character_level())


# --- The roster -----------------------------------------------------------------------------------

## Most characters travelling at once.
const PARTY_CAP := 4


## Everyone the player can choose from: the party, then those at camp.
func roster() -> Array[Character]:
	var out: Array[Character] = party.duplicate()
	out.append_array(bench)
	return out


## `incoming` (at camp) takes `outgoing`'s place in the party and marching order; `outgoing` goes to camp. A dead
## hero stays with the party, to be brought back (Ashwin, 2026-10-15): one can't go to camp, and one left there by an
## older save can be fetched.
func swap_members(outgoing: Character, incoming: Character) -> bool:
	var i := party.find(outgoing)
	var j := bench.find(incoming)
	if i < 0 or j < 0 or outgoing.dead:
		return false
	party[i] = incoming
	bench[j] = outgoing
	return true


## Someone at camp joins the party at the back, while there's room (a dead hero too: the body comes back to be raised).
func bring_along(ch: Character) -> bool:
	var j := bench.find(ch)
	if j < 0 or party.size() >= PARTY_CAP:
		return false
	bench.remove_at(j)
	party.append(ch)
	return true


## Most custom characters a game has at once (owner, 2026-10-07), the hero made at the start among them.
const CUSTOM_CAP := 4


## The custom characters in the roster (made in the creator: the starting hero and those made from the party screen).
func custom_members() -> Array[Character]:
	var out: Array[Character] = []
	for ch in roster():
		if bool((ch.build.get("appearance", {}) as Dictionary).get("custom", false)):
			out.append(ch)
	return out


## Why no more custom characters can be made in this game, or "".
func create_blocker() -> String:
	if custom_members().size() >= CUSTOM_CAP:
		return "This company has %d custom characters, the most one game can have." % CUSTOM_CAP
	return ""


## A character made during the game (the party screen's creator, owner 2026-10-07) joins the roster: the party while
## there's room, else camp. They start at level 1 and take the levels the party has reached on the level-up screen
## (levels_waiting). Their id is one nobody in the company has. Returns whether they joined the party.
func recruit(ch: Character) -> bool:
	var taken := {}
	for other in roster():
		taken[other.id] = true
	for f in fallen:
		taken[str(f["id"])] = true
	var base := ch.id if ch.id != "" else ch.name.to_snake_case()
	var id := base
	var n := 2
	while taken.has(id) or not Compendium.shared().get_entry("pregens", id).is_empty():
		id = "%s_%d" % [base, n]
		n += 1
	ch.id = id
	if party.size() < PARTY_CAP:
		party.append(ch)
		return true
	bench.append(ch)
	return false


## A party member goes to camp; the party never goes below one. A dead one stays with the party, so they can be brought
## back (Ashwin, 2026-10-15: a body left at camp could never be raised).
func send_to_camp(ch: Character) -> bool:
	var i := party.find(ch)
	if i < 0 or party.size() <= 1 or ch.dead:
		return false
	party.remove_at(i)
	if positions.size() > i:
		positions.remove_at(i)
	bench.append(ch)
	leader = clampi(leader, 0, party.size() - 1)
	return true


# --- Time -----------------------------------------------------------------------------------------

const DAY_MINUTES := 24 * 60


func total_minutes() -> int:
	return (day - 1) * DAY_MINUTES + minute_of_day


## A stretch of time worth showing passed (half an hour or more: a rest, a journey, a long wait).
signal time_passed(minutes: int)


func advance_minutes(minutes: int) -> void:
	if minutes >= 30:
		time_passed.emit(minutes)
	var start := total_minutes()
	Services.note_deaths(self, start)   # when each fallen hero died, for Raise Dead's 10 days
	minute_of_day += minutes
	while minute_of_day >= 24 * 60:
		minute_of_day -= 24 * 60
		day += 1
	for ch in party:
		ch.advance_minutes(minutes)
	# Story allies' spells and Concentration run out with the clock too.
	for g in guests:
		g.advance_minutes(minutes)
	_item_time(start, minutes)


## Magic items and the clock (ADR 0012): charges come back at dawn (or dusk), regeneration heals as time passes. The
## dice are seeded from the playthrough and the hour, so the same rest gives the same result.
func _item_time(start: int, minutes: int) -> void:
	if minutes <= 0:
		return
	var dice := DiceRoller.new(hash("%d:%d:items" % [playthrough_seed, start]))
	for t in range(start + 1, start + minutes + 1):
		var m := t % (24 * 60)
		if m == 6 * 60:
			for ch in party:
				for line in ch.on_dawn(dice):
					item_news.append(line)
		elif m == 18 * 60:
			for ch in party:
				ch.on_dusk(dice)
	for ch in party:
		ch.items_passage(minutes, dice)


## Things items did while time passed (charges back at dawn), for the world to show; drained by whoever shows them.
var item_news: Array[String] = []


## Whether an exploring spell is still running (`spell:light` in conditions).
func spell_active(spell_id: String) -> bool:
	return active_spells.has(spell_id) and int((active_spells[spell_id] as Dictionary)["until"]) > total_minutes()


func is_night() -> bool:
	return minute_of_day < 6 * 60 or minute_of_day >= 19 * 60


# --- Locations ------------------------------------------------------------------------------------

func loc_state(location_id: String) -> Dictionary:
	if not location_states.has(location_id):
		location_states[location_id] = {"doors": {}, "looted": {}, "traps": {}, "encounters": {}, "props": {}, "found": {}}
	return location_states[location_id] as Dictionary


## Madam Eva's respec: `ch` is replaced by `fresh` (built again at level 1), who keeps `ch`'s belongings and place in
## the line; milestones let them level back up. What the road left on them stays too (QA FN-15: a rebuild wiped it):
## the Amber Temple's dark gifts (for good, benefit and cost), what lasts on them (a curse, the Raise Dead ordeal, a
## spell still running), their Exhaustion, and their attunements (a cursed item's always; the rest where the new
## build may still have them).
func respec_member(ch: Character, fresh: Character) -> void:
	var i := party.find(ch)
	if i < 0:
		return
	fresh.inventory = ch.inventory.duplicate(true)
	if not ch.dark_gifts().is_empty():
		fresh.build["dark_gifts"] = ch.dark_gifts()
	fresh.refresh()
	fresh.finish_long_rest()
	for fx: Effect in ch.effects:
		if fx.source_kind != &"feature":
			fresh.add_effect(fx)
	fresh.exhaustion = ch.exhaustion
	for item_id in ch.attuned:
		if fresh.entry_of(item_id).is_empty() or item_id in fresh.attuned:
			continue
		var cursed := MagicItems.is_cursed(Compendium.shared().item_data(item_id)) \
			and not bool(fresh.entry_of(item_id).get("curse_lifted", false))
		if cursed or fresh.attune_blocker(item_id) == "":
			fresh.attuned.append(item_id)
	fresh.items_changed()
	fresh.id = ch.id
	party[i] = fresh


## Takes `ch` out of the party for good (a sacrifice, a death nobody undoes) and remembers them.
func lose_member(ch: Character, how: String) -> void:
	var i := party.find(ch)
	if i < 0:
		return
	ch.hp = 0
	ch.dead = true
	if ch.concentration != null:
		ch.concentration.end("died")
	party.remove_at(i)
	if positions.size() > i:
		positions.remove_at(i)
	leader = clampi(leader, 0, maxi(0, party.size() - 1))
	fallen.append({"name": ch.name, "id": ch.id, "how": how, "day": day})


# --- Shops (ADR 0010) -----------------------------------------------------------------------------

## What `npc_id` sells now: [{id, name, price, qty (-1 = always), stock_id, sets, counts, rarity}], at the prices the
## merchant's attitude and a haggle make (Trade): the magic stock the party's level has opened (Trade.magic_stock),
## then the shop's own lines and any stock that changes with the days. An item made on a base the party picks ("Flame Tongue") has `bases`:
## [{id, name, lot, price}], one for each weapon or armor it can be, and `price` is the cheapest of them.
func shop_wares(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shop := Compendium.shared().get_entry("npcs", npc_id).get("shop", {}) as Dictionary
	var stock := shops.get(npc_id, {}) as Dictionary
	# The magic first (rarest last), so a long counter's few special things aren't under its rope and nails.
	var lines: Array = []
	lines.append_array(Trade.magic_stock(self, npc_id))
	lines.append_array(shop.get("sells", []) as Array)
	lines.append_array(Trade.rotation(self, npc_id))
	for e: Variant in lines:
		var w := e as Dictionary
		if not StoryConditions.check(str(w.get("if", "")), self):
			continue
		var stock_id := str(w.get("stock_id", w["id"]))
		# A shop's "level 1 spell scroll" is a particular spell, the same one each visit this playthrough.
		var id := MagicItems.specific_scroll(str(w["id"]), "%d:shop:%s" % [playthrough_seed, npc_id], Compendium.shared())
		var data := Compendium.shared().item_data(id)
		var qty := int(w.get("qty", -1))
		if qty >= 0:
			qty = int(stock.get(stock_id, qty))
		if qty == 0:
			continue
		var markup := float(w.get("markup", shop.get("markup", 1.0)))
		if w.has("bases"):
			var options: Array[Dictionary] = []
			for b: Variant in w["bases"]:
				var made := "%s%s%s" % [id, MagicItems.SEP, str(b)]
				var md := Compendium.shared().item_data(made)
				if md.is_empty():
					continue
				var mlot := StoryState.shop_lot(md)
				options.append({"id": made, "name": str(md.get("name", made)) + (" ×%d" % mlot if mlot > 1 else ""), "lot": mlot,
					"price": Trade.buy_price(self, npc_id, float(md.get("cost_gp", 0)) * mlot * markup)})
			if options.is_empty():
				continue
			var cheapest := options.reduce(func(m: Dictionary, o: Dictionary) -> Dictionary: return o if float(o["price"]) < float(m["price"]) else m) as Dictionary
			out.append({"id": id, "name": str(data.get("name", id)), "lot": 1, "price": float(cheapest["price"]), "qty": qty,
				"stock_id": stock_id, "sets": "", "counts": "", "rarity": MagicItems.rarity(data), "bases": options})
			continue
		# Ammunition comes by its bundle (20 Arrows for 1 gp, as the PHB prices them), not a piece at a time.
		var lot := StoryState.shop_lot(data)
		var base := float(w["price"]) if w.has("price") else float(data.get("cost_gp", 0)) * lot * markup
		# A pair (Sending Stones) sells whole, both pieces for the item's price.
		out.append({"id": id, "name": str(data.get("name", id)) + (" ×%d" % lot if lot > 1 else ""), "lot": 2 if bool(data.get("pair", false)) else lot,
			"price": Trade.buy_price(self, npc_id, base), "qty": qty,
			"stock_id": stock_id, "sets": str(w.get("sets", "")), "counts": str(w.get("counts", "")), "rarity": MagicItems.rarity(data)})
	return out


## How many pieces a shop deals in at once: a bundle of ammunition (20 Arrows, 50 Blowgun Needles: the item's
## `bundle`), anything else one at a time (QA FN-03: a 0.05 gp arrow rounded up to a whole 1 gp each way).
## Magic ammunition goes a piece at a time, as Sane Magical Prices prices it (+1 Arrows at 25 gp each; Ashwin,
## 2026-10-14).
static func shop_lot(data: Dictionary) -> int:
	if MagicItems.is_magic(data):
		return 1
	return maxi(1, int(data.get("bundle", 1))) if bool(data.get("stackable", false)) else 1


## What `npc_id` pays for one `item_id`, or one bundle of it (shop_lot), or one piece of a pair, after their attitude
## and a haggle; or -1 if they don't buy that kind of thing.
func shop_offer(npc_id: String, item_id: String) -> float:
	var shop := Compendium.shared().get_entry("npcs", npc_id).get("shop", {}) as Dictionary
	var data := Compendium.shared().item_data(item_id)
	if data.is_empty() or str(data.get("category", "")) == "quest":
		return -1.0
	# One piece of a pair is half the pair's price.
	var pieces := 0.5 if bool(data.get("pair", false)) else float(StoryState.shop_lot(data))
	# A merchant who sells magic items buys them, at half price, whatever else they buy (Ashwin, 2026-10-17); never a
	# story item or an artifact, which have no price.
	if MagicItems.is_magic(data) and Trade.buys_magic(self, npc_id):
		if float(data.get("cost_gp", 0)) <= 0.0 or bool(data.get("quest_locked", false)):
			return -1.0
		var rate := float(shop.get("magic_sell_rate", Trade.MAGIC_SELL_RATE))
		return Trade.sell_price(self, npc_id, snappedf(float(data["cost_gp"]) * pieces * rate, 0.01))
	var buys := shop.get("buys", []) as Array
	# No `buys`: anything; an empty list: nothing (the Order of the Silver Dragon has no use for coin).
	if (shop.has("buys") and buys.is_empty()) or (not buys.is_empty() and not str(data.get("category", "")) in buys):
		return -1.0
	return Trade.sell_price(self, npc_id, snappedf(float(data.get("cost_gp", 0)) * pieces * float(shop.get("sell_rate", 0.5)), 0.01))


## Buys one `item_id` (a bundle of ammunition) from `npc_id` for `ch`: a ware's id, or one of a made-to-order ware's
## `bases` ("flame_tongue__rapier"). Returns "" or why not.
func shop_buy(npc_id: String, item_id: String, ch: Character) -> String:
	for w in shop_wares(npc_id):
		var pick := w
		if w.has("bases"):
			var found := (w["bases"] as Array).filter(func(o: Dictionary) -> bool: return str(o["id"]) == item_id)
			if found.is_empty():
				continue
			pick = found[0] as Dictionary
		elif str(w["id"]) != item_id:
			continue
		if gold < float(pick["price"]):
			return "Not enough gold"
		gold -= float(pick["price"])
		ch.add_item(item_id, int(pick.get("lot", 1)))
		if int(w["qty"]) > 0:
			if not shops.has(npc_id):
				shops[npc_id] = {}
			(shops[npc_id] as Dictionary)[str(w.get("stock_id", item_id))] = int(w["qty"]) - 1
		# A purchase the story remembers: Bildrath's one potion, Morgantha's pastries.
		if str(w["sets"]) != "":
			set_flag(str(w["sets"]), true)
		if str(w["counts"]) != "":
			set_flag(str(w["counts"]), int(get_flag(str(w["counts"]), 0)) + 1)
		return ""
	return "Not for sale"


## Sells one `item_id` (a whole bundle of ammunition, shop_lot) from `ch` to `npc_id`, from `entry` when given (a
## particular one of several: Sell all junk leaves an equipped one of the same kind alone). Returns "" or why not.
func shop_sell(npc_id: String, item_id: String, ch: Character, entry: Dictionary = {}) -> String:
	var offer := shop_offer(npc_id, item_id)
	if offer < 0.0:
		return "They don't buy that"
	var why := ch.part_blocker(item_id)
	if why != "":
		return why
	var lot := StoryState.shop_lot(Compendium.shared().item_data(item_id))
	for e in ch.inventory:
		if str(e["id"]) == item_id and int(e["qty"]) > 0 and (entry.is_empty() or is_same(e, entry)):
			if int(e["qty"]) < lot:
				return "They only buy these %d at a time" % lot
			# Out of the pack as giving it away does, which takes it off and ends its attunement with the last one
			# (QA FN-04: a sold item's attunement stayed, and its slot with it, for good).
			for i in lot:
				ch.remove_one(item_id, e)
			gold += offer
			return ""
	return "Not carried"


# --- Guests (ADR 0010) ----------------------------------------------------------------------------

## The creature a story ally fights as: their guest_build stat block (or a pregen-style character at a set level).
static func make_guest(npc_id: String) -> Creature:
	var npc := Compendium.shared().get_entry("npcs", npc_id)
	if npc.is_empty():
		return null
	var gb := npc.get("guest_build", {}) as Dictionary
	var cr: Creature = null
	if gb.has("pregen"):
		var ch := Pregens.build(str(gb["pregen"]), int(gb.get("level", 1)))
		ch.finish_long_rest()
		cr = ch
	else:
		var data := Compendium.shared().monster_data(str(gb.get("monster", npc.get("monster", "commoner"))))
		if data.is_empty():
			return null
		cr = Monster.from_data(data)
	cr.name = str(npc.get("name", npc_id))
	cr.id = "guest_" + npc_id
	return cr


## Whether a story ally takes part in fights: true unless their NPC says `guest_fights: false` (Ireena keeps out of them:
## LocationFights.sits_out, docs/contracts/campaign.md).
static func guest_fights(npc_id: String) -> bool:
	return bool(Compendium.shared().get_entry("npcs", npc_id).get("guest_fights", true))


## Adds a story ally to the party's company. Returns false if they're already along or unknown.
func add_guest(npc_id: String) -> bool:
	if npc_id in guest_ids:
		return false
	var cr := StoryState.make_guest(npc_id)
	if cr == null:
		return false
	guest_ids.append(npc_id)
	guests.append(cr)
	_settle_ally()
	return true


func remove_guest(npc_id: String) -> bool:
	var i := guest_ids.find(npc_id)
	if i < 0:
		return false
	guest_ids.remove_at(i)
	guests.remove_at(i)
	return true


## Why a guest won't leave the party now ("" when they can): the first of the npc's `guest_stays` ([{when, why}])
## whose condition holds, else Madam Eva's ally, who sees the end through. Send home and a fall in a fight both ask
## (Ashwin, 2026-10-12).
func guest_stays(npc_id: String) -> String:
	var npc := Compendium.shared().get_entry("npcs", npc_id)
	for s: Variant in npc.get("guest_stays", []):
		var rule := s as Dictionary
		if StoryConditions.check(str(rule.get("when", "")), self):
			return str(rule["why"])
	if Campaign.module().field(self, "ally.npc") == npc_id:
		return "Madam Eva's cards named %s for the end of this, and that isn't a promise to walk away from." \
			% str(npc.get("name", npc_id))
	return ""


## Sends a guest home (the Party screen's Send home): they leave the party and wait where the party found them, and
## their own scenes there can ask them along again. False if they won't go (guest_stays) or aren't travelling.
func send_guest_home(npc_id: String) -> bool:
	if not npc_id in guest_ids or guest_stays(npc_id) != "":
		return false
	return remove_guest(npc_id)


## After a fight: guests fight on monster stat blocks and die outright at 0 Hit Points, but a guest who fell isn't
## left for dead. One who can leave is carried home to heal (out of the party, to be asked along again where the party
## found them); one who can't (guest_stays) is patched up at 1 Hit Point and stays. Returns the names carried home.
## Ashwin, 2026-10-12: Adrian fell at the winery, his figure walked on with the party, and a reload showed him gone.
func see_to_fallen_guests() -> Array[String]:
	var home: Array[String] = []
	for i in range(guests.size() - 1, -1, -1):
		var g := guests[i]
		if g.hp > 0 and not g.dead:
			continue
		var id := guest_ids[i]
		if guest_stays(id) == "":
			home.push_front(g.name)
			remove_guest(id)
		else:
			g.dead = false
			g.hp = 0
			g.heal(1)
	return home


## After a fight: the guests who came for that one fight only (their NPC's `leaves_after_fight`: Sir Klutz's ghost in
## the catacombs' crypt 33) leave the party. Returns their names.
func release_one_fight_guests() -> Array[String]:
	var gone: Array[String] = []
	for i in range(guest_ids.size() - 1, -1, -1):
		if bool(Compendium.shared().get_entry("npcs", guest_ids[i]).get("leaves_after_fight", false)):
			gone.push_front(guests[i].name)
			remove_guest(guest_ids[i])
	return gone


func _guests_to_dict() -> Array:
	var out: Array = []
	for i in guest_ids.size():
		out.append({"npc": guest_ids[i], "state": guests[i].state_to_dict()})
	return out


# --- Saving ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var members: Array = []
	for ch in party:
		members.append(ch.to_dict())
	var pos: Array = []
	for p in positions:
		pos.append([p.x, p.y])
	var benched: Array = []
	for ch in bench:
		benched.append(ch.to_dict())
	return {"party": members, "bench": benched, "leader": leader, "gold": gold, "stash": stash.duplicate(true), "flags": flags.duplicate(true),
		"quests": quests.duplicate(true), "attitudes": attitudes.duplicate(true), "visited": visited.duplicate(true),
		"codex": codex.duplicate(), "narrator": narrator.duplicate(true), "milestones": milestones, "xp": xp, "xp_reserve": xp_reserve, "start_level": start_level,
		"day": day, "minute_of_day": minute_of_day, "location": location, "positions": pos,
		"location_states": location_states.duplicate(true), "last_check": last_check, "fallen": fallen.duplicate(true),
		"seed": playthrough_seed, "tarokka": tarokka.duplicate(), "guests": _guests_to_dict(), "shops": shops.duplicate(true),
		"travel_resume": travel_resume.duplicate(), "active_spells": active_spells.duplicate(true),
		"options": options.duplicate(), "miles_since_long_rest": miles_since_long_rest,
		"approval": approval.duplicate(true), "run_stats": run_stats.duplicate(true), "bestiary": bestiary.duplicate(true)}


## A pregen loaded from a save wears its look as data/pregens has it now. The six on the roster borrowed other
## characters' art until their own was drawn, and a save made then kept the borrowed `art` (owner report 2026-10-07:
## Kip in Gunther Arasek's portrait, Thistle in Mirabel's). Only the look changes: the build, levels and choices stay
## as saved. A custom hero keeps the look the player made.
static func current_look(ch: Character) -> void:
	var app := (ch.build.get("appearance", {}) as Dictionary).duplicate()
	if bool(app.get("custom", false)):
		return
	var data := Compendium.shared().get_entry("pregens", ch.id)
	if data.is_empty():
		return
	var now := ((data.get("build", {}) as Dictionary).get("appearance", {}) as Dictionary)
	for key: String in ["art", "portrait"]:
		if now.has(key):
			app[key] = now[key]
		else:
			app.erase(key)
	ch.build["appearance"] = app


static func from_dict(d: Dictionary) -> StoryState:
	var st := StoryState.new()
	var saved := {}
	var loaded: Array[Creature] = []
	for m: Variant in d.get("party", []):
		var ch := Character.from_dict(m as Dictionary)
		if ch != null:
			st.party.append(ch)
			loaded.append(ch)
			saved[ch.id] = (m as Dictionary).get("state", {})
	Creature.relink_concentration(loaded, saved)
	for m: Variant in d.get("bench", []):
		var ch := Character.from_dict(m as Dictionary)
		if ch != null:
			st.bench.append(ch)
	for ch in st.roster():
		current_look(ch)
	st.leader = int(d.get("leader", 0))
	st.gold = float(d.get("gold", 0.0))
	for e: Variant in d.get("stash", []):
		st.stash.append((e as Dictionary).duplicate())
	st.flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	st.quests = (d.get("quests", {}) as Dictionary).duplicate(true)
	st.attitudes = (d.get("attitudes", {}) as Dictionary).duplicate(true)
	st.visited = (d.get("visited", {}) as Dictionary).duplicate(true)
	for c: Variant in d.get("codex", []):
		st.codex.append(str(c))
	st.narrator = (d.get("narrator", {}) as Dictionary).duplicate(true)
	st.milestones = int(d.get("milestones", 0))
	st.xp = int(d.get("xp", 0))
	st.xp_reserve = int(d.get("xp_reserve", 0))
	st.start_level = int(d.get("start_level", 1))
	st.day = int(d.get("day", 1))
	st.minute_of_day = int(d.get("minute_of_day", 18 * 60))
	st.location = str(d.get("location", ""))
	for p: Variant in d.get("positions", []):
		var a := p as Array
		st.positions.append(Vector2i(int(a[0]), int(a[1])))
	st.location_states = (d.get("location_states", {}) as Dictionary).duplicate(true)
	st.last_check = bool(d.get("last_check", false))
	st.miles_since_long_rest = float(d.get("miles_since_long_rest", 0.0))
	for f: Variant in d.get("fallen", []):
		st.fallen.append((f as Dictionary).duplicate())
	st.playthrough_seed = int(d.get("seed", 0))
	st.tarokka = (d.get("tarokka", {}) as Dictionary).duplicate()
	st.shops = (d.get("shops", {}) as Dictionary).duplicate(true)
	st.travel_resume = (d.get("travel_resume", {}) as Dictionary).duplicate()
	st.active_spells = (d.get("active_spells", {}) as Dictionary).duplicate(true)
	st.run_stats = (d.get("run_stats", {}) as Dictionary).duplicate(true)
	st.options.merge(d.get("options", {}) as Dictionary, true)
	st.approval = Approval.from_save(d.get("approval", {}))
	st.bestiary = (d.get("bestiary", {}) as Dictionary).duplicate(true)
	for g: Variant in d.get("guests", []):
		var gd := g as Dictionary
		var cr := StoryState.make_guest(str(gd["npc"]))
		if cr != null:
			cr.state_from_dict(gd.get("state", {}) as Dictionary)
			st.guest_ids.append(str(gd["npc"]))
			st.guests.append(cr)
	_upgrade_found_spellbook(st, "death_house_dungeon_1", "durst_footlocker", "durst_spellbook")
	_upgrade_found_spellbook(st, "amber_temple_faceless_god", "warden_cell_chest", "amber_warden_spellbook")
	_upgrade_quests(st)
	return st


## Saves made before a quest fix (Storyline QA, 2026-10-12) are mended so the journal shows where the story really is.
## A fight that now moves its quest on (a location encounter's `quest`) was won before it did: Black Roses stayed at
## "vigil" after its vampires died. A quest that an unguarded line moved back out of its ending (Izek's, by Blinsky's
## doll talk) goes back to that ending, and one moved back to its first stage (The Third Stone, by Davian's pledge) to
## the furthest it had reached; set_quest_stage refuses both now. Wiki findings 1 and 66 too: Into the Mists closes
## for a party already in the village, and the Tarokka ally's quest catches up (_settle_ally).
static func _upgrade_quests(st: StoryState) -> void:
	for loc in Compendium.shared().all("locations"):
		var won := (st.location_states.get(str(loc["id"]), {}) as Dictionary).get("encounters", {}) as Dictionary
		if won.is_empty():
			continue
		for e: Variant in loc.get("encounters", []):
			var spec := e as Dictionary
			var w: Variant = won.get(str(spec["id"]), false)   # "started" while a fight is under way, true once won
			if not spec.has("quest") or not (w is bool and w):
				continue
			var qid := str((spec["quest"] as Dictionary)["id"])
			var stage := str((spec["quest"] as Dictionary)["stage"])
			if not st.quest_ended(qid) and st.quest_stage_index(qid, st.quest_stage(qid)) < st.quest_stage_index(qid, stage):
				st.set_quest_stage(qid, stage)
	for qid: String in st.quests:
		if st.quest_ended(qid):
			continue
		var stages := Compendium.shared().get_entry("quests", qid).get("stages", []) as Array
		var now := st.quest_stage_index(qid, st.quest_stage(qid))
		var furthest := now
		for h: Variant in ((st.quests[qid] as Dictionary).get("history", []) as Array):
			var i := st.quest_stage_index(qid, str(h))
			furthest = maxi(furthest, i)
			if i > now and str((stages[i] as Dictionary).get("ends", "")) != "":
				(st.quests[qid] as Dictionary)["stage"] = str(h)   # back to the ending it was moved out of
		if now == 0 and furthest > 0 and not st.quest_ended(qid):
			(st.quests[qid] as Dictionary)["stage"] = str((stages[furthest] as Dictionary)["id"])   # started over by mistake
	# Into the Mists closed only when Rose and Thorn were spoken to; a party already past them is past the mists.
	if st.quests.has("into_the_mists") and not st.quest_ended("into_the_mists") \
			and (st.visited.has("village_of_barovia") or st.visited.has("death_house_ground")):
		st.set_quest_stage("into_the_mists", "village_edge")
	# Ireena's escort put back to Ready by her asking again after the quiet burial (Wiki finding 74; saves from 1.0.3 and
	# 1.0.4): back to the answer the party had given.
	var esc := st.quests.get("escort_ireena", {}) as Dictionary
	if str(esc.get("stage", "")) == "ready":
		var said := esc.get("history", []) as Array
		var back := ""
		if "departed" in said:
			back = "departed"
		elif "accepted" in said and ("ireena" in st.guest_ids or not "declined" in said):
			back = "accepted"
		elif "declined" in said:
			back = "declined"
		if back != "":
			esc["stage"] = back
	# Madam Eva handed her treasure over without marking it found, so her chest held a second copy (Wiki finding 63).
	if bool(st.get_flag("tser_treasure_given", false)):
		for slot: String in Campaign.module().treasures_at("tser_pool_eva_tent", st):
			st.set_flag("treasure_found_" + slot, true)
	st._settle_ally()
	# A quest an earlier version left stuck closes on load when its data says so (`closes` with `old_saves`): the journal
	# only, no notice. Clocks and departures never run on load: an old save has no honest start time.
	QuestClosures.sweep(st, {"load": true})


## Saves from before found spellbooks listed their spells: a container that held a plain "spellbook" now holds a
## book with spells in it (owner, 2026-10-07: the Dursts' footlocker in Death House; Ashwin, 2026-10-18: a warden's chest
## at the Amber Temple). Swap it for that book wherever it went: still in the container, carried by someone who isn't a
## Wizard (a Wizard's own book stays theirs), or in the stash.
static func _upgrade_found_spellbook(st: StoryState, loc_id: String, container_id: String, book_id: String) -> void:
	var ls := st.location_states.get(loc_id, {}) as Dictionary
	if ls.is_empty():
		return
	var left := (ls.get("contents", {}) as Dictionary).get(container_id, {}) as Dictionary
	for it: Variant in left.get("items", []):
		if str((it as Dictionary)["id"]) == "spellbook":
			(it as Dictionary)["id"] = book_id
			return
	if left.is_empty() and not bool((ls.get("looted", {}) as Dictionary).get(container_id, false)):
		return
	if st.party_has_item(book_id):
		return
	var everyone: Array[Character] = []
	everyone.append_array(st.party)
	everyone.append_array(st.bench)
	for ch in everyone:
		if ch.spellbook_class() != "":
			continue
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == "spellbook" and int(e.get("qty", 1)) == 1:
				e["id"] = book_id
				return
	for e: Dictionary in st.stash:
		if str(e["id"]) == "spellbook" and int(e.get("qty", 1)) == 1:
			e["id"] = book_id
			return
