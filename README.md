# Curse of Strahd

![The title screen: Castle Ravenloft under a full moon](docs/screenshots/title.jpg)

A single-player, turn-based tactical RPG that plays the whole *Curse of Strahd* campaign on the 2024 Dungeons &
Dragons rules. You lead a party of four through the valley of Barovia: walk its villages, roads and haunted houses in a
lit 3D world, talk your way through voiced conversations that roll real skill checks, and fight turn-based battles on
a 5-foot grid wherever trouble finds you. You control every member of the party, in and out of fights. The rules
engine follows the 2024 Player's Handbook closely, and every number on screen can show where it came from.

The whole campaign is playable, from the road where the mists close in to Castle Ravenloft: 86 places in 19 regions,
six voiced companions, a Tarokka reading that reshuffles each playthrough, and five endings. The [Features](#features)
below list what's in it, and [curseofstrahd.app](https://curseofstrahd.app) has the trailer, screenshots and an FAQ.

It's built in Godot 4 with typed GDScript.

> **An unofficial fan game.** Curse of Strahd (this game) is a free, non-commercial fan project made by one fan. It is
> not made, approved, endorsed or sponsored by Wizards of the Coast LLC or Hasbro, Inc., and it is not affiliated with
> them in any way. It is not for sale and never will be. *Dungeons & Dragons*, *D&D*, *Curse of Strahd* and
> *Ravenloft* are trademarks of Wizards of the Coast LLC, and the characters, places and story of *Curse of Strahd*
> are their property; they are named here only to say what the game is based on, with no claim of ownership. Rights
> holders with a concern can [open an issue](https://github.com/ashwinmahesh/CurseOfStrahd/issues).

## Download

The game is free for macOS (Apple silicon) and Windows 10 and 11 (64-bit), from
[curseofstrahd.app](https://curseofstrahd.app/#download). Each download is about 3 GB, and about 8.5 GB once unzipped.

- **macOS:** unzip it and open *Curse of Strahd*. It isn't notarized by Apple, so the first time macOS won't open it:
  go to System Settings → Privacy & Security and choose **Open Anyway**.
- **Windows:** unzip the whole folder and run `CurseOfStrahd.exe`. It isn't code-signed, so if SmartScreen appears,
  choose **More info → Run anyway**.

Every published version is tagged in this repo on the commit it was built from ([tags](https://github.com/ashwinmahesh/CurseOfStrahd/tags);
`v1.0.0` is the first). Problems and bug reports go in [Issues](https://github.com/ashwinmahesh/CurseOfStrahd/issues).

## Screenshots

| | |
|---|---|
| ![The Village of Barovia at night](docs/screenshots/explore_village_of_barovia.jpg) | ![Vallaki's square on a festival day](docs/screenshots/explore_vallaki.jpg) |
| The Village of Barovia at night, in the mist. | Vallaki's square on a festival day, its townsfolk about their routines. |
| ![Rain over Vallaki at dusk](docs/screenshots/explore_vallaki_rain.jpg) | ![Snow in Krezk](docs/screenshots/explore_krezk.jpg) |
| Rain over Vallaki at dusk: wet stone and lamplight. | Snow in Krezk, with footprints where the party has walked. |
| ![The Vistani camp at Tser Pool](docs/screenshots/explore_tser_pool.jpg) | ![A candlelit hall in the Death House](docs/screenshots/explore_death_house.jpg) |
| The Vistani camp at Tser Pool by firelight. | The Death House, its near walls cut away toward the camera. |
| ![The gates of Castle Ravenloft in a storm](docs/screenshots/castle_gates.jpg) | ![Choosing four of the six companions](docs/screenshots/new_game.jpg) |
| The gates of Castle Ravenloft in a storm. | A new game: four of the six companions travel, or make a hero of your own. |
| ![A Fireball in the village square](docs/screenshots/combat_fireball.jpg) | ![Aiming a Fireball, with a friendly fire warning](docs/screenshots/combat_spell.jpg) |
| A Fireball among the village's dead: fights start where you stand. | Area spells show who they'll catch, each target's chance to fail the save, and any ally in the blast. |
| ![Hit odds before the attack](docs/screenshots/combat_attack.jpg) | ![Strahd's name plate and health bar](docs/screenshots/combat_boss.jpg) |
| Hover a foe to see the odds, the damage and any Advantage before you swing. | Bosses get a name plate and a health bar over the hotbar. |
| ![A Performance check in Blinsky's toy shop](docs/screenshots/dialogue_check.jpg) | ![The d20 rolling for the check](docs/screenshots/dialogue_d20.jpg) |
| Conversations show who will roll each check and their chance. | Then the d20 rolls with the DC and every bonus. |
| ![Sneaking in the Blue Water Inn](docs/screenshots/stealth.jpg) | ![The character sheet](docs/screenshots/character_sheet.jpg) |
| Sneaking: the ground each person can see, before you step into it. | The character sheet. Hover any number to see how it was worked out. |
| ![The inventory's paper doll](docs/screenshots/inventory.jpg) | ![The travel map of Barovia](docs/screenshots/travel_map.jpg) |
| The inventory: a paper doll, weapon sets and quick slots. | The travel map: hours on the road, the arrival time, and a warning before travelling after dark. |
| ![Skirmish and the Character Lab](docs/screenshots/skirmish.jpg) | |
| Skirmish and the Character Lab: any party at any level against any stat blocks. | |

## Running from source

The project is made and tested on a Mac, and the make targets expect a Unix shell. You need:

- macOS on Apple Silicon.
- Godot 4.7.2 at `/Applications/Godot.app`. Elsewhere, point `GODOT` at the binary (`make run GODOT=/path/to/Godot`).
- Python 3 for the data checks in `make ci` (standard library only).
- Git LFS (`brew install git-lfs`). New art and voice clips are stored in Git LFS (`.gitattributes`); without it,
  they check out as small pointer files the game can't load.
- Blender 5.2, a `GEMINI_API_KEY` and an `ELEVENLABS_API_KEY` only if you rebuild art or voices. Playing needs none
  of them, since the art and the voice clips are in the repo.

After cloning, turn Git LFS on for the repo and fetch its files once:

```bash
git lfs install
```

```bash
git lfs pull
```

The raw generated art in `art/generated` isn't loaded by the game or the tests. A clone that only plays or tests can
skip downloading it, which saves LFS bandwidth (GitHub's free plan has 10 GiB a month):

```bash
git config lfs.fetchexclude "art/generated/**"
```

Start the game from the repo root:

```bash
make run
```

The first run imports every asset, which takes a while. After that `make run` only re-imports when files have
changed since the last import, so a merge that adds scripts or images doesn't stop the game at a parse error.

`make play` runs a stable copy of the game instead (`~/Documents/CurseOfStrahdGame-play`), which only moves forward
to a `main` that passed the full checks, so a half-finished merge can't stop a play session.

Before merging anything into `main`, run the local CI:

```bash
make ci
```

It runs `validate` (every data file against its schema, and every feature marked as built really read by the code), `lint` (the pure
`rules/` and `combat/` libraries compiled on their own) and `test` (the unit and integration suites in a headless
Godot). All three must pass with a clean log.

### Make targets

| Command | What it does |
|---|---|
| `make run` | Starts the game at the title screen. |
| `make play` | Updates the stable play copy to the newest `main` that passed `make ci`, then starts it. |
| `make check` | The quick check while working: lint, a compile of every script, and the tests and data checks that cover what changed. |
| `make arena` | Opens the combat test arena: four level 3 pregens against wolves and zombies. |
| `make ci` | `validate`, `lint` and `test` together. |
| `make test [ONLY=substr]` | Imports, then runs the test suites, or only the tests whose names contain `substr`. |
| `make validate` | Checks every data file against its schema, and that features marked as built are read by the code. |
| `make lint` | Compiles `rules/` and `combat/` standalone, so a stray autoload reference fails. |
| `make import` | Re-imports assets headlessly. Run it after adding a `class_name`. |
| `make capture SCENE=… NAME=…` | Opens a window for a few seconds and saves screenshots to `captures/`. Options: `LOCATION=<id>` starts the story there, `ENCOUNTER=<id>` starts a fight, `DIALOGUE=<file:node> [BEATS=n]` plays a conversation, `MAP=1` opens the travel map, `SHOP=<npc>` opens a shop, `LOAD=<slot>` starts from a save, `FOCUS=<node>` takes close-ups of one node as it walks. |
| `make release [OUT=…] [VERSION=…]` | The Windows and Mac downloads: the Windows export, the Mac app built around the same pack (`tools/release/mac_app.py`), both zipped. The app icon is made by `tools/release/make_icon.py` from the title art. Needs Godot's 4.7.2 export templates. The **Release builds** workflow (Actions tab, `.github/workflows/release.yml`) runs it on GitHub, publishes to downloads.curseofstrahd.app and tags the commit vX.Y.Z; with upload off it only builds. |
| `make golden-saves` | Adds the current save version's chapter saves to `tests/saves`, which every test run loads. |
| `make lane NAME=… BRANCH=…` | A worktree for parallel work whose files and import cache are clones of the main checkout's. |
| `make palette` | Rebuilds the colour palettes after editing their lists. |
| `make voice [SPEAKER="…"] [LIMIT=n] [DRY=1] [MAX_USD=n]` | Generates the missing spoken lines with the pinned ElevenLabs voices. |
| `make sprite TURNAROUND=<png> ID=<id>` | Turns a character turnaround sheet into an 8-direction walking sprite. |
| `make sprites [ONLY="id …"]` | Re-renders every walk sheet from its turnaround with its recorded settings. |
| `make anims [ONLY="id …"] [GENERATE=1]` | Builds walk and attack sheets; `GENERATE=1` first draws any missing keyframes. |
| `make portrait SRC=<png> ID=<id>` | Crops, sizes and palette-matches a portrait. |
| `make textures [GENERATE=1] [ONLY=…]` | Builds the environment texture sets. |
| `make prop SRC=<png> ID=<id> HEIGHT=<units>` | Cuts out a single billboard prop. |
| `make props [GENERATE=1] [ONLY=…]` | Builds the set dressing sheets: props, wall pieces and doors. |
| `make ui_art` | Builds the menu ornaments and menu icons. |
| `make icons` | Frames the spell and item icons from the game-icons.net silhouettes. |
| `make standin` | Renders a stand-in villager so the sprite pipeline runs without generated art. |
| `make wireframes` | Redraws the UI flow wireframes in `docs/ui/wireframes/`. |

### Releases

`make release` builds both downloads locally. The **Release builds** workflow (`.github/workflows/release.yml`) does
the same on GitHub: run it from the Actions tab with a version such as `1.0.1`. With **upload** on, it publishes the two
zips to downloads.curseofstrahd.app and tags the commit it built as `v1.0.1`; it stops before building if that tag is
already on another commit. With upload off it's a dry run that only builds. It needs the repository secrets
`COS_CLOUDFLARE_R2_API_TOKEN` and `COS_CLOUDFLARE_ACCOUNT_ID`. The first run imports every asset (about two hours);
later runs start from the cached import, which a scheduled job keeps warm.

Each publishing run also makes a Mac disk image (`.github/workflows/mac-dmg.yml`): open it and drag the game into
Applications. Five secrets make the Mac downloads signed and notarized: `APPLE_DEVELOPER_ID_P12` (the Developer ID
Application certificate as a base64 .p12) and `APPLE_DEVELOPER_ID_P12_PASSWORD` sign the app in the release job, and an
App Store Connect API key as `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID` and `APPLE_API_KEY_P8` lets the disk image job
have Apple notarize the disk image. (Apple's notary can't take the zip: the game's 8.5 GB pack needs Zip64, which it
doesn't read.) Without them the app is signed ad hoc and macOS asks the first time it opens.
`tools/release/mac_app.py` signs locally from `MAC_SIGN_P12` and `MAC_SIGN_P12_PASSWORD_FILE`.

Players update with one line from the site (`curseofstrahd.app/update.sh` on a Mac, `update.ps1` on Windows), which
reads `downloads.curseofstrahd.app/latest.json`. When a release changes nothing a pack can't carry since the last full
download (the Godot version, `project.godot`, files removed from the folders the game lists), the release workflow also
exports a cumulative patch against that download (`tools/release/patch.py`, Godot's `--export-patch`) and the
updaters fetch just that, into the game's user folder beside the saves; `core/patch_loader.gd`, the first autoload,
loads it at startup. `release.json` beside each release's downloads records which it is.

The Windows .exe ships unsigned, so SmartScreen may warn. With an Azure Artifact Signing account, the secrets
`AZURE_TENANT_ID`, `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET` (an app registration allowed to sign with the
certificate profile) and `ARTIFACT_SIGNING_ENDPOINT`, `ARTIFACT_SIGNING_ACCOUNT` and `ARTIFACT_SIGNING_PROFILE` (as
secrets or variables) make the workflow sign it with jsign after the build. SmartScreen can still warn until signed
releases build up a reputation.

The screenshots in this README were taken off screen from the game at 1920x1080 on the High preset, by capture scenes
kept with the showcase site ([curseofstrahd-site](https://github.com/ashwinmahesh/curseofstrahd-site), in
`tools/godot`) run through `tools/capture/capture.tscn` as `make capture` does, then shrunk to 1280 px JPEGs.

## Controls

Every key can be changed under Settings → Keys. In a fight, press **F1** (or Start on a controller) for the full list
of combat controls.

**Exploring**

| Input | Action |
|---|---|
| Left-click | Walk there, or walk up to a person or thing and use it |
| Right-click | Everything you can do with that person, thing or party member |
| WASD or arrows | Step the party leader |
| Q / E, mouse wheel | Turn the camera, zoom (zoom out past the farthest step to look to the horizon) |
| Tab, 1 to 4 | Next party leader, or pick one |
| C · I · J · P | Character sheet · Inventory · Journal · Party |
| M · R · H | Travel map · Rest · Wait |
| F · V · G | Search · Sneak · Split the party |
| T, then Space | Turn-based exploring on or off, then end the round |
| L (hold) | Show what each foe in sight can see |
| Alt (hold) | Show the names of everything you can use |
| F5 · F9 | Quicksave · Quickload |
| Esc | Close the open panel, or open the pause menu |

In a conversation, Tab picks which hero speaks for the party.

On a controller: the left stick walks, A uses the nearest thing, X searches, Y opens the journal, LB the sheet, RB the
inventory, Back the menu for whatever is beside you, and Start pauses.

**Fighting**

| Input | Action |
|---|---|
| Hover the floor, click | See the path and its cost, then move |
| Hover an enemy, click | See the odds, then attack with the best weapon in reach |
| 1 to 0, Z / X | Use a hotbar slot, change hotbar tab |
| [ and ] | Change the spell slot level |
| Enter · Esc · Space | Confirm · Cancel · End the turn |
| T · Tab · L | Next target · Inspect the next party member · Show or hide the log |
| Ctrl or Cmd + Z | Undo a move that nothing came of |
| WASD, Q / E, wheel | Pan, turn and zoom the camera |

On a controller, hold LB for a radial menu of actions. Reactions ask first unless you set a rule for them.

## Features

**The adventure**

- The whole campaign, from the misty road in through the Death House, the Village of Barovia and Vallaki, across the
  valley and up to Castle Ravenloft: 86 places in 19 regions, 61 quests and over 120 named people to meet.
- After the opening chapters the regions can be played in any order; each gives a level milestone, up to level 11.
- Madam Eva's Tarokka reading, drawn once per playthrough, moves the three treasures, the party's ally and the room of
  the final battle.
- Strahd watches from the start: eight visits across the campaign, and a hidden measure of his attention that brings
  his spies, his visits and the road's dangers closer.
- Five endings with epilogue slides; choices set in one region are read in another.

**Your party**

- Six voiced companions, each with their own art, accent, personal quest, camp talks and banter: Sir Godrick
  Pendlebrook (Goliath Paladin), Liriel Dawnsong (High Elf Cleric), Thistle (Human Ranger), Ratatoille (High Elf
  Wizard), Wren Featherfoot (Halfling Monk) and Kip Smudgewick (Tiefling Warlock).
- Up to four travel at once, swapped outside fights; benched companions keep their level.
- Companion approval with romances, and Heroic Inspiration for playing in character.
- One optional custom hero with a full appearance creator, portraits and a voice.
- You control every party member and every guest who joins you, such as Ireena and Ismark. The AI only runs enemies
  and bystanders.
- Step-by-step creation with recommendations, level up with every 2024 swap and recommended picks, a BG3-style
  character sheet, an inventory with a paper doll, weapon sets and quick slots, and a respec at Madam Eva.

**The 2024 rules**

- A rules engine that keeps to the 2024 Player's Handbook, with each rule's status tracked in
  [docs/rules/coverage.md](docs/rules/coverage.md) and every departure explained in
  [docs/rules/deviations.md](docs/rules/deviations.md).
- 12 classes and 69 subclasses, 14 species, 48 backgrounds, 147 feats and 443 spells, including the *Ravenloft: The
  Horrors Within* options (the Dhampir, Hexblood, Lupin and Reborn, and Dark Gifts) and the playable Faerûn and Arcana
  Unleashed entries. Every spell and ability does all its text says, secondary effects included.
- Every die goes through one roller, every number the UI shows carries its breakdown, and rules words open their
  definitions on hover and can be pinned.

**Barovia**

- A lit 3D world with storybook-style 2D characters that walk and attack in 8 directions (the HD-2D look): lamps that cast
  shadows, sprites that catch the light, rain and snow on surfaces, water, 3D trees, Blender-built towns and interiors
  that cut away toward the camera, and vistas past the map's edge.
- Doors, locks, traps and hidden things to search for; sneaking with sight cones, surprise on either side,
  turn-based exploring, splitting the party, stealing and a town watch.
- Townsfolk schedules, town hours and seeded weather that slows travel and obscures squares in fights.
- A travel map with road times, a clock and random encounters that get worse after dark.
- A journal of quests, a codex of found books, a bestiary, shops in every town with haggling, temple services
  including Raise Dead, inn rooms, and a party stash.

**Conversations**

- Branching dialogue with large busts, a BG3-style Narrator, and skill checks that show who will roll and their chance
  before you choose, then roll a big animated d20. Failed social checks can't be retried.
- Voiced lines for the Narrator, the cast and the party, generated with ElevenLabs (Barovians, the Vistani and Strahd
  in Eastern European accents).
- 123 storybook cutscene stills, loading screens with each region's art, and a "Previously in Barovia" recap on load.

**Combat**

- Turn-based fights on a 5-foot grid that start where you are, with Initiative, a turn order strip, and surprise on
  either side.
- Hit odds with Advantage and its reasons before you attack, area templates that warn about friendly fire, and a
  combat log where any line shows its math. A hotbar you can arrange per hero.
- Weapon Mastery, Heroic Inspiration, Concentration, opportunity attacks, real lines of cover, death saves, mounted
  combat, summons, lingering zones, legendary and lair actions. Reactions and roll-changing features ask first.
- Height and flight, objects that break and burn, spreading fire, shoving and thrown items; knocking foes out,
  surrender and captives.
- Enemy AI that scores every move by expected damage, with nine behaviour profiles and Strahd's own boss brain.
- 3D effects for every spell and ability, combat sounds, enemy voices, impact on heavy hits and critical hits, boss
  name plates and health bars, music that rises with the fight.
- 125 monsters and over 540 magic items, every one from the 2024 Dungeon Master's Guide.
- Undo a move, and a save at the start of every round.

**Modes, saves and settings**

- Story, Balanced, Tactician and Honour difficulties (Honour keeps one save; a wipe ends the run).
- Skirmish and the Character Lab (any party at levels 1 to 20 against any stat blocks on any map), an encounter
  editor, 21 achievements and run stats.
- Five autosaves, save pictures and notes, backups, quicksave, and jump-in saves for 13 chapters.
- Settings for difficulty, graphics presets, keys, text size and UI scale, fight speed, narration, depth blur, the
  Modern or Classic look, and the respec.
- Cheat codes (pause menu → Cheat codes) that give any item to a hero; every code is in
  [docs/cheat_codes.md](docs/cheat_codes.md).

## Project layout

| Folder | What's in it |
|---|---|
| `rules/` | The rules engine: a pure library with no nodes, scenes or UI. |
| `combat/` | Grid, encounters, spells, features, AI and the action catalog, also pure logic. |
| `story/` | Story state, dialogue runner, quests, travel, weather, schedules, the Tarokka and treasure. |
| `world/`, `ui/`, `scenes/` | What you see: the board, the look, the HUDs and screens (Skirmish in `ui/skirmish/`), and the thin scene roots. |
| `shaders/` | The world, sprite, water, atmosphere and screen shaders. |
| `core/` | Autoloads: dice, game state, settings, saving, input, audio, voice and achievements. |
| `data/` | Classes, spells, monsters, items, locations, NPCs, quests, cutscenes and more, as JSON with schemas. |
| `narrative/` | The conversations, one `.dialogue` file per scene. |
| `art/`, `audio/`, `blender/` | Art, voices and the pipelines that build them. |
| `tests/` | Unit and integration tests, and the golden saves in `tests/saves/`. |
| `tools/` | Data checks, captures, the play copy, lanes, and the art and audio scripts. |
| `docs/` | Decisions in `adr/`, interface contracts in `contracts/`, rules coverage, region notes, UI and art guides. |

## Credits

The full list, with links and licence files, is in [docs/assets/LICENSES.md](docs/assets/LICENSES.md), and the game
shows it under Credits on the title screen (from `art/credits.json`).

**Rules.** This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast
LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0
International License, available at https://creativecommons.org/licenses/by/4.0/legalcode. Content beyond the SRD
(the *Curse of Strahd* adventure and options from other books) belongs to Wizards of the Coast; this free fan game
uses it without their endorsement (see the notice at the top), and the data files hold mechanics and our own
descriptions, not the books' text.

**Icons.** Spell, item and cursor icons by Lorc, Delapouite, Skoll, Sbed, Caro Asercion, Willdabeast, Cathelineau,
DarkZaitzev, Carl Olsen, Zajkonur and Faithtoken from [game-icons.net](https://game-icons.net/), under
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), and by Zeromancer (CC0). They were framed and coloured for
this game.

**Music.**

- Kevin MacLeod ([incompetech.com](https://incompetech.com/)): "Ossuary 6 - Air", "Oppressive Gloom", "Folk Round",
  "Duet Musette", "Darkling", "Darkest Child", "Unholy Knight", "Lightless Dawn", "Night Vigil", "Gypsy Shoegazer",
  "Minstrel Guild", "Clash Defiant", "Nightmare Machine", "Final Count", "Danse Macabre", "Achaidh Cheide", "Agnus
  Dei X", "Ancient Rite", "Baba Yaga", "Black Vortex", "Bump in the Night", "Celtic Impulse", "Children's Theme",
  "Come Play with Me", "Dama-May", "Dark Walk", "Death and Axes", "Echoes of Time", "Gloom Horizon", "Gregorian
  Chant", "Grim Idol", "Ice Demon", "Inner Sanctum", "Land of the Dead", "Long Road Ahead", "Lord of the Land", "Lost
  Frontier", "Malicious", "Midnight Tale", "Mirage", "Moorland", "Mystery Bazaar", "Ossuary 2 - Turn", "Pippin the
  Hunchback", "Relent", "Rites", "Shadowlands 1 - Horizon", "Teller of the Tales", "Tenebrous Brothers Carnival -
  Snake Lady", "Thatched Villagers", "The Britons", "Virtutes Instrumenti", "Volatile Reaction" and "Willow and the
  Light", under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- Scott Buckley ([scottbuckley.com.au](https://www.scottbuckley.com.au/)): "Memories Of Stone", "Anabasis I", "Eyes
  In The Void", "Nightfall", "Penumbra" and "Unraveling", under CC BY 4.0.
- Toccata and Fugue in D minor, BWV 565 (J. S. Bach), played by Norbert Schenk. CC BY 4.0, via Wikimedia Commons.
- Csárdás (Vittorio Monti), played by the United States Air Force Band. Public domain, via Wikimedia Commons.
- Fugue in G minor, BWV 542 (J. S. Bach), played by Herbert Collum on the Silbermann organ at Reinhardtsgrimma. CC BY
  1.0, via Wikimedia Commons.
- Marche funèbre (Chopin) and Night on Bald Mountain (Mussorgsky), recordings from Musopen. CC0 and public domain,
  via Wikimedia Commons.
- "Dark Gothic Haunted Masquerade", "Dark Solemn Choral with Organ" and "Final Boss Appearance Dark Fantasy" by ISAo
  (airyluvs.com). OGA-BY 3.0, via OpenGameArt.org.
- "In Darkness" by Of Far Different Nature (fardifferent.carrd.co). CC BY 4.0, via OpenGameArt.org.
- "Fanfares" (victory and defeat) by Spring Spring. CC BY 4.0, via OpenGameArt.org.

**Sound effects.**

- Kenney (kenney.nl): RPG Audio, Impact Sounds and Interface Sounds. CC0.
- Fantasy SFX Pack Vol 1 by JC Sounds. CC BY 4.0 - Credit: JC Sounds, via OpenGameArt.org.
- Additional Sound FX by Will Leamon (Fleshy Fight Sounds). OGA-BY 3.0, via OpenGameArt.org.
- Boom Pack 1 by dklon. CC BY 3.0, via OpenGameArt.org.
- OpenGameArt.org, CC0: 80 CC0 RPG SFX and 100 CC0 SFX #2 by rubberduck; sword sounds by StarNinjas; swishes by
  artisticdude; Magic Spell SFX by JaggedStone; fire-1 by AntumDeluge; crow caw by zeroisnotnull; Deep Bone
  Crack/Break by Zane Little Music; Impact by qubodup; squish sounds by EZduzziteh; Break Pumpkin by TinyWorlds.
- Wikimedia Commons: Howling wind by Tvabutzku1234 (CC0); Wolf howls by the US Fish and Wildlife Service and Rain and
  thunder by ezwa (public domain).
- "Footsteps on different surfaces" by congusbongus. CC BY 3.0, via OpenGameArt.org.
- "Stream Sounds" by kurt. CC BY 3.0, via OpenGameArt.org.
- "Open Chest" by spookymodem. CC BY 3.0, via OpenGameArt.org.
- OpenGameArt.org, CC0 (world sounds): Different steps on wood, stone, leaves, gravel and mud by TinyWorlds;
  Mechanical Sounds by BMacZero.

**Art and voices.** Characters, portraits, busts, cutscene stills, textures, props, menu art and the title art were
made for this game with Google Gemini and finished in Blender. The spoken lines and the enemies' battle voices were
generated with ElevenLabs. The menus use fonts that ship with macOS.
