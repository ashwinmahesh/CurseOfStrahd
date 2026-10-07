# Spell and ability effects

What plays on the combat field when a spell, class feature, trait or monster action is used. The encounter decides
everything; the effects only show it (ADR 0007).

## How it fits together

- `art/vfx/effects.json` is the data. Spells that look alike share a **family** (bolt, beam, burst, heal, smite...);
  each spell's **pick** names its family and, if it needs one, its **flavour**: `"fire_bolt": "bolt"`,
  `"eldritch_blast": "beam@force"`, or an object `{family, flavour, size, count}`. A flavour is five palette colours
  (core, glow, edge, smoke, light), so every effect stays inside the style bible's palette.
- With no flavour a spell takes its icon's tint (`art/icons.json`, `<silhouette>@<tint>`), else its damage type's
  flavour (`damage_flavours`), else arcane. With no pick at all, `SpellFx.derive_family` works one out from the spell's
  data (its area's shape, its attack roll, healing, on-hit), so a new spell always shows something.
- `world/combat/fx/spell_fx.gd` (`SpellFx`) plays a family. The combat view owns one and calls it from
  `_play_events`: `cast` once the caster's gesture lands (`spell` event), `volley` on each attack roll a missile
  spell makes (the `attack` events after the cast: one bolt or beam per roll, a miss sails past), `smite` when a smite
  spell rides a hit (`smite` event, docs/contracts/combat.md).
- `world/combat/fx/fx_kit.gd` (`FxKit`) holds the parts: GPU particle bursts and streams, beams, a churning blast
  sphere, rings on the floor, shafts of light, and real light flashes. Shaders are in `shaders/fx/`. Noise is made
  in code; no textures are needed.
- Effects draw after the palette pass, like the character sprites (render priority 7; floor rings 5), so they stay
  bright, and in the modern finish they bloom. Timings follow the combat speed setting (`GameSettings.combat_pace`).

## Families

The descriptions live in `art/vfx/effects.json` (`families`); every one is built in `world/combat/fx/`.

| family | where it plays | for example |
|---|---|---|
| bolt, ray, beam, shot | caster to each target (FxMissiles), one per attack roll; a miss sails past; a beam can chain | Fire Bolt, Scorching Ray, Eldritch Blast, an arrow |
| touch, drain | a hand's touch; life streaming back to the caster | Shocking Grasp, Vampiric Touch, a vampire's bite |
| burst, cone, line, nova | over the spell's squares (FxAreas): explosion, spray, bolt along a line, shockwave from the caster | Fireball, Burning Hands, Lightning Bolt, Thunderwave |
| strike, cloud, wall, ground, aura | from the sky, billowing, rising, erupting, settling round the caster | Flame Strike, Cloudkill, Wall of Fire, Entangle, Spirit Guardians |
| heal, buff, debuff, psychic, ward, transform | on each creature (FxBodies) | Cure Wounds, Bless, Hex, Vicious Mockery, Shield of Faith, Polymorph |
| smite, slash | on a blow that lands | Divine Smite, a zombie's slam, a longsword |
| summon, teleport, glimmer | where a creature appears, both ends of a jump, a small working | Summon Undead, Misty Step, Detect Magic |

## Lingering areas

A spell that leaves an area on the board (Darkness, Wall of Fire, Web, Grease, Spike Growth, Cloudkill, Spirit
Guardians...) keeps a 3D look for as long as it lasts: `zones` in the data picks one of FxZones' looks (mist, dark,
flames, spikes, vines, tentacles, web, slick, frost, daggers, swarm, spirits, aura, dome, beam, light, storm, quake,
wind, water, prism) and its flavour. The field view (world/combat/field_view.gd) builds it under the zone with a fainter
floor tint (the squares still read for the rules); its emitters start already full, so a moving aura never pops.
Thorns, vines, tentacles and web strands are lit meshes that sway (shaders/fx/fx_sway.gdshader), Grease and ice are
slicks on the floor (shaders/fx/fx_slick.gdshader). `VFX_SET=zones` captures them before and after.

## Abilities and attacks

- **Class features** (`features` in the data) play on the `ability` event the action catalog emits when one is used
  from the hotbar (Second Wind, Rage, Lay On Hands, Patient Defense...). Features the engine shows as a `spell` event
  with a non-spell id (Turn Undead, Divine Spark, Breath Weapon, Elemental Burst) are looked up there too.
- **Monster actions** (`monsters`, keyed `<monster>.<action>`): a save action plays on its `ability` event, an attack on
  its `attack` event (the event's `action` names it). With no pick a ranged attack is a bolt (magic damage) or a shot,
  a melee attack a touch (magic) or a slash, and a save action takes its area's shape or a curse or psychic look,
  coloured by its damage type.
- **Weapons** (`weapons`): a slash on a melee hit, a shot for a ranged attack.
- Creatures that appear (`summon_creature`) open a summoning circle in the last cast's colours; a `teleport` bursts
  into mist at both ends.
- `python3 tools/vfx/assign_families.py` sorts spells into families from their data (plus a list of spells whose
  look the data can't tell) and writes the picks a spell is missing; Faerûn, Arcana Unleashed and Ravenloft: The
  Horrors Within content is skipped.

## Checking it

- `make capture SCENE=res://tools/capture/vfx_capture.tscn NAME=vfx/vfx FRAMES=30` plays each staged spell in the
  Village of Barovia at night twice, effects off and on, and saves the frames (`VFX_ONLY=fire_bolt,fireball` for a
  few, `VFX_SIDES=after` to skip the "before" pass, `VFX_LOOK=classic` for the classic finish, `VFX_SET=gallery` for
  one cast of every family).
- `python3 tools/capture/vfx_sheet.py captures/vfx/vfx` joins them into side-by-side GIFs, stills at the moment the
  two differ most, and `vfx_overview.png`.
- `tests/unit/test_spell_fx.gd` checks the data (picks, families, palette colours) and that effects clean up.
