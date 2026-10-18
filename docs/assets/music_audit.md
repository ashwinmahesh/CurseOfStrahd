# Music audit: the conversations that play cutscenes

Date: 2026-10-17 · owner ask: "ensure the song that plays matches the vibe of the interaction"; fix what a re-mapping
to tracks already in the game can fix (no new music).

A conversation plays its place's mood (art/audio.json `places`, `regions`, `themes`), the castle's `dread` while one of
its menacing few speaks (`talk_moods`), and a fight's music once a fight starts. Before this audit nothing else could
change it, so Strahd at Ireena's window over a lively inn played the inn's folk tunes. Now a cutscene's picture can bring
its own mood (`scenes`: cutscene id -> mood), held for the rest of the conversation over whoever speaks; the place's own
music comes back when the conversation ends (`GameRoot._scene_music`). Endings already name their own (`data/endings/*.json`
`music`).

Track character comes from the composers' own notes (incompetech's feel and instrument tags, scottbuckley.com.au,
OpenGameArt pages), not from listening.

## New moods, all from recordings already in the game

| Mood | Recordings | For |
|---|---|---|
| `sorrow` | Relent (harp, clarinet: "so much sadness"), Unraveling, Penumbra, Memories of Stone | farewells, the dead laid to rest, reunions |
| `tension` (level -1.5) | Gloom Horizon, Oppressive Gloom, Lost Frontier | standoffs and menace in town |
| `dawn` | Long Road Ahead ("the aftermath of a battle between good and evil", triumphant last third), Virtutes Instrumenti (uplifting sacred viol) | real dawn, Strahd's end |
| `sacred` (level -3) | Night Vigil, Virtutes Instrumenti, Ancient Rite, Gregorian Chant | the vigil at St. Andral's, without the Toccata's organ |

Levels match each recording's loudness in its home mood (120 s RMS + mood level + track level: sorrow about -23 dB,
tension -21, dawn -21.5, sacred -23, against town and tavern -22, castle -21 to -24, church -24 to -27).

## Changed: the scene's music now

| Conversation | Where it plays (place music) | The scene | Now |
|---|---|---|---|
| strahd/visits | the road, camp, anywhere (wilds, camp: Czardas, town) | the rider on the ridge, the man watching the camp, wolves parting for him | `dread` at strahd_watcher, strahd_camp, wolves_part |
| strahd/letters | wherever the letter or carriage finds you (an inn's folk tunes, Vallaki's) | a letter in his hand, the black carriage | `dread` at strahd_letter, black_carriage |
| strahd/ireena | Ireena's room, the churchyard (tavern, town, church) | Strahd outside her window, at the churchyard gate | `dread` at ireena_window, church_gate |
| strahd/final | wherever the last fight is | "He is waiting for you" | `dread` at strahd_waiting |
| svalich_road/events | the road (wilds) | the rider out of the fog | `dread` at strahd_rides (the dead procession keeps the road's) |
| berez/marina | Marina's monument (berez: Baba Yaga's drums) | Marina on her bier; Strahd with his black rose | `sorrow` at marina_bier, `dread` at marina_rose |
| castle_ravenloft/catacombs_coffin | castle | Strahd asleep (before he speaks); his end like old paper, the knights at the stair | `dread` at strahd_asleep, `dawn` at strahd_end and knights_at_the_stair |
| castle_ravenloft/personal_prayers, companions/dawn | castle chapel (Danse Macabre, the masquerade waltz) | real dawn through the chapel glass | `dawn` at chapel_dawn |
| castle_ravenloft/catacombs_sergei | castle | Ireena kneels by Sergei's font; he is beside her | `sorrow` at sergei_font |
| castle_ravenloft/personal_aurel | castle | reading to an empty chair; the lamp goes out | `sorrow` at aurel_reading |
| castle_ravenloft/larders_cells | castle | Doru at rest, dust in the chains | `sorrow` at doru_rest |
| castle_ravenloft/court_gertruda | Mad Mary's house (village) | Gertruda comes home to her mother | `sorrow` at gertruda_home |
| vallaki/festival | Vallaki (town: bouncy folk) | the sun won't burn; Lady Wachter's coup; Vallaki draws steel | `tension` at festival_sun_dies, festival_square, festival_standoff (the blazing sun keeps the town's cheer) |
| vallaki/aftermath | Vallaki (town) | the Baron's spears go down; the attic window flashes | `tension` at baron_overthrown, attic_flash |
| vallaki/izek | Izek's room (town) | Izek in the dark with a doll; "My sister had red hair" | `tension` at izek_doll, `sorrow` at izek_truth |
| vallaki/one_lantern_too_many | the jetty (town) | a drowned girl's ghost leads a boy to the water; she takes the light and goes out | `dread` at sq_lantern_girl, `sorrow` at lantern_light |
| vallaki/the_counts_portraitist | the painter's studio (town) | the painted woman whose eyes move | `dread` at sq_counts_likeness |
| vallaki/lucian | St. Andral's (church: the Toccata) | the long vigil; St. Andral's bones home | `sacred` at church_vigil |
| vallaki/vistani_camp | the Vistani camp (camp: Czardas) | diving into black water for the sack; Arabelle alive on the shore | `tension` at arabelle_dive, back to `camp` at arabelle_shore |
| camp/kip | the party's camp, anywhere | Mister Quillon at the edge of the firelight | `dread` at quillon_fire |
| death_house/dungeon | Death House (haunted: Darkest Child, the skeleton waltz) | Rose and Thorn say goodbye | `sorrow` at death_house_children |
| van_richtens_tower/van_richten | the tower (haunted) | Rictavio without his feathers; the two of them down the stairs | `sorrow` at van_richten_workroom, vr_reunion |
| wizard_of_wines/davian | the winery (vineyard; the klezmer once Yester Hill falls) | Elvir's burial at the end of the green row | `sorrow` at elvir_burial (the feast keeps the freed vineyard's dance) |
| amber_temple/patrina | the temple (amber_temple: Ice Demon) | Kasimir finds his sister; she fades like breath | `sorrow` at patrina_kasimir, patrina_fades |
| old_bonegrinder/children | the mill loft (creepy children's songs) | Ilinca takes the children home | `sorrow` at ilinca_children |
| old_bonegrinder/mill | the mill (creepy children's songs) | the stolen souls go home | `sorrow` at souls_go_home |
| svalich_road/the_tinkers_wagon | the road or Tser Pool | Iosif free after seven years | `sorrow` at tinker_freed |
| endings | the ending screen (ending: a doom drone, the funeral march) | Dawn over Barovia; At Sergei's Side; The Second Thirst | `dawn`, `sorrow`, `dread` (Bride of Ravenloft and The Mists Remain keep `ending`) |

## Kept: the place's music already fits

- Castle: the brides, Rahadin, Escher, the dinner, the locket, Kestrel's forty chairs, the Heart of Sorrow, Corvina
  (castle music, or the `dread` its menacing few bring).
- Village of Barovia: the burial (Strahd comes late, but the village's mournful gloom is a funeral's music), Ireena's
  door and the siege, the road west, Doru on the church ceiling (the Toccata suits a horror reveal).
- Vallaki: the gate ("Smile, it's the law" is meant to sound cheerful), the blazing sun at the festival. The Keepers of
  the Feather at the Blue Water Inn keep the inn's music: no recording in the game fits a hushed secret better than its
  quiet Midnight Tale (a new mysterious track would).
- Death House: the cult, Lorghoth, the Dursts' supper, the escape. Khazan at Van Richten's tower.
- Abbey, Krezk (the pool, Billy, the runt), Argynvostholt (the dragon, the beacon, the feast, Godfrey, the knighting):
  their sacred and noble region themes fit.
- Amber Temple and Tsolenka Pass: the sentinels, Vosk, the vault, the eye, the roc, the watch, the pilgrims, the egg.
- Berez: Lysaga and her hut (Baba Yaga is her music). Marina's statue keeps Berez's eerie drone.
- Old Bonegrinder: the hags, Morgantha, the cages (the creepy children's songs are right until the rescue).
- Wilds and wildlands: the crossroads gallows, Tser Falls, the huntsman, the mists, the bone marshal, the drowned at
  Lake Zarovich, Kiril's den, Fen, Yester Hill, Mount Baratok, Mount Ghakis, the dancing bear.
- Madam Eva (the tarokka mood's mysterious Vistani pieces), the winery's gem and planting, the black row.

## Not fixable by re-mapping

- The Keepers of the Feather reveal would want a hushed, mysterious piece the game doesn't have.
- Place cutscenes (walking into an area, examining a thing) keep the place's music; none of them clashed.

## Castle piano (2026-10-18)

The owner's favourite castle piece is Chopin's Marche funèbre, so the audit's shortlist of more lonely piano (in
audio_shortlist.md) went to a listening page. He marked six Use: the Chopin nocturnes Op. 48 No. 1, Op. 72 No. 1 and
Op. posth. (C-sharp minor), the E minor prelude Op. 28 No. 4, Beethoven's Moonlight Sonata (first movement) and Kevin
MacLeod's Wounded. They join the `castle` mood, so the castle now shuffles seven piano pieces among its strings.
Skipped: Gymnopédie No. 1, Cryptic Sorrow, Loss and Quinn's Song: First Night.

Each piece has a `track_levels` line from its loudness over the whole recording against the Marche funèbre's (the
Marche plays at +4.4), capped so its peak stays under full scale. The listening page's clips were levelled on their
first two minutes, so a piece with a loud middle (the Op. 48 nocturne) plays quieter here than in its clip.
