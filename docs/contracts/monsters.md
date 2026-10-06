# Monster stat blocks in a fight (data/monsters → combat/monster_actions.gd, combat/ai/ai_brain.gd)

Numbers are the 2024 stat block's. These machine-readable keys sit next to the prose `text`.

## Actions

| key | meaning |
|---|---|
| `kind` | `melee`, `ranged`, `save`, `multiattack`, `spellcasting`, `special` |
| `attack`, `damage` | attack bonus and reach or range; damage entries (extra entries add dice; `if: bloodied` / `not_bloodied` picks a swarm's damage) |
| `on_hit` | riders after a hit (below) |
| `save`, `targets`, `on_fail` | a saving-throw action: who it can target (`range`, `count`, `max_size`, `in_space`, `requires`: grappled / incapacitated / restrained / willing), damage, riders on a failure |
| `multiattack[].or` | alternatives for that slot (Scimitar or Pistol); the AI picks what reaches, a save action first when it has a target |
| `recharge`, `uses` | Recharge X-6 rolled at the start of the monster's turn; uses per day |
| `forms` | Shape-Shift forms that can use it (the Werewolf's Bite) |
| `weapon` | a held weapon (Disarming Attack) |
| `ac_bonus` | Parry: +AC against one melee hit while holding a weapon |
| `do`, `cast` | special Bonus Actions: `dash_or_disengage`, `hide_in_dim`, `shape_shift`, `cast` (Divine Aid's spells) |

## Riders (`on_hit[]`, `on_fail[]`)

`{do, save, until, not_types, only_types, not_species, max_size, immune_on_success, ...}`:
`condition` (with `until`: target_turn_end, target_turn_start, source_turn_start, source_turn_end, minute, permanent;
optional `modifiers`), `grapple` (`escape_dc`, `limit`), `pull` / `push` (`feet`), `drain_max_hp` and `heal_self`
(`type`), `ability_drain` (`ability`, `dice`), `curse` (lycanthropy), `engulf` (`escape_dc`, `damage`, `conditions`).

## Traits read by code

`aura` (`radius`, `trigger: start_turn`, `save`, `condition`, `until`, `immune_on_success`, `affects`): Stench,
Festering Aura. `absorb`: Lightning Absorption. `sunlight`: `sensitivity`, `weakness`, `hypersensitivity`.
Flags: `pack_tactics`, `undead_fortitude`, `incorporeal_movement`, `spider_climb`, `swarm`, `flyby`,
`pass_through_creatures`, `loathsome_limbs` (by trait id). `make validate` runs tools/data/check_implemented.py,
which fails if a trait or feature says `"implemented": "engine"` and no code reads it.

## Spellcasting

`spellcasting: {ability, dc, attack, at_will, per_day: {"2": [...]}, levels: {spell: level}}`. Spells resolve
through SpellCaster with the stat block's numbers (MonsterActions.cast).

## AI profiles

`pack_hunter`, `brute`, `mindless`, `cowardly`, `skirmisher` (strikes, then Disengages or flies away), `swarm`,
`spellcaster` (Phantasmal Killer, Magic Missile from range, Etherealness to escape when badly hurt), `support`
(Divine Aid's Healing Word for a fallen ally).
