# Rules coverage matrix (2024 PHB)

This matrix, not anyone's impression, decides whether a rule is done (plan §3). Statuses:
**tested** (engine + unit test) · **implemented** (engine, not yet under test) · **data** (content entered, its
system arrives later) · **partial** (the non-positional part is tested; the rest needs the combat grid) ·
**deviated** (see deviations.md) · **not started**. Phase in brackets = where the rest lands.

Tests live in `tests/unit/` and `tests/integration/`; names below are files.

## Playing the Game: D20 Tests and proficiency

| Rule | Code | Status | Test |
|---|---|---|---|
| Ability scores and modifiers | model/abilities.gd | tested | test_abilities |
| Proficiency Bonus by level and by CR | model/abilities.gd | tested | test_abilities |
| D20 Test: meet the DC/AC to succeed | resolution/d20_test.gd | tested | test_d20_test |
| Advantage / Disadvantage (don't stack, cancel) | d20_test.gd, creature.gd d20_sources | tested | test_d20_test, test_conditions |
| Natural 20 / 1 only matter on attack rolls | d20_test.gd | tested | test_d20_test |
| Skills and default abilities (18) | abilities.gd | tested | test_abilities |
| Expertise (double PB) | creature.gd skill_rank, character.gd | tested | test_reference_party |
| Saving throw proficiency | character.gd | tested | test_reference_party |
| Passive scores (+5/−5) | creature.gd passive_score | tested | test_abilities, test_reference_party |
| Initiative = Dexterity check, Alert adds PB | creature.gd initiative_bonus | tested | test_reference_party |
| Heroic Inspiration | character.gd (Resourceful); encounter.gd reroll | partial: reroll offered on a missed attack roll; saves and checks [Phase 3] | test_combat_encounter |
| Bonus/penalty dice on D20 Tests (Bless, Bane) | creature.gd roll_d20 | tested | test_effects |
| Automatic failure (Paralyzed etc.) | creature.gd roll_d20 | tested | test_conditions |

## Playing the Game: damage, healing, death

| Rule | Code | Status | Test |
|---|---|---|---|
| Hit Points, maximum, Bloodied | creature.gd | tested | test_damage |
| Damage order: bonuses, Resistance, Vulnerability; Immunity | creature.gd take_damage_parts | tested | test_damage |
| Resistance/Vulnerability don't stack | creature.gd | tested | test_damage |
| Several damage types in one instance | creature.gd take_damage_parts | tested | test_damage, test_attacks |
| Temporary Hit Points: absorb first, don't stack | creature.gd | tested (engine keeps the higher; see deviations) | test_damage |
| Healing can't exceed maximum | creature.gd heal | tested | test_damage |
| Monsters die at 0 HP | creature.gd | tested | test_damage |
| Massive Damage | creature.gd | tested | test_damage |
| Falling Unconscious at 0 HP | creature.gd | tested | test_damage |
| Death Saving Throws (10+, nat 1, nat 20, 3/3) | creature.gd roll_death_save | tested | test_death_saves |
| Damage at 0 HP = failure (crit = 2) | creature.gd | tested | test_damage |
| Stabilizing, Stable creatures | creature.gd stabilize | tested | test_death_saves |
| Knocking a creature out | — | not started | [Phase 3] |
| Critical Hits: roll damage dice twice | resolution/attack_resolver.gd | tested | test_attacks |

## Rules Glossary: conditions (data/conditions)

| Rule | Code | Status | Test |
|---|---|---|---|
| Blinded, Charmed, Deafened | data + creature.gd | partial (sight/hearing/charmer checks: Phase 2-3) | test_conditions |
| Exhaustion (−2 per level to D20 Tests, −5 ft, death at 6, Long Rest −1) | data + creature.gd | tested | test_conditions |
| Frightened | data; Turn Undead fleeing in ai_brain.gd | partial (Disadvantage always on, see deviations; can't-approach only for AI) | test_conditions, test_combat_spells |
| Grappled (Speed 0) | data + encounter.gd | tested (Speed 0, escape, other-target Disadvantage); dragging: deviations | test_conditions, test_combat_encounter |
| Incapacitated (no actions, breaks Concentration) | data + creature.gd | tested | test_conditions |
| Invisible | data + encounter.gd can_see | tested (hidden creatures, attacks either way) | test_conditions, test_combat_encounter |
| Paralyzed, Petrified, Stunned, Unconscious | data + creature.gd | tested (auto-crit within 5 ft) | test_conditions, test_attacks |
| Poisoned, Restrained | data | tested | test_conditions |
| Prone (attackers within 5 ft Advantage, else Disadvantage) | data + attack_resolver.gd | tested | test_attacks |
| Condition immunity | creature.gd | tested | test_conditions, test_effects |

## Effects, durations and Concentration

| Rule | Code | Status | Test |
|---|---|---|---|
| Effects with source, modifiers, conditions, duration | model/effect.gd | tested | test_effects |
| Same effect doesn't stack (most potent, then most recent) | creature.gd all_modifiers | tested (potency is approximate; see deviations) | test_effects |
| Durations: rounds, start/end of turn, minutes, hours, rests | effect.gd | tested | test_effects |
| Concentration: one at a time, ends linked effects | model/concentration.gd | tested | test_effects |
| Concentration save after damage (DC 10 or half, max 30) | creature.gd | tested | test_damage, test_effects |
| Concentration ends when Incapacitated or dead | creature.gd | tested | test_conditions |

## Creating a Character and Level Advancement

| Rule | Code | Status | Test |
|---|---|---|---|
| Standard Array, Point Cost (27), Random 4d6 drop lowest | progression/ability_scores.gd | tested | test_character_builder |
| Background ability increases (+2/+1 or +1/+1/+1, max 20) | character.gd, choice_options.gd | tested | test_character_builder |
| Background skills, tool, origin feat, equipment A/B | character.gd | tested | test_data_integrity |
| Species traits, sizes, lineages, species spells at 3 and 5 | character.gd | tested | test_reference_party |
| Languages: Common + 2 standard | character.gd | tested | test_character_builder |
| Level 1 Hit Points; later levels fixed or rolled, minimum 1 | character.gd max_hp_breakdown | tested | test_reference_party, test_level_up |
| Constitution changes apply retroactively; Tough | character.gd | tested | test_reference_party, test_level_up |
| Class features by level, subclass at 3 | character.gd | tested | test_data_integrity |
| Ability Score Improvement or feat; feat prerequisites | choice_options.gd | tested | test_character_builder |
| Starting equipment and auto-equip | character.gd | tested | test_data_integrity |
| Multiclass prerequisites (new class and current classes) | level_up_controller.gd | tested | test_level_up, test_reference_party |
| Multiclass proficiencies, Hit Points, Proficiency Bonus | character.gd | tested | test_level_up |
| Multiclass spell slots; third casters alone round up | magic/spellcasting.gd | tested | test_spellcasting, test_level_up |
| Extra Attack doesn't stack across classes | encounter.gd attacks_per_action (highest wins) | implemented | — |
| Unarmored Defense from two classes: pick one | character.gd armor_class (best formula) | implemented | — |
| Epic Boons, levels 19-20 | data | data | [Phase 5] |
| Respec at Madam Eva | — | not started | [Phase 4] |

## Classes (Phase 1: Fighter, Rogue, Cleric, Wizard and all 16 subclasses)

| Rule | Code | Status | Test |
|---|---|---|---|
| Class tables, features 1-20, resources by level | data/classes | tested to level 5 | test_reference_party, test_data_integrity |
| All 16 PHB subclasses, features 3-18 | data/subclasses | tested to level 5 | test_data_integrity |
| Fighter: Fighting Style, Second Wind uses, Weapon Mastery count, Action Surge, Extra Attack | data + engine + combat/features.gd | tested | test_reference_party, test_combat_encounter |
| Champion: Improved/Superior Critical, Remarkable Athlete | data | tested | test_attacks, test_reference_party |
| Battle Master: Superiority Dice, maneuvers, Student of War | data + features.gd, feature_actions.gd, reactions.gd | tested: every combat maneuver (hit riders, Bonus Action maneuvers, Parry, Riposte, Precision Attack, Commander's Strike, Ambush); Commanding Presence and Tactical Assessment are checks (Phase 3) | test_feature_combat, test_level_up |
| Subclass features in combat (all 16 subclasses, levels 3-18) | features.gd, feature_actions.gd, reactions.gd, spell_caster.gd | implemented; tested for Battle Master, Light, War, Diviner, Abjurer, Soulknife (list in the spell and ability audit log). Out of combat: War Bond, Blessing of the Trickster's duration, Psi-Bolstered Knack, Psychic Whispers, Spell Thief, Versatile Trickster, Improved War Magic, Relentless | test_feature_combat |
| Class features in combat: Tactical Shift, Indomitable, Studied Attacks, Cunning Strike and Devious Strikes, Evasion, Reliable Talent, Elusive, Stroke of Luck, Divine Strike, Divine Intervention | features.gd, feature_actions.gd | implemented; Tactical Shift, Cunning Strike tested | test_feature_combat |
| Eldritch Knight / Arcane Trickster spellcasting tables | data + engine | tested | test_level_up |
| Rogue: Expertise, Sneak Attack, Cunning Action, Steady Aim, Thieves' Cant | data + combat/features.gd | tested | test_reference_party, test_combat_encounter |
| Cleric: Divine Order, Channel Divinity uses, domain spells always prepared | data + engine | tested | test_reference_party |
| Life Domain: Disciple of Life | data + engine | tested | test_reference_party |
| Wizard: spellbook (6 + 2 per level), prepared from the book, Scholar, Evocation Savant | data + engine | tested | test_reference_party, test_spellcasting |
| Other 8 classes | — | not started | [Phase 4] |

## Feats, equipment, spells

| Rule | Code | Status | Test |
|---|---|---|---|
| Feats: 10 origin, 43 general, 10 fighting style, 12 epic boons | data/feats + features.gd, feature_actions.gd, reactions.gd | implemented in combat (Lucky, Interception, Protection, Sentinel, Polearm Master, War Caster, Great Weapon Master, Sharpshooter, Spell Sniper, Crossbow Expert, Crusher, Piercer, Slasher, Mage Slayer, Heavy Armor Master, Shield Master, Defensive Duelist, Dual Wielder, Two-Weapon Fighting, Tavern Brawler, Unarmed Fighting, Healer, Durable, Charger, Speedy, Skulker, Telekinetic, Poisoner, Elemental Adept, Keen Mind and Observant Bonus Actions, boons); rest-time and social parts are Phase 3; `make validate` checks every "engine" label | test_feature_combat, test_attacks |
| Species actions: Breath Weapon, Draconic Flight, Giant Ancestry, Large Form, Relentless Endurance, Adrenaline Rush, Healing Hands, Celestial Revelation, Stonecunning; saves against conditions (Dwarven Resilience, Fey Ancestry, Brave) | feature_actions.gd, spell_caster.gd | tested: Breath Weapon, Fire's Burn, Relentless Endurance, Healing Hands, Dwarven Resilience | test_feature_combat |
| Weapon properties, Finesse, Versatile, Thrown, Range | resolution/weapon_profile.gd | tested | test_attacks |
| Weapon Mastery properties | encounter.gd, features.gd | tested: all eight (Cleave in test_feature_combat); Push and Topple can be held back from the class tab | test_combat_encounter, test_feature_combat |
| Armor: light/medium/heavy AC, Strength requirement, Stealth Disadvantage | character.gd | tested | test_reference_party, test_attacks |
| Armor and Shield without training | character.gd gear_d20_sources, armor_class | implemented | — |
| Unarmed Strike (1 + Str) | weapon_profile.gd | implemented | — |
| Carrying capacity by size and Powerful Build | creature.gd carrying_capacity | implemented | — |
| Spell slots (full, half, third, multiclass) | magic/spellcasting.gd | tested | test_spellcasting |
| Spell save DC and spell attack | character.gd | tested | test_reference_party |
| Cantrip scaling at 5/11/17; upcasting | magic/spellcasting.gd | tested | test_spellcasting |
| Prepared spells, always-prepared spells, spellbook | character.gd | tested | test_reference_party |
| Ritual casting | data (ritual flags) | data | [Phase 3] |
| Components and focuses | spell_caster.gd | partial: Verbal (can't speak, reveals the hidden), armor training; Material and focuses assumed carried | test_combat_spells |
| Areas of effect | grid.gd area_cells, spell_caster.gd | tested (sphere, cube, cone, line, emanation; walls block) | test_combat_grid, test_combat_spells |
| 176 spells (levels 0-3 for the Phase 1 classes, plus three the Night Hag casts) | data/spells, spell_caster.gd, spell_zones.gd | tested: every spell with combat rules is cast and must change the fight; 131 of them do something in combat; the other 45 are exploration (detection, communication, rituals, travel) and say so on the hotbar | test_spell_sweep, test_spell_recipes, test_combat_spells |

## Combat (Phase 2: combat/, ADR 0007)

| Rule | Code | Status | Test |
|---|---|---|---|
| Initiative: Dexterity check, surprise = Disadvantage, identical monsters share a roll, ties | encounter.gd start | tested | test_combat_encounter |
| Turn order, rounds, the action economy (Action, Bonus Action, Reaction, movement, one free object interaction) | encounter.gd, combatant.gd | tested | test_combat_encounter |
| Grid movement: 5 ft squares, diagonals 5 ft, no corner cutting, Difficult Terrain double, climbing | grid.gd | tested | test_combat_grid |
| Moving through creatures (allies, Incapacitated, Tiny, two sizes different; enemy squares are Difficult Terrain); can't end in an occupied square | encounter.gd _occupancy_for | tested | test_combat_encounter |
| Halfling Nimbleness, Naturally Stealthy, Luck | encounter.gd, d20_test.gd reroll_ones | tested (Nimbleness, Luck through the suite) | test_combat_encounter |
| Prone: Disadvantage to attack, Advantage within 5 ft / Disadvantage beyond against it, standing costs half Speed, crawling double | encounter.gd, action_catalog.gd | tested | test_combat_encounter, test_action_catalog |
| Opportunity Attacks (leaving reach of a creature that can see you; Disengage; forced movement doesn't provoke) | encounter.gd _walk, _provokers | tested | test_combat_encounter |
| Reactions: one per round, prompts for the player with per-reaction rules | encounter.gd, reaction_request.gd | tested | test_combat_encounter, test_combat_ai |
| Attack rolls: every Advantage/Disadvantage source, cover, long range, ranged attacks in melee, unseen attackers and targets, Heavy | encounter.gd attack_situation | tested | test_combat_encounter |
| Cover: Half +2, Three-Quarters +5, Total untargetable; creatures give Half; Dex saves add cover | grid.gd cover_between, spell_caster.gd | tested | test_combat_grid, test_combat_encounter |
| Critical Hits, automatic crits against Paralyzed/Unconscious within 5 ft | encounter.gd | tested | test_combat_encounter |
| Standard actions: Attack, Dash, Disengage, Dodge, Help (attack), Hide, Search, Study, Ready (attacks), Magic, Utilize (Healer's Kit), Influence | encounter.gd, action_catalog.gd | tested (Influence has no target in the arena; readied spells: deviations) | test_combat_encounter, test_action_catalog |
| Grapple and Shove with Unarmed Strike; escape | encounter.gd | tested | test_combat_encounter |
| Two-weapon fighting (Light) and Nick | encounter.gd offhand_attack | tested | test_combat_encounter |
| Thrown weapons leave the hand; ammunition used up | encounter.gd | tested | test_combat_encounter |
| Death Saving Throws on the creature's turn, stabilizing (Medicine DC 10 or Healer's Kit) | encounter.gd death_save, stabilize | tested (rules in test_death_saves) | test_death_saves, test_combat_arena_scene |
| Savage Attacker, Sneak Attack once per turn (any turn) | encounter.gd, features.gd | tested | test_combat_encounter |
| Spellcasting in combat: casting time vs the action economy, one slot-spell per turn, free castings, Concentration, range and line of effect, upcasting | spell_caster.gd | tested | test_combat_spells |
| Spell attacks, saves (damage rolled once, half on success), healing (Disciple of Life), buffs, repeated saves | spell_caster.gd | tested | test_combat_spells |
| Spell secondary effects: pushes and pulls (farthest first), lingering areas (Spirit Guardians, Cloud of Daggers, Web, Grease, Entangle, Fog Cloud, Darkness, Silence, Stinking Cloud, Sleet Storm, Gust of Wind), spell objects (Spiritual Weapon, Flaming Sphere, Dancing Lights, Mage Hand), sustained actions (Witch Bolt, Vampiric Touch, Dragon's Breath, Produce Flame), effect durations and triggers, repeated saves, escape checks, summons (Summon Fey/Undead), teleports, Haste and Slow, Mirror Image, Blink, Invisibility ending, cast-time choices, readied spells, Command's five words | spell_caster.gd, spell_zones.gd | tested | test_spell_recipes, test_combat_spells |
| Channel Divinity: Turn Undead (Sear Undead), Divine Spark, Preserve Life | features.gd | tested | test_combat_spells |
| Monster stat blocks in combat: attacks, Multiattack choices, timed riders with exceptions, real grapples, save actions, Recharge, drains, swarms, flyers, Parry, auras, sunlight, Lightning Absorption, Incorporeal Movement, Loathsome Limbs, lycanthropy, spellcasting | encounter.gd, monster_actions.gd | tested | test_monster_actions, test_combat_encounter |
| Enemy AI: pack_hunter, brute, mindless, cowardly, skirmisher, swarm, spellcaster, support; obeys Command, Fear, Crown of Madness, Calm Emotions | ai/ai_brain.gd | tested | test_combat_ai, test_arena_fight, test_monster_actions |
| Encounter XP budget (2024 DMG) | tools/data/validate_data.py | tested by make validate | — |
| Light, darkness and obscurement in combat | encounter.gd can_see / light_at, spell_zones.gd | implemented: map light (bright/dim/dark), Darkvision, Blindsight and Truesight, light from spells, magical Darkness, Heavily Obscured areas, sunlight | test_spell_recipes |

## Exploration and rests (Phase 3: world/exploration, story/, ADR 0008, ADR 0009)

| Rule | Code | Status | Test |
|---|---|---|---|
| Passive Perception notices traps (within 10 ft) | location_view.gd _check_traps | tested | test_exploration |
| Search (Wisdom (Perception)) finds traps, hidden objects and secret doors | location_view.gd search | tested | test_exploration |
| Thieves' Tools (2024): Dexterity check + Proficiency Bonus with the tools, Advantage with Sleight of Hand too; pick a lock or disarm a trap | location_view.gd _unlock, _disarm | implemented | test_exploration |
| Forcing a lock: Strength (Athletics) | location_view.gd _unlock | deviated (DC + 2, see deviations) | test_exploration |
| Traps: save, damage (half on a success), condition | location_view.gd _spring_trap | implemented | — |
| Stealth and surprise: a sneaking party's lowest Stealth against each enemy's passive Perception | location_view.gd _stealth_surprise | implemented | — |
| Short Rest: spend Hit Point Dice (roll + Con, minimum 1), short-rest features | rest_screen.gd, character.gd | tested | test_party_screens |
| Long Rest: all Hit Points, Hit Point Dice, slots and features; interruption | rest_screen.gd | implemented (interruption: deviations) | — |
| Ability checks in conversation (any skill or ability, the speaking character's bonus, Advantage sources) | story/dialogue_runner.gd | tested | test_story |
| Milestone levelling | story/story_state.gd, level_up_screen.gd | tested | test_story, test_party_screens |
| Saves outside combat and at the start of each round; effects and Concentration saved | core/save_system.gd, combat/encounter_snapshot.gd | tested | test_exploration, test_story |
| Casting outside combat: healing and helpful spells, slots, lasting effects and Concentration | story/field_casting.gd (through SpellCaster) | tested | test_party_screens |
| Frightened: can't willingly move closer to a visible source | encounter.gd reachable_for | tested (strict reading, deviations) | test_combat_encounter |
| Flying creatures move at their Fly Speed | combatant.gd speed | implemented (no altitude, deviations) | test_phase3_exit |
| Heroic Inspiration on saves and checks | — | not started | [Phase 4] |
| Light, Darkvision and obscurement affecting checks and attacks | — | spell and ability audit | — |

## Not started (later phases)

Influence and NPC attitudes as a rule (attitudes exist in the story; checks against them arrive with merchants),
travel, day and night effects (Phase 4); the other eight classes, magic items and attunement (Phases 4-5).
