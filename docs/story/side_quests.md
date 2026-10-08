# Side quests from rumours (sidequests lane)

Owner ask (2026-10-08): what people say when you ask "heard anything interesting?" should be side quests you can take
on; build the good rumours out, change the weak ones, make every quest interesting (a twist, a build-up, an
escalation) and pay rewards in proportion to the quest's level and effort. The full audit of every rumour and the plan
are in the vault note "Side Quests - Audit and Plan". This page is what's built.

## How a rumour works

- Each settlement's talkers answer **"Heard anything interesting?"**. A rumour sets a `*_rumor` flag and moves its quest
  to a `rumored` stage, so it shows in the journal with an objective that says whom to ask. A rumour never moves a quest
  backwards: it only starts one that hasn't started (`if not quest.<id>`).
- A rumour about a quest already in the game wires into it instead: the journal stage, or the place on the travel map.
- Once a quest is over, the same talkers say how it ended.
- Flags for every side quest live in one file, `data/flags/side_quests.json`.

## Rewards

Rarity follows docs/story/found_magic_items.md (uncommon up to level 4, rare from 5, no commons). Gold is set against
what the region's other quests pay. Each quest's items are listed there as Gifts or Tips.

## The Village of Barovia (level 3)

Talkers: Vasile and Petre (townsfolk:gossip, the village's three rumours), Arik (arik:rumors, one word at a time),
Bildrath (bildrath:news, with Grigore added to his topics). Wiring for quests already built: Bildrath's Morgantha line
sets `bonegrinder_rumor` (the mill on the map), his Mary line starts `find_gertruda` at `heard`, and Arik's empty casks
start `wizard_of_wines` at its new `rumored` stage.

### The Polite Caller (`polite_caller`, narrative/village_of_barovia/polite_caller.dialogue)

Widow Ileana's husband Teodor, three winters a vampire spawn, still knocks at her shutter every night and has never
asked to come in. **Twist:** he lives on wolves and is the reason the dead never scratch at her door; his master gave
him until tonight to get her to invite him in, and he came to say goodbye. **Escalation:** the master's coachman comes
for the door (`teodor_errand`), and Teodor can fight beside the party as a guest. **Choice at dawn:** the sunrise
with Ileana, the woods, or the party ends him (before the fight or after).

- Start: the widow at the grave by day (townsfolk:widow, after "Who was he?" or the rumour), or the gossips; Old Mihail
  adds Teodor's open grave (townsfolk:gravedigger_teodor).
- Vigil: by day, "wait with her until dark" (`time until 21`); at night Ileana stands at her door and Teodor comes to
  the shutter (approach). After the fight Ileana comes to the party (`polite_caller:dawn`).
- Fight `teodor_errand` (village map, the east road by the churchyard gate): level 4+ the coachman (vampire spawn), 2
  Strahd zombies, 2 dire wolves, 2 swarms of bats (2,700 XP, High); level 3 the coachman at 60 HP, 2 Strahd zombies, a
  swarm (2,250 raw); below, the coachman at 45 HP with zombies. The coachman is an attention mark (`coachman`, +1).
- Rewards: Teodor's grave (container `teodor_grave`, opens once he tells you): 90 gp, 2 Potions of Healing, a Shield,
  +1 (uncommon). Heroic Inspiration for the party if he sees the sunrise.

### Cut After Noon (`cut_after_noon`, narrative/village_of_barovia/cut_after_noon.dialogue)

The woodcutters cut by noon. Grigore's son Luca stayed late and came home with a load of pale wood; he hasn't woken
since, and Grigore sold the load to Bildrath. **Twist:** it's blight seedwood (Nature DC 13 on the pile `late_wood` or
in Bildrath's storeroom; Medicine DC 13 finds the splinter in Luca's palm), and it wants the boy. **Escalation:** at
dusk the wood walks; Bildrath's load rolls up the street and the woodpile stands up. **The clever way:** get Bildrath's
load, talk Grigore into burning his winter (Persuasion DC 12 or 10 gp) and burn it all by day.

- Fight `woodpile_wakes` (dusk, Grigore's yard): level 4+ "The Woodpile" (shambling mound), 2 vine and 4 needle
  blights; level 3 the mound at 85 HP, 4 twig and 2 needle blights; below, blights only.
- Fight `woodpile_burns` (by day, the clever way): blights only, smaller.
- After either, Grigore comes to the party: the splinter (Medicine, Lesser Restoration or pulled), Luca wakes and tells
  of the man in the bear's hide who planted the seeds ("the hill wants the valley back"): `yester_hill_known` unless the
  Gulthias tree has burned.
- Rewards: Grigore's 40 gp (or refuse it); Bildrath's hush money, the Wraps of Unarmed Power, +1 (uncommon) and his 10%
  discount if the party hasn't haggled it.

### Six Feet (`six_feet`, narrative/village_of_barovia/six_feet.dialogue)

Old Mihail digs a grave every week before anybody dies, because a woman's voice comes up the village well at night
and says a name; this week it's his sister, Goodwife Petra. Arik's third rumour or Mihail himself starts it. **Twist:**
Petra tells the story (Zinaida went down the well forty years ago rather than marry the man the castle sent), and the
voice was never predicting deaths: she has been asking for a grave, and every grave Mihail dug was hers. **Escalation:**
bring her bones up from the bottom (prop `well_lip`, Athletics DC 13, by day or night) and she rises behind you. Her
name talks her down; so may Persuasion DC 14; otherwise she screams and fights (`well_bride`). Then lay her in the
grave Mihail dug for Petra (prop `sixfeet_grave`); he cuts her name on the back of the board.

- Fight `well_bride` (the well): level 3 Zinaida (banshee, her Deathly Wail drops anyone at 25 HP or less) and 2
  shadows (1,300 XP, High-ish with the wail); level 4 adds 2 specters; below, Zinaida at 40 HP and a shadow.
- Rewards: 60 gp in her silver coins and the charm she wore so the castle couldn't find her, an Amulet of Proof against
  Detection and Location (uncommon).

## The Tser Pool camp (level 4)

Talker: Zora ("Heard anything interesting?" is her old road question renamed). Radu's Nicu line now starts
`the_hanged_vistana` at `asked`, as Luminita's does.

### The Grey Mare (`the_grey_mare`, narrative/svalich_road/grey_mare.dialogue)

The black carriage that drives itself stopped by Radu's pen and left a purse; tonight Radu walked his grey mare,
Steaua, to the Ivlis crossroads. **Twist:** he didn't sell her for the money; the voice in the carriage promised Nicu
would ride home (Insight or Persuasion; if the party has seen the gallows they can tell him what that promise was
worth). **Escalation:** at the milestone she is being finished into one of the castle's black horses, a brand smoking
on her flank. Calm her (Animal Handling DC 14, one try, or a ranger, a druid, Animal Friendship), then break the brand
(Remove Curse, Protection from Evil and Good, holy water, or Religion DC 15, one try: "she hates priests"). Saved, she
bolts home and the carriage comes early; failed or left alone, she is black by midnight and fights for it.

- Props on the crossroads map: `grey_mare_milestone` (her, until the carriage comes) and `carriage_crossroads` (the
  carriage, until its escort is beaten). The pen's grey horse (`tser_horse_grey`) is gone while she's sold.
- Fight `carriage_escort` (east of the junction): level 4 the lead horse (nightmare), a wight footman, 2 specters, 4
  zombies (2,000 XP, High), plus Steaua as a second nightmare if she wasn't saved; level 5 adds a wight and a specter;
  below 4 the lead horse at 50 HP with specters and zombies. An attention mark (`black_carriage`, +1).
- Back at the camp Radu pays either way (`home` if she lived, given to Radu or Luminita; `mourned` if not): 120 gp of
  the castle's gold and a Rod of the Pact Keeper, +1 (uncommon).

### Called by Name (`called_by_name`, narrative/svalich_road/called_by_name.dialogue; batch 2)

Big Tobar's son Nelu followed his dead mother's voice toward Tser Falls (Zora's rumour, or Tobar). **Twist:** the voices
are will-o'-wisps in the gorge, feeding on grief and speaking in whatever voice brings you to the edge; Nelu is alive on
a ledge, and they've been calling his father in Nelu's voice. **Escalation:** at the falls after dark (prop
`gorge_voices` in the west glade) they call each companion by someone they lost (Godrick's Sir Pellam, Wren's Sorrel,
Thistle's grandda, Kip's Pip, Liriel's old teacher, Ratatoille's maman), and a Wisdom check (DC 14, the party's best)
decides whether someone is lured toward the edge, which starts the fight with the party surprised.

- Fight `falls_wisps` (the west glade): level 4 four will-o'-wisps (1,800 XP, High), level 5 five, below three.
- Then Nelu comes up (Athletics DC 13 on a rope, Misty Step or Spider Climb), and Tobar pays at the camp: 100 gp and an
  Efficient Quiver (uncommon). Nelu stays by the fire afterwards (`tser_nelu`).

## Vallaki (level 5)

Talkers: the gate watch (gate:news, renamed) and Urwin (martikovs:rumors, renamed) wire into quests already built: the
bones start `bones_of_st_andral` and Arabelle starts `missing_arabelle` at new `rumored` stages, and the book club
starts `wachter_plot` at its own `rumored`. Arasek's road news (renamed "Heard anything interesting on the roads?")
puts Old Bonegrinder on the map. The watch adds Stella's rumour, Urwin the black roses.

### The Cat in the Window (`cat_in_the_window`, narrative/vallaki/cat_in_the_window.dialogue)

Lady Wachter's daughter Stella, locked in the bedroom at Wachterhaus, believes she's a cat. **Twist:** she isn't mad,
she's held (Insight DC 13, Arcana DC 14 or Detect Magic): at one of her mother's soirees she promised a stranger in
black she'd follow him like a cat follows cream, a black velvet ribbon with a silver bell holds the promise, and what
she sees, he sees; her mother ties the bow fresh every morning. **Breaking it:** Remove Curse (Liriel from level 6), a
Scroll of Remove Curse (Urwin's cellar, Vadoma, Rictavio, Lucian's services, or the scroll Lucian gives for her), not a
knife (cutting it rings the bell, an attention mark, and it ties itself again). **Escalation:** the master looks out of
her shadow one last time (`stella_shadow` in her bedroom).

- Fight `stella_shadow`: level 5 two wraiths ("The Master's Gaze", one at 50 HP) and 2 shadows (3,800 XP, High-ish);
  level 4 a wraith and 3 shadows (2,100, High); level 6+ two wraiths and 4 shadows; below, a wraith at 45 HP and 2
  shadows. Attention marks `stella_eyes` (+1) and, if the ribbon was cut, `stella_bell` (+1).
- Stella then goes to Father Lucian; in the vestry she gives 250 gp (her dowry), the Cloak of the Bat (rare; the
  master's present for her sixteenth birthday) and how the cellar panel at Wachterhaus opens.

### Black Roses (`black_roses`, narrative/vallaki/black_roses.dialogue)

Ilie the lamplighter's daughter Ana was taken last winter. **Twist one:** black roses come before a girl is taken, not
after, and they are on the chandler's step. **Twist two:** Ilie's scarf hides bite marks (Insight DC 13 or Medicine DC
12); Ana is the visitor and he has been feeding her so she won't go to anyone else. **The vigil:** at night Ana comes to
Mila Petrova's window in the lower town. Ask where she sleeps, talk her home to her grave (Persuasion DC 14), fight her
and the two girls she calls (`roses_street`), or let her go home to her father, who is found dead at the lake gate in
the morning (`ilie_fate` lost). **The grave:** three graves at the edge of St. Andral's churchyard (prop `ana_grave`):
dig them up by day (Athletics DC 12; they wake surprised and weak) or wait for them at night (`roses_graves`).

- Fights: `roses_street` at level 5 is Ana (50 HP), Irina and a swarm of bats; `roses_graves` by day has all three girls
  surprised at reduced HP, by night at full strength. Attention mark `roses` (+1).
- Rewards: Pyotr Petrov the chandler (by day in the lower town) pays 200 gp for Mila's life; Ilie gives Ana's mother's
  ring, a Ring of Resistance (Necrotic) (rare), once Ana is at rest.

### Ribbons (`ribbons`, narrative/vallaki/ribbons.dialogue; batch 2)

Daciana the ribbon girl writes down everyone who won't wear a festival ribbon ("it's not me who wants to know"); Anton in
the stocks points at her. She leaves the list under the lamp on Main Street at dusk (prop `ribbon_lamp`). **Twist:**
Watchman Dobre (lane 28's patrol) collects it and sells it three times: to the Baron's clerk (the stocks), to Wachterhaus
(her ladies visit whoever's in the stocks) and to a rider on a black horse at the west gate (the castle). **Escalation:**
the stake-out: follow him (Stealth DC 13) and catch the hand-off at the gate, or confront him at the lamp; Daciana can
leave the list blank to make the rider turn on him.

- Fights `ribbons_street` (Dobre and 3 of his lads, warrior veterans: 2,800 XP at level 5) and `ribbons_gate` (the same
  plus the rider and his man: 3,350); one more lad at 6+, one fewer below 5. Dobre leaves his beat once beaten.
- Daciana comes running after the fight: the satchel gives 250 gp of castle silver and an Arcane Grimoire, +2 (rare),
  and the lists go to Lucian and Urwin (the stocks empty), to the Baron (+100 gp, Dobre in his own stocks) or into the
  fire. Attention mark `lists` (+1).

### The Hunters at the Inn (`hunters_at_the_inn`, narrative/vallaki/hunters_at_the_inn.dialogue; batch 2, the book's pair)

Szoldar and his son Yevgeni (new NPCs in the Blue Water Inn's taproom; Urwin's rumour) offer half the Baron's 300 gp
for Old Greytooth. **Twist:** Arrigal pays Szoldar to bring strong strangers to the lake at dusk; the wolf is the castle's,
and the castle wants to see how you fight. Yevgeni says so (Persuasion DC 13, or a drink). **Escalation:** the hunt at
the Lake Zarovich landing at dusk (prop `greytooth_shore`), with Szoldar's bow on the rise behind the shacks unless he's
been turned (Intimidation DC 14) or left at the inn.

- **Boss: Old Greytooth** (data/monsters/old_greytooth.json, `source.book: custom`, drawn with the dire wolf's sprite):
  Huge, AC 15, 171 HP, two 2d10+5 bites that knock prone, a recharging howl (DC 15 Wis or Frightened), Legendary
  Resistance (2/day) and one extra bite a round as a legendary action. CR 8.
- Fight `greytooth_hunt`: level 6 Greytooth (150 HP), 2 dire wolves, 2 wolves; level 7 three dire wolves; level 8 adds
  a werewolf; Szoldar (bandit captain) on the rise unless dealt with, and he runs below 25 HP (`szoldar_fled`). The
  autopilot (tests/integration/test_side_quest_bosses.gd) wins about half its level 6 tries, losing three of four
  party members on the way. Attention mark `greytooth` (+1).
- Yevgeni pays the whole bounty, 300 gp, and gives his father's Horn of Valhalla, Silver (rare).

## Lake Zarovich (level 8)

### The Bell Under the Lake (`bell_under_the_lake`, narrative/lake_zarovich/bell_under_the_lake.dialogue; batch 2)

Old Nistor, the last fisherman (lane 28), tells it once the Arabelle business is over: before the count dammed the Luna,
the hamlet of Pescari stood where the lake is, and the ones who wouldn't leave its chapel are still in it with the
bell. **Twist:** Bluto wasn't mad; his sacks were paying the bell, and now they've stopped. **Escalation:** after
moonrise (prop `bell_water` at the jetty's end) the drowned come up the shore for Bluto (if he's alive at the landing)
or for Nistor. Stand in front of him, or stand aside and let them take Bluto (`bluto_fate` becomes `drowned`); they rise
either way.

- Fight `drowned_landing`: level 8 the Bellringer (a wraith), the Lake's Undertow (a water elemental), 4 ghasts and 6
  ghouls (6,600 XP; the autopilot wins two of three and loses most of the party doing it); level 9 adds a second
  undertow and a drowned bride (a wight); below 8 a wight, 2 ghasts and 6 ghouls.
- Then cut the bell loose (Athletics DC 15, Water Breathing or the potion) or ring it once for the dead (Religion DC 14):
  200 gp of chapel silver and the drowned priest's Staff of Healing (rare).

## Krezk (level 7)

Talker: the watchman (gate:news, renamed). Wiring: Ilya's sickness starts `the_burgomasters_son` at `heard` (if
nothing has yet), the stopped wine starts `wizard_of_wines` at `rumored`, and the children taken from the farms below
the wall set `werewolf_rumor` and start `wolves_in_the_hills` at `heard`. Kasha Varo's graves answer adds the toys.

### Lighter Than It Should Be (`lighter_than_it_should_be`, narrative/krezk/lighter_than_it_should_be.dialogue)

Somebody leaves carved toys on the five Krezkov graves at the Pool of the White Sun (prop `krezkov_toys`); Old Pavel
the carver says they're cut with a thumbnail, not a knife. **The vigil:** after midnight a goat-legged figure comes over
the north wall and sings Anna's lullaby in Anna's voice. **Twist:** he is Sorin, the Krezkovs' first son: Anna carried
him up the mountain with the fever twenty years ago against Dmitri's wishes, and the Abbot sent down a nailed coffin
full of stones (dig the eldest grave to see it). Dmitri calls Ilya his last son. **Escalation:** while the Abbot holds
the abbey (no `abbot_fate`), the abbey comes for its stray (`sorin_pursuers` at the pool). **Climax:** the family scene
at the Krezkov house: Persuasion DC 15, Insight DC 13, the coffin of stones, or Ilya asking his brother to carve a wolf
brings Sorin `home`; otherwise he stays at the pool with Kasha (`pool`) or goes back up the mountain (`mountain`).

- Fight `sorin_pursuers`: level 7 two flesh golems ("A Bride Before Vasilka"), 3 Belview Brutes (berserkers, as the
  Krezk doc stands them in) and 4 mongrelfolk (5,150 XP, Moderate); level 8 a third bride; below 7 one bride, 2 Brutes,
  4 mongrelfolk.
- Rewards in every ending: Anna's 400 gp (a dowry for a daughter they never had) and Dmitri's grandfather's mail, an
  Armor, +1 (rare, chain mail).

## Spoken lines

New lines are unvoiced until the voice thread records them: polite_caller.dialogue and cut_after_noon.dialogue in full
(new speakers Teodor and Luca), townsfolk.dialogue's gossip and gravedigger_teodor nodes, bildrath.dialogue's
news_grigore node and his two added lines (the windmill), and arik.dialogue's rumors node. The Tser Pool camp:
grey_mare.dialogue in full (Radu, Luminita), and tser_camp.dialogue's two added Zora lines. Batch 2, Tser Pool:
called_by_name.dialogue in full (new speaker Nelu; also Big Tobar), tser_camp.dialogue's new Zora lines (Nelu) and its
nelu node. Batch 2, Vallaki: ribbons.dialogue and hunters_at_the_inn.dialogue in full (new speakers Szoldar and
Yevgeni; also Daciana, Watchman Dobre), townsfolk.dialogue's grumbler_who node and the added ribbon_refuse lines, and
martikovs.dialogue's new rumours lines (the hunters). Batch 2, Lake
Zarovich: bell_under_the_lake.dialogue in full (Old Nistor, Bluto) and old_fisher.dialogue's added option. Vallaki:
cat_in_the_window.dialogue and black_roses.dialogue in full (new speakers Stella Wachter, Ana and Pyotr Petrov; also
Ilie and Father Lucian), the new lines in gate.dialogue (news: Stella), martikovs.dialogue (rumors: the roses),
arasek.dialogue (roads: the windmill) and the polite_caller.dialogue sunrise line rewritten as a break in the mist. Krezk:
six_feet.dialogue in full (new speaker Zinaida;
also Old Mihail and Goodwife Petra), the new lines in townsfolk.dialogue (goodwife after the burial, gravedigger after it)
and arik.dialogue (rumors: "Mihail. Digs early."). lighter_than_it_should_be.dialogue in full (new speaker Sorin; also Anna, Dmitri, Ilya, Kasha and Old Pavel), the new
lines in krezk gate.dialogue (news: Ilya, the stolen children, the toys), kasha.dialogue (graves: the toys) and, on
sq-krezk, black_roses.dialogue's lines naming the third girl (Daria, renamed from Sorina).
