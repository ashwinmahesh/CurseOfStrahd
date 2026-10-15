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

A long conversation over one picture gets more pictures where the scene changes (owner, 2026-10-12: "it's kind of
boring looking at the same image for multiple phases of dialogue, especially if the scene is evolving"). Each beat is a
`cutscene <id>` statement placed just before the line where something new happens (the dead knights stand, the wolf
comes out of the trapper, the organ bench is empty), so the next picture fades over the last. The first round,
2026-10-12: 42 beats (44 pictures) in the 28 conversations whose picture stayed up longest. The second round, the same night: 12 beats in the next-longest ones. The Abbot's first visit got its third picture on 2026-10-13 (owner: it stayed on one too long): his
bride, shown across the courtyard as he says he is making Strahd a wife; it stays up through the wedding-dress request and the
rest of the visit.

Owner rule (2026-10-14): every cutscene is at least two scenes. A conversation that plays one picture gets a second at a
later beat (a fight about to start, the aftermath, the memory a line brings up), with a caption line after it so it shows
before the fight begins. A place's trigger cutscene follows the same rule, but needs a small change to the player first.
The third round, 2026-10-14: 47 pictures, one more in each of the 47 conversations that had only one.
The drowned rising at Lake Zarovich (`drowned_rise`, then `drowned_bluto` or `drowned_nistor`) came first.

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
- `then`, `caption`: the scene after this one (owner rule, 2026-10-14: every cutscene is at least two scenes). `then`
  names another cutscene, with its own picture and a `caption`, a Narrator key (`scene:<id>`, in the narrator file of
  that region) whose line reads over it. When a trigger plays the first scene, the second fades in after its last
  caption, and so on down a chain; Skip leaves them all. A scene with no picture for the story now, or a key with no
  line, ends the chain there, so a game with no Narrator plays the first scene alone. A treasure found in a
  conversation plays its next scenes after the notices (each picture with the Narrator's line over it) and then takes
  the picture away, so the talk goes on as it did.

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
- Esc: pauses, with Resume and Skip the scene. Esc again resumes. Nothing else moves on while it's paused, the Narrator's
  voice included (VoiceOver.set_paused; UI QA SND-03).

## Endings
An ending's narration (`narrative/endings/`) can hold `cutscene <id>` too: the ending screen puts the picture behind
the words, in full colour, in place of the dimmed castle, and keeps it for the epilogue slides.

## Fights
A fight that a conversation starts gets its picture from that conversation: the `cutscene` line goes before its last
line, so the picture shows with it before the fight begins (Wintersplinter, the Abbot's wings, the hut). A fight an
area starts (the gallows field at night) takes the area's `enter:` trigger; the game waits under the picture.

## Code
- `story/cutscenes.gd` (`Cutscenes`): the data, the picture for the story now (`image`), `focus`, `for_trigger`, and
  `scenes` (a trigger's scenes in order, from `then` and `caption`).
- `ui/cutscene/cutscene_view.gd` (`CutsceneView`): the picture (whole, letterboxed in black) and its fade, the caption, Skip and the pause
  card. Motion is off in headless runs and still captures (UiMotion).
- `ui/cutscene/cutscene_player.gd` (`CutscenePlayer`): a place's cutscene while exploring, opened by
  `world/game_root.gd play_cutscene` from `LocationView.cutscene_requested` (a fight's narrator key opens it from
  `world/combat/combat_view.gd`). It stands in as the open screen, so nothing in the world moves under it. It plays
  `Cutscenes.scenes`: each scene's captions, then the next picture.
- `ui/dialogue/dialogue_ui.gd`: the `cutscene` beat, captions and Skip in a conversation.

## Art
`tools/art/build_cutscenes.py [--generate] [--only id ...] [--sheet out.png]` builds every picture from
`tools/art/cutscene_recipes.json` (the prompts the owner approved in the Cutscene Audit doc, 2026-10-07): Gemini
(`gemini-3.1-flash-image`, the pinned model, through `tools/art/generate_gemini.py` so the spend ledger counts it) with
`art/prompts/cutscene_preamble.txt`, 16:9 at 2K (2752x1536, about $0.10 a picture), and the cast's turnarounds from
`art/generated/characters/` as references so faces and clothes match the sprites. The party is drawn hooded and from
behind, since the player makes their own heroes. Takes are kept in `art/generated/cutscenes/<image>_<a, b ...>.png`;
the recipe's `use` take is saved as `art/cutscenes/<image>.jpg`, any solid black band along an edge trimmed off
(vosk_unmasked's take had one across its top; UI QA ART-07) (quality 92, Git LFS: Gemini returns JPEG anyway,
and the game's copies stay about 0.7 MB each) and imported with VRAM compression and mipmaps
(`tools/art/set_import.py`, force-add its `.import`). `--sheet` draws a contact sheet of the newest takes for review.

Round 2 (54 pictures, the owner's wider rule) followed on 2026-10-08. Lessons from both batches: a turnaround sheet passed as a reference can come back as several copies of that
creature in the scene (Argynvost's echo, the nightmare horse), so scenery creatures are described in words instead;
"an old painting" draws a paper border; scale words need an anchor ("the travellers are tiny specks beside one of its
talons"). The caged children and the hanged man passed Gemini's image safety only on a retry.

| Cutscene | Title | Plays from | Takes |
|---|---|---|---|
| abbey_bride | The Bride Opens Her Eyes | `abbey_of_st_markovia/unveiling` | 1 |
| abbey_gate_light | One Window Lit | the scene after `abbey_shelf` (`then`) | 1 |
| abbey_shelf | The Abbey on Its Shelf | `enter:abbey_of_st_markovia` | 1 |
| abbot_bride_wards | Making Him a Wife | `abbey_of_st_markovia/abbot` (a later beat, ~ bride) | 1 |
| abbot_candles | The Abbot Lights the Candles | `abbey_of_st_markovia/abbot` | 1 |
| abbot_holds_hand | He Is Holding Her Hand | `abbey_of_st_markovia/unveiling` | 1 |
| abbot_ireena_candles | The Candles Lean to Her | `abbey_of_st_markovia/abbot` (a later beat, ~ first) | 1 |
| abbot_kneeling | Light Like Water | `abbey_of_st_markovia/unveiling` | 1 |
| abbot_letter | Markovia's Letter | `abbey_of_st_markovia/unveiling` (a later beat, ~ letter_after) | 1 |
| abbot_wings | The Abbot's Wings | `abbey_of_st_markovia/abbot`, `abbey_of_st_markovia/unveiling` | 1 |
| adrian_picks | One Hat a Night | `wizard_of_wines/the_black_row` (a later beat, ~ stakeout) | 1 |
| amber_gift | Lying Down in the Amber | `amber_temple/vosk` | 1 |
| amber_pact | The Bargain | `amber_temple/vault` | 1 |
| amber_sentinel_steps | The Sentinel Steps Down | `amber_temple/sentinel` | 1 |
| amber_sentinels | The Amber Sentinels | `amber_temple/sentinel` | 1 |
| arabelle_dive | Under the Black Water | `vallaki/vistani_camp` | 1 |
| arabelle_shore | Out of the Sack | `vallaki/vistani_camp` (a later beat, ~ rescued) | 1 |
| argynvost_flame | The Silver Flame | `argynvostholt/mausoleum` | 1 |
| argynvost_frost | A Dragon in the Frost | `argynvostholt/argynvost` | 1 |
| argynvost_last_breath | Let Them Go Home | `argynvostholt/argynvost` (a later beat, ~ last_words) | 1 |
| attic_flash | The Attic Window Flashes | `vallaki/aftermath` | 1 |
| aurel_leaves | The Lamp Goes Out | `castle_ravenloft/personal_aurel` (a later beat, ~ woken) | 1 |
| aurel_reading | Reading to an Empty Chair | `castle_ravenloft/personal_aurel` | 1 |
| aurel_tome | The Book in His Hands | `castle_ravenloft/personal_aurel` (a later beat, ~ woken_tome) | 1 |
| baron_overthrown | The Spears Go Down | `vallaki/aftermath` (a later beat, ~ wachter) | 1 |
| beacon_hall_bows | The Knights Bow | `argynvostholt/beacon` (a later beat, ~ light) | 1 |
| beacon_lit | The Beacon Is Lit | `argynvostholt/beacon` | 2 |
| beacon_road | The Light on the Ridge | `argynvostholt/events` | 1 |
| bear_blights | The Trees Come for the Crying | `svalich_road/the_dancing_bear` (a later beat, ~ blights) | 1 |
| black_carriage | The Black Carriage | `strahd/letters` | 1 |
| blights_fall | The Slope Goes Quiet | `yester_hill/summit` (a later beat, ~ burn) | 1 |
| bonegrinder_burns | Old Bonegrinder Burns | `old_bonegrinder/mill` | 1 |
| bonegrinder_crag | The View from the Crag | `enter:hill_lookout` | 2 |
| bonegrinder_far_castle | The Castle Holds Still | the scene after `bonegrinder_crag`, `bonegrinder_view` (`then`) | 1 |
| bonegrinder_hag | Morgantha Stands | `old_bonegrinder/morgantha` | 1 |
| bonegrinder_loft | Cages and a Rocking Chair | `old_bonegrinder/children` | 1 |
| bonegrinder_view | The View from the Crag | `examine:bonegrinder_lookout` | 2 |
| bones_home | Welcome Home, Old Man | `vallaki/lucian` (a later beat, ~ return) | 1 |
| bride_rests | She Lies Back | `abbey_of_st_markovia/unveiling` (a later beat, ~ repent_unmake) | 1 |
| bride_turns | She Turns Her Head | `abbey_of_st_markovia/unveiling` (a later beat, ~ demand) | 1 |
| brides_rise | The Brides Rise | `castle_ravenloft/court_brides` (a later beat, ~ fight) | 1 |
| burial_choke | Ismark Can't Breathe | `village_of_barovia/burial` (a later beat, ~ ismark_choked) | 1 |
| burial_doru | A Messenger on the Wall | `village_of_barovia/burial` | 1 |
| burial_graves | The Graves Split | `village_of_barovia/burial` | 1 |
| burial_strahd | A Mourner Who Came Late | `village_of_barovia/burial` | 1 |
| cairn_open | Under the Last Stone | `mount_baratok/events` (a later beat, ~ cairn_open) | 1 |
| camp_bow | He Bows to Her | `strahd/visits` (a later beat, ~ night_shield) | 1 |
| camp_kneel | At His Feet | `strahd/visits` (a later beat, ~ night_kneel) | 1 |
| carriage_letter | A Letter in Black Wax | `strahd/letters` (a later beat, ~ invitation) | 1 |
| carriage_ride | Up into the Cloud | `strahd/letters` | 1 |
| carriage_turns | The Carriage Goes Back | `strahd/letters` (a later beat, ~ decline) | 1 |
| castle_chasm | The Castle Across the Chasm | `enter:castle_ravenloft_gates` | 2 |
| castle_drawbridge | No One at the Winch | the scene after `castle_chasm` (`then`) | 1 |
| castle_glimpse | The Castle on Its Pillar | `examine:castle_glimpse` | 1 |
| castle_road_west | The Castle on Its Pillar | `village_of_barovia/road_west` (the first try at the west posts, alone; once) | 1 |
| castle_windows_lit | The House Counts Its Guests | the scene after `castle_glimpse` (`then`) | 1 |
| chapel_dawn | Dawn in the Chapel | `castle_ravenloft/personal_prayers`, `companions/dawn` | 1 |
| children_freed | Five Children Walk Past the Wolves | `werewolf_den/kiril` | 1 |
| children_wave | Thorn Waves | `death_house/dungeon` (a later beat, ~ lay_to_rest) | 1 |
| church_gate | At the Churchyard Gate | `strahd/ireena` | 1 |
| church_gate_empty | The Gate Is Empty | `strahd/ireena` (a later beat, ~ church_end) | 1 |
| church_vigil | Vigil at St. Andral's | `vallaki/lucian` | 1 |
| coffin_turns | Something Turns to the Wall | `castle_ravenloft/personal_prayers` (a later beat, ~ prayer) | 1 |
| corvina_coat | A Candle on the Box | `castle_ravenloft/the_unnamed_crypt` (a later beat, ~ after) | 1 |
| crossroads_dead | The Gallows Field Wakes | `enter:crossroads_gallows` | 1 |
| crossroads_gallows | The Hanged Man | `svalich_road/crossroads` | 1 |
| dawn_sunburst | The Sunburst Given | `companions/dawn` (a later beat, ~ chapel_hymn) | 1 |
| dead_feast | A Feast Nobody Dismissed | `argynvostholt/vladimir` | 1 |
| dead_procession | The Dead Procession | `svalich_road/events` | 1 |
| death_house_children | The Children Go Home | `death_house/dungeon` | 1 |
| death_house_cult | The Ring of Shadows | `death_house/altar` | 1 |
| death_house_lorghoth | The Heap That Stands Up | `death_house/altar` | 1 |
| death_house_window | The House Shuts Its Mouth | `death_house/escape` | 1 |
| dinner_empty | The Empty Bench | `castle_ravenloft/gates_dinner` (a later beat, ~ thanks) | 1 |
| dinner_organ | Dinner at the Organ | `castle_ravenloft/gates_dinner` | 2 |
| dinner_toast | Strahd's Table | `castle_ravenloft/gates_dinner` (a later beat, ~ table) | 1 |
| doru_ceiling | The Face on the Ceiling | `village_of_barovia/doru` (the first meeting only) | 1 |
| doru_chains | In Silvered Chains | `castle_ravenloft/larders_cells` (a later beat, ~ doru_first) | 1 |
| doru_dessert | Dessert | `village_of_barovia/doru` (a later beat, ~ castle) | 1 |
| doru_rest | Doru at Rest | `castle_ravenloft/larders_cells` | 1 |
| dragos_unwound | A Goat, Then a Man | `krezk/one_horned_billy` (a later beat, ~ freed) | 1 |
| drowned_bluto | They Turn to Bluto | `lake_zarovich/bell_under_the_lake` (a later beat, ~ water, with Bluto alive) | 1 |
| drowned_nistor | One of Us | `lake_zarovich/bell_under_the_lake` (a later beat, ~ water, with Bluto gone) | 1 |
| drowned_rise | The Drowned Rise | `lake_zarovich/bell_under_the_lake` (~ water, after moonrise) | 1 |
| durst_supper | Supper with the Dursts | `death_house/dursts` | 1 |
| durst_table | The Table Goes Over | `death_house/dursts` (a later beat, ~ bristle, confess, fight) | 1 |
| egg_carried | Down with the Chick | `tsolenka_pass/the_last_egg` (a later beat, ~ take) | 1 |
| egg_sold | The Stone Birds Take It | `tsolenka_pass/the_last_egg` (a later beat, ~ sold) | 1 |
| elvir_burial | Elvir Comes Home | `wizard_of_wines/davian` | 1 |
| ending_arm | He Offers His Arm | `endings/ireena_given_up` (a later beat, ~ handed_over) | 1 |
| ending_bride | The Bride of Ravenloft | `endings/ireena_given_up` | 1 |
| ending_darklord | The Second Thirst | `endings/new_darklord` | 1 |
| ending_dawn | Dawn over Barovia | `endings/strahd_destroyed` | 1 |
| ending_mists | The Mists Remain | `endings/strahd_triumphant` | 1 |
| ending_sergei | At Sergei's Side | `endings/ireena_at_peace` | 1 |
| escher_coat | A Good Red Coat | `castle_ravenloft/escher_petition` (a later beat, ~ sun) | 1 |
| eva_candles_lean | The Candles Lean | `svalich_road/madam_eva` (a later beat, ~ ally_seen) | 1 |
| eva_chest | The Bundle in the Chest | `svalich_road/madam_eva` (a later beat, ~ treasure_here) | 1 |
| eye_watches_gods | A Thousand Years of Lies | `amber_temple/the_amber_debt` (a later beat, ~ eye_what) | 1 |
| feast_gift | The Thing He Kept | `argynvostholt/vladimir` (a later beat, ~ keeping) | 1 |
| feast_pact | The Order Stands | `argynvostholt/vladimir` (a later beat, ~ pact) | 1 |
| fen_chains | Grandda | `companions/fen` | 1 |
| fen_cloak | The Trapper's Cloak | `companions/fen` (a later beat, ~ cure) | 1 |
| fen_cure | The Wolf Comes Out | `companions/fen` (a later beat, ~ cure) | 1 |
| festival_square | The Square Turns | `vallaki/festival` | 1 |
| festival_standoff | Vallaki Draws Steel | `vallaki/festival` (a later beat, ~ baron_side) | 1 |
| festival_sun_blazes | The Blazing Sun | `vallaki/festival` | 1 |
| festival_sun_dies | The Sun That Wouldn't Burn | `vallaki/festival` | 1 |
| font_sergei | Beside Her in the Water | `castle_ravenloft/catacombs_sergei` (a later beat, ~ ireena_promised) | 1 |
| forty_chairs | Forty Chairs | `castle_ravenloft/personal_kestrel` | 1 |
| forty_fall_in | The Company Falls In | `castle_ravenloft/personal_kestrel` (a later beat, ~ merrow_counted) | 1 |
| forty_roll | Roll Call | `castle_ravenloft/personal_kestrel` (a later beat, ~ roll) | 1 |
| gallows_dead_turn | Every Head Turns | the scene after `crossroads_dead` (`then`) | 1 |
| gallows_grave | The Horse Thief's Grave | `svalich_road/crossroads` (a later beat, ~ buried) | 1 |
| gertruda_beads | Her Mother's Beads | `castle_ravenloft/court_gertruda` (a later beat, ~ homecoming) | 1 |
| gertruda_home | Gertruda Comes Home | `castle_ravenloft/court_gertruda` | 1 |
| gilded_rises | The Hoard Rises | `argynvostholt/the_silver_hoard` (a later beat, ~ fight) | 1 |
| gilded_shield | The Squire's Shield | `argynvostholt/the_silver_hoard` (a later beat, ~ hands) | 1 |
| godfrey_names | The Names on the Wall | `argynvostholt/godfrey` (a later beat, ~ remember_list) | 1 |
| godfrey_rests | Godfrey Rests | `argynvostholt/beacon` | 1 |
| godfrey_steps | Sir Godfrey on the Steps | `argynvostholt/godfrey` | 1 |
| godrick_knighting | Rise, Sir Godrick | `companions/ladle` | 1 |
| hags_three_faces | Three Faces at the Mill | `old_bonegrinder/ilinca` (a later beat, ~ mill) | 1 |
| hall_stirs | A Chair Scrapes Back | `argynvostholt/mausoleum` (a later beat, ~ kindle) | 1 |
| heart_beats | The Heart of Sorrow | `castle_ravenloft/spires_heart` | 1 |
| heart_breaks | The Heart Breaks | `castle_ravenloft/spires_heart` | 1 |
| hunt_begins | The Hunt Runs | `svalich_road/the_counts_huntsman` (a later beat, ~ fight) | 1 |
| ilinca_children | Ilinca Takes Them Home | `old_bonegrinder/children` | 1 |
| ilinca_raven | The Raven Who Is a Woman | `old_bonegrinder/ilinca` | 1 |
| ireena_door | Three Bolts Slide Back | `village_of_barovia/ireena` | 1 |
| ireena_looks_back | Ireena Looks Back | `village_of_barovia/road_west` | 2 |
| ireena_stake | She Kneels on the Coffin | `castle_ravenloft/catacombs_coffin` (a later beat, ~ ireena_stake) | 1 |
| ireena_window | At Ireena's Window | `strahd/ireena` (Ismark asleep by the door while he guards her at the inn; otherwise the take with the room empty) | 2 |
| ireena_window_empty | The Empty Window | `strahd/ireena` | 1 |
| izek_doll | Izek and the Doll | `vallaki/izek` | 1 |
| izek_truth | The Struck Bell | `vallaki/izek` (a later beat, ~ truth_ok) | 1 |
| keepers_ravens | Ravens on Every Beam | `vallaki/martikovs` | 1 |
| khazan_writes | Written Out in the Good Ink | `van_richtens_tower/the_name_over_the_door` (a later beat, ~ threaten) | 1 |
| kip_nobody_there | Nobody There | `camp/kip` (a later beat, ~ quillon_go) | 1 |
| kiril_eyes | Eyes Behind Kiril | `werewolf_den/kiril` | 1 |
| knighting_sword | Sir Aldric's Sword | `companions/ladle` (a later beat, ~ knighting_fellowship) | 1 |
| knights_at_the_stair | The Order at the Stair | `castle_ravenloft/catacombs_coffin` (a later beat, ~ the_end) | 3 |
| krezk_gate_lamps | The Watch at the Gate | the scene after `krezk_wall` (`then`) | 1 |
| krezk_reflection | The Second Reflection | `krezk/pool` | 1 |
| krezk_wall | The Wall of Krezk | `enter:krezk` | 1 |
| lantern_light | She Takes the Light | `vallaki/one_lantern_too_many` (a later beat, ~ girl_lantern) | 1 |
| lightning_ridge | Lightning on the Ridge | `mount_baratok/events` | 1 |
| locket_chair | The Chair by the Fire | `castle_ravenloft/personal_locket` | 1 |
| locket_given | The Locket | `castle_ravenloft/personal_locket` (a later beat, ~ give) | 1 |
| lysaga_bowl | The Witch in Her Bowl | `berez/marina` | 1 |
| lysaga_hut | The Hut Stands Up | `berez/lysaga` | 1 |
| lysaga_poppet | The Poppet over the Hearth | `berez/hut` | 1 |
| lysaga_supper | Supper at the Green Fire | `berez/lysaga` (a later beat, ~ supper) | 1 |
| madam_eva_reading | Five Cards | `svalich_road/madam_eva` | 1 |
| mansion_siege | Hands Through the Boards | `village_of_barovia/ireena` | 1 |
| marina_bier | Marina on Her Bier | `berez/marina` | 2 |
| marina_gone | Only the Rose | `berez/marina` (a later beat, ~ strahd_truth) | 1 |
| marina_rose | A Black Rose | `berez/marina` | 1 |
| marina_statue | Marina's Face | `berez/marina` | 1 |
| marshal_charge | The Lances Come Down | `into_the_mists/last_muster` (a later beat, ~ fight) | 1 |
| marshal_stand_down | The Column Stands Down | `into_the_mists/last_muster` (a later beat, ~ stood_down) | 1 |
| mists_arrival | Out of the Mists | `into_the_mists/arrival` | 1 |
| mists_wolves_watch | Wolves Along the Road | `into_the_mists/arrival` (a later beat, ~ hooks) | 1 |
| mordenkainen_jar | Mordenkainen Remembers | `mount_baratok/mordenkainen` | 1 |
| mordenkainen_returns | He Remembers Himself | `mount_baratok/mordenkainen` (a later beat, ~ restored) | 1 |
| morgantha_keys | Keys and Humming | `old_bonegrinder/morgantha` (a later beat, ~ release) | 1 |
| mother_lands | Mother Comes Down in Krezk | `abbey_of_st_markovia/mothers_ninth_improvement` (a later beat, ~ gift) | 1 |
| order_rides | The Order Rides | `argynvostholt/vladimir` | 1 |
| pack_law | Pack Law | `werewolf_den/kiril` | 1 |
| pact_two_books | Two Accounts of One Night | `amber_temple/vault` (a later beat, ~ pact_tome) | 1 |
| patrina | Patrina | `amber_temple/patrina` | 1 |
| patrina_fades | She Fades Like Breath | `amber_temple/patrina` (a later beat, ~ at_rest) | 1 |
| patrina_kasimir | Patrina, and Her Brother | `amber_temple/patrina` | 1 |
| penitent_stands | The Penitent Stands | `tsolenka_pass/the_frozen_pilgrims` (a later beat, ~ break) | 1 |
| petru_morning | Petru by the Goats | `krezk/the_packs_runt` (a later beat, ~ after) | 1 |
| phantom_ride | The Phantom Ride | `argynvostholt/events` | 1 |
| pool_alone | Only Her Reflection | `krezk/pool` (a later beat, ~ ireena_fade) | 1 |
| pool_lean | Her Breath on the Water | `krezk/pool` (a later beat, ~ ireena_promise) | 1 |
| pool_sergei_face | The Face in the Water | `endings/ireena_at_peace` (a later beat, ~ start) | 1 |
| portraits_turn | Every Portrait Turns | `vallaki/the_counts_portraitist` (a later beat, ~ burn) | 1 |
| quillon_fire | The Man at the Edge of the Light | `camp/kip` | 1 |
| rahadin_draws | Rahadin Draws | `castle_ravenloft/court_rahadin` (a later beat, ~ fight) | 1 |
| rahadin_voices | Rahadin and His Voices | `castle_ravenloft/court_rahadin` | 1 |
| roc_looks_down | Too Small to Bother With | `tsolenka_pass/events` (a later beat, ~ roc_shadow) | 1 |
| roc_shadow | The Roc's Shadow | `tsolenka_pass/events` | 1 |
| ruxandra_turns | The Kindest Face | `yester_hill/ruxandra` (a later beat, ~ speak) | 1 |
| sarkhaza_freed | The Collar Opens | `mount_ghakis/the_warm_snow` (a later beat, ~ unchained) | 1 |
| sergei_font | Sergei in the Font | `castle_ravenloft/catacombs_sergei` | 1 |
| sergei_tomb | The Thing Never Carved | `castle_ravenloft/catacombs_sergei` (a later beat, ~ tomb_look) | 1 |
| souls_go_home | The Souls Go Home | `old_bonegrinder/mill` (a later beat, ~ free) | 1 |
| stair_out | Up the Long Stair | `endings/strahd_destroyed` (a later beat, ~ start) | 1 |
| strahd_asleep | Strahd Asleep | `castle_ravenloft/catacombs_coffin` | 1 |
| strahd_begins | Begin | `strahd/final` (a later beat, ~ answered) | 1 |
| strahd_camp | Someone Is Watching the Camp | `strahd/visits` | 2 |
| strahd_end | Like Old Paper | `castle_ravenloft/catacombs_coffin` | 2 |
| strahd_letter | A Letter in His Own Hand | `strahd/letters` | 1 |
| strahd_mist_coffin | The Lid Slides Shut | the scene after `strahd_mist_flight` (`then`) | 1 |
| strahd_mist_flight | He Goes Home to His Coffin | `strahd:fled_to_coffin` | 1 |
| strahd_resting | Strahd, Beaten | `castle_ravenloft/catacombs_coffin` | 1 |
| strahd_rides | The Rider Out of the Fog | `svalich_road/events` | 2 |
| strahd_waiting | He Is Waiting for You | `strahd/final` | 12 |
| strahd_watcher | The Rider on the Ridge | `strahd/visits` | 2 |
| strahd_watcher_gone | The Empty Ridge | `strahd/visits` | 1 |
| sunsword_light | A Room Without Shadows | the scene after `treasure_sword` (`then`) | 1 |
| symbol_dawn | The Cold Takes a Step Back | the scene after `treasure_symbol` (`then`) | 1 |
| thirst_passes | Where the Thirst Goes | `endings/new_darklord` (a later beat, ~ start) | 1 |
| three_brides | Three Brides | `castle_ravenloft/court_brides` | 1 |
| tinker_freed | Seven Years at the Front of That Thing | `svalich_road/the_tinkers_wagon` (a later beat, ~ freed) | 1 |
| tome_page | The First Page | the scene after `treasure_tome` (`then`) | 1 |
| tower_lamp | Someone Waiting Up | the scene after `vr_tower` (`then`) | 1 |
| treasure_sword | The Sunsword | `find:sunsword` | 1 |
| treasure_symbol | The Holy Symbol of Ravenkind | `find:holy_symbol_of_ravenkind` | 1 |
| treasure_tome | The Tome of Strahd | `find:tome_of_strahd` | 1 |
| tser_falls | Tser Falls | `svalich_road/tser_falls` | 1 |
| tser_falls_ireena | At the Lip | `svalich_road/tser_falls` | 1 |
| tser_pool_fire | Firelight at Tser Pool | `enter:tser_pool` | 1 |
| tser_tent_music | One Song Long | the scene after `tser_pool_fire` (`then`) | 1 |
| vallaki_palisade | The Palisade | `vallaki/gate` | 1 |
| vallaki_smiles | Smile, It's the Law | `vallaki/gate` (a later beat, ~ rules) | 1 |
| van_richten_workroom | Without His Feathers | `van_richtens_tower/van_richten` (a later beat, ~ start) | 1 |
| village_rain | The Village in the Rain | `enter:village_of_barovia` | 1 |
| village_square_empty | A Candle in the Church | the scene after `village_rain` (`then`) | 1 |
| vines_feast | A Cask from Before | `wizard_of_wines/davian` (a later beat, ~ milestone) | 1 |
| vines_gem | The Vines Remember | `wizard_of_wines/davian` | 1 |
| vines_planted | The Gem in the Soil | `wizard_of_wines/davian` (a later beat, ~ return_cellar) | 1 |
| vineyard_south | The Vineyard Gone Quiet | `vallaki/martikovs` (a later beat, ~ keepers) | 1 |
| vosk_unmasked | Vosk Takes Off His Face | `amber_temple/vosk` | 1 |
| vr_reunion | Two People by a Fire | `van_richtens_tower/van_richten` | 1 |
| vr_tower | The Tower on Lake Baratok | `enter:van_richtens_tower` | 1 |
| watch_halt | Halt. Watchword. | `tsolenka_pass/watch` (a later beat, ~ sergeant) | 1 |
| watch_stands_down | The Watch Stands Down | `tsolenka_pass/watch` | 1 |
| whoever_m_was | Whoever M Was | `berez/hut` (a later beat, ~ poppet_truth) | 1 |
| window_burst | Out Through the Window | `death_house/escape` (a later beat, ~ window_through) | 1 |
| window_teeth | What Is Under the Courtesy | `strahd/ireena` (a later beat, ~ woke) | 1 |
| wolves_part | The Wolves Part | `strahd/visits` | 1 |
| yester_burn | The Tree Burns | `yester_hill/summit` | 1 |
| yester_effigy | The Effigy on Yester Hill | `yester_hill/ruxandra` | 1 |
| yester_planting | Something Planted on the Crown | `yester_hill/the_druid_who_came_back` (a later beat, ~ kostin, ruxandra, zorica) | 1 |
| yester_wintersplinter | Wintersplinter Walks | `yester_hill/ruxandra` | 1 |
| yielded_road | The Road Down | `endings/strahd_triumphant` (a later beat, ~ yielded) | 1 |
| zamfira_wrist | Her Mother Kisses Her Wrist | `old_bonegrinder/the_fourth_sister` (a later beat, ~ home) | 1 |
