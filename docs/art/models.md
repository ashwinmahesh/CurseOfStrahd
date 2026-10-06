# 3D set pieces (pilot: the Death House upper floor)

Date: 2026-10-06 · Owner request: "we can build 3D assets for things in Blender if they would look better than the
2D assets. Let's start doing that for things in the world." Follow-ups: "We can base them on our 2D assets" and
"It would be a nice contrast with the cartoon-like 2D sprites in a 3D world."

Furniture, hearths, stairs, doors and wall panelling read wrong as flat cards: seen along a wall they vanish, and
they never catch the lantern light or throw a shadow. These pieces are now real models, built by a script in
Blender from the 2D props they replace. Characters and creatures stay 2D sprites.

## Where they are used

Only the places in `art/sprites/props/catalog.json` `models3d.places` use them: `death_house_upper` while the owner
looks at the pilot. Everywhere else draws the 2D pieces exactly as before. Rolling out is adding place ids (or `"*"`).

| Model | Stands in for (2D art) | Mount |
|---|---|---|
| bookcase | book_shelf, book_shelf_front, bookshelf | against the wall |
| desk | desk, desk_front (a container: it dims when emptied) | against the wall |
| chair_high, armchair, table, table_chairs, candelabra | the 2D piece of the same name | free-standing |
| settee | settee | against the wall |
| fireplace | fireplace (the upper hall) | on the wall face; its fire is the 2D flame at the model's `flame` socket |
| fireplace_windmill | fireplace_windmill (the library) | the same, near-black stone, and the moonlit windmill painting above it: a carved 3D frame round the canvas cut from the 2D art |
| fireplace_dancers | fireplace_dancers (the conservatory) | the same, grey marble with an arched firebox; the dancing figurines on the mantel are cut from the 2D art, one sprite each, turning to the camera |
| stairs_up, stairs_down | stair_riser, stair_down | stairs: the steps start on the side the party walks in from |
| door_wood | door_wood (leaf only; the frame stays the wall's posts) | door |
| wainscot | the `interior/wainscot_wall` surface | a module on every open face of a wall painted with it |

## How a piece finds its place (`world/look/model_piece.gd`, `ModelPiece`)

`SetDressing` asks `ModelPiece.for_art(board, art)` before drawing a 2D piece: standing pieces
(`stand_piece`, so location props, containers, exits and the board's '=' furniture), wall pieces (`_hang`), door
leaves (`door`, not secret doors) and stairs (`exit_piece`). `ArenaBoard._wall` asks `ModelPiece.dress_wall` for the
panelling.

- **Facing:** like the 2D pieces, a piece backs onto the wall (or door) beside it, north first, else faces south.
- **Against the wall:** its back sits on the wall face; the face behind it takes no portrait. With no wall it is
  centred on its square.
- **Wall pieces:** on the face the 2D piece would hang on, looking into the room.
- **Stairs:** a stairwell down opens its square's floor while it shows.
- **Panelling:** one module per open face; a one-square gap in a wall (a doorway) is left to the door frame. The
  modules sit under one holder on the wall square, so a prop that takes the square, or a hidden area, hides them.
- **Picking:** `SpritePick.hit` also tests the ray against each model's triangles, so pointing at any drawn part
  picks the piece.

## Look

Every surface is a palette colour with the board's cel shading (`Look.cel`), or for big wooden surfaces (table tops,
the desk top, stair treads, door planks) the repo's own `interior/wood_planks` texture, so the models take the
scene's lights and shadows in the same two or three tones, and the screen pass outlines them and snaps them to the
palette like the rest of the world. Where a 2D piece has a detail that is a picture (a painting, figurines), the
model keeps that part of the 2D art (manifest `decals`: a pixel region of the prop sprite set at a socket). Material names in Blender say how each surface is drawn: `pal_<colour>`, `glow_<colour>` (flames
and embers, lit from within) or `tex_<theme>__<surface>` (a texture set from art/textures, world-mapped like the
board). Colours were picked from each 2D prop: the bookcase's umber carcass and books in the reds, browns, blues and
greens of the painted shelves; the desk's walnut top, plum body and blood-red trim; the red velvet chairs; the stone
fireplace's greys with violet; the red stair runner with gilt rods.

The panelling takes the painted wainscot's own colours (peat panels, near-black mouldings, an umber chair rail),
so lamplight shows its depth rather than a new colour.

Sizes are real sizes (a person is 6 ft, 1.2 units): a bookcase 7 ft, a desk top 2.6 ft, a chair seat 1.65 ft with a
4.75 ft back, stairs 7.5 ft over one square like `world/look/stairs.gd`.

## Making and changing them

`blender/models_3d.py` builds every piece from primitives (boxes, turned profiles, outlines, swept bars) with a fixed
seed, so the books on a shelf come out the same every time. Front is Blender -Y (Godot +Z), origin at the middle of
the footprint, or of the back for pieces that stand against or hang on a wall.

    make models                                   # every model -> art/models/*.glb + manifest.json, then import
    make models ONLY="bookcase desk" PREVIEW=captures/models.png   # also one Blender render per piece

`manifest.json` records each model's mount, the 2D art it stands for, its size and its sockets.

Checks: `tests/integration/test_models_3d.gd` (the catalog's models exist, the library is built of them, each stays in
its square, other places keep their 2D pieces, picking, looted desks dim). Captures:

    make capture SCENE=res://tools/art/preview/location_tour.tscn LOCATION=death_house_upper NAME=library ARGS="--at=4,4"

## Not done yet

- Only the Death House upper floor. Other furniture there (the grandfather clock, the armour, beds, the harpsichord)
  is still 2D.
- No lights of their own: candles and the hearth glow but don't light the room (lighting belongs to the world look).
- The secret bookcase door keeps its 2D disguise.
