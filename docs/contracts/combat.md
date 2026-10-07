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

## Reusable feature and spell responses

`FeatureRecipes` supplies data-defined activations and synchronous failed-D20 responses through `FeatureActions`. Save-based damage reduction is shared by ordinary spells, zones and monster actions. Magical monster saves carry a magic key when the action declares `magical`.

Reaction offers may provide `stop_if` alongside `stop`: after `use`, the continuation stops only when the predicate is true. This allows an interrupted Shield to spend its Reaction while the original hit continues. Spell casting gates run after casting time is consumed and before slot payment or concentration replacement.

Action targeting `points` collects `count` distinct grid positions into `opts.points`; selecting an already chosen position deselects it. Invalid summon spaces are rejected during selection. Multi-creature feature and sustained-action selections read the action's own `count` instead of a spell's target count. `Combatant.record_step` records a straight voluntary run; attacks consume that run, and teleports/forced movement clear it. Charge checks use distance actually closed during this run.

`feature.hit_response` offers a Reaction after an attack hit survives hit-negating defenses. It spends `resource`, forces a save against the feature class’s spell DC, and applies `effects` on failure through the shared effect engine. `range` and `requires_sight` are opt-in restrictions. Weapon/monster attacks pause for the normal reaction prompt; synchronous spell attacks use the current auto/never response policy. The original hit still resolves if the attacker is Stunned by the response.

Triggered selections reuse `ReactionRequest.target_choices` (`id`, `label`) and `selected_ids`; `spends_reaction: false` changes the prompt and log wording without consuming a Reaction. The encounter remains paused, the HUD allows explicit selection of each candidate, and the continuation revalidates targets. `TriggeredFeatures` reads `feature.cast_form` to expose a casting variant (`opts.cast_form` = feature id) for its named concentration `spell`, checking and spending `resource`. Its `modifiers` attach to that casting’s concentration and duration. An optional `pulse` declares `radius`, `dice` and damage `type`, offered on adoption and each own turn start. Frozen Haunt supplies these values in subclass data. Automatic selection affects enemies; the prompt can select or spare any eligible creature.

`incorporeal_occupied` allows ending movement in another creature’s space and makes those spaces Difficult Terrain. A casting form’s optional `embedded_damage` declares the dice and type for ending a turn inside a creature or solid terrain. `shunt_on_end` searches the whole battlefield for the nearest free footprint when the form ends. The effect stores its recipe and class provenance; its callback is restored on loading a fight.

Feature activations may specify `save` (against the feature class’s spell save DC) and `target_perceives_caster`. Save keys include magical effects and imposed conditions. Effect `params.tether` stores a range and optional `perceive_caster` requirement; leaving range or losing both sight and hearing ends that effect. Hypnotic Presence uses this together with damage-ending and primary-condition linkage, without requiring Concentration.

Activations may require `unarmored` and allow `dismissible` effects. Effect parameters `ends_when_incapacitated`, `ends_on_two_handed_attack` and `ends_when_armored` end the effect when their condition occurs, including equipping armor or a Shield. Bladesong consumes its Bonus Action and resource, lasts one minute, and restores one use when Arcane Recovery is consumed.

The `attack_cantrip` feature recipe (optional `class` filter) and legacy War Magic use validated `opts.war_magic`, consuming one Attack-action attack rather than a Magic action. Only one cantrip substitution is allowed in that Attack action; a new action or turn resets the marker. Bladesinger requires a Wizard cantrip. The `after_cast_attack` recipe matches `casting_time`, then grants a Bonus Action attack with data-defined `allow_ranged` and `weapons_only` restrictions. Its eligibility is tied to that specific bonus attack and cleared when used or at turn start. Song of Victory supplies this recipe, allowing ranged weapons and excluding Unarmed Strikes.


`slot_exchange` feature recipes declare a resource, free slot-to-resource conversion, and a table of slot recovery costs and class-level gates. `Character` validates exchanges and caps restored resources; spell slot conversion does not count as casting a slotted spell. Recovery opens only at a declared event (`short_rest` or `uncanny_metabolism`), restores at most one expended slot per feature per event, and supports ordinary and Pact Magic slots. The rest screen closes the window on exit; combat offers end the window after acceptance or declining all choices, without spending a Reaction.

`on_feature_target` applies ordinary effect entries after a declared feature targets a creature. `stunning_strike` emits this event after either save outcome. A modifier's `on` or `value` suffix `:caster` resolves to the source combatant's id. Spell saves carry `save_vs:spell:<caster id>` alongside spell/magic keys, including shared, special, repeated and zone saves; non-spell feature saves do not acquire spell provenance. Focused Strike uses a caster-specific disadvantage effect ending at its caster's next turn start.

`spell_sequence` declares eligible casting classes and base spell levels, a Bonus Action resource cost, and subsequent attacks. A selected `opts.spell_sequence` validates the spell and targets before paying; it spends the Bonus Action, resource and normal casting costs, preserving the normal action. Follow-up attacks use the normal attack resolver, validate before consumption, and expire at turn start. `attack_tag` identifies the existing attack context (such as Flurry) only while that strike resolves. Improved Mystic Fighting Style trades two Flurry attacks for an action-time level 1–2 Sorcerer spell, leaving one Unarmed Strike; upcasting uses the normal spell-slot rules.


### Resource-funded spellcasting

`feature.resource_cast` selects a prepared spell by school and, with `subclass_spells`, membership in that
class's subclass spell table. `resource`/`cost` replace slot payment; `casting: action` supplies the feature's
Magic action even for a spell that ordinarily takes longer. `omit_material: true` removes Material components
from this casting. The cast uses its prepared class's ability, at base level, retaining targeting, concentration,
and the other spell rules. It neither spends a slot nor changes the one-slot-spell-per-turn marker. Target and
eligibility failures consume nothing. Resource casting cannot combine with another payment or attack-substitution
feature. The combat catalog and exploration spell controls expose the same recipe; exhausted uses remain visible.
Exploration continues to use the existing field spell handlers; this recipe does not add missing spell effects.

The `spell_sequence.max_level` limit applies to the effective level of the actual casting, including upcasting
and effects that raise that level. Catalog slot choices and engine validation enforce the same cap before costs.
