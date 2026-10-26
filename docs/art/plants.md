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
| Loads the plants, sets the wind, plants the map's own ground, draws many at once | `addons/dnd_core/world/look/flora.gd` (`Flora`) |
| Plants the land: the map's trees become Flora's, the forest past the edge, its undergrowth | `addons/dnd_core/world/look/atmosphere_land.gd` (`AtmosphereLand`, Modern only) |
| Leaves (cards, wind, backlight, snow) and bark (furrows, lichen, wind) | `addons/dnd_core/shaders/atmosphere/foliage.gdshader`, `bark.gdshader`, `wind.gdshaderinc` |
| Art QA: every plant in a row and a stand of forest; outdoor places before and after | `tools/art/preview/plants_preview.tscn`, `tools/capture/land_capture.tscn` |

    make plants                      # paint the cards, build the plants, import
    make capture SCENE=res://tools/art/preview/plants_preview.tscn NAME=plants FRAMES=20
    make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/after FRAMES=10   # LAND_SHOTS=road_day,woods

## Each region's plants

The vault's Region Variety Plan: each region has its own set in art/plants/flora.json, from the plants we have, with
its own mix, forest density and tint: `woods`, `village`, `autumn` (Tser Pool and the Vistani camps), `graves` (half
the pines dead), `vineyard`, `heath`, `sick`, `spectral` (silver lichen on the dead trees), `rock` and `rock_snow`, and `baratok` (Mount Baratok's: spruce only, a little shorter, more snow on them; it needs its own `styles` block in vistas.json too, else the horizon falls back to the woods'). A
set's `tints` gives one kind of plant its own tint (the moor's grass straw, the heath's bushes heather), and `autumn`
turns that share of a kind's plants, each picked by where it stands (foliage.gdshader `autumn`), from green to a ramp
between the set's two `autumn_colours` by the leaf's own brightness, so they read rust and gold rather than a tinted
green.

## The regions' trees and plants

The Region Variety Plan's second half (owner's yes to Blender, 2026-10-12): eight more leaf cards at the end of the atlas
(which grew to six rows; `cards.json` `rows`, and blender/plants_3d.py sizes cards by `BOX`, the boxes in atlas widths,
so the older plants kept their shapes) and fourteen more plants. Broadleaf trees (`crown_tree`: a trunk and limbs into
a crown that is a cloud of leafy sprays on an ellipsoid, the top ones sprung from its axis so a high camera sees leaves,
not a ring): `birch_a`, `birch_b` (white bark, `bark_birch`), `oak_a`, `oak_b` (`bark_oak`), `willow_a` (strands
hanging from its rim) and the Scots pines `scots_a`, `scots_b` (orange upper bark, `bark_pine`; kind `tree`, so they
never turn), each with a `_far` copy. Broadleaf trees are their own kind, `broadleaf`, so a set's `autumn` can turn
them (the Vistani camps' oaks go rust and gold) while its spruces stay green. Ground plants: `vine` (a grapevine on its
stake, kind `bush`), `heather`, `thistle` and `cattails`. The sets: `autumn` oaks and birches round Tser Pool, `lake`
birches and willows and cattails on the shore, `marsh` willows, `mountain` and `rock` Scots pines, `heath` Scots pines
with heather and thistles, `spectral` birches at Argynvostholt, `vineyard` vines in the open rows, `village` an oak or
a birch among the spruces, `sick` twisted oaks on Yester Hill.

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

- **The map's own trees** (ArenaBoard's wall squares in the woods) belong to their square and fade as before, 10 to 20 ft
  tall (`scale`, `shortest`, `tallest` for `map`; a leaning tree's box too), but they are no longer one tree a square in
  rows (Natural Maps Plan N4, `addons/dnd_core/world/look/woods.gd`): each wall square's tree stands anywhere across it, varied in
  size, lean and kind (groves of tall trees and patches of young ones, a few squares across), each leaning a little
  and wearing its own shade (the foliage shader's `instance uniform hue`: groves a little warmer or cooler, lighter or
  darker), and a smaller tree or two fringe an edge square (more of them in a thicker wood: the set's `wood_density`,
  else from its `tree_density`). Along an edge the crowns' reach over the grid line wanders from a bay
  (a small tree drawn back into the wood square) to a headland, by noise seeded by the place and smooth over three
  squares or so; a trunk never stands more than 0.18 into the open square beside it (a quarter of a square less its
  girth) and none leans into a square a location's things stand on; every wood square keeps a crown over its middle,
  so it still reads as the wall the rules make it. Every tree of a square is in `ArenaBoard.dressing` for that square (a
  prop on it hides them all, `restore_cell` gives them back) and in `mesh_occluders` (they fade). The Classic look
  keeps its one tree.
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
  sedge along shores, nothing on roads; on the map, under its trees (`under`), spilling out of the woods into the
  squares beside them (`edge`: `Woods.feather` feathers a band whose depth wanders from nothing to half a square,
  thinning as it goes and rounding off round the inside corners of a clearing, with saplings (a metre or two high) and
  a fallen dead tree against the wood's line, none within 0.3 of the square's middle or taller things than 0.2 from
  the line), and short and sparse on its other wild squares (`open`, `open_scale`), never
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

`tests/integration/test_woods.gd`: every wood square keeps a crown over its middle, no trunk stands more than a quarter
of a square into an open square or into one a location's things stand on, the crowns' edge wanders, sizes, leans and
kinds vary, trees keep their 10 to 20 ft, a prop takes all of a square's trees, a place comes out the same every time,
the feathered edge keeps off the middle of the open squares and within half a square of the wood, and Classic keeps its
one tree a square. `tests/integration/test_flora.gd`: every set names built plants, every mood grows a set, the road's trees and forest
are Flora's (the map's 10 to 20 ft), ground plants stand on the land and never on map squares, map plants keep off
the middle of squares, off things and out of water, the castle's wind blows harder than the woods', and Classic keeps
its old trees.

## Not done yet

- The leaf cards are painted by script; Gemini-painted cards could carry more hand-painted detail.
- A tree put back after a big piece leaves its square (`ArenaBoard.restore_cell`) comes back as the old model.
- Fading a 3D tree in front of the party (`ArenaBoard.fade_occluders`) drops it out of sight rather than ghosting it,
  since a faded mesh draws after the screen pass's copy of the screen (true of the old 3D trees as well).
