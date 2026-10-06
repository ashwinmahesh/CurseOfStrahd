# P4 cast art pass: the rest of the Vallaki cast, Stanimir, and clean sprites

Date: 2026-10-06 · Model: `gemini-3.1-flash-image` through `tools/art/generate.sh` (28 calls, all in
`art/generation_log.jsonl`; no fallback model, nothing downloaded) · Per-asset prompts and notes: `art/manifest.json`.

## New characters (sprite + 2 portraits each)

| id | look | portraits | sprite flags | suggested `CombatToken.HEIGHTS` |
|---|---|---|---|---|
| milivoj | big, sullen teenage gravedigger: sheepskin vest, spade at his side | neutral (sullen scowl), `angry` | none | 1.3 |
| henrik | thin, sweating coffin maker: leather apron, three holy symbols | neutral (uneasy), `afraid` | none | 1.22 |
| gunther_arasek | burly stockyard trader: leather apron, rope, keys, ledger | neutral (blunt), `smile` | none | 1.3 |
| luvash | huge grieving Vistani headman: wine-stained shirt, red sash, a bottle in each hand | neutral (bleary, grief-worn), `sad` | none | 1.38 |
| arabelle | solemn seven-year-old Vistani girl: red headband, purple and mustard skirts, barefoot | neutral (grave), `sly` (a knowing half-smile) | `SAT=1.3` | 0.75 |
| bluto | gaunt, drunk fisherman: knit cap, ragged oilskin coat, net, empty bottle | neutral (haggard), `afraid` | none | 1.22 |
| kasimir_velikov | dusk elf in Vistani dress: ash-grey skin, white hair, wine vest, purple sash, long coat | neutral (grave), `sad` | none | 1.32 |
| stanimir | huge grey-bearded Vistani elder: red headscarf and sash, green vest, fiddle | neutral (warm), `angry` | `SAT=1.3` | 1.38 |

- The second mood is the one each character's dialogue uses most (Henrik 5x `[afraid]`, Luvash 3x `[sad]`,
  Stanimir 5x `[angry]`, Milivoj `[angry]`/`[sad]`); for the three with no tags it is the one that fits the voice bible.
- Files follow P4-09: `art/generated/characters/<id>_turnaround.png` → `art/sprites/<id>/walk.png` + `walk.tres`
  (8 directions × 8 frames, 384 px cells, VRAM BPTC with mipmaps); `art/generated/portraits/<id>[_<mood>]_portrait.png`
  → `art/portraits/<id>.png`, `<id>_<mood>.png` (`make portrait … BG=ash_violet`, `SAT=1.3` for Arabelle and Stanimir,
  like their sprites). Base portraits use the turnaround as the reference; the mood uses the base portrait.
- Region 3: Stanimir was the only Tser Pool NPC without art. Luminita uses `vistana`, Bogdan and Grigor use
  `commoner`/`villager`, Kolyan Indirovich uses `noble`, and those files exist.
- The NPC files already point at these ids, so the game picks them up as they are. `CombatToken.HEIGHTS` (world/,
  the lead's file) has no entry for them yet, so they stand at its default 1.2: right for most, but Arabelle would
  stand as tall as an adult. The table's last column is the suggestion.

## Clean sprites: smoothing before the cut, lone specks and small clumps after the snap

Owner feedback today: the screen pass no longer pixelates or dithers, and the sprites still showed salt-and-pepper in
flat areas (Arrigal's trousers, vest and sash were the clearest case; the Phase 2-3 sheets, made before P4-09's
despeckle, were the worst). The noise comes from Gemini's JPEG data and faint painted texture: a flat area whose colour
sits between two palette shades flips between them pixel by pixel, in clumps of every size, so no post-snap filter
alone fixes it. And P4-09's single-pixel despeckle had a cost of its own: a thin line (a jaw line, an eyelid) samples
down to a dotted line in a 384 px cell, every dot looks like a speck, and faces lost their features.

`blender/render_walk.py` now runs (all in `blender/lib/cutout.py`; `--no-clean` renders the P4-09 way for comparison):

1. **`smooth_colours`** on the cut-out turnaround, before the figures are cut: an edge-preserving (bilateral) filter,
   radius 3 px, colour sigma 0.06, two passes, over opaque pixels only. Neighbours of a similar colour are averaged, so a
   flat area settles on one side of the palette boundary; ink lines and colour edges are far more than the sigma apart
   and keep their pixels.
2. **`quantize(..., neutral_area=0.5)`**: the P4-09 grey-ramp rule (the wolf fix) applies only where half of the
   pixel's 7x7 neighbourhood is grey too (fur, mail, a grey coat). A thin warm-grey line on skin snaps to the browns
   around it instead of becoming a cool grey blotch (Arrigal's and Hedda's faces had them). The wolf stays grey.
3. **`despeckle(..., near=0.3, ring=True)`**: a pixel goes only if nothing within the 5x5 window is its colour or a near
   shade, so dotted lines keep their dots and lines drawn in two dark shades (void, ink) count as one.
4. **`merge_islands`**: a same-coloured, 8-connected patch of at most 6 pixels takes the most common near shade
   around it (redmean distance ≤ 0.45: two greys, blood and rust, two skin tones next to each other, void and ink).
   Lines longer than 6 pixels are never touched, and patches with no near shade around them (an ink pupil on skin is
   1.6 away, a skin highlight 0.5) keep their pixels.

Pixels with at most 2 of 8 neighbours in their own colour (speckle, plus the thinnest line ends) across the 47
re-rendered sheets: 20.4% of opaque pixels before, 7.9% after on average (median 21.8% → 7.3%; the Phase 2-3 sheets fell from 20-47% to 3-8%, the P4-09 ones from 4-11% to 3-7%). All sheets stay palette-only.

Every character sheet was re-rendered from its turnaround with its original flags by the new **`make sprites`**
(`tools/art/rerender_sprites.py`; each manifest entry now records its `sprite_flags`, e.g. `["SAT=1.3"]` or
`["STATIC=1"]`): the 47 existing sheets (party, Village and Death House cast, monsters, the Vallaki cast, and the
static wolf, dire wolf, specter, flying sword, broom, grick, shambling mound and rat swarm) plus the 8 new ones.
`walk.tres` files are unchanged except `villager`, whose Phase 0 sheet was still 192 px cells and is now 384 like the
rest (`DirectionalSprite` reads the cell size from the frames). Not re-rendered: `villager_standin` (the primitive
pipeline stand-in, unused). Portraits keep their pipeline (box-downscaled 1024 → 512, which already averages the
noise), so the existing 3-to-4-expression sets still match.

## Tools added

- `make sprites [ONLY="id …"]` (`tools/art/rerender_sprites.py`): re-renders walk sheets from the manifest.
- `tools/art/check_npc_art.py [--all]`: NPCs in `data/npcs/` whose `art/portraits/<portrait>.png` or
  `art/sprites/<sprite>/walk.png` is missing, and the moods each has.
- `tools/art/preview/character_preview.tscn`: a line-up of walk sheets on a cobbled floor with the cel lighting and the
  palette pass, with each one's portraits on a UI layer; shots `_lineup`, `_walk` (each facing another direction) and
  `_close`. `make capture SCENE=res://tools/art/preview/character_preview.tscn NAME=p4_cast FRAMES=30`
  → `captures/p4_cast_*.png`.

## Not right yet (for art QA)

- Gunther's dark green tunic snaps to charcoal grey (stone/slate) in his sprite and portraits. `SAT=1.3` only added
  green specks and 1.7 turned his skin red, so he stays at the default: he reads as a grey-shirted trader.
- Stanimir's turnaround drops the fiddle in the side view (E/W directions) and shows the bow only in the front
  three-quarter view.
- Kasimir's ash-grey skin snaps to the slate/pewter greys: readable as a dusk elf, but cool rather than ashen.
- Henrik's grey trousers keep two flat grey tones in broad patches (the source's cel shading), not speckle.
- Luvash's and Bluto's first portraits came out as floating cameo busts (Luvash's face also orange from the
  candlelight); both were regenerated with the shoulders running off the bottom edge, and their moods made from the
  new bases.
- Ilse's mail shirt still reads busy: that is the drawn chain texture, larger than the island limit.
- Ireena's dusky-blue dress snaps to grey with blue patches (a quantizer limit, as before this pass, not speckle).

## NPCs still without art

`tools/art/check_npc_art.py` lists 11, all from earlier phases and outside this pass: Village of Barovia `alenka`,
`mirabel`, `sorvia` (Vistani; could use `vistana`), `arik`, `doru` (the `vampire_spawn` sheet is drawn as Doru);
Death House `gustav_durst`, `elisabeth_durst`, `durst_nursemaid`, `lorghoth`, `cult_shades`; Into the Mists
`mists_wolves` (could use `wolf`). Pointing an NPC at shared art is a data change for the lead or the writers.
