class_name StrahdCampaign
extends CampaignModule
## Curse of Strahd's answers to the story engine (CampaignModule): the Tarokka reading, Strahd's attention and visits,
## the field spells that read the valley, the endings. Each one hands over to the module that holds the rule.


func fill(text: String, st: StoryState) -> String:
	return Tarokka.fill(text, st)


func field(st: StoryState, path: String) -> String:
	return Tarokka.field(st, path)


func final_room(st: StoryState) -> String:
	return Tarokka.final_room(st)


func treasures_at(place: String, st: StoryState) -> Array[String]:
	return Tarokka.treasures_at(place, st)


func take_from(place: String, st: StoryState) -> Array[String]:
	return Tarokka.take_from(place, st)


func treasure_name(item_id: String) -> String:
	for slot: String in Tarokka.TREASURE_ITEMS:
		if str(Tarokka.TREASURE_ITEMS[slot]) == item_id:
			return str(Tarokka.SLOT_NAMES[slot])   # "The Sunsword", as Madam Eva names them
	return ""


func ensure_drawn(st: StoryState) -> void:
	Tarokka.ensure_drawn(st)


func reading(slot: String, st: StoryState) -> Dictionary:
	Tarokka.ensure_drawn(st)
	var card_id := str(st.tarokka.get(slot, ""))
	if card_id == "":
		return {}
	var o := Tarokka.outcome(slot, card_id)
	return {"card": card_id, "slot": slot, "verse": str(o.get("verse", "")),
		"title": "%s: %s" % [Tarokka.SLOT_NAMES.get(slot, slot), Tarokka.card(card_id).get("name", card_id)]}


func presence_tier(st: StoryState) -> Dictionary:
	return StrahdPresence.tier(st)


func presence_tier_min(name: String) -> int:
	return StrahdPresence.tier_min(name)


func presence_attention(st: StoryState) -> int:
	return StrahdPresence.attention(st)


func night_between(start: int, end: int) -> bool:
	return StrahdPresence.night_between(start, end)


func visit_may_fight(st: StoryState, on: String, ctx: Dictionary) -> bool:
	return StrahdPresence.may_fight(StrahdPresence.find(st, on, ctx))


func place_visitors(enc: Dictionary, rows: Array, taken: Array[Vector2i], near: Vector2i) -> Dictionary:
	return StrahdPresence.placed(enc, rows, taken, near)


func handles_spell(spell_id: String) -> bool:
	return spell_id in Oracles.HANDLED


func cast_spell(st: StoryState, caster: Character, spell_id: String, choice: String = "") -> String:
	return Oracles.cast(st, caster, spell_id, choice)


func request_ending(st: StoryState) -> void:
	Endings.request(st)


# --- Fights and places --------------------------------------------------------------------------------------------

func parley_ref() -> String:
	return "strahd/final:parley"   # Strahd parleys before a final battle, when it's written and hasn't been answered


func parley_speaker() -> String:
	return "strahd"


func parley_answer(st: StoryState) -> String:
	return str(st.get_flag("strahd_parley", ""))


## `fight` or unset lets the battle start; `yield` and `ireena` leave it to the ending.
func parley_allows_fight(st: StoryState) -> bool:
	return parley_answer(st) in ["", "fight"]


func treasure_spots(loc: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for place: String in Tarokka.spots(loc):
		out.append(place)
	return out


func take_treasure(loc: Dictionary, kind: String, id: String, st: StoryState) -> Array[String]:
	return Tarokka.take_from(Tarokka.place_for(loc, kind, id), st)


func final_battle_begun(st: StoryState) -> void:
	if st.quest_stage_index("strahds_lair", st.quest_stage("strahds_lair")) < st.quest_stage_index("strahds_lair", "confronted"):
		st.set_quest_stage("strahds_lair", "confronted")


func fight_start_keys() -> Array[String]:
	return ["combat:sunsword_start"]   # the Sunsword, while carried (narrative/narrator/sunsword.dialogue)


func fight_victory_keys() -> Array[String]:
	return ["combat:sunsword_victory"]


func guard_monster() -> String:
	return "vallaki_guard"


func spring_trap(st: StoryState, location_id: String, cell: Vector2i, ft: int = 30) -> Dictionary:
	return Oracles.spring_trap(st, location_id, cell, ft)


func open_way(st: StoryState, location_id: String, cell: Vector2i, ft: int = 30) -> Dictionary:
	return Oracles.open_way(st, location_id, cell, ft)


# --- Endings and achievements -------------------------------------------------------------------------------------

func defeat_text() -> String:
	return "Barovia keeps what it takes. Load a save to try again."


func endings() -> Array[Dictionary]:
	return Endings.all()


func ending(id: String) -> Dictionary:
	return Endings.get_ending(id)


func extra_achievements() -> Dictionary:
	return {"skirmish_strahd": ["Dress Rehearsal", "Defeat Strahd in a Skirmish."]}


func skirmish_achievements(foe_monsters: Array[String]) -> Array[String]:
	return ["skirmish_strahd"] if "strahd_von_zarovich" in foe_monsters else ([] as Array[String])
