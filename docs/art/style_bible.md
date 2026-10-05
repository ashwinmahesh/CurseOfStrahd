# Style bible (draft 1, Phase 0)

Owner sign-off: **pending**. Reference images: Build Log 02 style test (gpt-image-2.5-flare column).

## The look in one line
Gothic horror told as a 1990s Saturday-morning cartoon: bold ink, flat cel shading, big readable
silhouettes, and a small saturated palette in the spirit of *Castlevania: Symphony of the Night*.

## Palette
- One list: `tools/art/build_palette.py` → `art/palette/` (49 colours). Nothing else invents colours.
- Ramps: void/ink/grave (near-black, never pure black) · blood reds · bruised purples · moonlit blues ·
  bone and parchment · bog greens and bile · candle and ember oranges · stone greys · earth browns (peat, umber, walnut, rust, leather, tan) · skin.
- Night scenes sit in purples and blues; warmth comes only from candles, fire and blood.
- The in-game post-process snaps every pixel to the palette at a 2x pixel grid with light ordered dithering.
  Sprites are also quantized in the pipeline so they hold up when the pass is off.

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
  back three-quarter, back. Arms at the sides, same height, clear gaps, transparent background.
- `make sprite TURNAROUND=<png> ID=<id>` cuts it into a cutout rig and renders 8 directions × 8 walk frames.
- In game a sprite is about 1.5 world units tall (a Medium creature).

## Portraits
- Bust, three-quarter view, candle-lit from below or the side, plain dark purple background (keep scene detail
  out so expressions read in the dialogue frame). 3 to 4 expressions per named NPC.

## Environments
- Low-poly geometry with generated tileable textures; distant scenery as matte paintings.
- Barovia is always overcast: heavy cloud, mist at ground level, red sunset bands only at dusk.

## UI
- Iron, parchment and candlelight frames; a highly legible body font. UI is drawn after the palette pass.

## Banned
Photorealism, soft airbrushed gradients, lens blur or bloom-heavy glow, modern clothing or objects,
text or watermarks in images, pure black, neon colours outside the palette, chibi proportions.

## Prompting rules
- Every call goes through `tools/art/generate.sh` (adds `art/prompts/style_preamble.txt`, pins the model, logs the call).
- Model: `gpt-image-2.5-flare-2026-09-08` (art/manifest.json).
- Templates live in `art/prompts/`. Ask for transparent backgrounds for sprites, parts and props.

## Art QA before "final"
Silhouette reads at in-game size, palette compliance after quantization, all 8 directions consistent,
no background remnants, walk loop has no pops.
