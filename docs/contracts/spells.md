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
| `area` | shape and size; a Self-range area is aimed from the caster (`direction`), any other at a point |
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
`maintain` (Crown of Madness, which ends without it). They appear on the hotbar while the spell lasts.

## Reactions and readied spells

Shield (when hit or targeted by Magic Missile), Hellish Rebuke (after being damaged), Counterspell (data only:
monsters' spells resolve at once). Any one-action spell can be readied (hotbar right-click → Ready): it's cast and
its slot spent, held with Concentration, and released at the first enemy to come within range.
