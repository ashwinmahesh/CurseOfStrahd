# Region design: Old Bonegrinder (Phase 5)

Plan §6 row 5. Party level 5 or 6 on arrival (after Vallaki), one level higher at the climax (one `xp milestone`,
when the children come out of the cages). Source: *Curse of Strahd* chapter 6, retold in our own words; every line,
summary and description here and in the data is ours. Implementation reads this doc; the data and dialogue files in
§16 are the source of truth for exact text.

## 1. What this region is for

A short, sharp side region on the way between the village and Vallaki: a windmill on a crag where the sweet old woman
from the village square, Morgantha, bakes her dream pastries with her two "daughters", and keeps the children her
customers couldn't pay for. All three are night hags. Three hags together are a coven, and a coven is far more than a
level 5 party can fight, so the region is a puzzle about **splitting the coven** (feed one, fool one, bargain with
one), then a choice about **the children** (fight for them, buy them, or walk away) and about **the trade** (end it,
hand it to the daughter who betrayed her mother, or let it go on).

Tone: the village's dread-with-a-wink, turned up. The comedy is all in the hags' manners (Morgantha's sugar, Offalia's
cheerful appetite, Bella's boredom); the cages are not funny, and the children are written straight.

End state for later regions: the string flag **`bonegrinder_fate`** (`destroyed`, `broken`, `bella`, `bargain`,
`abandoned`) and the trade's state **`pastry_trade`** (`ended`, `dwindling`, `thriving`).

## 2. Who is here, what they want, how they talk

| id | Name | Where | Wants | Fears | Voice in a line | Stat block |
|---|---|---|---|---|---|---|
| `morgantha` (existing) | Morgantha | loft, rocking between the cages; the lane with her cart | customers, and their children; her coven whole | being alone; sunlight on holy symbols | sugar, endearments, appraisal; talks of herself in the third person | `night_hag` (name Morgantha) |
| `bella_sunbane` | Bella Sunbane | loft at her dressing table; the stair | her mother dead, the mill and the soul bags hers, to be adored | getting old (becoming Mother); ugliness | languid, sardonic, "darlings"; flatters then cuts | `night_hag` (name override) |
| `offalia_wormwiggle` | Offalia Wormwiggle | the bakery, at the oven | to eat, to please Mother, to be best at the flour | Mother being cross; the grey place where nothing tastes of anything | short happy sentences, "Mother says", food words, grotesquely innocent | `night_hag` (name override) |
| `ilinca_vrana` | Ilinca Vrana | the dead oak on the hill | the children out; the mill gone | being too late again (she delivered both children and couldn't stop the sale) | brisk, dry, unsentimental midwife; short sentences | `wereraven` (guest) |
| `ilka_sarnov` | Ilka Sarnov, 10 | a cage in the loft | Toma safe; the truth | Toma getting heavier; being lied to | fierce, practical, counts things | `commoner` |
| `toma_sarnov` | Toma Sarnov, 6 | the other cage | cake; Mama | nothing yet (he sleeps on the pastries) | tiny, sleepy; calls Morgantha "Granny" | `commoner` |

Voice notes (there are no separate docs/voice files for the new NPCs; this section is their bible, and the NPC files'
`voice` points here; the lead may split them out):

- **Bella Sunbane.** Wears a lovely young miller's daughter with flour-white hands and a red ribbon. Bored, vain,
  contemptuous of "the old crust" and of her sister's appetite. Funny because she treats murdering her mother as a
  career move. With clerics: amused ("Give, darling. Selling is Mother's line."). With anyone who keeps faith with
  her: genuinely surprised ("Honest heroes. How very rare."). Secret: she doesn't want the mill, she wants the soul
  bags. Samples: "I'm Bella, the pretty one. I'd shake hands, but you'd want yours back." / "I don't eat children.
  Terrible for the figure." / "Keep your conscience. It'll be the only warm thing you own by winter."
- **Offalia Wormwiggle.** Wears a round, rosy baker's wife; always holding a hot tray in bare hands. Simple and
  cheerful; says the worst things about the millstone the way any cook says "don't waste the rind". Loves her mother
  completely; easy to fool with "Mother's calling". Samples: "Are you deliveries? You're ever so big for deliveries." /
  "Mother says you mustn't waste anything. Not the marrow. Not the teeth." / "I'm not allowed to touch them. Not yet."
- **Ilinca Vrana.** Seventy-one, forty years the village midwife, a raven more often than not. Doesn't judge the
  mother; has no time for heroes who stand about. Refers to Urwin Martikov as "a good boy, talks too much". Samples:
  "I'm still a bird. I'm also seventy-one." / "It's hags, dear. Cheating is the only fair fight on offer."
- **Ilka and Toma.** Written straight. Ilka knows her mother sold them and asks the party to say it; Toma doesn't.
- **Morgantha** keeps docs/voice/morgantha.md. At home the sugar is the same; the mask slips only at the fight
  ("your bones for the stone, and your dreams for supper. Waste not, dearies.").

## 3. Layout and scenes

Four maps (data/locations/). The hill is the travel map's place `old_bonegrinder`; the mill's ground floor is the
location **`old_bonegrinder`** (the Tarokka place).

| Map | Size, theme | Areas (enter: triggers) | What happens |
|---|---|---|---|
| `old_bonegrinder_hill` | 30 x 24, `village` (outdoors) | `hill_track`, `hill_oak`, `hill_yard`, `hill_bone_heap`, `hill_lookout`, `hill_shed` | The track up from the road (exit `bonegrinder_track_down` → travel; spawn `from_road`), Ilinca in the dead oak (approach), the bone heap (search DC 13: Brother Kesten's holy symbol), the hags' garden, the lookout crag, the cart shed with Morgantha's pastry cart (container) and, after the rescue, the lamp oil to burn the mill. The mill door (exit, shut once the mill burns). |
| `old_bonegrinder` | 20 x 16, `house` | `mill_bakery`, `mill_grindstone`, `mill_pantry`, `mill_stair_foot`, `mill_stair` | Offalia at the oven (approach). The great oven (`hag_oven`, the treasure spot), the millstone, the receipt book, the pantry (cupboard, jars), the pastry rack. Bella comes halfway down the stair once Offalia is dealt with. Stair up to the loft. Rest risky. |
| `old_bonegrinder_loft` | 18 x 14, `attic` | `loft_landing`, `loft_nest`, `loft_gears`, `loft_hearth`, `loft_cages` | Morgantha in her rocking chair (approach), Bella at her mirror, the children in the cages (approach), the soul bags on hooks, the hoard chest (lock 15), the sail brake (lever), a trapped hatch over the chute (detect 13, DEX 13, 2d6). The last stand. Rest no. |
| `old_bonegrinder_track` | 32 x 16, `road` | `millers_lane` | The lane's random fights and meetings (table `bonegrinder_lane`): Morgantha's cart, Bella's cart, Offalia in the hedge, the Keepers' gift; `bella_on_the_road`, `offalia_on_the_road`. |

### The flow (each step optional except the cages)

1. **The lane.** On the way up, Morgantha may meet the party with her cart (`morgantha_cart`, once, while the coven
   stands): she remembers the village, sells a pastry, invites them up. She can't be fought on the open road; she
   steps into the Ethereal.
2. **The hill.** Ilinca drops out of the oak as a raven and stands up an old woman. She names the hags and the
   children, explains the coven and how to split it (Offalia's appetite, Bella's grudge), hints at the oven if the
   reading put a treasure there, and flies in with the party as a guest if asked (`join ilinca_vrana`). If the party
   struck the Keepers' raven on the Svalich road, she needs Persuasion 13.
3. **The bakery.** Offalia greets the "deliveries". Deal with her one of three ways: **feed her** one of her mother's
   pastries (from the village, the cart or the rack: `offalia_asleep`), **fool her** (Deception 13, "Mother's calling
   from the road": `offalia_lured`), or **fight her alone** (`bakery_offalia`). Opening the oven while she's awake
   starts the fight too. Upstairs, the chair keeps rocking; Morgantha doesn't come down.
4. **Bella on the stair.** Once Offalia is out of the way, Bella comes down to look and offers a **pact**: she sits
   out the fight if the mill is hers afterwards. Insight 13 shows she really wants something in the loft (the soul
   bags). Deception 14 ("Mother means to leave the mill to Offalia") sends her off in a fury (`bella_fled`). Or refuse
   her and she fights beside her mother. If the party goes up first, the same offer is made at her mirror.
5. **The loft.** Morgantha, rocking between the cages, greets them by what they did in the village and below. The
   children can be talked to through the bars. Then the choice: **buy them back** (150 gp, one party member's sweetest
   dream, or Persuasion 16 for the party's word to leave the mill in peace), **walk away** and leave them, or **fight**.
   Whoever of her daughters is still at hand fights beside her (`coven_last_stand`, §7).
6. **The cages.** After the fight (or the bargain) the children come out: the **milestone**. Ilka asks whether her
   mother sold them (truth or a kind lie). Ilinca takes them **home** to the village or to **Vallaki** (Urwin Martikov's
   inn), vouches for the party to the Keepers, and leaves the party.
7. **After.** If Bella has her pact she takes the rocking chair and asks for the soul bags (keep faith, Persuasion 14
   to free them anyway, or break the pact and fight her alone). Free the soul bags, release the sail brake, rake the
   oven, burn the mill. A sleeping Offalia can be killed in her sleep or left to wake and wander.

## 4. The big threads

### 4.1 Splitting the coven (the fight shaping)

A full-strength coven (three night hags, 5,400 XP, three casters of Phantasmal Killer and 4th-level Magic Missile)
is far above High for four level 5 characters. The region is built so the critical path faces one hag at a time:

- Offalia is alone at the oven, and can be removed without a fight (a pastry, a lie) or fought alone.
- Bella can be removed by a pact (plain option) or a lie (Deception 14), or she fights.
- Morgantha never leaves her chair until the last stand; whoever is left joins her (`offalia_in_last_stand`,
  `bella_in_last_stand`, set by her dialogue just before `combat`).
- Ilinca (a wereraven guest) adds a fifth body; the hags' HP are tuned per fight (§7); and the stat block's own AI has
  a hag flee through the Ethereal at a quarter of her HP, which ends her part in the fight.

Ilinca warns plainly; the journal's first stage says "Don't fight all three hags at once"; Morgantha gives a last
chance to back out before the whole coven fights ("Wait. Not like this.").

### 4.2 The children

Ilka (10) and Toma (6) Sarnov, from the Village of Barovia. Their mother bought a basket of pastries a week to dream
of the baby she lost; when the coin ran out, Morgantha took the children "for a season". Ilka scratches days on the
bars and has stopped eating so she won't get heavier. They come out when Morgantha falls or when she's paid, never
otherwise. Where they go (`bonegrinder_children_fate`): **home** (their mother, who sold them, weeps and means it) or
**vallaki** (the Blue Water Inn; Urwin "won't ask questions"). Telling Ilka the truth sets `sarnov_truth_told`.

### 4.3 Morgantha's bargains

`bonegrinder_bargain`: **gold** (150 gp; "their mother let them go for less, if you don't count the honey"),
**dream** (a party member's sweetest dream, drawn out like a splinter; she visits that sleeper now and then, which
the Narrator shows on long rests anywhere until she dies or her soul bags are cut open, when the dream comes home),
**truce** (Persuasion 16: the party's word to leave the mill in peace; breaking it later is narrated), or
**abandoned** (the party leaves the children; quest failure). Any bargain leaves the coven and the trade running.
The party can come back and fight later (`after_bargain`, `kept`).

### 4.4 Bella's pact and the soul bags

Bella's price is the mill. After Morgantha falls she takes the chair and asks for the soul bags too. Keep faith
(`soul_bag_given`, `bonegrinder_fate = "bella"`, Bella sells lighter pastries on the lane afterwards), make her give up
the bags (Persuasion 14, `soul_bag_freed`), or break the pact and kill her (`bella_betrayed`). Without a living
claimant the soul bags are a prop in the loft: cut them open (`soul_bag_freed`).

### 4.5 The dream-pastry trade

Morgantha's cart is the trade. `pastry_trade`: **ended** when all three hags are dead; **dwindling** when Morgantha is
dead and a daughter is loose or holds the mill; **thriving** after a bargain or abandonment. Unset means the party
never settled it. The lane shows it (Morgantha's cart, Bella's cart, ruts greening over); the village and Vallaki
should read it (§10).

## 5. The ways it can end

| | Destroy | Broken | Bella's mill | Bargain | Abandon |
|---|---|---|---|---|---|
| How | Morgantha and both daughters dead (any mix of the bakery, the last stand, betraying Bella, the lane, killing Offalia asleep) | Morgantha dead; a daughter loose (lured, left asleep, fled) | Morgantha dead; Bella's pact kept | gold, dream or truce | "Keep them." |
| Children | freed (milestone) | freed | freed | freed (milestone) | caged (no milestone) |
| `bonegrinder_fate` | `destroyed` | `broken` | `bella` | `bargain` | `abandoned` |
| `pastry_trade` | `ended` | `dwindling` | `dwindling` | `thriving` | `thriving` |
| Afterwards | lane ruts green over; the mill may burn; the sails may turn | the loose daughter on the lane (fight or spare) | Bella's cart on the lane (end it there) | Morgantha still rocking; return to fight | Morgantha "keeping" them; return to bargain or fight |

## 6. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| Ilinca | hill | join, go alone; Persuasion 13 if `raven_harmed` | guest wereraven; intel | she takes the children; `ilinca_vouched` (Keepers: Vallaki, Wizard of Wines); the lane's gift |
| Offalia | bakery | feed (item), lie (Deception 13), fight | `offalia_asleep` / `offalia_lured` / `offalia_slain` | who joins the last stand; a loose Offalia on the lane (send her home: she's back at the oven) |
| Bella | stair / mirror | pact, lie (Deception 14), refuse | `bella_pact` / `bella_fled` | who joins the last stand; who holds the mill; the soul bags |
| The children | loft | buy (gold, dream, word), fight, leave | `bonegrinder_bargain`, `coven_last_stand` | `bonegrinder_fate`, `pastry_trade`, milestone, quest |
| The truth | cages | tell Ilka, or lie | `sarnov_truth_told` | banter; village/Vallaki may read it |
| Where they go | cages | home, Vallaki | `bonegrinder_children_fate` | the village (the Sarnovs) and Vallaki (the Blue Water Inn) |
| Bella's due | loft, after | keep faith, free the bags (Persuasion 14), betray | `soul_bag_given` / `soul_bag_freed` / `bella_betrayed` | `bonegrinder_fate`; Bella on the lane |
| The soul bags | loft | cut open, leave | `soul_bag_freed` | a dream bargain's dream comes home; epilogue |
| The mill | cart shed | burn, leave | `bonegrinder_burned` | the hill's look; the mill door shuts |
| The sails | loft | knock the brake out | `mill_sails_freed` | the hill's look |

## 7. Encounters (2024 DMG budgets for four characters)

Level 5: Low 2,000 / Moderate 3,000 / High 4,400. Level 6: Low 2,400 / Moderate 4,000 / High 5,600. A night hag is
CR 5 (1,800 XP, 112 HP, AC 17, Fire and Cold Resistance, Magic Resistance; Phantasmal Killer 2/day, Magic Missile at
4th level at will; the `spellcaster` AI flees ethereally under a quarter of its HP, which ends its part in the fight).
HP overrides keep each fight inside the band. Ilinca (wereraven, 450 XP) fights on the party's side when she joined.

| id | Map | Trigger | Monsters by variant (HP) | XP, band |
|---|---|---|---|---|
| `bakery_offalia` | mill | Offalia's dialogue, or `open:hag_oven` while she's awake | Offalia: L6+ 100, L5 80, lower 60 (oven trigger: 80) | 1,800 nominal (~1,300-1,600 tuned): Low |
| `coven_last_stand` | loft | Morgantha's dialogue | whole coven (`offalia_in_last_stand` and `bella_in_last_stand`): Morgantha 95, Bella 60, Offalia 60 | 5,400 nominal (~3,900 tuned): High at L5, Moderate at L6. Warned, can be backed out of. |
| | | | one daughter: Morgantha 95 + Offalia 60 or Bella 60 | 3,600 nominal (~2,600 tuned): Moderate |
| | | | **alone (critical path)**: L6+ Morgantha 112 + 3 rat swarms; L5 100 + 2; lower 85 + 1 | 1,950 / 1,900 / 1,850: Low (follows the bakery fight) |
| `bella_betrayed` | loft | Bella's dialogue (after the pact) | Bella: L6+ 100, else 80 | 1,800: Low |
| `bella_on_the_road` | lane | road dialogue | Bella: L6+ 100, else 80 | 1,800: Low |
| `offalia_on_the_road` | lane | road dialogue | Offalia: L6+ 100, else 80 | 1,800: Low |
| lane table `bonegrinder_lane` | lane | travel (day 20%, night 45%) | day: 3 dire wolves + 3 wolves (750); night: a werewolf, 2 dire wolves, 2 wolves (1,200); the dead: 5 Strahd zombies + 2 zombies (1,100); 4 bat swarms + 3 Strahd zombies (800) | under Low: road nuisance |

The critical path fights two lone hags (Offalia, then Morgantha with rats), with a rest possible between them in the
bakery (risky). Nothing in the region requires a check: every split, the pact, the fight and the rescue have plain
options.

## 8. Milestone

One `xp milestone`, in `old_bonegrinder/children:freed`: the moment the children are out of the cages, whether
Morgantha fell or was paid. Leaving the children gives no milestone (coming back later and freeing them does).

## 9. Reading earlier regions

| Flag (owner) | Read by |
|---|---|
| `morgantha_met`, `dream_pastries_bought`, `dream_pastry_eaten`, `morgantha_driven_off` (village) | morgantha (her greeting), road (the cart) |
| `morgantha_suspected`, `bonegrinder_rumor` (village) | set again by road (the cart); `bonegrinder_rumor` puts the mill on the travel map |
| `raven_harmed`, `raven_fed` (Svalich road), `keepers_of_the_feather_met` (Vallaki) | ilinca (cold or warm greeting; Persuasion to join after `raven_harmed`); narrator (the oak) |
| `vallaki_backed` (Vallaki) | road (who buys pastries in Vallaki: Lady Wachter's book club, or the Baron's festivals) |
| `death_house_children_met` (Death House) | banter ("another house with children shut in upstairs") |
| `guest:ireena` | morgantha (the "custom"), banter (her father's basket) |
| `treasure_at:old_bonegrinder` (Tarokka) | ilinca, morgantha, narrator (the oven), mill (won't burn it before the oven is raked) |
| `tarokka.<slot>.region == old_bonegrinder` | travel (the place appears when the reading names it) |

## 10. Flags (data/flags/old_bonegrinder.json) and what later regions should read

All 33 flags are registered, set and read. The ones for other regions:

- **`bonegrinder_fate`** (`destroyed`, `broken`, `bella`, `bargain`, `abandoned`): the epilogue; Strahd's opinion of
  the party; Vallaki and the village.
- **`pastry_trade`** (`ended`, `dwindling`, `thriving`; unset = unchanged): **the Village of Barovia and Vallaki should
  stop showing Morgantha's pastries when it is `ended`, and thin them when `dwindling`** (a Vallaki pastry seller, the
  village square). Lady Wachter's book club (if she rules) loses its supplier.
- **`children_rescued`**, **`bonegrinder_children_fate`** (`home`, `vallaki`), `sarnov_truth_told`: the village (the
  Sarnov family; Mad Mary hears another mother got hers back), Vallaki (two new children in the Blue Water Inn's
  kitchen; Danika and Urwin mention them).
- `morgantha_slain`, `bella_slain`, `offalia_slain`, `bella_pact`, `bella_fled`, `offalia_at_large`: who is still out
  there (a loose hag could turn up anywhere later).
- `bonegrinder_bargain` (`dream` especially): the Amber Temple and the endings may read a party member who sold a
  dream to a hag.
- `soul_bag_freed`, `soul_bag_given`: the epilogue.
- **`ilinca_vouched`**: the Keepers of the Feather (Urwin and Danika in Vallaki; Davian Martikov at the Wizard of
  Wines) know the party freed the children.
- `bonegrinder_burned`, `mill_sails_freed`: the travel map art and later views of the crag.
- Quest: `children_of_the_mill` (`heard`, `bakery_cleared`, `coven_broken` or `bargain_struck`, `children_freed`
  success, `children_abandoned` failure).

## 11. Tarokka and allies

- **Treasure spot:** place `old_bonegrinder` (Glyphs 7 in all three slots of data/tarokka/outcomes.json) →
  `treasure_spots: {"old_bonegrinder": {"container": "hag_oven"}}` in data/locations/old_bonegrinder.json: the treasure
  lies at the back of the great oven, among the ashes, untouched because the hags won't touch it. Opening the oven
  while Offalia is awake starts `bakery_offalia` instead; after she's dealt with it opens normally. Hinted by Ilinca
  ("What else have your ravens seen?"), Morgantha ("keep your fingers out of my oven"), the Narrator (`open:hag_oven`,
  `examine:bonegrinder_oven_fire`) and the burning (blocked until the oven is raked). Reachable on every path (after
  a bargain, Offalia still guards it: feed, fool or fight her).
- **Ally:** none in this region.

## 12. Loot spots

| Container | Where | Contents |
|---|---|---|
| `hag_oven` | bakery | 4 gp (blackened); the Tarokka treasure if the reading put one here |
| `bonegrinder_pastry_rack` | bakery | 6 dream pastries (useful for feeding Offalia) |
| `bonegrinder_pantry_shelf` | pantry | potion of healing, herbalism kit, 3 rations, basic poison |
| `bonegrinder_flour_bin` | grindstone | 2 sacks, 22 gp |
| `bonegrinder_pastry_cart` | hill shed | 4 dream pastries, a basket, 9 gp (sets `pastry_cart_raided`; Morgantha notices) |
| `bonegrinder_hag_hoard` | loft nest, lock 15 | 140 gp, 2 perfume, fine clothes, a level 1 spell scroll |
| `bonegrinder_bella_drawer` | loft, Bella's jewel box | a mirror, perfume, 35 gp |
| search `bonegrinder_bone_heap` (DC 13) | hill | a holy symbol amulet (Brother Kesten's) |
| search `bonegrinder_pantry_jars` (DC 12) | pantry | antitoxin |

The lane's Keepers leave a potion of healing (road `raven_flight`) after Ilinca vouches.

**Fixed Curse of Strahd items:** none needed for this chapter beyond the Tarokka treasure (the coven's soul bags
are story props, not items). **For the DMG magic-item thread:** `bonegrinder_hag_hoard` (the coven's hoard; a good
home for an uncommon or rare item) and `bonegrinder_bella_drawer` (a small trinket-scale item).

## 13. Art and theme needs

- **Portraits and sprites:** `bella_sunbane` (lovely young woman, flour-white hands, red ribbon; true form for the
  combat sprite would be a night hag), `offalia_wormwiggle` (round rosy baker's wife, floury apron, hot tray),
  `ilinca_vrana` (old woman in a black shawl; a raven form), `ilka_sarnov`, `toma_sarnov` (thin Barovian children).
  Morgantha's existing art covers her; a night-hag true-form sprite for all three would serve the fights.
- **Props** (stand-ins from art/sprites/props/catalog.json used now; wanted art in brackets): the sails `winch`
  [`windmill_sails`, which can burn], the millstone `rocks` [`millstone`], the soul bags `charms` [`soul_bags`],
  the receipt book `book` (lectern) [`receipt_book` lying on a table], the brake `winch` [`gear_brake`]. Everything
  else uses fitting existing art (`stove`, `rocking_chair`, `dressing_table`, `cage`, `bones`, `cart`, `flame`, ...).
- **Theme:** the hill uses `village` so the mill and the shed are built as houses; a **`hilltop` / windmill theme**
  (grass and rock floor, scree for `~`, the mill as a round stone tower with sails instead of a gabled house) would
  fit better. The mill interior uses `house`; a round-walled **`mill`** interior would be nicer.
- **Travel map:** the windmill landmark at (0.69, 0.24) is already on the parchment art.

## 14. The critical path (what a test bot does)

Setup: four pregens at level 5, 9:00, with `bonegrinder_rumor` set (or start at `old_bonegrinder_hill`). The bot's
`prefer` list, in order:

```
"Fly with us. We're going in."                       (ilinca: join)
"Step away from the oven, Offalia. Now."            (offalia: bakery_offalia)
"Deal. Stay out of it, and the mill is yours."      (bella: pact)
"Then we'll take them from you."                    (morgantha: coven_last_stand, Morgantha alone + rats)
"A deal's a deal. The mill and the bags are yours." (bella: inheritance)
"Tell her the truth: yes, she did."                 (children: freed, the milestone)
"Take them home to the village."                    (children: destination)
```

and `avoid`: `"Keep them"`, `"Take mine"`, `"We'll buy them back"`, `"Strike her down"`, `"We're leaving"`,
`"Wait. Not like this"`, `"No deals with hags"`, `"Leave her to her baking"`, `"Our deal ends here"`.

Steps: `go_to("old_bonegrinder_hill")` (Ilinca speaks on approach, else `talk("ilinca_vrana")`) →
`go_to("old_bonegrinder")` (Offalia speaks on approach; fight) → settle (Bella approaches from the stair, else
`talk("bella_sunbane")`) → `go_to("old_bonegrinder_loft")` (Morgantha speaks on approach; fight) → settle (Bella's
inheritance and Ilka's rescue fire on approach; else `talk("bella_sunbane")`, `talk("ilka_sarnov")`).

Expected flags: `offalia_slain`, `bella_pact`, `morgantha_slain`, `children_rescued`, `bonegrinder_fate == "bella"`,
`pastry_trade == "dwindling"`, `bonegrinder_children_fate == "home"`, quest `children_of_the_mill == children_freed`,
one milestone. For the **destroy** ending, prefer `"Our deal ends here, Bella. So do you."` instead (adds
`bella_betrayed`, Bella alone at 80 HP) → `bonegrinder_fate == "destroyed"`, `pastry_trade == "ended"`. For the
**bargain** ending, prefer `"The children. Let them go."` and `"We'll buy them back. (150 gp)"` (needs 150 gp) →
`bonegrinder_fate == "bargain"`, the milestone without the last stand.

## 15. Needs outside this package

- **Engine:** none required. Nice to have: a "the party's guest leaves with an escort" beat (today Ilinca just
  `leave`s); a per-character mark for the dream bargain (which party member paid) so the Narrator can name them on
  rests; flags read in random-table `when`s aren't counted by the validator as reads (harmless here).
- **Other regions (hooks, not edits):** Village of Barovia (Morgantha's cart and the Sarnov house should read
  `pastry_trade`, `children_rescued`, `bonegrinder_children_fate`); Vallaki (Urwin/Danika and two children at the inn
  for `bonegrinder_children_fate == "vallaki"`; Arasek's or the herald's news; Lady Wachter's book club and
  `pastry_trade`); Wizard of Wines (the Martikovs read `ilinca_vouched`); endings (`bonegrinder_fate`,
  `bonegrinder_bargain == "dream"`, `soul_bag_freed`).
- **Monsters:** only `night_hag`, `wereraven`, `swarm_of_rats`, `commoner` and the lane's wolves, werewolf, zombies
  and bats, all in data/monsters.

## 16. Files

- Region: docs/regions/old_bonegrinder.md (this file; §2 holds the new NPCs' voice notes)
- NPCs: data/npcs/{bella_sunbane, offalia_wormwiggle, ilinca_vrana, ilka_sarnov, toma_sarnov}.json; data/npcs/
  morgantha.json (summary and tags updated)
- Quest: data/quests/children_of_the_mill.json
- Flags: data/flags/old_bonegrinder.json
- Locations: data/locations/{old_bonegrinder_hill, old_bonegrinder, old_bonegrinder_loft, old_bonegrinder_track}.json
- Travel: data/travel/old_bonegrinder.json (place `old_bonegrinder` at (0.69, 0.24); roads from the village and the
  Ivlis crossroads, 2 hours each, table `bonegrinder_lane`)
- Random table: data/random_encounters/bonegrinder_lane.json
- Dialogue: narrative/old_bonegrinder/{ilinca, offalia, bella, morgantha, children, aftermath, mill, road}.dialogue;
  narrative/narrator/old_bonegrinder.dialogue; narrative/banter/old_bonegrinder.dialogue
