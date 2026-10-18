# Deeper NPCs, more kinds of side quest, comedy and failure, and a voice for the Sunsword (plan)

Status: **plan, waiting for Ashwin's go.** Nothing in game data changes until he says so, and then only batch 1.
Branch `npc-plan`. The per-NPC table is in [npc_depth_roster.md](npc_depth_roster.md).

## What was asked (Ashwin's todos, 2026-10-17)

1. Every NPC should have something that makes them unique (a story, feature or trait), something they want, and a
   secret. Not all of it needs a side quest or big drama.
2. Side quests feel the same: talk to someone, wait somewhere at night, fight something. Make them more diverse.
3. More comic-relief characters and lines; failure dialogues (not everything a success); not everything should give
   information, as long as a failed check never locks us out of a quest. Ten comic NPCs in all. Every new line is
   drafted with Gemini on his subscription (not the API key).
4. Give the Sunsword lines, and a voice.

## What the audit found (origin/main bd316c714)

**NPCs.** 280 NPC entries, 241 of whom speak (4,341 lines). 68 speak one to five lines and 115 speak six to twenty.
The story NPCs (the book's cast and every side quest's people) already have a trait, a want and a secret. The gap is
the townsfolk: around 60 people who are a job and a mood (Goodwife Viorica counts coppers, Gheorghe rakes the mud),
written well but with nothing to find out about them. 39 entries never speak: animals, the castle's dead servants,
the abbey's Belview extras, three of the den's children, and bosses that only fight.

**Side quests.** 104 quests: 13 main, 31 from the book, 10 companion quests and 50 rumour side quests. The book and
companion quests vary (the stolen bones are an investigation, Victor's Circle and the Wachter plot are social, the
companion quests are mostly talk). The 50 rumour side quests are where Ashwin's feeling comes from, and the numbers
back him up:

- 46 of 50 have a fight, and 41 can't be finished without one. 22 of the fights are custom bosses with legendary
  actions.
- 27 of 50 turn on waiting for dusk or night.
- 25 of 50 are exactly "talk to someone, wait for dark, fight". The sidequests lane built every one to the same rule
  (a twist, a build-up, an escalation), and the escalation is always the fight.
- Only four have no fight: Clovin's Audience, Mother's Ninth Improvement, The Toymaker's Masterpiece and The Mage's
  Lost Pages. They're among the best-written ones.

**Checks and failure.** 420 skill checks in 335 dialogue files. On paper failure already mostly withholds the
information (about 365 of the 420 fail branches give less than success), and 51 fail forward with the same result
(the Oat Thief's Parriwimple tells you either way; Henrik confesses on a failed Persuasion too). In play, though,
failing is rare (inferred from the rules, not measured): Guidance is offered before every roll, the party always
chooses its best speaker, and 84% of DCs sit at 12 to 15. What's really missing is failure that isn't a roll: no NPC
ever doesn't know, gets it wrong, lies, refuses, or tells a joke that dies. Every one of the 28 "Heard anything
interesting?" menus always hands over a hook.

**Comedy.** There are good comic beats (Parriwimple's counting, Clovin's jokes, Arik's one-word rumours, Blinsky and
Piccolo, Exethanter's notes, the village goat that eats fences, the Baron's decrees), but they're one-offs. Nobody
recurs as comic relief, and there are no running gags.

**The Sunsword.** Sentient in data (Int 11, Wis 17, Cha 16; "speaks into its bearer's mind"), and it has no lines at
all.

## Rules this work follows

Project rules: every conversation has an exit; side quests never change main flags (they may read them); NPC names
are unique; every monster has a portrait; every cutscene has two or more scenes; stills never show hero faces;
Detect Thoughts stays out. New lines stay unvoiced until the voice thread records them with Ashwin's typed yes.

Rules for this work:

1. **A failed check never locks a quest.** Every check a side quest needs has a second way on: another skill, a
   price, time, another person who knows, or the fight. The `fail_routes` check (batch 1) enforces it in
   `make validate`, and each reshaped quest's test walks it once with every roll failed.
2. **Failure costs something, but never the quest:** gold, time, an NPC's attitude, a companion's approval, a harder
   fight, a smaller reward, a lost bonus or a laugh at the party's expense.
3. **Not everything gives information.** Some NPCs don't know, some are wrong, a few lie (Insight catches it, and
   the truth is always available from someone else).
4. **A fight stays in the data when a quest is reshaped.** It becomes the failure path or a choice, so the fight
   tests still have it to play, and `xp fight` pays its XP when it's avoided, so XP levelling doesn't fall behind.
   Rewards don't change.
5. **New NPCs reuse existing sprites and portraits** (169 NPCs share a portrait today), so no art is spent. Own art for
   the comic characters is optional and would need Ashwin's yes (Gemini spend).
6. **Every new line is drafted with Gemini** (Gemini 4 Argon, Medium effort, on Ashwin's subscription, never
   the API key; owner, 2026-10-17): the NPCs' flavour lines and hooks from the roster row and the NPC's existing lines,
   the comic characters' from a brief per character, every reshaped and new side quest's from a brief per scene (who
   speaks, what happens, which flags and checks, the exits), and the Sunsword's from Part D. I write the briefs and the
   dialogue file's logic (nodes, checks, flags, exits), then review and edit every drafted line for canon, tone, the
   rules above and voice safety before it goes into game data. How: Ashwin's ai-bridge (~/Documents/ai-bridge, the
   daemon on 127.0.0.1:8765), whose `gemini` participant runs Antigravity's `agy` CLI signed in with his Google account
   (consumer OAuth, so his subscription; no API key). `agy` answers on its selected model, Gemini 4 Argon (Medium);
   its log says so on every run, and I check it. Tested 2026-10-17 with three lines for Sprig. I keep each brief and
   Gemini's raw reply (the bridge's transcript holds them too), so what it wrote and what I changed can be compared.

## Part A: NPCs

The [roster](npc_depth_roster.md) gives every speaking NPC a trait, a want and a secret, region by region (176 rows).
94 rows already have all three, from the book or a side quest, and the row only names them. The rest get one of:

- **Flavour** (52 rows, 2–5 lines each): the trait shows in the greeting, the want is an answer when asked ("What
  would make your day?" in that NPC's own words), and the secret sits behind something: an Insight check (failing
  it gets nothing), a second visit, another NPC's gossip or a companion's interject.
- **Hook** (9 rows, 6–15 lines): a small errand with a small reward and no fight. For example, Anca the acolyte wants
  to learn her letters at St. Andral's; the party carries her letter to Father Lucian, and his answer comes back.
  Goodwife Viorica wants one candle at last spring's price; give her a copper. Codruta in the den wants the rag doll
  she hid on the hillside.
- **Quest** (20 rows): the NPC is part of a new or reshaped side quest (Part B).

A few secrets, to show the weight: Bildrath has a debt book in which half the village owes him and he has never
collected a copper (he's been feeding them on credit). The Krezk watchman can't read the burgomaster's list of who
may come in, so he says no to everyone to be safe. Lord Aubrey Thale, leaving the castle in the morning for 190
years, sold his horses at cards the first night. Old Smaranda's wolfsbane is half parsley.

Every new flag goes in the region's flag file or `data/flags/side_quests.json`; nothing reads or sets a main flag
except to read it for a line.

## Part B: Side quests

### The 50 rumour side quests today

"Dark" means the quest waits for dusk or night. "Fight" is whether one is needed to finish (✓), optional (opt) or
absent (–).

| Quest | Lv | What the player does | Dark | Fight | Plan |
|---|---|---|---|---|---|
| The Last Traveller | 1 | Talk at the fog's edge, walk him home | | ✓ | keep |
| The Goatherd's Count | 1 | Watch the evening count, fight mist wolves | ✓ | ✓ | **reshape** (batch 1) |
| The Burgomaster's Hound | 2 | Follow the dog, read the wall, seal it or open it | | opt | keep |
| The Oat Thief | 2 | Wait on the north path at night, follow, fight hunters | ✓ | ✓ | **reshape** (batch 1) |
| The Lantern in the Roadhouse | 2 | Night ghost, read the guest book, fight the cellar | ✓ | ✓ | keep |
| The Polite Caller | 3 | Vigil till dark, fight the coachman, choose at dawn | ✓ | ✓ | keep |
| Cut After Noon | 3 | Investigate the wood, fight at dusk or burn it by day | ✓ | ✓ | keep |
| Six Feet | 3 | Raise the bones, name her or fight | | opt | keep |
| The Nursemaid's Grave | 3 | Night ghost, carry the bones, fight the keepers | ✓ | ✓ | keep |
| The Dancing Bear | 3 | Follow the bear, free the cub, fight blights | | ✓ | keep |
| The Spiders' Gully | 3 | Cut her down, fight spiders | | ✓ | keep |
| The Grey Mare | 4 | Night crossroads, calm and unbrand her, fight the escort | ✓ | ✓ | **reshape** (batch 2) |
| Called by Name | 4 | Falls after dark, resist the voices, fight wisps | ✓ | ✓ | **reshape** (batch 2) |
| The Cat in the Window | 5 | Diagnose a curse, find Remove Curse, fight | | ✓ | keep |
| Black Roses | 5 | Investigate, night vigil, talk down or fight, graves | ✓ | ✓ | keep |
| Ribbons | 5 | Stake-out at dusk, follow, fight Dobre | ✓ | ✓ | **reshape** (batch 3) |
| One Lantern Too Many | 5 | Night jetty, dive for the lantern or fight | ✓ | opt | keep |
| The Tinker's Wagon | 5 | Spot the mimic, boss | | ✓ | keep |
| The Baron's Island | 5 | Row out, night fight with the boatmen | ✓ | ✓ | **reshape** (batch 4) |
| Hunters at the Inn | 6 | Inn talk, dusk hunt, boss | ✓ | ✓ | keep |
| The Ravens' Ransom | 6 | Night cage, sneak or be surprised, fight | ✓ | ✓ | keep |
| The Last Muster | 6 | After dark at the gates, stand the riders down, boss | ✓ | ✓ | keep |
| The Fourth Sister | 6 | Name the girl, next night Granny Ash, give her up or fight | ✓ | ✓ | **reshape** (batch 4) |
| The Black Row | 6 | Read the row by day, after midnight Adrian, boss | ✓ | ✓ | keep |
| The Waystone | 6 | Night at the stone, fight wolves, talk him down | ✓ | ✓ | **reshape** (batch 4) |
| Lighter Than It Should Be | 7 | Vigil after midnight, fight pursuers, family scene | ✓ | ✓ | keep |
| Clovin's Audience | 7 | Book the square, land three beats | ✓ | – | keep |
| Mother's Ninth Improvement | 7 | Cut the wire, coax her off the wall | | – | keep |
| The Druid Who Came Back | 7 | Night on the hill, boss | ✓ | ✓ | keep |
| The Barrow on Yester Hill | 7 | Lift the skull, fight the watch | | ✓ | keep |
| The Squire | 8 | Read the headstone, night vigil, fight | ✓ | ✓ | **reshape** (batch 5) |
| Bell Under the Lake | 8 | After moonrise, fight the drowned, cut the bell | ✓ | ✓ | keep |
| The Count's Huntsman | 8 | Read the cairns, night crossroads, boss | ✓ | ✓ | keep |
| The Pack's Runt | 8 | Night at the pens, give him up or fight | ✓ | ✓ | keep |
| The Forgotten Storm | 8 | Dusk at the ring, tell it the truth or fight | ✓ | opt | keep |
| The Count's Portraitist | 9 | Evening doorstep, studio, boss | ✓ | ✓ | **reshape** (batch 3) |
| The Silver Hoard | 9 | Undercroft boss, keep or send the tithe | | ✓ | keep |
| The One-Horned Billy | 9 | Remove Curse, boss in the field | | ✓ | keep |
| The Last Egg | 9 | Defend the nest or step back | | ✓ | keep |
| The Mage's Lost Pages | 9 | Find three letters | | – | keep |
| The Drowned Library | 9 | Down the well, boss | | ✓ | keep |
| The Toymaker's Masterpiece | 10 | Bring Pidlwick to Blinsky | | – | keep |
| The Frozen Pilgrims | 10 | Last rites, or break her out (boss) | | opt | keep |
| The Guide to the Temple | 10 | Smell the tea, boss | | ✓ | keep |
| The Unnamed Crypt | 10 | Name her, boss | | ✓ | keep |
| Escher's Petition | 10 | Before dawn on the roof, boss | ✓ | ✓ | keep |
| The Warm Snow | 10 | Dungeon, three lair tricks, boss | | ✓ | keep |
| The Mountain's Heart | 10 | Quarry, boss, give the heart back or keep it | | ✓ | keep |
| The Name Over the Door | 10 | Dungeon, unmake the name, boss | | ✓ | keep |
| The Amber Debt | 10 | Dungeon, lair tricks, boss | | ✓ | keep |

The book's 31 quests, the 10 companion quests and the 13 main quests stay as they are, apart from failure lines
(Part C).

### Shapes to use

Each is built from what dialogue and locations already do (checks, flags, items, gold, `time`, hours, guests,
attitudes, approval). None needs new engine code.

| Shape | What the player does | Where it's used |
|---|---|---|
| Whodunit | Gather clues by day, question suspects, accuse; a wrong accusation costs something | The Oat Thief |
| Puzzle | Work out an order, a count or a riddle from what's in front of you | The Goatherd's Count, The Fourth Sister |
| Herding / chores | Several small checks against the clock, any party member, failures add up | The Goatherd's Count |
| Rescue by climbing | A route of checks and spells to reach someone; the danger only if it goes wrong | Called by Name |
| Con / swap | Fool someone with a substitute or a forgery | The Grey Mare, Ribbons |
| Hearing | Argue a case before a judge or a table, with evidence found earlier; a vote | Ribbons, The Squire |
| Retrieval / heist | Get three things back from three people: buy one, talk one free, steal one | The Count's Portraitist |
| Smuggling | Get people away unseen; the fight only if seen | The Baron's Island |
| Lure / trap | Bring a frightened creature in by day with the right bait | The Waystone |
| Contest | Rounds against a rival, judged by a crowd; forfeits for losing | Stanimir's Fire, The Sun-Cake |
| Trade chain | A wants what B has, B wants what C has | Radu's Unsellable Horse, The Sun-Cake |
| Delivery against the clock | Carry something fragile somewhere before an hour, on a bad road | Old Silviu's Wedding Cask |
| Moral choice | Truth or comfort, with no right answer and companions split | Florin's Grandson |
| Talk-down | Change someone's mind with what you learn about them | Emanoil Wants to Be Bitten |
| Kindness / con | Arrange something good for someone who'd never ask | Dumitru's Visitor |
| Paperwork | Collect seals and signatures from people who each want something | The Boyar's Petition |
| Collection | Spot or verify things across the whole valley | Fennimore's Guide, The Well-Travelled Goat |
| Spread a rumour | Make something up and watch it come back changed | The Fourth Rumour |

### Ten reshaped quests

Each keeps its story, NPCs, rewards and fight; what changes is what the player does to get there, and the fight
becomes a failure path or a choice.

1. **The Oat Thief (batch 1): whodunit by day.** Bildrath's back room by daylight: oat dust, a very large boot print,
   a key worn on a string. Suspects: Parriwimple, Arik, the village goat (a comic false lead; with Speak with Animals
   it confesses to a fence, not oats) and a raven on the roof. Accuse the wrong one and it costs: Bildrath raises his
   prices, or the accused is humiliated in front of the square (approval). Accuse Parriwimple, or catch him on the
   north path at night as now, and he takes you up to the hollow by day. There the split sack has left a trail:
   lay a false trail down to the river (Survival or Stealth, by day) and the hunters never come, or stand in the
   door and fight them as now.
2. **The Goatherd's Count (batch 1): a counting puzzle and a race against dark.** Erno counts twenty-four. The party
   counts too, and checks the collars against the names in Erno's tally (a small puzzle, or Perception): one name
   isn't on it, SNOWDROP. Then the flock has to be in the fold before dark: three beats (Animal Handling, Survival or
   Athletics, any party member). Each failure lets a goat stray; two strays bring the wolves out of the fog, as now.
3. **Called by Name (batch 2): a climb by day.** Nelu is on a ledge. Reach him by day: a route of Athletics,
   Survival and Investigation checks, or Spider Climb, Misty Step, or the rope. The wisps only come if the party
   stays until dark, or someone answers a voice (the Wisdom check); then it's the fight as now.
4. **The Grey Mare (batch 2): a swap.** Calm and unbrand Steaua as now, then leave a decoy in her place at the
   milestone, one of Radu's other horses rubbed black with lamp-soot (Sleight of Hand or Deception against the coachman,
   or Animal Handling to keep the decoy still). Fooled, the carriage takes the decoy and goes; caught, the escort
   fights.
5. **Ribbons (batch 3): a sting and a hearing.** Daciana writes a list of names that don't exist (Deception to make
   it pass). The party watches where they turn up: the Baron's clerk, Wachterhaus, the rider at the gate.
   Then Dobre stands before the Baron in the square: present the false list, the ladies' visits and the rider's
   silver (each a check or a found proof; any two win it). Lose the hearing, or skip it, and it's the fights as now.
6. **The Count's Portraitist (batch 3): three copies back.** Before the studio, the three paintings Haralamb sold:
   buy the Baron's (gold, or Persuasion), talk Urwin out of his (he's a Keeper; telling him what it is is enough),
   steal Lady Wachter's from the parlour (Stealth and Sleight of Hand; caught, the guards and her attitude cost).
   Each copy burned takes Hit Points off the Likeness. The boss stays.
7. **The Baron's Island (batch 4): get them off unseen.** The boatmen come tonight. Row the castaways off before
   they do, in Nistor's leaking boat, a few at a time (Stealth, Athletics on the oars, a bailing check). The
   castaways vote first whether to go at all (Ostap's speech; the party can argue either side). Seen, or out of
   time, and the boatmen fight on the shingle as now.
8. **The Fourth Sister (batch 4): riddles with Granny Ash.** Hags bargain. Granny Ash offers a basket of coins for the
   girl; the party can offer her a riddle game instead: three riddles each way, answered by the party (a puzzle the
   player can solve, or Intelligence checks), with Mouse's name as the last answer if the party learned it. Win and
   Granny goes back into the trees; lose and she fights, as now; the basket ending stays.
9. **The Waystone (batch 4): bring Yanko in by day.** Lark's song carries in daylight too. By day the party follows
   his tracks to where he lies up (Survival), and Lark sings him out before the pack notices (Persuasion to keep her
   singing, Stealth to keep the pack off). The fight at the stone only happens if the party waits for night or the
   pack hears.
10. **The Squire (batch 5): a hearing before the dead knights.** Instead of the vigil, Cosmin asks Vladimir's table to
    hear Ioan's case. Evidence the party brings (the headstone's back, Godfrey's memory, the chronicle, the dragon's
    last words) counts for votes; History and Persuasion argue it. The table votes. Lose, and the men-at-arms come out
    for the living on the ridge, as now.

After these and the new quests below, 32 of 62 rumour side quests need a fight (was 41 of 50), and 15 are
"talk, wait for dark, fight" (was 25).

### Twelve new side quests, none needing a fight

Small ones (20–45 lines each), from the roster's wants and secrets. Rewards follow the existing rules (uncommon to
level 4, rare from 5), smaller than a fight quest's.

1. **The Fourth Rumour** (village, batch 1, comedy). Vasile and Petre have had the same three rumours for years. The
   party makes up a fourth (pick one: the Baron is bald under the wig, Lupu can count, Bildrath gives discounts on
   Tuesdays) and sells it to them (Deception or Performance). Believed, it spreads and comes back garbled from talkers
   in later regions, a laugh each, never information. Not believed, Vasile tells you a better one. If the Tuesday one
   spreads, Bildrath gives the party exactly one discount, out of spite.
2. **Stanimir's Fire** (Tser Pool, batch 2, contest). Stanimir bets his cask of plum wine that nobody can tell a
   better tale at the fire. Three rounds (Performance, then Deception or History, then the camp's vote, which a
   companion's interject can tip). Lose, and the forfeit is a dance on Lavinia's stage while the camp laughs.
3. **Radu's Unsellable Horse** (Tser Pool to Vallaki, batch 2, trade chain, comedy). A horse called Dinte ("Tooth")
   bites everyone. Radu wants it sold. Find who it won't bite (Lupu? Izek? Thistle?), then trade along a chain to get it
   there. The horse ends up with someone who deserves it, one way or the other.
4. **Fennimore's Guide** (the whole valley, batches 2–6, collection, comedy). Ambrose Fennimore, from beyond the mists,
   is writing a guidebook and rates everything ("The Blue Water Inn: two stars. Wolves."). He asks the party to check
   one fact in each region. Some of his facts are right, most are wrong, one is dangerous. His last chapter is in the
   castle; he never finds the way home, and decides the book is the point.
5. **Florin's Grandson** (village to Vallaki, batch 3, moral choice). Old Florin's grandson Tudorel went to the castle
   for work two winters ago. He's alive, a footman at Wachterhaus in the count's livery, and he likes it. Tell Florin
   the truth, tell him the boy is dead and at peace, or tell him he's well and leave out whose coin it is. Companions
   split on it.
6. **Emanoil Wants to Be Bitten** (Vallaki, batch 3, comedy, talk-down). Emanoil writes poems to the castle and sleeps
   in a coffin from Henrik's. Help him write the letter (it's very bad), read his poems (Insight: they're about being
   lonely), or show him a spawn up close. Talked out of it, he writes a better poem, about the party.
7. **The Sun-Cake** (Vallaki, batch 3, contest and trade chain). The Baron's cook, Leontina, needs a cake shaped like
   the sun for the festival and has made four hundred and thirteen round things. Ratatouille (or any hero, badly)
   cooks against her. Ingredients come from around town (eggs from Goodwife Marta, honey from the Vistani camp,
   saffron from Vadoma). If the cake collapses, the Baron declares it a triumph anyway.
8. **Dumitru's Visitor** (Krezk, batch 4, kindness). Dumitru waits by the gate for a visitor who never comes, and
   writes letters to an uncle in Vallaki who died. Find someone who'll come up the road for him (a Vistana, Ostap,
   Fennimore), or come up it yourselves dressed as cousins (Deception against the watchman).
9. **Old Silviu's Wedding Cask** (the winery to Vallaki, batch 4, delivery against the clock). The last cask of the
   year Elvir was born, for Silviu's daughter's wedding in Vallaki by noon the day after next. A bad road: checks to
   keep it from being shaken, a wolf that wants the cart, Kip who wants to taste it. Late or spoiled, the wedding
   happens anyway and somebody makes a speech about it.
10. **The Boyar's Petition** (the castle, batch 6, paperwork, comedy). Boyar Vintila Crainic has waited 206 years to
    present a petition about a boundary stone. Get it the four seals it needs from the castle's ghost servants, each of
    whom wants a small thing first. He's received at last. The stone is under Lake Zarovich, and he's satisfied.
11. **The Well-Travelled Goat** (the whole valley, batches 1–6, collection, comedy). The village goat turns up in
    impossible places: the church roof, Bildrath's shop, Argynvostholt's banquet table, the Amber Temple, the top of
    the high tower. Spot six; with Speak with Animals it explains itself every time. Mostly Narrator lines.
12. **Exethanter's Notes** (the Amber Temple, batch 5, puzzle hook). Put the notes on his sleeve in order to work out
    what he was doing this morning (he was making tea).

## Part C: Comedy and failure

### Comic relief

The valley stays a horror story. The comedy is dry, character-based and short, and it never makes a serious
scene's NPC ridiculous.

Ten new comic characters, all on existing sprites, at least one in every stretch of the valley (owner, 2026-10-17:
"maybe 10 in total"), plus the Sunsword (Part D):

| Who | Where | The joke | Want | Secret | Lines |
|---|---|---|---|---|---|
| **The Well-Travelled Goat** | Everywhere (batches 1–6) | Turns up in impossible places, eating them | Everything | It has been everywhere, and with Speak with Animals it has opinions about all of it | ~25 (Narrator) |
| **Ambrose Fennimore** | Roads, every region (2–6) | A travel writer from beyond the mists rating the valley ("The Blue Water Inn: two stars. Wolves.") | To finish the book and go home | Eleven years here, nine hundred pages, no way out | ~60 |
| **Costică** | The Svalich road and the crossroads (2) | The worst highwayman in Barovia: robs politely, apologises, ends up giving you his lunch | One robbery that works | He's Bildrath's cousin, has never kept a thing, and buys back whatever he "steals" | ~35 |
| **Piccolo** | Blinsky's shop, Vallaki (3) | Blinsky's monkey, a critic who charges admission | Your coins, one at a time | Everything he's taken is in the jester's hat on the top shelf | ~10 (Narrator) |
| **Emanoil** | Vallaki (3) | A clerk who writes poems to the castle and sleeps in a coffin from Henrik's | To be chosen and bitten | He's afraid of the dark and sleeps with a candle in the coffin | ~40 |
| **Leontina** | Vallaki (3) | The Baron's cook: four hundred and thirteen sun-shaped dishes | One dish that isn't round | She trained in a great kitchen beyond the mists, and nobody here believes her | ~35 |
| **Madam Profira** | Krezk (4) | Krezk's matchmaker, who has been trying to marry the same three people for thirty years, and starts on the party (always the wrong pairs) | One wedding in Krezk this year | The watchman's grandfather jilted her, and she's matched out of spite ever since | ~25 |
| **Sprig** | The winery (4) | A twig blight from Yester Hill that won't fight and has decided it's a dog | To be patted | The druids sent it to spy, and it is very bad at it | ~10 (Narrator) |
| **Sir Ottokar the Late** | Argynvostholt (5) | A dead knight who arrived late to the last battle and has been late to everything since ("Did I miss it?") | To be on time once | He was late because he stopped to help a farmer's wife with her cart, and he'd do it again | ~20 |
| **Gogu** | Castle Ravenloft's roofs (6) | A gargoyle on the highest ledge who's afraid of heights | A lower ledge | He's the one who drops things on guests, and blames the ravens | ~20 |

Existing characters given recurring comic beats: Vasile and Petre as a double act, Mirabel's nicknames for each
hero, Parriwimple's counting, Arik's one-word "no"s, the Baron's decree of the day, Anton in the stocks (who likes
it there), Old Smaranda's parsley, Old Dorina's sixty-year stew, the Krezk watchman's "no", the Phantom Watchman who
nods at any watchword, Lord Thale leaving in the morning, the Belviews greeting you in the last visitor's voice.

Companions: Kip, Ratatouille and Wren get comic interjects in the new scenes (`name:` selectors), and a `tag:blunt`
line where it fits, as the side quests already do.

Running gags, each paying off late: the Fourth Rumour coming back garbled; the Goat's sightings; Fennimore's
ratings; Piccolo's coin-stealing (catch him to get your coins back); Costică's robberies; Ottokar arriving after
every fight at Argynvostholt.

### Failure that isn't a dead end

Patterns the regional batches apply, everywhere they fit:

| Pattern | What happens | Example |
|---|---|---|
| Doesn't know | Asked, the NPC has nothing, in character | Vasile on a quiet day: "Nothing. Nothing happens here. That's what here is for." |
| Nothing new | A rumour-giver with no new rumour says so (a cooldown), instead of repeating | The 28 "Heard anything interesting?" menus |
| Wrong | A rumour that turns out false, corrected later by someone else | Vasile swears the riders at the gate are Vistani |
| Lies | Insight catches it; missed, you believe it and pay for it (gold, a wasted trip) | Radu's horse "has never bitten anyone" |
| Refuses | Attitude too low; a gift, a favour, a companion or another day changes it | Bildrath after a wrong accusation |
| Bombs | A joke, speech or haggle fails, and the price goes up or the crowd turns | Stanimir's Fire, Clovin's Audience |
| Costs | Success at a price: the information, for gold, time or approval | A bribe that works, but the watch remembers |
| Partial | Half the answer: a vaguer version of the same lead; the journal hint still points | A failed Investigation finds the place, not the clue |
| Wrong person | "I don't know, but she might" | A failed Persuasion sends you round to Goodwife Marta |
| Hard extra | A DC 16–18 check for a bonus secret, not for the quest | The roster's secrets |

The 51 checks that fail forward with the same result are looked at region by region: the ones where a failure
should cost something get a cost (a cooler attitude, a smaller reward, the long way round); the rest stay.

### The never-lock check

`tools/data/fail_routes.py`, run by `make validate` (batch 1): for every check option whose success moves a side
quest's stage (directly or through jumps), its fail branch must reach the same stage, or its menu must keep another
option that does without the same check. A short allow-list covers quests whose other route lives somewhere else
(a different NPC or a prop), each with a comment naming it. Fixture tests cover the checker. Each reshaped quest's
StoryBot test also walks it once with every roll failed.

## Part D: The Sunsword

**Who it is.** Sergei's sword, the prince's blade, made to end vampires and made proud by it. It speaks in a bright,
ringing, courtly voice, a little too loud, with the manners of a royal court four hundred years gone. It wants
Strahd destroyed, less for the valley than for revenge: he broke its crystal blade, and it was his brother's sword.
It is vain about its light, rude about other weapons, bored by shopping and impatient with a bearer who dawdles. It
calls Strahd "the elder brother" and never his name. It's tender about two people: Sergei, whom it misses, and
Ireena, whom it knows. Its secret, which the book gives it: it is afraid of being broken again. That fear shows when
the bearer falls, at the castle, and once at a camp.

It's comic relief too: pompous, theatrical, and right more often than anyone would like.

**Where it speaks** (only while someone carries it):

| Moment | Lines |
|---|---|
| Found, at each of its Tarokka places (one scene, then attunement) | 8 |
| First drawn; first undead it kills | 4 |
| Exploring: entering places it knows (the Pool of the White Sun, Sergei's tomb, Argynvostholt, the castle), idle remarks on a long walk | 18 |
| Fights: a strike on undead, a kill, a crit, the bearer falls, Strahd appears | 20 |
| Strahd's visits, the dinner, the final fight and each ending | 14 |
| Ireena and Sergei (the pool, the wedding question) | 6 |
| A camp talk with its bearer: the fear | 8 |
| Left in the stash, or its bearer running from Strahd | 4 |
| **Total** | **82** |

**How.** A `sunsword` NPC entry (speaker "Sunsword", the item's icon as its portrait); its lines in
`narrative/banter/guest_sunsword.dialogue` using the guest moments (enter, fight, idle), plus its own lines in the
Strahd scenes (`if item:sunsword`) and the finding scene. Two small code changes: Banter treats the Sunsword as a
guest while someone carries it, and CombatBarks lets a party member's sentient weapon bark (today party barks are
skipped). The voice is designed later by the castle voices lane.

## Batches

Each batch is one stretch of the valley, played and checked as a whole, then handed off with `make check` green. Lines
are estimates; every one is unvoiced until the voice thread records it.

| Batch | Region (levels) | What's in it | New lines |
|---|---|---|---|
| **1** | The Village of Barovia and the road in (1–3) | The `fail_routes` check; the village's rumour-givers get "nothing new", a wrong rumour and a refusal; trait, want and secret for about 30 villagers, with hooks for Anca, Viorica and Parriwimple; The Oat Thief and The Goatherd's Count reshaped; The Fourth Rumour; the Goat's first sightings; Mirabel's nicknames | ~290 |
| 2 | Tser Pool, the Svalich road and the crossroads (3–5) | ~20 NPCs; Called by Name and The Grey Mare reshaped; Stanimir's Fire; Radu's Unsellable Horse; Fennimore arrives; Costică; Old Dorina's stew | ~295 |
| 3 | Vallaki and the Vistani camp (5–6) | ~45 NPCs; Ribbons and The Count's Portraitist reshaped; Florin's Grandson; Emanoil; The Sun-Cake; Piccolo, the Baron's decrees, Anton, Smaranda | ~450 |
| 4 | Krezk, the abbey, the lake, the winery, the den, Yester Hill (6–8) | ~40 NPCs; The Baron's Island, The Waystone and The Fourth Sister reshaped; Dumitru's Visitor; Old Silviu's Wedding Cask; Madam Profira; Sprig; the watchman, the Belviews | ~405 |
| 5 | Argynvostholt, Berez, the mountains, the Amber Temple (8–10) | ~25 NPCs; The Squire reshaped; Exethanter's Notes; Sir Ottokar the Late | ~160 |
| 6 | Castle Ravenloft (10) | ~25 NPCs; The Boyar's Petition; Gogu; the Goat's and Fennimore's last chapters | ~195 |
| S | The Sunsword (any time; its own files) | Part D | ~82 |

**Batch 1 in detail** (what lands when Ashwin says go):

1. `tools/data/fail_routes.py` in `make validate`, with fixture tests, and any village check it flags fixed.
2. Vasile and Petre, Arik, Bildrath's news, Goodwife Petra and Old Mihail: an in-character "nothing new" on a
   cooldown, one wrong rumour (Vasile's), and one refusal that a gift or another day fixes.
3. The roster's village rows: flavour lines for Bildrath, Petre, Mirabel, Goodwife Sorina, Iulian and Lucia, Ismark's
   counted fights; the hooks for Anca (her letter waits for Father Lucian's answer in batch 3; until then she says
   she's still waiting), Goodwife Viorica (a copper, a candle, a line at the church) and Parriwimple (the debt book,
   and Bildrath's charity).
4. The Oat Thief and The Goatherd's Count reshaped as above, with their tests updated and a fail-every-roll walk each.
5. The Fourth Rumour (its echoes in later regions arrive with those batches).
6. The Goat's first three sightings (church roof, Bildrath's shop, the Death House gate), with Speak with Animals
   answers.
7. Every new line drafted with Gemini through the ai-bridge, then edited.
8. `docs/story/side_quests.md` and the flags files updated; `make check` green; handed off by branch name.

## Voice cost

New lines average about 105 characters, about 50 credits each on eleven_v3 with tags (and about the same on v4 for
the Narrator since the sale ended).

| | Lines | Credits |
|---|---|---|
| Batch 1 | ~290 | ~14,500 |
| Batch 2 | ~295 | ~14,750 |
| Batch 3 | ~450 | ~22,500 |
| Batch 4 | ~405 | ~20,250 |
| Batch 5 | ~160 | ~8,000 |
| Batch 6 | ~195 | ~9,750 |
| The Sunsword | ~82 | ~4,100 |
| Designed voices (the Sunsword and the seven speaking comic characters; Tudorel and the rest share townsfolk voices) | | ~2,400 |
| **Total** | **~1,880** | **~96,250** |

The account had 49,021 credits early on 2026-10-17; Ashwin topped it up the same evening, and the voice lane read
about 159,000 (limit 873,500; 29 of 30 voice slots used; the count resets 2026-11-06), so the whole plan fits if
nothing else spends. Every recording waits for Ashwin's typed yes in this thread.

## What I need from Ashwin

1. Go or changes on this plan; then I build batch 1 only.
