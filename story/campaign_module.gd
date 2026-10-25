class_name CampaignModule
extends RefCounted
## What the story engine asks of the campaign it runs (docs/plans/engine_split.md). The engine names no campaign: where a
## story rule needs a fact only the campaign knows (a reading of the cards, a villain's attention, a field spell that
## reads the place, how the game ends), it asks the module `Campaign.module()` hands back. This base answers for a
## game with no such things: nothing is hidden anywhere, no one is watching, every spell is ordinary, the game never
## ends by itself. A campaign extends it and says which script in data/campaign.json (Curse of Strahd:
## story/strahd_campaign.gd).


# --- Text and facts the story data reaches for ------------------------------------------------------------------

## `text` with the campaign's {placeholders} filled from the story (quest journals, hints, warnings).
func fill(text: String, _st: StoryState) -> String:
	return text


## One fact of the campaign's own state, by dotted path (`ally.npc`); "" when there is none.
func field(_st: StoryState, _path: String) -> String:
	return ""


## The room the campaign's last fight waits in, or "".
func final_room(_st: StoryState) -> String:
	return ""


## The treasure ids hidden at `place` that the party hasn't taken.
func treasures_at(_place: String, _st: StoryState) -> Array[String]:
	return []


## Takes them: marks them found and returns their item ids.
func take_from(_place: String, _st: StoryState) -> Array[String]:
	return []


## The name the campaign gives one of its treasures ("The Sunsword"), or "" for any other item.
func treasure_name(_item_id: String) -> String:
	return ""


## Makes sure the campaign's reading (the story's seeded draw) exists.
func ensure_drawn(_st: StoryState) -> void:
	pass


## One slot of the reading, as {card, slot, title, verse} to show; {} when the slot holds nothing.
func reading(_slot: String, _st: StoryState) -> Dictionary:
	return {}


# --- A villain's attention ---------------------------------------------------------------------------------------

## The tier of attention the party has earned (its data: road_day, road_night, ...), or {}.
func presence_tier(_st: StoryState) -> Dictionary:
	return {}


## The attention level a named tier starts at, or -1 when there is none.
func presence_tier_min(_name: String) -> int:
	return -1


func presence_attention(_st: StoryState) -> int:
	return 0


## Whether `start` to `end` (minutes) spans a night.
func night_between(_start: int, _end: int) -> bool:
	return false


## Whether a visit due on `on` (for example "rest") with `ctx` would come to blows.
func visit_may_fight(_st: StoryState, _on: String, _ctx: Dictionary) -> bool:
	return false


## `enc` with its monsters placed on open ground near `near` (a visit finds room even on a crowded road).
func place_visitors(enc: Dictionary, _rows: Array, _taken: Array[Vector2i], _near: Vector2i) -> Dictionary:
	return enc


# --- Spells that read the place ----------------------------------------------------------------------------------

func handles_spell(_spell_id: String) -> bool:
	return false


## What the field spell tells, cast by `caster` where the party stands.
func cast_spell(_st: StoryState, _caster: Character, _spell_id: String, _choice: String = "") -> String:
	return ""


# --- How the game ends -------------------------------------------------------------------------------------------

## Records the ending that holds now (a dialogue's `end_game`).
func request_ending(_st: StoryState) -> void:
	pass
