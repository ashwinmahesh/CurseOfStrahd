# 3D set pieces

Date: 2026-10-06 · Owner request: "we can build 3D assets for things in Blender if they would look better than the
2D assets. Let's start doing that for things in the world." Follow-ups: "We can base them on our 2D assets" and
"It would be a nice contrast with the cartoon-like 2D sprites in a 3D world."

Furniture, hearths, stairs, doors and wall panelling read wrong as flat cards: seen along a wall they vanish, and
they never catch the lantern light or throw a shadow. These pieces are now real models, built by a script in
Blender from the 2D props they replace. Characters and creatures stay 2D sprites, and so do trees, brambles and
boulders, which already look right from every side.

The Death House upper floor was the pilot; the owner signed it off the same day ("the 3D pieces look so much
better. Lets start rolling out this change everywhere") and then asked for everything: "Anything that isnt a player,
NPC, or a character shold be a 3D assett" (2026-10-07). The rollout went in batches, each merged to main: (1) common
furniture and containers with 3D on everywhere, (2) doors, gates, windows and wall trim, (3) town and outdoor pieces,
(5) nature, (6) every remaining object, figure and wall picture, (7) landmarks and buildings, (8) the last few.
Castle Ravenloft's own pieces follow once its set dressing is settled.

What stays painted is flat by nature: scorch marks, bloodstains, drag and claw marks, rune and offering circles,
puddles, a plaster seam, the flames of fires and candles. The fog bank is the world look's mist.

## Where they are used

Every place uses them (`art/sprites/props/catalog.json` `models3d.places` is `"*"`); a place left out of a list of ids
would keep its 2D pieces. `models3d.art` names the model for each 2D art id, or a model per board theme
(`{theme: model, "*": model}`): wooden stairs in houses, inns, shops and attics, stone stairs everywhere else. 2D art
without a model is drawn as before.

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
| stairs_up_stone, stairs_down_stone | stair_riser, stair_down outside wooden interiors | stairs: stone steps between stone walls; a stone well with a low parapet |
| barrel, crate | barrel, crate | free-standing |
| chest, chest_iron, strongbox, trunk, footlocker | the same (containers: they dim when emptied) | free-standing |
| bed, bed_small | bed, bed_small | against the wall (headboard on it), a square long |
| wardrobe, sideboard, shelves | the same and their `_front` views | against the wall |
| pew, lectern, table_set, letters_table, coffin | the same | free-standing |
| door_house, door_double, door_carved, gate_iron, crypt_gate, portcullis, curtain | the same leaves (the carved door keeps its 2D hand) | door: modelled at the 2D leaf's 0.86 x 1.15 and scaled to the opening; never for secret doors |
| church_doors | church_doors (exits) | on the wall face: a stone arch, 3D leaves, the 2D rose window as a decal |
| window_tall, window_stained | the same | on the wall face: a deep pointed-arch reveal and sill round the 2D window, kept whole as a decal |
| window_shuttered | the same | on the wall face |
| panelling | the `interior/wood_panel` and `interior/carved_panel` surfaces | wall modules: stiles, skirting and a top rail |
| wall_trim | papered and plastered surfaces (plaster, green and nursery papers, damp plaster, whitewash, kitchen) | wall modules: a skirting board and a picture rail |
| wagon, market_stall, cart_broken | the same | free-standing, building-sized (`big`): they keep their size and clear the trees around them |
| shop_counter, bar_counter, workbench, cask_rack | the same and their `_front` views | against the wall |
| woodpile, notice_board, crypt_small, crypt, gravestone, well, well_stone, bridge_parapet, signpost | the same | free-standing |
| pine_a/b/c, pine_clawed, dead_tree_a/b | pine, pine_clawed, dead_tree (variants picked by square) | trees in the board's woods and the land past the map's edge, as tall as the 2D trees, each turned its own way; they fade like the billboards (ArenaBoard.mesh_occluders) |
| bramble_a/b, boulder_a/b, log, stump, rubble, cairn, snowdrift, ice_patch, reeds, leaves, grave_mound, hay_bale, garden_bed, vines | the same | free-standing, turned per square (nature has no front) |
| sculpted pieces (statues, armour, scarecrows, the stuffed wolves, the horse, carcasses, skeletons, dolls, cages, charms, sheeted furniture, the dollhouse, harp, spinning wheel, the colossus, the faceless statue, Strahd's effigy, the wicker sun ...) | the same | made from their own sprite: its silhouette made solid, swelling toward the middle, painted with the sprite in front and the 2D back view behind (`spr_<art>` materials, shaders/cel_sprite.gdshader) |
| wall pictures (paintings, portraits, mirrors, boards, notices, reliefs, carvings, tapestries, banners) | the same | the 2D picture kept in a 3D mount: a moulded frame, a board, a stone slab, a hanging rod |
| wall fittings (trophies, chains, shelves of jars, winches, robes on pegs ...) | the same | sculpted from their art against the wall |
| about 60 more hand-modelled objects (braziers, altars, shrines, cabinets, the canopy bed, harpsichord, organ, tubs, the wine press, stoves, marble hearths, the manor entrance, painted doors, windows, rugs, straw ...) | the same | as their 2D pieces were mounted |
| cottage, tent, vardo, barn_collapsed, windmill, bell_tower, tower_vr, hut_lysaga, standing_stones, gallows, barrow, gulthias_tree, ribbon_tree ... | the same | building-sized: they keep their size and clear the trees; a piece standing in for a whole house is a 3D building over its ground; tall ones fade |

## How a piece finds its place (`world/look/model_piece.gd`, `ModelPiece`)

`SetDressing` asks `ModelPiece.for_art(board, art)` before drawing a 2D piece: standing pieces
(`stand_piece`, so location props, containers, exits and the board's '=' furniture), wall pieces (`_hang`), door
leaves (`door`, not secret doors) and stairs (`exit_piece`). `ArenaBoard._wall` asks `ModelPiece.dress_wall` for the
panelling.

- **Facing:** like the 2D pieces, a piece backs onto the wall (or door) beside it, north first, else faces south.
- **Against the wall:** its back sits on the wall face; the face behind it takes no portrait. With no wall it is
  centred on its square.
- **Wall pieces:** on the face the 2D piece would hang on, looking into the room. A piece modelled round its middle
  (a door leaf some places hang as a picture) stands just in front of the face.
- **Stairs:** a stairwell down opens its square's floor while it shows.
- **Panelling:** one module per open face; a one-square gap in a wall (a doorway) is left to the door frame. The
  modules sit under one holder on the wall square, so a prop that takes the square, or a hidden area, hides them.
- **Picking:** `SpritePick.hit` also tests the ray against each model's triangles, so pointing at any drawn part
  picks the piece.
- **Elsewhere:** the board's trees, brambles and yard gravestones (`ArenaBoard`), the land's near and far trees
  (`AtmosphereLand`, a MultiMesh per tree variant with shaders/cel_instanced.gdshader keeping the far ones darker), a
  town house's windows (`TownBuilder`), torches (`LocationView`), the gates' statues and the secret bookcase door
  (`SetDressing`) all use a model where there is one.

## Look

Every surface is a palette colour with the board's cel shading (`Look.cel`), or for big wooden surfaces (table tops,
the desk top, stair treads, door planks) the repo's own `interior/wood_planks` texture, so the models take the
scene's lights and shadows in the same two or three tones, and the screen pass outlines them and snaps them to the
palette like the rest of the world. Where a 2D piece has a detail that is a picture (a painting, figurines), the
model keeps that part of the 2D art (manifest `decals`: a pixel region of the prop sprite set at a socket).
Material names in Blender say how each surface is drawn: `pal_<colour>`, `glow_<colour>` (flames
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

Checks: `tests/integration/test_models_3d.gd` (the catalog's models exist, the library is built of them, in every
location each model stays in its square, every model is its real height, the woods are 3D trees that fade, a place
left out keeps its 2D pieces, picking, looted desks dim); `test_set_dressing.gd` checks 3D pieces for facing, wall
contact, stairs and the cottage's size as it does the 2D ones. Captures:

    make capture SCENE=res://tools/art/preview/location_tour.tscn LOCATION=death_house_upper NAME=library ARGS="--at=4,4"

## Not done yet

- Castle Ravenloft's own pieces, once the world assets work there has chosen them.
- Sculpted pieces are only as deep as a swelling of their outline: from the side they read as thick reliefs, not
  carved figures.
- Long runs of pews or tables are one model per square, so a long table shows its seams.
- No lights of their own: candles and the hearth glow but don't light the room (lighting belongs to the world look).
- The secret bookcase door keeps its 2D disguise.
