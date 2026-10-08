# Story cutscenes

Date: 2026-10-07 · Improvement Ideas G4, lane 20 (Story presentation).

## What earns one
Owner rule (2026-10-07): a cutscene shows, faithfully, anything the game's own views can't display accurately. The
map and the fights draw small cartoon figures in a lit diorama; they can't show Strahd sitting his black horse up on a
ridge, the whole valley from a crag, a reveal on a castle's scale. Those moments get a full-screen still picture that
shows exactly what is happening. No motion is needed: the picture fades up out of black and closes in very slowly on
its focus, which is enough to make a still feel alive.

## Data
`data/cutscenes/<id>.json` (schema `cutscene.schema.json`, read by `story/cutscenes.gd`):
- `title`, `summary`: our own words.
- `images`: the picture's takes, `{image, when}`, first match wins. `image` is `art/cutscenes/<image>.jpg`; `when` is
  a dialogue condition (`guest:ireena`, `flag.x`, empty for always). When no take holds, the cutscene is skipped and
  the scene plays as before. So a picture that shows Ireena carries `"when": "guest:ireena"`, and a second take
  without her can follow it.
- `focus`: where the slow push-in closes on, as a share of the picture's width and height (default the centre).
- `trigger` (places only): a Narrator key (`examine:bonegrinder_lookout`, `enter:<area>`). Looking at that thing or
  walking into that area shows the picture with the narrator's line as its caption, instead of the line in the HUD's
  box, and pauses the game under it (so a fight the area starts waits for it).
- `once` (places only): the picture shows only the first time its trigger fires (`_cutscene/<id>` in the story's
  flags).

`make validate` checks every picture exists, every trigger is a node in a `narrative/narrator/` file, and every
`cutscene <id>` in a conversation names a cutscene.

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
- `ui/cutscene/cutscene_view.gd` (`CutsceneView`): the picture, its fade and push-in, the caption, Skip and the pause
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

Lessons from the first batch: a turnaround sheet passed as a reference can come back as several copies of that
creature in the scene (Argynvost's echo, the nightmare horse), so scenery creatures are described in words instead;
"an old painting" draws a paper border; scale words need an anchor ("the travellers are tiny specks beside one of its
talons"). The caged children and the hanged man passed Gemini's image safety only on a retry.

| Cutscene | Title | Plays from | Takes |
|---|---|---|---|
| abbey_bride | The Bride Opens Her Eyes | `abbey_of_st_markovia/unveiling` | 1 |
| abbot_kneeling | Light Like Water | `abbey_of_st_markovia/unveiling` | 1 |
| abbot_wings | The Abbot's Wings | `abbey_of_st_markovia/abbot`, `abbey_of_st_markovia/unveiling` | 1 |
| amber_gift | Lying Down in the Amber | `amber_temple/vosk` | 1 |
| amber_pact | The Bargain | `amber_temple/vault` | 1 |
| amber_sentinel_steps | The Sentinel Steps Down | `amber_temple/sentinel` | 1 |
| amber_sentinels | The Amber Sentinels | `amber_temple/sentinel` | 1 |
| arabelle_dive | Under the Black Water | `vallaki/vistani_camp` | 1 |
| argynvost_flame | The Silver Flame | `argynvostholt/mausoleum` | 1 |
| argynvost_frost | A Dragon in the Frost | `argynvostholt/argynvost` | 1 |
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
| castle_road_west | The Castle on Its Pillar | `enter:village_road_west` | 1 |
| chapel_dawn | Dawn in the Chapel | `companions/dawn` | 1 |
| crossroads_dead | The Gallows Field Wakes | `enter:crossroads_gallows` | 1 |
| crossroads_gallows | The Hanged Man | `svalich_road/crossroads` | 1 |
| death_house_children | The Children Go Home | `death_house/dungeon` | 1 |
| death_house_cult | The Ring of Shadows | `death_house/altar` | 1 |
| death_house_lorghoth | The Heap That Stands Up | `death_house/altar` | 1 |
| death_house_window | The House Shuts Its Mouth | `death_house/escape` | 1 |
| dinner_organ | Dinner at the Organ | `castle_ravenloft/gates_dinner` | 2 |
| ending_bride | The Bride of Ravenloft | `endings/ireena_given_up` | 1 |
| ending_darklord | The Second Thirst | `endings/new_darklord` | 1 |
| ending_dawn | Dawn over Barovia | `endings/strahd_destroyed` | 1 |
| ending_mists | The Mists Remain | `endings/strahd_triumphant` | 1 |
| ending_sergei | At Sergei's Side | `endings/ireena_at_peace` | 1 |
| festival_square | The Square Turns | `vallaki/festival` | 1 |
| festival_sun_blazes | The Blazing Sun | `vallaki/festival` | 1 |
| festival_sun_dies | The Sun That Wouldn't Burn | `vallaki/festival` | 1 |
| heart_beats | The Heart of Sorrow | `castle_ravenloft/spires_heart` | 1 |
| heart_breaks | The Heart Breaks | `castle_ravenloft/spires_heart` | 1 |
| ilinca_raven | The Raven Who Is a Woman | `old_bonegrinder/ilinca` | 1 |
| ireena_window | At Ireena's Window | `strahd/ireena` | 1 |
| ireena_window_empty | The Empty Window | `strahd/ireena` | 1 |
| krezk_reflection | The Second Reflection | `krezk/pool` | 1 |
| lysaga_bowl | The Witch in Her Bowl | `berez/marina` | 1 |
| lysaga_hut | The Hut Stands Up | `berez/lysaga` | 1 |
| madam_eva_reading | Five Cards | `svalich_road/madam_eva` | 1 |
| marina_rose | A Black Rose | `berez/marina` | 1 |
| marina_statue | Marina's Face | `berez/marina` | 1 |
| mists_arrival | Out of the Mists | `into_the_mists/arrival` | 1 |
| mordenkainen_jar | Mordenkainen Remembers | `mount_baratok/mordenkainen` | 1 |
| order_rides | The Order Rides | `argynvostholt/vladimir` | 1 |
| pack_law | Pack Law | `werewolf_den/kiril` | 1 |
| phantom_ride | The Phantom Ride | `argynvostholt/events` | 1 |
| roc_shadow | The Roc's Shadow | `tsolenka_pass/events` | 1 |
| sergei_font | Sergei in the Font | `castle_ravenloft/catacombs_sergei` | 1 |
| strahd_camp | Someone Is Watching the Camp | `strahd/visits` | 2 |
| strahd_end | Like Old Paper | `castle_ravenloft/catacombs_coffin` | 2 |
| strahd_rides | The Rider Out of the Fog | `svalich_road/events` | 2 |
| strahd_waiting | He Is Waiting for You | `strahd/final` | 12 |
| strahd_watcher | The Rider on the Ridge | `strahd/visits` | 2 |
| strahd_watcher_gone | The Empty Ridge | `strahd/visits` | 1 |
| tser_falls | Tser Falls | `svalich_road/tser_falls` | 1 |
| tser_falls_ireena | At the Lip | `svalich_road/tser_falls` | 1 |
| vines_gem | The Vines Remember | `wizard_of_wines/davian` | 1 |
| yester_burn | The Tree Burns | `yester_hill/summit` | 1 |
| yester_effigy | The Effigy on Yester Hill | `yester_hill/ruxandra` | 1 |
| yester_wintersplinter | Wintersplinter Walks | `yester_hill/ruxandra` | 1 |
