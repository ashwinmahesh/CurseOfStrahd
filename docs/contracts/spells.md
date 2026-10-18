# Spell recipes (data/spells → combat/spell_caster.gd, combat/spell_zones.gd)

A spell's combat behaviour comes from its data. The engine reads these keys; anything else is narrative (`text`,
`summary`). A spell with none of them shows "No effect in a fight" on the hotbar instead of spending a slot for
nothing. `make test` casts every combat spell (tests/unit/test_spell_sweep.gd) and fails if one changes nothing.

## Who and where

| key | meaning |
|---|---|
| `targets.kind` | `self` (the caster, no picking), `creature`, `ally`, `enemy`, `point`, `area` |
| `targets.count` | creatures to pick (99 = any number); `upcast.targets` adds more per slot level (the hotbar offers several picks) |
| `targets.creature_type` | only creatures of this type (Hold Person: `humanoid`) |
| `area` | shape and size; a Self-range area is aimed from the caster (`direction`), any other at a point; `from_caster: true` lays an Emanation round the caster's own space as it stands at the cast although the range isn't Self (Thunder Step's boom round the space it leaves) |
| `area_targets` | `all` (default for a point), `others` (default from Self), `enemies` ("creatures of your choice"), `allies` |
| `area_max_targets` | at most this many in the area (Slow: 6) |
| `upcast.area` | feet added to the area per slot level (Fog Cloud) |
| `cantrip_scaling.range_doubles` | the range doubles at 5, 11, 17 (Spare the Dying) |
| `choice` | a cast-time pick: `{kind, label, from}` (damage type, condition, ability, skill or option). The hotbar's right-click menu lists the options; the first is the default. `"choice"` inside effect data becomes the pick |

## What it does

| key | meaning |
|---|---|
| `attack` | a spell attack per target (`damage[0].per: "ray"` for several rays); `miss: "half"` (Melf's Acid Arrow); `drain: true` heals the caster half the damage (Vampiric Touch) |
| `secondary` | a save after the attack, hit or miss, around the target: `{radius, save, save_success, damage, effects}` (Ice Knife) |
| `save`, `save_success` | a save per creature; damage rolled once for everyone; cover for Dex saves; Evasion, Sculpt Spells and Interpose Shield apply |
| `save_disadvantage_for` | a creature type saves with Disadvantage (Shatter: `construct`) |
| `save_advantage_if_fighting`, `willing_skip_save` | Charm Person; allies don't resist Enlarge/Reduce or Levitate |
| `heal`, `temp_hp` | healing (Disciple of Life, Beacon of Hope's maximum, Supreme Healing, Blessed Healer) and Temporary Hit Points |
| `living_only`, `skip_types` | healing that does nothing for an Undead or a Construct (`living_only`), or for the creature types listed (`skip_types`: the Icon of Ravenloft's Cure Wounds skips Fiends too) |
| `damage` without attack or save | dealt to everyone affected |
| `effects` | effect entries (below) |
| `zone` | a lingering area (below) |
| `object` | a spell object on a square: `{kind: weapon/sphere/lights/hand, range, on_appear: attack, rules}` |
| `sustain` | actions the spell keeps granting while it lasts (below) |

## Effect entries (`effects[].effect` and `params`)

Kinds: `modifiers`, `condition`, `temp_hp`, `heal`, `damage` (delayed, `when: target_turn_end`), `push`, `pull`
(`feet`, `max_size`), `end_condition` (`conditions`: ends one of them), `light` (`bright`, `dim`, `sunlight`; follows
the target), `summon`, `custom` (`mirror_image`, `warding_bond`, `goodberry`).

| param | meaning |
|---|---|
| `on` | `hit`, `miss`, `fail`, `success`, `cast`, `always`. Default: hit for attack spells, fail for save spells, cast otherwise |
| `target` | `self` puts it on the caster |
| `until` | `spell` (default: the spell's duration and Concentration), `caster_turn_start`, `caster_turn_end`, `target_turn_start`, `target_turn_end`, `this_turn_end`, `rounds:N`, `permanent` |
| `consume` | `next_save`, `next_attack`, `next_check`, `next_attacked`: gone after that roll |
| `ends_on` | `attack_roll`, `deal_damage`, `cast_spell`, `damage`, `damaged_by_caster_side` |
| `repeat_save` | `end_of_turn` or `start_of_turn`; with `repeat_on_damage`, `damage_advantage`, `repeat_if: no_sight_of_caster`, `repeat_fail_damage` |
| `escape` | `check:<skill>`: an action and that check against the spell DC ends it (Web, Entangle) |
| `plain` | a plain condition that outlasts the spell (Grease's Prone); `breaks_concentration` (Sleet Storm) |
| `only_choice` | only when the cast-time pick is this value (Enlarge or Reduce) |
| `wakeable` | an ally can use its action to shake the creature out of it (Sleep, Hypnotic Pattern) |

Modifier values may use `slot_level`, `"spell"` as an ability (the caster's spellcasting ability), a die
`"tier:1d8,1d10,1d12,2d6"` (Shillelagh) and `":caster"` in a flag (Mind Spike, Bestow Curse).

## Zones (`zone`)

A FieldObject on the cells the area covers, kept by Concentration (or the duration). Emanations move with the caster.

| key | meaning |
|---|---|
| `triggers` | `cast`, `enter` (first time in a turn), `moved_into` (the area moves onto a creature), `start_turn`, `end_turn`, `near_start_turn` / `near_end_turn` (within `reach` of an object) |
| `once_per_turn` | default true |
| `affects`, `spare_allies` | who it affects (Spirit Guardians spares the caster's side) |
| `save`, `half`, `damage`, `effects` | default to the spell's own; `damage_type_choice` resolves a type choice |
| `terrain: difficult` | Difficult Terrain (`terrain_affected_only` for Spirit Guardians' half Speed) |
| `obscured` | `heavy` (blocks sight through it) or `light` |
| `darkness`, `silence`, `light`, `dispels_darkness` | magical Darkness, no Verbal spells, light and sunlight, Daylight dispelling Darkness |
| `inside` | modifiers and conditions that hold while a creature is inside (Silence, Pass without Trace, Crusader's Mantle) |

## Sustained actions (`sustain[]`)

`{do, cost (action/magic/bonus_action/free), label, sub, help, range, move, reach, attack, damage, area, save,
save_success, heal, owner: target, not_this_turn, upkeep}`. `do`: `attack` (Spiritual Weapon, Vampiric Touch,
Produce Flame), `damage` (Witch Bolt), `area` (Dragon's Breath), `move_object` (Flaming Sphere, Cloud of Daggers,
Dancing Lights, Mage Hand), `dash` (Expeditious Retreat), `heal_one` (Aura of Vitality), `aim` (Gust of Wind),
`maintain` (Crown of Madness, which ends without it), `teleport` (Far Step: a Bonus Action to teleport again, to a square checked like the cast's: `range`, in sight, unoccupied, outside an Antimagic Field). They appear on the hotbar while the spell lasts.

## Reactions and readied spells

Shield (when hit or targeted by Magic Missile), Hellish Rebuke (after being damaged), Counterspell (foes' Counterspell of
a hero's spell, and the chain of Counterspells it opens: `SpellCounters`, below; monsters' own spells resolve at once). Any one-action spell can be readied (hotbar right-click → Ready): it's cast and
its slot spent, held with Concentration, and released at the first enemy to come within range.

### The Counterspell chain (`combat/spell_counters.gd`, owned by `SpellReactions.counters`)

`SpellCasting.cast` works out what the cast needs, then hands the rest (`_cast_after_counter(cx)`: slot, Concentration,
events, resolution) to `SpellReactions.counter_chain(c, s, seen, proceed)`, so a Counterspell prompt can pause it. A foe
the AI plays that would Counterspell the spell (a levelled spell it sees within 60 ft, with its Reaction and a casting
left) casts it first; then whoever is hostile to the last Counterspell's caster may Counterspell it: the AI at once, a
hero or guest on a `counterspell` Reaction prompt (`Reactions.offer`; its `ways` key makes an Automatic rule ask when
there are several ways to pay). Each step is `{caster, target, dc, level, slot, countered}`: the caster's Reaction (and a
free casting or a monster's use) goes when it is cast, its slot (`SpellReactions.pay(..., defer_slot)`) only when the
step stands. When no one answers, `_resolve` goes from the last step back: a step that wasn't countered makes its target
roll a Constitution save against its DC; a failure counters the step before it (the spell, for the first). `proceed` runs
when the spell is not countered; a countered spell returns an empty result with its action spent and its slot kept. Each
step and its resolution is a combat log line; the prompt's text is the preview (the save and its odds on each side).

## Recipe keys added for the Phase 4 spells

- Smites: `on_hit_spell`, `on_hit_melee_only` (default true), `on_hit_ranged_only`, `on_miss_too`, `replaces_weapon_damage`,
  `damage_bonus_vs`; a smite with `save` rolls it on the hit, with `secondary` bursts around the target
  (`exclude_target`), otherwise its effects land on "hit".
- Effect params: `target: caster_vs` (a mark the caster carries, `vs: target`), `turn_damage` {dice, type, when},
  `turn_temp_hp` ("mod" or a number), `ends_without_temp_hp`, `repeat_save: manual` (only code repeats it).
- Saves: `save_advantage_min_size`, `fighting_auto_success`, `auto_fail_types`.
- Areas: `area.shape: wall` (a straight wall along the cast direction), `area.origin_size` (an Emanation around something
  placed at the point).
- Zones: `per_square` trigger (Spike Growth), `start_damage` (no save, start of turn), `charges` / `charges_per_slot`,
  `damage_cap`, `revive_downed`, `caster_near`, `caster_effects`, `side_ft` (Wall of Fire), `storm_radius`, `terrain_cost`,
  `deflects_missiles`, `resolve_on_cast`, `caster_turn_ends`, `rounds`, `camouflaged` (Spike Growth: the AI knows the
  area only if it saw it cast or was hurt by it, kept in the live area's `rules.known_by`).
- Objects: `kind` hound and vine, `reach` (how far it strikes), `rules.bite`.
- Sustained actions: `disengage`, `compel`, `once_per_turn`, `at_point` with `within_object`.
- Summons: SummonBlocks builds Find Steed, Summon Beast, Giant Insect, Summon Aberration, Summon Construct and Summon
  Elemental from the slot level and the cast-time choice.
- Teleports (`SpellTargeting.TELEPORTS`: Misty Step, Dimension Door, Thunder Step, Far Step) ask the hotbar for a square (`place`), whatever area the
  spell has; `bring_along: {within, max_size}` lets one willing creature go too (Dimension Door: any size; Thunder Step: `max_size: caster`, the caster's size or smaller;
  `opts.with`, `SpellTargeting.companion_why`; the combat view asks after the square, TargetPicker `companion`).
- Code handlers (combat/spell_specials.gd): Polymorph (combat/shape_change.gd), Banishment, Otiluke's Resilient Sphere,
  Dimension Door, Thunder Step, Far Step, Heat Metal, Confusion, Compelled Duel, Compulsion, Dominate Beast, Dissonant Whispers, Eldritch Blast's
  beams, Sorcerous Burst.

## Supplemental spell recipes

`automation: reference` disables casting with “Not automated yet”, separately from combat role tags. A damage reference remains tagged `damage`.

Shared additions:

- `requires_sight`, `ignore_partial_cover`, `crit_range`, `repeat_targets`, and `auto_success_types` express target/attack/save exceptions. Full cover remains blocking unless an explicit object movement rule allows passing barriers.
- Spell weapons can choose multiple targets for their attack count, measure attacks from the object, and save casting numbers. Validate the whole selection before moving or paying for the activation.
- Sustained actions serialize casting DC/attack/modifier/class rather than a live `Breakdown`. They can override attack `effects`, require the granting effect (`requires_effect`), and break on tether range/cover. Duration uses actual spell units.
- Effect `primary_condition` links all grouped penalties to that condition: immunity discards the group and curing it removes dependent penalties. `starts_next_turn` delays turn restrictions. `casting_save` stores ability and casting DC on the effect; failing spends casting time without a slot or replacing concentration.
- `until: minutes:N` supports a fixed condition duration. Minute effects tick every ten owner turns as well as during exploration time advancement.
- `turn_damage.upcast: false` keeps ongoing damage independent of initial upcasting. `repeat_fail_exhaustion` adds Exhaustion on a failed repeat save.
- `end_concentration` is an effect operation. Temporary Exhaustion records its own contribution and removes only that contribution with its effect.
- `short_rest_on_expiry` grants a Short Rest only after uninterrupted natural expiry, then creates a Long-Rest lockout. Damage, waking, cures, dispelling, and other early removal do not grant that rest.

These primitives are tested in `test_faerun_recipes`; book-level completion and outstanding exceptions live in rules/coverage.md.

Spell `roll_response` describes failed-D20 or incoming-attack reactions: `scope`, `natural`, `incoming_natural`, `reroll_advantage`, and `success_temp_hp`. Synchronous checks/saves use auto/never; attack defense joins the existing reaction prompt. `field_utility` exposes a harmless self/creature handler to exploration casting. Slot recovery can restore Spellcasting or Pact Magic slots (Spellcasting first at the same level).

Splintered Summons supplies two `opts.points` plus `splintered: true`. Both full footprints, visibility, range and non-overlap are validated before payment. A real slot and feature use are required; both creatures have half HP, keep the same form, and share the casting's concentration. The action catalog exposes the two-point choice while retaining form and slot choices.

Subclass `cast_level_boost` recipes select an explicit spell variant (`opts.slot_boost`). Eligibility checks school, optional extra-target upcasting or absence of attack/save mechanics, resource availability, and actual slot expenditure before any costs. The spell resolves with effective `slot + 1`; `paid_slot` retains the spent slot for post-cast benefits such as Arcane Ward or school Adept features. Free castings and cantrips cannot use the variant.
