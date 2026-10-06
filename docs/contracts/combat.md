# Combat contract (ADR 0007)

How the scene, the HUD and tests talk to a fight. Everything here lives in `combat/` and is pure logic.

## Building a fight

- `EncounterSetup.load_id(id, dice)` reads `data/encounters/<id>.json` (schema: `data/schemas/encounter.schema.json`):
  `map.rows`, `party` (pregen id, cell, `precast` spells), `enemies` (monster id, cell, optional name and side),
  `party_level`, `difficulty` (checked against the 2024 XP budget by `make validate`), `surprised`.
- Or by hand: `Encounter.new(grid, dice)`, `add(creature, side, cell)` (side: party, guest, enemy, neutral), then
  `start(surprised_ids)`.

## Commands (all return `CombatResult`: `ok`, `reason`, `pending`, `hit`, `critical`, `damage`, `killed`)

| Command | Notes |
|---|---|
| `move(c, cell)` | Cheapest legal path; stands up first if Prone; may pause for Opportunity Attacks or readied attacks |
| `attack(c, target, option_id)` | `option_id` from `attack_options(c)` (`weapon:<item>`, `thrown:<item>`, `monster:<action>`) |
| `offhand_attack(c, target, option_id)` | Light property extra attack (Bonus Action, or free with Nick) |
| `monster_attack(c, target, action_id)`, `begin_multiattack(c)` | Stat-block attacks |
| `dash/disengage(c, use_bonus)`, `dodge`, `help_attack(c, enemy)`, `hide(c, use_bonus)`, `search`, `study(c, t)` | Standard actions; `use_bonus` needs Cunning Action |
| `ready_attack(c, option_id)` | Readied attack, triggers when an enemy comes into reach |
| `unarmed_special(c, t, "grapple" / "shove_prone" / "shove")`, `escape_grapple(c)` | |
| `stand_up(c)`, `drop_prone(c)`, `stabilize(c, t, use_kit)`, `death_save(c)` | |
| `spells.cast(c, spell_id, slot, targets, point, direction, opts)` | `point` for spheres, `direction` for cones, cubes and lines from the caster; opts: `word` (Command), `damage_type` |
| `spells.use_sustained(c, action_id, targets, point, direction)` | a sustained spell action (`spells.sustained_actions(c)`): Spiritual Weapon's strike, Witch Bolt's arc, Flaming Sphere's roll... |
| `spells.spiritual_weapon_attack(c, t, cell)` | shortcut for the weapon's strike |
| `ready_spell(c, spell_id, slot)` | Ready a one-action spell: cast now, held with Concentration, released at the first enemy in range |
| `features.toggle_rider(c, rider_id)` | arm a rider for this turn's next hit (`features.rider_options(c)`): maneuvers, Cunning Strike, Giant Ancestry, Psionic Strike |
| `feature_actions.perform(c, id, t, point)` | a class, subclass, feat or species action (`feature_actions.list(c)`); the eight Phase 4 classes' actions are `cf:<id>`, run by combat/class_features.gd |
| `free_move(c, cell)`, `jump(c, cell)` | movement without Opportunity Attacks from a feature; Jump's 30 ft leap |
| `escape_effect(c, effect_id)`, `wake(c, t)`, `haste_action_use(c, what, t, option_id)`, `use_item(c, item_id, t)` | breaking free of Web/Entangle, shaking a sleeper awake, Haste's extra action, potions and Goodberries |
| `features.second_wind / action_surge / steady_aim / turn_undead / divine_spark / preserve_life` | |
| `end_turn()` | Rolls a pending Death Saving Throw, end-of-turn effects and repeated saves, next creature |
| `run_ai_turn()` | Plays the current AI creature's turn (may pause for player reactions) |
| `answer_reaction(use)` | Resumes a paused command |

Queries: `current()`, `order`, `living()`, `hostiles_of(c)`, `distance(a, b)`, `cover(a, b)`, `can_see(a, b)`,
`reachable_for(c)`, `attack_situation(c, t, option)`, `hit_chance(c, t, option)`, `needs_death_save(c)`.

## Reaction prompts (`ReactionRequest`)

`kind` (opportunity_attack, shield, uncanny_dodge, readied_attack, heroic_inspiration, hellish_rebuke, storms_thunder,
sentinel, reactive_strike, warding_flare, protection, lucky, precision_attack, guided_strike, defensive_duelist,
illusory_self, riposte, parry, stones_endurance, interception, protective_field, projected_ward, homing_strikes),
`reactor_id`, `trigger_id`,
`title`, `text` (the trigger with its numbers), `cost`. A player-controlled creature's
`reaction_rules[kind]` = ask (default) / auto / never decides whether it's asked.

## Events (`Encounter.drain_events()`)

| type | fields |
|---|---|
| move | id, from, to, forced |
| attack | attacker, target, hit, critical |
| damage / heal | id, amount (critical) |
| condition / down / death | id |
| death_save | id, success |
| spell | caster, spell, cells, targets |
| summon | caster, cell (Spiritual Weapon) |
| object / object_gone | id, kind, cell: a spell object or lingering area appeared, moved or ended (`spells.zones.objects`) |
| teleport | id, from, to (Misty Step, Bait and Switch, Engulf) |
| summon_creature / vanish | id: a summoned creature (Summon Undead, a severed limb) joined; a creature vanished |
| resize | id: Enlarge/Reduce or Large Form changed its size |
| turn | id, round |
| round | round |
| over | outcome (victory, defeat) |

## The hotbar (`ActionCatalog`)

`actions_for(c)` returns entries `{id, tab, label, sub, cost, legal, reason, targeting, count, repeat, range,
spell_id, slot, option_id, kind, help, opts}`; `perform(c, action, targets, point, direction, slot)` carries one out.
Previews: `attack_preview(c, action, t)`, `spell_preview(c, action, point, direction, slot)`,
`move_preview(c, cell, move_reach(c))`, `slot_choices(c, spell_id)`, `target_why(c, action, t)`.
