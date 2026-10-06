# Region design: Van Richten's Tower, the Werewolf Den and Lake Zarovich (Phase 5, region 9a)

Plan §6 row 9, first half (task P5-09). Party level 7 or 8 on arrival, one level higher at the climax (one
`xp milestone`, when the pack question in the werewolf den is settled). Source: *Curse of Strahd*, the chapters on Van
Richten's Tower and the Werewolf Den, and Lake Zarovich, retold in our own words; every line, summary and description
here and in the data is ours. Implementation reads this doc; the data and dialogue files in §16 are the source of truth
for exact text.

Three places, one package. Location `region` fields: `lake_zarovich`, `van_richtens_tower`, `werewolf_den`. One flag
registry (data/flags/van_richtens_tower.json), one travel file (data/travel/van_richtens_tower.json).

## 1. What this region is for

The hills north and west of Vallaki, where the valley's two great hunters are not speaking to each other, and the
castle's wolves are building an army out of children.

- **The werewolf den** is the climax. Kiril Stoyanovich came home from the castle with a new law: grow the pack for the
  master, out of children stolen from the farms below Krezk. The old leader, Emil Toranescu, said no, and hangs in
  silver chains for it. His mate Zuleika wants him free and Kiril dead. The party decides **who leads the pack**:
  Emil (Kiril dies), Kiril (Emil dies), or nobody (both die), and whether **the five children** go home. End state:
  **`wolf_pack_leader`** (`emil`, `kiril`, `none`) and `den_children_freed` / `den_children_left`.
- **Van Richten's Tower** stands on an island in Lake Baratok, a cold tarn under Mount Baratok. A dead archmage
  built it; its door still opens to his name, Khazan. Rudolph van Richten keeps it now, and has keyed a second ward to
  exactly one person: his student Ezmerelda d'Avenir, who is camped on the shore, furious. Inside are his notes, his
  letter to her, the ledger that says plainly that Vallaki's Rictavio is Van Richten, and a lightning ward. The party
  decides **what to tell Ezmerelda** (`ezmerelda_told_rictavio`, `ezmerelda_secret_kept`, `van_richten_reunited`),
  which sets her trust (`ezmerelda_trust`).
- **Lake Zarovich** is the fishers' landing: the payoff for Vallaki's missing Arabelle (Bluto's fate, `bluto_fate`),
  the boat that shortens the roads to the den and the tower, and the **Tarokka ally scene for Arabelle**.

Tone: hill-country gothic. The wolves are funny only through Kiril's host's manners and Zuleika's farmhouse
briskness; the children are written straight. Ezmerelda and Van Richten are the region's warmth: two stubborn people
who love each other and would rather be shot than say so.

## 2. Who is here, what they want, how they talk

| id | Name | Where | Wants | Fears | Voice in a line | Stat block |
|---|---|---|---|---|---|---|
| `kiril_stoyanovich` (new) | Kiril Stoyanovich | out on the Krezk road; answers Emil's challenge in the den passage; rules the great cave if the party lets him | a pack nobody can tell no, an army for the master | being made a dog (he is one) | jovial, brutal, food words for people: "Meat with swords." | `kiril_stoyanovich` |
| `emil_toranescu` (new) | Emil Toranescu | chained in the west alcove; then a guest; then leading the pack | his pack back, the children home, off the castle's leash | the wolf winning | slow, plain pack law, dry about pain: "The jewellery chafes." | `emil_toranescu` (guest) |
| `zuleika_toranescu` (new) | Zuleika Toranescu | the cave mouth (first visit), the shrine, the great cave after | Emil free, Kiril dead, the den hers again | choosing between husband and pack | low, quick, practical; herbalist's images | `werewolf` |
| `mirela` (new) | Mirela | the children's pen; leads the children out | home; the little ones safe | the first moon, eleven days off | fierce, blunt, counts everything | `commoner` |
| `ezmerelda` (abbey writer's NPC) | Ezmerelda d'Avenir | her camp on the shore of Lake Baratok (when the Tarokka did not name her) | into the tower; a word with Rudolph | being too late again | quick, sardonic, hunter's rules as jokes | `ezmerelda_davenir` |
| `rictavio` (Vallaki's NPC) | Rudolph van Richten | his workroom, only if he left Vallaki (`rictavio_gone`); the fire on the shore after the reunion | to keep his last student alive by keeping her out | another protégé dying in his place | unmasked: low, clipped, precise | `rictavio` |
| `bluto` (Vallaki's NPC) | Bluto Krogarov | the jetty end (Arabelle saved) or his drying racks (Arabelle lost) | for the lake to stop talking to him | the voice in the dark | desperate, pleading | `commoner` |
| `arabelle` (Vallaki's NPC) | Arabelle | drifting off the jetty end in a loose boat (Tarokka ally) | to go with the party; the cards said | nothing much; she has seen most of it | solemn prophecy as small talk | `commoner` (guest) |

Voice bibles: docs/voice/{kiril_stoyanovich, emil_toranescu, zuleika_toranescu, mirela}.md (new); the others are
existing (ezmerelda.md, rictavio.md, bluto.md, arabelle.md).

## 3. Layout and scenes

Six maps (data/locations/). Map themes are existing ones; §13 lists the themes and art this region wants.

| Map | Size, theme | Areas (enter: triggers) | What happens |
|---|---|---|---|
| `lake_zarovich` | 36 x 24, riverside, outdoors | `lz_jetty`, `lz_shore`, `lz_landing`, `lz_bluto_hut`, `lz_old_huts`, `lz_path` | The fishers' landing on the south-west shore: the lake (deep water `w`), a jetty, empty huts with a farewell notice, Bluto's shack, his rowboat (prop `lz_boat`). Bluto's fate, the boat, Arabelle's ally scene. Exit `lz_road` → travel. |
| `lake_zarovich_trail` | 32 x 20, wilderness, outdoors | `lzt_trail` | Battlefield for the region's random fights (tables `zarovich_hills`, `zarovich_shore`). |
| `van_richtens_tower` | 32 x 30, village, outdoors | `vrt_island`, `vrt_causeway`, `vrt_camp`, `vrt_shore` | Lake Baratok: the island and its tower (a 6 x 6 block), a two-wide causeway, Ezmerelda's camp (her wagon is a locked container with a tripwire), her note on the wagon. The door (prop `vrt_door_ward`) opens the exits `vrt_tower_door` when `tower_door_opened`. At night after the casebook is read, the castle's servants wait at the causeway's shore end. |
| `van_richtens_tower_interior` | 14 x 35, manor | `vrt_hall`, `vrt_workroom`, `vrt_lantern_room` | Three round floors stacked in one map (stair exits to the same location). Hall: supplies, the hearth with the ward's copper rod. Workroom: casebook, ledger of disguises, map of the valley (`den_way_known`), medicine cabinet; Van Richten himself if he left Vallaki. Lantern room: the lightning ward across the floor (trap), the strongbox (Tarokka spot), the letter to Ezmerelda. Safe rest. |
| `werewolf_den` | 34 x 26, wilderness, outdoors | `den_trail`, `den_stream`, `den_slope`, `den_watch_rock` | The slope under the cave mouth: Zuleika at her wolfsbane patch (approach), Ana's rag doll in the mud, a torn hunter's pack (Grigor's brother), the bone midden. Exits: `den_trail_out` → travel; `den_cave_mouth` → the caves. |
| `werewolf_den_caves` | 40 x 30, dungeon, dark | `den_mouth_cave`, `den_passage`, `den_great_cave`, `den_emil_alcove`, `den_children_pen`, `den_kiril_lair`, `den_shrine`, `den_zuleika_nook` | The mouth cave (guards if the party came uninvited), the great cave round its fire pit (the challenge), Emil's alcove, the pen behind a pole gate, Kiril's lair (hoard, trophies, the second key on a peg), the shrine of Mother Night (offerings: Tarokka spot), Zuleika's nook. No rest. |

### Scene flow (every step optional; the critical path is §14)

1. **Hearing of it.** Grigor's hunters (`werewolf_rumor`), the hill-trail events (`den_way_known`, `tower_rumor`),
   Bluto saved (both), Ezmerelda (the den), Van Richten's map (the den), the Tarokka (either place) put the den and the
   tower on the travel map. The landing is on the map once Vallaki has been visited.
2. **The landing.** Bluto's scene if Vallaki's Arabelle thread is resolved; the boat (`lake_boat_ready`) opens the
   boat roads; Arabelle's ally scene once Bluto's business is settled (§4.3).
3. **The tower.** Ezmerelda on the shore; the name on the door; the floors; what to tell her (§4.2).
4. **The den.** Zuleika at the mouth; Emil's chains; the challenge; the aftermath and the milestone (§4.1).

## 4. The big threads

### 4.1 The pack in the hills (the climax)

- **Zuleika** meets the party at the cave mouth (`werewolf_den/zuleika:start`, approach). She tells them who she is,
  what Kiril is doing (`What do you want from strangers?` sets `zuleika_asked`, quest `wolves_in_the_hills asked`),
  and about the children (`zuleika_children_told`). **"We'll free Emil."** sets `zuleika_vouched`, gives the key
  (`emil_key_found`) and walks them in past the wolves: no `den_guards` fight. **"We won't do your killing for you."**
  sends them away; going in anyway starts `den_guards` (afterwards Zuleika, at the shrine, asks again and gives the key).
- **Emil** (`werewolf_den/emil:start`) hangs in silver chains in the west alcove. Free him with the key (Zuleika's or
  the peg in Kiril's lair), or by Athletics 15 or Sleight of Hand 14 (one try each). If Izek's story is known or
  Ireena is a guest, he remembers the night by the lake twenty years ago: the castle's wolves, a boy's arm, a red-haired
  girl, a rider at the treeline. Freed, he **joins as a guest** (`emil_freed`, `join emil_toranescu`) and must howl
  his challenge by pack law. Kiril comes home to answer it.
- **Kiril** (`werewolf_den/kiril:challenge`, approach, in the passage). THE CHOICE:
  - **"We stand with Emil."** → `pack_challenge` (Kiril and his loyalists; Emil fights on the party's side). Victory:
    Zuleika's aftermath (`aftermath:emil_wins`): `wolf_pack_leader = "emil"`, the children go home with Zuleika at
    first light, she treats Mirela's bite (`mirela_cured`), the milestone. If the Tarokka named Emil (the Beast) he stays
    (`find_the_ally found`); otherwise he stays with his pack (`leave emil_toranescu`) and Zuleika gives two potions.
  - **"This is pack business. Settle it between the two of you."** → the duel by pack law; Emil, weak from a month in
    silver, dies (`emil_dead`). **"Take him back, Kiril."** → the same, plus `emil_betrayed`. Then Kiril's terms:
    the children stay unless the party wins them (Persuasion 15, Intimidation 15, or a purse of 100 gp:
    `kiril_bribed`), or takes them (**"Then we'll take them."** → `pack_challenge` without Emil), or leaves them
    (`den_children_left`). `wolf_pack_leader = "kiril"`; the milestone. Coming back for the children later (Kiril's
    `after`, or Mirela's "We're taking you out of here. Now.") breaks the truce (`truce_broken`, `pack_challenge`).
  - **"Neither of you leads anything. This den ends tonight."** → `den_reckoning` (Kiril, Emil, Zuleika and the
    loyalists all against the party). Victory: Mirela's aftermath (`aftermath:no_emil`): `wolf_pack_leader = "none"`.
- Kiril dead without Emil (the reckoning, or the truce broken) also ends in Mirela's aftermath: the children walk home,
  `wolf_pack_leader = "none"`, the milestone. Mirela's bite can be seen (Medicine 13) and prayed away (a cleric).
- **The shrine of Mother Night** (`werewolf_den/shrine:statue`): the Barovian almanacs' goddess of the dark half of
  the year (Religion 13), a cleric's prayer to the Morninglord in her house, and the Tarokka spot.

### 4.2 The hunter's tower

- **Ezmerelda** (`van_richtens_tower/ezmerelda:start`, approach) is here when the Tarokka did not name her (the abbey
  has her when it did). She tells them about the tower: the old lock opens to the archmage's name, KHAZAN (she sets
  `khazan_known`); Rudolph's newer ward is keyed to her alone and threw her into the lake. She asks them to go in for
  her (`the_hunters_tower asked`). If a Tarokka treasure is up there she mentions "the thing the cards keep moving".
- **The door** (`van_richtens_tower/tower:door`): say the name (from Ezmerelda, her note on the wagon, or History 14 on
  the lintel); Arcana 14 reads the two wards. With Van Richten as a guest he opens it and lowers the upstairs ward.
- **Inside:** the casebook (`van_richten_notes_read`: Strahd's weaknesses in Van Richten's words, the wolves, the hearth
  rod), the ledger of disguises (`van_richten_identity_known`: Rictavio is Van Richten), the map (`den_way_known`),
  the letter to Ezmerelda (`van_richten_letter_found`). The lightning ward spans the lantern-room floor (trap: detect
  15, disarm 16, DEX 15, 4d10 lightning) unless the hearth's copper rod is pulled (`tower_ward_lowered`; the casebook
  says how, or Arcana 13 / Investigation 14). The strongbox is the Tarokka spot.
- **Van Richten at home:** if he left Vallaki (`rictavio_gone`), he sits in the workroom, ignoring his student on the
  doorstep. "She's going to get in eventually..." (or Persuasion 14) sends him down to her: `van_richten_reunited`.
  If the Tarokka names him and he refused in Vallaki, he can be won back here (freeing the children is enough; else
  Persuasion 15).
- **What to tell Ezmerelda:** that he is Rictavio in Vallaki (`ezmerelda_told_rictavio`; she leaves for Vallaki that
  night, `ezmerelda_left_tower`, unless he has already gone home to the tower, in which case she realises he's inside);
  keep his secret (`ezmerelda_secret_kept`); or lie (Deception 15, `ezmerelda_lied`). Give her the letter. Bring him
  to her (as a guest: the reunion plays at her fire).
- **Trust** (`ezmerelda_trust`): +1 letter, +1 the truth, +2 reunion, +1 Kiril dead (he took her leg; his trophy
  wall has her boot), +1 the children home; -1 a failed lie, -1 Kiril on top, -2 her wagon robbed. At 2 she gives
  holy water, a potion and silver-headed bolts, and **"Hunt with us."** lets her join as a guest even when she isn't the
  ally (the abbey's scene does the same).
- **At night**, once the casebook has been read, two vampire spawn and bat swarms (and a wight at level 8) wait at the
  shore end of the causeway: the castle has heard what the party was reading (`tower_night_visitors`).

### 4.3 Lake Zarovich

- **Bluto** (Vallaki's rescue scene sets `arabelle_rescued` or `arabelle_lost`; before that he isn't here).
  - Arabelle saved: he is on the jetty end with stones in his pockets, as she said he would be
    (`landing:bluto_pier`). Persuasion 14, Athletics 12, or the plain **"We need your boat, and a man who knows this
    water. Row for us."** saves him (`bluto_fate = "saved"`: the boat, and he tells of the den trail and the tower:
    `den_way_known`, `tower_rumor`). A failed check lets him step off; Athletics 13 to dive for him, else `drowned`.
    "Let him go." → `drowned`.
  - Arabelle lost: his nets are full at last (`landing:bluto_nets`): take him to Luvash (`vistani`), kill him
    (`killed`), or leave him to live with it (`left`).
- **The boat** (`landing:boat`): Bluto's leave, his fate, or simply borrowed (`lake_boat_ready`). It opens the boat
  roads: to the den (2 h) and to Lake Baratok (3 h).
- **Arabelle, the Tempter ally** (`lake_zarovich/arabelle_ally:start`): once Bluto's business is settled, if the
  Tarokka names her, she was rescued and she isn't with the party, she is drifting off the jetty end in a boat that has
  slipped its rope. Haul her in (Athletics 12, or throw a line); **"We promise. Come with us."** → `join arabelle`,
  `find_the_ally found`. "Go home to your father." → `arabelle_sent_home` (Luvash's own scene in Vallaki still offers
  her). Before her rescue, a ribbon on the jetty post marks where she'll be (`arabelle_ribbon_found`).

## 5. The three pack outcomes

| | Emil | Kiril | None |
|---|---|---|---|
| Choice | "We stand with Emil." | "This is pack business..." / "Take him back, Kiril..." | "Neither of you leads anything..." (or the truce broken) |
| Fight | `pack_challenge`, Emil beside the party | none (or `pack_challenge` to take the children) | `den_reckoning` (or `pack_challenge`) |
| Emil | leads the pack; the ally if the Beast | dead (`emil_dead`) | dead |
| Kiril | dead (`kiril_defeated`) | leads, for the castle | dead |
| Zuleika | the den-mother; potions | keens and is gone | dead in the reckoning, fled otherwise |
| Children | home, Mirela cured | home if won or bought, else left (`den_children_left`) | home |
| The hills after | Emil's wolves dip their heads (event); no werewolf random fights | `pack_hunt` by night, Kiril's `after` scene | no pack; dire wolves and the dead only |
| Ezmerelda | +1, +1 children | -1 | +1, +1 children |
| `wolf_pack_leader` | `"emil"` | `"kiril"` | `"none"` |

No skill check gates a path: each outcome is reached with plain options.

## 6. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| Who leads the pack | den passage | Emil, Kiril, nobody | the fight or none; `wolf_pack_leader` | random tables, Ezmerelda's trust, Krezk, the castle (Emil's teeth at the gates), epilogue |
| The children | Kiril's terms, the pen | free (fight, Persuasion, Intimidation, 100 gp) or leave | `den_children_freed` / `den_children_left` | Krezk's farms, the epilogue; the moon in eleven days |
| Mirela's bite | the pen, the aftermath | Zuleika's wolfsbane, a cleric's prayer, or nobody notices | `mirela_cured`, `mirela_bite_seen` | a wolf in Krezk at the next moon if untreated (Krezk/epilogue) |
| Zuleika's offer | cave mouth | vouch or refuse | `zuleika_vouched` or `den_guards` | how many loyalists answer the challenge |
| What to tell Ezmerelda | her fire | the truth, the secret, a lie, the letter, the reunion | trust, `ezmerelda_left_tower` | her joining (trust 2), Vallaki/castle scenes, epilogue |
| Van Richten at home | workroom | talk him down to her | `van_richten_reunited` | the two of them at the fire; ally retry |
| Her wagon | her camp | rob it or not | -2 trust | her coldness |
| Bluto | the jetty / the racks | save, let drown, hand over, kill, leave | `bluto_fate`, the boat | landing mood, banter, epilogue |
| Arabelle | jetty end | take her or send her home | `join arabelle` / `arabelle_sent_home` | the Tempter ally |

## 7. Encounters (2024 DMG budgets for four characters)

Level 7: Low 3000 / Moderate 5200 / High 6800. Level 8: Low 4000 / Moderate 6800 / High 8400. Level 6: Low 2400 /
Moderate 4000. XP: werewolf 700, Kiril 1100, Emil 700, dire wolf 200, vampire spawn 1800, wight 700, bat swarm 50.
Each fight has `level >= 8`, `level >= 7` and fallback variants (same id, first matching `when`).

| id | Map | Trigger | L8 | L7 | Fallback |
|---|---|---|---|---|---|
| `den_guards` | caves | enter `den_mouth_cave`, not vouched | 5 werewolves + 2 dire wolves (3900, Low) | 4 + 2 (3200, Low) | 3 + 1 (2300) |
| `pack_challenge` | caves | dialogue (Kiril, Mirela) | Kiril + 4 werewolves + 2 dire wolves (4300, Low); guards cleared: Kiril + 3 + 2 (3600) | Kiril + 3 + 2 (3600, Low); cleared: Kiril + 2 + 2 (2900) | Kiril + 2 + 1 (2700) |
| `den_reckoning` | caves | dialogue (Kiril) | Kiril, Emil (45 HP), Zuleika (werewolf, 60 HP), 3 werewolves, 2 dire wolves (5000, Low) | 2 werewolves (4300, Low) | 1 werewolf, 1 dire wolf (3400) |
| `tower_night_visitors` | tower | enter `vrt_causeway` at night after the casebook | 2 vampire spawn, a wight, 2 bat swarms (4400, Low) | 2 spawn, 2 swarms (3700, Low) | 1 spawn, 2 swarms (1900) |

The critical-path fight is `pack_challenge` with Emil (a CR 3 werewolf) on the party's side: Low for four, lower still
with the guest. Werewolves have Pack Tactics and a cursing bite (lycanthropy, DC 12 Con); the party has had the chance
to rest at the tower (safe) or on the hill (risky).

**Random tables.** `zarovich_hills` (map `lake_zarovich_trail`; day 0.2, night 0.45): Kiril's `pack_hunt` at night
(3 werewolves, 3 wolves, 2250) unless the pack is Emil's or gone; `dire_wolves` by day (a werewolf and 5 dire wolves,
1700) unless Emil's; `hill_ghouls` at night (4 ghouls, 2 ghasts, 1700); events (once each): `howl_call` (Survival 13 →
`den_way_known`), `krezk_cart` (Survival 12 → `den_way_known`), `ridge_watcher` (→ `den_way_known`), `silver_snare`
(Ezmerelda's snare → `tower_rumor`), `emil_wolves` (Emil's pack nods). `zarovich_shore` (same map; day 0.1, night
0.35): `the_drowned` at night (4 Strahd zombies as drowned fishers, 2 ghasts, 1700), `marsh_lights` (3 will-o'-wisps,
1350, once), `shore_wolves` by day (4 dire wolves, 800), events `drowned_bell`, `shore_howl`.

## 8. Milestone

One `xp milestone` (level 7 → 8, or 8 → 9), guarded by `wolf_den_milestone_reached`, when the pack question is
settled: `aftermath:emil_wins`, `aftermath:no_emil` (in `home`), or `kiril:kiril_resolve`. The tower and the lake give
none.

## 9. Reading earlier regions

| Flag (owner) | Read by |
|---|---|
| `werewolf_rumor`, `hunters_befriended`, `falls_werewolf_slain` (Svalich Road) | the den's travel place, Zuleika, the hunter's pack |
| `arabelle_rescued`, `arabelle_lost` (Vallaki) | Bluto at the landing, the boat, Arabelle's ally scene |
| `rictavio_unmasked`, `rictavio_secret_kept`, `rictavio_gone`, `vallaki_backed` (Vallaki) | Ezmerelda, Van Richten at home, the tower |
| `izek_story_heard` (Vallaki) | Emil (the night by the lake) |
| `ezmerelda_met` (Krezk/abbey) | set here too when she is met at the tower |
| `guest:ireena`, `guest:ezmerelda`, `guest:rictavio`, `guest:arabelle`, `tarokka.ally.npc` | throughout |

## 10. Flags (data/flags/van_richtens_tower.json) and what later regions read

All 64 flags are registered, set and read. For later regions:

- **`wolf_pack_leader`** (`emil` / `kiril` / `none`): Krezk (raids on the farms stop or don't), Castle Ravenloft
  (Emil said "send word up the hill" if you need teeth at the gates; Kiril's pack answers the castle), the epilogue.
- **`den_children_freed`**, **`den_children_left`**, **`mirela_cured`**, `mirela_bite_seen`: Krezk (five children
  from the farms below Krezk: Mirela, Ana, Petru, Ilie and Ioana; untreated, Mirela turns at the next moon), epilogue.
- `emil_dead`, `emil_betrayed`, `kiril_defeated`, `den_broken`, `kiril_bribed`: epilogue, Strahd's remarks.
- **`ezmerelda_trust`** (int), `ezmerelda_told_rictavio`, `ezmerelda_left_tower`, `ezmerelda_secret_kept`,
  **`van_richten_reunited`**: the abbey's Ezmerelda, Vallaki (if she arrives looking for Rictavio), the castle, the
  epilogue.
- `bluto_fate`: Vallaki's Vistani camp and the epilogue.
- Quests: `wolves_in_the_hills`, `the_stolen_children`, `the_hunters_tower`; `find_the_ally found`/`lost`.

## 11. The Tarokka

| Place (cards) | Location | Spot | Notes |
|---|---|---|---|
| `werewolf_den_shrine` (Swords 5: tome, symbol, sword) | `werewolf_den_caves` | container `mother_night_offerings` | Among the offerings at Mother Night's feet. Zuleika mentions "a thing left at her feet" (`treasure_at:`); the shrine and the open line say so too. |
| `van_richtens_tower` (Stars master: tome, symbol, sword) | `van_richtens_tower_interior` | container `van_richten_strongbox` (lantern room) | Behind the lightning ward. Ezmerelda mentions "the thing the cards keep moving" (`treasure_at:`). |

**Allies.** The Beast → `emil_toranescu` (data/npcs/emil_toranescu.json, `guest: true`, `guest_build.monster =
emil_toranescu`): `werewolf_den/emil:start` reaches `join emil_toranescu` when he is freed (any card; he fights the
challenge beside the party); `aftermath:emil_wins` keeps him with `find_the_ally found` when `tarokka.ally.npc ==
emil_toranescu`, and lets him go otherwise. If he dies, `find_the_ally lost`. The Tempter → `arabelle`
(`lake_zarovich/arabelle_ally:start`, §4.3; Vallaki's Luvash scene also reaches `join arabelle`).

Test setup for the Phase 5 exit (SETUP): `emil_toranescu`: `{"emil_key_found": true}`; `arabelle`:
`{"arabelle_rescued": true, "bluto_fate": "saved"}`. The two treasure spots are plain containers (no setup).

## 12. Loot

| Container | Where | Contents |
|---|---|---|
| `lz_bluto_chest` (lock 10) | landing | 2 gp, a net, a flask of oil |
| `lz_hut_locker` | empty hut | 6 gp, hooded lantern, 2 oil, rope |
| search `lz_reed_satchel` (DC 13) | reeds | a dagger |
| `ezmerelda_wagon` (lock 16, tripwire 3d10 fire) | her camp | 30 gp, 2 holy water, alchemist's fire, 20 bolts, a potion (theft costs her trust) |
| `vrt_supply_crate` | tower hall | 2 holy water, 3 torches, 2 oil, 4 rations |
| `vrt_workroom_cabinet` | workroom | healer's kit, 2 potions of healing, antitoxin |
| `van_richten_strongbox` | lantern room | 120 gp, 3 holy water, 2 potions, a level 1 spell scroll; Tarokka spot |
| `den_hunter_pack` | hillside | 8 gp, longbow, 20 arrows, 2 rations |
| `mother_night_offerings` | shrine | 35 gp, 3 candles; Tarokka spot |
| `kiril_hoard` (lock 15) | Kiril's lair | 140 gp, 2 potions, perfume, fine clothes, dice |
| fight loot | `pack_challenge`, `den_reckoning`, `tower_night_visitors` | 30 / 30 / 25 gp and a potion each |
| gifts | Zuleika (Emil path), Ezmerelda (trust 2) | 2 potions; 2 holy water, a potion, 10 bolts |

**Fixed magic items:** none of the adventure's named items lives in these chapters in our version; the Tarokka
treasures are the story items. **Containers for the DMG-items thread:** `van_richten_strongbox` (a hunter's item:
armour, a weapon against the undead), `kiril_hoard` (something taken off a traveller on the Krezk road),
`ezmerelda_wagon` (only if she should lose it), `vrt_workroom_cabinet` (a potion or two).

## 13. Art and theme needs

- **Portraits and 8-direction walk/attack sheets:** `kiril_stoyanovich` (huge, bare-chested, wolf-pelt cloak, long
  teeth), `emil_toranescu` (grey-bearded, big, black burn rings on both wrists), `zuleika_toranescu` (lean, patched wool
  coat, herb knife), `mirela` (ten, split lip, too-big coat). Werewolf hybrid/wolf forms for the encounters use the
  existing werewolf art.
- **Themes:** `lake_shore` (shingle, reeds, fishers' huts as buildings: today `riverside` draws the huts' wall squares
  as trees, so each hut is a single wall square with a `cottage` prop); `tower_island` (a round black-stone tower, a
  stone causeway, a tarn: today `village`, so the tower is a slate-roofed house); `wizard_tower` interior (round stone
  rooms, spiral stairs: today `manor`); `cave` (the den: today `dungeon`); `hill_slope` (rock face with a cave mouth:
  today `wilderness`, which draws the rock face as trees).
- **Props wanted** (stand-ins in brackets): rowboat `boat` [log], net-drying rack `net_rack` [fence], silver wall
  chains `wall_chains` [rope, invisible], statue of Mother Night `statue_mother_night` [altar_stone], lightning-ward
  floor nails `copper_spiral` [none; the trap marks it], Kiril's trophy wall with a Vistani boot [trophy_wolf],
  tower door lintel `lintel_carved` [relief], the cave mouth `cave_mouth` [the exit's stair_down].
- **Travel map:** the art has one lake. Van Richten's Tower sits at (0.14, 0.27) on the grass between the big
  north-west mountain and the lake's north-west rim; the art wants a small tarn with an island tower there (Lake
  Baratok). The den sits at (0.285, 0.22) on the foothills north-east of the lake; a rock face with a cave mouth would
  mark it. Lake Zarovich's place is the middle of the water (0.22, 0.39).

## 14. The critical path (a test bot's route)

Start: party of four at level 7 in Vallaki (`_start("vallaki", 7)`), `werewolf_rumor = true` (the den on the map).
Prefer (in this order): `"We'll free Emil."`, `"We have the key to your chains."`, `"Howl, then."`,
`"We stand with Emil."`, `"What do you want from strangers?"`, `"It's over. You're going home."`.
Avoid: `"We won't do your killing"`, `"Settle it between"`, `"Take him back"`, `"Neither of you"`, `"Then we'll take
them"`, `"We're leaving"`, `"Draw steel"`, `"Let him go"`, `"Insight"`.

1. `go_to("werewolf_den")` (travel, 5 h by the north track; random fights possible). Zuleika approaches; if not,
   `talk("zuleika_toranescu")`. "We'll free Emil." only shows once she has asked, so the bot takes "What do you want
   from strangers?" first, then "We'll free Emil." → `zuleika_vouched`, `emil_key_found`.
2. `go_to("werewolf_den_caves")` (no fight while vouched).
3. `talk("emil_toranescu")` → "We have the key to your chains." → "Howl, then." → Emil is a guest (`emil_freed`).
4. `talk("kiril_stoyanovich")` (he also approaches) → "We stand with Emil." → `pack_challenge` (autopilot).
5. `talk("zuleika_toranescu")` (she also approaches) → `aftermath:emil_wins`.

Assert: `wolf_pack_leader == "emil"`, `den_children_freed`, `kiril_defeated`, `st.milestones == 1`, quest
`wolves_in_the_hills == emil_leads`, `the_stolen_children == freed`; Emil not a guest unless the reading's ally is
`beast`.

Tower (optional second path): `tower_rumor = true`; `go_to("van_richtens_tower")`; Ezmerelda: "What's wrong with the
tower?" → "We'll go in." → "Goodbye."; `use((17, 10))` (the door) → "Say the name: Khazan."; into
`van_richtens_tower_interior`; `use((1, 6))` after the casebook (`use((5, 16))`, workroom) → "Pull the copper rod, as
the casebook says."; the lantern room's strongbox at (7, 33). By day, to skip the causeway ambush.

## 15. Needs outside this package

- **Abbey/Krezk writer:** `ezmerelda_met`'s summary should say the tower sets it too; Ezmerelda's abbey scene could read
  `ezmerelda_trust`, `van_richten_reunited` and `ezmerelda_told_rictavio`. No change to data/npcs/ezmerelda.json is
  needed (she already has `guest`, a `guest_build` and her stat block).
- **Krezk writer:** read `den_children_freed`, `den_children_left`, `mirela_cured` and `wolf_pack_leader` (five
  children from the Vadu and neighbouring farms below Krezk; an untreated bite means a wolf at the next moon). My
  travel file adds a road `tower_to_krezk` (4 h) to their place `krezk`.
- **Vallaki (lead):** `bluto_fate = "vistani"` could show in the camp (Luvash's people dealt with him);
  `ezmerelda_left_tower` could bring Ezmerelda to the Blue Water Inn looking for Rictavio. No Vallaki file was changed.
  data/npcs/arabelle.json already has `guest: true` and a `guest_build` (commoner): no change needed.
- **Tarokka outcomes:** the Broken One's ally (`mordenkainen`) has `region: van_richtens_tower`, but Mount Baratok is
  region 9b's (`mount_baratok`); the lead may want to change that region. The Stars master hint ("on Lake Baratok")
  matches this package's geography.
- **Region 9b:** a road from `van_richtens_tower` to their Mount Baratok place would suit (their lookout already sees the
  tower); I left it to them since their place id isn't in a travel file yet.
- **Engine:** (1) a guest who dies in a fight is still `guest:`; Emil's aftermath assumes he lived. (2) Encounter
  monsters started from dialogue can be placed on squares the party stands on; mine are kept away from where the party
  will be (the passage and mouth cave), but the engine should nudge. (3) Travel-place and road `when` flags aren't
  counted as reads by the validator (every flag used there is also read in dialogue here). (4) `rope` used as an
  invisible model for the silver chains.
- **Items:** silvered weapons and silver-headed bolts (Ezmerelda's gift is plain `crossbow_bolt` until one exists);
  a `wolfsbane` item (Zuleika's brewing is two `potion_of_healing`).
- **Monsters:** none new; all ids used exist (`kiril_stoyanovich`, `emil_toranescu`, `werewolf`, `dire_wolf`, `wolf`,
  `vampire_spawn`, `wight`, `swarm_of_bats`, `ghoul`, `ghast`, `strahd_zombie`, `will_o_wisp`, `commoner`).

## 16. Files

- Region: docs/regions/van_richtens_tower.md (this file); task docs/tasks/P5-09.md
- Voice: docs/voice/{kiril_stoyanovich, emil_toranescu, zuleika_toranescu, mirela}.md
- NPCs: data/npcs/{kiril_stoyanovich, emil_toranescu, zuleika_toranescu, mirela}.json
- Quests: data/quests/{wolves_in_the_hills, the_stolen_children, the_hunters_tower}.json
- Flags: data/flags/van_richtens_tower.json · Travel: data/travel/van_richtens_tower.json
- Random tables: data/random_encounters/{zarovich_hills, zarovich_shore}.json
- Locations: data/locations/{lake_zarovich, lake_zarovich_trail, van_richtens_tower, van_richtens_tower_interior,
  werewolf_den, werewolf_den_caves}.json
- Dialogue: narrative/werewolf_den/{zuleika, emil, kiril, aftermath, children, shrine}.dialogue;
  narrative/van_richtens_tower/{ezmerelda, tower, van_richten}.dialogue;
  narrative/lake_zarovich/{landing, arabelle_ally, events}.dialogue;
  narrative/narrator/{lake_zarovich, van_richtens_tower, werewolf_den}.dialogue;
  narrative/banter/{lake_zarovich, van_richtens_tower, werewolf_den}.dialogue
