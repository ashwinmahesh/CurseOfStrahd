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

## Figures of light (`CombatToken.OWN_LIGHT`)

A sprite id in `CombatToken.OWN_LIGHT` gives off its own light, by the amount named (`DirectionalSprite.glow`: the shader's
`glow`, how much of its colours it shows whatever the scene's lights), so it stays bright in the dark: the Lantern Girl,
a girl of candle-gold light (a 5-view turnaround, a floating `BODY=float` walk, a lantern-swing attack; her portrait is
from the same turnaround). Until her own art was drawn (2026-10-14) she stood on Rose's sheets washed to candlelight.

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
| `idle4` (with `walk8a`, `walk8b`: plan `walk8i`) | the cape lifting, billowing and swaying while he stands | `walk`: as `walk8`, but idle_ is the drawn loop (6 frames at 6 fps; the cape never hangs still, owner 2026-10-09) instead of breathing |

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
billows while he stands, never hanging still), `attack10`, `hurt` and `cast`, no riding or sneaking
(`tools/art/build_keys.py` KEYED). His animations.json entry has `flow`, a sentence added to every strip's prompt so
the cape moves in every pose, and `cast_gather` / `cast_release` for his shadow spell. `make keys ONLY=strahd`
renders them; `make anims` leaves him alone. His dark aura (below) is drawn at run time, not in the sheets.

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
screen's travellers, drawn some 20 times smaller, average their sheet through `addons/dnd_core/shaders/ui/sprite_small.gdshader`.

In game, `DirectionalSprite.frames_for` merges every sheet a sprite folder has (walk, attack, hurt, ride, sneak,
cast) and picks the loop from its `pose`: "" (on foot), "sneak", "ride" or "down". `CombatToken` sets the pose from
the fight (riding when `Encounter.mount_of` has a mount, crouched when hidden or when the party sneaks while
exploring, lying at 0 Hit Points or Prone), flinches on damage (`hurt()`), plays the drawn fall when a creature drops
(`fall()`, `fall_if_drawn()`), and plays the spell gesture for spells (`start_cast`). Sprites without these sheets
keep the earlier behaviour (the lunge, the flattened fall, the attack used as a spell gesture).

`tools/art/preview/anim_showcase.tscn` plays a before/after of one hero (old sheets copied to
`art/sprites/<id>_before`, not committed) for review; recorded with Godot's movie writer through `tools/godot`.

## Veo clips: the heroes' walk, idle, attack, cast and hurt (owner 2026-10-19)

The owner asked for smoother motion from video for the most common animations. The six heroes' walk, idle, attack,
cast and hurt (the flinch) are cut from video clips (image to video) as the clips come in. Until a hero's clips
for a kind are in, that kind stays on its drawn frames. Their fall, lying down, riding and sneaking stay drawn.

Veo 3.1 shut down on 2026-10-22. The clips made until then are Veo 3.1 Lite (Fast for Godrick's and Liriel's swings and
Ratatouille's cast); every clip since is Gemini Omni Flash (`gemini-omni-1.1-flash`, the Interactions API), which the
tool now calls. `clips.json` names each clip's model. The sheets built from either play alike.

The clips show the motions only (owner 2026-10-19: "no effects when spellcasting or making an attack, just the
motions; the effects come from our game engine"). The tool's `MOVES` gives each hero's wind-up and strike in words
without the glows and bursts that `animations.json` describes for the drawn strips, and every one-shot prompt rules out
glow, light, sparks, beams and motion trails. Every attack is timed to feel heavy (owner 2026-10-20: "make weapon
swings feel heavier"): 18 frames, the wind-up eased so it gathers slowly and the blow comes fast (`WINDUP_EASE`), and
the blow on frame 11, held for two frames (`IMPACT_HOLD`). Godrick and Liriel (`SWINGS`) swing a weapon overhead in
their clips (owner 2026-10-19: "make it look like a heavier attack").

Godrick's and Liriel's attacks were made on Veo 3.1 Fast ($0.80 a clip); every other Veo clip is made on Lite (owner
2026-10-20: "do the rest of the swings in Veo Lite, along with all the other videos"). `MODEL_OF` and `MODEL_FOR` name a
kind, or a hero's kind, for another model; both are empty now that there is one model. The owner turned down the first Lite swings on 2026-10-20 ("there's no movement ... their capes, their bodies,
their expressions"; "their legs bending, squatting"), so a swing's prompt asks for full fighting-game key poses: a deep crouch, a lunge into the blow, the cape flaring and whipping after
it, a fierce face. Fast draws white swoosh arcs round the blade in some frames even when asked not to; the owner liked
the result with them. Liriel swings a longsword in every direction (owner 2026-10-20): Gemini redrew the weapon in her e,
ne and n first frames (`edits/`), fitted back onto the frames by her lower body.

Some sheets stay as the owner chose them, whatever clips exist (`KEEP`): Godrick's cast is his first Veo one, with its
glow, and Liriel's cast is her drawn one, with its effect (owner 2026-10-20: "I like Liriel's old casting (with the
effect)"; "Godrick's previous casting animation with the effect").

The casters' casts (owner 2026-10-20: "putting power into it, as if they are channeling magic") ask for a braced,
bent-legged stance, the body gathering, then thrown forward, with the robes and coat flowing (`MOVES`'
`cast_gather` and `cast_release`), motions only. Ratatouille's were made on Veo Fast (his choice).

The tool is `tools/art/veo_anims.py` (`make veo-anims [ONLY=<id>] [KINDS=…] [GENERATE=1]
[REDO="cast_se …"]`). The sheets are still sprite sheets: the game plays frames as before, and nothing decodes
video at run time.

**Clips.**
- Each clip starts on that direction's first frame from the hero's sheet, set on a flat screen colour. It is
  720x1280 (9:16) at 24 fps, with the cell centre at (360, 776), so a clip's pixels are the sheet's pixels and the
  figure keeps its size and ground line.
- The screen is green, except for Kip and Thistle, who wear green and stand on cyan. No hero has a cyan hue.
- Walks and idles are 4-second clips: $0.41 each on Gemini Omni (about $0.10 a second of 720p video; Veo Lite was $0.20).
  Omni takes no length, so the prompt ends "The clip is exactly 4 seconds long."
- Omni turned Kip from facing the camera into three-quarter view on his first walk (2026-10-24), so every prompt now says
  how the hero faces in words (`FACING`: front, three-quarter toward the viewer's right, side profile, seen from behind) and
  that his body never rotates. Retaking that one clip with the new wording kept him square to the camera.
- The walk prompt names what flows on each hero (`FLOWS`: Godrick's tabard and hair, Ratatouille's robes and apron, ...).
  Told "cape, clothes and hair" for everyone, Omni drew Godrick a black cape and Ratatouille a dark cloak on some walks.
  Those clips (Godrick's s, se and e; Ratatouille's s) were kept on their earlier Veo clips; retaking them with the new
  wording is $0.41 each.
- Attacks, casts and flinches are 3-second clips ($0.31 each), asked for in real time (Veo's 8-second clips ran the motion
  in slow motion, so a cast squeezed into 12 frames played at several times its real speed). They are meant to end on
  their first frame: the first image is sent twice, as the first and last frame. Without that, Veo turned heroes seen from
  behind round to face the camera, or left them in another pose. Not tried on Omni yet: the first attack, cast or flinch
  made on it is the test.
- The first frame of an attack or cast is drawn at 0.8 scale, so a swing stays inside the 720-wide clip, and the
  frames are scaled back up.
- A cast and a flinch start and end on the standing frame, because the drawn cast's first frame holds a glowing orb and
  the drawn flinch's is already a crouch (`source_of`). An attack starts on the drawn attack's ready pose.
- Calls go through the Gemini ledger (`make art-spend`).
- Clips, their first frames and prompts (`clips.json`) are kept in `art/generated/veo/<id>/` (LFS, `.gdignore`).

**Frames.**
- Each frame is keyed off the screen colour (the colour left at an edge is unmixed, and one pixel is eaten off the
  edge).
- It is then snapped to the palette like the drawn sheets: binary alpha, and greys only on the grey ramp.
- Frames are trimmed and packed as `render_keys.py` packs them.
- `sheets.json` records what was chosen from each clip. `--review` writes a contact sheet per kind
  (`review_<kind>.png`).

**What the game gets from each kind.**

| Kind | Frames | Timing |
|---|---|---|
| Walk | 24 (the cleanest two-step loop of 18 to 38 clip frames, starting on the lowest head, a foot coming down; one stride pair only: two pairs squeezed into 24 frames play at double speed and miss footfalls) | 24 fps |
| Idle | 9 to 18 (a 1.5 to 3 second loop whose last third of a second is faded into its start, since an idle drifts and seldom comes back on its own) | 6 fps |
| Attack | 18, the fastest motion (the blow) landing on frame 11 (`hit_frames`), held two frames | 16 fps (Godrick's 20.8: owner 2026-10-24, "about 1.3x faster") |
| Cast | 24, the release landing on frame 8: 1.5 s (owner 2026-10-25: "like 1.5 seconds") | 16 fps |
| Hurt | 8, the flinch landing on frame 2 (4-second clips; the sheet's die_ and down_ stay drawn) | 16 fps |

For the attack and cast, the frames run from just before the hero moves to the first frame back at the starting
pose.

**Size and checks.**
- Godrick's sheets came to about 1.7 times the drawn set's pixels: 157 against 90 megapixels for all six sheets.
- Look at every clip by eye. Veo sometimes changes a shield's colour mid-swing, adds a floor shadow, or lets a spell
  burst run past the clip's edge (`sheets.json` lists such frames as `clipped` and `shadow`).
- `make veo-anims ONLY=<id> GENERATE=1 REDO="<kind>_<dir>"` draws a clip again.
- `make keys` rewrites these four kinds from the strips, so run `make veo-anims` (without GENERATE) after it.
- `tools/art/preview/anim_showcase.tscn -- --id=<id> --veo` shows a hero beside a copy of their drawn sheets in
  `art/sprites/<id>_before` (not committed).

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
townsfolk had been held to four squares a cycle, so their legs alternated far too slowly). A foot comes down on a
walk's first and middle frames: the sprite sends `footfall` there, and the leader's footsteps play on it
(`WorldSounds`), so they keep the legs' pace (owner 2026-10-12: two a square had been about four times too fast).

**Lit by the scene (Improvement Ideas W6, the Modern finish).** `sprite_crisp.gdshader` (`lit`, set from
`Look.modern()`) lights each figure by the lamps near it, the sun or moon and the sky, so a figure takes a lantern's
warmth, the time of day and a storm's lightning; a light behind it draws a thin rim along the edge it shines past, and
the figure casts its shadow on the ground (it faces the camera in the shadow pass too, so the shadow is the figure the
player sees). A painted figure isn't shaded across its body: each light lights it evenly (less from behind), no more
than `light_cap` so a carried lantern warms it without washing it out, and `light_floor` keeps it readable in the
dark. The ink outline and the crisp sampling are unchanged. Classic draws figures at their own colours, as before.
`tools/art/preview/lit_lab.tscn` shows figures at night with a torch behind one and a lamp by another (`--day`,
`--flash`, `--classic`).

**Auras (owner 2026-10-09).** `AuraFx` (addons/dnd_core/world/look/aura_fx.gd), built by `CombatToken` for whoever has one, so it
shows in fights and while exploring alike: Strahd's dark aura (smoke curling up round him with a crimson edge, a quad
behind the figure, `addons/dnd_core/shaders/fx/aura_halo.gdshader`, and a pool of creeping shadow under him, `aura_floor.gdshader`)
surges when he attacks, casts or is struck (`AuraFx.surge`); a paladin with Aura of Protection glows faintly warm, and
in a fight the floor shows the area the aura covers, 10 ft (two squares every way from their space, as
`ClassFeatures._in_aura` measures it) or 30 ft with Aura Expansion. Both draw after the palette pass just before the
sprites (render priority 5), so the figure covers the middle. A fire-like flicker for both was tried and the
owner preferred these (2026-10-09). `tools/capture/aura_capture.tscn` shoots them and films three seconds.

**Motion between frames (G12).** Every DirectionalSprite, drawn frames or not, moves between them: it breathes while
standing on a single frame (each figure in its own rhythm), leans into the way it travels across the screen and into a
turn, bobs in the walk when the sheet has no drawn bob (the earlier walk sheets), settles with a squash when it
stops, and recoils from a hit (`hurt()` calls `recoil()`: knocked back away from where it faces and squashed). Springs
drive it; the shader applies it to the flat figure with its feet as the pivot, so its shadow moves with it.
`lit_lab.tscn -- --motion` records it.

## Where a creature's art goes (the engine core, docs/plans/engine_split.md)

The sprites and portraits of every creature in the engine core's data (its monsters and the generic summons, familiars and
spirits) live in `addons/dnd_core/art/sprites/<id>/` and `addons/dnd_core/art/portraits/<id>.png`; the game keeps its heroes,
NPCs and villains. The pipelines (`make sprite`, `make anims`, `make portrait`, `tools/art/new_creatures.py`) still write into the
game's `art/` first; `tools/art/build_anims.py` and `new_creatures.py` finish by running `python3 tools/art/route_to_core.py`,
which moves such a creature's art into the core. After `make sprite` or `make portrait` alone, run it yourself, then commit the
new files in the core. Lookups go through `ArtPaths` (the game's art first, then the core's), so either place works at run time.
