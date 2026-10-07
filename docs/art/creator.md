# The custom hero's paper doll

Owner request (2026-10-06): a character creator where the look is built from hair styles, heads, body types,
heights, genders, beards, starting outfits, skin tones and two voices, with ten portraits to pick from, and where
every combination walks and attacks in 8 directions like every other sprite (docs/art/animation.md).

The options and their prompts are one file, `art/creator/catalog.json`, read by the game and the tools alike.

## The idea: chroma-keyed pieces fitted in game

Gemini draws every piece on a **keyed base figure**: a bald person whose skin is flat lime green (#7CFC00) with
darker lime shading and normal black ink lines. Edits of that figure keep the figure where it was (tested
2026-10-06), so:

| Piece | Drawn as | Count |
|---|---|---|
| Base | a fresh bald, lime-skinned figure per gender and build (an edit can't change a build) | 2 x 3 |
| Body | the base in an outfit (edit), head left bald | 2 genders x 3 builds x 6 outfits = 36 |
| Attack | three keyframes per view of each body, as for every character (art/prompts/attack_keyframes.txt) | 36 x 5 strips |
| Head | the average base with another face, still bald (edit) | 2 x 6 (the plain head is the base) |
| Hair, beard | the male average base with the hair or beard in flat magenta (#FF00FF, edit) | 8 + 6 |
| Portrait | the usual bust portrait (art/prompts/portrait.txt), then `make portrait` | 10 |

`tools/art/creator_art.py --generate` draws whatever is missing in that order; `--process` (or `make creator`)
cuts the pieces. Art lives in `art/generated/creator/` (sources) and `art/creator/pieces/` (what the game reads;
hidden from Godot's importer by a `.gdignore`, which would compress the keys away).

## Cutting the pieces (blender/creator_pieces.py, blender/lib/creator.py)

- **Keys.** Lime pixels (hue 65-165, saturated) are skin; magenta (hue 275-345) is hair. Each keyed pixel gets a
  shade, 0 deep to 3 light, by its value against the region's most common value. Cool grey shading Gemini sometimes
  paints on lime skin counts as skin shadow on the head.
- **The head.** The skin blob at the top of each view, cut at the neck: the narrowest row, measured through the
  head's centre, between 11% and 19% of the figure's height below the skull's top. The skull's width is measured
  4.5% of the figure's height below its top, above where ears or a jaw can widen it.
- **Bodies** walk on the humanoid rig of `render_walk.py` and attack with `render_attack.py`'s six frames, with skin
  rendered in exact key colours (Closest sampling, no anti-aliasing, so they come back untouched). For every frame the
  bald head's skull (centre, top, width) is projected through the rig, and the box holding its skin is stored.
  Everything but the skin is palette-snapped and cleaned like any walk sheet.
- **Heads** are everything above the neck in each view (skull, face, ears, horns), at the walk sheets' pixel size.
  **Hair and beards** are the magenta, its ink outline and anything it encloses, placed against the skull of the base
  they were drawn on (moved by how the edit's lower body sits against the base's).
- Stored form: skin pixels have alpha 254 and hair 253, with the shade in red; everything else is final colour.

## Putting a look together (world/look/hero_look.gd)

`HeroLook.frames(appearance)` tints the body's skin with the chosen tone, then on every frame draws a **head stack**
over the bald head: the head (tinted), the beard (hair colour; scaled by the head's height and hung from the neck)
and the hair (hair colour; scaled by the skull's width and set on its top). West-facing directions use the mirrored
stack. Skin tones and hair colours are four-shade ramps of palette colours. A whole look (walk and attack, 8
directions) takes about 0.2 s and is cached per look.

A custom character's `build.appearance` holds the picks plus `custom: true` and `art` (the portrait id).
`CombatToken.art_for` registers it with `HeroLook`, `DirectionalSprite.frames_for` returns its frames for that id,
and `CombatToken.height_for` gives its height (the species' usual height times the height pick), so tokens, the
lying-down figure, portraits and dialogue all work unchanged.

## Checks

`tests/unit/test_hero_look.gd`: every combination has its pieces (and walks and attacks), composed sheets have no
keys left and wear the chosen colours, tints map shades to ramps, heights follow species and pick, and a custom
character gets its paper doll in game.

## TODO: fuller animation for custom heroes

The six pre-made heroes have the fuller animation set (breathing idle, drawn walk, five-step attack, hit and fall, riding,
sneaking, casting; docs/art/animation.md, "Animation set v2"). Custom heroes from the creator keep the earlier walk
and attack until that set is worked out for paper-doll parts (owner 2026-10-07: about 35 images a hero, so later).
