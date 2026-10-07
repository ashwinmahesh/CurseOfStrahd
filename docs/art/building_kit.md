# The building kit (W7: real architecture)

Date: 2026-10-07 · Improvement Ideas W7, the surfaces and architecture lane. Owner direction (W1): HD-2D, A's
effects in B's tone; the reference frames are `art/generated/look_targets/*_ab.png`.

Towns were textured boxes under a gabled slab: a painted timber pattern on a box, no beams, sills, eaves or footings.
They are now put together from a kit of Blender modules in their region's style, the way a modular kit works in any
3D game: each face of a house is a module, and the corners, roof, gables and chimney are modules too.

| Style | Where | What it is |
|---|---|---|
| timber | the Village of Barovia, Old Bonegrinder's hill, the Wizard of Wines, Van Richten's tower (board theme `village`) | Barovian half-timbering: dark oak posts, sill beam, mid rail and wall plate, braces, St Andrew's crosses and chevrons over cracked plaster with brick showing (`interior/plaster_wall`), a fieldstone footing, deep thatch on small houses and slate on grand ones, casements with plank shutters |
| clapboard | Vallaki (theme `vallaki`) | lapped painted boards (each house its own colour from `paints`), corner boards, frieze and skirt boards, cased windows with a pediment, a pedimented door case, steep slate roofs with carved bargeboards; the town's border is a palisade of sharpened logs |
| stone | Krezk, the Abbey, Argynvostholt, the castle's outer yards (theme `shrine_yard`) | coursed stone with quoins, a chamfered plinth, a string course and an eaves cornice, dressed window surrounds with keystones, a round-arched door; Krezk's wall is the tall wall with merlons |

The style comes from `art/sprites/props/catalog.json` `building_kit`: a place's own, else its board theme's. A place
or theme not named keeps the plain boxes (none are left).

## How a house is put together (`world/look/town_builder.gd`, `world/look/building_kit.gd`)

TownBuilder still finds the houses in the map's `#` squares as before (docs/art/set_dressing.md). For each house:

- **Faces.** Every side of every edge square is a face. It gets a lower module (footing, sill beam, mid rail and the
  lower panel's timbers) and an upper module (the upper panel and the wall plate), picked by the square, so a house is
  always built the same way. Faces over open ground get a window on every third one, as before: a dark casement, a
  lit one (candlelight; the marker in `board.windows` has meta `lit`) or one with its shutters closed.
- **Doors.** A door hung on a face (an exit's door, by `SetDressing._hang`) calls `TownBuilder.face_taken`: the face
  becomes a door bay (jambs, a head beam, a step) and the leaf is sized to the opening (0.8 x 1.9). Anything else hung
  there takes the window's place.
- **Corners** are posts, quoins or corner boards; the **core** behind the modules is the style's wall texture
  (`cores`), so the plaster or stone shows between the timbers.
- **Height.** Houses are 2.2 to 2.9 units to the eaves. Lower modules are never stretched; upper modules, corners and
  the space over a door are stretched above their own pivot, so footings, sills and doors stay their real size.
- **Roof.** One module per square along the ridge for the house's span (1 to 12 squares), an end module over each
  gable (the verge and its barge board), the framing of each gable's triangle, and the triangle itself in the core.
  Thatch has a rounded eave, a saddle and a rolled ridge; slate has ridge tiles, a fascia board and rafter feet.
- **Chimney.** The stack is a box (the chimney smoke finds it), the cap and pot are a module.
- **Merged.** The walls and the roof are each one mesh, one surface per material (`BuildingKit.merge`), so a village
  costs a few dozen draws, not thousands.
- **Cut away.** A house between the camera and the party squashes down and is replaced by its low band: a ring of
  wall 0.5 high, capped dark like the cut-away interiors, round a floor of boards, with its footing.

Yard walls are the kit's too: a stone arm from each square's middle toward each neighbouring wall or gate, a capped
pier where the wall turns, ends or branches, and a gate pier each side of a gateway (gates there hang between them,
with no box frame). A town wall (catalog `town_walls`, Krezk's 2.6) is the tall wall with merlons. Vallaki's
palisade is one mesh for the whole border (`TownBuilder.palisade`, asked by `ArenaBoard._wall`).

## Making and changing the modules (`blender/building_kit.py`)

    blender -b --python blender/building_kit.py -- [--only kit_timber_low_b ...] [--preview captures/kit.png]
    make import

It reuses `blender/models_3d.py`'s pieces, materials and export, writing `art/models/kit/*.glb` and
`art/models/kit/manifest.json` (each module's part, size, materials, a roof's span and rise, the colour a house
repaints, and the kit's constants). A wall module is one square's face, 1 unit wide, standing on the wall face: Blender
-Y (Godot +Z) points out of the house and the origin is the bottom middle of the face. Surfaces use palette colours
and the existing texture sets; the HD surfaces (W4) will give the kit its own painted materials.

Checks: `tests/integration/test_building_kit.gd` (every module TownBuilder asks for exists with real materials, the
village is built of kit houses with door bays and lit windows, a house cuts away to its footing, Vallaki is clapboard
behind its palisade and Krezk is stone inside its tall wall). Captures, before and after:

    make capture SCENE=res://tools/capture/kit_capture.tscn NAME=kit/after FRAMES=10   # KIT_SHOTS=village_close,...

## Not done yet

- Interiors, pillars and the castle's gothic (W7's second part), then W8's interiors that keep their outer walls.
- The kit's own HD materials (W4): timber, plaster, thatch and stone painted at 2K with normal and roughness maps.
- Houses are still rectangles; an L-shaped block is two houses with their own roofs.
