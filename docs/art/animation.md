# Character animation: walk and attack

Every character and creature sprite walks in 8 directions and has an attack in 8 directions (owner request
2026-10-06). Props and scenery stay still.

## Files

| What | Where |
|---|---|
| Each character's attack: who, the move, its wind-up and strike, whether it's a spell gesture (`casts`) | `art/anim/animations.json` |
| How each walk sheet is made: `BODY=quadruped` etc., `SAT=1.3` (the flags `make sprites` uses) | `art/manifest.json` `sprite_flags` |
| Prompt templates | `art/prompts/attack_keyframes.txt`, `art/prompts/walk_keyframes.txt` |
| Keyframe strips (Gemini, one per view) | `art/generated/anim/<id>/attack_<view>.png`, `walk_<view>.png` |
| Walk sheet | `art/sprites/<id>/walk.png` + `walk.tres` (walk_<dir>, idle_<dir>) |
| Attack sheet | `art/sprites/<id>/attack.png` + `attack.tres` (attack_<dir>, metadata `hit_frame`) |

`art/generated/anim` has a `.gdignore`: Godot never imports the strips.

## Commands

- `make anims` re-renders every walk sheet (with its manifest flags, like `make sprites`) and every attack sheet
  from the strips; `ONLY="wolf ilse_varga"` limits it.
- `make anims ONLY=<id> GENERATE=1` first draws any missing strips for that character.
- `tools/art/anim_keyframes.py --only <id> --views side front` redraws chosen strips (when a check or a look
  at the sheet finds a bad one); `--retry 2` redraws what `render_attack.py --check` flags.

A new character: `make sprite ...` as before (with `BODY=<type>` for a body the humanoid rig can't walk, recorded in
its manifest `sprite_flags`), add an entry to `animations.json` (copy a similar one: `who`, `attack`, `windup`,
`strike`, and `casts` for a spell gesture), then `make anims ONLY=<id> GENERATE=1`, then look at
`art/sprites/<id>/attack.png`.

## Attack keyframes

The turnaround sheet is cut into one image per view (`blender/anim_refs.py`). For each view Gemini draws a strip of
three figures from that same angle: 1) the reference pose redrawn, 2) the wind-up, 3) the strike. Drawing one view
per image gives far livelier poses than asking for a whole 5-view action sheet, which Gemini treats as a small edit
of the reference (arms barely move). 21:9 leaves room for a swung weapon.

`blender/render_attack.py` then:

- **Scale**: frame 1's height against the turnaround view's height gives the strip's scale, so wind-up and strike
  come out at the walk sheet's pixel size.
- **Colour**: frame 1's per-channel tone curve is matched to the turnaround view (quantile matching) and applied to
  the whole strip, so a strip drawn a shade darker doesn't pop.
- **Feet**: each pose stands where the view stands, by the median column of its lowest fifth (between the feet).
- **Frames** (12 fps, per-frame durations): wind-up squashed, wind-up held, strike stretched and leaning in
  (the hit frame), strike, strike settling, back to the standing view. About 0.6 s, blow at 0.2 s.
- **Cells** are as big as the character's widest and tallest pose needs: rendered large, then cropped evenly
  round the walk cell's centre at its pixel scale, so a raised sword or a lunge fits and the figure keeps its size
  and ground line (the game centres each frame). At least 1.25x the walk cell's width.
- **Checks** (`--check`): figures merged or clipped by the picture's edge, or frame 1 not shaped like the view
  (Gemini put a new pose first). Flagged strips are redrawn.

## Walk

- **People** (no `BODY` flag): the cutout rig of `blender/render_walk.py`. Head-on, the legs lift and
  bend in turn and the body sways over the planted foot; in profile the legs swing. The body dips on each stride.
- **Four-legged** (`BODY=quadruped`: wolves): profile and three-quarter views trot on two drawn strides from
  `walk_<view>.png` strips (stretched, gathered) with the standing view as the passing pose; head-on views lift
  their leg halves. Cells are 1.5x wide so a stretched wolf fits.
- **float** (specter, flying sword): hovers, bobs and leans into the glide. **hop** (broom): squash, leap, land.
  **slither** (grick), **lumber** (shambling mound), **swarm** (rats): squash, stretch and rock the one plane.
- Frame 0 of every cycle is the rest pose: it is also the idle frame.

## Animation set v2 (the six heroes; owner 2026-10-07)

The owner asked for fluid, expressive animation like a modern 2D game, and poses for riding, hiding and casting. The
six pre-made heroes get a fuller set, drawn rather than rigged: `tools/art/anim_keyframes.py --kind <kind>` draws one
strip per view at 2K (frame 1 the turnaround view redrawn, then the poses), and `blender/render_keys.py --kind <kind>`
turns the strips into sheets, adding in-between frames (squash, stretch, lean, a small step) and the timing.

| Kind | Drawn poses | Sheet and animations |
|---|---|---|
| `walk8` (strips `walk8a`, `walk8b`) | contact, down, passing, up for each foot (four poses a strip) | `walk`: walk_ (16 frames at 20 fps with the body's rise and fall), idle_ (breathing, 6 frames) |
| `attack10` (strips `attack10a`, `attack10b`) | ready, settling, anticipation, coiling, wind-up; the strike starting and landing (motion smears), follow-through, recovering, back to ready | `attack`: 11 frames, the blow on frame 6 |
| `hurt` | flinch, stagger, collapse to the knees, lying | `hurt`: hurt_ (flinch and recover), die_ (the fall), down_ (lying) |
| `ride` | seated astride (the horse drawn flat magenta and keyed out), weapon raised, striking down | `ride`: ride_idle_, ride_attack_ |
| `sneak` | crouched, two crouched steps | `sneak`: sneak_idle_, sneak_walk_ |
| `cast` | gathering, releasing | `cast`: cast_ (the release lands on frame 3) |
| `idle4` (with `walk8a`, `walk8b`: plan `walk8i`) | the cape stirring, billowing and settling while he stands | `walk`: as `walk8`, but idle_ is the drawn loop (8 frames at 6 fps) instead of breathing |

(Doubled frames, owner 2026-10-07: `walk4` and `attack5`, one strip of four or five poses, came first and still
render.) About 40 strips a hero (8 strips for 6 kinds, 5 views; the other 3 directions are mirrors), plus redraws;
poses keep the reference's colours and gear, and the check flags a recoloured pose. Strips are still worth a look
by eye: Gemini sometimes drops a hat or hands a bare-handed hero a staff (`"unarmed": true` in animations.json tells the
prompt there is no weapon); redraw one view with `tools/art/anim_keyframes.py --only <id> --kind <kind> --views <view>`.
Touching poses (a beam reaching the next figure) are cut apart at even spacing (`anim.split_even`). `--check` (as for
attacks) flags merged, clipped or mis-scaled strips, and panel borders Gemini sometimes draws are dropped.

**Strahd (owner 2026-10-09: "give Strahd's sprite better animation treatment than the rest of the monsters since he
is the main villain").** The main villain has the fuller set too, from a menacing turnaround (fangs, claws, a torn
cape; `strahd_turnaround.png` and its `_hd`): `walk8i` (the walk plus a drawn idle, `idle4`, where his cape stirs and
billows while he stands), `attack10`, `hurt` and `cast`, no riding or sneaking (`tools/art/build_keys.py` KEYED). His
animations.json entry has `flow`, a sentence added to every strip's prompt so the cape moves in every pose, and
`cast_gather` / `cast_release` for his shadow spell. `make keys ONLY=strahd` renders them; `make anims` leaves him
alone. His dark aura (below) is drawn at run time, not in the sheets.

**HD sheets (owner 2026-10-07: "crystal clear, and higher-res when zoomed in").** The heroes' cells are 768 px
(twice the earlier 384). Each hero's turnaround is redrawn at 2K, faithful to the original with sharper line art
(`<id>_turnaround_hd.png`, used for the standing frames and as the colour reference; `blender/hd_colour.py` gives the
redraw the original's colours where Gemini drifted, since the strips were drawn from the original), and frames render
at twice the
cell and are area-averaged down, so lines stay clean instead of dropping pixels. Each frame is trimmed to its figure
plus a 12 px border (room for the shader's outline) and the frames are packed into one atlas; each AtlasTexture's
margin restores the full cell, so the game sizes and places frames as before. The mirror-image directions (nw, w, sw
with five views) are not stored: the sheet's metadata `mirrored` names each one's twin and `DirectionalSprite.anim_for`
shows the twin flipped (frames are trimmed symmetrically about the centre, so the flip lines up). Sheets import as
VRAM-compressed without mipmaps (`tools/art/set_import.py --sheets`; the crisp shader never reads mipmaps).
`make keys [ONLY="id ..."] [KINDS="walk8 ..."]` renders them (`make anims` leaves the heroes alone);
`tools/art/preview/hd_compare.tscn` shows sheets side by side at any zoom.

**Everyone else in HD (owner 2026-10-07: "lets do it").** `tools/art/hd_turnarounds.py` asks Gemini to redraw each
character's turnaround at 2K, then `blender/hd_colour.py` gives the redraw the original's colours and rejects it (to
be drawn again) if the views, their sizes or the picture itself differ. The colours are matched region by region
(each area between the redraw's ink lines shifts by the median difference from the original under it), so a garment
Gemini recoloured gets its colour back and no line moves. The cut-out is decided against the original's and stored
as the redraw's alpha (the renderers use it as it is): Gemini's 2K backgrounds are often a faint lavender, and a pale
area inside a figure (Godrick's sun, a ghost's robe) would otherwise be taken for a hole and drawn see-through. (The first match added a blurred difference, which left soft halos round the figures;
`blender/hd_restore.py` recovered the raw redraws from it.) Redraws still need a look by eye: a few changed a design
(a skull made solid, text on an apron, an added helmet) and were drawn again or dropped. Characters without an
`_hd.png` (the elephant, the will-o'-wisp, the air elemental, the saber-toothed tiger and the djinni, which Gemini
won't draw) keep their original art at 384 px, packed the same way. `render_walk.py` and `render_attack.py` cut
the HD turnaround when there is one: 768 px cells rendered at twice the size, frames trimmed and packed, mirror-image
directions shown flipped, exactly as the heroes' sheets. The attack's wind-up and strike still come from the 1K
strips, which are drawn at about the size they're shown. Packing alone makes a walk sheet several times smaller (the
villager's went from 9.4 to 1.2 megapixels at 384 px), so HD sheets end up about the size of the old grids. The title
screen's travellers, drawn some 20 times smaller, average their sheet through `shaders/ui/sprite_small.gdshader`.

In game, `DirectionalSprite.frames_for` merges every sheet a sprite folder has (walk, attack, hurt, ride, sneak,
cast) and picks the loop from its `pose`: "" (on foot), "sneak", "ride" or "down". `CombatToken` sets the pose from
the fight (riding when `Encounter.mount_of` has a mount, crouched when hidden or when the party sneaks while
exploring, lying at 0 Hit Points or Prone), flinches on damage (`hurt()`), plays the drawn fall when a creature drops
(`fall()`, `fall_if_drawn()`), and plays the spell gesture for spells (`start_cast`). Sprites without these sheets
keep the earlier behaviour (the lunge, the flattened fall, the attack used as a spell gesture).

`tools/art/preview/anim_showcase.tscn` plays a before/after of one hero (old sheets copied to
`art/sprites/<id>_before`, not committed) for review; recorded with Godot's movie writer through `tools/godot`.

**TODO (owner 2026-10-07): custom heroes.** Heroes made in the creator are paper dolls (`HeroLook`, docs/art/creator.md)
and keep the earlier walk and attack until the v2 set is worked out for parts; each needs about 35 images, so it waits
for a decision on cost. Also still to do: a pose for riding an ally (the riding pose is used as it is), and monsters'
hit and fall (about 15 images each; they keep the flash and the flattened fall).

## In game

`DirectionalSprite.frames_for(id)` merges `attack.tres` into the walk frames. `CombatToken.start_attack(dir)` plays
it facing the target, `wait_for_strike()` waits for the hit frame, and the combat view shows the hit or miss then,
with a short step toward the target. Without an attack sheet the old lunge plays. Walking is paced to the step time
(`set_step_time`): legs keep a natural cadence of about a cycle (two steps) a second, with the stride as long as the
pace makes it, from one square (townsfolk strolling at 0.7 s a square) to four (the party's quick pace); past four the
legs speed up rather than skate (owner 2026-10-06), below one they slow with the feet on the ground (owner 2026-10-08:
townsfolk had been held to four squares a cycle, so their legs alternated far too slowly).

**Lit by the scene (Improvement Ideas W6, the Modern finish).** `sprite_crisp.gdshader` (`lit`, set from
`Look.modern()`) lights each figure by the lamps near it, the sun or moon and the sky, so a figure takes a lantern's
warmth, the time of day and a storm's lightning; a light behind it draws a thin rim along the edge it shines past, and
the figure casts its shadow on the ground (it faces the camera in the shadow pass too, so the shadow is the figure the
player sees). A painted figure isn't shaded across its body: each light lights it evenly (less from behind), no more
than `light_cap` so a carried lantern warms it without washing it out, and `light_floor` keeps it readable in the
dark. The ink outline and the crisp sampling are unchanged. Classic draws figures at their own colours, as before.
`tools/art/preview/lit_lab.tscn` shows figures at night with a torch behind one and a lamp by another (`--day`,
`--flash`, `--classic`).

**Auras (owner 2026-10-09).** `AuraFx` (world/look/aura_fx.gd), built by `CombatToken` for whoever has one, so it
shows in fights and while exploring alike: Strahd's dark aura (smoke curling up round him with a crimson edge, a quad
behind the figure, `shaders/fx/aura_halo.gdshader`, and a pool of creeping shadow under him, `aura_floor.gdshader`)
surges when he attacks, casts or is struck (`AuraFx.surge`); a paladin with Aura of Protection glows faintly warm, and
in a fight the floor shows the area the aura covers, 10 ft (two squares every way from their space, as
`ClassFeatures._in_aura` measures it) or 30 ft with Aura Expansion. Both draw after the palette pass just before the
sprites (render priority 5), so the figure covers the middle. `tools/capture/aura_capture.tscn` shoots them.

**Motion between frames (G12).** Every DirectionalSprite, drawn frames or not, moves between them: it breathes while
standing on a single frame (each figure in its own rhythm), leans into the way it travels across the screen and into a
turn, bobs in the walk when the sheet has no drawn bob (the earlier walk sheets), settles with a squash when it
stops, and recoils from a hit (`hurt()` calls `recoil()`: knocked back away from where it faces and squashed). Springs
drive it; the shader applies it to the flat figure with its feet as the pivot, so its shadow moves with it.
`lit_lab.tscn -- --motion` records it.
