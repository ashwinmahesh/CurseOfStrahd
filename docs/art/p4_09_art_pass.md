# P4-09 art pass: main characters, Vallaki cast, Village and Vallaki environments

Date: 2026-10-06 · Model: `gemini-3.1-flash-image` through `tools/art/generate.sh` (105 calls this pass, all in
`art/generation_log.jsonl`; no fallback model was used, and nothing was downloaded) · Per-asset prompts and notes:
`art/manifest.json`.

## Owner notes from Build Log 04

| Note | Fix |
|---|---|
| Ilse's face reads masculine | New turnaround (old sheet as the reference, same kit): a clearly feminine face, a scar and an ash-blonde braid. Re-rigged (`make sprite … SAT=1.3`, which also keeps the tabard red instead of rust), new portrait from the new sheet. |
| Silvain's portrait has a strong red rim light | Regenerated with soft frontal candlelight and an explicit "no rim light" line; navy and silver robes. The expressions keep the same line. |
| The grey wolf comes out beige after the palette pass | Pipeline fix: the palette's greys are cool and a neutral mid grey sat closer to `bone` by redmean. `cutout.quantize` now matches near-neutral pixels only against low-chroma palette colours (stone, slate, pewter, silver…), so greys stay grey. The wolf sheet and portrait are re-rendered from the same sources. |
| One expression per named character | See below. |

## Portraits (`art/portraits/<id>.png`, `<id>_<mood>.png`)

- **Pregens, 4 each:** Ilse (neutral, smile, angry, weary), Tamsin (his grinning base, afraid, sly, sad),
  Hedda (neutral, smile, angry, sad), Silvain (neutral, smile, afraid, angry).
- **Village of Barovia:** Ireena gains `angry` (now 4); Donavich gains `afraid` and `sad` (now 3); Ismark
  already had 3.
- **Phase 4 cast, 3 each:** madam_eva (sly, sad), baron_vargas (angry, afraid), izek (angry, sly), lady_wachter
  (sly, angry), father_lucian (afraid, sad), rictavio (sly, weary), urwin_martikov (smile, angry), arrigal (sly,
  angry), victor_vallakovich (angry, afraid). **2 each:** blinsky (his grinning base, sad), danika_martikov
  (angry), lydia_petrovna (her beaming base, afraid). **1 each:** vallaki_guard, vistana.
- 50 new portrait files, plus 9 existing ones regenerated or reprocessed (ilse_varga, silvain_aster;
  tamsin_tealeaf, hedda_ironvow, ireena ×3, donavich and wolf reprocessed from their old sources, so each set
  matches its new expressions).
- Base portraits use the character's turnaround as the reference; expressions use the base portrait, with only
  the expression changed. Three variants drifted and were regenerated: Father Lucian's sad face turned into
  another man, Rictavio's weary face went blue, and Silvain's angry robe went brown.

## Sprites (`art/sprites/<id>/walk.png` + `walk.tres`, 8 directions × 8 frames, 384 px cells)

New: madam_eva, baron_vargas, izek, lady_wachter, father_lucian, rictavio, blinsky, urwin_martikov,
danika_martikov, arrigal, victor_vallakovich, lydia_petrovna, vallaki_guard, vistana (14). Re-rendered:
ilse_varga, wolf. All are imported as VRAM (BPTC) with mipmaps, like the existing sheets.

Suggested `height_units` relative to a human (the rig fills the cell with the tallest view): Madam Eva about
0.85 (tiny and stooped), Izek 1.1, Rictavio 1.1 (hat and feather), Blinsky 1.05 (cap), the guard 1.15 (the
spear tip sets the figure height), Danika, Victor, Lydia and the Vistana about 0.95, the rest 1.0. These are
estimates: check them in a capture.

## Environments and props

18 seamless 512 px textures in 5 themes (`art/textures/`, `art/textures/manifest.json`) and 12 billboard props
(`art/sprites/props/`, with their own manifest). How they were made and how to apply them:
[textures.md](textures.md).

## Pipeline changes (all under blender/ and tools/art/)

- `tools/art/generate_gemini.py` writes **real PNGs**. Gemini returns JPEG data, and Godot refuses JPEG bytes
  behind a `.png` name, which broke `make import` mid-pass. Returned images are now converted with macOS `sips`
  in a temp folder. The 165 JPEG-in-PNG files already under `art/` (all earlier generations too) were converted
  in place: same pixels, real PNG.
- `cutout.quantize`: neutral greys stay on the grey ramp (the wolf fix). This applies to every future sprite,
  portrait, texture and prop; existing assets change only when re-rendered.
- `cutout.despeckle`: an opaque pixel with at most one same-coloured neighbour takes its neighbours' colour.
  This clears the salt-and-pepper JPEG noise left after snapping. Used by portraits, walk sheets, textures and
  props.
- `cutout.saturate` and `SAT=` on `make sprite` / `make portrait` / `make prop`: an opt-in chroma boost before
  snapping. Gemini's muted reds otherwise land on leather or rust. Used at 1.3 for Ilse, Madam Eva, Izek (the
  fiendish arm), Blinsky, Lydia, the guard and the market stall.
- `blender/portrait.py`: flattens the background to one colour (`BG=<palette name>`, default the border's own).
  It floods from the top and side borders through the border's colours and absorbs small specks. This pass
  uses `BG=ash_violet`, the colour most existing portraits already had.
- New: `blender/make_texture.py`, `tools/art/build_textures.py` + `texture_recipes.json` (`make textures`),
  `blender/prop_sprite.py` (`make prop`), `tools/art/set_import.py` (VRAM + mipmap import settings),
  `tools/art/preview/` (preview scene and a reference world-UV cel shader).

## Not right yet (for art QA)

- The quantizer still shifts colours: Blinsky's motley is loud orange and green from the back, the guard's
  iron helmet reads blue, and Victor's angry face is cold grey-blue. All are readable, none is
  photoreal-wrong.
- Lady Wachter's gown came out black and maroon rather than black and plum.
- Some textures repeat visibly over large areas: the mud road's puddles, the dungeon floor's tan blocks, the
  plaster wall's brick patches. textures.md suggests per-region UV offsets.
- The lantern post's painted glow left a few pale pixels beside the lantern.
- Expression variants of the same character are close but not identical (hair strands, collar details), as
  with the Phase 3 sets.
- Nothing is wired into the game yet (the lead's step). The textures and props were checked in Godot with the
  cel lighting and palette pass in `tools/art/preview/texture_preview.tscn`
  (`captures/p4_09_textures_*.png`); the characters have no in-game capture yet.
