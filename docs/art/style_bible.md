# Style bible (draft 1, Phase 0)

Owner sign-off: approved 2026-10-06. Reference images: Build Log 02 style test (Gemini 3.1 Flash column).

## The look in one line
Gothic horror told as a 1990s Saturday-morning cartoon: bold ink, flat cel shading, big readable
silhouettes, and a small saturated palette in the spirit of *Castlevania: Symphony of the Night*.

## Palette
- One list: `tools/art/build_palette.py` → `art/palette/` (49 colours). Nothing else invents colours.
- Ramps: void/ink/grave (near-black, never pure black) · blood reds · bruised purples · moonlit blues ·
  bone and parchment · bog greens and bile · candle and ember oranges · stone greys · earth browns (peat, umber, walnut, rust, leather, tan) · skin.
- Night scenes sit in purples and blues; warmth comes only from candles, fire and blood.
- The in-game post-process snaps every pixel to the palette at full resolution, with no dithering (owner feedback 2026-10-06: the 2x pixel grid and ordered dither read as grain).
  Sprites are also quantized in the pipeline so they hold up when the pass is off. The pipeline's quantizer keeps neutral
  greys on the grey ramp (so a grey wolf stays grey) and despeckles; `SAT=1.3` is an opt-in chroma boost for
  muted reds that would otherwise snap to brown.
- Character sprites are the exception (owner, 2026-10-06: they read blurry and grainy through the pass): their
  sheets are rendered at 384 px cells, mipmapped, and drawn after the pass at full screen resolution. They keep the
  palette because the pipeline already quantized them.

## Line and shading
- Outlines: dark ink (`void`), heavy on silhouettes, lighter inside. The post-process adds outlines to 3D geometry.
- Shading: two or three flat tones per material, hard edges, no airbrushed gradients.
- Light: one cold key (moonlight, `moonlight`) plus warm local sources (`candle`). Shadows lean purple, not grey.

## Proportions and silhouettes
- Barovians: gaunt, hunched, slightly oversized heads and hands, worn layered clothes.
- Vampires: tall and narrow, sharp collars and capes, long pale faces, red eyes.
- Heroes: slightly heroic proportions (about 7 heads), one strong colour each so they read at sprite size.
- Monsters: exaggerate the one feature that tells you what they are (wolves' jaws, zombies' slump).

## Characters (sprites)
- Generate a **5-view turnaround in one row**: front, front three-quarter, side profile facing right,
  back three-quarter, back. Arms at the sides, same height, clear gaps, plain flat white background
  (Gemini can't do transparency; the pipeline removes the background).
- `make sprite TURNAROUND=<png> ID=<id>` cuts it into a cutout rig and renders 8 directions × 8 walk frames.
- In game a sprite is about 1.5 world units tall (a Medium creature).

## Portraits
- Bust, three-quarter view, candle-lit from below or the side, plain dark purple background (keep scene detail
  out so expressions read in the dialogue frame). 3 to 4 expressions per named NPC.
- Files: `art/portraits/<id>.png` is the default face, `<id>_<mood>.png` the others (moods: neutral, smile,
  angry, afraid, sad, sly, weary). `make portrait` flattens the background to one palette colour; P4-09 used
  `ash_violet` for every set (docs/art/p4_09_art_pass.md).

## Environments
- Low-poly geometry with generated tileable textures; distant scenery as matte paintings.
  Texture sets, billboard props and how they're applied: docs/art/textures.md (`make textures`, `make prop`).
- Barovia is always overcast: heavy cloud, mist at ground level, red sunset bands only at dusk.

## UI
- Iron, parchment and candlelight frames; a highly legible body font. UI is drawn after the palette pass.

## Banned
Photorealism, soft airbrushed gradients, lens blur or bloom-heavy glow, modern clothing or objects,
text or watermarks in images, pure black, neon colours outside the palette, chibi proportions.

## Prompting rules
- Every call goes through `tools/art/generate.sh` (adds `art/prompts/style_preamble.txt`, pins the model, logs the call).
- Model: `gemini-3.1-flash-image` (art/manifest.json, owner pick 2026-10-06).
- Templates live in `art/prompts/`. Ask for a plain flat white background for sprites, parts and props.
- Gemini tends to add scenery behind portraits: say "plain dark purple background, no props or scenery".

## Art QA before "final"
Silhouette reads at in-game size, palette compliance after quantization, all 8 directions consistent,
no background remnants, walk loop has no pops.
