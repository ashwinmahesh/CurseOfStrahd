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
