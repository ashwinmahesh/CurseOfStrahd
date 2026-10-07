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
- Sprites are clean pixel art with no salt-and-pepper (owner feedback 2026-10-06): the cutter smooths the turnaround
  with an edge-preserving filter before cutting it; after the snap it removes only truly lone specks (thin lines that
  sample down to dots keep them) and merges same-coloured clumps of up to 6 pixels into the near shade around them.
  On walk sheets the grey-ramp rule applies only inside mostly grey areas, so thin warm lines on skin stay warm
  (docs/art/p4_cast_art_pass.md). `make sprites` re-renders every sheet with it.
- Character sprites are the exception (owner, 2026-10-06: they read blurry and grainy through the pass): their
  sheets are rendered at 384 px cells, mipmapped, and drawn after the pass at full screen resolution. They keep the
  palette because the pipeline already quantized them.

## Two finishes: Modern (default) and Classic
The owner picked Modern as the default on 2026-10-07 (docs/plans/ui_polish.md); Classic stays in the pause menu's
Settings (`Look.style`, kept in user://settings.cfg by `GameSettings`). The art is the same in both.
- **Classic** is the pass described under Palette: every world pixel snapped to the palette, light in two or three
  hard bands, mist and cloud shadows in flat bands.
- **Modern** keeps the ink outlines and the palette's hues but drops the snap: the cel shaders light with a soft
  ramp (`shaders/cel_light.gdshaderinc`, global uniform `look_soft`), floors and walls use the smooth
  `<surface>_hd.png` tiles (docs/art/textures.md) with relief from a normal map made from the tile itself
  (`Look.normal_map`), AgX tone mapping with glow on anything brighter than white (flames, lanterns), deeper contact
  shadows with bounced light, a thin volumetric haze, smooth mist and cloud shadows, a lighter colour grade, and a
  light depth of field far behind the party that follows the zoom, never near the lens
  (`Atmosphere._modern_finish`, `_focus_dof`, strengths in `Atmosphere.DOF_STRENGTHS`, "light" by default).
- Anything new must read in both: check a place with `make capture SCENE=res://tools/capture/polish_capture.tscn`
  and `POLISH_LOOK=classic|modern POLISH_ONLY=look`.

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
- Every character also has an attack in 8 directions, drawn as wind-up and strike keyframes per view and rendered by
  `make anims`; four-legged and legless bodies get their own walk cycles. See docs/art/animation.md.
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
- Deep crimson and black with aged gold trim (owner's pick after Phase 3, replacing purple and orange). The UI-only
  colours (`ui_black`, `ui_oxblood`, `ui_wine`, `gilt_dark`, `gilt`, `gilt_light`) live in `art/palette/ui_palette.json`,
  never in the world's palette strip. UI is drawn after the palette pass.
- Gothic trim: a wrought-iron corner flourish (mirrored to all four corners), a gilt scrollwork divider and 16 icons,
  drawn by Gemini as black silhouettes and turned into white shapes with alpha (`make ui_art`, `blender/ui_art.py`), so
  the game tints them with palette colours. Screens get the corners, an inner gilt rule and a title plaque on the top
  border; buttons are crimson-black with gilt edges and gilt icons.
- Type: titles, headers and buttons use a medieval book hand the system already has (Luminari on macOS, with
  fallbacks); body text stays in the plain, highly legible default font. No font files are downloaded or shipped.
- Every stock control (tabs, scroll bars, tooltips, text fields, check boxes, pop-ups) falls back to the same look
  (`UiKit.install_theme`).

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
no background remnants, walk loop has no pops, the attack's wind-up and strike read clearly in every direction.
