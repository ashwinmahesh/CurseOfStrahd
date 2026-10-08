# Trees and plants (the Modern look)

Date: 2026-10-07 · Improvement Ideas W9, lane 8 (World look: land, plants and vistas). Owner direction: the HD-2D
look, smoothly animated 2D cartoon sprites moving through a modern 3D world; the W1 target frames' forest (dark
spruces, ferns and undergrowth round the clearings) in option B's darker, colder tone.

In the Modern look every tree in and around an outdoor map is a 3D spruce or dead tree built of needle and twig
cards, ferns, bracken, grass, undergrowth and reeds grow by the thousand on the land past the edge and on the map's
own wild ground, and all of it sways in the place's wind. The Classic look keeps its old trees (it is frozen, owner
2026-10-07). Cosmetic only: the rules grid never sees any of it.

## Where it lives

| Piece | File |
|---|---|
| The leaf cards: needle sprays, fern fronds, grass tufts, leaf clusters, twigs and reeds, painted in one 4 x 4 atlas | `tools/art/plant_cards.py` -> `art/plants/cards.png`, `art/plants/cards.json` (each cell's drawn box) |
| The plants: spruces (three and a young one), dead trees (three), each with a lighter `_far` copy; ferns, bracken, grass, sedge, reeds, undergrowth | `blender/plants_3d.py` -> `art/plants/*.glb`, `art/plants/manifest.json` |
| What grows where, by mood: trees per 2D tree kind and their heights, the land's, the woods', the edges', the open ground's and the shore's plants, tint, snow, bark colours | `art/plants/flora.json` |
| Loads the plants, sets the wind, plants the map's own ground, draws many at once | `world/look/flora.gd` (`Flora`) |
| Plants the land: the map's trees become Flora's, the forest past the edge, its undergrowth | `world/look/atmosphere_land.gd` (`AtmosphereLand`, Modern only) |
| Leaves (cards, wind, backlight, snow) and bark (furrows, lichen, wind) | `shaders/atmosphere/foliage.gdshader`, `bark.gdshader`, `wind.gdshaderinc` |
| Art QA: every plant in a row and a stand of forest; outdoor places before and after | `tools/art/preview/plants_preview.tscn`, `tools/capture/land_capture.tscn` |

    make plants                      # paint the cards, build the plants, import
    make capture SCENE=res://tools/art/preview/plants_preview.tscn NAME=plants FRAMES=20
    make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/after FRAMES=10   # LAND_SHOTS=road_day,woods

## How a plant is made

- **Cards.** A spray of fir is painted as clumps of needles along its twigs, dark at their roots and lighter toward
  their fringed tips, rather than needle by needle, so it reads at the size a tree is on screen. A dark band inside
  every shape's edge is its ink line; colour is spread into the transparent pixels so mipmaps never fringe.
- **Spruces.** A tapering trunk under tiers of sprays that droop more toward their tips, broad at the foot of the
  crown and narrowing to a spire, with a leader of two crossed sprays. **Dead trees**: a leaning, twisting trunk that
  splits into limbs reaching up and out, forking twice, each tip a spray of twigs. **Ferns and bracken**: fronds
  arching out of one crown. **Grass, sedge, reeds**: crossed upright cards. **Undergrowth**: leaf cards round a dome.
- **Per vertex** (the shaders read them): normals bent out from the crown, so a tree is lit as one soft volume rather
  than card by card; vertex alpha, how much light reaches that part (inside and under the crown is darker); UV2, how
  freely the vertex moves in the wind and a phase of its own.
- **Far copies** (`_far`) have fewer tiers and one segment per card; the land uses them past `FAR_DETAIL` squares
  from the map, where they cast no shadow.

## Where they grow

- **The map's own trees** (ArenaBoard's wall squares in the woods) keep their square, heading and fading; only the
  tree changes, 10 to 20 ft tall as before (`scale`, `shortest`, `tallest` for `map`).
- **The land's trees** stand where the old ones did (the same spacing rule, never within two squares of where people
  walk), but further apart (`tree_density`), since a spruce is fuller than the old cone. The first rows are nodes of
  their own and fade like the map's; the rest are drawn many at once in 10-square chunks, so the camera only draws
  the chunks it can see, darker further out as before.
- **Shadows**: only trees within `SHADOW_REACH` (3) squares of where people walk cast the sun's shadow; every shadow
  split draws every tree that casts, and the ones further out shade nothing anyone looks at (lane 6's frame budget,
  W17, 2026-10-07).
- **Hidden until found**: plants on squares HiddenAreas hides are left out (AtmosphereLand's HiddenWatch redraws
  them when a secret door is found), and none grows on a trap's square, where a pit could open.
- **Ground plants**: on the forest land out to `land_reach` squares from the map, thinning with distance, reeds and
  sedge along shores, nothing on roads; on the map, under its trees (`under`), spilling out of the woods onto the side
  of a square that faces them (`edge`), and short and sparse on its other wild squares (`open`, `open_scale`), never
  within 0.3 of a square's middle (feet and the selection rings stay clear), on water, on a square a location's
  things stand on, in a building or on a door. Towns grow nothing on their streets.
- **Sets** (`flora.json`): forest (the Svalich woods and everything like them), lake, mountain (Krezk, the Abbey,
  the werewolf den; patchy snow on the tops), snow (Mount Baratok, the Amber Temple road, Tsolenka), marsh (Berez:
  dead trees, sedge and reeds), blight (Yester Hill, Argynvostholt: bracken and dry grass), castle (Ravenloft).
  A mood without a set takes the set of the mood it is `like`.

## Wind

The mood's mist wind sets the direction and a strength (a breeze in the Svalich woods, more in rain, a storm at the
castle, a gale in the blizzard). A plant bends from its foot, more the higher a point stands (stiff for a spruce,
loose for grass), leans downwind and rocks as gusts roll across the land in waves; its cards also flutter on their own.
Bark and leaves share one function, so a tree moves as one, and its shadow sways with it.

## Rules

- No alpha to coverage on leaves: Godot draws it in the transparent pass, after the copy of the screen the screen
  pass works from, so the leaves would miss the outlines, mist and grade. Edges are hard cut, smoothed by the
  screen-space anti-aliasing.
- Roughness never below 0.1: the screen pass reads near-zero roughness as water.
- Leaves and wood within `near_fade` units of the camera thin away, so the camera tilted toward the horizon (W13)
  sees past the trees right in front of it.
- Plant copies drawn many at once keep where they stand in their node's `origins` meta: a MultiMesh without a
  renderer (headless tests) keeps none.

## Checks

`tests/integration/test_flora.gd`: every set names built plants, every mood grows a set, the road's trees and forest
are Flora's (the map's 10 to 20 ft), ground plants stand on the land and never on map squares, map plants keep off
the middle of squares, off things and out of water, the castle's wind blows harder than the woods', and Classic keeps
its old trees.

## Not done yet

- The leaf cards are painted by script; Gemini-painted cards could carry more hand-painted detail.
- A tree put back after a big piece leaves its square (`ArenaBoard.restore_cell`) comes back as the old model.
- Fading a 3D tree in front of the party (`ArenaBoard.fade_occluders`) drops it out of sight rather than ghosting it,
  since a faded mesh draws after the screen pass's copy of the screen (true of the old 3D trees as well).
