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
| `items.use(c, item_id, power_id, targets, point, direction, level, opts)` | a magic item's power (ADR 0012, docs/contracts/magic_items.md): a wand's spell at a level paid in charges, a potion, a toggle, a custom power; `items.list(c)` is the Items tab |
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

## Bosses: legendary and lair actions, forms, Misty Escape, withdrawing (ADR 0014, combat/legendary.gd)

Stat-block fields any monster can use (`data/schemas/monster.schema.json`; Strahd's block is the reference):

| field | shape | what the engine does |
|---|---|---|
| `legendary_actions` | `{per_round, options: [{id, name, cost, action \| move, summary}]}` | `per_round` uses, refreshed at the start of its own turn (full at the start of the fight); one option at the end of each other creature's turn, chosen by the AI. `action` names one of its actions (an attack, or a save action), `move: true` moves up to its Speed without Opportunity Attacks. `cost` defaults to 1. Not while Incapacitated. |
| `legendary_resistance` | uses per day (per fight) | a failed saving throw becomes a success while uses last |
| `lair_actions` | `[{id, name, kind, summary, ...}]` | with the encounter's `lair: true`: one on initiative count 20, losing ties (after everyone at 20 or more, before the rest), never the same twice in a row, by a lair master that can act. `kind`: `self` (`modifiers` on the master until the next lair turn), `attack` (`attack.bonus`, `damage`, `on_hit` at a foe it can see within `attack.range`, default 120), `save` (`save`, `targets` {range from the master, count, max_size, types}, `damage`, `on_fail` riders, `summon` on a failure: e.g. the target's shadow, acting on initiative 20), `summon` (`summon: {monster, count, max}` beside the master), `text` (told only). |
| `regenerates` | `{hp, stopped_by: [damage types], running_water: bool, sunlight: bool}` | any monster (Strahd, trolls, vampires): `hp` back at the start of its turn while it has at least 1 Hit Point, unless it took a `stopped_by` type since its last turn, or stands in running water (a `WATER` square it isn't flying over, or the `in_running_water` flag) or sunlight when those are true |
| `forms` | `{base, change: action \| bonus_action, blocked_in, shapes: [{id, name, size, speed, actions, immunities, resistances, vulnerabilities, condition_immunities, save_advantage, flags, art}]}` | a shape keeps its Hit Points and swaps size, speeds, the actions it can use (`actions: []` = none, so no attacks or spells) and defenses. Actions may still carry their own `forms` list, naming `base` for the true form. |
| `misty_escape` | `{resting_place, flag, form, narration, destroyed_flag, quest: {id, stage}, blocked_in}` | at 0 Hit Points anywhere but its `resting_place` (a location id, or a place inside one: `Encounter.at_place`): it turns to mist (`form`, default mist), leaves the fight, `flag` is set and the Narrator says `narration`; at its resting place, or in sunlight or running water, it is destroyed (`destroyed_flag`, `quest` moved to `stage`) |
| `ward` | `{hp, unless, region}` | LocationView gives it `hp` of ward (taken before Temporary Hit Points and Hit Points) in a fight in `region`, unless the story condition `unless` holds: Strahd's is the Heart of Sorrow's 50, gone once `heart_of_sorrow_shattered` is set |
| action `summon` | `{choices: [{monster, count (int or dice), max, where: any \| outdoors \| indoors}], arrive (rounds, int or dice), not_in}` | Children of the Night: the first choice allowed where the fight is, arriving at the start of a later round beside the summoner and acting after it |
| action `targets.requires` | conditions | on an attack action too: only targets with one of them (a vampire's Bite) |
| rider `repeat_save` | `{ability, dc, when: end \| start \| manual, on_damage}` | a condition the target can shake off (Charm: a new save whenever it takes damage) |
| `ai_profile: strahd` | | see below |

Trait ids the code reads for `"implemented": "engine"`: `legendary_resistance`, `regeneration`, `shapechanger`,
`misty_escape`, `children_of_the_night`, `charm`, `spider_climb`, `vampire_weakness`.

Encounter fields (a location's `encounters[]`, `data/schemas/location.schema.json`): `allies_block: true` (also on the location: party members can't pass through each other; by default they can, as Difficult Terrain), `lair: true`,
`final_battle: "<enemy room id>"` and `withdraw: {who, at_hp_below, after_rounds, flag}` (the foe `who` leaves below
that many Hit Points, or at the start of its turn once `after_rounds` rounds have passed; never dies while it can
withdraw; no loot). On an Encounter: `lair`, `location_id`, `places` (the location's Tarokka places and the final
battle's room), `outdoors`, `legendary.withdraws`; all are kept in a round's save.

What a fight hands back to the story (`Encounter.legendary`): `story_flags` (flag -> value: Misty Escape's flag, a
withdrawal's flag, `strahd_destroyed`), `story_quests` (quest -> stage), `departed` (creature id -> `mist` or
`withdraw`). LocationView applies them when the fight ends, whatever the outcome; a creature that departed leaves no
remains, and a fight where every foe left without one dying gives no `loot` (a Tarokka treasure there is still found).

The final battle (LocationView): an encounter with `final_battle` also needs `StoryConditions.final_battle_condition(room)`
(`final_room:<room> and quest.strahds_lair >= foretold and not flag.strahd_destroyed`; `encounter_when(spec)` joins it
to the entry's own `when`). Before it starts, `strahd/final:parley` plays (when the file has that node) unless
`strahd_parley` is already set; the fight starts when `strahd_parley` is `fight` or unset, and `strahds_lair` moves
to `confronted`. `yield` and `ireena` start nothing (the ending takes over). `LocationView.last_encounter` is the spec of the fight
that just ended (its `final_battle` decides the ending after a wipe, story/endings.gd).

The Tarokka (story/tarokka.gd): the card `mists` (room `castle_ravenloft`, `Tarokka.ROAM_ROOM`) sends him roaming;
`draw()` stores the room picked from the seed as the reading's `enemy_roam` key, read as `tarokka.enemy.roam`
(a reading saved before the pick finds the same room from the seed). `Tarokka.final_room(st)` and the condition
`final_room:<room>` give the room he waits in.

### The `strahd` AI profile (combat/ai/boss_brain.gd)

Strikes the weakest foe or the one carrying the Sunsword, the Holy Symbol of Ravenkind or the Tome of Strahd; bites
whoever he holds; charms a strong foe (a save action whose failure Charms) when no one is charmed by him; calls the
Children of the Night once when two or more foes stand; uses legendary Moves to get out of reach when hurt and
legendary strikes otherwise; below a quarter of his Hit Points with Regeneration working, takes mist form and keeps
away until he is back over half. Withdrawing turns him to mist (or a bat) as he goes.

Events: `legendary` (id, option, name, left), `lair` (id, action, name), `form` (id, form, art: the token wears the
shape's sprite when it exists), `vanish` (id, left: mist or withdraw, narration) for a creature leaving the fight.
The initiative tracker shows a legendary creature's actions left (◆◇) and the lair's card at count 20.
