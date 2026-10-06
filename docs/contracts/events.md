# EventBus signals (core/event_bus.gd)

| Signal | Emitted by | Meaning |
|---|---|---|
| mode_changed(old, new) | ModeController | Play mode switched (Exploration, Dialogue, Combat, Rest, Travel, Cutscene) |
| roll_made(entry) | Dice | Any die rolled: {reason, sides, rolls} |
| leader_changed(index) | GameState / PartyController | Exploration leader changed |
| location_entered(id) | world (Phase 3) | For the Narrator and quests |
| flag_changed(flag, value) | GameState.set_flag | Story flag set |
| game_saved(slot) / game_loaded(slot) | SaveSystem | Save file written / read |
| scene_changed(path) | SceneRouter | Level changed |

## Rules events (Creature.events, drained with drain_events())

Plain dictionaries from the rules library (ADR 0003). Every event has `type` and `creature` (the creature's id).

| type | Extra fields | When |
|---|---|---|
| d20 | text | any D20 Test rolled through the creature (combat-log line) |
| damage | amount, damage_type, text | damage taken (after defenses), with the full explanation |
| healed / temp_hp | amount, source | Hit Points restored / Temporary Hit Points gained |
| condition_applied / condition_removed / condition_immune | condition, source | |
| exhaustion | level | Exhaustion level changed |
| effect_added / effect_removed | effect | |
| concentration_started / concentration_ended | source, reason | |
| died / stable | reason | |
| short_rest / long_rest / level_up | class, level | |
