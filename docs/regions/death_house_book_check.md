# Death House against the book: room by room

Date 2026-10-06. Owner request: "Some things are missing from the death house, portraits. Validate that the layout and
decor looks like the descriptions from the Curse of Strahd books", then "the bathroom doesn't look like a bathroom",
"we can change the flooring and wall styles of different rooms", "make sure assets aren't overlapping".

Source: *Curse of Strahd* appendix B (areas 1 to 38), from memory, cross-checked against DM guides and play reports
(listed at the end). Where the sources disagree or are silent the entry says **unsure**; those are also listed in
docs/rules/data_sources.md. Floors and walls marked *(suggested)* are not in the book: they are picks for the tone.

Who does what: the Death House thread (branch `death-house`) owns the rooms, connections, encounters, NPCs, loot and
text in data/locations and narrative/. The World assets thread owns prop art, the catalogue, and floor and wall
textures. "Prop id" below is the id in data/locations; where the art doesn't exist yet the prop is placed with the
nearest existing art and listed under "Art wanted", so the catalogue's `ids` can point it at new art without a data
change.

## Why portraits went missing

A wall piece hangs on the first open side of its wall square, in the order south, west, east, north
(`SetDressing.FACES`). Two portraits sat on north-south walls between two rooms, so they hung on the **west** face:

| Prop | Square | Meant for | Actually hung in |
|---|---|---|---|
| `hall_family_portrait` (ground) | (9, 8) | Main Hall | the Den of Wolves |
| `upper_hall_portraits` (upper) | (9, 11) | Upper Hall | the Secret Study, behind the bookcase |

Fixed in data: every wall piece in the house now sits on a wall square whose first open side is its own room (mostly
north walls, which also face the opening camera). The check is a script in `tools/data/check_wall_pieces.py`.

## Ground floor (`death_house_ground`), book areas 1 to 5

| Book area | Game area | Floor | Walls | Book furniture and props | In the game now |
|---|---|---|---|---|---|
| 1 Entrance | `dh_foyer` | stone flags *(suggested)* | dark oak paneling *(suggested)* | Outside: wrought-iron gate in an arched portico, oil lamps hanging on chains, heavy oak double doors (drawn by the village's `death_house_facade`). | Crest over the arch (`durst_crest`). |
| 2 Main Hall | `dh_main_hall` | polished dark boards *(suggested)* | wood paneling carved with vines, flowers, nymphs and satyrs; a close look (Perception 12) finds serpents and skulls hidden in it | Marble fireplace with a longsword mounted above the mantel; sweeping red marble staircase up; cloakroom off the hall. | `hall_hearth` (new, north wall), `hall_carvings` (new, the paneling, Perception 12), `hall_lamp`, `under_stair_cache` (game's: Mother's purse). Family portrait moved up to the Upper Hall, where the book has it. |
| 2 Cloakroom | `dh_cloakroom` | boards | plain paneling | Coats and cloaks on hooks. | `cloakroom_coats` (game's hidden lantern). |
| 3 Den of Wolves | `dh_den` | wide oak boards, fur rugs *(suggested)* | oak paneling, a hunting lodge | Stag's head over the hearth; three stuffed wolves around the room; two padded chairs draped in furs facing the hearth; oak table between them; chandelier; cloth-covered card table with four chairs; two cabinets: one locked (heavy crossbow, light crossbow, 20 bolts), one unlocked (playing cards, wine glasses). | `den_hearth`, `den_stag_head` (new, replaces the wolf-head trophies), `den_stuffed_wolf_a/b/c` (new), `den_gun_cabinet` (now heavy + light crossbow, 20 bolts), `den_card_cabinet` (new). `den_wolf_rug` kept (game's). |
| 4 Kitchen | `dh_kitchen` | stone flags or terracotta tiles *(suggested)* | whitewashed plaster *(suggested)* | Tidy: shelves of dishes, kettles and pots; worktable with cutting board and rolling pin; domed stone oven; dumbwaiter (small door, rope and pulley) up to the servants' room and the master suite. | `kitchen_stove` (the oven), `kitchen_worktable` (new), `kitchen_dumbwaiter`. |
| 4 Pantry | `dh_pantry` | stone flags | plaster | Shelves of preserved food. | `pantry_jars`, `pantry_shelves`. |
| 5 Dining Room | `dh_dining_room` | polished boards, long rug *(suggested)* | wood paneling carved with deer among trees; red silk drapes | Carved mahogany table, eight high-backed chairs; crystal chandelier; silver and crystal; marble fireplace with a mahogany-framed painting of an alpine valley above it; tapestry on an iron rod: hounds and riders chasing a wolf. | `dining_table_set`, `dining_tapestry` (narration now says wolf), `dining_hearth` (new), `dining_sideboard` (game's), `tall_window` (escape). |

## Second floor (`death_house_upper`), book areas 6 to 10

| Book area | Game area | Floor | Walls | Book furniture and props | In the game now |
|---|---|---|---|---|---|
| 6 Upper Hall | `dh_upper_hall` | polished boards, runner *(suggested)* | dark paneling, oil lamps; carved wooden doors | Fireplace with the **family portrait** above the mantel: Gustav holding a swaddled baby, Elisabeth looking at the baby with scorn, Rose and Thorn smiling; two suits of chain armor with wolf-head visored helms, each holding a spear; red marble stair continuing up. | `upper_hearth` (new), `hall_family_portrait` (moved here), `upper_armor_west/east` (new), `upper_hall_clock` (game's). The ancestor row is gone (the book has the one family portrait). |
| 7 Servants' Room | `dh_servants_room` | bare boards | plain plaster | Two beds, two footlockers, a closet of uniforms, the dumbwaiter's door with a call button. | `servants_uniforms`, `servants_footlocker`, `servants_dumbwaiter` (new). |
| 8 Library | `dh_library` | boards with a rug *(suggested)* | floor-to-ceiling shelves, red velvet drapes | Mahogany desk and high-backed chair; two overstuffed chairs; fireplace with a painting of a windmill on a rocky crag above it; rolling ladder; one bookcase is the secret door. Desk: writing things and an iron key (the attic padlock). | `library_desk` (now holds the attic key), `library_hearth` (new), `library_histories`, `library_odd_shelf`, `study_bookcase` (secret door, Perception 13). |
| 9 Secret Room | `dh_secret_study` | dusty boards | shelves of black-bound books on fiends and necromancy | Heavy wooden chest with clawed iron feet; skeleton in leather armor beside it (three darts); chest: three blank black-leather books (25 gp each), three spell scrolls (bless, protection from poison, spiritual weapon), deeds to the house and to a windmill, a will. Strahd's letter. | `strahd_letter`, `durst_deeds`, `study_cult_tract` (game's), `study_chest` (book's contents), `study_skeleton` (new: leather armor, 3 darts). |
| 10 Conservatory | `dh_conservatory` | parquet *(suggested)* | pale paneling, gossamer drapes, stained-glass hangings of singers and musicians | Harpsichord; standing harp by the fireplace; alabaster dancer figurines on the mantel; brass chandelier; upholstered chairs. | `harpsichord`, `conservatory_hearth` (new). The stuffed-bird case is gone (not in the book). |

## Third floor (`death_house_third`), book areas 11 to 15

| Book area | Game area | Floor | Walls | Book furniture and props | In the game now |
|---|---|---|---|---|---|
| 11 Balcony | `dh_attic_landing` + `dh_third_hall` (both named Balcony) | dusty boards | faded oak paneling carved with woodland scenes; oil lamps | Suit of black plate against the wall (the animated armor); railing over the stairwell; a **secret door** to the attic stair. | Armor fight on the landing; `attic_stair_door` is now secret (Perception 12). |
| 12 Master Suite | `dh_master_suite` | boards; rotting tiger-skin rug | burgundy drapes; double doors with stained glass | Four-poster bed with embroidered curtains and gauze; two wardrobes; padded chair; vanity with mirror; silver jewelry box; fireplace with a dusty portrait of Gustav and Elisabeth above; dumbwaiter; a small sitting corner. Jewelry box 75 gp, three gold rings (25 gp each), thin platinum necklace with a topaz (750 gp). | `master_bed`, `dressing_table`, `master_hearth`, `master_portrait` (new), `master_wardrobe` + `master_wardrobe_2` (new), `master_dumbwaiter` (new), `jewel_box` (900 gp of jewels). |
| 13 Bathroom | `dh_bathroom` | stone or tile *(suggested; a wet room)* | plaster, damp-stained *(suggested)* | Dark room: wooden tub with clawed feet; small iron stove with a kettle on it; a barrel under a dry spigot (a pipe from the rooftop cistern). | `clawfoot_tub`, `bath_stove` (new), `bath_barrel` (new), `bath_cabinet` (game's). The mirror is gone (the book's mirror is the nursemaid's). |
| 14 Storage Room | `dh_third_storage` (**new room**) | boards | bare plaster | Shelves of folded sheets, blankets and soap; a broom leaning on the wall (the broom of animated attack). | `third_storage_shelves` (new); the broom fight moved here from the attic. |
| 15 Nursemaid's Suite | `dh_nursemaid_room` | boards | faded wallpaper *(suggested)* | Large bed, two end tables, empty wardrobe, full-length mirror (a **secret door** to the attic stair behind it). | `nursemaid_letters` (game's), `nursemaid_bed`, `nursemaid_wardrobe`, `nursemaid_mirror` (new), secret door into the attic stair. |
| 15A Nursery | `dh_nursery` | boards | pastel wallpaper *(suggested)* | Crib under a black shroud, a wrapped blanket in it and no baby; the nursemaid's specter. | `nursery_crib`, `nursery_mobile`, `nursery_chest`, the nursemaid. |

## Attic (`death_house_attic`), book areas 16 to 21

| Book area | Game area | Floor | Walls | Book furniture and props | In the game now |
|---|---|---|---|---|---|
| 16 Attic Hall | `dh_attic_hall` | rough planks | bare rafters and boards | Dust and cobwebs; the padlocked door of the children's room. | Same. |
| 17 Spare Bedroom | `dh_spare_bedroom` | rough planks | bare boards | Slender bed, nightstand, small iron stove, writing desk and stool, empty wardrobe, rocking chair, a doll in a yellow lace dress in the window box. | `spare_bed`, `spare_wardrobe`, `spare_stove`, `spare_desk`, `spare_rocking_chair`, `spare_doll` (new). The chimney alcove is gone. |
| 18 Storage Room | `dh_storage_room` | rough planks | bare boards | Sheeted furniture; an iron stove; a big trunk holding the nursemaid's remains in a bloody sheet; **secret door in the north-east corner** to the spiral stair. | `storage_junk`, `storage_stove` (new), `nursemaid_trunk` (new), `storage_trunk` (game's), `storage_panel` (the secret door, Perception 14) and the `secret_stair_down` nook. |
| 19 Spare Bedroom | `dh_spare_bedroom_2` (**new room**) | rough planks | bare boards | As 17. | `spare2_bed`, `spare2_wardrobe`, `spare2_stove`. |
| 20 Children's Room | `dh_childrens_room` | planks | faded children's wallpaper *(suggested)* | Padlocked (key in the library desk); two small beds; toy chest painted with windmills; dollhouse copy of the house; Rose and Thorn. | Same; the door now also takes the library key. |
| 21 Secret Stairs | (the exit) | wooden spiral steps | mortared stone shaft, cobwebs | About 50 ft down inside the walls. | `secret_stair_down`. |

## Dungeon (`death_house_dungeon_1`, upper level), book areas 22 to 34

Redrawn so every book room exists and the two ways to the stairs down are the book's: past the spiked pit, or
through the ghouls.

| Book area | Game area | Floor | Walls | Book contents | In the game now |
|---|---|---|---|---|---|
| 22 Dungeon Level Access | `dh_stair_foot` | packed earth | rough stone, red clay, timber bracing | Chanting from below. | Same. |
| 23 Family Crypts | `dh_family_crypts` | flagstones | cut stone, crypt slabs | Crypts closed by stone slabs: Gustav, Elisabeth (insects swarm out if disturbed), Rose and Thorn (empty), Walter, one more empty. | `crypt_ancestors`, `crypt_gustav`, `crypt_elisabeth` (new: swarm of insects), `crypt_children`, `crypt_walter`. |
| 24 Cult Initiates' Quarters | `dh_initiates_quarters` | packed earth | rough stone | Straw pallets. | Pallets, `dormitory_pegs`, `dormitory_footlockers`. |
| 25 Well and Cultist Quarters | `dh_well_quarters` | packed earth | earth with rotted posts and beams | Well (stone lip, rope and pulley, bucket) in the middle; five alcoves with beds and chests: 11 gp and 60 sp in a skin pouch; three moss agates (30 gp); an eye-patch with a carnelian (50 gp); an ivory hairbrush with silver bristles (25 gp); a silvered shortsword. | `dungeon_well`, `alcove_chest_a` to `_e`. |
| 26 Hidden Spiked Pit | `dh_pit_passage` | stone | stone | A concealed spiked pit. | `passage_pit` (now spiked, Perception 15). |
| 27 Dining Hall | `dh_cult_refectory` | dirt | stone | Plain table, long benches, gnawed bones. | `cult_ledger` (game's), `refectory_bones`. |
| 28 Larder | `dh_larder` (**new**) | dirt | stone | Dark; the grick; a net of rotted venison. | Grick moved here from the well. |
| 29 Ghoulish Encounter | `dh_ghoul_passage` (**new**) | stone, old bones | cracked, red-stained stone | Ghouls rise out of the floor (four). | Ghouls moved here from the dormitory (four, was three). |
| 30 Stairs Down | `dh_lower_stair` | stone steps | stone | Chanting below. | Same. |
| 31 Darklord's Shrine | `dh_shrine` (**new**, was the reliquary) | stone | stone, skeletons in rusty shackles | Painted wooden statue of a gaunt, pale man in a black cloak, hand on a wolf's head, holding a smoky crystal orb (25 gp); take the orb and five shadows peel off the walls. A secret door leads to 32. | `shrine_statue` (new), the shadows (now five, on taking the orb), `shrine_shackles` (new). |
| 32 Hidden Trapdoor | `dh_trapdoor_stair` (**new**) | clay steps | earth | A stair up to a trapdoor bolted from below. | A way out to the village after the sacrifice. |
| 33 Cult Leader's Den | `dh_leaders_den` | flagstones | stone | Table, two high-backed chairs, clay jug and two flagons, iron chandelier, iron candlesticks. The door into it is a **mimic**. | `durst_supper`, `den_candlesticks`; the mimic door. |
| 34 Cult Leaders' Quarters | `dh_durst_chambers` | flagstones | stone | Rotted bed, wardrobe, footlocker: cloak of protection, coffer with four potions of healing, chain shirt, mess kit, alchemist's fire, bullseye lantern, thieves' tools, a yellow spellbook. Gustav and Elisabeth (both ghasts). | Gustav and Elisabeth (Elisabeth is now a ghast too), `durst_footlocker` (book contents that exist in our data). |

## Dungeon (`death_house_dungeon_2`, lower level), book areas 35 to 38

| Book area | Game area | Floor | Walls | Book contents | In the game now |
|---|---|---|---|---|---|
| 35 Reliquary | `dh_lower_landing` (named Reliquary) | stone steps, mist | stone with small alcoves | Thirteen strange trinkets and relics in the alcoves; the chant is clear here ("He is the Ancient. He is the Land"). | `reliquary_niches` (new). |
| 36 Prison | `dh_robing_room` (named Prison) | stone | stone, rusty shackles | Shackles; a skeleton in a tattered black robe wearing a gold ring (25 gp). | `prison_skeleton` (new). The robing chest moved here. |
| 37 Portcullis | `dh_flooded_passage` + `dh_winch_room` | 2 ft of black water | stone | Rusted portcullis; a wheel to raise it. | Same; the rat swarms are gone (not in the book). |
| 38 Ritual Chamber | `dh_ritual_antechamber` + `dh_ritual_chamber` | 2 ft of murky water; dry ledges along the walls; an octagonal dais | smooth masonry, stone pillars | Altar carved with grasping ghouls, bloodstained; rusty chains and shackles hanging over it; hooded figures chanting "one must die"; Lorghoth. | Same. |

## Art wanted (World assets)

Placed now with stand-in art; point `ids.<prop id>` at the new piece when it exists.

| Prop id(s) | Wanted piece | Mount | Stand-in now |
|---|---|---|---|
| `den_stag_head` | Stag's head on a plaque | wall | `trophy_wolf` |
| `den_stuffed_wolf_a/b/c` | Stuffed grey wolf on a low plinth (three poses if possible) | stand | `rug_wolf` |
| `hall_hearth` | Marble fireplace, longsword mounted above the mantel | wall | `fireplace` |
| `hall_carvings` | Carved paneling: vines, flowers, nymphs, satyrs (serpents and skulls hidden in it) | wall | invisible spot |
| `kitchen_stove` | Domed stone oven (`oven_brick` on your branch fits) | wall | `stove` |
| `dining_hearth` | Marble fireplace, framed alpine valley painting above | wall | `fireplace` |
| `hall_family_portrait` | The family portrait as the book has it: Gustav holding a swaddled baby, Elisabeth looking at it with scorn, Rose and Thorn (Thorn with a stuffed wolf) | wall | `painting` (no baby yet) |
| `upper_armor_west/east` | Chain armor with a wolf-head visored helm, holding a spear | stand | `statue_knight` |
| `library_hearth` | Fireplace, painting of a windmill on a rocky crag above | wall | `fireplace` |
| `study_skeleton` | Skeleton in leather armor slumped against a chest, darts in its ribs | stand | `bones` |
| `conservatory_hearth` | Fireplace with alabaster dancer figurines on the mantel | wall | `fireplace` |
| (conservatory) | Standing harp; stained-glass hangings of singers (`window_stained` on your branch) | stand / wall | not placed yet |
| `master_portrait` | Dusty portrait of Gustav and Elisabeth | wall | `painting` |
| (master suite) | Rotting tiger-skin rug | floor | not placed yet |
| `bath_barrel` | Barrel under a dry spigot pipe | stand | `barrel` |
| `clawfoot_tub` | Wooden tub on clawed iron feet | stand | `bathtub` |
| `nursery_crib` | Crib draped in a black shroud | stand | `crib` |
| `nursemaid_mirror` | Full-length mirror, carved frame | wall | `mirror` |
| `third_storage_shelves` | Shelves of folded sheets, blankets and soap | stand | `shelves` |
| `spare_doll` | Doll in a yellow lace dress | stand | `doll` |
| `shrine_statue` | Painted wooden statue of a gaunt pale man in a black cloak, one hand on a wolf's head, holding a smoky crystal orb | stand | `statue_knight` |
| `shrine_shackles`, `prison_skeleton` | Skeletons hanging in rusty wall shackles | wall | `robe_pegs` / `bones` |
| `initiate_pallets` | Straw pallets | floor | `straw` |
| `reliquary_niches` | Wall alcoves holding odd trinkets | wall | `shelves_wall` |
| doors `nursemaid_mirror_door` | A door rule for "mirror" so the secret door looks like the mirror once found | door | default leaf |

Creature sprites (build thread / animations thread, through the coordinator): **swarm of insects** (crypt 23) and
**mimic** (door to 33; new stat block `data/monsters/mimic.json`).

## Floors and walls per room

The area schema has no floor or wall field yet (`areas` items are `additionalProperties: false`). Suggestion: an
optional `floor` and `walls` on each area naming a texture from the catalogue's `floors`, read by the board when it
lays that rectangle. The picks per room are the Floor and Walls columns above; book-given ones are the main hall's
carved paneling, the den's oak paneling, the dining room's deer paneling and red drapes, the library's velvet drapes,
the conservatory's stained glass and drapes, the master suite's burgundy drapes, the balcony's carved oak, the
dungeon's packed earth and timber bracing, and the ritual chamber's black water and masonry. The bathroom wants a
tiled or stone floor and damp plaster to read as a bathroom.

## Not changed (kept as game additions)

The burning lamp, Mother's purse under the stair, the lantern behind the coats, the cult pamphlet, the nursemaid's
letters, the lullaby, the dollhouse showing the altar, the cult ledger, the nursemaid as a calmable specter, the house
turning after a refusal (brick at the front door, the dining room window). The book's escape (doors that become scything
blades, hearth rooms filling with smoke, out by the front door) is close to ours in spirit; ours is kept.

## Sources

From memory of the book, checked against: [Curse of Strahd: Reloaded, Arc A](https://www.strahdreloaded.com/Act+I+-+Into+the+Mists/Arc+A+-+Escape+From+Death+House)
(marks its own changes), [Elven Tower](https://www.elventower.com/curse-of-strahd-intro-running-the-death-house/),
[Medieval Melodies part 2](http://medievalmelodies.blogspot.com/2016/12/curse-of-strahd-death-house-survival_14.html)
and [part 3](https://medievalmelodies.blogspot.com/2016/12/curse-of-strahd-death-house-survival_21.html),
[GMort's play report](http://gmortschaotica.blogspot.com/2017/11/d-curse-of-strahd-part-two-death-house.html),
[Death House Revised](https://lunchbreakheroes.com/death-house/), [Master Quest encounters](https://fosskers.github.io/curse-of-strahd/death-house.html),
[treasure list](https://www.gmbinder.com/share/-MXkI0n3frcgvEsKfzhy).
