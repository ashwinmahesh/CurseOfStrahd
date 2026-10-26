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
- `addons/dnd_core/world/combat/fx/spell_fx.gd` (`SpellFx`) plays a family. The combat view owns one and calls it from
  `_play_events`: `cast` once the caster's gesture lands (`spell` event), `volley` on each attack roll a missile
  spell makes (the `attack` events after the cast: one bolt or beam per roll, a miss sails past), `smite` when a smite
  spell rides a hit (`smite` event, docs/contracts/combat.md).
- `addons/dnd_core/world/combat/fx/fx_kit.gd` (`FxKit`) holds the parts: GPU particle bursts and streams, beams, a churning blast
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
| burst, cone, line, nova | over the spell's squares (FxAreas): explosion, spray, bolt along a line, shockwave from the caster | Fireball, Burning Hands, Lightning Bolt, Thunderwave, Thunder Step (round the space it leaves, ahead of the jump) |
| strike, cloud, wall, ground, aura | from the sky, billowing, rising, erupting, settling round the caster | Flame Strike, Cloudkill, Wall of Fire, Entangle, Spirit Guardians |
| heal, buff, debuff, psychic, ward, transform | on each creature (FxBodies) | Cure Wounds, Bless, Hex, Vicious Mockery, Shield of Faith, Polymorph |
| feast | on each creature that eats (FxBodies): a wide warm circle, steam, rising gold motes; the exploring view plays it with its own table sounds (`combat.keys.heroes_feast`) when the feast lands | Heroes' Feast |
| smite, slash | on a blow that lands | Divine Smite, a zombie's slam, a longsword |
| summon, teleport, glimmer | where a creature appears, both ends of a jump, a small working | Summon Undead, Misty Step, Far Step, Detect Magic |

## A change of shape

Every shapeshifter shows its change the same way (owner ask, 2026-10-14): the creature's old figure gathers and
flares, then the new one arrives in a flash, with a sound. It covers Polymorph and the other spells (`ShapeChange`'s
`shape` events: Wild Shape, True Polymorph, Shapechange, Animal Shapes, Boon of Fluid Forms), a Shapechanger's bat, wolf
and mist (`Legendary._set_form`'s `form` events: Strahd, vampires, Misty Escape) and a lycanthrope's hybrid
(`MonsterActions.show_form`: Emil and Kiril swap to the werewolf's figure through the stat block's `hybrid_art`; the
wereraven allies to the wereraven's), in both directions. `CombatView._swap_form_art` is the one place a figure is
swapped: `SpellFx.shape_gather` (motes spiral up and a circle closes on the old figure, which flares; the change's sound
starts) and a beat of `FxShapeshift.GATHER` at the combat speed, then the swap and `SpellFx.shape_settle` (a light
flash, smoke, streaks and glints from the new figure, which fades in). The event's `kind` picks how it looks
(`FxShapeshift.LOOKS`: werewolf, wereraven, bat, wolf, mist, wild_shape, polymorph, default) and sounds (`combat`
`shapeshift` in art/audio.json, layered from the repo's own recordings, so the sound slider sets how loud they are). A
kind with no entry gets the default's, so a new shapeshifter needs only to emit the event. A figure nobody can see (an
Invisible foe's), and a fight with its effects off, change at once with no effect or sound.

The same effect covers the other routes to a new figure (the audit, owner ask 2026-10-14): the lycanthropy curse (the
cursed creature gathers and changes where it fell, then the werewolf arrives in a flash: the `vanish` and
`summon_creature` events' `becomes`); a shape with no sprite of its own (it still shows on the figure it has: every
monster has a sprite today, and a test keeps it so); a fight picked up from a save with someone mid-shape
(`CombatView._restore_forms` puts each in the figure it was in, so it can still change back); and a person the story
showed who turns out to be something else when their conversation ends in a fight (`LocationNpcs.hide_npcs_of` keeps who
stepped aside; a foe of the same name whose stat block has a `reveal`, a kind from `FxShapeshift.LOOKS`, changes in
front of the party: Offalia and the other hags, Vosk, the Abbot, the vampire spawn Anatol, Doru, Escher and the brides,
Patrina, Zuleika; `LocationFights._reveal`).

More shapes (the forms branch): a Werewolf's wolf and a Wereraven's raven (`forms` in their stat blocks, taken with
`MonsterActions.shift(c, "wolf")`; an ally the player runs sees a hotbar entry for each), Baba Lysaga's swarm of insects
and a Night Hag's disguise (`art_from_npc`: the figure of the NPC the creature is named for, `Legendary.shape_art`) are
all `Legendary` shapes, so they size, speed, save, load and show like Strahd's. The AI shifts only a lycanthrope into its
hybrid (`MonsterActions.bonus_action`). Starry Form, Celestial Revelation, Disguise Self and Seeming, which change how
someone looks but swap no figure, show the transform cue (`features` and `spells` in art/vfx/effects.json) and sound
(`keys` in art/audio.json), like Alter Self, Gaseous Form and Enlarge/Reduce already did.

A Werewolf or Wereraven foe walks in as a person (`human_art`: werewolf_human, wereraven_human, drawn 2026-10-15) and
changes into its hybrid (`art`) when the AI shifts it on its first turn, with the same effect and sound; a named one the
story showed (Zuleika) wears that NPC's figure, an ally (Davian) keeps their own face, and the turn bar keeps the
creature's portrait (`CombatToken.human_figure`, `true_figure`, `portrait_id`).
`make capture SCENE=res://tools/capture/shapeshift_capture.tscn NAME=shapeshift/shot` takes a filmstrip of each.
`tests/integration/test_shapeshift_effect.gd` and `test_shapeshift_audit.gd` check it; `reveal_capture.tscn` takes the
story reveal.

## Lingering areas

A spell that leaves an area on the board (Darkness, Wall of Fire, Web, Grease, Spike Growth, Cloudkill, Spirit
Guardians...) keeps a 3D look for as long as it lasts: `zones` in the data picks one of FxZones' looks (mist, dark,
flames, spikes, vines, tentacles, web, slick, frost, daggers, swarm, spirits, aura, dome, beam, light, storm, quake,
wind, water, prism) and its flavour. The field view (addons/dnd_core/world/combat/field_view.gd) builds it under the zone with a fainter
floor tint (the squares still read for the rules); its emitters start already full, so a moving aura never pops.
Thorns, vines, tentacles and web strands are lit meshes that sway (addons/dnd_core/shaders/fx/fx_sway.gdshader), Grease and ice are
slicks on the floor (addons/dnd_core/shaders/fx/fx_slick.gdshader). `VFX_SET=zones` captures them before and after.

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

## Traps and falls

Outside a fight a trap that goes off, a pit's fall and a climb or swim that fails and hurts show themselves the same
way (owner todo, 2026-10-17). Once the big d20 has been seen, and no cutscene or screen holds the game
(`addons/dnd_core/world/exploration/location_hurt.gd`, `LocationHurt`; its waiting runs on timers that run while the game is paused):

- the figure flashes red and flinches;
- the trap's own effect plays on it (`addons/dnd_core/world/exploration/trap_fx.gd`, `TrapFx`), built from the same parts as the
  fights' effects: a lamp or tripwire that burns bursts into flame, a glyph or ward calls down lightning, a ward of
  thunder or force sends a shockwave, a vent of frost or a breath of soot billows, blades slash, needles, bolts and
  shards fly in (`darts`, from above, the side or below), and a weight or a failing floor comes down in chunks, dust
  and a ring across the ground (`crash`: a rotten floorboard, a beam, a pit, a slip from a ledge). A save that held
  plays at 60%. Physical harm sounds as a blow lands (`CombatSfx.hit`);
- the damage floats over their head (`FloatText`, the mark a fight uses, about 2.4 seconds), the fall and the stakes of
  a pit as one number, "Unhurt" when nothing got through;
- the party panel shows their new Hit Points (`LocationView.party_hurt`; before this the cards kept the old value until
  something else refreshed them).

The looks are data: `art/vfx/effects.json` `traps` (by trap id), `checks` (by a world check's id), then `trap_damage` (by
damage type). A pick is `"<family>@<flavour>"` or `{family, flavour, size, count, from}`; `tests/integration/test_trap_fx.gd`
checks that every trap in the game has a look and that no pick names something that isn't there. In a fight the same
damage numbers come from the `damage` event, so a trap there floats its damage like a blow does
(`tests/integration/test_combat_damage_marks.gd`).

## Checking it

- `make capture SCENE=res://tools/capture/vfx_capture.tscn NAME=vfx/vfx FRAMES=30` plays each staged spell in the
  Village of Barovia at night twice, effects off and on, and saves the frames (`VFX_ONLY=fire_bolt,fireball` for a
  few, `VFX_SIDES=after` to skip the "before" pass, `VFX_LOOK=classic` for the classic finish, `VFX_SET=gallery` for
  one cast of every family).
- `python3 tools/capture/vfx_sheet.py captures/vfx/vfx` joins them into side-by-side GIFs, stills at the moment the
  two differ most, and `vfx_overview.png`.
- `tests/unit/test_spell_fx.gd` checks the data (picks, families, palette colours) and that effects clean up.

## Sounds

Every effect sounds the way it looks (addons/dnd_core/world/combat/fx/combat_sfx.gd, `combat` in art/audio.json). A family names the
sounds of its moments: `cast` (the effect begins), `launch` (a missile leaves the hand), `impact` (it lands or bursts),
`arrive` (a jump's far end). An entry starting with `@` is the flavour's own sound for that moment, so Fire Bolt and a
flameskull's Fire Ray share fire's launch and burst, and Fireball layers a rumble under the same burst. `keys` gives a
spell or ability its own sounds (Hold Person's chains); a family with no entry plays the plain spell sound. The
sustained class abilities sound as a hero switches them on, through `keys` too (Rage, Bladesong, Wild Shape, Vow of
Enmity, Sacred Weapon, Innate Sorcery, Hunter's Mark, Hex, Divine Favor; owner, 2026-10-07): a feature with no effect
of its own still plays its key's sound, a key with a choice in it ("wild_shape:wolf") plays its kind's, and an entry
written `<id>@<seconds>` comes in that long after the others. `concentration` holds the soft cue when a hero starts
concentrating on a spell and the sharp one when a blow breaks it (the combat view watches each caster's
Concentration).

A blow (a weapon, claw or bite) sounds by what struck and how hard it landed: `hits` has blade (slashing), blunt
(bludgeoning, cracking bone on heavy and critical hits), point (a melee pierce) and shot (an arrow, bolt or throw),
each light, heavy (a quarter of the target's Hit Point maximum, or 15 damage) or critical. A spell's missile or a
magic touch sounds through its flavour instead. Levels in art/audio.json `levels` set each sound's volume; the owner
picked the sounds by ear (2026-10-07, three rounds of samples).
