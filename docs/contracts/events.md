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
