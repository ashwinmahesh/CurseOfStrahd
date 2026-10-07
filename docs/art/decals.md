# Clutter and decals (W10)

Date: 2026-10-07 · Improvement Ideas W10, the surfaces and architecture lane. In the Modern look a board is dressed
with painted marks laid over its floors and walls: cracks, stains, moss, old blood, rain puddles, fallen leaves, straw,
dust drifts, mud fringes where cobbles meet mud, damp and soot streaks, creeping moss. They break up the grid and the
repeat of a tile without blocking any square, and take the scene's lights like the surfaces under them. Classic is
left as it was (frozen, owner 2026-10-07).

## The marks (`art/textures/decals/`)

`tools/art/decal_recipes.json` names 13 sheets of four marks each; Gemini paints each sheet at 2K on plain white
(`art/prompts/decal_preamble.txt`, a look target frame as the style reference), kept as WebP in
`art/generated/decals/`. `blender/make_decals.py` cuts a sheet into its quarters and makes each a decal: alpha from
how far each pixel is from the sheet's white (eased, so paper texture drops out), the colour unmixed from the white,
cropped to the mark and faded at its edges, at 512 px on its longer side, with a normal map (dark parts read as
grooves, the body as a slight rise). `art/textures/decals/manifest.json` lists each mark's files, whether it lies on a
floor or a wall, and its aspect.

    python3 tools/art/build_decals.py [--generate] [--only floor_moss ...] [--jobs 4]
    make import && python3 tools/art/set_import.py art/textures/decals/<albedo files> && python3 tools/art/set_import.py --normal art/textures/decals/*_n.webp && make import

## Where they go (`world/look/clutter.gd`, catalog `clutter`)

`ArenaBoard` asks `Clutter.dress` once a board is built. The rules come from the catalog's `clutter`: a place's own
(by the start of its id: every room of Castle Ravenloft, the Death House) or its board theme's. A rule names decals
(ids, or a sheet for all four), where they go, a chance per square, a size range and a cap:

| on | Where |
|---|---|
| floor | any open square that isn't rough ground |
| edge | an open square beside a wall, the mark pushed toward it (dust drifts, moss in corners) |
| difficult | rough ground (mud, puddles) |
| boundary | an open square beside rough ground, the mark on the line between them: cobbles fringed with mud |
| wall | an open face of a wall square, at a varying height, projected into the wall |
| wall_foot | the same, standing on the floor (moss and rising damp) |

Every pick (whether a square gets a mark, which, where in the square, how big, which way round) comes from a hash of
the place and the square, so a place looks the same every time. Decals are Godot `Decal` nodes under the board's
`Clutter` node, their boxes shallow so they mark the floor or wall and not the people standing on it.

Checks: `tests/integration/test_hd_surfaces.gd` (every decal loads; the village, a dungeon and a castle hall are
dressed in the Modern look, with marks on walls; Classic has none).

## Not done yet

- Scattered small 3D things (stones, roots, bones, debris) by the same rules.
- Wheel ruts along the roads lane 8's shaped ground carves (`GroundRelief.roads()`).
- Puddles that reflect (a decal ORM with low roughness).
