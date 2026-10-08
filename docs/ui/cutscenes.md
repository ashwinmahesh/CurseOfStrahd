# Story cutscenes

Date: 2026-10-07 · Improvement Ideas G4, lane 20 (Story presentation).

## What earns one
Owner rules (2026-10-07): a cutscene shows, faithfully, anything the game's own views can't display accurately, and
any moment a cinematic picture makes more dramatic. The
map and the fights draw small cartoon figures in a lit diorama; they can't show Strahd sitting his black horse up on a
ridge, the whole valley from a crag, a reveal on a castle's scale. Those moments get a full-screen still picture that
shows exactly what is happening. No motion is needed: the picture fades up out of black. It is drawn whole, as large as
the screen allows, with black bars filling whatever is left (owner, 2026-10-08: in fullscreen the old fill-and-crop and
slow push-in cut off the top of the picture); the caption sits low over the picture or its bottom bar.

## Data
`data/cutscenes/<id>.json` (schema `cutscene.schema.json`, read by `story/cutscenes.gd`):
- `title`, `summary`: our own words.
- `images`: the picture's takes, `{image, when}`, first match wins. `image` is `art/cutscenes/<image>.jpg`; `when` is
  a dialogue condition (`guest:ireena`, `flag.x`, empty for always). When no take holds, the cutscene is skipped and
  the scene plays as before. So a picture that shows Ireena carries `"when": "guest:ireena"`, and a second take
  without her can follow it.
- `focus`: the picture's point of interest, as a share of its width and height (default the centre). Kept for the
  picture's pivot; the picture no longer zooms (see above).
- `trigger`: a Narrator key (`examine:bonegrinder_lookout`, `enter:<area>`). Looking at that thing or walking into
  that area shows the picture with the narrator's line as its caption, instead of the line in the HUD's box, and
  pauses the game under it (so a fight the area starts waits for it). A fight's narrator key works too
  (`strahd:fled_to_coffin`: the picture over the fight, which goes on under it). `find:<magic item>` plays when a
  Tarokka treasure is found: in a conversation (`tarokka give`) its picture comes before the notice, and among a
  chest's or a fight's spoils it shows before the loot window opens.
- `once`: the picture shows only the first time its trigger fires (`_cutscene/<id>` in the story's flags). Every
  `enter:` and `find:` trigger has it.

`make validate` checks every picture exists, every trigger is a node in a `narrative/narrator/` file (or a
`find:` names a magic item), and every `cutscene <id>` in a conversation names a cutscene.

## In a conversation
`cutscene <id>` (docs/contracts/dialogue.md) puts the picture under the conversation. The lines that follow read as
captions on it: the narrator in the book's italic, anyone else with their name above their words, each still voiced
(ADR 0013) and kept in the History (H). Options, checks and notices bring the dialogue box back up over the picture.
`cutscene end`, or the conversation ending, takes it away. Another `cutscene <id>` fades to the next picture.

Example, the rider on the ridge (`narrative/strahd/visits.dialogue ~ watcher`):

```
~ watcher
appear strahd
set strahd_watcher_seen
cutscene strahd_watcher
Narrator: The road bends under a bare ridge. ...
```

## Controls
- A click, Space or Enter: the next caption (past the last one in a place's cutscene, it closes).
- Skip (top right): a conversation's captions go by unread up to the next choice, note or the end (they stay in the
  History); a place's cutscene closes.
- Esc: pauses, with Resume and Skip the scene. Esc again resumes. Nothing else moves on while it's paused.

## Endings
An ending's narration (`narrative/endings/`) can hold `cutscene <id>` too: the ending screen puts the picture behind
the words, in full colour, in place of the dimmed castle, and keeps it for the epilogue slides.

## Fights
A fight that a conversation starts gets its picture from that conversation: the `cutscene` line goes before its last
line, so the picture shows with it before the fight begins (Wintersplinter, the Abbot's wings, the hut). A fight an
area starts (the gallows field at night) takes the area's `enter:` trigger; the game waits under the picture.

## Code
- `story/cutscenes.gd` (`Cutscenes`): the data, the picture for the story now (`image`), `focus`, `for_trigger`.
- `ui/cutscene/cutscene_view.gd` (`CutsceneView`): the picture (whole, letterboxed in black) and its fade, the caption, Skip and the pause
  card. Motion is off in headless runs and still captures (UiMotion).
- `ui/cutscene/cutscene_player.gd` (`CutscenePlayer`): a place's cutscene while exploring, opened by
  `world/game_root.gd play_cutscene` from `LocationView.cutscene_requested`. It stands in as the open screen, so
  nothing in the world moves under it.
- `ui/dialogue/dialogue_ui.gd`: the `cutscene` beat, captions and Skip in a conversation.

## Art
`tools/art/build_cutscenes.py [--generate] [--only id ...] [--sheet out.png]` builds every picture from
`tools/art/cutscene_recipes.json` (the prompts the owner approved in the Cutscene Audit doc, 2026-10-07): Gemini
(`gemini-3.1-flash-image`, the pinned model, through `tools/art/generate_gemini.py` so the spend ledger counts it) with
`art/prompts/cutscene_preamble.txt`, 16:9 at 2K (2752x1536, about $0.10 a picture), and the cast's turnarounds from
`art/generated/characters/` as references so faces and clothes match the sprites. The party is drawn hooded and from
behind, since the player makes their own heroes. Takes are kept in `art/generated/cutscenes/<image>_<a, b ...>.png`;
the recipe's `use` take is saved as `art/cutscenes/<image>.jpg` (quality 92, Git LFS: Gemini returns JPEG anyway,
and the game's copies stay about 0.7 MB each) and imported with VRAM compression and mipmaps
(`tools/art/set_import.py`, force-add its `.import`). `--sheet` draws a contact sheet of the newest takes for review.

Round 2 (54 pictures, the owner's wider rule) followed on 2026-10-08. Lessons from both batches: a turnaround sheet passed as a reference can come back as several copies of that
creature in the scene (Argynvost's echo, the nightmare horse), so scenery creatures are described in words instead;
"an old painting" draws a paper border; scale words need an anchor ("the travellers are tiny specks beside one of its
talons"). The caged children and the hanged man passed Gemini's image safety only on a retry.

| Cutscene | Title | Plays from | Takes |
|---|---|---|---|
| abbey_bride | The Bride Opens Her Eyes | `abbey_of_st_markovia/unveiling` | 1 |
| abbey_shelf | The Abbey on Its Shelf | `enter:abbey_of_st_markovia` | 1 |
| abbot_candles | The Abbot Lights the Candles | `abbey_of_st_markovia/abbot` | 1 |
| abbot_holds_hand | He Is Holding Her Hand | `abbey_of_st_markovia/unveiling` | 1 |
| abbot_kneeling | Light Like Water | `abbey_of_st_markovia/unveiling` | 1 |
| abbot_wings | The Abbot's Wings | `abbey_of_st_markovia/abbot`, `abbey_of_st_markovia/unveiling` | 1 |
| amber_gift | Lying Down in the Amber | `amber_temple/vosk` | 1 |
| amber_pact | The Bargain | `amber_temple/vault` | 1 |
| amber_sentinel_steps | The Sentinel Steps Down | `amber_temple/sentinel` | 1 |
| amber_sentinels | The Amber Sentinels | `amber_temple/sentinel` | 1 |
| arabelle_dive | Under the Black Water | `vallaki/vistani_camp` | 1 |
| argynvost_flame | The Silver Flame | `argynvostholt/mausoleum` | 1 |
| argynvost_frost | A Dragon in the Frost | `argynvostholt/argynvost` | 1 |
| attic_flash | The Attic Window Flashes | `vallaki/aftermath` | 1 |
| aurel_reading | Reading to an Empty Chair | `castle_ravenloft/personal_aurel` | 1 |
| beacon_lit | The Beacon Is Lit | `argynvostholt/beacon` | 2 |
| beacon_road | The Light on the Ridge | `argynvostholt/events` | 1 |
| black_carriage | The Black Carriage | `strahd/letters` | 1 |
| bonegrinder_burns | Old Bonegrinder Burns | `old_bonegrinder/mill` | 1 |
| bonegrinder_crag | The View from the Crag | `enter:hill_lookout` | 2 |
| bonegrinder_hag | Morgantha Stands | `old_bonegrinder/morgantha` | 1 |
| bonegrinder_loft | Cages and a Rocking Chair | `old_bonegrinder/children` | 1 |
| bonegrinder_view | The View from the Crag | `examine:bonegrinder_lookout` | 2 |
| burial_doru | A Messenger on the Wall | `village_of_barovia/burial` | 1 |
| burial_graves | The Graves Split | `village_of_barovia/burial` | 1 |
| burial_strahd | A Mourner Who Came Late | `village_of_barovia/burial` | 1 |
| carriage_ride | Up into the Cloud | `strahd/letters` | 1 |
| castle_chasm | The Castle Across the Chasm | `enter:castle_ravenloft_gates` | 2 |
| castle_glimpse | The Castle on Its Pillar | `examine:castle_glimpse` | 1 |
| castle_road_west | The Castle on Its Pillar | `village_of_barovia/road_west` (the first try at the west posts, alone; once) | 1 |
| chapel_dawn | Dawn in the Chapel | `castle_ravenloft/personal_prayers`, `companions/dawn` | 1 |
| children_freed | Five Children Walk Past the Wolves | `werewolf_den/kiril` | 1 |
| church_gate | At the Churchyard Gate | `strahd/ireena` | 1 |
| church_vigil | Vigil at St. Andral's | `vallaki/lucian` | 1 |
| crossroads_dead | The Gallows Field Wakes | `enter:crossroads_gallows` | 1 |
| crossroads_gallows | The Hanged Man | `svalich_road/crossroads` | 1 |
| dead_feast | A Feast Nobody Dismissed | `argynvostholt/vladimir` | 1 |
| dead_procession | The Dead Procession | `svalich_road/events` | 1 |
| death_house_children | The Children Go Home | `death_house/dungeon` | 1 |
| death_house_cult | The Ring of Shadows | `death_house/altar` | 1 |
| death_house_lorghoth | The Heap That Stands Up | `death_house/altar` | 1 |
| death_house_window | The House Shuts Its Mouth | `death_house/escape` | 1 |
| dinner_organ | Dinner at the Organ | `castle_ravenloft/gates_dinner` | 2 |
| doru_ceiling | The Face on the Ceiling | `village_of_barovia/doru` (the first meeting only) | 1 |
| doru_rest | Doru at Rest | `castle_ravenloft/larders_cells` | 1 |
| durst_supper | Supper with the Dursts | `death_house/dursts` | 1 |
| elvir_burial | Elvir Comes Home | `wizard_of_wines/davian` | 1 |
| ending_bride | The Bride of Ravenloft | `endings/ireena_given_up` | 1 |
| ending_darklord | The Second Thirst | `endings/new_darklord` | 1 |
| ending_dawn | Dawn over Barovia | `endings/strahd_destroyed` | 1 |
| ending_mists | The Mists Remain | `endings/strahd_triumphant` | 1 |
| ending_sergei | At Sergei's Side | `endings/ireena_at_peace` | 1 |
| fen_chains | Grandda | `companions/fen` | 1 |
| festival_square | The Square Turns | `vallaki/festival` | 1 |
| festival_sun_blazes | The Blazing Sun | `vallaki/festival` | 1 |
| festival_sun_dies | The Sun That Wouldn't Burn | `vallaki/festival` | 1 |
| forty_chairs | Forty Chairs | `castle_ravenloft/personal_kestrel` | 1 |
| gertruda_home | Gertruda Comes Home | `castle_ravenloft/court_gertruda` | 1 |
| godfrey_rests | Godfrey Rests | `argynvostholt/beacon` | 1 |
| godfrey_steps | Sir Godfrey on the Steps | `argynvostholt/godfrey` | 1 |
| godrick_knighting | Rise, Sir Godrick | `companions/ladle` | 1 |
| heart_beats | The Heart of Sorrow | `castle_ravenloft/spires_heart` | 1 |
| heart_breaks | The Heart Breaks | `castle_ravenloft/spires_heart` | 1 |
| ilinca_children | Ilinca Takes Them Home | `old_bonegrinder/children` | 1 |
| ilinca_raven | The Raven Who Is a Woman | `old_bonegrinder/ilinca` | 1 |
| ireena_door | Three Bolts Slide Back | `village_of_barovia/ireena` | 1 |
| ireena_looks_back | Ireena Looks Back | `village_of_barovia/road_west` | 2 |
| ireena_window | At Ireena's Window | `strahd/ireena` (at the inn, only while Ismark guards her: he is in the picture) | 1 |
| ireena_window_empty | The Empty Window | `strahd/ireena` | 1 |
| izek_doll | Izek and the Doll | `vallaki/izek` | 1 |
| keepers_ravens | Ravens on Every Beam | `vallaki/martikovs` | 1 |
| kiril_eyes | Eyes Behind Kiril | `werewolf_den/kiril` | 1 |
| krezk_reflection | The Second Reflection | `krezk/pool` | 1 |
| krezk_wall | The Wall of Krezk | `enter:krezk` | 1 |
| lightning_ridge | Lightning on the Ridge | `mount_baratok/events` | 1 |
| locket_chair | The Chair by the Fire | `castle_ravenloft/personal_locket` | 1 |
| lysaga_bowl | The Witch in Her Bowl | `berez/marina` | 1 |
| lysaga_hut | The Hut Stands Up | `berez/lysaga` | 1 |
| lysaga_poppet | The Poppet over the Hearth | `berez/hut` | 1 |
| madam_eva_reading | Five Cards | `svalich_road/madam_eva` | 1 |
| mansion_siege | Hands Through the Boards | `village_of_barovia/ireena` | 1 |
| marina_bier | Marina on Her Bier | `berez/marina` | 2 |
| marina_rose | A Black Rose | `berez/marina` | 1 |
| marina_statue | Marina's Face | `berez/marina` | 1 |
| mists_arrival | Out of the Mists | `into_the_mists/arrival` | 1 |
| mordenkainen_jar | Mordenkainen Remembers | `mount_baratok/mordenkainen` | 1 |
| order_rides | The Order Rides | `argynvostholt/vladimir` | 1 |
| pack_law | Pack Law | `werewolf_den/kiril` | 1 |
| patrina | Patrina | `amber_temple/patrina` | 1 |
| patrina_kasimir | Patrina, and Her Brother | `amber_temple/patrina` | 1 |
| phantom_ride | The Phantom Ride | `argynvostholt/events` | 1 |
| quillon_fire | The Man at the Edge of the Light | `camp/kip` | 1 |
| rahadin_voices | Rahadin and His Voices | `castle_ravenloft/court_rahadin` | 1 |
| roc_shadow | The Roc's Shadow | `tsolenka_pass/events` | 1 |
| sergei_font | Sergei in the Font | `castle_ravenloft/catacombs_sergei` | 1 |
| strahd_asleep | Strahd Asleep | `castle_ravenloft/catacombs_coffin` | 1 |
| strahd_camp | Someone Is Watching the Camp | `strahd/visits` | 2 |
| strahd_end | Like Old Paper | `castle_ravenloft/catacombs_coffin` | 2 |
| strahd_letter | A Letter in His Own Hand | `strahd/letters` | 1 |
| strahd_mist_flight | He Goes Home to His Coffin | `strahd:fled_to_coffin` | 1 |
| strahd_resting | Strahd, Beaten | `castle_ravenloft/catacombs_coffin` | 1 |
| strahd_rides | The Rider Out of the Fog | `svalich_road/events` | 2 |
| strahd_waiting | He Is Waiting for You | `strahd/final` | 12 |
| strahd_watcher | The Rider on the Ridge | `strahd/visits` | 2 |
| strahd_watcher_gone | The Empty Ridge | `strahd/visits` | 1 |
| three_brides | Three Brides | `castle_ravenloft/court_brides` | 1 |
| treasure_sword | The Sunsword | `find:sunsword` | 1 |
| treasure_symbol | The Holy Symbol of Ravenkind | `find:holy_symbol_of_ravenkind` | 1 |
| treasure_tome | The Tome of Strahd | `find:tome_of_strahd` | 1 |
| tser_falls | Tser Falls | `svalich_road/tser_falls` | 1 |
| tser_falls_ireena | At the Lip | `svalich_road/tser_falls` | 1 |
| tser_pool_fire | Firelight at Tser Pool | `enter:tser_pool` | 1 |
| vallaki_palisade | The Palisade | `vallaki/gate` | 1 |
| village_rain | The Village in the Rain | `enter:village_of_barovia` | 1 |
| vines_gem | The Vines Remember | `wizard_of_wines/davian` | 1 |
| vosk_unmasked | Vosk Takes Off His Face | `amber_temple/vosk` | 1 |
| vr_reunion | Two People by a Fire | `van_richtens_tower/van_richten` | 1 |
| vr_tower | The Tower on Lake Baratok | `enter:van_richtens_tower` | 1 |
| watch_stands_down | The Watch Stands Down | `tsolenka_pass/watch` | 1 |
| wolves_part | The Wolves Part | `strahd/visits` | 1 |
| yester_burn | The Tree Burns | `yester_hill/summit` | 1 |
| yester_effigy | The Effigy on Yester Hill | `yester_hill/ruxandra` | 1 |
| yester_wintersplinter | Wintersplinter Walks | `yester_hill/ruxandra` | 1 |
