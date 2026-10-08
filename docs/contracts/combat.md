# Combat contract (ADR 0007)

How the scene, the HUD and tests talk to a fight. Everything here lives in `combat/` and is pure logic.

## Where the code lives

`Encounter` and `SpellCaster` hold the fight's state. Each job is a helper in a file of its own, which the owner makes
in `_init` and forwards its commands to, so the calls below don't change and a lane can own a whole file. New code goes
in the helper whose job it is; a function other files call gets a one-line forwarder on the owner.

| Job | File (`e.<var>` / `e.spells.<var>`) |
|---|---|
| Initiative, turns and rounds, the end of the fight, AI turns, the action economy's checks | `encounter_turns.gd` (`turns`) |
| Sight, light, obscurement, invisibility, cover | `encounter_sight.gd` (`sight`) |
| Reachable squares, moving and what each step sets off, forced movement, Jump | `encounter_movement.gd` (`movement`) |
| Mounted combat | `encounter_mounts.gd` (`mounts`) |
| Grapple and Shove | `encounter_grapples.gd` (`grappling`) |
| Attack options, legality, ammunition, thrown weapons | `encounter_weapons.gd` (`weapons`) |
| Attacks: Advantage and cover, the roll and its stages, hits and misses, Opportunity and readied attacks | `encounter_attacks.gd` (`attacks`) |
| Damage and healing dice, dealing damage, Death Saving Throws, stabilizing | `encounter_damage.gd` (`damage`) |
| Reaction decisions and answers, the queued reactions | `encounter_reactions.gd` (`reaction_flow`) |
| Standard actions, hiding, effects' actions (escape, douse, wake), Haste's action | `encounter_actions.gd` (`actions`) |
| Taking back a move | `encounter_undo.gd` (`undo`) |
| Casting: paying, checking targets, resolving the recipe | `spell_casting.gd` (`casting`) |
| What can be cast, casting numbers, Metamagic | `spell_options.gd` (`options`) |
| Reaction spells, releasing a readied spell | `spell_reactions.gd` (`reaction_spells`) |
| Range, target counts, areas | `spell_targeting.gd` (`targeting`) |
| Spell attacks | `spell_attacks.gd` (`attacks`) |
| Spell damage, healing, Temporary Hit Points | `spell_damage.gd` (`damage`) |
| Saving throws against spells, repeated saves, pushes | `spell_saves.gd` (`saves`) |
| Effects from the data recipe | `spell_effects.gd` (`effects`) |
| Spells with handlers of their own (`SpellCaster.SPECIAL`) | `spell_handlers.gd` (`handlers`) |
| Zones, walls and spell objects | `spell_placement.gd` (`placement`) |
| Sustained actions | `spell_sustained.gd` (`sustain`) |
| Summons | `spell_summons.gd` (`summons`) |
| Turn, damage and movement hooks | `spell_turns.gd` (`turn_hooks`) |

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
| `unarmed_special(c, t, "grapple" / "shove_prone" / "shove")`, `escape_grapple(c)`, `release_grapple(c, t)` | a grappler drags what it holds when it moves (1 extra foot per foot); letting go is free |
| `stand_up(c)`, `drop_prone(c)`, `stabilize(c, t, use_kit)`, `death_save(c)` | |
| `fall(c, feet)` | 1d6 per 10 ft (20d6 at most), Prone unless unharmed; Slow Fall and Feather Fall answer it. `forced_move` calls it for a ledge, and `movement.fall_away` for a map's open drop (`grid.drop_ft`, from the map's `drop_ft`): the creature leaves the grid (`left_fight` meta) |
| `spells.cast(c, spell_id, slot, targets, point, direction, opts)` | `point` for spheres, `direction` for cones, cubes and lines from the caster; opts: `word` (Command), `damage_type` |
| `spells.use_sustained(c, action_id, targets, point, direction)` | a sustained spell action (`spells.sustained_actions(c)`): Spiritual Weapon's strike, Witch Bolt's arc, Flaming Sphere's roll... |
| `spells.spiritual_weapon_attack(c, t, cell)` | shortcut for the weapon's strike |
| `ready_spell(c, spell_id, slot)` | Ready a one-action spell: cast now, held with Concentration, released at the first enemy in range |
| `features.toggle_rider(c, rider_id)` | arm a rider for this turn's next hit (`features.rider_options(c)`): maneuvers, Cunning Strike, Giant Ancestry, Psionic Strike |
| `feature_actions.perform(c, id, t, point)` | a class, subclass, feat or species action (`feature_actions.list(c)`); the eight Phase 4 classes' actions are `cf:<id>`, run by combat/class_features.gd |
| `free_move(c, cell)`, `jump(c, cell)` | movement without Opportunity Attacks from a feature; Jump's 30 ft leap |
| `undo_move(c)`, `can_undo_move(c)` | Takes back `c`'s last move (`move`, `free_move`, `jump`, with the mount or rider that went along) while nothing came of it: no die rolled, no reaction offered (even one declined or passed up), nothing queued, no other creature, zone, spell object, mark or grapple changed, no log line but the move's own, and nothing new seen (the mover not spotted, no foe the party couldn't see in sight now). Moves come back one by one, to the last thing that wasn't a move; anything else ends them. Player-controlled creatures on their own turn only; not saved |
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

### Choices after a D20 Test (F6, `D20Responses`, `e.d20`)

Everything that can change a roll once its die is rolled is an offer in the shape `Reactions.offer` takes, built by
`D20Responses.offers_for` in the order the rules apply them: Restore Balance, Reliable Talent, feature `roll_response`
recipes, Cosmic Omen, Dark One's Own Luck, Bend Luck, the Ravenloft and Faerûn responses, items (Ring of Evasion, a
Luck Blade...), Legendary Resistance, Countercharm, Fanatical Focus, a Bardic Inspiration die, Tactical Mind,
Indomitable, Guarded Mind, Stroke of Luck, Heroic Inspiration, and Reaction spells that answer a roll (Reweave Fate).
Each module adds its own with `d20_offers(c, t, keys, out)`. Offer fields beyond a reaction offer's: `forced` (not a
choice: it happens when reached), `ask: false` (never asked; its rule settles it), `default` (the rule until one is
set), `helps` (asked only when it could change the result), `sync` (how it's settled where the roll can't wait: `auto`
unless Off, `explicit` only on Automatic, `decision` when `_reaction_decision` says auto), and `text`/`cost` as
Callables so the prompt shows the roll as it stands.

A roll that can pause goes through `e.d20.then_after(c, roll, after, r)` (or `collect`/`collected` around a roll with
steps of its own, as attacks do): the offers are asked one by one and `after(test)` carries on once they're answered.
These pause today: spells' saves (`SpellSaves._save_spell(..., pausable)` from `cast`, `cast_with_numbers`,
`cast_free`, item spells, readied spells and reaction spells; `_resolve`/`_generic` return a CombatResult and take
`pausable`), monsters' save actions (`MonsterActions.save_action`, which returns `r` and takes `pausable`, true by
default), the riders on a monster's hit and their saves (`apply_riders(..., pausable)`), Topple, repeated saves at the
end of a turn (`end_turn` carries on with `Encounter.then`), Death Saving Throws (`death_save(c, pausable)`) and attack
rolls. Any other roll settles its offers at once (`run_now`). `Encounter.each(list, body, done)` runs a loop whose
steps can pause. `run_reaction_queue` called while a prompt is open waits for its answer.

## Events (`Encounter.drain_events()`)

| type | fields |
|---|---|
| move | id, from, to, forced, mounted (a rider carried along), dragged (pulled along by its grappler: it moves with the step before it), undo (a move taken back: the token goes back to `to`) |
| fall | id, feet: a creature falls (off a ledge, into a drop) |
| attack | attacker, target, hit, critical, action (the attack option's id: `weapon:longsword`, `monster:claw`; `spell:fire_bolt` for a spell attack), from (the token the blow comes from: the attacker, or an Echo Knight's echo) |
| damage / heal | id, amount (critical) |
| condition / down / death | id |
| death_save | id, success |
| spell | caster, spell, cells, targets |
| ability | source (feature, monster), by, key, targets, cells: a class feature used from the hotbar (key: its id, e.g. `second_wind`, `rage`) or a monster's saving-throw action (key: `<monster>.<action>`, e.g. `swarm_of_ravens.cacophony`), ahead of the events it caused |
| smite | caster, spell, target: a smite spell (Divine Smite, Searing Smite...) rides the hit that just landed (the view's effect, world/combat/fx/spell_fx.gd) |
| summon | caster, cell (Spiritual Weapon) |
| object / object_gone | id, kind, cell: a spell object or lingering area appeared, moved or ended (`spells.zones.objects`) |
| teleport | id, from, to (Misty Step, Bait and Switch, Engulf) |
| summon_creature / vanish | id: a summoned creature (Summon Undead, a severed limb) joined; a creature vanished (left: "fell" when it went into a drop) |
| resize | id: Enlarge/Reduce or Large Form changed its size |
| turn | id, round |
| round | round |
| over | outcome (victory, defeat) |

`action`, `ability`, `smite` and a `lair` event's `targets` are for the view's effects only (world/combat/fx/spell_fx.gd, docs/art/spell_effects.md):
nothing in the rules reads them, and emitting them changes no roll, order or state.

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

Events: `legendary` (id, option, name, left), `lair` (id, action, name, targets), `form` (id, form, art: the token wears the
shape's sprite when it exists), `vanish` (id, left: mist or withdraw, narration) for a creature leaving the fight.
The initiative tracker shows a legendary creature's actions left (◆◇) and the lair's card at count 20.

## Reusable feature and spell responses

`FeatureRecipes` supplies data-defined activations and synchronous failed-D20 responses through `FeatureActions`. Save-based damage reduction is shared by ordinary spells, zones and monster actions. Magical monster saves carry a magic key when the action declares `magical`.

Reaction offers may provide `stop_if` alongside `stop`: after `use`, the continuation stops only when the predicate is true. This allows an interrupted Shield to spend its Reaction while the original hit continues. Spell casting gates run after casting time is consumed and before slot payment or concentration replacement.

Action targeting `points` collects `count` distinct grid positions into `opts.points`; selecting an already chosen position deselects it. Invalid summon spaces are rejected during selection. Multi-creature feature and sustained-action selections read the action's own `count` instead of a spell's target count. `Combatant.record_step` retains the voluntary path. Charge checks count trailing steps that each close distance to the current target, allowing angled approaches on a square grid. Sideways/retreating steps break the counted approach; attacks, teleports, forced movement and new turns clear it.

Before a spell's attack rolls (`SpellCaster._before_attack_rolls`, in `cast`, `cast_with_numbers` and `cast_free`, for a
spell with `attack` and creature targets but no `object`), the before-roll offers (`EchoKnight.before_roll`,
`Reactions.before_roll`) are made for each roll `attack_shots` says the spell will make, with a stand-in attack state
(`pre_roll: true`); the spell resolves once they are answered, and `spell_attack` takes each roll's answers from
`ctx.pre_rolls` (the creature it is now made against, added Advantage and Disadvantage).

`feature.hit_response` offers a Reaction after an attack hit survives hit-negating defenses. It spends `resource`, forces a save against the feature class’s spell DC, and applies `effects` on failure through the shared effect engine. `range` and `requires_sight` are opt-in restrictions. Weapon/monster attacks pause for the normal reaction prompt; synchronous spell attacks only respond when `Encounter._reaction_decision` returns `auto`. The original hit still resolves if the attacker is Stunned by the response.

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


Reaction-cost D20 and spell-hit responses never default to spending a player's resource in a synchronous
resolver. They use the ordinary `Encounter._reaction_decision`: Ask and Off do not spend there; Auto does.
The class abilities tab exposes Ask / Automatic / Off preferences for known response spells and feature recipes,
including exhausted ones. Preferences take no action or resource, and forged ids/modes are rejected.
Free D20 responses retain their prior automatic default. Full manual synchronous continuations remain pending.

### Slot-funded damage responses

`feature.damage_response` declares `reduction_per_slot` and an optional `requires_flag`. `DamageResponses`
feeds the existing attack-reaction pipeline and `Encounter.deal_damage` for spells, zones, retaliation, and
other encounter damage. It spends one Reaction and one slot of the selected level (including Pact Magic),
reduces one damage instance across its component types, then leaves Resistance, Temporary Hit Points,
Concentration, and death to the ordinary damage engine. Spending a slot this way is not casting a spell.
The damage packet passed by the caller is unchanged. `Creature.preview_damage_parts` shares the existing
Immunity/Resistance/Vulnerability calculation without changing HP or rolling saves.

Reaction offers may supply `target_choices`, `selected_ids`, `min_targets`, `max_targets`, `validate_selected`,
and `select`. A bounded single selection uses radio behavior in the HUD. The encounter validates again before
clearing `pending`; an invalid or exhausted selection costs nothing and leaves the decision open.

Weapon attacks offer a slot-selection prompt. Synchronous damage cannot pause yet: its default Ask policy
spends nothing. The class abilities tab provides Ask, Off, and Auto at an **exact slot level**. Only explicit Auto
spends against synchronous damage, and it never substitutes another slot level if that pool is exhausted.
A declined/handled attack response is recorded on that attack so the central damage path cannot try it again.
Song of Defense (Bladesinger) is the user.

### Book modules

`RavenloftFeatures` (`e.ravenloft`, actions `feat:rh:<id>`) and `FaerunFeatures` (`e.faerun`, actions `feat:fr:<id>`)
hold the book options that need their own code. Each FaerunFeatures hook sits beside the matching Ravenloft one:
`list`/`perform`, `before_initiative`/`initiative_advantage`/`initiative_rolled`, `after_cast`, `spell_damage_bonus`,
`after_hit`, `adjust_incoming`, plus `after_damage` (end of `deal_damage`), `after_help`/`help_reach` (Help),
`after_stabilize`, `after_ready`, `blocks_forced_move` (start of `forced_move`), `exploit_opening` (weapon damage
dice) and `effect_added`, which every Creature calls when an effect lands (`Creature.effect_added`, set in `add`).
A monster save action's damage parts carry `magic: true` when the action is `magical`, as spell parts carry `spell`.
Batch 3 added `before_d20`, `turn_start`/`turn_end`, `after_save_ended` (a successful repeat save), `after_disengage`,
`attack_advantage` (in `attack_situation`) and queued damage reactions with `fr_` kinds (`queue_damage_reactions`,
`queued_ok`, `fire_queued`, `queued_text`). `Encounter.hit_context` names the attack whose damage is being dealt
({attacker, target, melee, spell}) while `deal_damage` runs for a weapon, monster or spell attack hit.
Dice that restore Hit Points go through `Encounter.heal_roll(expr, target, reason)` (or `heal_floor(target)` for a
single die) so Soothing Familiar's 3s apply to every healing roll. `EncounterSetup.bring_familiars` gives each party
member whose familiar is still summoned (`Character.familiar`: "here" or "pocket", set by casting Find Familiar and
cleared when it drops to 0 Hit Points or is dismissed) the familiar at the start of a location fight
(`SpellCaster.precast(c, id, true)`: no slot); `FaerunFeatures.familiar_of(c)` finds it, and its caster's `feat:fr:familiar_away` / `familiar_back` /
`familiar_dismiss` are Find Familiar's pocket-dimension and dismiss Magic actions.
Batch 8 (epic boons): `FaerunFeatures.maximized(c, type)` says whether a damage roll of that type uses every die's
maximum (spent when it answers yes; `Encounter._max_damage_dice` builds the roll) and is asked by weapon hits,
`roll_damage_parts`, `_roll_spell_damage` and the poison features; `waives_components(c, spell_id)` skips a spell's
components; `choice_in` carries the right-click choice of a `feat:fr:` action; `shaped_list` lists a Fluid Forms shape's
actions. The hotbar lists FeatureActions for any combatant, a shaped character or a summoned creature included.

`EchoKnight` (`e.echo_knight`, actions `feat:ek:<id>`; Explorer's Guide to Wildemount) keeps the Echo Knight's echoes:
creatures on the board with meta `echo_of` (the knight's id) and `echo_n`, a `look_of` in their stat block for the
view, no place in `order` (no turns) and none in `allies_of`. `attack_why`/`attack_origin` decide whether an attack of
the Attack action (`attack`, a Nick `offhand_attack`, Haste's attack; ActionCatalog's `target_why` and
`attack_preview`) comes from an echo's space, and `strike(c, echo, fn)` runs the attack with the knight and the echo
swapped until it and every prompt it pauses on are done (meta `strike_from` while it runs). Other hooks: `provokers`
and `oa_origin` (Opportunity Attacks from the echo), `before_roll` (Shadow Martyr, first of the before-roll offers),
`spell_redirect` (Shadow Martyr against a spell roll that can't pause, Automatic only), `in_avatar`/`echo_sees` (Echo Avatar in
`can_see`), `turn_start`/`turn_end`, `effect_added`, `after_damage`, `on_death`, `initiative_rolled` and
`rider_options`. A hotbar entry can carry `from` (an echo's id) or `from_echo` (any echo): its range is measured from
there (`range_why`, in `target_why`, `FeatureActions.perform` and the view's place hover).

