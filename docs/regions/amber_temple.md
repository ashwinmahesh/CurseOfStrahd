# Region design: the Amber Temple and its dark gifts (Phase 5, region 10)

Plan §6 row 10. The party arrives at level 9 or 10 (after Berez and the Tsolenka Pass) and leaves one level higher
(one `xp milestone`, §8). Source: *Curse of Strahd* chapter 13, retold in our own words; every vestige's gift, its
price, and every line here are ours. Implementation reads this doc; the data and dialogue files in §16 are the source
of truth for exact text.

## 1. What this region is for

**Accepting dark gifts with lasting mechanical costs** (plan §6). High above the Tsolenka Pass, in the ice of the
mountain, an order of wizards (the wardens) once gathered the vestiges, the last embers of dead gods and worse, and
sealed each one in a sarcophagus of amber, the only thing that holds them. A prison where the prisoners can talk
becomes, given a few centuries, a market. The wardens listened, one by one, and the temple fell.

The region is a dungeon of temptations. Sixteen sarcophagi talk; each offers a gift that solves a real problem and
costs something real and permanent (data/dark_gifts, §4.3). Under them lies the empty sarcophagus of the Thirst, the
thing that went into a prince of the west four centuries ago, and beside it the copper record of his bargain. The
climax is the broker of that bargain, the arcanaloth Vosk, offering the party the same deal.

It also pays off threads from earlier regions: **Kasimir Velikov's sister Patrina** (Vallaki), the **Tome of
Strahd** (read beside the pact), Silvain's lost friend **Aurel**, Hedda's lost dawn, Ilse's lost company, Tamsin's
woman in the locket, Doru's promised cure (village), and what the party did on the Death House altar.

Tone: one of the game's three scariest places (plan §5.7). The vestiges are funny only through character (five heads
arguing, a mouth of borrowed voices) and several aren't funny at all. The comedy lives upstairs with **Exethanter**,
the forgetful lich, and even there it has a sad floor: he is being eaten by his own bargain.

## 2. Who's here, what they want, how they talk

Voice bibles: docs/voice/{exethanter, vosk, patrina_velikovna, amber_vestiges}.md.

| NPC | Wants | Offers | Price / secret |
|---|---|---|---|
| **Exethanter** (`exethanter`, stat block `exethanter`), the last warden, a lich | to remember what he's for; his phylactery ("something with a lid"), hidden so well he lost it | the wardens' word (for the asking), the jackal's true name (once his phylactery is back, or held over him), his memory of Strahd (if shown the ledger), the sealing rite | traded his memory to Norganas to stop hearing the whispers; he let the prince in and showed him the way down |
| **Master Vosk** (`vosk`, an `arcanaloth`), "a scholar of the temple" | a second vessel for the Thirst; his commission on every gift | the Second Thirst (`gift_of_the_hollow`): to become what Strahd is | a fiend broker; witnessed Strahd's pact; true name **Ashkarreth** binds him |
| **Patrina Velikovna** (`patrina_velikovna`, a `banshee`), Kasimir's sister | to hear her brother say it; not to be bought back | nothing | the stones hurt less than the silence afterward |
| **The Amber Sentinel** (`amber_sentinel`, an `amber_golem`) | to keep the wardens' rule | entry to anyone | stops anyone leaving with a gift, unless it hears the wardens' word |
| **The vestiges** (`vestige_<name>`, speakers only) | each its one idea: adoration, war, hunger, the dark... | a dark gift each | the cost, always named if asked; the wardens' lid inscription (History 13) warns plainly |
| **Kasimir Velikov** (Vallaki's NPC, guest only if the Tarokka's Seer names him) | Patrina back; to stop being a coward | | at Tarakamedes he can trade every year he has left but one for her life |

How they talk, in one line each: Exethanter is courtly and loses his sentences ("Have we met? You have the look of
people I've met."); Vosk talks like a notary ("People never read the terms."); Patrina is proud and cutting ("Three
centuries, and it took you one breath."); the Sentinel speaks in capitals (SPEAK THE WORD. NOTHING LEAVES.).

## 3. Layout and scenes

Five maps (data/locations/). Themes: `dungeon` for the temple (the doors map is `outdoors` for the sky and the day),
`wilderness` for the ice stair. A dedicated `amber_temple` theme is an art need (§13).

| Map | Areas (enter: triggers) | What happens |
|---|---|---|
| `amber_temple_entrance` (32 x 26) | `snow_ledge`, `ice_stair`, `vestibule`, `west_guardroom`, `east_guardroom` | Arrival from the pass (spawn `from_pass`, exit `down_to_the_pass` → travel). The two colossi: one split (prop), one the Sentinel (NPC, approach). The great doors, the frozen traveller just inside (**Tarokka spot**: `pilgrims_pack`), two guardrooms (the frozen watch, wights, east). A snow cornice over the drop (trap). No rest. |
| `amber_temple_faceless_god` (40 x 29) | `south_gallery`, `great_hall`, `ring_of_amber`, `hall_of_echoes`, `wardens_cells` | The colossal statue with no face and the offerings at its feet (**Tarokka spot**: `statue_offerings`; a gaze trap on the step before it). East: the ring of amber, six sarcophagi and the hollow-eyed seekers (fight). West: the hall of echoes, Patrina (approach). North: the wardens' cells (loot, a frost vent), the library passage and the stair down. Risky rest. |
| `amber_temple_library` (30 x 20) | `library_stacks`, `reading_room`, `restricted_stacks`, `exethanter_study` | Vosk reading in the stacks (approach, once). The reading room's books: the wardens' charter, the visitors' ledger (Strahd and Exethanter), a treatise on amber. The barred alcove (iron gate, DC 18) and its chained case (the wardens' flameskulls). Exethanter's study: his wall of notes (Investigation 15), the jar labelled NOT THE PHYLACTERY (search DC 13). Risky rest. |
| `amber_temple_vault` (40 x 30) | `vault_stair`, `hall_of_vestiges`, `treasure_vault`, `sanctum` | Black ice on the stair (trap). The hall of vestiges: ten sarcophagi, a warding glyph line (trap), an empty plinth, a dead sarcophagus. The honey-glow doors (prop `honey_door_seal`) and their guardian; the vault of offerings (**Tarokka spot**: `gift_heap`; falling amber trap). The sanctum: the hollow sarcophagus, the copper pact ledger, Vosk (approach), later Exethanter (approach). No rest. |
| `amber_temple_road` (30 x 16) | `switchbacks` | The battlefield for the climb's random fights and events (data/random_encounters/amber_temple_road.json). |

### The flow (every step optional except the climax)

1. **The doors** (§4.1). The Sentinel asks for the word. Nobody needs it to get in.
2. **The great hall**: the faceless god and its offerings; the ring of amber (the first voices, a fight); the hall of
   echoes (Patrina, §4.4).
3. **The library** (§4.2): Vosk, the books, Exethanter and the thing with a lid.
4. **The vaults** (§4.5): ten more voices, the honey-glow doors, the vault of offerings.
5. **The sanctum** (§4.6, the climax): the hollow, the pact ledger, Vosk's offer; banished, paid or destroyed.
6. **The revelation** (the milestone), Exethanter's rite (seal the temple or not), and **the way out** past the Sentinel,
   who stops anyone carrying a gift who hasn't the word.

## 4. The threads

### 4.1 The doors and the Amber Sentinel

`amber_temple/sentinel`. On first approach (`arrival`, approach 5) the surviving colossus turns its head: SPEAK THE
WORD. History 17 reads the word off the lintel (`warden_word_known`, `sentinel_stilled`); Arcana 16 shows its ward
faces inward (it was built to keep things in); without either, "ALL MAY ENTER", and it says nothing about leaving.
Striking it starts `sentinel_wakes`.

**Leaving with a gift**: once anyone carries a dark gift (`dark_gifts_taken >= 1`) and the Sentinel is neither stilled
nor destroyed, it speaks first as the party comes to the doors (`departure`): the word stills it; Arcana 18 unpicks its
ward; anything else is a fight. Stepping onto the ledge without settling it starts `sentinel_stops_you`. The word comes
from the lintel, Exethanter, or his notes. This is the temple's first cost: whatever you take, you fight your way out
with it, or you learned the word.

### 4.2 Exethanter and the thing with a lid

`amber_temple/exethanter`, `amber_temple/library`. A lich in a tea-coloured robe pinned all over with notes, who greets
the party as strangers every visit unless they pin "These are friends" to his sleeve (`exethanter_note_given`).

- **The word**: ask about the colossus or the glowing doors and he finds it pinned to his robe (no check).
- **The lid** (quest `something_with_a_lid`): he has lost his phylactery. It is in a jar on his own top shelf labelled
  NOT THE PHYLACTERY (search prop `exethanter_jar`, DC 13). Return it (`exethanter_phylactery = "returned"`, friendly:
  the word, and the jackal's note when asked about Vosk), keep it (`kept`: he cooperates, the same help, colder), or
  smash it (`smashed`: he thanks you, withdraws, no sealing rite, no help in the sanctum).
- **His notes** (Investigation 15, one try): the word, and THE JACKAL IN THE STACKS IS NOT A SCHOLAR. HIS NAME IS
  ASHKARRETH (`vosk_named`).
- **His bargain**: Norganas's lid and its own voice reveal that Exethanter asked it to take the whispering and it never
  stopped taking (`exethanter_bargain_known`). "It isn't age at all. It's interest."
- **His secret**: the visitors' ledger (book prop, `visitors_ledger_read`) has his signature under "He asked for the
  deep vault. God help us, I showed him." Shown it, he remembers the polite young prince (`exethanter_strahd_told`), and
  asks to forget again; the party can let him (comic and kind) or ask him to keep it (`exethanter_remembers`: he writes
  it on his hand, and says so in the sanctum).
- Attacking him starts `exethanter_wrath` (him and two flameskulls).

### 4.3 The dark gifts (the centrepiece)

Sixteen sarcophagi, each a node in `amber_temple/vestiges`, each a vestige NPC speaker. Every node: sealed (silent) /
its gift already carried (a short "sated" line) / heard before (a short greeting) / first hearing (the Narrator
describes the shape in the amber; the voice makes its pitch). Its menu: what it wants, what it offers, the price, the
wardens' lid inscription (History 13), and personal hooks. "No." comes before "I accept." in every menu. Accepting runs
`dark_gift <id>`: the player picks who takes it, or "No one" (the engine shows the gift's `summary`, which states the
price). Taking one sets `dark_gifts_taken += 1`. A gift can't be undone; benefit and cost both live in the build.

| Vestige (where) | Gift (id) | Benefit | Price | Engine |
|---|---|---|---|---|
| Zantras, who crowned beggars (ring) | The Crown of Zantras (`gift_of_zantras`) | Cha +4 (max 22) | Disadvantage on Stealth and Insight; must be the one watched | data |
| Fekre, the mother of fevers (ring) | Fekre's Fever (`gift_of_fekre`) | immune to poison and Poisoned; Blight 1/long rest (Con) | Cha -2; healing does half to you; sickness follows you | partial (halved healing is text) |
| Great Taar Haak (ring) | The Five Throats (`gift_of_taar_haak`) | Str +4 (max 22); +1 HP per level | Int -2; Disadvantage on Wis saves; can't stop at surrender | data |
| Shami-Amourae, the honeyed hand (ring) | The Honeyed Hand (`gift_of_shami_amourae`) | Advantage on Persuasion; Charm Monster 1/long rest | Disadvantage on saves vs Charmed; can't refuse a pleasure | data |
| Yog, the unbroken (ring) | Yog's Hide (`gift_of_yog`) | resistance to bludgeoning, piercing, slashing | Speed -10, Dex -2; no feeling in the skin | data |
| Drizlash (ring) | The Eyes of Drizlash (`gift_of_drizlash`) | climb 30 ft, darkvision 120, Web PB/long rest | Cha -2; four extra eyes; sunlight Disadvantage | partial (sunlight is text) |
| Khirad, who reads the stars backward (vault) | The Backward Stars (`gift_of_khirad`) | Advantage on Initiative, passive Perception +5, Clairvoyance 1/long rest | -1 HP per level; endless visions | data |
| Norganas, the eraser (vault) | The Eraser's Finger (`gift_of_norganas`) | Finger of Death 1/long rest (Cha) | Int -4; each casting takes a loved memory | data |
| Savnok, the locked mouth (vault) | The Locked Mouth (`gift_of_savnok`) | can't be Charmed; Advantage on Deception | Disadvantage on Persuasion, passive Perception -5; no true word about yourself | data |
| Seriach, master of the burning hounds (vault) | The Hounds' Leash (`gift_of_seriach`) | fire resistance; +1d6 fire on weapon hits | vulnerability to cold; Disadvantage on Animal Handling | data |
| Sykane, the hollow belly (vault) | The Hollow Belly (`gift_of_sykane`) | Vampiric Touch PB/long rest; necrotic resistance | -1 HP per level; no Hit Dice on a day you haven't fed | partial (Hit Dice rule is text) |
| Tarakamedes, the dragon in the grave (vault) | The Grave Wyrm's Claim (`gift_of_tarakamedes`) | Animate Dead and Speak with Dead 1/long rest; cold resistance | Disadvantage on every death saving throw | data |
| Tenebrous, the last shadow (vault) | The Last Shadow (`gift_of_tenebrous`) | darkvision 120, Advantage on Stealth, Darkness PB/long rest | vulnerability to radiant | data |
| Yrrga, the eye that opened outside (vault) | The Outside Eye (`gift_of_yrrga`) | truesight 30 ft | Wis -2; Disadvantage on saves vs Frightened | data |
| Zhudun, the dead star (vault) | The Dead Star's Light (`gift_of_zhudun`) | radiant resistance; Hunger of Hadar 1/long rest | Con -2; vulnerability to fire; a grey glow | data |
| Dahlver-Nar, the mouth of borrowed teeth (vault) | A Mouth of Borrowed Teeth (`gift_of_dahlver_nar`) | +2 HP per level; Advantage on death saves | Cha -2; Disadvantage on Persuasion; borrowed teeth and voices | data |
| The Thirst (sanctum, offered by Vosk) | The Second Thirst (`gift_of_the_hollow`) | Str and Con +2, darkvision 120, necrotic resistance, +1 HP per level, +1d6 necrotic on weapon hits | radiant vulnerability; sunlight burns; the lord of the valley knows you; bound to Barovia | partial (sunlight, running water, being bound are text; Phase 6 endings read it) |

Spells a gift grants are both a `spell` modifier (with its uses and ability, which the engine reads today) and listed
in the gift's `spells` (for the sheet). **Personal hooks** (option tags and interjections): Ireena at Zantras;
Tamsin's locket at Shami-Amourae; Silvain's Aurel at Khirad (with Madam Eva's answer if `eva_question == "aurel"`);
Exethanter's bargain at Norganas; the Death House sacrifice at Sykane (`death_house_sacrificed`); Ilse's company and
Doru's cure (`doru_cure_promised`) and Kasimir's sister at Tarakamedes; Hedda's lost dawn at Zhudun.

### 4.4 Patrina and Kasimir

`amber_temple/patrina` (hall of echoes, approach 6) and `vestiges:tarakamedes_kasimir`. Quest `patrinas_wail`.

- Patrina wails over a crumbling book. Who she is (Insight 14: it's the crowd she can't forgive, and one face at the
  back). If Kasimir told the party of her in Vallaki (`kasimir_sister_told`), they can name her (`patrina_named`).
- **Without Kasimir**: tell her he grieves and Persuasion 15 ("he's been too afraid; that's the only thing he's ever
  been") → at rest; Religion 16 (the old words for the dead) → at rest; failing Persuasion, she starts to wail (back
  away or fight). `patrina_fate = "rest"`.
- **With Kasimir** (`guest:kasimir_velikov`, the Seer's ally): he faces her. Persuasion 13 helps him find the words, or
  he finds his own: "I let them, Patrina. Because I was afraid of being you." She lets go (`kasimir_at_peace`, rest).
- **Kasimir's bargain**: at Tarakamedes, before she is at rest, he can trade every year he has left but one for her
  life. Let him choose → `kasimir_bargain = "made"`, `patrina_fate = "restored"`: his hair goes grey, the wailing
  stops, and bare footprints lead out of the temple toward the castle. Persuasion 15, or "You heard her" (if met),
  talks him out of it (`refused`). Suggesting it to her face makes her forbid it.
- **Fight**: `patrina_wails` (Patrina and four frozen students, specters) → `patrina_destroyed`.

### 4.5 The vaults and the honey-glow doors

`amber_temple/vault:honey_door`. The doors (`honey_doors`, `when: flag.honey_door_opened`) open to the wardens' word, or
Arcana 17 (clean). Strength 20, a failed attempt pressed on, or a bleeding hand (no check) force them
(`honey_door_forced`): the guardian golem in the alcove wakes (`vault_guardian`). Behind them the vault of offerings,
everything anyone ever brought down to bargain with (the Tarokka spot, loot, a falling-amber trap).

### 4.6 The sanctum (the climax) and the broker

`amber_temple/vosk:sanctum` (approach 7). Vosk waits by the hollow sarcophagus, the empty amber of the Thirst. He
explains: the prince stood here and asked for time; the Thirst went into him; the amber has room for one more. Arcana
16 sees the thread from the hollow to the valley. His offer: lie down in the amber (`gift_of_the_hollow`).

| Choice | Result | `vosk_fate` / flag | Quest stage |
|---|---|---|---|
| "Ashkarreth." (true name known) → "Leave this temple..." | bound; he walks into the hollow and is gone for good | `banished` | `broker_banished` |
| "Ashkarreth." → strike while bound | `vosk_unmasked` at 80 HP | `vosk_destroyed` | `broker_destroyed` |
| "We'll take nothing from you." | the jackal unmasks: `vosk_unmasked` | `vosk_destroyed` | `broker_destroyed` |
| Deception 18 (step aside at the last moment) | the hollow eats his shadow: weakened fight | `vosk_weakened`, then `vosk_destroyed` | `broker_destroyed` |
| "(Lie down in the amber.)" + a member accepts | the Second Thirst; he leaves smiling | `paid`, `dark_gifts_taken += 1` | `broker_paid` |

The copper **pact ledger** (prop) records the terms in two hands, the wardens' and Strahd's: "one life he loves, given by
his own hand on the day he most wants to be happy"; the Thirst lives in him and he in it, and he and his land are one
thing until the end of both; witnessed by Exethanter and a sketch of a jackal's head (`strahd_pact_known = "ledger"`).
**With the Tome of Strahd** in the party's hands, his own account of the climb sits beside it: he bargained not to
live forever but to stop growing older than her (`strahd_pact_known = "full"`).

**The revelation** (`vault:revelation`, the milestone) follows every outcome: from Vosk's banishing or payment
directly, after the fight when Exethanter comes down to sweep (approach 8, `vault:aftermath`), or from the hollow
sarcophagus prop. Then Exethanter offers the wardens' last rite: **seal the temple** (`amber_temple_sealed`: every
sarcophagus goes dark for good; gifts already given stay) or leave it open.

## 5. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| Dark gifts (each) | the 16 sarcophagi, the hollow | accept (who), refuse | permanent benefit and cost in the build; `dark_gifts_taken` | the Sentinel blocks the way out; Exethanter, Vosk, banter, rests react; Phase 6 endings (`gift:gift_of_the_hollow`, the count) |
| The wardens' word | lintel, Exethanter, notes | learn it or not | stills the Sentinel, opens the honey doors cleanly | leaving with gifts without a fight |
| The phylactery | Exethanter's shelf | return, keep, smash | his attitude; the jackal's name | his help in the sanctum and the sealing rite; Phase 6 / epilogue |
| Exethanter's memory | the ledger | let him forget, make him remember | his line in the sanctum | epilogue |
| Patrina | hall of echoes | rest (word, prayer, Kasimir), restore (Kasimir's bargain), fight | `patrina_fate`, `kasimir_bargain`, `kasimir_at_peace` | Phase 6: a living Patrina at the castle, or her bones at peace; Kasimir has one year left |
| The honey doors | vault | word, Arcana, force, blood | the guardian wakes or not | |
| The broker | sanctum | banish, fight, trick, pay | `vosk_fate` / `vosk_destroyed` | Strahd's scenes (Phase 6): his witness is gone, or one of the party carries his Thirst |
| The pact | sanctum | read it (with or without the Tome) | `strahd_pact_known` | Phase 6: an option against Strahd ("we know what you paid") and the endings |
| Seal the temple | sanctum, after | seal, leave open | silence | the epilogue; no more gifts |

## 6. Quests

| Quest | Stages | Set by |
|---|---|---|
| `the_amber_temple` | `arrived` → `voices_heard` → `broker_met` → `hollow_found` → `broker_banished` / `broker_destroyed` / `broker_paid` → `pact_learned` (success) → `temple_sealed` (success) | sentinel, vestiges, vosk, vault, encounter `vosk_unmasked` |
| `something_with_a_lid` | `asked` → `found` → `returned` / `kept` (success) / `smashed` (failure) | exethanter, library |
| `patrinas_wail` | `heard` → `named` → `at_rest` (success) / `restored` (failure) / `destroyed` (success) | patrina, vestiges, encounter `patrina_wails` |

Stage moves that could run backward are guarded (`if not quest.the_amber_temple >= <stage>`).

## 7. Encounters (2024 DMG budgets for four characters)

Level 8: Low 4000 / Moderate 6800 / High 8400. Level 9: 5200 / 8000 / 10400. Level 10: 6400 / 9200 / 12400. Variants
share an id; the first whose `when` holds is the fight. Guests (Kasimir, Ireena) make each easier.

| id | Map | Trigger | L10 | L8-9 | Lower |
|---|---|---|---|---|---|
| `sentinel_wakes` | doors | dialogue (strike it; failed ward) | amber golem + 2 gargoyles (6800, Low+) | amber golem (5900, Low+ at 9) | golem at 130 HP |
| `sentinel_stops_you` | doors | enter `snow_ledge` carrying a gift, Sentinel not stilled | amber golem (5900) | same | same |
| `frozen_watch` | doors | enter `east_guardroom` | 4 wights (2800) | 3 wights (2100) | same |
| `hollow_eyed` | great hall | enter `ring_of_amber` | 5 nothics + 3 wraiths (7650, Low+) | 4 nothics + 3 wraiths (7200, Low+ at 9, Moderate at 8) | 4 nothics + wraith (3600) |
| `patrina_wails` | great hall | dialogue | Patrina (banshee, 110 HP) + 4 specters (1900; her Wail is the danger) | same | same |
| `library_wardens` | library | open `restricted_case` | 4 flameskulls (4400) | 3 flameskulls (3300) | same |
| `exethanter_wrath` | library | dialogue (attack him) | Exethanter + 2 flameskulls (8100, Moderate at 9) | same | same |
| `vault_guardian` | vaults | `flag:honey_door_forced` | amber golem + wraith (7700, Low+) | amber golem (5900) | same |
| `vosk_unmasked` (climax) | vaults | dialogue | arcanaloth at 104 HP + 2 flameskulls (10600, Moderate+) | arcanaloth at 104 HP + flameskull (9500, Moderate+ at 9, High at 8; Vosk kept at the old 104 HP since the 2025 arcanaloth's 175, 2026-10-06) | arcanaloth at 85 HP; named or weakened: 80 HP alone |

Random (data/random_encounters/amber_temple_road.json, map `amber_temple_road`, 25% day / 45% night): a whiteout
(Survival 15, else hours lost), the frozen expedition (once: loot or rites), five gargoyles off the cliffs (2250), the
frozen climbers at night (3 wights + 2 wraiths, 5700, Low+ at 9).

The critical path's only fight is the climax; the rest are optional or avoidable (the word, the side rooms, the case).
Traps: snow cornice (DEX 14, 4d10 + prone), frost vent (CON 15, 4d8 cold), the faceless gaze at the statue's feet (WIS
15, 3d8 psychic + frightened), warding glyphs (WIS 16, 4d8 psychic), falling amber in the vault (DEX 15, 4d10), black
ice on the vault stair (DEX 13, 2d6 + prone). **The cold**: the doors and the vaults can't be rested in, the hall and
the library are risky, and the Narrator's rest lines carry the voices (§13 asks for an exposure rule).

## 8. Milestone

One `xp milestone` (`vault:revelation`, guarded by `amber_milestone_given`), at the bottom of the temple after the
broker is dealt with, by any outcome. A party at 9 leaves at 10; at 10, leaves at 11 (the cap).

## 9. Reading earlier regions

| Flag (owner) | Read by |
|---|---|
| `tsolenka_gate_open` (Berez) | travel place `amber_temple` (`when`); Berez's road to the temple uses it too |
| `kasimir_sister_told` (Vallaki), `guest:kasimir_velikov` (the Seer) | travel place, patrina, sentinel, vestiges (Tarakamedes), vosk, banter, Narrator |
| `death_house_sacrificed` (Death House) | vestiges (Sykane) |
| `doru_cure_promised` (village) | vestiges (Tarakamedes) |
| `eva_question` (Svalich Road) | vestiges (Khirad, Silvain's Aurel) |
| `stanimir_tale_heard` (Svalich Road) | vault (the pact) |
| `guest:ireena`, `item:tome_of_strahd`, `tarokka.*.region == amber_temple`, `treasure_at:<spot>` | vestiges, vosk, vault, travel, Narrator |

## 10. Flags (data/flags/amber_temple.json) and what later regions read

59 flags, all set and read (`make validate`). For Phase 6 (the castle, the endings):

- **`strahd_pact_known`** (`ledger` / `full`): the party knows the terms (and, with the Tome, why). An option against
  Strahd; the endings.
- **`gift:gift_of_the_hollow`** (one of them carries the Second Thirst) and **`dark_gifts_taken`** (the count): the
  "darker bargains" ending (plan §5.5); Strahd's attitude (a rival, or an heir).
- **`vosk_fate`** (`banished` / `paid`) / `vosk_destroyed`: Strahd's broker is gone or paid.
- **`patrina_fate`** (`rest` / `restored`) / `patrina_destroyed`, **`kasimir_bargain`** (`made`: one year left),
  `kasimir_at_peace`: Patrina's bones in the castle crypts are quiet (rest), or she is alive at the castle (restored);
  don't place her banshee in the castle as well.
- `exethanter_phylactery` (`returned` / `kept` / `smashed`), `exethanter_destroyed`, `exethanter_remembers`,
  `amber_temple_sealed`: the epilogue.
- Quests: `the_amber_temple`, `something_with_a_lid`, `patrinas_wail`.

## 11. Tarokka places and the ally

| Place (data/tarokka/outcomes.json) | Cards | Location (treasure_spots) | Spot |
|---|---|---|---|
| `amber_temple_entrance` ("past the amber guardians at its doors") | stars_5 | `amber_temple_entrance` | container `pilgrims_pack`: the frozen traveller just inside the doors, who got past the colossi and no further |
| `amber_temple_faceless_god` ("a great statue whose sculptor never finished the face. Look at its feet.") | swords_7 | `amber_temple_faceless_god` | container `statue_offerings` at the statue's feet (the faceless gaze trap is the step in front) |
| `amber_temple_vault` ("behind a door that glows like honey... the gifts of forgotten gods lie heaped up") | glyphs_8 | `amber_temple_vault` | container `gift_heap` in the vault behind the honey-glow doors |

The location ids are the place ids, so the outcomes' `place` values resolve as locations. The Narrator hints with
`treasure_at:` (the statue; the honey doors). **Ally card: none** in this region. Kasimir (the Seer) joins in Vallaki;
here he pays off (§4.4).

## 12. Loot

Mundane loot and gold in every container (cold-weather gear, potions, holy water, scholar's kit, 1,149 gp in all).
Fixed Curse of Strahd items: none placed as story items here beyond the Tarokka treasures (the three treasure items
already exist). **For the DMG-items thread** (containers that should receive the chapter's magic): `watch_chest`
(doors, east guardroom, locked 15), `warden_cell_locker` (great hall, locked 14), `restricted_case` (library, guarded by
the flameskulls: the place for spell scrolls of levels 3 to 6 and a wizard's item), `gift_heap` and `offering_urns`
(vault of offerings: the richest hoard, an offering from every century), `statue_offerings`. **Item needs**: spell
scrolls above level 1 (only `spell_scroll_cantrip` and `_level_1` exist; the restricted case and the wardens' locker
hold level 1 scrolls as stand-ins), gems and art objects as items (gold stands in), and the copper pact ledger as a
codex entry (it is a prop conversation today).

## 13. Art and theme needs

- **Theme `amber_temple`**: black stone veined with faintly glowing amber, frost on every surface; snow on the
  outdoor ledge; ice for `~` (the doors map uses `dungeon` + `outdoors`, the road uses `wilderness`). A snowdrift
  dressing for `~` outdoors.
- **Props** (stand-ins in use): an amber sarcophagus with a shape inside (`coffin` now; sixteen silhouettes would be
  ideal, one per vestige), the hollow sarcophagus (`crypt`), the colossi of amber, whole and split (`statue_knight`),
  the faceless god (`statue_knight`), the honey-glow doors (`door_double`), a stone lectern with a copper book
  (`lectern` via `book`), a frozen traveller (`bones`), a jar labelled NOT THE PHYLACTERY (`jars`), Exethanter's wall of
  notes (`letters`), cold braziers lit green (`brazier`).
- **Portraits and sprites**: `exethanter` (moods neutral, sad), `vosk` (neutral, smile; and an unmasked jackal
  portrait), `patrina_velikovna` (neutral, angry; translucent, stone scars), `amber_sentinel` (a Large sprite: a hooded
  amber colossus), `vestige_amber` (one shared portrait: a glow in amber).
- **Effects**: amber glow light (the `magic` light kind is used), grey corpse-light for Zhudun's bearer, green fire for
  the flameskulls and braziers.

## 14. The critical path (story bot)

Party of four at level 9 (`tsolenka_gate_open` set, or start at `amber_temple_entrance`, spawn `from_pass`).

1. Travel to `amber_temple` (the road is Berez's `tsolenka_pass_to_amber_temple`).
2. Walk to the doors; the Sentinel speaks: **"We don't know any word."** (no fight).
3. Open `pilgrims_pack` at (19, 8) (Tarokka spot).
4. `go_to("amber_temple_faceless_god")`; open `statue_offerings` at (19, 10) (Tarokka spot; trap on the step in front).
5. `go_to("amber_temple_library")`; if Vosk speaks first, any options end at **"Goodbye."**; `talk("exethanter")`:
   **"The colossus at the doors asked us for a word."** (then the menu ends at "Goodbye, warden.").
6. `go_to("amber_temple_vault")`; use the seal at (21, 8): **"Speak the wardens' word."**; open `gift_heap` at (21, 2)
   (Tarokka spot; a falling-amber trap on the way in).
7. Walk to (19, 20); Vosk speaks: **"What are you offering?"** → **"We'll take nothing from you."** → `vosk_unmasked`
   (arcanaloth + flameskull at 9). Win.
8. Exethanter comes down (approach): `vault:aftermath` → the revelation (**milestone**) → **"Seal it. Nobody should ever
   bargain here again."** If he doesn't come, use the hollow sarcophagus at (19, 26).
   Expect `amber_milestone_given`, quest `the_amber_temple` at `pact_learned` or `temple_sealed`, `vosk_destroyed`.

Prefer: `["We don't know any word.", "The colossus at the doors asked us for a word.", "Speak the wardens' word.",
"What are you offering?", "We'll take nothing from you.", "No one", "Seal it."]`. Avoid: `["Draw steel", "Attack",
"Strike", "Smash", "Lie down in the amber", "I accept", "Keep at it", "bleeding hand"]`. At any dark-gift pick the bot
should choose **"No one"** (the last entry). With no gift taken, the Sentinel lets them leave.

## 15. Engine needs the format can't express

- **Dark gift costs the engine can't apply yet**: halved healing received (Fekre), sunlight penalties for characters
  (Drizlash, the Hollow: Disadvantage, radiant damage per turn), no Hit Dice on an unfed day (Sykane), being bound to
  the valley and running water (the Hollow). Each gift says so in `implemented`.
- **`spells` and `spell` modifiers**: a gift's spells are listed in both; the engine reads the modifiers. If it ever
  reads `spells` too, it must not grant them twice.
- **Gifts for guests**: `dark_gift` offers party members only, so Kasimir's bargain is narrative (flags), not a build.
- **Cold**: no exposure rule; the cold is rest rules, traps, the whiteout and the Narrator. An `exhaustion +1`
  dialogue statement (or an environment field on a location) would let the climb and a failed whiteout bite.
- **Allies in a fight**: Exethanter can't fight beside the party (`side` is enemy or neutral). A `side: ally` would let
  a friendly warden help against Vosk.
- **Travel**: the road `tsolenka_pass_to_amber_temple` already lives in data/travel/berez.json (gated by
  `tsolenka_gate_open`), so data/travel/amber_temple.json holds only the place. Its table is Berez's `baratok_slopes`;
  the climb's own table, `amber_temple_road` (ice, the frozen dead), is ready if the lead points that road at it.

## 16. Files

- Region: docs/regions/amber_temple.md (this file)
- Voice: docs/voice/{exethanter, vosk, patrina_velikovna, amber_vestiges}.md
- NPCs: data/npcs/{exethanter, vosk, patrina_velikovna, amber_sentinel, vestige_zantras, vestige_fekre,
  vestige_taar_haak, vestige_shami_amourae, vestige_yog, vestige_drizlash, vestige_khirad, vestige_norganas,
  vestige_savnok, vestige_seriach, vestige_sykane, vestige_tarakamedes, vestige_tenebrous, vestige_yrrga,
  vestige_zhudun, vestige_dahlver_nar}.json
- Dark gifts: data/dark_gifts/{gift_of_zantras, gift_of_fekre, gift_of_taar_haak, gift_of_shami_amourae, gift_of_yog,
  gift_of_drizlash, gift_of_khirad, gift_of_norganas, gift_of_savnok, gift_of_seriach, gift_of_sykane,
  gift_of_tarakamedes, gift_of_tenebrous, gift_of_yrrga, gift_of_zhudun, gift_of_dahlver_nar, gift_of_the_hollow}.json
- Quests: data/quests/{the_amber_temple, something_with_a_lid, patrinas_wail}.json
- Flags: data/flags/amber_temple.json
- Locations: data/locations/{amber_temple_entrance, amber_temple_faceless_god, amber_temple_library,
  amber_temple_vault, amber_temple_road}.json
- Travel: data/travel/amber_temple.json; random encounters: data/random_encounters/amber_temple_road.json
- Dialogue: narrative/amber_temple/{sentinel, vestiges, exethanter, library, vosk, patrina, vault, road}.dialogue;
  narrative/narrator/amber_temple.dialogue; narrative/banter/amber_temple.dialogue
