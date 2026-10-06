# Character animation: walk and attack

Every character and creature sprite walks in 8 directions and has an attack in 8 directions (owner request
2026-10-06). Props and scenery stay still.

## Files

| What | Where |
|---|---|
| Per-character settings: body type, saturation, the attack's wind-up and strike | `art/anim/animations.json` |
| Prompt templates | `art/prompts/attack_keyframes.txt`, `art/prompts/walk_keyframes.txt` |
| Keyframe strips (Gemini, one per view) | `art/generated/anim/<id>/attack_<view>.png`, `walk_<view>.png` |
| Walk sheet | `art/sprites/<id>/walk.png` + `walk.tres` (walk_<dir>, idle_<dir>) |
| Attack sheet | `art/sprites/<id>/attack.png` + `attack.tres` (attack_<dir>, metadata `hit_frame`) |

`art/generated/anim` has a `.gdignore`: Godot never imports the strips.

## Commands

- `make anims` re-renders every walk and attack sheet from the strips; `ONLY="wolf ilse_varga"` limits it.
- `make anims ONLY=<id> GENERATE=1` first draws any missing strips for that character.
- `tools/art/anim_keyframes.py --only <id> --views side front` redraws chosen strips (when a check or a look
  at the sheet finds a bad one); `--retry 2` redraws what `render_attack.py --check` flags.

A new character: `make sprite ...` as before, add an entry to `animations.json` (copy a similar one: `who`, `attack`,
`windup`, `strike`, plus `body`, `saturate`, `views` when they differ from the defaults), then
`make anims ONLY=<id> GENERATE=1`, then look at `art/sprites/<id>/attack.png`.

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
- **Cells** are 1.75x the walk cell's width and 1.25x its height (672 x 480), same pixel scale and same centre,
  so a raised sword or a lunge fits and the figure keeps its size and ground line (the game centres each frame).
- **Checks** (`--check`): figures merged or clipped by the picture's edge, or frame 1 not shaped like the view
  (Gemini put a new pose first). Flagged strips are redrawn.

## Walk

- **People** (`body` humanoid, the default): the cutout rig of `blender/render_walk.py`. Head-on, the legs lift and
  bend in turn and the body sways over the planted foot; in profile the legs swing. The body dips on each stride.
- **Four-legged** (`quadruped`: wolves): profile and three-quarter views trot on two drawn strides from
  `walk_<view>.png` strips (stretched, gathered) with the standing view as the passing pose; head-on views lift
  their leg halves. Cells are 1.5x wide so a stretched wolf fits.
- **float** (specter, flying sword): hovers, bobs and leans into the glide. **hop** (broom): squash, leap, land.
  **slither** (grick), **lumber** (shambling mound), **swarm** (rats): squash, stretch and rock the one plane.
- Frame 0 of every cycle is the rest pose: it is also the idle frame.

## In game

`DirectionalSprite.frames_for(id)` merges `attack.tres` into the walk frames. `CombatToken.start_attack(dir)` plays
it facing the target, `wait_for_strike()` waits for the hit frame, and the combat view shows the hit or miss then,
with a short step toward the target. Without an attack sheet the old lunge plays. Walking is paced to the step time
(`set_step_time`): one cycle covers three squares in exploration and combat alike.
