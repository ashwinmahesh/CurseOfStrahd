# Region design: the Wizard of Wines and Yester Hill (Phase 5, region 6)

Plan §6 row 6. Party level 6 on arrival (5 to 7 handled), level 7 after the region's one `xp milestone` (§7). Source:
*Curse of Strahd* chapters 12 and 14, retold in our own words; every line, name of a vintage and piece of lore here is
ours. Two region ids share this package: `wizard_of_wines` (the winery, its cellars and press house) and `yester_hill`
(the druids' hill). Implementation reads this doc; the data and dialogue files in §16 are the source of truth.

## 1. What this region is for

The Martikov family has pressed wine in the hills south-west of Vallaki for longer than the valley has had a lord.
Their vines live in Barovia's sunless soil because three magic gems, which the family calls its **vine stones**, lie in
the earth. The Martikovs are also wereravens, the Keepers of the Feather, who watch the castle and carry word, and the
castle has noticed. Three months ago the druids of Yester Hill came up the lane with blights at their backs, took the
winery and stole a stone. The family hides in the trees.

The region asks the party to **recover the stones and save the winery**, and gives them a family to save it for: an old
patriarch too proud to ask, the son he can't forgive, and the daughter who keeps them both fed. The choices are
about what the party brings home (stones, a body, the truth), what they leave on the hill (druids alive or dead, a
tree standing or ash), and where the first wine goes. The payoff is the Keepers of the Feather as allies for the rest
of the campaign, and Davian Martikov as the Tarokka's **Raven** ally.

Tone: warm and wry at the winery (a family that argues over soup), cold and devout on the hill. The jokes come from
Davian's pride, Adrian's dryness and Stefania's shouting; Yester Hill is funny only through the party, if at all.

## 2. People and what they want

| NPC (id) | Where | Wants | Fears / secret | Voice | Stat block |
|---|---|---|---|---|---|
| Davian Martikov (`davian_martikov`) | camp, then the yard | his house, his stones, (unsaid) to stop blaming Adrian | dying with the vines dead; he sent both sons up that hill | grand and blunt, vine metaphors, "Hm." "Speak." | `wereraven` (guest) |
| Adrian Martikov (`adrian_martikov`) | the lane, camp, then the fermenting hall | to go back up the hill; his father's eyes on him | that his father is right; Elvir ordered him to fly | dry, self-mocking, craftsman | `wereraven` (guest for the hill) |
| Stefania Martikov (`stefania_martikov`) | camp, then the yard | a roof; father and brother in one room without a silence | the children seeing the family break | brisk, warm, shouting with love | `wereraven` |
| Kostin (`kostin`) | the press house; the foot of the hill if he doubts | to be faithful and told he did well | silence in the roots; he gave Elvir water in the cage | earnest liturgy, then broken short sentences | `druid` (44 HP) |
| Mother Ruxandra (`ruxandra`) | the crown of Yester Hill | the Lord-in-the-Land to rise and tread the vines flat | (none admitted) the tree loves only what it's fed | grandmotherly, patient, menace in content not tone | `druid` (50-60 HP) |

Voice bibles: docs/voice/{davian_martikov, adrian_martikov, stefania_martikov, kostin, ruxandra}.md. Off-stage: Elvir
(Davian's youngest, dead a year), Stefania's children Mirela, Toma and Viorel, Urwin and Danika in Vallaki
(data/npcs/urwin_martikov.json, danika_martikov.json; Vallaki's files, unchanged), the witch of Berez (region 9b).

The druids believe the lord in the castle and the land of Barovia are one being; they grow blights from the seed of
the **Gulthias tree** on Yester Hill (a tree that grew from a stake pulled out of something that should have stayed dead,
carried here by the mists) and feed it. Their **effigy** is a forty-foot man of earth and timber in the lord's likeness;
the stolen stone sits in its chest, and the chant grows **Wintersplinter** (`tree_blight`) out of it, to walk east and
crush the winery.

## 3. Layout and scenes

Six maps (data/locations/), all in existing themes.

| Map (theme) | Areas | What happens |
|---|---|---|
| `wizard_of_wines` (46 x 32, `village`, outdoors) | `lane_foot`, `vine_lane`, `vineyard_west`, `vineyard_east`, `winery_yard`, `martikov_camp` | Arrive at the lane foot (spawn `from_road`; exit `lane_to_road` → travel). Adrian drops out of the vines (approach). The camp under the trees in the south-west: Davian (approach), Stefania, Adrian; Elvir's empty cairn. The lane is the only way through seven rows of vines (`=`), and they stand up (`vineyard_ambush`). The yard: the house, the winery (exit `winery_door`), the press house (exit `press_house_door`), the well, the broken cart. After the winery is reclaimed the family moves to the yard and the house. |
| `wizard_of_wines_winery` (32 x 20, `tavern`) | `winery_entry`, `winery_office`, `ferment_hall`, `bottling_room` | Tasting room; Davian's office (ledger, portrait, the strongbox); the fermenting hall with eight vats where the druids sleep (`winery_occupation`); the bottling room; the cellar stair in the hall's far corner. Safe rest once cleared. Adrian works here after the reclaiming. |
| `wizard_of_wines_cellar` (30 x 14, `dungeon`, dark) | `cellar_stair_foot`, `cask_vaults`, `old_vintages`, `the_dig` | The founder's cask at the stair foot (the hidden stone, `winery:founders_cask`); the cask vaults with the dry cask (Tarokka spot); a side vault of old vintages; a broken wall into the dig, where blights claw for the stone in the wrong place (`cellar_dig`, optional). |
| `wizard_of_wines_press_house` (24 x 16, `shop`) | `press_floor`, `press_door`, `wizards_corner` | The great press; the vat where Kostin grew the Mash; Kostin's confrontation (approach) and `press_house_mash`; the wizard's rack of unclaimed casks (Tarokka spot); the tally board; Ruxandra's letter. |
| `yester_hill` (40 x 30, `wilderness`, outdoors) | `hill_foot`, `back_gully`, `wardens_camp`, `barrow_slope`, `hill_crest` | A bald barrow hill rising in five 5-ft steps (`.`→`4`). Kostin at the foot if he doubted. The back gully up the west side (`approach:gully`, Stealth). The wardens' camp on the shoulder: painted wild men, the wicker cages, **Elvir's message** on the cage post (`approach:cage_post`), the hoard (`wardens_camp_fight`, optional: the main path passes it by). Exits `summit_path` and `gully_head` to the crown; `hill_track_out` → travel. |
| `yester_hill_gulthias_tree` (32 x 24, `shrine_yard`, outdoors) | `summit_edge`, `ritual_ring` | The crown in its ring of standing stones: the Gulthias tree (2 x 2 trunk, `summit:tree`, `burning` when burned), the effigy lying on its back, the ritual fire, Ruxandra (approach) and the climax `summit_ritual`. After: Ruxandra's fate, Wintersplinter's heart (`summit:heart`), Elvir's bones (`summit:elvir`), the roots (Tarokka spot), the offerings. |

### The flow (any order works; this is the natural one)

1. **The lane.** Adrian, the raven from the Svalich road, drops out of the vines: grateful (`raven_fed`), cold
   (`raven_harmed`, with an apology option), or curious; mentions Urwin's letter (`keepers_of_the_feather_met`). He warns
   the party off the lane and leads them to the camp.
2. **The camp.** Davian greets them by what the valley has told him (`raven_harmed`, Urwin's friends, Ilinca Vrana's word
   from Old Bonegrinder `ilinca_vouched`, Vallaki's `wizard_of_wines_hook`, or nothing), tells of the three stones (one to
   the witch of Berez, one to Yester Hill, one hidden in the founder's cask) and sets terms: clear the winery and the
   press house, bring up the hidden stone. Quests `wizard_of_wines asked`, `the_third_stone told`; Yester Hill appears on
   the map. Stefania tells Elvir's story (`elvir_martikov heard`).
3. **The winery.** The lane ambush; the fermenting hall; the cellar stair; the founder's cask ("third hoop, pull"); the
   optional dig; the press house and Kostin (fight, scare, or talk him out of his faith).
4. **The reclaiming.** Back at the camp: "The druids are out of your house." The family goes home (`winery_reclaimed`).
   The stone goes into the soil; the first cart is promised (Vallaki, the village of Barovia or Krezk).
5. **Yester Hill.** Optionally take Adrian. Kostin at the foot (if he doubted); the gully or the path; the cages and
   Elvir's words; the crown, Ruxandra, the ritual and Wintersplinter. Then: Ruxandra's fate, the tree, the stone, Elvir.
6. **Home.** The stone, the hill report, the milestone, the Keepers' oath, Elvir's burial, the reconciliation, and the
   ally if the cards named Davian.

## 4. The threads

### 4.1 The winery (Davian's terms)

Two fights free the house: `winery_occupation` (enter the fermenting hall) and `press_house_mash` (from Kostin's
conversation). Reporting both to Davian (`davian:reclaim`) sets **`winery_reclaimed`**, quest `wizard_of_wines
reclaimed`, and moves the family home (NPC entries switch on the flag). The cellar dig is optional. If the Gulthias tree
already burned (the party went to the hill first), every blight in the region is dead: the vineyard ambush never comes,
the hall holds three druids, the dig one druid, the press house Kostin and the Mash only.

### 4.2 The three stones

| Stone | Where | How | Flags |
|---|---|---|---|
| The cellar stone | founder's cask, foot of the cellar stair | Davian's "third hoop, pull" (`winery_stone_hiding_told`), or Investigation 14 at the cask | `winery_stone_recovered` → `winery_stone_returned` |
| The hill stone | the effigy's chest, then Wintersplinter's heartwood | win `summit_ritual`, use the splintered heartwood (`summit:heart`); a black thread runs through it unless the tree burned | `yester_stone_recovered` → `yester_stone_returned` |
| The Berez stone | Baba Lysaga's hut, Berez (region 9b) | Berez sets `winery_gem_berez_found` (docs/regions/berez.md §10); Davian's option reads it (or `quest.the_third_stone == found`) | `berez_stone_returned`, quest `the_third_stone returned` |

Each return adds 1 to **`winery_stones_returned`**. One stone with the winery reclaimed: **`winery_wine_flows`**, and the
party picks where the **first cart** goes (`winery_first_cart`: `vallaki`, `village`, `krezk`). Two stones with the winery
reclaimed: the **Keepers' oath** (`keepers_allied`). Three: Davian's best scene. The vineyard's Narrator lines, Adrian's
"How's the wine?" and the yard's cart prop all follow the count.

### 4.3 Yester Hill

- **The approach.** The path goes straight up past the wardens' camp (avoidable). The back gully (`approach:gully`):
  Stealth 13, or 16 if Kostin ran to warn them, sets `yester_sneaked` (or `yester_heard`).
- **The crown** (`ruxandra:summit`, approach 10). Sneaked: "Strike now, while they chant" (`yester_struck_first`:
  surprise, Wintersplinter half-made). Otherwise Ruxandra speaks: fight; Intimidation 17 (the circle runs, she follows:
  `yester_druids_fate = "fled"`, Wintersplinter alone with twig blights); Religion 15 (the circle breaks, she stays:
  `yester_circle_broken`); ask about the tree; ask about Elvir (she tells, cruelly). Every branch ends in `summit_ritual`,
  which sets **`yester_hill_resolved`**.
- **After.** Ruxandra among the roots (`ruxandra:fallen`): spare her (`spared`) or end it (`killed`); she can also tell
  Elvir's truth. The tree (`summit:tree`): **burn it** (`gulthias_tree_burned`: it screams, every blight in the region
  dies, the stone comes clean, the druids can't come back) or leave it. The heart (the stone). Elvir's bones.
- **Consequence on the road.** Druids spared or fled with the tree standing: they ambush the party once on the vineyard
  road (`vineyard_road` entry `druids_return`, Ruxandra at their head). Blights keep coming out of the hedges until the
  tree burns; druid patrols until the hill is broken.

### 4.4 Kostin

The young druid in the press house. Fight ("Then we'll take it back."); Intimidation 15 (`kostin_fled`: he runs to the
hill and warns them: no easy gully, an extra druid in the summit fight, Davian says "expect to be expected"); Nature 14,
Persuasion 16 or a druid's words (`kostin_doubts` + `kostin_fled`: he walks away; at the foot of Yester Hill he tells the
party about the gully and what Elvir said, and leaves for somewhere "the trees only drink rain"). The Mash fights in
every case.

### 4.5 Elvir, Adrian and Davian

Last spring Davian sent Adrian and Elvir to watch the hill; a root pinned Elvir, who couldn't change and ordered Adrian
to fly for help. Adrian obeyed and has said only "I flew". Davian blames him. Routes to the truth (`elvir_truth_known`):
Elvir's words on the cage post (no check), Kostin at the foot of the hill, Ruxandra (before or after the fight), Speak
with Dead on the bones. Adrian's own account (Insight 13, `adrian_told_order`) is not proof. Reconciliation
(`martikovs_reconciled`, quest `elvir_martikov reconciled`): tell Davian the truth (no check), or Persuasion 14 with
Adrian's account, or Insight 14 into Davian's own guilt (one try each). Bringing Elvir's bones home
(`elvir_remains_recovered` → `elvir_buried`) gives a burial at the last green row; the cairn becomes a grave. Adrian can
come to the hill as a guest (`adrian_went_to_hill`) and reacts at the cage, the heart, the tree and the bones; he leaves
the party at the hill report (or with Stefania).

### 4.6 Smaller beats

- **The strongbox** in Davian's office (lock 15, 60 gp, `winery_strongbox_opened`): once home, Davian notices. Give it
  back (he returns 10 for the lock), claim innocence, call it a fee or lie (Deception 14). Keeping it
  (`winery_strongbox_kept`) earns a banter and "I'll be counting the spoons" in the ally scene.
- **The wizard who never came back**: the sign, the tally board, the rack of unclaimed casks (the press house Tarokka
  spot) explain the winery's name.
- **The first cart**: Stefania later reports how it was received (Urwin's three-word note; the village bell; Krezk's
  pear tree).
- **A raven on the road** (`vineyard_road` event `keepers_word`) brings a green leaf.

## 5. Choices and consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| Kostin | press house | fight; scare (Intimidation 15); convert (Nature 14 / Persuasion 16 / druid) | who fights the Mash; `kostin_fled`, `kostin_doubts` | warned hill (extra druid, harder gully) or Kostin's help at the hill foot |
| The strongbox | winery office | leave it; open it, then return / deny / keep / lie | `winery_strongbox_opened`, `winery_strongbox_kept` | Davian's trust, banter, the ally scene |
| Take Adrian up the hill | camp / hall | yes, no | `join adrian_martikov` | his scenes at the cage, heart, tree and bones; Davian's thanks |
| The approach | foot of the hill | path, gully (Stealth) | `yester_sneaked` / `yester_heard` | surprise and a half-made Wintersplinter |
| The druids | the crown | fight; drive off (Intimidation 17); break the circle (Religion 15); after: spare or kill Ruxandra | `yester_druids_fate`, `yester_circle_broken` | the summit fight's size; the druids' revenge on the road; Davian's words; epilogue |
| The Gulthias tree | the crown | burn, leave | `gulthias_tree_burned` | every blight dies (winery fights, road table); the stone is clean; no revenge; Narrator and banter |
| Which stones come home | cellar, crown, Berez | 0 to 3 | `winery_stones_returned` | wine flows (1), the Keepers' oath (2), Davian's toast (3) |
| The first cart | Davian | Vallaki, the village, Krezk | `winery_first_cart` | Stefania's news; Krezk's gate (§11); epilogue |
| Elvir | cage, roots, Davian | find the truth, bring him home, tell Davian or not | `elvir_truth_known`, `elvir_buried`, `martikovs_reconciled` | Adrian gets the press; the ally scene; the Keepers' tone; epilogue |
| The ally (if the Raven card) | Davian | ask before / after the reclaiming | `davian_ally_asked`, `join davian_martikov` | Davian travels with the party |

No path is gated by a check: the winery, the stones, the hill and reconciliation through the truth all have plain
options.

## 6. Encounters (2024 DMG budgets, four characters)

Level 5: Low 2000 / Moderate 3000 / High 4400. Level 6: Low 2400 / Moderate 4000 / High 5600. Level 7: Low 3000 /
Moderate 5200 / High 6800. XP per block: druid 450, berserker 450, tree blight 2900, shambling mound 1800, vine blight
100, needle blight 50, twig blight 25. Variants are tried in order; the first whose `when` holds is the fight.

| id (map, trigger) | Variants (XP; L6 band) | Notes |
|---|---|---|
| `vineyard_ambush` (exterior, enter `vine_lane`; party surprised) | L7: druid, 3 vine, 6 needle, 6 twig (1200); L6: druid, 2 vine, 6 needle, 6 twig (1100, Low); under 6: 2 vine, 4 needle, 6 twig (550) | none once the tree burned |
| `winery_occupation` (winery, enter `ferment_hall`) | tree burned: 3 druids at 35 HP (1350); L7: 4 druids, 4 vine, 6 needle, 4 twig (2600); L6: 3 druids, 3 vine, 6 needle, 4 twig (2050, Low); under 6: 2 druids, 2 vine, 4 needle (1300) | critical path |
| `cellar_dig` (cellar, enter `the_dig`) | tree burned: druid overseer 35 HP (450); L7: druid, 2 vine, 8 needle (1050); L6: druid, vine, 6 needle (850); under 6: vine, 4 needle (300) | optional |
| `press_house_mash` (press house, dialogue) | burned+fled: the Mash (1800); burned: Kostin 44 HP + Mash (2250); fled: Mash, 2 vine, 3 needle (2150); L7: Kostin, druid, Mash, 2 vine (2900); L6: Kostin, Mash, 2 vine (2450, Low); under 6: Kostin, Mash at 90 HP, vine (2350) | critical path; the Mash is a `shambling_mound` named "The Mash" |
| `wardens_camp_fight` (hill, enter `wardens_camp`) | L7: 4 berserkers, 4 twig (1900); L6: 3 berserkers, 4 twig (1450, Low); under 6: 2 berserkers, 4 twig (1000) | optional; gone once the hill is broken |
| `summit_ritual` (crown, dialogue) — **the climax** | fled: Wintersplinter 120 + 6 twig (3050); struck first (enemies surprised): W 100, Ruxandra 55, 2 druids, 4 twig (4350); circle broken: W 140, Ruxandra 60, 6 twig (3500); Kostin warned: W 140, Ruxandra, Kostin, 2 druids, 4 twig (4800, Moderate); L7: W 149, Ruxandra, 3 druids, a warden, 2 vine, 4 twig (5450, Moderate for L7); L6: W 140, Ruxandra 60, 2 druids, 6 twig (4400, Moderate); under 6: W 110, Ruxandra 50, druid, 4 twig (3900, Moderate for L5) | critical path; Wintersplinter is a Huge `tree_blight` |
| `vineyard_road` table (map `road_forest`) | hedge blights (550, until the tree burns; party surprised), druid patrol (1150, until the hill is broken), wolves at night (600), the Keepers' leaf (event, once), `druids_return` (1650, once, if spared/fled and the tree stands) | day 15%, night 40% |

The critical path is three Low fights (lane, hall, press) and one Moderate (the crown). Davian or Adrian as guests (a
wereraven each, 450 XP) can add to the party's side; the summit stays Moderate with one guest. The auto-player has the
Mash (110 HP, engulf) and Wintersplinter (140 HP, AC 15, reach) as the two big bodies; neither fight has a rider it can't
answer, and the party can rest safely in the winery between the press house and the hill.

## 7. Milestone

One `xp milestone` (level 6 → 7), guarded by `wizard_of_wines_milestone_reached`, at the region's climax: in
`davian:milestone`, reached from `check_done` after any report once **`winery_reclaimed` and `yester_hill_resolved`** both
hold (winery first or hill first). Quest `wizard_of_wines saved`. When Davian travels as the ally, Stefania's "We have news
for the family" opens the same menu.

## 8. Tarokka treasure spots and the ally

| Place (outcomes.json) | Card | Location | Spot | Reached |
|---|---|---|---|---|
| `wizard_of_wines_cellar` | coins_4 | `wizard_of_wines_cellar` | container `dry_cask` ("A cask that sounds hollow", cask vaults, behind the hall fight) | the Narrator hints (`treasure_at:`) on entering the cellar and opening the cask |
| `wizard_of_wines_press_house` | coins_3 | `wizard_of_wines_press_house` | container `wizards_rack` (the wizard's rack, east wall) | after or around the press house fight; the casks' examine line hints |
| `yester_hill_gulthias_tree` | glyphs_5 | `yester_hill_gulthias_tree` | container `gulthias_roots` ("Among the roots", at the trunk) | after the summit fight; `open:` line hints |

Davian also hints (`davian:intel`) at "a cold light where no lamp is" when a treasure is in the winery.

**The Raven ally: Davian Martikov** (`data/npcs/davian_martikov.json`, `guest: true`, `guest_build: {monster:
wereraven}`). Option "Madam Eva's cards named you." in Davian's menu when `tarokka.ally.npc == davian_martikov`: before
the winery is reclaimed he refuses until his house is his (`davian_ally_asked`); after, `davian:ally` ends in `join
davian_martikov` and `quest find_the_ally found`, with lines for reconciliation and the strongbox.

## 9. Loot

| Container | Map | Contents | DMG magic item candidate |
|---|---|---|---|
| `davian_strongbox` | winery office | 60 gp (the family's; see §4.6) | no (it's Davian's) |
| `druid_bedrolls` | fermenting hall | 2 bedrolls, herbalism kit, mistletoe focus, 12 gp | yes (an uncommon druid item) |
| `bottling_shelf` | bottling room | 3 glass bottles, 2 oil, 4 candles | no |
| `dry_cask` | cellar vaults | pouch, 9 gp (+ Tarokka treasure) | no |
| `old_vintage_rack` | old vintages | 2 glass bottles, jug | yes (a potion or two, "kept for somebody") |
| `overseer_pack` | the dig (after `cellar_dig`) | potion of healing, shovel, lamp, 10 gp | no |
| `wizards_rack` | press house | jug, 8 gp (+ Tarokka treasure) | yes (the wizard's cask: a fitting place for a wand or scroll) |
| `press_tools` | press house | carpenter's tools, crowbar, rope | no |
| `kostin_satchel` | press house (after the fight, if Kostin stayed) | herbalism kit, potion of healing, 18 gp | no |
| `wardens_hoard` | wardens' camp | greataxe, 2 handaxes, 4 rations, hide armor, 34 gp | yes (a weapon or armour) |
| `gulthias_roots` | the crown | dagger, shortsword, 41 gp (+ Tarokka treasure) | yes (what the tree swallowed) |
| `ritual_offerings` | the crown | herbalism kit, 2 potions of healing, druidic staff, 25 gp | yes (a druid's staff or a periapt) |

**Fixed Curse of Strahd items of these chapters:** the three magic gems (the vine stones). There is no gem item in
data/items or data/magic_items, so the package tracks them with flags (§4.2) and asks for an item (§15). No other fixed
magic item belongs to chapters 12 and 14.

## 10. Reading earlier regions

| Flag (owner) | Read by |
|---|---|
| `raven_fed`, `raven_harmed` (svalich_road) | Adrian's first meeting (he was the raven), Davian's greeting, the Keepers' oath |
| `keepers_of_the_feather_met`, `wizard_of_wines_hook` (vallaki) | Adrian (Urwin's letter), Davian's greeting |
| `ilinca_vouched` (old_bonegrinder) | Davian's greeting |
| `winery_gem_berez_found` (berez, region 9b; not yet in data/flags) | Davian's Berez stone option |
| `tarokka.ally.npc`, `treasure_at:<place>` (campaign) | the ally scene; Davian's intel; Narrator hints |
| `guest:ireena` | Davian's first meeting, the reconciliation |
| `spell:speak_with_dead` | Elvir's bones |

## 11. Flags (data/flags/wizard_of_wines.json) and what later regions read

All 57 flags are registered, set and read. For other packages and the ending:

- **`winery_reclaimed`**, **`yester_hill_resolved`**: the region's two halves.
- **`winery_wine_flows`**, **`winery_first_cart`** (`vallaki` / `village` / `krezk`): Krezk's gate (Dmitri says the
  Martikovs' cart is the one thing the gate opens for: krezk/gate.dialogue could read `winery_first_cart == "krezk"` or
  `winery_wine_flows`), the Abbey (Clovin Belview walks to the winery for wine: krezk/road.dialogue), Vallaki's inn and
  the village tavern (both could pour again), the epilogue.
- **`keepers_allied`**: the Keepers of the Feather pledged their eyes and wings: Castle Ravenloft (ravens scout, carry
  word, join a fight), Argynvostholt, the epilogue.
- **`winery_stones_returned`** (0-3), **`berez_stone_returned`**, quest `the_third_stone`.
- **`gulthias_tree_burned`**, **`yester_druids_fate`** (`fled` / `spared` / `killed`): later blight or druid content,
  Strahd's notice, the epilogue.
- **`martikovs_reconciled`**, **`elvir_buried`**, **`elvir_truth_known`**: the epilogue; Davian's lines as the ally.
- Quests: `wizard_of_wines` (asked → reclaimed / hill_broken → saved), `the_third_stone` (told → found → returned),
  `elvir_martikov` (heard → truth_found → reconciled); `find_the_ally found` (Svalich Road's) when Davian joins.

## 12. Travel

data/travel/wizard_of_wines.json: places `wizard_of_wines` (pos 0.235, 0.54: the open meadow south of the lake road
between Vallaki and Krezk, on land; known from the start, the winery is famous) and `yester_hill` (pos 0.12, 0.565: the
grassy foot of Krezk's hill, west of the vines; appears with `yester_hill_known` or a Tarokka treasure there). Roads:
`vallaki_to_wizard_of_wines` (3 h) and `wizard_of_wines_to_yester_hill` (2 h), both on table `vineyard_road`. Krezk's
package should join `krezk` to `yester_hill` or `wizard_of_wines` (the Old Svalich Road runs on west).

## 13. The critical path (what a test bot follows)

Party of four at level 6, starting at Vallaki (or `wizard_of_wines`). Avoid: "End it", "Call it our fee", "Deception",
"Leave it standing". Prefer, in this order: "Take us to your father.", "We'll clear your house.", "Turn the third hoop
and pull.", "Then we'll take it back.", "The druids are out of your house.", "Your stone, from the founder's cask.",
"To Vallaki.", "We're taking the stone.", "Go. Crawl off this hill", "The stone from Yester Hill.", "Yester Hill is
finished.", and with the Raven card "Madam Eva's cards named you."

1. `go_to("wizard_of_wines")` (map: Vallaki → the Wizard of Wines). Adrian's approach at the lane foot → "Take us to your
   father." (`adrian_met`).
2. `talk("davian_martikov")` (camp) → first meeting → "We'll clear your house." (`davian_met`, `winery_stone_hiding_told`,
   `yester_hill_known`, quest `wizard_of_wines asked`) → "Goodbye."
3. `go_to("wizard_of_wines_cellar")`: up the lane (`vineyard_ambush`), into the winery, through the fermenting hall
   (`winery_occupation`), down the stair.
4. Use the founder's cask (cell 4,2) → "Turn the third hoop and pull." (`winery_stone_recovered`).
5. `go_to("wizard_of_wines_press_house")`: Kostin's approach → "Then we'll take it back." → `press_house_mash`.
6. `go_to("wizard_of_wines")`, `talk("davian_martikov")` (still at the camp) → "The druids are out of your house."
   (`winery_reclaimed`) → "Your stone, from the founder's cask." (`winery_wine_flows`) → "To Vallaki." → "Goodbye."
   (Davian now stands in the yard.) Raven card: "Madam Eva's cards named you." → `join davian_martikov`.
7. `go_to("yester_hill_gulthias_tree")` (map: the Wizard of Wines → Yester Hill; walk the path up, x = 20).
8. `talk("ruxandra")` → "We're taking the stone. Stand aside or don't." → `summit_ritual` (`yester_hill_resolved`).
   Ruxandra's fallen approach → "Go. Crawl off this hill and don't come back." (`yester_druids_fate = "spared"`).
9. Use the splintered heartwood (cell 21,10) → `yester_stone_recovered`.
10. `go_to("wizard_of_wines")`, `talk("davian_martikov")` (the yard; or Stefania's "We have news for the family." when
    Davian is the ally) → "The stone from Yester Hill." → the milestone (`wizard_of_wines_milestone_reached`, quest
    `wizard_of_wines saved`) and the Keepers' oath (`keepers_allied`) → "Yester Hill is finished." → "Goodbye."

Checks: `wizard_of_wines_milestone_reached`, `winery_stones_returned == 2`, `keepers_allied`, quest `wizard_of_wines ==
saved`; with the Raven card, `guest:davian_martikov` and `find_the_ally == found`. Treasure test: open `dry_cask`
(cellar), `wizards_rack` (press house) and `gulthias_roots` (crown).

## 14. Art and theme needs

- **Portraits and sprites:** `davian_martikov` (old man, white beard, black eyes, wine-stained coat, a carved raven clasp;
  raven form), `adrian_martikov` (lean, black-eyed, cooper's apron), `stefania_martikov` (sleeves rolled, a child on her
  hip), `kostin` (young, gaunt, robe of green-dyed sacking), `ruxandra` (old woman, kind face, earth to the elbows).
  Moods used: Davian angry, Adrian angry/sad, Kostin angry. Monster art: `tree_blight` (Wintersplinter), `shambling_mound`
  (the Mash), and the blights/druids/berserkers if missing.
- **Props wanted** (stand-ins in brackets, all in the catalog today): wine press [`winch`], fermenting vats and the mash
  vat [`barrel`], a cask rack and the founder's giant cask [`barrel`], trellised vine rows (the `=` cells; today drawn as
  low cover) [`fence`], the winery sign with the wizard [`sign`], the Gulthias tree, black and crooked, plus a burned stump
  [`dead_tree`, burning flame], the earthen effigy of Strahd lying down [`grave_mound`], Wintersplinter's splintered
  heartwood [`log`], wicker cages [`cage`], standing stones (drawn as shrine pillars; examine spot `statue_headless`).
- **Themes wanted:** `vineyard` (grass between trellis rows instead of the village's cobbles, stone-and-timber winery
  buildings, forest at the edge); `wine_cellar` (vaulted brick, casks; `dungeon` stands in); `barrow_hill` (bare grass,
  turf mounds, a few dead trees; `wilderness` draws `#` as healthy pines).

## 15. Needs outside this package

- **Items:** a story item for the gems, e.g. `wizard_of_wines_gem` (quest item, "a green stone the size of a plum, warm",
  three of them) so the stones show in inventory and Berez can hand one over; today they are flags.
- **Berez (region 9b):** register and set `winery_gem_berez_found` as its doc says (`davian.dialogue` reads it now: until
  berez.json lands the validator reports it unregistered and never set). Optionally also `quest the_third_stone found`.
- **Krezk (region 7):** read `winery_first_cart == "krezk"` / `winery_wine_flows` at the gate; add a road from `krezk` to
  `yester_hill` or `wizard_of_wines`.
- **Vallaki (wanted change, not made):** `urwin_martikov.json` and `danika_martikov.json` could use `monster: wereraven`
  now that the block exists (they are `commoner` stand-ins), and Danika's kitchen or Urwin's bar could react to
  `winery_wine_flows` / `winery_first_cart == "vallaki"` ("About time, Father").
- **Village of Barovia:** Arik at the Blood of the Vine could pour again with `winery_first_cart == "village"`.
- **Engine:** a timed threat (Wintersplinter marching on the winery N days after the party learns of it) needs a day
  counter or `wait until`; a way for the conversation to know a fight's survivors (today Ruxandra's fate is asked after a
  victory regardless of how she fell); `combat` from a random-table dialogue needs encounters on the table's map, so the
  druids' return is a plain fight with narration (a table-owned encounter list would let it start with Ruxandra speaking).
- **Validator:** random-table and travel `when` conditions aren't scanned for flags (so `yester_hill_known`,
  `raven_word_heard`, `yester_druids_fate` are also read in dialogue to count as read).

## 16. Files

- Region: docs/regions/wizard_of_wines.md (this file); task docs/tasks/P5-06.md
- Voice: docs/voice/{davian_martikov, adrian_martikov, stefania_martikov, kostin, ruxandra}.md
- NPCs: data/npcs/{davian_martikov, adrian_martikov, stefania_martikov, kostin, ruxandra}.json
- Quests: data/quests/{wizard_of_wines, the_third_stone, elvir_martikov}.json
- Flags: data/flags/wizard_of_wines.json
- Locations: data/locations/{wizard_of_wines, wizard_of_wines_winery, wizard_of_wines_cellar,
  wizard_of_wines_press_house, yester_hill, yester_hill_gulthias_tree}.json
- Travel: data/travel/wizard_of_wines.json; random table data/random_encounters/vineyard_road.json
- Dialogue: narrative/wizard_of_wines/{adrian, davian, stefania, kostin, winery, road}.dialogue;
  narrative/yester_hill/{approach, ruxandra, summit}.dialogue; narrative/narrator/{wizard_of_wines, yester_hill}.dialogue;
  narrative/banter/{wizard_of_wines, yester_hill}.dialogue
