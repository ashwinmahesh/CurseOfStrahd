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

| family | what it looks like | pilot spell |
|---|---|---|
| bolt | a glowing missile with a trail streaks from the hand and bursts on the target | Fire Bolt |
| beam | a crackling beam joins hand and target for a moment, flaring where it lands | Eldritch Blast |
| burst | a bead arcs to the point and explodes: churning ball sized to the area, shockwave, sparks, smoke | Fireball |
| heal | warm light wells up: a soft shaft, spiralling motes and a circle of light at the feet | Cure Wounds |
| smite | a shaft of light strikes down on the target as the blow lands, sparks and a ring across the floor | Divine Smite |

## Checking it

- `make capture SCENE=res://tools/capture/vfx_capture.tscn NAME=vfx/vfx FRAMES=30` plays each staged spell in the
  Village of Barovia at night twice, effects off and on, and saves the frames (`VFX_ONLY=fire_bolt,fireball` for a
  few, `VFX_SIDES=after` to skip the "before" pass, `VFX_LOOK=classic` for the classic finish).
- `python3 tools/capture/vfx_sheet.py captures/vfx/vfx` joins them into side-by-side GIFs, stills at the moment the
  two differ most, and `vfx_overview.png`.
- `tests/unit/test_spell_fx.gd` checks the data (picks, families, palette colours) and that effects clean up.
